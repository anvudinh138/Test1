//+------------------------------------------------------------------+
//|                             PTG_Test_03_Market_Structure.mq5    |
//|                                    MARKET STRUCTURE AWARENESS   |
//|                              Sessions + Volatility + S/R Levels |
//+------------------------------------------------------------------+
#property copyright "PTG Test Suite"
#property version   "1.03"
#property description "Test #3: MARKET STRUCTURE - Sessions, Volatility, S/R"

//--- MARKET STRUCTURE PARAMETERS
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter  
input int      LookbackPeriod     = 30;                // Extended market context

input group "=== STRUCTURE-AWARE PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.65;              // Range >= 65% (selective)
input double   ClosePercent       = 0.70;              // Close position 70% (strong)
input double   OppWickPercent     = 0.40;              // Opposite wick <= 40%
input double   VolHighMultiplier  = 1.3;               // Volume >= 130%
input double   MinRangePips       = 50.0;              // Minimum 50-pip moves only

input group "=== MARKET STRUCTURE FILTERS ==="
input bool     UseSessionFilter   = true;              // Enable session filtering
input bool     UseVolatilityFilter = true;             // Enable volatility filtering
input bool     UseSRLevels        = true;              // Enable S/R level detection
input double   ATRMultiplier      = 1.2;               // ATR > 1.2x average for volatility
input int      ATRPeriod          = 14;                // ATR calculation period

input group "=== SESSION SETTINGS ==="
input bool     TradeLondonSession = true;              // 07:00-16:00 GMT
input bool     TradeNYSession     = true;              // 13:00-22:00 GMT
input bool     TradeOverlapOnly   = false;             // Only London/NY overlap 13:00-16:00

input group "=== TEST PARAMETERS ==="
input int      TestBars           = 5;                 // Standard test window
input int      PendingTimeout     = 7;                 // Longer timeout for structure
input double   PullbackMax        = 0.50;              // Standard pullback
input double   VolLowMultiplier   = 1.0;               // Standard volume for test

input group "=== RISK MANAGEMENT ==="
input double   EntryBufferPips    = 1.0;               // Larger buffer for structure
input double   SLBufferPips       = 1.0;               // Larger SL buffer
input double   TPMultiplier       = 2.0;               // Standard R:R
input bool     UseTrailingStop    = true;              // Enable trailing stop
input double   TrailingStopPips   = 20.0;             // Wider trailing for structure
input double   RiskPercent        = 0.5;               // Conservative risk
input double   MaxSpreadPips      = 35.0;              // Moderate spread filter

input group "=== SYSTEM SETTINGS ==="
input bool     AllowMultiplePositions = false;        // Single position
input int      MinBarsBetweenTrades   = 10;            // More spacing for quality
input bool     EnableDebugLogs    = true;              // Detailed logging
input bool     EnableAlerts       = true;              // Enable alerts

//--- Global variables
int            ema34_handle, ema55_handle, atr_handle;
double         ema34[], ema55[], atr[];
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
    atr_handle = iATR(symbol, PERIOD_CURRENT, ATRPeriod);
    
    if(ema34_handle == INVALID_HANDLE || ema55_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicators");
        return INIT_FAILED;
    }
    
    Print("=== PTG TEST #3: MARKET STRUCTURE ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("STRUCTURE PARAMETERS:");
    Print("Min Range: ", MinRangePips, " pips");
    Print("ATR Multiplier: ", ATRMultiplier, "x");
    Print("Session Filter: ", UseSessionFilter ? "ENABLED" : "DISABLED");
    Print("Volatility Filter: ", UseVolatilityFilter ? "ENABLED" : "DISABLED");
    Print("EXPECTED: High-quality structure-aware signals");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    IndicatorRelease(atr_handle);
    Print("=== TEST #3 COMPLETED ===");
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
        
    PTG_StructureLogic();
}

//+------------------------------------------------------------------+
//| Get market data and indicators                                   |
//+------------------------------------------------------------------+
bool GetMarketData()
{
    ArraySetAsSeries(ema34, true);
    ArraySetAsSeries(ema55, true);
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(ema34_handle, 0, 0, LookbackPeriod + 5, ema34) <= 0)
        return false;
    if(CopyBuffer(ema55_handle, 0, 0, LookbackPeriod + 5, ema55) <= 0)
        return false;
    if(CopyBuffer(atr_handle, 0, 0, ATRPeriod + 5, atr) <= 0)
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
//| Check if current time is in active trading session              |
//+------------------------------------------------------------------+
bool IsActiveSession()
{
    if(!UseSessionFilter)
        return true;
        
    datetime server_time = TimeCurrent();
    MqlDateTime time_struct;
    TimeToStruct(server_time, time_struct);
    int current_hour = time_struct.hour;
    
    bool london_session = (current_hour >= 7 && current_hour < 16);
    bool ny_session = (current_hour >= 13 && current_hour < 22);
    bool overlap_session = (current_hour >= 13 && current_hour < 16);
    
    if(TradeOverlapOnly)
        return overlap_session;
        
    if(TradeLondonSession && TradeNYSession)
        return london_session || ny_session;
    else if(TradeLondonSession)
        return london_session;
    else if(TradeNYSession)
        return ny_session;
        
    return false;
}

//+------------------------------------------------------------------+
//| Check if market volatility is sufficient                        |
//+------------------------------------------------------------------+
bool IsHighVolatility()
{
    if(!UseVolatilityFilter || ArraySize(atr) < ATRPeriod + 1)
        return true;
        
    double current_atr = atr[1];
    double atr_sma = 0;
    
    for(int i = 1; i <= ATRPeriod; i++)
    {
        atr_sma += atr[i];
    }
    atr_sma /= ATRPeriod;
    
    return (current_atr >= atr_sma * ATRMultiplier);
}

//+------------------------------------------------------------------+
//| Simple Support/Resistance level detection                       |
//+------------------------------------------------------------------+
bool IsNearSRLevel(double price, double range)
{
    if(!UseSRLevels)
        return true;
        
    string symbol = Symbol();
    
    // Simple S/R: Check for recent highs/lows in extended period
    double highest = 0;
    double lowest = 999999;
    
    for(int i = 1; i <= 50; i++) // Look back 50 bars for S/R levels
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(high > highest) highest = high;
        if(low < lowest) lowest = low;
    }
    
    double sr_buffer = range * 0.5; // 50% of current range as buffer
    
    // Check if price is near major S/R levels
    bool near_resistance = (MathAbs(price - highest) <= sr_buffer);
    bool near_support = (MathAbs(price - lowest) <= sr_buffer);
    
    return near_resistance || near_support;
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
        if(PositionGetInteger(POSITION_MAGIC) != 33333) continue; // Test #3 magic
        
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
        return false;
    
    // Market structure filters
    if(!IsActiveSession())
    {
        if(EnableDebugLogs)
            Print("STRUCTURE: Outside active trading session");
        return false;
    }
    
    if(!IsHighVolatility())
    {
        if(EnableDebugLogs)
            Print("STRUCTURE: Low volatility period");
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
//| Structure-aware PTG Logic                                        |
//+------------------------------------------------------------------+
void PTG_StructureLogic()
{
    string symbol = Symbol();
    
    double high = iHigh(symbol, PERIOD_CURRENT, 1);
    double low = iLow(symbol, PERIOD_CURRENT, 1);
    double open = iOpen(symbol, PERIOD_CURRENT, 1);
    double close = iClose(symbol, PERIOD_CURRENT, 1);
    long volume = iVolume(symbol, PERIOD_CURRENT, 1);
    
    double range = high - low;
    double range_pips = range / pip_size;
    
    // Minimum range filter
    if(range_pips < MinRangePips)
    {
        if(EnableDebugLogs)
            Print("STRUCTURE: Range too small: ", DoubleToString(range_pips, 1), "p < ", MinRangePips, "p");
        return;
    }
    
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
    
    // Market structure confirmation
    bool near_sr_level = IsNearSRLevel(close, range);
    
    bool push_up = up_trend && big_range && high_volume && near_sr_level &&
                   (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && near_sr_level &&
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
            datetime server_time = TimeCurrent();
            MqlDateTime time_struct;
            TimeToStruct(server_time, time_struct);
            
            string msg = StringFormat("🔥 STRUCTURE PUSH #%d %s | Range: %.1fp | Vol: %.0f/%.0f | Session: %02d:00 | ATR: %.1f", 
                                     total_signals, push_up ? "UP" : "DOWN", 
                                     range_pips, (double)volume, vol_sma,
                                     time_struct.hour, atr[1]/pip_size);
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
            bool small_range = (range <= max_range * 0.7);
            
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
                        Print("🚀 STRUCTURE LONG #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Structure Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    if(EnableDebugLogs)
                        Print("🔻 STRUCTURE SHORT #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Structure Short");
                }
                
                wait_test = false;
            }
        }
        
        if(push_bar_index > TestBars)
        {
            wait_test = false;
            if(EnableDebugLogs)
                Print("TEST TIMEOUT after ", TestBars, " bars");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade with enhanced risk management                      |
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
    request.magic = 33333; // Test #3 magic number
    request.deviation = 10;
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ STRUCTURE TRADE #%d: %s %.2f lots | Risk: %.1fp",
                                 total_trades,
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, pip_risk);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        
        last_order_ticket = (int)result.order;
        order_place_time = TimeCurrent();
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ STRUCTURE TRADE #", total_trades, " FAILED: ", result.retcode, " - ", result.comment);
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
                
                string msg = StringFormat("🎯 STRUCTURE ENTRY: %s %.2f lots at %.5f",
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
                
                string msg = StringFormat("💰 STRUCTURE EXIT %s: %s%.1f pips | Entry: %.5f | Exit: %.5f",
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
