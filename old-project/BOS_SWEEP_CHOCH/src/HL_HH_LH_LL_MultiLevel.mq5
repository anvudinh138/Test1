//+------------------------------------------------------------------+
//|                                       HL_HH_LH_LL_MultiLevel.mq5 |
//|                          Copyright 2024, Market Structure Expert |
//|                              Multi-Level Entry Detection System   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Market Structure Expert"
#property link      "https://github.com/market-structure"
#property version   "2.00"
#property description "Advanced Market Structure Analysis with Multi-Level Entry Detection"
#property description "Array A (Main Structure) + Array B (Entry Detection) System"
#property description "No Lower Timeframes Required - All Analysis on Current TF"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include "HL_Structures.mqh"
#include "HL_ArrayManager.mqh"
#include "HL_EntryDetection.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Core Algorithm Settings ==="
input double InpRetestThresholdA = 0.20;      // Array A Retest Threshold (20%)
input double InpRetestThresholdB = 0.15;      // Array B Retest Threshold (15%)
input int    InpMinSwingDistance = 10;        // Minimum Swing Distance (pips)
input bool   InpConfirmOnClose = true;        // Confirm Only on Candle Close

input group "=== Multi-Level System ==="
input int    InpMaxEntryArrays = 5;           // Maximum Concurrent Array B Instances
input double InpRangeBufferPips = 2.0;        // Array B Range Buffer (pips)
input int    InpEntryConfirmBars = 2;         // Entry Confirmation Bars
input int    InpStaleTimeoutBars = 20;        // Stale Array Timeout (bars)
input bool   InpAutoClearStale = true;        // Auto Clear Stale Arrays

input group "=== Detection Thresholds ==="
input double InpBOSBuffer = 1.0;              // BOS Buffer (pips)
input double InpChoCHBuffer = 0.5;             // ChoCH Buffer (pips)
input int    InpSweepConfirmBars = 3;          // Sweep Confirmation Bars

input group "=== Visual Display ==="
input bool   InpShowArrayA = true;            // Show Array A Structure
input bool   InpShowArrayB = true;            // Show Array B Patterns
input bool   InpShowRanges = true;            // Show Range Boundaries
input bool   InpShowEntrySignals = true;      // Show Entry Signals
input bool   InpShowLabels = true;            // Show Swing Labels

input group "=== Colors & Styles ==="
input color  InpColorBullish = clrDodgerBlue;     // Bullish Structure Color
input color  InpColorBearish = clrOrangeRed;      // Bearish Structure Color
input color  InpColorChoCH = clrMagenta;          // ChoCH Event Color
input color  InpColorSweep = clrYellow;           // Sweep Event Color
input color  InpColorEntryLong = clrLimeGreen;    // Long Entry Color
input color  InpColorEntryShort = clrRed;         // Short Entry Color
input color  InpColorRange = clrGray;             // Range Boundary Color

input group "=== Alerts ==="
input bool   InpAlertOnChoCH = true;          // Alert on ChoCH Detection
input bool   InpAlertOnSweep = true;          // Alert on Sweep Detection
input bool   InpAlertOnEntry = true;          // Alert on Entry Signals
input bool   InpPushNotifications = false;   // Push Notifications

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CArrayManager*      g_ArrayManager;
CEntryDetection*    g_EntryDetector;
datetime            g_LastCalculated;
int                 g_TotalBars;

// Visual Objects Management
string              g_IndicatorName = "HL_MultiLevel";
int                 g_ObjectCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicator name with unique suffix
    g_IndicatorName = "HL_ML_" + IntegerToString(ChartID());
    
    // Initialize managers
    g_ArrayManager = new CArrayManager(InpRetestThresholdA, InpMinSwingDistance);
    g_EntryDetector = new CEntryDetection(InpRetestThresholdB, InpMaxEntryArrays);
    
    if(!g_ArrayManager || !g_EntryDetector)
    {
        Print("ERROR: Failed to initialize managers");
        return INIT_FAILED;
    }
    
    // Set parameters
    g_ArrayManager.SetConfirmOnClose(InpConfirmOnClose);
    g_ArrayManager.SetBOSBuffer(InpBOSBuffer * Point * 10);
    g_ArrayManager.SetChoCHBuffer(InpChoCHBuffer * Point * 10);
    
    g_EntryDetector.SetRangeBuffer(InpRangeBufferPips * Point * 10);
    g_EntryDetector.SetConfirmationBars(InpEntryConfirmBars);
    g_EntryDetector.SetStaleTimeout(InpStaleTimeoutBars);
    g_EntryDetector.SetAutoClearStale(InpAutoClearStale);
    
    // Initialize display
    g_LastCalculated = 0;
    g_TotalBars = iBars(Symbol(), Period());
    
    Print("HL-HH-LH-LL Multi-Level Entry Detection System v2.0 Initialized");
    Print("Array A Threshold: ", InpRetestThresholdA * 100, "%");
    Print("Array B Threshold: ", InpRetestThresholdB * 100, "%");
    Print("Max Entry Arrays: ", InpMaxEntryArrays);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up managers
    if(g_ArrayManager)
    {
        delete g_ArrayManager;
        g_ArrayManager = NULL;
    }
    
    if(g_EntryDetector)
    {
        delete g_EntryDetector;
        g_EntryDetector = NULL;
    }
    
    // Clean up visual objects
    CleanupVisualObjects();
    
    Print("HL Multi-Level System Deinitialized. Reason: ", reason);
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
    // Check if we have enough data
    if(rates_total < 10)
        return 0;
    
    // Determine start position for calculation
    int start = prev_calculated > 0 ? prev_calculated - 1 : 10;
    if(start < 10) start = 10;
    
    // Process new bars
    for(int i = start; i < rates_total - 1; i++) // Skip current bar if not closed
    {
        if(InpConfirmOnClose && i == rates_total - 1)
            break; // Skip current unclosed bar
            
        ProcessBar(i, time, open, high, low, close);
    }
    
    // Update visual display
    if(InpShowArrayA || InpShowArrayB || InpShowEntrySignals)
    {
        UpdateVisualDisplay();
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Process single bar for pattern recognition                      |
//+------------------------------------------------------------------+
void ProcessBar(int bar_index, 
               const datetime &time[],
               const double &open[],
               const double &high[],
               const double &low[],
               const double &close[])
{
    if(!g_ArrayManager || !g_EntryDetector)
        return;
        
    // Create swing point data for current bar
    SSwingPoint point;
    point.price_high = high[bar_index];
    point.price_low = low[bar_index];
    point.time = time[bar_index];
    point.bar_index = bar_index;
    point.swing_type = SWING_UNKNOWN;
    
    // Process with Array A (Main Structure)
    bool new_swing_detected = g_ArrayManager.ProcessSwingPoint(point);
    
    if(new_swing_detected)
    {
        // Check for ChoCH detection
        SChoCHEvent choch_event;
        if(g_ArrayManager.DetectChoCH(choch_event))
        {
            // Initialize Array B for entry detection
            g_EntryDetector.InitializeEntryArray(choch_event);
            
            // Generate ChoCH alert
            if(InpAlertOnChoCH)
            {
                string message = "ChoCH Detected: " + Symbol() + " " + 
                               EnumToString(Period()) + " at " + 
                               DoubleToString(choch_event.trigger_price, Digits);
                               
                Alert(message);
                if(InpPushNotifications)
                    SendNotification(message);
            }
            
            Print("ChoCH Event: Direction=", choch_event.direction, 
                  " Price=", choch_event.trigger_price,
                  " Range=[", choch_event.range_low, ",", choch_event.range_high, "]");
        }
        
        // Check for BOS detection  
        SBOSEvent bos_event;
        if(g_ArrayManager.DetectBOS(bos_event))
        {
            Print("BOS Event: Direction=", bos_event.direction,
                  " Price=", bos_event.trigger_price);
        }
    }
    
    // Process Array B instances for entry detection
    CArrayList<SEntrySignal> entry_signals;
    g_EntryDetector.ProcessEntryDetection(point, entry_signals);
    
    // Handle entry signals
    for(int i = 0; i < entry_signals.Total(); i++)
    {
        SEntrySignal signal = entry_signals.At(i);
        ProcessEntrySignal(signal);
    }
    
    // Clean up stale arrays if enabled
    if(InpAutoClearStale)
    {
        g_EntryDetector.CleanupStaleArrays(bar_index);
    }
}

//+------------------------------------------------------------------+
//| Process entry signal                                            |
//+------------------------------------------------------------------+
void ProcessEntrySignal(const SEntrySignal &signal)
{
    string signal_type = "";
    color signal_color = clrWhite;
    
    switch(signal.signal_type)
    {
        case ENTRY_REAL_CHOCH:
            signal_type = "Real ChoCH Entry";
            signal_color = signal.direction == TREND_BULLISH ? InpColorEntryLong : InpColorEntryShort;
            break;
            
        case ENTRY_SWEEP:
            signal_type = "Sweep Entry";
            signal_color = signal.direction == TREND_BULLISH ? InpColorEntryLong : InpColorEntryShort;
            break;
            
        default:
            return;
    }
    
    // Generate entry alert
    if(InpAlertOnEntry)
    {
        string direction_str = signal.direction == TREND_BULLISH ? "LONG" : "SHORT";
        string message = signal_type + " " + direction_str + ": " + Symbol() + 
                        " " + EnumToString(Period()) + " at " + 
                        DoubleToString(signal.entry_price, Digits);
                        
        Alert(message);
        if(InpPushNotifications)
            SendNotification(message);
    }
    
    // Log entry signal
    Print("ENTRY SIGNAL: ", signal_type, " ", 
          (signal.direction == TREND_BULLISH ? "LONG" : "SHORT"),
          " at ", signal.entry_price,
          " SL: ", signal.stop_loss,
          " TP: ", signal.take_profit);
          
    // Create visual marker for entry
    if(InpShowEntrySignals)
    {
        CreateEntryMarker(signal, signal_color);
    }
}

//+------------------------------------------------------------------+
//| Create visual marker for entry signal                           |
//+------------------------------------------------------------------+
void CreateEntryMarker(const SEntrySignal &signal, color marker_color)
{
    string obj_name = g_IndicatorName + "_Entry_" + IntegerToString(g_ObjectCounter++);
    
    if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, signal.signal_time, signal.entry_price))
    {
        ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, signal.direction == TREND_BULLISH ? 233 : 234);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, marker_color);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
        ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, 
                       "Entry: " + (signal.direction == TREND_BULLISH ? "LONG" : "SHORT") +
                       " | Price: " + DoubleToString(signal.entry_price, Digits) +
                       " | Type: " + (signal.signal_type == ENTRY_REAL_CHOCH ? "Real ChoCH" : "Sweep"));
    }
}

//+------------------------------------------------------------------+
//| Update visual display                                           |
//+------------------------------------------------------------------+
void UpdateVisualDisplay()
{
    if(!g_ArrayManager || !g_EntryDetector)
        return;
        
    // Update Array A visualization
    if(InpShowArrayA)
    {
        DrawArrayAStructure();
    }
    
    // Update Array B visualization  
    if(InpShowArrayB)
    {
        DrawArrayBStructure();
    }
    
    // Update range boundaries
    if(InpShowRanges)
    {
        DrawRangeBoundaries();
    }
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw Array A structure                                          |
//+------------------------------------------------------------------+
void DrawArrayAStructure()
{
    CArrayList<SSwingPoint> swing_points;
    g_ArrayManager.GetSwingPoints(swing_points);
    
    // Draw swing points and connections
    for(int i = 0; i < swing_points.Total() - 1; i++)
    {
        SSwingPoint point1 = swing_points.At(i);
        SSwingPoint point2 = swing_points.At(i + 1);
        
        // Draw trend line
        string line_name = g_IndicatorName + "_Line_A_" + IntegerToString(i);
        double price1 = (point1.swing_type == SWING_H || point1.swing_type == SWING_HH || point1.swing_type == SWING_LH) ? 
                        point1.price_high : point1.price_low;
        double price2 = (point2.swing_type == SWING_H || point2.swing_type == SWING_HH || point2.swing_type == SWING_LH) ? 
                        point2.price_high : point2.price_low;
        
        if(ObjectCreate(0, line_name, OBJ_TREND, 0, point1.time, price1, point2.time, price2))
        {
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, 
                           IsBullishSwing(point2.swing_type) ? InpColorBullish : InpColorBearish);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
        }
        
        // Draw swing label
        if(InpShowLabels)
        {
            string label_name = g_IndicatorName + "_Label_A_" + IntegerToString(i);
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, point2.time, price2))
            {
                ObjectSetString(0, label_name, OBJPROP_TEXT, SwingTypeToString(point2.swing_type));
                ObjectSetInteger(0, label_name, OBJPROP_COLOR, 
                               IsBullishSwing(point2.swing_type) ? InpColorBullish : InpColorBearish);
                ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Array B structure                                          |
//+------------------------------------------------------------------+
void DrawArrayBStructure()
{
    CArrayList<SEntryArray> entry_arrays;
    g_EntryDetector.GetActiveArrays(entry_arrays);
    
    for(int a = 0; a < entry_arrays.Total(); a++)
    {
        SEntryArray array_b = entry_arrays.At(a);
        
        // Draw range boundaries
        string range_name = g_IndicatorName + "_Range_B_" + IntegerToString(a);
        if(ObjectCreate(0, range_name, OBJ_RECTANGLE, 0, 
                       array_b.created_time, array_b.range_low,
                       TimeCurrent(), array_b.range_high))
        {
            ObjectSetInteger(0, range_name, OBJPROP_COLOR, InpColorRange);
            ObjectSetInteger(0, range_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, range_name, OBJPROP_FILL, false);
            ObjectSetInteger(0, range_name, OBJPROP_BACK, true);
        }
        
        // Draw Array B swing points
        for(int i = 0; i < array_b.swing_points.Total() - 1; i++)
        {
            SSwingPoint point1 = array_b.swing_points.At(i);
            SSwingPoint point2 = array_b.swing_points.At(i + 1);
            
            string line_name = g_IndicatorName + "_Line_B_" + IntegerToString(a) + "_" + IntegerToString(i);
            double price1 = (point1.swing_type == SWING_H || point1.swing_type == SWING_HH || point1.swing_type == SWING_LH) ? 
                            point1.price_high : point1.price_low;
            double price2 = (point2.swing_type == SWING_H || point2.swing_type == SWING_HH || point2.swing_type == SWING_LH) ? 
                            point2.price_high : point2.price_low;
            
            if(ObjectCreate(0, line_name, OBJ_TREND, 0, point1.time, price1, point2.time, price2))
            {
                ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrYellow);
                ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw range boundaries                                           |
//+------------------------------------------------------------------+
void DrawRangeBoundaries()
{
    SRange current_range;
    if(g_ArrayManager.GetCurrentRange(current_range))
    {
        // Draw current range
        string range_name = g_IndicatorName + "_Range_Current";
        datetime start_time = iTime(Symbol(), Period(), iBars(Symbol(), Period()) - 50);
        
        if(ObjectCreate(0, range_name, OBJ_RECTANGLE, 0, 
                       start_time, current_range.range_low,
                       TimeCurrent(), current_range.range_high))
        {
            ObjectSetInteger(0, range_name, OBJPROP_COLOR, InpColorRange);
            ObjectSetInteger(0, range_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, range_name, OBJPROP_FILL, false);
            ObjectSetInteger(0, range_name, OBJPROP_BACK, true);
            ObjectSetInteger(0, range_name, OBJPROP_WIDTH, 2);
        }
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+
bool IsBullishSwing(ENUM_SWING_TYPE swing_type)
{
    return (swing_type == SWING_HL || swing_type == SWING_HH || swing_type == SWING_H);
}

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
        default:       return "?";
    }
}

//+------------------------------------------------------------------+
//| Cleanup visual objects                                          |
//+------------------------------------------------------------------+
void CleanupVisualObjects()
{
    int total_objects = ObjectsTotal(0);
    
    for(int i = total_objects - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if(StringFind(obj_name, g_IndicatorName) == 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        // Redraw when chart changes
        UpdateVisualDisplay();
    }
}
