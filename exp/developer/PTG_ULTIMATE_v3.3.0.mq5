//+------------------------------------------------------------------+
//|                    PTG ULTIMATE v3.3.0                          |
//|     Ultimate Strategy: UseCase 2 Conservative + ChatGPT Insights|
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.30"
#property description "PTG v3.3.0 - ULTIMATE: Conservative success + dynamic ATR insights"

//=== ULTIMATE INPUTS (Best of Both Worlds) ===
input group "=== CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // Core lookback period

input group "=== ULTIMATE CONSERVATIVE PUSH ==="
input double   PushRangePercent   = 0.45;              // ULTRA STRICT: 45% (vs 40% UseCase 2)
input double   ClosePercent       = 0.55;              // ULTRA STRICT: 55% (vs 50% UseCase 2)
input double   OppWickPercent     = 0.45;              // ULTRA STRICT: 45% (vs 50% UseCase 2)
input double   VolHighMultiplier  = 1.30;              // ULTRA STRICT: 1.30× (vs 1.25× UseCase 2)

input group "=== CHATGPT INSPIRED ATR FILTERING ==="
input double   MaxSpreadPips      = 10.0;              // ULTRA TIGHT: 10p (vs 12p UseCase 2)
input bool     UseATRFilter       = true;              // NEW: ChatGPT inspired ATR filtering
input double   MinATRPips         = 40.0;              // Minimum ATR for quality signals
input double   MaxATRPips         = 80.0;              // Maximum ATR to avoid chaos
input bool     UseSessionFilter   = true;              // PROVEN: Strategic session
input int      SessionStartHour   = 9;                 // PEAK HOURS: 9:00-15:00 (vs 8-16)
input int      SessionEndHour     = 15;                // London/NY overlap only
input bool     UseMomentumFilter  = true;              // PROVEN: Quality filter
input double   MomentumThresholdPips = 10.0;           // ULTRA HIGH: 10p momentum (vs 8p)

input group "=== CHATGPT INSPIRED REGIME FILTERS ==="
input bool     UseRoundNumberFilter = true;            // NEW: From ChatGPT insights
input double   RoundNumberBufferPips = 8.0;            // Avoid major round numbers
input bool     UseVolatilityRegime = true;             // NEW: Volatility regime detection
input double   LowVolThresholdPips = 35.0;             // Low volatility threshold
input double   HighVolThresholdPips = 70.0;            // High volatility threshold

input group "=== ULTIMATE CONSERVATIVE EXITS ==="
input double   FixedSLPips        = 18.0;              // ULTRA TIGHT: 18p (vs 20p UseCase 2)
input bool     UseEarlyBreakeven  = true;              // PROVEN: Protection
input double   EarlyBEPips        = 22.0;              // EARLIER: 22p (vs 25p UseCase 2)
input bool     UsePartialTP       = true;              // NEW: Partial TP for safety
input double   PartialTPPips      = 35.0;              // 35p partial TP
input double   PartialTPPercent   = 0.50;              // Close 50% at partial TP
input bool     UseTrailing        = true;              // PROVEN: Let remaining run
input double   TrailStartPips     = 45.0;              // EARLIER: 45p (vs 40p UseCase 2)
input double   TrailStepPips      = 18.0;              // TIGHTER: 18p (vs 20p UseCase 2)

input group "=== ULTIMATE CONSERVATIVE PROTECTION ==="
input bool     UseTimeBasedExit   = true;              // PROVEN: Time management
input int      MaxHoldingHours    = 6;                 // SHORTER: 6h (vs 8h UseCase 2)
input int      MinProfitForHold   = 15;                // HIGHER: 15p (vs 12p UseCase 2)
input bool     UseCircuitBreaker  = true;              // PROVEN: Protection
input int      MaxConsecutiveLosses = 3;               // ULTRA CONSERVATIVE: 3 (vs 5 UseCase 2)
input int      CooldownMinutes    = 90;                // LONGER: 90min (vs 60min UseCase 2)
input bool     UseDailyLossLimit  = true;              // NEW: Daily loss protection
input double   MaxDailyLossPips   = 50.0;              // Max 50p loss per day
input int      DailyLossResetHour = 0;                 // Reset at midnight

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.3.0-Ultimate";

//=== GLOBAL VARIABLES ===
int magic_number = 33000;  // v3.3.0 magic number
ulong active_position_ticket = 0;
int bars_since_entry = 0;
datetime entry_time = 0;
int last_signal_bar = -1;
int last_trade_bar = -1;
double original_entry_price = 0.0;
double pip_size = 0.0;
bool breakeven_activated = false;
bool trailing_activated = false;
bool partial_tp_taken = false;
double remaining_volume = 0.0;
int signal_count = 0;
int trade_count = 0;

// Ultimate protection
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;
double daily_loss_pips = 0.0;
datetime daily_reset_time = 0;

// ATR for dynamic filtering
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
   daily_reset_time = TimeCurrent();
   
   // Initialize ATR
   atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("❌ Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   Print("🏆 PTG ULTIMATE v3.3.0 - CONSERVATIVE SUCCESS + CHATGPT INSIGHTS!");
   Print("🛡️ ULTRA CONSERVATIVE: Push=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("📊 CHATGPT INSPIRED: ATR=", (UseATRFilter ? DoubleToString(MinATRPips, 0) + "-" + DoubleToString(MaxATRPips, 0) + "p" : "OFF"), 
         " | Session=", SessionStartHour, "-", SessionEndHour, " | Momentum=", MomentumThresholdPips, "p");
   Print("🎯 ULTRA PROTECTION: SL=", FixedSLPips, "p | BE=", EarlyBEPips, "p | Partial=", (UsePartialTP ? DoubleToString(PartialTPPips, 0) + "p" : "OFF"));
   Print("🔴 ULTIMATE SAFETY: MaxLoss=", MaxConsecutiveLosses, " | Cooldown=", CooldownMinutes, "min | Daily=", MaxDailyLossPips, "p");
   Print("🏆 ULTIMATE GOAL: Maximum survivability + proven profitability!");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   UpdateATR();
   ResetDailyLoss();
   
   if(!IsUltimateMarketOK()) return;
   if(IsInBlackoutPeriod()) return;  
   if(UseSessionFilter && !IsInTradingSession()) return;
   if(IsInCircuitBreaker()) return;
   if(UseDailyLossLimit && IsInDailyLossLimit()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageUltimatePosition();
      bars_since_entry++;
      return;
   }
   
   CheckUltimatePTGSignals();
}

//=== ULTIMATE FILTERING SYSTEM ===
void UpdateATR()
{
   if(atr_handle == INVALID_HANDLE) return;
   
   double atr_buffer[1];
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
   {
      current_atr_pips = atr_buffer[0] / Pip();
   }
}

void ResetDailyLoss()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour == DailyLossResetHour && TimeCurrent() >= daily_reset_time + 24*3600)
   {
      daily_loss_pips = 0.0;
      daily_reset_time = TimeCurrent();
      if(EnableDebugLogs)
         Print("🔄 DAILY LOSS RESET: New trading day");
   }
}

bool IsUltimateMarketOK() 
{
   // Ultra tight spread check
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ SPREAD TOO HIGH: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   // ChatGPT inspired ATR filtering
   if(UseATRFilter && current_atr_pips > 0)
   {
      if(current_atr_pips < MinATRPips || current_atr_pips > MaxATRPips)
      {
         if(EnableDebugLogs && signal_count % 1000 == 0)
            Print("⚠️ ATR OUT OF RANGE: ", DoubleToString(current_atr_pips, 1), "p (", MinATRPips, "-", MaxATRPips, ")");
         return false;
      }
   }
   
   // ChatGPT inspired volatility regime
   if(UseVolatilityRegime && current_atr_pips > 0)
   {
      if(current_atr_pips < LowVolThresholdPips)
      {
         if(EnableDebugLogs && signal_count % 1000 == 0)
            Print("⚠️ LOW VOLATILITY REGIME: ", DoubleToString(current_atr_pips, 1), "p < ", LowVolThresholdPips, "p");
         return false;
      }
      
      if(current_atr_pips > HighVolThresholdPips)
      {
         if(EnableDebugLogs && signal_count % 1000 == 0)
            Print("⚠️ HIGH VOLATILITY REGIME: ", DoubleToString(current_atr_pips, 1), "p > ", HighVolThresholdPips, "p");
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
   
   // Ultra conservative session (peak hours only)
   bool in_session = (dt.hour >= SessionStartHour && dt.hour < SessionEndHour);
   
   if(!in_session && EnableDebugLogs && signal_count % 1000 == 0)
      Print("💤 OUT OF PEAK SESSION: ", IntegerToString(dt.hour), ":00 (", SessionStartHour, "-", SessionEndHour, ")");
   
   return in_session;
}

bool IsInBlackoutPeriod()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Standard rollover blackout
   bool in_blackout = ((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0 && dt.min <= 10));
   
   return in_blackout;
}

bool IsInCircuitBreaker()
{
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 CIRCUIT BREAKER: Active until ", TimeToString(circuit_breaker_until));
      return true;
   }
   
   return false;
}

bool IsInDailyLossLimit()
{
   if(daily_loss_pips >= MaxDailyLossPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 DAILY LOSS LIMIT: ", DoubleToString(daily_loss_pips, 1), "p >= ", MaxDailyLossPips, "p");
      return true;
   }
   
   return false;
}

void ActivateCircuitBreaker()
{
   if(consecutive_losses >= MaxConsecutiveLosses)
   {
      circuit_breaker_until = TimeCurrent() + CooldownMinutes * 60;
      
      if(EnableDebugLogs)
         Print("🔴 ULTIMATE BREAKER: ", consecutive_losses, " losses → ", 
               CooldownMinutes, "min until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0;
   }
}

bool IsNearRoundNumber(double price)
{
   if(!UseRoundNumberFilter) return false;
   
   // ChatGPT inspired round number logic
   double major_levels[] = {3200.0, 3300.0, 3400.0, 3500.0, 3600.0, 3700.0, 3800.0};
   double minor_levels[] = {3250.0, 3350.0, 3450.0, 3550.0, 3650.0, 3750.0};
   
   double buffer = PriceFromPips(RoundNumberBufferPips);
   
   // Check major levels
   for(int i = 0; i < ArraySize(major_levels); i++)
   {
      if(MathAbs(price - major_levels[i]) <= buffer)
         return true;
   }
   
   // Check minor levels
   for(int i = 0; i < ArraySize(minor_levels); i++)
   {
      if(MathAbs(price - minor_levels[i]) <= buffer)
         return true;
   }
   
   return false;
}

//=== ULTIMATE PTG SIGNALS ===
void CheckUltimatePTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsUltimatePushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 100 == 0)
         Print("🏆 ULTIMATE PUSH #", signal_count, " | ATR: ", DoubleToString(current_atr_pips, 1), "p");
      
      CheckUltimateTestAndGo();
   }
}

bool IsUltimatePushDetected() 
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
   
   // ULTIMATE criteria (ultra strict)
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
   
   // Ultra high momentum filter
   bool momentum_ok = true;
   if(UseMomentumFilter)
   {
      double momentum_pips = MathAbs(close[0] - close[1]) / Pip();
      momentum_ok = momentum_pips >= MomentumThresholdPips;
   }
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok && momentum_ok;
}

void CheckUltimateTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   
   double entry_price = is_bullish ? 
                       SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                       SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // ChatGPT inspired round number check
   if(IsNearRoundNumber(entry_price))
   {
      if(EnableDebugLogs)
         Print("⚠️ ULTIMATE FILTER: Near round number @ ", DoubleToString(entry_price, 5));
      return;
   }
   
   ExecuteUltimateEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== ULTIMATE TRADE EXECUTION ===
void ExecuteUltimateEntry(bool is_long) 
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
   req.comment = "PTG Ultimate v3.3.0";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ ULTIMATE ENTRY: ", direction, " @ ", DoubleToString(current_price, 5), 
               " | ATR: ", DoubleToString(current_atr_pips, 1), "p");
      
      if(EnableAlerts)
         Alert("PTG Ultimate ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ ULTIMATE ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== ULTIMATE POSITION MANAGEMENT ===
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

void ManageUltimatePosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // Ultimate time management
   if(UseTimeBasedExit)
   {
      int holding_hours = (int)((TimeCurrent() - entry_time) / 3600);
      if(holding_hours >= MaxHoldingHours)
      {
         if(profit_pips >= MinProfitForHold)
         {
            CloseUltimatePosition("Ultimate time exit - " + IntegerToString(holding_hours) + "h");
            return;
         }
      }
   }
   
   // Ultimate early breakeven
   if(UseEarlyBreakeven && !breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToUltimateBreakeven();
      return;
   }
   
   // Ultimate partial TP
   if(UsePartialTP && !partial_tp_taken && profit_pips >= PartialTPPips) 
   {
      TakePartialTP();
      return;
   }
   
   // Ultimate trailing
   if(UseTrailing && !trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("🏆 ULTIMATE TRAILING: Profit ", DoubleToString(profit_pips, 1), "p >= ", TrailStartPips, "p");
   }
   
   if(UseTrailing && trailing_activated && profit_pips >= TrailStartPips) 
   {
      TrailUltimateStopLoss(profit_pips);
   }
}

void MoveToUltimateBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(5.0)) :
                     (original_entry_price - spread - PriceFromPips(5.0));
   
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
         Print("🛡️ ULTIMATE BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(EarlyBEPips, 1), "p trigger)");
   }
}

void TakePartialTP() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double partial_volume = PositionGetDouble(POSITION_VOLUME) * PartialTPPercent;
   partial_volume = NormalizeDouble(partial_volume, 2);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.volume = partial_volume;
   req.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.magic = magic_number;
   req.comment = "Ultimate Partial TP";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume -= partial_volume;
      
      if(EnableDebugLogs)
         Print("💰 ULTIMATE PARTIAL TP: ", DoubleToString(partial_volume, 2), " @ +", 
               DoubleToString(PartialTPPips, 1), "p");
   }
}

void TrailUltimateStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
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
         Print("📈 ULTIMATE TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(TrailStepPips, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

void CloseUltimatePosition(string reason) 
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
         Print("🔚 ULTIMATE CLOSE: ", reason);
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
            partial_tp_taken = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🏆 ULTIMATE FILLED: ", direction, " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - ultimate loss tracking
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // Ultimate loss tracking
               if(profit_pips < -3.0)
               {
                  consecutive_losses++;
                  daily_loss_pips += MathAbs(profit_pips);
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 8.0)
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 ULTIMATE EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Losses: ", consecutive_losses, " | Daily: ", DoubleToString(daily_loss_pips, 1), "p");
            
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
   
   Print("🏆 PTG ULTIMATE v3.3.0 STOPPED - CONSERVATIVE SUCCESS + CHATGPT INSIGHTS COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Daily Loss: ", DoubleToString(daily_loss_pips, 1), "p");
   Print("🏆 ULTIMATE PHILOSOPHY: Maximum survivability + proven profitability + ChatGPT wisdom!");
}
