//+------------------------------------------------------------------+
//|                                                 HL_Utilities.mqh |
//|                          Copyright 2024, Market Structure Expert |
//|                                      Utility Functions & Helpers |
//+------------------------------------------------------------------+

#ifndef HL_UTILITIES_MQH
#define HL_UTILITIES_MQH

#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Simple Array List Implementation                                |
//+------------------------------------------------------------------+
template<typename T>
class CArrayList
{
private:
    T                    m_data[];
    int                  m_size;
    int                  m_capacity;
    
public:
    CArrayList()
    {
        m_size = 0;
        m_capacity = 10;
        ArrayResize(m_data, m_capacity);
    }
    
    ~CArrayList()
    {
        ArrayFree(m_data);
    }
    
    void Add(const T &item)
    {
        if(m_size >= m_capacity)
        {
            m_capacity *= 2;
            ArrayResize(m_data, m_capacity);
        }
        
        m_data[m_size] = item;
        m_size++;
    }
    
    T At(int index) const
    {
        if(index < 0 || index >= m_size)
        {
            T default_val;
            return default_val;
        }
        return m_data[index];
    }
    
    int Total() const
    {
        return m_size;
    }
    
    void Clear()
    {
        m_size = 0;
    }
    
    void RemoveAt(int index)
    {
        if(index < 0 || index >= m_size)
            return;
            
        for(int i = index; i < m_size - 1; i++)
        {
            m_data[i] = m_data[i + 1];
        }
        m_size--;
    }
};

//+------------------------------------------------------------------+
//| Price Utilities                                                 |
//+------------------------------------------------------------------+
class CPriceUtils
{
public:
    // Convert pips to price difference
    static double PipsToPrice(double pips)
    {
        return pips * Point * 10;
    }
    
    // Convert price difference to pips
    static double PriceToPips(double price_diff)
    {
        return price_diff / (Point * 10);
    }
    
    // Normalize price to symbol digits
    static double NormalizePrice(double price)
    {
        return NormalizeDouble(price, Digits);
    }
    
    // Check if price is valid
    static bool IsValidPrice(double price)
    {
        return (price > 0 && price != DBL_MAX && price != -DBL_MAX);
    }
    
    // Get current spread in pips
    static double GetSpreadPips()
    {
        return PriceToPips(SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                          SymbolInfoDouble(Symbol(), SYMBOL_BID));
    }
    
    // Check if market is open
    static bool IsMarketOpen()
    {
        return SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL;
    }
};

//+------------------------------------------------------------------+
//| Time Utilities                                                  |
//+------------------------------------------------------------------+
class CTimeUtils
{
public:
    // Get time difference in bars
    static int GetBarsDifference(datetime time1, datetime time2)
    {
        return (int)((time1 - time2) / PeriodSeconds());
    }
    
    // Check if time is within trading hours
    static bool IsTradingHours(datetime time = 0)
    {
        if(time == 0) time = TimeCurrent();
        
        MqlDateTime dt;
        TimeToStruct(time, dt);
        
        // Basic trading hours check (can be customized)
        return (dt.hour >= 1 && dt.hour <= 22); // 1 AM to 10 PM
    }
    
    // Format time for display
    static string FormatTime(datetime time)
    {
        return TimeToString(time, TIME_DATE | TIME_MINUTES);
    }
    
    // Get session name
    static string GetSessionName(datetime time = 0)
    {
        if(time == 0) time = TimeCurrent();
        
        MqlDateTime dt;
        TimeToStruct(time, dt);
        
        if(dt.hour >= 0 && dt.hour < 8)
            return "Asian";
        else if(dt.hour >= 8 && dt.hour < 16)
            return "London";
        else
            return "New York";
    }
};

//+------------------------------------------------------------------+
//| Chart Utilities                                                 |
//+------------------------------------------------------------------+
class CChartUtils
{
public:
    // Get unique object name
    static string GetUniqueObjectName(string prefix)
    {
        static int counter = 0;
        counter++;
        return prefix + "_" + IntegerToString(ChartID()) + "_" + IntegerToString(counter);
    }
    
    // Clean objects by prefix
    static void CleanObjectsByPrefix(string prefix)
    {
        int total = ObjectsTotal(0);
        for(int i = total - 1; i >= 0; i--)
        {
            string name = ObjectName(0, i);
            if(StringFind(name, prefix) == 0)
            {
                ObjectDelete(0, name);
            }
        }
    }
    
    // Create horizontal line
    static bool CreateHLine(string name, double price, color line_color = clrGray, int style = STYLE_SOLID)
    {
        if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
            ObjectSetInteger(0, name, OBJPROP_STYLE, style);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            return true;
        }
        return false;
    }
    
    // Create text label
    static bool CreateTextLabel(string name, string text, datetime time, double price, 
                               color text_color = clrWhite, int font_size = 8)
    {
        if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
        {
            ObjectSetString(0, name, OBJPROP_TEXT, text);
            ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
            return true;
        }
        return false;
    }
    
    // Create trend line
    static bool CreateTrendLine(string name, datetime time1, double price1, 
                               datetime time2, double price2, color line_color = clrYellow)
    {
        if(ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
            return true;
        }
        return false;
    }
    
    // Update chart
    static void RefreshChart()
    {
        ChartRedraw();
    }
};

//+------------------------------------------------------------------+
//| Alert Utilities                                                 |
//+------------------------------------------------------------------+
class CAlertUtils
{
private:
    static datetime      m_last_alert_time;
    static int           m_min_alert_interval; // Seconds between alerts
    
public:
    static void Initialize(int min_interval = 30)
    {
        m_min_alert_interval = min_interval;
        m_last_alert_time = 0;
    }
    
    // Send alert with throttling
    static bool SendAlert(string message, bool force = false)
    {
        datetime current_time = TimeCurrent();
        
        if(!force && (current_time - m_last_alert_time) < m_min_alert_interval)
            return false;
            
        Alert(message);
        m_last_alert_time = current_time;
        return true;
    }
    
    // Send notification
    static bool SendNotification(string message)
    {
        return SendNotification(message);
    }
    
    // Format standard alert message
    static string FormatAlertMessage(string event_type, string symbol, string timeframe, 
                                   double price, string additional_info = "")
    {
        string message = event_type + " Alert: " + symbol + " " + timeframe + 
                        " at " + DoubleToString(price, Digits);
                        
        if(additional_info != "")
            message += " | " + additional_info;
            
        return message;
    }
};

// Static member initialization
datetime CAlertUtils::m_last_alert_time = 0;
int CAlertUtils::m_min_alert_interval = 30;

//+------------------------------------------------------------------+
//| Validation Utilities                                           |
//+------------------------------------------------------------------+
class CValidationUtils
{
public:
    // Validate input parameters
    static bool ValidateInputs(double retest_threshold, int min_swing_distance, 
                              int max_arrays, double buffer_pips)
    {
        bool valid = true;
        
        if(retest_threshold < 0.05 || retest_threshold > 0.50)
        {
            Print("ERROR: Retest threshold should be between 5% and 50%");
            valid = false;
        }
        
        if(min_swing_distance < 5 || min_swing_distance > 100)
        {
            Print("ERROR: Min swing distance should be between 5 and 100 pips");
            valid = false;
        }
        
        if(max_arrays < 1 || max_arrays > 10)
        {
            Print("ERROR: Max arrays should be between 1 and 10");
            valid = false;
        }
        
        if(buffer_pips < 0 || buffer_pips > 50)
        {
            Print("ERROR: Buffer pips should be between 0 and 50");
            valid = false;
        }
        
        return valid;
    }
    
    // Validate symbol for trading
    static bool ValidateSymbol(string symbol = "")
    {
        if(symbol == "") symbol = Symbol();
        
        if(!SymbolSelect(symbol, true))
        {
            Print("ERROR: Symbol ", symbol, " not available");
            return false;
        }
        
        if(SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
        {
            Print("ERROR: Trading disabled for symbol ", symbol);
            return false;
        }
        
        return true;
    }
    
    // Check minimum bars requirement
    static bool CheckMinimumBars(int required_bars = 100)
    {
        int available_bars = iBars(Symbol(), Period());
        if(available_bars < required_bars)
        {
            Print("ERROR: Not enough bars. Required: ", required_bars, 
                  " Available: ", available_bars);
            return false;
        }
        return true;
    }
};

//+------------------------------------------------------------------+
//| Performance Monitor                                             |
//+------------------------------------------------------------------+
class CPerformanceMonitor
{
private:
    static int           m_calculation_count;
    static int           m_total_execution_time;
    static int           m_max_execution_time;
    static datetime      m_last_performance_report;
    
public:
    static void Initialize()
    {
        m_calculation_count = 0;
        m_total_execution_time = 0;
        m_max_execution_time = 0;
        m_last_performance_report = TimeCurrent();
    }
    
    static int StartTimer()
    {
        return GetTickCount();
    }
    
    static void EndTimer(int start_time)
    {
        int execution_time = GetTickCount() - start_time;
        
        m_calculation_count++;
        m_total_execution_time += execution_time;
        
        if(execution_time > m_max_execution_time)
            m_max_execution_time = execution_time;
            
        // Report every hour
        if(TimeCurrent() - m_last_performance_report > 3600)
        {
            ReportPerformance();
            m_last_performance_report = TimeCurrent();
        }
    }
    
    static void ReportPerformance()
    {
        if(m_calculation_count == 0) return;
        
        double avg_time = (double)m_total_execution_time / m_calculation_count;
        
        Print("Performance Report:");
        Print("- Calculations: ", m_calculation_count);
        Print("- Average time: ", DoubleToString(avg_time, 2), " ms");
        Print("- Max time: ", m_max_execution_time, " ms");
        Print("- Total time: ", m_total_execution_time, " ms");
    }
    
    static void ResetCounters()
    {
        m_calculation_count = 0;
        m_total_execution_time = 0;
        m_max_execution_time = 0;
    }
};

// Static member initialization
int CPerformanceMonitor::m_calculation_count = 0;
int CPerformanceMonitor::m_total_execution_time = 0;
int CPerformanceMonitor::m_max_execution_time = 0;
datetime CPerformanceMonitor::m_last_performance_report = 0;

#endif // HL_UTILITIES_MQH
