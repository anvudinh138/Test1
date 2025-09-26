//+------------------------------------------------------------------+
//|                                                FlexGridDCA_EA.mq5 |
//|                                            Flex Grid DCA System   |
//|                      Universal Grid + DCA EA with Fixed Lot Size  |
//+------------------------------------------------------------------+
#property copyright "Flex Grid DCA EA"
#property link      ""
#property version   "1.01" // UPDATED: Version increment
#property description "Universal Grid + DCA EA with ATR-based calculations. Corrected profit checking and state management."

#include <Trade\Trade.mqh>
#include <ATRCalculator.mqh>
#include <GridManager_v2.mqh>

//+------------------------------------------------------------------+
//| Expert Properties                                                |
//+------------------------------------------------------------------+
input group "=== BASIC SETTINGS ==="
enum ENUM_SYMBOLS
{
    SYMBOL_AUTO = 0,        // Auto (Current Chart Symbol)
    SYMBOL_EURUSD = 1,      // EURUSD
    SYMBOL_GBPUSD = 2,      // GBPUSD  
    SYMBOL_USDCHF = 3,      // USDCHF
    SYMBOL_USDJPY = 4,      // USDJPY
    SYMBOL_AUDUSD = 5,      // AUDUSD
    SYMBOL_NZDUSD = 6,      // NZDUSD
    SYMBOL_USDCAD = 7,      // USDCAD
    SYMBOL_EURJPY = 8,      // EURJPY
    SYMBOL_GBPJPY = 9,      // GBPJPY
    SYMBOL_XAUUSD = 10,     // Gold (XAUUSD)
    SYMBOL_XAGUSD = 11,     // Silver (XAGUSD)
    SYMBOL_BTCUSD = 12,     // Bitcoin (BTCUSD)
    SYMBOL_ETHUSD = 13,     // Ethereum (ETHUSD)
    SYMBOL_US30 = 14,       // Dow Jones (US30)
    SYMBOL_SPX500 = 15,     // S&P 500 (SPX500)
    SYMBOL_NAS100 = 16      // Nasdaq (NAS100)
};

input ENUM_SYMBOLS InpTradingSymbol = SYMBOL_AUTO;    // Trading Symbol
input double      InpFixedLotSize = 0.01;           // Fixed Lot Size (Always 0.01 - Broker minimum)
input int         InpMaxGridLevels = 5;             // Maximum Grid Levels
input double      InpATRMultiplier = 1.0;           // ATR Multiplier for Grid Spacing
input bool        InpEnableGridTrading = true;      // Enable Grid Trading
input bool        InpEnableDCATrading = true;       // Enable DCA Trading

input group "=== RISK MANAGEMENT ==="
input double      InpMaxAccountRisk = 10.0;         // Maximum Account Risk %
input double      InpProfitTargetPercent = 1.0;     // Profit Target % (Per Direction)
input double      InpProfitTargetUSD = 4.0;         // Profit Target USD (Per Direction)
input bool        InpUseTotalProfitTarget = true;   // Use Total Profit Target (Both Directions)
input double      InpMaxLossUSD = 10.0;             // Maximum Loss USD (Loss Protection)
input double      InpMaxSpreadPips = 0.0;           // Maximum Spread (pips) - 0=Auto based on symbol
input double      InpMaxSpreadPipsWait = 0.0;       // Maximum Spread Wait (pips) - 0=Auto (2x normal)
input bool        InpUseVolatilityFilter = false;   // Use Volatility Filter

input group "=== TIME FILTERS ==="
input bool        InpUseTimeFilter = false;         // Enable Time Filter
input int         InpStartHour = 8;                 // Start Trading Hour
input int         InpEndHour = 18;                  // End Trading Hour

input group "=== ADVANCED ==="
input bool        InpEnableTrailingStop = false;    // Enable Trailing Stop
input bool        InpEnableMarketEntry = true;      // Enable Market Entry at Grid Setup
input bool        InpUseFibonacciSpacing = false;   // Use Fibonacci Grid Spacing (Golden Ratio)

input group "=== TREND FILTER ==="
input bool        InpUseTrendFilter = false;        // Enable Trend Filter (Wait for Sideways)
input double      InpMaxADXStrength = 25.0;         // Maximum ADX for Sideways (< 25 = weak trend)
input bool        InpUseDCARecoveryMode = false;    // DCA Recovery Mode (Lower targets after DCA expansion)
input double      InpTrailingStopATR = 2.0;         // Trailing Stop ATR Multiplier
input int         InpMagicNumber = 12345;           // Magic Number
input string      InpEAComment = "FlexGridDCA";     // EA Comment

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CATRCalculator   *g_atr_calculator;
CGridManagerV2   *g_grid_manager;
CTrade           g_trade;

datetime         g_last_grid_update;
datetime         g_last_check_time;
double           g_account_start_balance;
bool             g_ea_initialized;

// ADDED: Per-direction state management to prevent race conditions
bool             g_is_closing_positions = false;  // Global state (for total profit mode)
bool             g_is_closing_buy = false;        // BUY direction closing state
bool             g_is_closing_sell = false;       // SELL direction closing state

// ADDED: Smart spread management after profit taking
bool             g_waiting_for_spread = false;    // Waiting for normal spread after profit
datetime         g_last_profit_time = 0;          // Time of last profit taking

// ADDED: Trend Filter variables
int              g_ema8_handle = INVALID_HANDLE;   // EMA 8 handle  
int              g_ema13_handle = INVALID_HANDLE;  // EMA 13 handle
int              g_ema21_handle = INVALID_HANDLE;  // EMA 21 handle
int              g_adx_handle = INVALID_HANDLE;    // ADX handle
bool             g_dca_recovery_mode = false;      // DCA Recovery mode active

//+------------------------------------------------------------------+
//| Symbol Conversion Function                                       |
//+------------------------------------------------------------------+
string GetTradingSymbol()
{
    switch(InpTradingSymbol)
    {
        case SYMBOL_AUTO:    return _Symbol;
        case SYMBOL_EURUSD:  return "EURUSD";
        case SYMBOL_GBPUSD:  return "GBPUSD";
        case SYMBOL_USDCHF:  return "USDCHF";
        case SYMBOL_USDJPY:  return "USDJPY";
        case SYMBOL_AUDUSD:  return "AUDUSD";
        case SYMBOL_NZDUSD:  return "NZDUSD";
        case SYMBOL_USDCAD:  return "USDCAD";
        case SYMBOL_EURJPY:  return "EURJPY";
        case SYMBOL_GBPJPY:  return "GBPJPY";
        case SYMBOL_XAUUSD:  return "XAUUSD";
        case SYMBOL_XAGUSD:  return "XAGUSD";
        case SYMBOL_BTCUSD:  return "BTCUSD";
        case SYMBOL_ETHUSD:  return "ETHUSD";
        case SYMBOL_US30:    return "US30";
        case SYMBOL_SPX500:  return "SPX500";
        case SYMBOL_NAS100:  return "NAS100";
        default:             return _Symbol;
    }
}

//+------------------------------------------------------------------+
//| Get Adaptive Spread Limit                                       |
//+------------------------------------------------------------------+
double GetAdaptiveSpreadLimit(string symbol, bool is_wait_mode = false)
{
    if(InpMaxSpreadPips > 0.0)
        return is_wait_mode ? InpMaxSpreadPipsWait : InpMaxSpreadPips;
    
    double base_spread = 10.0; // Default for major forex
    
    // 🎯 ADAPTIVE SPREAD LIMITS by symbol type
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        base_spread = 150.0;     // Gold: 150 pips normal
    else if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
        base_spread = 80.0;      // Silver: 80 pips normal
    else if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0)
        base_spread = 200.0;     // Crypto: 200 pips normal
    else if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "SPX") >= 0 || StringFind(symbol, "NAS") >= 0)
        base_spread = 100.0;     // Indices: 100 pips normal
    else if(StringFind(symbol, "JPY") >= 0)
        base_spread = 15.0;      // JPY pairs: 15 pips normal
    else if(StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "NZD") >= 0 || StringFind(symbol, "CAD") >= 0)
        base_spread = 25.0;      // Minor pairs: 25 pips normal
    else
        base_spread = 10.0;      // Major EUR/GBP/USD: 10 pips normal
    
    return is_wait_mode ? (base_spread * 3.0) : base_spread; // Wait mode = 3x normal
}

//+------------------------------------------------------------------+
//| Trend Filter: Check if market is suitable for grid trading     |
//+------------------------------------------------------------------+
bool IsSidewaysMarket()
{
    if(!InpUseTrendFilter)
        return true; // No filter = always allow
    
    // Get indicator values
    double ema8[1], ema13[1], ema21[1], adx_main[1];
    
    if(CopyBuffer(g_ema8_handle, 0, 0, 1, ema8) <= 0 ||
       CopyBuffer(g_ema13_handle, 0, 0, 1, ema13) <= 0 ||
       CopyBuffer(g_ema21_handle, 0, 0, 1, ema21) <= 0 ||
       CopyBuffer(g_adx_handle, 0, 0, 1, adx_main) <= 0)
    {
        Print("⚠️ TREND FILTER: Failed to get indicator values");
        return true; // Default to allow trading if data unavailable
    }
    
    // 🎯 TREND STRENGTH CHECK: ADX < 25 = weak trend (sideways)
    bool weak_trend = (adx_main[0] < InpMaxADXStrength);
    
    // 🎯 EMA ALIGNMENT CHECK: Strong trend = EMA8 > EMA13 > EMA21 (uptrend) OR EMA8 < EMA13 < EMA21 (downtrend)
    bool strong_uptrend = (ema8[0] > ema13[0] && ema13[0] > ema21[0]);
    bool strong_downtrend = (ema8[0] < ema13[0] && ema13[0] < ema21[0]);
    bool no_clear_trend = (!strong_uptrend && !strong_downtrend);
    
    // 🎯 SIDEWAYS CONDITIONS: Weak ADX AND no clear EMA alignment
    bool is_sideways = (weak_trend && no_clear_trend);
    
    static datetime last_trend_log = 0;
    if(TimeCurrent() - last_trend_log > 3600) // Log every hour
    {
        Print("📊 TREND FILTER: ADX=", DoubleToString(adx_main[0], 1), 
              " | EMA8=", DoubleToString(ema8[0], _Digits),
              " | EMA13=", DoubleToString(ema13[0], _Digits), 
              " | EMA21=", DoubleToString(ema21[0], _Digits),
              " | Sideways: ", (is_sideways ? "YES ✅" : "NO ❌"));
        last_trend_log = TimeCurrent();
    }
    
    return is_sideways;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== FlexGridDCA EA Starting ===");
    
    // Initialize global variables
    g_ea_initialized = false;
    g_last_grid_update = 0;
    g_last_check_time = 0;
    g_is_closing_positions = false; // ADDED: Initialize global state
    g_is_closing_buy = false;        // ADDED: Initialize BUY state
    g_is_closing_sell = false;       // ADDED: Initialize SELL state
    g_waiting_for_spread = false;    // ADDED: Initialize spread waiting state
    g_last_profit_time = 0;          // ADDED: Initialize profit time
    g_account_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Set trade settings
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Get trading symbol
    string trading_symbol = GetTradingSymbol();
    Print("🎯 Trading Symbol: ", trading_symbol);
    
    // Initialize ATR Calculator
    g_atr_calculator = new CATRCalculator();
    if(!g_atr_calculator.Initialize(trading_symbol))
    {
        Print("ERROR: Failed to initialize ATR Calculator");
        return(INIT_FAILED);
    }
    
    // Initialize Grid Manager V2
    g_grid_manager = new CGridManagerV2();
    if(!g_grid_manager.Initialize(trading_symbol, InpFixedLotSize, InpMaxGridLevels, (ulong)InpMagicNumber))
    {
        Print("ERROR: Failed to initialize Grid Manager V2");
        return(INIT_FAILED);
    }
    
    // Set profit targets in GridManager
    g_grid_manager.SetProfitTargets(InpProfitTargetUSD, InpProfitTargetPercent, InpUseTotalProfitTarget);
    
    // Set market entry option in GridManager
    g_grid_manager.SetMarketEntry(InpEnableMarketEntry);
    
    // Set Fibonacci spacing option in GridManager
    g_grid_manager.SetFibonacciSpacing(InpUseFibonacciSpacing);
    
    // Initialize Trend Filter indicators
    if(InpUseTrendFilter)
    {
        g_ema8_handle = iMA(trading_symbol, PERIOD_H1, 8, 0, MODE_EMA, PRICE_CLOSE);
        g_ema13_handle = iMA(trading_symbol, PERIOD_H1, 13, 0, MODE_EMA, PRICE_CLOSE);
        g_ema21_handle = iMA(trading_symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
        g_adx_handle = iADX(trading_symbol, PERIOD_H1, 14);
        
        if(g_ema8_handle == INVALID_HANDLE || g_ema13_handle == INVALID_HANDLE || 
           g_ema21_handle == INVALID_HANDLE || g_adx_handle == INVALID_HANDLE)
        {
            Print("ERROR: Failed to initialize Trend Filter indicators");
            return(INIT_FAILED);
        }
        
        Print("✅ Trend Filter initialized: EMA(8,13,21) + ADX on H1");
    }
    
    // Initial setup
    if(!InitialSetup())
    {
        Print("ERROR: Initial setup failed");
        return(INIT_FAILED);
    }
    
    g_ea_initialized = true;
    Print("=== FlexGridDCA EA Initialized Successfully ===");
    Print("Fixed Lot Size: ", InpFixedLotSize);
    Print("Max Grid Levels: ", InpMaxGridLevels);
    Print("ATR Multiplier: ", InpATRMultiplier);
    Print("Account Balance: ", g_account_start_balance);
    Print("Profit Target USD: $", InpProfitTargetUSD);
    Print("Profit Target %: ", InpProfitTargetPercent, "%");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== FlexGridDCA EA Stopping ===");
    Print("Reason: ", reason);
    
    // Print final statistics
    PrintFinalStatistics();
    
    // Cleanup
    if(g_atr_calculator != NULL)
        delete g_atr_calculator;
        
    // Release indicator handles
    if(g_ema8_handle != INVALID_HANDLE)
        IndicatorRelease(g_ema8_handle);
    if(g_ema13_handle != INVALID_HANDLE)
        IndicatorRelease(g_ema13_handle);
    if(g_ema21_handle != INVALID_HANDLE)
        IndicatorRelease(g_ema21_handle);
    if(g_adx_handle != INVALID_HANDLE)
        IndicatorRelease(g_adx_handle);
        
    if(g_grid_manager != NULL)
        delete g_grid_manager;
    
    Print("=== FlexGridDCA EA Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_ea_initialized)
        return;
        
    // Limit processing frequency to avoid excessive load
    if(TimeCurrent() - g_last_check_time < 5)  // Check every 5 seconds
        return;
        
    g_last_check_time = TimeCurrent();
    
    // UPDATED: Per-direction state machine to handle closing process safely
    if(g_is_closing_positions)
    {
        // Total profit mode - close everything
        int total_orders = CountBuyOrdersAndPositions() + CountSellOrdersAndPositions();
        if(total_orders == 0)
        {
            Print("✅ CONFIRMED: All positions and orders are closed. Ready for a new grid setup.");
            g_is_closing_positions = false;
            g_last_grid_update = 0; // Force SetupGridSystem() to run on the next valid tick
        }
        else
        {
            Print("⏳ Waiting for ", IntegerToString(total_orders), " positions/orders to close completely...");
            g_grid_manager.CloseAllGridPositions();
        }
        return; // Do nothing else while in closing state
    }
    
    // Per-direction closing states
    bool all_closed = true;
    if(g_is_closing_buy)
    {
        int buy_count = CountBuyOrdersAndPositions();
        if(buy_count == 0)
        {
            Print("✅ BUY cleanup complete. Resetting BUY grid.");
            g_is_closing_buy = false;
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            g_grid_manager.SetupDirectionGrid(GRID_DIRECTION_BUY, current_price, InpATRMultiplier);
        }
        else
        {
            Print("⏳ Waiting for BUY cleanup: ", IntegerToString(buy_count), " left.");
            g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_BUY);
            all_closed = false;
        }
    }
    if(g_is_closing_sell)
    {
        int sell_count = CountSellOrdersAndPositions();
        if(sell_count == 0)
        {
            Print("✅ SELL cleanup complete. Resetting SELL grid.");
            g_is_closing_sell = false;
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            g_grid_manager.SetupDirectionGrid(GRID_DIRECTION_SELL, current_price, InpATRMultiplier);
        }
        else
        {
            Print("⏳ Waiting for SELL cleanup: ", IntegerToString(sell_count), " left.");
            g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_SELL);
            all_closed = false;
        }
    }
    if(!all_closed) return; // Don't do anything while closing
    
    // Update ATR values
    g_atr_calculator.UpdateATRValues();
    
    // 🎯 SMART SPREAD MANAGEMENT: Check if waiting for normal spread after profit
    if(g_waiting_for_spread)
    {
        string trading_symbol = GetTradingSymbol();
        double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0; // Convert to pips
        double max_spread_limit = GetAdaptiveSpreadLimit(trading_symbol, false); // Normal mode
        
        if(current_spread <= max_spread_limit)
        {
            Print("✅ SPREAD NORMALIZED: ", DoubleToString(current_spread, 1), " <= ", DoubleToString(max_spread_limit, 1), " - Resuming grid setup");
            g_waiting_for_spread = false;
            g_last_grid_update = 0; // Force new grid setup
        }
        else
        {
            Print("⏳ WAITING FOR SPREAD: ", DoubleToString(current_spread, 1), " > ", DoubleToString(max_spread_limit, 1), " - Will wait...");
            return; // Wait for better spread
        }
    }
    
    // 🎯 TREND FILTER: Only setup grid during sideways market
    if(!IsSidewaysMarket())
    {
        static datetime last_trend_warning = 0;
        if(TimeCurrent() - last_trend_warning > 1800) // Warn every 30 minutes
        {
            Print("⏳ TREND FILTER: Waiting for sideways market to setup new grid...");
            last_trend_warning = TimeCurrent();
        }
        return; // Wait for sideways market
    }
    
    // Setup grid if needed (first time or after reset)
    if(ShouldSetupGrid())
    {
        SetupGridSystem();
        // Return after setup to ensure clean state on next tick
        return; 
    }
    
    // 🚨 CRITICAL FIX: Check profit target BEFORE spread filter
    // Profit checking should ALWAYS work regardless of spread!
    if(CheckProfitTarget())
    {
        return; // Stop further processing as closing process has been initiated
    }
    
    // Check trading conditions (only affects new orders, not profit checks)
    if(!IsTradingAllowed())
        return;
    
    // Update grid status
    g_grid_manager.UpdateGridStatus();
    
    // 🚀 SMART DCA EXPANSION: Check if we need to add counter-trend orders
    if(g_grid_manager.CheckSmartDCAExpansion())
    {
        Print("⚡ DCA EXPANSION TRIGGERED - Placing new orders...");
        g_grid_manager.PlaceDirectionOrders(GRID_DIRECTION_BUY);
        g_grid_manager.PlaceDirectionOrders(GRID_DIRECTION_SELL);
        
        // 🎯 ACTIVATE DCA RECOVERY MODE: Lower profit targets after DCA expansion
        if(InpUseDCARecoveryMode)
        {
            g_dca_recovery_mode = true;
            Print("🔄 DCA RECOVERY MODE ACTIVATED: Lower profit targets now in effect");
        }
    }
    
    // Place pending orders
    if(InpEnableGridTrading)
    {
        g_grid_manager.PlaceGridOrders();
    }
    
    // Check DCA Expansion (if enabled)
    if(InpEnableDCATrading)
    {
        CheckDCAExpansion();
    }
    
    // Check Loss Protection
    CheckLossProtection();
    
    // Handle trailing stop
    if(InpEnableTrailingStop)
    {
        HandleTrailingStop();
    }
}

//+------------------------------------------------------------------+
//| Initial Setup Function                                           |
//+------------------------------------------------------------------+
bool InitialSetup()
{
    // Validate inputs
    if(InpFixedLotSize <= 0)
    {
        Print("ERROR: Invalid lot size: ", InpFixedLotSize);
        return false;
    }
    
    if(InpMaxGridLevels <= 0 || InpMaxGridLevels > 20)
    {
        Print("ERROR: Invalid max grid levels: ", InpMaxGridLevels);
        return false;
    }
    
    // Print market information
    PrintMarketInfo();
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // Check if market is open
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
        return false;
        
    // Check spread
    string trading_symbol = GetTradingSymbol();
    double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0; // Convert to pips
    double max_spread_limit = GetAdaptiveSpreadLimit(trading_symbol, false); // Normal mode
    
    if(current_spread > max_spread_limit)
    {
        static datetime last_spread_warning = 0;
        if(TimeCurrent() - last_spread_warning > 300)  // Warn every 5 minutes
        {
            Print("Spread too high: ", DoubleToString(current_spread, 1), " > ", DoubleToString(max_spread_limit, 1));
            last_spread_warning = TimeCurrent();
        }
        return false;
    }
    
    // Check volatility filter
    if(InpUseVolatilityFilter)
    {
        if(!g_atr_calculator.IsVolatilityNormal())
            return false;
    }
    
    // Check time filter
    if(InpUseTimeFilter)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.hour < InpStartHour || dt.hour >= InpEndHour)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if should setup grid                                       |
//+------------------------------------------------------------------+
bool ShouldSetupGrid()
{
    // Setup grid if it's the first time
    if(g_last_grid_update == 0)
        return true;
        
    // Reset grid periodically (every 24 hours) - can be disabled if not needed
    // if(TimeCurrent() - g_last_grid_update > 86400)  // 24 hours
    //    return true;
        
    return false;
}

//+------------------------------------------------------------------+
//| Setup Grid System                                                |
//+------------------------------------------------------------------+
void SetupGridSystem()
{
    Print("=== Setting up New Grid System ===");
    
    // Close existing positions if resetting (safety check)
    if(g_last_grid_update > 0)
    {
        Print("Grid is being reset. Closing any remaining positions.");
        g_grid_manager.CloseAllGridPositions();
        Sleep(1000);  // Wait for orders to close
    }
    
    // CRITICAL: CONFIRMATION CHECK - Only create grid if orders are truly cleared
    int buy_count = CountBuyOrdersAndPositions();
    int sell_count = CountSellOrdersAndPositions();
    
    Print("🔍 CONFIRMATION CHECK BEFORE NEW GRID:");
    Print("BUY orders/positions: ", buy_count);
    Print("SELL orders/positions: ", sell_count);
    
    if(buy_count > 0 || sell_count > 0)
    {
        Print("⚠️ ORDERS NOT CLEARED YET - Aborting new grid setup for this tick.");
        return; // Don't create new grid until old orders are completely cleared
    }
    
    Print("✅ CONFIRMATION: All clear. Safe to create new grid.");
    
    // Setup new grid only after confirmation
    if(g_grid_manager.SetupDualGrid(0.0, InpATRMultiplier))
    {
        g_last_grid_update = TimeCurrent();
        Print("Dual Grid system setup completed.");
        g_grid_manager.PrintGridInfo();
    }
    else
    {
        Print("ERROR: Failed to setup dual grid system.");
    }
}

//+------------------------------------------------------------------+
//| Count BUY orders/positions for our EA (UPDATED)                 |
//+------------------------------------------------------------------+
int CountBuyOrdersAndPositions()
{
    int count = 0;
    
    // Count positions
    for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
    {
        if(PositionGetSymbol(pos_idx) == _Symbol && 
           PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            count++;
        }
    }
    
    // Count pending BUY orders
    for(int ord_idx = OrdersTotal() - 1; ord_idx >= 0; ord_idx--)
    {
        if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
           OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && 
           OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
        {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Count SELL orders/positions for our EA (UPDATED)                |
//+------------------------------------------------------------------+
int CountSellOrdersAndPositions()
{
    int count = 0;
    
    // Count positions
    for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
    {
        if(PositionGetSymbol(pos_idx) == _Symbol && 
           PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            count++;
        }
    }
    
    // Count pending SELL orders
    for(int ord_idx = OrdersTotal() - 1; ord_idx >= 0; ord_idx--)
    {
        if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
           OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && 
           OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
        {
            count++;
        }
    }
    
    return count;
}


//+------------------------------------------------------------------+
//| Check profit target - COMPLETELY REWRITTEN for Per-Direction    |
//+------------------------------------------------------------------+
bool CheckProfitTarget()
{
    if(g_grid_manager == NULL) return false;

    double buy_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
    double sell_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
    double total_profit = buy_profit + sell_profit;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double effective_target_usd = MathMin(InpProfitTargetUSD, balance * (InpProfitTargetPercent / 100.0));
    
    // 🎯 DCA RECOVERY MODE: Lower profit target after DCA expansion
    if(InpUseDCARecoveryMode && g_dca_recovery_mode)
    {
        // Target break-even (0) or half the max loss (e.g., -$5 instead of -$10)
        double recovery_target = MathMax(0.0, -InpMaxLossUSD / 2.0);
        effective_target_usd = recovery_target;
        
        static datetime last_recovery_log = 0;
        if(TimeCurrent() - last_recovery_log > 300) // Log every 5 minutes
        {
            Print("🔄 DCA RECOVERY MODE: Target = $", DoubleToString(recovery_target, 2), " (Break-even or half max loss)");
            last_recovery_log = TimeCurrent();
        }
    }
    
    // 🚨 LOSS PROTECTION: Check if total loss exceeds limit
    if(total_profit <= -InpMaxLossUSD)
    {
        Print("🚨 LOSS PROTECTION TRIGGERED! Total Loss: $", DoubleToString(total_profit, 2), " >= $", DoubleToString(-InpMaxLossUSD, 2));
        Print("🔄 Closing ALL positions to prevent further losses...");
        g_grid_manager.CloseAllGridPositions();
        g_is_closing_positions = true;
        
        // 🎯 SMART SPREAD: Set waiting state after loss protection
        g_last_profit_time = TimeCurrent();
        g_waiting_for_spread = true;
        Print("📊 LOSS PROTECTION: Will wait for spread <= ", DoubleToString(InpMaxSpreadPips, 1), " before new grid");
        
        return true;
    }

    if(InpUseTotalProfitTarget)
    {
        // TOTAL PROFIT MODE - Close both directions
        if(total_profit >= effective_target_usd)
        {
            Print("🎯 TOTAL PROFIT TARGET REACHED! Total: $", DoubleToString(total_profit, 2));
            g_grid_manager.CloseAllGridPositions();
            g_is_closing_positions = true;
            
        // 🎯 SMART SPREAD: Set waiting state after profit
        g_last_profit_time = TimeCurrent();
        g_waiting_for_spread = true;
        g_dca_recovery_mode = false; // Reset DCA recovery mode after profit
        string trading_symbol = GetTradingSymbol();
        double max_spread_limit = GetAdaptiveSpreadLimit(trading_symbol, false);
        Print("📊 SPREAD MANAGEMENT: Will wait for spread <= ", DoubleToString(max_spread_limit, 1), " before new grid");
            
            return true;
        }
    }
    else
    {
        // PER-DIRECTION MODE - Close each direction independently
        bool target_hit = false;
        if(buy_profit >= effective_target_usd)
        {
            Print("🎯 BUY DIRECTION PROFIT TARGET REACHED! Buy Profit: $", DoubleToString(buy_profit, 2));
            g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_BUY);
            g_is_closing_buy = true;
            target_hit = true;
        }
        if(sell_profit >= effective_target_usd)
        {
            Print("🎯 SELL DIRECTION PROFIT TARGET REACHED! Sell Profit: $", DoubleToString(sell_profit, 2));
            g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_SELL);
            g_is_closing_sell = true;
            target_hit = true;
        }
        return target_hit;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check DCA Expansion                                              |
//+------------------------------------------------------------------+
void CheckDCAExpansion()
{
    if(g_grid_manager == NULL) return;
    
    // Check both directions for potential DCA expansion
    // Note: GridManager handles the logic internally
    static datetime last_dca_check = 0;
    if(TimeCurrent() - last_dca_check < 300) return; // Check every 5 minutes
    
    last_dca_check = TimeCurrent();
    
    // GridManager will handle DCA expansion logic internally
    // This could be enhanced to call specific DCA methods if implemented
}

//+------------------------------------------------------------------+
//| Check Loss Protection                                            |
//+------------------------------------------------------------------+
void CheckLossProtection()
{
    if(g_grid_manager == NULL) return;
    
    double buy_loss = -g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
    double sell_loss = -g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double max_loss = balance * (InpMaxAccountRisk / 100.0);
    
    bool protection_triggered = false;
    
    if(buy_loss > max_loss)
    {
        Print("🚨 BUY Loss Protection: Loss $", DoubleToString(buy_loss, 2), " > Max $", DoubleToString(max_loss, 2));
        g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_BUY);
        g_is_closing_buy = true;
        protection_triggered = true;
    }
    
    if(sell_loss > max_loss)
    {
        Print("🚨 SELL Loss Protection: Loss $", DoubleToString(sell_loss, 2), " > Max $", DoubleToString(max_loss, 2));
        g_grid_manager.CloseDirectionPositions(GRID_DIRECTION_SELL);
        g_is_closing_sell = true;
        protection_triggered = true;
    }
    
    if(protection_triggered)
    {
        Print("🚨 LOSS PROTECTION ACTIVATED - Account Risk Limit Reached!");
    }
}

//+------------------------------------------------------------------+
//| Handle trailing stop                                             |
//+------------------------------------------------------------------+
void HandleTrailingStop()
{
    // This function can be implemented later if needed.
    // Kept here for future development.
}

//+------------------------------------------------------------------+
//| Print current status                                             |
//+------------------------------------------------------------------+
void PrintCurrentStatus()
{
    Print("=== Current Status ===");
    Print("Time: ", TimeToString(TimeCurrent()));
    Print("Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    Print("Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    Print("Open Positions: ", PositionsTotal());
    Print("Pending Orders: ", OrdersTotal());
    
    if(g_atr_calculator != NULL)
        g_atr_calculator.PrintATRInfo();
        
    if(g_grid_manager != NULL)
        g_grid_manager.PrintGridInfo();
}

//+------------------------------------------------------------------+
//| Print market information                                         |
//+------------------------------------------------------------------+
void PrintMarketInfo()
{
    Print("=== Market Information ===");
    Print("Symbol: ", _Symbol);
    Print("Digits: ", (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    Print("Point: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("Tick Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
    Print("Tick Value: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
    Print("Lot Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
    Print("Min Lot: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
    Print("Max Lot: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
    Print("Lot Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
    Print("Current Spread: ", (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
}

//+------------------------------------------------------------------+
//| Print final statistics                                           |
//+------------------------------------------------------------------+
void PrintFinalStatistics()
{
    double final_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double total_profit = final_balance - g_account_start_balance;
    double profit_percent = (total_profit / g_account_start_balance) * 100.0;
    
    Print("=== Final Statistics ===");
    Print("Start Balance: ", g_account_start_balance);
    Print("Final Balance: ", final_balance);
    Print("Total Profit: ", total_profit);
    Print("Profit %: ", DoubleToString(profit_percent, 2), "%");
}
//+------------------------------------------------------------------+
