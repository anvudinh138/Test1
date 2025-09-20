//+------------------------------------------------------------------+
//|                                         Fx_SweepBOS_EA_clean_build|
//|  Purpose : Multi-symbol scaffold + safe order wrappers + reporting|
//|  Notes   : No CSV, logs summary in OnDeinit/OnTesterDeinit        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"
#property description "Multi-symbol EA scaffold with ms timer, fixed lot, safe stops, and end-of-test logs."

#include <Trade/Trade.mqh>
CTrade trade;

//============================= INPUTS ===============================
input bool   UseMultiSymbol     = true;                               // Run many symbols from ONE chart
input string InpSymbolsCSV      = "XAUUSD,EURUSD,GBPUSD,USDJPY";      // Symbols to manage
input string InpSymbol          = "XAUUSD";                           // Single-symbol fallback when UseMultiSymbol=false
input ENUM_TIMEFRAMES InpTF     = PERIOD_M1;                          // Working timeframe

input bool   UseMsTimer         = true;                               // Use EventSetMillisecondTimer for sub-second
input int    InpTimerMs         = 200;                                // 200 ms ~ 0.2s
input int    InpTimerSeconds    = 1;                                  // Fallback seconds timer

input int    MagicBase          = 532100;                              // Magic number base per symbol idx

// --- Risk & execution ---
input bool   UseFixedLot        = true;                                // TRUE: always use fixed lot for safety
input double InpFixedLot        = 0.01;                                // Default lot (clamped to symbol min/step)
input double MaxSpreadPrice     = 0.5;                                 // Max spread (price units). Adjust per symbol.
input int    MaxOpenPerSymbol   = 1;                                   // Only 1 net position per symbol by default
input double MarginBufferPct    = 5.0;                                 // +5% margin headroom
input bool   Debug              = true;

// --- Demo strategy switch (for quick sanity tests only) ---
input bool   EnableDemoStrategy = false;                               // If true, place tiny trades on new bar (for demo)

//============================ INTERNALS =============================
string CurrSymbol = "";        // Symbol currently being processed
string Sym(){ return UseMultiSymbol ? CurrSymbol : InpSymbol; }

// Working buffers (shared; we swap state per symbol before use)
MqlRates rates[];              // price series
datetime last_bar_time = 0;    // last processed closed-bar time for CURRENT symbol

// Example state you may extend to mirror your real strategy
enum StateEnum { ST_IDLE=0, ST_ARMED=1, ST_INPOSITION=2 };
StateEnum state = ST_IDLE;

// Per-symbol state container
struct SymState {
   string    sym;
   datetime  last_bar_time;
   StateEnum state;
};
SymState gSyms[];

//============================= REPORTING ============================
struct SymReport {
  string sym;
  int    trades;       // number of closed deals
  int    wins;
  int    losses;
  double volume;       // total lots closed
  double grossProfit;  // >0
  double grossLoss;    // <0 (negative)
  double commission;
  double swap;
  double netProfit;    // profit + commission + swap
};
SymReport gRep[];

void SetupReportArray(){
  int n = (UseMultiSymbol ? ArraySize(gSyms) : 1);
  ArrayResize(gRep, n);
  if(UseMultiSymbol){
    for(int i=0;i<n;i++) gRep[i].sym = gSyms[i].sym;
  }else{
    gRep[0].sym = InpSymbol;
  }
}

// Live collection via OnTradeTransaction
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
  if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

  ulong deal = trans.deal;
  long entry=0; if(!HistoryDealGetInteger(deal, DEAL_ENTRY, entry)) return;
  if(entry != DEAL_ENTRY_OUT) return; // only when a position is closed

  string dsym=""; HistoryDealGetString(deal, DEAL_SYMBOL, dsym);
  int idx = UseMultiSymbol ? FindSymIdx(dsym) : 0;
  if(UseMultiSymbol && (idx<0 || idx>=ArraySize(gRep))) return;

  long mg=0; HistoryDealGetInteger(deal, DEAL_MAGIC, mg);
  long myMagic = MagicBase + (UseMultiSymbol ? idx : 0);
  if(mg != myMagic) return;

  double profit=0, comm=0, swp=0, vol=0;
  HistoryDealGetDouble(deal, DEAL_PROFIT,     profit);
  HistoryDealGetDouble(deal, DEAL_COMMISSION, comm);
  HistoryDealGetDouble(deal, DEAL_SWAP,       swp);
  HistoryDealGetDouble(deal, DEAL_VOLUME,     vol);

  gRep[idx].trades++;
  gRep[idx].volume     += vol;
  gRep[idx].commission += comm;
  gRep[idx].swap       += swp;
  gRep[idx].netProfit  += profit + comm + swp;
  if(profit >= 0){ gRep[idx].wins++;   gRep[idx].grossProfit += profit; }
  else            { gRep[idx].losses++; gRep[idx].grossLoss   += profit; }
}

void AggregateFromHistory(){
  HistorySelect(0, TimeCurrent());
  int total = (int)HistoryDealsTotal();
  for(int i=0;i<total;i++){
    ulong deal = HistoryDealGetTicket(i);
    long entry=0; HistoryDealGetInteger(deal, DEAL_ENTRY, entry);
    if(entry != DEAL_ENTRY_OUT) continue;

    string dsym=""; HistoryDealGetString(deal, DEAL_SYMBOL, dsym);
    int idx = UseMultiSymbol ? FindSymIdx(dsym) : 0;
    if(UseMultiSymbol && (idx<0 || idx>=ArraySize(gRep))) continue;

    long mg=0; HistoryDealGetInteger(deal, DEAL_MAGIC, mg);
    long myMagic = MagicBase + (UseMultiSymbol ? idx : 0);
    if(mg != myMagic) continue;

    double profit=0, comm=0, swp=0, vol=0;
    HistoryDealGetDouble(deal, DEAL_PROFIT,     profit);
    HistoryDealGetDouble(deal, DEAL_COMMISSION, comm);
    HistoryDealGetDouble(deal, DEAL_SWAP,       swp);
    HistoryDealGetDouble(deal, DEAL_VOLUME,     vol);

    gRep[idx].trades++;
    gRep[idx].volume     += vol;
    gRep[idx].commission += comm;
    gRep[idx].swap       += swp;
    gRep[idx].netProfit  += profit + comm + swp;
    if(profit >= 0){ gRep[idx].wins++;   gRep[idx].grossProfit += profit; }
    else            { gRep[idx].losses++; gRep[idx].grossLoss   += profit; }
  }
}

void LogSymbolReport(const string tag="FINAL")
{
  Print("====================================================");
  Print(" Multi-Symbol Report (", tag, ") — per symbol");
  Print("====================================================");

  int n = ArraySize(gRep);
  int    totalTrades = 0, totalWins = 0, totalLosses = 0;
  double totalVol = 0.0, totalGP = 0.0, totalGL = 0.0, totalComm = 0.0, totalSwap = 0.0, totalNet = 0.0;

  for(int i=0; i<n; ++i){
    double wr = (gRep[i].trades>0) ? (100.0*gRep[i].wins/gRep[i].trades) : 0.0;

    PrintFormat("[%s] Trades=%d | Win=%d | Loss=%d | WinRate=%.2f%% | Vol=%.2f | GP=%.2f | GL=%.2f | Comm=%.2f | Swap=%.2f | Net=%.2f",
      gRep[i].sym,
      gRep[i].trades,
      gRep[i].wins,
      gRep[i].losses,
      wr,
      gRep[i].volume,
      gRep[i].grossProfit,
      gRep[i].grossLoss,
      gRep[i].commission,
      gRep[i].swap,
      gRep[i].netProfit
    );

    totalTrades += gRep[i].trades;
    totalWins   += gRep[i].wins;
    totalLosses += gRep[i].losses;
    totalVol    += gRep[i].volume;
    totalGP     += gRep[i].grossProfit;
    totalGL     += gRep[i].grossLoss;
    totalComm   += gRep[i].commission;
    totalSwap   += gRep[i].swap;
    totalNet    += gRep[i].netProfit;
  }

  double totalWR = (totalTrades>0) ? (100.0*totalWins/totalTrades) : 0.0;

  Print("----------------------------------------------------");
  PrintFormat("[TOTAL] Trades=%d | Win=%d | Loss=%d | WinRate=%.2f%% | Vol=%.2f | GP=%.2f | GL=%.2f | Comm=%.2f | Swap=%.2f | Net=%.2f",
    totalTrades, totalWins, totalLosses, totalWR,
    totalVol, totalGP, totalGL, totalComm, totalSwap, totalNet
  );
  Print("====================================================");
}

//============================= HELPERS ==============================
int FindSymIdx(const string s)
{
   for(int i=0; i<ArraySize(gSyms); ++i)
      if(gSyms[i].sym == s) return i;
   return 0;
}

bool UpdateRates(const int need_bars=450){
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(Sym(), InpTF, 0, need_bars, rates);
   return (copied > 0);
}

double SpreadPrice(){
   MqlTick t; if(!SymbolInfoTick(Sym(), t)) return 0.0;
   return (t.ask - t.bid);
}

// Normalize a lot to symbol's constraints
int VolumeDigitsByStep(double step){
   int d=0; while(step < 1.0 && d < 8){ step *= 10.0; d++; }
   return d;
}
double ClampLotToSymbol(const string s, double vol){
   double step = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   int vd = VolumeDigitsByStep(step);
   vol = MathRound(vol/step)*step;
   if(vol < vmin) vol = vmin;
   if(vol > vmax) vol = vmax;
   return NormalizeDouble(vol, vd);
}
double ComputeFixedLot(const string s, double desired){
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double vol  = (desired>0 ? desired : vmin);
   if(vol < 0.01) vol = 0.01;
   return ClampLotToSymbol(s, vol);
}

// Netting-friendly: return 1 if this EA (symbol+magic) has an open position
int PositionsOnSymbol(){
   long myMagic = MagicBase + FindSymIdx(Sym());
   if(!PositionSelect(Sym())) return 0;
   long pmagic=0; PositionGetInteger(POSITION_MAGIC, pmagic);
   return (pmagic==myMagic ? 1 : 0);
}

// Margin check
bool CanAfford(const string s, bool isShort, double vol, double bufferPct){
  MqlTick t; if(!SymbolInfoTick(s, t)) return false;
  double px   = isShort ? t.bid : t.ask;
  double need = 0.0;
  if(!OrderCalcMargin(isShort ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, s, vol, px, need))
    return false;
  double fm = AccountInfoDouble(ACCOUNT_FREEMARGIN);
  return (fm >= need * (1.0 + bufferPct/100.0));
}

// ======= SAFE ORDER HELPERS (stops & retcode) ======================
struct StopSpec { double point; int digits; double stopLevel; };

void GetStopsSpec(const string s, StopSpec &sp)
{
   sp.point     = SymbolInfoDouble(s, SYMBOL_POINT);
   sp.digits    = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
   int slv      = (int)SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL);
   sp.stopLevel = slv * sp.point; // min distance from price to SL/TP in absolute price units
}

// Adjust SL/TP: correct side, min distance, normalize. If tiny -> treat as distance.
void FixStopsForMarket(const string s, bool isShort, double &sl, double &tp)
{
   StopSpec sp; GetStopsSpec(s, sp);
   MqlTick t; if(!SymbolInfoTick(s, t)) return;
   double ask=t.ask, bid=t.bid, minDist=sp.stopLevel;

   if(sl>0 && sl < 50.0*sp.point) sl = isShort ? (ask + sl) : (bid - sl);
   if(tp>0 && tp < 50.0*sp.point) tp = isShort ? (bid - tp) : (ask + tp);

   if(isShort){
      if(sl>0 && sl < ask + minDist) sl = ask + minDist;
      if(tp>0 && tp > bid - minDist) tp = bid - minDist;
      if(sl>0 && sl<=ask)  sl = ask + minDist;
      if(tp>0 && tp>=bid)  tp = bid - minDist;
   }else{
      if(sl>0 && sl > bid - minDist) sl = bid - minDist;
      if(tp>0 && tp < ask + minDist) tp = ask + minDist;
      if(sl>0 && sl>=bid)  sl = bid - minDist;
      if(tp>0 && tp<=ask)  tp = ask + minDist;
   }
   if(sl>0) sl = NormalizeDouble(sl, sp.digits);
   if(tp>0) tp = NormalizeDouble(tp, sp.digits);
}

bool SendMarket(bool isShort, double lots, double sl, double tp)
{
   const string s = Sym();
   FixStopsForMarket(s, isShort, sl, tp);

   // Spread guard
   if(MaxSpreadPrice>0 && SpreadPrice() > MaxSpreadPrice){
      if(Debug) Print("[",s,"] spread too high: ", DoubleToString(SpreadPrice(), 6));
      return false;
   }

   if(MaxOpenPerSymbol<=1 && PositionsOnSymbol()>0){
      if(Debug) Print("[",s,"] skip: already has position (magic matched).");
      return false;
   }

   if(!CanAfford(s, isShort, lots, MarginBufferPct)){
      if(Debug){
        MqlTick t; SymbolInfoTick(s,t);
        double need=0; OrderCalcMargin(isShort?ORDER_TYPE_SELL:ORDER_TYPE_BUY, s, lots, isShort?t.bid:t.ask, need);
        double fm=AccountInfoDouble(ACCOUNT_FREEMARGIN);
        PrintFormat("[%s] Not enough margin: need=%.2f, free=%.2f, vol=%.2f", s, need, fm, lots);
      }
      return false;
   }

   bool ok = isShort
      ? trade.Sell(lots, s, 0.0, sl, tp, "MS market")
      : trade.Buy (lots, s, 0.0, sl, tp, "MS market");

   const int rc = trade.ResultRetcode();
   const string rcdesc = trade.ResultRetcodeDescription();

   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_PLACED)){
      PrintFormat("[%s] OrderSend FAILED (rc=%d) %s | price=%.5f sl=%.5f tp=%.5f lots=%.2f",
                  s, rc, rcdesc, trade.ResultPrice(), sl, tp, lots);
      return false;
   }

   PrintFormat("[%s] %s OK (rc=%d) %s | ticket=%I64u price=%.5f sl=%.5f tp=%.5f lots=%.2f",
               s, isShort?"SELL":"BUY", rc, rcdesc, trade.ResultOrder(),
               trade.ResultPrice(), sl, tp, lots);
   return true;
}

//=========================== STRATEGY HOOKS =========================
// NOTE: Replace with your real logic (Sweep -> BOS -> Retest -> Entry).
// This demo will optionally place a tiny trade each new bar to verify plumbing.
void Strategy_OnNewBar()
{
   if(!EnableDemoStrategy) return;

   // Simple demo: alternate BUY/SELL each new bar per symbol
   static bool flip=false;
   double lots = UseFixedLot ? ComputeFixedLot(Sym(), InpFixedLot) : ComputeFixedLot(Sym(), 0.01);
   double sl   = 0.5;   // interpret as price-distance (FixStopsForMarket will convert)
   double tp   = 1.0;   // price-distance

   if(flip) SendMarket(true,  lots, sl, tp);  // SELL
   else     SendMarket(false, lots, sl, tp);  // BUY
   flip = !flip;
}

void Strategy_ManageOpenPosition()
{
   // Keep empty for now; paste management logic here if needed
}

//============================ MAIN EVENTS ===========================
int OnInit(){
   trade.SetAsyncMode(false);

   if(UseMultiSymbol){
      // parse CSV -> gSyms
      string parts[]; int n = StringSplit(InpSymbolsCSV, ',', parts);
      ArrayResize(gSyms, 0);
      for(int i=0;i<n;i++){
         string s = StringTrim(parts[i]);
         if(s=="") continue;
         SymbolSelect(s, true); // ensure data feed
         SymState st;
         st.sym = s;
         st.last_bar_time = 0;
         st.state = ST_IDLE;
         int sz=ArraySize(gSyms); ArrayResize(gSyms, sz+1); gSyms[sz]=st;
      }
   }else{
      SymbolSelect(InpSymbol, true);
      ArrayResize(gSyms, 1);
      gSyms[0].sym = InpSymbol;
      gSyms[0].last_bar_time = 0;
      gSyms[0].state = ST_IDLE;
   }

   // set timer
   if(UseMsTimer && InpTimerMs>0) EventSetMillisecondTimer(InpTimerMs);
   else EventSetTimer(MathMax(1, InpTimerSeconds));

   // prepare reporting
   SetupReportArray();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   EventKillTimer();
   // finalize report (backup aggregate) and log
   AggregateFromHistory();
   LogSymbolReport("OnDeinit");
}

void OnTesterDeinit()
{
   AggregateFromHistory();
   LogSymbolReport("OnTesterDeinit");
}

// Drive via timer (symbol-agnostic)
void OnTick(){ /* Intentionally empty: we drive via timer */ }

void OnTimer(){
   if(UseMultiSymbol){
      for(int i=0;i<ArraySize(gSyms); ++i){
         CurrSymbol = gSyms[i].sym;
         trade.SetExpertMagicNumber(MagicBase + i);
         // load state
         last_bar_time = gSyms[i].last_bar_time;
         state         = gSyms[i].state;

         ProcessSingle();

         // save back
         gSyms[i].last_bar_time = last_bar_time;
         gSyms[i].state         = state;
      }
   }else{
      CurrSymbol = InpSymbol;
      trade.SetExpertMagicNumber(MagicBase);
      ProcessSingle();
   }
}

// Core routine used by both single & multi
void ProcessSingle(){
   if(!UpdateRates(450)) return;
   if(ArraySize(rates) < 2)  return;

   // Closed-bar detection
   datetime closed = rates[1].time;
   if(closed != last_bar_time){
      last_bar_time = closed;
      Strategy_OnNewBar();         // <-- plug your entry logic here
   }

   // Manage position every tick
   Strategy_ManageOpenPosition();
}
//+------------------------------------------------------------------+
