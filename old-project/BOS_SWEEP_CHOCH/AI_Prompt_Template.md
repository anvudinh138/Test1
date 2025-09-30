# 🤖 AI Prompt Template for HL-HH-LH-LL Algorithm Development
## v2.0 - Multi-Level Entry Detection System

---

## 🎯 **MASTER PROMPT FOR MT5 INDICATOR DEVELOPMENT**

```
You are an expert MT5 MQL5 developer specializing in advanced market structure analysis. 
Develop a professional MT5 indicator implementing the HL-HH-LH-LL algorithm with Multi-Level Entry Detection System and the following specifications:

### CORE ALGORITHM REQUIREMENTS:
1. **Pattern Recognition System**:
   - Implement 6 enum types: HL, HH, LH, LL, H, L
   - Complete upswing pattern: [HL,HH,HL,HH]
   - Complete downswing pattern: [LH,LL,LH,LL]
   - Real-time pattern detection on candle close only

2. **Multi-Level Entry Detection System**:
   - Array A (Main): Primary market structure tracking
   - Array B (Entry): Micro-pattern tracking within ChoCH range
   - Range-confined tracking: Clear Array B when price exits range
   - Dual-level analysis without requiring lower timeframes

3. **Market Structure Detection**:
   - BOS (Break of Structure): Price breaks established ranges
   - ChoCH (Change of Character): Pattern breaks with trend reversal
   - Sweep Detection: False ChoCH followed by opposite BOS
   - Range management: {A,B} with dynamic boundaries
   - Entry Signal Detection: Real ChoCH vs Sweep identification

4. **Retest Validation**:
   - Minimum 20% retest of range before confirmation (Array A)
   - Minimum 15% retest for micro-patterns (Array B - more sensitive)
   - Formula: |CurrentPrice - Extreme| > threshold * |RangeHigh - RangeLow|
   - Prevent shallow/weak retests that cause false signals

5. **Performance Optimizations**:
   - Confirm signals only on candle close (not tick-by-tick)
   - Use circular buffer for memory management
   - Implement early exit conditions for efficiency
   - Cache pattern recognition results

### VISUAL REQUIREMENTS:
- Draw swing points with clear HL/HH/LH/LL labels
- Highlight BOS breaks with arrows
- Mark ChoCH events with distinct colors
- Show Sweep patterns with special markers
- Display current range boundaries
- Color-code trend direction (bullish/bearish)

### CODE STRUCTURE:
```cpp
// Key structures needed
enum SwingType { L, H, HL, HH, LH, LL };
enum EntrySignal { NO_SIGNAL, REAL_CHOCH_ENTRY, SWEEP_ENTRY, WAIT_FOR_COMPLETION };

struct SwingPoint {
    double price;
    datetime time;
    SwingType type;
    int bar_index;
};

struct Range {
    double high;
    double low;
    bool has_upper_bound;
    bool has_lower_bound;
};

// Multi-Level System Structures
struct SwingArray {
    SwingPoint points[];
    Range range;
    int trend_direction; // 1=up, -1=down
    datetime created_time;
};

struct EntryArray {
    SwingPoint points[];
    Range confined_range;  // ChoCH range boundaries
    int original_direction; // Direction before ChoCH
    int choch_direction;   // Direction of ChoCH
    datetime created_time;
    bool is_active;
};

struct ChoCHEvent {
    double start_price;
    double end_price;
    int direction;
    datetime time;
    SwingArray* source_array;
};

// Core functions to implement
bool IsValidRetest(double current_price, Range range, double threshold);
SwingType DetermineSwingType(SwingPoint current, SwingPoint previous);
bool IsCompletePattern(SwingArray& array);
bool DetectBOS(double current_price, Range range);
bool DetectChoCH(SwingArray& arrayA);
void InitializeEntryTracking(ChoCHEvent choch_event);
EntrySignal AnalyzeEntryArray(EntryArray& arrayB);
bool IsSweep(EntryArray& arrayB);
void ClearStaleArrays();
```

Generate clean, efficient, and well-documented MQL5 code following MT5 best practices.
```

---

## 🎯 **MASTER PROMPT FOR MT5 EA DEVELOPMENT**

```
You are an expert MT5 MQL5 developer creating a sophisticated trading EA based on the HL-HH-LH-LL market structure algorithm.

### EA SPECIFICATIONS:
1. **Entry Logic (Multi-Level System)**:
   - BOS Continuation: Enter on retest after confirmed BOS (Array A level)
   - Real ChoCH Entry: Enter new direction when Array B confirms ChoCH + BOS same direction
   - Sweep Counter Entry: Enter original direction when Array B detects fake ChoCH + BOS opposite direction
   - Micro-Structure Timing: Use Array B patterns for precise entry without lower timeframes
   - FVG Integration: Enhanced entries when FVG aligns with ChoCH levels

2. **Risk Management**:
   - Dynamic stop loss based on market structure levels
   - Position sizing based on range volatility
   - Maximum risk per trade: 2% of account
   - Maximum concurrent positions: 3

3. **Trade Management**:
   - Partial profit taking at key structure levels
   - Trailing stop based on swing points
   - Break-even move after 1:1 RR achieved
   - Time-based exit for stale positions

4. **Signal Filtering**:
   - Multiple timeframe confirmation
   - Volume validation when available
   - Spread filtering for optimal execution
   - News avoidance periods

### ENTRY ALGORITHMS (Multi-Level System):
```cpp
// BOS Continuation Entry (Array A Level)
if (DetectBOS(arrayA) && ValidateRetest(arrayA) && !IsSweep(arrayA)) {
    if (trend == BULLISH && price_retest_from_below) {
        OpenBuyOrder();
    } else if (trend == BEARISH && price_retest_from_above) {
        OpenSellOrder();
    }
}

// Real ChoCH Entry (Array B Level)
for (EntryArray& arrayB : active_entry_arrays) {
    EntrySignal signal = AnalyzeEntryArray(arrayB);
    
    if (signal == REAL_CHOCH_ENTRY) {
        // True ChoCH confirmed by Array B micro-structure
        if (arrayB.choch_direction == BULLISH) {
            OpenBuyOrder(); // Enter new uptrend
        } else {
            OpenSellOrder(); // Enter new downtrend
        }
        ClearArray(arrayB);
    }
    
    else if (signal == SWEEP_ENTRY) {
        // Sweep detected by Array B - fake ChoCH
        if (arrayB.original_direction == BULLISH) {
            OpenBuyOrder(); // Continue original uptrend
        } else {
            OpenSellOrder(); // Continue original downtrend
        }
        ClearArray(arrayB);
    }
}

// ChoCH Detection and Array B Initialization
if (DetectChoCH(arrayA)) {
    ChoCHEvent choch_event = {
        .start_price = arrayA.range.low,
        .end_price = arrayA.range.high,
        .direction = GetChoCHDirection(arrayA),
        .time = TimeCurrent(),
        .source_array = &arrayA
    };
    InitializeEntryTracking(choch_event);
}
```

### REQUIRED PARAMETERS:
- MaxRiskPercent = 2.0 (Maximum risk per trade)
- RetestThreshold = 0.20 (20% retest validation)
- MaxSpread = 3.0 (Maximum spread for entry)
- MinRR = 1.5 (Minimum risk-reward ratio)
- PartialClosePercent = 50.0 (Percentage to close at first target)

Create professional, robust EA code with comprehensive error handling and logging.
```

---

## 🎯 **SPECIFIC COMPONENT PROMPTS**

### **Pattern Recognition Engine**
```
Create a highly efficient pattern recognition engine for the HL-HH-LH-LL algorithm:

Requirements:
1. Real-time detection of swing patterns on candle close
2. Memory-efficient circular buffer implementation
3. Accurate classification of 6 swing types
4. Pattern validation with configurable parameters
5. Early exit optimization for performance

Key Functions:
- UpdateSwingArray(double high, double low, datetime time)
- ClassifySwingPoint(SwingPoint current, SwingPoint[] history)
- ValidatePattern(SwingType[] pattern, int start_index)
- OptimizeArraySize(SwingPoint[] array, int max_size)

Focus on accuracy and performance optimization.
```

### **Range Management System**
```
Develop a dynamic range management system:

Features:
1. Automatic range boundary detection
2. Support for infinite boundaries (+/-Infinity)
3. Range update on pattern completion
4. Retest validation with configurable threshold
5. Multi-range tracking for complex scenarios

Structure:
```cpp
class RangeManager {
    private:
        Range active_ranges[];
        double retest_threshold;
    public:
        bool UpdateRange(SwingPoint new_point);
        bool ValidateRetest(double price, int range_id);
        Range GetActiveRange();
        void CleanupExpiredRanges();
};
```

Ensure thread-safe operations and memory efficiency.
```

### **Visual Display Engine**
```
Create a comprehensive visual display system for the indicator:

Visual Elements:
1. Swing point labels (HL, HH, LH, LL, H, L)
2. Trend lines connecting swing points
3. Range boundary lines (horizontal support/resistance)
4. BOS break arrows with directional indicators
5. ChoCH markers with color coding
6. Sweep identification with special symbols
7. FVG boxes when detected

Display Features:
- Configurable colors and styles
- Toggle visibility for each element type
- Auto-scaling for different timeframes
- Clean, professional appearance
- Minimal chart clutter while maintaining clarity

Use MT5 drawing objects efficiently for optimal performance.
```

---

## 🎯 **TESTING & VALIDATION PROMPTS**

### **Backtesting Framework**
```
Develop a comprehensive backtesting framework for the HL-HH-LH-LL EA:

Testing Requirements:
1. Historical pattern accuracy validation
2. Entry/exit timing precision testing
3. Risk management effectiveness analysis
4. Performance metrics calculation
5. Drawdown analysis and optimization

Key Metrics to Track:
- Pattern detection accuracy (% correct identifications)
- Signal quality (win rate, average RR)
- Maximum drawdown periods
- Recovery time analysis
- Consistency across different market conditions

Generate detailed reports with visual charts and statistical analysis.
```

### **Optimization Strategy**
```
Create an optimization strategy for the algorithm parameters:

Parameters to Optimize:
1. Retest threshold (15-25% range)
2. Minimum swing distance (5-20 pips)
3. Pattern confirmation bars (1-5 bars)
4. Risk management ratios
5. Time-based filters

Optimization Method:
- Multi-objective optimization (profit vs. drawdown)
- Walk-forward analysis for robustness
- Monte Carlo simulation for stability
- Cross-validation on different market periods
- Symbol-specific parameter sets

Focus on finding stable, robust parameters rather than curve-fitted results.
```

---

## 🎯 **INTEGRATION PROMPTS**

### **Multi-Timeframe Analysis**
```
Implement multi-timeframe confirmation for the HL-HH-LH-LL algorithm:

Timeframe Hierarchy:
- Primary: Current trading timeframe
- Confirmation: Higher timeframe (4x multiplier)
- Filter: Lower timeframe (1/4 multiplier)

Confirmation Rules:
1. Higher TF must show same trend direction
2. Lower TF provides precise entry timing
3. Structure alignment across timeframes
4. Divergence detection between timeframes

Enhance signal quality while maintaining execution speed.
```

### **News & Fundamental Integration**
```
Add economic news awareness to the EA:

Features:
1. Economic calendar integration
2. News impact assessment (High/Medium/Low)
3. Pre/post-news trading restrictions
4. Volatility adjustment during news events
5. Position management during major announcements

Implementation:
- API integration for real-time news feeds
- Configurable avoidance periods
- Dynamic risk adjustment
- Emergency position closure protocols

Protect capital during high-impact news events while maintaining trading opportunities.
```

---

## 📝 **USAGE INSTRUCTIONS**

1. **For New Development**: Copy the master prompt and add specific requirements
2. **For Component Work**: Use specific component prompts with additional context  
3. **For Testing**: Apply testing prompts with historical data specifications
4. **For Optimization**: Combine optimization prompts with performance requirements

---

*"These prompts are designed to accelerate development while maintaining the algorithm's integrity and performance standards."*
