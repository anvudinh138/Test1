//+------------------------------------------------------------------+
//|                    PTG REFINED v3.2.5                           |
//|          Back to v3.2.3 Success + Strategic Quality Only        |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.25"
#property description "PTG v3.2.5 - REFINED: Back to v3.2.3 success + minimal strategic improvements"

//=== REFINED INPUTS (Back to Success + Quality) ===
input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // PROVEN: 10 (exact v3.2.3)

input group "=== REFINED PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.34;              // REFINED: 34% (vs 35% v3.2.3) slightly tighter
input double   ClosePercent       = 0.44;              // REFINED: 44% (vs 45% v3.2.3) slightly tighter
input double   OppWickPercent     = 0.56;              // REFINED: 56% (vs 55% v3.2.3) slightly more flexible
input double   VolHighMultiplier  = 1.18;              // REFINED: 1.18× (vs 1.2× v3.2.3) slightly tighter

input group "=== PROVEN SESSION FILTERING ==="
input double   MaxSpreadPips      = 15.5;              // REFINED: 15.5p (vs 15p v3.2.3) slightly more generous
input bool     UseSessionFilter   = true;              // PROVEN: Strategic session
input int      SessionStartHour   = 7;                 // PROVEN: 7:00-17:00 (exact v3.2.3)
input int      SessionEndHour     = 17;                // PROVEN: NO EOS exit (lesson learned!)
input bool     UseBlackoutTimes   = true;              // PROVEN: Keep rollover blackout
input int      BlackoutStartHour  = 23;                
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 
input int      BlackoutEndMin     = 10;
input bool     UseMomentumFilter  = true;              // NEW: Quality filter only
input double   MomentumThresholdPips = 6.0;            // REFINED: 6p momentum for quality

input group "=== PROVEN BIG WINNER EXITS ==="
input double   FixedSLPips        = 25.0;              // PROVEN: 25p SL (exact v3.2.3)
input bool     UseEarlyBreakeven  = true;              // PROVEN: Early protection
input double   EarlyBEPips        = 30.0;              // PROVEN: 30p BE (exact v3.2.3)
input bool     UsePartialTP       = false;             // PROVEN: No partial TP (exact v3.2.3)
input bool     UseTrailing        = true;              // PROVEN: Let winners run
input double   TrailStartPips     = 50.0;              // PROVEN: 50p trail start (exact v3.2.3)
input double   TrailStepPips      = 25.0;              // PROVEN: 25p steps (exact v3.2.3)

input group "=== PROVEN TIME MANAGEMENT ==="
input bool     UseTimeBasedExit   = true;              // PROVEN: Time management
input int      MaxHoldingHours    = 12;                // PROVEN: 12h max (exact v3.2.3)
input int      MinProfitForHold   = 10;                // PROVEN: 10p profit (exact v3.2.3)
// REMOVED: UseEndOfSessionExit - KILLED BIG WINNERS!

input group "=== PROVEN CIRCUIT BREAKER ==="
input bool     UseCircuitBreaker  = true;              // PROVEN: Protection
input int      MaxConsecutiveLosses = 8;               // PROVEN: 8 (exact v3.2.3)
input int      CooldownMinutes    = 45;                // PROVEN: 45min (exact v3.2.3)
input bool     UseHourlyReset     = true;              // KEEP: Prevents long lockouts
input int      HourlyResetInterval = 3;                // REFINED: 3h (vs 2h) less aggressive

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.5-Refined";

//=== GLOBAL VARIABLES ===
int magic_number = 32500;  // v3.2.5 magic number
ulong active_position_ticket = 0;
int bars_since_entry = 0;
datetime entry_time = 0;
int last_signal_bar = -1;
int last_trade_bar = -1;
double original_entry_price = 0.0;
double pip_size = 0.0;
bool breakeven_activated = false;
bool trailing_activated = false;
double remaining_volume = 0.0;
int signal_count = 0;
int trade_count = 0;

// Proven circuit breaker
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;
datetime last_hourly_reset = 0;

//=== HELPER FUNCTIONS ===
double Pip() 
{
   if(StringFind(Symbol(), "XAU") >= 0) return 0.01;  
   double pt = Point();
   int d = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   if(d == 5 || d == 3) return 10 * pt;
   return pt;
}

double PriceFromPips(double pips) 
{
   return pips * Pip();
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

double CalculateProfitPips(double entry_price, double current_price, bool is_long)
{
   if(entry_price <= 0 || current_price <= 0) return 0;
   
   double profit_pips = is_long ? 
                       (current_price - entry_price) / Pip() :
                       (entry_price - current_price) / Pip();
   
   return profit_pips;
}

//=== INITIALIZATION ===
int OnInit() 
{
   pip_size = Pip();
   last_hourly_reset = TimeCurrent();
   
   Print("🎯 PTG REFINED v3.2.5 - BACK TO v3.2.3 SUCCESS + STRATEGIC QUALITY!");
   Print("📊 REFINED Push: Range=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("⏰ PROVEN Session: ", SessionStartHour, "-", SessionEndHour, " | Spread=", MaxSpreadPips, "p | Momentum=", (UseMomentumFilter ? DoubleToString(MomentumThresholdPips, 1) + "p" : "OFF"));
   Print("🌟 PROVEN Exits: SL=", FixedSLPips, "p | BE=", EarlyBEPips, "p | Trail=", TrailStartPips, "p");
   Print("⏰ PROVEN Time: Max=", MaxHoldingHours, "h | MinProfit=", MinProfitForHold, "p | NO EOS EXIT!");
   Print("🔴 PROVEN Breaker: ", MaxConsecutiveLosses, " losses → ", CooldownMinutes, "min | Reset=", HourlyResetInterval, "h");
   Print("🎯 REFINED PHILOSOPHY: Keep v3.2.3 success formula + add ONLY strategic quality control!");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // Proven hourly reset (less aggressive)
   if(UseHourlyReset && TimeCurrent() >= last_hourly_reset + HourlyResetInterval * 3600)
   {
      consecutive_losses = 0;
      last_hourly_reset = TimeCurrent();
      if(EnableDebugLogs)
         Print("🔄 REFINED RESET: Consecutive losses reset to 0");
   }
   
   // Proven filtering (exact v3.2.3 + momentum only)
   if(!IsRefinedMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseSessionFilter && !IsInTradingSession()) return;
   if(UseCircuitBreaker && IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageRefinedPosition();
      bars_since_entry++;
      return;
   }
   
   CheckRefinedPTGSignals();
}

//=== REFINED FILTERING ===
bool IsRefinedMarketOK() 
{
   // Slightly more generous spread (vs v3.2.3)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   return true;
}

bool IsInTradingSession()
{
   // PROVEN: Exact same as v3.2.3
   if(!UseSessionFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   bool in_session = (dt.hour >= SessionStartHour && dt.hour < SessionEndHour);
   
   if(!in_session && EnableDebugLogs && signal_count % 1000 == 0)
      Print("💤 OUT OF SESSION: ", IntegerToString(dt.hour), ":00 (", SessionStartHour, "-", SessionEndHour, ")");
   
   return in_session;
}

bool IsInBlackoutPeriod()
{
   // PROVEN: Exact same as v3.2.3
   if(!UseBlackoutTimes) return false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   bool in_blackout = false;
   
   if(BlackoutStartHour == 23 && BlackoutEndHour == 0)
   {
      if((dt.hour == BlackoutStartHour && dt.min >= BlackoutStartMin) ||
         (dt.hour == BlackoutEndHour && dt.min <= BlackoutEndMin))
      {
         in_blackout = true;
      }
   }
   
   return in_blackout;
}

//=== PROVEN CIRCUIT BREAKER ===
bool IsInCircuitBreaker()
{
   // PROVEN: Exact same as v3.2.3
   if(!UseCircuitBreaker) return false;
   
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 CIRCUIT BREAKER: Active until ", TimeToString(circuit_breaker_until));
      return true;
   }
   
   return false;
}

void ActivateCircuitBreaker()
{
   if(UseCircuitBreaker && consecutive_losses >= MaxConsecutiveLosses)
   {
      circuit_breaker_until = TimeCurrent() + CooldownMinutes * 60;
      
      if(EnableDebugLogs)
         Print("🔴 REFINED BREAKER ACTIVATED: ", consecutive_losses, " losses | Cooldown ", 
               CooldownMinutes, "min until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0;
   }
}

//=== REFINED PTG SIGNALS ===
void CheckRefinedPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsRefinedPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 400 == 0)
         Print("🎯 REFINED PUSH #", signal_count, " detected");
      
      CheckRefinedTestAndGo();
   }
}

bool IsRefinedPushDetected() 
{
   if(Bars(Symbol(), PERIOD_CURRENT) < LookbackPeriod + 2) return false;
   
   double high[], low[], close[];
   long volume[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, high) <= 0) return false;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, low) <= 0) return false;
   if(CopyClose(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, close) <= 0) return false;
   if(CopyTickVolume(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, volume) <= 0) return false;
   
   double current_range = high[0] - low[0];
   
   double avg_range = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_range += (high[i] - low[i]);
   avg_range /= LookbackPeriod;
   
   double avg_volume = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_volume += (double)volume[i];
   avg_volume /= LookbackPeriod;
   
   // REFINED PTG criteria (slightly tighter than v3.2.3 for better quality)
   bool range_criteria = current_range >= avg_range * PushRangePercent;
   bool volume_criteria = (double)volume[0] >= avg_volume * VolHighMultiplier;
   
   double close_position = (close[0] - low[0]) / current_range;
   bool bullish_push = close_position >= ClosePercent;
   bool bearish_push = close_position <= (1.0 - ClosePercent);
   
   double upper_wick = high[0] - MathMax(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1));
   double lower_wick = MathMin(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1)) - low[0];
   
   bool opp_wick_ok = false;
   if(bullish_push) opp_wick_ok = (upper_wick / current_range) <= OppWickPercent;
   if(bearish_push) opp_wick_ok = (lower_wick / current_range) <= OppWickPercent;
   
   // REFINED: Strategic momentum filter for quality
   bool momentum_ok = true;
   if(UseMomentumFilter)
   {
      double momentum_pips = MathAbs(close[0] - close[1]) / Pip();
      momentum_ok = momentum_pips >= MomentumThresholdPips;
   }
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok && momentum_ok;
}

void CheckRefinedTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteRefinedEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== REFINED TRADE EXECUTION ===
void ExecuteRefinedEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double current_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double sl_price = is_long ? 
                     current_price - PriceFromPips(FixedSLPips) :
                     current_price + PriceFromPips(FixedSLPips);
   
   current_price = NormalizePrice(current_price);
   sl_price = NormalizePrice(sl_price);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.volume = FixedLotSize;
   req.type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = current_price;
   req.sl = sl_price;
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "PTG Refined v3.2.5";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ REFINED ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG Refined ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ REFINED ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== PROVEN POSITION MANAGEMENT (exact v3.2.3) ===
void UpdatePositionInfo() 
{
   active_position_ticket = 0;
   
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) 
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number) 
         {
            active_position_ticket = ticket;
            remaining_volume = PositionGetDouble(POSITION_VOLUME);
            break;
         }
      }
   }
}

void ManageRefinedPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // REMOVED: End of session exit - LET BIG WINNERS RUN!
   
   // PROVEN: Same time management as v3.2.3
   if(UseTimeBasedExit)
   {
      int holding_hours = (int)((TimeCurrent() - entry_time) / 3600);
      if(holding_hours >= MaxHoldingHours)
      {
         if(profit_pips >= MinProfitForHold)
         {
            CloseRefinedPosition("Refined time exit - " + IntegerToString(holding_hours) + "h");
            return;
         }
      }
   }
   
   // PROVEN: Same breakeven as v3.2.3
   if(UseEarlyBreakeven && !breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToRefinedBreakeven();
      return;
   }
   
   // PROVEN: Same trailing as v3.2.3
   if(UseTrailing && !trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("🎯 REFINED TRAILING ACTIVATED: Profit ", DoubleToString(profit_pips, 1), "p >= ", TrailStartPips, "p");
   }
   
   if(UseTrailing && trailing_activated && profit_pips >= TrailStartPips) 
   {
      TrailRefinedStopLoss(profit_pips);
   }
}

void MoveToRefinedBreakeven() 
{
   // PROVEN: Exact same as v3.2.3
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(3.0)) :
                     (original_entry_price - spread - PriceFromPips(3.0));
   
   be_price = NormalizePrice(be_price);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_SLTP;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.sl = be_price;
   req.tp = PositionGetDouble(POSITION_TP);
   
   if(OrderSend(req, res)) 
   {
      breakeven_activated = true;
      if(EnableDebugLogs)
         Print("🛡️ REFINED BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(EarlyBEPips, 1), "p trigger)");
   }
}

void TrailRefinedStopLoss(double profit_pips) 
{
   // PROVEN: Exact same as v3.2.3
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   double min_improvement = PriceFromPips(8.0);
   if((is_long && new_sl > current_sl + min_improvement) || 
      (!is_long && new_sl < current_sl - min_improvement)) 
   {
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      
      req.action = TRADE_ACTION_SLTP;
      req.symbol = Symbol();
      req.position = active_position_ticket;
      req.sl = new_sl;
      req.tp = PositionGetDouble(POSITION_TP);
      
      if(OrderSend(req, res) && EnableDebugLogs) 
      {
         Print("📈 REFINED TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(TrailStepPips, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

void CloseRefinedPosition(string reason) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.volume = PositionGetDouble(POSITION_VOLUME);
   req.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.magic = magic_number;
   req.comment = reason;
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      ResetTradeState();
      if(EnableDebugLogs)
         Print("🔚 REFINED CLOSE: ", reason);
   }
}

//=== UTILITY FUNCTIONS ===
void ResetTradeState() 
{
   active_position_ticket = 0;
   bars_since_entry = 0;
   entry_time = 0;
   original_entry_price = 0.0;
   breakeven_activated = false;
   trailing_activated = false;
   remaining_volume = 0.0;
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result) 
{
   if(trans.symbol != Symbol() || request.magic != magic_number) return;
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) 
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) 
      {
         if((trans.deal_type == DEAL_TYPE_BUY && request.type == ORDER_TYPE_BUY) ||
            (trans.deal_type == DEAL_TYPE_SELL && request.type == ORDER_TYPE_SELL)) 
         {
            // Entry
            active_position_ticket = trans.position;
            original_entry_price = trans.price;
            bars_since_entry = 0;
            entry_time = TimeCurrent();
            breakeven_activated = false;
            trailing_activated = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 REFINED FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - proven loss tracking
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // PROVEN: Same loss tracking as v3.2.3
               if(profit_pips < -2.0)
               {
                  consecutive_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 5.0)
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 REFINED EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Consecutive losses: ", consecutive_losses);
            
            if(active_position_ticket == trans.position && trans.volume >= remaining_volume) 
            {
               ResetTradeState();
            }
         }
      }
   }
}

void OnDeinit(const int reason) 
{
   Print("🎯 PTG REFINED v3.2.5 STOPPED - BACK TO v3.2.3 SUCCESS + STRATEGIC QUALITY COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("🎯 REFINED PHILOSOPHY: Keep proven success + add ONLY strategic quality improvements!");
}
