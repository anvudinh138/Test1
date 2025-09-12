//+------------------------------------------------------------------+
//|                    PTG NATURAL v3.2.1                           |
//|          Fixed Profit Calc + Let Winners Run Strategy           |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.21"
#property description "PTG v3.2.1 - NATURAL: Fixed Profit Calc + Let Winners Run"

//=== NATURAL INPUTS (Let Winners Run Philosophy) ===
input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== PROVEN PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // PROVEN: 35% (from v3.2.0 success)
input double   ClosePercent       = 0.45;              // PROVEN: 45% (from v3.2.0 success)
input double   OppWickPercent     = 0.55;              // PROVEN: 55% (from v3.2.0 success)
input double   VolHighMultiplier  = 1.2;               // PROVEN: 1.2× (from v3.2.0 success)

input group "=== ESSENTIAL FILTERING ONLY ==="
input double   MaxSpreadPips      = 15.0;              // PROVEN: 15p (generous for Gold)
input bool     UseBlackoutTimes   = true;              // Keep rollover blackout
input int      BlackoutStartHour  = 23;                // 23:50 server time
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 // 00:10 server time  
input int      BlackoutEndMin     = 10;

input group "=== NATURAL EXITS (Let Winners Run) ==="
input double   FixedSLPips        = 25.0;              // PROVEN: 25p SL
input bool     UseEarlyBreakeven  = true;              // Early protection
input double   EarlyBEPips        = 30.0;              // NATURAL: 30p BE (later than 15p)
input bool     UsePartialTP       = false;             // NATURAL: No partial TP - let it run!
input bool     UseTrailing        = true;              // NATURAL: Simple trailing only
input double   TrailStartPips     = 50.0;              // NATURAL: Start trail at 50p (much later)
input double   TrailStepPips      = 25.0;              // NATURAL: 25p steps (wider)

input group "=== NATURAL TIME MANAGEMENT ==="
input bool     UseTimeBasedExit   = true;              // NATURAL: Time-based exit
input int      MaxHoldingHours    = 12;                // NATURAL: Max 12 hours holding
input int      MinProfitForHold   = 10;                // NATURAL: Need 10p profit to hold long

input group "=== SIMPLE CIRCUIT BREAKER ==="
input bool     UseCircuitBreaker  = true;              // Simple circuit breaker
input int      MaxConsecutiveLosses = 8;               // PROVEN: 8 losses
input int      CooldownMinutes    = 45;                // PROVEN: 45min cooldown

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.1-Natural";

//=== GLOBAL VARIABLES ===
int magic_number = 32100;  // v3.2.1 magic number
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

// Simple circuit breaker
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;

//=== HELPER FUNCTIONS ===
double Pip() 
{
   if(StringFind(Symbol(), "XAU") >= 0) return 0.01;  // Gold = 0.01
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

// FIXED: Proper profit calculation
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
   
   Print("🌿 PTG NATURAL v3.2.1 - FIXED PROFIT CALC + LET WINNERS RUN!");
   Print("📊 Gold M1 Natural: Push=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("💰 Simple Filters: Spread=", MaxSpreadPips, "p | Blackout=", (UseBlackoutTimes ? "ON" : "OFF"));
   Print("🌿 Natural Exits: BE=", (UseEarlyBreakeven ? DoubleToString(EarlyBEPips, 0) + "p" : "OFF"), 
         " | Partial=", (UsePartialTP ? "ON" : "OFF"), " | Trail=", (UseTrailing ? DoubleToString(TrailStartPips, 0) + "p" : "OFF"));
   Print("⏰ Time Management: Max=", MaxHoldingHours, "h | MinProfit=", MinProfitForHold, "p");
   Print("🔴 Simple Breaker: ", MaxConsecutiveLosses, " consecutive losses → ", CooldownMinutes, "min cooldown");
   Print("🎯 NATURAL PHILOSOPHY: Let good signals run naturally with minimal interference");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // Essential filtering only
   if(!IsBasicMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseCircuitBreaker && IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageNaturalPosition();
      bars_since_entry++;
      return;
   }
   
   CheckNaturalPTGSignals();
}

//=== BASIC FILTERING SYSTEM ===
bool IsBasicMarketOK() 
{
   // Simple spread check (generous)
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

bool IsInBlackoutPeriod()
{
   if(!UseBlackoutTimes) return false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Handle rollover period 23:50-00:10
   bool in_blackout = false;
   
   if(BlackoutStartHour == 23 && BlackoutEndHour == 0) // Cross midnight
   {
      if((dt.hour == BlackoutStartHour && dt.min >= BlackoutStartMin) ||
         (dt.hour == BlackoutEndHour && dt.min <= BlackoutEndMin))
      {
         in_blackout = true;
      }
   }
   
   if(in_blackout && EnableDebugLogs && signal_count % 1000 == 0)
      Print("🌙 BLACKOUT: ", IntegerToString(dt.hour), ":", IntegerToString(dt.min));
   
   return in_blackout;
}

//=== SIMPLE CIRCUIT BREAKER ===
bool IsInCircuitBreaker()
{
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
         Print("🔴 CIRCUIT BREAKER ACTIVATED: ", consecutive_losses, " losses | Cooldown ", 
               CooldownMinutes, "min until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0; // Reset
   }
}

//=== NATURAL PTG SIGNALS ===
void CheckNaturalPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsNaturalPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔥 NATURAL PUSH #", signal_count, " detected");
      
      CheckNaturalTestAndGo();
   }
}

bool IsNaturalPushDetected() 
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
   
   // NATURAL PTG criteria (proven working)
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
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok;
}

void CheckNaturalTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteNaturalEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== NATURAL TRADE EXECUTION ===
void ExecuteNaturalEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double current_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double sl_price = is_long ? 
                     current_price - PriceFromPips(FixedSLPips) :
                     current_price + PriceFromPips(FixedSLPips);
   
   // Proper normalization
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
   req.comment = "PTG Natural v3.2.1";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ NATURAL ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG Natural ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ NATURAL ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== NATURAL POSITION MANAGEMENT (FIXED & SIMPLIFIED) ===
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

void ManageNaturalPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // FIXED: Use helper function for profit calculation
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // Natural time-based exit
   if(UseTimeBasedExit)
   {
      int holding_hours = (int)((TimeCurrent() - entry_time) / 3600);
      if(holding_hours >= MaxHoldingHours)
      {
         if(profit_pips >= MinProfitForHold)
         {
            CloseNaturalPosition("Natural time exit - holding " + IntegerToString(holding_hours) + "h");
            return;
         }
      }
   }
   
   // Natural early breakeven (minimal interference)
   if(UseEarlyBreakeven && !breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToNaturalBreakeven();
      return;
   }
   
   // Natural trailing (let big winners run)
   if(UseTrailing && !trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("🌿 NATURAL TRAILING ACTIVATED: Profit ", DoubleToString(profit_pips, 1), "p >= ", TrailStartPips, "p");
   }
   
   if(UseTrailing && trailing_activated && profit_pips >= TrailStartPips) 
   {
      TrailNaturalStopLoss(profit_pips);
   }
}

void MoveToNaturalBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Natural breakeven (simple + buffer)
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
         Print("🛡️ NATURAL BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(EarlyBEPips, 1), "p trigger)");
   }
}

void TrailNaturalStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Natural trailing: wide steps to let winners run
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move if significant improvement (wider than usual)
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
         Print("📈 NATURAL TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(TrailStepPips, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

void CloseNaturalPosition(string reason) 
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
         Print("🔚 NATURAL CLOSE: ", reason);
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
         // Entry
         if((trans.deal_type == DEAL_TYPE_BUY && request.type == ORDER_TYPE_BUY) ||
            (trans.deal_type == DEAL_TYPE_SELL && request.type == ORDER_TYPE_SELL)) 
         {
            active_position_ticket = trans.position;
            original_entry_price = trans.price;
            bars_since_entry = 0;
            entry_time = TimeCurrent();
            breakeven_activated = false;
            trailing_activated = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 NATURAL FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - track losses for circuit breaker
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // Update loss tracking (simple)
               if(profit_pips < -2.0) // Consider < -2 pip as loss
               {
                  consecutive_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 5.0) // Reset on good profit
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 NATURAL EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
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
   Print("🌿 PTG NATURAL v3.2.1 STOPPED - FIXED PROFIT CALC + LET WINNERS RUN COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("🎯 NATURAL PHILOSOPHY: Good signals + minimal interference = natural profits!");
}
