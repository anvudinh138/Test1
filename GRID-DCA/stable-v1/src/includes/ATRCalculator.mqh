//+------------------------------------------------------------------+
//|                                                ATRCalculator.mqh |
//|                                            Flex Grid DCA System |
//|                                      Universal ATR Calculator    |
//+------------------------------------------------------------------+
#property copyright "Flex Grid DCA EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| ATR Calculator Class - Universal for all symbols                 |
//+------------------------------------------------------------------+
class CATRCalculator
{
private:
    string            m_symbol;
    int               m_atr_handles[5];  // M1, M15, H1, H4, D1
    ENUM_TIMEFRAMES   m_timeframes[5];
    double            m_atr_values[5];
    bool              m_initialized;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CATRCalculator(void)
    {
        m_symbol = _Symbol;
        m_timeframes[0] = PERIOD_M1;
        m_timeframes[1] = PERIOD_M15; 
        m_timeframes[2] = PERIOD_H1;
        m_timeframes[3] = PERIOD_H4;
        m_timeframes[4] = PERIOD_D1;
        m_initialized = false;
        ArrayInitialize(m_atr_values, 0.0);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CATRCalculator(void)
    {
        Cleanup();
    }
    
    //+------------------------------------------------------------------+
    //| Initialize ATR handles for all timeframes                       |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol = "")
    {
        if(symbol != "")
            m_symbol = symbol;
            
        // Create ATR handles for all timeframes
        for(int i = 0; i < 5; i++)
        {
            m_atr_handles[i] = iATR(m_symbol, m_timeframes[i], 14);
            if(m_atr_handles[i] == INVALID_HANDLE)
            {
                Print("Failed to create ATR handle for ", EnumToString(m_timeframes[i]));
                return false;
            }
        }
        
        m_initialized = true;
        Print("ATR Calculator initialized for ", m_symbol);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Update all ATR values                                           |
    //+------------------------------------------------------------------+
    bool UpdateATRValues(void)
    {
        if(!m_initialized)
            return false;
            
        double atr_buffer[];
        ArrayResize(atr_buffer, 1);
        
        for(int i = 0; i < 5; i++)
        {
            if(CopyBuffer(m_atr_handles[i], 0, 1, 1, atr_buffer) <= 0)
            {
                Print("Failed to copy ATR buffer for ", EnumToString(m_timeframes[i]));
                continue;
            }
            m_atr_values[i] = atr_buffer[0];
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get ATR value for specific timeframe                            |
    //+------------------------------------------------------------------+
    double GetATR(ENUM_TIMEFRAMES timeframe)
    {
        int index = GetTimeframeIndex(timeframe);
        if(index < 0) return 0.0;
        
        return m_atr_values[index];
    }
    
    //+------------------------------------------------------------------+
    //| Get normalized ATR (as percentage of current price)             |
    //+------------------------------------------------------------------+
    double GetNormalizedATR(ENUM_TIMEFRAMES timeframe)
    {
        double atr = GetATR(timeframe);
        if(atr <= 0) return 0.0;
        
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(current_price <= 0) return 0.0;
        
        return (atr / current_price) * 100.0;  // Return as percentage
    }
    
    //+------------------------------------------------------------------+
    //| Calculate grid spacing based on ATR                             |
    //+------------------------------------------------------------------+
    double CalculateGridSpacing(ENUM_TIMEFRAMES timeframe, double multiplier = 1.0)
    {
        double atr = GetATR(timeframe);
        return atr * multiplier;
    }
    
    //+------------------------------------------------------------------+
    //| Check if volatility is within acceptable range                  |
    //+------------------------------------------------------------------+
    bool IsVolatilityNormal(double min_threshold = 0.05, double max_threshold = 5.0)
    {
        double normalized_atr = GetNormalizedATR(PERIOD_H1);
        return (normalized_atr >= min_threshold && normalized_atr <= max_threshold);
    }
    
    //+------------------------------------------------------------------+
    //| Get volatility condition                                         |
    //+------------------------------------------------------------------+
    string GetVolatilityCondition(void)
    {
        double normalized_atr = GetNormalizedATR(PERIOD_H1);
        
        if(normalized_atr < 0.05)
            return "LOW_VOLATILITY";
        else if(normalized_atr > 5.0)
            return "HIGH_VOLATILITY"; 
        else
            return "NORMAL_VOLATILITY";
    }
    
    //+------------------------------------------------------------------+
    //| Print ATR information                                            |
    //+------------------------------------------------------------------+
    void PrintATRInfo(void)
    {
        if(!m_initialized) return;
        
        UpdateATRValues();
        
        Print("=== ATR Information for ", m_symbol, " ===");
        Print("M1 ATR: ", DoubleToString(m_atr_values[0], 5));
        Print("M15 ATR: ", DoubleToString(m_atr_values[1], 5));
        Print("H1 ATR: ", DoubleToString(m_atr_values[2], 5));
        Print("H4 ATR: ", DoubleToString(m_atr_values[3], 5));
        Print("D1 ATR: ", DoubleToString(m_atr_values[4], 5));
        Print("H1 Normalized ATR: ", DoubleToString(GetNormalizedATR(PERIOD_H1), 2), "%");
        Print("Volatility: ", GetVolatilityCondition());
    }
    
private:
    //+------------------------------------------------------------------+
    //| Get array index for timeframe                                   |
    //+------------------------------------------------------------------+
    int GetTimeframeIndex(ENUM_TIMEFRAMES timeframe)
    {
        for(int i = 0; i < 5; i++)
        {
            if(m_timeframes[i] == timeframe)
                return i;
        }
        return -1;
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup handles                                                  |
    //+------------------------------------------------------------------+
    void Cleanup(void)
    {
        for(int i = 0; i < 5; i++)
        {
            if(m_atr_handles[i] != INVALID_HANDLE)
                IndicatorRelease(m_atr_handles[i]);
        }
        m_initialized = false;
    }
};
//+------------------------------------------------------------------+
