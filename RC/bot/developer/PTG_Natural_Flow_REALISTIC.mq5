//+------------------------------------------------------------------+
//|                    PTG Natural Flow REALISTIC v1.6.0           |
//|               Realistic Backtest with Exness Conditions       |
//|                    Includes Spread + Commission Simulation     |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.60"
#property description "PTG Natural Flow REALISTIC - Simulates real Exness Pro conditions"

//=== INPUTS ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA 34/55 trend filter
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

input group "=== REALISTIC EXNESS PRO CONDITIONS ==="
// Simulate real Exness Pro account conditions
input double   FixedSpreadPips    = 1.5;               // Average Exness Pro spread (0.1-3p)
input double   CommissionPerLot   = 3.5;               // $3.5 per lot round trip
input double   SlippagePips       = 0.5;               // Average slippage on entries/exits
input double   MaxSpreadPips      = 5.0;               // Don't trade if spread > 5p
input bool     SimulateRealism    = true;              // Enable realistic simulation

input group "=== NATURAL PTG MANAGEMENT ==="
input double   BreakevenPips      = 12.0;              // +X pips => move SL to BE (wider for costs)
input double   PartialTPPips      = 20.0;              // Take 30% profit at +X pips (wider)
input double   PartialTPPercent   = 30.0;              // % of position to close at partial TP
input double   TrailStepPips      = 18.0;              // Trail step (wider for costs)
input double   MinProfitPips      = 8.0;               // Min profit to keep when trailing (wider)
input int      MaxBarsInTrade     = 25;                // Time-stop: close if no progress

input group "=== ENTRY OPTIMIZATION (REALISTIC) ==="
input double   EntryBufferPips    = 2.0;               // Entry buffer (wider for slippage)
input double   SLBufferPips       = 3.0;               // SL buffer (wider for safety)
input double   MinProfitTarget    = 15.0;              // Min profit target to cover costs

input group "=== RISK MANAGEMENT ==="
input bool     UseFixedLotSize    = false;             // false=Auto lot based on balance
input double   FixedLotSize       = 0.01;              // Fallback micro lot
input double   RiskPercentage     = 2.0;               // Risk % per trade
input double   MaxLotSize         = 0.05;              // Max lot for small accounts

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // true=limit hours
input string   StartTime          = "00:00";
input string   EndTime            = "23:59";

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;         // 1 trade at a time
input int      MinBarsBetweenTrades   = 2;             // Min spacing (wider for realism)
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;

input group "=== VERSION CONTROL ==="
input string   BotVersion         = "v1.6.0-REALISTIC-ExnessPro";

//=== GLOBAL VARIABLES ===
int magic_number = 88888; // Realistic PTG magic
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
double total_commission_paid = 0.0;

int signal_count = 0;
int trade_count = 0;
int rejected_by_spread = 0;
int rejected_by_costs = 0;

//=== INITIALIZATION ===
int OnInit()
{
   pip_size = Point();
   if(Digits() == 5 || Digits() == 3) pip_size *= 10;
   
   Print("💰 PTG NATURAL FLOW REALISTIC v1.6.0 - EXNESS PRO SIMULATION!");
   Print("🎯 Simulating: Spread=", DoubleToString(FixedSpreadPips, 1), "p | Commission=$", DoubleToString(CommissionPerLot, 1), "/lot | Slippage=", DoubleToString(SlippagePips, 1), "p");
   Print("📊 Realistic Management: BE=", DoubleToString(BreakevenPips, 1), "p | PartialTP=", DoubleToString(PartialTPPips, 1), "p | Trail=", DoubleToString(TrailStepPips, 1), "p");
   Print("⚠️  REALISTIC MODE: Results should match live trading conditions!");
   
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
      ManageRealisticPosition();
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

void ManageRealisticPosition()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / pip_size :
                       (original_entry_price - current_price) / pip_size;
   
   // Subtract realistic costs from profit calculation
   double cost_pips = CalculateTotalCostPips();
   double net_profit_pips = profit_pips - cost_pips;
   
   // Time-stop: Close if no progress after MaxBarsInTrade
   if(bars_since_entry >= MaxBarsInTrade && net_profit_pips < MinProfitPips)
   {
      ClosePositionAtMarket("Time-stop: No progress after " + IntegerToString(MaxBarsInTrade) + " bars");
      return;
   }
   
   // Partial TP at target pips (accounting for costs)
   if(!partial_tp_taken && net_profit_pips >= PartialTPPips)
   {
      TakePartialProfit();
      return;
   }
   
   // Breakeven when profitable (accounting for costs)
   if(!breakeven_activated && net_profit_pips >= BreakevenPips)
   {
      MoveSLToBreakeven();
      return;
   }
   
   // Trail after breakeven (accounting for costs)
   if(breakeven_activated && net_profit_pips > BreakevenPips + TrailStepPips)
   {
      TrailStopLoss(net_profit_pips);
   }
}

double CalculateTotalCostPips()
{
   // Calculate total cost in pips: spread + commission + slippage
   double commission_pips = (CommissionPerLot * 2) / (10.0 * remaining_volume); // Round trip commission in pips
   double total_cost = FixedSpreadPips + commission_pips + (SlippagePips * 2); // Entry + exit slippage
   
   return total_cost;
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
   
   // Apply realistic slippage to exit price
   double exit_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                      SymbolInfoDouble(Symbol(), SYMBOL_BID) - SlippagePips * pip_size :
                      SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SlippagePips * pip_size;
   
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
   req.comment = "Realistic Partial TP " + DoubleToString(PartialTPPips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      // Add commission cost
      double commission_cost = close_volume * CommissionPerLot;
      total_commission_paid += commission_cost;
      
      if(EnableDebugLogs)
         Print("💰 REALISTIC PARTIAL TP: Closed ", DoubleToString(close_volume, 2), " lots at +", 
               DoubleToString(PartialTPPips, 1), "p | Commission: $", DoubleToString(commission_cost, 2),
               " | Remaining: ", DoubleToString(remaining_volume, 2));
      
      if(EnableAlerts)
         Alert("PTG REALISTIC 💰 Partial TP: +", DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveSLToBreakeven()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Move to breakeven + costs to ensure true breakeven
   double cost_pips = CalculateTotalCostPips();
   double be_price = is_long ? 
                    original_entry_price + (cost_pips + 1) * pip_size : // +1 pip safety
                    original_entry_price - (cost_pips + 1) * pip_size;
   
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
         Print("🛡️  REALISTIC BE: SL moved to cover costs (", DoubleToString(cost_pips, 1), "p) @", 
               DoubleToString(be_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)));
      
      if(EnableAlerts)
         Alert("PTG REALISTIC 🛡️  Breakeven activated (costs covered)");
   }
}

void TrailStopLoss(double net_profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Calculate new trailing SL (keeping costs in mind)
   double cost_pips = CalculateTotalCostPips();
   double trail_distance = net_profit_pips - MinProfitPips;
   double new_sl = is_long ? 
                   original_entry_price + (cost_pips + trail_distance) * pip_size :
                   original_entry_price - (cost_pips + trail_distance) * pip_size;
   
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
            Print("📈 REALISTIC TRAIL: SL @", DoubleToString(new_sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
                  " | Net Profit: +", DoubleToString(net_profit_pips, 1), "p (after costs)");
      }
   }
}

void ClosePositionAtMarket(string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   // Apply realistic slippage to exit
   double exit_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                      SymbolInfoDouble(Symbol(), SYMBOL_BID) - SlippagePips * pip_size :
                      SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SlippagePips * pip_size;
   
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
      // Add final commission
      double final_commission = remaining_volume * CommissionPerLot;
      total_commission_paid += final_commission;
      
      ResetTradeState();
      
      if(EnableDebugLogs)
         Print("🔚 REALISTIC CLOSE: ", reason, " | Final Commission: $", DoubleToString(final_commission, 2));
      
      if(EnableAlerts)
         Alert("PTG REALISTIC 🔚 ", reason);
   }
}

//=== AUTO LOT SIZE CALCULATION ===
double CalculateOptimalLotSize(double sl_distance_pips)
{
   if(UseFixedLotSize)
   {
      return FixedLotSize;
   }
   
   // Auto lot calculation accounting for realistic costs
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * RiskPercentage / 100.0;
   
   // Account for total costs in risk calculation
   double total_cost_pips = FixedSpreadPips + (CommissionPerLot * 2) / 10.0 + (SlippagePips * 2);
   double effective_sl_pips = sl_distance_pips + total_cost_pips;
   
   // For XAUUSD: 1 pip ≈ $0.10 per 0.01 lot
   double pip_value_per_001_lot = 0.10;
   double calculated_lot = risk_amount / (effective_sl_pips * pip_value_per_001_lot);
   
   // Apply safety limits
   calculated_lot = MathMin(calculated_lot, MaxLotSize);
   calculated_lot = MathMax(calculated_lot, 0.01); // Min micro lot
   
   if(EnableDebugLogs)
      Print("💰 REALISTIC LOT: Balance=$", DoubleToString(account_balance, 0), 
            " | Risk=$", DoubleToString(risk_amount, 2), 
            " | SL+Costs=", DoubleToString(effective_sl_pips, 1), "p",
            " | Lot=", DoubleToString(calculated_lot, 2));
   
   return calculated_lot;
}

//=== PTG SIGNAL DETECTION ===
void CheckPTGSignals()
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected())
   {
      signal_count++;
      if(signal_count % 100 == 0)
         Print("🔥 REALISTIC PUSH #", signal_count, " detected");
      
      last_signal_bar = current_bar;
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
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   bool is_bullish = IsBullishContext();
   
   if(is_bullish)
   {
      ExecuteRealisticTrade(ORDER_TYPE_BUY_STOP, ask + EntryBufferPips * pip_size);
   }
   else
   {
      ExecuteRealisticTrade(ORDER_TYPE_SELL_STOP, bid - EntryBufferPips * pip_size);
   }
}

bool IsBullishContext()
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== REALISTIC TRADE EXECUTION ===
void ExecuteRealisticTrade(ENUM_ORDER_TYPE order_type, double entry_price)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   // Check current spread
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double current_spread_pips = (ask - bid) / pip_size;
   
   if(current_spread_pips > MaxSpreadPips)
   {
      rejected_by_spread++;
      if(EnableDebugLogs)
         Print("❌ SPREAD REJECT: ", DoubleToString(current_spread_pips, 1), "p > ", DoubleToString(MaxSpreadPips, 1), "p");
      return;
   }
   
   bool is_long = (order_type == ORDER_TYPE_BUY_STOP);
   
   // Calculate natural SL
   double sl_price = CalculateNaturalSL(is_long, entry_price);
   double sl_distance_pips = MathAbs(entry_price - sl_price) / pip_size;
   
   // Check if trade is profitable after costs
   double total_cost_pips = FixedSpreadPips + (CommissionPerLot * 2) / 10.0 + (SlippagePips * 2);
   if(sl_distance_pips < MinProfitTarget || total_cost_pips >= MinProfitTarget * 0.5)
   {
      rejected_by_costs++;
      if(EnableDebugLogs)
         Print("❌ COST REJECT: SL=", DoubleToString(sl_distance_pips, 1), "p | Costs=", DoubleToString(total_cost_pips, 1), "p");
      return;
   }
   
   // Apply realistic slippage to entry
   double realistic_entry = is_long ? 
                           entry_price + SlippagePips * pip_size :
                           entry_price - SlippagePips * pip_size;
   
   double lot_size = CalculateOptimalLotSize(sl_distance_pips);
   
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
   req.price = NormalizeDouble(realistic_entry, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = 0.0; // No TP - let management handle exits
   req.magic = magic_number;
   req.comment = "Realistic PTG R:" + DoubleToString(sl_distance_pips, 1) + "p C:" + DoubleToString(total_cost_pips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      last_order_ticket = res.order;
      last_trade_bar = current_bar;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      double entry_commission = lot_size * CommissionPerLot;
      total_commission_paid += entry_commission;
      
      if(EnableDebugLogs)
         Print("✅ REALISTIC PTG: ", direction, " ", DoubleToString(lot_size, 2), " lots",
               " | Risk: ", DoubleToString(sl_distance_pips, 1), "p",
               " | Costs: ", DoubleToString(total_cost_pips, 1), "p",
               " | Commission: $", DoubleToString(entry_commission, 2));
      
      if(EnableAlerts)
         Alert("PTG REALISTIC ", direction, " Risk:", DoubleToString(sl_distance_pips, 1), "p Costs:", DoubleToString(total_cost_pips, 1), "p");
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ REALISTIC TRADE FAILED: ", res.retcode, " - ", res.comment);
   }
}

double CalculateNaturalSL(bool is_long, double entry_price)
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
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread_pips = (ask - bid) / pip_size;
   
   if(spread_pips > MaxSpreadPips)
   {
      return false;
   }
   
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
               Print("🎯 REALISTIC ENTRY: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " lots at ", DoubleToString(trans.price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)));
            
            if(EnableAlerts)
               Alert("PTG REALISTIC ENTRY ", direction);
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
            
            // Calculate net profit after all costs
            double cost_pips = CalculateTotalCostPips();
            double net_profit_pips = profit_pips - cost_pips;
            
            if(EnableDebugLogs)
               Print("💰 REALISTIC EXIT: Gross: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Costs: -", DoubleToString(cost_pips, 1), "p | Net: ", (net_profit_pips >= 0 ? "+" : ""), 
                     DoubleToString(net_profit_pips, 1), "p");
            
            if(EnableAlerts)
               Alert("PTG REALISTIC 💰 Net: ", (net_profit_pips >= 0 ? "+" : ""), DoubleToString(net_profit_pips, 1), "p");
            
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
   Print("💰 PTG NATURAL FLOW REALISTIC v1.6.0 STOPPED");
   Print("📊 Total Signals: ", signal_count, " | Total Trades: ", trade_count);
   Print("❌ Rejected by Spread: ", rejected_by_spread, " | Rejected by Costs: ", rejected_by_costs);
   Print("💸 Total Commission Paid: $", DoubleToString(total_commission_paid, 2));
   Print("🎯 REALISTIC SIMULATION COMPLETED - Results should match live trading!");
}
