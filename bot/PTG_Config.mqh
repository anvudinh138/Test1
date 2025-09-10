//+------------------------------------------------------------------+
//|                                                   PTG_Config.mqh |
//|                        Configuration file for PTG Smart EA       |
//|                                 Optimized parameters by pair      |
//+------------------------------------------------------------------+

#ifndef PTG_CONFIG_MQH
#define PTG_CONFIG_MQH

//+------------------------------------------------------------------+
//| Optimized parameters for different trading pairs                 |
//+------------------------------------------------------------------+
struct PTGConfig
{
    // Core PTG parameters
    double push_range_pct;
    double close_pct;
    double opp_wick_pct;
    double vol_high_mult;
    double vol_low_mult;
    double pullback_max;
    int    test_bars;
    
    // Risk management
    double entry_buffer;
    double sl_buffer;
    double tp_multiplier;
    double risk_percent;
    double max_spread;
    
    // Filters
    bool   use_ema;
    bool   use_vwap;
    bool   use_time_filter;
    string start_time;
    string end_time;
};

//+------------------------------------------------------------------+
//| Get optimized config for specific symbol                         |
//+------------------------------------------------------------------+
PTGConfig GetPTGConfig(const string symbol)
{
    PTGConfig config;
    
    // Default settings
    config.push_range_pct = 0.60;
    config.close_pct = 0.60;
    config.opp_wick_pct = 0.40;
    config.vol_high_mult = 1.2;
    config.vol_low_mult = 1.0;
    config.pullback_max = 0.50;
    config.test_bars = 5;
    config.entry_buffer = 0.1;
    config.sl_buffer = 0.1;
    config.tp_multiplier = 2.0;
    config.risk_percent = 2.0;
    config.max_spread = 3.0;
    config.use_ema = false;
    config.use_vwap = false;
    config.use_time_filter = true;
    config.start_time = "07:00";
    config.end_time = "22:00";
    
    // Symbol-specific optimizations
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
    {
        // Gold optimized settings
        config.push_range_pct = 0.65;
        config.vol_high_mult = 1.3;
        config.tp_multiplier = 2.5;
        config.risk_percent = 1.5;
        config.max_spread = 5.0;
        config.use_vwap = true;
        config.start_time = "13:00"; // NY session
        config.end_time = "22:00";
    }
    else if(StringFind(symbol, "EUR") >= 0 && StringFind(symbol, "USD") >= 0)
    {
        // EURUSD optimized settings
        config.push_range_pct = 0.55;
        config.vol_high_mult = 1.1;
        config.tp_multiplier = 2.0;
        config.risk_percent = 2.0;
        config.max_spread = 2.0;
        config.use_ema = true;
        config.start_time = "07:00"; // London session
        config.end_time = "16:00";
    }
    else if(StringFind(symbol, "GBP") >= 0)
    {
        // GBP pairs
        config.push_range_pct = 0.70;
        config.vol_high_mult = 1.4;
        config.tp_multiplier = 1.8;
        config.max_spread = 4.0;
        config.use_ema = true;
    }
    else if(StringFind(symbol, "JPY") >= 0)
    {
        // JPY pairs
        config.push_range_pct = 0.60;
        config.vol_high_mult = 1.2;
        config.tp_multiplier = 2.2;
        config.max_spread = 3.0;
        config.entry_buffer = 1.0; // Larger buffer for JPY
        config.sl_buffer = 1.0;
    }
    
    return config;
}

//+------------------------------------------------------------------+
//| Trading session definitions                                      |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION
{
    SESSION_ASIAN,      // Tokyo: 00:00-09:00 GMT
    SESSION_LONDON,     // London: 07:00-16:00 GMT  
    SESSION_NEW_YORK,   // New York: 13:00-22:00 GMT
    SESSION_OVERLAP     // London/NY: 13:00-16:00 GMT
};

//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool IsSessionActive(ENUM_TRADING_SESSION session)
{
    datetime current_time = TimeCurrent();
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    int hour = time_struct.hour;
    
    switch(session)
    {
        case SESSION_ASIAN:
            return (hour >= 0 && hour < 9);
            
        case SESSION_LONDON:
            return (hour >= 7 && hour < 16);
            
        case SESSION_NEW_YORK:
            return (hour >= 13 && hour < 22);
            
        case SESSION_OVERLAP:
            return (hour >= 13 && hour < 16);
            
        default:
            return true;
    }
}

//+------------------------------------------------------------------+
//| Get recommended session for symbol                               |
//+------------------------------------------------------------------+
ENUM_TRADING_SESSION GetRecommendedSession(const string symbol)
{
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
        return SESSION_NEW_YORK;        // Gold active during NY session
    else if(StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0)
        return SESSION_LONDON;          // European pairs during London
    else if(StringFind(symbol, "JPY") >= 0)
        return SESSION_ASIAN;           // JPY pairs during Asian session
    else if(StringFind(symbol, "USD") >= 0)
        return SESSION_OVERLAP;         // USD pairs during overlap
    else
        return SESSION_OVERLAP;         // Default to overlap
}

//+------------------------------------------------------------------+
//| Volatility-based parameter adjustment                            |
//+------------------------------------------------------------------+
PTGConfig AdjustForVolatility(const PTGConfig &base_config, double atr_value, double atr_average)
{
    PTGConfig adjusted = base_config;
    
    double volatility_ratio = atr_value / atr_average;
    
    if(volatility_ratio > 1.5) // High volatility
    {
        adjusted.push_range_pct *= 1.1;
        adjusted.vol_high_mult *= 1.1;
        adjusted.tp_multiplier *= 0.9;  // Tighter TP in high vol
        adjusted.max_spread *= 1.2;
    }
    else if(volatility_ratio < 0.7) // Low volatility
    {
        adjusted.push_range_pct *= 0.9;
        adjusted.vol_high_mult *= 0.9;
        adjusted.tp_multiplier *= 1.1;  // Wider TP in low vol
    }
    
    return adjusted;
}

#endif // PTG_CONFIG_MQH
