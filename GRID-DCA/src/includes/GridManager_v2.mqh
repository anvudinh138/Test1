//+------------------------------------------------------------------+
//|                                                GridManager_v2.mqh |
//|                                     Independent Dual Grid System |
//|                              Dynamic Reset + DCA + Loss Protection |
//+------------------------------------------------------------------+
#property copyright "Flex Grid DCA EA v2"
#property version   "2.00"

#include <ATRCalculator.mqh>

//+------------------------------------------------------------------+
//| Grid Direction Enum                                              |
//+------------------------------------------------------------------+
enum ENUM_GRID_DIRECTION
{
    GRID_DIRECTION_BUY,
    GRID_DIRECTION_SELL
};

//+------------------------------------------------------------------+
//| Grid Level Structure                                             |
//+------------------------------------------------------------------+
struct SGridLevel
{
    double            price;           // Grid level price
    double            lot_size;        // Position size (fixed 0.01)
    bool              is_filled;       // Whether position is open
    ulong             ticket;          // Order ticket
    datetime          fill_time;       // Fill time
    ENUM_ORDER_TYPE   order_type;      // Buy or Sell
    int               level_index;     // Grid level index
    bool              is_dca_level;    // Is this a DCA expansion level
    ENUM_GRID_DIRECTION direction;     // Grid direction
};

//+------------------------------------------------------------------+
//| Grid Direction Manager                                           |
//+------------------------------------------------------------------+
struct SGridDirection
{
    SGridLevel        levels[];        // Grid levels for this direction
    double            base_price;      // Base price for this direction
    double            total_profit;    // Total profit for this direction
    double            total_loss;      // Total loss for this direction
    int               active_levels;   // Number of active levels
    datetime          last_reset;      // Last reset time
    bool              is_active;       // Is this direction active
    int               dca_expansions;  // Number of DCA expansions
};

//+------------------------------------------------------------------+
//| Advanced Grid Manager Class                                      |
//+------------------------------------------------------------------+
class CGridManagerV2
{
private:
    string            m_symbol;
    SGridDirection    m_buy_grid;      // Buy direction grid
    SGridDirection    m_sell_grid;     // Sell direction grid
    double            m_fixed_lot_size; // Fixed 0.01 lot size
    int               m_max_levels;     // Maximum levels per direction
    ulong             m_magic_number;   // EA magic number for position identification
    double            m_grid_spacing;   // Grid spacing in price
    CATRCalculator   *m_atr_calculator;
    bool              m_initialized;
    
    // Risk management
    double            m_account_start_balance;
    double            m_max_loss_percent;     // 5% loss protection
    double            m_profit_target_usd;    // Profit target in USD
    double            m_profit_target_percent; // Profit target in %
    bool              m_use_total_profit_target; // Use total profit instead of per-direction
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CGridManagerV2(void)
    {
        m_symbol = _Symbol;
        m_fixed_lot_size = 0.01;  // Fixed lot size
        m_max_levels = 5;         // 5 levels per direction
        m_magic_number = 12345;   // Default magic number
        m_grid_spacing = 0.0;
        m_initialized = false;
        m_atr_calculator = NULL;
        m_account_start_balance = 0.0;
        m_max_loss_percent = 5.0;    // 5% account loss protection
        m_profit_target_usd = 3.0;   // Default $3 USD profit target
        m_profit_target_percent = 1.0; // Default 1% profit target
        m_use_total_profit_target = true; // Default use total profit
        
        // Initialize grid directions
        InitializeGridDirection(m_buy_grid, GRID_DIRECTION_BUY);
        InitializeGridDirection(m_sell_grid, GRID_DIRECTION_SELL);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CGridManagerV2(void)
    {
        if(m_atr_calculator != NULL)
            delete m_atr_calculator;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Grid Manager                                          |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, double fixed_lot, int max_levels = 5, ulong magic_number = 12345)
    {
        m_symbol = symbol;
        m_fixed_lot_size = 0.01;  // Always fixed 0.01
        m_max_levels = max_levels;
        m_magic_number = magic_number;  // Set magic number for position identification
        m_account_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        // Initialize ATR calculator
        m_atr_calculator = new CATRCalculator();
        if(!m_atr_calculator.Initialize(symbol))
        {
            Print("Failed to initialize ATR calculator");
            return false;
        }
        
        m_initialized = true;
        Print("Grid Manager V2 initialized for ", symbol, " with fixed lot: 0.01");
        Print("Account Balance: ", m_account_start_balance);
        Print("Profit Target USD: ", m_profit_target_usd);
        Print("Profit Target %: ", m_profit_target_percent);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Set Profit Targets                                               |
    //+------------------------------------------------------------------+
    void SetProfitTargets(double target_usd, double target_percent, bool use_total_profit = true)
    {
        m_profit_target_usd = target_usd;
        m_profit_target_percent = target_percent;
        m_use_total_profit_target = use_total_profit;
        Print("Updated Profit Targets - USD: ", target_usd, ", Percent: ", target_percent, "%, Total Mode: ", use_total_profit ? "YES" : "NO");
        Print("Effective Target will be: $", DoubleToString(MathMin(target_usd, m_account_start_balance * (target_percent / 100.0)), 2));
    }
    
    //+------------------------------------------------------------------+
    //| Setup Dual Direction Grid                                        |
    //+------------------------------------------------------------------+
    bool SetupDualGrid(double current_price = 0.0, double atr_multiplier = 1.0)
    {
        if(!m_initialized || m_atr_calculator == NULL)
            return false;
            
        // Update ATR values
        m_atr_calculator.UpdateATRValues();
        
        // Get current price
        if(current_price <= 0.0)
            current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            
        // Calculate grid spacing based on H1 ATR
        double atr_h1 = m_atr_calculator.GetATR(PERIOD_H1);
        m_grid_spacing = atr_h1 * atr_multiplier;
        
        if(m_grid_spacing <= 0)
        {
            Print("Invalid grid spacing calculated: ", m_grid_spacing);
            return false;
        }
        
        // IMMEDIATE MARKET ENTRY: Place 1 Buy + 1 Sell market order first
        PlaceImmediateMarketOrders(current_price);
        
        // Setup Buy Grid (below current price)
        SetupDirectionGrid(m_buy_grid, GRID_DIRECTION_BUY, current_price);
        
        // Setup Sell Grid (above current price)
        SetupDirectionGrid(m_sell_grid, GRID_DIRECTION_SELL, current_price);
        
        Print("Dual Grid setup completed with immediate entries at price: ", current_price, ", Spacing: ", m_grid_spacing);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Place Immediate Market Orders (1 Buy + 1 Sell)                  |
    //+------------------------------------------------------------------+
    void PlaceImmediateMarketOrders(double current_price)
    {
        Print("🚀 Placing immediate market entries at price: ", current_price);
        
        // Place immediate BUY market order
        MqlTradeRequest buy_request = {};
        MqlTradeResult buy_result = {};
        
        buy_request.action = TRADE_ACTION_DEAL;
        buy_request.symbol = m_symbol;
        buy_request.volume = m_fixed_lot_size;
        buy_request.type = ORDER_TYPE_BUY;
        buy_request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        buy_request.sl = 0;
        buy_request.tp = 0;
        buy_request.deviation = 10;
        buy_request.magic = m_magic_number;
        buy_request.comment = "IMMEDIATE_BUY";
        
        if(OrderSend(buy_request, buy_result))
        {
            Print("✅ Immediate BUY market order placed: ", buy_result.order, " at ", buy_result.price);
        }
        else
        {
            Print("❌ Failed to place immediate BUY order: ", buy_result.retcode, " - ", buy_result.comment);
        }
        
        // Place immediate SELL market order
        MqlTradeRequest sell_request = {};
        MqlTradeResult sell_result = {};
        
        sell_request.action = TRADE_ACTION_DEAL;
        sell_request.symbol = m_symbol;
        sell_request.volume = m_fixed_lot_size;
        sell_request.type = ORDER_TYPE_SELL;
        sell_request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        sell_request.sl = 0;
        sell_request.tp = 0;
        sell_request.deviation = 10;
        sell_request.magic = m_magic_number;
        sell_request.comment = "IMMEDIATE_SELL";
        
        if(OrderSend(sell_request, sell_result))
        {
            Print("✅ Immediate SELL market order placed: ", sell_result.order, " at ", sell_result.price);
        }
        else
        {
            Print("❌ Failed to place immediate SELL order: ", sell_result.retcode, " - ", sell_result.comment);
        }
        
        Print("🎯 Immediate market entries completed - Bot now has positions to catch trends immediately!");
    }
    
    //+------------------------------------------------------------------+
    //| Check Direction Profits and Handle Profit Taking                |
    //+------------------------------------------------------------------+
    void CheckDirectionProfits(void)
    {
        // Calculate profit targets
        double usd_target = m_profit_target_usd;
        double percent_target = m_account_start_balance * (m_profit_target_percent / 100.0);
        
        // Use the LOWER of the two targets (more conservative)
        double effective_target = MathMin(usd_target, percent_target);
        
        // Get individual direction profits
        double buy_profit = CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_profit = CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        double total_profit = buy_profit + sell_profit;
        
        if(m_use_total_profit_target)
        {
            // MODE 1: TOTAL PROFIT TARGET (Both directions combined)
            if(total_profit >= effective_target)
            {
                Print("🎯 TOTAL PROFIT TARGET REACHED!");
                Print("Total Profit: $", DoubleToString(total_profit, 2), " >= Target: $", DoubleToString(effective_target, 2));
                Print("(Buy: $", DoubleToString(buy_profit, 2), " + Sell: $", DoubleToString(sell_profit, 2), ")");
                
                // Close ALL positions and reset both grids
                CloseDirectionPositions(GRID_DIRECTION_BUY);
                CloseDirectionPositions(GRID_DIRECTION_SELL);
                
                double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                SetupDirectionGrid(m_buy_grid, GRID_DIRECTION_BUY, current_price);
                SetupDirectionGrid(m_sell_grid, GRID_DIRECTION_SELL, current_price);
                Print("🔄 BOTH grids reset at price: ", current_price);
            }
            else if(total_profit >= effective_target * 10.0)  // Emergency safety trigger
            {
                Print("🚨 EMERGENCY PROFIT TRIGGER! Total: $", DoubleToString(total_profit, 2), " >> Target: $", DoubleToString(effective_target, 2));
                Print("Forcing profit taking to prevent excessive exposure!");
                
                CloseDirectionPositions(GRID_DIRECTION_BUY);
                CloseDirectionPositions(GRID_DIRECTION_SELL);
                
                double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                SetupDirectionGrid(m_buy_grid, GRID_DIRECTION_BUY, current_price);
                SetupDirectionGrid(m_sell_grid, GRID_DIRECTION_SELL, current_price);
                Print("🔄 EMERGENCY reset at price: ", current_price);
            }
        }
        else
        {
            // MODE 2: PER-DIRECTION PROFIT TARGET (Original logic)
            if(buy_profit >= effective_target)
            {
                Print("✅ BUY DIRECTION PROFIT TARGET REACHED!");
                Print("Buy Profit: $", DoubleToString(buy_profit, 2), " >= Target: $", DoubleToString(effective_target, 2));
                CloseDirectionPositions(GRID_DIRECTION_BUY);
                
                double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                SetupDirectionGrid(m_buy_grid, GRID_DIRECTION_BUY, current_price);
                Print("🔄 Buy Grid reset at new price: ", current_price);
            }
            
            if(sell_profit >= effective_target)
            {
                Print("✅ SELL DIRECTION PROFIT TARGET REACHED!");
                Print("Sell Profit: $", DoubleToString(sell_profit, 2), " >= Target: $", DoubleToString(effective_target, 2));
                CloseDirectionPositions(GRID_DIRECTION_SELL);
                
                double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                SetupDirectionGrid(m_sell_grid, GRID_DIRECTION_SELL, current_price);
                Print("🔄 Sell Grid reset at new price: ", current_price);
            }
        }
        
        // Debug info (print every 2 minutes for better monitoring)
        static datetime last_debug_print = 0;
        if(TimeCurrent() - last_debug_print > 120)  // 2 minutes
        {
            Print("=== PROFIT MONITORING ===");
            Print("Mode: ", m_use_total_profit_target ? "TOTAL PROFIT" : "PER-DIRECTION");
            Print("Buy Profit: $", DoubleToString(buy_profit, 2));
            Print("Sell Profit: $", DoubleToString(sell_profit, 2));
            Print("TOTAL Profit: $", DoubleToString(total_profit, 2), " / Target: $", DoubleToString(effective_target, 2));
            Print("USD Target: $", usd_target, " | Percent Target: $", DoubleToString(percent_target, 2));
            Print("Should Trigger: ", (total_profit >= effective_target && m_use_total_profit_target) ? "YES" : "NO");
            
            // Force trigger check if profit is very high
            if(total_profit >= effective_target * 5.0) {
                Print("⚠️ VERY HIGH PROFIT DETECTED! Total: $", DoubleToString(total_profit, 2), " - Force checking trigger logic");
            }
            last_debug_print = TimeCurrent();
        }
    }
    
    //+------------------------------------------------------------------+
    //| Check for DCA Expansion                                          |
    //+------------------------------------------------------------------+
    void CheckDCAExpansion(void)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        
        // Check Buy Direction for DCA expansion (price went down, all 5 levels filled)
        if(AllLevelsFilled(m_buy_grid) && current_price < GetLowestGridPrice(m_buy_grid))
        {
            ExpandDCAGrid(m_buy_grid, GRID_DIRECTION_BUY, current_price);
        }
        
        // Check Sell Direction for DCA expansion (price went up, all 5 levels filled)
        if(AllLevelsFilled(m_sell_grid) && current_price > GetHighestGridPrice(m_sell_grid))
        {
            ExpandDCAGrid(m_sell_grid, GRID_DIRECTION_SELL, current_price);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Check Loss Protection                                            |
    //+------------------------------------------------------------------+
    void CheckLossProtection(void)
    {
        double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double account_loss = m_account_start_balance - account_equity;
        double loss_percent = (account_loss / m_account_start_balance) * 100.0;
        
        if(loss_percent >= m_max_loss_percent)
        {
            Print("LOSS PROTECTION TRIGGERED! Account loss: ", loss_percent, "%");
            
            // Check which direction has more loss and close it
            double buy_loss = CalculateDirectionLoss(GRID_DIRECTION_BUY);
            double sell_loss = CalculateDirectionLoss(GRID_DIRECTION_SELL);
            
            if(buy_loss > sell_loss && buy_loss > 0)
            {
                Print("Closing Buy Direction due to loss protection");
                CloseDirectionPositions(GRID_DIRECTION_BUY);
                DisableDirection(m_buy_grid);
            }
            else if(sell_loss > 0)
            {
                Print("Closing Sell Direction due to loss protection");
                CloseDirectionPositions(GRID_DIRECTION_SELL);
                DisableDirection(m_sell_grid);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Place Grid Orders                                                |
    //+------------------------------------------------------------------+
    bool PlaceGridOrders(void)
    {
        if(!m_initialized)
            return false;
            
        int orders_placed = 0;
        
        // Place Buy Grid Orders
        orders_placed += PlaceDirectionOrders(m_buy_grid, GRID_DIRECTION_BUY);
        
        // Place Sell Grid Orders
        orders_placed += PlaceDirectionOrders(m_sell_grid, GRID_DIRECTION_SELL);
        
        if(orders_placed > 0)
            Print("Placed ", orders_placed, " grid orders");
            
        return (orders_placed > 0);
    }
    
    //+------------------------------------------------------------------+
    //| Update Grid Status                                               |
    //+------------------------------------------------------------------+
    void UpdateGridStatus(void)
    {
        UpdateDirectionStatus(m_buy_grid);
        UpdateDirectionStatus(m_sell_grid);
        
        // Check for profit taking opportunities
        CheckDirectionProfits();
        
        // Check for DCA expansion
        CheckDCAExpansion();
        
        // Check loss protection
        CheckLossProtection();
    }
    
    //+------------------------------------------------------------------+
    //| Print Grid Information                                           |
    //+------------------------------------------------------------------+
    void PrintGridInfo(void)
    {
        if(!m_initialized)
            return;
            
        Print("=== Dual Grid Information ===");
        Print("Symbol: ", m_symbol);
        Print("Fixed Lot Size: ", m_fixed_lot_size);
        Print("Grid Spacing: ", m_grid_spacing);
        
        Print("--- Buy Grid ---");
        PrintDirectionInfo(m_buy_grid, "BUY");
        
        Print("--- Sell Grid ---");
        PrintDirectionInfo(m_sell_grid, "SELL");
    }
    
    //+------------------------------------------------------------------+
    //| Close All Grid Positions                                         |
    //+------------------------------------------------------------------+
    bool CloseAllGridPositions(void)
    {
        int closed_count = 0;
        
        closed_count += CloseDirectionPositions(GRID_DIRECTION_BUY);
        closed_count += CloseDirectionPositions(GRID_DIRECTION_SELL);
        
        Print("Closed ", closed_count, " total grid positions");
        return (closed_count > 0);
    }
    
private:
    //+------------------------------------------------------------------+
    //| DEBUG: Check ALL positions in market regardless of magic        |
    //+------------------------------------------------------------------+
    void DebugAllMarketPositions(string direction_name)
    {
        Print("🚨 EMERGENCY DEBUG for ", direction_name, " - Checking ALL market positions:");
        double total_all_profit = 0.0;
        int total_all_count = 0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(!PositionSelectByTicket(ticket)) continue;
            
            string symbol = PositionGetString(POSITION_SYMBOL);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);
            string comment = PositionGetString(POSITION_COMMENT);
            
            if(symbol == m_symbol)
            {
                total_all_profit += (profit + swap);
                total_all_count++;
                
                string type_name = (pos_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
                Print("🎯 Position #", ticket, " | Type: ", type_name, " | Magic: ", magic, 
                      " | P&L: $", DoubleToString(profit + swap, 2), " | Comment: ", comment);
            }
        }
        
        Print("🔥 TOTAL ALL ", m_symbol, " positions: ", total_all_count, " | Total P&L: $", DoubleToString(total_all_profit, 2));
        Print("🔥 Expected from MT5 chart: ~$17.67 | EA Magic filter: ", m_magic_number);
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Grid Direction                                         |
    //+------------------------------------------------------------------+
    void InitializeGridDirection(SGridDirection &grid, ENUM_GRID_DIRECTION direction)
    {
        grid.base_price = 0.0;
        grid.total_profit = 0.0;
        grid.total_loss = 0.0;
        grid.active_levels = 0;
        grid.last_reset = 0;
        grid.is_active = true;
        grid.dca_expansions = 0;
        ArrayResize(grid.levels, 0);
    }
    
    //+------------------------------------------------------------------+
    //| Setup Direction Grid                                             |
    //+------------------------------------------------------------------+
    void SetupDirectionGrid(SGridDirection &grid, ENUM_GRID_DIRECTION direction, double base_price)
    {
        grid.base_price = base_price;
        grid.last_reset = TimeCurrent();
        grid.is_active = true;
        
        // Resize and initialize levels
        ArrayResize(grid.levels, m_max_levels);
        
        for(int i = 0; i < m_max_levels; i++)
        {
            double level_price;
            ENUM_ORDER_TYPE order_type;
            
            if(direction == GRID_DIRECTION_BUY)
            {
                // Buy levels below base price
                level_price = base_price - (m_grid_spacing * (i + 1));
                order_type = ORDER_TYPE_BUY;
            }
            else
            {
                // Sell levels above base price
                level_price = base_price + (m_grid_spacing * (i + 1));
                order_type = ORDER_TYPE_SELL;
            }
            
            grid.levels[i].price = level_price;
            grid.levels[i].lot_size = m_fixed_lot_size;
            grid.levels[i].is_filled = false;
            grid.levels[i].ticket = 0;
            grid.levels[i].fill_time = 0;
            grid.levels[i].order_type = order_type;
            grid.levels[i].level_index = i;
            grid.levels[i].is_dca_level = false;
            grid.levels[i].direction = direction;
        }
        
        Print("Direction grid setup: ", EnumToString(direction), " at base price: ", base_price);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Direction Total Profit (ALL positions including immediate)|
    //+------------------------------------------------------------------+
    double CalculateDirectionTotalProfit(ENUM_GRID_DIRECTION direction)
    {
        double total_profit = 0.0;
        int position_count = 0;
        string direction_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
        
        // Method 1: Check grid-tracked positions (existing logic)
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].is_filled && m_buy_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_buy_grid.levels[i].ticket))
                    {
                        total_profit += PositionGetDouble(POSITION_PROFIT);
                        position_count++;
                    }
                }
            }
        }
        else
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].is_filled && m_sell_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_sell_grid.levels[i].ticket))
                    {
                        total_profit += PositionGetDouble(POSITION_PROFIT);
                        position_count++;
                    }
                }
            }
        }
        
        // Method 2: Check ALL positions by magic number (includes immediate entries)
        double all_positions_profit = 0.0;
        int all_positions_count = 0;
        
        for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
        {
            ulong ticket = PositionGetTicket(pos_idx);
            if(ticket == 0)
                continue;
            if(!PositionSelectByTicket(ticket))
                continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)
                continue;
            // CRITICAL FIX: Include ALL positions for this symbol, regardless of magic number
            // Magic number filtering removed to capture all grid positions
            // if(PositionGetInteger(POSITION_MAGIC) != m_magic_number)
            //     continue;
                
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Match direction with position type
            bool is_direction_match = false;
            if(direction == GRID_DIRECTION_BUY && pos_type == POSITION_TYPE_BUY)
                is_direction_match = true;
            else if(direction == GRID_DIRECTION_SELL && pos_type == POSITION_TYPE_SELL)
                is_direction_match = true;
                
            if(is_direction_match)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                double swap = PositionGetDouble(POSITION_SWAP);
                // Note: POSITION_COMMISSION is deprecated in newer MT5 builds
                double position_total = profit + swap;
                
                all_positions_profit += position_total;
                all_positions_count++;
                
                // Debug for significant positions
                if(MathAbs(position_total) > 0.5)
                {
                    ulong position_ticket = PositionGetInteger(POSITION_TICKET);
                    string comment = PositionGetString(POSITION_COMMENT);
                    Print("💰 ", direction_name, " #", position_ticket, " (", comment, "): $", DoubleToString(position_total, 2));
                }
            }
        }
        
        // Debug comprehensive information
        Print("🔍 ", direction_name, " found ", all_positions_count, " total positions vs ", position_count, " grid-tracked");
        Print("📊 ", direction_name, " Grid-tracked P&L: $", DoubleToString(total_profit, 2));
        Print("📊 ", direction_name, " All-positions P&L: $", DoubleToString(all_positions_profit, 2));
        Print("🔧 FIXED: Including ALL positions for ", m_symbol, " (magic filter disabled) | Total positions: ", PositionsTotal());
        
        // EMERGENCY DEBUG: Check ALL positions regardless of magic number
        DebugAllMarketPositions(direction_name);
        
        // Always use the comprehensive method (includes immediate entries + all positions)
        return all_positions_profit;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Direction Profit (ONLY positive profits)              |
    //+------------------------------------------------------------------+
    double CalculateDirectionProfit(ENUM_GRID_DIRECTION direction)
    {
        double total_profit = 0.0;
        
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].is_filled && m_buy_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_buy_grid.levels[i].ticket))
                    {
                        double position_profit = PositionGetDouble(POSITION_PROFIT);
                        if(position_profit > 0)
                            total_profit += position_profit;
                    }
                }
            }
        }
        else
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].is_filled && m_sell_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_sell_grid.levels[i].ticket))
                    {
                        double position_profit = PositionGetDouble(POSITION_PROFIT);
                        if(position_profit > 0)
                            total_profit += position_profit;
                    }
                }
            }
        }
        
        return total_profit;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Direction Loss                                         |
    //+------------------------------------------------------------------+
    double CalculateDirectionLoss(ENUM_GRID_DIRECTION direction)
    {
        double total_loss = 0.0;
        
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].is_filled && m_buy_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_buy_grid.levels[i].ticket))
                    {
                        double position_profit = PositionGetDouble(POSITION_PROFIT);
                        if(position_profit < 0)
                            total_loss += MathAbs(position_profit);
                    }
                }
            }
        }
        else
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].is_filled && m_sell_grid.levels[i].ticket > 0)
                {
                    if(PositionSelectByTicket(m_sell_grid.levels[i].ticket))
                    {
                        double position_profit = PositionGetDouble(POSITION_PROFIT);
                        if(position_profit < 0)
                            total_loss += MathAbs(position_profit);
                    }
                }
            }
        }
        
        return total_loss;
    }
    
    //+------------------------------------------------------------------+
    //| Close Direction Positions                                        |
    //+------------------------------------------------------------------+
    int CloseDirectionPositions(ENUM_GRID_DIRECTION direction)
    {
        int closed_count = 0;
        
        if(direction == GRID_DIRECTION_BUY)
        {
            for(int i = 0; i < ArraySize(m_buy_grid.levels); i++)
            {
                if(m_buy_grid.levels[i].is_filled && m_buy_grid.levels[i].ticket > 0)
                {
                    if(ClosePosition(m_buy_grid.levels[i].ticket))
                    {
                        m_buy_grid.levels[i].is_filled = false;
                        m_buy_grid.levels[i].ticket = 0;
                        closed_count++;
                    }
                }
            }
        }
        else
        {
            for(int i = 0; i < ArraySize(m_sell_grid.levels); i++)
            {
                if(m_sell_grid.levels[i].is_filled && m_sell_grid.levels[i].ticket > 0)
                {
                    if(ClosePosition(m_sell_grid.levels[i].ticket))
                    {
                        m_sell_grid.levels[i].is_filled = false;
                        m_sell_grid.levels[i].ticket = 0;
                        closed_count++;
                    }
                }
            }
        }
        
        // CRITICAL FIX: Close ALL positions of this direction (includes immediate entries)
        string direction_name = (direction == GRID_DIRECTION_BUY) ? "BUY" : "SELL";
        int additional_closed = 0;
        
        Print("🚨 CLOSING ALL ", direction_name, " positions for ", m_symbol);
        
        for(int pos_idx = PositionsTotal() - 1; pos_idx >= 0; pos_idx--)
        {
            ulong ticket = PositionGetTicket(pos_idx);
            if(ticket == 0) continue;
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
                
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Match direction with position type
            bool should_close = false;
            if(direction == GRID_DIRECTION_BUY && pos_type == POSITION_TYPE_BUY)
                should_close = true;
            else if(direction == GRID_DIRECTION_SELL && pos_type == POSITION_TYPE_SELL)
                should_close = true;
                
            if(should_close)
            {
                string comment = PositionGetString(POSITION_COMMENT);
                if(ClosePosition(ticket))
                {
                    additional_closed++;
                    Print("✅ Closed ", direction_name, " position #", ticket, " (", comment, ")");
                }
                else
                {
                    Print("❌ Failed to close ", direction_name, " position #", ticket);
                }
            }
        }
        
        int total_closed = closed_count + additional_closed;
        Print("🎯 TOTAL CLOSED ", direction_name, ": ", total_closed, " positions (", closed_count, " grid + ", additional_closed, " additional)");
        return total_closed;
    }
    
    //+------------------------------------------------------------------+
    //| Check if all levels are filled                                   |
    //+------------------------------------------------------------------+
    bool AllLevelsFilled(SGridDirection &grid)
    {
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(!grid.levels[i].is_filled)
                return false;
        }
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Expand DCA Grid                                                  |
    //+------------------------------------------------------------------+
    void ExpandDCAGrid(SGridDirection &grid, ENUM_GRID_DIRECTION direction, double current_price)
    {
        if(grid.dca_expansions >= 2) // Limit to 2 DCA expansions
            return;
            
        Print("Expanding DCA grid for direction: ", EnumToString(direction));
        
        int current_size = ArraySize(grid.levels);
        ArrayResize(grid.levels, current_size + m_max_levels);
        
        for(int i = 0; i < m_max_levels; i++)
        {
            int new_index = current_size + i;
            double level_price;
            ENUM_ORDER_TYPE order_type;
            
            if(direction == GRID_DIRECTION_BUY)
            {
                level_price = current_price - (m_grid_spacing * (i + 1));
                order_type = ORDER_TYPE_BUY;
            }
            else
            {
                level_price = current_price + (m_grid_spacing * (i + 1));
                order_type = ORDER_TYPE_SELL;
            }
            
            grid.levels[new_index].price = level_price;
            grid.levels[new_index].lot_size = m_fixed_lot_size;
            grid.levels[new_index].is_filled = false;
            grid.levels[new_index].ticket = 0;
            grid.levels[new_index].order_type = order_type;
            grid.levels[new_index].level_index = new_index;
            grid.levels[new_index].is_dca_level = true;
            grid.levels[new_index].direction = direction;
        }
        
        grid.dca_expansions++;
        Print("DCA expansion completed. Total levels: ", ArraySize(grid.levels));
    }
    
    //+------------------------------------------------------------------+
    //| Get lowest/highest grid prices                                   |
    //+------------------------------------------------------------------+
    double GetLowestGridPrice(SGridDirection &grid)
    {
        double lowest = 999999;
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(grid.levels[i].price < lowest)
                lowest = grid.levels[i].price;
        }
        return lowest;
    }
    
    double GetHighestGridPrice(SGridDirection &grid)
    {
        double highest = 0;
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(grid.levels[i].price > highest)
                highest = grid.levels[i].price;
        }
        return highest;
    }
    
    //+------------------------------------------------------------------+
    //| Place Direction Orders                                           |
    //+------------------------------------------------------------------+
    int PlaceDirectionOrders(SGridDirection &grid, ENUM_GRID_DIRECTION direction)
    {
        if(!grid.is_active)
            return 0;
            
        int orders_placed = 0;
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(grid.levels[i].is_filled || grid.levels[i].ticket > 0)
                continue;
                
            bool should_place = false;
            ENUM_ORDER_TYPE order_type;
            
            if(direction == GRID_DIRECTION_BUY && grid.levels[i].price < current_price)
            {
                should_place = true;
                order_type = ORDER_TYPE_BUY_LIMIT;
            }
            else if(direction == GRID_DIRECTION_SELL && grid.levels[i].price > current_price)
            {
                should_place = true;
                order_type = ORDER_TYPE_SELL_LIMIT;
            }
            
            if(should_place)
            {
                ulong ticket = PlaceLimitOrder(order_type, grid.levels[i].lot_size, 
                                             grid.levels[i].price, i, direction);
                if(ticket > 0)
                {
                    grid.levels[i].ticket = ticket;
                    orders_placed++;
                }
            }
        }
        
        return orders_placed;
    }
    
    //+------------------------------------------------------------------+
    //| Update Direction Status                                          |
    //+------------------------------------------------------------------+
    void UpdateDirectionStatus(SGridDirection &grid)
    {
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(grid.levels[i].ticket > 0 && !grid.levels[i].is_filled)
            {
                if(PositionSelectByTicket(grid.levels[i].ticket))
                {
                    grid.levels[i].is_filled = true;
                    grid.levels[i].fill_time = TimeCurrent();
                    Print("Grid level filled: ", i, " at price: ", grid.levels[i].price);
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Place Limit Order                                                |
    //+------------------------------------------------------------------+
    ulong PlaceLimitOrder(ENUM_ORDER_TYPE order_type, double lot_size, double price, 
                         int level_index, ENUM_GRID_DIRECTION direction)
    {
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_PENDING;
        request.symbol = m_symbol;
        request.volume = lot_size;
        request.type = order_type;
        request.price = price;
        request.sl = 0;  // No stop loss for grid
        request.tp = 0;  // No take profit for grid
        request.magic = 12345 + level_index + ((direction == GRID_DIRECTION_BUY) ? 1000 : 2000);
        request.comment = "Grid_" + EnumToString(direction) + "_" + IntegerToString(level_index);
        
        if(!OrderSend(request, result))
        {
            Print("Failed to place order at level ", level_index, ". Error: ", result.retcode);
            return 0;
        }
        
        return result.order;
    }
    
    //+------------------------------------------------------------------+
    //| Close Position                                                   |
    //+------------------------------------------------------------------+
    bool ClosePosition(ulong ticket)
    {
        if(!PositionSelectByTicket(ticket))
            return false;
            
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                       ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                        SymbolInfoDouble(m_symbol, SYMBOL_BID) :
                        SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        request.magic = PositionGetInteger(POSITION_MAGIC);
        
        return OrderSend(request, result);
    }
    
    //+------------------------------------------------------------------+
    //| Disable Direction                                                |
    //+------------------------------------------------------------------+
    void DisableDirection(SGridDirection &grid)
    {
        grid.is_active = false;
        Print("Grid direction disabled due to loss protection");
    }
    
    //+------------------------------------------------------------------+
    //| Print Direction Info                                             |
    //+------------------------------------------------------------------+
    void PrintDirectionInfo(SGridDirection &grid, string direction_name)
    {
        Print("Direction: ", direction_name);
        Print("Base Price: ", grid.base_price);
        Print("Active: ", grid.is_active ? "YES" : "NO");
        Print("Total Levels: ", ArraySize(grid.levels));
        Print("DCA Expansions: ", grid.dca_expansions);
        
        int filled_count = 0;
        for(int i = 0; i < ArraySize(grid.levels); i++)
        {
            if(grid.levels[i].is_filled)
                filled_count++;
        }
        Print("Filled Levels: ", filled_count);
    }
};
//+------------------------------------------------------------------+
