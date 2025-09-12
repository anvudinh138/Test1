//+------------------------------------------------------------------+
//|                    PTG REAL TICK FINAL v2.2.0                   |
//|            ChatGPT-Optimized for "Every tick based on real"     |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "2.20"
#property description "PTG Real Tick Final - ChatGPT Optimized for Gold M1"

//=== INPUTS - CHATGPT OPTIMIZED ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA filter (keep simple)
input int      LookbackPeriod     = 10;                // Lookback period

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.35;              // Range >= 35%
input double   ClosePercent       = 0.45;              // Close position 45%
input double   OppWickPercent     = 0.55;              // Opp wick <= 55% (ChatGPT)
input double   VolHighMultiplier  = 1.2;               // Vol >= 120% (ChatGPT)

input group "=== REAL TICK GOLD SETTINGS (CHATGPT) ==="
input double   MaxSpreadPips      = 12.0;              // ChatGPT: 12 pips for Gold
input double   EntryBufferBasePips = 1.5;              // Base entry buffer
input double   SpreadMultiplier   = 1.2;               // Dynamic spread multiplier
input bool     UseStopLimit       = false;             // Use STOP-LIMIT orders (disabled - invalid price issue)
input double   MaxSlippagePips    = 3.0;               // Max slippage for STOP-LIMIT

input group "=== FIXED RISK MANAGEMENT (CHATGPT) ==="
input bool     UseFixedSL         = true;              // Use fixed SL instead of swing
input double   FixedSLPips        = 25.0;              // Fixed SL distance (realistic)
input double   MaxRiskPips        = 35.0;              // Max risk (tighter control)
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;

input group "=== GOLD POSITION MANAGEMENT (CHATGPT) ==="
input double   BreakevenPips      = 15.0;              // ChatGPT: 15 pips BE
input double   PartialTPPips      = 22.0;              // ChatGPT: 22 pips partial TP
input double   PartialTPPercent   = 30.0;              // 30% close at partial TP
input double   TrailStepPips      = 18.0;              // ChatGPT: 18 pips trail
input double   MinProfitPips      = 9.0;               // ChatGPT: 9 pips min profit

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;
input int      MinBarsBetweenTrades   = 3;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v2.2.0-ChatGPT-Final";

//=== GLOBAL VARIABLES ===
int magic_number = 99999;  // Final version magic
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

// ChatGPT dynamic spread tracking
double spread_ema = 0.0;

//=== CHATGPT HELPER FUNCTIONS ===
double Pip() 
{
   // ChatGPT: Proper Gold pip calculation
   if(StringFind(Symbol(), "XAU") >= 0) return 0.01;  // Gold = 0.01
   double pt = Point();
   int d = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   if(d == 5 || d == 3) return 10 * pt;
   return pt;
}

int PointsFromPips(double pips) 
{
   return (int)MathRound((pips * Pip()) / Point());
}

double DynamicEntryBufferPips() 
{
   // ChatGPT: Dynamic buffer based on spread
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(spread_ema == 0.0) spread_ema = current_spread;
   else spread_ema = 0.7 * spread_ema + 0.3 * current_spread;  // EMA smoothing
   
   return MathMax(EntryBufferBasePips, spread_ema * SpreadMultiplier);
}

//=== INITIALIZATION ===
int OnInit() 
{
   pip_size = Pip();
   
   Print("🎯 PTG REAL TICK FINAL v2.2.0 - CHATGPT OPTIMIZED!");
   Print("📊 Gold Specialist: Pip=", pip_size, " | Magic=", magic_number);
   Print("⚡ ChatGPT Settings: MaxSpread=", MaxSpreadPips, "p | FixedSL=", FixedSLPips, "p");
   Print("🛡️ Management: BE=", BreakevenPips, "p | TP=", PartialTPPips, "p | Trail=", TrailStepPips, "p");
   Print("🔧 STOP-LIMIT Orders: ", UseStopLimit ? "ENABLED" : "DISABLED");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   if(!IsMarketConditionsOK()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageGoldPosition();
      bars_since_entry++;
      return;
   }
   
   CheckPTGSignals();
   CheckPendingOrderTimeout();
}

//=== MARKET CONDITIONS CHECK ===
bool IsMarketConditionsOK() 
{
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips) 
   {
      if(EnableDebugLogs)
         Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   // ChatGPT: Skip extreme spreads (news)
   if(current_spread > MaxSpreadPips * 1.5) 
   {
      if(EnableDebugLogs)
         Print("🚨 EXTREME SPREAD: ", DoubleToString(current_spread, 1), "p - SKIPPING");
      return false;
   }
   
   return true;
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

void ManageGoldPosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = is_long ? 
                       (current_price - original_entry_price) / pip_size :
                       (original_entry_price - current_price) / pip_size;
   
   // ChatGPT: Time-stop for Gold
   if(bars_since_entry >= 30 && profit_pips < MinProfitPips) 
   {
      ClosePositionAtMarket("Gold Time-stop: 30 bars no progress");
      return;
   }
   
   // Partial TP at ChatGPT level
   if(!partial_tp_taken && profit_pips >= PartialTPPips) 
   {
      TakePartialProfit();
      return;
   }
   
   // Breakeven with spread buffer (ChatGPT)
   if(!breakeven_activated && profit_pips >= BreakevenPips) 
   {
      MoveSLToBreakevenGold();
      return;
   }
   
   // Trail with ChatGPT parameters
   if(breakeven_activated && profit_pips > BreakevenPips + TrailStepPips) 
   {
      TrailStopLossGold(profit_pips);
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
   req.comment = "Gold TP " + DoubleToString(PartialTPPips, 1) + "p";
   req.deviation = PointsFromPips(MaxSlippagePips);  // ChatGPT deviation
   
   if(OrderSend(req, res)) 
   {
      partial_tp_taken = true;
      remaining_volume = current_volume - close_volume;
      
      if(EnableDebugLogs)
         Print("💰 GOLD PARTIAL TP: ", DoubleToString(close_volume, 2), " @ +", 
               DoubleToString(PartialTPPips, 1), "p");
   }
}

void MoveSLToBreakevenGold() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // ChatGPT: Breakeven with spread buffer
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + 0.5 * pip_size) :
                     (original_entry_price - spread - 0.5 * pip_size);
   
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
         Print("🛡️ GOLD BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
   }
}

void TrailStopLossGold(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // ChatGPT: Conservative trailing with buffer
   double trail_distance = profit_pips - MinProfitPips - 3.0;  // Extra 3 pip buffer
   double new_sl = is_long ? 
                   original_entry_price + trail_distance * pip_size :
                   original_entry_price - trail_distance * pip_size;
   
   // Only move if significant improvement (ChatGPT)
   if((is_long && new_sl > current_sl + 3 * pip_size) || 
      (!is_long && new_sl < current_sl - 3 * pip_size)) 
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
            Print("📈 GOLD TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Profit: +", 
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
   req.deviation = PointsFromPips(MaxSlippagePips);
   
   if(OrderSend(req, res)) 
   {
      ResetTradeState();
      if(EnableDebugLogs)
         Print("🔚 GOLD CLOSE: ", reason);
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
      
      if(EnableDebugLogs && signal_count % 200 == 0)
         Print("🔥 GOLD PUSH #", signal_count, " detected");
      
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
   
   // ChatGPT: Stricter criteria for Gold
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
   bool is_bullish = IsBullishContext();
   
   // ChatGPT: Immediate execution with STOP-LIMIT
   if(UseStopLimit) 
   {
      PlaceStopLimitOrder(is_bullish);
   } 
   else 
   {
      ExecuteMarketEntry(is_bullish);
   }
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== CHATGPT STOP-LIMIT IMPLEMENTATION ===
void PlaceStopLimitOrder(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar - last_trade_bar < MinBarsBetweenTrades) return;
   
   // Dynamic entry buffer (ChatGPT)
   double buffer = DynamicEntryBufferPips() * pip_size;
   
   double stop_price, limit_price;
   if(is_long) 
   {
      stop_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + buffer;
      limit_price = stop_price + MaxSlippagePips * pip_size;  // Limit slippage
   } 
   else 
   {
      stop_price = SymbolInfoDouble(Symbol(), SYMBOL_BID) - buffer;
      limit_price = stop_price - MaxSlippagePips * pip_size;
   }
   
   // Fixed SL (ChatGPT recommendation)
   double sl_price = is_long ? 
                     stop_price - FixedSLPips * pip_size :
                     stop_price + FixedSLPips * pip_size;
   
   // Risk check
   double sl_distance_pips = MathAbs(stop_price - sl_price) / pip_size;
   if(sl_distance_pips > MaxRiskPips) 
   {
      if(EnableDebugLogs)
         Print("❌ GOLD: Risk too high ", DoubleToString(sl_distance_pips, 1), "p > ", MaxRiskPips, "p");
      return;
   }
   
   // Check stop level (ChatGPT)
   double stops_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * Point();
   if(is_long && stop_price - SymbolInfoDouble(Symbol(), SYMBOL_ASK) < stops_level) 
      stop_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + stops_level;
   if(!is_long && SymbolInfoDouble(Symbol(), SYMBOL_BID) - stop_price < stops_level) 
      stop_price = SymbolInfoDouble(Symbol(), SYMBOL_BID) - stops_level;
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_PENDING;
   req.symbol = Symbol();
   req.magic = magic_number;
   req.volume = FixedLotSize;
   req.type = is_long ? ORDER_TYPE_BUY_STOP_LIMIT : ORDER_TYPE_SELL_STOP_LIMIT;
   req.price = NormalizeDouble(stop_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.stoplimit = NormalizeDouble(limit_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = 0.0;  // No TP, managed by EA
   req.type_time = ORDER_TIME_SPECIFIED;
   req.expiration = TimeCurrent() + 5 * PeriodSeconds(PERIOD_CURRENT);  // 5 bars timeout
   req.comment = "Gold SL " + DoubleToString(FixedSLPips, 1) + "p";
   
   if(OrderSend(req, res)) 
   {
      last_order_ticket = res.order;
      last_trade_bar = current_bar;
      trade_count++;
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ GOLD STOP-LIMIT: ", direction, " @ ", DoubleToString(stop_price, 5), 
               " | Limit: ", DoubleToString(limit_price, 5), " | SL: ", DoubleToString(sl_price, 5));
   } 
   else 
   {
      if(EnableDebugLogs)
         Print("❌ STOP-LIMIT FAILED: ", res.retcode, " - ", res.comment);
   }
}

void ExecuteMarketEntry(bool is_long) 
{
   // Fallback market entry if STOP-LIMIT disabled
   if(active_position_ticket > 0) return;
   
   double entry_price = is_long ? 
                       SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                       SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double sl_price = is_long ? 
                     entry_price - FixedSLPips * pip_size :
                     entry_price + FixedSLPips * pip_size;
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.volume = FixedLotSize;
   req.type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = entry_price;
   req.sl = NormalizeDouble(sl_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "Gold Market " + DoubleToString(FixedSLPips, 1) + "p";
   req.deviation = PointsFromPips(MaxSlippagePips);
   
   if(OrderSend(req, res)) 
   {
      if(EnableDebugLogs)
         Print("✅ GOLD MARKET: ", (is_long ? "LONG" : "SHORT"), " @ ", DoubleToString(entry_price, 5));
   }
}

//=== UTILITY FUNCTIONS ===
void CheckPendingOrderTimeout() 
{
   // Orders auto-expire with ORDER_TIME_SPECIFIED (ChatGPT recommendation)
   return;
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
         // Entry from STOP-LIMIT
         if((trans.deal_type == DEAL_TYPE_BUY && (request.type == ORDER_TYPE_BUY_STOP_LIMIT || request.type == ORDER_TYPE_BUY)) ||
            (trans.deal_type == DEAL_TYPE_SELL && (request.type == ORDER_TYPE_SELL_STOP_LIMIT || request.type == ORDER_TYPE_SELL))) 
         {
            active_position_ticket = trans.position;
            original_entry_price = trans.price;
            bars_since_entry = 0;
            breakeven_activated = false;
            partial_tp_taken = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🎯 GOLD ENTRY: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = was_long ? 
                            (trans.price - original_entry_price) / pip_size :
                            (original_entry_price - trans.price) / pip_size;
            }
            
            if(EnableDebugLogs)
               Print("💰 GOLD EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), "p");
            
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
   Print("🎯 PTG REAL TICK FINAL v2.2.0 STOPPED - CHATGPT OPTIMIZED");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🏆 GOLD REAL TICK ADAPTATION COMPLETE!");
}
