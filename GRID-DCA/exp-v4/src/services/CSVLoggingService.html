//+------------------------------------------------------------------+
//|                                       CSVLoggingService.mqh      |
//|                                       FlexGridDCA EA v3.2.0      |
//|                            Independent CSV Logging & Analytics   |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <services/SettingsService.mqh>

//+------------------------------------------------------------------+
//| Log Entry Structure                                              |
//+------------------------------------------------------------------+
struct SLogEntry
{
    datetime timestamp;
    string   symbol;
    string   event_type;      // TRADE, PROFIT, LOSS, SYSTEM, etc.
    string   event_category;  // BUY, SELL, SETUP, CLOSE, etc.
    string   message;
    double   price;
    double   volume;
    double   profit;
    double   balance;
    double   equity;
    double   drawdown_percent;
    double   margin_level;
    string   additional_data; // JSON-like string for extra data
};

//+------------------------------------------------------------------+
//| CSV Logging Service                                             |
//| Advanced logging system with multiple file outputs             |
//+------------------------------------------------------------------+
class CCSVLoggingService
{
private:
    static CCSVLoggingService* m_instance;
    
    // File handles
    int m_main_log_handle;        // Main trading log
    int m_trades_log_handle;      // Trades-only log
    int m_profits_log_handle;     // Profits tracking log
    int m_system_log_handle;      // System events log
    
    // Configuration
    string m_base_filename;
    bool   m_is_initialized;
    datetime m_last_export_time;
    int    m_export_interval_seconds;
    
    // Statistics
    int    m_total_entries_logged;
    int    m_trades_logged;
    int    m_errors_logged;
    
    CCSVLoggingService()
    {
        m_main_log_handle = INVALID_HANDLE;
        m_trades_log_handle = INVALID_HANDLE;
        m_profits_log_handle = INVALID_HANDLE;
        m_system_log_handle = INVALID_HANDLE;
        m_is_initialized = false;
        m_last_export_time = 0;
        m_export_interval_seconds = 300; // 5 minutes default
        m_total_entries_logged = 0;
        m_trades_logged = 0;
        m_errors_logged = 0;
    }
    
    //+------------------------------------------------------------------+
    //| Generate Filename with Timestamp                               |
    //+------------------------------------------------------------------+
    string GenerateFilename(string prefix, string suffix = ".csv")
    {
        string date_str = TimeToString(TimeCurrent(), TIME_DATE);
        date_str = StringReplace(date_str, ":", "-");
        date_str = StringReplace(date_str, " ", "_");
        
        return prefix + "_" + m_base_filename + "_" + date_str + suffix;
    }
    
    //+------------------------------------------------------------------+
    //| Create CSV File with Header                                     |
    //+------------------------------------------------------------------+
    int CreateCSVFile(string filename, string header)
    {
        int file_handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON);
        
        if(file_handle != INVALID_HANDLE)
        {
            FileWriteString(file_handle, header + "\n");
            FileFlush(file_handle);
            
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("✅ CSV file created: ", filename);
        }
        else
        {
            if(CSettingsService::LogLevel >= 0) // ERROR
                Print("❌ Failed to create CSV file: ", filename);
        }
        
        return file_handle;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CCSVLoggingService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CCSVLoggingService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Logging System                                       |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, string ea_name = "FlexGridDCA")
    {
        if(!CSettingsService::EnableCSVExport)
        {
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("ℹ️ CSV Export disabled in settings");
            return true;
        }
        
        m_base_filename = ea_name + "_" + symbol;
        
        // Create main trading log
        string main_header = "Timestamp,Symbol,EventType,Category,Message,Price,Volume,Profit,Balance,Equity,DrawdownPct,MarginLevel,AdditionalData";
        m_main_log_handle = CreateCSVFile(GenerateFilename("MainLog"), main_header);
        
        // Create trades-only log
        string trades_header = "Timestamp,Symbol,Action,Price,Volume,Ticket,Comment,Profit,Commission,Swap";
        m_trades_log_handle = CreateCSVFile(GenerateFilename("Trades"), trades_header);
        
        // Create profits tracking log
        string profits_header = "Timestamp,Symbol,BuyProfit,SellProfit,TotalProfit,Target,Balance,Equity,Positions,Orders,Status";
        m_profits_log_handle = CreateCSVFile(GenerateFilename("Profits"), profits_header);
        
        // Create system events log
        string system_header = "Timestamp,EventType,Level,Category,Message,ErrorCode";
        m_system_log_handle = CreateCSVFile(GenerateFilename("System"), system_header);
        
        m_is_initialized = (m_main_log_handle != INVALID_HANDLE);
        
        if(m_is_initialized)
        {
            LogSystemEvent("INIT", "INFO", "CSV Logging Service initialized for " + symbol);
            Print("✅ CSV Logging Service initialized successfully");
        }
        
        return m_is_initialized;
    }
    
    //+------------------------------------------------------------------+
    //| Log General Entry                                               |
    //+------------------------------------------------------------------+
    void LogEntry(SLogEntry &entry)
    {
        if(!m_is_initialized || m_main_log_handle == INVALID_HANDLE) return;
        
        FileWrite(m_main_log_handle,
                  TimeToString(entry.timestamp),
                  entry.symbol,
                  entry.event_type,
                  entry.event_category,
                  entry.message,
                  DoubleToString(entry.price, _Digits),
                  DoubleToString(entry.volume, 3),
                  DoubleToString(entry.profit, 2),
                  DoubleToString(entry.balance, 2),
                  DoubleToString(entry.equity, 2),
                  DoubleToString(entry.drawdown_percent, 2),
                  DoubleToString(entry.margin_level, 2),
                  entry.additional_data);
        
        FileFlush(m_main_log_handle);
        m_total_entries_logged++;
        
        if(CSettingsService::EnableDebugMode && CSettingsService::LogLevel >= 3) // DEBUG
        {
            Print("🔍 CSV Entry logged: ", entry.event_type, " - ", entry.message);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Log Trade Event                                                 |
    //+------------------------------------------------------------------+
    void LogTrade(string symbol, string action, double price, double volume, ulong ticket, string comment, double profit = 0, double commission = 0, double swap = 0)
    {
        if(!m_is_initialized || m_trades_log_handle == INVALID_HANDLE) return;
        
        FileWrite(m_trades_log_handle,
                  TimeToString(TimeCurrent()),
                  symbol,
                  action,
                  DoubleToString(price, _Digits),
                  DoubleToString(volume, 3),
                  IntegerToString(ticket),
                  comment,
                  DoubleToString(profit, 2),
                  DoubleToString(commission, 2),
                  DoubleToString(swap, 2));
        
        FileFlush(m_trades_log_handle);
        m_trades_logged++;
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("📊 Trade logged: ", action, " ", symbol, " @ ", DoubleToString(price, _Digits));
    }
    
    //+------------------------------------------------------------------+
    //| Log Profit Snapshot                                             |
    //+------------------------------------------------------------------+
    void LogProfitSnapshot(string symbol, double buy_profit, double sell_profit, double total_profit, double target, double balance, double equity, int positions_count, int orders_count, string status)
    {
        if(!m_is_initialized || m_profits_log_handle == INVALID_HANDLE) return;
        
        FileWrite(m_profits_log_handle,
                  TimeToString(TimeCurrent()),
                  symbol,
                  DoubleToString(buy_profit, 2),
                  DoubleToString(sell_profit, 2),
                  DoubleToString(total_profit, 2),
                  DoubleToString(target, 2),
                  DoubleToString(balance, 2),
                  DoubleToString(equity, 2),
                  IntegerToString(positions_count),
                  IntegerToString(orders_count),
                  status);
        
        FileFlush(m_profits_log_handle);
        
        if(CSettingsService::LogLevel >= 3) // DEBUG
            Print("💰 Profit snapshot logged: $", DoubleToString(total_profit, 2));
    }
    
    //+------------------------------------------------------------------+
    //| Log System Event                                                |
    //+------------------------------------------------------------------+
    void LogSystemEvent(string event_type, string level, string message, int error_code = 0)
    {
        if(!m_is_initialized || m_system_log_handle == INVALID_HANDLE) return;
        
        FileWrite(m_system_log_handle,
                  TimeToString(TimeCurrent()),
                  event_type,
                  level,
                  "SYSTEM",
                  message,
                  IntegerToString(error_code));
        
        FileFlush(m_system_log_handle);
        
        if(level == "ERROR") m_errors_logged++;
        
        // Also print to terminal based on level and settings
        if(level == "ERROR" && CSettingsService::LogLevel >= 0)
            Print("❌ [", event_type, "] ", message, (error_code > 0 ? " (Error: " + IntegerToString(error_code) + ")" : ""));
        else if(level == "WARNING" && CSettingsService::LogLevel >= 1)
            Print("⚠️ [", event_type, "] ", message);
        else if(level == "INFO" && CSettingsService::LogLevel >= 2)
            Print("ℹ️ [", event_type, "] ", message);
        else if(level == "DEBUG" && CSettingsService::LogLevel >= 3)
            Print("🔍 [", event_type, "] ", message);
    }
    
    //+------------------------------------------------------------------+
    //| Auto Export (Periodic)                                          |
    //+------------------------------------------------------------------+
    void AutoExport()
    {
        if(!m_is_initialized) return;
        
        datetime current_time = TimeCurrent();
        
        if(current_time - m_last_export_time >= m_export_interval_seconds)
        {
            // This method can be called periodically to export snapshots
            LogSystemEvent("AUTO_EXPORT", "DEBUG", "Periodic auto-export triggered");
            m_last_export_time = current_time;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Export Grid Status (Comprehensive)                              |
    //+------------------------------------------------------------------+
    void ExportGridStatus(string symbol, string grid_status, int buy_levels, int sell_levels, double buy_profit, double sell_profit, string additional_info = "")
    {
        if(!m_is_initialized) return;
        
        SLogEntry entry;
        entry.timestamp = TimeCurrent();
        entry.symbol = symbol;
        entry.event_type = "GRID_STATUS";
        entry.event_category = "SNAPSHOT";
        entry.message = grid_status;
        entry.price = 0;
        entry.volume = 0;
        entry.profit = buy_profit + sell_profit;
        entry.balance = AccountInfoDouble(ACCOUNT_BALANCE);
        entry.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        entry.drawdown_percent = (entry.balance > 0) ? ((entry.balance - entry.equity) / entry.balance) * 100.0 : 0.0;
        entry.margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        entry.additional_data = StringFormat("{\"buy_levels\":%d,\"sell_levels\":%d,\"buy_profit\":%.2f,\"sell_profit\":%.2f,\"info\":\"%s\"}",
                                           buy_levels, sell_levels, buy_profit, sell_profit, additional_info);
        
        LogEntry(entry);
    }
    
    //+------------------------------------------------------------------+
    //| Set Export Interval                                             |
    //+------------------------------------------------------------------+
    void SetExportInterval(int seconds) { m_export_interval_seconds = seconds; }
    
    //+------------------------------------------------------------------+
    //| Get Statistics                                                   |
    //+------------------------------------------------------------------+
    void PrintStatistics()
    {
        Print("=== CSV LOGGING SERVICE STATISTICS ===");
        Print("Total Entries: ", m_total_entries_logged);
        Print("Trades Logged: ", m_trades_logged);
        Print("Errors Logged: ", m_errors_logged);
        Print("Files Status:");
        Print("  ├─ Main Log: ", (m_main_log_handle != INVALID_HANDLE ? "ACTIVE" : "INACTIVE"));
        Print("  ├─ Trades Log: ", (m_trades_log_handle != INVALID_HANDLE ? "ACTIVE" : "INACTIVE"));
        Print("  ├─ Profits Log: ", (m_profits_log_handle != INVALID_HANDLE ? "ACTIVE" : "INACTIVE"));
        Print("  └─ System Log: ", (m_system_log_handle != INVALID_HANDLE ? "ACTIVE" : "INACTIVE"));
        Print("=====================================");
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup and Close Files                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        if(m_is_initialized)
        {
            LogSystemEvent("SHUTDOWN", "INFO", "CSV Logging Service shutting down");
            
            // Write final statistics to system log
            string stats = StringFormat("Final stats - Entries: %d, Trades: %d, Errors: %d", 
                                      m_total_entries_logged, m_trades_logged, m_errors_logged);
            LogSystemEvent("STATISTICS", "INFO", stats);
        }
        
        // Close all file handles
        if(m_main_log_handle != INVALID_HANDLE)
        {
            FileClose(m_main_log_handle);
            m_main_log_handle = INVALID_HANDLE;
        }
        
        if(m_trades_log_handle != INVALID_HANDLE)
        {
            FileClose(m_trades_log_handle);
            m_trades_log_handle = INVALID_HANDLE;
        }
        
        if(m_profits_log_handle != INVALID_HANDLE)
        {
            FileClose(m_profits_log_handle);
            m_profits_log_handle = INVALID_HANDLE;
        }
        
        if(m_system_log_handle != INVALID_HANDLE)
        {
            FileClose(m_system_log_handle);
            m_system_log_handle = INVALID_HANDLE;
        }
        
        m_is_initialized = false;
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("✅ CSV Logging Service cleaned up");
    }
    
    //+------------------------------------------------------------------+
    //| Static Cleanup                                                  |
    //+------------------------------------------------------------------+
    static void CleanupStatic()
    {
        if(m_instance != NULL)
        {
            m_instance.Cleanup();
            delete m_instance;
            m_instance = NULL;
        }
    }
};

// Static member definition
CCSVLoggingService* CCSVLoggingService::m_instance = NULL;

//+------------------------------------------------------------------+
