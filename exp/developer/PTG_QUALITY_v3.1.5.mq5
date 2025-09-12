//+------------------------------------------------------------------+
//|                    PTG QUALITY v3.1.5                           |
//|          Fixed Profit Calc + Stricter Quality Filters           |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.15"
#property description "PTG v3.1.5 - QUALITY: Fixed Bugs + Stricter Filters for Better Win Rate"

//=== QUALITY INPUTS (Stricter for Better Win Rate) ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA filter (keep simple)
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== STRICTER PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.40;              // STRICTER: 40% (vs 30% moderate)
input double   ClosePercent       = 0.50;              // STRICTER: 50% (vs 40% moderate)
input double   OppWickPercent     = 0.45;              // STRICTER: 45% (vs 60% moderate)
input double   VolHighMultiplier  = 1.3;               // STRICTER: 1.3× (vs 1.15× moderate)

input group "=== QUALITY FILTERING ==="
input bool     UseQualityATR      = true;              // Quality ATR filter
input double   MinATRPips         = 85.0;              // STRICTER: 85p (vs 75p moderate)
input bool     UseBlackoutTimes   = true;              // Keep rollover blackout
input int      BlackoutStartHour  = 23;                // 23:50 server time
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 // 00:10 server time  
input int      BlackoutEndMin     = 10;

input group "=== QUALITY SPREAD MANAGEMENT ==="
input double   MaxSpreadPips      = 11.0;              // STRICTER: 11p (vs 13p moderate)

input group "=== QUALITY ENTRY SYSTEM ==="
input bool     UseQualityEntry    = true;              // Quality entry filters
input double   MinRangePips       = 65.0;              // STRICTER: 65p (vs 50p moderate)
input bool     UseVolumeRatio     = true;              // Volume ratio check
input double   VolumeRatioMin     = 1.15;              // STRICTER: 1.15× (vs 1.05× moderate)
input bool     UseSpreadATRRatio  = true;              // Spread vs ATR check
input double   MaxSpreadATRRatio  = 0.15;              // STRICTER: 15% (vs 20% moderate)
input bool     UseMomentumFilter  = true;              // NEW: Momentum confirmation
input double   MinMomentumPips    = 8.0;               // NEW: Min 8p movement in 3 bars

input group "=== QUALITY EXITS (Better R:R) ==="
input double   FixedSLPips        = 25.0;              // Keep 25p SL
input double   QualityBEPips      = 22.0;              // QUALITY: 22p BE (safer)
input double   QualityPartialPips = 32.0;              // QUALITY: 32p partial (much better R:R)  
input double   PartialPercent     = 20.0;              // QUALITY: 20% close (keep more running)
input double   TrailStartPips     = 35.0;              // QUALITY: 35p trail start (let winners run)
input double   TrailStepPips      = 20.0;              // QUALITY: 20p step (wider)

input group "=== QUALITY CIRCUIT BREAKER ==="
input bool     UseQualityBreaker  = true;              // Quality circuit breaker
input int      LossWindow60Min    = 5;                 // STRICTER: 5 losses in 60min (vs 7)
input int      CooldownMinutes    = 60;                // 60min cooldown
input int      DailyLossLimit     = 12;                // STRICTER: 12 losses per day (vs 15)

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.1.5-Quality";

//=== GLOBAL VARIABLES ===
int magic_number = 31500;  // v3.1.5 magic number
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

// Quality filtering variables
int atr_handle = INVALID_HANDLE;

// Quality circuit breaker
struct LossRecord {
   datetime time;
   double loss_pips;
};
LossRecord loss_history[];
int loss_count_60min = 0;
int loss_count_daily = 0;
datetime circuit_breaker_until = 0;
datetime daily_reset_time = 0;

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
   if(UseQualityATR || UseSpreadATRRatio)
   {
      atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
      if(atr_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create ATR(14) indicator");
         return INIT_FAILED;
      }
   }
   
   // Initialize arrays
   ArrayResize(loss_history, 100);
   daily_reset_time = TimeCurrent() + 86400; // Next day
   
   Print("💎 PTG QUALITY v3.1.5 - FIXED BUGS + STRICTER QUALITY FILTERS!");
   Print("🎯 Gold M1 Quality: Push=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("📊 Quality Filters: ATR=", (UseQualityATR ? DoubleToString(MinATRPips, 0) + "p" : "OFF"), " | Spread=", MaxSpreadPips, "p");
   Print("🔥 Entry Quality: Range=", MinRangePips, "p | VolRatio=", VolumeRatioMin, "× | Momentum=", (UseMomentumFilter ? DoubleToString(MinMomentumPips, 0) + "p" : "OFF"));
   Print("💎 Quality Exits: BE=", QualityBEPips, "p | Partial=", QualityPartialPips, "p | Trail=", TrailStartPips, "p+");
   Print("🔴 Quality Breaker: ", LossWindow60Min, " losses/60min → ", CooldownMinutes, "min cooldown");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // Quality filtering system
   if(!IsQualityMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseQualityBreaker && IsInQualityCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageQualityPosition();
      bars_since_entry++;
      return;
   }
   
   CheckQualityPTGSignals();
}

//=== QUALITY FILTERING SYSTEM ===
bool IsQualityMarketOK() 
{
   // Quality spread check (stricter)
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ QUALITY SPREAD: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   // Quality spread vs ATR ratio check (stricter)
   if(UseSpreadATRRatio && atr_handle != INVALID_HANDLE)
   {
      double current_atr = GetCurrentATRPips();
      if(current_atr > 0)
      {
         double spread_atr_ratio = current_spread / current_atr;
         if(spread_atr_ratio > MaxSpreadATRRatio)
         {
            if(EnableDebugLogs && signal_count % 500 == 0)
               Print("⚠️ SPREAD/ATR RATIO: ", DoubleToString(spread_atr_ratio*100, 1), "% > ", 
                     DoubleToString(MaxSpreadATRRatio*100, 1), "%");
            return false;
         }
      }
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

bool IsQualityATROK()
{
   if(!UseQualityATR || atr_handle == INVALID_HANDLE) return true;
   
   double current_atr = GetCurrentATRPips();
   if(current_atr <= 0) return true;
   
   // Quality ATR check (stricter)
   bool atr_ok = current_atr >= MinATRPips;
   
   if(!atr_ok && EnableDebugLogs && signal_count % 500 == 0)
      Print("📉 QUALITY ATR: ", DoubleToString(current_atr, 1), "p < ", MinATRPips, "p");
   
   return atr_ok;
}

double GetCurrentATRPips()
{
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0) return 0;
   return atr_buffer[0] / Pip();
}

//=== QUALITY CIRCUIT BREAKER ===
bool IsInQualityCircuitBreaker()
{
   if(!UseQualityBreaker) return false;
   
   // Check if still in cooldown
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 QUALITY BREAKER: Cooldown until ", TimeToString(circuit_breaker_until));
      return true;
   }
   
   return false;
}

void UpdateQualityLossHistory(double loss_pips)
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
      Print("📊 QUALITY LOSS TRACKING: 60min=", loss_count_60min, "/", LossWindow60Min, 
            " | Daily=", loss_count_daily, "/", DailyLossLimit);
   
   // Activate circuit breaker if needed
   if(loss_count_60min >= LossWindow60Min)
   {
      circuit_breaker_until = current_time + CooldownMinutes * 60;
      if(EnableDebugLogs)
         Print("🔴 QUALITY BREAKER ACTIVATED: ", loss_count_60min, " losses in 60min | Cooldown until ", 
               TimeToString(circuit_breaker_until));
   }
   
   if(loss_count_daily >= DailyLossLimit)
   {
      circuit_breaker_until = daily_reset_time;
      if(EnableDebugLogs)
         Print("🔴 DAILY LIMIT REACHED: ", loss_count_daily, " losses | Stopped for the day");
   }
}

//=== QUALITY ENTRY SYSTEM ===
bool IsQualityEntryOK()
{
   if(!UseQualityEntry) return true;
   
   // Check 3-bar range (stricter threshold)
   double range_3bars = Get3BarRangePips();
   if(range_3bars < MinRangePips)
   {
      if(EnableDebugLogs && signal_count % 200 == 0)
         Print("❌ QUALITY RANGE: ", DoubleToString(range_3bars, 1), "p < ", MinRangePips, "p");
      return false;
   }
   
   // Quality volume ratio check (stricter)
   if(UseVolumeRatio)
   {
      if(!IsVolumeRatioOK())
      {
         if(EnableDebugLogs && signal_count % 200 == 0)
            Print("❌ QUALITY VOLUME RATIO: Below ", VolumeRatioMin, "× threshold");
         return false;
      }
   }
   
   // NEW: Momentum filter
   if(UseMomentumFilter)
   {
      if(!IsMomentumOK())
      {
         if(EnableDebugLogs && signal_count % 200 == 0)
            Print("❌ QUALITY MOMENTUM: Below ", MinMomentumPips, "p threshold");
         return false;
      }
   }
   
   return true;
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

bool IsVolumeRatioOK()
{
   // Fixed volume ratio check using completed bars only
   long current_vol = iTickVolume(Symbol(), PERIOD_CURRENT, 1); // Use bar 1 (completed)
   
   // Get average volume of last 5 completed bars
   double avg_volume = 0.0;
   for(int i = 2; i <= 6; i++) // bars 2-6 (all completed)
   {
      avg_volume += (double)iTickVolume(Symbol(), PERIOD_CURRENT, i);
   }
   avg_volume /= 5.0;
   
   if(avg_volume <= 0) return true; // Avoid division by zero
   
   double volume_ratio = (double)current_vol / avg_volume;
   return volume_ratio >= VolumeRatioMin;
}

bool IsMomentumOK()
{
   // Check momentum over last 3 bars
   double high_3 = iHigh(Symbol(), PERIOD_CURRENT, 3);
   double low_3 = iLow(Symbol(), PERIOD_CURRENT, 3);
   double high_1 = iHigh(Symbol(), PERIOD_CURRENT, 1);
   double low_1 = iLow(Symbol(), PERIOD_CURRENT, 1);
   
   double momentum_range = MathMax(high_1 - low_3, high_3 - low_1);
   double momentum_pips = momentum_range / Pip();
   
   return momentum_pips >= MinMomentumPips;
}

//=== QUALITY PTG SIGNALS ===
void CheckQualityPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsQualityPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 500 == 0)
         Print("🔥 QUALITY PUSH #", signal_count, " detected");
      
      CheckQualityTestAndGo();
   }
}

bool IsQualityPushDetected() 
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
   
   // Quality PTG criteria (stricter than moderate)
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

void CheckQualityTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   
   // Quality filtering (stricter)
   if(!IsQualityATROK()) return;
   if(!IsQualityEntryOK()) return;
   
   ExecuteQualityEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== QUALITY TRADE EXECUTION ===
void ExecuteQualityEntry(bool is_long) 
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
   req.comment = "PTG Quality v3.1.5";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ QUALITY ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG Quality ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ QUALITY ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== QUALITY POSITION MANAGEMENT (FIXED PROFIT CALCULATION) ===
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

void ManageQualityPosition() 
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
   
   // Quality partial TP (better R:R)
   if(!partial_tp_taken && profit_pips >= QualityPartialPips) 
   {
      TakeQualityPartialProfit();
      return;
   }
   
   // Quality breakeven  
   if(!breakeven_activated && profit_pips >= QualityBEPips) 
   {
      MoveToQualityBreakeven();
      return;
   }
   
   // Quality trailing (let winners run)
   if(breakeven_activated && profit_pips >= TrailStartPips) 
   {
      TrailQualityStopLoss(profit_pips);
   }
}

void TakeQualityPartialProfit() 
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
   req.comment = "Quality Partial " + DoubleToString(QualityPartialPips, 1) + "p";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 QUALITY PARTIAL: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(QualityPartialPips, 1), "p (", DoubleToString(PartialPercent, 0), "%)");
   }
}

void MoveToQualityBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Quality breakeven with spread buffer
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
         Print("🛡️ QUALITY BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(QualityBEPips, 1), "p trigger)");
   }
}

void TrailQualityStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Quality trailing: wider step to let winners run
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move if significant improvement
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
      
      if(OrderSend(req, res) && EnableDebugLogs) 
      {
         Print("📈 QUALITY TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
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
               Print("🎯 QUALITY FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - track losses for quality circuit breaker
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / Pip() :
                            (original_entry_price - trans.price) / Pip();
               
               // Update quality loss tracking
               if(profit_pips < -2.0) // Consider < -2 pip as loss
               {
                  UpdateQualityLossHistory(-profit_pips);
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 QUALITY EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
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
   
   Print("💎 PTG QUALITY v3.1.5 STOPPED - FIXED BUGS + STRICTER QUALITY COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Circuit Breaker Stats: 60min=", loss_count_60min, " | Daily=", loss_count_daily);
   Print("🎯 QUALITY APPROACH: Fixed Profit Calc + Stricter Filters = BETTER WIN RATE!");
}
