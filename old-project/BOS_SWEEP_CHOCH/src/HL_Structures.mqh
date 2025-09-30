//+------------------------------------------------------------------+
//|                                                HL_Structures.mqh |
//|                          Copyright 2024, Market Structure Expert |
//|                           Multi-Level Entry Detection Structures |
//+------------------------------------------------------------------+

#ifndef HL_STRUCTURES_MQH
#define HL_STRUCTURES_MQH

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+

// Swing point types (6 core types)
enum ENUM_SWING_TYPE
{
    SWING_UNKNOWN = 0,  // Unknown/Not determined
    SWING_L  = 1,       // Low (standalone)
    SWING_H  = 2,       // High (standalone)
    SWING_HL = 3,       // Higher Low
    SWING_HH = 4,       // Higher High
    SWING_LH = 5,       // Lower High
    SWING_LL = 6        // Lower Low
};

// Trend direction
enum ENUM_TREND_DIRECTION
{
    TREND_UNKNOWN = 0,
    TREND_BULLISH = 1,
    TREND_BEARISH = -1
};

// Market structure events
enum ENUM_MARKET_EVENT
{
    EVENT_NONE = 0,
    EVENT_BOS_UP = 1,
    EVENT_BOS_DOWN = 2,
    EVENT_CHOCH_UP = 3,
    EVENT_CHOCH_DOWN = 4,
    EVENT_SWEEP = 5
};

// Entry signal types
enum ENUM_ENTRY_SIGNAL
{
    ENTRY_NONE = 0,
    ENTRY_REAL_CHOCH = 1,
    ENTRY_SWEEP = 2,
    ENTRY_BOS_CONTINUATION = 3
};

//+------------------------------------------------------------------+
//| Core Structures                                                 |
//+------------------------------------------------------------------+

// Basic swing point structure
struct SSwingPoint
{
    double               price_high;        // High price of the swing
    double               price_low;         // Low price of the swing  
    datetime             time;              // Time of the swing
    int                  bar_index;         // Bar index
    ENUM_SWING_TYPE      swing_type;        // Type of swing point
    bool                 confirmed;         // Is swing confirmed
    
    // Constructor
    SSwingPoint()
    {
        price_high = 0.0;
        price_low = 0.0;
        time = 0;
        bar_index = 0;
        swing_type = SWING_UNKNOWN;
        confirmed = false;
    }
    
    // Copy constructor
    SSwingPoint(const SSwingPoint &other)
    {
        price_high = other.price_high;
        price_low = other.price_low;
        time = other.time;
        bar_index = other.bar_index;
        swing_type = other.swing_type;
        confirmed = other.confirmed;
    }
    
    // Get effective price based on swing type
    double GetEffectivePrice() const
    {
        if(swing_type == SWING_H || swing_type == SWING_HH || swing_type == SWING_LH)
            return price_high;
        else
            return price_low;
    }
};

// Range structure  
struct SRange
{
    double               range_high;        // High boundary
    double               range_low;         // Low boundary
    bool                 has_upper_bound;   // Has finite upper boundary
    bool                 has_lower_bound;   // Has finite lower boundary
    datetime             created_time;      // When range was created
    int                  created_bar;       // Bar index when created
    
    // Constructor
    SRange()
    {
        range_high = DBL_MAX;
        range_low = -DBL_MAX;
        has_upper_bound = false;
        has_lower_bound = false;
        created_time = 0;
        created_bar = 0;
    }
    
    // Check if price is within range
    bool IsInRange(double price, double buffer = 0.0) const
    {
        bool above_low = !has_lower_bound || (price >= (range_low - buffer));
        bool below_high = !has_upper_bound || (price <= (range_high + buffer));
        return above_low && below_high;
    }
    
    // Get range size in points
    double GetRangeSize() const
    {
        if(has_upper_bound && has_lower_bound)
            return range_high - range_low;
        return 0.0;
    }
    
    // Update range with new price
    void UpdateRange(double price, ENUM_SWING_TYPE swing_type)
    {
        if(swing_type == SWING_H || swing_type == SWING_HH || swing_type == SWING_LH)
        {
            range_high = price;
            has_upper_bound = true;
        }
        else if(swing_type == SWING_L || swing_type == SWING_LL || swing_type == SWING_HL)
        {
            range_low = price;
            has_lower_bound = true;
        }
    }
};

// ChoCH event structure
struct SChoCHEvent
{
    double               trigger_price;     // Price that triggered ChoCH
    double               range_high;        // High of the range for Array B
    double               range_low;         // Low of the range for Array B
    ENUM_TREND_DIRECTION original_direction; // Direction before ChoCH
    ENUM_TREND_DIRECTION choch_direction;   // Direction of ChoCH
    datetime             event_time;        // Time of ChoCH event
    int                  event_bar;         // Bar index of event
    bool                 is_active;         // Is this ChoCH still active
    
    // Constructor
    SChoCHEvent()
    {
        trigger_price = 0.0;
        range_high = 0.0;
        range_low = 0.0;
        original_direction = TREND_UNKNOWN;
        choch_direction = TREND_UNKNOWN;
        event_time = 0;
        event_bar = 0;
        is_active = false;
    }
};

// BOS event structure
struct SBOSEvent
{
    double               trigger_price;     // Price that triggered BOS
    ENUM_TREND_DIRECTION direction;         // Direction of BOS
    datetime             event_time;        // Time of BOS event
    int                  event_bar;         // Bar index of event
    bool                 is_continuation;   // Is this BOS a continuation
    
    // Constructor
    SBOSEvent()
    {
        trigger_price = 0.0;
        direction = TREND_UNKNOWN;
        event_time = 0;
        event_bar = 0;
        is_continuation = false;
    }
};

// Entry signal structure
struct SEntrySignal
{
    ENUM_ENTRY_SIGNAL    signal_type;       // Type of entry signal
    ENUM_TREND_DIRECTION direction;         // Direction to enter
    double               entry_price;       // Suggested entry price
    double               stop_loss;         // Suggested stop loss
    double               take_profit;       // Suggested take profit
    datetime             signal_time;       // Time of signal
    int                  signal_bar;        // Bar index of signal
    double               confidence;        // Signal confidence (0.0-1.0)
    string               description;       // Human readable description
    
    // Constructor
    SEntrySignal()
    {
        signal_type = ENTRY_NONE;
        direction = TREND_UNKNOWN;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        signal_time = 0;
        signal_bar = 0;
        confidence = 0.0;
        description = "";
    }
};

//+------------------------------------------------------------------+
//| Multi-Level System Structures                                   |
//+------------------------------------------------------------------+

// Array B (Entry Array) structure
struct SEntryArray
{
    CArrayObj            swing_points;      // Array of swing points in this entry array
    SRange               confined_range;    // Range boundaries for this array
    ENUM_TREND_DIRECTION original_direction; // Original trend direction before ChoCH
    ENUM_TREND_DIRECTION choch_direction;   // Direction of the ChoCH
    datetime             created_time;      // When this array was created
    int                  created_bar;       // Bar when this array was created
    datetime             last_update;       // Last time this array was updated
    bool                 is_active;         // Is this array still active
    bool                 pattern_complete;  // Has this array formed complete pattern
    SChoCHEvent          source_choch;      // ChoCH event that created this array
    
    // Constructor
    SEntryArray()
    {
        original_direction = TREND_UNKNOWN;
        choch_direction = TREND_UNKNOWN;
        created_time = 0;
        created_bar = 0;
        last_update = 0;
        is_active = true;
        pattern_complete = false;
    }
    
    // Add swing point to this array
    bool AddSwingPoint(const SSwingPoint &point)
    {
        if(!is_active) return false;
        
        // Check if point is within confined range
        if(!confined_range.IsInRange(point.GetEffectivePrice()))
            return false;
            
        SSwingPoint *new_point = new SSwingPoint(point);
        swing_points.Add(new_point);
        last_update = point.time;
        
        return true;
    }
    
    // Get number of swing points
    int GetSwingCount() const
    {
        return swing_points.Total();
    }
    
    // Check if pattern is complete
    bool IsPatternComplete() const
    {
        if(GetSwingCount() < 4) return false;
        
        // Check for complete upswing or downswing pattern
        SSwingPoint *p1 = swing_points.At(GetSwingCount() - 4);
        SSwingPoint *p2 = swing_points.At(GetSwingCount() - 3);
        SSwingPoint *p3 = swing_points.At(GetSwingCount() - 2);
        SSwingPoint *p4 = swing_points.At(GetSwingCount() - 1);
        
        if(!p1 || !p2 || !p3 || !p4) return false;
        
        // Check for [HL,HH,HL,HH] or [LH,LL,LH,LL]
        bool upswing = (p1.swing_type == SWING_HL && p2.swing_type == SWING_HH && 
                       p3.swing_type == SWING_HL && p4.swing_type == SWING_HH);
                       
        bool downswing = (p1.swing_type == SWING_LH && p2.swing_type == SWING_LL && 
                         p3.swing_type == SWING_LH && p4.swing_type == SWING_LL);
        
        return upswing || downswing;
    }
    
    // Detect BOS direction in this array
    ENUM_TREND_DIRECTION DetectBOSDirection() const
    {
        if(!IsPatternComplete()) return TREND_UNKNOWN;
        
        SSwingPoint *last_point = swing_points.At(GetSwingCount() - 1);
        if(!last_point) return TREND_UNKNOWN;
        
        // Determine BOS direction based on last swing type
        if(last_point.swing_type == SWING_HH)
            return TREND_BULLISH;
        else if(last_point.swing_type == SWING_LL)
            return TREND_BEARISH;
            
        return TREND_UNKNOWN;
    }
    
    // Cleanup
    ~SEntryArray()
    {
        swing_points.Clear();
    }
};

//+------------------------------------------------------------------+
//| Pattern Analysis Structures                                     |
//+------------------------------------------------------------------+

// Pattern state for Array A
struct SPatternState
{
    CArrayObj            swing_array;       // Main swing array (Array A)
    SRange               current_range;     // Current active range
    ENUM_TREND_DIRECTION current_trend;     // Current trend direction
    bool                 pattern_complete;  // Is current pattern complete
    datetime             last_update;       // Last update time
    int                  last_bar;          // Last processed bar
    
    // Pattern completion check
    bool IsCompleteUpswing() const
    {
        if(swing_array.Total() < 4) return false;
        
        SSwingPoint *p1 = swing_array.At(swing_array.Total() - 4);
        SSwingPoint *p2 = swing_array.At(swing_array.Total() - 3);
        SSwingPoint *p3 = swing_array.At(swing_array.Total() - 2);
        SSwingPoint *p4 = swing_array.At(swing_array.Total() - 1);
        
        if(!p1 || !p2 || !p3 || !p4) return false;
        
        return (p1.swing_type == SWING_HL && p2.swing_type == SWING_HH && 
                p3.swing_type == SWING_HL && p4.swing_type == SWING_HH);
    }
    
    bool IsCompleteDownswing() const
    {
        if(swing_array.Total() < 4) return false;
        
        SSwingPoint *p1 = swing_array.At(swing_array.Total() - 4);
        SSwingPoint *p2 = swing_array.At(swing_array.Total() - 3);
        SSwingPoint *p3 = swing_array.At(swing_array.Total() - 2);
        SSwingPoint *p4 = swing_array.At(swing_array.Total() - 1);
        
        if(!p1 || !p2 || !p3 || !p4) return false;
        
        return (p1.swing_type == SWING_LH && p2.swing_type == SWING_LL && 
                p3.swing_type == SWING_LH && p4.swing_type == SWING_LL);
    }
    
    // Constructor
    SPatternState()
    {
        current_trend = TREND_UNKNOWN;
        pattern_complete = false;
        last_update = 0;
        last_bar = 0;
    }
    
    // Cleanup
    ~SPatternState()
    {
        swing_array.Clear();
    }
};

//+------------------------------------------------------------------+
//| Validation and Helper Functions                                 |
//+------------------------------------------------------------------+

// Validate retest with threshold
bool IsValidRetest(double current_price, double extreme_price, const SRange &range, double threshold)
{
    if(!range.has_upper_bound || !range.has_lower_bound)
        return false;
        
    double range_size = range.GetRangeSize();
    if(range_size <= 0) return false;
    
    double distance = MathAbs(current_price - extreme_price);
    return (distance > threshold * range_size);
}

// Check if swing type is bullish
bool IsBullishSwing(ENUM_SWING_TYPE swing_type)
{
    return (swing_type == SWING_HL || swing_type == SWING_HH || swing_type == SWING_H);
}

// Check if swing type is bearish  
bool IsBearishSwing(ENUM_SWING_TYPE swing_type)
{
    return (swing_type == SWING_LH || swing_type == SWING_LL || swing_type == SWING_L);
}

// Convert swing type to string
string SwingTypeToString(ENUM_SWING_TYPE swing_type)
{
    switch(swing_type)
    {
        case SWING_HL: return "HL";
        case SWING_HH: return "HH";
        case SWING_LH: return "LH";
        case SWING_LL: return "LL";
        case SWING_H:  return "H";
        case SWING_L:  return "L";
        default:       return "UNKNOWN";
    }
}

// Convert trend direction to string
string TrendDirectionToString(ENUM_TREND_DIRECTION direction)
{
    switch(direction)
    {
        case TREND_BULLISH: return "BULLISH";
        case TREND_BEARISH: return "BEARISH";
        default:            return "UNKNOWN";
    }
}

#endif // HL_STRUCTURES_MQH
