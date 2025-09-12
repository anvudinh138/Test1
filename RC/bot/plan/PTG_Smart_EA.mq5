//+------------------------------------------------------------------+
//|                                                  PTG_Smart_EA.mq5 |
//|                        Copyright 2024, PTG Trading Strategy      |
//|                                   Converted from Pine Script v5  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.00"

//--- Include configuration (same folder)
#include "PTG_Config.mqh"

//--- Input parameters
input group "=== PTG CORE SETTINGS ==="
input string   TradingPair        = "XAUUSD";           // Trading Pair (EURUSD/XAUUSD)
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter
input int      LookbackPeriod     = 20;                // Lookback period for range calculation

input group "=== PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.60;              // Range >= 60% of max range
input double   ClosePercent       = 0.60;              // Close position 60-100% of extreme
input double   OppWickPercent     = 0.40;              // Opposite wick <= 40% of range
input double   VolHighMultiplier  = 1.2;               // Volume >= 1.2x SMA Volume

input group "=== TEST PARAMETERS ==="
input int      TestBars           = 5;                 // Allow TEST within 1-5 bars
input double   PullbackMax        = 0.50;              // Pullback <= 50% of PUSH range
input double   VolLowMultiplier   = 1.0;               // Volume TEST <= 1.0x SMA Volume

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.1;               // Entry buffer (pips)
input double   SLBufferPips       = 0.1;               // Stop loss buffer (pips)
input double   TPMultiplier       = 2.0;               // Take profit multiplier
input double   RiskPercent        = 2.0;               // Risk per trade (%)
input double   MaxSpreadPips      = 3.0;               // Maximum spread allowed (pips)

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = false;             // Enable trading time filter
input string   StartTime          = "07:00";           // Trading start time
input string   EndTime            = "22:00";           // Trading end time

input group "=== ALERT INTEGRATION ==="
input bool     EnableAlerts       = true;              // Enable TradingView alerts
input string   AlertKeyword       = "PTG";             // Alert keyword to detect

//--- Global variables
int            ema34_handle, ema55_handle, volume_handle;
double         ema34[], ema55[], volume_sma[];
double         pip_size;
bool           wait_test = false;
bool           long_direction = false;
int            push_bar_index = 0;
double         push_high, push_low, push_range;
double         test_high = 0, test_low = 0;
datetime       last_trade_time = 0;
PTGConfig      ptg_config; // Configuration object

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Get optimized configuration for this symbol
    ptg_config = GetPTGConfig(_Symbol);
    
    // Set pip size based on symbol
    if(StringFind(_Symbol, "USD") >= 0 && StringFind(_Symbol, "JPY") < 0)
        pip_size = 0.0001;
    else if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
        pip_size = 0.01;
    else
        pip_size = 0.00001; // For most majors
        
    // Initialize indicators
    ema34_handle = iMA(_Symbol, PERIOD_CURRENT, 34, 0, MODE_EMA, PRICE_CLOSE);
    ema55_handle = iMA(_Symbol, PERIOD_CURRENT, 55, 0, MODE_EMA, PRICE_CLOSE);
    volume_handle = iMA(_Symbol, PERIOD_CURRENT, LookbackPeriod, 0, MODE_SMA, PRICE_VOLUME);
    
    if(ema34_handle == INVALID_HANDLE || ema55_handle == INVALID_HANDLE || volume_handle == INVALID_HANDLE)
    {
        Print("Error creating indicators");
        return INIT_FAILED;
    }
    
    Print("PTG Smart EA v1.0 initialized successfully");
    Print("Symbol: ", _Symbol, " | Pip size: ", pip_size);
    Print("Risk per trade: ", RiskPercent, "%");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    IndicatorRelease(volume_handle);
    Print("PTG Smart EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new bar
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(current_bar_time == last_bar_time)
        return; // Wait for new bar
        
    last_bar_time = current_bar_time;
    
    // Get market data
    if(!GetMarketData())
        return;
        
    // Check trading conditions
    if(!IsTradingAllowed())
        return;
        
    // Main PTG logic
    PTG_Logic();
}

//+------------------------------------------------------------------+
//| Get market data and indicators                                   |
//+------------------------------------------------------------------+
bool GetMarketData()
{
    // Resize arrays
    ArraySetAsSeries(ema34, true);
    ArraySetAsSeries(ema55, true);
    ArraySetAsSeries(volume_sma, true);
    
    // Copy indicator data
    if(CopyBuffer(ema34_handle, 0, 0, LookbackPeriod + 5, ema34) <= 0)
        return false;
    if(CopyBuffer(ema55_handle, 0, 0, LookbackPeriod + 5, ema55) <= 0)
        return false;
    if(CopyBuffer(volume_handle, 0, 0, LookbackPeriod + 5, volume_sma) <= 0)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // Check spread
    double spread = (Ask - Bid) / pip_size;
    if(spread > MaxSpreadPips)
    {
        Print("Spread too high: ", spread, " pips");
        return false;
    }
    
    // Check time filter
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
    
    // Check if position already exists
    if(PositionsTotal() > 0)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Main PTG Logic Implementation                                    |
//+------------------------------------------------------------------+
void PTG_Logic()
{
    // Get current bar data
    double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low = iLow(_Symbol, PERIOD_CURRENT, 1);
    double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
    double close = iClose(_Symbol, PERIOD_CURRENT, 1);
    long volume = iVolume(_Symbol, PERIOD_CURRENT, 1);
    
    // Calculate range and position metrics
    double range = high - low;
    double close_pos_hi = (close - low) / MathMax(range, pip_size);
    double close_pos_lo = (high - close) / MathMax(range, pip_size);
    double low_wick = (MathMin(open, close) - low) / MathMax(range, pip_size);
    double up_wick = (high - MathMax(open, close)) / MathMax(range, pip_size);
    
    // Get maximum range in lookback period
    double max_range = 0;
    for(int i = 1; i <= LookbackPeriod; i++)
    {
        double bar_range = iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
        if(bar_range > max_range)
            max_range = bar_range;
    }
    
    // Check trend filters
    bool up_trend = true;
    bool down_trend = true;
    
    if(UseEMAFilter)
    {
        up_trend = up_trend && (ema34[1] > ema55[1]);
        down_trend = down_trend && (ema34[1] < ema55[1]);
    }
    
    // Volume and range conditions
    bool big_range = (range >= max_range * PushRangePercent);
    bool high_volume = (volume >= volume_sma[1] * VolHighMultiplier) && (volume > iVolume(_Symbol, PERIOD_CURRENT, 2));
    
    // PUSH detection
    bool push_up = up_trend && big_range && high_volume && (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && (close_pos_lo >= ClosePercent) && (low_wick <= OppWickPercent);
    
    // Handle PUSH signals
    if(push_up || push_down)
    {
        wait_test = true;
        long_direction = push_up;
        push_bar_index = 0; // Reset counter
        push_high = high;
        push_low = low;
        push_range = range;
        test_high = 0;
        test_low = 0;
        
        if(EnableAlerts)
        {
            string alert_msg = StringFormat("PTG PUSH %s detected on %s", 
                                           push_up ? "UP" : "DOWN", _Symbol);
            Alert(alert_msg);
            Print(alert_msg);
        }
    }
    
    // TEST phase logic
    if(wait_test)
    {
        push_bar_index++;
        
        if(push_bar_index >= 1 && push_bar_index <= TestBars)
        {
            // Check pullback conditions
            bool pullback_ok_long = long_direction && ((push_high - low) <= PullbackMax * push_range);
            bool pullback_ok_short = !long_direction && ((high - push_low) <= PullbackMax * push_range);
            
            // Volume and range conditions for TEST
            bool low_volume = (volume <= volume_sma[1] * VolLowMultiplier);
            bool small_range = (range <= (max_range * 1.2) / LookbackPeriod); // Approximation
            
            bool test_long = pullback_ok_long && low_volume && small_range;
            bool test_short = pullback_ok_short && low_volume && small_range;
            
            if(test_long || test_short)
            {
                test_high = high;
                test_low = low;
                
                // Calculate entry levels
                double entry_level, sl_level, tp_level;
                
                if(test_long)
                {
                    entry_level = test_high + (EntryBufferPips * pip_size);
                    sl_level = test_low - (SLBufferPips * pip_size);
                    tp_level = entry_level + ((entry_level - sl_level) * TPMultiplier);
                    
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Short");
                }
                
                // Reset wait state
                wait_test = false;
            }
        }
        
        // Timeout TEST phase
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            if(EnableAlerts)
                Print("PTG TEST phase timeout");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade with proper risk management                        |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    // Calculate position size based on risk
    double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
    double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
    
    if(pip_risk <= 0)
    {
        Print("Invalid pip risk calculation");
        return;
    }
    
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(pip_value <= 0)
        pip_value = 1.0; // Fallback
        
    double lot_size = risk_amount / (pip_risk * pip_value);
    
    // Normalize lot size
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, MathFloor(lot_size / lot_step) * lot_step));
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = order_type;
    request.price = NormalizeDouble(entry_price, _Digits);
    request.sl = NormalizeDouble(sl_price, _Digits);
    request.tp = NormalizeDouble(tp_price, _Digits);
    request.comment = comment;
    request.magic = 12345; // PTG Magic number
    request.deviation = 10; // Price deviation in points
    
    // Send order
    if(OrderSend(request, result))
    {
        string alert_msg = StringFormat("PTG %s order placed: Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Risk=%.1f pips",
                                       order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                       lot_size, entry_price, sl_price, tp_price, pip_risk);
        
        if(EnableAlerts)
            Alert(alert_msg);
        Print(alert_msg);
        
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("Order failed: ", result.retcode, " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Handle TradingView alerts via comment                           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Handle position events
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
            string msg = StringFormat("PTG Trade executed: %s %.2f lots at %.5f",
                                    trans.deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL",
                                    trans.volume, trans.price);
            Print(msg);
            if(EnableAlerts)
                Alert(msg);
        }
    }
}

//+------------------------------------------------------------------+
//| Handle TradingView webhook alerts (if using web integration)    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_CUSTOM)
    {
        // Parse TradingView alert
        if(StringFind(sparam, AlertKeyword) >= 0)
        {
            Print("TradingView alert received: ", sparam);
            
            // Parse alert message for LONG/SHORT signals
            if(StringFind(sparam, "LONG") >= 0)
            {
                // Handle long signal from TradingView
                Print("External LONG signal detected");
            }
            else if(StringFind(sparam, "SHORT") >= 0)
            {
                // Handle short signal from TradingView
                Print("External SHORT signal detected");
            }
        }
    }
}

//+------------------------------------------------------------------+
