
//+------------------------------------------------------------------+
//|                           PTG_Test_01_Quality_Over_Quantity.mq5 |
//|                                    HARSH TEST - QUALITY SIGNALS |
//|                              Eliminate 90% of noise signals     |
//+------------------------------------------------------------------+
#property copyright "PTG Test Suite"
#property version   "1.01"
#property description "Test #1: QUALITY OVER QUANTITY - Strict Parameters"

//--- STRICT PARAMETERS FOR QUALITY SIGNALS
input group "=== PTG CORE SETTINGS ==="
input bool     UseEMAFilter       = false;             // Use EMA 34/55 trend filter
input bool     UseVWAPFilter      = false;             // Use VWAP trend filter  
input int      LookbackPeriod     = 20;                // Extended lookback for better context

input group "=== STRICT PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.80;              // Range >= 80% (MUCH MORE SELECTIVE)
input double   ClosePercent       = 0.80;              // Close position 80% (STRONG MOMENTUM)
input double   OppWickPercent     = 0.30;              // Opposite wick <= 30% (STRICTER)
input double   VolHighMultiplier  = 2.0;               // Volume >= 200% (REAL VOLUME SPIKES)

input group "=== STRICT TEST PARAMETERS ==="
input int      TestBars           = 3;                 // Tighter window (was 10)
input int      PendingTimeout     = 3;                 // Quick timeout
input double   PullbackMax        = 0.40;              // Smaller pullback (was 85%)
input double   VolLowMultiplier   = 0.8;               // Lower volume for test

input group "=== ENHANCED RISK MANAGEMENT ==="
input double   EntryBufferPips    = 0.5;               // Entry buffer
input double   SLBufferPips       = 0.5;               // Stop loss buffer
input double   TPMultiplier       = 2.5;               // Better R:R (was 1.5)
input bool     UseTrailingStop    = true;              // Enable trailing stop
input double   TrailingStopPips   = 20.0;             // Wider trailing
input double   RiskPercent        = 0.5;               // Conservative risk
input double   MaxSpreadPips      = 30.0;              // Tighter spread filter

input group "=== TRADING HOURS ==="
input bool     UseTimeFilter      = true;              // Enable session filter
input string   StartTime          = "07:00";           // London open
input string   EndTime            = "22:00";           // NY close

input group "=== SYSTEM SETTINGS ==="
input bool     AllowMultiplePositions = false;        // Single position
input int      MinBarsBetweenTrades   = 5;             // More spacing between trades
input bool     EnableDebugLogs    = true;              // Detailed logging
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
    
    Print("=== PTG TEST #1: QUALITY OVER QUANTITY ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("STRICT PARAMETERS:");
    Print("Push Range: ", PushRangePercent*100, "% (vs 35% baseline)");
    Print("Close Position: ", ClosePercent*100, "% (vs 45% baseline)");
    Print("Volume Multiplier: ", VolHighMultiplier, "x (vs 1.0x baseline)");
    Print("TP Multiplier: ", TPMultiplier, "x (vs 1.5x baseline)");
    Print("EXPECTED: <500 signals, >80% win rate");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ema34_handle);
    IndicatorRelease(ema55_handle);
    Print("=== TEST #1 COMPLETED ===");
    Print("Total Signals: ", total_signals);
    Print("Total Trades: ", total_trades);
    Print("Signal Efficiency: ", total_trades > 0 ? DoubleToString((double)total_signals/total_trades, 2) : "N/A");
    Print("TARGET ACHIEVED: ", total_signals < 500 ? "YES" : "NO");
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
        
    PTG_QualityLogic();
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
        if(PositionGetInteger(POSITION_MAGIC) != 11111) continue; // Test #1 magic
        
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
    
    // Strict time filter for quality trading
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
//| Quality-focused PTG Logic                                        |
//+------------------------------------------------------------------+
void PTG_QualityLogic()
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
    
    // Extended lookback for better context
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
    
    // STRICT conditions for quality signals
    bool big_range = (range >= max_range * PushRangePercent);
    double vol_sma = GetVolumeSMA(LookbackPeriod, 1);
    bool high_volume = (volume >= vol_sma * VolHighMultiplier);
    
    // Additional quality filters
    bool volume_spike = (volume > iVolume(symbol, PERIOD_CURRENT, 2) * 1.5); // Volume increase
    bool significant_move = (range > pip_size * 20); // Minimum 20 pip move
    
    bool push_up = up_trend && big_range && high_volume && volume_spike && significant_move &&
                   (close_pos_hi >= ClosePercent) && (up_wick <= OppWickPercent);
    bool push_down = down_trend && big_range && high_volume && volume_spike && significant_move &&
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
            string msg = StringFormat("🔥 QUALITY PUSH #%d %s | Range: %.1fp | Vol: %.0f/%.0f | Spike: %.1fx", 
                                     total_signals, push_up ? "UP" : "DOWN", 
                                     range/pip_size, (double)volume, vol_sma,
                                     (double)volume/vol_sma);
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
            bool small_range = (range <= max_range * 0.6); // Stricter test range
            
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
                        Print("🚀 QUALITY LONG #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_BUY_STOP, entry_level, sl_level, tp_level, "PTG Quality Long");
                }
                else if(test_short)
                {
                    entry_level = test_low - (EntryBufferPips * pip_size);
                    sl_level = test_high + (SLBufferPips * pip_size);
                    tp_level = entry_level - ((sl_level - entry_level) * TPMultiplier);
                    
                    if(EnableDebugLogs)
                        Print("🔻 QUALITY SHORT #", total_signals, " → TRADE #", total_trades + 1);
                    
                    ExecuteTrade(ORDER_TYPE_SELL_STOP, entry_level, sl_level, tp_level, "PTG Quality Short");
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
    
    if(EnableDebugLogs)
    {
        Print("QUALITY RISK: Balance=$", account_balance, " | Risk%=", RiskPercent, " | PipRisk=", pip_risk, "p");
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
    request.magic = 11111; // Test #1 magic number
    request.deviation = 10;
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ QUALITY TRADE #%d: %s %.2f lots | Risk: %.1fp | R:R %.1fx",
                                 total_trades,
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, pip_risk, TPMultiplier);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        
        last_order_ticket = (int)result.order;
        order_place_time = TimeCurrent();
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ QUALITY TRADE #", total_trades, " FAILED: ", result.retcode, " - ", result.comment);
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
                
                string msg = StringFormat("🎯 QUALITY ENTRY: %s %.2f lots at %.5f",
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
                
                string msg = StringFormat("💰 QUALITY EXIT %s: %s%.1f pips | Entry: %.5f | Exit: %.5f",
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
