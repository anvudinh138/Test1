//+------------------------------------------------------------------+
//|                                        CTI_Strategy_Complete.mq5 |
//|              Full ICT CTI Strategy Implementation                |
//|   CHoCH → FVG Detection → Retest → LTF Entry → OB Fallback     |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "=== SWING DETECTION ==="
input int    SwingLookback       = 5;        // Fractal lookback for swing detection
input bool   RequireCloseBreak   = true;     // BOS requires close beyond level
input double BreakBuffer         = 2.0;      // Extra points for break confirmation

input group "=== CTI STRATEGY ==="
input bool   ShowFVGZones        = true;     // Show FVG zones on CHoCH swings
input bool   ShowOBZones         = true;     // Show Order Block zones
input bool   ShowRetestLines     = true;     // Show retest horizontal lines
input bool   ShowEntrySignals    = true;     // Show entry long/short signals
input double FVGMinSize          = 5.0;      // Minimum FVG size in points
input int    RetestTimeout       = 20;       // Bars to wait for retest
input int    EntryTimeout        = 15;       // Bars to wait for entry confirmation

input group "=== VISUAL SETTINGS ==="
input color  ColorCHoCH_Bull     = clrCyan;
input color  ColorCHoCH_Bear     = clrYellow;
input color  ColorFVG_Zone       = clrLightBlue;
input color  ColorOB_Zone        = clrLightGray;
input color  ColorRetestLine     = clrWhite;
input color  ColorEntryLong      = clrLime;
input color  ColorEntryShort     = clrRed;
input int    TextSize            = 10;

input group "=== STATISTICS ==="
input bool   EnableLogging       = true;     // Enable trade statistics logging
input string LogFileName         = "CTI_Stats.csv"; // Log file name

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

enum EntryType
{
    ENTRY_NONE = 0,
    ENTRY_LONG = 1,
    ENTRY_SHORT = -1
};

enum ZoneType
{
    ZONE_FVG = 1,
    ZONE_OB = 2
};

//--- Structures using separate arrays
datetime swingTimes[];
double swingPrices[];
int swingIndices[];
SwingType swingTypes[];
StructureType swingStructures[];
bool swingProcessed[];
int swingIds[];

datetime chochTimes[];
double chochPrices[];
bool chochIsBullish[];
int chochSwingIds[];
int chochIds[];

datetime fvgTimes[];
double fvgTopPrices[];
double fvgBottomPrices[];
bool fvgIsBullish[];
int fvgChochIds[];
bool fvgRetested[];
int fvgIds[];

datetime obTimes[];
double obTopPrices[];
double obBottomPrices[];
bool obIsBullish[];
int obChochIds[];
bool obRetested[];
int obIds[];

datetime entryTimes[];
double entryPrices[];
EntryType entryTypes[];
bool entryConfirmed[];
int entryIds[];

//--- Global variables
int swingCount = 0;
int chochCount = 0;
int fvgCount = 0;
int obCount = 0;
int entryCount = 0;

int uniqueId = 0;
TrendDirection currentTrend = TREND_UNKNOWN;
string objPrefix = "CTI_";

// Statistics
int totalSignals = 0;
int successfulEntries = 0;
int failedEntries = 0;
int fileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI Strategy Complete v1.0");
    
    // Initialize arrays
    ArrayResize(swingTimes, 100);
    ArrayResize(swingPrices, 100);
    ArrayResize(swingIndices, 100);
    ArrayResize(swingTypes, 100);
    ArrayResize(swingStructures, 100);
    ArrayResize(swingProcessed, 100);
    ArrayResize(swingIds, 100);
    
    ArrayResize(chochTimes, 50);
    ArrayResize(chochPrices, 50);
    ArrayResize(chochIsBullish, 50);
    ArrayResize(chochSwingIds, 50);
    ArrayResize(chochIds, 50);
    
    ArrayResize(fvgTimes, 50);
    ArrayResize(fvgTopPrices, 50);
    ArrayResize(fvgBottomPrices, 50);
    ArrayResize(fvgIsBullish, 50);
    ArrayResize(fvgChochIds, 50);
    ArrayResize(fvgRetested, 50);
    ArrayResize(fvgIds, 50);
    
    ArrayResize(obTimes, 50);
    ArrayResize(obTopPrices, 50);
    ArrayResize(obBottomPrices, 50);
    ArrayResize(obIsBullish, 50);
    ArrayResize(obChochIds, 50);
    ArrayResize(obRetested, 50);
    ArrayResize(obIds, 50);
    
    ArrayResize(entryTimes, 100);
    ArrayResize(entryPrices, 100);
    ArrayResize(entryTypes, 100);
    ArrayResize(entryConfirmed, 100);
    ArrayResize(entryIds, 100);
    
    // Initialize logging
    if(EnableLogging)
    {
        InitializeLogging();
    }
    
    CleanupObjects();
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupObjects();
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileClose(fileHandle);
        fileHandle = INVALID_HANDLE;
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
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    
    // Step 1: Detect swing points and structure
    DetectSwingPoints(rates_total, time, high, low, close);
    AnalyzeStructure();
    
    // Step 2: Detect CHoCH formations
    DetectCHoCH();
    
    // Step 3: Find FVG on CHoCH swings
    if(ShowFVGZones) DetectFVGOnCHoCH(time, open, high, low, close);
    
    // Step 4: Find OB at CHoCH swing points
    if(ShowOBZones) DetectOBAtCHoCH(time, open, high, low, close);
    
    // Step 5: Check for retests and generate entry signals
    CheckRetestsAndEntries(rates_total, time, open, high, low, close);
    
    // Step 6: Update visual elements
    UpdateVisualElements();
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Initialize logging system                                        |
//+------------------------------------------------------------------+
void InitializeLogging()
{
    string fileName = LogFileName;
    fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
    
    if(fileHandle != INVALID_HANDLE)
    {
        // Write header
        FileWrite(fileHandle, "Time", "Type", "Price", "Direction", "Result", "Notes");
        Print("[CTI Strategy] Logging initialized: ", fileName);
    }
    else
    {
        Print("[CTI Strategy] Failed to initialize logging");
    }
}

//+------------------------------------------------------------------+
//| Detect swing points using fractal logic                         |
//+------------------------------------------------------------------+
void DetectSwingPoints(const int total, const datetime &time[], 
                      const double &high[], const double &low[], const double &close[])
{
    for(int i = SwingLookback; i < total - SwingLookback - 3; i++)
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
    SortSwingsByTime();
    
    // Draw short horizontal line at swing level
    if(ShowRetestLines)
    {
        string lineName = objPrefix + "LEVEL_" + IntegerToString(uniqueId);
        CreateShortHorizontalLine(lineName, swingTime, swingPrice, ColorRetestLine);
    }
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
                
                int tempId = swingIds[i];
                swingIds[i] = swingIds[j];
                swingIds[j] = tempId;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze structure for each swing                                |
//+------------------------------------------------------------------+
void AnalyzeStructure()
{
    if(swingCount < 2) return;
    
    for(int i = 1; i < swingCount; i++)
    {
        if(swingProcessed[i]) continue;
        
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
        
        StructureType structure = STRUCTURE_NONE;
        
        if(swingTypes[i] == SWING_HIGH)
        {
            if(swingPrices[i] > swingPrices[lastSameTypeIndex])
                structure = STRUCTURE_HH;
            else
                structure = STRUCTURE_LH;
        }
        else if(swingTypes[i] == SWING_LOW)
        {
            if(swingPrices[i] > swingPrices[lastSameTypeIndex])
                structure = STRUCTURE_HL;
            else
                structure = STRUCTURE_LL;
        }
        
        swingStructures[i] = structure;
        swingProcessed[i] = true;
        
        UpdateTrend(structure);
    }
}

//+------------------------------------------------------------------+
//| Update trend based on structure                                 |
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
//| Detect CHoCH formations                                         |
//+------------------------------------------------------------------+
void DetectCHoCH()
{
    if(swingCount < 3) return;
    
    for(int i = swingCount - 1; i >= swingCount - 3 && i >= 0; i--)
    {
        if(!swingProcessed[i]) continue;
        
        bool isCHoCH = false;
        bool isBullish = false;
        
        // Bullish CHoCH: HL formation
        if(swingStructures[i] == STRUCTURE_HL)
        {
            isCHoCH = true;
            isBullish = true;
        }
        
        // Bearish CHoCH: LH formation
        if(swingStructures[i] == STRUCTURE_LH)
        {
            isCHoCH = true;
            isBullish = false;
        }
        
        if(isCHoCH && !CHoCHExists(swingTimes[i], swingPrices[i]))
        {
            AddCHoCH(swingTimes[i], swingPrices[i], isBullish, swingIds[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if CHoCH already exists                                   |
//+------------------------------------------------------------------+
bool CHoCHExists(datetime chochTime, double chochPrice)
{
    for(int i = 0; i < chochCount; i++)
    {
        if(chochTimes[i] == chochTime && MathAbs(chochPrices[i] - chochPrice) < _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add new CHoCH                                                   |
//+------------------------------------------------------------------+
void AddCHoCH(datetime chochTime, double chochPrice, bool isBullish, int swingId)
{
    if(chochCount >= ArraySize(chochTimes))
    {
        // Remove oldest CHoCH
        for(int i = 0; i < chochCount - 1; i++)
        {
            chochTimes[i] = chochTimes[i + 1];
            chochPrices[i] = chochPrices[i + 1];
            chochIsBullish[i] = chochIsBullish[i + 1];
            chochSwingIds[i] = chochSwingIds[i + 1];
            chochIds[i] = chochIds[i + 1];
        }
        chochCount--;
    }
    
    chochTimes[chochCount] = chochTime;
    chochPrices[chochCount] = chochPrice;
    chochIsBullish[chochCount] = isBullish;
    chochSwingIds[chochCount] = swingId;
    chochIds[chochCount] = ++uniqueId;
    
    chochCount++;
    
    // Display CHoCH label
    string objName = objPrefix + "CHOCH_" + IntegerToString(uniqueId);
    string text = "CHoCH" + (isBullish ? "↑" : "↓");
    color chochColor = isBullish ? ColorCHoCH_Bull : ColorCHoCH_Bear;
    
    CreateTextLabel(objName, chochTime, chochPrice, chochColor, text, TextSize);
}

//+------------------------------------------------------------------+
//| Detect FVG on CHoCH swing waves                                 |
//+------------------------------------------------------------------+
void DetectFVGOnCHoCH(const datetime &time[], const double &open[], 
                     const double &high[], const double &low[], const double &close[])
{
    if(chochCount == 0) return;
    
    // For each recent CHoCH, find FVG on the swing that created it
    for(int c = chochCount - 1; c >= MathMax(0, chochCount - 3); c--)
    {
        // Find the swing range that created this CHoCH
        int startBar = -1, endBar = -1;
        
        // Find swing start and end based on CHoCH swing
        for(int s = 0; s < swingCount; s++)
        {
            if(swingIds[s] == chochSwingIds[c])
            {
                // This is the swing that created CHoCH
                // Find previous opposite swing to define the range
                for(int ps = s - 1; ps >= 0; ps--)
                {
                    if(swingTypes[ps] != swingTypes[s])
                    {
                        startBar = swingIndices[ps];
                        endBar = swingIndices[s];
                        break;
                    }
                }
                break;
            }
        }
        
        if(startBar == -1 || endBar == -1) continue;
        
        // Search for FVG in this range
        FindFVGInRange(time, open, high, low, close, startBar, endBar, chochIsBullish[c], chochIds[c]);
    }
}

//+------------------------------------------------------------------+
//| Find FVG in specified range                                     |
//+------------------------------------------------------------------+
void FindFVGInRange(const datetime &time[], const double &open[], const double &high[], 
                   const double &low[], const double &close[], int startBar, int endBar, 
                   bool isBullish, int chochId)
{
    // Ensure correct order
    if(startBar > endBar)
    {
        int temp = startBar;
        startBar = endBar;
        endBar = temp;
    }
    
    // Look for FVG pattern (3-candle gap)
    for(int i = startBar + 1; i < endBar - 1; i++)
    {
        bool foundFVG = false;
        double fvgTop = 0, fvgBottom = 0;
        
        if(isBullish)
        {
            // Bullish FVG: low[i+1] > high[i-1]
            if(low[i + 1] > high[i - 1])
            {
                fvgTop = low[i + 1];
                fvgBottom = high[i - 1];
                foundFVG = true;
            }
        }
        else
        {
            // Bearish FVG: high[i+1] < low[i-1]
            if(high[i + 1] < low[i - 1])
            {
                fvgTop = low[i - 1];
                fvgBottom = high[i + 1];
                foundFVG = true;
            }
        }
        
        if(foundFVG && (fvgTop - fvgBottom) >= FVGMinSize * _Point)
        {
            if(!FVGExists(time[i], fvgTop, fvgBottom))
            {
                AddFVG(time[i], fvgTop, fvgBottom, isBullish, chochId);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if FVG already exists                                     |
//+------------------------------------------------------------------+
bool FVGExists(datetime fvgTime, double fvgTop, double fvgBottom)
{
    for(int i = 0; i < fvgCount; i++)
    {
        if(fvgTimes[i] == fvgTime && 
           MathAbs(fvgTopPrices[i] - fvgTop) < _Point && 
           MathAbs(fvgBottomPrices[i] - fvgBottom) < _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add new FVG                                                     |
//+------------------------------------------------------------------+
void AddFVG(datetime fvgTime, double fvgTop, double fvgBottom, bool isBullish, int chochId)
{
    if(fvgCount >= ArraySize(fvgTimes))
    {
        // Remove oldest FVG
        for(int i = 0; i < fvgCount - 1; i++)
        {
            fvgTimes[i] = fvgTimes[i + 1];
            fvgTopPrices[i] = fvgTopPrices[i + 1];
            fvgBottomPrices[i] = fvgBottomPrices[i + 1];
            fvgIsBullish[i] = fvgIsBullish[i + 1];
            fvgChochIds[i] = fvgChochIds[i + 1];
            fvgRetested[i] = fvgRetested[i + 1];
            fvgIds[i] = fvgIds[i + 1];
        }
        fvgCount--;
    }
    
    fvgTimes[fvgCount] = fvgTime;
    fvgTopPrices[fvgCount] = fvgTop;
    fvgBottomPrices[fvgCount] = fvgBottom;
    fvgIsBullish[fvgCount] = isBullish;
    fvgChochIds[fvgCount] = chochId;
    fvgRetested[fvgCount] = false;
    fvgIds[fvgCount] = ++uniqueId;
    
    fvgCount++;
    
    // Draw FVG zone
    string zoneName = objPrefix + "FVG_" + IntegerToString(uniqueId);
    CreateZoneRectangle(zoneName, fvgTime, fvgTop, fvgBottom, ColorFVG_Zone);
    
    // Label
    string labelName = objPrefix + "FVG_LBL_" + IntegerToString(uniqueId);
    string text = "FVG";
    CreateTextLabel(labelName, fvgTime, (fvgTop + fvgBottom) / 2, ColorFVG_Zone, text, TextSize - 2);
}

//+------------------------------------------------------------------+
//| Detect Order Blocks at CHoCH swing points                       |
//+------------------------------------------------------------------+
void DetectOBAtCHoCH(const datetime &time[], const double &open[], 
                    const double &high[], const double &low[], const double &close[])
{
    if(chochCount == 0) return;
    
    for(int c = chochCount - 1; c >= MathMax(0, chochCount - 3); c--)
    {
        // Find the swing that created this CHoCH
        for(int s = 0; s < swingCount; s++)
        {
            if(swingIds[s] == chochSwingIds[c])
            {
                // Find OB near this swing point
                int swingBar = swingIndices[s];
                bool isSwingHigh = (swingTypes[s] == SWING_HIGH);
                
                // Look for order block pattern
                FindOBNearSwing(time, open, high, low, close, swingBar, isSwingHigh, chochIsBullish[c], chochIds[c]);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Find Order Block near swing point                               |
//+------------------------------------------------------------------+
void FindOBNearSwing(const datetime &time[], const double &open[], const double &high[], 
                    const double &low[], const double &close[], int swingBar, bool isSwingHigh, 
                    bool isBullish, int chochId)
{
    // Look for OB within 5 bars of the swing
    int searchRange = 5;
    
    for(int i = MathMax(0, swingBar - searchRange); i <= MathMin(ArraySize(time) - 1, swingBar + searchRange); i++)
    {
        bool isOB = false;
        double obTop = 0, obBottom = 0;
        
        if(isBullish && !isSwingHigh)
        {
            // Bullish OB at swing low: look for bearish candle
            if(close[i] < open[i])
            {
                obTop = open[i];
                obBottom = close[i];
                isOB = true;
            }
        }
        else if(!isBullish && isSwingHigh)
        {
            // Bearish OB at swing high: look for bullish candle
            if(close[i] > open[i])
            {
                obTop = close[i];
                obBottom = open[i];
                isOB = true;
            }
        }
        
        if(isOB && !OBExists(time[i], obTop, obBottom))
        {
            AddOB(time[i], obTop, obBottom, isBullish, chochId);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if OB already exists                                      |
//+------------------------------------------------------------------+
bool OBExists(datetime obTime, double obTop, double obBottom)
{
    for(int i = 0; i < obCount; i++)
    {
        if(obTimes[i] == obTime && 
           MathAbs(obTopPrices[i] - obTop) < _Point && 
           MathAbs(obBottomPrices[i] - obBottom) < _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add new Order Block                                             |
//+------------------------------------------------------------------+
void AddOB(datetime obTime, double obTop, double obBottom, bool isBullish, int chochId)
{
    if(obCount >= ArraySize(obTimes))
    {
        // Remove oldest OB
        for(int i = 0; i < obCount - 1; i++)
        {
            obTimes[i] = obTimes[i + 1];
            obTopPrices[i] = obTopPrices[i + 1];
            obBottomPrices[i] = obBottomPrices[i + 1];
            obIsBullish[i] = obIsBullish[i + 1];
            obChochIds[i] = obChochIds[i + 1];
            obRetested[i] = obRetested[i + 1];
            obIds[i] = obIds[i + 1];
        }
        obCount--;
    }
    
    obTimes[obCount] = obTime;
    obTopPrices[obCount] = obTop;
    obBottomPrices[obCount] = obBottom;
    obIsBullish[obCount] = isBullish;
    obChochIds[obCount] = chochId;
    obRetested[obCount] = false;
    obIds[obCount] = ++uniqueId;
    
    obCount++;
    
    // Draw OB zone
    string zoneName = objPrefix + "OB_" + IntegerToString(uniqueId);
    CreateZoneRectangle(zoneName, obTime, obTop, obBottom, ColorOB_Zone);
    
    // Label
    string labelName = objPrefix + "OB_LBL_" + IntegerToString(uniqueId);
    string text = "OB";
    CreateTextLabel(labelName, obTime, (obTop + obBottom) / 2, ColorOB_Zone, text, TextSize - 2);
}

//+------------------------------------------------------------------+
//| Check for retests and generate entry signals                    |
//+------------------------------------------------------------------+
void CheckRetestsAndEntries(const int total, const datetime &time[], const double &open[], 
                           const double &high[], const double &low[], const double &close[])
{
    // Check FVG retests first
    for(int f = 0; f < fvgCount; f++)
    {
        if(fvgRetested[f]) continue;
        
        // Check if current price is retesting FVG
        for(int i = total - 10; i < total; i++) // Check last 10 bars
        {
            if(i < 0) continue;
            
            bool inFVG = (low[i] <= fvgTopPrices[f] && high[i] >= fvgBottomPrices[f]);
            
            if(inFVG)
            {
                fvgRetested[f] = true;
                
                // Generate entry signal
                if(ShowEntrySignals)
                {
                    GenerateEntrySignal(time[i], (fvgTopPrices[f] + fvgBottomPrices[f]) / 2, 
                                       fvgIsBullish[f] ? ENTRY_LONG : ENTRY_SHORT, "FVG Retest");
                }
                break;
            }
        }
    }
    
    // Check OB retests if FVG failed
    for(int o = 0; o < obCount; o++)
    {
        if(obRetested[o]) continue;
        
        // Check if current price is retesting OB
        for(int i = total - 10; i < total; i++)
        {
            if(i < 0) continue;
            
            bool inOB = (low[i] <= obTopPrices[o] && high[i] >= obBottomPrices[o]);
            
            if(inOB)
            {
                obRetested[o] = true;
                
                // Generate entry signal
                if(ShowEntrySignals)
                {
                    GenerateEntrySignal(time[i], (obTopPrices[o] + obBottomPrices[o]) / 2, 
                                       obIsBullish[o] ? ENTRY_LONG : ENTRY_SHORT, "OB Retest");
                }
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Generate entry signal                                           |
//+------------------------------------------------------------------+
void GenerateEntrySignal(datetime entryTime, double entryPrice, EntryType entryType, string reason)
{
    if(entryCount >= ArraySize(entryTimes))
    {
        // Remove oldest entry
        for(int i = 0; i < entryCount - 1; i++)
        {
            entryTimes[i] = entryTimes[i + 1];
            entryPrices[i] = entryPrices[i + 1];
            entryTypes[i] = entryTypes[i + 1];
            entryConfirmed[i] = entryConfirmed[i + 1];
            entryIds[i] = entryIds[i + 1];
        }
        entryCount--;
    }
    
    entryTimes[entryCount] = entryTime;
    entryPrices[entryCount] = entryPrice;
    entryTypes[entryCount] = entryType;
    entryConfirmed[entryCount] = true;
    entryIds[entryCount] = ++uniqueId;
    
    entryCount++;
    totalSignals++;
    
    // Draw entry signal
    string signalName = objPrefix + "ENTRY_" + IntegerToString(uniqueId);
    string text = (entryType == ENTRY_LONG) ? "LONG ↑" : "SHORT ↓";
    color signalColor = (entryType == ENTRY_LONG) ? ColorEntryLong : ColorEntryShort;
    
    CreateTextLabel(signalName, entryTime, entryPrice, signalColor, text, TextSize + 2);
    
    // Log the signal
    if(EnableLogging && fileHandle != INVALID_HANDLE)
    {
        string direction = (entryType == ENTRY_LONG) ? "LONG" : "SHORT";
        FileWrite(fileHandle, TimeToString(entryTime), "ENTRY", DoubleToString(entryPrice, _Digits), 
                 direction, "PENDING", reason);
    }
    
    Print("[CTI Strategy] Entry Signal: ", text, " at ", DoubleToString(entryPrice, _Digits), " - ", reason);
}

//+------------------------------------------------------------------+
//| Update visual elements                                          |
//+------------------------------------------------------------------+
void UpdateVisualElements()
{
    // Update statistics label
    string statsText = StringFormat("CTI Strategy Stats\nTotal Signals: %d\nSuccess: %d\nFailed: %d\nSuccess Rate: %.1f%%",
                                   totalSignals, successfulEntries, failedEntries,
                                   (totalSignals > 0) ? (successfulEntries * 100.0 / totalSignals) : 0.0);
    
    string statsName = objPrefix + "STATS";
    if(ObjectFind(0, statsName) >= 0) ObjectDelete(0, statsName);
    
    CreateStatsLabel(statsName, statsText);
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
//| Create short horizontal line                                    |
//+------------------------------------------------------------------+
void CreateShortHorizontalLine(string objName, datetime time, double price, color clr)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    datetime endTime = time + PeriodSeconds(PERIOD_CURRENT) * 10; // 10 bars long
    
    ObjectCreate(0, objName, OBJ_TREND, 0, time, price, endTime, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_RAY, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Create zone rectangle                                           |
//+------------------------------------------------------------------+
void CreateZoneRectangle(string objName, datetime time, double top, double bottom, color clr)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    datetime endTime = time + PeriodSeconds(PERIOD_CURRENT) * 50; // Extend 50 bars
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, top, endTime, bottom);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create statistics label                                         |
//+------------------------------------------------------------------+
void CreateStatsLabel(string objName, string text)
{
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
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
