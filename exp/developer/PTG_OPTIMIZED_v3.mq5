//+------------------------------------------------------------------+
//|                    PTG OPTIMIZED v3.0.0                         |
//|            Based on ChatGPT Analysis - Win Rate Optimization    |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.00"
#property description "PTG v3.0 - ChatGPT Optimized: Signal Quality + Entry Timing + Position Management"

//=== CHATGPT OPTIMIZED INPUTS ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA filter (keep simple)
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // Range >= 35%
input double   ClosePercent       = 0.45;              // Close position 45%
input double   OppWickPercent     = 0.55;              // Opp wick <= 55%
input double   VolHighMultiplier  = 1.2;               // Vol >= 120%

input group "=== CHATGPT SIGNAL QUALITY FILTERS ==="
input bool     UseSessionFilter   = true;              // London+NY only (ChatGPT priority 1)
input int      SessionStartHour   = 7;                 // London start (broker time)
input int      SessionEndHour     = 17;                // NY end (broker time)
input bool     UseSqueezeFilter   = true;              // Squeeze->Expansion filter
input double   ATRPercentileMin   = 60.0;              // Min ATR percentile (60-70%)
input int      ATRLookbackDays    = 5;                 // Days for ATR percentile calc
input bool     UseM5TrendFilter   = true;              // M5 trend confirmation
input int      M5_EMA_Fast        = 50;                // M5 EMA fast
input int      M5_EMA_Slow        = 200;               // M5 EMA slow

input group "=== DYNAMIC SPREAD & RISK (CHATGPT) ==="
input double   MaxSpreadPips      = 12.0;              // Max spread (fallback)
input bool     UseDynamicSpread   = true;              // Dynamic spread filter
input double   SpreadATRRatio     = 0.15;              // Max spread = 15% of ATR
input double   FixedSLPips        = 25.0;              // Fixed SL distance
input double   MaxRiskPips        = 35.0;              // Max risk per trade

input group "=== ENTRY TIMING OPTIMIZATION (CHATGPT) ==="
input bool     UseStopEmulation   = true;              // Stop emulation instead of immediate entry
input double   StopEmulationMS    = 200.0;             // Wait time for confirmation (ms)
input int      MinMomentumTicks   = 2;                 // Min ticks beyond trigger
input bool     UseRetestFilter    = true;              // Micro-retest after breakout
input double   RetestMaxPercent   = 30.0;              // Max retest 30% of push range
input bool     AvoidRoundNumbers  = true;              // Skip trades near round numbers
input double   RoundNumberBuffer  = 12.0;              // Buffer around round numbers (pips)

input group "=== IMPROVED POSITION MANAGEMENT (CHATGPT) ==="
input double   BreakevenPips      = 18.0;              // ChatGPT: 18 pips BE (was 15)
input bool     UseStructureBE     = true;              // Structure-based BE activation
input double   PartialTPPips      = 20.0;              // ChatGPT: 20 pips partial TP (was 22)  
input double   PartialTPPercent   = 30.0;              // 30% close at partial TP
input double   TrailStepPips      = 20.0;              // ChatGPT: 20 pips trail (was 18)
input double   MinProfitPips      = 9.0;               // Min profit for trail

input group "=== RISK CONTROL ENHANCEMENTS (CHATGPT) ==="
input bool     UseCircuitBreaker  = true;              // Circuit breaker after losses
input int      MaxConsecutiveLosses = 6;               // Max losses before cooldown
input int      CooldownMinutes    = 60;                // Cooldown period (minutes)
input bool     UseCooldownAfterSL = true;              // Cooldown after SL hit
input int      SLCooldownMinutes  = 5;                 // Minutes to wait after SL
input int      TimeStopBars       = 25;                // Dynamic time-stop (was 30)

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.0.0-ChatGPT-Optimized";

//=== GLOBAL VARIABLES ===
int magic_number = 30000;  // v3.0 magic number
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

// ChatGPT v3.0 specific variables
int consecutive_losses = 0;
datetime last_loss_time = 0;
datetime circuit_breaker_until = 0;
datetime last_sl_time = 0;
int m5_ema_fast_handle = INVALID_HANDLE;
int m5_ema_slow_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;
double atr_history[];
datetime stop_emulation_time = 0;
double stop_emulation_price = 0.0;
bool stop_emulation_pending = false;
bool stop_emulation_is_long = false;

//=== CHATGPT HELPER FUNCTIONS ===
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
   
   // Initialize indicators for ChatGPT filters
   if(UseM5TrendFilter)
   {
      m5_ema_fast_handle = iMA(Symbol(), PERIOD_M5, M5_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      m5_ema_slow_handle = iMA(Symbol(), PERIOD_M5, M5_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      
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
      int total_bars = ATRLookbackDays * 1440; // Days * minutes per day
      ArrayResize(atr_history, total_bars);
      ArrayInitialize(atr_history, 0.0);
   }
   
   Print("🎯 PTG OPTIMIZED v3.0.0 - CHATGPT WIN RATE OPTIMIZATION!");
   Print("📊 Gold Specialist: Pip=", pip_size, " | Magic=", magic_number);
   Print("⚡ Signal Quality: Session=", UseSessionFilter, " | Squeeze=", UseSqueezeFilter, " | M5Trend=", UseM5TrendFilter);
   Print("🎯 Entry Timing: StopEmulation=", UseStopEmulation, " | Retest=", UseRetestFilter, " | RoundNum=", AvoidRoundNumbers);
   Print("🛡️ Position Mgmt: BE=", BreakevenPips, "p | PartialTP=", PartialTPPips, "p | Trail=", TrailStepPips, "p");
   Print("🔧 Risk Control: CircuitBreaker=", UseCircuitBreaker, " | SL Cooldown=", UseCooldownAfterSL);
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // ChatGPT Priority: Check all filters first
   if(!IsMarketConditionsOK()) return;
   if(!IsSessionTimeOK()) return;
   if(IsInCircuitBreaker()) return;
   if(IsInSLCooldown()) return;
   
   UpdatePositionInfo();
   
   // Handle stop emulation timing
   if(stop_emulation_pending)
   {
      HandleStopEmulation();
      return;
   }
   
   if(active_position_ticket > 0) 
   {
      ManageOptimizedPosition();
      bars_since_entry++;
      return;
   }
   
   CheckOptimizedPTGSignals();
}

//=== CHATGPT SIGNAL QUALITY FILTERS ===
bool IsSessionTimeOK()
{
   if(!UseSessionFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;
   
   // London + NY sessions (7:00 - 17:00 broker time)
   bool session_ok = (current_hour >= SessionStartHour && current_hour < SessionEndHour);
   
   if(!session_ok && EnableDebugLogs)
      Print("⏰ OUTSIDE SESSION: Hour ", current_hour, " not in ", SessionStartHour, "-", SessionEndHour);
   
   return session_ok;
}

bool IsSqueezeExpansionOK()
{
   if(!UseSqueezeFilter || atr_handle == INVALID_HANDLE) return true;
   
   // Get current ATR
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0) return false;
   
   double current_atr = atr_buffer[0];
   double current_atr_pips = current_atr / Pip();
   
   // Update ATR history
   for(int i = ArraySize(atr_history) - 1; i > 0; i--)
      atr_history[i] = atr_history[i-1];
   atr_history[0] = current_atr_pips;
   
   // Calculate ATR percentile
   double sorted_atr[];
   ArrayCopy(sorted_atr, atr_history);
   ArraySort(sorted_atr);
   
   int valid_count = 0;
   for(int i = 0; i < ArraySize(sorted_atr); i++)
      if(sorted_atr[i] > 0) valid_count++;
   
   if(valid_count < 100) return true; // Not enough data yet
   
   int percentile_index = (int)(valid_count * ATRPercentileMin / 100.0);
   double atr_threshold = sorted_atr[percentile_index];
   
   bool squeeze_ok = current_atr_pips >= atr_threshold;
   
   if(!squeeze_ok && EnableDebugLogs)
      Print("📉 SQUEEZE DETECTED: ATR ", DoubleToString(current_atr_pips, 1), "p < threshold ", DoubleToString(atr_threshold, 1), "p");
   
   return squeeze_ok;
}

bool IsM5TrendOK(bool is_bullish_signal)
{
   if(!UseM5TrendFilter || m5_ema_fast_handle == INVALID_HANDLE || m5_ema_slow_handle == INVALID_HANDLE) 
      return true;
   
   double ema_fast[], ema_slow[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   
   if(CopyBuffer(m5_ema_fast_handle, 0, 1, 2, ema_fast) <= 0) return false;
   if(CopyBuffer(m5_ema_slow_handle, 0, 1, 2, ema_slow) <= 0) return false;
   
   bool uptrend = ema_fast[0] > ema_slow[0];
   double ema_slope = (ema_fast[0] - ema_fast[1]) / Pip();
   bool strong_trend = MathAbs(ema_slope) > 0.5; // Min 0.5 pip slope
   
   bool trend_ok = false;
   if(is_bullish_signal) trend_ok = uptrend && ema_slope > 0;
   else trend_ok = !uptrend && ema_slope < 0;
   
   if(!trend_ok && EnableDebugLogs)
      Print("📊 M5 TREND CONFLICT: Signal=", (is_bullish_signal ? "BULL" : "BEAR"), 
            " | Trend=", (uptrend ? "UP" : "DOWN"), " | Slope=", DoubleToString(ema_slope, 1), "p");
   
   return trend_ok;
}

bool IsDynamicSpreadOK()
{
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   double max_spread = MaxSpreadPips;
   
   if(UseDynamicSpread && atr_handle != INVALID_HANDLE)
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
      {
         double atr_pips = atr_buffer[0] / Pip();
         double dynamic_max = atr_pips * SpreadATRRatio;
         max_spread = MathMin(MaxSpreadPips, dynamic_max);
      }
   }
   
   bool spread_ok = current_spread <= max_spread;
   
   if(!spread_ok && EnableDebugLogs)
      Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", DoubleToString(max_spread, 1), "p");
   
   return spread_ok;
}

bool IsMarketConditionsOK() 
{
   if(!IsDynamicSpreadOK()) return false;
   if(!IsSqueezeExpansionOK()) return false;
   
   // Skip extreme spreads (news periods)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   if(current_spread > MaxSpreadPips * 2.0) 
   {
      if(EnableDebugLogs)
         Print("🚨 EXTREME SPREAD: ", DoubleToString(current_spread, 1), "p - NEWS PERIOD");
      return false;
   }
   
   return true;
}

//=== CIRCUIT BREAKER & COOLDOWN (CHATGPT) ===
bool IsInCircuitBreaker()
{
   if(!UseCircuitBreaker) return false;
   
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔴 CIRCUIT BREAKER: Active until ", TimeToString(circuit_breaker_until));
      return true;
   }
   
   return false;
}

bool IsInSLCooldown()
{
   if(!UseCooldownAfterSL) return false;
   
   if(TimeCurrent() < last_sl_time + SLCooldownMinutes * 60)
   {
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
         Print("🔴 CIRCUIT BREAKER ACTIVATED: ", consecutive_losses, " losses | Cooldown until ", 
               TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0; // Reset counter
   }
}

//=== ROUND NUMBER FILTER (CHATGPT) ===
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

//=== OPTIMIZED PTG SIGNAL DETECTION ===
void CheckOptimizedPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 200 == 0)
         Print("🔥 OPTIMIZED PUSH #", signal_count, " detected");
      
      CheckTestAndOptimizedGo();
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
   
   // ChatGPT: Keep core PTG criteria
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

void CheckTestAndOptimizedGo() 
{
   bool is_bullish = IsBullishContext();
   
   // ChatGPT: M5 trend filter first
   if(!IsM5TrendOK(is_bullish)) return;
   
   // ChatGPT: Stop emulation instead of immediate entry
   if(UseStopEmulation)
   {
      InitiateStopEmulation(is_bullish);
   } 
   else 
   {
      ExecuteOptimizedEntry(is_bullish);
   }
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== STOP EMULATION (CHATGPT ENTRY TIMING) ===
void InitiateStopEmulation(bool is_long)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < 3) return; // Min spacing
   
   // Set up stop emulation
   double trigger_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) + PriceFromPips(1.0) :
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) - PriceFromPips(1.0);
   
   // Check round number filter
   if(IsNearRoundNumber(trigger_price)) return;
   
   stop_emulation_pending = true;
   stop_emulation_time = (datetime)(TimeCurrent() + (long)(StopEmulationMS / 1000.0));
   stop_emulation_price = trigger_price;
   stop_emulation_is_long = is_long;
   
   if(EnableDebugLogs)
      Print("⏳ STOP EMULATION: ", (is_long ? "LONG" : "SHORT"), " trigger @ ", 
            DoubleToString(trigger_price, 5), " waiting ", DoubleToString(StopEmulationMS, 0), "ms");
}

void HandleStopEmulation()
{
   if(!stop_emulation_pending) return;
   
   // Check if enough time has passed
   if(TimeCurrent() < stop_emulation_time) return;
   
   // Check if price still beyond trigger + minimum ticks
   double current_price = stop_emulation_is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double price_diff = stop_emulation_is_long ? 
                      (current_price - stop_emulation_price) :
                      (stop_emulation_price - current_price);
   
   double min_movement = MinMomentumTicks * Point();
   
   if(price_diff >= min_movement)
   {
      // Additional retest filter
      if(UseRetestFilter && !IsRetestOK()) 
      {
         if(EnableDebugLogs)
            Print("❌ RETEST FAILED: Too much pullback after breakout");
         ResetStopEmulation();
         return;
      }
      
      ExecuteOptimizedEntry(stop_emulation_is_long);
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ STOP EMULATION FAILED: Movement ", DoubleToString(price_diff / Point(), 0), 
               " ticks < ", MinMomentumTicks, " required");
   }
   
   ResetStopEmulation();
}

bool IsRetestOK()
{
   // Simple retest check - price shouldn't have pulled back too much
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 0, 3, high) <= 0) return true;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 0, 3, low) <= 0) return true;
   
   double recent_range = high[0] - low[0];
   double push_range = high[1] - low[1]; // Previous bar was push
   
   if(push_range == 0) return true;
   
   double retest_ratio = recent_range / push_range;
   bool retest_ok = retest_ratio <= (RetestMaxPercent / 100.0);
   
   return retest_ok;
}

void ResetStopEmulation()
{
   stop_emulation_pending = false;
   stop_emulation_time = 0;
   stop_emulation_price = 0.0;
   stop_emulation_is_long = false;
}

//=== OPTIMIZED TRADE EXECUTION ===
void ExecuteOptimizedEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double entry_price = is_long ? 
                       SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                       SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Final round number check at entry
   if(IsNearRoundNumber(entry_price)) return;
   
   double sl_price = is_long ? 
                     entry_price - PriceFromPips(FixedSLPips) :
                     entry_price + PriceFromPips(FixedSLPips);
   
   // Risk check
   double sl_distance_pips = MathAbs(entry_price - sl_price) / Pip();
   if(sl_distance_pips > MaxRiskPips) 
   {
      if(EnableDebugLogs)
         Print("❌ RISK TOO HIGH: ", DoubleToString(sl_distance_pips, 1), "p > ", MaxRiskPips, "p");
      return;
   }
   
   // Normalize prices properly (ChatGPT fix for "Invalid stops")
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
   req.tp = 0.0;  // Managed by EA
   req.magic = magic_number;
   req.comment = "PTG v3.0 " + DoubleToString(FixedSLPips, 1) + "p";
   req.deviation = 30;  // 3 pip slippage tolerance
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ PTG v3.0 ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(entry_price, 5), " | SL: ", DoubleToString(sl_price, 5));
      
      if(EnableAlerts)
         Alert("PTG v3.0 ", direction, " ENTRY @", DoubleToString(entry_price, 5));
   } 
   else 
   {
      if(EnableDebugLogs)
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

void ManageOptimizedPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / Pip() :
                       (original_entry_price - current_price) / Pip();
   
   // ChatGPT: Dynamic time-stop  
   if(bars_since_entry >= TimeStopBars && profit_pips < MinProfitPips) 
   {
      ClosePositionAtMarket("Time-stop: " + IntegerToString(TimeStopBars) + " bars no progress");
      return;
   }
   
   // ChatGPT: Optimized partial TP (20 pips)
   if(!partial_tp_taken && profit_pips >= PartialTPPips) 
   {
      TakeOptimizedPartialProfit();
      return;
   }
   
   // ChatGPT: Improved breakeven (18 pips)
   if(!breakeven_activated && profit_pips >= BreakevenPips) 
   {
      if(!UseStructureBE || IsStructureBreakevenOK(is_long))
      {
         MoveToOptimizedBreakeven();
         return;
      }
   }
   
   // Trail with optimized settings
   if(breakeven_activated && profit_pips > BreakevenPips + TrailStepPips) 
   {
      TrailOptimizedStopLoss(profit_pips);
   }
}

bool IsStructureBreakevenOK(bool is_long)
{
   if(!UseStructureBE) return true;
   
   // Simple structure check - look for higher low (long) or lower high (short)
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 1, 3, high) <= 0) return true;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 1, 3, low) <= 0) return true;
   
   if(is_long)
   {
      // Look for higher low
      bool higher_low = low[0] > low[1] || low[1] > low[2];
      return higher_low;
   }
   else
   {
      // Look for lower high  
      bool lower_high = high[0] < high[1] || high[1] < high[2];
      return lower_high;
   }
}

void TakeOptimizedPartialProfit() 
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
   req.comment = "PTG v3.0 TP " + DoubleToString(PartialTPPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 OPTIMIZED PARTIAL TP: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveToOptimizedBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // ChatGPT: Proper spread buffer for breakeven
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(1.0)) :
                     (original_entry_price - spread - PriceFromPips(1.0));
   
   be_price = NormalizePrice(be_price);  // ChatGPT: Proper normalization
   
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
         Print("🛡️ OPTIMIZED BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ BREAKEVEN FAILED: ", res.retcode, " - ", res.comment);
   }
}

void TrailOptimizedStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // ChatGPT: Conservative trailing with wider steps
   double trail_distance = profit_pips - MinProfitPips - 5.0;  // Extra 5 pip buffer
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move if significant improvement (ChatGPT: wider minimum move)
   double min_improvement = PriceFromPips(5.0);
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
      
      if(OrderSend(req, res)) 
      {
         if(EnableDebugLogs)
            Print("📈 OPTIMIZED TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Profit: +", 
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
         Print("🔚 OPTIMIZED CLOSE: ", reason);
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
               Print("🎯 PTG v3.0 FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - track for circuit breaker
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / Pip() :
                            (original_entry_price - trans.price) / Pip();
               
               // Update loss tracking for circuit breaker
               if(profit_pips < -1.0) // Consider < -1 pip as loss
               {
                  consecutive_losses++;
                  last_loss_time = TimeCurrent();
                  last_sl_time = TimeCurrent(); // For SL cooldown
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 1.0) // Reset on profitable trade
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 PTG v3.0 EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), "p | Consecutive losses: ", consecutive_losses);
            
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
   
   Print("🎯 PTG OPTIMIZED v3.0.0 STOPPED - CHATGPT WIN RATE OPTIMIZATION COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("🏆 CHATGPT ANALYSIS IMPLEMENTATION: COMPLETE!");
}
