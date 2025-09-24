//+------------------------------------------------------------------+
//|                                          CTI_ICT_Optimized.mq5 |
//|                    Optimized ICT Structure - No Lag Version    |
//|         BOS/CHoCH Lines from Swing to Break Point Only         |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "=== SWING DETECTION ==="
input int    SwingLookback    = 3;        // Fractal lookback for swing detection
input bool   ShowSwingPoints  = true;     // Show swing high/low points
input bool   ShowStructure    = true;     // Show HH/HL/LH/LL labels

input group "=== ICT LINES ==="
input bool   ShowBOSLines     = true;     // Show BOS lines (swing to break)
input bool   ShowCHoCHLines   = true;     // Show CHoCH lines (swing to break)
input bool   ShowSweepLines   = true;     // Show Sweep lines (wick break only)
input bool   ShowCHoCHFVG     = true;     // Show FVG on CHoCH waves only
input bool   QualityFilterCHoCH = false;  // Only show CHoCH with FVG (high quality)

input group "=== PERFORMANCE ==="
input int    MaxSwings        = 20;       // Maximum swings to track
input int    CheckBars        = 5;        // Recent bars to check for breaks

input group "=== VISUAL ==="
input color  ColorHH          = clrLime;
input color  ColorHL          = clrGreen;
input color  ColorLH          = clrOrange;
input color  ColorLL          = clrRed;
input color  ColorBOSLine     = clrBlue;
input color  ColorCHoCHLine   = clrYellow;
input color  ColorSweepLine   = clrOrange;
input color  ColorFVG         = clrMagenta;
input int    TextSize         = 10;
input bool   DebugMode        = true;     // Enable for CHoCH debugging

//--- Enums
enum TrendDirection
{
    TREND_UNKNOWN = 0,
    TREND_BULLISH = 1,
    TREND_BEARISH = -1
};

enum SwingType
{
    SWING_HIGH = 1,
    SWING_LOW = -1
};

enum StructureType
{
    STRUCTURE_NONE = 0,
    STRUCTURE_HH = 1,
    STRUCTURE_HL = 2,
    STRUCTURE_LH = 3,
    STRUCTURE_LL = 4
};

enum BreakType
{
    BREAK_NONE = 0,
    BREAK_SWEEP = 1,    // Wick break only (liquidity grab)
    BREAK_BOS = 2,      // Close break (structure continuation) 
    BREAK_CHOCH = 3     // Close break (structure change)
};

//--- Lightweight structures
struct SimpleSwing
{
    datetime time;
    double price;
    int index;
    SwingType type;
    StructureType structure;
    bool processed;
    bool lineCreated;
    bool hasFVG;        // Quality indicator for CHoCH
    BreakType breakType; // What type of break occurred
};

//--- Global variables
SimpleSwing swings[50]; // Fixed size array for performance
int swingCount = 0;
TrendDirection currentTrend = TREND_UNKNOWN;
TrendDirection previousTrend = TREND_UNKNOWN;
string objPrefix = "ICT_OPT_";
int lastProcessedBar = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI ICT Optimized");
    
    // Initialize array
    for(int i = 0; i < 50; i++)
    {
        swings[i].time = 0;
        swings[i].price = 0;
        swings[i].index = 0;
        swings[i].type = SWING_HIGH;
        swings[i].structure = STRUCTURE_NONE;
        swings[i].processed = false;
        swings[i].lineCreated = false;
        swings[i].hasFVG = false;
        swings[i].breakType = BREAK_NONE;
    }
    
    swingCount = 0;
    lastProcessedBar = 0;
    
    CleanupObjects();
    
    Print("[ICT Optimized] Initialized - Performance mode enabled");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupObjects();
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
    if(rates_total < SwingLookback * 2 + 10) return 0;
    
    // Performance optimization: only process new bars
    int limit = rates_total - prev_calculated;
    if(limit > 10) limit = 10; // Limit processing to last 10 bars max
    
    // Convert to non-series arrays (only recent bars)
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    
    // Step 1: Detect swing points (optimized)
    DetectSwingPointsOptimized(rates_total, time, high, low, close);
    
    // Step 2: Analyze structure (only unprocessed swings)
    AnalyzeStructureOptimized();
    
    // Step 3: Check for structure breaks (only recent bars)
    CheckStructureBreaksOptimized(rates_total, time, high, low, close);
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Optimized swing point detection                                 |
//+------------------------------------------------------------------+
void DetectSwingPointsOptimized(const int total, const datetime &time[], 
                                const double &high[], const double &low[], const double &close[])
{
    // Only check recent bars for new swings
    int startBar = MathMax(SwingLookback, total - 20);
    int endBar = total - SwingLookback - 3;
    
    for(int i = startBar; i < endBar; i++)
    {
        // Check for swing high
        bool isSwingHigh = true;
        for(int j = 1; j <= SwingLookback; j++)
        {
            if(high[i] <= high[i-j] || high[i] <= high[i+j])
            {
                isSwingHigh = false;
                break;
            }
        }
        
        // Check for swing low
        bool isSwingLow = true;
        for(int j = 1; j <= SwingLookback; j++)
        {
            if(low[i] >= low[i-j] || low[i] >= low[i+j])
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingHigh && !SwingExistsOptimized(time[i], high[i]))
        {
            AddSwingPointOptimized(time[i], high[i], i, SWING_HIGH);
        }
        
        if(isSwingLow && !SwingExistsOptimized(time[i], low[i]))
        {
            AddSwingPointOptimized(time[i], low[i], i, SWING_LOW);
        }
    }
}

//+------------------------------------------------------------------+
//| Optimized swing exists check                                    |
//+------------------------------------------------------------------+
bool SwingExistsOptimized(datetime swingTime, double swingPrice)
{
    for(int i = 0; i < swingCount; i++)
    {
        if(swings[i].time == swingTime && MathAbs(swings[i].price - swingPrice) < _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Optimized add swing point                                       |
//+------------------------------------------------------------------+
void AddSwingPointOptimized(datetime swingTime, double swingPrice, int swingIndex, SwingType type)
{
    // Remove oldest swing if array full
    if(swingCount >= MaxSwings)
    {
        // Shift array left
        for(int i = 0; i < MaxSwings - 1; i++)
        {
            swings[i] = swings[i + 1];
        }
        swingCount--;
    }
    
    // Add new swing
    swings[swingCount].time = swingTime;
    swings[swingCount].price = swingPrice;
    swings[swingCount].index = swingIndex;
    swings[swingCount].type = type;
    swings[swingCount].structure = STRUCTURE_NONE;
    swings[swingCount].processed = false;
    swings[swingCount].lineCreated = false;
    swings[swingCount].hasFVG = false;
    swings[swingCount].breakType = BREAK_NONE;
    
    swingCount++;
    
    // Show swing point
    if(ShowSwingPoints)
    {
        string objName = objPrefix + "SW_" + IntegerToString(swingIndex);
        color swingColor = (type == SWING_HIGH) ? clrDodgerBlue : clrGold;
        string swingText = (type == SWING_HIGH) ? "H" : "L";
        
        CreateTextLabelOptimized(objName, swingTime, swingPrice, swingColor, swingText, 8);
    }
}

//+------------------------------------------------------------------+
//| Optimized structure analysis                                    |
//+------------------------------------------------------------------+
void AnalyzeStructureOptimized()
{
    if(swingCount < 2) return;
    
    // Only process unprocessed swings
    for(int i = 0; i < swingCount; i++)
    {
        if(swings[i].processed) continue;
        
        // Find the last swing of the same type
        int lastSameTypeIndex = -1;
        for(int j = i - 1; j >= 0; j--)
        {
            if(swings[j].type == swings[i].type)
            {
                lastSameTypeIndex = j;
                break;
            }
        }
        
        if(lastSameTypeIndex == -1) continue;
        
        // Determine structure type
        StructureType structure = STRUCTURE_NONE;
        
        if(swings[i].type == SWING_HIGH)
        {
            if(swings[i].price > swings[lastSameTypeIndex].price)
                structure = STRUCTURE_HH;
            else
                structure = STRUCTURE_LH;
        }
        else if(swings[i].type == SWING_LOW)
        {
            if(swings[i].price > swings[lastSameTypeIndex].price)
                structure = STRUCTURE_HL;
            else
                structure = STRUCTURE_LL;
        }
        
        swings[i].structure = structure;
        swings[i].processed = true;
        
        // Update trend
        previousTrend = currentTrend;
        UpdateTrendOptimized(structure);
        
        // Show structure label
        if(ShowStructure && structure != STRUCTURE_NONE)
        {
            string structureText = GetStructureText(structure);
            color structureColor = GetStructureColor(structure);
            string objName = objPrefix + "STR_" + IntegerToString(swings[i].index);
            
            double offsetPrice = swings[i].price + (swings[i].type == SWING_HIGH ? 15 : -15) * _Point;
            CreateTextLabelOptimized(objName, swings[i].time, offsetPrice, structureColor, structureText, TextSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Optimized trend update                                          |
//+------------------------------------------------------------------+
void UpdateTrendOptimized(StructureType structure)
{
    switch(structure)
    {
        case STRUCTURE_HH:
        case STRUCTURE_HL:
            currentTrend = TREND_BULLISH;
            break;
            
        case STRUCTURE_LH:
        case STRUCTURE_LL:
            currentTrend = TREND_BEARISH;
            break;
    }
}

//+------------------------------------------------------------------+
//| Optimized structure breaks check                                |
//+------------------------------------------------------------------+
void CheckStructureBreaksOptimized(const int total, const datetime &time[], 
                                  const double &high[], const double &low[], const double &close[])
{
    // Only check recent bars for performance
    int startCheck = MathMax(0, total - CheckBars);
    
    for(int i = startCheck; i < total; i++)
    {
        if(i < 0) continue;
        
        double currentClose = close[i];
        datetime currentTime = time[i];
        
        // Check breaks against recent swings only
        for(int s = swingCount - 1; s >= MathMax(0, swingCount - 5); s--)
        {
            if(swings[s].time >= currentTime || swings[s].lineCreated) continue;
            
            // Get current bar data
            double currentHigh = high[i];
            double currentLow = low[i];
            
            BreakType breakType = BREAK_NONE;
            bool isBullishBreak = false;
            
            // Check for breaks on swing high
            if(swings[s].type == SWING_HIGH)
            {
                bool wickBreak = currentHigh > swings[s].price;
                bool closeBreak = currentClose > swings[s].price;
                
                if(wickBreak && !closeBreak)
                {
                    breakType = BREAK_SWEEP;  // Sweep: Wick break but no close break
                    isBullishBreak = true;
                }
                else if(closeBreak)
                {
                    // Determine if BOS or CHoCH based on structure change
                    if(IsStructureChangeBreak(s))
                        breakType = BREAK_CHOCH;
                    else
                        breakType = BREAK_BOS;
                    isBullishBreak = true;
                }
            }
            
            // Check for breaks on swing low  
            if(swings[s].type == SWING_LOW)
            {
                bool wickBreak = currentLow < swings[s].price;
                bool closeBreak = currentClose < swings[s].price;
                
                if(wickBreak && !closeBreak)
                {
                    breakType = BREAK_SWEEP;  // Sweep: Wick break but no close break
                    isBullishBreak = false;
                }
                else if(closeBreak)
                {
                    // Determine if BOS or CHoCH based on structure change
                    if(IsStructureChangeBreak(s))
                        breakType = BREAK_CHOCH;
                    else
                        breakType = BREAK_BOS;
                    isBullishBreak = false;
                }
            }
            
            // Process breaks
            if(breakType != BREAK_NONE)
            {
                swings[s].breakType = breakType;
                
                // Check for FVG first (for quality filtering)
                bool hasFVG = false;
                if(breakType == BREAK_CHOCH && ShowCHoCHFVG)
                {
                    hasFVG = DetectFVGOnCHoCHWave(s, currentTime, high, low, close);
                    swings[s].hasFVG = hasFVG;
                }
                
                // Create appropriate line based on break type
                if(breakType == BREAK_SWEEP && ShowSweepLines)
                {
                    string lineName = objPrefix + "SWEEP_" + IntegerToString(swings[s].index);
                    CreateTrendLineOptimized(lineName, swings[s].time, swings[s].price, 
                                           currentTime, swings[s].price, ColorSweepLine, "Sweep");
                }
                else if(breakType == BREAK_CHOCH && ShowCHoCHLines)
                {
                    // Quality filter: only show CHoCH with FVG if enabled
                    if(!QualityFilterCHoCH || hasFVG)
                    {
                        string lineName = objPrefix + "CHOCH_" + IntegerToString(swings[s].index);
                        string label = hasFVG ? "CHoCH*" : "CHoCH";  // * indicates high quality
                        CreateTrendLineOptimized(lineName, swings[s].time, swings[s].price, 
                                               currentTime, swings[s].price, ColorCHoCHLine, label);
                    }
                }
                else if(breakType == BREAK_BOS && ShowBOSLines)
                {
                    string lineName = objPrefix + "BOS_" + IntegerToString(swings[s].index);
                    CreateTrendLineOptimized(lineName, swings[s].time, swings[s].price, 
                                           currentTime, swings[s].price, ColorBOSLine, "BOS");
                }
                
                swings[s].lineCreated = true; // Mark as processed
                
                if(DebugMode)
                {
                    string breakTypeName = (breakType == BREAK_SWEEP) ? "Sweep" : 
                                          (breakType == BREAK_CHOCH) ? "CHoCH" : "BOS";
                    string quality = (breakType == BREAK_CHOCH && hasFVG) ? " (High Quality)" : "";
                    Print("[ICT] ", breakTypeName, quality, " line created from swing to break point");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Determine if break is CHoCH or BOS - ICT Standard              |
//+------------------------------------------------------------------+
bool IsStructureChangeBreak(int swingIndex)
{
    if(swingIndex < 0 || swingIndex >= swingCount) return false;
    
    // ICT CHoCH Logic: First break that changes trend direction
    // Look for trend change patterns more comprehensively
    
    // Get current swing info
    SwingType currentType = swings[swingIndex].type;
    StructureType currentStructure = swings[swingIndex].structure;
    
    // CHoCH Pattern 1: HL in bearish trend (bullish CHoCH)
    if(currentStructure == STRUCTURE_HL && previousTrend == TREND_BEARISH)
    {
        if(DebugMode) Print("[CHoCH] Bullish CHoCH detected: HL in bearish trend");
        return true;
    }
    
    // CHoCH Pattern 2: LH in bullish trend (bearish CHoCH)  
    if(currentStructure == STRUCTURE_LH && previousTrend == TREND_BULLISH)
    {
        if(DebugMode) Print("[CHoCH] Bearish CHoCH detected: LH in bullish trend");
        return true;
    }
    
    // CHoCH Pattern 3: First HH after series of LH/LL (strong bullish CHoCH)
    if(currentStructure == STRUCTURE_HH && previousTrend == TREND_BEARISH)
    {
        if(DebugMode) Print("[CHoCH] Strong Bullish CHoCH: HH after bearish trend");
        return true;
    }
    
    // CHoCH Pattern 4: First LL after series of HH/HL (strong bearish CHoCH)
    if(currentStructure == STRUCTURE_LL && previousTrend == TREND_BULLISH)
    {
        if(DebugMode) Print("[CHoCH] Strong Bearish CHoCH: LL after bullish trend");
        return true;
    }
    
    // Additional logic: Check if this swing represents a significant trend change
    // by analyzing the pattern of the last few swings
    if(IsSignificantTrendChange(swingIndex))
    {
        if(DebugMode) Print("[CHoCH] Significant trend change detected at swing ", swingIndex);
        return true;
    }
    
    return false; // Otherwise it's BOS (continuation)
}

//+------------------------------------------------------------------+
//| Check for significant trend change pattern                      |
//+------------------------------------------------------------------+
bool IsSignificantTrendChange(int currentSwingIndex)
{
    if(currentSwingIndex < 2) return false;
    
    // Look at the last 3 swings to identify trend change
    int count = 0;
    SwingType lastTypes[3];
    StructureType lastStructures[3];
    
    // Collect last 3 swings
    for(int i = currentSwingIndex; i >= 0 && count < 3; i--)
    {
        lastTypes[count] = swings[i].type;
        lastStructures[count] = swings[i].structure;
        count++;
        if(count >= 3) break;
    }
    
    if(count < 3) return false;
    
    // Pattern: Break of bearish structure followed by bullish structure
    if((lastStructures[0] == STRUCTURE_HH || lastStructures[0] == STRUCTURE_HL) && 
       (lastStructures[1] == STRUCTURE_LH || lastStructures[1] == STRUCTURE_LL))
    {
        return true; // Bullish CHoCH
    }
    
    // Pattern: Break of bullish structure followed by bearish structure  
    if((lastStructures[0] == STRUCTURE_LL || lastStructures[0] == STRUCTURE_LH) && 
       (lastStructures[1] == STRUCTURE_HH || lastStructures[1] == STRUCTURE_HL))
    {
        return true; // Bearish CHoCH
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Create optimized trend line (swing to break point)             |
//+------------------------------------------------------------------+
void CreateTrendLineOptimized(string objName, datetime time1, double price1, 
                             datetime time2, double price2, color clr, string lineType)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    // Create trend line from swing point to break point
    ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_RAY, false); // No extension
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    
    // Add text label at end of line
    string labelName = objName + "_LBL";
    ObjectCreate(0, labelName, OBJ_TEXT, 0, time2, price2);
    ObjectSetString(0, labelName, OBJPROP_TEXT, lineType);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Optimized text label creation                                   |
//+------------------------------------------------------------------+
void CreateTextLabelOptimized(string objName, datetime time, double price, color clr, string text, int size)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    ObjectCreate(0, objName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LOWER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
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
//| Cleanup objects                                                 |
//+------------------------------------------------------------------+
//| Detect FVG on CHoCH wave only - Returns true if FVG found      |
//+------------------------------------------------------------------+
bool DetectFVGOnCHoCHWave(int chochSwingIndex, datetime breakTime, 
                         const double &high[], const double &low[], const double &close[])
{
    if(chochSwingIndex < 0 || chochSwingIndex >= swingCount) return false;
    
    // Get CHoCH swing details
    datetime chochTime = swings[chochSwingIndex].time;
    double chochPrice = swings[chochSwingIndex].price;
    SwingType chochType = swings[chochSwingIndex].type;
    
    // Convert time to bar index for scanning
    int chochBar = iBarShift(_Symbol, _Period, chochTime);
    int breakBar = iBarShift(_Symbol, _Period, breakTime);
    
    if(chochBar <= 0 || breakBar <= 0 || chochBar <= breakBar) return false;
    
    bool fvgFound = false;
    
    // Scan for FVG between CHoCH swing and break point
    for(int i = chochBar - 1; i > breakBar + 1; i--)
    {
        if(i < 2) continue;
        
        // Check for bullish FVG (gap up)
        if(low[i-1] > high[i+1])
        {
            double fvgTop = low[i-1];
            double fvgBottom = high[i+1];
            double fvgSize = fvgTop - fvgBottom;
            
            // Only show significant FVGs
            if(fvgSize > 10 * _Point)
            {
                // Check if FVG is still unfilled
                if(IsFVGUnfilled(i, fvgTop, fvgBottom, close))
                {
                    datetime fvgTime = iTime(_Symbol, _Period, i);
                    CreateFVGRectangle(fvgTime, fvgTop, fvgBottom, true, i);
                    fvgFound = true;
                    
                    if(DebugMode) 
                        Print("[FVG] Bullish FVG on CHoCH wave: ", fvgTop, " - ", fvgBottom);
                }
            }
        }
        
        // Check for bearish FVG (gap down)  
        if(high[i-1] < low[i+1])
        {
            double fvgTop = low[i+1];
            double fvgBottom = high[i-1];
            double fvgSize = fvgTop - fvgBottom;
            
            // Only show significant FVGs
            if(fvgSize > 10 * _Point)
            {
                // Check if FVG is still unfilled
                if(IsFVGUnfilled(i, fvgTop, fvgBottom, close))
                {
                    datetime fvgTime = iTime(_Symbol, _Period, i);
                    CreateFVGRectangle(fvgTime, fvgTop, fvgBottom, false, i);
                    fvgFound = true;
                    
                    if(DebugMode) 
                        Print("[FVG] Bearish FVG on CHoCH wave: ", fvgTop, " - ", fvgBottom);
                }
            }
        }
    }
    
    return fvgFound;
}

//+------------------------------------------------------------------+
//| Check if FVG is still unfilled                                  |
//+------------------------------------------------------------------+
bool IsFVGUnfilled(int fvgBar, double fvgTop, double fvgBottom, const double &close[])
{
    // Check recent price action to see if FVG was filled
    int currentBar = 0;
    
    for(int i = fvgBar - 1; i >= currentBar; i--)
    {
        if(i < 0) break;
        
        double currentClose = close[i];
        
        // FVG filled if price closed within the gap
        if(currentClose >= fvgBottom && currentClose <= fvgTop)
        {
            return false; // FVG filled
        }
    }
    
    return true; // FVG still unfilled
}

//+------------------------------------------------------------------+
//| Create FVG rectangle on chart                                   |
//+------------------------------------------------------------------+
void CreateFVGRectangle(datetime fvgTime, double fvgTop, double fvgBottom, bool isBullish, int fvgIndex)
{
    string objName = objPrefix + "FVG_" + IntegerToString(fvgIndex);
    
    if(ObjectFind(0, objName) >= 0) return;
    
    // Create rectangle for FVG
    datetime endTime = fvgTime + (10 * PeriodSeconds(_Period)); // Extend rectangle
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvgTime, fvgTop, endTime, fvgBottom);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, ColorFVG);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    
    // Add FVG label
    string labelName = objName + "_LBL";
    double labelPrice = (fvgTop + fvgBottom) / 2;
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, fvgTime, labelPrice);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "FVG");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, ColorFVG);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
}

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
