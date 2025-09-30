//+------------------------------------------------------------------+
//|                                            CTI_FVG_Simple.mq5 |
//|                         Simple FVG Detection for Testing       |
//+------------------------------------------------------------------+
#property copyright "CTI Development Team"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input bool   ShowFVG          = true;     // Show FVG zones
input double MinFVGSize       = 1.0;      // Minimum FVG size in points
input int    MaxFVGToShow     = 20;       // Maximum FVG zones to show
input bool   DebugMode        = true;     // Print debug information

//--- Colors
input color  ColorFVG_Bull    = clrLightBlue;
input color  ColorFVG_Bear    = clrLightPink;

//--- Global variables
string objPrefix = "FVG_";
int fvgCount = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, "CTI FVG Simple");
    CleanupObjects();
    
    if(DebugMode) Print("[FVG Debug] Initialized successfully");
    
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
    if(rates_total < 10) return 0;
    
    // Convert to non-series arrays
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    
    // Detect FVG patterns
    DetectFVGSimple(rates_total, time, open, high, low, close);
    
    // Convert back to series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Simple FVG detection                                           |
//+------------------------------------------------------------------+
void DetectFVGSimple(const int total, const datetime &time[], const double &open[],
                    const double &high[], const double &low[], const double &close[])
{
    if(!ShowFVG) return;
    
    // Scan for FVG patterns (3-candle gaps) - check recent bars only to avoid overload
    int startBar = MathMax(1, total - 100); // Check last 100 bars
    
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
                // Check if this FVG already exists
                string fvgName = objPrefix + "BULL_" + IntegerToString(i);
                if(ObjectFind(0, fvgName) < 0 && fvgCount < MaxFVGToShow)
                {
                    CreateFVGZone(fvgName, time[i], fvgTop, fvgBottom, ColorFVG_Bull, true);
                    fvgCount++;
                    
                    if(DebugMode)
                    {
                        Print("[FVG Debug] Bullish FVG at bar ", i, 
                              " Time: ", TimeToString(time[i]),
                              " Top: ", DoubleToString(fvgTop, _Digits),
                              " Bottom: ", DoubleToString(fvgBottom, _Digits),
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
                // Check if this FVG already exists
                string fvgName = objPrefix + "BEAR_" + IntegerToString(i);
                if(ObjectFind(0, fvgName) < 0 && fvgCount < MaxFVGToShow)
                {
                    CreateFVGZone(fvgName, time[i], fvgTop, fvgBottom, ColorFVG_Bear, false);
                    fvgCount++;
                    
                    if(DebugMode)
                    {
                        Print("[FVG Debug] Bearish FVG at bar ", i,
                              " Time: ", TimeToString(time[i]),
                              " Top: ", DoubleToString(fvgTop, _Digits),
                              " Bottom: ", DoubleToString(fvgBottom, _Digits),
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
