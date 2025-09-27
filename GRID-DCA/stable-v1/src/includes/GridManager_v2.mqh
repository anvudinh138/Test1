//+------------------------------------------------------------------+
//|                                              GridManager_v2.mqh |
//|                                    FlexGridDCA Independent Grid |
//|         Grid Manager V2 - Independent Dual Direction System     |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "2.01"

#include <Trade\Trade.mqh>
#include <ATRCalculator.mqh>

//+------------------------------------------------------------------+
//| Enums and Structures                                             |
//+------------------------------------------------------------------+
enum GRID_DIRECTION
{
    GRID_DIRECTION_BUY = 0,
    GRID_DIRECTION_SELL = 1
};

struct SGridLevel
{
    double               price;              // Level price
    double               lot_size;           // Position size
    bool                 is_filled;          // Fill status
    ulong                ticket;             // Order/Position ticket
    datetime             fill_time;          // Fill time
    bool                 is_dca_level;       // DCA expansion level
};

struct SGridDirection
{
    SGridLevel          levels[];            // Grid levels array
    double              base_price;          // Base price for grid
    double              total_profit;        // Current floating P/L
    bool                is_active;           // Direction active status
    int                 dca_expansions;      // Number of DCA expansions
    datetime            last_reset;          // Last reset time
    bool                is_closing;          // Closing state
};

//+------------------------------------------------------------------+
//| Grid Manager V2 Class - Independent Dual Direction              |
//+------------------------------------------------------------------+
class CGridManagerV2
{
private:
    string               m_symbol;
    double               m_fixed_lot_size;
    int                  m_max_grid_levels;
    ulong                m_magic_number;
    CTrade               m_trade;
    
    // Independent Grids
    SGridDirection       m_buy_grid;
    SGridDirection       m_sell_grid;
    
    // Profit Targets
    double               m_profit_target_usd;
    double               m_profit_target_percent;
    bool                 m_use_total_profit_target;
    
    // Risk Management
    double               m_max_account_risk;
    double               m_account_start_balance;
    
    // Market Entry Settings
    bool                 m_enable_market_entry;
    
    // Grid Spacing Settings
    bool                 m_use_fibonacci_spacing;
    
    // ENHANCED: ATR Calculator Integration
    CATRCalculator      *m_atr_calculator;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CGridManagerV2(void)
    {
        m_symbol = _Symbol;
        m_fixed_lot_size = 0.01;
        m_max_grid_levels = 5;
        m_magic_number = 12345;
        m_profit_target_usd = 3.0;
        m_profit_target_percent = 1.0;
        m_use_total_profit_target = true;
        m_max_account_risk = 10.0;
        m_account_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_enable_market_entry = false;
        m_use_fibonacci_spacing = false;
        
        // ENHANCED: Initialize ATR Calculator pointer
        m_atr_calculator = NULL;
        
        // Initialize grids
        InitializeBuyGrid();
        InitializeSellGrid();
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CGridManagerV2(void) {}
    
    //+------------------------------------------------------------------+
    //| Initialize Grid Manager                                          |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, double lot_size, int max_levels, ulong magic)
    {
        m_symbol = symbol;
        m_fixed_lot_size = lot_size;
        m_max_grid_levels = max_levels;
        m_magic_number = magic;
        
        // Setup trade object
        m_trade.SetExpertMagicNumber(m_magic_number);
        m_trade.SetDeviationInPoints(10);
        m_trade.SetTypeFilling(ORDER_FILLING_FOK);
        
        Print("GridManager V2 initialized - Symbol: ", m_symbol, 
              ", Lot Size: ", m_fixed_lot_size, 
              ", Max Levels: ", m_max_grid_levels);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Set Profit Targets                                              |
    //+------------------------------------------------------------------+
    void SetProfitTargets(double target_usd, double target_percent, bool use_total)
    {
        m_profit_target_usd = target_usd;
        m_profit_target_percent = target_percent;
        m_use_total_profit_target = use_total;
        
        Print("Profit Targets Set - USD: $", m_profit_target_usd,
              ", Percent: ", m_profit_target_percent, "%",
              ", Use Total: ", (use_total ? "Yes" : "Per-Direction"));
    }
    
    //+------------------------------------------------------------------+
    //| Set Market Entry Option                                          |
    //+------------------------------------------------------------------+
    void SetMarketEntry(bool enable_market_entry)
    {
        m_enable_market_entry = enable_market_entry;
        
        Print("🚀 Market Entry Mode: ", (m_enable_market_entry ? "ENABLED - Will place market orders at grid setup" : "DISABLED - Limit orders only"));
    }
    
    //+------------------------------------------------------------------+
    //| Set Fibonacci Spacing Option                                     |
    //+------------------------------------------------------------------+
    void SetFibonacciSpacing(bool use_fibonacci)
    {
        m_use_fibonacci_spacing = use_fibonacci;
        
        Print("📐 Grid Spacing Mode: ", (m_use_fibonacci_spacing ? "FIBONACCI - Using Golden Ratio (1.618, 2.618, 4.236, 6.854)" : "EQUAL - Traditional equal spacing"));
    }
    
    //+------------------------------------------------------------------+
    //| Set ATR Calculator (ENHANCED Integration)                       |
    //+------------------------------------------------------------------+
    void SetATRCalculator(CATRCalculator* atr_calc)
    {
        m_atr_calculator = atr_calc;
        Print("✅ ATR Calculator integrated into GridManager");
    }
    
    //+------------------------------------------------------------------+
    //| ENHANCED: Calculate Dynamic Lot Size                            |
    //+------------------------------------------------------------------+
    double CalculateDynamicLotSize()
    {
        // This will be overridden by EA implementation
        // For now, return fixed lot size
        return m_fixed_lot_size;
    }
    
    //+------------------------------------------------------------------+
    //| ENHANCED: Risk Check for Order Placement                        |
    //+------------------------------------------------------------------+
    bool CanPlaceOrder(GRID_DIRECTION direction, double lot_size)
    {
        // Default implementation - always allow
        // This will be overridden by EA implementation
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| EMERGENCY: Force DCA Rescue for Losing Direction               |
    //+------------------------------------------------------------------+
    bool ForceDCARescue(GRID_DIRECTION losing_direction)
    {
        Print("🚨 EMERGENCY DCA RESCUE ACTIVATED for ", (losing_direction == GRID_DIRECTION_SELL ? "SELL" : "BUY"), " direction!");
        
        GRID_DIRECTION rescue_direction = (losing_direction == GRID_DIRECTION_SELL) ? GRID_DIRECTION_BUY : GRID_DIRECTION_SELL;
        
        // Get current price
        double current_price = (rescue_direction == GRID_DIRECTION_BUY) ? 
                              SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                              SymbolInfoDouble(m_symbol, SYMBOL_BID);
        
        // Calculate ATR spacing
        double atr_spacing = 0.001; // Fallback
        if(m_atr_calculator != NULL)
        {
            atr_spacing = m_atr_calculator.CalculateGridSpacing(PERIOD_H1, 1.0);
        }
        else
        {
            atr_spacing = GetATRValue() * 1.0;
        }
        
        // Add rescue orders
        if(rescue_direction == GRID_DIRECTION_BUY)
        {
            // Add BUY STOP orders above current price to rescue SELL grid
            int old_size = ArraySize(m_buy_grid.levels);
            ArrayResize(m_buy_grid.levels, old_size + m_max_grid_levels);
            
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                int new_index = old_size + i;
                double level_price = current_price + atr_spacing * (i + 1); // Above current price
                
                m_buy_grid.levels[new_index].price = NormalizeDouble(level_price, _Digits);
                m_buy_grid.levels[new_index].lot_size = CalculateDynamicLotSize();
                m_buy_grid.levels[new_index].is_filled = false;
                m_buy_grid.levels[new_index].ticket = 0;
                m_buy_grid.levels[new_index].fill_time = 0;
                m_buy_grid.levels[new_index].is_dca_level = true; // Mark as DCA rescue
            }
            
            m_sell_grid.dca_expansions++;
            Print("✅ Added ", m_max_grid_levels, " EMERGENCY BUY STOP rescue orders above ", DoubleToString(current_price, _Digits));
        }
        else
        {
            // Add SELL STOP orders below current price to rescue BUY grid
            int old_size = ArraySize(m_sell_grid.levels);
            ArrayResize(m_sell_grid.levels, old_size + m_max_grid_levels);
            
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                int new_index = old_size + i;
                double level_price = current_price - atr_spacing * (i + 1); // Below current price
                
                m_sell_grid.levels[new_index].price = NormalizeDouble(level_price, _Digits);
                m_sell_grid.levels[new_index].lot_size = CalculateDynamicLotSize();
                m_sell_grid.levels[new_index].is_filled = false;
                m_sell_grid.levels[new_index].ticket = 0;
                m_sell_grid.levels[new_index].fill_time = 0;
                m_sell_grid.levels[new_index].is_dca_level = true; // Mark as DCA rescue
            }
            
            m_buy_grid.dca_expansions++;
            Print("✅ Added ", m_max_grid_levels, " EMERGENCY SELL STOP rescue orders below ", DoubleToString(current_price, _Digits));
        }
        
        // Immediately place the rescue orders
        PlaceDirectionOrders(rescue_direction);
        
        Print("🔥 EMERGENCY DCA RESCUE COMPLETED - Check for new ", (rescue_direction == GRID_DIRECTION_BUY ? "BUY STOP" : "SELL STOP"), " orders!");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get Direction DCA Expansions Count                              |
    //+------------------------------------------------------------------+
    int GetDirectionDCAExpansions(GRID_DIRECTION direction)
    {
        if(direction == GRID_DIRECTION_BUY)
            return m_buy_grid.dca_expansions;
        else
            return m_sell_grid.dca_expansions;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Direction Total Profit                                |
    //+------------------------------------------------------------------+
    double CalculateDirectionTotalProfit(GRID_DIRECTION direction)
    {
        double total_profit = 0.0;
        ENUM_POSITION_TYPE pos_type = (direction == GRID_DIRECTION_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        
        // Scan all positions for this direction
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionGetSymbol(i) == m_symbol)
            {
                if(PositionGetInteger(POSITION_MAGIC) == m_magic_number && 
                   PositionGetInteger(POSITION_TYPE) == pos_type)
                {
                    total_profit += PositionGetDouble(POSITION_PROFIT);
                    total_profit += PositionGetDouble(POSITION_SWAP);
                }
            }
        }
        
        return total_profit;
    }
    
    //+------------------------------------------------------------------+
    //| Setup Dual Grid System                                          |
    //+------------------------------------------------------------------+
    bool SetupDualGrid(double base_price = 0.0, double atr_multiplier = 1.0)
    {
        if(base_price <= 0.0)
            base_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        
        // Calculate ATR spacing using integrated ATRCalculator
        double spacing = 0.001; // Fallback
        if(m_atr_calculator != NULL)
        {
            spacing = m_atr_calculator.CalculateGridSpacing(PERIOD_H1, atr_multiplier);
        }
        else
        {
            // Fallback: Use simplified ATR calculation
            double atr_h1 = GetATRValue();
            spacing = atr_h1 * atr_multiplier;
        }
        
        Print("=== Setting Up Dual Independent Grids ===");
        Print("Base Price: ", DoubleToString(base_price, _Digits));
        Print("ATR Spacing: ", DoubleToString(spacing, _Digits));
        
        // Setup BUY grid (below current price)
        if(!SetupDirectionGrid(GRID_DIRECTION_BUY, base_price, spacing))
        {
            Print("Failed to setup BUY grid");
            return false;
        }
        
        // Setup SELL grid (above current price)  
        if(!SetupDirectionGrid(GRID_DIRECTION_SELL, base_price, spacing))
        {
            Print("Failed to setup SELL grid");
            return false;
        }
        
        Print("✅ Dual Grid Setup Completed Successfully");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Setup Individual Direction Grid                                 |
    //+------------------------------------------------------------------+
    bool SetupDirectionGrid(GRID_DIRECTION direction, double base_price, double spacing)
    {
        string dir_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
        
        if(direction == GRID_DIRECTION_BUY)
        {
            // Clear existing levels
            ArrayFree(m_buy_grid.levels);
            ArrayResize(m_buy_grid.levels, m_max_grid_levels);
        
            // Setup BUY grid levels with Fibonacci or Equal spacing
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                double level_spacing;
                if(m_use_fibonacci_spacing)
                {
                    // 🌟 FIBONACCI SPACING: Golden Ratio progression
                    double fib_multipliers[] = {1.0, 1.618, 2.618, 4.236, 6.854, 11.090, 17.944, 29.034};
                    int fib_index = (i < ArraySize(fib_multipliers)) ? i : (ArraySize(fib_multipliers) - 1);
                    level_spacing = spacing * fib_multipliers[fib_index];
                }
                else
                {
                    // Traditional equal spacing
                    level_spacing = spacing * (i + 1);
                }
                
                double level_price = base_price - level_spacing; // Below base price
                
                m_buy_grid.levels[i].price = NormalizeDouble(level_price, _Digits);
                m_buy_grid.levels[i].lot_size = CalculateDynamicLotSize(); // ENHANCED: Dynamic sizing
                m_buy_grid.levels[i].is_filled = false;
                m_buy_grid.levels[i].ticket = 0;
                m_buy_grid.levels[i].fill_time = 0;
                m_buy_grid.levels[i].is_dca_level = false;
            }
            
            // Set BUY grid properties
            m_buy_grid.base_price = base_price;
            m_buy_grid.is_active = true;
            m_buy_grid.total_profit = 0.0;
            m_buy_grid.dca_expansions = 0;
            m_buy_grid.last_reset = TimeCurrent();
            m_buy_grid.is_closing = false;
        }
        else // SELL direction
        {
            // Clear existing levels
            ArrayFree(m_sell_grid.levels);
            ArrayResize(m_sell_grid.levels, m_max_grid_levels);
            
            // Setup SELL grid levels with Fibonacci or Equal spacing
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                double level_spacing;
                if(m_use_fibonacci_spacing)
                {
                    // 🌟 FIBONACCI SPACING: Golden Ratio progression
                    double fib_multipliers[] = {1.0, 1.618, 2.618, 4.236, 6.854, 11.090, 17.944, 29.034};
                    int fib_index = (i < ArraySize(fib_multipliers)) ? i : (ArraySize(fib_multipliers) - 1);
                    level_spacing = spacing * fib_multipliers[fib_index];
                }
                else
                {
                    // Traditional equal spacing
                    level_spacing = spacing * (i + 1);
                }
                
                double level_price = base_price + level_spacing; // Above base price
                
                m_sell_grid.levels[i].price = NormalizeDouble(level_price, _Digits);
                m_sell_grid.levels[i].lot_size = CalculateDynamicLotSize(); // ENHANCED: Dynamic sizing
                m_sell_grid.levels[i].is_filled = false;
                m_sell_grid.levels[i].ticket = 0;
                m_sell_grid.levels[i].fill_time = 0;
                m_sell_grid.levels[i].is_dca_level = false;
            }
            
            // Set SELL grid properties
            m_sell_grid.base_price = base_price;
            m_sell_grid.is_active = true;
            m_sell_grid.total_profit = 0.0;
            m_sell_grid.dca_expansions = 0;
            m_sell_grid.last_reset = TimeCurrent();
            m_sell_grid.is_closing = false;
        }
        
        if(direction == GRID_DIRECTION_BUY)
        {
            Print("✅ ", dir_name, " Grid Setup: ", m_max_grid_levels, " levels from ", 
                  DoubleToString(m_buy_grid.levels[0].price, _Digits), " to ", 
                  DoubleToString(m_buy_grid.levels[m_max_grid_levels-1].price, _Digits));
        }
        else
        {
            Print("✅ ", dir_name, " Grid Setup: ", m_max_grid_levels, " levels from ", 
                  DoubleToString(m_sell_grid.levels[0].price, _Digits), " to ", 
                  DoubleToString(m_sell_grid.levels[m_max_grid_levels-1].price, _Digits));
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Close Direction Positions                                       |
    //+------------------------------------------------------------------+
    bool CloseDirectionPositions(GRID_DIRECTION direction)
    {
        string dir_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
        ENUM_POSITION_TYPE pos_type = (direction == GRID_DIRECTION_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        ENUM_ORDER_TYPE order_type = (direction == GRID_DIRECTION_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        
        if(direction == GRID_DIRECTION_BUY)
            m_buy_grid.is_closing = true;
        else
            m_sell_grid.is_closing = true;
        int closed_positions = 0;
        int cancelled_orders = 0;
        
        Print("🔄 Closing all ", dir_name, " positions and orders...");
        
        // Close all positions of this direction
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetSymbol(i) == m_symbol && 
               PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
               PositionGetInteger(POSITION_TYPE) == pos_type)
            {
                ulong ticket = PositionGetTicket(i);
                if(m_trade.PositionClose(ticket))
                {
                    closed_positions++;
                    Print("✅ Closed ", dir_name, " position ticket: ", IntegerToString(ticket));
                }
                else
                {
                    Print("❌ Failed to close ", dir_name, " position ticket: ", IntegerToString(ticket), " Error: ", IntegerToString(GetLastError()));
                }
            }
        }
        
        // 🚨 CRITICAL FIX: Cancel ALL pending orders of this direction using proper MQL5 method
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);  // Get ticket directly by position
            if(ticket > 0 && OrderSelect(ticket))  // Select by ticket, not position
            {
                if(OrderGetString(ORDER_SYMBOL) == m_symbol && 
                   OrderGetInteger(ORDER_MAGIC) == m_magic_number)
                {
                    ENUM_ORDER_TYPE order_type_current = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                    bool is_target_direction = false;
                    
                    // Check if order belongs to target direction
                    if(direction == GRID_DIRECTION_BUY)
                    {
                        is_target_direction = (order_type_current == ORDER_TYPE_BUY_LIMIT || 
                                             order_type_current == ORDER_TYPE_BUY_STOP || 
                                             order_type_current == ORDER_TYPE_BUY);
                    }
                    else // SELL direction  
                    {
                        is_target_direction = (order_type_current == ORDER_TYPE_SELL_LIMIT || 
                                             order_type_current == ORDER_TYPE_SELL_STOP || 
                                             order_type_current == ORDER_TYPE_SELL);
                    }
                    
                    if(is_target_direction)
                    {
                        if(m_trade.OrderDelete(ticket))
                        {
                            cancelled_orders++;
                            Print("✅ Cancelled ", dir_name, " order ticket: ", IntegerToString(ticket));
                        }
                        else
                        {
                            Print("❌ Failed to cancel ", dir_name, " order ticket: ", IntegerToString(ticket), " Error: ", IntegerToString(GetLastError()));
                        }
                    }
                }
            }
        }
        
        Print("📊 ", dir_name, " Cleanup Summary: ", IntegerToString(closed_positions), " positions closed, ", IntegerToString(cancelled_orders), " orders cancelled");
        
        // Reset grid levels and flags
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                m_buy_grid.levels[i].is_filled = false;
                m_buy_grid.levels[i].ticket = 0;
                m_buy_grid.levels[i].fill_time = 0;
            }
            m_buy_grid.is_closing = false;
        }
        else
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                m_sell_grid.levels[i].is_filled = false;
                m_sell_grid.levels[i].ticket = 0;
                m_sell_grid.levels[i].fill_time = 0;
            }
            m_sell_grid.is_closing = false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Close All Grid Positions (Both Directions)                     |
    //+------------------------------------------------------------------+
    bool CloseAllGridPositions()
    {
        Print("🔄 Closing ALL grid positions and orders...");
        
        bool buy_result = CloseDirectionPositions(GRID_DIRECTION_BUY);
        bool sell_result = CloseDirectionPositions(GRID_DIRECTION_SELL);
        
        return (buy_result && sell_result);
    }
    
    //+------------------------------------------------------------------+
    //| Place Grid Orders                                                |
    //+------------------------------------------------------------------+
    bool PlaceGridOrders()
    {
        bool buy_result = PlaceDirectionOrders(GRID_DIRECTION_BUY);
        bool sell_result = PlaceDirectionOrders(GRID_DIRECTION_SELL);
        
        return (buy_result && sell_result);
    }
    
    //+------------------------------------------------------------------+
    //| Place Orders for One Direction                                  |
    //+------------------------------------------------------------------+
    bool PlaceDirectionOrders(GRID_DIRECTION direction)
    {
        if(direction == GRID_DIRECTION_BUY)
        {
            if(!m_buy_grid.is_active || m_buy_grid.is_closing)
                return false;
        }
        else
        {
            if(!m_sell_grid.is_active || m_sell_grid.is_closing)
                return false;
        }
        
        string dir_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
        // Default order types for normal grid levels
        ENUM_ORDER_TYPE order_type = (direction == GRID_DIRECTION_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        
        double current_ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double min_distance = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        
        int orders_placed = 0;
        
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].is_filled || m_buy_grid.levels[i].ticket > 0)
                    continue; // Skip filled or pending levels
                
                double price = m_buy_grid.levels[i].price;
                string comment = StringFormat("Grid_%s_%d", dir_name, i);
                
                // Check if order already exists
                if(PendingOrderExists(comment))
                    continue;
                
                // ENHANCED: Check risk limits before placing order  
                if(!CanPlaceOrder(direction, m_buy_grid.levels[i].lot_size))
                {
                    LogMessage(1, "RISK", "BUY order blocked by exposure limits");
                    continue;
                }
                
                // 🎯 SMART ORDER TYPE: DCA levels use STOP orders for momentum catching
                ENUM_ORDER_TYPE actual_order_type = order_type;
                if(m_buy_grid.levels[i].is_dca_level)
                {
                    actual_order_type = ORDER_TYPE_BUY_STOP;
                    // BUY STOP orders must be above Ask
                    if(price <= current_ask + min_distance)
                    {
                        static datetime last_warning = 0;
                        if(TimeCurrent() - last_warning > 60) // Warn every minute
                        {
                            Print("⚠️ Skipping BUY STOP level ", IntegerToString(i), ": Price too close to market");
                            last_warning = TimeCurrent();
                        }
                        continue;
                    }
                }
                else
                {
                    // BUY LIMIT orders must be below Ask
                    if(price >= current_ask - min_distance)
                    {
                        static datetime last_warning = 0;
                        if(TimeCurrent() - last_warning > 60) // Warn every minute
                        {
                            Print("⚠️ Skipping BUY LIMIT level ", IntegerToString(i), ": Price too close to market");
                            last_warning = TimeCurrent();
                        }
                        continue;
                    }
                }
                
                // 🚀 MARKET ENTRY LOGIC: Place market order for level 0 (closest to price) if enabled
                bool use_market_order = (m_enable_market_entry && i == 0);
                
                if(use_market_order)
                {
                    // Place market BUY order
                    if(m_trade.Buy(m_buy_grid.levels[i].lot_size, m_symbol, 0, 0, 0, comment))
                    {
                        m_buy_grid.levels[i].ticket = m_trade.ResultOrder();
                        m_buy_grid.levels[i].is_filled = true;
                        m_buy_grid.levels[i].fill_time = TimeCurrent();
                        orders_placed++;
                        Print("🚀 Placed BUY MARKET order | Ticket: ", IntegerToString(m_buy_grid.levels[i].ticket));
                    }
                    else
                    {
                        Print("❌ Failed to place BUY MARKET order | Error: ", IntegerToString(GetLastError()));
                    }
                }
                else
                {
                    // Place BUY order using proper CTrade API methods
                    bool order_result = false;
                    string order_type_name = "";
                    
                    if(actual_order_type == ORDER_TYPE_BUY_STOP)
                    {
                        order_type_name = "BUY STOP";
                        order_result = m_trade.BuyStop(m_buy_grid.levels[i].lot_size, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    }
                    else // ORDER_TYPE_BUY_LIMIT
                    {
                        order_type_name = "BUY LIMIT";
                        order_result = m_trade.BuyLimit(m_buy_grid.levels[i].lot_size, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    }
                    
                    if(order_result)
                    {
                        m_buy_grid.levels[i].ticket = m_trade.ResultOrder();
                        orders_placed++;
                        Print("✅ Placed ", order_type_name, " order at ", DoubleToString(price, _Digits), " | Ticket: ", IntegerToString(m_buy_grid.levels[i].ticket));
                    }
                    else
                    {
                        Print("❌ Failed to place ", order_type_name, " order at ", DoubleToString(price, _Digits), " | Error: ", IntegerToString(GetLastError()));
                    }
                }
            }
        }
        else // SELL direction
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].is_filled || m_sell_grid.levels[i].ticket > 0)
                    continue; // Skip filled or pending levels
                
                double price = m_sell_grid.levels[i].price;
                string comment = StringFormat("Grid_%s_%d", dir_name, i);
                
                // Check if order already exists
                if(PendingOrderExists(comment))
                    continue;
                
                // ENHANCED: Check risk limits before placing order  
                if(!CanPlaceOrder(direction, m_sell_grid.levels[i].lot_size))
                {
                    LogMessage(1, "RISK", "SELL order blocked by exposure limits");
                    continue;
                }
                
                // 🎯 SMART ORDER TYPE: DCA levels use STOP orders for momentum catching
                ENUM_ORDER_TYPE actual_order_type = order_type;
                if(m_sell_grid.levels[i].is_dca_level)
                {
                    actual_order_type = ORDER_TYPE_SELL_STOP;
                    // SELL STOP orders must be below Bid
                    if(price >= current_bid - min_distance)
                    {
                        static datetime last_warning = 0;
                        if(TimeCurrent() - last_warning > 60) // Warn every minute
                        {
                            Print("⚠️ Skipping SELL STOP level ", IntegerToString(i), ": Price too close to market");
                            last_warning = TimeCurrent();
                        }
                        continue;
                    }
                }
                else
                {
                    // SELL LIMIT orders must be above Bid
                    if(price <= current_bid + min_distance)
                    {
                        static datetime last_warning = 0;
                        if(TimeCurrent() - last_warning > 60) // Warn every minute
                        {
                            Print("⚠️ Skipping SELL LIMIT level ", IntegerToString(i), ": Price too close to market");
                            last_warning = TimeCurrent();
                        }
                        continue;
                    }
                }
                
                // 🚀 MARKET ENTRY LOGIC: Place market order for level 0 (closest to price) if enabled
                bool use_market_order = (m_enable_market_entry && i == 0);
                
                if(use_market_order)
                {
                    // Place market SELL order
                    if(m_trade.Sell(m_sell_grid.levels[i].lot_size, m_symbol, 0, 0, 0, comment))
                    {
                        m_sell_grid.levels[i].ticket = m_trade.ResultOrder();
                        m_sell_grid.levels[i].is_filled = true;
                        m_sell_grid.levels[i].fill_time = TimeCurrent();
                        orders_placed++;
                        Print("🚀 Placed SELL MARKET order | Ticket: ", IntegerToString(m_sell_grid.levels[i].ticket));
                    }
                    else
                    {
                        Print("❌ Failed to place SELL MARKET order | Error: ", IntegerToString(GetLastError()));
                    }
                }
                else
                {
                    // Place SELL order using proper CTrade API methods
                    bool order_result = false;
                    string order_type_name = "";
                    
                    if(actual_order_type == ORDER_TYPE_SELL_STOP)
                    {
                        order_type_name = "SELL STOP";
                        order_result = m_trade.SellStop(m_sell_grid.levels[i].lot_size, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    }
                    else // ORDER_TYPE_SELL_LIMIT
                    {
                        order_type_name = "SELL LIMIT";
                        order_result = m_trade.SellLimit(m_sell_grid.levels[i].lot_size, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    }
                    
                    if(order_result)
                    {
                        m_sell_grid.levels[i].ticket = m_trade.ResultOrder();
                        orders_placed++;
                        Print("✅ Placed ", order_type_name, " order at ", DoubleToString(price, _Digits), " | Ticket: ", IntegerToString(m_sell_grid.levels[i].ticket));
                    }
                    else
                    {
                        Print("❌ Failed to place ", order_type_name, " order at ", DoubleToString(price, _Digits), " | Error: ", IntegerToString(GetLastError()));
                    }
                }
            }
        }
        
        if(orders_placed > 0)
            Print("📋 Placed ", IntegerToString(orders_placed), " new ", dir_name, " orders");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Update Grid Status                                               |
    //+------------------------------------------------------------------+
    void UpdateGridStatus()
    {
        // ENHANCED: Cancel far-away orders first
        // CancelFarAwayOrders();
        
        UpdateDirectionStatus(GRID_DIRECTION_BUY);
        UpdateDirectionStatus(GRID_DIRECTION_SELL);
    }
    
    //+------------------------------------------------------------------+
    //| Cancel Orders That Are Too Far From Current Price              |
    //+------------------------------------------------------------------+
    void CancelFarAwayOrders()
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double atr_value = 0.001; // Default fallback
        
        if(m_atr_calculator != NULL)
        {
            atr_value = m_atr_calculator.CalculateGridSpacing(PERIOD_H1, 1.0);
        }
        
        double cancel_distance = atr_value * 10.0; // Cancel orders 10x ATR away
        
        // Check all pending orders
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket))
            {
                string comment = OrderGetString(ORDER_COMMENT);
                if(StringFind(comment, "Grid_") >= 0) // Only our grid orders
                {
                    double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
                    double distance = MathAbs(current_price - order_price);
                    
                    if(distance > cancel_distance)
                    {
                        if(m_trade.OrderDelete(ticket))
                        {
                            Print("🗑️ CLEANUP: Cancelled far-away order #", ticket, " at ", DoubleToString(order_price, _Digits), " (Distance: ", DoubleToString(distance/_Point, 0), " points)");
                        }
                    }
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Update Direction Status                                          |
    //+------------------------------------------------------------------+
    void UpdateDirectionStatus(GRID_DIRECTION direction)
    {
        if(direction == GRID_DIRECTION_BUY && !m_buy_grid.is_active)
            return;
        if(direction == GRID_DIRECTION_SELL && !m_sell_grid.is_active)
            return;
        
        ENUM_POSITION_TYPE pos_type = (direction == GRID_DIRECTION_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        
        // Check for filled orders that became positions
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].ticket > 0 && !m_buy_grid.levels[i].is_filled)
                {
                    // Check if order became a position
                    for(int pos = 0; pos < PositionsTotal(); pos++)
                    {
                        if(PositionGetSymbol(pos) == m_symbol &&
                           PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
                           PositionGetInteger(POSITION_TYPE) == pos_type)
                        {
                            double pos_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                            double level_price = m_buy_grid.levels[i].price;
                            
                            if(MathAbs(pos_open_price - level_price) < SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10)
                            {
                                m_buy_grid.levels[i].is_filled = true;
                                m_buy_grid.levels[i].fill_time = TimeCurrent();
                                m_buy_grid.levels[i].ticket = PositionGetTicket(pos);
                                
                                Print("🎯 BUY Grid level filled: Level ", IntegerToString(i), " at ", DoubleToString(pos_open_price, _Digits));
                                break;
                            }
                        }
                    }
                }
            }
            m_buy_grid.total_profit = CalculateDirectionTotalProfit(direction);
        }
        else // SELL direction
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].ticket > 0 && !m_sell_grid.levels[i].is_filled)
                {
                    // Check if order became a position
                    for(int pos = 0; pos < PositionsTotal(); pos++)
                    {
                        if(PositionGetSymbol(pos) == m_symbol &&
                           PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
                           PositionGetInteger(POSITION_TYPE) == pos_type)
                        {
                            double pos_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                            double level_price = m_sell_grid.levels[i].price;
                            
                            if(MathAbs(pos_open_price - level_price) < SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10)
                            {
                                m_sell_grid.levels[i].is_filled = true;
                                m_sell_grid.levels[i].fill_time = TimeCurrent();
                                m_sell_grid.levels[i].ticket = PositionGetTicket(pos);
                                
                                Print("🎯 SELL Grid level filled: Level ", IntegerToString(i), " at ", DoubleToString(pos_open_price, _Digits));
                                break;
                            }
                        }
                    }
                }
            }
            m_sell_grid.total_profit = CalculateDirectionTotalProfit(direction);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Smart DCA Expansion: Add BUY when all SELL filled               |
    //+------------------------------------------------------------------+
    bool CheckSmartDCAExpansion()
    {
        // Check if all SELL levels are filled (trending up scenario)
        bool all_sell_filled = true;
        int sell_filled_count = 0;
        
        for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
        {
            if(m_sell_grid.levels[i].is_filled)
                sell_filled_count++;
            else
                all_sell_filled = false;
        }
        
        // Check if all BUY levels are filled (trending down scenario) 
        bool all_buy_filled = true;
        int buy_filled_count = 0;
        
        for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
        {
            if(m_buy_grid.levels[i].is_filled)
                buy_filled_count++;
            else
                all_buy_filled = false;
        }
        
        bool dca_triggered = false;
        
        // 🎯 ENHANCED DCA LOGIC: Two triggers - Risk Loss OR Grid Fill
        int dca_trigger_count = MathMax(3, (int)(m_max_grid_levels * 0.6)); // 60% grid fill trigger
        
        // Calculate current losses for risk-based trigger
        double buy_loss = CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_loss = CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        double max_risk_loss = 50.0; // 50% of typical max loss for early intervention
        
        bool sell_risk_trigger = (sell_loss <= -max_risk_loss);
        bool buy_risk_trigger = (buy_loss <= -max_risk_loss);
        bool sell_grid_trigger = (sell_filled_count >= dca_trigger_count);
        bool buy_grid_trigger = (buy_filled_count >= dca_trigger_count);
        
        // 🔥 DEBUG: Enhanced DCA status with grid size info
        static datetime last_dca_debug = 0;
        if(TimeCurrent() - last_dca_debug > 30) // Reduced frequency
        {
            Print("🔍 DCA DEBUG - SELL: filled=", sell_filled_count, "/", m_max_grid_levels, " array_size=", ArraySize(m_sell_grid.levels), " loss=$", DoubleToString(sell_loss, 2), " risk_trigger=", (sell_risk_trigger ? "YES" : "NO"), " grid_trigger=", (sell_grid_trigger ? "YES" : "NO"), " expansions=", m_sell_grid.dca_expansions);
            Print("🔍 DCA DEBUG - BUY: filled=", buy_filled_count, "/", m_max_grid_levels, " array_size=", ArraySize(m_buy_grid.levels), " loss=$", DoubleToString(buy_loss, 2), " risk_trigger=", (buy_risk_trigger ? "YES" : "NO"), " grid_trigger=", (buy_grid_trigger ? "YES" : "NO"), " expansions=", m_buy_grid.dca_expansions);
            last_dca_debug = TimeCurrent();
        }
        
        if((sell_risk_trigger || sell_grid_trigger) && m_sell_grid.dca_expansions == 0)
        {
            Print("🚀 SMART DCA EXPANSION: ", IntegerToString(sell_filled_count), "/", IntegerToString(m_max_grid_levels), " SELL levels filled (trigger: ", IntegerToString(dca_trigger_count), ") - Adding ", IntegerToString(m_max_grid_levels), " BUY orders to counter uptrend");
            
            // 🚀 SMART DCA: BUY STOP orders ABOVE current price to catch momentum!
            // Logic: If SELL grid filled → uptrend → Need BUY STOP to catch further momentum
            double current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK); // Use ASK for BUY STOP
            
            // Use ATR Calculator for DCA spacing if available
            double atr_spacing = 0.001; // Fallback
            if(m_atr_calculator != NULL)
            {
                atr_spacing = m_atr_calculator.CalculateGridSpacing(PERIOD_H1, 1.0);
            }
            else
            {
                atr_spacing = GetATRValue() * 1.0; // Fallback to old method
            }
            
            // Find highest SELL level price as reference
            double highest_sell_price = 0.0;
            for(int j = 0; j < ArraySize(m_sell_grid.levels); j++)
            {
                if(m_sell_grid.levels[j].is_filled && m_sell_grid.levels[j].price > highest_sell_price)
                    highest_sell_price = m_sell_grid.levels[j].price;
            }
            
            // Start BUY STOP levels above the highest filled SELL level
            double start_price = MathMax(current_price, highest_sell_price) + atr_spacing * 0.5; // Small buffer above
            
            // Expand BUY grid with new levels
            int old_size = ArraySize(m_buy_grid.levels);
            ArrayResize(m_buy_grid.levels, old_size + m_max_grid_levels);
            
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                int new_index = old_size + i;
                double level_spacing;
                if(m_use_fibonacci_spacing)
                {
                    // 🌟 FIBONACCI SPACING: Golden Ratio progression
                    double fib_multipliers[] = {1.0, 1.618, 2.618, 4.236, 6.854, 11.090, 17.944, 29.034};
                    int fib_index = (i < ArraySize(fib_multipliers)) ? i : (ArraySize(fib_multipliers) - 1);
                    level_spacing = atr_spacing * fib_multipliers[fib_index];
                }
                else
                {
                    level_spacing = atr_spacing * (i + 1);
                }
                
                m_buy_grid.levels[new_index].price = NormalizeDouble(start_price + level_spacing, _Digits); // ABOVE price!
                m_buy_grid.levels[new_index].lot_size = m_fixed_lot_size;
                m_buy_grid.levels[new_index].is_filled = false;
                m_buy_grid.levels[new_index].ticket = 0;
                m_buy_grid.levels[new_index].fill_time = 0;
                m_buy_grid.levels[new_index].is_dca_level = true;
            }
            
            m_sell_grid.dca_expansions++;
            dca_triggered = true;
            Print("✅ Added ", IntegerToString(m_max_grid_levels), " DCA BUY levels starting from ", DoubleToString(m_buy_grid.levels[old_size].price, _Digits));
            
            // Place the new DCA BUY orders immediately
            PlaceDirectionOrders(GRID_DIRECTION_BUY);
        }
        else if((buy_risk_trigger || buy_grid_trigger) && m_buy_grid.dca_expansions == 0)
        {
            Print("🚀 SMART DCA EXPANSION: ", IntegerToString(buy_filled_count), "/", IntegerToString(m_max_grid_levels), " BUY levels filled (trigger: ", IntegerToString(dca_trigger_count), ") - Adding ", IntegerToString(m_max_grid_levels), " SELL orders to counter downtrend");
            
            // 🚀 SMART DCA: SELL STOP orders BELOW current price to catch momentum!
            // Logic: If BUY grid filled → downtrend → Need SELL STOP to catch further momentum
            double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID); // Use BID for SELL STOP
            
            // Use ATR Calculator for DCA spacing if available
            double atr_spacing = 0.001; // Fallback
            if(m_atr_calculator != NULL)
            {
                atr_spacing = m_atr_calculator.CalculateGridSpacing(PERIOD_H1, 1.0);
            }
            else
            {
                atr_spacing = GetATRValue() * 1.0; // Fallback to old method
            }
            
            // Find lowest BUY level price as reference
            double lowest_buy_price = 999999.0;
            for(int j = 0; j < ArraySize(m_buy_grid.levels); j++)
            {
                if(m_buy_grid.levels[j].is_filled && m_buy_grid.levels[j].price < lowest_buy_price)
                    lowest_buy_price = m_buy_grid.levels[j].price;
            }
            
            // Start SELL STOP levels below the lowest filled BUY level
            double start_price = MathMin(current_price, lowest_buy_price) - atr_spacing * 0.5; // Small buffer below
            
            // Expand SELL grid with new levels
            int old_size = ArraySize(m_sell_grid.levels);
            ArrayResize(m_sell_grid.levels, old_size + m_max_grid_levels);
            
            for(int i = 0; i < m_max_grid_levels; i++)
            {
                int new_index = old_size + i;
                double level_spacing;
                if(m_use_fibonacci_spacing)
                {
                    // 🌟 FIBONACCI SPACING: Golden Ratio progression
                    double fib_multipliers[] = {1.0, 1.618, 2.618, 4.236, 6.854, 11.090, 17.944, 29.034};
                    int fib_index = (i < ArraySize(fib_multipliers)) ? i : (ArraySize(fib_multipliers) - 1);
                    level_spacing = atr_spacing * fib_multipliers[fib_index];
                }
                else
                {
                    level_spacing = atr_spacing * (i + 1);
                }
                
                m_sell_grid.levels[new_index].price = NormalizeDouble(start_price - level_spacing, _Digits); // BELOW price!
                m_sell_grid.levels[new_index].lot_size = m_fixed_lot_size;
                m_sell_grid.levels[new_index].is_filled = false;
                m_sell_grid.levels[new_index].ticket = 0;
                m_sell_grid.levels[new_index].fill_time = 0;
                m_sell_grid.levels[new_index].is_dca_level = true;
            }
            
            m_buy_grid.dca_expansions++;
            dca_triggered = true;
            Print("✅ Added ", IntegerToString(m_max_grid_levels), " DCA SELL levels starting from ", DoubleToString(m_sell_grid.levels[old_size].price, _Digits));
            
            // Place the new DCA SELL orders immediately
            PlaceDirectionOrders(GRID_DIRECTION_SELL);
        }
        
        return dca_triggered;
    }
    
    //+------------------------------------------------------------------+
    //| Print Grid Information                                           |
    //+------------------------------------------------------------------+
    void PrintGridInfo()
    {
        Print("=== GRID MANAGER V2 STATUS ===");
        
        PrintBuyGridInfo();
        PrintSellGridInfo();
        
        double buy_profit = CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_profit = CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        double total_profit = buy_profit + sell_profit;
        
        Print("💰 PROFITS: BUY: $", DoubleToString(buy_profit, 2), 
              " | SELL: $", DoubleToString(sell_profit, 2),
              " | TOTAL: $", DoubleToString(total_profit, 2));
        
        Print("🎯 TARGETS: USD: $", DoubleToString(m_profit_target_usd, 2), 
              " | Percent: ", DoubleToString(m_profit_target_percent, 2), "%");
    }

private:
    //+------------------------------------------------------------------+
    //| Initialize BUY Grid                                              |
    //+------------------------------------------------------------------+
    void InitializeBuyGrid()
    {
        ArrayFree(m_buy_grid.levels);
        m_buy_grid.base_price = 0.0;
        m_buy_grid.total_profit = 0.0;
        m_buy_grid.is_active = false;
        m_buy_grid.dca_expansions = 0;
        m_buy_grid.last_reset = 0;
        m_buy_grid.is_closing = false;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize SELL Grid                                             |
    //+------------------------------------------------------------------+
    void InitializeSellGrid()
    {
        ArrayFree(m_sell_grid.levels);
        m_sell_grid.base_price = 0.0;
        m_sell_grid.total_profit = 0.0;
        m_sell_grid.is_active = false;
        m_sell_grid.dca_expansions = 0;
        m_sell_grid.last_reset = 0;
        m_sell_grid.is_closing = false;
    }
    
    //+------------------------------------------------------------------+
    //| Print BUY Grid Info                                              |
    //+------------------------------------------------------------------+
    void PrintBuyGridInfo()
    {
        int filled_levels = 0;
        for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
        {
            if(m_buy_grid.levels[i].is_filled)
                filled_levels++;
        }
        
        Print("--- BUY GRID ---");
        Print("Active: ", (m_buy_grid.is_active ? "YES" : "NO"),
              " | Base: ", DoubleToString(m_buy_grid.base_price, _Digits),
              " | Levels: ", IntegerToString(ArraySize(m_buy_grid.levels)),
              " | Filled: ", IntegerToString(filled_levels),
              " | DCA Exp: ", IntegerToString(m_buy_grid.dca_expansions),
              " | Closing: ", (m_buy_grid.is_closing ? "YES" : "NO"));
    }
    
    //+------------------------------------------------------------------+
    //| Print SELL Grid Info                                             |
    //+------------------------------------------------------------------+
    void PrintSellGridInfo()
    {
        int filled_levels = 0;
        for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
        {
            if(m_sell_grid.levels[i].is_filled)
                filled_levels++;
        }
        
        Print("--- SELL GRID ---");
        Print("Active: ", (m_sell_grid.is_active ? "YES" : "NO"),
              " | Base: ", DoubleToString(m_sell_grid.base_price, _Digits),
              " | Levels: ", IntegerToString(ArraySize(m_sell_grid.levels)),
              " | Filled: ", IntegerToString(filled_levels),
              " | DCA Exp: ", IntegerToString(m_sell_grid.dca_expansions),
              " | Closing: ", (m_sell_grid.is_closing ? "YES" : "NO"));
    }
    
    //+------------------------------------------------------------------+
    //| Check if Pending Order Exists (FIXED: Proper OrderSelect)      |
    //+------------------------------------------------------------------+
    bool PendingOrderExists(string comment)
    {
        for(int i = 0; i < OrdersTotal(); i++)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0) continue; // Invalid ticket
            
            // Select order before accessing properties
            if(OrderSelect(ticket))
            {
                if(OrderGetString(ORDER_COMMENT) == comment &&
                   OrderGetString(ORDER_SYMBOL) == m_symbol &&
                   OrderGetInteger(ORDER_MAGIC) == m_magic_number)
                {
                    return true;
                }
            }
        }
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Get ATR Value (DEPRECATED - Use CATRCalculator instead)         |
    //+------------------------------------------------------------------+
    double GetATRValue()
    {
        // DEPRECATED: This function is kept for fallback compatibility only
        // Prefer using m_atr_calculator.CalculateGridSpacing() for better accuracy
        Print("⚠️ WARNING: Using deprecated GetATRValue() - Consider updating to use CATRCalculator");
        
        double high[], low[], close[];
        ArraySetAsSeries(high, true);
        ArraySetAsSeries(low, true);
        ArraySetAsSeries(close, true);
        
        if(CopyHigh(m_symbol, PERIOD_H1, 0, 15, high) != 15 ||
           CopyLow(m_symbol, PERIOD_H1, 0, 15, low) != 15 ||
           CopyClose(m_symbol, PERIOD_H1, 0, 15, close) != 15)
        {
            return 0.001; // Fallback value
        }
        
        double atr_sum = 0.0;
        for(int i = 1; i < 14; i++)
        {
            double tr = MathMax(high[i] - low[i], MathMax(MathAbs(high[i] - close[i+1]), MathAbs(low[i] - close[i+1])));
            atr_sum += tr;
        }
        
        return atr_sum / 13.0;
    }
};
//+------------------------------------------------------------------+
