//+------------------------------------------------------------------+
//|                                             CTI_All_In_One.mq5 |
//|                    Complete CTI with No Label Overlap Issues   |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "=== DETECTION SETTINGS ==="
input int    SwingLookback    = 3;        // Fractal lookback for swing detection
input bool   ShowSwingPoints  = true;     // Show swing high/low points
input bool   ShowStructure    = true;     // Show HH/HL/LH/LL labels
input bool   ShowBOS          = true;     // Show Break of Structure
input bool   ShowCHoCH        = true;     // Show Change of Character
input bool   ShowFVG          = true;     // Show FVG zones
input double MinFVGSize       = 1.0;      // Minimum FVG size in points
input bool   DebugMode        = true;     // Print debug info

input group "=== VISUAL SETTINGS ==="
input color  ColorHH          = clrLime;
input color  ColorHL          = clrGreen;
input color  ColorLH          = clrOrange;
input color  ColorLL          = clrRed;
input color  ColorBOS_Bull    = clrBlue;
input color  ColorBOS_Bear    = clrMagenta;
input color  ColorCHoCH_Bull  = clrCyan;
input color  ColorCHoCH_Bear  = clrYellow;
input color  ColorFVG_Bull    = clrLightBlue;
input color  ColorFVG_Bear    = clrLightPink;
input int    TextSize         = 10;

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

//--- Global variables
datetime swingTimes[];
double swingPrices[];
int swingIndices[];
SwingType swingTypes[];
StructureType swingStructures[];
bool swingProcessed[];

int swingCount = 0;
int fvgCount = 0;
TrendDirection currentTrend = TREND_UNKNOWN;
TrendDirection previousTrend = TREND_UNKNOWN;
string objPrefix = "CTI_AIO_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI All-In-One v1.0");
    
    ArrayResize(swingTimes, 50);
    ArrayResize(swingPrices, 50);
    ArrayResize(swingIndices, 50);
    ArrayResize(swingTypes, 50);
    ArrayResize(swingStructures, 50);
    ArrayResize(swingProcessed, 50);
    
    CleanupObjects();
    
    if(DebugMode) Print("[CTI AIO] Initialized successfully");
    
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
    
    // Step 2: Analyze structure
    AnalyzeStructure();
    
    // Step 3: Detect BOS
    DetectBOS(rates_total, time, high, low, close);
    
    // Step 4: Detect FVG
    if(ShowFVG) DetectFVG(rates_total, time, open, high, low, close);
    
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
        }
        swingCount--;
    }
    
    swingTimes[swingCount] = swingTime;
    swingPrices[swingCount] = swingPrice;
    swingIndices[swingCount] = swingIndex;
    swingTypes[swingCount] = type;
    swingStructures[swingCount] = STRUCTURE_NONE;
    swingProcessed[swingCount] = false;
    
    swingCount++;
    SortSwingsByTime();
    
    // Show swing point
    if(ShowSwingPoints)
    {
        string objName = objPrefix + "SW_" + IntegerToString(swingIndex);
        color swingColor = (type == SWING_HIGH) ? clrDodgerBlue : clrGold;
        string swingText = (type == SWING_HIGH) ? "H" : "L";
        
        CreateTextLabel(objName, swingTime, swingPrice, swingColor, swingText, 8);
    }
    
    if(DebugMode) 
    {
        Print("[CTI AIO] Added swing: ", (type == SWING_HIGH ? "HIGH" : "LOW"), 
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
        
        // Show structure label with offset to avoid overlap
        if(ShowStructure && structure != STRUCTURE_NONE)
        {
            string structureText = GetStructureText(structure);
            color structureColor = GetStructureColor(structure);
            string objName = objPrefix + "STR_" + IntegerToString(swingIndices[i]);
            
            // Layer 1: Structure labels (closest to swing)
            double offsetPrice = swingPrices[i] + (swingTypes[i] == SWING_HIGH ? 15 : -15) * _Point;
            CreateTextLabel(objName, swingTimes[i], offsetPrice, structureColor, structureText, TextSize);
        }
        
        // Check for CHoCH with offset
        CheckForCHoCH(i, structure);
        
        if(DebugMode)
        {
            Print("[CTI AIO] Structure: ", GetStructureText(structure), 
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
//| Check for CHoCH at structure formation                          |
//+------------------------------------------------------------------+
void CheckForCHoCH(int swingIndex, StructureType structure)
{
    if(!ShowCHoCH) return;
    
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
        string objName = objPrefix + "CHOCH_" + IntegerToString(swingIndices[swingIndex]);
        string text = "CHoCH" + (isBullish ? "↑" : "↓");
        color chochColor = isBullish ? ColorCHoCH_Bull : ColorCHoCH_Bear;
        
        // Layer 2: CHoCH labels (further from swing)
        double offsetPrice = swingPrices[swingIndex] + (swingTypes[swingIndex] == SWING_HIGH ? 35 : -35) * _Point;
        CreateTextLabel(objName, swingTimes[swingIndex], offsetPrice, chochColor, text, TextSize + 2);
        
        if(DebugMode)
        {
            Print("[CTI AIO] CHoCH detected: ", text, " at ", TimeToString(swingTimes[swingIndex]));
        }
    }
}

//+------------------------------------------------------------------+
//| Detect BOS                                                      |
//+------------------------------------------------------------------+
void DetectBOS(const int total, const datetime &time[], 
               const double &high[], const double &low[], const double &close[])
{
    if(!ShowBOS || swingCount < 2) return;
    
    // Check recent price action for BOS
    for(int i = total - 10; i < total; i++) // Check last 10 bars
    {
        if(i < 0) continue;
        
        double currentClose = close[i];
        datetime currentTime = time[i];
        
        // Check for bullish BOS (close above recent swing high)
        for(int s = swingCount - 1; s >= MathMax(0, swingCount - 5); s--)
        {
            if(swingTypes[s] == SWING_HIGH && swingTimes[s] < currentTime)
            {
                if(currentClose > swingPrices[s])
                {
                    string objName = objPrefix + "BOS_BULL_" + IntegerToString(i);
                    if(ObjectFind(0, objName) < 0)
                    {
                        // Layer 3: BOS labels (furthest from swing)
                        double offsetPrice = currentClose + 50 * _Point;
                        CreateTextLabel(objName, currentTime, offsetPrice, ColorBOS_Bull, "BOS↑", TextSize + 2);
                        
                        if(DebugMode)
                        {
                            Print("[CTI AIO] Bullish BOS at ", TimeToString(currentTime), 
                                  " broke high at ", DoubleToString(swingPrices[s], _Digits));
                        }
                    }
                    break;
                }
            }
        }
        
        // Check for bearish BOS (close below recent swing low)
        for(int s = swingCount - 1; s >= MathMax(0, swingCount - 5); s--)
        {
            if(swingTypes[s] == SWING_LOW && swingTimes[s] < currentTime)
            {
                if(currentClose < swingPrices[s])
                {
                    string objName = objPrefix + "BOS_BEAR_" + IntegerToString(i);
                    if(ObjectFind(0, objName) < 0)
                    {
                        // Layer 3: BOS labels (furthest from swing)
                        double offsetPrice = currentClose - 50 * _Point;
                        CreateTextLabel(objName, currentTime, offsetPrice, ColorBOS_Bear, "BOS↓", TextSize + 2);
                        
                        if(DebugMode)
                        {
                            Print("[CTI AIO] Bearish BOS at ", TimeToString(currentTime), 
                                  " broke low at ", DoubleToString(swingPrices[s], _Digits));
                        }
                    }
                    break;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect FVG patterns                                            |
//+------------------------------------------------------------------+
void DetectFVG(const int total, const datetime &time[], const double &open[],
               const double &high[], const double &low[], const double &close[])
{
    // Scan recent bars for FVG patterns
    int startBar = MathMax(1, total - 50); // Check last 50 bars
    
    for(int i = startBar; i < total - 1; i++)
    {
        // Bullish FVG: low[i+1] > high[i-1] (gap up)
        if(i > 0 && low[i + 1] > high[i - 1])
        {
            double fvgTop = low[i + 1];
            double fvgBottom = high[i - 1];
            double fvgSize = fvgTop - fvgBottom;
            
            if(fvgSize >= MinFVGSize * _Point)
            {
                string fvgName = objPrefix + "FVG_BULL_" + IntegerToString(i);
                if(ObjectFind(0, fvgName) < 0 && fvgCount < 20)
                {
                    CreateFVGZone(fvgName, time[i], fvgTop, fvgBottom, ColorFVG_Bull, true);
                    fvgCount++;
                    
                    if(DebugMode)
                    {
                        Print("[CTI AIO] Bullish FVG at bar ", i, 
                              " Size: ", DoubleToString(fvgSize / _Point, 1), " points");
                    }
                }
            }
        }
        
        // Bearish FVG: high[i+1] < low[i-1] (gap down)
        if(i > 0 && high[i + 1] < low[i - 1])
        {
            double fvgTop = low[i - 1];
            double fvgBottom = high[i + 1];
            double fvgSize = fvgTop - fvgBottom;
            
            if(fvgSize >= MinFVGSize * _Point)
            {
                string fvgName = objPrefix + "FVG_BEAR_" + IntegerToString(i);
                if(ObjectFind(0, fvgName) < 0 && fvgCount < 20)
                {
                    CreateFVGZone(fvgName, time[i], fvgTop, fvgBottom, ColorFVG_Bear, false);
                    fvgCount++;
                    
                    if(DebugMode)
                    {
                        Print("[CTI AIO] Bearish FVG at bar ", i,
                              " Size: ", DoubleToString(fvgSize / _Point, 1), " points");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Create FVG zone rectangle                                       |
//+------------------------------------------------------------------+
void CreateFVGZone(string objName, datetime startTime, double top, double bottom, color clr, bool isBullish)
{
    if(ObjectFind(0, objName) >= 0) return;
    
    // Create rectangle extending 15 bars to the right
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 15;
    
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
    
    fvgCount = 0;
}
//+------------------------------------------------------------------+
