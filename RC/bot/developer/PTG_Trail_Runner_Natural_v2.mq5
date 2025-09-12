//+------------------------------------------------------------------+
//|                    PTG Trail Runner Natural v2.0               |
//|               AUTO LOT SIZE FOR $100 ACCOUNT                   |
//|                    Natural Flow + Smart Risk Management        |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "2.00"
#property description "PTG Trail Runner Natural v2.0 - Auto Lot Size for $100 Account"

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

input group "=== TRAIL RUNNER NATURAL CONFIG ==="
input double   BreakevenPips      = 8.0;               // +X pips => move SL to BE
input double   TrailStepPips      = 15.0;              // Trail step (optimal for big moves)
input double   MinProfitPips      = 5.0;               // Min profit to keep when trailing
input int      MaxBarsInTrade     = 30;                // Time-stop: close if no progress
input bool     UsePartialTP       = false;             // false=Full position trails

input group "=== AUTO LOT SIZE FOR $100 ACCOUNT ==="
input bool     UseFixedLotSize    = false;             // false=Auto lot based on balance
input double   FixedLotSize       = 0.01;              // Fallback micro lot
input double   RiskPercentage     = 2.0;               // Risk % per trade (2% = $2 with $100)
input double   MaxLotSize         = 0.05;              // Max lot for $100 account
input double   MinLotSize         = 0.01;              // Min micro lot

input group "=== ENTRY OPTIMIZATION ==="
input double   EntryBufferPips    = 1.0;               // Entry buffer
input double   SLBufferPips       = 2.0;               // SL buffer
input double   MaxSpreadPips      = 30.0;              // Higher spread tolerance

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
input string   BotVersion         = "v2.0-AutoLot-$100Account";

//=== GLOBAL VARIABLES ===
int magic_number = 77777; // Auto Lot Trail Runner magic
ulong active_position_ticket = 0;
ulong last_order_ticket = 0;
int bars_since_entry = 0;
int last_signal_bar = -1;
int last_trade_bar = -1;
double original_entry_price = 0.0;
double pip_size = 0.0;
bool breakeven_activated = false;
double last_trail_level = 0.0;

int signal_count = 0;
int trade_count = 0;

//=== INITIALIZATION ===
int OnInit()
{
   pip_size = Point();
   if(Digits() == 5 || Digits() == 3) pip_size *= 10;
   
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("💰 PTG TRAIL RUNNER NATURAL v2.0 - AUTO LOT FOR $100 ACCOUNT!");
   Print("🌊 Natural Flow + Smart Risk Management + Auto Lot Sizing");
   Print("📊 Account Balance: $", DoubleToString(account_balance, 0));
   Print("📏 Risk per trade: ", DoubleToString(RiskPercentage, 1), "% = $", DoubleToString(account_balance * RiskPercentage / 100, 2));
   Print("🎯 Lot Range: ", DoubleToString(MinLotSize, 2), " - ", DoubleToString(MaxLotSize, 2), " lots");
   Print("🔧 Pip Size: ", DoubleToString(pip_size, 5), " | Magic: ", magic_number);
   Print("🚫 NO ARTIFICIAL LIMITS - Natural PTG flow with smart money management!");
   
   if(account_balance < 100)
      Print("⚠️  WARNING: Account balance very low! Consider higher leverage (1:500+)");
   
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
      ManageTrailRunnerPosition();
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
         break;
      }
   }
}

void ManageTrailRunnerPosition()
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
   
   // Breakeven when profitable
   if(!breakeven_activated && profit_pips >= BreakevenPips)
   {
      MoveSLToBreakeven();
      return;
   }
   
   // UNLIMITED TRAILING - No TP limit!
   if(breakeven_activated && profit_pips > last_trail_level + TrailStepPips)
   {
      TrailStopLoss(profit_pips);
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
   req.tp = 0.0; // NO TP - UNLIMITED PROFIT!
   
   if(OrderSend(req, res))
   {
      breakeven_activated = true;
      last_trail_level = BreakevenPips;
      
      if(EnableDebugLogs)
         Print("🛡️  AUTO BE: SL moved to entry+1p | UNLIMITED UPSIDE ACTIVATED!");
      
      if(EnableAlerts)
         Alert("PTG AUTO TRAIL 🛡️  Breakeven - Ready for moon mission!");
   }
}

void TrailStopLoss(double profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Calculate new trailing SL - Keep MinProfitPips
   double new_trail_level = MathFloor(profit_pips / TrailStepPips) * TrailStepPips;
   double trail_distance = new_trail_level - MinProfitPips;
   
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
      req.tp = 0.0; // ALWAYS 0 - UNLIMITED!
      
      if(OrderSend(req, res))
      {
         last_trail_level = new_trail_level;
         
         if(EnableDebugLogs)
            Print("🚀 AUTO TRAIL TO MOON: SL @", DoubleToString(new_sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
                  " | Profit: +", DoubleToString(profit_pips, 1), "p | Keep: +", DoubleToString(trail_distance, 1), "p");
         
         if(EnableAlerts)
            Alert("PTG AUTO TRAIL 🚀 Trailing +", DoubleToString(profit_pips, 1), "p");
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
         Print("🔚 AUTO TRAIL CLOSED: ", reason);
      
      if(EnableAlerts)
         Alert("PTG AUTO TRAIL 🔚 ", reason);
   }
}

//=== AUTO LOT SIZE CALCULATION ===
double CalculateOptimalLotSize(double sl_distance_pips)
{
   if(UseFixedLotSize)
   {
      return FixedLotSize;
   }
   
   // Auto lot calculation for $100 account
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * RiskPercentage / 100.0;
   
   // For XAUUSD: 1 pip ≈ $1 per 0.1 lot
   // So 1 pip ≈ $0.10 per 0.01 lot
   double pip_value_per_001_lot = 0.10;
   double calculated_lot = risk_amount / (sl_distance_pips * pip_value_per_001_lot);
   
   // Apply safety limits for $100 account
   calculated_lot = MathMin(calculated_lot, MaxLotSize);
   calculated_lot = MathMax(calculated_lot, MinLotSize); // Min micro lot
   
   if(EnableDebugLogs)
      Print("💰 AUTO LOT CALC: Balance=$", DoubleToString(account_balance, 0), 
            " | Risk=$", DoubleToString(risk_amount, 2), 
            " | SL=", DoubleToString(sl_distance_pips, 1), "p",
            " | Lot=", DoubleToString(calculated_lot, 2),
            " | Risk/pip=$", DoubleToString(calculated_lot * pip_value_per_001_lot * 100, 2));
   
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
         Print("🔥 AUTO TRAIL PUSH #", signal_count, " detected");
      
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
      ExecuteAutoLotTrade(ORDER_TYPE_BUY_STOP, ask + EntryBufferPips * pip_size);
   }
   else
   {
      ExecuteAutoLotTrade(ORDER_TYPE_SELL_STOP, bid - EntryBufferPips * pip_size);
   }
}

bool IsBullishContext()
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== TRADE EXECUTION WITH AUTO LOT ===
void ExecuteAutoLotTrade(ENUM_ORDER_TYPE order_type, double entry_price)
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   bool is_long = (order_type == ORDER_TYPE_BUY_STOP);
   
   // Calculate natural SL based on recent swing points
   double sl_price = CalculateNaturalSL(is_long, entry_price);
   double sl_distance_pips = MathAbs(entry_price - sl_price) / pip_size;
   
   // AUTO LOT CALCULATION - No artificial risk limits!
   double lot_size = CalculateOptimalLotSize(sl_distance_pips);
   
   // Apply broker constraints
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
   req.tp = 0.0; // NO TP - UNLIMITED TRAIL TO MOON!
   req.magic = magic_number;
   req.comment = "AutoLot R:" + DoubleToString(sl_distance_pips, 1) + "p";
   
   if(OrderSend(req, res))
   {
      last_order_ticket = res.order;
      last_trade_bar = current_bar;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      double risk_usd = sl_distance_pips * lot_size * 0.10 * 100; // Risk in USD
      
      if(EnableDebugLogs)
         Print("✅ AUTO LOT TRADE: ", direction, " ", DoubleToString(lot_size, 2), " lots",
               " | Risk: $", DoubleToString(risk_usd, 2), " (", DoubleToString(sl_distance_pips, 1), "p)",
               " | UNLIMITED UPSIDE!");
      
      if(EnableAlerts)
         Alert("PTG AUTO LOT ", direction, " @", DoubleToString(entry_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), 
               " Risk:$", DoubleToString(risk_usd, 2), " MOON MISSION");
   }
   else
   {
      if(EnableDebugLogs)
         Print("❌ AUTO LOT TRADE FAILED: ", res.retcode, " - ", res.comment);
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
      if(EnableDebugLogs)
         Print("SPREAD TOO HIGH: ", DoubleToString(spread_pips, 1), " > ", DoubleToString(MaxSpreadPips, 1), " pips");
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
   last_trail_level = 0.0;
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
            last_trail_level = 0.0;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 AUTO LOT ENTRY: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " lots at ", DoubleToString(trans.price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)), " - MOON MISSION STARTED!");
            
            if(EnableAlerts)
               Alert("PTG AUTO LOT ENTRY ", direction, " - TO THE MOON!");
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
            
            double profit_usd = profit_pips * trans.volume * 0.10 * 100; // Approximate for Gold 0.01 lot
            
            if(EnableDebugLogs)
               Print("💰 AUTO LOT EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p ($", DoubleToString(profit_usd, 2), ")");
            
            if(EnableAlerts)
               Alert("PTG AUTO LOT 💰 Exit: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), "p");
            
            ResetTradeState();
         }
      }
   }
}

void OnDeinit(const int reason)
{
   Print("💰 PTG TRAIL RUNNER NATURAL v2.0 STOPPED - AUTO LOT EDITION");
   Print("📊 Total Signals: ", signal_count, " | Total Trades: ", trade_count);
   Print("🌊 AUTO LOT COMPLETED - Perfect for $100 accounts!");
}
