//+------------------------------------------------------------------+
//|                                           HL_EntryDetection.mqh |
//|                          Copyright 2024, Market Structure Expert |
//|                           Array B (Entry Detection) Manager     |
//+------------------------------------------------------------------+

#ifndef HL_ENTRYDETECTION_MQH
#define HL_ENTRYDETECTION_MQH

#include "HL_Structures.mqh"

//+------------------------------------------------------------------+
//| Entry Detection Class - Array B Management                      |
//+------------------------------------------------------------------+
class CEntryDetection
{
private:
    // Core parameters
    double               m_retest_threshold;   // Retest threshold for Array B (15%)
    int                  m_max_entry_arrays;   // Maximum concurrent Array B instances
    double               m_range_buffer;       // Buffer for range boundaries
    int                  m_confirmation_bars;  // Bars needed for confirmation
    int                  m_stale_timeout;      // Timeout for stale arrays
    bool                 m_auto_clear_stale;   // Auto clear stale arrays
    
    // Active Array B instances
    CArrayObj            m_active_arrays;      // List of active SEntryArray instances
    
    // Statistics
    int                  m_total_arrays_created;    // Total arrays created
    int                  m_real_choch_signals;      // Real ChoCH signals generated
    int                  m_sweep_signals;           // Sweep signals generated
    int                  m_arrays_cleared;          // Arrays cleared (stale/range exit)
    
public:
    // Constructor
    CEntryDetection(double retest_threshold = 0.15, int max_arrays = 5)
    {
        m_retest_threshold = retest_threshold;
        m_max_entry_arrays = max_arrays;
        m_range_buffer = 0.0;
        m_confirmation_bars = 2;
        m_stale_timeout = 20;
        m_auto_clear_stale = true;
        
        // Initialize statistics
        m_total_arrays_created = 0;
        m_real_choch_signals = 0;
        m_sweep_signals = 0;
        m_arrays_cleared = 0;
    }
    
    // Destructor
    ~CEntryDetection()
    {
        ClearAllArrays();
    }
    
    //+------------------------------------------------------------------+
    //| Parameter setters                                               |
    //+------------------------------------------------------------------+
    void SetRetestThreshold(double threshold) { m_retest_threshold = threshold; }
    void SetMaxArrays(int max_arrays) { m_max_entry_arrays = max_arrays; }
    void SetRangeBuffer(double buffer) { m_range_buffer = buffer; }
    void SetConfirmationBars(int bars) { m_confirmation_bars = bars; }
    void SetStaleTimeout(int timeout) { m_stale_timeout = timeout; }
    void SetAutoClearStale(bool auto_clear) { m_auto_clear_stale = auto_clear; }
    
    //+------------------------------------------------------------------+
    //| Main Array B management functions                              |
    //+------------------------------------------------------------------+
    bool InitializeEntryArray(const SChoCHEvent &choch_event)
    {
        // Check if we have room for new array
        if(m_active_arrays.Total() >= m_max_entry_arrays)
        {
            // Clear oldest array to make room
            ClearOldestArray();
        }
        
        // Create new entry array
        SEntryArray *new_array = new SEntryArray();
        
        // Set up the array with ChoCH event data
        new_array.original_direction = choch_event.original_direction;
        new_array.choch_direction = choch_event.choch_direction;
        new_array.created_time = choch_event.event_time;
        new_array.created_bar = choch_event.event_bar;
        new_array.last_update = choch_event.event_time;
        new_array.is_active = true;
        new_array.pattern_complete = false;
        new_array.source_choch = choch_event;
        
        // Set confined range with buffer
        new_array.confined_range.range_high = choch_event.range_high + m_range_buffer;
        new_array.confined_range.range_low = choch_event.range_low - m_range_buffer;
        new_array.confined_range.has_upper_bound = true;
        new_array.confined_range.has_lower_bound = true;
        new_array.confined_range.created_time = choch_event.event_time;
        new_array.confined_range.created_bar = choch_event.event_bar;
        
        // Add to active arrays
        m_active_arrays.Add(new_array);
        m_total_arrays_created++;
        
        Print("Array B initialized for ChoCH: Direction=", 
              TrendDirectionToString(choch_event.choch_direction),
              " Range=[", new_array.confined_range.range_low, ",", 
              new_array.confined_range.range_high, "]");
        
        return true;
    }
    
    void ProcessEntryDetection(const SSwingPoint &point, CArrayList<SEntrySignal> &signals)
    {
        signals.Clear();
        
        // Process each active Array B
        for(int i = m_active_arrays.Total() - 1; i >= 0; i--)
        {
            SEntryArray *array_b = m_active_arrays.At(i);
            if(!array_b || !array_b.is_active)
                continue;
                
            // Check if price is still within range
            if(!IsInRange(point.GetEffectivePrice(), array_b.confined_range))
            {
                // Price exited range - clear this array
                Print("Array B cleared - price exited range: ", point.GetEffectivePrice());
                ClearArrayAtIndex(i);
                continue;
            }
            
            // Try to add swing point to this array
            if(TryAddSwingToArray(point, array_b))
            {
                // Check if we can generate entry signal
                SEntrySignal signal;
                if(AnalyzeArrayForEntry(array_b, signal))
                {
                    signals.Add(signal);
                    
                    // Mark array as completed and remove it
                    array_b.is_active = false;
                    ClearArrayAtIndex(i);
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Entry signal analysis                                          |
    //+------------------------------------------------------------------+
    bool AnalyzeArrayForEntry(SEntryArray *array_b, SEntrySignal &signal)
    {
        if(!array_b || !array_b.IsPatternComplete())
            return false;
            
        // Detect BOS direction in Array B
        ENUM_TREND_DIRECTION bos_direction = array_b.DetectBOSDirection();
        if(bos_direction == TREND_UNKNOWN)
            return false;
            
        // Determine signal type based on BOS direction vs ChoCH direction
        if(bos_direction == array_b.choch_direction)
        {
            // BOS same direction as ChoCH = Real ChoCH
            return GenerateRealChoCHSignal(array_b, signal);
        }
        else if(bos_direction == array_b.original_direction)
        {
            // BOS opposite to ChoCH = Sweep
            return GenerateSweepSignal(array_b, signal);
        }
        
        return false;
    }
    
    bool GenerateRealChoCHSignal(SEntryArray *array_b, SEntrySignal &signal)
    {
        signal.signal_type = ENTRY_REAL_CHOCH;
        signal.direction = array_b.choch_direction;
        signal.signal_time = TimeCurrent();
        signal.signal_bar = iBars(Symbol(), Period()) - 1;
        signal.confidence = 0.8; // High confidence for real ChoCH
        signal.description = "Real ChoCH Entry - True trend reversal confirmed";
        
        // Get last swing point for entry price
        if(array_b.GetSwingCount() > 0)
        {
            SSwingPoint *last_point = array_b.swing_points.At(array_b.GetSwingCount() - 1);
            if(last_point)
            {
                signal.entry_price = last_point.GetEffectivePrice();
                
                // Calculate stop loss and take profit
                CalculateStopLossAndTakeProfit(array_b, signal);
            }
        }
        
        m_real_choch_signals++;
        
        Print("REAL ChoCH Signal Generated: ", TrendDirectionToString(signal.direction),
              " Entry: ", signal.entry_price, " SL: ", signal.stop_loss, " TP: ", signal.take_profit);
        
        return true;
    }
    
    bool GenerateSweepSignal(SEntryArray *array_b, SEntrySignal &signal)
    {
        signal.signal_type = ENTRY_SWEEP;
        signal.direction = array_b.original_direction; // Enter original direction
        signal.signal_time = TimeCurrent();
        signal.signal_bar = iBars(Symbol(), Period()) - 1;
        signal.confidence = 0.9; // Very high confidence for sweep
        signal.description = "Sweep Entry - Fake ChoCH detected, original trend continues";
        
        // Get last swing point for entry price
        if(array_b.GetSwingCount() > 0)
        {
            SSwingPoint *last_point = array_b.swing_points.At(array_b.GetSwingCount() - 1);
            if(last_point)
            {
                signal.entry_price = last_point.GetEffectivePrice();
                
                // Calculate stop loss and take profit
                CalculateStopLossAndTakeProfit(array_b, signal);
            }
        }
        
        m_sweep_signals++;
        
        Print("SWEEP Signal Generated: ", TrendDirectionToString(signal.direction),
              " Entry: ", signal.entry_price, " SL: ", signal.stop_loss, " TP: ", signal.take_profit);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Risk management calculations                                   |
    //+------------------------------------------------------------------+
    void CalculateStopLossAndTakeProfit(SEntryArray *array_b, SEntrySignal &signal)
    {
        double range_size = array_b.confined_range.GetRangeSize();
        double risk_distance = range_size * 0.3; // 30% of range for risk
        double reward_distance = risk_distance * 2.0; // 1:2 risk-reward
        
        if(signal.direction == TREND_BULLISH)
        {
            // Long entry
            signal.stop_loss = signal.entry_price - risk_distance;
            signal.take_profit = signal.entry_price + reward_distance;
        }
        else
        {
            // Short entry
            signal.stop_loss = signal.entry_price + risk_distance;
            signal.take_profit = signal.entry_price - reward_distance;
        }
        
        // Validate levels
        ValidateRiskLevels(signal);
    }
    
    void ValidateRiskLevels(SEntrySignal &signal)
    {
        double min_stop_distance = 10 * Point * 10; // Minimum 10 pips
        double max_stop_distance = 100 * Point * 10; // Maximum 100 pips
        
        double stop_distance = MathAbs(signal.entry_price - signal.stop_loss);
        
        if(stop_distance < min_stop_distance)
        {
            // Adjust to minimum distance
            if(signal.direction == TREND_BULLISH)
            {
                signal.stop_loss = signal.entry_price - min_stop_distance;
                signal.take_profit = signal.entry_price + (min_stop_distance * 2.0);
            }
            else
            {
                signal.stop_loss = signal.entry_price + min_stop_distance;
                signal.take_profit = signal.entry_price - (min_stop_distance * 2.0);
            }
        }
        else if(stop_distance > max_stop_distance)
        {
            // Adjust to maximum distance
            if(signal.direction == TREND_BULLISH)
            {
                signal.stop_loss = signal.entry_price - max_stop_distance;
                signal.take_profit = signal.entry_price + (max_stop_distance * 2.0);
            }
            else
            {
                signal.stop_loss = signal.entry_price + max_stop_distance;
                signal.take_profit = signal.entry_price - (max_stop_distance * 2.0);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Array management utilities                                     |
    //+------------------------------------------------------------------+
    void CleanupStaleArrays(int current_bar)
    {
        for(int i = m_active_arrays.Total() - 1; i >= 0; i--)
        {
            SEntryArray *array_b = m_active_arrays.At(i);
            if(!array_b)
                continue;
                
            // Check if array is stale
            int bars_since_creation = current_bar - array_b.created_bar;
            if(bars_since_creation > m_stale_timeout)
            {
                Print("Array B cleared - stale timeout: ", bars_since_creation, " bars");
                ClearArrayAtIndex(i);
            }
        }
    }
    
    void GetActiveArrays(CArrayList<SEntryArray> &arrays)
    {
        arrays.Clear();
        for(int i = 0; i < m_active_arrays.Total(); i++)
        {
            SEntryArray *array_b = m_active_arrays.At(i);
            if(array_b && array_b.is_active)
                arrays.Add(*array_b);
        }
    }
    
    int GetActiveArrayCount() const
    {
        int count = 0;
        for(int i = 0; i < m_active_arrays.Total(); i++)
        {
            SEntryArray *array_b = m_active_arrays.At(i);
            if(array_b && array_b.is_active)
                count++;
        }
        return count;
    }
    
    // Statistics
    int GetTotalArraysCreated() const { return m_total_arrays_created; }
    int GetRealChoCHSignals() const { return m_real_choch_signals; }
    int GetSweepSignals() const { return m_sweep_signals; }
    int GetArraysCleared() const { return m_arrays_cleared; }
    
private:
    //+------------------------------------------------------------------+
    //| Helper methods                                                  |
    //+------------------------------------------------------------------+
    bool IsInRange(double price, const SRange &range)
    {
        return range.IsInRange(price, m_range_buffer);
    }
    
    bool TryAddSwingToArray(const SSwingPoint &point, SEntryArray *array_b)
    {
        if(!array_b || !array_b.is_active)
            return false;
            
        // Create copy of point for this array
        SSwingPoint array_point = point;
        
        // Determine swing type relative to this array's history
        array_point.swing_type = DetermineArrayBSwingType(point, array_b);
        
        if(array_point.swing_type == SWING_UNKNOWN)
            return false;
            
        // Validate retest if applicable
        if(!ValidateArrayBRetest(point, array_b))
            return false;
            
        // Add to array
        return array_b.AddSwingPoint(array_point);
    }
    
    ENUM_SWING_TYPE DetermineArrayBSwingType(const SSwingPoint &point, SEntryArray *array_b)
    {
        if(array_b.GetSwingCount() == 0)
        {
            // First point in array - determine based on point characteristics
            return (point.price_high > point.price_low + (5 * Point * 10)) ? SWING_H : SWING_L;
        }
        
        // Get previous swing in this array
        SSwingPoint *prev_swing = array_b.swing_points.At(array_b.GetSwingCount() - 1);
        if(!prev_swing)
            return SWING_UNKNOWN;
            
        // Simple high/low determination
        bool is_high = (point.price_high > point.price_low + (5 * Point * 10));
        
        if(is_high)
        {
            // Find last high in array for comparison
            double last_high = FindLastHighInArray(array_b);
            if(last_high > 0 && point.price_high > last_high)
                return SWING_HH;
            else
                return SWING_LH;
        }
        else
        {
            // Find last low in array for comparison
            double last_low = FindLastLowInArray(array_b);
            if(last_low > 0 && point.price_low > last_low)
                return SWING_HL;
            else
                return SWING_LL;
        }
    }
    
    double FindLastHighInArray(SEntryArray *array_b)
    {
        for(int i = array_b.GetSwingCount() - 1; i >= 0; i--)
        {
            SSwingPoint *point = array_b.swing_points.At(i);
            if(point && (point.swing_type == SWING_H || point.swing_type == SWING_HH || point.swing_type == SWING_LH))
                return point.price_high;
        }
        return 0.0;
    }
    
    double FindLastLowInArray(SEntryArray *array_b)
    {
        for(int i = array_b.GetSwingCount() - 1; i >= 0; i--)
        {
            SSwingPoint *point = array_b.swing_points.At(i);
            if(point && (point.swing_type == SWING_L || point.swing_type == SWING_LL || point.swing_type == SWING_HL))
                return point.price_low;
        }
        return 0.0;
    }
    
    bool ValidateArrayBRetest(const SSwingPoint &point, SEntryArray *array_b)
    {
        if(array_b.GetSwingCount() < 2)
            return true; // No retest validation needed for first few points
            
        // Get range for retest validation
        double range_size = array_b.confined_range.GetRangeSize();
        if(range_size <= 0)
            return true;
            
        // Simple retest validation - more permissive than Array A
        return true; // For now, accept all points within range
    }
    
    void ClearArrayAtIndex(int index)
    {
        if(index < 0 || index >= m_active_arrays.Total())
            return;
            
        SEntryArray *array_b = m_active_arrays.At(index);
        if(array_b)
        {
            delete array_b;
            m_arrays_cleared++;
        }
        
        m_active_arrays.Delete(index);
    }
    
    void ClearOldestArray()
    {
        if(m_active_arrays.Total() == 0)
            return;
            
        // Find oldest array
        int oldest_index = 0;
        datetime oldest_time = TimeCurrent();
        
        for(int i = 0; i < m_active_arrays.Total(); i++)
        {
            SEntryArray *array_b = m_active_arrays.At(i);
            if(array_b && array_b.created_time < oldest_time)
            {
                oldest_time = array_b.created_time;
                oldest_index = i;
            }
        }
        
        Print("Clearing oldest Array B to make room for new one");
        ClearArrayAtIndex(oldest_index);
    }
    
    void ClearAllArrays()
    {
        for(int i = m_active_arrays.Total() - 1; i >= 0; i--)
        {
            ClearArrayAtIndex(i);
        }
        m_active_arrays.Clear();
    }
};

#endif // HL_ENTRYDETECTION_MQH
