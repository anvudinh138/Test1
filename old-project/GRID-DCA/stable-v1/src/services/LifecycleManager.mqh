//+------------------------------------------------------------------+
//|                                          LifecycleManager.mqh   |
//|                                       FlexGridDCA EA v4.0.0      |
//|                                  Multi-Lifecycle Management      |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <../includes/GridManager_v2.mqh>

//+------------------------------------------------------------------+
//| Lifecycle States                                                |
//+------------------------------------------------------------------+
enum LIFECYCLE_STATE
{
    LIFECYCLE_IDLE,           // Waiting to start
    LIFECYCLE_ACTIVE,         // Grid is running
    LIFECYCLE_DCA_RESCUE,     // DCA rescue activated
    LIFECYCLE_TRAILING,       // Trailing stop active
    LIFECYCLE_CLOSING,        // Closing positions
    LIFECYCLE_COMPLETED       // Lifecycle finished
};

//+------------------------------------------------------------------+
//| Single Lifecycle Structure                                      |
//+------------------------------------------------------------------+
struct SLifecycle
{
    int                 id;                    // Unique lifecycle ID
    datetime            start_time;            // When lifecycle started
    datetime            last_update;           // Last update time
    LIFECYCLE_STATE     state;                 // Current state
    
    // Grid Management
    CGridManagerV2*     grid_manager;          // Dedicated grid manager
    double              initial_balance;       // Starting balance for this lifecycle
    
    // Profit/Loss Tracking
    double              total_profit;          // Current total profit
    double              max_profit;            // Peak profit reached
    double              max_loss;              // Maximum loss experienced
    double              profit_target;         // Target profit for this lifecycle
    double              stop_loss;             // Stop loss for this lifecycle
    
    // DCA Status
    bool                dca_activated;         // DCA rescue activated
    int                 dca_expansions;        // Number of DCA expansions
    
    // Trailing Stop
    bool                trailing_active;       // Trailing stop active
    double              trailing_threshold;    // Current trailing threshold
    bool                partial_profit_taken;  // 50% profit taken
    
    // Lifecycle Settings
    int                 max_grid_levels;       // Grid levels for this lifecycle
    double              fixed_lot_size;        // Lot size for this lifecycle
    double              atr_multiplier;        // ATR multiplier
    
    // Timing
    int                 min_interval_minutes;  // Minimum interval before new lifecycle
    datetime            next_allowed_start;    // When next lifecycle can start
    
    // Status
    bool                is_active;             // Is this lifecycle active
    string              status_message;        // Current status description
};

//+------------------------------------------------------------------+
//| Lifecycle Manager Class                                         |
//+------------------------------------------------------------------+
class CLifecycleManager
{
private:
    SLifecycle          m_lifecycles[];        // Array of lifecycles
    int                 m_next_id;             // Next lifecycle ID
    int                 m_max_concurrent;      // Max concurrent lifecycles
    datetime            m_last_cleanup;        // Last cleanup time
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CLifecycleManager()
    {
        m_next_id = 1;
        m_max_concurrent = 3; // Allow up to 3 concurrent lifecycles
        m_last_cleanup = 0;
        ArrayResize(m_lifecycles, 0);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CLifecycleManager()
    {
        CleanupAllLifecycles();
    }
    
    //+------------------------------------------------------------------+
    //| Create New Lifecycle                                            |
    //+------------------------------------------------------------------+
    int CreateLifecycle(double profit_target, double stop_loss, int grid_levels, double lot_size, int interval_minutes = 25)
    {
        // Check if we can create new lifecycle
        if(GetActiveLifecycleCount() >= m_max_concurrent)
        {
            Print("⚠️ LIFECYCLE: Cannot create new lifecycle - Max concurrent limit reached (", m_max_concurrent, ")");
            return -1;
        }
        
        // Check timing constraints
        datetime current_time = TimeCurrent();
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(m_lifecycles[i].next_allowed_start > current_time)
            {
                Print("⚠️ LIFECYCLE: Must wait ", (m_lifecycles[i].next_allowed_start - current_time) / 60, " minutes before new lifecycle");
                return -1;
            }
        }
        
        // Create new lifecycle
        int new_size = ArraySize(m_lifecycles) + 1;
        ArrayResize(m_lifecycles, new_size);
        int index = new_size - 1;
        
        // Initialize lifecycle
        m_lifecycles[index].id = m_next_id++;
        m_lifecycles[index].start_time = current_time;
        m_lifecycles[index].last_update = current_time;
        m_lifecycles[index].state = LIFECYCLE_IDLE;
        
        // Create dedicated grid manager
        m_lifecycles[index].grid_manager = new CGridManagerV2();
        m_lifecycles[index].grid_manager.Initialize(_Symbol, grid_levels, lot_size);
        
        // Set targets and limits
        m_lifecycles[index].profit_target = profit_target;
        m_lifecycles[index].stop_loss = stop_loss;
        m_lifecycles[index].max_grid_levels = grid_levels;
        m_lifecycles[index].fixed_lot_size = lot_size;
        
        // Initialize tracking
        m_lifecycles[index].total_profit = 0.0;
        m_lifecycles[index].max_profit = 0.0;
        m_lifecycles[index].max_loss = 0.0;
        m_lifecycles[index].initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        // Initialize flags
        m_lifecycles[index].dca_activated = false;
        m_lifecycles[index].dca_expansions = 0;
        m_lifecycles[index].trailing_active = false;
        m_lifecycles[index].partial_profit_taken = false;
        m_lifecycles[index].is_active = true;
        
        // Set timing
        m_lifecycles[index].min_interval_minutes = interval_minutes;
        m_lifecycles[index].next_allowed_start = current_time + (interval_minutes * 60);
        
        m_lifecycles[index].status_message = "Lifecycle created - Ready to start";
        
        Print("🚀 LIFECYCLE #", m_lifecycles[index].id, " CREATED: Target=$", DoubleToString(profit_target, 2), " StopLoss=$", DoubleToString(stop_loss, 2), " Levels=", grid_levels);
        
        return m_lifecycles[index].id;
    }
    
    //+------------------------------------------------------------------+
    //| Update All Lifecycles                                          |
    //+------------------------------------------------------------------+
    void UpdateAll()
    {
        datetime current_time = TimeCurrent();
        
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(!m_lifecycles[i].is_active) continue;
            
            UpdateLifecycle(i);
            m_lifecycles[i].last_update = current_time;
        }
        
        // Cleanup completed lifecycles periodically
        if(current_time - m_last_cleanup > 300) // Every 5 minutes
        {
            CleanupCompletedLifecycles();
            m_last_cleanup = current_time;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Update Single Lifecycle                                        |
    //+------------------------------------------------------------------+
    void UpdateLifecycle(int index)
    {
        if(index < 0 || index >= ArraySize(m_lifecycles)) return;
        
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Update profit tracking
        if(lifecycle.grid_manager != NULL)
        {
            double buy_profit = lifecycle.grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_BUY);
            double sell_profit = lifecycle.grid_manager.CalculateDirectionTotalProfit(GRID_DIRECTION_SELL);
            lifecycle.total_profit = buy_profit + sell_profit;
            
            // Update max profit/loss
            if(lifecycle.total_profit > lifecycle.max_profit)
                lifecycle.max_profit = lifecycle.total_profit;
            if(lifecycle.total_profit < lifecycle.max_loss)
                lifecycle.max_loss = lifecycle.total_profit;
        }
        
        // State machine logic
        switch(lifecycle.state)
        {
            case LIFECYCLE_IDLE:
                HandleIdleState(index);
                break;
                
            case LIFECYCLE_ACTIVE:
                HandleActiveState(index);
                break;
                
            case LIFECYCLE_DCA_RESCUE:
                HandleDCARescueState(index);
                break;
                
            case LIFECYCLE_TRAILING:
                HandleTrailingState(index);
                break;
                
            case LIFECYCLE_CLOSING:
                HandleClosingState(index);
                break;
        }
    }
    
    //+------------------------------------------------------------------+
    //| State Handlers                                                  |
    //+------------------------------------------------------------------+
    void HandleIdleState(int index)
    {
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Start the grid
        if(lifecycle.grid_manager != NULL)
        {
            lifecycle.grid_manager.SetupDualGrid();
            lifecycle.state = LIFECYCLE_ACTIVE;
            lifecycle.status_message = "Grid activated - Trading started";
            Print("📊 LIFECYCLE #", lifecycle.id, " STARTED: Grid setup complete");
        }
    }
    
    void HandleActiveState(int index)
    {
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Check for stop loss
        if(lifecycle.total_profit <= -lifecycle.stop_loss)
        {
            lifecycle.state = LIFECYCLE_CLOSING;
            lifecycle.status_message = "Stop loss hit - Closing positions";
            Print("🛑 LIFECYCLE #", lifecycle.id, " STOP LOSS: $", DoubleToString(lifecycle.total_profit, 2));
            return;
        }
        
        // Check for DCA trigger
        if(!lifecycle.dca_activated && lifecycle.grid_manager != NULL)
        {
            if(lifecycle.grid_manager.CheckSmartDCAExpansion())
            {
                lifecycle.dca_activated = true;
                lifecycle.state = LIFECYCLE_DCA_RESCUE;
                lifecycle.status_message = "DCA rescue activated";
                Print("🚨 LIFECYCLE #", lifecycle.id, " DCA ACTIVATED");
            }
        }
        
        // Check for profit target (trailing activation)
        if(lifecycle.total_profit >= lifecycle.profit_target)
        {
            lifecycle.state = LIFECYCLE_TRAILING;
            lifecycle.trailing_active = true;
            lifecycle.trailing_threshold = lifecycle.total_profit * 0.7;
            lifecycle.status_message = "Profit target reached - Trailing active";
            Print("🎯 LIFECYCLE #", lifecycle.id, " TRAILING ACTIVATED: $", DoubleToString(lifecycle.total_profit, 2));
        }
        
        // Update grid
        if(lifecycle.grid_manager != NULL)
        {
            lifecycle.grid_manager.UpdateGridStatus();
            lifecycle.grid_manager.PlaceGridOrders();
        }
    }
    
    void HandleDCARescueState(int index)
    {
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Continue normal operations but with DCA active
        HandleActiveState(index);
        
        // Additional DCA-specific logic can be added here
    }
    
    void HandleTrailingState(int index)
    {
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Update trailing threshold
        if(lifecycle.total_profit > lifecycle.max_profit * 0.8)
        {
            double new_threshold = lifecycle.total_profit * 0.7;
            if(new_threshold > lifecycle.trailing_threshold)
            {
                lifecycle.trailing_threshold = new_threshold;
                Print("🔄 LIFECYCLE #", lifecycle.id, " TRAILING UPDATED: $", DoubleToString(lifecycle.trailing_threshold, 2));
            }
        }
        
        // Check trailing stop
        if(lifecycle.total_profit <= lifecycle.trailing_threshold)
        {
            lifecycle.state = LIFECYCLE_CLOSING;
            lifecycle.status_message = "Trailing stop triggered - Closing";
            Print("🏃 LIFECYCLE #", lifecycle.id, " TRAILING STOP: $", DoubleToString(lifecycle.total_profit, 2));
        }
        
        // Continue grid operations
        if(lifecycle.grid_manager != NULL)
        {
            lifecycle.grid_manager.UpdateGridStatus();
        }
    }
    
    void HandleClosingState(int index)
    {
        SLifecycle& lifecycle = m_lifecycles[index];
        
        // Close all positions for this lifecycle
        if(lifecycle.grid_manager != NULL)
        {
            lifecycle.grid_manager.CloseAllGridPositions();
            
            // Check if all positions are closed
            int total_positions = PositionsTotal();
            bool all_closed = true;
            
            for(int i = 0; i < total_positions; i++)
            {
                ulong ticket = PositionGetTicket(i);
                if(PositionSelectByTicket(ticket))
                {
                    string comment = PositionGetString(POSITION_COMMENT);
                    if(StringFind(comment, "Grid_") >= 0)
                    {
                        all_closed = false;
                        break;
                    }
                }
            }
            
            if(all_closed)
            {
                lifecycle.state = LIFECYCLE_COMPLETED;
                lifecycle.status_message = "Lifecycle completed";
                Print("✅ LIFECYCLE #", lifecycle.id, " COMPLETED: Final profit $", DoubleToString(lifecycle.total_profit, 2));
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Utility Functions                                              |
    //+------------------------------------------------------------------+
    int GetActiveLifecycleCount()
    {
        int count = 0;
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(m_lifecycles[i].is_active && m_lifecycles[i].state != LIFECYCLE_COMPLETED)
                count++;
        }
        return count;
    }
    
    void CleanupCompletedLifecycles()
    {
        for(int i = ArraySize(m_lifecycles) - 1; i >= 0; i--)
        {
            if(m_lifecycles[i].state == LIFECYCLE_COMPLETED)
            {
                if(m_lifecycles[i].grid_manager != NULL)
                {
                    delete m_lifecycles[i].grid_manager;
                    m_lifecycles[i].grid_manager = NULL;
                }
                
                // Remove from array
                for(int j = i; j < ArraySize(m_lifecycles) - 1; j++)
                {
                    m_lifecycles[j] = m_lifecycles[j + 1];
                }
                ArrayResize(m_lifecycles, ArraySize(m_lifecycles) - 1);
                
                Print("🧹 LIFECYCLE CLEANUP: Removed completed lifecycle");
            }
        }
    }
    
    void CleanupAllLifecycles()
    {
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(m_lifecycles[i].grid_manager != NULL)
            {
                delete m_lifecycles[i].grid_manager;
                m_lifecycles[i].grid_manager = NULL;
            }
        }
        ArrayResize(m_lifecycles, 0);
    }
    
    //+------------------------------------------------------------------+
    //| Get Lifecycle Status                                           |
    //+------------------------------------------------------------------+
    string GetLifecycleStatus(int lifecycle_id)
    {
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(m_lifecycles[i].id == lifecycle_id)
            {
                return StringFormat("LC#%d: %s | Profit: $%.2f | State: %d", 
                    lifecycle_id, m_lifecycles[i].status_message, 
                    m_lifecycles[i].total_profit, m_lifecycles[i].state);
            }
        }
        return "Lifecycle not found";
    }
    
    string GetAllLifecyclesStatus()
    {
        string status = "=== LIFECYCLES STATUS ===\n";
        status += StringFormat("Active: %d/%d\n", GetActiveLifecycleCount(), m_max_concurrent);
        
        for(int i = 0; i < ArraySize(m_lifecycles); i++)
        {
            if(m_lifecycles[i].is_active)
            {
                status += GetLifecycleStatus(m_lifecycles[i].id) + "\n";
            }
        }
        
        return status;
    }
};

//+------------------------------------------------------------------+
