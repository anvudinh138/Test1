//+------------------------------------------------------------------+
//|                                              HL_ArrayManager.mqh |
//|                          Copyright 2024, Market Structure Expert |
//|                              Array A (Main Structure) Manager    |
//+------------------------------------------------------------------+

#ifndef HL_ARRAYMANAGER_MQH
#define HL_ARRAYMANAGER_MQH

#include "HL_Structures.mqh"

//+------------------------------------------------------------------+
//| Array A Manager Class - Main Market Structure                   |
//+------------------------------------------------------------------+
class CArrayManager
{
private:
    // Core parameters
    double               m_retest_threshold;   // Retest threshold for validation
    int                  m_min_swing_distance; // Minimum distance between swings
    bool                 m_confirm_on_close;   // Only confirm on candle close
    double               m_bos_buffer;          // BOS detection buffer
    double               m_choch_buffer;        // ChoCH detection buffer
    
    // Pattern state
    SPatternState        m_pattern_state;      // Current pattern state
    SSwingPoint          m_last_swing;         // Last detected swing point
    bool                 m_pattern_initialized; // Is pattern system initialized
    
    // Tracking variables
    double               m_last_high;          // Last significant high
    double               m_last_low;           // Last significant low
    int                  m_last_high_bar;      // Bar index of last high
    int                  m_last_low_bar;       // Bar index of last low
    
    // Statistics
    int                  m_total_swings;       // Total swings detected
    int                  m_bos_count;          // Total BOS events
    int                  m_choch_count;        // Total ChoCH events
    
public:
    // Constructor
    CArrayManager(double retest_threshold = 0.20, int min_swing_distance = 10)
    {
        m_retest_threshold = retest_threshold;
        m_min_swing_distance = min_swing_distance;
        m_confirm_on_close = true;
        m_bos_buffer = 0.0;
        m_choch_buffer = 0.0;
        m_pattern_initialized = false;
        m_last_high = 0.0;
        m_last_low = 0.0;
        m_last_high_bar = 0;
        m_last_low_bar = 0;
        m_total_swings = 0;
        m_bos_count = 0;
        m_choch_count = 0;
    }
    
    // Destructor
    ~CArrayManager() {}
    
    //+------------------------------------------------------------------+
    //| Parameter setters                                               |
    //+------------------------------------------------------------------+
    void SetRetestThreshold(double threshold) { m_retest_threshold = threshold; }
    void SetMinSwingDistance(int distance) { m_min_swing_distance = distance; }
    void SetConfirmOnClose(bool confirm) { m_confirm_on_close = confirm; }
    void SetBOSBuffer(double buffer) { m_bos_buffer = buffer; }
    void SetChoCHBuffer(double buffer) { m_choch_buffer = buffer; }
    
    //+------------------------------------------------------------------+
    //| Main processing function                                        |
    //+------------------------------------------------------------------+
    bool ProcessSwingPoint(SSwingPoint &point)
    {
        // Initialize if first time
        if(!m_pattern_initialized)
        {
            return InitializePattern(point);
        }
        
        // Validate minimum distance
        if(!ValidateSwingDistance(point))
            return false;
            
        // Determine swing type
        ENUM_SWING_TYPE swing_type = DetermineSwingType(point);
        if(swing_type == SWING_UNKNOWN)
            return false;
            
        // Update swing point with determined type
        point.swing_type = swing_type;
        point.confirmed = true;
        
        // Add to pattern state
        SSwingPoint *new_swing = new SSwingPoint(point);
        m_pattern_state.swing_array.Add(new_swing);
        
        // Update tracking variables
        UpdateTrackingVariables(point);
        
        // Update current range
        UpdateCurrentRange(point);
        
        // Update pattern completion status
        m_pattern_state.pattern_complete = 
            m_pattern_state.IsCompleteUpswing() || m_pattern_state.IsCompleteDownswing();
            
        // Update statistics
        m_total_swings++;
        m_last_swing = point;
        m_pattern_state.last_update = point.time;
        m_pattern_state.last_bar = point.bar_index;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Market structure event detection                               |
    //+------------------------------------------------------------------+
    bool DetectChoCH(SChoCHEvent &choch_event)
    {
        if(!m_pattern_state.pattern_complete)
            return false;
            
        // Get current price for comparison
        double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        
        // Check for ChoCH conditions
        if(m_pattern_state.IsCompleteUpswing())
        {
            // Check if price breaks below the key level (i2 in upswing)
            if(m_pattern_state.swing_array.Total() >= 4)
            {
                SSwingPoint *i2_point = m_pattern_state.swing_array.At(m_pattern_state.swing_array.Total() - 3);
                if(i2_point && current_price < (i2_point.GetEffectivePrice() - m_choch_buffer))
                {
                    // ChoCH Down detected
                    PopulateChoCHEvent(choch_event, TREND_BEARISH, current_price, i2_point);
                    m_choch_count++;
                    return true;
                }
            }
        }
        else if(m_pattern_state.IsCompleteDownswing())
        {
            // Check if price breaks above the key level (i2 in downswing)
            if(m_pattern_state.swing_array.Total() >= 4)
            {
                SSwingPoint *i2_point = m_pattern_state.swing_array.At(m_pattern_state.swing_array.Total() - 3);
                if(i2_point && current_price > (i2_point.GetEffectivePrice() + m_choch_buffer))
                {
                    // ChoCH Up detected
                    PopulateChoCHEvent(choch_event, TREND_BULLISH, current_price, i2_point);
                    m_choch_count++;
                    return true;
                }
            }
        }
        
        return false;
    }
    
    bool DetectBOS(SBOSEvent &bos_event)
    {
        if(!m_pattern_state.pattern_complete)
            return false;
            
        double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        
        // Check for BOS conditions
        if(m_pattern_state.current_range.has_upper_bound && 
           current_price > (m_pattern_state.current_range.range_high + m_bos_buffer))
        {
            // BOS Up detected
            bos_event.trigger_price = current_price;
            bos_event.direction = TREND_BULLISH;
            bos_event.event_time = TimeCurrent();
            bos_event.event_bar = iBars(Symbol(), Period()) - 1;
            bos_event.is_continuation = (m_pattern_state.current_trend == TREND_BULLISH);
            
            m_bos_count++;
            return true;
        }
        else if(m_pattern_state.current_range.has_lower_bound && 
                current_price < (m_pattern_state.current_range.range_low - m_bos_buffer))
        {
            // BOS Down detected
            bos_event.trigger_price = current_price;
            bos_event.direction = TREND_BEARISH;
            bos_event.event_time = TimeCurrent();
            bos_event.event_bar = iBars(Symbol(), Period()) - 1;
            bos_event.is_continuation = (m_pattern_state.current_trend == TREND_BEARISH);
            
            m_bos_count++;
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Data access methods                                            |
    //+------------------------------------------------------------------+
    void GetSwingPoints(CArrayList<SSwingPoint> &swing_points)
    {
        swing_points.Clear();
        for(int i = 0; i < m_pattern_state.swing_array.Total(); i++)
        {
            SSwingPoint *point = m_pattern_state.swing_array.At(i);
            if(point)
                swing_points.Add(*point);
        }
    }
    
    bool GetCurrentRange(SRange &range)
    {
        range = m_pattern_state.current_range;
        return (range.has_upper_bound || range.has_lower_bound);
    }
    
    ENUM_TREND_DIRECTION GetCurrentTrend() const
    {
        return m_pattern_state.current_trend;
    }
    
    bool IsPatternComplete() const
    {
        return m_pattern_state.pattern_complete;
    }
    
    int GetSwingCount() const
    {
        return m_pattern_state.swing_array.Total();
    }
    
    // Statistics
    int GetTotalSwings() const { return m_total_swings; }
    int GetBOSCount() const { return m_bos_count; }
    int GetChoCHCount() const { return m_choch_count; }
    
private:
    //+------------------------------------------------------------------+
    //| Helper methods                                                  |
    //+------------------------------------------------------------------+
    bool InitializePattern(const SSwingPoint &point)
    {
        // Create first swing point
        SSwingPoint *first_swing = new SSwingPoint(point);
        first_swing.swing_type = SWING_L; // Start with a low assumption
        first_swing.confirmed = true;
        
        m_pattern_state.swing_array.Add(first_swing);
        
        // Initialize tracking variables
        m_last_low = point.price_low;
        m_last_high = point.price_high;
        m_last_low_bar = point.bar_index;
        m_last_high_bar = point.bar_index;
        
        // Initialize range with infinite boundaries
        m_pattern_state.current_range.range_low = point.price_low;
        m_pattern_state.current_range.range_high = DBL_MAX;
        m_pattern_state.current_range.has_lower_bound = true;
        m_pattern_state.current_range.has_upper_bound = false;
        
        m_pattern_initialized = true;
        
        Print("Pattern initialized with first swing at: ", point.price_low);
        return true;
    }
    
    bool ValidateSwingDistance(const SSwingPoint &point)
    {
        if(m_pattern_state.swing_array.Total() == 0)
            return true;
            
        SSwingPoint *last_point = m_pattern_state.swing_array.At(m_pattern_state.swing_array.Total() - 1);
        if(!last_point)
            return false;
            
        // Check minimum distance in pips
        double distance = MathAbs(point.GetEffectivePrice() - last_point.GetEffectivePrice());
        double min_distance = m_min_swing_distance * Point * 10;
        
        return (distance >= min_distance);
    }
    
    ENUM_SWING_TYPE DetermineSwingType(const SSwingPoint &point)
    {
        if(m_pattern_state.swing_array.Total() == 0)
            return SWING_L; // First point defaults to L
            
        // Get the last swing point
        SSwingPoint *last_swing = m_pattern_state.swing_array.At(m_pattern_state.swing_array.Total() - 1);
        if(!last_swing)
            return SWING_UNKNOWN;
            
        // Determine if current point is a high or low relative to structure
        bool is_high_point = (point.price_high > point.price_low + (10 * Point * 10)); // Simple high detection
        bool is_low_point = !is_high_point;
        
        // Determine swing type based on comparison with previous points
        if(is_high_point)
        {
            if(point.price_high > m_last_high)
            {
                m_last_high = point.price_high;
                m_last_high_bar = point.bar_index;
                return SWING_HH; // Higher High
            }
            else
            {
                return SWING_LH; // Lower High
            }
        }
        else if(is_low_point)
        {
            if(point.price_low > m_last_low)
            {
                return SWING_HL; // Higher Low
            }
            else
            {
                m_last_low = point.price_low;
                m_last_low_bar = point.bar_index;
                return SWING_LL; // Lower Low
            }
        }
        
        return SWING_UNKNOWN;
    }
    
    void UpdateTrackingVariables(const SSwingPoint &point)
    {
        // Update last high/low tracking
        if(point.swing_type == SWING_HH || point.swing_type == SWING_H)
        {
            m_last_high = point.price_high;
            m_last_high_bar = point.bar_index;
        }
        else if(point.swing_type == SWING_LL || point.swing_type == SWING_L)
        {
            m_last_low = point.price_low;
            m_last_low_bar = point.bar_index;
        }
        
        // Update trend direction
        if(point.swing_type == SWING_HH || point.swing_type == SWING_HL)
        {
            m_pattern_state.current_trend = TREND_BULLISH;
        }
        else if(point.swing_type == SWING_LL || point.swing_type == SWING_LH)
        {
            m_pattern_state.current_trend = TREND_BEARISH;
        }
    }
    
    void UpdateCurrentRange(const SSwingPoint &point)
    {
        // Update range based on swing type
        if(point.swing_type == SWING_H || point.swing_type == SWING_HH || point.swing_type == SWING_LH)
        {
            m_pattern_state.current_range.range_high = point.price_high;
            m_pattern_state.current_range.has_upper_bound = true;
        }
        else if(point.swing_type == SWING_L || point.swing_type == SWING_LL || point.swing_type == SWING_HL)
        {
            m_pattern_state.current_range.range_low = point.price_low;
            m_pattern_state.current_range.has_lower_bound = true;
        }
        
        // Update range creation time
        m_pattern_state.current_range.created_time = point.time;
        m_pattern_state.current_range.created_bar = point.bar_index;
    }
    
    void PopulateChoCHEvent(SChoCHEvent &choch_event, ENUM_TREND_DIRECTION direction, 
                           double trigger_price, SSwingPoint *reference_point)
    {
        choch_event.trigger_price = trigger_price;
        choch_event.choch_direction = direction;
        choch_event.original_direction = (direction == TREND_BULLISH) ? TREND_BEARISH : TREND_BULLISH;
        choch_event.event_time = TimeCurrent();
        choch_event.event_bar = iBars(Symbol(), Period()) - 1;
        choch_event.is_active = true;
        
        // Set range boundaries for Array B initialization
        if(m_pattern_state.current_range.has_upper_bound && m_pattern_state.current_range.has_lower_bound)
        {
            choch_event.range_high = m_pattern_state.current_range.range_high;
            choch_event.range_low = m_pattern_state.current_range.range_low;
        }
        else
        {
            // Fallback to reference point area
            choch_event.range_high = reference_point.price_high + (50 * Point * 10);
            choch_event.range_low = reference_point.price_low - (50 * Point * 10);
        }
    }
};

#endif // HL_ARRAYMANAGER_MQH
