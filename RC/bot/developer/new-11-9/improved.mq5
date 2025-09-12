//+------------------------------------------------------------------+
//|                         PTG Bot v1.3.2 (XAUUSD M1/M5)            |
//| Push-Test-Go: QuickScalp (QuickExit=true) / TrailRunner (false)  |
//| Includes: MinRisk/MaxRisk, MinPushRange, Time-Stop, BE offset,   |
//| Partial TP, spread in pips, pending-level validator,             |
//| ZeroMemory init + OrderSend checks.                              |
//+------------------------------------------------------------------+
#property strict
#property version   "1.32"
#property copyright "PTG Trading Strategy 2024"

//==================== INPUTS ====================//
input group "=== PTG CORE SETTINGS ==="
input bool   UseEMAFilter       = false;
input bool   UseVWAPFilter      = false;     // (reserved)
input int    LookbackPeriod     = 10;

input group "=== PUSH PARAMETERS (OPTIMIZED) ==="
input double PushRangePercent   = 0.35;      // % of max range (lookback)
input double ClosePercent       = 0.45;
input double OppWickPercent     = 0.65;
input double VolHighMultiplier  = 1.0;
input double MinPushRangePips   = 8.0;       // NEW: ignore push bars < X pips

input group "=== TEST PARAMETERS (BALANCED) ==="
input int    TestBars           = 10;
input int    PendingTimeout     = 5;
input double PullbackMax        = 0.85;
input double VolLowMultiplier   = 2.0;

input group "=== YOLO PIP MANAGEMENT ==="
input double BreakevenPips      = 5.0;       // recommend 5 for scalp
input double QuickExitPips      = 10.0;      // test 8/10/12
input bool   UseQuickExit       = true;      // true=QuickScalp, false=Runner
input double TrailStepPips      = 12.0;
input double MinProfitPips      = 4.0;

input group "=== RISK MANAGEMENT ==="
input double EntryBufferPips    = 0.5;
input double SLBufferPips       = 0.5;
input bool   UseFixedLotSize    = true;
input double FixedLotSize       = 0.10;      // ~ $1/pip with XAU if 0.10 lot
input double MaxSpreadPips      = 20.0;
input double MinRiskPips        = 6.0;       // SL < 6p -> widen to 6p
input double MaxRiskPips        = 60.0;      // SL > 60p -> skip (broader for M1)
input double MinEntryDistancePips = 2.0;     // NEW: min distance from market for pendings

input group "=== TIME-STOP (KILL DEAD TRADE) ==="
input bool   UseTimeStop        = true;
input int    MaxBarsInTrade     = 12;
input double MinProfitToHoldPips= 3.0;

input group "=== TRADING HOURS ==="
input bool   UseTimeFilter      = false;
input string StartTime          = "00:00";
input string EndTime            = "23:59";

input group "=== SYSTEM ==="
input bool   AllowMultiplePositions = false;
input int    MinBarsBetweenTrades   = 1;
input bool   EnableDebugLogs    = true;
input bool   EnableAlerts       = true;

input group "=== BEHAVIOR ADD-ONS ==="
input bool   BEOnBarClose       = true;      // move to BE after bar closes
input double BEOffsetPips       = 0.5;       // SL at entry ± offset
input bool   EnablePartialTP    = true;      // partial close @ TP1
input double TP1Pips            = 10.0;
input double TP1Part            = 0.5;       // 50%

input group "=== VERSION ==="
input string BotVersion         = "v1.3.2";

//==================== GLOBALS ====================//
int      ema34_handle, ema55_handle;
double   ema34[], ema55[];
double   pip_size = 0.01; // XAUUSD 1 pip = 0.01

bool     wait_test=false, long_direction=false;
int      push_bar_index=0;
double   push_high, push_low, push_range, test_high=0, test_low=0;
datetime last_trade_time=0, order_place_time=0;

int      total_signals=0, total_trades=0, last_order_ticket=0;

double   original_entry_price=0, original_sl_price=0;
bool     position_active=false;
ulong    active_position_ticket=0;

// pip management state
bool     quick_exit_triggered=false;
bool     pip_breakeven_activated=false;
double   last_trail_level=0;

// BE-on-close state
bool     be_armed=false;
datetime be_armed_bar=0;

// partial tp
bool     partial_done=false;

// time-stop tracking
datetime position_entry_bar_time=0;

// run once/bar
datetime g_bar_time=0;

//==================== INIT/DEINIT ====================//
int OnInit()
{
   string symbol=Symbol();
   if(StringFind(symbol,"XAU")>=0 || StringFind(symbol,"GOLD")>=0) pip_size=0.01;
   else if(StringFind(symbol,"JPY")>=0) pip_size=0.01;
   else if(StringFind(symbol,"USD")>=0) pip_size=0.0001;
   else pip_size=0.00001;

   ema34_handle=iMA(symbol,PERIOD_CURRENT,34,0,MODE_EMA,PRICE_CLOSE);
   ema55_handle=iMA(symbol,PERIOD_CURRENT,55,0,MODE_EMA,PRICE_CLOSE);
   if(ema34_handle==INVALID_HANDLE || ema55_handle==INVALID_HANDLE){ Print("Init error"); return INIT_FAILED; }

   Print("PTG ",BotVersion," | ",symbol," | pip=",pip_size);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int){ IndicatorRelease(ema34_handle); IndicatorRelease(ema55_handle); }

//==================== ONTICK ====================//
void OnTick()
{
   static datetime last_bar=0;
   g_bar_time=iTime(Symbol(),PERIOD_CURRENT,0);
   if(g_bar_time==last_bar) return; // once per bar
   last_bar=g_bar_time;

   if(!GetMarketData())  return;
   if(!IsTradingAllowed()) return;

   CheckPendingOrderTimeout();

   if(position_active) ManageYoloPipPosition();

   PTG_MainLogic();
}

//==================== HELPERS ====================//
bool GetMarketData()
{
   ArraySetAsSeries(ema34,true); ArraySetAsSeries(ema55,true);
   if(CopyBuffer(ema34_handle,0,0,LookbackPeriod+5,ema34)<=0) return false;
   if(CopyBuffer(ema55_handle,0,0,LookbackPeriod+5,ema55)<=0) return false;
   return true;
}
double GetVolumeSMA(int period,int shift=1)
{
   double s=0; for(int i=shift;i<shift+period;i++) s+=(double)iVolume(Symbol(),PERIOD_CURRENT,i);
   return s/period;
}
void CheckPendingOrderTimeout()
{
   if(last_order_ticket<=0 || order_place_time==0) return;
   int bars_elapsed=Bars(Symbol(),PERIOD_CURRENT,order_place_time,g_bar_time)-1;
   if(bars_elapsed>=PendingTimeout)
   {
      MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
      r.action=TRADE_ACTION_REMOVE; r.order=last_order_ticket;
      if(OrderSend(r,s))
      { if(EnableDebugLogs) Print("⏰ Removed pending #",last_order_ticket); }
      else
      { Print("⚠️ Remove pending failed: ",s.retcode," - ",s.comment); }
      last_order_ticket=0; order_place_time=0;
   }
}

// Validate pending prices vs market + broker stops level
bool EnsurePendingLevels(ENUM_ORDER_TYPE type, double &entry, double &sl, double &tp)
{
   const string sym   = Symbol();
   const int    digits= (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double point = _Point;
   const double ask   = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(sym, SYMBOL_BID);

   int stops_pts = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL); // in points
   double min_dist = MathMax(MinEntryDistancePips * pip_size, stops_pts * point);

   if(type == ORDER_TYPE_BUY_STOP)
   {
      if(entry <= ask + min_dist) entry = ask + min_dist;
      if((entry - sl) < min_dist)  sl    = entry - min_dist;
      if(UseQuickExit && (tp - entry) < min_dist) tp = entry + min_dist;
   }
   else if(type == ORDER_TYPE_SELL_STOP)
   {
      if(entry >= bid - min_dist) entry = bid - min_dist;
      if((sl - entry) < min_dist)  sl    = entry + min_dist;
      if(UseQuickExit && (entry - tp) < min_dist) tp = entry - min_dist;
   }

   entry = NormalizeDouble(entry, digits);
   sl    = NormalizeDouble(sl,    digits);
   if(UseQuickExit) tp = NormalizeDouble(tp, digits);
   return true;
}

//==================== POSITION MANAGEMENT ====================//
void ManageYoloPipPosition()
{
   string sym=Symbol();
   if(!PositionSelectByTicket(active_position_ticket)){ ResetPositionVariables(); return; }

   bool is_long=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double price=is_long?SymbolInfoDouble(sym,SYMBOL_BID):SymbolInfoDouble(sym,SYMBOL_ASK);
   double profit_pips=is_long?(price-original_entry_price)/pip_size:(original_entry_price-price)/pip_size;

   // partial TP
   if(EnablePartialTP && !partial_done && profit_pips>=TP1Pips) PartialCloseAndLock();

   // Quick Exit
   if(UseQuickExit && !quick_exit_triggered && profit_pips>=QuickExitPips)
   { ClosePositionAtMarket("QUICK EXIT +" + DoubleToString(profit_pips,1) + "p"); return; }

   // BE with on-close + offset
   if(!pip_breakeven_activated)
   {
      if(!BEOnBarClose){ if(profit_pips>=BreakevenPips){ MoveSLToEntry("BE instant"); return; } }
      else
      {
         if(!be_armed && profit_pips>=BreakevenPips){ be_armed=true; be_armed_bar=g_bar_time; }
         else if(be_armed && g_bar_time>be_armed_bar)
         {
            if(profit_pips>=BreakevenPips){ MoveSLToEntry("BE on close"); return; }
            be_armed=false;
         }
      }
   }

   // trailing after BE
   if(pip_breakeven_activated && profit_pips>=(last_trail_level+TrailStepPips))
   {
      double new_trail=MathFloor(profit_pips/TrailStepPips)*TrailStepPips;
      double new_sl_pips=new_trail-MinProfitPips;
      if(new_sl_pips>last_trail_level){ MoveSLToPipLevel(new_sl_pips, "TRAIL +"+DoubleToString(new_sl_pips,1)); last_trail_level=new_trail; }
   }

   // TIME-STOP
   if(UseTimeStop && position_entry_bar_time>0)
   {
      int live_bars=Bars(Symbol(),PERIOD_CURRENT,position_entry_bar_time,g_bar_time)-1;
      if(live_bars>=MaxBarsInTrade && profit_pips<MinProfitToHoldPips)
      { ClosePositionAtMarket("TIME-STOP ("+IntegerToString(live_bars)+" bars)"); return; }
   }
}

void PartialCloseAndLock()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   string sym=Symbol();
   double vol=PositionGetDouble(POSITION_VOLUME);
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   double minv=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double closeVol=MathMax(minv, MathFloor(vol*TP1Part/step)*step);

   MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
   r.action=TRADE_ACTION_DEAL; r.symbol=sym; r.position=active_position_ticket;
   r.volume=closeVol;
   r.type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   r.deviation=10; r.comment="TP1 partial";
   if(OrderSend(r,s))
   {
      partial_done=true;
      if(!pip_breakeven_activated) MoveSLToEntry("Lock after TP1");
   }
   else
   {
      Print("⚠️ Partial close failed: ",s.retcode," - ",s.comment);
   }
}

void ClosePositionAtMarket(string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
   r.action=TRADE_ACTION_DEAL; r.symbol=Symbol(); r.position=active_position_ticket;
   r.type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   r.volume=PositionGetDouble(POSITION_VOLUME); r.deviation=10; r.comment=reason;
   if(OrderSend(r,s))
   {
      quick_exit_triggered=true;
      if(EnableAlerts) Alert(reason);
   }
   else
   {
      Print("⚠️ Close at market failed: ",s.retcode," - ",s.comment);
   }
}

void MoveSLToEntry(string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   bool is_long=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double be_price=original_entry_price + (is_long?BEOffsetPips:-BEOffsetPips)*pip_size;

   MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
   r.action=TRADE_ACTION_SLTP; r.symbol=Symbol(); r.position=active_position_ticket;
   r.sl=NormalizeDouble(be_price,(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
   r.tp=PositionGetDouble(POSITION_TP);
   if(OrderSend(r,s))
   {
      pip_breakeven_activated=true; last_trail_level=BreakevenPips; be_armed=false;
      if(EnableDebugLogs) Print("🎯 ",reason," -> SL @ BE±",BEOffsetPips,"p");
   }
   else
   {
      Print("⚠️ BE failed: ",s.retcode," - ",s.comment);
   }
}

void MoveSLToPipLevel(double pip_level,string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   bool is_long=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double new_sl=is_long? original_entry_price + pip_level*pip_size
                        : original_entry_price - pip_level*pip_size;

   MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
   r.action=TRADE_ACTION_SLTP; r.symbol=Symbol(); r.position=active_position_ticket;
   r.sl=NormalizeDouble(new_sl,(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
   r.tp=PositionGetDouble(POSITION_TP);
   if(!OrderSend(r,s))
      Print("⚠️ Trail SL failed: ",s.retcode," - ",s.comment);
}

void ResetPositionVariables()
{
   position_active=false; active_position_ticket=0;
   original_entry_price=0; original_sl_price=0;
   quick_exit_triggered=false; pip_breakeven_activated=false;
   last_trail_level=0; be_armed=false; be_armed_bar=0;
   partial_done=false; position_entry_bar_time=0;
}

//==================== GUARDS ====================//
bool IsTradingAllowed()
{
   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double spread_pips=(ask-bid)/pip_size;
   if(spread_pips>MaxSpreadPips)
   {
      if(EnableDebugLogs && spread_pips>MaxSpreadPips*1.5)
         Print("SPREAD TOO HIGH: ",DoubleToString(spread_pips,1)," pips");
      return false;
   }

   if(UseTimeFilter)
   {
      MqlDateTime ts; TimeToStruct(TimeCurrent(),ts);
      int curH=ts.hour, startH=(int)StringToInteger(StringSubstr(StartTime,0,2));
      int endH=(int)StringToInteger(StringSubstr(EndTime,0,2));
      if(curH<startH || curH>=endH) return false;
   }

   if(!AllowMultiplePositions && (PositionsTotal()>0 || position_active)) return false;

   static datetime last_check=0;
   if(g_bar_time-last_check < MinBarsBetweenTrades*PeriodSeconds(PERIOD_CURRENT)) return false;
   last_check=g_bar_time;
   return true;
}

//==================== SIGNAL/ENTRY ====================//
void PTG_MainLogic()
{
   string sym=Symbol();
   double high=iHigh(sym,PERIOD_CURRENT,1), low=iLow(sym,PERIOD_CURRENT,1);
   double open=iOpen(sym,PERIOD_CURRENT,1), close=iClose(sym,PERIOD_CURRENT,1);
   long   volume=iVolume(sym,PERIOD_CURRENT,1);

   double range=high-low;
   double range_pips=range/pip_size;
   double close_pos_hi=(close-low)/MathMax(range,pip_size);
   double close_pos_lo=(high-close)/MathMax(range,pip_size);
   double low_wick=(MathMin(open,close)-low)/MathMax(range,pip_size);
   double up_wick=(high-MathMax(open,close))/MathMax(range,pip_size);

   // Max range in lookback
   double max_range=0;
   for(int i=1;i<=LookbackPeriod;i++)
   {
      double r=iHigh(sym,PERIOD_CURRENT,i)-iLow(sym,PERIOD_CURRENT,i);
      if(r>max_range) max_range=r;
   }

   bool up_trend=true, down_trend=true;
   if(UseEMAFilter && ArraySize(ema34)>1 && ArraySize(ema55)>1){ up_trend=(ema34[1]>ema55[1]); down_trend=(ema34[1]<ema55[1]); }

   bool big_range=(range>=max_range*PushRangePercent) && (range_pips>=MinPushRangePips);
   double vol_sma=GetVolumeSMA(LookbackPeriod,1);
   bool high_volume=(volume>=vol_sma*VolHighMultiplier);

   bool push_up  = up_trend && big_range && high_volume && (close_pos_hi>=ClosePercent) && (up_wick <=OppWickPercent);
   bool push_down= down_trend&& big_range && high_volume && (close_pos_lo>=ClosePercent) && (low_wick<=OppWickPercent);

   if(push_up || push_down)
   {
      total_signals++; wait_test=true; long_direction=push_up; push_bar_index=0;
      push_high=high; push_low=low; push_range=range; test_high=0; test_low=0;
   }

   if(!wait_test) return;
   push_bar_index++;

   if(push_bar_index>=1 && push_bar_index<=TestBars)
   {
      bool pullback_ok_long =  long_direction && ((push_high-low) <= PullbackMax*push_range);
      bool pullback_ok_short= !long_direction && ((high-push_low) <= PullbackMax*push_range);
      bool low_volume       = (volume <= vol_sma * VolLowMultiplier);
      bool small_range      = (range  <= max_range);

      bool test_long  = pullback_ok_long  && low_volume && small_range;
      bool test_short = pullback_ok_short && low_volume && small_range;

      if(test_long || test_short)
      {
         test_high=high; test_low=low;
         double entry, sl, tp;
         if(test_long)
         {
            entry=test_high + EntryBufferPips*pip_size;
            sl   =test_low  - SLBufferPips*pip_size;
            tp   =entry + QuickExitPips*pip_size;
            ExecuteYoloTrade(ORDER_TYPE_BUY_STOP, entry, sl, tp, "PTG LONG");
         }
         else
         {
            entry=test_low  - EntryBufferPips*pip_size;
            sl   =test_high + SLBufferPips*pip_size;
            tp   =entry - QuickExitPips*pip_size;
            ExecuteYoloTrade(ORDER_TYPE_SELL_STOP, entry, sl, tp, "PTG SHORT");
         }
         wait_test=false;
      }
   }
   if(push_bar_index>TestBars) wait_test=false;
}

void ExecuteYoloTrade(ENUM_ORDER_TYPE type,double entry,double sl,double tp,string comment)
{
   string sym=Symbol();
   total_trades++;

   // enforce min risk
   double risk_pips=MathAbs(entry-sl)/pip_size;
   if(type==ORDER_TYPE_BUY_STOP)
   { if(risk_pips < MinRiskPips) sl = entry - MinRiskPips*pip_size; }
   else
   { if(risk_pips < MinRiskPips) sl = entry + MinRiskPips*pip_size; }

   // validate pending distances (market + stops level)
   EnsurePendingLevels(type, entry, sl, tp);

   // recompute risk and compare to max
   risk_pips=MathAbs(entry-sl)/pip_size;
   if(risk_pips > MaxRiskPips + 1e-6)
   {
      if(EnableDebugLogs) Print("Skip trade after adjust: risk ",DoubleToString(risk_pips,1),"p > Max ",MaxRiskPips,"p");
      total_trades--; return;
   }

   original_entry_price=entry; original_sl_price=sl;

   double lot=FixedLotSize;
   double minv=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double maxv=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   lot=MathMax(minv, MathMin(maxv, MathFloor(lot/step)*step));

   MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s);
   r.action=TRADE_ACTION_PENDING; r.symbol=sym; r.volume=lot; r.type=type;
   r.price=NormalizeDouble(entry,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS));
   r.sl   =NormalizeDouble(sl,   (int)SymbolInfoInteger(sym,SYMBOL_DIGITS));
   r.tp   = UseQuickExit ? NormalizeDouble(tp,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)) : 0.0;
   r.comment=comment; r.magic=77777; r.deviation=10;

   if(OrderSend(r,s))
   {
      last_order_ticket=(int)s.order; order_place_time=TimeCurrent(); last_trade_time=TimeCurrent();
      if(EnableAlerts) Alert("Order placed: ",comment);
   }
   else
   {
      Print("⚠️ OrderSend fail: ", s.retcode," - ",s.comment);
      total_trades--;
      ResetPositionVariables();
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,const MqlTradeRequest& req,const MqlTradeResult& res)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;

   if((trans.deal_type==DEAL_TYPE_BUY || trans.deal_type==DEAL_TYPE_SELL) && !position_active && trans.position>0)
   {
      position_active=true; active_position_ticket=trans.position;
      partial_done=false; quick_exit_triggered=false; pip_breakeven_activated=false; be_armed=false;
      position_entry_bar_time=g_bar_time;
      if(EnableDebugLogs) Print("🎯 ENTRY ",(trans.deal_type==DEAL_TYPE_BUY?"LONG":"SHORT")," ",DoubleToString(trans.volume,2)," lots @ ",DoubleToString(trans.price,2));
      return;
   }

   if(trans.deal_type==DEAL_TYPE_BUY || trans.deal_type==DEAL_TYPE_SELL)
   {
      if(!PositionSelectByTicket(trans.position))
      {
         if(EnableDebugLogs) Print("💰 EXIT/FLAT ticket ",trans.position);
         ResetPositionVariables();
      }
   }
}
