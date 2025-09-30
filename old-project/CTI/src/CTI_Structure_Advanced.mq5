//+------------------------------------------------------------------+
//|                                 CTI_Structure_Advanced_Fixed.mq5 |
//|              Advanced Structure Analysis with Enhanced Logic    |
//|      HH/HL/LH/LL → Market Structure → BOS/CHoCH/Sweep + POI    |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "2.01"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "=== SWING DETECTION ==="
input int    SwingLookback       = 5;        // Fractal lookback for swing detection
input int    MinSwingDistance    = 3;        // Minimum bars between swings
input double MinSwingSize        = 0.0;      // Minimum swing size (0 = auto ATR based)
input double ATRMultiplier       = 0.5;      // ATR multiplier for min swing size

input group "=== STRUCTURE ANALYSIS ==="
input bool   StrictStructure     = true;     // Use strict HH/HL/LH/LL rules
input int    StructureDepth      = 3;        // How many swings back to analyze
input bool   RequireCloseBreak   = true;     // BOS requires close beyond level
input double BreakBuffer         = 2.0;      // Extra points for break confirmation

input group "=== DISPLAY OPTIONS ==="
input bool   ShowSwingPoints     = true;     // Show swing high/low points  
input bool   ShowStructure       = true;     // Show HH/HL/LH/LL labels
input bool   ShowBOS             = true;     // Show Break of Structure
input bool   ShowCHoCH           = true;     // Show Change of Character
input bool   ShowSweep           = true;     // Show Liquidity Sweeps
input bool   ShowTrendLines      = true;     // Show structure trend lines
input bool   ShowPOI             = true;     // Show Points of Interest
input int    MaxLabelsOnChart    = 100;      // Maximum labels to keep

input group "=== COLORS & STYLING ==="
input color  ColorHH             = clrLime;
input color  ColorHL             = clrLimeGreen;
input color  ColorLH             = clrOrange; 
input color  ColorLL             = clrRed;
input color  ColorBOS_Bull       = clrBlue;
input color  ColorBOS_Bear       = clrMagenta;
input color  ColorCHoCH_Bull     = clrCyan;
input color  ColorCHoCH_Bear     = clrYellow;
input color  ColorSweep_Bull     = clrLightBlue;
input color  ColorSweep_Bear     = clrPink;
input color  ColorTrendLine      = clrGray;
input color  ColorPOI            = clrWhite;
input int    TextSize            = 10;
input int    LabelOffset         = 20;

//--- Enhanced enums
enum TrendDirection
{
    TREND_UNKNOWN = 0,
    TREND_BULLISH = 1,
    TREND_BEARISH = -1,
    TREND_RANGING = 2
};

enum SwingType
{
    SWING_HIGH = 1,
    SWING_LOW = -1
};

enum StructureType
{
    STRUCTURE_NONE = 0,
    STRUCTURE_HH = 1,    // Higher High
    STRUCTURE_HL = 2,    // Higher Low
    STRUCTURE_LH = 3,    // Lower High  
    STRUCTURE_LL = 4     // Lower Low
};

enum BreakType
{
    BREAK_NONE = 0,
    BREAK_BOS_BULL = 1,
    BREAK_BOS_BEAR = 2,
    BREAK_CHOCH_BULL = 3,
    BREAK_CHOCH_BEAR = 4,
    BREAK_SWEEP_BULL = 5,
    BREAK_SWEEP_BEAR = 6
};

//--- Swing data arrays
datetime swingTimes[];
double swingPrices[];
int swingIndices[];
SwingType swingTypes[];
StructureType swingStructures[];
bool swingProcessed[];
bool swingIsSignificant[];
double swingStrength[];
int swingIds[];

//--- Break data arrays  
BreakType breakTypes[];
datetime breakTimes[];
double breakPrices[];
int breakSwingIds[];
bool breakConfirmed[];
string breakDescriptions[];

//--- Market structure
struct MarketStructure
{
    TrendDirection trend;
    datetime lastHighTime;
    double lastHighPrice;
    datetime lastLowTime;
    double lastLowPrice;
    datetime trendChangeTime;
    bool isValid;
    double trendStrength;
};

//--- Global variables
MarketStructure market;
int swingCount = 0;
int breakCount = 0;
int atrHandle = INVALID_HANDLE;
string objPrefix = "CTSA_";
int uniqueId = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI Structure Advanced v2.01");
    
    // Initialize swing arrays
    ArrayResize(swingTimes, 200);
    ArrayResize(swingPrices, 200);
    ArrayResize(swingIndices, 200);
    ArrayResize(swingTypes, 200);
    ArrayResize(swingStructures, 200);
    ArrayResize(swingProcessed, 200);
    ArrayResize(swingIsSignificant, 200);
    ArrayResize(swingStrength, 200);
    ArrayResize(swingIds, 200);
    
    // Initialize break arrays
    ArrayResize(breakTypes, 100);
    ArrayResize(breakTimes, 100);
    ArrayResize(breakPrices, 100);
    ArrayResize(breakSwingIds, 100);
    ArrayResize(breakConfirmed, 100);
    ArrayResize(breakDescriptions, 100);
    
    // Initialize market structure
    market.trend = TREND_UNKNOWN;
    market.isValid = false;
    market.trendStrength = 0.0;
    market.trendChangeTime = 0;
    market.lastHighTime = 0;
    market.lastHighPrice = 0;
    market.lastLowTime = 0;
    market.lastLowPrice = 0;
    
    // Create ATR handle for swing filtering
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator handle");
        return INIT_FAILED;
    }
    
    // Clear all previous objects
    CleanupObjects();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupObjects();
    
    if(atrHandle != INVALID_HANDLE)
    {
        IndicatorRelease(atrHandle);
        atrHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < SwingLookback * 2 + 20) return 0;
    
    // Convert to non-series arrays
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArraySetAsSeries(open, false);
    
    // Get current ATR value
    double atrValue = GetCurrentATR();
    
    // Detect swing points with enhanced logic
    DetectSwingPointsAdvanced(rates_total, time, high, low, close, atrValue);
    
    // Analyze market structure
    AnalyzeMarketStructure();
    
    // Detect breaks with advanced logic
    DetectBreaksAdvanced(rates_total, time, high, low, close);
    
    // Update visual elements
    UpdateVisualElements();
    
    // Cleanup old objects if too many
    if(ObjectsTotal(0) > MaxLabelsOnChart)
    {
        CleanupOldObjects();
    }
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Get current ATR value                                           |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
    if(atrHandle == INVALID_HANDLE) return 0.0;
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
        return 0.0;
        
    return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Advanced swing point detection with filtering                   |
//+------------------------------------------------------------------+
void DetectSwingPointsAdvanced(const int total, const datetime &time[],
                               const double &high[], const double &low[], 
                               const double &close[], double atrValue)
{
    double minSize = (MinSwingSize > 0) ? MinSwingSize * _Point : atrValue * ATRMultiplier;
    
    for(int i = SwingLookback; i < total - SwingLookback - 5; i++)
    {
        // Check for swing high
        if(IsSwingHigh(high, i, SwingLookback))
        {
            // Additional validations
            if(ValidateSwingHigh(i, time, high, low, minSize))
            {
                if(!SwingExists(time[i], high[i]))
                {
                    AddSwingPointAdvanced(time[i], high[i], i, SWING_HIGH, atrValue);
                }
            }
        }
        
        // Check for swing low
        if(IsSwingLow(low, i, SwingLookback))
        {
            // Additional validations
            if(ValidateSwingLow(i, time, high, low, minSize))
            {
                if(!SwingExists(time[i], low[i]))
                {
                    AddSwingPointAdvanced(time[i], low[i], i, SWING_LOW, atrValue);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if point is swing high                                    |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int index, int lookback)
{
    double currentHigh = high[index];
    
    for(int i = 1; i <= lookback; i++)
    {
        if(currentHigh <= high[index - i] || currentHigh <= high[index + i])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if point is swing low                                     |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int index, int lookback)
{
    double currentLow = low[index];
    
    for(int i = 1; i <= lookback; i++)
    {
        if(currentLow >= low[index - i] || currentLow >= low[index + i])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Validate swing high with additional criteria                    |
//+------------------------------------------------------------------+
bool ValidateSwingHigh(int index, const datetime &time[], const double &high[],
                      const double &low[], double minSize)
{
    // Check minimum distance from last swing
    if(swingCount > 0)
    {
        int lastIndex = swingIndices[swingCount - 1];
        if(MathAbs(index - lastIndex) < MinSwingDistance)
            return false;
    }
    
    // Check minimum swing size if specified
    if(minSize > 0 && swingCount > 0)
    {
        int lastSwingIndex = swingCount - 1;
        if(swingTypes[lastSwingIndex] == SWING_LOW)
        {
            double swingRange = high[index] - swingPrices[lastSwingIndex];
            if(swingRange < minSize)
                return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate swing low with additional criteria                     |
//+------------------------------------------------------------------+
bool ValidateSwingLow(int index, const datetime &time[], const double &high[],
                     const double &low[], double minSize)
{
    // Check minimum distance from last swing
    if(swingCount > 0)
    {
        int lastIndex = swingIndices[swingCount - 1];
        if(MathAbs(index - lastIndex) < MinSwingDistance)
            return false;
    }
    
    // Check minimum swing size if specified
    if(minSize > 0 && swingCount > 0)
    {
        int lastSwingIndex = swingCount - 1;
        if(swingTypes[lastSwingIndex] == SWING_HIGH)
        {
            double swingRange = swingPrices[lastSwingIndex] - low[index];
            if(swingRange < minSize)
                return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if swing already exists                                   |
//+------------------------------------------------------------------+
bool SwingExists(datetime swingTime, double swingPrice)
{
    for(int i = 0; i < swingCount; i++)
    {
        if(swingTimes[i] == swingTime && MathAbs(swingPrices[i] - swingPrice) < _Point * 2)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add swing point with advanced properties                        |
//+------------------------------------------------------------------+
void AddSwingPointAdvanced(datetime swingTime, double swingPrice, int swingIndex, 
                          SwingType type, double atrValue)
{
    if(swingCount >= ArraySize(swingTimes))
    {
        // Remove oldest swing
        for(int i = 0; i < swingCount - 1; i++)
        {
            swingTimes[i] = swingTimes[i + 1];
            swingPrices[i] = swingPrices[i + 1];
            swingIndices[i] = swingIndices[i + 1];
            swingTypes[i] = swingTypes[i + 1];
            swingStructures[i] = swingStructures[i + 1];
            swingProcessed[i] = swingProcessed[i + 1];
            swingIsSignificant[i] = swingIsSignificant[i + 1];
            swingStrength[i] = swingStrength[i + 1];
            swingIds[i] = swingIds[i + 1];
        }
        swingCount--;
    }
    
    // Calculate swing strength based on various factors
    double strength = CalculateSwingStrength(swingIndex, type, atrValue);
    
    swingTimes[swingCount] = swingTime;
    swingPrices[swingCount] = swingPrice;
    swingIndices[swingCount] = swingIndex;
    swingTypes[swingCount] = type;
    swingStructures[swingCount] = STRUCTURE_NONE;
    swingProcessed[swingCount] = false;
    swingIsSignificant[swingCount] = (strength > 0.6);
    swingStrength[swingCount] = strength;
    swingIds[swingCount] = ++uniqueId;
    
    swingCount++;
    
    // Sort swings by time
    SortSwingsByTime();
    
    // Show swing point
    if(ShowSwingPoints)
    {
        DisplaySwingPoint(swingCount - 1);
    }
}

//+------------------------------------------------------------------+
//| Calculate swing strength (0-1)                                  |
//+------------------------------------------------------------------+
double CalculateSwingStrength(int index, SwingType type, double atrValue)
{
    // This is a simplified strength calculation
    double baseStrength = 0.5;
    
    // Add strength based on swing size relative to ATR
    if(swingCount > 0 && atrValue > 0)
    {
        int lastSwingIndex = swingCount - 1;
        if(swingTypes[lastSwingIndex] != type) // Different swing type
        {
            double swingSize = MathAbs(swingPrices[lastSwingIndex] - ((type == SWING_HIGH) ? 
                              iHigh(_Symbol, PERIOD_CURRENT, index) : 
                              iLow(_Symbol, PERIOD_CURRENT, index)));
            double sizeRatio = swingSize / atrValue;
            baseStrength += MathMin(0.4, sizeRatio * 0.1);
        }
    }
    
    return MathMin(1.0, baseStrength);
}

//+------------------------------------------------------------------+
//| Sort swings by time                                             |
//+------------------------------------------------------------------+
void SortSwingsByTime()
{
    for(int i = 0; i < swingCount - 1; i++)
    {
        for(int j = i + 1; j < swingCount; j++)
        {
            if(swingTimes[i] > swingTimes[j])
            {
                // Swap all arrays
                datetime tempTime = swingTimes[i];
                swingTimes[i] = swingTimes[j];
                swingTimes[j] = tempTime;
                
                double tempPrice = swingPrices[i];
                swingPrices[i] = swingPrices[j];
                swingPrices[j] = tempPrice;
                
                int tempIndex = swingIndices[i];
                swingIndices[i] = swingIndices[j];
                swingIndices[j] = tempIndex;
                
                SwingType tempType = swingTypes[i];
                swingTypes[i] = swingTypes[j];
                swingTypes[j] = tempType;
                
                StructureType tempStructure = swingStructures[i];
                swingStructures[i] = swingStructures[j];
                swingStructures[j] = tempStructure;
                
                bool tempProcessed = swingProcessed[i];
                swingProcessed[i] = swingProcessed[j];
                swingProcessed[j] = tempProcessed;
                
                bool tempSignificant = swingIsSignificant[i];
                swingIsSignificant[i] = swingIsSignificant[j];
                swingIsSignificant[j] = tempSignificant;
                
                double tempStrength = swingStrength[i];
                swingStrength[i] = swingStrength[j];
                swingStrength[j] = tempStrength;
                
                int tempId = swingIds[i];
                swingIds[i] = swingIds[j];
                swingIds[j] = tempId;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze market structure with enhanced logic                    |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
    if(swingCount < 2) return;
    
    // Find recent highs and lows
    UpdateMarketStructure();
    
    // Analyze each unprocessed swing
    for(int i = 1; i < swingCount; i++)
    {
        if(swingProcessed[i]) continue;
        
        StructureType structure = DetermineStructureType(i);
        swingStructures[i] = structure;
        swingProcessed[i] = true;
        
        // Update market trend based on structure
        UpdateMarketTrend(structure);
        
        // Display structure label
        if(ShowStructure && structure != STRUCTURE_NONE)
        {
            DisplayStructureLabel(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Update market structure tracking                                |
//+------------------------------------------------------------------+
void UpdateMarketStructure()
{
    // Find most recent high and low
    for(int i = swingCount - 1; i >= 0; i--)
    {
        if(swingTypes[i] == SWING_HIGH && market.lastHighTime < swingTimes[i])
        {
            market.lastHighTime = swingTimes[i];
            market.lastHighPrice = swingPrices[i];
        }
        if(swingTypes[i] == SWING_LOW && market.lastLowTime < swingTimes[i])
        {
            market.lastLowTime = swingTimes[i];
            market.lastLowPrice = swingPrices[i];
        }
    }
    
    market.isValid = (market.lastHighTime > 0 && market.lastLowTime > 0);
}

//+------------------------------------------------------------------+
//| Determine structure type for swing                              |
//+------------------------------------------------------------------+
StructureType DetermineStructureType(int currentIndex)
{
    // Find the last swing of the same type
    int lastSameTypeIndex = -1;
    for(int i = currentIndex - 1; i >= 0; i--)
    {
        if(swingTypes[i] == swingTypes[currentIndex])
        {
            lastSameTypeIndex = i;
            break;
        }
    }
    
    if(lastSameTypeIndex == -1) return STRUCTURE_NONE;
    
    if(StrictStructure)
    {
        // Apply strict structure rules
        return DetermineStructureStrict(currentIndex, lastSameTypeIndex);
    }
    else
    {
        // Apply relaxed structure rules
        return DetermineStructureRelaxed(currentIndex, lastSameTypeIndex);
    }
}

//+------------------------------------------------------------------+
//| Determine structure with strict rules                           |
//+------------------------------------------------------------------+
StructureType DetermineStructureStrict(int currentIndex, int previousIndex)
{
    double threshold = _Point * 2; // Minimum difference threshold
    
    if(swingTypes[currentIndex] == SWING_HIGH)
    {
        if(swingPrices[currentIndex] > swingPrices[previousIndex] + threshold)
            return STRUCTURE_HH;
        else if(swingPrices[currentIndex] < swingPrices[previousIndex] - threshold)
            return STRUCTURE_LH;
    }
    else if(swingTypes[currentIndex] == SWING_LOW)
    {
        if(swingPrices[currentIndex] > swingPrices[previousIndex] + threshold)
            return STRUCTURE_HL;
        else if(swingPrices[currentIndex] < swingPrices[previousIndex] - threshold)
            return STRUCTURE_LL;
    }
    
    return STRUCTURE_NONE;
}

//+------------------------------------------------------------------+
//| Determine structure with relaxed rules                          |
//+------------------------------------------------------------------+
StructureType DetermineStructureRelaxed(int currentIndex, int previousIndex)
{
    if(swingTypes[currentIndex] == SWING_HIGH)
    {
        return (swingPrices[currentIndex] >= swingPrices[previousIndex]) ? STRUCTURE_HH : STRUCTURE_LH;
    }
    else if(swingTypes[currentIndex] == SWING_LOW)
    {
        return (swingPrices[currentIndex] >= swingPrices[previousIndex]) ? STRUCTURE_HL : STRUCTURE_LL;
    }
    
    return STRUCTURE_NONE;
}

//+------------------------------------------------------------------+
//| Update market trend based on structure                          |
//+------------------------------------------------------------------+
void UpdateMarketTrend(StructureType structure)
{
    TrendDirection newTrend = market.trend;
    
    switch(structure)
    {
        case STRUCTURE_HH:
        case STRUCTURE_HL:
            newTrend = TREND_BULLISH;
            break;
            
        case STRUCTURE_LH:
        case STRUCTURE_LL:
            newTrend = TREND_BEARISH;
            break;
    }
    
    // Check for trend change
    if(newTrend != market.trend && market.trend != TREND_UNKNOWN)
    {
        market.trendChangeTime = TimeCurrent();
    }
    
    market.trend = newTrend;
}

//+------------------------------------------------------------------+
//| Detect breaks with advanced logic                               |
//+------------------------------------------------------------------+
void DetectBreaksAdvanced(const int total, const datetime &time[],
                         const double &high[], const double &low[], const double &close[])
{
    // Check recent bars for breaks
    for(int i = 1; i < MathMin(20, total); i++)
    {
        CheckForAdvancedBreaks(i, time, high, low, close);
    }
}

//+------------------------------------------------------------------+
//| Check for advanced break patterns                               |
//+------------------------------------------------------------------+
void CheckForAdvancedBreaks(int barIndex, const datetime &time[], 
                           const double &high[], const double &low[], const double &close[])
{
    double currentHigh = high[barIndex];
    double currentLow = low[barIndex];
    double currentClose = close[barIndex];
    datetime currentTime = time[barIndex];
    
    // Check against recent significant swings
    for(int i = swingCount - 1; i >= MathMax(0, swingCount - 10); i--)
    {
        if(swingTimes[i] >= currentTime) continue;
        
        // Enhanced BOS detection
        if(ShowBOS) CheckForBOSAdvanced(barIndex, i, currentTime, currentHigh, currentLow, currentClose);
        
        // Enhanced CHoCH detection  
        if(ShowCHoCH) CheckForCHoCHAdvanced(barIndex, i, currentTime, currentHigh, currentLow, currentClose);
        
        // Enhanced Sweep detection
        if(ShowSweep) CheckForSweepAdvanced(barIndex, i, currentTime, currentHigh, currentLow, currentClose);
    }
}

//+------------------------------------------------------------------+
//| Advanced BOS detection                                          |
//+------------------------------------------------------------------+
void CheckForBOSAdvanced(int barIndex, int swingIndex, datetime currentTime,
                        double currentHigh, double currentLow, double currentClose)
{
    double buffer = BreakBuffer * _Point;
    bool isBOSBull = false, isBOSBear = false;
    
    if(swingTypes[swingIndex] == SWING_HIGH)
    {
        if(RequireCloseBreak)
            isBOSBull = (currentClose > swingPrices[swingIndex] + buffer);
        else
            isBOSBull = (currentHigh > swingPrices[swingIndex] + buffer);
    }
    else if(swingTypes[swingIndex] == SWING_LOW)
    {
        if(RequireCloseBreak)
            isBOSBear = (currentClose < swingPrices[swingIndex] - buffer);
        else
            isBOSBear = (currentLow < swingPrices[swingIndex] - buffer);
    }
    
    if(isBOSBull || isBOSBear)
    {
        // Validate this is a true BOS (creates new structure)
        if(ValidateBOS(swingIndex, isBOSBull))
        {
            RecordBreakEvent(isBOSBull ? BREAK_BOS_BULL : BREAK_BOS_BEAR, 
                           currentTime, currentClose, swingIds[swingIndex], "BOS " + (isBOSBull ? "↑" : "↓"));
        }
    }
}

//+------------------------------------------------------------------+
//| Advanced CHoCH detection                                        |
//+------------------------------------------------------------------+
void CheckForCHoCHAdvanced(int barIndex, int swingIndex, datetime currentTime,
                          double currentHigh, double currentLow, double currentClose)
{
    // CHoCH logic: trend change confirmed by structure break
    bool isCHoCHBull = false, isCHoCHBear = false;
    
    if(market.trend == TREND_BEARISH && swingStructures[swingIndex] == STRUCTURE_HL)
    {
        isCHoCHBull = true;
    }
    else if(market.trend == TREND_BULLISH && swingStructures[swingIndex] == STRUCTURE_LH)
    {
        isCHoCHBear = true;
    }
    
    if(isCHoCHBull || isCHoCHBear)
    {
        RecordBreakEvent(isCHoCHBull ? BREAK_CHOCH_BULL : BREAK_CHOCH_BEAR,
                        swingTimes[swingIndex], swingPrices[swingIndex], swingIds[swingIndex], 
                        "CHoCH " + (isCHoCHBull ? "↑" : "↓"));
    }
}

//+------------------------------------------------------------------+
//| Advanced Sweep detection                                        |
//+------------------------------------------------------------------+
void CheckForSweepAdvanced(int barIndex, int swingIndex, datetime currentTime,
                          double currentHigh, double currentLow, double currentClose)
{
    double buffer = BreakBuffer * _Point;
    bool isSweepBull = false, isSweepBear = false;
    
    if(swingTypes[swingIndex] == SWING_HIGH)
    {
        // Wick breaks high but doesn't close above
        isSweepBull = (currentHigh > swingPrices[swingIndex] + buffer) && 
                      (currentClose <= swingPrices[swingIndex] + buffer);
    }
    else if(swingTypes[swingIndex] == SWING_LOW)
    {
        // Wick breaks low but doesn't close below  
        isSweepBear = (currentLow < swingPrices[swingIndex] - buffer) && 
                      (currentClose >= swingPrices[swingIndex] - buffer);
    }
    
    if(isSweepBull || isSweepBear)
    {
        RecordBreakEvent(isSweepBull ? BREAK_SWEEP_BULL : BREAK_SWEEP_BEAR,
                        currentTime, isSweepBull ? currentHigh : currentLow, 
                        swingIds[swingIndex], "Sweep " + (isSweepBull ? "↑" : "↓"));
    }
}

//+------------------------------------------------------------------+
//| Validate BOS against market structure                           |
//+------------------------------------------------------------------+
bool ValidateBOS(int swingIndex, bool isBullish)
{
    // Additional validation logic can be added here
    return true;
}

//+------------------------------------------------------------------+
//| Record break event                                              |
//+------------------------------------------------------------------+
void RecordBreakEvent(BreakType breakType, datetime eventTime, double eventPrice,
                     int swingId, string description)
{
    // Check if this event already exists
    string eventKey = description + "_" + TimeToString(eventTime, TIME_MINUTES);
    if(BreakEventExists(eventKey)) return;
    
    if(breakCount >= ArraySize(breakTypes))
    {
        // Remove oldest break
        for(int i = 0; i < breakCount - 1; i++)
        {
            breakTypes[i] = breakTypes[i + 1];
            breakTimes[i] = breakTimes[i + 1];
            breakPrices[i] = breakPrices[i + 1];
            breakSwingIds[i] = breakSwingIds[i + 1];
            breakConfirmed[i] = breakConfirmed[i + 1];
            breakDescriptions[i] = breakDescriptions[i + 1];
        }
        breakCount--;
    }
    
    breakTypes[breakCount] = breakType;
    breakTimes[breakCount] = eventTime;
    breakPrices[breakCount] = eventPrice;
    breakSwingIds[breakCount] = swingId;
    breakConfirmed[breakCount] = true;
    breakDescriptions[breakCount] = description;
    
    breakCount++;
    
    // Display the break event
    DisplayBreakEvent(breakCount - 1);
}

//+------------------------------------------------------------------+
//| Check if break event already exists                             |
//+------------------------------------------------------------------+
bool BreakEventExists(string eventKey)
{
    string objName = objPrefix + eventKey;
    return (ObjectFind(0, objName) >= 0);
}

//+------------------------------------------------------------------+
//| Display swing point on chart                                    |
//+------------------------------------------------------------------+
void DisplaySwingPoint(int swingIndex)
{
    string objName = objPrefix + "SW_" + IntegerToString(swingIds[swingIndex]);
    color swingColor = (swingTypes[swingIndex] == SWING_HIGH) ? clrDodgerBlue : clrGold;
    string swingText = (swingTypes[swingIndex] == SWING_HIGH) ? "H" : "L";
    
    if(swingIsSignificant[swingIndex])
    {
        swingText += "★";
        swingColor = (swingTypes[swingIndex] == SWING_HIGH) ? clrBlue : clrOrange;
    }
    
    CreateTextLabel(objName, swingTimes[swingIndex], swingPrices[swingIndex], swingColor, swingText, 8);
}

//+------------------------------------------------------------------+
//| Display structure label                                         |
//+------------------------------------------------------------------+
void DisplayStructureLabel(int swingIndex)
{
    string objName = objPrefix + "STR_" + IntegerToString(swingIds[swingIndex]);
    string structureText = GetStructureText(swingStructures[swingIndex]);
    color structureColor = GetStructureColor(swingStructures[swingIndex]);
    
    CreateTextLabel(objName, swingTimes[swingIndex], swingPrices[swingIndex], structureColor, structureText, TextSize);
}

//+------------------------------------------------------------------+
//| Display break event                                             |
//+------------------------------------------------------------------+
void DisplayBreakEvent(int breakIndex)
{
    string objName = objPrefix + breakDescriptions[breakIndex] + "_" + TimeToString(breakTimes[breakIndex], TIME_MINUTES);
    color breakColor = GetBreakColor(breakTypes[breakIndex]);
    
    CreateTextLabel(objName, breakTimes[breakIndex], breakPrices[breakIndex], breakColor, breakDescriptions[breakIndex], TextSize);
    
    // Draw connecting line if enabled
    if(ShowTrendLines)
    {
        DrawBreakLine(breakIndex);
    }
}

//+------------------------------------------------------------------+
//| Draw line for break event                                       |
//+------------------------------------------------------------------+
void DrawBreakLine(int breakIndex)
{
    // Find the related swing point
    int relatedSwingIndex = -1;
    
    for(int i = 0; i < swingCount; i++)
    {
        if(swingIds[i] == breakSwingIds[breakIndex])
        {
            relatedSwingIndex = i;
            break;
        }
    }
    
    if(relatedSwingIndex == -1) return;
    
    string lineName = objPrefix + "LINE_" + breakDescriptions[breakIndex] + "_" + TimeToString(breakTimes[breakIndex], TIME_MINUTES);
    color lineColor = GetBreakColor(breakTypes[breakIndex]);
    
    CreateTrendLine(lineName, swingTimes[relatedSwingIndex], swingPrices[relatedSwingIndex], 
                   breakTimes[breakIndex], swingPrices[relatedSwingIndex], lineColor, STYLE_DASH);
}

//+------------------------------------------------------------------+
//| Get structure text                                              |
//+------------------------------------------------------------------+
string GetStructureText(StructureType structure)
{
    switch(structure)
    {
        case STRUCTURE_HH: return "HH";
        case STRUCTURE_HL: return "HL";
        case STRUCTURE_LH: return "LH";
        case STRUCTURE_LL: return "LL";
        default: return "";
    }
}

//+------------------------------------------------------------------+
//| Get structure color                                             |
//+------------------------------------------------------------------+
color GetStructureColor(StructureType structure)
{
    switch(structure)
    {
        case STRUCTURE_HH: return ColorHH;
        case STRUCTURE_HL: return ColorHL;
        case STRUCTURE_LH: return ColorLH;
        case STRUCTURE_LL: return ColorLL;
        default: return clrWhite;
    }
}

//+------------------------------------------------------------------+
//| Get break event color                                           |
//+------------------------------------------------------------------+
color GetBreakColor(BreakType breakType)
{
    switch(breakType)
    {
        case BREAK_BOS_BULL: return ColorBOS_Bull;
        case BREAK_BOS_BEAR: return ColorBOS_Bear;
        case BREAK_CHOCH_BULL: return ColorCHoCH_Bull;
        case BREAK_CHOCH_BEAR: return ColorCHoCH_Bear;
        case BREAK_SWEEP_BULL: return ColorSweep_Bull;
        case BREAK_SWEEP_BEAR: return ColorSweep_Bear;
        default: return clrWhite;
    }
}

//+------------------------------------------------------------------+
//| Update visual elements                                          |
//+------------------------------------------------------------------+
void UpdateVisualElements()
{
    // Draw trend lines if enabled
    if(ShowTrendLines)
    {
        DrawTrendLines();
    }
    
    // Show POI if enabled
    if(ShowPOI)
    {
        HighlightPointsOfInterest();
    }
}

//+------------------------------------------------------------------+
//| Draw trend lines connecting swing points                        |
//+------------------------------------------------------------------+
void DrawTrendLines()
{
    if(swingCount < 2) return;
    
    // Draw lines connecting recent swing highs
    int lastHighIndex1 = -1, lastHighIndex2 = -1;
    int highCount = 0;
    
    for(int i = swingCount - 1; i >= 0 && highCount < 2; i--)
    {
        if(swingTypes[i] == SWING_HIGH)
        {
            if(highCount == 0) lastHighIndex1 = i;
            else if(highCount == 1) lastHighIndex2 = i;
            highCount++;
        }
    }
    
    if(lastHighIndex1 >= 0 && lastHighIndex2 >= 0)
    {
        string lineName = objPrefix + "TREND_HIGH";
        CreateTrendLine(lineName, swingTimes[lastHighIndex2], swingPrices[lastHighIndex2], 
                       swingTimes[lastHighIndex1], swingPrices[lastHighIndex1], ColorTrendLine, STYLE_SOLID);
    }
    
    // Draw lines connecting recent swing lows
    int lastLowIndex1 = -1, lastLowIndex2 = -1;
    int lowCount = 0;
    
    for(int i = swingCount - 1; i >= 0 && lowCount < 2; i--)
    {
        if(swingTypes[i] == SWING_LOW)
        {
            if(lowCount == 0) lastLowIndex1 = i;
            else if(lowCount == 1) lastLowIndex2 = i;
            lowCount++;
        }
    }
    
    if(lastLowIndex1 >= 0 && lastLowIndex2 >= 0)
    {
        string lineName = objPrefix + "TREND_LOW";
        CreateTrendLine(lineName, swingTimes[lastLowIndex2], swingPrices[lastLowIndex2], 
                       swingTimes[lastLowIndex1], swingPrices[lastLowIndex1], ColorTrendLine, STYLE_SOLID);
    }
}

//+------------------------------------------------------------------+
//| Highlight points of interest                                    |
//+------------------------------------------------------------------+
void HighlightPointsOfInterest()
{
    // Highlight significant swing points that could be POI
    for(int i = 0; i < swingCount; i++)
    {
        if(swingIsSignificant[i] && swingStrength[i] > 0.7)
        {
            string objName = objPrefix + "POI_" + IntegerToString(swingIds[i]);
            CreateHorizontalLine(objName, swingPrices[i], ColorPOI, STYLE_DOT);
        }
    }
}

//+------------------------------------------------------------------+
//| Create text label                                               |
//+------------------------------------------------------------------+
void CreateTextLabel(string objName, datetime time, double price, color clr, string text, int size)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    ObjectCreate(0, objName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LOWER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Create trend line                                               |
//+------------------------------------------------------------------+
void CreateTrendLine(string objName, datetime time1, double price1, datetime time2, double price2,
                    color clr, ENUM_LINE_STYLE style)
{
    if(ObjectFind(0, objName) >= 0) 
    {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_RAY, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Create horizontal line                                          |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string objName, double price, color clr, ENUM_LINE_STYLE style)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Cleanup old objects to prevent chart clutter                   |
//+------------------------------------------------------------------+
void CleanupOldObjects()
{
    datetime cutoffTime = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * 100;
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, objPrefix) == 0)
        {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            if(objTime < cutoffTime)
            {
                ObjectDelete(0, objName);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Cleanup all objects                                             |
//+------------------------------------------------------------------+
void CleanupObjects()
{
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, objPrefix) == 0)
        {
            ObjectDelete(0, objName);
        }
    }
}
//+------------------------------------------------------------------+
