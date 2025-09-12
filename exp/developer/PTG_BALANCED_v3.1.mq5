//+------------------------------------------------------------------+
//|                    PTG BALANCED v3.1.0                          |
//|          Balanced Filters - Based on User + ChatGPT Feedback    |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.10"
#property description "PTG v3.1 - Balanced: User Logic + Selective ChatGPT Optimizations"

//=== BALANCED INPUTS (User + ChatGPT) ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA filter (keep simple)
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // Range >= 35%
input double   ClosePercent       = 0.45;              // Close position 45%
input double   OppWickPercent     = 0.55;              // Opp wick <= 55%
input double   VolHighMultiplier  = 1.2;               // Vol >= 120%

input group "=== SELECTIVE QUALITY FILTERS ==="
input bool     UseSessionFilter   = false;             // Session filter (USER: disabled by default)
input int      SessionStartHour   = 7;                 // London start (if enabled)
input int      SessionEndHour     = 17;                // NY end (if enabled)
input bool     UseSqueezeFilter   = false;             // Squeeze filter (USER: too restrictive)
input double   ATRPercentileMin   = 50.0;              // Relaxed ATR percentile (was 60%)
input bool     UseM5TrendFilter   = false;             // M5 trend (USER: PTG is M1 manipulation)

input group "=== SMART SPREAD MANAGEMENT ==="
input double   MaxSpreadPips      = 15.0;              // USER: Back to realistic Gold spread
input bool     UseDynamicSpread   = false;             // USER: Dynamic was too strict
input double   SpreadATRRatio     = 0.25;              // Relaxed ratio (was 0.15)

input group "=== BALANCED ENTRY TIMING ==="
input bool     UseStopEmulation   = true;              // Keep this - good concept
input double   StopEmulationMS    = 100.0;             // Faster (was 200ms) 
input int      MinMomentumTicks   = 1;                 // Relaxed (was 2)
input bool     UseRetestFilter    = false;             // USER: Too restrictive for M1
input bool     AvoidRoundNumbers  = true;              // Keep this - practical
input double   RoundNumberBuffer  = 8.0;               // Smaller buffer (was 12)

input group "=== OPTIMIZED POSITION MANAGEMENT ==="
input double   FixedSLPips        = 25.0;              // Keep ChatGPT value
input double   MaxRiskPips        = 35.0;              // Keep ChatGPT value
input double   BreakevenPips      = 18.0;              // ChatGPT optimized  
input bool     UseStructureBE     = false;             // USER: Too complex for M1
input double   PartialTPPips      = 19.0;              // ChatGPT: 19 pips (was 20)
input double   PartialTPPercent   = 30.0;              // 30% close
input double   TrailStepPips      = 20.0;              // ChatGPT optimized
input double   MinProfitPips      = 8.0;               // Relaxed (was 9)

input group "=== PRACTICAL RISK CONTROL ==="
input bool     UseCircuitBreaker  = true;              // Keep - practical
input int      MaxConsecutiveLosses = 8;               // More lenient (was 6)  
input int      CooldownMinutes    = 45;                // Shorter cooldown (was 60)
input bool     UseCooldownAfterSL = false;             // USER: Too restrictive
input int      TimeStopBars       = 30;                // Back to reasonable (was 25)

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.1.0-Balanced";

//=== GLOBAL VARIABLES ===
int magic_number = 31000;  // v3.1 magic number
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

// Selective indicators (only if enabled)
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;
int m5_ema_fast_handle = INVALID_HANDLE;
int m5_ema_slow_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;
double atr_history[];
datetime stop_emulation_time = 0;
double stop_emulation_price = 0.0;
bool stop_emulation_pending = false;
bool stop_emulation_is_long = false;

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
   
   // Only initialize indicators if filters are enabled
   if(UseM5TrendFilter)
   {
      m5_ema_fast_handle = iMA(Symbol(), PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
      m5_ema_slow_handle = iMA(Symbol(), PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m5_ema_fast_handle == INVALID_HANDLE || m5_ema_slow_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create M5 EMA indicators");
         return INIT_FAILED;
      }
   }
   
   if(UseSqueezeFilter)
   {
      atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
      if(atr_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create ATR indicator");  
         return INIT_FAILED;
      }
      
      // Initialize ATR history array
      ArrayResize(atr_history, 1000);
      ArrayInitialize(atr_history, 0.0);
   }
   
   Print("🎯 PTG BALANCED v3.1.0 - USER LOGIC + SELECTIVE CHATGPT!");
   Print("📊 Gold M1 Manipulation Strategy: Pip=", pip_size, " | Magic=", magic_number);
   Print("⚡ Selective Filters: Session=", UseSessionFilter, " | Squeeze=", UseSqueezeFilter, " | M5=", UseM5TrendFilter);
   Print("📈 Smart Spread: Max=", MaxSpreadPips, "p | Dynamic=", UseDynamicSpread);
   Print("🎯 Balanced Entry: StopEmu=", UseStopEmulation, " | RoundNum=", AvoidRoundNumbers);
   Print("🛡️ Position: BE=", BreakevenPips, "p | PartialTP=", PartialTPPips, "p | Trail=", TrailStepPips, "p");
   Print("🔧 Risk Control: CircuitBreaker=", UseCircuitBreaker, " (", MaxConsecutiveLosses, " losses)");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // Core market conditions (always check)
   if(!IsBasicMarketOK()) return;
   
   // Optional filters (only if enabled)
   if(UseSessionFilter && !IsSessionTimeOK()) return;
   if(UseCircuitBreaker && IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   // Handle stop emulation timing
   if(stop_emulation_pending)
   {
      HandleStopEmulation();
      return;
   }
   
   if(active_position_ticket > 0) 
   {
      ManageBalancedPosition();
      bars_since_entry++;
      return;
   }
   
   CheckBalancedPTGSignals();
}

//=== BALANCED MARKET FILTERS ===
bool IsBasicMarketOK() 
{
   // Core spread check
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   double max_spread = MaxSpreadPips;
   
   // Optional dynamic spread (if enabled and less restrictive)
   if(UseDynamicSpread && atr_handle != INVALID_HANDLE)
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
      {
         double atr_pips = atr_buffer[0] / Pip();
         double dynamic_max = atr_pips * SpreadATRRatio;
         max_spread = MathMax(MaxSpreadPips, dynamic_max); // Take the HIGHER limit
      }
   }
   
   if(current_spread > max_spread)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", DoubleToString(max_spread, 1), "p");
      return false;
   }
   
   // Skip extreme spreads (news periods)
   if(current_spread > MaxSpreadPips * 2.0) 
   {
      if(EnableDebugLogs)
         Print("🚨 EXTREME SPREAD: ", DoubleToString(current_spread, 1), "p - NEWS PERIOD");
      return false;
   }
   
   return true;
}

bool IsSessionTimeOK()
{
   if(!UseSessionFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;
   
   bool session_ok = (current_hour >= SessionStartHour && current_hour < SessionEndHour);
   
   if(!session_ok && EnableDebugLogs && signal_count % 2000 == 0)
      Print("⏰ OUTSIDE SESSION: Hour ", current_hour, " not in ", SessionStartHour, "-", SessionEndHour);
   
   return session_ok;
}

bool IsSqueezeExpansionOK()
{
   if(!UseSqueezeFilter) return true;
   // Simplified squeeze check - just basic ATR threshold
   if(atr_handle == INVALID_HANDLE) return true;
   
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0) return true;
   
   double current_atr_pips = atr_buffer[0] / Pip();
   bool squeeze_ok = current_atr_pips >= 15.0; // Simple threshold
   
   if(!squeeze_ok && EnableDebugLogs && signal_count % 1000 == 0)
      Print("📉 LOW ATR: ", DoubleToString(current_atr_pips, 1), "p < 15p threshold");
   
   return squeeze_ok;
}

bool IsM5TrendOK(bool is_bullish_signal)
{
   if(!UseM5TrendFilter) return true;
   if(m5_ema_fast_handle == INVALID_HANDLE || m5_ema_slow_handle == INVALID_HANDLE) return true;
   
   double ema_fast[], ema_slow[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   
   if(CopyBuffer(m5_ema_fast_handle, 0, 1, 1, ema_fast) <= 0) return true;
   if(CopyBuffer(m5_ema_slow_handle, 0, 1, 1, ema_slow) <= 0) return true;
   
   bool uptrend = ema_fast[0] > ema_slow[0];
   
   bool trend_ok = true;
   if(is_bullish_signal) trend_ok = uptrend;
   else trend_ok = !uptrend;
   
   if(!trend_ok && EnableDebugLogs && signal_count % 500 == 0)
      Print("📊 M5 TREND CONFLICT: Signal=", (is_bullish_signal ? "BULL" : "BEAR"), 
            " | Trend=", (uptrend ? "UP" : "DOWN"));
   
   return trend_ok;
}

//=== CIRCUIT BREAKER (SIMPLIFIED) ===
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
         Print("🔴 CIRCUIT BREAKER: ", consecutive_losses, " losses | Cooldown ", 
               CooldownMinutes, "m until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0; // Reset
   }
}

//=== ROUND NUMBER FILTER (PRACTICAL) ===
bool IsNearRoundNumber(double price)
{
   if(!AvoidRoundNumbers) return false;
   
   // Check for X.00 and X.50 levels  
   double price_fractional = price - MathFloor(price);
   double cents = MathRound(price_fractional * 100);
   
   bool near_00 = MathAbs(cents - 0) <= RoundNumberBuffer;
   bool near_50 = MathAbs(cents - 50) <= RoundNumberBuffer;
   
   if(near_00 || near_50)
   {
      if(EnableDebugLogs)
         Print("🔢 ROUND NUMBER: Price ", DoubleToString(price, 2), " near round level");
      return true;
   }
   
   return false;
}

//=== BALANCED PTG SIGNAL DETECTION ===
void CheckBalancedPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔥 BALANCED PUSH #", signal_count, " detected");
      
      CheckTestAndBalancedGo();
   }
}

bool IsPushDetected() 
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
   
   // Core PTG criteria (unchanged)
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

void CheckTestAndBalancedGo() 
{
   bool is_bullish = IsBullishContext();
   
   // Optional filters (only if enabled)
   if(!IsSqueezeExpansionOK()) return;
   if(!IsM5TrendOK(is_bullish)) return;
   
   // Balanced entry timing
   if(UseStopEmulation)
   {
      InitiateBalancedStopEmulation(is_bullish);
   } 
   else 
   {
      ExecuteBalancedEntry(is_bullish);
   }
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== BALANCED STOP EMULATION ===
void InitiateBalancedStopEmulation(bool is_long)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < 2) return; // Min spacing
   
   double trigger_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) + PriceFromPips(0.5) :
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) - PriceFromPips(0.5);
   
   // Check round number filter
   if(IsNearRoundNumber(trigger_price)) return;
   
   stop_emulation_pending = true;
   stop_emulation_time = (datetime)(TimeCurrent() + (long)(StopEmulationMS / 1000.0));
   stop_emulation_price = trigger_price;
   stop_emulation_is_long = is_long;
   
   if(EnableDebugLogs && signal_count % 100 == 0)
      Print("⏳ BALANCED STOP EMU: ", (is_long ? "LONG" : "SHORT"), " trigger @ ", 
            DoubleToString(trigger_price, 5));
}

void HandleStopEmulation()
{
   if(!stop_emulation_pending) return;
   
   // Check timing
   if(TimeCurrent() < stop_emulation_time) return;
   
   // Check price momentum
   double current_price = stop_emulation_is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double price_diff = stop_emulation_is_long ? 
                      (current_price - stop_emulation_price) :
                      (stop_emulation_price - current_price);
   
   double min_movement = MinMomentumTicks * Point();
   
   if(price_diff >= min_movement)
   {
      ExecuteBalancedEntry(stop_emulation_is_long);
   }
   else if(EnableDebugLogs && signal_count % 200 == 0)
   {
      Print("❌ STOP EMU FAILED: Movement ", DoubleToString(price_diff / Point(), 0), 
            " ticks < ", MinMomentumTicks);
   }
   
   ResetStopEmulation();
}

void ResetStopEmulation()
{
   stop_emulation_pending = false;
   stop_emulation_time = 0;
   stop_emulation_price = 0.0;
   stop_emulation_is_long = false;
}

//=== BALANCED TRADE EXECUTION ===
void ExecuteBalancedEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double entry_price = is_long ? 
                       SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                       SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Final round number check
   if(IsNearRoundNumber(entry_price)) return;
   
   double sl_price = is_long ? 
                     entry_price - PriceFromPips(FixedSLPips) :
                     entry_price + PriceFromPips(FixedSLPips);
   
   // Risk check
   double sl_distance_pips = MathAbs(entry_price - sl_price) / Pip();
   if(sl_distance_pips > MaxRiskPips) 
   {
      if(EnableDebugLogs)
         Print("❌ RISK HIGH: ", DoubleToString(sl_distance_pips, 1), "p > ", MaxRiskPips, "p");
      return;
   }
   
   // Proper normalization
   entry_price = NormalizePrice(entry_price);
   sl_price = NormalizePrice(sl_price);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.volume = FixedLotSize;
   req.type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = entry_price;
   req.sl = sl_price;
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "PTG v3.1 " + DoubleToString(FixedSLPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ PTG v3.1 ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(entry_price, 5), " | SL: ", DoubleToString(sl_price, 5));
      
      if(EnableAlerts)
         Alert("PTG v3.1 ", direction, " @", DoubleToString(entry_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== POSITION MANAGEMENT ===
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

void ManageBalancedPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / Pip() :
                       (original_entry_price - current_price) / Pip();
   
   // Balanced time-stop  
   if(bars_since_entry >= TimeStopBars && profit_pips < MinProfitPips) 
   {
      ClosePositionAtMarket("Balanced time-stop: " + IntegerToString(TimeStopBars) + " bars");
      return;
   }
   
   // Optimized partial TP
   if(!partial_tp_taken && profit_pips >= PartialTPPips) 
   {
      TakeBalancedPartialProfit();
      return;
   }
   
   // Simplified breakeven
   if(!breakeven_activated && profit_pips >= BreakevenPips) 
   {
      MoveToBalancedBreakeven();
      return;
   }
   
   // Optimized trailing
   if(breakeven_activated && profit_pips > BreakevenPips + TrailStepPips) 
   {
      TrailBalancedStopLoss(profit_pips);
   }
}

void TakeBalancedPartialProfit() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double close_volume = NormalizeDouble(current_volume * PartialTPPercent / 100.0, 2);
   
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
   req.comment = "PTG v3.1 TP " + DoubleToString(PartialTPPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 BALANCED PARTIAL TP: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveToBalancedBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Simple breakeven with spread buffer
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
         Print("🛡️ BALANCED BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
   }
}

void TrailBalancedStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Conservative trailing
   double trail_distance = profit_pips - MinProfitPips - 3.0;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move if significant improvement
   double min_improvement = PriceFromPips(4.0);
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
         Print("📈 BALANCED TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Profit: +", 
               DoubleToString(profit_pips, 1), "p");
      }
   }
}

void ClosePositionAtMarket(string reason) 
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
         Print("🔚 BALANCED CLOSE: ", reason);
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
   ResetStopEmulation();
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
               Print("🎯 PTG v3.1 FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
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
               
               // Update loss tracking
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
               Print("💰 PTG v3.1 EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), "p | Losses: ", consecutive_losses);
            
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
   if(m5_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(m5_ema_fast_handle);
   if(m5_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(m5_ema_slow_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   
   Print("🎯 PTG BALANCED v3.1.0 STOPPED - USER LOGIC + SELECTIVE CHATGPT");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("🏆 BALANCED APPROACH: M1 MANIPULATION + SMART OPTIMIZATIONS COMPLETE!");
}
