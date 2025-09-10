//+------------------------------------------------------------------+
//|                                         PTG_High_Frequency.mq5   |
//|                        More aggressive parameters for more trades |
//|                         Closer to TradingView indicator behavior |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.00"

//--- AGGRESSIVE INPUTS FOR MORE TRADES
input group "=== HIGH FREQUENCY PTG ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter
input int      LookbackPeriod     = 10;                // REDUCED lookback (was 20)

input group "=== AGGRESSIVE PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.25;              // Range >= 25% (was 60%)
input double   ClosePercent       = 0.35;              // Close position 35% (was 60%)
input double   OppWickPercent     = 0.75;              // Opposite wick <= 75% (was 40%)
input double   VolHighMultiplier  = 0.8;               // Volume >= 80% (was 120%)

input group "=== AGGRESSIVE TEST PARAMETERS ==="
input int      TestBars           = 10;                // Allow TEST within 10 bars (was 5)
input double   PullbackMax        = 0.85;              // Pullback <= 85% (was 50%)
input double   VolLowMultiplier   = 2.0;               // Volume TEST <= 200% (was 100%)

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.1;               // Entry buffer (pips)
input double   SLBufferPips       = 0.1;               // Stop loss buffer (pips)
input double   TPMultiplier       = 1.5;               // TP multiplier (REDUCED for more wins)
input double   RiskPercent        = 1.0;               // Risk per trade (REDUCED)
input double   MaxSpreadPips      = 15.0;              // Maximum spread (high tolerance)

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // Disable for 24/7 trading
input string   StartTime          = "00:00";           // Trading start time
input string   EndTime            = "23:59";           // Trading end time

input group "=== FREQUENCY SETTINGS ==="
input bool     AllowMultiplePositions = false;        // Allow multiple positions
input int      MinBarsBetweenTrades   = 1;             // Min bars between trades (was 60)
input bool     EnableDebugLogs    = true;              // Enable detailed debug logs
input bool     EnableAlerts       = true;              // Enable alerts

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    string symbol = Symbol();
    
    // Set pip size
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
    
    Print("=== PTG HIGH FREQUENCY EA v1.0 INITIALIZED ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("AGGRESSIVE PARAMETERS FOR MORE TRADES:");
    Print("Push Range: ", PushRangePercent*100, "% (vs 60% normal)");
    Print("Close Position: ", ClosePercent*100, "% (vs 60% normal)");
    Print("Vol Multiplier: ", VolHighMultiplier, "x (vs 1.2x normal)");
    Print("Test Bars: ", TestBars, " (vs 5 normal)");
    Print("TARGET: 100+ trades like TradingView!");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    Print("=== PTG HIGH FREQUENCY EA STOPPED ===");
    Print("Total Signals: ", total_signals);
    Print("Total Trades: ", total_trades);
    Print("Signal to Trade Ratio: ", total_trades > 0 ? DoubleToString((double)total_signals/total_trades, 2) : "N/A");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check EVERY BAR (not every 10th like Ultra Simple)
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(current_bar_time == last_bar_time)
        return;
        
    last_bar_time = current_bar_time;
    
    static int bar_counter = 0;
    bar_counter++;
    
    if(!GetMarketData())
        return;
        
    if(!IsTradingAllowed())
        return;
        
    PTG_HighFrequency_Logic();
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
//| Check if trading is allowed (more permissive)                    |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // Check spread
    double current_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double spread = (current_ask - current_bid) / pip_size;
    
    if(spread > MaxSpreadPips)
        return false;
    
    // Time filter (usually disabled)
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
    
    // Position check (more permissive)
    if(!AllowMultiplePositions && PositionsTotal() > 0)
        return false;
    
    // Minimum time between trades (very short)
    static datetime last_check_time = 0;
    datetime current_time = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(current_time - last_check_time < MinBarsBetweenTrades * PeriodSeconds(PERIOD_CURRENT))
        return false;
        
    last_check_time = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| High Frequency PTG Logic                                         |
//+------------------------------------------------------------------+
void PTG_HighFrequency_Logic()
{
    string symbol = Symbol();
    
    // Get current bar data
    double high = iHigh(symbol, PERIOD_CURRENT, 1);
    double low = iLow(symbol, PERIOD_CURRENT, 1);
    double open = iOpen(symbol, PERIOD_CURRENT, 1);
    double close = iClose(symbol, PERIOD_CURRENT, 1);
    long volume = iVolume(symbol, PERIOD_CURRENT, 1);
    
    // Calculate range and position metrics
    double range = high - low;
    double close_pos_hi = (close - low) / MathMax(range, pip_size);
    double close_pos_lo = (high - close) / MathMax(range, pip_size);
    double low_wick = (MathMin(open, close) - low) / MathMax(range, pip_size);
    double up_wick = (high - MathMax(open, close)) / MathMax(range, pip_size);
    
    // Get maximum range in lookback period (SHORTER period = more signals)
    double max_range = 0;
    for(int i = 1; i <= LookbackPeriod; i++)
    {
        double bar_range = iHigh(symbol, PERIOD_CURRENT, i) - iLow(symbol, PERIOD_CURRENT, i);
        if(bar_range > max_range)
            max_range = bar_range;
    }
    
    // Check trend filters (usually disabled for more signals)
    bool up_trend = true;
    bool down_trend = true;
    
    if(UseEMAFilter && ArraySize(ema34) > 1 && ArraySize(ema55) > 1)
    {
        up_trend = (ema34[1] > ema55[1]);
        down_trend = (ema34[1] < ema55[1]);
    }
    
    // RELAXED Volume and range conditions
    bool big_range = (range >= max_range * PushRangePercent);
    double vol_sma = GetVolumeSMA(LookbackPeriod, 1);
    bool high_volume = (volume >= vol_sma * VolHighMultiplier); // Removed volume increase requirement
    
    // RELAXED PUSH detection
    bool push_up = up_trend && big_range && high_volume && (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);
    
    // Debug every 50 bars if no signals
    static int debug_counter = 0;
    debug_counter++;
    
    if(EnableDebugLogs && (push_up || push_down || debug_counter % 50 == 0))
    {
        Print("=== PUSH CHECK (Bar ", debug_counter, ") ===");
        Print("Range: ", DoubleToString(range/pip_size, 1), "p vs Max: ", DoubleToString(max_range/pip_size, 1), 
              "p | Need: ", DoubleToString(max_range * PushRangePercent/pip_size, 1), "p | OK: ", big_range);
        Print("Volume: ", volume, " vs SMA: ", DoubleToString(vol_sma, 0), 
              " | Need: ", DoubleToString(vol_sma * VolHighMultiplier, 0), " | OK: ", high_volume);
        Print("Close Hi: ", DoubleToString(close_pos_hi*100, 1), "% (need ", DoubleToString(ClosePercent*100, 1), "%)");
        Print("Close Lo: ", DoubleToString(close_pos_lo*100, 1), "% (need ", DoubleToString(ClosePercent*100, 1), "%)");
        Print("UpWick: ", DoubleToString(up_wick*100, 1), "% (max ", DoubleToString(OppWickPercent*100, 1), "%)");
        Print("LowWick: ", DoubleToString(low_wick*100, 1), "% (max ", DoubleToString(OppWickPercent*100, 1), "%)");
        Print("PUSH UP: ", push_up, " | PUSH DOWN: ", push_down);
    }
    
    // Handle PUSH signals
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
            string msg = StringFormat("🔥 PUSH #%d %s | Range: %.1fp | Vol: %.0f/%.0f", 
                                     total_signals, push_up ? "UP" : "DOWN", 
                                     range/pip_size, (double)volume, vol_sma);
            Print(msg);
        }
    }
    
    // AGGRESSIVE TEST phase logic
    if(wait_test)
    {
        push_bar_index++;
        
        if(push_bar_index >= 1 && push_bar_index <= TestBars)
        {
            // RELAXED pullback conditions
            bool pullback_ok_long = long_direction && ((push_high - low) <= PullbackMax * push_range);
            bool pullback_ok_short = !long_direction && ((high - push_low) <= PullbackMax * push_range);
            
            // RELAXED volume and range conditions for TEST
            bool low_volume = (volume <= vol_sma * VolLowMultiplier); // Much higher threshold
            bool small_range = (range <= max_range); // Just smaller than max (was complex calculation)
            
            bool test_long = pullback_ok_long && low_volume && small_range;
            bool test_short = pullback_ok_short && low_volume && small_range;
            
            if(EnableDebugLogs && (test_long || test_short))
            {
                Print("=== TEST PHASE BAR ", push_bar_index, " ===");
                Print("Pullback Long: ", pullback_ok_long, " | Short: ", pullback_ok_short);
                Print("Low Vol: ", low_volume, " | Small Range: ", small_range);
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
                    
                    if(EnableDebugLogs)
                        Print("🚀 LONG SIGNAL #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG HF Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    if(EnableDebugLogs)
                        Print("🔻 SHORT SIGNAL #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG HF Short");
                }
                
                wait_test = false;
            }
        }
        
        // Longer timeout for more opportunities
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            if(EnableDebugLogs)
                Print("TEST TIMEOUT after ", TestBars, " bars");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade with risk management                               |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    string symbol = Symbol();
    total_trades++;
    
    // Calculate position size based on risk
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
    
    // Normalize lot size
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, MathFloor(lot_size / lot_step) * lot_step));
    
    // Prepare trade request
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
    request.magic = 77777; // High Frequency magic
    request.deviation = 10;
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ TRADE #%d: %s %.2f lots | Risk: %.1fp | S/T: %d/%d",
                                 total_trades,
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, pip_risk, total_signals, total_trades);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ TRADE #", total_trades, " FAILED: ", result.retcode, " - ", result.comment);
        total_trades--; // Revert counter
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
            string msg = StringFormat("🎯 EXECUTED: %s %.2f lots at %.5f",
                                    trans.deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL",
                                    trans.volume, trans.price);
            Print(msg);
            if(EnableAlerts) Alert(msg);
        }
    }
}

//+------------------------------------------------------------------+
