//+------------------------------------------------------------------+
//|                                                   GridManager.mqh |
//|                                            Flex Grid DCA System   |
//|                                      Grid Management with ATR      |
//+------------------------------------------------------------------+
#property copyright "Flex Grid DCA EA"
#property version   "1.00"

#include "ATRCalculator.mqh"

//+------------------------------------------------------------------+
//| Grid Level Structure                                             |
//+------------------------------------------------------------------+
struct SGridLevel
{
    double            price;           // Grid level price
    double            lot_size;        // Position size
    bool              is_filled;       // Whether position is open
    ulong             ticket;          // Order ticket
    datetime          fill_time;       // Fill time
    ENUM_ORDER_TYPE   order_type;      // Buy or Sell
    int               level_index;     // Grid level index
    bool              is_dca_level;    // Is this a DCA averaging level
};

//+------------------------------------------------------------------+
//| Grid Manager Class                                               |
//+------------------------------------------------------------------+
class CGridManager
{
private:
    string            m_symbol;
    SGridLevel        m_grid_levels[];
    double            m_base_price;
    double            m_grid_spacing;
    int               m_max_levels;
    double            m_fixed_lot_size;
    CATRCalculator   *m_atr_calculator;
    bool              m_initialized;
    
    // Fibonacci ratios for dynamic spacing
    double            m_fibonacci_ratios[8];
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CGridManager(void)
    {
        m_symbol = _Symbol;
        m_base_price = 0.0;
        m_grid_spacing = 0.0;
        m_max_levels = 10;
        m_fixed_lot_size = 0.01;  // Safe default for high margin account
        m_initialized = false;
        m_atr_calculator = NULL;
        
        // Initialize Fibonacci ratios
        m_fibonacci_ratios[0] = 0.236;
        m_fibonacci_ratios[1] = 0.382;
        m_fibonacci_ratios[2] = 0.618;
        m_fibonacci_ratios[3] = 1.000;
        m_fibonacci_ratios[4] = 1.618;
        m_fibonacci_ratios[5] = 2.618;
        m_fibonacci_ratios[6] = 4.236;
        m_fibonacci_ratios[7] = 6.854;
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CGridManager(void)
    {
        if(m_atr_calculator != NULL)
            delete m_atr_calculator;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Grid Manager                                          |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, double fixed_lot, int max_levels = 10)
    {
        m_symbol = symbol;
        m_fixed_lot_size = fixed_lot;
        m_max_levels = max_levels;
        
        // Initialize ATR calculator
        m_atr_calculator = new CATRCalculator();
        if(!m_atr_calculator.Initialize(symbol))
        {
            Print("Failed to initialize ATR calculator");
            return false;
        }
        
        m_initialized = true;
        Print("Grid Manager initialized for ", symbol, " with fixed lot: ", fixed_lot);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Setup grid based on current price and ATR                       |
    //+------------------------------------------------------------------+
    bool SetupGrid(double base_price = 0.0, double atr_multiplier = 1.0)
    {
        if(!m_initialized || m_atr_calculator == NULL)
            return false;
            
        // Update ATR values
        m_atr_calculator.UpdateATRValues();
        
        // Set base price
        if(base_price <= 0.0)
            m_base_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        else
            m_base_price = base_price;
            
        // Calculate grid spacing based on H1 ATR
        double atr_h1 = m_atr_calculator.GetATR(PERIOD_H1);
        m_grid_spacing = atr_h1 * atr_multiplier;
        
        if(m_grid_spacing <= 0)
        {
            Print("Invalid grid spacing calculated: ", m_grid_spacing);
            return false;
        }
        
        // Create grid levels
        CreateGridLevels();
        
        Print("Grid setup completed. Base price: ", m_base_price, 
              ", Spacing: ", m_grid_spacing, " (", DoubleToString(atr_multiplier, 1), " x ATR)");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Create grid levels using Fibonacci spacing                      |
    //+------------------------------------------------------------------+
    void CreateGridLevels(void)
    {
        ArrayResize(m_grid_levels, m_max_levels * 2);  // Buy and Sell levels
        ArrayInitialize(m_grid_levels, 0);
        
        int index = 0;
        
        // Create Buy levels (below current price)
        for(int i = 0; i < m_max_levels; i++)
        {
            double spacing = CalculateFibonacciSpacing(i);
            double price = m_base_price - spacing;
            
            m_grid_levels[index].price = price;
            m_grid_levels[index].lot_size = m_fixed_lot_size;
            m_grid_levels[index].is_filled = false;
            m_grid_levels[index].ticket = 0;
            m_grid_levels[index].order_type = ORDER_TYPE_BUY;
            m_grid_levels[index].level_index = i;
            m_grid_levels[index].is_dca_level = (i > 0);  // First level is not DCA
            
            index++;
        }
        
        // Create Sell levels (above current price)
        for(int i = 0; i < m_max_levels; i++)
        {
            double spacing = CalculateFibonacciSpacing(i);
            double price = m_base_price + spacing;
            
            m_grid_levels[index].price = price;
            m_grid_levels[index].lot_size = m_fixed_lot_size;
            m_grid_levels[index].is_filled = false;
            m_grid_levels[index].ticket = 0;
            m_grid_levels[index].order_type = ORDER_TYPE_SELL;
            m_grid_levels[index].level_index = i;
            m_grid_levels[index].is_dca_level = (i > 0);  // First level is not DCA
            
            index++;
        }
        
        Print("Created ", ArraySize(m_grid_levels), " grid levels");
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Fibonacci-based spacing for level                     |
    //+------------------------------------------------------------------+
    double CalculateFibonacciSpacing(int level)
    {
        if(level == 0)
            return m_grid_spacing * 0.5;  // Closer first level
            
        int fib_index = (level - 1) % ArraySize(m_fibonacci_ratios);
        double multiplier = m_fibonacci_ratios[fib_index];
        
        // For higher levels, use exponential growth
        if(level > ArraySize(m_fibonacci_ratios))
        {
            multiplier = m_fibonacci_ratios[ArraySize(m_fibonacci_ratios) - 1] * 
                        MathPow(1.618, level - ArraySize(m_fibonacci_ratios));
        }
        
        return m_grid_spacing * multiplier;
    }
    
    //+------------------------------------------------------------------+
    //| Place pending orders for unfilled grid levels                   |
    //+------------------------------------------------------------------+
    bool PlaceGridOrders(void)
    {
        if(!m_initialized)
            return false;
            
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        int orders_placed = 0;
        
        for(int i = 0; i < ArraySize(m_grid_levels); i++)
        {
            if(m_grid_levels[i].is_filled || m_grid_levels[i].ticket > 0)
                continue;
                
            // Check if we should place this order
            bool should_place = false;
            ENUM_ORDER_TYPE order_type;
            
            if(m_grid_levels[i].order_type == ORDER_TYPE_BUY && 
               m_grid_levels[i].price < current_price)
            {
                should_place = true;
                order_type = ORDER_TYPE_BUY_LIMIT;
            }
            else if(m_grid_levels[i].order_type == ORDER_TYPE_SELL && 
                    m_grid_levels[i].price > current_price)
            {
                should_place = true;
                order_type = ORDER_TYPE_SELL_LIMIT;
            }
            
            if(should_place)
            {
                ulong ticket = PlaceLimitOrder(order_type, m_grid_levels[i].lot_size, 
                                             m_grid_levels[i].price, i);
                if(ticket > 0)
                {
                    m_grid_levels[i].ticket = ticket;
                    orders_placed++;
                }
            }
        }
        
        Print("Placed ", orders_placed, " grid orders");
        return (orders_placed > 0);
    }
    
    //+------------------------------------------------------------------+
    //| Check for filled orders and update grid                         |
    //+------------------------------------------------------------------+
    void UpdateGridStatus(void)
    {
        for(int i = 0; i < ArraySize(m_grid_levels); i++)
        {
            if(m_grid_levels[i].ticket > 0 && !m_grid_levels[i].is_filled)
            {
                // Check if order is filled by checking positions
                if(PositionSelectByTicket(m_grid_levels[i].ticket))
                {
                    m_grid_levels[i].is_filled = true;
                    m_grid_levels[i].fill_time = TimeCurrent();
                    
                    Print("Grid level ", i, " filled at price: ", m_grid_levels[i].price);
                    
                    // If DCA level, adjust lot sizes for next levels
                    if(m_grid_levels[i].is_dca_level)
                    {
                        AdjustDCALotSizes(i);
                    }
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Get current grid information                                     |
    //+------------------------------------------------------------------>
    void PrintGridInfo(void)
    {
        if(!m_initialized)
            return;
            
        Print("=== Grid Information ===");
        Print("Symbol: ", m_symbol);
        Print("Base Price: ", m_base_price);
        Print("Grid Spacing: ", m_grid_spacing);
        Print("Fixed Lot Size: ", m_fixed_lot_size);
        Print("Total Levels: ", ArraySize(m_grid_levels));
        
        int filled_count = 0;
        for(int i = 0; i < ArraySize(m_grid_levels); i++)
        {
            if(m_grid_levels[i].is_filled)
                filled_count++;
        }
        Print("Filled Levels: ", filled_count);
        
        if(m_atr_calculator != NULL)
        {
            Print("Current ATR H1: ", m_atr_calculator.GetATR(PERIOD_H1));
            Print("Volatility: ", m_atr_calculator.GetVolatilityCondition());
        }
    }
    
    //+------------------------------------------------------------------+
    //| Close all grid positions                                         |
    //+------------------------------------------------------------------+
    bool CloseAllGridPositions(void)
    {
        int closed_count = 0;
        
        for(int i = 0; i < ArraySize(m_grid_levels); i++)
        {
            if(m_grid_levels[i].is_filled && m_grid_levels[i].ticket > 0)
            {
                if(PositionSelectByTicket(m_grid_levels[i].ticket))
                {
                    if(ClosePosition(m_grid_levels[i].ticket))
                    {
                        m_grid_levels[i].is_filled = false;
                        closed_count++;
                    }
                }
            }
        }
        
        Print("Closed ", closed_count, " grid positions");
        return (closed_count > 0);
    }
    
private:
    //+------------------------------------------------------------------+
    //| Place limit order                                                |
    //+------------------------------------------------------------------+
    ulong PlaceLimitOrder(ENUM_ORDER_TYPE order_type, double lot_size, double price, int level_index)
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
        request.magic = 12345 + level_index;  // Unique magic for each level
        request.comment = "Grid_Level_" + IntegerToString(level_index);
        
        if(!OrderSend(request, result))
        {
            Print("Failed to place order at level ", level_index, ". Error: ", result.retcode);
            return 0;
        }
        
        return result.order;
    }
    
    //+------------------------------------------------------------------+
    //| Adjust DCA lot sizes (could implement martingale here)          |
    //+------------------------------------------------------------------+
    void AdjustDCALotSizes(int filled_level)
    {
        // For now, keep same lot size for safety
        // In future, could implement progressive lot sizing
        // But with high margin account, better keep fixed lots
        
        Print("DCA level filled: ", filled_level, " - maintaining fixed lot sizes for safety");
    }
    
    //+------------------------------------------------------------------+
    //| Close position by ticket                                         |
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
};
//+------------------------------------------------------------------+
