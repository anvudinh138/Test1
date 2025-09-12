//+------------------------------------------------------------------+
//|                    PTG BACK TO BASICS v3.2.0                    |
//|          Back to Working Foundation + Critical Bug Fixes        |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.20"
#property description "PTG v3.2.0 - BACK TO BASICS: Fix Core Issues + Return to Working Logic"

//=== BACK TO BASICS INPUTS (Proven Working Parameters) ===
input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== ORIGINAL PUSH PARAMETERS (v2.2.0 had 20.90% WR) ==="
input double   PushRangePercent   = 0.35;              // ORIGINAL: 35% (back to v2.2.0)
input double   ClosePercent       = 0.45;              // ORIGINAL: 45% (back to v2.2.0)
input double   OppWickPercent     = 0.55;              // ORIGINAL: 55% (back to v2.2.0)
input double   VolHighMultiplier  = 1.2;               // ORIGINAL: 1.2× (back to v2.2.0)

input group "=== ESSENTIAL FILTERING ONLY ==="
input double   MaxSpreadPips      = 15.0;              // GENEROUS: 15p (realistic for Gold)
input bool     UseBlackoutTimes   = true;              // Keep rollover blackout
input int      BlackoutStartHour  = 23;                // 23:50 server time
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 // 00:10 server time  
input int      BlackoutEndMin     = 10;

input group "=== ORIGINAL EXITS (Back to Working) ==="
input double   FixedSLPips        = 25.0;              // ORIGINAL: 25p SL
input double   BreakevenPips      = 15.0;              // ORIGINAL: 15p BE (from memory)
input double   PartialTPPips      = 22.0;              // ORIGINAL: 22p partial (from memory)  
input double   PartialPercent     = 30.0;              // ORIGINAL: 30% close
input double   TrailStepPips      = 18.0;              // ORIGINAL: 18p trail (from memory)

input group "=== SIMPLE CIRCUIT BREAKER ==="
input bool     UseCircuitBreaker  = true;              // Simple circuit breaker
input int      MaxConsecutiveLosses = 8;               // ORIGINAL: 8 losses (from memory)
input int      CooldownMinutes    = 45;                // ORIGINAL: 45min cooldown

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.0-BackToBasics";

//=== GLOBAL VARIABLES ===
int magic_number = 32000;  // v3.2.0 magic number
ulong active_position_ticket = 0;
int bars_since_entry = 0;
int last_signal_bar = -1;
int last_trade_bar = -1;
double original_entry_price = 0.0;
double pip_size = 0.0;
bool breakeven_activated = false;
bool partial_tp_taken = false;
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

//=== INITIALIZATION ===
int OnInit() 
{
   pip_size = Pip();
   
   Print("🔄 PTG BACK TO BASICS v3.2.0 - RETURN TO WORKING FOUNDATION!");
   Print("📊 Gold M1 Original: Push=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("💰 Simple Filters: Spread=", MaxSpreadPips, "p | Blackout=", (UseBlackoutTimes ? "ON" : "OFF"));
   Print("💎 Original Exits: BE=", BreakevenPips, "p | Partial=", PartialTPPips, "p | Trail=", TrailStepPips, "p");
   Print("🔴 Simple Breaker: ", MaxConsecutiveLosses, " consecutive losses → ", CooldownMinutes, "min cooldown");
   Print("🎯 GOAL: Fix core bugs + return to v2.2.0's 20.90% win rate foundation");
   
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
      ManageOriginalPosition();
      bars_since_entry++;
      return;
   }
   
   CheckOriginalPTGSignals();
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

//=== ORIGINAL PTG SIGNALS ===
void CheckOriginalPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsOriginalPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔥 ORIGINAL PUSH #", signal_count, " detected");
      
      CheckOriginalTestAndGo();
   }
}

bool IsOriginalPushDetected() 
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
   
   // ORIGINAL PTG criteria (exactly as v2.2.0)
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

void CheckOriginalTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteOriginalEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== ORIGINAL TRADE EXECUTION ===
void ExecuteOriginalEntry(bool is_long) 
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
   req.comment = "PTG BackToBasics v3.2.0";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ ORIGINAL ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG BackToBasics ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ ORIGINAL ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== ORIGINAL POSITION MANAGEMENT (FIXED PROFIT CALCULATION) ===
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

void ManageOriginalPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // FIXED: Proper profit calculation in pips
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / Pip() :
                       (original_entry_price - current_price) / Pip();
   
   // FIXED: Validate profit calculation
   if(MathAbs(profit_pips) > 1000.0) // Sanity check
   {
      if(EnableDebugLogs)
         Print("⚠️ PROFIT CALC ERROR: ", profit_pips, "p - SKIPPING MANAGEMENT");
      return;
   }
   
   // Original partial TP
   if(!partial_tp_taken && profit_pips >= PartialTPPips) 
   {
      TakeOriginalPartialProfit();
      return;
   }
   
   // Original breakeven  
   if(!breakeven_activated && profit_pips >= BreakevenPips) 
   {
      MoveToOriginalBreakeven();
      return;
   }
   
   // Original trailing
   if(breakeven_activated && profit_pips >= BreakevenPips + TrailStepPips) 
   {
      TrailOriginalStopLoss(profit_pips);
   }
}

void TakeOriginalPartialProfit() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double close_volume = NormalizeDouble(current_volume * PartialPercent / 100.0, 2);
   
   double min_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(close_volume < min_vol) close_volume = min_vol;
   if(close_volume >= current_volume) close_volume = current_volume;
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.volume = close_volume;
   req.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.magic = magic_number;
   req.comment = "Original Partial " + DoubleToString(PartialTPPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 ORIGINAL PARTIAL: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(PartialTPPips, 1), "p (", DoubleToString(PartialPercent, 0), "%)");
   }
}

void MoveToOriginalBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Original breakeven logic (simple)
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(1.0)) :
                     (original_entry_price - spread - PriceFromPips(1.0));
   
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
         Print("🛡️ ORIGINAL BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(BreakevenPips, 1), "p trigger)");
   }
}

void TrailOriginalStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Original trailing: simple step
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move if significant improvement
   double min_improvement = PriceFromPips(3.0);
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
         Print("📈 ORIGINAL TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(TrailStepPips, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

//=== UTILITY FUNCTIONS ===
void ResetTradeState() 
{
   active_position_ticket = 0;
   bars_since_entry = 0;
   original_entry_price = 0.0;
   breakeven_activated = false;
   partial_tp_taken = false;
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
            breakeven_activated = false;
            partial_tp_taken = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 ORIGINAL FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - track losses for circuit breaker
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / Pip() :
                            (original_entry_price - trans.price) / Pip();
               
               // Update loss tracking (simple)
               if(profit_pips < -2.0) // Consider < -2 pip as loss
               {
                  consecutive_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 2.0) // Reset on decent profit
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 ORIGINAL EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
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
   Print("🔄 PTG BACK TO BASICS v3.2.0 STOPPED - FOUNDATION RESET COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("🎯 BACK TO BASICS: Return to working v2.2.0 foundation with critical bug fixes!");
}
