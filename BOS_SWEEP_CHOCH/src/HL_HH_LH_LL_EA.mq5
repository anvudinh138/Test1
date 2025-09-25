//+------------------------------------------------------------------+
//|                                              HL_HH_LH_LL_EA.mq5 |
//|                          Copyright 2024, Market Structure Expert |
//|                       Multi-Level Entry Detection Trading EA     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Market Structure Expert"
#property link      "https://github.com/market-structure"
#property version   "2.00"
#property description "Expert Advisor based on Multi-Level Entry Detection System"
#property description "Trades Real ChoCH and Sweep signals from HL-HH-LH-LL analysis"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include "HL_Structures.mqh"
#include "HL_ArrayManager.mqh"
#include "HL_EntryDetection.mqh"
#include "HL_Utilities.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Core Algorithm Settings ==="
input double InpRetestThresholdA = 0.20;      // Array A Retest Threshold (20%)
input double InpRetestThresholdB = 0.15;      // Array B Retest Threshold (15%)
input int    InpMinSwingDistance = 10;        // Minimum Swing Distance (pips)
input bool   InpConfirmOnClose = true;        // Confirm Only on Candle Close

input group "=== Multi-Level System ==="
input int    InpMaxEntryArrays = 3;           // Maximum Concurrent Array B Instances
input double InpRangeBufferPips = 2.0;        // Array B Range Buffer (pips)
input int    InpEntryConfirmBars = 2;         // Entry Confirmation Bars
input int    InpStaleTimeoutBars = 20;        // Stale Array Timeout (bars)

input group "=== Trading Settings ==="
input bool   InpTradeRealChoCH = true;        // Trade Real ChoCH Signals
input bool   InpTradeSweep = true;            // Trade Sweep Signals
input bool   InpTradeBOSContinuation = false; // Trade BOS Continuation (Array A)
input double InpLotSize = 0.01;               // Fixed Lot Size
input bool   InpUseRiskPercent = false;       // Use Risk Percentage
input double InpRiskPercent = 2.0;            // Risk Percentage of Account
input double InpMaxRiskPips = 50.0;           // Maximum Risk in Pips

input group "=== Risk Management ==="
input double InpStopLossMultiplier = 1.0;     // Stop Loss Multiplier
input double InpTakeProfitMultiplier = 2.0;   // Take Profit Multiplier (Risk:Reward)
input bool   InpUseTrailingStop = true;       // Use Trailing Stop
input double InpTrailingStopPips = 20.0;      // Trailing Stop Distance (pips)
input bool   InpBreakevenAfterTP1 = true;     // Move to breakeven after 1:1

input group "=== Filters ==="
input double InpMaxSpreadPips = 5.0;          // Maximum Spread for Entry (pips)
input bool   InpAvoidNews = false;            // Avoid Trading During News
input int    InpNewsAvoidMinutes = 30;        // Minutes to avoid before/after news
input bool   InpTradingHoursOnly = false;     // Trade Only During Main Sessions

input group "=== Money Management ==="
input int    InpMaxPositions = 3;             // Maximum Open Positions
input double InpMaxDailyLoss = 100.0;         // Maximum Daily Loss ($)
input double InpMaxDailyProfit = 300.0;       // Maximum Daily Profit ($)
input bool   InpStopAfterLoss = true;         // Stop Trading After Max Loss

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CArrayManager*      g_ArrayManager;
CEntryDetection*    g_EntryDetector;
CTrade              g_Trade;
CPositionInfo       g_Position;

// Trading state
datetime            g_LastCalculated;
double              g_DailyProfit;
double              g_DailyLoss;
datetime            g_LastDayReset;
bool                g_TradingEnabled;
int                 g_MagicNumber;

// Statistics
int                 g_TotalTrades;
int                 g_WinningTrades;
int                 g_LosingTrades;
double              g_GrossProfit;
double              g_GrossLoss;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Generate unique magic number based on symbol and timeframe
    g_MagicNumber = GenerateMagicNumber();
    g_Trade.SetExpertMagicNumber(g_MagicNumber);
    
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
    g_EntryDetector.SetRangeBuffer(InpRangeBufferPips * Point * 10);
    g_EntryDetector.SetConfirmationBars(InpEntryConfirmBars);
    g_EntryDetector.SetStaleTimeout(InpStaleTimeoutBars);
    g_EntryDetector.SetAutoClearStale(true);
    
    // Initialize trading state
    g_TradingEnabled = true;
    g_DailyProfit = 0.0;
    g_DailyLoss = 0.0;
    g_LastDayReset = TimeCurrent();
    
    // Initialize statistics
    g_TotalTrades = 0;
    g_WinningTrades = 0;
    g_LosingTrades = 0;
    g_GrossProfit = 0.0;
    g_GrossLoss = 0.0;
    
    // Validate inputs
    if(!ValidateInputParameters())
    {
        Print("ERROR: Invalid input parameters");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize utilities
    CAlertUtils::Initialize(30); // 30 seconds between alerts
    CPerformanceMonitor::Initialize();
    
    Print("HL Multi-Level EA v2.0 Initialized Successfully");
    Print("Magic Number: ", g_MagicNumber);
    Print("Trading: Real ChoCH=", InpTradeRealChoCH, " Sweep=", InpTradeSweep);
    Print("Risk Management: Lot Size=", InpLotSize, " Max Risk=", InpMaxRiskPips, " pips");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
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
    
    // Print final statistics
    PrintFinalStatistics();
    
    Print("HL Multi-Level EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Performance monitoring
    int start_time = CPerformanceMonitor::StartTimer();
    
    // Check if new bar
    if(!IsNewBar())
        return;
        
    // Reset daily stats if new day
    CheckAndResetDailyStats();
    
    // Check if trading is enabled
    if(!IsTradingAllowed())
        return;
        
    // Process market structure
    ProcessMarketStructure();
    
    // Manage existing positions
    ManagePositions();
    
    // End performance monitoring
    CPerformanceMonitor::EndTimer(start_time);
}

//+------------------------------------------------------------------+
//| Process market structure analysis                               |
//+------------------------------------------------------------------+
void ProcessMarketStructure()
{
    if(!g_ArrayManager || !g_EntryDetector)
        return;
        
    // Get current bar data
    int current_bar = 1; // Previous closed bar
    double high = iHigh(Symbol(), Period(), current_bar);
    double low = iLow(Symbol(), Period(), current_bar);
    datetime time = iTime(Symbol(), Period(), current_bar);
    
    // Create swing point
    SSwingPoint point;
    point.price_high = high;
    point.price_low = low;
    point.time = time;
    point.bar_index = iBars(Symbol(), Period()) - current_bar - 1;
    
    // Process with Array A
    bool new_swing = g_ArrayManager.ProcessSwingPoint(point);
    
    if(new_swing)
    {
        // Check for ChoCH
        SChoCHEvent choch_event;
        if(g_ArrayManager.DetectChoCH(choch_event))
        {
            // Initialize Array B
            g_EntryDetector.InitializeEntryArray(choch_event);
            
            string message = "ChoCH Detected: " + TrendDirectionToString(choch_event.choch_direction) +
                           " at " + DoubleToString(choch_event.trigger_price, Digits);
            CAlertUtils::SendAlert(message);
        }
    }
    
    // Process Array B for entry signals
    CArrayList<SEntrySignal> entry_signals;
    g_EntryDetector.ProcessEntryDetection(point, entry_signals);
    
    // Handle entry signals
    for(int i = 0; i < entry_signals.Total(); i++)
    {
        SEntrySignal signal = entry_signals.At(i);
        ProcessEntrySignal(signal);
    }
    
    // Clean up stale arrays
    g_EntryDetector.CleanupStaleArrays(point.bar_index);
}

//+------------------------------------------------------------------+
//| Process entry signal for trading                               |
//+------------------------------------------------------------------+
void ProcessEntrySignal(const SEntrySignal &signal)
{
    // Check if we should trade this signal type
    if(!ShouldTradeSignal(signal))
        return;
        
    // Check trading filters
    if(!PassTradingFilters())
        return;
        
    // Check position limits
    if(GetOpenPositionsCount() >= InpMaxPositions)
        return;
        
    // Calculate position size
    double lot_size = CalculatePositionSize(signal);
    if(lot_size <= 0)
        return;
        
    // Place order
    if(signal.direction == TREND_BULLISH)
    {
        PlaceBuyOrder(signal, lot_size);
    }
    else
    {
        PlaceSellOrder(signal, lot_size);
    }
}

//+------------------------------------------------------------------+
//| Place buy order                                                 |
//+------------------------------------------------------------------+
bool PlaceBuyOrder(const SEntrySignal &signal, double lot_size)
{
    double entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double stop_loss = CalculateStopLoss(signal, true);
    double take_profit = CalculateTakeProfit(signal, true);
    
    // Validate levels
    if(!ValidateOrderLevels(entry_price, stop_loss, take_profit, true))
        return false;
        
    string comment = "HL_" + EnumToString(signal.signal_type) + "_BUY";
    
    if(g_Trade.Buy(lot_size, Symbol(), entry_price, stop_loss, take_profit, comment))
    {
        g_TotalTrades++;
        
        string message = "BUY Order Placed: " + GetSignalDescription(signal) +
                        " | Lot: " + DoubleToString(lot_size, 2) +
                        " | Entry: " + DoubleToString(entry_price, Digits) +
                        " | SL: " + DoubleToString(stop_loss, Digits) +
                        " | TP: " + DoubleToString(take_profit, Digits);
                        
        Print(message);
        CAlertUtils::SendAlert(message);
        return true;
    }
    else
    {
        Print("ERROR: Failed to place BUY order. Error: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place sell order                                                |
//+------------------------------------------------------------------+
bool PlaceSellOrder(const SEntrySignal &signal, double lot_size)
{
    double entry_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double stop_loss = CalculateStopLoss(signal, false);
    double take_profit = CalculateTakeProfit(signal, false);
    
    // Validate levels
    if(!ValidateOrderLevels(entry_price, stop_loss, take_profit, false))
        return false;
        
    string comment = "HL_" + EnumToString(signal.signal_type) + "_SELL";
    
    if(g_Trade.Sell(lot_size, Symbol(), entry_price, stop_loss, take_profit, comment))
    {
        g_TotalTrades++;
        
        string message = "SELL Order Placed: " + GetSignalDescription(signal) +
                        " | Lot: " + DoubleToString(lot_size, 2) +
                        " | Entry: " + DoubleToString(entry_price, Digits) +
                        " | SL: " + DoubleToString(stop_loss, Digits) +
                        " | TP: " + DoubleToString(take_profit, Digits);
                        
        Print(message);
        CAlertUtils::SendAlert(message);
        return true;
    }
    else
    {
        Print("ERROR: Failed to place SELL order. Error: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_Position.SelectByIndex(i))
            continue;
            
        if(g_Position.Symbol() != Symbol() || g_Position.Magic() != g_MagicNumber)
            continue;
            
        // Apply trailing stop if enabled
        if(InpUseTrailingStop)
        {
            ApplyTrailingStop(g_Position.Ticket());
        }
        
        // Move to breakeven if enabled
        if(InpBreakevenAfterTP1)
        {
            MoveToBreakeven(g_Position.Ticket());
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
    if(!g_Position.SelectByTicket(ticket))
        return;
        
    double trailing_distance = InpTrailingStopPips * Point * 10;
    double current_price = (g_Position.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                          SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    double new_sl = 0.0;
    bool should_modify = false;
    
    if(g_Position.PositionType() == POSITION_TYPE_BUY)
    {
        new_sl = current_price - trailing_distance;
        should_modify = (new_sl > g_Position.StopLoss() && new_sl < current_price);
    }
    else
    {
        new_sl = current_price + trailing_distance;
        should_modify = (new_sl < g_Position.StopLoss() && new_sl > current_price);
    }
    
    if(should_modify)
    {
        g_Trade.PositionModify(ticket, new_sl, g_Position.TakeProfit());
    }
}

//+------------------------------------------------------------------+
//| Move position to breakeven                                     |
//+------------------------------------------------------------------+
void MoveToBreakeven(ulong ticket)
{
    if(!g_Position.SelectByTicket(ticket))
        return;
        
    double profit_distance = MathAbs(g_Position.PriceOpen() - g_Position.StopLoss());
    double current_profit = 0.0;
    
    if(g_Position.PositionType() == POSITION_TYPE_BUY)
    {
        current_profit = SymbolInfoDouble(Symbol(), SYMBOL_BID) - g_Position.PriceOpen();
    }
    else
    {
        current_profit = g_Position.PriceOpen() - SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    }
    
    // If profit >= risk distance, move SL to breakeven
    if(current_profit >= profit_distance && g_Position.StopLoss() != g_Position.PriceOpen())
    {
        g_Trade.PositionModify(ticket, g_Position.PriceOpen(), g_Position.TakeProfit());
        Print("Position moved to breakeven: ", ticket);
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    datetime current_time = iTime(Symbol(), Period(), 0);
    if(current_time != g_LastCalculated)
    {
        g_LastCalculated = current_time;
        return true;
    }
    return false;
}

bool ShouldTradeSignal(const SEntrySignal &signal)
{
    switch(signal.signal_type)
    {
        case ENTRY_REAL_CHOCH:
            return InpTradeRealChoCH;
        case ENTRY_SWEEP:
            return InpTradeSweep;
        case ENTRY_BOS_CONTINUATION:
            return InpTradeBOSContinuation;
        default:
            return false;
    }
}

bool PassTradingFilters()
{
    // Check spread
    double spread_pips = CPriceUtils::GetSpreadPips();
    if(spread_pips > InpMaxSpreadPips)
    {
        Print("Spread too high: ", spread_pips, " pips");
        return false;
    }
    
    // Check trading hours
    if(InpTradingHoursOnly && !CTimeUtils::IsTradingHours())
    {
        return false;
    }
    
    // Check market open
    if(!CPriceUtils::IsMarketOpen())
    {
        return false;
    }
    
    return true;
}

double CalculatePositionSize(const SEntrySignal &signal)
{
    if(InpUseRiskPercent)
    {
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double risk_amount = account_balance * InpRiskPercent / 100.0;
        double stop_distance = MathAbs(signal.entry_price - signal.stop_loss);
        
        if(stop_distance > 0)
        {
            double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
            double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
            double lot_size = risk_amount / (stop_distance / tick_size * tick_value);
            
            // Normalize lot size
            double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
            double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
            double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
            
            lot_size = MathMax(min_lot, MathMin(max_lot, MathRound(lot_size / lot_step) * lot_step));
            return lot_size;
        }
    }
    
    return InpLotSize;
}

double CalculateStopLoss(const SEntrySignal &signal, bool is_buy)
{
    double base_sl = signal.stop_loss;
    double adjusted_sl = base_sl;
    
    // Apply multiplier
    if(InpStopLossMultiplier != 1.0)
    {
        double entry_price = is_buy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                                     SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double distance = MathAbs(entry_price - base_sl);
        adjusted_sl = is_buy ? (entry_price - distance * InpStopLossMultiplier) : 
                              (entry_price + distance * InpStopLossMultiplier);
    }
    
    // Check maximum risk
    double max_risk_distance = InpMaxRiskPips * Point * 10;
    double entry_price = is_buy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                                 SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    if(is_buy && (entry_price - adjusted_sl) > max_risk_distance)
    {
        adjusted_sl = entry_price - max_risk_distance;
    }
    else if(!is_buy && (adjusted_sl - entry_price) > max_risk_distance)
    {
        adjusted_sl = entry_price + max_risk_distance;
    }
    
    return CPriceUtils::NormalizePrice(adjusted_sl);
}

double CalculateTakeProfit(const SEntrySignal &signal, bool is_buy)
{
    double entry_price = is_buy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                                 SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double stop_loss = CalculateStopLoss(signal, is_buy);
    double risk_distance = MathAbs(entry_price - stop_loss);
    
    double take_profit = is_buy ? (entry_price + risk_distance * InpTakeProfitMultiplier) : 
                                 (entry_price - risk_distance * InpTakeProfitMultiplier);
    
    return CPriceUtils::NormalizePrice(take_profit);
}

bool ValidateOrderLevels(double price, double sl, double tp, bool is_buy)
{
    double min_distance = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * Point;
    
    if(is_buy)
    {
        if(sl > 0 && (price - sl) < min_distance) return false;
        if(tp > 0 && (tp - price) < min_distance) return false;
    }
    else
    {
        if(sl > 0 && (sl - price) < min_distance) return false;
        if(tp > 0 && (price - tp) < min_distance) return false;
    }
    
    return true;
}

int GetOpenPositionsCount()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(g_Position.SelectByIndex(i) && 
           g_Position.Symbol() == Symbol() && 
           g_Position.Magic() == g_MagicNumber)
        {
            count++;
        }
    }
    return count;
}

bool IsTradingAllowed()
{
    // Check if trading is globally enabled
    if(!g_TradingEnabled)
        return false;
        
    // Check daily loss limit
    if(InpStopAfterLoss && g_DailyLoss >= InpMaxDailyLoss)
    {
        g_TradingEnabled = false;
        Print("Trading stopped: Daily loss limit reached");
        return false;
    }
    
    // Check daily profit limit
    if(g_DailyProfit >= InpMaxDailyProfit)
    {
        Print("Daily profit target reached: ", g_DailyProfit);
        return false;
    }
    
    return true;
}

void CheckAndResetDailyStats()
{
    MqlDateTime current_dt;
    TimeToStruct(TimeCurrent(), current_dt);
    
    MqlDateTime last_dt;
    TimeToStruct(g_LastDayReset, last_dt);
    
    if(current_dt.day != last_dt.day)
    {
        // New day - reset stats
        g_DailyProfit = 0.0;
        g_DailyLoss = 0.0;
        g_LastDayReset = TimeCurrent();
        g_TradingEnabled = true;
        
        Print("Daily stats reset for new day");
    }
}

string GetSignalDescription(const SEntrySignal &signal)
{
    string description = "";
    
    switch(signal.signal_type)
    {
        case ENTRY_REAL_CHOCH:
            description = "Real ChoCH";
            break;
        case ENTRY_SWEEP:
            description = "Sweep";
            break;
        case ENTRY_BOS_CONTINUATION:
            description = "BOS Continuation";
            break;
        default:
            description = "Unknown";
    }
    
    description += " " + TrendDirectionToString(signal.direction);
    return description;
}

bool ValidateInputParameters()
{
    return CValidationUtils::ValidateInputs(InpRetestThresholdA, InpMinSwingDistance, 
                                           InpMaxEntryArrays, InpRangeBufferPips) &&
           CValidationUtils::ValidateSymbol() &&
           CValidationUtils::CheckMinimumBars(100);
}

int GenerateMagicNumber()
{
    string symbol = Symbol();
    int period = Period();
    int magic = 0;
    
    // Create unique magic number based on symbol and timeframe
    for(int i = 0; i < StringLen(symbol); i++)
    {
        magic += StringGetCharacter(symbol, i);
    }
    
    magic = magic * 1000 + period;
    return magic % 2147483647; // Keep within int range
}

void PrintFinalStatistics()
{
    Print("=== FINAL STATISTICS ===");
    Print("Total Trades: ", g_TotalTrades);
    Print("Winning Trades: ", g_WinningTrades);
    Print("Losing Trades: ", g_LosingTrades);
    
    if(g_TotalTrades > 0)
    {
        double win_rate = (double)g_WinningTrades / g_TotalTrades * 100.0;
        Print("Win Rate: ", DoubleToString(win_rate, 2), "%");
    }
    
    Print("Gross Profit: $", DoubleToString(g_GrossProfit, 2));
    Print("Gross Loss: $", DoubleToString(g_GrossLoss, 2));
    Print("Net Profit: $", DoubleToString(g_GrossProfit - g_GrossLoss, 2));
    
    if(g_ArrayManager)
    {
        Print("Array A Stats - Swings: ", g_ArrayManager.GetTotalSwings(),
              " BOS: ", g_ArrayManager.GetBOSCount(),
              " ChoCH: ", g_ArrayManager.GetChoCHCount());
    }
    
    if(g_EntryDetector)
    {
        Print("Array B Stats - Arrays Created: ", g_EntryDetector.GetTotalArraysCreated(),
              " Real ChoCH Signals: ", g_EntryDetector.GetRealChoCHSignals(),
              " Sweep Signals: ", g_EntryDetector.GetSweepSignals());
    }
    
    CPerformanceMonitor::ReportPerformance();
}

//+------------------------------------------------------------------+
//| Trade event handler                                             |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Update statistics when trades are closed
    UpdateTradeStatistics();
}

void UpdateTradeStatistics()
{
    // This would be called to update daily P&L and trade statistics
    // Implementation depends on specific requirements
}
