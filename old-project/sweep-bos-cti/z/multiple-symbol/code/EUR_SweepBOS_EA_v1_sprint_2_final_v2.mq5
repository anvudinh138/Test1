//+------------------------------------------------------------------+
//|                                      EUR_SweepBOS_EA_v1_sprint_2 |
//|  Single-symbol (EURUSD-ready) EA: Sweep -> BOS -> Retest -> Entry |
//|  Features: fixed lot, spread/margin guard, safe SL/TP conversion, |
//|            killzones, end-of-test summary logging.                |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"
#property description "Single-symbol BOS/Retest EA tuned for EURUSD (price-based inputs, not pips)."

#include <Trade/Trade.mqh>
CTrade trade;

//============================= INPUTS ===============================
// Symbol / timeframe
input string InpSymbol          = "EURUSD";
input ENUM_TIMEFRAMES InpTF     = PERIOD_M1;

// Switches
input bool   EnableLong         = true;
input bool   EnableShort        = true;

// Core structure
input int    K_swing            = 50;        // lookback bars for swing high/low
input int    N_bos              = 6;         // min bars since swing before BOS valid
input int    LookbackInternal   = 12;        // extra guard (bars) around BOS
input int    M_retest           = 3;         // bars to wait for retest after BOS

// Price-based filters (UNITS = price, not pips)
input double EqTol_USD          = 0.00020;   // equality tolerance near BOS level
input double RetestOffset_USD   = 0.00010;   // small offset to avoid exact touch
input double SL_Buffer_USD      = 0.00030;   // extra beyond swing for SL

// Execution & risk
input double MaxSpreadPrice     = 0.00030;   // e.g., EURUSD 3.0 pips
input bool   UseFixedLot        = true;
input double InpFixedLot        = 0.01;
input double MarginBufferPct    = 5.0;
input int    MagicBase          = 620200;

// TP/SL RR
input double RR_TP              = 2.0;       // TP distance = RR * (entry - SL)

// Killzones
input bool   UseKillzones       = true;
input int    KZ1_StartMin       = 420;       // 07:00
input int    KZ1_EndMin         = 600;       // 10:00
input int    KZ2_StartMin       = 780;       // 13:00
input int    KZ2_EndMin         = 990;       // 16:30
input bool   Debug              = true;

//============================ INTERNALS =============================
MqlRates    rates[];
datetime    last_bar_time = 0;

enum StateEnum { ST_IDLE=0, ST_ARMED=1 };
StateEnum   state = ST_IDLE;

// BOS state
bool        bosIsShort=false;
double      bosLevel=0.0;
datetime    bosBarTime=0;
double      sweepHigh=0.0, sweepLow=0.0;
int         retestCountdown=0;

//=========================== SMALL HELPERS ==========================
double SpreadPrice(){
   MqlTick t; if(!SymbolInfoTick(InpSymbol,t)) return 0.0;
   return (t.ask - t.bid);
}
int VolumeDigitsByStep(double step){ int d=0; while(step<1.0 && d<8){ step*=10.0; d++; } return d; }
double ClampLotToSymbol(const string s, double vol){
   double step = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   int vd = VolumeDigitsByStep(step);
   vol = MathRound(vol/step)*step;
   if(vol<vmin) vol=vmin;
   if(vol>vmax) vol=vmax;
   return NormalizeDouble(vol, vd);
}
double ComputeFixedLot(const string s, double desired){
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double vol  = (desired>0?desired:vmin);
   if(vol<0.01) vol=0.01;
   return ClampLotToSymbol(s, vol);
}
bool CanAfford(const string s, bool isShort, double vol, double bufferPct){
   MqlTick t; if(!SymbolInfoTick(s, t)) return false;
   double px = isShort? t.bid : t.ask;
   double need=0.0;
   if(!OrderCalcMargin(isShort?ORDER_TYPE_SELL:ORDER_TYPE_BUY, s, vol, px, need)){
      PrintFormat("[%s] OrderCalcMargin failed (err=%d)", s, GetLastError());
      return false;
   }
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   return (fm >= need*(1.0+bufferPct/100.0));
}
bool IsInKillzone(){
   if(!UseKillzones) return true;
   datetime now = TimeCurrent();
   MqlDateTime mt; TimeToStruct(now, mt);
   int mins = mt.hour*60 + mt.min;
   bool in1 = (mins>=KZ1_StartMin && mins<=KZ1_EndMin);
   bool in2 = (mins>=KZ2_StartMin && mins<=KZ2_EndMin);
   return (in1 || in2);
}
bool UpdateRates(int need=450){
   ArraySetAsSeries(rates,true);
   int c = CopyRates(InpSymbol, InpTF, 0, need, rates);
   return (c>0);
}
bool NewBar(){
   if(ArraySize(rates)<2) return false;
   if(rates[1].time != last_bar_time){
      last_bar_time = rates[1].time;
      return true;
   }
   return false;
}

// Stops helpers
struct StopSpec { double point; int digits; double stopLevel; };
void GetStopsSpec(const string s, StopSpec &sp){
   sp.point   = SymbolInfoDouble(s, SYMBOL_POINT);
   sp.digits  = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
   int slv    = (int)SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL);
   sp.stopLevel = slv * sp.point;
}
// If sl/tp tiny (<50*point) -> treat as distance; correct side & respect StopsLevel; normalize
void FixStopsForMarket(const string s, bool isShort, double &sl, double &tp){
   StopSpec sp; GetStopsSpec(s,sp);
   MqlTick t; if(!SymbolInfoTick(s,t)) return;
   double ask=t.ask, bid=t.bid, minDist=sp.stopLevel;

   if(sl>0 && sl < 50.0*sp.point) sl = isShort? (ask+sl) : (bid-sl);
   if(tp>0 && tp < 50.0*sp.point) tp = isShort? (bid-tp) : (ask+tp);

   if(isShort){
      if(sl>0 && sl < ask+minDist) sl = ask+minDist;
      if(tp>0 && tp > bid-minDist) tp = bid-minDist;
      if(sl>0 && sl<=ask)  sl = ask+minDist;
      if(tp>0 && tp>=bid)  tp = bid-minDist;
   }else{
      if(sl>0 && sl > bid-minDist) sl = bid-minDist;
      if(tp>0 && tp < ask+minDist) tp = ask+minDist;
      if(sl>0 && sl>=bid)  sl = bid-minDist;
      if(tp>0 && tp<=ask)  tp = ask+minDist;
   }
   if(sl>0) sl = NormalizeDouble(sl, sp.digits);
   if(tp>0) tp = NormalizeDouble(tp, sp.digits);
}

bool SendMarket(bool isShort, double lots, double sl, double tp){
   trade.SetExpertMagicNumber(MagicBase);
   if(MaxSpreadPrice>0 && SpreadPrice()>MaxSpreadPrice){
      if(Debug) Print("[",InpSymbol,"] spread too high: ", DoubleToString(SpreadPrice(),6));
      return false;
   }
   if(!CanAfford(InpSymbol, isShort, lots, MarginBufferPct)){
      if(Debug){
         MqlTick t; SymbolInfoTick(InpSymbol,t);
         double need=0; OrderCalcMargin(isShort?ORDER_TYPE_SELL:ORDER_TYPE_BUY, InpSymbol, lots, isShort?t.bid:t.ask, need);
         double fm=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         PrintFormat("[%s] Not enough margin: need=%.2f, free=%.2f, vol=%.2f", InpSymbol, need, fm, lots);
      }
      return false;
   }
   FixStopsForMarket(InpSymbol, isShort, sl, tp);

   bool ok = isShort
     ? trade.Sell(lots, InpSymbol, 0.0, sl, tp, "EUR_BOS")
     : trade.Buy (lots, InpSymbol, 0.0, sl, tp, "EUR_BOS");

   int rc = trade.ResultRetcode();
   string rcdesc = trade.ResultRetcodeDescription();

   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_PLACED)){
      PrintFormat("[%s] OrderSend FAILED (rc=%d) %s | price=%.5f sl=%.5f tp=%.5f lots=%.2f",
                  InpSymbol, rc, rcdesc, trade.ResultPrice(), sl, tp, lots);
      return false;
   }
   PrintFormat("[%s] %s OK (rc=%d) %s | ticket=%I64u price=%.5f sl=%.5f tp=%.5f lots=%.2f",
               InpSymbol, isShort?"SELL":"BUY", rc, rcdesc, trade.ResultOrder(),
               trade.ResultPrice(), sl, tp, lots);
   return true;
}

//=========================== STRATEGY CORE ==========================
// Find recent swing high/low over K_swing bars ending at bar[1]
bool GetRecentSwing(double &hi, double &lo, int &hiShift, int &loShift){
   if(ArraySize(rates)<(K_swing+2)) return false;
   hi = -DBL_MAX; lo = DBL_MAX; hiShift=-1; loShift=-1;
   for(int i=1; i<=K_swing; ++i){
      if(rates[i].high > hi){ hi = rates[i].high; hiShift=i; }
      if(rates[i].low  < lo){ lo = rates[i].low;  loShift=i; }
   }
   return (hiShift>0 && loShift>0);
}

// Detect BOS (break of structure) on bar[1] close
bool TryDetectBOS(){
   double hi,lo; int hiS,loS;
   if(!GetRecentSwing(hi,lo,hiS,loS)) return false;

   // need swing at least N_bos bars back
   int minShift = MathMin(hiS, loS);
   if(minShift < N_bos) return false;

   double c1 = rates[1].close;
   // BOS long: close > recent swing high
   if(EnableLong && c1 > hi){
      bosIsShort = false;
      bosLevel   = hi;
      sweepHigh  = hi;
      sweepLow   = lo;
      bosBarTime = rates[1].time;
      retestCountdown = M_retest;
      state = ST_ARMED;
      if(Debug) Print(TimeToString(rates[1].time,TIME_DATE|TIME_MINUTES|TIME_SECONDS), "  BOS-Long armed | swingHi@", TimeToString(rates[hiS].time,TIME_MINUTES|TIME_SECONDS));
      return true;
   }
   // BOS short: close < recent swing low
   if(EnableShort && c1 < lo){
      bosIsShort = true;
      bosLevel   = lo;
      sweepHigh  = hi;
      sweepLow   = lo;
      bosBarTime = rates[1].time;
      retestCountdown = M_retest;
      state = ST_ARMED;
      if(Debug) Print(TimeToString(rates[1].time,TIME_DATE|TIME_MINUTES|TIME_SECONDS), "  BOS-Short armed | swingLo@", TimeToString(rates[loS].time,TIME_MINUTES|TIME_SECONDS));
      return true;
   }
   return false;
}

// Try enter on retest within M_retest bars
void TryEnterAfterRetest(){
   if(state!=ST_ARMED) return;
   if(--retestCountdown < 0){
      state = ST_IDLE;
      if(Debug) Print(TimeToString(rates[0].time,TIME_DATE|TIME_MINUTES|TIME_SECONDS),"  Retest window expired");
      return;
   }
   if(!IsInKillzone()) return;

   // Check retest at current bar[0]
   MqlTick t; if(!SymbolInfoTick(InpSymbol,t)) return;

   if(!bosIsShort){
      // Long: want pullback near bosLevel
      bool touched = (rates[0].low <= (bosLevel + EqTol_USD + RetestOffset_USD));
      if(touched){
         double entry = t.ask;
         double sl = MathMin(sweepLow, bosLevel) - SL_Buffer_USD;
         double risk = MathAbs(entry - sl);
         double tp = entry + RR_TP * risk;

         double lots = UseFixedLot ? ComputeFixedLot(InpSymbol, InpFixedLot)
                                   : ComputeFixedLot(InpSymbol, 0.01);
         if(lots>0 && SpreadPrice()<=MaxSpreadPrice){
            if(SendMarket(false, lots, sl, tp)) state = ST_IDLE;
         }
      }
   }else{
      // Short: retest up to bosLevel
      bool touched = (rates[0].high >= (bosLevel - EqTol_USD - RetestOffset_USD));
      if(touched){
         double entry = t.bid;
         double sl = MathMax(sweepHigh, bosLevel) + SL_Buffer_USD;
         double risk = MathAbs(sl - entry);
         double tp = entry - RR_TP * risk;

         double lots = UseFixedLot ? ComputeFixedLot(InpSymbol, InpFixedLot)
                                   : ComputeFixedLot(InpSymbol, 0.01);
         if(lots>0 && SpreadPrice()<=MaxSpreadPrice){
            if(SendMarket(true, lots, sl, tp)) state = ST_IDLE;
         }
      }
   }
}

//============================ REPORT (LOG) ==========================
struct ReportAgg { int trades; int wins; int losses; double net; };
ReportAgg rep={0,0,0,0.0};

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
  if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
  ulong deal = trans.deal;
  long entry=0; if(!HistoryDealGetInteger(deal, DEAL_ENTRY, entry)) return;
  if(entry != DEAL_ENTRY_OUT) return;
  string dsym=""; HistoryDealGetString(deal, DEAL_SYMBOL, dsym);
  if(dsym!=InpSymbol) return;

  long mg=0; HistoryDealGetInteger(deal, DEAL_MAGIC, mg);
  if(mg != MagicBase) return;

  double profit=0, comm=0, swp=0;
  HistoryDealGetDouble(deal, DEAL_PROFIT, profit);
  HistoryDealGetDouble(deal, DEAL_COMMISSION, comm);
  HistoryDealGetDouble(deal, DEAL_SWAP, swp);
  rep.trades++;
  rep.net += profit + comm + swp;
  if(profit>=0) rep.wins++; else rep.losses++;
}

void LogSummary(){
   Print("============== Summary (", InpSymbol, ") ==============");
   double wr = (rep.trades>0)? (100.0*rep.wins/rep.trades) : 0.0;
   PrintFormat("Trades=%d | Win=%d | Loss=%d | WinRate=%.2f%% | Net=%.2f",
               rep.trades, rep.wins, rep.losses, wr, rep.net);
   Print("=======================================================");
}

//============================ LIFECYCLE ============================
int OnInit(){
   trade.SetAsyncMode(false);
   SymbolSelect(InpSymbol, true);
   trade.SetExpertMagicNumber(MagicBase);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
   LogSummary();
}
void OnTick(){
   if(!UpdateRates(450)) return;
   if(NewBar()){
      if(SpreadPrice()<=MaxSpreadPrice){
         TryDetectBOS();
      }
   }
   TryEnterAfterRetest();
}
//+------------------------------------------------------------------+
