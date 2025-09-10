//+------------------------------------------------------------------+
//|                                PTG_Test_01_RELAXED.mq5          |
//|                                    RELAXED VERSION FOR TESTING  |
//|                              Emergency fix - less strict filter |
//+------------------------------------------------------------------+
#property copyright "PTG Test Suite - Emergency Fix"
#property version   "1.01R"
#property description "Test #1 RELAXED: More reasonable parameters"

//--- RELAXED PARAMETERS FOR TESTING
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter  
input int      LookbackPeriod     = 20;                // Standard lookback

input group "=== RELAXED PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.50;              // Range >= 50% (MORE REASONABLE)
input double   ClosePercent       = 0.60;              // Close position 60% (RELAXED)
input double   OppWickPercent     = 0.50;              // Opposite wick <= 50% (RELAXED)
input double   VolHighMultiplier  = 1.3;               // Volume >= 130% (RELAXED)

input group "=== TEST PARAMETERS ==="
input int      TestBars           = 8;                 // Longer test window
input int      PendingTimeout     = 10;                // Longer timeout
input double   PullbackMax        = 0.70;              // More pullback allowed
input double   VolLowMultiplier   = 1.0;               // Standard volume for test

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.5;               // Entry buffer
input double   SLBufferPips       = 0.5;               // Stop loss buffer
input double   TPMultiplier       = 2.0;               // Standard R:R
input bool     UseTrailingStop    = true;              // Enable trailing stop
input double   TrailingStopPips   = 15.0;             // Standard trailing
input double   RiskPercent        = 0.5;               // Conservative risk
input double   MaxSpreadPips      = 50.0;              // Higher spread tolerance

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // DISABLE for testing
input string   StartTime          = "00:00";           // All day
input string   EndTime            = "23:59";           // All day

input group "=== SYSTEM SETTINGS ==="
input bool     AllowMultiplePositions = false;        // Single position
input int      MinBarsBetweenTrades   = 2;             // Less spacing
input bool     EnableDebugLogs    = true;              // Detailed logging
input bool     EnableAlerts       = true;              // Enable alerts

//--- Global variables (same as original)
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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    string symbol = Symbol();
    
    // Set pip size correctly
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        pip_size = 0.01;
    else if(StringFind(symbol, "JPY") >= 0)
        pip_size = 0.01;
    else if(StringFind(symbol, "USD") >= 0)
        pip_size = 0.0001;
    else
        pip_size = 0.00001;
        
    // Initialize indicators
    ema34_handle = iMA(symbol, PERIOD_CURRENT, 34, 0, MODE_EMA, PRICE_CLOSE);
    ema55_handle = iMA(symbol, PERIOD_CURRENT, 55, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema34_handle == INVALID_HANDLE || ema55_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicators");
        return INIT_FAILED;
    }
    
    Print("=== PTG TEST #1 RELAXED: EMERGENCY FIX ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("RELAXED PARAMETERS:");
    Print("Push Range: ", PushRangePercent*100, "% (relaxed from 80%)");
    Print("Close Position: ", ClosePercent*100, "% (relaxed from 80%)");
    Print("Volume Multiplier: ", VolHighMultiplier, "x (relaxed from 2.0x)");
    Print("Time Filter: ", UseTimeFilter ? "ENABLED" : "DISABLED");
    Print("EXPECTED: Should get some signals and trades!");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    Print("=== TEST #1 RELAXED COMPLETED ===");
    Print("Total Signals: ", total_signals);
    Print("Total Trades: ", total_trades);
    Print("Signal Efficiency: ", total_trades > 0 ? DoubleToString((double)total_signals/total_trades, 2) : "N/A");
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
    
    if(UseTrailingStop && MQLInfoInteger(MQL_TESTER))
        ManageTrailingStop();
        
    PTG_RelaxedLogic();
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
//| Manage trailing stop for open positions                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    string symbol = Symbol();
    int positions = PositionsTotal();
    
    for(int i = 0; i < positions; i++)
    {
        if(PositionGetSymbol(i) != symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != 99999) continue; // Relaxed test magic
        
        double current_price;
        double current_sl = PositionGetDouble(POSITION_SL);
        double trailing_distance = TrailingStopPips * pip_size;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
            double new_sl = current_price - trailing_distance;
            
            if(new_sl > current_sl + pip_size)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_SLTP;
                request.symbol = symbol;
                request.position = PositionGetInteger(POSITION_TICKET);
                request.sl = NormalizeDouble(new_sl, Digits());
                request.tp = PositionGetDouble(POSITION_TP);
                
                if(OrderSend(request, result))
                {
                    if(EnableDebugLogs)
                        Print("📈 TRAILING: Long SL moved to ", new_sl, " (was ", current_sl, ")");
                }
            }
        }
        else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double new_sl = current_price + trailing_distance;
            
            if(new_sl < current_sl - pip_size || current_sl == 0)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_SLTP;
                request.symbol = symbol;
                request.position = PositionGetInteger(POSITION_TICKET);
                request.sl = NormalizeDouble(new_sl, Digits());
                request.tp = PositionGetDouble(POSITION_TP);
                
                if(OrderSend(request, result))
                {
                    if(EnableDebugLogs)
                        Print("📉 TRAILING: Short SL moved to ", new_sl, " (was ", current_sl, ")");
                }
            }
        }
    }
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
        if(EnableDebugLogs)
            Print("SPREAD TOO HIGH: ", spread_points, " > ", MaxSpreadPips, " points");
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
    
    if(!AllowMultiplePositions && PositionsTotal() > 0)
        return false;
    
    static datetime last_check_time = 0;
    datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(current_time - last_check_time < MinBarsBetweenTrades * PeriodSeconds(PERIOD_CURRENT))
        return false;
        
    last_check_time = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Relaxed PTG Logic                                                |
//+------------------------------------------------------------------+
void PTG_RelaxedLogic()
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
    
    // Get max range from lookback period
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
    
    // RELAXED conditions
    bool big_range = (range >= max_range * PushRangePercent);
    double vol_sma = GetVolumeSMA(LookbackPeriod, 1);
    bool high_volume = (volume >= vol_sma * VolHighMultiplier);
    
    // Debug range and volume info
    if(EnableDebugLogs && big_range)
    {
        Print("DEBUG: Range check - Current: ", DoubleToString(range/pip_size, 1), "p | Max: ", 
              DoubleToString(max_range/pip_size, 1), "p | Required: ", 
              DoubleToString(max_range * PushRangePercent/pip_size, 1), "p");
    }
    
    if(EnableDebugLogs && high_volume)
    {
        Print("DEBUG: Volume check - Current: ", volume, " | SMA: ", DoubleToString(vol_sma, 0), 
              " | Required: ", DoubleToString(vol_sma * VolHighMultiplier, 0));
    }
    
    bool push_up = up_trend && big_range && high_volume &&
                   (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume &&
                     (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);
    
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
        
        if(EnableDebugLogs)
        {
            string msg = StringFormat("🔥 RELAXED PUSH #%d %s | Range: %.1fp | Vol: %.0f/%.0f | ClosePos: %.1f%% | Wick: %.1f%%", 
                                     total_signals, push_up ? "UP" : "DOWN", 
                                     range/pip_size, (double)volume, vol_sma,
                                     (push_up ? close_pos_hi : close_pos_lo) * 100,
                                     (push_up ? up_wick : low_wick) * 100);
            Print(msg);
        }
    }
    
    if(wait_test)
    {
        push_bar_index++;
        
        if(push_bar_index >= 1 && push_bar_index <= TestBars)
        {
            bool pullback_ok_long = long_direction && ((push_high - low) <= PullbackMax * push_range);
            bool pullback_ok_short = !long_direction && ((high - push_low) <= PullbackMax * push_range);
            
            bool low_volume = (volume <= vol_sma * VolLowMultiplier);
            bool small_range = (range <= max_range * 0.8); // Allow moderate range for test
            
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
                    tp_level = entry_level + ((entry_level - sl_level) * TPMultiplier);
                    
                    if(EnableDebugLogs)
                        Print("🚀 RELAXED LONG #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Relaxed Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    if(EnableDebugLogs)
                        Print("🔻 RELAXED SHORT #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Relaxed Short");
                }
                
                wait_test = false;
            }
            else
            {
                if(EnableDebugLogs)
                {
                    Print("TEST BAR #", push_bar_index, " - Pullback: ", 
                          long_direction ? (push_high - low)/push_range*100 : (high - push_low)/push_range*100, 
                          "% | Vol: ", volume, "/", DoubleToString(vol_sma, 0), " | Range: ", range/pip_size, "p");
                }
            }
        }
        
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            if(EnableDebugLogs)
                Print("TEST TIMEOUT after ", TestBars, " bars - Signal #", total_signals, " rejected");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade with standard risk management                      |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    string symbol = Symbol();
    total_trades++;
    
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * RiskPercent / 100.0;
    double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
    
    if(pip_risk <= 0)
    {
        Print("ERROR: Invalid pip risk calculation");
        return;
    }
    
    double pip_value;
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        pip_value = 10.0;
    else
    {
        pip_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        if(pip_value <= 0) pip_value = 1.0;
    }
        
    double lot_size = risk_amount / (pip_risk * pip_value);
    
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, MathFloor(lot_size / lot_step) * lot_step));
    lot_size = MathMin(lot_size, 1.0);
    
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
    request.magic = 99999; // Relaxed test magic number
    request.deviation = 10;
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ RELAXED TRADE #%d: %s %.2f lots | Risk: %.1fp | Entry: %.5f | SL: %.5f | TP: %.5f",
                                 total_trades,
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, pip_risk, entry_price, sl_price, tp_price);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        
        last_order_ticket = (int)result.order;
        order_place_time = TimeCurrent();
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ RELAXED TRADE #", total_trades, " FAILED: ", result.retcode, " - ", result.comment);
        total_trades--;
    }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    static double last_entry_price = 0;
    static bool is_position_open = false;
    
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
            if(!is_position_open)
            {
                last_entry_price = trans.price;
                is_position_open = true;
                
                string msg = StringFormat("🎯 RELAXED ENTRY: %s %.2f lots at %.5f",
                                        trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT",
                                        trans.volume, trans.price);
                Print(msg);
                if(EnableAlerts) Alert(msg);
            }
            else
            {
                double exit_price = trans.price;
                double profit_pips = (exit_price - last_entry_price) / pip_size;
                
                if(trans.deal_type == DEAL_TYPE_BUY && last_entry_price > exit_price)
                    profit_pips = (last_entry_price - exit_price) / pip_size;
                
                string exit_type = profit_pips > 0 ? "TP" : "SL";
                string profit_sign = profit_pips >= 0 ? "+" : "";
                
                string msg = StringFormat("💰 RELAXED EXIT %s: %s%.1f pips | Entry: %.5f | Exit: %.5f",
                                        exit_type, profit_sign, profit_pips,
                                        last_entry_price, exit_price);
                Print(msg);
                if(EnableAlerts) Alert(msg);
                
                last_entry_price = 0;
                is_position_open = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
