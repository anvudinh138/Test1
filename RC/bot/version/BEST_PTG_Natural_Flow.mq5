//+------------------------------------------------------------------+
//|                        PTG Natural Flow v1.5.0                  |
//|               Let PTG Breathe - No Artificial Limits           |
//|                    Pure PTG Strategy Implementation            |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.50"
#property description "PTG Natural Flow - Pure PTG without artificial constraints"

//=== INPUTS ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // (chưa dùng)
input int      LookbackPeriod     = 10;                // Lookback for range & volSMA

input group "=== PUSH PARAMETERS (NATURAL) ==="
input double   PushRangePercent   = 0.35;              // Range >= 35% (quality)
input double   ClosePercent       = 0.45;              // Close pos 45% (momentum)
input double   OppWickPercent     = 0.65;              // Opp wick <= 65% (strict)
input double   VolHighMultiplier  = 1.0;               // Vol >= 100% (confirm)

input group "=== TEST PARAMETERS (NATURAL) ==="
input int      TestBars           = 10;                // Allow TEST within X bars
input int      PendingTimeout     = 5;                 // Remove pendings after X bars
input double   PullbackMax        = 0.85;              // Pullback <= 85% push range
input double   VolLowMultiplier   = 2.0;               // Vol TEST <= 200%

input group "=== NATURAL PTG MANAGEMENT ==="
// Let PTG signals run naturally with smart management
input double   BreakevenPips      = 8.0;               // +X pips => move SL to BE (wider for natural flow)
input double   PartialTPPips      = 15.0;              // Take 30% profit at +X pips
input double   PartialTPPercent   = 30.0;              // % of position to close at partial TP
input double   TrailStepPips      = 15.0;              // Trail step (wider for big moves)
input double   MinProfitPips      = 5.0;               // Min profit to keep when trailing
input int      MaxBarsInTrade     = 20;                // Time-stop: close if no progress

input group "=== ENTRY OPTIMIZATION ==="
// Tighter entries while keeping natural SLs
input double   EntryBufferPips    = 1.0;               // Entry buffer (tighter)
input double   SLBufferPips       = 2.0;               // SL buffer (keep original SL intent)
input double   MaxSlippagePips    = 3.0;               // Max acceptable slippage

input group "=== RISK MANAGEMENT (NATURAL) ==="
input bool     UseFixedLotSize    = true;              // Fixed lot (recommended)
input double   FixedLotSize       = 0.10;              // 0.10 lot ~ $1/pip with Gold
input double   MaxSpreadPips      = 30.0;              // Higher spread tolerance
input bool     AllowWideStops     = true;              // Allow natural wide stops

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // true=limit hours
input string   StartTime          = "00:00";
input string   EndTime            = "23:59";

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;         // 1 trade at a time
input int      MinBarsBetweenTrades   = 1;             // Min spacing (bars)
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;

input group "=== VERSION CONTROL ==="
input string   BotVersion         = "v1.5.0-NaturalFlow";

//=== GLOBAL VARIABLES ===
int magic_number = 77777;
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

//=== INITIALIZATION ===
int OnInit()
{
   pip_size = Point();
   if(Digits() == 5 || Digits() == 3) pip_size *= 10;
   
   Print("🌊 PTG NATURAL FLOW v1.5.0 STARTED - Let PTG Breathe!");
   Print("📊 Pip Size: ", pip_size, " | Magic: ", magic_number);
   Print("🎯 Natural Management: BE=", BreakevenPips, "p | PartialTP=", PartialTPPips, "p | Trail=", TrailStepPips, "p");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick()
{
   if(!IsTradingAllowed()) return;
   
   // Update active position info
   UpdatePositionInfo();
   
   // Manage existing positions
   if(active_position_ticket > 0)
   {
      ManageNaturalPosition();
      bars_since_entry++;
      return;
   }
   
   // Look for new PTG signals
   CheckPTGSignals();
   
   // Clean up old pending orders
   CheckPendingOrderTimeout();
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

void ManageNaturalPosition()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / pip_size :
                       (original_entry_price - current_price) / pip_size;
   
   // Time-stop: Close if no progress after MaxBarsInTrade
   if(bars_since_entry >= MaxBarsInTrade && profit_pips < MinProfitPips)
   {
      ClosePositionAtMarket("Time-stop: No progress after " + IntegerToString(MaxBarsInTrade) + " bars");
      return;
   }
   
   // Partial TP at target pips
   if(!partial_tp_taken && profit_pips >= PartialTPPips)
   {
      TakePartialProfit();
      return;
   }
   
   // Breakeven when profitable
   if(!breakeven_activated && profit_pips >= BreakevenPips)
   {
      MoveSLToBreakeven();
      return;
   }
   
   // Trail after breakeven
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
   
   // Ensure minimum volume
   double min_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(close_volume < min_vol) close_volume = min_vol;
   
   // Ensure we don't close more than we have
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
   req.comment = "Partial TP " + DoubleToString(PartialTPPips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 PARTIAL TP: Closed ", DoubleToString(close_volume, 2), " lots at +", 
               DoubleToString(PartialTPPips, 1), "p | Remaining: ", DoubleToString(remaining_volume, 2));
      
      if(EnableAlerts)
         Alert("PTG NATURAL 💰 Partial TP: +", DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveSLToBreakeven()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double be_price = original_entry_price + (is_long ? pip_size : -pip_size); // +1 pip for safety
   
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
         Print("🛡️ BREAKEVEN: SL moved to ", DoubleToString(be_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)));
      
      if(EnableAlerts)
         Alert("PTG NATURAL 🛡️ Breakeven activated");
   }
}

void TrailStopLoss(double profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Calculate new trailing SL
   double trail_distance = profit_pips - MinProfitPips;
   double new_sl = is_long ? 
                   original_entry_price + trail_distance * pip_size :
                   original_entry_price - trail_distance * pip_size;
   
   // Only move SL if it's better
   if((is_long && new_sl > current_sl) || (!is_long && new_sl < current_sl))
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
            Print("📈 TRAIL: SL moved to ", DoubleToString(new_sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
                  " | Profit: +", DoubleToString(profit_pips, 1), "p");
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
   
   if(OrderSend(req, res))
   {
      ResetTradeState();
      
      if(EnableDebugLogs)
         Print("🔚 CLOSED: ", reason);
      
      if(EnableAlerts)
         Alert("PTG NATURAL 🔚 ", reason);
   }
}

//=== PTG SIGNAL DETECTION ===
void CheckPTGSignals()
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   // Check for PUSH signal
   if(IsPushDetected())
   {
      signal_count++;
      if(signal_count % 100 == 0)
         Print("🔥 NATURAL PUSH #", signal_count, " detected");
      
      last_signal_bar = current_bar;
      
      // Look for TEST and GO
      CheckTestAndGo();
   }
}

bool IsPushDetected()
{
   if(Bars(Symbol(), PERIOD_CURRENT) < LookbackPeriod + 2) return false;
   
   // Get recent bars data
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
   
   // Calculate range for current bar [0]
   double current_range = high[0] - low[0];
   
   // Calculate average range over lookback period [1 to LookbackPeriod]
   double avg_range = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_range += (high[i] - low[i]);
   avg_range /= LookbackPeriod;
   
   // Calculate average volume
   double avg_volume = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_volume += (double)volume[i];
   avg_volume /= LookbackPeriod;
   
   // PUSH criteria
   bool range_criteria = current_range >= avg_range * PushRangePercent;
   bool volume_criteria = (double)volume[0] >= avg_volume * VolHighMultiplier;
   
   // Direction and momentum criteria
   double body_size = MathAbs(close[0] - iOpen(Symbol(), PERIOD_CURRENT, 1));
   double close_position = (close[0] - low[0]) / current_range;
   
   bool bullish_push = close_position >= ClosePercent;
   bool bearish_push = close_position <= (1.0 - ClosePercent);
   
   // Opposite wick criteria
   double upper_wick = high[0] - MathMax(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1));
   double lower_wick = MathMin(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1)) - low[0];
   
   bool opp_wick_ok = false;
   if(bullish_push) opp_wick_ok = (upper_wick / current_range) <= OppWickPercent;
   if(bearish_push) opp_wick_ok = (lower_wick / current_range) <= OppWickPercent;
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok;
}

void CheckTestAndGo()
{
   // Implementation for TEST and GO detection
   // This would check for pullback (TEST) and breakout (GO)
   // For now, simplified version
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Determine direction based on last PUSH
   bool is_bullish = IsBullishContext();
   
   if(is_bullish)
   {
      ExecuteNaturalTrade(ORDER_TYPE_BUY_STOP, ask + EntryBufferPips * pip_size);
   }
   else
   {
      ExecuteNaturalTrade(ORDER_TYPE_SELL_STOP, bid - EntryBufferPips * pip_size);
   }
}

bool IsBullishContext()
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   
   return close_current > close_prev;
}

//=== TRADE EXECUTION ===
void ExecuteNaturalTrade(ENUM_ORDER_TYPE order_type, double entry_price)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   bool is_long = (order_type == ORDER_TYPE_BUY_STOP);
   
   // Calculate natural SL based on recent swing points
   double sl_price = CalculateNaturalSL(is_long, entry_price);
   double sl_distance_pips = MathAbs(entry_price - sl_price) / pip_size;
   
   // No MaxRiskPips limit - let PTG breathe!
   if(EnableDebugLogs && sl_distance_pips > 50)
      Print("🌊 NATURAL SL: ", DoubleToString(sl_distance_pips, 1), "p (Wide stops allowed)");
   
   // Calculate lot size
   double lot_size = UseFixedLotSize ? FixedLotSize : 0.10;
   
   // Validate lot size
   double min_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lot_size = MathMax(min_vol, MathMin(max_vol, MathFloor(lot_size / step) * step));
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_PENDING;
   req.symbol = Symbol();
   req.volume = lot_size;
   req.type = order_type;
   req.price = NormalizeDouble(entry_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = 0.0; // No TP - let management handle exits
   req.magic = magic_number;
   req.comment = "Natural PTG R:" + DoubleToString(sl_distance_pips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      last_order_ticket = res.order;
      last_trade_bar = current_bar;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ NATURAL PTG: ", direction, " ", DoubleToString(lot_size, 2), " lots | Risk: ", 
               DoubleToString(sl_distance_pips, 1), "p");
      
      if(EnableAlerts)
         Alert("PTG NATURAL ", direction, " @", DoubleToString(entry_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
               " SL@", DoubleToString(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
               " Risk:", DoubleToString(sl_distance_pips, 1), "p");
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ NATURAL TRADE FAILED: ", res.retcode, " - ", res.comment);
   }
}

double CalculateNaturalSL(bool is_long, double entry_price)
{
   // Calculate natural SL based on recent swing points
   double swing_low = entry_price;
   double swing_high = entry_price;
   
   // Look back for swing points
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
      sl_price = swing_low - SLBufferPips * pip_size;
   }
   else
   {
      sl_price = swing_high + SLBufferPips * pip_size;
   }
   
   return sl_price;
}

//=== UTILITY FUNCTIONS ===
bool IsTradingAllowed()
{
   // Check spread
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread_pips = (ask - bid) / pip_size;
   
   if(spread_pips > MaxSpreadPips)
   {
      if(EnableDebugLogs)
         Print("SPREAD TOO HIGH: ", DoubleToString(spread_pips, 1), " > ", DoubleToString(MaxSpreadPips, 1), " pips");
      return false;
   }
   
   // Check time filter
   if(UseTimeFilter)
   {
      datetime current_time = TimeCurrent();
      string current_time_str = TimeToString(current_time, TIME_MINUTES);
      
      if(current_time_str < StartTime || current_time_str > EndTime)
         return false;
   }
   
   return true;
}

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
                  Print("⏰ TIMEOUT: Removed pending order #", last_order_ticket, " after ", PendingTimeout, " bars");
               
               last_order_ticket = 0;
            }
         }
         return;
      }
   }
   
   last_order_ticket = 0; // Order not found, reset
}

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
         if((trans.deal_type == DEAL_TYPE_BUY && request.type == ORDER_TYPE_BUY_STOP) ||
            (trans.deal_type == DEAL_TYPE_SELL && request.type == ORDER_TYPE_SELL_STOP))
         {
            active_position_ticket = trans.position;
            original_entry_price = trans.price;
            bars_since_entry = 0;
            breakeven_activated = false;
            partial_tp_taken = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 NATURAL ENTRY: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " lots at ", DoubleToString(trans.price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)));
            
            if(EnableAlerts)
               Alert("PTG NATURAL ENTRY ", direction);
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
               Print("💰 NATURAL EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), " pips");
            
            if(EnableAlerts)
               Alert("PTG NATURAL 💰 Exit: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), "p");
            
            // Reset if full position closed
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
   Print("🌊 PTG NATURAL FLOW v1.5.0 STOPPED");
   Print("📊 Total Signals: ", signal_count, " | Total Trades: ", trade_count);
   Print("🧠 NATURAL PTG TEST COMPLETED - No Artificial Limits!");
}
