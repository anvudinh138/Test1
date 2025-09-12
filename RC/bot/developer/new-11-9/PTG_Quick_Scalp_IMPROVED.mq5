//+------------------------------------------------------------------+
//|                        PTG Quick Scalp IMPROVED v1.3.0          |
//|               Based on AI Analysis - Implementing Fixes         |
//|                    R&D Version for Profitability               |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.30"
#property description "PTG Quick Scalp IMPROVED - Implementing AI recommendations for profitability"

//=== INPUTS ===
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // (chưa dùng)
input int      LookbackPeriod     = 10;                // Lookback for range & volSMA

input group "=== PUSH PARAMETERS (OPTIMIZED) ==="
input double   PushRangePercent   = 0.35;              // Range >= 35% (quality)
input double   ClosePercent       = 0.45;              // Close pos 45% (momentum)
input double   OppWickPercent     = 0.65;              // Opp wick <= 65% (strict)
input double   VolHighMultiplier  = 1.0;               // Vol >= 100% (confirm)

input group "=== TEST PARAMETERS (BALANCED) ==="
input int      TestBars           = 10;                // Allow TEST within X bars
input int      PendingTimeout     = 5;                 // Remove pendings after X bars
input double   PullbackMax        = 0.85;              // Pullback <= 85% push range
input double   VolLowMultiplier   = 2.0;               // Vol TEST <= 200%

input group "=== IMPROVED SCALP CONFIG (AI RECOMMENDATIONS) ==="
// AI Analysis: Need better R:R ratio for profitability
input double   BreakevenPips      = 5.0;               // +X pips => move SL to BE (wider for stability)
input double   QuickExitPips      = 10.0;              // Lower TP for better hit rate (was 18)
input bool     UseQuickExit       = true;              // Quick Scalp mode
input double   TrailStepPips      = 10.0;              // Trail step
input double   MinProfitPips      = 3.0;               // Keep minimum profit when trailing

input group "=== AI IMPROVEMENTS ==="
// KEY: Limit risk and improve R:R ratio
input double   MaxRiskPips        = 12.0;              // Skip trades with SL > 12p (CRITICAL)
input bool     BEOnBarClose       = true;              // Only move to BE after bar close
input double   BEOffsetPips       = 0.5;               // BE = entry + 0.5p (avoid $0 wins)
input double   TP1Pips            = 10.0;              // Partial TP target
input double   TP1Part            = 0.5;               // Close 50% at TP1

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.5;               // Entry buffer
input double   SLBufferPips       = 0.5;               // SL buffer
input bool     UseFixedLotSize    = true;              // Fixed lot (recommended)
input double   FixedLotSize       = 0.10;              // 0.10 lot ~ $1/pip với Gold
input double   MaxSpreadPips      = 20.0;              // Spread tối đa (pips)

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // true=giới hạn giờ
input string   StartTime          = "00:00";
input string   EndTime            = "23:59";

input group "=== SYSTEM ==="
input bool     AllowMultiplePositions = false;         // 1 lệnh một lúc
input int      MinBarsBetweenTrades   = 1;             // Giãn cách tối thiểu (bars)
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;

input group "=== VERSION CONTROL ==="
input string   BotVersion         = "v1.3.0-IMPROVED-AI-ANALYSIS";

//--- Globals
int            ema34_handle, ema55_handle;
double         ema34[], ema55[];
double         pip_size = 0.01;           // XAUUSD: 1 pip = 0.01
bool           wait_test = false;
bool           long_direction = false;
int            push_bar_index = 0;
double         push_high, push_low, push_range;
double         test_high = 0, test_low = 0;
datetime       last_trade_time = 0;
int            total_signals = 0;
int            total_trades = 0;
int            last_order_ticket = 0;
datetime       order_place_time = 0;

// Position tracking
double         original_entry_price = 0;
double         original_sl_price = 0;
bool           position_active = false;
ulong          active_position_ticket = 0;

// Improved management
bool           pip_breakeven_activated = false;
bool           partial_tp_triggered = false;
double         last_trail_level = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   string symbol = Symbol();

   // Pip size
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      pip_size = 0.01;
   else if(StringFind(symbol, "JPY") >= 0)
      pip_size = 0.01;
   else if(StringFind(symbol, "USD") >= 0)
      pip_size = 0.0001;
   else
      pip_size = 0.00001;

   // Indicators
   ema34_handle = iMA(symbol, PERIOD_CURRENT, 34, 0, MODE_EMA, PRICE_CLOSE);
   ema55_handle = iMA(symbol, PERIOD_CURRENT, 55, 0, MODE_EMA, PRICE_CLOSE);
   if(ema34_handle == INVALID_HANDLE || ema55_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicators");
      return(INIT_FAILED);
   }

   Print("=== PTG QUICK SCALP IMPROVED v1.3.0 INITIALIZED ===");
   Print("🧠 AI ANALYSIS IMPLEMENTATION: Fixing Quick Scalp profitability");
   Print("🔧 VERSION: ", BotVersion, " | Symbol: ", symbol, " | Pip size: ", pip_size);
   Print("📊 TARGET: Transform 95% win rate + losses → 85% win rate + profits");
   Print("⚡ KEY IMPROVEMENTS:");
   Print("   - MaxRiskPips = ", MaxRiskPips, " (reject bad R:R trades)");
   Print("   - QuickExitPips = ", QuickExitPips, " (lower TP for better hit rate)");
   Print("   - BreakevenPips = ", BreakevenPips, " (more breathing room)");
   Print("   - PartialTP = ", TP1Part*100, "% @ +", TP1Pips, "p (secure profits)");
   Print("   - BEOffset = +", BEOffsetPips, "p (avoid $0 wins)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ema34_handle);
   IndicatorRelease(ema55_handle);
   Print("=== PTG QUICK SCALP IMPROVED v1.3.0 STOPPED ===");
   Print("Total Signals: ", total_signals, " | Total Trades: ", total_trades);
   Print("🧠 AI IMPROVEMENT TEST COMPLETED");
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(current_bar_time == last_bar_time) return;
   last_bar_time = current_bar_time;

   if(!GetMarketData())   return;
   if(!IsTradingAllowed()) return;

   CheckPendingOrderTimeout();

   if(position_active)
      ManageImprovedScalpPosition();

   PTG_MainLogic();
}

//+------------------------------------------------------------------+
bool GetMarketData()
{
   ArraySetAsSeries(ema34, true);
   ArraySetAsSeries(ema55, true);

   if(CopyBuffer(ema34_handle, 0, 0, LookbackPeriod+5, ema34) <= 0) return(false);
   if(CopyBuffer(ema55_handle, 0, 0, LookbackPeriod+5, ema55) <= 0) return(false);
   return(true);
}

//+------------------------------------------------------------------+
double GetVolumeSMA(int period, int shift=1)
{
   double sum = 0;
   for(int i=shift; i<shift+period; i++)
      sum += (double)iVolume(Symbol(), PERIOD_CURRENT, i);
   return(sum/period);
}

//+------------------------------------------------------------------+
void CheckPendingOrderTimeout()
{
   if(last_order_ticket <= 0 || order_place_time == 0) return;

   datetime now_bar = iTime(Symbol(), PERIOD_CURRENT, 0);
   int bars_elapsed = Bars(Symbol(), PERIOD_CURRENT, order_place_time, now_bar) - 1;
   if(bars_elapsed >= PendingTimeout)
   {
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order  = last_order_ticket;
      if(OrderSend(req, res))
      {
         if(EnableDebugLogs)
            Print("⏰ TIMEOUT: Removed pending order #", last_order_ticket, " after ", bars_elapsed, " bars");
      }
      last_order_ticket = 0;
      order_place_time  = 0;
   }
}

//+------------------------------------------------------------------+
//| IMPROVED: Risk check function (AI recommendation #1)           |
//+------------------------------------------------------------------+
bool RiskOk(double entry_price, double sl_price)
{
   double risk_pips = MathAbs(entry_price - sl_price) / pip_size;
   if(risk_pips > MaxRiskPips)
   {
      if(EnableDebugLogs)
         Print("🚫 SKIP TRADE: Risk ", DoubleToString(risk_pips,1), "p > ", MaxRiskPips, "p limit");
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
//| IMPROVED: Position management with AI fixes                     |
//+------------------------------------------------------------------+
void ManageImprovedScalpPosition()
{
   string symbol = Symbol();

   if(!PositionSelectByTicket(active_position_ticket))
   {
      ResetPositionVariables();
      return;
   }

   bool   is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double price   = is_long ? SymbolInfoDouble(symbol, SYMBOL_BID)
                            : SymbolInfoDouble(symbol, SYMBOL_ASK);

   double profit_pips = is_long ?
                        (price - original_entry_price)/pip_size :
                        (original_entry_price - price)/pip_size;

   // AI IMPROVEMENT #3: Partial TP at +10p (50% position)
   if(!partial_tp_triggered && profit_pips >= TP1Pips)
   {
      CheckPartialTP(profit_pips);
      return;
   }

   // AI IMPROVEMENT #2: Better breakeven management
   if(!pip_breakeven_activated && profit_pips >= BreakevenPips)
   {
      // Only move BE after bar close if enabled
      if(BEOnBarClose)
      {
         datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
         static datetime last_be_check = 0;
         if(current_time == last_be_check) return; // Wait for bar close
         last_be_check = current_time;
      }
      
      MoveSLToEntryWithOffset("IMPROVED BE at +" + DoubleToString(profit_pips,1) + "p");
      return;
   }

   // Quick Exit for remaining position
   if(UseQuickExit && profit_pips >= QuickExitPips)
   {
      ClosePositionAtMarket("IMPROVED SCALP at +" + DoubleToString(profit_pips,1) + "p");
      return;
   }

   // Light trailing for remaining position
   if(pip_breakeven_activated && profit_pips >= (last_trail_level + TrailStepPips))
   {
      double new_trail_level = MathFloor(profit_pips / TrailStepPips) * TrailStepPips;
      double new_sl_pips     = new_trail_level - MinProfitPips;
      if(new_sl_pips > last_trail_level)
      {
         MoveSLToPipLevel(new_sl_pips, "IMPROVED TRAIL to +" + DoubleToString(new_sl_pips,1) + "p");
         last_trail_level = new_trail_level;
      }
   }
}

//+------------------------------------------------------------------+
//| AI IMPROVEMENT #3: Partial TP implementation                   |
//+------------------------------------------------------------------+
void CheckPartialTP(double profit_pips)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   if(partial_tp_triggered) return;

   double vol = PositionGetDouble(POSITION_VOLUME);
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double closeVol = MathMax(minv, MathFloor(vol*TP1Part/step)*step);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = Symbol();
   req.position = active_position_ticket;
   req.volume   = closeVol;
   req.type     = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.deviation= 10;
   req.comment  = "TP1 Partial " + DoubleToString(TP1Part*100,0) + "%";

   if(OrderSend(req, res))
   {
      partial_tp_triggered = true;
      Print("💰 PARTIAL TP: Closed ", DoubleToString(TP1Part*100,0), "% @ +", DoubleToString(profit_pips,1), "p");
      if(EnableAlerts) Alert("PTG IMPROVED Partial TP +" + DoubleToString(profit_pips,1) + "p");
   }
   else
   {
      Print("❌ PARTIAL TP FAILED: ", res.retcode, " - ", res.comment);
   }
}

//+------------------------------------------------------------------+
void ClosePositionAtMarket(string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = Symbol();
   req.position = active_position_ticket;
   req.type     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.volume   = PositionGetDouble(POSITION_VOLUME);
   req.deviation= 10;
   req.comment  = reason;

   if(OrderSend(req, res))
   {
      Print("🚀 ", reason, " - Remaining position closed");
      if(EnableAlerts) Alert("PTG IMPROVED " + reason);
   }
   else
   {
      Print("❌ CLOSE FAILED: ", res.retcode, " - ", res.comment);
   }
}

//+------------------------------------------------------------------+
//| AI IMPROVEMENT #2: BE with offset to avoid $0 wins            |
//+------------------------------------------------------------------+
void MoveSLToEntryWithOffset(string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;

   bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double be_price = original_entry_price + (is_long ? BEOffsetPips : -BEOffsetPips) * pip_size;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = Symbol();
   req.position = active_position_ticket;
   req.sl       = NormalizeDouble(be_price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp       = PositionGetDouble(POSITION_TP);

   if(OrderSend(req, res))
   {
      pip_breakeven_activated = true;
      last_trail_level        = BreakevenPips;
      Print("🎯 ", reason, " - SL moved to entry+", BEOffsetPips, "p (avoid $0 wins)");
      if(EnableAlerts) Alert("PTG IMPROVED " + reason);
   }
   else
   {
      Print("❌ IMPROVED BE FAILED: ", res.retcode, " - ", res.comment);
   }
}

//+------------------------------------------------------------------+
void MoveSLToPipLevel(double pip_level, string reason)
{
   if(!PositionSelectByTicket(active_position_ticket)) return;

   bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double new_sl = is_long ?
                   original_entry_price + (pip_level * pip_size) :
                   original_entry_price - (pip_level * pip_size);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = Symbol();
   req.position = active_position_ticket;
   req.sl       = NormalizeDouble(new_sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
   req.tp       = PositionGetDouble(POSITION_TP);

   if(OrderSend(req, res))
   {
      Print("📈 ", reason, " - SL improved trailing");
      if(EnableAlerts) Alert("PTG IMPROVED " + reason);
   }
   else
   {
      Print("❌ IMPROVED TRAIL FAILED: ", res.retcode, " - ", res.comment);
   }
}

//+------------------------------------------------------------------+
void ResetPositionVariables()
{
   position_active = false;
   active_position_ticket = 0;
   original_entry_price = 0;
   original_sl_price = 0;
   pip_breakeven_activated = false;
   partial_tp_triggered = false;
   last_trail_level = 0;
}

//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double spread_pips = (ask - bid) / pip_size;
   if(spread_pips > MaxSpreadPips)
   {
      if(EnableDebugLogs && spread_pips > MaxSpreadPips*1.5)
         Print("SPREAD TOO HIGH: ", DoubleToString(spread_pips,1), " > ", MaxSpreadPips, " pips");
      return(false);
   }

   if(UseTimeFilter)
   {
      datetime server_time = TimeCurrent();
      MqlDateTime ts; TimeToStruct(server_time, ts);
      int curH = ts.hour;
      int startH = (int)StringToInteger(StringSubstr(StartTime,0,2));
      int endH   = (int)StringToInteger(StringSubstr(EndTime,0,2));
      if(curH < startH || curH >= endH) return(false);
   }

   if(!AllowMultiplePositions && (PositionsTotal() > 0 || position_active))
      return(false);

   static datetime last_check_time = 0;
   datetime cur_time = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(cur_time - last_check_time < MinBarsBetweenTrades * PeriodSeconds(PERIOD_CURRENT))
      return(false);
   last_check_time = cur_time;

   return(true);
}

//+------------------------------------------------------------------+
void PTG_MainLogic()
{
   string symbol = Symbol();

   double high   = iHigh(symbol, PERIOD_CURRENT, 1);
   double low    = iLow(symbol, PERIOD_CURRENT, 1);
   double open   = iOpen(symbol, PERIOD_CURRENT, 1);
   double close  = iClose(symbol, PERIOD_CURRENT, 1);
   long   volume = iVolume(symbol, PERIOD_CURRENT, 1);

   double range = high - low;
   double close_pos_hi = (close - low) / MathMax(range, pip_size);
   double close_pos_lo = (high  - close) / MathMax(range, pip_size);
   double low_wick     = (MathMin(open, close) - low) / MathMax(range, pip_size);
   double up_wick      = (high - MathMax(open, close)) / MathMax(range, pip_size);

   double max_range = 0;
   for(int i=1; i<=LookbackPeriod; i++)
   {
      double br = iHigh(symbol, PERIOD_CURRENT, i) - iLow(symbol, PERIOD_CURRENT, i);
      if(br > max_range) max_range = br;
   }

   bool up_trend=true, down_trend=true;
   if(UseEMAFilter && ArraySize(ema34)>1 && ArraySize(ema55)>1)
   {
      up_trend   = (ema34[1] > ema55[1]);
      down_trend = (ema34[1] < ema55[1]);
   }

   bool big_range   = (range >= max_range * PushRangePercent);
   double vol_sma   = GetVolumeSMA(LookbackPeriod,1);
   bool high_volume = (volume >= vol_sma * VolHighMultiplier);

   bool push_up   = up_trend   && big_range && high_volume && (close_pos_hi >= ClosePercent) && (up_wick  <= OppWickPercent);
   bool push_down = down_trend && big_range && high_volume && (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);

   if(push_up || push_down)
   {
      total_signals++;
      wait_test = true;
      long_direction = push_up;
      push_bar_index = 0;
      push_high = high; push_low = low; push_range = range;
      test_high = 0; test_low = 0;

      if(EnableDebugLogs && (total_signals % 100 == 0))
         Print("🔥 IMPROVED PUSH #", total_signals, " ", push_up ? "UP" : "DOWN");
   }

   if(!wait_test) return;

   push_bar_index++;

   if(push_bar_index >= 1 && push_bar_index <= TestBars)
   {
      bool pullback_ok_long  =  long_direction && ((push_high - low) <= PullbackMax * push_range);
      bool pullback_ok_short = !long_direction && ((high      - push_low) <= PullbackMax * push_range);

      bool low_volume  = (volume <= vol_sma * VolLowMultiplier);
      bool small_range = (range <= max_range);

      bool test_long  = pullback_ok_long  && low_volume && small_range;
      bool test_short = pullback_ok_short && low_volume && small_range;

      if(test_long || test_short)
      {
         test_high = high;
         test_low  = low;

         double entry_level, sl_level, tp_level;
         if(test_long)
         {
            entry_level = test_high + (EntryBufferPips * pip_size);
            sl_level    = test_low  - (SLBufferPips   * pip_size);
            tp_level    = entry_level + (QuickExitPips * pip_size);
            
            // AI IMPROVEMENT #1: Check risk before executing
            if(RiskOk(entry_level, sl_level))
               ExecuteImprovedScalpTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Improved Long");
         }
         else
         {
            entry_level = test_low  - (EntryBufferPips * pip_size);
            sl_level    = test_high + (SLBufferPips   * pip_size);
            tp_level    = entry_level - (QuickExitPips * pip_size);
            
            // AI IMPROVEMENT #1: Check risk before executing
            if(RiskOk(entry_level, sl_level))
               ExecuteImprovedScalpTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Improved Short");
         }
         wait_test = false;
      }
   }
   if(push_bar_index > TestBars) wait_test = false;
}

//+------------------------------------------------------------------+
void ExecuteImprovedScalpTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
   string symbol = Symbol();
   total_trades++;

   double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
   if(pip_risk <= 0)
   {
      Print("ERROR: Invalid pip risk calculation");
      return;
   }

   // Store original values
   original_entry_price = entry_price;
   original_sl_price    = sl_price;

   // Fixed lot size
   double lot_size = FixedLotSize;
   double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot_size = MathMax(min_lot, MathMin(max_lot, MathFloor(lot_size/lot_step)*lot_step));

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action  = TRADE_ACTION_PENDING;
   req.symbol  = symbol;
   req.volume  = lot_size;
   req.type    = order_type;
   req.price   = NormalizeDouble(entry_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   req.sl      = NormalizeDouble(sl_price,   (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   req.tp      = NormalizeDouble(tp_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   req.comment = comment;
   req.magic   = 11111; // Improved Scalp magic
   req.deviation = 10;

   if(OrderSend(req, res))
   {
      string alert_msg = "PTG IMPROVED " + (order_type==ORDER_TYPE_BUY_STOP?"LONG":"SHORT") + 
                        " @" + DoubleToString(req.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                        " TP@" + DoubleToString(req.tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                        " SL@" + DoubleToString(req.sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                        " Risk:" + DoubleToString(pip_risk,1) + "p";
      
      if(EnableAlerts) Alert(alert_msg);
      Print("✅ IMPROVED SCALP: ", (order_type==ORDER_TYPE_BUY_STOP?"LONG":"SHORT"),
            " ", lot_size, " lots | Risk: ", DoubleToString(pip_risk,1), "p | TP: +", QuickExitPips, "p");

      last_order_ticket = (int)res.order;
      order_place_time  = TimeCurrent();
      last_trade_time   = TimeCurrent();
   }
   else
   {
      Print("❌ IMPROVED TRADE #", total_trades, " FAILED: ", res.retcode, " - ", res.comment);
      total_trades--;
      ResetPositionVariables();
   }
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult&  result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Position opened?
         if(!position_active && trans.position > 0)
         {
            position_active = true;
            active_position_ticket = trans.position;

            string msg = StringFormat("🎯 IMPROVED ENTRY: %s %.2f lots at %.5f",
                        trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT",
                        trans.volume, trans.price);
            Print(msg); 
            if(EnableAlerts) Alert("PTG IMPROVED ENTRY " + (trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT"));
         }
         else if(position_active)
         {
            // Position closed (partial or full)
            double exit_price = trans.price;
            double profit_pips = 0.0;

            if(trans.deal_type == DEAL_TYPE_BUY)    // close buy -> sell
               profit_pips = (original_entry_price - exit_price)/pip_size;
            else                                     // close sell -> buy
               profit_pips = (exit_price - original_entry_price)/pip_size;

            string exit_type = profit_pips >= 0 ? "TP" : "SL";
            string profit_sign = (profit_pips >= 0 ? "+" : "");
            string msg = StringFormat("💰 IMPROVED EXIT %s: %s%.1f pips", exit_type, profit_sign, profit_pips);
            Print(msg); 
            if(EnableAlerts) Alert("PTG IMPROVED " + msg);

            // Check if full position closed
            if(trans.volume >= PositionGetDouble(POSITION_VOLUME))
               ResetPositionVariables();
         }
      }
   }
}
//+------------------------------------------------------------------+
