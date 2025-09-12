//+------------------------------------------------------------------+
//|                    PTG ENHANCED v3.2.2                          |
//|          Optimized for More Frequent Big Winners                |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.22"
#property description "PTG v3.2.2 - ENHANCED: More frequent quality signals + big winner exits"

//=== ENHANCED INPUTS (More Big Winners) ===
input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 12;                // ENHANCED: 12 (vs 10) for better context

input group "=== OPTIMIZED PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.32;              // ENHANCED: 32% (vs 35%) for more signals
input double   ClosePercent       = 0.42;              // ENHANCED: 42% (vs 45%) for more signals
input double   OppWickPercent     = 0.58;              // ENHANCED: 58% (vs 55%) for more flexibility
input double   VolHighMultiplier  = 1.15;              // ENHANCED: 1.15× (vs 1.2×) for more signals

input group "=== SMART FILTERING ==="
input double   MaxSpreadPips      = 14.5;              // ENHANCED: 14.5p (vs 15p) for better spread tolerance
input bool     UseSessionFilter   = true;              // ENHANCED: Add session filtering
input int      SessionStartHour   = 8;                 // London session start
input int      SessionEndHour     = 16;                // NY session overlap end
input bool     UseBlackoutTimes   = true;              // Keep rollover blackout
input int      BlackoutStartHour  = 23;                
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 
input int      BlackoutEndMin     = 10;
input bool     UseVolatilityFilter = true;             // ENHANCED: ATR-based volatility filter
input double   MinATRPips         = 8.0;               // Minimum ATR for trading
input double   MaxATRPips         = 45.0;              // Maximum ATR for trading

input group "=== BIG WINNER EXITS ==="
input double   FixedSLPips        = 22.0;              // ENHANCED: 22p SL (tighter for better R:R)
input bool     UseEarlyBreakeven  = true;              
input double   EarlyBEPips        = 35.0;              // ENHANCED: 35p BE (later to give room)
input bool     UsePartialTP       = false;             // Keep: No partial TP
input bool     UseTrailing        = true;              
input double   TrailStartPips     = 45.0;              // ENHANCED: 45p start (vs 50p)
input double   TrailStepPips      = 20.0;              // ENHANCED: 20p steps (tighter trailing)
input bool     UseDynamicTrail    = true;              // ENHANCED: ATR-based dynamic trailing
input double   TrailATRMultiplier = 2.5;               // Dynamic trail based on ATR

input group "=== ENHANCED TIME MANAGEMENT ==="
input bool     UseTimeBasedExit   = true;              
input int      MaxHoldingHours    = 8;                 // ENHANCED: 8h max (vs 12h) for more active management
input int      MinProfitForHold   = 12;                // ENHANCED: 12p min (vs 10p) for better quality
input bool     UseEndOfDayExit    = true;              // ENHANCED: Close positions at day end
input int      EODExitHour        = 22;                // Close at 22:00 server time

input group "=== SMART CIRCUIT BREAKER ==="
input bool     UseCircuitBreaker  = true;              
input int      MaxConsecutiveLosses = 6;               // ENHANCED: 6 losses (vs 8) for faster brake
input int      CooldownMinutes    = 30;                // ENHANCED: 30min (vs 45min) for faster recovery
input bool     UseHourlyLossLimit = true;              // ENHANCED: Hourly loss limit
input int      MaxLossesPerHour   = 4;                 // Max 4 losses per hour

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.2-Enhanced";

//=== GLOBAL VARIABLES ===
int magic_number = 32200;  // v3.2.2 magic number
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

// Enhanced circuit breaker
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;
int hourly_losses = 0;
datetime hourly_reset_time = 0;

// ATR for dynamic features
int atr_handle = INVALID_HANDLE;
double current_atr_pips = 0.0;

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
   
   // Initialize ATR for dynamic features
   atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   Print("🚀 PTG ENHANCED v3.2.2 - OPTIMIZED FOR MORE BIG WINNERS!");
   Print("📊 Enhanced Push: Range=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("🎯 Smart Filters: Spread=", MaxSpreadPips, "p | Session=", (UseSessionFilter ? "ON" : "OFF"), " | ATR=", (UseVolatilityFilter ? "ON" : "OFF"));
   Print("💰 Big Winner Exits: BE=", EarlyBEPips, "p | Trail=", TrailStartPips, "p | Dynamic=", (UseDynamicTrail ? "ON" : "OFF"));
   Print("⏰ Enhanced Time: Max=", MaxHoldingHours, "h | EOD=", (UseEndOfDayExit ? IntegerToString(EODExitHour) + ":00" : "OFF"));
   Print("🔴 Smart Breaker: ", MaxConsecutiveLosses, " consecutive | ", MaxLossesPerHour, "/hour | ", CooldownMinutes, "min cooldown");
   Print("🎯 ENHANCED PHILOSOPHY: More frequent quality signals with proven big winner exits");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   UpdateATR();
   
   if(!IsEnhancedMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseSessionFilter && !IsInTradingSession()) return;
   if(UseCircuitBreaker && IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageEnhancedPosition();
      bars_since_entry++;
      return;
   }
   
   CheckEnhancedPTGSignals();
}

//=== ENHANCED FILTERING SYSTEM ===
void UpdateATR()
{
   if(atr_handle == INVALID_HANDLE) return;
   
   double atr_buffer[1];
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
   {
      current_atr_pips = atr_buffer[0] / Pip();
   }
}

bool IsEnhancedMarketOK() 
{
   // Enhanced spread check
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   // Enhanced volatility filter
   if(UseVolatilityFilter && current_atr_pips > 0)
   {
      if(current_atr_pips < MinATRPips || current_atr_pips > MaxATRPips)
      {
         if(EnableDebugLogs && signal_count % 1000 == 0)
            Print("⚠️ ATR OUT OF RANGE: ", DoubleToString(current_atr_pips, 1), "p (", MinATRPips, "-", MaxATRPips, ")");
         return false;
      }
   }
   
   return true;
}

bool IsInTradingSession()
{
   if(!UseSessionFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Enhanced session filter (London + NY overlap)
   bool in_session = (dt.hour >= SessionStartHour && dt.hour < SessionEndHour);
   
   if(!in_session && EnableDebugLogs && signal_count % 1000 == 0)
      Print("💤 OUT OF SESSION: ", IntegerToString(dt.hour), ":00 (", SessionStartHour, "-", SessionEndHour, ")");
   
   return in_session;
}

bool IsInBlackoutPeriod()
{
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

//=== ENHANCED CIRCUIT BREAKER ===
bool IsInCircuitBreaker()
{
   if(!UseCircuitBreaker) return false;
   
   // Reset hourly counter
   if(UseHourlyLossLimit && TimeCurrent() >= hourly_reset_time)
   {
      hourly_losses = 0;
      hourly_reset_time = TimeCurrent() + 3600; // Next hour
   }
   
   // Check hourly limit
   if(UseHourlyLossLimit && hourly_losses >= MaxLossesPerHour)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 HOURLY LIMIT: ", hourly_losses, " losses this hour");
      return true;
   }
   
   // Check consecutive losses cooldown
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
      
      consecutive_losses = 0;
   }
}

//=== ENHANCED PTG SIGNALS ===
void CheckEnhancedPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsEnhancedPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 300 == 0)
         Print("🚀 ENHANCED PUSH #", signal_count, " | ATR: ", DoubleToString(current_atr_pips, 1), "p");
      
      CheckEnhancedTestAndGo();
   }
}

bool IsEnhancedPushDetected() 
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
   
   // Enhanced context calculation
   double avg_range = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_range += (high[i] - low[i]);
   avg_range /= LookbackPeriod;
   
   double avg_volume = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_volume += (double)volume[i];
   avg_volume /= LookbackPeriod;
   
   // ENHANCED PTG criteria (more relaxed for more signals)
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

void CheckEnhancedTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteEnhancedEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== ENHANCED TRADE EXECUTION ===
void ExecuteEnhancedEntry(bool is_long) 
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
   req.comment = "PTG Enhanced v3.2.2";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ ENHANCED ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5), " | ATR: ", DoubleToString(current_atr_pips, 1), "p");
      
      if(EnableAlerts)
         Alert("PTG Enhanced ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ ENHANCED ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== ENHANCED POSITION MANAGEMENT ===
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

void ManageEnhancedPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // Enhanced end-of-day exit
   if(UseEndOfDayExit)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= EODExitHour)
      {
         CloseEnhancedPosition("Enhanced EOD exit - " + IntegerToString(dt.hour) + ":00");
         return;
      }
   }
   
   // Enhanced time-based exit
   if(UseTimeBasedExit)
   {
      int holding_hours = (int)((TimeCurrent() - entry_time) / 3600);
      if(holding_hours >= MaxHoldingHours)
      {
         if(profit_pips >= MinProfitForHold)
         {
            CloseEnhancedPosition("Enhanced time exit - " + IntegerToString(holding_hours) + "h");
            return;
         }
      }
   }
   
   // Enhanced breakeven
   if(UseEarlyBreakeven && !breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToEnhancedBreakeven();
      return;
   }
   
   // Enhanced trailing
   if(UseTrailing && profit_pips >= TrailStartPips) 
   {
      if(!trailing_activated)
      {
         trailing_activated = true;
         if(EnableDebugLogs)
            Print("🚀 ENHANCED TRAILING ACTIVATED: Profit ", DoubleToString(profit_pips, 1), "p >= ", TrailStartPips, "p");
      }
      
      TrailEnhancedStopLoss(profit_pips);
   }
}

void MoveToEnhancedBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_buffer = PriceFromPips(5.0); // Enhanced 5p buffer
   
   double be_price = is_long ? 
                     (original_entry_price + spread + be_buffer) :
                     (original_entry_price - spread - be_buffer);
   
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
         Print("🛡️ ENHANCED BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(EarlyBEPips, 1), "p trigger)");
   }
}

void TrailEnhancedStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Enhanced dynamic trailing based on ATR
   double trail_step = UseDynamicTrail && current_atr_pips > 0 ? 
                      MathMax(TrailStepPips, current_atr_pips * TrailATRMultiplier) :
                      TrailStepPips;
   
   double trail_distance = profit_pips - trail_step;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Enhanced improvement threshold
   double min_improvement = PriceFromPips(UseDynamicTrail ? MathMax(6.0, current_atr_pips * 0.5) : 6.0);
   
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
         Print("📈 ENHANCED TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(trail_step, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

void CloseEnhancedPosition(string reason) 
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
         Print("🔚 ENHANCED CLOSE: ", reason);
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
               Print("🎯 ENHANCED FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - enhanced loss tracking
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // Enhanced loss tracking
               if(profit_pips < -3.0) 
               {
                  consecutive_losses++;
                  hourly_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 8.0) 
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 ENHANCED EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Losses: ", consecutive_losses, " consecutive, ", hourly_losses, " hourly");
            
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
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   
   Print("🚀 PTG ENHANCED v3.2.2 STOPPED - MORE FREQUENT BIG WINNERS COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Losses: ", consecutive_losses, " consecutive | ", hourly_losses, " hourly");
   Print("🎯 ENHANCED PHILOSOPHY: Optimized frequency + proven big winner strategy!");
}
