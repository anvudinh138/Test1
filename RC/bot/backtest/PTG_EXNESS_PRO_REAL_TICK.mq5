//+------------------------------------------------------------------+
//|                     PTG EXNESS PRO - REAL TICK OPTIMIZED        |
//|               Enhanced for "Every tick based on real ticks"     |
//|                    Better Spread/Slippage Handling             |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "2.10"
#property description "PTG Real Tick Optimized - Enhanced for actual market conditions"

//=== INPUTS ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA 34/55 trend filter
input int      LookbackPeriod     = 10;                // Lookback for range & volSMA

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // Range >= 35% 
input double   ClosePercent       = 0.45;              // Close pos 45%
input double   OppWickPercent     = 0.65;              // Opp wick <= 65%
input double   VolHighMultiplier  = 1.0;               // Vol >= 100%

input group "=== TEST PARAMETERS ==="
input int      TestBars           = 10;                // Allow TEST within X bars
input int      PendingTimeout     = 3;                 // Remove pendings after X bars (tighter for real tick)
input double   PullbackMax        = 0.85;              // Pullback <= 85% push range
input double   VolLowMultiplier   = 2.0;               // Vol TEST <= 200%

input group "=== REAL TICK ADAPTATIONS ==="
// Adaptive spread & slippage handling for real market conditions
input double   MaxSpreadPips      = 15.0;              // Max spread in pips (fixed for Gold real tick)
input double   MaxSlippagePips    = 5.0;               // Higher slippage tolerance for real tick
input bool     UseMarketEntry     = true;              // Use MARKET orders instead of STOP orders (less slippage)
input bool     UseSpreadFilter    = true;              // Skip trades when spread too high
input bool     AdaptiveSpread     = false;             // Use adaptive spread (experimental)
input double   VolatilityBuffer   = 1.5;               // Extra buffer during high volatility

input group "=== ENHANCED RISK MANAGEMENT ==="
input bool     UseFixedLotSize    = true;              
input double   FixedLotSize       = 0.10;              
input double   MaxRiskPips        = 80.0;              // Max risk per trade (real tick protection - Gold needs wider)
input bool     UseATRStops        = false;             // Use ATR-based stops (disabled for Gold - too wide)
input int      ATRPeriod          = 14;                // ATR period for stops
input double   ATRMultiplier      = 1.3;               // ATR multiplier for SL (reduced from 2.0)

input group "=== POSITION MANAGEMENT ==="
input double   BreakevenPips      = 10.0;              // Wider BE for real tick
input double   PartialTPPips      = 20.0;              // Wider partial TP
input double   PartialTPPercent   = 30.0;              // % close at partial TP
input double   TrailStepPips      = 15.0;              // Wider trail step
input double   MinProfitPips      = 8.0;               // Higher min profit for trail

input group "=== ENTRY OPTIMIZATION ==="
input bool     UseEntryConfirmation = false;           // Wait for confirmation (disabled - too strict for real tick)
input int      ConfirmationBars   = 2;                 // Bars to wait for confirmation
input double   MinMomentumPips    = 1.5;               // Min movement for entry confirmation (reduced)
input double   EntryDelayMS       = 200;               // Delay before entry (ms) to avoid spikes (reduced)

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;         
input int      MinBarsBetweenTrades   = 3;             // More spacing for real tick
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v2.1.0-RealTick-GoldOptimized";

//=== GLOBAL VARIABLES ===
int magic_number = 88888;  // Different magic for real tick version
ulong active_position_ticket = 0;
ulong last_order_ticket = 0;
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

// Real tick specific variables
int atr_handle = INVALID_HANDLE;
bool confirmation_pending = false;
datetime confirmation_time = 0;
double confirmation_entry_price = 0.0;
bool confirmation_is_long = false;

//=== INITIALIZATION ===
int OnInit()
{
   pip_size = Point();
   if(Digits() == 5 || Digits() == 3) pip_size *= 10;
   
   // Initialize ATR indicator
   if(UseATRStops)
   {
      atr_handle = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod);
      if(atr_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create ATR indicator");
         return INIT_FAILED;
      }
   }
   
   Print("🚀 PTG REAL TICK v2.1.0 STARTED - GOLD OPTIMIZED!");
   Print("📊 Pip Size: ", pip_size, " | Magic: ", magic_number);
   Print("⚡ Real Tick Settings: Market Entry=", UseMarketEntry, " | Confirmation=", UseEntryConfirmation);
   Print("📈 Spread: Max=", MaxSpreadPips, "p | Risk: Max=", MaxRiskPips, "p");
   Print("🛡️ SL Method: ATR=", UseATRStops, " | Multiplier=", ATRMultiplier);
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick()
{
   if(!IsMarketConditionsOK()) return;
   
   // Update position info
   UpdatePositionInfo();
   
   // Handle entry confirmation
   if(confirmation_pending)
   {
      HandleEntryConfirmation();
      return;
   }
   
   // Manage existing positions
   if(active_position_ticket > 0)
   {
      ManageEnhancedPosition();
      bars_since_entry++;
      return;
   }
   
   // Look for new PTG signals
   CheckPTGSignals();
   
   // Clean up old pending orders
   CheckPendingOrderTimeout();
}

//=== REAL TICK SPECIFIC FUNCTIONS ===

bool IsSpreadAcceptable()
{
   if(!UseSpreadFilter) return true;
   
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / pip_size;
   
   double max_acceptable;
   
   if(AdaptiveSpread)
   {
      // Use adaptive spread (experimental) - default for Gold
      double avg_spread = 8.0; // Typical Gold spread
      max_acceptable = avg_spread * 2.5; // = 20.0 pips
   }
   else
   {
      // Use fixed max spread for Gold real tick
      max_acceptable = MaxSpreadPips;
   }
   
   bool acceptable = current_spread <= max_acceptable;
   
   if(!acceptable && EnableDebugLogs)
      Print("⚠️ SPREAD TOO HIGH: ", DoubleToString(current_spread, 1), 
            " > ", DoubleToString(max_acceptable, 1), " pips");
   
   return acceptable;
}

bool IsMarketConditionsOK()
{
   // Basic trading check
   if(!IsSpreadAcceptable()) return false;
   
   // Check for news/high volatility periods
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double current_spread = (ask - bid) / pip_size;
   
   // Skip if spread is extremely high (news period)
   if(current_spread > 50.0)
   {
      if(EnableDebugLogs)
         Print("🚨 EXTREME SPREAD DETECTED: ", DoubleToString(current_spread, 1), " pips - Skipping");
      return false;
   }
   
   return true;
}

void HandleEntryConfirmation()
{
   if(!confirmation_pending) return;
   
   // Check if confirmation period has passed
   if(TimeCurrent() - confirmation_time < EntryDelayMS / 1000) return;
   
   double current_price = confirmation_is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Check if price has moved favorably
   double price_movement = confirmation_is_long ?
                          (current_price - confirmation_entry_price) / pip_size :
                          (confirmation_entry_price - current_price) / pip_size;
   
   if(price_movement >= MinMomentumPips)
   {
      // Execute market entry
      ExecuteMarketEntry(confirmation_is_long);
   }
   else if(EnableDebugLogs)
   {
      Print("❌ CONFIRMATION FAILED: Movement ", DoubleToString(price_movement, 1), 
            "p < ", DoubleToString(MinMomentumPips, 1), "p required");
   }
   
   // Reset confirmation
   confirmation_pending = false;
}

//=== POSITION MANAGEMENT ===
void UpdatePositionInfo()
{
   active_position_ticket = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) && PositionGetInteger(POSITION_MAGIC) == magic_number)
      {
         active_position_ticket = PositionGetInteger(POSITION_TICKET);
         remaining_volume = PositionGetDouble(POSITION_VOLUME);
         break;
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
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / pip_size :
                       (original_entry_price - current_price) / pip_size;
   
   // Enhanced time-stop for real tick
   if(bars_since_entry >= 25 && profit_pips < MinProfitPips)
   {
      ClosePositionAtMarket("Real Tick Time-stop: No progress after 25 bars");
      return;
   }
   
   // Partial TP
   if(!partial_tp_taken && profit_pips >= PartialTPPips)
   {
      TakePartialProfit();
      return;
   }
   
   // Breakeven
   if(!breakeven_activated && profit_pips >= BreakevenPips)
   {
      MoveSLToBreakeven();
      return;
   }
   
   // Enhanced trailing for real tick
   if(breakeven_activated && profit_pips > BreakevenPips + TrailStepPips)
   {
      TrailStopLoss(profit_pips);
   }
}

void TakePartialProfit()
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
   req.comment = "RT Partial TP " + DoubleToString(PartialTPPips, 1) + "p";
   req.deviation = (int)(MaxSlippagePips * 10); // Higher slippage tolerance
   
   if(OrderSend(req, res))
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 REAL TICK PARTIAL TP: ", DoubleToString(close_volume, 2), " lots @ +", 
               DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveSLToBreakeven()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double be_price = original_entry_price + (is_long ? 2*pip_size : -2*pip_size); // +2 pips buffer for real tick
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_SLTP;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.sl = NormalizeDouble(be_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = PositionGetDouble(POSITION_TP);
   
   if(OrderSend(req, res))
   {
      breakeven_activated = true;
      if(EnableDebugLogs)
         Print("🛡️ REAL TICK BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
   }
}

void TrailStopLoss(double profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // More conservative trailing for real tick
   double trail_distance = profit_pips - MinProfitPips - 5.0; // Extra buffer
   double new_sl = is_long ? 
                   original_entry_price + trail_distance * pip_size :
                   original_entry_price - trail_distance * pip_size;
   
   if((is_long && new_sl > current_sl + 3*pip_size) || 
      (!is_long && new_sl < current_sl - 3*pip_size)) // Only move if significant improvement
   {
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      
      req.action = TRADE_ACTION_SLTP;
      req.symbol = Symbol();
      req.position = active_position_ticket;
      req.sl = NormalizeDouble(new_sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
      req.tp = PositionGetDouble(POSITION_TP);
      
      if(OrderSend(req, res))
      {
         if(EnableDebugLogs)
            Print("📈 REAL TICK TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Profit: +", 
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
   req.deviation = (int)(MaxSlippagePips * 10);
   
   if(OrderSend(req, res))
   {
      ResetTradeState();
      if(EnableDebugLogs)
         Print("🔚 REAL TICK CLOSE: ", reason);
   }
}

//=== PTG SIGNAL DETECTION ===
void CheckPTGSignals()
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected())
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 100 == 0)
         Print("🔥 REAL TICK PUSH #", signal_count, " detected");
      
      CheckTestAndGo();
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
   
   bool range_criteria = current_range >= avg_range * PushRangePercent;
   bool volume_criteria = (double)volume[0] >= avg_volume * VolHighMultiplier;
   
   double body_size = MathAbs(close[0] - iOpen(Symbol(), PERIOD_CURRENT, 1));
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

void CheckTestAndGo()
{
   bool is_bullish = IsBullishContext();
   
   if(UseEntryConfirmation)
   {
      // Set up confirmation for market entry
      confirmation_pending = true;
      confirmation_time = TimeCurrent();
      confirmation_is_long = is_bullish;
      confirmation_entry_price = is_bullish ? 
                                 SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                                 SymbolInfoDouble(Symbol(), SYMBOL_BID);
      
      if(EnableDebugLogs)
         Print("⏳ REAL TICK CONFIRMATION: Waiting ", DoubleToString(EntryDelayMS/1000.0, 1), 
               "s for ", (is_bullish ? "LONG" : "SHORT"), " confirmation");
   }
   else
   {
      // Immediate market entry (no confirmation)
      ExecuteMarketEntry(is_bullish);
   }
}

bool IsBullishContext()
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== TRADE EXECUTION ===
void ExecuteMarketEntry(bool is_long)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   double entry_price = is_long ? 
                       SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                       SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Enhanced SL calculation for real tick
   double sl_price = CalculateEnhancedSL(is_long, entry_price);
   double sl_distance_pips = MathAbs(entry_price - sl_price) / pip_size;
   
   // Risk check for real tick
   if(sl_distance_pips > MaxRiskPips)
   {
      if(EnableDebugLogs)
         Print("❌ REAL TICK: Risk too high ", DoubleToString(sl_distance_pips, 1), 
               "p > ", DoubleToString(MaxRiskPips, 1), "p");
      return;
   }
   
   double lot_size = CalculateOptimalLotSize(sl_distance_pips);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.volume = lot_size;
   req.type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = entry_price;
   req.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "RT PTG " + DoubleToString(sl_distance_pips, 1) + "p";
   req.deviation = (int)(MaxSlippagePips * 10);
   
   if(OrderSend(req, res))
   {
      last_trade_bar = current_bar;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ REAL TICK ENTRY: ", direction, " ", DoubleToString(lot_size, 2), 
               " @ ", DoubleToString(entry_price, 5), " | SL: ", DoubleToString(sl_price, 5), 
               " | Risk: ", DoubleToString(sl_distance_pips, 1), "p");
      
      if(EnableAlerts)
         Alert("PTG REAL TICK ", direction, " ENTRY @", DoubleToString(entry_price, 5));
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ REAL TICK ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

double CalculateEnhancedSL(bool is_long, double entry_price)
{
   double sl_price;
   
   if(UseATRStops && atr_handle != INVALID_HANDLE)
   {
      double atr_values[];
      ArraySetAsSeries(atr_values, true);
      
      if(CopyBuffer(atr_handle, 0, 1, 1, atr_values) > 0)
      {
         double atr = atr_values[0];
         sl_price = is_long ? 
                    entry_price - (atr * ATRMultiplier) :
                    entry_price + (atr * ATRMultiplier);
         
         if(EnableDebugLogs)
            Print("🔧 Using ATR SL: ATR=", DoubleToString(atr, 5), 
                  " | Multiplier=", ATRMultiplier);
      }
      else
      {
         sl_price = CalculateSwingSL(is_long, entry_price);
      }
   }
   else
   {
      sl_price = CalculateSwingSL(is_long, entry_price);
   }
   
   return sl_price;
}

double CalculateSwingSL(bool is_long, double entry_price)
{
   double swing_low = entry_price;
   double swing_high = entry_price;
   
   for(int i = 1; i <= 20; i++)
   {
      double high_i = iHigh(Symbol(), PERIOD_CURRENT, i);
      double low_i = iLow(Symbol(), PERIOD_CURRENT, i);
      
      if(low_i < swing_low) swing_low = low_i;
      if(high_i > swing_high) swing_high = high_i;
   }
   
   double sl_price;
   if(is_long)
   {
      sl_price = swing_low - (VolatilityBuffer * pip_size);
   }
   else
   {
      sl_price = swing_high + (VolatilityBuffer * pip_size);
   }
   
   return sl_price;
}

double CalculateOptimalLotSize(double sl_distance_pips)
{
   if(UseFixedLotSize) return FixedLotSize;
   
   // Dynamic lot sizing based on SL distance
   double base_lot = 0.10;
   double risk_ratio = sl_distance_pips / 30.0; // Normalize to 30 pips
   double adjusted_lot = base_lot / MathMax(risk_ratio, 1.0);
   
   double min_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   return MathMax(min_vol, MathMin(max_vol, MathFloor(adjusted_lot / step) * step));
}

//=== UTILITY FUNCTIONS ===
void CheckPendingOrderTimeout()
{
   if(last_order_ticket == 0) return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) && OrderGetInteger(ORDER_TICKET) == last_order_ticket)
      {
         datetime order_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         int bars_elapsed = iBarShift(Symbol(), PERIOD_CURRENT, order_time);
         
         if(bars_elapsed >= PendingTimeout)
         {
            MqlTradeRequest req;
            MqlTradeResult res;
            ZeroMemory(req);
            ZeroMemory(res);
            
            req.action = TRADE_ACTION_REMOVE;
            req.order = last_order_ticket;
            
            if(OrderSend(req, res))
            {
               if(EnableDebugLogs)
                  Print("⏰ REAL TICK TIMEOUT: Removed pending #", last_order_ticket);
               last_order_ticket = 0;
            }
         }
         return;
      }
   }
   
   last_order_ticket = 0;
}

void ResetTradeState()
{
   active_position_ticket = 0;
   bars_since_entry = 0;
   original_entry_price = 0.0;
   breakeven_activated = false;
   partial_tp_taken = false;
   remaining_volume = 0.0;
   confirmation_pending = false;
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
               Print("🎯 REAL TICK FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         }
         // Exit
         else
         {
            double profit_pips = 0.0;
            if(original_entry_price > 0)
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / pip_size :
                            (original_entry_price - trans.price) / pip_size;
            }
            
            if(EnableDebugLogs)
               Print("💰 REAL TICK EXIT: ", (profit_pips >= 0 ? "+" : ""), 
                     DoubleToString(profit_pips, 1), " pips");
            
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
   
   Print("🚀 PTG REAL TICK v2.1.0 STOPPED - GOLD OPTIMIZED");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("⚡ Real Tick Adaptations: COMPLETE");
}
