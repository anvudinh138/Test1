//+------------------------------------------------------------------+
//|                                           PTG_Ultra_Simple.mq5   |
//|                        ULTRA SIMPLIFIED - Just to get trades     |
//|                         Minimal conditions for testing           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, PTG Trading Strategy"
#property link      "https://github.com/ptg-trading"
#property version   "1.00"

//--- ULTRA SIMPLE INPUTS
input group "=== ULTRA SIMPLE PTG ==="
input double   MinRangePips       = 5.0;               // Minimum range in pips (VERY LOW)
input double   RiskPercent        = 2.0;               // Risk per trade (%)
input double   TPMultiplier       = 2.0;               // Take profit multiplier
input double   MaxSpreadPips      = 20.0;              // Max spread (VERY HIGH)
input bool     EnableDebugLogs    = true;              // Show all debug info
input bool     EnableAlerts       = true;              // Enable alerts

//--- Global variables
double         pip_size;
int            trade_count = 0;
datetime       last_trade_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    string symbol = Symbol();
    
    // Set pip size
    if(StringFind(symbol, "JPY") >= 0)
        pip_size = 0.01;
    else if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        pip_size = 0.01;
    else
        pip_size = 0.0001;
        
    Print("=== PTG ULTRA SIMPLE EA INITIALIZED ===");
    Print("Symbol: ", symbol, " | Pip size: ", pip_size);
    Print("Min Range: ", MinRangePips, " pips | Max Spread: ", MaxSpreadPips, " pips");
    Print("THIS VERSION SHOULD DEFINITELY GET TRADES!");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("PTG Ultra Simple EA stopped - Total trades attempted: ", trade_count);
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
    
    // Only check every 10 bars to avoid spam
    static int bar_counter = 0;
    bar_counter++;
    
    if(bar_counter % 10 != 0)
        return;
    
    if(EnableDebugLogs)
        Print("=== CHECKING BAR #", bar_counter, " ===");
    
    if(!IsTradingAllowed())
        return;
        
    UltraSimplePTG();
}

//+------------------------------------------------------------------+
//| Check if trading is allowed (very permissive)                    |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // Check spread (very permissive)
    double current_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double spread = (current_ask - current_bid) / pip_size;
    
    if(spread > MaxSpreadPips)
    {
        if(EnableDebugLogs)
            Print("❌ Spread too high: ", DoubleToString(spread, 1), " > ", MaxSpreadPips);
        return false;
    }
    
    // Check if position exists
    if(PositionsTotal() > 0)
    {
        if(EnableDebugLogs)
            Print("❌ Position already exists");
        return false;
    }
    
    // Check minimum time between trades (1 hour)
    if(TimeCurrent() - last_trade_time < 3600)
    {
        if(EnableDebugLogs)
            Print("❌ Too soon since last trade");
        return false;
    }
        
    return true;
}

//+------------------------------------------------------------------+
//| Ultra Simple PTG Logic                                           |
//+------------------------------------------------------------------+
void UltraSimplePTG()
{
    string symbol = Symbol();
    
    // Get last 3 bars
    double high1 = iHigh(symbol, PERIOD_CURRENT, 1);
    double low1 = iLow(symbol, PERIOD_CURRENT, 1);
    double close1 = iClose(symbol, PERIOD_CURRENT, 1);
    double open1 = iOpen(symbol, PERIOD_CURRENT, 1);
    
    double high2 = iHigh(symbol, PERIOD_CURRENT, 2);
    double low2 = iLow(symbol, PERIOD_CURRENT, 2);
    double close2 = iClose(symbol, PERIOD_CURRENT, 2);
    
    double high3 = iHigh(symbol, PERIOD_CURRENT, 3);
    double low3 = iLow(symbol, PERIOD_CURRENT, 3);
    double close3 = iClose(symbol, PERIOD_CURRENT, 3);
    
    // Calculate ranges in pips
    double range1 = (high1 - low1) / pip_size;
    double range2 = (high2 - low2) / pip_size;
    double range3 = (high3 - low3) / pip_size;
    
    if(EnableDebugLogs)
    {
        Print("--- RANGE ANALYSIS ---");
        Print("Bar 1 range: ", DoubleToString(range1, 1), " pips (need > ", MinRangePips, ")");
        Print("Bar 2 range: ", DoubleToString(range2, 1), " pips");
        Print("Bar 3 range: ", DoubleToString(range3, 1), " pips");
    }
    
    // ULTRA SIMPLE CONDITIONS:
    // 1. Bar 1 has minimum range
    // 2. Price movement direction
    bool big_range = (range1 >= MinRangePips);
    bool bullish_bar = (close1 > open1);
    bool bearish_bar = (close1 < open1);
    
    // Simple trend: compare last 3 closes
    bool uptrend = (close1 > close2) && (close2 > close3);
    bool downtrend = (close1 < close2) && (close2 < close3);
    
    if(EnableDebugLogs)
    {
        Print("--- CONDITION CHECK ---");
        Print("Big range: ", big_range, " | Bullish bar: ", bullish_bar, " | Bearish bar: ", bearish_bar);
        Print("Uptrend: ", uptrend, " | Downtrend: ", downtrend);
        Print("Close1: ", close1, " | Close2: ", close2, " | Close3: ", close3);
    }
    
    // SIGNAL GENERATION (very simple)
    bool long_signal = big_range && bullish_bar && uptrend;
    bool short_signal = big_range && bearish_bar && downtrend;
    
    if(EnableDebugLogs)
        Print("🎯 SIGNALS: Long=", long_signal, " | Short=", short_signal);
    
    if(long_signal)
    {
        double entry = high1 + (1.0 * pip_size);  // 1 pip above high
        double sl = low1 - (1.0 * pip_size);     // 1 pip below low
        double tp = entry + ((entry - sl) * TPMultiplier);
        
        Print("🚀 LONG SIGNAL DETECTED!");
        Print("Entry: ", entry, " | SL: ", sl, " | TP: ", tp);
        Print("Risk: ", DoubleToString((entry - sl) / pip_size, 1), " pips");
        
        ExecuteTrade(ORDER_TYPE_BUY_STOP, entry, sl, tp, "PTG Ultra Long");
    }
    else if(short_signal)
    {
        double entry = low1 - (1.0 * pip_size);   // 1 pip below low
        double sl = high1 + (1.0 * pip_size);    // 1 pip above high
        double tp = entry - ((sl - entry) * TPMultiplier);
        
        Print("🔻 SHORT SIGNAL DETECTED!");
        Print("Entry: ", entry, " | SL: ", sl, " | TP: ", tp);
        Print("Risk: ", DoubleToString((sl - entry) / pip_size, 1), " pips");
        
        ExecuteTrade(ORDER_TYPE_SELL_STOP, entry, sl, tp, "PTG Ultra Short");
    }
    else if(EnableDebugLogs)
    {
        Print("❌ No signal - waiting for conditions...");
    }
}

//+------------------------------------------------------------------+
//| Execute trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, double tp_price, string comment)
{
    string symbol = Symbol();
    trade_count++;
    
    // Simple position size (fixed)
    double lot_size = 0.1; // Fixed lot for testing
    
    // For real trading, use risk management:
    /*
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * RiskPercent / 100.0;
    double pip_risk = MathAbs(entry_price - sl_price) / pip_size;
    double pip_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    if(pip_value > 0)
        lot_size = risk_amount / (pip_risk * pip_value);
    */
    
    // Normalize lot size
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    
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
    request.magic = 99999; // Ultra Simple magic number
    request.deviation = 20;
    
    Print("=== EXECUTING TRADE #", trade_count, " ===");
    Print("Type: ", order_type == ORDER_TYPE_BUY_STOP ? "BUY STOP" : "SELL STOP");
    Print("Lot: ", lot_size, " | Entry: ", entry_price, " | SL: ", sl_price, " | TP: ", tp_price);
    
    if(OrderSend(request, result))
    {
        string msg = StringFormat("✅ TRADE PLACED! %s %.2f lots | Ticket: %d",
                                 order_type == ORDER_TYPE_BUY_STOP ? "LONG" : "SHORT",
                                 lot_size, result.order);
        Print(msg);
        if(EnableAlerts) Alert(msg);
        
        last_trade_time = TimeCurrent();
    }
    else
    {
        Print("❌ TRADE FAILED: Code ", result.retcode, " - ", result.comment);
        if(EnableAlerts) Alert("Trade failed: " + result.comment);
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
