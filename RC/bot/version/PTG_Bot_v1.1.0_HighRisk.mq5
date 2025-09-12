//+------------------------------------------------------------------+
//|                                    PTG Bot v1.1.0 HIGH RISK     |
//|                        Unlimited Profit Potential Algorithm      |
//|                         Optimized for XAUUSD M1 Timeframe      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.10"
#property description "PTG (Push-Test-Go) Bot - HIGH RISK UNLIMITED PROFIT VERSION"

//--- STABLE PARAMETERS (OPTIMIZED FOR PERFORMANCE)
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter
input int      LookbackPeriod     = 10;                // Lookback period for range calculation

input group "=== PUSH PARAMETERS (OPTIMIZED) ==="
input double   PushRangePercent   = 0.35;              // Range >= 35% (quality signals)
input double   ClosePercent       = 0.45;              // Close position 45% (momentum)
input double   OppWickPercent     = 0.65;              // Opposite wick <= 65% (strict)
input double   VolHighMultiplier  = 1.0;               // Volume >= 100% (strong confirmation)

input group "=== TEST PARAMETERS (BALANCED) ==="
input int      TestBars           = 10;                // Allow TEST within 10 bars
input int      PendingTimeout     = 5;                 // Remove pending orders after 5 bars
input double   PullbackMax        = 0.85;              // Pullback <= 85%
input double   VolLowMultiplier   = 2.0;               // Volume TEST <= 200%

input group "=== YOLO PIP MANAGEMENT ==="
input double   BreakevenPips      = 3.0;               // Move SL to entry when +X pips profit
input double   QuickExitPips      = 40.0;              // Fixed TP target (larger for better R:R)
input bool     UseQuickExit       = false;             // Disable quick exit - use fixed TP
input double   TrailStepPips     = 10.0;              // Trail SL every X pips profit
input double   MinProfitPips      = 5.0;               // Keep minimum X pips when trailing

input group "=== RISK MANAGEMENT (YOLO MODE) ==="
input double   EntryBufferPips    = 0.5;               // Entry buffer (optimized)
input double   SLBufferPips       = 0.5;               // Stop loss buffer (optimized)
input bool     UseFixedLotSize    = true;              // Use fixed lot size instead of % risk
input double   FixedLotSize       = 0.1;               // Fixed lot size (0.1 = $1 per pip for Gold)
input double   MaxSpreadPips      = 20.0;              // Maximum spread for Gold

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // Disable for 24/7 trading
input string   StartTime          = "00:00";           // Trading start time
input string   EndTime            = "23:59";           // Trading end time

input group "=== SYSTEM SETTINGS ==="
input bool     AllowMultiplePositions = false;        // Single position mode
input int      MinBarsBetweenTrades   = 1;             // Min bars between trades
input bool     EnableDebugLogs    = true;              // Enable detailed logging
input bool     EnableAlerts       = true;              // Enable alerts

input group "=== VERSION CONTROL ==="
input string   BotVersion        = "v1.1.0-e1h7c4g6";  // Bot version + UUID (change to force reload)

//--- Global variables
int            ema34_handle, ema55_handle;
double         ema34[], ema55[];
double         pip_size;
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

//--- YOLO Position Management Variables
double         original_entry_price = 0;
double         original_sl_price = 0;
bool           position_active = false;
ulong          active_position_ticket = 0;

//--- YOLO Pip Management Variables
bool           quick_exit_triggered = false;
bool           pip_breakeven_activated = false;
double         last_trail_level = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    string symbol = Symbol();
    
    // Set pip size correctly for Gold
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        pip_size = 0.01;  // Gold: 1 pip = 0.01
    else if(StringFind(symbol, "JPY") >= 0)
        pip_size = 0.01;  // JPY pairs: 1 pip = 0.01
    else if(StringFind(symbol, "USD") >= 0)
        pip_size = 0.0001;  // Major pairs: 1 pip = 0.0001
    else
        pip_size = 0.00001;  // 5-digit brokers
        
    // Initialize indicators
    ema34_handle = iMA(symbol, PERIOD_CURRENT, 34, 0, MODE_EMA, PRICE_CLOSE);
    ema55_handle = iMA(symbol, PERIOD_CURRENT, 55, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema34_handle == INVALID_HANDLE || ema55_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicators");
        return INIT_FAILED;
    }
    
    Print("=== PTG BOT YOLO MODE INITIALIZED ===");
    Print("🔧 VERSION: ", BotVersion, " | Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("🎰 YOLO PARAMETERS:");
    Print("Lot Size: ", FixedLotSize, " lots ($", FixedLotSize * 10, " per pip)");
    Print("🎯 PIP MANAGEMENT:");
    Print("Breakeven: +", BreakevenPips, "p | Quick Exit: +", QuickExitPips, "p");
    Print("Trail Step: +", TrailStepPips, "p | Keep Profit: +", MinProfitPips, "p");
    Print("🚨 YOLO MODE: SCALP FOR PIPS!");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    Print("=== PTG BOT v1.1.0 YOLO MODE STOPPED ===");
    Print("Total Signals: ", total_signals);
    Print("Total Trades: ", total_trades);
    Print("🎰 YOLO SUMMARY: ", FixedLotSize, " lots per trade");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(current_bar_time == last_bar_time)
        return;
        
    last_bar_time = current_bar_time;
    
    if(!GetMarketData())
        return;
        
    if(!IsTradingAllowed())
        return;
    
    CheckPendingOrderTimeout();
    
    // YOLO Position Management - Pip-based only
    if(position_active)
        ManageYoloPipPosition();
        
    PTG_MainLogic();
}

//+------------------------------------------------------------------+
//| Get market data and indicators                                   |
//+------------------------------------------------------------------+
bool GetMarketData()
{
    ArraySetAsSeries(ema34, true);
    ArraySetAsSeries(ema55, true);
    
    if(CopyBuffer(ema34_handle, 0, 0, LookbackPeriod + 5, ema34) <= 0)
        return false;
    if(CopyBuffer(ema55_handle, 0, 0, LookbackPeriod + 5, ema55) <= 0)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Calculate volume SMA manually                                    |
//+------------------------------------------------------------------+
double GetVolumeSMA(int period, int shift = 1)
{
    double sum = 0;
    string symbol = Symbol();
    
    for(int i = shift; i < shift + period; i++)
    {
        sum += (double)iVolume(symbol, PERIOD_CURRENT, i);
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Check and remove expired pending orders                          |
//+------------------------------------------------------------------+
void CheckPendingOrderTimeout()
{
    if(last_order_ticket <= 0 || order_place_time == 0)
        return;
    
    datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    int bars_elapsed = Bars(Symbol(), PERIOD_CURRENT, order_place_time, current_time) - 1;
    
    if(bars_elapsed >= PendingTimeout)
    {
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_REMOVE;
        request.order = last_order_ticket;
        
        if(OrderSend(request, result))
        {
            if(EnableDebugLogs)
                Print("⏰ TIMEOUT: Removed pending order #", last_order_ticket, " after ", bars_elapsed, " bars");
        }
        
        last_order_ticket = 0;
        order_place_time = 0;
    }
}

//+------------------------------------------------------------------+
//| YOLO: Manage position based on pip profits (scalping mode)       |
//+------------------------------------------------------------------+
void ManageYoloPipPosition()
{
    string symbol = Symbol();
    
    // Check if position still exists
    if(!PositionSelectByTicket(active_position_ticket))
    {
        ResetPositionVariables();
        return;
    }
    
    // Get current position info
    double current_price;
    bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    if(is_long)
        current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    else
        current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Calculate current profit in pips
    double profit_pips = is_long ? 
        (current_price - original_entry_price) / pip_size : 
        (original_entry_price - current_price) / pip_size;
    
    // Quick Exit Strategy - Take small profits fast
    if(UseQuickExit && !quick_exit_triggered && profit_pips >= QuickExitPips)
    {
        ClosePositionAtMarket("QUICK EXIT at +" + DoubleToString(profit_pips, 1) + "p");
        return;
    }
    
    // Pip-based Breakeven - Move SL to entry when profitable
    if(!pip_breakeven_activated && profit_pips >= BreakevenPips)
    {
        MoveSLToEntry("PIP BREAKEVEN at +" + DoubleToString(profit_pips, 1) + "p");
        return;
    }
    
    // Progressive pip trailing - Move SL every TrailStepPips
    if(pip_breakeven_activated && profit_pips >= (last_trail_level + TrailStepPips))
    {
        double new_trail_level = MathFloor(profit_pips / TrailStepPips) * TrailStepPips;
        double new_sl_pips = new_trail_level - MinProfitPips; // Keep some profit
        
        if(new_sl_pips > last_trail_level)
        {
            MoveSLToPipLevel(new_sl_pips, "TRAIL to +" + DoubleToString(new_sl_pips, 1) + "p");
            last_trail_level = new_trail_level;
        }
    }
}

//+------------------------------------------------------------------+
//| Close position at market price                                   |
//+------------------------------------------------------------------+
void ClosePositionAtMarket(string reason)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.position = active_position_ticket;
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = 10;
    request.comment = reason;
    
    if(OrderSend(request, result))
    {
        quick_exit_triggered = true;
        Print("🚀 ", reason, " - Position closed at market");
        if(EnableAlerts) Alert("YOLO " + reason);
    }
    else
    {
        Print("❌ QUICK EXIT FAILED: ", result.retcode, " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Move SL to entry level (breakeven)                              |
//+------------------------------------------------------------------+
void MoveSLToEntry(string reason)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = Symbol();
    request.position = active_position_ticket;
    request.sl = NormalizeDouble(original_entry_price, Digits());
    request.tp = PositionGetDouble(POSITION_TP); // Keep existing TP
    
    if(OrderSend(request, result))
    {
        pip_breakeven_activated = true;
        Print("🎯 ", reason, " - SL moved to entry (risk-free)");
        if(EnableAlerts) Alert("YOLO " + reason);
    }
    else
    {
        Print("❌ BREAKEVEN FAILED: ", result.retcode, " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Move SL to specific pip level                                    |
//+------------------------------------------------------------------+
void MoveSLToPipLevel(double pip_level, string reason)
{
    bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double new_sl = is_long ?
        original_entry_price + (pip_level * pip_size) :
        original_entry_price - (pip_level * pip_size);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = Symbol();
    request.position = active_position_ticket;
    request.sl = NormalizeDouble(new_sl, Digits());
    request.tp = PositionGetDouble(POSITION_TP);
    
    if(OrderSend(request, result))
    {
        Print("📈 ", reason, " - SL trailing activated");
        if(EnableAlerts) Alert("YOLO " + reason);
    }
    else
    {
        Print("❌ PIP TRAIL FAILED: ", result.retcode, " - ", result.comment);
    }
}


//+------------------------------------------------------------------+
//| Reset position tracking variables                                |
//+------------------------------------------------------------------+
void ResetPositionVariables()
{
    position_active = false;
    active_position_ticket = 0;
    original_entry_price = 0;
    original_sl_price = 0;
    
    // Reset YOLO pip management variables
    quick_exit_triggered = false;
    pip_breakeven_activated = false;
    last_trail_level = 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    double current_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double spread_points = (current_ask - current_bid) * MathPow(10, Digits());
    
    if(spread_points > MaxSpreadPips)
    {
        if(EnableDebugLogs && spread_points > MaxSpreadPips * 1.5)
            Print("SPREAD TOO HIGH: ", DoubleToString(spread_points, 0), " > ", MaxSpreadPips, " points");
        return false;
    }
    
    if(UseTimeFilter)
    {
        datetime server_time = TimeCurrent();
        MqlDateTime time_struct;
        TimeToStruct(server_time, time_struct);
        int current_hour = time_struct.hour;
        int start_hour = (int)StringToInteger(StringSubstr(StartTime, 0, 2));
        int end_hour = (int)StringToInteger(StringSubstr(EndTime, 0, 2));
        
        if(current_hour < start_hour || current_hour >= end_hour)
            return false;
    }
    
    if(!AllowMultiplePositions && (PositionsTotal() > 0 || position_active))
        return false;
    
    static datetime last_check_time = 0;
    datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(current_time - last_check_time < MinBarsBetweenTrades * PeriodSeconds(PERIOD_CURRENT))
        return false;
        
    last_check_time = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Main PTG Logic - HIGH RISK VERSION                              |
//+------------------------------------------------------------------+
void PTG_MainLogic()
{
    string symbol = Symbol();
    
    double high = iHigh(symbol, PERIOD_CURRENT, 1);
    double low = iLow(symbol, PERIOD_CURRENT, 1);
    double open = iOpen(symbol, PERIOD_CURRENT, 1);
    double close = iClose(symbol, PERIOD_CURRENT, 1);
    long volume = iVolume(symbol, PERIOD_CURRENT, 1);
    
    double range = high - low;
    double close_pos_hi = (close - low) / MathMax(range, pip_size);
    double close_pos_lo = (high - close) / MathMax(range, pip_size);
    double low_wick = (MathMin(open, close) - low) / MathMax(range, pip_size);
    double up_wick = (high - MathMax(open, close)) / MathMax(range, pip_size);
    
    double max_range = 0;
    for(int i = 1; i <= LookbackPeriod; i++)
    {
        double bar_range = iHigh(symbol, PERIOD_CURRENT, i) - iLow(symbol, PERIOD_CURRENT, i);
        if(bar_range > max_range)
            max_range = bar_range;
    }
    
    bool up_trend = true;
    bool down_trend = true;
    
    if(UseEMAFilter && ArraySize(ema34) > 1 && ArraySize(ema55) > 1)
    {
        up_trend = (ema34[1] > ema55[1]);
        down_trend = (ema34[1] < ema55[1]);
    }
    
    bool big_range = (range >= max_range * PushRangePercent);
    double vol_sma = GetVolumeSMA(LookbackPeriod, 1);
    bool high_volume = (volume >= vol_sma * VolHighMultiplier);
    
    bool push_up = up_trend && big_range && high_volume && (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);
    
    if(push_up || push_down)
    {
        total_signals++;
        wait_test = true;
        long_direction = push_up;
        push_bar_index = 0;
        push_high = high;
        push_low = low;
        push_range = range;
        test_high = 0;
        test_low = 0;
        
        // Reduced logging - only every 100th signal
        if(EnableDebugLogs && (total_signals % 100 == 0))
            Print("🔥 PUSH #", total_signals, " ", push_up ? "UP" : "DOWN");
    }
    
    if(wait_test)
    {
        push_bar_index++;
        
        if(push_bar_index >= 1 && push_bar_index <= TestBars)
        {
            bool pullback_ok_long = long_direction && ((push_high - low) <= PullbackMax * push_range);
            bool pullback_ok_short = !long_direction && ((high - push_low) <= PullbackMax * push_range);
            
            bool low_volume = (volume <= vol_sma * VolLowMultiplier);
            bool small_range = (range <= max_range);
            
            bool test_long = pullback_ok_long && low_volume && small_range;
            bool test_short = pullback_ok_short && low_volume && small_range;
            
            if(test_long || test_short)
            {
                test_high = high;
                test_low = low;
                
                double entry_level, sl_level, tp_level;
                
                if(test_long)
                {
                    entry_level = test_high + (EntryBufferPips * pip_size);
                    sl_level = test_low - (SLBufferPips * pip_size);
                    tp_level = entry_level + (QuickExitPips * pip_size); // Use QuickExitPips as initial TP
                    
                    // Reduced logging
                    
                    ExecuteYoloTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG YOLO Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - (QuickExitPips * pip_size); // Use QuickExitPips as initial TP
                    
                    // Reduced logging
                    
                    ExecuteYoloTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG YOLO Short");
                }
                
                wait_test = false;
            }
        }
        
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            // Reduced logging - timeout not critical
        }
    }
}

//+------------------------------------------------------------------+
//| Execute YOLO trade with fixed lot size                           |
//+------------------------------------------------------------------+
void ExecuteYoloTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    string symbol = Symbol();
    total_trades++;
    
    double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
    
    if(pip_risk <= 0)
    {
        Print("ERROR: Invalid pip risk calculation");
        return;
    }
    
    // Store original trade parameters
    original_entry_price = entry_price;
    original_sl_price = sl_price;
    
    // YOLO MODE: Fixed lot size only
    double lot_size = FixedLotSize;
    
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, MathFloor(lot_size / lot_step) * lot_step));
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = symbol;
    request.volume = lot_size;
    request.type = order_type;
    request.price = NormalizeDouble(entry_price, Digits());
    request.sl = NormalizeDouble(sl_price, Digits());
    request.tp = NormalizeDouble(tp_price, Digits());
    request.comment = comment;
    request.magic = 77777; // PTG v1.1.0 magic
    request.deviation = 10;
    
    if(OrderSend(request, result))
    {
        Print("✅ YOLO: ", order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT", " ", lot_size, " lots");
        if(EnableAlerts) Alert("YOLO " + (order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT"));
        
        last_order_ticket = (int)result.order;
        order_place_time = TimeCurrent();
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ YOLO TRADE #", total_trades, " FAILED: ", result.retcode, " - ", result.comment);
        total_trades--;
        ResetPositionVariables();
    }
}

//+------------------------------------------------------------------+
//| Trade transaction handler with R-multiple tracking              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
            if(!position_active && trans.position > 0)
            {
                // Position opened
                position_active = true;
                active_position_ticket = trans.position;
                
                string msg = StringFormat("🎯 ENTRY: %s %.2f lots at %.5f",
                                        trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT",
                                        trans.volume, trans.price);
                Print(msg);
                if(EnableAlerts) Alert(msg);
            }
            else if(position_active)
            {
                // Position closed
                double exit_price = trans.price;
                double profit_pips = (trans.deal_type == DEAL_TYPE_BUY) ? 
                    (original_entry_price - exit_price) / pip_size :
                    (exit_price - original_entry_price) / pip_size;
                
                if(trans.deal_type == DEAL_TYPE_SELL && original_entry_price > 0)
                    profit_pips = (exit_price - original_entry_price) / pip_size;
                
                string exit_type = profit_pips > 0 ? "TP" : "SL";
                string profit_sign = profit_pips >= 0 ? "+" : "";
                
                string msg = StringFormat("💰 EXIT %s: %s%.1f pips | $%.0f P&L",
                                        exit_type, profit_sign, profit_pips, 
                                        profit_pips * trans.volume * 10);
                Print(msg);
                if(EnableAlerts) Alert(msg);
                
                ResetPositionVariables();
            }
        }
    }
}

//+------------------------------------------------------------------+
