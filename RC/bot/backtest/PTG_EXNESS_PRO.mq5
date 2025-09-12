//+------------------------------------------------------------------+
//|                        PTG EXNESS PRO ACCOUNT v1.0             |
//|               Realistic Backtest for Exness Pro Account        |
//|                    Spread: 0.1-2p | Commission: $0             |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property version   "1.00"
#property description "PTG Natural Flow - EXNESS PRO Account Simulation"

//=== EXNESS PRO ACCOUNT SETTINGS ===
input group "=== EXNESS PRO ACCOUNT CONDITIONS ==="
input double   FixedSpreadPips    = 1.2;               // Exness Pro average spread (0.1-2p)
input double   CommissionPerLot   = 0.0;               // No commission on Pro
input double   SlippagePips       = 0.3;               // Minimal slippage on Pro
input double   MaxSpreadPips      = 15.0;              // Don't trade if spread > 15p (realistic for Gold)
input bool     SimulateRealism    = true;              // Enable Pro conditions

//=== PTG CORE SETTINGS ===
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
input int      PendingTimeout     = 5;                 // Remove pendings after X bars
input double   PullbackMax        = 0.85;              // Pullback <= 85%
input double   VolLowMultiplier   = 2.0;               // Vol TEST <= 200%

input group "=== PRO ACCOUNT MANAGEMENT ==="
// Optimized for Exness Pro (low spread, no commission)
input double   BreakevenPips      = 8.0;               // +X pips => move SL to BE
input double   PartialTPPips      = 15.0;              // Take 30% profit at +X pips
input double   PartialTPPercent   = 30.0;              // % of position to close
input double   TrailStepPips      = 12.0;              // Trail step
input double   MinProfitPips      = 5.0;               // Min profit to keep
input int      MaxBarsInTrade     = 20;                // Time-stop

input group "=== ENTRY SETTINGS ==="
input double   EntryBufferPips    = 1.0;               // Entry buffer
input double   SLBufferPips       = 2.0;               // SL buffer
input double   MinProfitTarget    = 10.0;              // Min profit target

input group "=== RISK MANAGEMENT ==="
input bool     UseFixedLotSize    = false;             // Auto lot sizing
input double   FixedLotSize       = 0.01;              // Fallback lot
input double   RiskPercentage     = 2.0;               // Risk % per trade
input double   MaxLotSize         = 0.10;              // Max lot size

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;         // 1 trade at a time
input int      MinBarsBetweenTrades   = 1;             // Min spacing
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v1.0-ExnessPro";

//=== GLOBAL VARIABLES ===
int magic_number = 11111; // Exness Pro magic
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
int rejected_by_spread = 0;

//=== INITIALIZATION ===
int OnInit()
{
   pip_size = Point();
   if(Digits() == 5 || Digits() == 3) pip_size *= 10;
   
   Print("💎 PTG EXNESS PRO ACCOUNT v1.0 STARTED!");
   Print("📊 Pro Conditions: Spread=", DoubleToString(FixedSpreadPips, 1), "p | Commission=$0 | Slippage=", DoubleToString(SlippagePips, 1), "p");
   Print("🎯 Pro Management: BE=", DoubleToString(BreakevenPips, 1), "p | PartialTP=", DoubleToString(PartialTPPips, 1), "p | Trail=", DoubleToString(TrailStepPips, 1), "p");
   Print("✅ BEST FOR: Scalping strategies with tight spreads!");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick()
{
   if(!IsTradingAllowed()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0)
   {
      ManageProPosition();
      bars_since_entry++;
      return;
   }
   
   CheckPTGSignals();
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

void ManageProPosition()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / pip_size :
                       (original_entry_price - current_price) / pip_size;
   
   // Pro account: Only subtract spread (no commission)
   double cost_pips = FixedSpreadPips + (SlippagePips * 2); // Entry + exit slippage
   double net_profit_pips = profit_pips - cost_pips;
   
   // Time-stop
   if(bars_since_entry >= MaxBarsInTrade && net_profit_pips < MinProfitPips)
   {
      ClosePositionAtMarket("Pro Time-stop: No progress");
      return;
   }
   
   // Partial TP
   if(!partial_tp_taken && net_profit_pips >= PartialTPPips)
   {
      TakePartialProfit();
      return;
   }
   
   // Breakeven
   if(!breakeven_activated && net_profit_pips >= BreakevenPips)
   {
      MoveSLToBreakeven();
      return;
   }
   
   // Trail
   if(breakeven_activated && net_profit_pips > BreakevenPips + TrailStepPips)
   {
      TrailStopLoss(net_profit_pips);
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
   req.comment = "Pro Partial TP " + DoubleToString(PartialTPPips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💎 PRO PARTIAL TP: ", DoubleToString(close_volume, 2), " lots at +", DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveSLToBreakeven()
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double cost_pips = FixedSpreadPips + (SlippagePips * 2);
   double be_price = is_long ? 
                    original_entry_price + (cost_pips + 1) * pip_size :
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
         Print("💎 PRO BREAKEVEN: SL moved to cover spread costs");
   }
}

void TrailStopLoss(double net_profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   double cost_pips = FixedSpreadPips + (SlippagePips * 2);
   double trail_distance = net_profit_pips - MinProfitPips;
   double new_sl = is_long ? 
                   original_entry_price + (cost_pips + trail_distance) * pip_size :
                   original_entry_price - (cost_pips + trail_distance) * pip_size;
   
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
            Print("💎 PRO TRAIL: Net +", DoubleToString(net_profit_pips, 1), "p");
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
         Print("💎 PRO CLOSED: ", reason);
   }
}

//=== AUTO LOT CALCULATION ===
double CalculateOptimalLotSize(double sl_distance_pips)
{
   if(UseFixedLotSize) return FixedLotSize;
   
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * RiskPercentage / 100.0;
   
   // Pro account: Only spread cost (no commission)
   double total_cost_pips = FixedSpreadPips + (SlippagePips * 2);
   double effective_sl_pips = sl_distance_pips + total_cost_pips;
   
   double pip_value_per_001_lot = 0.10;
   double calculated_lot = risk_amount / (effective_sl_pips * pip_value_per_001_lot);
   
   calculated_lot = MathMin(calculated_lot, MaxLotSize);
   calculated_lot = MathMax(calculated_lot, 0.01);
   
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
   
   bool is_bullish = iClose(Symbol(), PERIOD_CURRENT, 1) > iClose(Symbol(), PERIOD_CURRENT, 2);
   
   if(is_bullish)
      ExecuteProTrade(ORDER_TYPE_BUY_STOP, ask + EntryBufferPips * pip_size);
   else
      ExecuteProTrade(ORDER_TYPE_SELL_STOP, bid - EntryBufferPips * pip_size);
}

void ExecuteProTrade(ENUM_ORDER_TYPE order_type, double entry_price)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   // Check spread
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double current_spread_pips = (ask - bid) / pip_size;
   
   if(current_spread_pips > MaxSpreadPips)
   {
      rejected_by_spread++;
      return;
   }
   
   bool is_long = (order_type == ORDER_TYPE_BUY_STOP);
   double sl_price = CalculateNaturalSL(is_long, entry_price);
   double sl_distance_pips = MathAbs(entry_price - sl_price) / pip_size;
   
   // Check profitability
   double total_cost_pips = FixedSpreadPips + (SlippagePips * 2);
   if(sl_distance_pips < MinProfitTarget || total_cost_pips >= MinProfitTarget * 0.3)
      return;
   
   // Apply slippage
   double realistic_entry = is_long ? 
                           entry_price + SlippagePips * pip_size :
                           entry_price - SlippagePips * pip_size;
   
   double lot_size = CalculateOptimalLotSize(sl_distance_pips);
   
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
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "Pro PTG R:" + DoubleToString(sl_distance_pips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      last_order_ticket = res.order;
      last_trade_bar = current_bar;
      trade_count++;
      
      if(EnableDebugLogs)
         Print("💎 PRO TRADE: ", (is_long ? "LONG" : "SHORT"), " ", DoubleToString(lot_size, 2), 
               " lots | Risk: ", DoubleToString(sl_distance_pips, 1), "p | Costs: ", DoubleToString(total_cost_pips, 1), "p");
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
   
   return is_long ? swing_low - SLBufferPips * pip_size : swing_high + SLBufferPips * pip_size;
}

//=== UTILITY FUNCTIONS ===
bool IsTradingAllowed()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread_pips = (ask - bid) / pip_size;
   
   return spread_pips <= MaxSpreadPips;
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
            
            if(EnableDebugLogs)
               Print("💎 PRO ENTRY: ", (trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT"), 
                     " ", DoubleToString(trans.volume, 2), " lots");
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
            
            double cost_pips = FixedSpreadPips + (SlippagePips * 2);
            double net_profit_pips = profit_pips - cost_pips;
            
            if(EnableDebugLogs)
               Print("💎 PRO EXIT: Gross: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Net: ", (net_profit_pips >= 0 ? "+" : ""), DoubleToString(net_profit_pips, 1), "p");
            
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
   Print("💎 PTG EXNESS PRO ACCOUNT v1.0 STOPPED");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count, " | Spread Rejects: ", rejected_by_spread);
   Print("✅ PRO ACCOUNT SIMULATION COMPLETED!");
}
