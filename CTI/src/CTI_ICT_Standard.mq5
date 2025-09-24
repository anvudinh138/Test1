//+------------------------------------------------------------------+
//|                                           CTI_ICT_Standard.mq5 |
//|                      Standard ICT Structure Implementation      |
//|   HH/HL/LH/LL → Horizontal BOS/CHoCH Lines → Valid FVG Only    |
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

input group "=== ICT STRUCTURE ==="
input bool   ShowBOSLines     = true;     // Show BOS horizontal lines
input bool   ShowCHoCHLines   = true;     // Show CHoCH horizontal lines
input bool   ShowValidFVG     = true;     // Show only unfilled FVG from CHoCH waves
input double MinFVGSize       = 2.0;      // Minimum FVG size in points

input group "=== VISUAL SETTINGS ==="
input color  ColorHH          = clrLime;
input color  ColorHL          = clrGreen;
input color  ColorLH          = clrOrange;
input color  ColorLL          = clrRed;
input color  ColorBOSLine     = clrBlue;
input color  ColorCHoCHLine   = clrYellow;
input color  ColorFVG_Bull    = clrLightBlue;
input color  ColorFVG_Bear    = clrLightPink;
input int    TextSize         = 10;
input bool   DebugMode        = true;     // Print debug info

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

//--- Global variables - Swings
datetime swingTimes[];
double swingPrices[];
int swingIndices[];
SwingType swingTypes[];
StructureType swingStructures[];
bool swingProcessed[];
int swingIds[];

//--- Global variables - CHoCH tracking
datetime chochTimes[];
double chochPrices[];
bool chochIsBullish[];
int chochSwingIds[];
bool chochProcessed[];

//--- Counters
int swingCount = 0;
int chochCount = 0;
int uniqueId = 0;
TrendDirection currentTrend = TREND_UNKNOWN;
TrendDirection previousTrend = TREND_UNKNOWN;
string objPrefix = "ICT_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI ICT Standard v1.0");
    
    // Initialize swing arrays
    ArrayResize(swingTimes, 50);
    ArrayResize(swingPrices, 50);
    ArrayResize(swingIndices, 50);
    ArrayResize(swingTypes, 50);
    ArrayResize(swingStructures, 50);
    ArrayResize(swingProcessed, 50);
    ArrayResize(swingIds, 50);
    
    // Initialize CHoCH arrays
    ArrayResize(chochTimes, 20);
    ArrayResize(chochPrices, 20);
    ArrayResize(chochIsBullish, 20);
    ArrayResize(chochSwingIds, 20);
    ArrayResize(chochProcessed, 20);
    
    CleanupObjects();
    
    if(DebugMode) Print("[ICT Standard] Initialized successfully");
    
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
    
    // Convert to non-series arrays
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    
    // Step 1: Detect swing points
    DetectSwingPoints(rates_total, time, high, low, close);
    
    // Step 2: Analyze structure (HH/HL/LH/LL)
    AnalyzeStructure();
    
    // Step 3: Check for price breaking swing levels → create BOS/CHoCH lines
    CheckStructureBreaks(rates_total, time, high, low, close);
    
    // Step 4: Find valid FVG only from CHoCH waves
    if(ShowValidFVG) FindValidFVGFromCHoCH(time, open, high, low, close);
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    return rates_total;
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
    
    // Show swing point
    if(ShowSwingPoints)
    {
        string objName = objPrefix + "SW_" + IntegerToString(uniqueId);
        color swingColor = (type == SWING_HIGH) ? clrDodgerBlue : clrGold;
        string swingText = (type == SWING_HIGH) ? "H" : "L";
        
        CreateTextLabel(objName, swingTime, swingPrice, swingColor, swingText, 8);
    }
    
    if(DebugMode) 
    {
        Print("[ICT] Added swing: ", (type == SWING_HIGH ? "HIGH" : "LOW"), 
              " at ", TimeToString(swingTime), " price ", DoubleToString(swingPrice, _Digits));
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
        previousTrend = currentTrend;
        UpdateTrend(structure);
        
        // Show structure label with offset
        if(ShowStructure && structure != STRUCTURE_NONE)
        {
            string structureText = GetStructureText(structure);
            color structureColor = GetStructureColor(structure);
            string objName = objPrefix + "STR_" + IntegerToString(swingIds[i]);
            
            double offsetPrice = swingPrices[i] + (swingTypes[i] == SWING_HIGH ? 15 : -15) * _Point;
            CreateTextLabel(objName, swingTimes[i], offsetPrice, structureColor, structureText, TextSize);
        }
        
        // Check for CHoCH and store it
        CheckForCHoCH(i, structure);
        
        if(DebugMode)
        {
            Print("[ICT] Structure: ", GetStructureText(structure), 
                  " at ", TimeToString(swingTimes[i]), 
                  " Trend: ", (currentTrend == TREND_BULLISH ? "BULL" : "BEAR"));
        }
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
//| Check for CHoCH and store it                                   |
//+------------------------------------------------------------------+
void CheckForCHoCH(int swingIndex, StructureType structure)
{
    bool isCHoCH = false;
    bool isBullish = false;
    
    // CHoCH occurs when trend changes
    if(previousTrend != TREND_UNKNOWN && currentTrend != previousTrend)
    {
        // Bullish CHoCH: HL formation (trend change from bear to bull)
        if(structure == STRUCTURE_HL && previousTrend == TREND_BEARISH)
        {
            isCHoCH = true;
            isBullish = true;
        }
        
        // Bearish CHoCH: LH formation (trend change from bull to bear)
        if(structure == STRUCTURE_LH && previousTrend == TREND_BULLISH)
        {
            isCHoCH = true;
            isBullish = false;
        }
    }
    
    if(isCHoCH)
    {
        // Store CHoCH information for FVG analysis
        AddCHoCH(swingTimes[swingIndex], swingPrices[swingIndex], isBullish, swingIds[swingIndex]);
        
        if(DebugMode)
        {
            Print("[ICT] CHoCH detected: ", (isBullish ? "BULLISH" : "BEARISH"), 
                  " at ", TimeToString(swingTimes[swingIndex]));
        }
    }
}

//+------------------------------------------------------------------+
//| Add CHoCH to tracking array                                     |
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
            chochProcessed[i] = chochProcessed[i + 1];
        }
        chochCount--;
    }
    
    chochTimes[chochCount] = chochTime;
    chochPrices[chochCount] = chochPrice;
    chochIsBullish[chochCount] = isBullish;
    chochSwingIds[chochCount] = swingId;
    chochProcessed[chochCount] = false;
    
    chochCount++;
}

//+------------------------------------------------------------------+
//| Check for structure breaks and create horizontal lines         |
//+------------------------------------------------------------------+
void CheckStructureBreaks(const int total, const datetime &time[], 
                         const double &high[], const double &low[], const double &close[])
{
    // Check recent price action for breaks
    for(int i = total - 10; i < total; i++) // Check last 10 bars
    {
        if(i < 0) continue;
        
        double currentClose = close[i];
        datetime currentTime = time[i];
        
        // Check for breaks of recent swing levels
        for(int s = swingCount - 1; s >= MathMax(0, swingCount - 5); s--)
        {
            if(swingTimes[s] >= currentTime) continue;
            
            // Check for bullish break (close above swing high)
            if(swingTypes[s] == SWING_HIGH && currentClose > swingPrices[s])
            {
                string lineKey = "BREAK_HIGH_" + IntegerToString(swingIds[s]);
                if(!LineExists(lineKey))
                {
                    // Determine if this is BOS or CHoCH based on structure context
                    bool isCHoCHBreak = IsStructureChangeBreak(s, true);
                    
                    if(isCHoCHBreak && ShowCHoCHLines)
                    {
                        CreateHorizontalLine(objPrefix + "CHOCH_" + lineKey, swingPrices[s], ColorCHoCHLine, "CHoCH");
                        
                        if(DebugMode)
                            Print("[ICT] CHoCH Line created at: ", DoubleToString(swingPrices[s], _Digits));
                    }
                    else if(!isCHoCHBreak && ShowBOSLines)
                    {
                        CreateHorizontalLine(objPrefix + "BOS_" + lineKey, swingPrices[s], ColorBOSLine, "BOS");
                        
                        if(DebugMode)
                            Print("[ICT] BOS Line created at: ", DoubleToString(swingPrices[s], _Digits));
                    }
                }
            }
            
            // Check for bearish break (close below swing low)
            if(swingTypes[s] == SWING_LOW && currentClose < swingPrices[s])
            {
                string lineKey = "BREAK_LOW_" + IntegerToString(swingIds[s]);
                if(!LineExists(lineKey))
                {
                    // Determine if this is BOS or CHoCH based on structure context
                    bool isCHoCHBreak = IsStructureChangeBreak(s, false);
                    
                    if(isCHoCHBreak && ShowCHoCHLines)
                    {
                        CreateHorizontalLine(objPrefix + "CHOCH_" + lineKey, swingPrices[s], ColorCHoCHLine, "CHoCH");
                        
                        if(DebugMode)
                            Print("[ICT] CHoCH Line created at: ", DoubleToString(swingPrices[s], _Digits));
                    }
                    else if(!isCHoCHBreak && ShowBOSLines)
                    {
                        CreateHorizontalLine(objPrefix + "BOS_" + lineKey, swingPrices[s], ColorBOSLine, "BOS");
                        
                        if(DebugMode)
                            Print("[ICT] BOS Line created at: ", DoubleToString(swingPrices[s], _Digits));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if line already exists                                   |
//+------------------------------------------------------------------+
bool LineExists(string lineKey)
{
    string bosName = objPrefix + "BOS_" + lineKey;
    string chochName = objPrefix + "CHOCH_" + lineKey;
    
    return (ObjectFind(0, bosName) >= 0 || ObjectFind(0, chochName) >= 0);
}

//+------------------------------------------------------------------+
//| Determine if break represents structure change (CHoCH)         |
//+------------------------------------------------------------------+
bool IsStructureChangeBreak(int swingIndex, bool isBullishBreak)
{
    // Check if this swing is associated with any CHoCH
    int swingId = swingIds[swingIndex];
    
    for(int c = 0; c < chochCount; c++)
    {
        if(chochSwingIds[c] == swingId)
        {
            return true; // This is a CHoCH break
        }
    }
    
    return false; // This is a BOS break
}

//+------------------------------------------------------------------+
//| Find valid FVG only from CHoCH waves                           |
//+------------------------------------------------------------------+
void FindValidFVGFromCHoCH(const datetime &time[], const double &open[], 
                          const double &high[], const double &low[], const double &close[])
{
    if(chochCount == 0) return;
    
    // For each CHoCH, find FVG in the wave that created it
    for(int c = 0; c < chochCount; c++)
    {
        if(chochProcessed[c]) continue;
        
        // Find the swing range that created this CHoCH
        int chochSwingIndex = FindSwingIndexById(chochSwingIds[c]);
        if(chochSwingIndex == -1) continue;
        
        // Find previous opposite swing to define the wave range
        int waveStartIndex = -1;
        for(int s = chochSwingIndex - 1; s >= 0; s--)
        {
            if(swingTypes[s] != swingTypes[chochSwingIndex])
            {
                waveStartIndex = s;
                break;
            }
        }
        
        if(waveStartIndex == -1) continue;
        
        // Search for FVG in this wave range
        int startBar = swingIndices[waveStartIndex];
        int endBar = swingIndices[chochSwingIndex];
        
        FindFVGInWave(time, open, high, low, close, startBar, endBar, chochIsBullish[c], c);
        
        chochProcessed[c] = true;
    }
}

//+------------------------------------------------------------------+
//| Find swing index by ID                                         |
//+------------------------------------------------------------------+
int FindSwingIndexById(int swingId)
{
    for(int i = 0; i < swingCount; i++)
    {
        if(swingIds[i] == swingId)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Find FVG in specific wave range                                |
//+------------------------------------------------------------------+
void FindFVGInWave(const datetime &time[], const double &open[], const double &high[], 
                  const double &low[], const double &close[], int startBar, int endBar, 
                  bool isBullish, int chochIndex)
{
    // Ensure correct order
    if(startBar > endBar)
    {
        int temp = startBar;
        startBar = endBar;
        endBar = temp;
    }
    
    // Look for FVG pattern in this wave
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
        
        if(foundFVG && (fvgTop - fvgBottom) >= MinFVGSize * _Point)
        {
            // Check if this FVG is still valid (not filled)
            if(IsFVGValid(i, fvgTop, fvgBottom, time, high, low, close))
            {
                string fvgName = objPrefix + "FVG_" + IntegerToString(chochIndex) + "_" + IntegerToString(i);
                CreateFVGZone(fvgName, time[i], fvgTop, fvgBottom, 
                             isBullish ? ColorFVG_Bull : ColorFVG_Bear, isBullish);
                
                if(DebugMode)
                {
                    Print("[ICT] Valid FVG found in CHoCH wave at bar ", i,
                          " Size: ", DoubleToString((fvgTop - fvgBottom) / _Point, 1), " points");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if FVG is still valid (not filled by price)             |
//+------------------------------------------------------------------+
bool IsFVGValid(int fvgBar, double fvgTop, double fvgBottom, const datetime &time[], 
               const double &high[], const double &low[], const double &close[])
{
    // Check bars after FVG formation to see if it's been filled
    int arraySize = ArraySize(time);
    
    for(int i = fvgBar + 3; i < arraySize; i++) // Start checking 3 bars after FVG
    {
        // FVG is filled if price has moved through the entire gap
        if(low[i] <= fvgBottom && high[i] >= fvgTop)
        {
            return false; // FVG has been filled
        }
        
        // Stop checking after certain period (50 bars)
        if(i > fvgBar + 50) break;
    }
    
    return true; // FVG is still valid
}

//+------------------------------------------------------------------+
//| Create FVG zone rectangle                                       |
//+------------------------------------------------------------------+
void CreateFVGZone(string objName, datetime startTime, double top, double bottom, color clr, bool isBullish)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    // Create rectangle extending 20 bars to the right
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    
    // Add label
    string labelName = objName + "_LBL";
    string text = "FVG" + (isBullish ? "↑" : "↓");
    double labelPrice = (top + bottom) / 2;
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, labelPrice);
    ObjectSetString(0, labelName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Create horizontal line                                          |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string objName, double price, color clr, string lineType)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    
    // Add text label at the line
    string labelName = objName + "_LBL";
    ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), price);
    ObjectSetString(0, labelName, OBJPROP_TEXT, lineType);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
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
