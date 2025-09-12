//+------------------------------------------------------------------+
//|                    PTG REALISTIC v3.1.2                         |
//|          Fixed Spread Logic - Realistic Gold Trading            |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.12"
#property description "PTG v3.1.2 - REALISTIC: Fixed Spread Logic + Smart Filtering"

//=== REALISTIC INPUTS (Fixed Spread Logic) ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA filter (keep simple)
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // Range >= 35%
input double   ClosePercent       = 0.45;              // Close position 45%
input double   OppWickPercent     = 0.55;              // Opp wick <= 55%
input double   VolHighMultiplier  = 1.2;               // Vol >= 120%

input group "=== REALISTIC FILTERING SYSTEM ==="
input bool     UseSoftSqueeze     = true;              // SOFT squeeze filter
input double   MinATRPips         = 70.0;              // Min ATR threshold (REALISTIC: 70p vs 85p)
input double   ATRPercentile      = 40.0;              // P40 ATR (more lenient vs P50)
input double   PushATRMultiplier  = 1.15;              // Push >= 1.15×ATR to override (easier vs 1.25)
input bool     UseBlackoutTimes   = true;              // Rollover blackout
input int      BlackoutStartHour  = 23;                // 23:50 server time
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 // 00:10 server time  
input int      BlackoutEndMin     = 10;

input group "=== REALISTIC SPREAD MANAGEMENT ==="
input double   MaxSpreadPips      = 12.0;              // FIXED: Single realistic spread limit
input bool     UseSpreadATRFilter = false;             // DISABLED: No more 2-tier confusion
input double   ExtremeSpreadPips  = 18.0;              // Only block extreme spreads (news)

input group "=== REALISTIC ENTRY SYSTEM ==="
input bool     UseSmartEntry      = true;              // Smart entry buffer + confirmation
input double   EntryBufferPips    = 2.0;               // REALISTIC: 2p buffer (vs 3p)
input double   SpreadMultiplier   = 1.0;               // Buffer = max(2p, 1.0×spread) - simpler
input bool     UseTickConfirm     = false;             // DISABLED: Too complex for M1
input bool     UseVolumeConfirm   = true;              // Keep volume confirmation  
input double   VolumeMultiplier   = 1.1;               // REALISTIC: 1.1× (vs 1.2×)
input double   MinRangePips       = 40.0;              // REALISTIC: 40p (vs 60p)

input group "=== REALISTIC EXITS ==="
input double   FixedSLPips        = 25.0;              // Keep 25p SL
input double   RealisticBEPips    = 20.0;              // REALISTIC: 20p BE (vs 22p)
input double   RealisticPartialPips = 23.0;            // REALISTIC: 23p partial (vs 25p)  
input double   PartialPercent     = 25.0;              // REALISTIC: 25% close (vs 30%)
input double   TrailStartPips     = 24.0;              // REALISTIC: 24p trail start (vs 26p)
input double   TrailStepPips      = 18.0;              // REALISTIC: 18p step (vs 22p)

input group "=== REALISTIC CIRCUIT BREAKER ==="
input bool     UseRealisticBreaker = true;             // Realistic circuit breaker
input int      LossWindow60Min    = 8;                 // REALISTIC: 8 losses in 60min (vs 6)
input int      CooldownMinutes    = 60;                // REALISTIC: 60min cooldown (vs 90min)
input int      DailyLossLimit     = 15;                // REALISTIC: 15 losses per day (vs 10)
input double   RestartATRMin      = 60.0;              // REALISTIC: ATR >= 60p to restart (vs 95p)
input double   RestartSpreadMax   = 12.5;              // REALISTIC: Spread <= 12.5p to restart

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.1.2-Realistic";

//=== GLOBAL VARIABLES ===
int magic_number = 31200;  // v3.1.2 magic number
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

// Realistic filtering variables
int atr_handle = INVALID_HANDLE;
double atr_history[];
int atr_history_size = 0;

// Realistic circuit breaker
struct LossRecord {
   datetime time;
   double loss_pips;
};
LossRecord loss_history[];
int loss_count_60min = 0;
int loss_count_daily = 0;
datetime circuit_breaker_until = 0;
datetime daily_reset_time = 0;

// Realistic entry confirmation  
double volume_history[];

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
   
   // Initialize ATR indicator
   atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create ATR(14) indicator");
      return INIT_FAILED;
   }
   
   // Initialize arrays
   ArrayResize(atr_history, 1000);
   ArrayInitialize(atr_history, 0.0);
   ArrayResize(loss_history, 100);
   ArrayResize(volume_history, 100);
   
   daily_reset_time = TimeCurrent() + 86400; // Next day
   
   Print("🎯 PTG REALISTIC v3.1.2 - FIXED SPREAD LOGIC!");
   Print("📊 Gold M1 Realistic: ATR=", MinATRPips, "p | Blackout=", UseBlackoutTimes);
   Print("💰 FIXED Spread: Max=", MaxSpreadPips, "p (NO 2-tier confusion!)");
   Print("🔥 Realistic Entry: Buffer=", EntryBufferPips, "p | Vol=", UseVolumeConfirm, " | Range=", MinRangePips, "p");
   Print("💎 Realistic Exits: BE=", RealisticBEPips, "p | Partial=", RealisticPartialPips, "p | Trail=", TrailStartPips, "p+");
   Print("🔴 Realistic Breaker: ", LossWindow60Min, " losses/60min → ", CooldownMinutes, "min cooldown");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   UpdateATRHistory();
   UpdateVolumeHistory();
   
   // Realistic filtering system
   if(!IsRealisticMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseRealisticBreaker && IsInRealisticCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageRealisticPosition();
      bars_since_entry++;
      return;
   }
   
   CheckRealisticPTGSignals();
}

//=== REALISTIC FILTERING SYSTEM ===
bool IsRealisticMarketOK() 
{
   // FIXED: Single realistic spread check (NO 2-tier confusion!)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   // Simple realistic spread filter
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ REALISTIC SPREAD: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   // Block only extreme spreads (news periods)
   if(current_spread > ExtremeSpreadPips) 
   {
      if(EnableDebugLogs)
         Print("🚨 EXTREME SPREAD: ", DoubleToString(current_spread, 1), "p - NEWS PERIOD");
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
   else // Same day
   {
      if(dt.hour >= BlackoutStartHour && dt.hour <= BlackoutEndHour)
      {
         if(dt.hour == BlackoutStartHour && dt.min < BlackoutStartMin) in_blackout = false;
         else if(dt.hour == BlackoutEndHour && dt.min > BlackoutEndMin) in_blackout = false;
         else in_blackout = true;
      }
   }
   
   if(in_blackout && EnableDebugLogs && signal_count % 1000 == 0)
      Print("🌙 BLACKOUT: ", IntegerToString(dt.hour), ":", IntegerToString(dt.min), 
            " in ", IntegerToString(BlackoutStartHour), ":", IntegerToString(BlackoutStartMin), 
            "-", IntegerToString(BlackoutEndHour), ":", IntegerToString(BlackoutEndMin));
   
   return in_blackout;
}

bool IsRealisticSqueezeOK()
{
   if(!UseSoftSqueeze) return true;
   
   double current_atr = GetCurrentATRPips();
   if(current_atr <= 0) return true;
   
   // Get ATR P40 from history (more lenient than P50)
   double atr_p40 = GetATRPercentile(ATRPercentile);
   double min_atr_required = MathMax(MinATRPips, atr_p40);
   
   // Condition 1: ATR >= max(70p, P40) - more realistic
   bool atr_ok = current_atr >= min_atr_required;
   
   // Condition 2: OR push range >= 1.15×ATR (easier than 1.25×)
   bool push_override = false;
   if(!atr_ok)
   {
      double push_range = GetCurrentPushRangePips();
      if(push_range >= current_atr * PushATRMultiplier)
      {
         push_override = true;
         if(EnableDebugLogs)
            Print("🔥 PUSH OVERRIDE: Range ", DoubleToString(push_range, 1), "p >= ", 
                  DoubleToString(current_atr * PushATRMultiplier, 1), "p (1.15×ATR)");
      }
   }
   
   bool squeeze_ok = atr_ok || push_override;
   
   if(!squeeze_ok && EnableDebugLogs && signal_count % 500 == 0)
      Print("📉 REALISTIC SQUEEZE: ATR ", DoubleToString(current_atr, 1), "p < ", 
            DoubleToString(min_atr_required, 1), "p | Push range insufficient");
   
   return squeeze_ok;
}

double GetCurrentATRPips()
{
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0) return 0;
   return atr_buffer[0] / Pip();
}

double GetATRPercentile(double percentile)
{
   if(atr_history_size < 50) return MinATRPips; // Not enough data
   
   // Simple percentile calculation
   double sorted_atr[];
   int valid_count = 0;
   
   for(int i = 0; i < atr_history_size && i < 1000; i++)
   {
      if(atr_history[i] > 0)
      {
         ArrayResize(sorted_atr, valid_count + 1);
         sorted_atr[valid_count] = atr_history[i];
         valid_count++;
      }
   }
   
   if(valid_count < 10) return MinATRPips;
   
   ArraySort(sorted_atr);
   int index = (int)(valid_count * percentile / 100.0);
   if(index >= valid_count) index = valid_count - 1;
   
   return sorted_atr[index] / Pip();
}

double GetCurrentPushRangePips()
{
   double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
   double low = iLow(Symbol(), PERIOD_CURRENT, 1);
   return (high - low) / Pip();
}

void UpdateATRHistory()
{
   double current_atr = GetCurrentATRPips();
   if(current_atr <= 0) return;
   
   // Shift array and add new value
   if(atr_history_size < 1000)
   {
      atr_history[atr_history_size] = current_atr * Pip();
      atr_history_size++;
   }
   else
   {
      // Shift array left
      for(int i = 0; i < 999; i++)
         atr_history[i] = atr_history[i + 1];
      atr_history[999] = current_atr * Pip();
   }
}

//=== REALISTIC CIRCUIT BREAKER ===
bool IsInRealisticCircuitBreaker()
{
   if(!UseRealisticBreaker) return false;
   
   // Check if still in cooldown
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 REALISTIC BREAKER: Cooldown until ", TimeToString(circuit_breaker_until), 
               " | Need ATR>=", RestartATRMin, "p + Spread<=", RestartSpreadMax, "p");
      return true;
   }
   
   // Check restart conditions if we just exited cooldown
   if(circuit_breaker_until > 0 && TimeCurrent() >= circuit_breaker_until)
   {
      if(!CheckRealisticRestartConditions())
      {
         circuit_breaker_until = TimeCurrent() + 300; // Extend 5min if conditions not met
         if(EnableDebugLogs)
            Print("🔴 REALISTIC RESTART CONDITIONS NOT MET: Extending cooldown 5min");
         return true;
      }
      else
      {
         circuit_breaker_until = 0;
         if(EnableDebugLogs)
            Print("✅ REALISTIC BREAKER: Restart conditions met - resuming trading");
      }
   }
   
   return false;
}

bool CheckRealisticRestartConditions()
{
   // Condition 1: ATR >= 60p (more realistic than 95p)
   double current_atr = GetCurrentATRPips();
   if(current_atr < RestartATRMin) return false;
   
   // Condition 2: Spread <= 12.5p (realistic)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   if(current_spread > RestartSpreadMax) return false;
   
   return true;
}

void UpdateRealisticLossHistory(double loss_pips)
{
   datetime current_time = TimeCurrent();
   
   // Reset daily counter if needed
   if(current_time >= daily_reset_time)
   {
      loss_count_daily = 0;
      daily_reset_time = current_time + 86400;
      if(EnableDebugLogs)
         Print("🔄 DAILY RESET: Loss counter reset");
   }
   
   // Add loss to history
   int history_size = ArraySize(loss_history);
   if(history_size < 100)
   {
      ArrayResize(loss_history, history_size + 1);
      loss_history[history_size].time = current_time;
      loss_history[history_size].loss_pips = loss_pips;
   }
   else
   {
      // Shift array and add new
      for(int i = 0; i < 99; i++)
         loss_history[i] = loss_history[i + 1];
      loss_history[99].time = current_time;
      loss_history[99].loss_pips = loss_pips;
   }
   
   // Count losses in last 60 minutes
   loss_count_60min = 0;
   datetime cutoff_time = current_time - 3600; // 60 minutes ago
   
   for(int i = ArraySize(loss_history) - 1; i >= 0; i--)
   {
      if(loss_history[i].time >= cutoff_time && loss_history[i].loss_pips > 2.0)
         loss_count_60min++;
      else if(loss_history[i].time < cutoff_time)
         break;
   }
   
   loss_count_daily++;
   
   if(EnableDebugLogs)
      Print("📊 REALISTIC LOSS TRACKING: 60min=", loss_count_60min, "/", LossWindow60Min, 
            " | Daily=", loss_count_daily, "/", DailyLossLimit);
   
   // Activate circuit breaker if needed
   if(loss_count_60min >= LossWindow60Min)
   {
      circuit_breaker_until = current_time + CooldownMinutes * 60;
      if(EnableDebugLogs)
         Print("🔴 REALISTIC BREAKER ACTIVATED: ", loss_count_60min, " losses in 60min | Cooldown until ", 
               TimeToString(circuit_breaker_until));
   }
   
   if(loss_count_daily >= DailyLossLimit)
   {
      circuit_breaker_until = daily_reset_time;
      if(EnableDebugLogs)
         Print("🔴 DAILY LIMIT REACHED: ", loss_count_daily, " losses | Stopped for the day");
   }
}

//=== REALISTIC ENTRY SYSTEM ===
void UpdateVolumeHistory()
{
   static datetime last_update = 0;
   if(TimeCurrent() == last_update) return;
   last_update = TimeCurrent();
   
   // Update volume history  
   long current_volume = iTickVolume(Symbol(), PERIOD_CURRENT, 0);
   
   int vol_size = ArraySize(volume_history);
   if(vol_size < 100)
   {
      ArrayResize(volume_history, vol_size + 1);
      volume_history[vol_size] = (double)current_volume;
   }
   else
   {
      for(int i = 0; i < 99; i++)
         volume_history[i] = volume_history[i + 1];
      volume_history[99] = (double)current_volume;
   }
}

bool IsRealisticEntryConfirmed(bool is_long)
{
   if(!UseSmartEntry) return true;
   
   // Check volume confirmation (simplified)
   if(UseVolumeConfirm)
   {
      long current_vol = iTickVolume(Symbol(), PERIOD_CURRENT, 0);
      double median_vol_5 = GetMedianVolume5();
      
      if(current_vol < median_vol_5 * VolumeMultiplier)
      {
         if(EnableDebugLogs)
            Print("❌ REALISTIC VOLUME: ", current_vol, " < ", 
                  DoubleToString(median_vol_5 * VolumeMultiplier, 0));
         return false;
      }
   }
   
   // Check 3-bar range (realistic threshold)
   double range_3bars = Get3BarRangePips();
   if(range_3bars < MinRangePips)
   {
      if(EnableDebugLogs)
         Print("❌ REALISTIC RANGE: ", DoubleToString(range_3bars, 1), "p < ", MinRangePips, "p");
      return false;
   }
   
   return true;
}

double GetMedianVolume5()
{
   if(ArraySize(volume_history) < 5) return 1000.0; // Default
   
   double sum = 0.0;
   int count = MathMin(5, ArraySize(volume_history));
   
   for(int i = ArraySize(volume_history) - count; i < ArraySize(volume_history); i++)
      sum += volume_history[i];
   
   return sum / count;
}

double Get3BarRangePips()
{
   double total_range = 0.0;
   
   for(int i = 1; i <= 3; i++)
   {
      double high = iHigh(Symbol(), PERIOD_CURRENT, i);
      double low = iLow(Symbol(), PERIOD_CURRENT, i);
      total_range += (high - low);
   }
   
   return total_range / Pip();
}

//=== REALISTIC PTG SIGNALS ===
void CheckRealisticPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔥 REALISTIC PUSH #", signal_count, " detected");
      
      CheckRealisticTestAndGo();
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

void CheckRealisticTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   
   // Realistic filtering
   if(!IsRealisticSqueezeOK()) return;
   
   // Realistic entry confirmation
   if(!IsRealisticEntryConfirmed(is_bullish)) return;
   
   ExecuteRealisticEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== REALISTIC TRADE EXECUTION ===
void ExecuteRealisticEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double current_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Realistic entry buffer (simplified)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   double buffer_pips = MathMax(EntryBufferPips, current_spread * SpreadMultiplier);
   
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
   req.comment = "PTG Realistic v3.1.2";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ REALISTIC ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5), " | Buffer: ", DoubleToString(buffer_pips, 1), "p");
      
      if(EnableAlerts)
         Alert("PTG Realistic ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ REALISTIC ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== REALISTIC POSITION MANAGEMENT ===
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

void ManageRealisticPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / Pip() :
                       (original_entry_price - current_price) / Pip();
   
   // Realistic partial TP
   if(!partial_tp_taken && profit_pips >= RealisticPartialPips) 
   {
      TakeRealisticPartialProfit();
      return;
   }
   
   // Realistic breakeven  
   if(!breakeven_activated && profit_pips >= RealisticBEPips) 
   {
      MoveToRealisticBreakeven();
      return;
   }
   
   // Realistic trailing
   if(breakeven_activated && profit_pips >= TrailStartPips) 
   {
      TrailRealisticStopLoss(profit_pips);
   }
}

void TakeRealisticPartialProfit() 
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
   req.comment = "Realistic Partial " + DoubleToString(RealisticPartialPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 REALISTIC PARTIAL: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(RealisticPartialPips, 1), "p (", DoubleToString(PartialPercent, 0), "%)");
   }
}

void MoveToRealisticBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Realistic breakeven with spread buffer
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(2.0)) :
                     (original_entry_price - spread - PriceFromPips(2.0));
   
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
         Print("🛡️ REALISTIC BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(RealisticBEPips, 1), "p trigger)");
   }
}

void TrailRealisticStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Realistic trailing: fixed step
   double trail_distance = profit_pips - TrailStepPips;  
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
         Print("📈 REALISTIC TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
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
               Print("🎯 REALISTIC FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - track losses for realistic circuit breaker
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / Pip() :
                            (original_entry_price - trans.price) / Pip();
               
               // Update realistic loss tracking
               if(profit_pips < -2.0) // Consider < -2 pip as loss
               {
                  UpdateRealisticLossHistory(-profit_pips);
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 REALISTIC EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | 60min losses: ", loss_count_60min);
            
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
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   
   Print("🎯 PTG REALISTIC v3.1.2 STOPPED - FIXED SPREAD LOGIC COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Circuit Breaker Stats: 60min=", loss_count_60min, " | Daily=", loss_count_daily);
   Print("💰 REALISTIC SPREAD: Fixed ", MaxSpreadPips, "p limit (NO 2-tier confusion!)");
}
