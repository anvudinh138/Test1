//+------------------------------------------------------------------+
//|                                      IndependentLifecycle.mqh  |
//|                                       FlexGridDCA EA v3.0.0      |
//|                                Self-Managing Lifecycle Core     |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA v3.0"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <GridManager_v2.mqh>
#include <ATRCalculator.mqh>

//+------------------------------------------------------------------+
//| Lifecycle States                                               |
//+------------------------------------------------------------------+
enum LIFECYCLE_STATE
{
    LIFECYCLE_INITIALIZING,    // Setting up grid
    LIFECYCLE_ACTIVE,          // Normal grid trading
    LIFECYCLE_DCA_RESCUE,      // DCA rescue mode
    LIFECYCLE_TRAILING,        // Trailing stop active
    LIFECYCLE_CLOSING,         // Closing all positions
    LIFECYCLE_COMPLETED,       // Lifecycle finished
    LIFECYCLE_EMERGENCY        // Emergency shutdown
};

//+------------------------------------------------------------------+
//| Independent Self-Managing Lifecycle                            |
//+------------------------------------------------------------------+
class CIndependentLifecycle
{
private:
    // Core identification
    int                 m_id;
    string              m_symbol;
    datetime            m_start_time;
    LIFECYCLE_STATE     m_state;
    
    // Grid management
    CGridManagerV2*     m_grid_manager;
    CATRCalculator*     m_atr_calculator;
    CTrade              m_trade;
    
    // Financial tracking
    double              m_allocated_balance;
    double              m_profit_target;
    double              m_stop_loss;
    double              m_current_profit;
    double              m_peak_profit;
    double              m_max_loss;
    
    // Grid settings
    int                 m_grid_levels;
    double              m_lot_size;
    double              m_atr_multiplier;
    
    // Risk management
    double              m_current_risk;
    double              m_max_risk_allowed;
    bool                m_emergency_shutdown_requested;
    string              m_emergency_reason;
    
    // Trailing stop
    bool                m_trailing_active;
    double              m_trailing_threshold;
    double              m_trailing_atr_multiplier;  // NEW: Configurable ATR multiplier
    bool                m_partial_profit_taken;
    
    // DCA management
    bool                m_dca_activated;
    int                 m_dca_expansions;
    bool                m_dca_orders_placed;     // NEW: Track if DCA orders placed
    
    // Lifecycle management
    bool                m_is_active;
    bool                m_is_completed;
    datetime            m_last_update;
    datetime            m_last_risk_check;
    
    // Order cleanup tracking
    bool                m_orders_cleaned;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CIndependentLifecycle(int id, string symbol, double profit_target, double stop_loss, 
                         int grid_levels, double lot_size, double allocated_balance, 
                         double trailing_atr_multiplier = 2.0)
    {
        m_id = id;
        m_symbol = symbol;
        m_profit_target = profit_target;
        m_stop_loss = stop_loss;
        m_grid_levels = grid_levels;
        m_lot_size = lot_size;
        m_allocated_balance = allocated_balance;
        
        m_start_time = TimeCurrent();
        m_state = LIFECYCLE_INITIALIZING;
        
        // Initialize financial tracking
        m_current_profit = 0.0;
        m_peak_profit = 0.0;
        m_max_loss = 0.0;
        m_current_risk = 0.0;
        m_max_risk_allowed = stop_loss; // Risk cannot exceed stop loss
        
        // Initialize flags
        m_is_active = true;
        m_is_completed = false;
        m_emergency_shutdown_requested = false;
        m_trailing_active = false;
        m_trailing_atr_multiplier = trailing_atr_multiplier;  // NEW: Set configurable ATR multiplier
        m_partial_profit_taken = false;
        m_dca_activated = false;
        m_dca_expansions = 0;
        m_dca_orders_placed = false;     // NEW: Initialize DCA flag
        m_orders_cleaned = false;
        
        m_last_update = TimeCurrent();
        m_last_risk_check = TimeCurrent();
        
        // Initialize grid components
        m_grid_manager = new CGridManagerV2();
        m_atr_calculator = new CATRCalculator();
        
        if(m_grid_manager != NULL && m_atr_calculator != NULL)
        {
            // CRITICAL: Initialize ATR Calculator first
                if(!m_atr_calculator.Initialize(m_symbol))
                {
                    Print("❌ LIFECYCLE #", m_id, " Failed to initialize ATR Calculator");
                    RequestEmergencyShutdown("ATR Calculator initialization failed");
                    return;
                }
                
                m_grid_manager.Initialize(m_symbol, m_grid_levels, m_lot_size);
                m_grid_manager.SetATRCalculator(m_atr_calculator);
                m_grid_manager.SetJobID(m_id);  // NEW: Set job ID for order comments
                
                // Grid Manager Job ID set - debug logging removed
            
            Print("✅ LIFECYCLE #", m_id, " ATR Calculator initialized successfully");
        }
        
        Print("🚀 LIFECYCLE #", m_id, " CREATED: Target=$", DoubleToString(m_profit_target, 2), 
              " StopLoss=$", DoubleToString(m_stop_loss, 2), " Levels=", m_grid_levels);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CIndependentLifecycle()
    {
        if(m_grid_manager != NULL)
        {
            delete m_grid_manager;
            m_grid_manager = NULL;
        }
        
        if(m_atr_calculator != NULL)
        {
            delete m_atr_calculator;
            m_atr_calculator = NULL;
        }
        
        Print("🧹 LIFECYCLE #", m_id, " DESTROYED");
    }
    
    //+------------------------------------------------------------------+
    //| Main Update Function - SELF MANAGEMENT                         |
    //+------------------------------------------------------------------+
    void Update()
    {
        if(!m_is_active || m_is_completed) return;
        
        datetime current_time = TimeCurrent();
        
        // Update financial tracking
        UpdateFinancialStatus();
        
        // Risk check every 30 seconds
        if(current_time - m_last_risk_check > 30)
        {
            if(!PerformSelfRiskCheck())
            {
                return; // Emergency shutdown requested
            }
            m_last_risk_check = current_time;
        }
        
        // State machine
        switch(m_state)
        {
            case LIFECYCLE_INITIALIZING:
                HandleInitializingState();
                break;
                
            case LIFECYCLE_ACTIVE:
                HandleActiveState();
                break;
                
            case LIFECYCLE_DCA_RESCUE:
                HandleDCARescueState();
                break;
                
            case LIFECYCLE_TRAILING:
                HandleTrailingState();
                break;
                
            case LIFECYCLE_CLOSING:
                HandleClosingState();
                break;
                
            case LIFECYCLE_EMERGENCY:
                HandleEmergencyState();
                break;
        }
        
        m_last_update = current_time;
    }
    
    //+------------------------------------------------------------------+
    //| Financial Status Update                                        |
    //+------------------------------------------------------------------+
    void UpdateFinancialStatus()
    {
        if(m_grid_manager == NULL) return;
        
        m_current_profit = CalculateTotalProfit();
        
        // Update peak profit
        if(m_current_profit > m_peak_profit)
        {
            m_peak_profit = m_current_profit;
        }
        
        // Update max loss
        if(m_current_profit < m_max_loss)
        {
            m_max_loss = m_current_profit;
        }
        
        // Calculate current risk (unrealized loss)
        m_current_risk = MathAbs(MathMin(0.0, m_current_profit));
    }
    
    //+------------------------------------------------------------------+
    //| Self Risk Management - CRITICAL                                |
    //+------------------------------------------------------------------+
    bool PerformSelfRiskCheck()
    {
        // Check stop loss
        if(m_current_profit <= -m_stop_loss)
        {
            RequestEmergencyShutdown(StringFormat("Stop Loss Hit: $%.2f <= -$%.2f", 
                                                 m_current_profit, m_stop_loss));
            return false;
        }
        
        // Check maximum risk
        if(m_current_risk > m_max_risk_allowed)
        {
            RequestEmergencyShutdown(StringFormat("Max Risk Exceeded: $%.2f > $%.2f", 
                                                 m_current_risk, m_max_risk_allowed));
            return false;
        }
        
        // Check for runaway positions (too many positions)
        int total_positions = GetLifecyclePositionCount();
        if(total_positions > m_grid_levels * 4) // 4x normal grid size
        {
            RequestEmergencyShutdown(StringFormat("Too Many Positions: %d > %d", 
                                                 total_positions, m_grid_levels * 4));
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| State Handlers                                                 |
    //+------------------------------------------------------------------+
    void HandleInitializingState()
    {
        if(m_grid_manager == NULL) return;
        
        // Setup initial grid with ATR multiplier
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(m_grid_manager.SetupDualGrid(current_price, 1.2)) // Use default ATR multiplier
        {
            m_state = LIFECYCLE_ACTIVE;
            Print("📊 LIFECYCLE #", m_id, " GRID SETUP COMPLETE - Now ACTIVE");
        }
        else
        {
            RequestEmergencyShutdown("Failed to setup initial grid");
        }
    }
    
    void HandleActiveState()
    {
        if(m_grid_manager == NULL) return;
        
        // Update grid status
        m_grid_manager.UpdateGridStatus();
        
        // Check for DCA trigger
        if(!m_dca_activated && m_grid_manager.CheckSmartDCAExpansion())
        {
            m_dca_activated = true;
            m_state = LIFECYCLE_DCA_RESCUE;
            Print("🚨 LIFECYCLE #", m_id, " DCA RESCUE ACTIVATED");
            return;
        }
        
        // Check for profit target (trailing activation)
        if(m_current_profit >= m_profit_target)
        {
            ActivateTrailingStop();
            return;
        }
        
        // Place grid orders
        m_grid_manager.PlaceGridOrders();
    }
    
    void HandleDCARescueState()
    {
        if(m_grid_manager == NULL) return;
        
        // Update grid status and calculate profit
        m_grid_manager.UpdateGridStatus();
        m_current_profit = CalculateTotalProfit();
        
        // MINIMAL LOGGING: Only log DCA progress every 5 minutes
        static datetime last_dca_log = 0;
        if(TimeCurrent() - last_dca_log > 300) // 5 minutes
        {
            Print("📈 LIFECYCLE #", m_id, " DCA RECOVERY: $", DoubleToString(m_current_profit, 2));
            last_dca_log = TimeCurrent();
        }
        
        // 🚨 FORCE DCA EXPANSION: Place counter-trend orders
        if(!m_dca_orders_placed)
        {
            PlaceDCAOrders();
            m_dca_orders_placed = true;
        }
        
        // Continue normal operations with DCA active
        m_grid_manager.PlaceGridOrders();
        
        // Check for profit target (50% threshold for trailing)
        double trailing_threshold = m_profit_target * 0.5; // 50% of profit target
        if(m_current_profit >= trailing_threshold)
        {
            Print("🎯 LIFECYCLE #", m_id, " DCA RECOVERY SUCCESS - TRAILING THRESHOLD: $", DoubleToString(m_current_profit, 2));
            ActivateTrailingStop();
            return;
        }
        
        // Check for emergency stop loss (expanded)
        double emergency_stop = m_stop_loss * 2.0; // Double stop loss in DCA mode
        if(m_current_profit <= -emergency_stop)
        {
            Print("🚨 LIFECYCLE #", m_id, " EMERGENCY STOP LOSS HIT: $", DoubleToString(m_current_profit, 2));
            RequestEmergencyShutdown("Emergency stop loss in DCA mode");
            return;
        }
        
        // Original check for full profit target
        if(m_current_profit >= m_profit_target)
        {
            ActivateTrailingStop();
            return;
        }
        
        // Monitor DCA effectiveness - REMOVED VERBOSE LOGGING
    }
    
    void HandleTrailingState()
    {
        // 🧹 CRITICAL: Clean all pending orders to avoid conflicts
        if(!m_orders_cleaned)
        {
            CleanAllPendingOrders();
            m_orders_cleaned = true;
            Print("🧹 LIFECYCLE #", m_id, " CLEANED ALL PENDING ORDERS - Trailing Mode");
        }
        
        // 🎯 FIXED TRAILING LOGIC: ATR-based trailing stop like STABLE-V1
        // Use configurable ATR multiplier from constructor
        double current_atr = 0.001; // Fallback
        
        // Get ATR from grid manager
        if(m_grid_manager != NULL)
        {
            current_atr = m_grid_manager.CalculateGridSpacing() / 1.2; // Reverse calculate ATR
            if(current_atr < 0.0005) current_atr = 0.001; // Minimum ATR
        }
        
        // Calculate ATR-based trailing distance
        double atr_trailing_distance = current_atr * m_trailing_atr_multiplier; // Configurable ATR distance
        double atr_trailing_distance_usd = atr_trailing_distance * 100000.0; // Convert to USD (rough estimate)
        
        // 🚨 ENHANCED TRAILING LOGIC: Combination of percentage + ATR
        // Update trailing threshold (can move up OR down based on market)
        double percentage_threshold = m_current_profit * 0.7; // 70% of current profit
        double atr_threshold = m_peak_profit - atr_trailing_distance_usd; // ATR-based from peak
        
        // Use the more conservative (higher) threshold
        double new_trailing_threshold = MathMax(percentage_threshold, atr_threshold);
        
        // Always update threshold (can go up or down) - SILENT UPDATES
        m_trailing_threshold = new_trailing_threshold;
        
        // 🛑 TRAILING STOP CHECK: Close if profit drops below threshold
        if(m_current_profit <= m_trailing_threshold)
        {
            m_state = LIFECYCLE_CLOSING;
            Print("🏃 LIFECYCLE #", m_id, " TRAILING STOP TRIGGERED: Profit $", DoubleToString(m_current_profit, 2), 
                  " <= Threshold $", DoubleToString(m_trailing_threshold, 2));
        }
        
        // 🚨 EMERGENCY STOP: If profit drops too much from peak (like breakeven protection)
        double max_drawdown_from_peak = m_peak_profit * 0.5; // 50% drawdown from peak
        if(m_current_profit <= max_drawdown_from_peak && m_peak_profit > m_profit_target)
        {
            m_state = LIFECYCLE_CLOSING;
            Print("🚨 LIFECYCLE #", m_id, " EMERGENCY TRAILING STOP: Profit dropped 50% from peak $", 
                  DoubleToString(m_peak_profit, 2), " to $", DoubleToString(m_current_profit, 2));
        }
    }
    
    void HandleClosingState()
    {
        // Close all positions for this lifecycle
        CloseAllLifecyclePositions();
        
        // Check if all closed
        if(GetLifecyclePositionCount() == 0)
        {
            m_state = LIFECYCLE_COMPLETED;
            m_is_completed = true;
            m_is_active = false;
            Print("✅ LIFECYCLE #", m_id, " COMPLETED: Final profit $", DoubleToString(m_current_profit, 2));
        }
    }
    
    void HandleEmergencyState()
    {
        // Emergency close everything
        CloseAllLifecyclePositions();
        CleanAllPendingOrders();
        
        m_state = LIFECYCLE_COMPLETED;
        m_is_completed = true;
        m_is_active = false;
        
        Print("🚨 LIFECYCLE #", m_id, " EMERGENCY SHUTDOWN COMPLETE");
    }
    
    //+------------------------------------------------------------------+
    //| Trailing Stop Activation                                       |
    //+------------------------------------------------------------------+
    void ActivateTrailingStop()
    {
        m_trailing_active = true;
        m_trailing_threshold = m_current_profit * 0.7; // Start at 70% of current profit
        m_state = LIFECYCLE_TRAILING;
        
        Print("🎯 LIFECYCLE #", m_id, " PROFIT TARGET REACHED: $", DoubleToString(m_current_profit, 2));
        Print("🏃 LIFECYCLE #", m_id, " TRAILING STOP ACTIVATED: Threshold $", DoubleToString(m_trailing_threshold, 2));
    }
    
    //+------------------------------------------------------------------+
    //| Order and Position Management                                  |
    //+------------------------------------------------------------------+
    void CleanAllPendingOrders()
    {
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket))
            {
                string comment = OrderGetString(ORDER_COMMENT);
                if(StringFind(comment, "Grid_") >= 0) // Our grid orders
                {
                    if(m_trade.OrderDelete(ticket))
                    {
                        Print("🗑️ LIFECYCLE #", m_id, " Cancelled order #", ticket);
                    }
                }
            }
        }
    }
    
    void CloseAllLifecyclePositions()
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                string comment = PositionGetString(POSITION_COMMENT);
                if(StringFind(comment, "Grid_") >= 0) // Our grid positions
                {
                    if(m_trade.PositionClose(ticket))
                    {
                        Print("💰 LIFECYCLE #", m_id, " Closed position #", ticket);
                    }
                }
            }
        }
    }
    
    int GetLifecyclePositionCount()
    {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                string comment = PositionGetString(POSITION_COMMENT);
                if(StringFind(comment, "Grid_") >= 0)
                {
                    count++;
                }
            }
        }
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Emergency Management                                           |
    //+------------------------------------------------------------------+
    void RequestEmergencyShutdown(string reason)
    {
        m_emergency_shutdown_requested = true;
        m_emergency_reason = reason;
        m_state = LIFECYCLE_EMERGENCY;
        
        Print("🚨 LIFECYCLE #", m_id, " REQUESTS EMERGENCY SHUTDOWN: ", reason);
    }
    
    void EmergencyClose()
    {
        m_state = LIFECYCLE_EMERGENCY;
        HandleEmergencyState();
    }
    
    //+------------------------------------------------------------------+
    //| Public Interface                                               |
    //+------------------------------------------------------------------+
    int GetID() { return m_id; }
    bool IsActive() { return m_is_active; }
    bool IsCompleted() { return m_is_completed; }
    double GetCurrentProfit() { return m_current_profit; }
    double GetCurrentRisk() { return m_current_risk; }
    double GetAllocatedBalance() { return m_allocated_balance; }
    LIFECYCLE_STATE GetState() { return m_state; }
    
    // 🚨 NEW: Get DCA expansion count for trigger detection
    int GetDCAExpansions() 
    { 
        if(m_grid_manager != NULL)
        {
            // Get total DCA expansions from both directions
            int buy_expansions = m_grid_manager.GetDirectionDCAExpansions(GRID_DIRECTION_BUY);
            int sell_expansions = m_grid_manager.GetDirectionDCAExpansions(GRID_DIRECTION_SELL);
            return MathMax(buy_expansions, sell_expansions); // Return highest expansion count
        }
        return 0; 
    }
    
    bool IsEmergencyShutdownRequested() { return m_emergency_shutdown_requested; }
    string GetEmergencyReason() { return m_emergency_reason; }
    
    string GetStatusString()
    {
        return StringFormat("LC#%d: State=%d | Profit=$%.2f | Risk=$%.2f | Pos=%d", 
                           m_id, m_state, m_current_profit, m_current_risk, GetLifecyclePositionCount());
    }
    
    // NEW: Calculate total profit from both directions
    double CalculateTotalProfit()
    {
        if(m_grid_manager == NULL) return 0.0;
        
        double buy_profit = m_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
        double sell_profit = m_grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
        return buy_profit + sell_profit;
    }
    
    // NEW: Place DCA rescue orders
    void PlaceDCAOrders()
    {
        if(m_grid_manager == NULL) return;
        
        Print("🚨 LIFECYCLE #", m_id, " PLACING DCA RESCUE ORDERS");
        
        // Force DCA expansion through grid manager
        if(m_grid_manager.ForceDCARescue(GRID_DIRECTION_BUY))
        {
            Print("✅ LIFECYCLE #", m_id, " DCA BUY STOP orders placed");
        }
        
        if(m_grid_manager.ForceDCARescue(GRID_DIRECTION_SELL))
        {
            Print("✅ LIFECYCLE #", m_id, " DCA SELL STOP orders placed");
        }
    }
};

//+------------------------------------------------------------------+
