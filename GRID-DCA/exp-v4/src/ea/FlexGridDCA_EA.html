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
#include <services\DashboardUIService.mqh>

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
input int         InpMaxGridLevels = 8;              // Maximum Grid Levels 
input double      InpATRMultiplier = 1.2;           // ATR Multiplier for Grid Spacing (Optimized: 1.1-1.4 range from backtest)

input group "=== RISK MANAGEMENT ==="
input double      InpMaxAccountRisk = 10.0;         // Maximum Account Risk %
input double      InpProfitTargetPercent = 5;     // Profit Target % (Per Direction)
input double      InpProfitTargetUSD = 20;         // Profit Target USD (Per Direction)
input bool        InpUseTotalProfitTarget = true;   // Use Total Profit Target (Both Directions)
input double      InpMaxLossUSD = 50.0;             // Maximum Loss USD (MUST be > ProfitTarget for optimal performance)
input double      InpMaxEquityDrawdownPercent = 15.0; // Maximum Equity Drawdown % (Enhanced Protection)
input double      InpMinMarginLevel = 200.0;        // Minimum Margin Level % (Enhanced Protection)

input group "=== ENHANCED RISK MANAGEMENT ==="
input bool        InpUseATRDollarSizing = false;    // Use ATR-Dollar Position Sizing (Alternative to Fixed Lot)
input double      InpRiskPerLevelUSD = 5.0;         // Risk per Grid Level in USD (for ATR sizing)
input double      InpMaxExposurePerDirection = 50.0; // Maximum Exposure per Direction (USD)
input int         InpMaxPositionsPerDirection = 10; // Maximum Positions per Direction

input double      InpMaxSpreadPips = 0.0;           // Maximum Spread (pips) - 0=Auto based on symbol
input double      InpMaxSpreadPipsWait = 0.0;       // Maximum Spread Wait (pips) - 0=Auto (2x normal)
input bool        InpUseVolatilityFilter = false;   // Use Volatility Filter

input group "=== NEWS FILTER ==="
input bool        InpUseNewsFilter = false;         // Use News Filter (Pause trading during news)
input int         InpNewsAvoidMinutes = 30;         // Minutes to avoid trading before/after news
input string      InpNewsEvents = "NFP,FOMC,GDP,CPI,PMI"; // News Events to Monitor
input bool        InpAvoidFridayClose = true;       // Avoid trading 2 hours before Friday market close

input group "=== PRESET CONFIGURATIONS ==="
input bool        InpUsePresetConfig = false;       // Use Preset Configuration for Symbol
input string      InpPresetSymbols = "EURUSD,GBPUSD,XAUUSD,BTCUSD,USDJPY"; // Available Presets

input group "=== LOGGING & ANALYSIS ==="
input bool        InpEnableCSVExport = true;        // Enable CSV Export for Analysis
input bool        InpEnableDebugMode = true;       // Enable Debug Mode (Verbose Logging)
input int         InpLogLevel = 2;                  // Log Level: 0=Error, 1=Warning, 2=Info, 3=Debug

input group "=== TIME FILTERS ==="
input int         InpStartHour = 10;                // Start Trading Hour (Optimized: 10-11 from backtest)
input int         InpEndHour = 20;                  // End Trading Hour (Optimized: 18-21 from backtest)


input group "=== TREND FILTER ==="
input double      InpMaxADXStrength = 35.0;         // Maximum ADX for Sideways (Optimized: 35+ from backtest)
input double      InpTrailingStopATR = 2.4;         // Trailing Stop ATR Multiplier
input int         InpMagicNumber = 12345;           // Magic Number
input string      InpEAComment = "FlexGridDCA";     // EA Comment

//+------------------------------------------------------------------+
//| ENHANCED: Enhanced Grid Manager with Risk Management            |
//+------------------------------------------------------------------+
class CEnhancedGridManager : public CGridManagerV2
{
public:
    // Override dynamic lot size calculation
    double CalculateDynamicLotSize()
    {
        // Use EA's enhanced risk management
        string symbol = GetTradingSymbol();
        return CalculateATRDollarLotSize(symbol, InpRiskPerLevelUSD);
    }
    
    // Enhanced order placement with risk checks
    bool CanPlaceOrder(GRID_DIRECTION direction, double lot_size) 
    {
        return CheckExposureLimits(direction, lot_size);
    }
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CATRCalculator       *g_atr_calculator;
CEnhancedGridManager *g_grid_manager;    // ENHANCED: Use derived class
CTrade               g_trade;

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

// ENHANCED: On-Chart Dashboard Variables
bool             g_dashboard_initialized = false; // Dashboard initialization flag
int              g_dashboard_update_timer = 0;    // Dashboard update timing

// ENHANCED: Logging System Variables  
int              g_log_file_handle = INVALID_HANDLE; // CSV log file handle
datetime         g_last_csv_export = 0;           // Last CSV export time

// ENHANCED: News Filter Variables
datetime         g_next_news_event = 0;            // Next known news event time
bool             g_news_trading_paused = false;    // Trading paused due to news

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
    // InpUseTrendFilter hardcoded to true - 100% of optimal configs use trend filter
    // if(!InpUseTrendFilter)
    //     return true; // No filter = always allow
    
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
    
    // Initialize Enhanced Grid Manager with Risk Management
    g_grid_manager = new CEnhancedGridManager();
    if(!g_grid_manager.Initialize(trading_symbol, InpFixedLotSize, InpMaxGridLevels, (ulong)InpMagicNumber))
    {
        Print("ERROR: Failed to initialize Grid Manager V2");
        return(INIT_FAILED);
    }
    
    // Set profit targets in GridManager
    g_grid_manager.SetProfitTargets(InpProfitTargetUSD, InpProfitTargetPercent, InpUseTotalProfitTarget);
    
    // Set market entry option in GridManager (hardcoded to false - optimal from backtest)
    g_grid_manager.SetMarketEntry(false); // InpEnableMarketEntry removed - 95% optimal = false
    
    // Set Fibonacci spacing option in GridManager (hardcoded to false - optimal from backtest)
    g_grid_manager.SetFibonacciSpacing(false); // InpUseFibonacciSpacing removed - 100% optimal = false
    
    // ENHANCED: Inject ATR Calculator into GridManager 
    g_grid_manager.SetATRCalculator(g_atr_calculator);
    
    // Initialize Trend Filter indicators (hardcoded to true - optimal from backtest)
    // if(InpUseTrendFilter) // Removed - always true
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
    
    // Initial setup
    if(!InitialSetup())
    {
        Print("ERROR: Initial setup failed");
        return(INIT_FAILED);
    }
    
    g_ea_initialized = true;
    // ENHANCED: Initialize On-Chart Dashboard
    InitializeDashboard();
    
    // ENHANCED: Initialize Logging System
    InitializeLogging();
    
    // ENHANCED: Apply Preset Configuration (if enabled)
    ApplyPresetConfiguration(trading_symbol);
    
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
    
    // ENHANCED: Cleanup On-Chart Dashboard
    CleanupDashboard();
    
    // ENHANCED: Cleanup Logging System
    CleanupLogging();
    
    // Cleanup
    if(g_atr_calculator != NULL)
    {
        delete g_atr_calculator;
        g_atr_calculator = NULL;
    }
        
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
            // Reduced logging frequency for trend filter
        static datetime last_trend_log = 0;
        if(TimeCurrent() - last_trend_log > 300) // Log every 5 minutes instead of every tick
        {
            Print("⏳ TREND FILTER: Waiting for sideways market to setup new grid...");
            last_trend_log = TimeCurrent();
        }
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
    if(!IsTradingAllowed() || !IsNewsTradingAllowed())
        return;
    
    // Update grid status
    g_grid_manager.UpdateGridStatus();
    
    // 🚀 SMART DCA EXPANSION: Check if we need to add counter-trend orders
    if(g_grid_manager.CheckSmartDCAExpansion())
    {
        Print("⚡ DCA EXPANSION TRIGGERED - Placing new orders...");
        
        // 🎯 ACTIVATE DCA RECOVERY MODE: Lower profit targets after DCA expansion
        
            g_dca_recovery_mode = true;
            Print("🔄 DCA RECOVERY MODE ACTIVATED: Lower profit targets now in effect");
        
    }
    
    // Place pending orders for both directions
    g_grid_manager.PlaceGridOrders();
    
    
    // Check Loss Protection
    CheckLossProtection();
    
    // 🎯 TRAILING STOP: Check for partial profit taking and trailing
    CheckTrailingStopLogic();
    
    // ENHANCED: Check Equity Drawdown & Margin Level Protection
    if(CheckEquityDrawdownKillSwitch())
        return; // Stop trading if kill-switch triggered
    
    
    // 🔥 AUTO-RESCUE: Trigger DCA rescue when loss exceeds threshold
    static datetime last_auto_rescue_check = 0;
    if(TimeCurrent() - last_auto_rescue_check > 5) // Check every 5 seconds (more aggressive)
    {
        double buy_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        
        // MORE AGGRESSIVE AUTO-RESCUE: 30% of max loss (even earlier intervention)
        double rescue_threshold = -InpMaxLossUSD * 0.3;
        
        // Debug current profits
        if(sell_profit < -5.0 || buy_profit < -5.0)
        {
            Print("🔍 PROFIT DEBUG: BUY=$", DoubleToString(buy_profit, 2), " SELL=$", DoubleToString(sell_profit, 2), " Threshold=$", DoubleToString(rescue_threshold, 2));
        }
        
        if(sell_profit <= rescue_threshold && g_grid_manager.GetDirectionDCAExpansions(GRID_DIRECTION_SELL) == 0)
        {
            Print("🔥 EARLY AUTO-RESCUE TRIGGERED: SELL loss $", DoubleToString(sell_profit, 2), " >= threshold $", DoubleToString(rescue_threshold, 2));
            g_grid_manager.ForceDCARescue(GRID_DIRECTION_SELL);
        }
        
        if(buy_profit <= rescue_threshold && g_grid_manager.GetDirectionDCAExpansions(GRID_DIRECTION_BUY) == 0)
        {
            Print("🔥 EARLY AUTO-RESCUE TRIGGERED: BUY loss $", DoubleToString(buy_profit, 2), " >= threshold $", DoubleToString(rescue_threshold, 2));
            g_grid_manager.ForceDCARescue(GRID_DIRECTION_BUY);
        }
        
        last_auto_rescue_check = TimeCurrent();
    }
        
    // ENHANCED: Update On-Chart Dashboard (every 10 seconds - more frequent)
    g_dashboard_update_timer++;
    if(g_dashboard_update_timer >= 2) // 2 * 5 seconds = 10 seconds
    {
        if(g_dashboard_initialized)
        {
            UpdateEnhancedDashboard();
            Print("🔄 Dashboard updated at ", TimeToString(TimeCurrent()));
        }
        g_dashboard_update_timer = 0;
    }
    
    // ENHANCED: Export to CSV periodically (every 5 minutes)
    if(InpEnableCSVExport && TimeCurrent() - g_last_csv_export > 300)
    {
        ExportTradingDataToCSV();
        g_last_csv_export = TimeCurrent();
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
    
    if(InpMaxGridLevels <= 0 || InpMaxGridLevels > 100)
    {
        Print("ERROR: Invalid max grid levels: ", InpMaxGridLevels, " (Max: 100)");
        return false;
    }
    
    // CRITICAL VALIDATION: Verify optimal risk pattern from backtest
    if(InpMaxLossUSD <= InpProfitTargetUSD)
    {
        Print("⚠️ WARNING: MaxLossUSD (", InpMaxLossUSD, ") should be > ProfitTargetUSD (", InpProfitTargetUSD, ")");
        Print("📊 BACKTEST INSIGHT: 100% of optimal configs use MaxLoss > ProfitTarget for better DCA recovery");
        Print("💡 RECOMMENDATION: Set MaxLossUSD = 2-3x ProfitTargetUSD for optimal performance");
        // Continue but warn user about suboptimal settings
    }
    
    // ENHANCED RISK VALIDATION: Equity Drawdown & Margin Level
    if(InpMaxEquityDrawdownPercent <= 0 || InpMaxEquityDrawdownPercent > 50)
    {
        Print("⚠️ WARNING: MaxEquityDrawdownPercent (", InpMaxEquityDrawdownPercent, "%) should be 5-25% for safe trading");
        Print("💡 RECOMMENDATION: 10-15% is optimal balance between protection and trading freedom");
    }
    
    if(InpMinMarginLevel < 100)
    {
        Print("⚠️ WARNING: MinMarginLevel (", InpMinMarginLevel, "%) too low - risk of margin call");
        Print("💡 RECOMMENDATION: Use 200-500% for safe margin buffer");
    }
    
    // ENHANCED RISK VALIDATION: ATR-Dollar Sizing
    if(InpUseATRDollarSizing && InpRiskPerLevelUSD <= 0)
    {
        Print("⚠️ WARNING: RiskPerLevelUSD must be > 0 when using ATR-Dollar sizing");
        Print("💡 RECOMMENDATION: Use $2-10 per level depending on account size");
    }
    
    if(InpMaxExposurePerDirection <= 0 || InpMaxExposurePerDirection < InpRiskPerLevelUSD * 3)
    {
        Print("⚠️ WARNING: MaxExposurePerDirection too low for effective grid operation");
        Print("💡 RECOMMENDATION: Set to at least 5-10x RiskPerLevel for flexibility");
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
    
    // Check time filter (hardcoded to true - 100% of optimal configs use time filter)
    // if(InpUseTimeFilter) // Removed - always true
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
        // FIXED: Remove Sleep() - use state-based waiting instead
        // Sleep(1000);  // Wait for orders to close - REMOVED for performance
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
    if(g_dca_recovery_mode)
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
//| Enhanced: Check Equity Drawdown & Margin Level Kill-Switch      |
//+------------------------------------------------------------------+
bool CheckEquityDrawdownKillSwitch()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    // Calculate equity drawdown percentage
    double equity_drawdown_percent = 0.0;
    if(balance > 0)
    {
        equity_drawdown_percent = ((balance - equity) / balance) * 100.0;
    }
    
    bool kill_switch_triggered = false;
    
    // 🚨 EQUITY DRAWDOWN KILL-SWITCH
    if(equity_drawdown_percent >= InpMaxEquityDrawdownPercent)
    {
        Print("🚨 EQUITY DRAWDOWN KILL-SWITCH TRIGGERED!");
        Print("📉 Current Drawdown: ", DoubleToString(equity_drawdown_percent, 2), "% >= Max: ", DoubleToString(InpMaxEquityDrawdownPercent, 2), "%");
        Print("💰 Balance: $", DoubleToString(balance, 2), " | Equity: $", DoubleToString(equity, 2));
        kill_switch_triggered = true;
    }
    
    // 🚨 MARGIN LEVEL KILL-SWITCH
    if(margin_level > 0 && margin_level <= InpMinMarginLevel)
    {
        Print("🚨 MARGIN LEVEL KILL-SWITCH TRIGGERED!");
        Print("📊 Current Margin Level: ", DoubleToString(margin_level, 2), "% <= Min: ", DoubleToString(InpMinMarginLevel, 2), "%");
        Print("⚠️ Risk of margin call - Closing all positions immediately!");
        kill_switch_triggered = true;
    }
    
    if(kill_switch_triggered)
    {
        Print("🔄 EMERGENCY SHUTDOWN: Closing ALL positions and orders...");
        g_grid_manager.CloseAllGridPositions();
        g_is_closing_positions = true;
        
        // Set waiting state for spread normalization after emergency close
        g_last_profit_time = TimeCurrent();
        g_waiting_for_spread = true;
        
        Print("📊 KILL-SWITCH: Will wait for normal spread before resuming trading");
        return true;
    }
    
    return false;
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
//| ENHANCED: Initialize On-Chart Dashboard                         |
//+------------------------------------------------------------------+
void InitializeDashboard()
{
    if(g_dashboard_initialized) return;
    
    // Create dashboard background
    ObjectCreate(0, "DashboardBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_XSIZE, 300);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_YSIZE, 180);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_COLOR, clrDarkGray);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_COLOR, clrDarkGray);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_BACK, false);
    ObjectSetInteger(0, "DashboardBG", OBJPROP_SELECTABLE, false);
    
    // Create dashboard labels
    string labels[] = {
        "DashTitle", "DashStatus", "DashBuyProfit", "DashSellProfit", 
        "DashTotalProfit", "DashTarget", "DashTrend", "DashSpread"
    };
    
    for(int i = 0; i < ArraySize(labels); i++)
    {
        ObjectCreate(0, labels[i], OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labels[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labels[i], OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, labels[i], OBJPROP_YDISTANCE, 40 + i * 18);
        ObjectSetInteger(0, labels[i], OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, labels[i], OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, labels[i], OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, labels[i], OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, labels[i], OBJPROP_BACK, false);
    }
    
    // Create Panic Button
    ObjectCreate(0, "PanicButton", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PanicButton", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "PanicButton", OBJPROP_XDISTANCE, 200);
    ObjectSetInteger(0, "PanicButton", OBJPROP_YDISTANCE, 180);
    ObjectSetInteger(0, "PanicButton", OBJPROP_XSIZE, 100);
    ObjectSetInteger(0, "PanicButton", OBJPROP_YSIZE, 25);
    ObjectSetInteger(0, "PanicButton", OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, "PanicButton", OBJPROP_BORDER_COLOR, clrDarkRed);
    ObjectSetInteger(0, "PanicButton", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "PanicButton", OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "PanicButton", OBJPROP_BACK, false);
    ObjectSetInteger(0, "PanicButton", OBJPROP_SELECTABLE, true);
    
    ObjectCreate(0, "PanicText", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PanicText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "PanicText", OBJPROP_XDISTANCE, 220);
    ObjectSetInteger(0, "PanicText", OBJPROP_YDISTANCE, 190);
    ObjectSetInteger(0, "PanicText", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "PanicText", OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, "PanicText", OBJPROP_FONT, "Arial Bold");
    ObjectSetString(0, "PanicText", OBJPROP_TEXT, "CLOSE ALL");
    ObjectSetInteger(0, "PanicText", OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, "PanicText", OBJPROP_BACK, false);
    
    g_dashboard_initialized = true;
    Print("✅ On-Chart Dashboard initialized");
}

//+------------------------------------------------------------------+
//| ENHANCED: Update Dashboard Information                           |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    if(!g_dashboard_initialized) return;
    
    // Update Title
    ObjectSetString(0, "DashTitle", OBJPROP_TEXT, "FlexGrid DCA EA v3.1 📊");
    
    // Update Status
    string status = "⚪ IDLE";
    if(g_is_closing_positions) status = "🔄 CLOSING ALL";
    else if(g_is_closing_buy || g_is_closing_sell) status = "🔄 CLOSING";
    else if(g_waiting_for_spread) status = "⏳ WAITING SPREAD";
    else if(!IsSidewaysMarket()) status = "⏳ WAITING TREND";
    else if(g_news_trading_paused) status = "📰 NEWS PAUSE";
    else if(!IsTradingAllowed()) status = "⏸️ PAUSED";
    else status = "🟢 TRADING";
    ObjectSetString(0, "DashStatus", OBJPROP_TEXT, "Status: " + status);
    
    // Update Profits
    if(g_grid_manager != NULL)
    {
        double buy_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        double total_profit = buy_profit + sell_profit;
        
        ObjectSetString(0, "DashBuyProfit", OBJPROP_TEXT, "BUY: $" + DoubleToString(buy_profit, 2));
        ObjectSetString(0, "DashSellProfit", OBJPROP_TEXT, "SELL: $" + DoubleToString(sell_profit, 2));
        
        color profit_color = (total_profit >= 0) ? clrLime : clrRed;
        ObjectSetInteger(0, "DashTotalProfit", OBJPROP_COLOR, profit_color);
        ObjectSetString(0, "DashTotalProfit", OBJPROP_TEXT, "TOTAL: $" + DoubleToString(total_profit, 2));
    }
    
    // Update Target
    string target_text = "Target: $" + DoubleToString(InpProfitTargetUSD, 2);
    if(g_dca_recovery_mode) target_text += " (Recovery)";
    ObjectSetString(0, "DashTarget", OBJPROP_TEXT, target_text);
    
    // Update Trend Status
    string trend_status = "🔍 UNKNOWN";
    if(IsSidewaysMarket()) trend_status = "↔️ SIDEWAYS";
    else trend_status = "📈 TRENDING";
    ObjectSetString(0, "DashTrend", OBJPROP_TEXT, "Trend: " + trend_status);
    
    // Update Spread
    string trading_symbol = GetTradingSymbol();
    double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0;
    double max_spread_limit = GetAdaptiveSpreadLimit(trading_symbol, false);
    
    color spread_color = (current_spread <= max_spread_limit) ? clrLime : clrYellow;
    ObjectSetInteger(0, "DashSpread", OBJPROP_COLOR, spread_color);
    ObjectSetString(0, "DashSpread", OBJPROP_TEXT, "Spread: " + DoubleToString(current_spread, 1) + "/" + DoubleToString(max_spread_limit, 1));
}

//+------------------------------------------------------------------+
//| ENHANCED: Cleanup Dashboard Objects                              |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
    string objects[] = {
        "DashboardBG", "DashTitle", "DashStatus", "DashBuyProfit", "DashSellProfit",
        "DashTotalProfit", "DashTarget", "DashTrend", "DashSpread", "PanicButton", "PanicText"
    };
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        ObjectDelete(0, objects[i]);
    }
    
    g_dashboard_initialized = false;
    Print("🧹 Dashboard cleaned up");
}

//+------------------------------------------------------------------+
//| ENHANCED: Handle Chart Events (Panic Button)                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "PanicButton")
        {
            LogMessage(1, "PANIC", "Emergency Close All button pressed by user");
            if(g_grid_manager != NULL)
            {
                g_grid_manager.CloseAllGridPositions();
                g_is_closing_positions = true;
            }
            
            // Reset button
            ObjectSetInteger(0, "PanicButton", OBJPROP_STATE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| ENHANCED: Initialize Logging System                             |
//+------------------------------------------------------------------+
void InitializeLogging()
{
    if(!InpEnableCSVExport) return;
    
    string filename = "FlexGridDCA_" + GetTradingSymbol() + "_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    StringReplace(filename, ":", "-");
    StringReplace(filename, " ", "_");
    
    g_log_file_handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON);
    
    if(g_log_file_handle != INVALID_HANDLE)
    {
        // Write CSV header
        FileWrite(g_log_file_handle, 
                  "Timestamp", "Symbol", "Event", "Status", "BuyProfit", "SellProfit", "TotalProfit", 
                  "Target", "Balance", "Equity", "DrawdownPct", "MarginLevel", "Spread", 
                  "TrendStatus", "RecoveryMode", "GridLevels", "ATRMultiplier");
        
        FileFlush(g_log_file_handle);
        LogMessage(2, "INIT", "CSV logging initialized: " + filename);
    }
    else
    {
        LogMessage(0, "ERROR", "Failed to initialize CSV logging");
    }
}

//+------------------------------------------------------------------+
//| ENHANCED: Central Logging Function with Levels                  |
//+------------------------------------------------------------------+
void LogMessage(int level, string category, string message)
{
    // 0=Error, 1=Warning, 2=Info, 3=Debug
    if(level > InpLogLevel) return;
    
    string level_names[] = {"ERROR", "WARN", "INFO", "DEBUG"};
    string level_icons[] = {"❌", "⚠️", "ℹ️", "🔍"};
    
    if(level < 0 || level > 3) level = 2; // Default to INFO
    
    string log_text = level_icons[level] + " [" + level_names[level] + "][" + category + "] " + message;
    
    Print(log_text);
    
    // In debug mode, also log to file immediately
    if(InpEnableDebugMode && g_log_file_handle != INVALID_HANDLE)
    {
        FileWrite(g_log_file_handle, TimeToString(TimeCurrent()), category, message);
        FileFlush(g_log_file_handle);
    }
}

//+------------------------------------------------------------------+
//| ENHANCED: Export Trading Data to CSV                            |
//+------------------------------------------------------------------+
void ExportTradingDataToCSV()
{
    if(!InpEnableCSVExport || g_log_file_handle == INVALID_HANDLE || g_grid_manager == NULL) 
        return;
    
    double buy_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
    double sell_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
    double total_profit = buy_profit + sell_profit;
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double drawdown_pct = (balance > 0) ? ((balance - equity) / balance) * 100.0 : 0.0;
    double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    string trading_symbol = GetTradingSymbol();
    double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0;
    
    string status = "TRADING";
    if(g_is_closing_positions) status = "CLOSING_ALL";
    else if(g_is_closing_buy || g_is_closing_sell) status = "CLOSING_PARTIAL";
    else if(g_waiting_for_spread) status = "WAITING_SPREAD";
    else if(g_news_trading_paused) status = "NEWS_PAUSE";
    else if(!IsSidewaysMarket()) status = "WAITING_TREND";
    
    string trend_status = IsSidewaysMarket() ? "SIDEWAYS" : "TRENDING";
    
    // Write data to CSV
    FileWrite(g_log_file_handle,
              TimeToString(TimeCurrent()),
              trading_symbol,
              "SNAPSHOT",
              status,
              DoubleToString(buy_profit, 2),
              DoubleToString(sell_profit, 2), 
              DoubleToString(total_profit, 2),
              DoubleToString(InpProfitTargetUSD, 2),
              DoubleToString(balance, 2),
              DoubleToString(equity, 2),
              DoubleToString(drawdown_pct, 2),
              DoubleToString(margin_level, 2),
              DoubleToString(current_spread, 1),
              trend_status,
              g_dca_recovery_mode ? "YES" : "NO",
              IntegerToString(InpMaxGridLevels),
              DoubleToString(InpATRMultiplier, 2));
    
    FileFlush(g_log_file_handle);
    
    LogMessage(3, "CSV", "Trading data exported to CSV");
}

//+------------------------------------------------------------------+
//| ENHANCED: Cleanup Logging System                                |
//+------------------------------------------------------------------+
void CleanupLogging()
{
    if(g_log_file_handle != INVALID_HANDLE)
    {
        // Write final summary
        if(InpEnableCSVExport)
        {
            FileWrite(g_log_file_handle, TimeToString(TimeCurrent()), "SYSTEM", "SHUTDOWN", "EA_STOPPED");
        }
        
        FileClose(g_log_file_handle);
        g_log_file_handle = INVALID_HANDLE;
        LogMessage(2, "CLEANUP", "CSV logging closed");
    }
}

//+------------------------------------------------------------------+
//| ENHANCED: Preset Configuration Structure                        |
//+------------------------------------------------------------------+
struct SPresetConfig
{
    string symbol;
    double fixed_lot_size;
    int max_grid_levels;
    double atr_multiplier;
    double profit_target_usd;
    double max_loss_usd;
    double risk_per_level_usd;
    double max_exposure_per_direction;
    int max_positions_per_direction;
    double max_spread_pips;
    string description;
};

//+------------------------------------------------------------------+
//| ENHANCED: Apply Preset Configuration                            |
//+------------------------------------------------------------------+
void ApplyPresetConfiguration(string symbol)
{
    if(!InpUsePresetConfig) return;
    
    SPresetConfig presets[] = {
        // EURUSD - Conservative Forex
        {"EURUSD", 0.01, 10, 1.2, 3.0, 8.0, 4.0, 40.0, 8, 2.0, "Conservative Forex"},
        
        // GBPUSD - Moderate Forex (higher volatility)
        {"GBPUSD", 0.01, 12, 1.4, 4.0, 10.0, 5.0, 50.0, 10, 3.0, "Moderate Forex"},
        
        // XAUUSD - Gold (high volatility, wider spreads)
        {"XAUUSD", 0.01, 8, 0.8, 8.0, 20.0, 10.0, 80.0, 6, 50.0, "Gold Trading"},
        
        // BTCUSD - Crypto (very high volatility)
        {"BTCUSD", 0.01, 6, 0.6, 15.0, 40.0, 20.0, 120.0, 5, 100.0, "Crypto Trading"},
        
        // USDJPY - Stable Forex
        {"USDJPY", 0.01, 11, 1.3, 3.5, 9.0, 4.5, 45.0, 9, 2.5, "Stable Forex"}
    };
    
    for(int i = 0; i < ArraySize(presets); i++)
    {
        if(StringFind(symbol, presets[i].symbol) >= 0)
        {
            LogMessage(2, "PRESET", "Applying " + presets[i].description + " configuration for " + symbol);
            Print("📋 PRESET CONFIG: " + presets[i].description);
            Print("├─ Lot Size: " + DoubleToString(presets[i].fixed_lot_size, 3));
            Print("├─ Grid Levels: " + IntegerToString(presets[i].max_grid_levels));
            Print("├─ ATR Multiplier: " + DoubleToString(presets[i].atr_multiplier, 1));
            Print("├─ Profit Target: $" + DoubleToString(presets[i].profit_target_usd, 2));
            Print("├─ Max Loss: $" + DoubleToString(presets[i].max_loss_usd, 2));
            Print("├─ Risk/Level: $" + DoubleToString(presets[i].risk_per_level_usd, 2));
            Print("├─ Max Exposure: $" + DoubleToString(presets[i].max_exposure_per_direction, 2));
            Print("├─ Max Positions: " + IntegerToString(presets[i].max_positions_per_direction));
            Print("└─ Max Spread: " + DoubleToString(presets[i].max_spread_pips, 1) + " pips");
            
            // Note: In a real implementation, these would override the input parameters
            // For now, we just log the recommended values
            Print("💡 RECOMMENDATION: Adjust input parameters to match preset for optimal performance");
            return;
        }
    }
    
    LogMessage(1, "PRESET", "No preset found for " + symbol + ". Using manual settings.");
    Print("⚠️ No preset configuration found for " + symbol);
    Print("📋 Available presets: " + InpPresetSymbols);
}

//+------------------------------------------------------------------+
//| ENHANCED: Calculate ATR-Dollar Position Size                    |
//+------------------------------------------------------------------+
double CalculateATRDollarLotSize(string symbol, double risk_usd_per_level)
{
    if(!InpUseATRDollarSizing || g_atr_calculator == NULL)
    {
        return InpFixedLotSize; // Fallback to fixed lot size
    }
    
    double atr_h1 = g_atr_calculator.GetATR(PERIOD_H1);
    if(atr_h1 <= 0) 
    {
        LogMessage(1, "RISK", "ATR unavailable, using fixed lot size");
        return InpFixedLotSize;
    }
    
    // Calculate point value for the symbol
    double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(tick_size <= 0 || tick_value <= 0 || point <= 0)
    {
        LogMessage(1, "RISK", "Invalid symbol info, using fixed lot size");
        return InpFixedLotSize;
    }
    
    // Calculate point value ($ per point)
    double point_value = (point / tick_size) * tick_value;
    
    // Calculate lot size: risk_usd / (atr * point_value)
    double calculated_lot = risk_usd_per_level / (atr_h1 * point_value);
    
    // Apply broker constraints
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Round to lot step
    if(lot_step > 0)
    {
        calculated_lot = MathFloor(calculated_lot / lot_step) * lot_step;
    }
    
    // Apply limits
    calculated_lot = MathMax(min_lot, MathMin(max_lot, calculated_lot));
    
    LogMessage(3, "RISK", StringFormat("ATR-Dollar sizing: ATR=%.5f, Risk=$%.2f, Lot=%.3f", 
                                       atr_h1, risk_usd_per_level, calculated_lot));
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
//| ENHANCED: Check Per-Direction Exposure Limits                   |
//+------------------------------------------------------------------+
bool CheckExposureLimits(GRID_DIRECTION direction, double additional_lot_size = 0.0)
{
    if(g_grid_manager == NULL) return true;
    
    string dir_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
    ENUM_POSITION_TYPE pos_type = (direction == GRID_DIRECTION_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    double current_exposure = 0.0; // Total USD exposure
    int position_count = 0;
    
    // Calculate current exposure for this direction
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == GetTradingSymbol() && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
           PositionGetInteger(POSITION_TYPE) == pos_type)
        {
            double position_volume = PositionGetDouble(POSITION_VOLUME);
            double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
            
            // Estimate USD exposure (simplified calculation)
            double tick_value = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_TRADE_TICK_VALUE);
            double tick_size = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_TRADE_TICK_SIZE);
            double point = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_POINT);
            
            if(tick_size > 0 && tick_value > 0 && point > 0)
            {
                double point_value = (point / tick_size) * tick_value;
                current_exposure += (position_volume * position_price * point_value) / point;
            }
            
            position_count++;
        }
    }
    
    // Add potential additional exposure
    if(additional_lot_size > 0.0)
    {
        double current_price = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_BID);
        double tick_value = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_TRADE_TICK_SIZE);
        double point = SymbolInfoDouble(GetTradingSymbol(), SYMBOL_POINT);
        
        if(tick_size > 0 && tick_value > 0 && point > 0)
        {
            double point_value = (point / tick_size) * tick_value;
            current_exposure += (additional_lot_size * current_price * point_value) / point;
        }
        position_count++;
    }
    
    // Check exposure limits
    bool exposure_ok = current_exposure <= InpMaxExposurePerDirection;
    bool position_count_ok = position_count <= InpMaxPositionsPerDirection;
    
    if(!exposure_ok)
    {
        LogMessage(1, "RISK", StringFormat("%s exposure limit reached: $%.2f >= $%.2f", 
                                          dir_name, current_exposure, InpMaxExposurePerDirection));
    }
    
    if(!position_count_ok)
    {
        LogMessage(1, "RISK", StringFormat("%s position count limit reached: %d >= %d", 
                                          dir_name, position_count, InpMaxPositionsPerDirection));
    }
    
    return exposure_ok && position_count_ok;
}

//+------------------------------------------------------------------+
//| ENHANCED: News Filter Implementation                            |
//+------------------------------------------------------------------+
bool IsNewsTradingAllowed()
{
    if(!InpUseNewsFilter) return true;
    
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    // Check Friday close avoidance (2 hours before market close)
    if(InpAvoidFridayClose && dt.day_of_week == 5) // Friday
    {
        // Assuming market closes at 17:00 EST (22:00 GMT)
        // Avoid trading after 20:00 GMT on Friday
        if(dt.hour >= 20)
        {
            LogMessage(2, "NEWS", "Trading paused: Friday market close approaching");
            g_news_trading_paused = true;
            return false;
        }
    }
    
    // Enhanced news event detection (simplified implementation)
    // In production, this would integrate with economic calendar API
    bool is_news_time = CheckForScheduledNews(current_time);
    
    if(is_news_time)
    {
        LogMessage(2, "NEWS", "Trading paused: High-impact news event detected");
        g_news_trading_paused = true;
        return false;
    }
    
    // Reset news pause flag if conditions are clear
    if(g_news_trading_paused)
    {
        LogMessage(2, "NEWS", "Trading resumed: News event period ended");
        g_news_trading_paused = false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| ENHANCED: Check for Scheduled News Events                       |
//+------------------------------------------------------------------+
bool CheckForScheduledNews(datetime current_time)
{
    // Simplified news detection based on common patterns
    // In production: integrate with ForexFactory, Investing.com API, or MT5 Calendar
    
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    // Common high-impact news times (EST/GMT)
    // NFP: First Friday of month at 8:30 EST (13:30 GMT)
    // FOMC: Usually Wednesday 2:00 PM EST (19:00 GMT)
    // CPI: Mid-month Tuesday/Wednesday 8:30 EST (13:30 GMT)
    
    // Check for first Friday NFP
    if(dt.day_of_week == 5 && dt.day <= 7) // First Friday of month
    {
        if(dt.hour == 13 && dt.min >= 0 && dt.min <= 60) // 13:30 GMT ± 30min
        {
            LogMessage(1, "NEWS", "Potential NFP release detected");
            return true;
        }
    }
    
    // Check for mid-week CPI/economic data (simplified)
    if((dt.day_of_week == 2 || dt.day_of_week == 3) && dt.day >= 10 && dt.day <= 20) // Mid-month Tue/Wed
    {
        if(dt.hour == 13 && dt.min >= 0 && dt.min <= 60) // 13:30 GMT ± 30min
        {
            LogMessage(1, "NEWS", "Potential CPI/Economic data release detected");
            return true;
        }
    }
    
    // Check for FOMC (simplified - every 6-8 weeks on Wednesday)
    if(dt.day_of_week == 3 && dt.hour == 19 && dt.min >= 0 && dt.min <= 60) // 19:00 GMT ± 30min
    {
        LogMessage(1, "NEWS", "Potential FOMC meeting detected");
        return true;
    }
    
    return false;
}



//+------------------------------------------------------------------+
//| Enhanced Dashboard Update with State Info                       |
//+------------------------------------------------------------------+
void UpdateEnhancedDashboard()
{
    // ALWAYS update dashboard, even without positions
    if(g_dashboard_initialized)
    {
        double buy_profit = 0.0;
        double sell_profit = 0.0;
        
        if(g_grid_manager != NULL)
        {
            buy_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
            sell_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        }
        
        string trading_symbol = GetTradingSymbol();
        double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0;
        
        // Get detailed state information
        string state_reason = GetDetailedStateReason();
        double adx_value = GetCurrentADX();
        bool time_allowed = IsTradingAllowed();
        
        // Update Status
        string status = "⚪ IDLE";
        if(g_is_closing_positions) status = "🔄 CLOSING ALL";
        else if(g_is_closing_buy || g_is_closing_sell) status = "🔄 CLOSING";
        else if(g_waiting_for_spread) status = "⏳ WAITING SPREAD";
        else if(!IsSidewaysMarket()) status = "⏳ WAITING TREND";
        else if(g_news_trading_paused) status = "📰 NEWS PAUSE";
        else if(!IsTradingAllowed()) status = "⏸️ PAUSED";
        else status = "🟢 TRADING";
        
        // Update Trend Status
        string trend_status = "🔍 UNKNOWN";
        if(IsSidewaysMarket()) trend_status = "↔️ SIDEWAYS";
        else trend_status = "📈 TRENDING";
        
        string news_status = g_news_trading_paused ? "PAUSED" : "OK";
        
        CDashboardUIService::GetInstance().Update(
            trading_symbol, status, buy_profit, sell_profit, 
            InpProfitTargetUSD, trend_status, current_spread, news_status,
            state_reason, adx_value, time_allowed
        );
    }
}

//+------------------------------------------------------------------+
//| Get Detailed State Reason                                       |
//+------------------------------------------------------------------+
string GetDetailedStateReason()
{
    if(!IsTradingAllowed())
    {
        return "BLOCKED: Outside trading hours";
    }
    
    if(g_news_trading_paused)
    {
        return "WAITING: News event pause";
    }
    
    if(g_waiting_for_spread)
    {
        string trading_symbol = GetTradingSymbol();
        double current_spread = (double)SymbolInfoInteger(trading_symbol, SYMBOL_SPREAD) / 10.0;
        return "WAITING: High spread (" + DoubleToString(current_spread, 1) + "p)";
    }
    
    if(!IsSidewaysMarket())
    {
        double adx = GetCurrentADX();
        return "WAITING: Strong trend (ADX " + DoubleToString(adx, 1) + ")";
    }

    
    return "READY: Sideways grid setup";
}

//+------------------------------------------------------------------+
//| Get Current ADX Value                                           |
//+------------------------------------------------------------------+
double GetCurrentADX()
{
    double adx_buffer[1];
    if(CopyBuffer(g_adx_handle, 0, 0, 1, adx_buffer) > 0)
    {
        return adx_buffer[0];
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| TRAILING STOP LOGIC: Partial Profit + Trailing                 |
//+------------------------------------------------------------------+
void CheckTrailingStopLogic()
{
    double total_profit = g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY) + 
                         g_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
    
    // Only apply trailing if we have significant profit
    if(total_profit <= InpProfitTargetUSD * 0.5) return; // Must be at least 50% of target
    
    static bool partial_profit_taken = false;
    static double highest_profit = 0.0;
    static double trailing_threshold = 0.0;
    
    // Update highest profit
    if(total_profit > highest_profit)
    {
        highest_profit = total_profit;
    }
    
    // 🎯 PARTIAL PROFIT TAKING: Close 50% when reaching target
    if(!partial_profit_taken && total_profit >= InpProfitTargetUSD)
    {
        Print("🎯 PARTIAL PROFIT TAKING: Target $", DoubleToString(InpProfitTargetUSD, 2), " reached! Closing 50% of positions...");
        
        // Close 50% of most profitable positions
        ClosePartialPositions(0.5);
        
        partial_profit_taken = true;
        trailing_threshold = total_profit * 0.7; // Start trailing at 70% of peak
        
        Print("🏃 TRAILING ACTIVATED: Threshold set at $", DoubleToString(trailing_threshold, 2));
    }
    
    // 🏃 TRAILING STOP: Close remaining if profit drops significantly
    if(partial_profit_taken && total_profit <= trailing_threshold)
    {
        Print("🛑 TRAILING STOP TRIGGERED: Profit dropped to $", DoubleToString(total_profit, 2), " (threshold: $", DoubleToString(trailing_threshold, 2), ")");
        
        // Close all remaining positions
        g_is_closing_positions = true;
        g_grid_manager.CloseAllGridPositions();
        
        // Reset trailing variables
        partial_profit_taken = false;
        highest_profit = 0.0;
        trailing_threshold = 0.0;
    }
    
    // Update trailing threshold as profit increases
    if(partial_profit_taken && total_profit > highest_profit * 0.8)
    {
        double new_threshold = total_profit * 0.7;
        if(new_threshold > trailing_threshold)
        {
            trailing_threshold = new_threshold;
            Print("🔄 TRAILING UPDATED: New threshold $", DoubleToString(trailing_threshold, 2), " (Current profit: $", DoubleToString(total_profit, 2), ")");
        }
    }
}

//+------------------------------------------------------------------+
//| Close Partial Positions (Most Profitable First)                |
//+------------------------------------------------------------------+
void ClosePartialPositions(double percentage)
{
    // Get all positions and sort by profit
    struct SPositionInfo
    {
        ulong ticket;
        double profit;
        string symbol;
    };
    
    SPositionInfo positions[];
    int pos_count = 0;
    
    // Collect all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            if(pos_symbol == GetTradingSymbol())
            {
                ArrayResize(positions, pos_count + 1);
                positions[pos_count].ticket = ticket;
                positions[pos_count].profit = PositionGetDouble(POSITION_PROFIT);
                positions[pos_count].symbol = pos_symbol;
                pos_count++;
            }
        }
    }
    
    if(pos_count == 0) return;
    
    // Sort by profit (highest first) - simple bubble sort
    for(int i = 0; i < pos_count - 1; i++)
    {
        for(int j = 0; j < pos_count - i - 1; j++)
        {
            if(positions[j].profit < positions[j + 1].profit)
            {
                SPositionInfo temp = positions[j];
                positions[j] = positions[j + 1];
                positions[j + 1] = temp;
            }
        }
    }
    
    // Close specified percentage of positions (most profitable first)
    int positions_to_close = (int)(pos_count * percentage);
    if(positions_to_close < 1) positions_to_close = 1;
    
    Print("📊 CLOSING ", DoubleToString(positions_to_close, 0), " out of ", DoubleToString(pos_count, 0), " positions (", DoubleToString(percentage * 100, 0), "%)");
    
    for(int i = 0; i < positions_to_close && i < pos_count; i++)
    {
        if(PositionSelectByTicket(positions[i].ticket))
        {
            if(g_trade.PositionClose(positions[i].ticket))
            {
                Print("✅ PARTIAL CLOSE: Ticket #", DoubleToString(positions[i].ticket, 0), " Profit: $", DoubleToString(positions[i].profit, 2));
            }
            else
            {
                Print("❌ FAILED to close ticket #", DoubleToString(positions[i].ticket, 0), " Error: ", DoubleToString(GetLastError(), 0));
            }
        }
    }
}
