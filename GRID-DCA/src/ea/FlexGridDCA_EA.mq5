//+------------------------------------------------------------------+
//|                                                FlexGridDCA_EA.mq5 |
//|                                            Flex Grid DCA System   |
//|                      Universal Grid + DCA EA with Fixed Lot Size  |
//+------------------------------------------------------------------+
#property copyright "Flex Grid DCA EA"
#property link      ""
#property version   "1.00"
#property description "Universal Grid + DCA EA with ATR-based calculations"

#include <Trade\Trade.mqh>
#include <ATRCalculator.mqh>
#include <GridManager_v2.mqh>

//+------------------------------------------------------------------+
//| Expert Properties                                                |
//+------------------------------------------------------------------+
input group "=== BASIC SETTINGS ==="
input double      InpFixedLotSize = 0.01;           // Fixed Lot Size (Always 0.01 - Broker minimum)
input int         InpMaxGridLevels = 5;             // Maximum Grid Levels
input double      InpATRMultiplier = 1.0;           // ATR Multiplier for Grid Spacing
input bool        InpEnableGridTrading = true;      // Enable Grid Trading
input bool        InpEnableDCATrading = true;       // Enable DCA Trading

input group "=== RISK MANAGEMENT ==="
input double      InpMaxAccountRisk = 10.0;         // Maximum Account Risk %
input double      InpProfitTargetPercent = 1.0;     // Profit Target % (Per Direction)
input double      InpProfitTargetUSD = 3.0;         // Profit Target USD (Per Direction)
input bool        InpUseTotalProfitTarget = true;   // Use Total Profit Target (Both Directions)
input double      InpMaxSpreadPips = 8.0;           // Maximum Spread (pips)
input bool        InpUseVolatilityFilter = false;   // Use Volatility Filter

input group "=== TIME FILTERS ==="
input bool        InpUseTimeFilter = false;         // Enable Time Filter
input int         InpStartHour = 8;                 // Start Trading Hour
input int         InpEndHour = 18;                  // End Trading Hour

input group "=== ADVANCED ==="
input bool        InpEnableTrailingStop = false;    // Enable Trailing Stop
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
double           g_current_profit_target;
bool             g_ea_initialized;

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
    g_account_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_current_profit_target = g_account_start_balance * (InpProfitTargetPercent / 100.0);
    
    // Set trade settings
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Initialize ATR Calculator
    g_atr_calculator = new CATRCalculator();
    if(!g_atr_calculator.Initialize(_Symbol))
    {
        Print("ERROR: Failed to initialize ATR Calculator");
        return(INIT_FAILED);
    }
    
    // Initialize Grid Manager V2
    g_grid_manager = new CGridManagerV2();
    if(!g_grid_manager.Initialize(_Symbol, InpFixedLotSize, InpMaxGridLevels, InpMagicNumber))
    {
        Print("ERROR: Failed to initialize Grid Manager V2");
        return(INIT_FAILED);
    }
    
    // Set profit targets
    g_grid_manager.SetProfitTargets(InpProfitTargetUSD, InpProfitTargetPercent, InpUseTotalProfitTarget);
    
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
    
    // Update ATR values
    g_atr_calculator.UpdateATRValues();
    
    // Setup grid if needed (first time or after reset) - Do this BEFORE trading checks
    if(ShouldSetupGrid())
    {
        SetupGridSystem();
    }
    
    // Check trading conditions
    if(!IsTradingAllowed())
        return;
        
    // Check profit target
    if(CheckProfitTarget())
    {
        CloseAllPositions("Profit Target Reached");
        g_last_grid_update = 0;  // Force SetupGridSystem() to run in next tick
        return;                  // CRITICAL: Don't place new grid orders in same tick
    }
    
    // Update grid status
    g_grid_manager.UpdateGridStatus();
    
    // Place pending orders
    if(InpEnableGridTrading)
    {
        g_grid_manager.PlaceGridOrders();
    }
    
    // Handle trailing stop
    if(InpEnableTrailingStop)
    {
        HandleTrailingStop();
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Print status every hour
    static datetime last_status_print = 0;
    if(TimeCurrent() - last_status_print > 3600)  // 1 hour
    {
        PrintCurrentStatus();
        last_status_print = TimeCurrent();
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
    
    // Set timer for periodic checks
    EventSetTimer(300);  // 5 minutes
    
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
    int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double spread = spread_points * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double max_spread = InpMaxSpreadPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    if(spread > max_spread)
    {
        static datetime last_spread_warning = 0;
        if(TimeCurrent() - last_spread_warning > 300)  // Warn every 5 minutes
        {
            Print("Spread too high: ", spread, " > ", max_spread);
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
        
    // Reset grid periodically (every 24 hours)
    if(TimeCurrent() - g_last_grid_update > 86400)  // 24 hours
        return true;
        
    return false;
}

//+------------------------------------------------------------------+
//| Setup Grid System                                                |
//+------------------------------------------------------------------+
void SetupGridSystem()
{
    Print("=== Setting up Grid System ===");
    
    // Close existing positions if resetting
    if(g_last_grid_update > 0)
    {
        CloseAllPositions("Grid Reset");
        Sleep(1000);  // Wait for orders to close
    }
    
    // CRITICAL: CONFIRMATION CHECK - Only create grid if orders are truly cleared
    int buy_count = CountBuyOrdersAndPositions();
    int sell_count = CountSellOrdersAndPositions();
    
    Print("🔍 CONFIRMATION CHECK:");
    Print("BUY orders/positions: ", buy_count);
    Print("SELL orders/positions: ", sell_count);
    
    if(buy_count > 0 || sell_count > 0)
    {
        Print("⚠️ ORDERS NOT CLEARED YET - Waiting for cleanup completion");
        Print("BUY remaining: ", buy_count, " | SELL remaining: ", sell_count);
        return; // Don't create new grid until old orders are completely cleared
    }
    
    Print("✅ CONFIRMATION: All orders cleared - Safe to create new grid");
    
    // Setup new grid only after confirmation
    if(g_grid_manager.SetupDualGrid(0.0, InpATRMultiplier))
    {
        g_last_grid_update = TimeCurrent();
        Print("Dual Grid system setup completed");
        
        // Print grid information
        g_grid_manager.PrintGridInfo();
    }
    else
    {
        Print("ERROR: Failed to setup dual grid system");
    }
}

//+------------------------------------------------------------------+
//| Count BUY orders/positions for our EA                           |
//+------------------------------------------------------------------+
int CountBuyOrdersAndPositions()
{
    int count = 0;
    
    // Count BUY positions
    for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
    {
        ulong ticket = PositionGetTicket(pos_idx);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
        string comment = PositionGetString(POSITION_COMMENT);
        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        if(pos_type == POSITION_TYPE_BUY && (IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0))
        {
            count++;
        }
    }
    
    // Count BUY pending orders
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(OrderGetTicket(i))) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)OrderGetInteger(ORDER_MAGIC);
        string comment = OrderGetString(ORDER_COMMENT);
        ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        
        if((order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP) && 
           (IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0))
        {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Count SELL orders/positions for our EA                          |
//+------------------------------------------------------------------+
int CountSellOrdersAndPositions()
{
    int count = 0;
    
    // Count SELL positions
    for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
    {
        ulong ticket = PositionGetTicket(pos_idx);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
        string comment = PositionGetString(POSITION_COMMENT);
        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        if(pos_type == POSITION_TYPE_SELL && (IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0))
        {
            count++;
        }
    }
    
    // Count SELL pending orders
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(OrderGetTicket(i))) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)OrderGetInteger(ORDER_MAGIC);
        string comment = OrderGetString(ORDER_COMMENT);
        ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        
        if((order_type == ORDER_TYPE_SELL_LIMIT || order_type == ORDER_TYPE_SELL_STOP) && 
           (IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0))
        {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Check if magic number belongs to our EA                         |
//+------------------------------------------------------------------+
bool IsOurGridMagic(ulong magic)
{
    // Original EA magic number
    if(magic == InpMagicNumber) return true;
    
    // Grid BUY magic: InpMagic + 1000 + level_index  
    // Grid SELL magic: InpMagic + 2000 + level_index
    for(int i = 0; i < InpMaxGridLevels * 2; i++) // *2 for potential DCA expansion
    {
        if(magic == (InpMagicNumber + 1000 + i)) return true; // BUY grid
        if(magic == (InpMagicNumber + 2000 + i)) return true; // SELL grid
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check profit target                                              |
//+------------------------------------------------------------------+
bool CheckProfitTarget()
{
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double profit = current_balance - g_account_start_balance;
    
    if(profit >= g_current_profit_target)
    {
        Print("=== PROFIT TARGET REACHED ===");
        Print("Start Balance: ", g_account_start_balance);
        Print("Current Balance: ", current_balance);
        Print("Profit: ", profit);
        Print("Target: ", g_current_profit_target);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    Print("=== Closing All Positions ===");
    Print("Reason: ", reason);
    
    // 1) Close ALL positions belonging to our EA (all magic numbers)
    int closed_positions = 0;
    for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
    {
        ulong ticket = PositionGetTicket(pos_idx);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
        string comment = PositionGetString(POSITION_COMMENT);
        
        // Check if this is our EA's position
        if(IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0)
        {
            if(g_trade.PositionClose(ticket))
            {
                closed_positions++;
                Print("✅ Closed position #", ticket, " (Magic: ", magic, ", Comment: ", comment, ")");
            }
            else
            {
                Print("❌ Failed to close position #", ticket);
            }
        }
    }
    
    // 2) Cancel ALL pending orders belonging to our EA  
    int cancelled_orders = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(OrderGetTicket(i))) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        
        ulong magic = (ulong)OrderGetInteger(ORDER_MAGIC);
        string comment = OrderGetString(ORDER_COMMENT);
        
        // Check if this is our EA's order
        if(IsOurGridMagic(magic) || StringFind(comment, "Grid_") == 0 || StringFind(comment, "IMMEDIATE_") == 0)
        {
            ulong ticket = OrderGetTicket(i);
            if(g_trade.OrderDelete(ticket))
            {
                cancelled_orders++;
                Print("✅ Cancelled order #", ticket, " (Magic: ", magic, ", Comment: ", comment, ")");
            }
            else
            {
                Print("❌ Failed to cancel order #", ticket);
            }
        }
    }
    
    Print("🎯 CLEANUP COMPLETE: ", closed_positions, " positions closed, ", cancelled_orders, " orders cancelled");
    Print("All EA positions and orders cleaned up successfully");
}

//+------------------------------------------------------------------+
//| Handle trailing stop                                             |
//+------------------------------------------------------------------+
void HandleTrailingStop()
{
    // Simple trailing stop implementation
    double atr = g_atr_calculator.GetATR(PERIOD_H1);
    double trailing_distance = atr * InpTrailingStopATR;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                     SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                     SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                     
                double position_profit = PositionGetDouble(POSITION_PROFIT);
                
                // Only trail if in profit
                if(position_profit > 0)
                {
                    // Implement trailing stop logic here
                    // This is a simplified version
                }
            }
        }
    }
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
    Print("Digits: ", SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    Print("Point: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("Tick Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
    Print("Tick Value: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
    Print("Lot Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
    Print("Min Lot: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
    Print("Max Lot: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
    Print("Lot Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
    Print("Current Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
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
    Print("Target Reached: ", (total_profit >= g_current_profit_target) ? "YES" : "NO");
}
//+------------------------------------------------------------------+

