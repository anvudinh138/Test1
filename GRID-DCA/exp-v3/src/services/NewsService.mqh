//+------------------------------------------------------------------+
//|                                             NewsService.mqh      |
//|                                       FlexGridDCA EA v3.2.0      |
//|                            Advanced News Filter & Calendar       |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <services/SettingsService.mqh>

//+------------------------------------------------------------------+
//| News Event Structure                                             |
//+------------------------------------------------------------------+
struct SNewsEvent
{
    datetime event_time;       // Event timestamp
    string   event_name;       // Event name (NFP, FOMC, etc.)
    string   currency;         // Affected currency
    string   impact_level;     // LOW, MEDIUM, HIGH
    string   description;      // Event description
    bool     is_active;        // Whether to filter this event
    int      avoid_minutes_before;  // Minutes to avoid before
    int      avoid_minutes_after;   // Minutes to avoid after
};

//+------------------------------------------------------------------+
//| Market Session Structure                                         |
//+------------------------------------------------------------------+
struct SMarketSession
{
    string session_name;       // Session name (Asian, European, US)
    int    start_hour_gmt;     // Start hour in GMT
    int    end_hour_gmt;       // End hour in GMT
    bool   is_high_activity;   // High volatility session
    double volatility_factor;  // Volatility multiplier
};

//+------------------------------------------------------------------+
//| News Service                                                     |
//| Advanced news filtering and market session management           |
//+------------------------------------------------------------------+
class CNewsService
{
private:
    static CNewsService* m_instance;
    
    SNewsEvent m_scheduled_events[];       // Predefined high-impact events
    SMarketSession m_market_sessions[];    // Trading sessions
    
    bool   m_is_initialized;
    bool   m_trading_paused;
    string m_pause_reason;
    datetime m_pause_until;
    datetime m_last_check_time;
    
    CNewsService()
    {
        m_is_initialized = false;
        m_trading_paused = false;
        m_pause_reason = "";
        m_pause_until = 0;
        m_last_check_time = 0;
        
        InitializeScheduledEvents();
        InitializeMarketSessions();
    }
    
    //+------------------------------------------------------------------+
    //| Initialize High-Impact News Events                             |
    //+------------------------------------------------------------------+
    void InitializeScheduledEvents()
    {
        ArrayResize(m_scheduled_events, 20);
        
        // NFP (Non-Farm Payrolls) - First Friday of month
        m_scheduled_events[0].event_name = "NFP";
        m_scheduled_events[0].currency = "USD";
        m_scheduled_events[0].impact_level = "HIGH";
        m_scheduled_events[0].description = "US Non-Farm Payrolls";
        m_scheduled_events[0].is_active = true;
        m_scheduled_events[0].avoid_minutes_before = 30;
        m_scheduled_events[0].avoid_minutes_after = 60;
        
        // FOMC Rate Decision
        m_scheduled_events[1].event_name = "FOMC";
        m_scheduled_events[1].currency = "USD";
        m_scheduled_events[1].impact_level = "HIGH";
        m_scheduled_events[1].description = "Federal Open Market Committee Rate Decision";
        m_scheduled_events[1].is_active = true;
        m_scheduled_events[1].avoid_minutes_before = 60;
        m_scheduled_events[1].avoid_minutes_after = 120;
        
        // CPI (Consumer Price Index)
        m_scheduled_events[2].event_name = "CPI";
        m_scheduled_events[2].currency = "USD";
        m_scheduled_events[2].impact_level = "HIGH";
        m_scheduled_events[2].description = "US Consumer Price Index";
        m_scheduled_events[2].is_active = true;
        m_scheduled_events[2].avoid_minutes_before = 15;
        m_scheduled_events[2].avoid_minutes_after = 30;
        
        // GDP (Gross Domestic Product)
        m_scheduled_events[3].event_name = "GDP";
        m_scheduled_events[3].currency = "USD";
        m_scheduled_events[3].impact_level = "MEDIUM";
        m_scheduled_events[3].description = "US Gross Domestic Product";
        m_scheduled_events[3].is_active = true;
        m_scheduled_events[3].avoid_minutes_before = 15;
        m_scheduled_events[3].avoid_minutes_after = 30;
        
        // PMI (Purchasing Managers Index)
        m_scheduled_events[4].event_name = "PMI";
        m_scheduled_events[4].currency = "USD";
        m_scheduled_events[4].impact_level = "MEDIUM";
        m_scheduled_events[4].description = "US Manufacturing PMI";
        m_scheduled_events[4].is_active = true;
        m_scheduled_events[4].avoid_minutes_before = 10;
        m_scheduled_events[4].avoid_minutes_after = 20;
        
        // ECB Rate Decision
        m_scheduled_events[5].event_name = "ECB";
        m_scheduled_events[5].currency = "EUR";
        m_scheduled_events[5].impact_level = "HIGH";
        m_scheduled_events[5].description = "European Central Bank Rate Decision";
        m_scheduled_events[5].is_active = true;
        m_scheduled_events[5].avoid_minutes_before = 30;
        m_scheduled_events[5].avoid_minutes_after = 60;
        
        // BOE Rate Decision
        m_scheduled_events[6].event_name = "BOE";
        m_scheduled_events[6].currency = "GBP";
        m_scheduled_events[6].impact_level = "HIGH";
        m_scheduled_events[6].description = "Bank of England Rate Decision";
        m_scheduled_events[6].is_active = true;
        m_scheduled_events[6].avoid_minutes_before = 30;
        m_scheduled_events[6].avoid_minutes_after = 60;
        
        // BOJ Rate Decision
        m_scheduled_events[7].event_name = "BOJ";
        m_scheduled_events[7].currency = "JPY";
        m_scheduled_events[7].impact_level = "HIGH";
        m_scheduled_events[7].description = "Bank of Japan Rate Decision";
        m_scheduled_events[7].is_active = true;
        m_scheduled_events[7].avoid_minutes_before = 30;
        m_scheduled_events[7].avoid_minutes_after = 60;
        
        Print("✅ News Service: ", ArraySize(m_scheduled_events), " high-impact events configured");
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Market Sessions                                      |
    //+------------------------------------------------------------------+
    void InitializeMarketSessions()
    {
        ArrayResize(m_market_sessions, 4);
        
        // Asian Session (Tokyo)
        m_market_sessions[0].session_name = "ASIAN";
        m_market_sessions[0].start_hour_gmt = 23;  // 23:00 GMT (previous day)
        m_market_sessions[0].end_hour_gmt = 8;     // 08:00 GMT
        m_market_sessions[0].is_high_activity = false;
        m_market_sessions[0].volatility_factor = 0.7;
        
        // European Session (London)
        m_market_sessions[1].session_name = "EUROPEAN";
        m_market_sessions[1].start_hour_gmt = 7;   // 07:00 GMT
        m_market_sessions[1].end_hour_gmt = 16;    // 16:00 GMT
        m_market_sessions[1].is_high_activity = true;
        m_market_sessions[1].volatility_factor = 1.2;
        
        // US Session (New York)
        m_market_sessions[2].session_name = "US";
        m_market_sessions[2].start_hour_gmt = 13;  // 13:00 GMT
        m_market_sessions[2].end_hour_gmt = 22;    // 22:00 GMT
        m_market_sessions[2].is_high_activity = true;
        m_market_sessions[2].volatility_factor = 1.3;
        
        // Overlap Session (London-New York)
        m_market_sessions[3].session_name = "OVERLAP";
        m_market_sessions[3].start_hour_gmt = 13;  // 13:00 GMT
        m_market_sessions[3].end_hour_gmt = 16;    // 16:00 GMT
        m_market_sessions[3].is_high_activity = true;
        m_market_sessions[3].volatility_factor = 1.5;
        
        Print("✅ News Service: ", ArraySize(m_market_sessions), " market sessions configured");
    }
    
    //+------------------------------------------------------------------+
    //| Check for Scheduled News Events (Pattern-based)               |
    //+------------------------------------------------------------------+
    bool IsScheduledNewsTime(datetime current_time)
    {
        MqlDateTime dt;
        TimeToStruct(current_time, dt);
        
        // NFP - First Friday of month at 13:30 GMT
        if(dt.day_of_week == 5 && dt.day <= 7) // First Friday
        {
            if(dt.hour == 13 && dt.min >= 0 && dt.min <= 60) // 13:30 GMT ± 30min
            {
                m_pause_reason = "NFP Release (Non-Farm Payrolls)";
                return true;
            }
        }
        
        // CPI - Usually mid-month Tuesday/Wednesday at 13:30 GMT
        if((dt.day_of_week == 2 || dt.day_of_week == 3) && dt.day >= 10 && dt.day <= 20)
        {
            if(dt.hour == 13 && dt.min >= 15 && dt.min <= 45) // 13:30 GMT ± 15min
            {
                m_pause_reason = "CPI Release (Consumer Price Index)";
                return true;
            }
        }
        
        // FOMC - Every 6-8 weeks on Wednesday at 19:00 GMT
        if(dt.day_of_week == 3 && dt.hour == 19 && dt.min >= 0 && dt.min <= 60)
        {
            m_pause_reason = "FOMC Meeting (Federal Reserve)";
            return true;
        }
        
        // ECB - First Thursday of month at 12:45 GMT (Rate) and 13:30 GMT (Press Conference)
        if(dt.day_of_week == 4 && dt.day <= 7)
        {
            if((dt.hour == 12 && dt.min >= 30) || (dt.hour == 13 && dt.min <= 45))
            {
                m_pause_reason = "ECB Rate Decision & Press Conference";
                return true;
            }
        }
        
        // High-impact US data at 13:30 GMT (8:30 EST)
        if(dt.hour == 13 && dt.min >= 15 && dt.min <= 45)
        {
            // Check if it's a weekday with potential high-impact data
            if(dt.day_of_week >= 2 && dt.day_of_week <= 4) // Tuesday to Thursday
            {
                m_pause_reason = "Potential High-Impact US Economic Data";
                return true;
            }
        }
        
        return false;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CNewsService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CNewsService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize News Service                                          |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        m_is_initialized = true;
        
        if(CSettingsService::LogLevel >= 2) // INFO
        {
            Print("✅ News Service initialized");
            Print("  ├─ News Filter: ", (CSettingsService::UseNewsFilter ? "ENABLED" : "DISABLED"));
            Print("  ├─ Friday Close Avoidance: ", (CSettingsService::AvoidFridayClose ? "ENABLED" : "DISABLED"));
            Print("  ├─ Avoid Minutes: ", CSettingsService::NewsAvoidMinutes);
            Print("  └─ Monitored Events: ", CSettingsService::NewsEvents);
        }
        
        return m_is_initialized;
    }
    
    //+------------------------------------------------------------------+
    //| Check if Trading is Allowed (Main Method)                      |
    //+------------------------------------------------------------------+
    bool IsTradingAllowed()
    {
        if(!CSettingsService::UseNewsFilter) return true;
        
        datetime current_time = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(current_time, dt);
        
        // Check Friday close avoidance (2 hours before market close)
        if(CSettingsService::AvoidFridayClose && dt.day_of_week == 5) // Friday
        {
            // Market typically closes at 22:00 GMT Friday
            // Avoid trading after 20:00 GMT
            if(dt.hour >= 20)
            {
                if(!m_trading_paused || m_pause_reason != "Friday Market Close")
                {
                    m_trading_paused = true;
                    m_pause_reason = "Friday Market Close";
                    m_pause_until = current_time + (2 * 60 * 60); // 2 hours
                    
                    if(CSettingsService::LogLevel >= 1) // WARNING
                        Print("⚠️ Trading paused: ", m_pause_reason);
                }
                return false;
            }
        }
        
        // Check scheduled news events
        if(IsScheduledNewsTime(current_time))
        {
            if(!m_trading_paused)
            {
                m_trading_paused = true;
                m_pause_until = current_time + (CSettingsService::NewsAvoidMinutes * 60);
                
                if(CSettingsService::LogLevel >= 1) // WARNING
                    Print("⚠️ Trading paused: ", m_pause_reason, " (", CSettingsService::NewsAvoidMinutes, " minutes)");
            }
            return false;
        }
        
        // Check if pause period has ended
        if(m_trading_paused && current_time >= m_pause_until)
        {
            m_trading_paused = false;
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("✅ Trading resumed after news event: ", m_pause_reason);
            m_pause_reason = "";
            m_pause_until = 0;
        }
        
        return !m_trading_paused;
    }
    
    //+------------------------------------------------------------------+
    //| Get Current Market Session                                      |
    //+------------------------------------------------------------------+
    SMarketSession GetCurrentSession()
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int current_hour = dt.hour; // GMT
        
        // Check each session
        for(int i = 0; i < ArraySize(m_market_sessions); i++)
        {
            SMarketSession session = m_market_sessions[i];
            
            bool in_session = false;
            
            // Handle sessions that cross midnight
            if(session.start_hour_gmt > session.end_hour_gmt)
            {
                in_session = (current_hour >= session.start_hour_gmt || current_hour < session.end_hour_gmt);
            }
            else
            {
                in_session = (current_hour >= session.start_hour_gmt && current_hour < session.end_hour_gmt);
            }
            
            if(in_session)
            {
                if(CSettingsService::LogLevel >= 3) // DEBUG
                    Print("🌍 Current session: ", session.session_name, " (Volatility: ", session.volatility_factor, ")");
                
                return session;
            }
        }
        
        // Return default session if none found
        SMarketSession default_session;
        default_session.session_name = "UNKNOWN";
        default_session.start_hour_gmt = 0;
        default_session.end_hour_gmt = 24;
        default_session.is_high_activity = false;
        default_session.volatility_factor = 1.0;
        
        return default_session;
    }
    
    //+------------------------------------------------------------------+
    //| Get Trading Status Info                                         |
    //+------------------------------------------------------------------+
    string GetTradingStatus()
    {
        if(!CSettingsService::UseNewsFilter) return "News Filter Disabled";
        
        if(m_trading_paused)
        {
            int minutes_remaining = (int)((m_pause_until - TimeCurrent()) / 60);
            return m_pause_reason + " (" + IntegerToString(MathMax(0, minutes_remaining)) + "min remaining)";
        }
        
        SMarketSession current_session = GetCurrentSession();
        return "Trading Allowed - " + current_session.session_name + " Session";
    }
    
    //+------------------------------------------------------------------+
    //| Check if Symbol is Affected by News                            |
    //+------------------------------------------------------------------+
    bool IsSymbolAffectedByNews(string symbol, string news_currency)
    {
        // Check if symbol contains the news currency
        return (StringFind(symbol, news_currency) >= 0);
    }
    
    //+------------------------------------------------------------------+
    //| Force Pause Trading                                             |
    //+------------------------------------------------------------------+
    void ForcePause(string reason, int minutes)
    {
        m_trading_paused = true;
        m_pause_reason = "MANUAL: " + reason;
        m_pause_until = TimeCurrent() + (minutes * 60);
        
        if(CSettingsService::LogLevel >= 1) // WARNING
            Print("⚠️ Trading manually paused: ", reason, " (", minutes, " minutes)");
    }
    
    //+------------------------------------------------------------------+
    //| Force Resume Trading                                            |
    //+------------------------------------------------------------------+
    void ForceResume()
    {
        if(m_trading_paused)
        {
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("✅ Trading manually resumed (was: ", m_pause_reason, ")");
        }
        
        m_trading_paused = false;
        m_pause_reason = "";
        m_pause_until = 0;
    }
    
    //+------------------------------------------------------------------+
    //| Get Next Known News Event                                       |
    //+------------------------------------------------------------------+
    string GetNextNewsEvent()
    {
        datetime current_time = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(current_time, dt);
        
        // Simple prediction of next major events
        string next_events = "";
        
        // Check if this week has NFP (first Friday)
        if(dt.day <= 7 && dt.day_of_week < 5)
        {
            next_events += "NFP (This Friday 13:30 GMT); ";
        }
        
        // Check for mid-month CPI
        if(dt.day >= 10 && dt.day <= 20 && dt.day_of_week < 3)
        {
            next_events += "CPI (Mid-month 13:30 GMT); ";
        }
        
        if(next_events == "")
            next_events = "No major events detected for immediate future";
        else
            StringReplace(next_events, "; ", "");
        
        return next_events;
    }
    
    //+------------------------------------------------------------------+
    //| Print News Service Status                                       |
    //+------------------------------------------------------------------+
    void PrintStatus()
    {
        Print("=== NEWS SERVICE STATUS ===");
        Print("Filter Enabled: ", (CSettingsService::UseNewsFilter ? "YES" : "NO"));
        Print("Trading Status: ", GetTradingStatus());
        Print("Current Session: ", GetCurrentSession().session_name);
        Print("Next Events: ", GetNextNewsEvent());
        Print("============================");
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup                                                          |
    //+------------------------------------------------------------------+
    static void Cleanup()
    {
        if(m_instance != NULL)
        {
            delete m_instance;
            m_instance = NULL;
        }
    }
};

// Static member definition
CNewsService* CNewsService::m_instance = NULL;

//+------------------------------------------------------------------+
