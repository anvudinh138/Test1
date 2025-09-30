//+------------------------------------------------------------------+
//|                                     CTI_Structure_Pro_Fixed.mq5 |
//|                           Xác định chính xác BOS, CHoCH, Sweep |
//|   Logic: HH/HL/LH/LL → Trend → BOS (close beyond) → CHoCH      |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "1.01"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input int    SwingLookback    = 3;        // Fractal lookback for swing detection
input bool   ShowSwingPoints  = true;     // Show swing high/low points
input bool   ShowStructure    = true;     // Show HH/HL/LH/LL labels
input bool   ShowBOS          = true;     // Show Break of Structure
input bool   ShowCHoCH        = true;     // Show Change of Character  
input bool   ShowSweep        = true;     // Show Liquidity Sweeps
input double BreakBuffer      = 0.0;      // Extra points for break confirmation
input int    MaxSwingsToTrack = 50;       // Maximum swings to keep in memory

//--- Colors
input color  ColorHH          = clrLime;
input color  ColorHL          = clrGreen;  
input color  ColorLH          = clrOrange;
input color  ColorLL          = clrRed;
input color  ColorBOS_Bull    = clrBlue;
input color  ColorBOS_Bear    = clrMagenta;
input color  ColorCHoCH_Bull  = clrCyan;
input color  ColorCHoCH_Bear  = clrYellow;
input color  ColorSweep_Bull  = clrLightBlue;
input color  ColorSweep_Bear  = clrPink;

//--- Object styling
input int    TextSize         = 9;
input int    LabelOffset      = 15;       // Vertical offset for labels

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
    STRUCTURE_HH = 1,    // Higher High
    STRUCTURE_HL = 2,    // Higher Low  
    STRUCTURE_LH = 3,    // Lower High
    STRUCTURE_LL = 4     // Lower Low
};

//--- Global variables - Using separate arrays instead of struct array
datetime swingTimes[];
double swingPrices[];
int swingIndices[];
SwingType swingTypes[];
StructureType swingStructures[];
bool swingProcessed[];
int swingIds[];

int swingCount = 0;
int uniqueId = 0;
TrendDirection currentTrend = TREND_UNKNOWN;
string objPrefix = "CTS_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI Structure Pro v1.01");
    
    // Initialize arrays
    ArrayResize(swingTimes, MaxSwingsToTrack);
    ArrayResize(swingPrices, MaxSwingsToTrack);
    ArrayResize(swingIndices, MaxSwingsToTrack);
    ArrayResize(swingTypes, MaxSwingsToTrack);
    ArrayResize(swingStructures, MaxSwingsToTrack);
    ArrayResize(swingProcessed, MaxSwingsToTrack);
    ArrayResize(swingIds, MaxSwingsToTrack);
    
    // Clear all previous objects
    CleanupObjects();
    
    return(INIT_SUCCEEDED);
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
    
    // Convert to non-series arrays for easier processing
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    
    // Detect new swing points
    DetectSwingPoints(rates_total, time, high, low, close);
    
    // Analyze structure for each swing
    AnalyzeStructure();
    
    // Detect BOS, CHoCH, and Sweeps
    DetectBreaksAndSignals(rates_total, time, high, low, close);
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Detect swing points using fractal logic                         |
//+------------------------------------------------------------------+
void DetectSwingPoints(const int total, const datetime &time[], 
                      const double &high[], const double &low[], const double &close[])
{
    // Check for swing highs and lows
    for(int i = SwingLookback; i < total - SwingLookback - 3; i++) // -3 to avoid incomplete swings
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
        
        // Add swing point if found and not already exists
        if(isSwingHigh && !SwingExists(time[i], high[i]))
        {
            AddSwingPoint(time[i], high[i], i, SWING_HIGH);
        }
        
        if(isSwingLow && !SwingExists(time[i], low[i]))
        {
            AddSwingPoint(time[i], low[i], i, SWING_LOW);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if swing already exists                                   |
//+------------------------------------------------------------------+
bool SwingExists(datetime swingTime, double swingPrice)
{
    for(int i = 0; i < swingCount; i++)
    {
        if(swingTimes[i] == swingTime && MathAbs(swingPrices[i] - swingPrice) < _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add new swing point                                             |
//+------------------------------------------------------------------+
void AddSwingPoint(datetime swingTime, double swingPrice, int swingIndex, SwingType type)
{
    if(swingCount >= MaxSwingsToTrack)
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
            swingIds[i] = swingIds[i + 1];
        }
        swingCount--;
    }
    
    swingTimes[swingCount] = swingTime;
    swingPrices[swingCount] = swingPrice;
    swingIndices[swingCount] = swingIndex;
    swingTypes[swingCount] = type;
    swingStructures[swingCount] = STRUCTURE_NONE;
    swingProcessed[swingCount] = false;
    swingIds[swingCount] = ++uniqueId;
    
    swingCount++;
    
    // Sort swings by time
    SortSwingsByTime();
    
    // Show swing point if enabled
    if(ShowSwingPoints)
    {
        string objName = objPrefix + "SW_" + IntegerToString(swingIndex);
        color swingColor = (type == SWING_HIGH) ? clrDodgerBlue : clrGold;
        string swingText = (type == SWING_HIGH) ? "H" : "L";
        
        CreateTextLabel(objName, swingTime, swingPrice, swingColor, swingText, 8);
    }
}

//+------------------------------------------------------------------+
//| Sort swings by time (chronological order)                       |
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
                
                int tempId = swingIds[i];
                swingIds[i] = swingIds[j];
                swingIds[j] = tempId;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze structure (HH, HL, LH, LL) for each swing              |
//+------------------------------------------------------------------+
void AnalyzeStructure()
{
    if(swingCount < 2) return;
    
    for(int i = 1; i < swingCount; i++)
    {
        if(swingProcessed[i]) continue;
        
        // Find the last swing of the same type
        int lastSameTypeIndex = -1;
        for(int j = i - 1; j >= 0; j--)
        {
            if(swingTypes[j] == swingTypes[i])
            {
                lastSameTypeIndex = j;
                break;
            }
        }
        
        if(lastSameTypeIndex == -1) continue;
        
        // Determine structure type
        StructureType structure = STRUCTURE_NONE;
        
        if(swingTypes[i] == SWING_HIGH)
        {
            if(swingPrices[i] > swingPrices[lastSameTypeIndex])
                structure = STRUCTURE_HH; // Higher High
            else
                structure = STRUCTURE_LH; // Lower High
        }
        else if(swingTypes[i] == SWING_LOW)
        {
            if(swingPrices[i] > swingPrices[lastSameTypeIndex])
                structure = STRUCTURE_HL; // Higher Low
            else
                structure = STRUCTURE_LL; // Lower Low
        }
        
        swingStructures[i] = structure;
        swingProcessed[i] = true;
        
        // Update trend based on structure
        UpdateTrend(structure);
        
        // Show structure label
        if(ShowStructure && structure != STRUCTURE_NONE)
        {
            string structureText = GetStructureText(structure);
            color structureColor = GetStructureColor(structure);
            string objName = objPrefix + "STR_" + IntegerToString(swingIndices[i]);
            
            CreateTextLabel(objName, swingTimes[i], swingPrices[i], structureColor, structureText, TextSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Update trend based on structure formation                       |
//+------------------------------------------------------------------+
void UpdateTrend(StructureType structure)
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
//| Get structure text label                                        |
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
//| Detect BOS, CHoCH, and Sweeps                                   |
//+------------------------------------------------------------------+
void DetectBreaksAndSignals(const int total, const datetime &time[], 
                           const double &high[], const double &low[], const double &close[])
{
    if(swingCount < 2) return;
    
    // Check recent price action against swing levels
    for(int i = 1; i < 10 && i < total; i++) // Check last 10 bars
    {
        CheckForBOS(i, time, high, low, close);
        CheckForCHoCH(i, time, high, low, close);
        CheckForSweep(i, time, high, low, close);
    }
}

//+------------------------------------------------------------------+
//| Check for Break of Structure (BOS)                             |
//+------------------------------------------------------------------+
void CheckForBOS(int barIndex, const datetime &time[], const double &high[], 
                const double &low[], const double &close[])
{
    if(!ShowBOS || swingCount < 2) return;
    
    double currentClose = close[barIndex];
    datetime currentTime = time[barIndex];
    
    // Check for bullish BOS (close above previous swing high)
    for(int i = swingCount - 1; i >= 0; i--)
    {
        if(swingTypes[i] == SWING_HIGH && swingTimes[i] < currentTime)
        {
            if(currentClose > swingPrices[i] + BreakBuffer * _Point)
            {
                // This is a BOS if it creates a new HH in the right trend context
                string objName = objPrefix + "BOS_BULL_" + TimeToString(currentTime, TIME_MINUTES);
                if(ObjectFind(0, objName) < 0) // Avoid duplicates
                {
                    CreateTextLabel(objName, currentTime, currentClose, ColorBOS_Bull, "BOS↑", TextSize);
                    
                    // Draw line from swing to break point
                    string lineName = objPrefix + "BOS_LINE_" + TimeToString(currentTime, TIME_MINUTES);
                    CreateTrendLine(lineName, swingTimes[i], swingPrices[i], currentTime, swingPrices[i], ColorBOS_Bull, STYLE_DASH);
                }
                break;
            }
        }
    }
    
    // Check for bearish BOS (close below previous swing low)
    for(int i = swingCount - 1; i >= 0; i--)
    {
        if(swingTypes[i] == SWING_LOW && swingTimes[i] < currentTime)
        {
            if(currentClose < swingPrices[i] - BreakBuffer * _Point)
            {
                // This is a BOS if it creates a new LL in the right trend context  
                string objName = objPrefix + "BOS_BEAR_" + TimeToString(currentTime, TIME_MINUTES);
                if(ObjectFind(0, objName) < 0) // Avoid duplicates
                {
                    CreateTextLabel(objName, currentTime, currentClose, ColorBOS_Bear, "BOS↓", TextSize);
                    
                    // Draw line from swing to break point
                    string lineName = objPrefix + "BOS_LINE_" + TimeToString(currentTime, TIME_MINUTES);
                    CreateTrendLine(lineName, swingTimes[i], swingPrices[i], currentTime, swingPrices[i], ColorBOS_Bear, STYLE_DASH);
                }
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Change of Character (CHoCH)                          |
//+------------------------------------------------------------------+
void CheckForCHoCH(int barIndex, const datetime &time[], const double &high[], 
                  const double &low[], const double &close[])
{
    if(!ShowCHoCH || swingCount < 3) return;
    
    // CHoCH occurs when trend changes:
    // - Bullish CHoCH: In downtrend, price makes HL (higher low)
    // - Bearish CHoCH: In uptrend, price makes LH (lower high)
    
    // Look for recent structure changes that indicate trend change
    for(int i = swingCount - 1; i >= swingCount - 3 && i >= 0; i--)
    {
        if(!swingProcessed[i]) continue;
        
        // Bullish CHoCH: HL formation in previous bearish trend
        if(swingStructures[i] == STRUCTURE_HL && currentTrend == TREND_BULLISH)
        {
            string objName = objPrefix + "CHOCH_BULL_" + TimeToString(swingTimes[i], TIME_MINUTES);
            if(ObjectFind(0, objName) < 0)
            {
                CreateTextLabel(objName, swingTimes[i], swingPrices[i], ColorCHoCH_Bull, "CHoCH↑", TextSize);
            }
        }
        
        // Bearish CHoCH: LH formation in previous bullish trend  
        if(swingStructures[i] == STRUCTURE_LH && currentTrend == TREND_BEARISH)
        {
            string objName = objPrefix + "CHOCH_BEAR_" + TimeToString(swingTimes[i], TIME_MINUTES);
            if(ObjectFind(0, objName) < 0)
            {
                CreateTextLabel(objName, swingTimes[i], swingPrices[i], ColorCHoCH_Bear, "CHoCH↓", TextSize);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Liquidity Sweep                                      |
//+------------------------------------------------------------------+
void CheckForSweep(int barIndex, const datetime &time[], const double &high[], 
                  const double &low[], const double &close[])
{
    if(!ShowSweep || swingCount < 2) return;
    
    double currentHigh = high[barIndex];
    double currentLow = low[barIndex];
    double currentClose = close[barIndex];
    datetime currentTime = time[barIndex];
    
    // Check for bullish sweep (wick above swing high but close below)
    for(int i = swingCount - 1; i >= 0; i--)
    {
        if(swingTypes[i] == SWING_HIGH && swingTimes[i] < currentTime)
        {
            // Wick breaks high but doesn't close above it
            if(currentHigh > swingPrices[i] + BreakBuffer * _Point && 
               currentClose <= swingPrices[i] + BreakBuffer * _Point)
            {
                string objName = objPrefix + "SWEEP_BULL_" + TimeToString(currentTime, TIME_MINUTES);
                if(ObjectFind(0, objName) < 0)
                {
                    CreateTextLabel(objName, currentTime, currentHigh, ColorSweep_Bull, "Sweep↑", TextSize);
                }
                break;
            }
        }
    }
    
    // Check for bearish sweep (wick below swing low but close above)  
    for(int i = swingCount - 1; i >= 0; i--)
    {
        if(swingTypes[i] == SWING_LOW && swingTimes[i] < currentTime)
        {
            // Wick breaks low but doesn't close below it
            if(currentLow < swingPrices[i] - BreakBuffer * _Point && 
               currentClose >= swingPrices[i] - BreakBuffer * _Point)
            {
                string objName = objPrefix + "SWEEP_BEAR_" + TimeToString(currentTime, TIME_MINUTES);
                if(ObjectFind(0, objName) < 0)
                {
                    CreateTextLabel(objName, currentTime, currentLow, ColorSweep_Bear, "Sweep↓", TextSize);
                }
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Create text label on chart                                      |
//+------------------------------------------------------------------+
void CreateTextLabel(string objName, datetime time, double price, color clr, string text, int size)
{
    if(ObjectFind(0, objName) >= 0) return; // Already exists
    
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
    if(ObjectFind(0, objName) >= 0) return; // Already exists
    
    ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_RAY, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Cleanup all objects created by this indicator                   |
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
