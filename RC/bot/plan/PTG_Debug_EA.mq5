//+------------------------------------------------------------------+
//|                                             PTG_Debug_EA.mq5     |
//|                        Debug version with relaxed parameters     |
//|                         Shows detailed logs for troubleshooting  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.00"

//--- Input parameters
input group "=== PTG RELAXED SETTINGS ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter
input int      LookbackPeriod     = 15;                // Lookback period (REDUCED from 20)

input group "=== PUSH PARAMETERS (RELAXED) ==="
input double   PushRangePercent   = 0.40;              // Range >= 40% (REDUCED from 60%)
input double   ClosePercent       = 0.50;              // Close position 50% (REDUCED from 60%)
input double   OppWickPercent     = 0.60;              // Opposite wick <= 60% (INCREASED from 40%)
input double   VolHighMultiplier  = 1.0;               // Volume >= 1.0x (REDUCED from 1.2x)

input group "=== TEST PARAMETERS (RELAXED) ==="
input int      TestBars           = 8;                 // Allow TEST within 8 bars (INCREASED from 5)
input double   PullbackMax        = 0.70;              // Pullback <= 70% (INCREASED from 50%)
input double   VolLowMultiplier   = 1.5;               // Volume TEST <= 1.5x (INCREASED from 1.0x)

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.1;               // Entry buffer (pips)
input double   SLBufferPips       = 0.1;               // Stop loss buffer (pips)
input double   TPMultiplier       = 2.0;               // Take profit multiplier
input double   RiskPercent        = 2.0;               // Risk per trade (%)
input double   MaxSpreadPips      = 10.0;              // Maximum spread (INCREASED from 3.0)

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // Disable time filter for more signals
input string   StartTime          = "00:00";           // Trading start time
input string   EndTime            = "23:59";           // Trading end time

input group "=== DEBUG SETTINGS ==="
input bool     EnableDebugLogs    = true;              // Enable detailed debug logs
input bool     EnableAlerts       = true;              // Enable TradingView alerts
input string   AlertKeyword       = "PTG";             // Alert keyword to detect

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
int            debug_counter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    string symbol = Symbol();
    
    // Set pip size based on symbol
    if(StringFind(symbol, "USD") >= 0 && StringFind(symbol, "JPY") < 0)
        pip_size = 0.0001;
    else if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        pip_size = 0.01;
    else if(StringFind(symbol, "JPY") >= 0)
        pip_size = 0.01;
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
    
    Print("=== PTG DEBUG EA v1.0 INITIALIZED ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("RELAXED PARAMETERS ENABLED FOR MORE SIGNALS");
    Print("Push Range: ", PushRangePercent*100, "% (vs 60% normal)");
    Print("Vol Multiplier: ", VolHighMultiplier, "x (vs 1.2x normal)");
    Print("Max Spread: ", MaxSpreadPips, " pips (vs 3 pips normal)");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    Print("PTG Debug EA deinitialized - Total debug messages: ", debug_counter);
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
    debug_counter++;
    
    if(EnableDebugLogs && debug_counter % 10 == 0)
        Print("DEBUG: Bar #", debug_counter, " - Checking conditions...");
    
    if(!GetMarketData())
    {
        if(EnableDebugLogs)
            Print("DEBUG: Failed to get market data");
        return;
    }
        
    if(!IsTradingAllowed())
    {
        if(EnableDebugLogs && debug_counter % 50 == 0)
            Print("DEBUG: Trading not allowed (spread/time/position check)");
        return;
    }
        
    PTG_Logic();
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
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    double current_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double spread = (current_ask - current_bid) / pip_size;
    
    if(spread > MaxSpreadPips)
    {
        if(EnableDebugLogs)
            Print("DEBUG: Spread too high: ", spread, " > ", MaxSpreadPips);
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
        {
            if(EnableDebugLogs)
                Print("DEBUG: Outside trading hours: ", current_hour);
            return false;
        }
    }
    
    if(PositionsTotal() > 0)
    {
        if(EnableDebugLogs && debug_counter % 20 == 0)
            Print("DEBUG: Position already exists");
        return false;
    }
        
    return true;
}

//+------------------------------------------------------------------+
//| Main PTG Logic with Debug Information                            |
//+------------------------------------------------------------------+
void PTG_Logic()
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
    
    // Get maximum range in lookback period
    double max_range = 0;
    for(int i = 1; i <= LookbackPeriod; i++)
    {
        double bar_range = iHigh(symbol, PERIOD_CURRENT, i) - iLow(symbol, PERIOD_CURRENT, i);
        if(bar_range > max_range)
            max_range = bar_range;
    }
    
    // Check trend filters
    bool up_trend = true;
    bool down_trend = true;
    
    if(UseEMAFilter && ArraySize(ema34) > 1 && ArraySize(ema55) > 1)
    {
        up_trend = (ema34[1] > ema55[1]);
        down_trend = (ema34[1] < ema55[1]);
    }
    
    // Volume and range conditions
    bool big_range = (range >= max_range * PushRangePercent);
    double vol_sma = GetVolumeSMA(LookbackPeriod, 1);
    bool high_volume = (volume >= vol_sma * VolHighMultiplier) && 
                      (volume > iVolume(symbol, PERIOD_CURRENT, 2));
    
    // PUSH detection with debug
    bool push_up = up_trend && big_range && high_volume && (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);
    
    // Debug PUSH conditions
    if(EnableDebugLogs && (push_up || push_down || debug_counter % 100 == 0))
    {
        Print("=== PUSH DEBUG (Bar ", debug_counter, ") ===");
        Print("Range: ", DoubleToString(range/pip_size, 1), " pips vs Max: ", DoubleToString(max_range/pip_size, 1), 
              " | Need: ", DoubleToString(max_range * PushRangePercent/pip_size, 1), " | BigRange: ", big_range);
        Print("Volume: ", volume, " vs SMA: ", DoubleToString(vol_sma, 0), 
              " | Need: ", DoubleToString(vol_sma * VolHighMultiplier, 0), " | HighVol: ", high_volume);
        Print("ClosePos Hi: ", DoubleToString(close_pos_hi*100, 1), "% (need ", DoubleToString(ClosePercent*100, 1), "%)");
        Print("ClosePos Lo: ", DoubleToString(close_pos_lo*100, 1), "% (need ", DoubleToString(ClosePercent*100, 1), "%)");
        Print("UpWick: ", DoubleToString(up_wick*100, 1), "% (max ", DoubleToString(OppWickPercent*100, 1), "%)");
        Print("LowWick: ", DoubleToString(low_wick*100, 1), "% (max ", DoubleToString(OppWickPercent*100, 1), "%)");
        Print("Trend Up: ", up_trend, " | Trend Down: ", down_trend);
        Print("PUSH UP: ", push_up, " | PUSH DOWN: ", push_down);
    }
    
    // Handle PUSH signals
    if(push_up || push_down)
    {
        wait_test = true;
        long_direction = push_up;
        push_bar_index = 0;
        push_high = high;
        push_low = low;
        push_range = range;
        test_high = 0;
        test_low = 0;
        
        string alert_msg = StringFormat("🔥 PTG PUSH %s detected! Range: %.1f pips | Vol: %.0f vs %.0f", 
                                       push_up ? "UP" : "DOWN", 
                                       range/pip_size, (double)volume, vol_sma);
        Print(alert_msg);
        if(EnableAlerts)
            Alert(alert_msg);
    }
    
    // TEST phase logic with debug
    if(wait_test)
    {
        push_bar_index++;
        
        if(EnableDebugLogs)
            Print("TEST Phase: Bar ", push_bar_index, "/", TestBars, " | Direction: ", long_direction ? "LONG" : "SHORT");
        
        if(push_bar_index >= 1 && push_bar_index <= TestBars)
        {
            bool pullback_ok_long = long_direction && ((push_high - low) <= PullbackMax * push_range);
            bool pullback_ok_short = !long_direction && ((high - push_low) <= PullbackMax * push_range);
            
            bool low_volume = (volume <= vol_sma * VolLowMultiplier);
            bool small_range = (range <= (max_range * 1.2) / LookbackPeriod);
            
            bool test_long = pullback_ok_long && low_volume && small_range;
            bool test_short = pullback_ok_short && low_volume && small_range;
            
            if(EnableDebugLogs && (test_long || test_short))
            {
                Print("=== TEST DETECTED ===");
                Print("Pullback Long OK: ", pullback_ok_long, " | Short OK: ", pullback_ok_short);
                Print("Low Volume: ", low_volume, " (", volume, " <= ", DoubleToString(vol_sma * VolLowMultiplier, 0), ")");
                Print("Small Range: ", small_range);
                Print("TEST LONG: ", test_long, " | TEST SHORT: ", test_short);
            }
            
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
                    
                    Print("🚀 PTG LONG SIGNAL | Entry: ", entry_level, " | SL: ", sl_level, " | TP: ", tp_level);
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Long DEBUG");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    Print("🔻 PTG SHORT SIGNAL | Entry: ", entry_level, " | SL: ", sl_level, " | TP: ", tp_level);
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Short DEBUG");
                }
                
                wait_test = false;
            }
        }
        
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            if(EnableDebugLogs)
                Print("TEST Phase TIMEOUT after ", TestBars, " bars");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade with detailed logging                              |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    string symbol = Symbol();
    
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * RiskPercent / 100.0;
    double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
    
    if(pip_risk <= 0)
    {
        Print("ERROR: Invalid pip risk calculation");
        return;
    }
    
    double pip_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    if(pip_value <= 0) pip_value = 1.0;
        
    double lot_size = risk_amount / (pip_risk * pip_value);
    
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
    request.magic = 12345;
    request.deviation = 10;
    
    Print("=== EXECUTING TRADE ===");
    Print("Type: ", order_type == ORDER_TYPE_BUY_STOP ? "BUY STOP" : "SELL STOP");
    Print("Lot: ", lot_size, " | Risk: ", DoubleToString(pip_risk, 1), " pips | $", DoubleToString(risk_amount, 2));
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ PTG %s ORDER PLACED - Lot: %.2f | Risk: %.1f pips | $%.2f",
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, pip_risk, risk_amount);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ ORDER FAILED: ", result.retcode, " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
            string msg = StringFormat("🎯 TRADE EXECUTED: %s %.2f lots at %.5f",
                                    trans.deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL",
                                    trans.volume, trans.price);
            Print(msg);
            if(EnableAlerts) Alert(msg);
        }
    }
}

//+------------------------------------------------------------------+
