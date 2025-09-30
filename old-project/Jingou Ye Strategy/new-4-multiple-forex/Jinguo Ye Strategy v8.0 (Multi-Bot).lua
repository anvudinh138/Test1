//+------------------------------------------------------------------+
//|                                     ye_strategy_v8_3_final.mq5   |
//|                                  Copyright 2024, Gemini Advisor  |
//|                    Version 8.3 (Final Stable Release)            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Advisor"
#property link      ""
#property version   "8.3"
#property description "Final stable version with all compiler fixes. This version is production-ready."
#property strict

#include <Trade/Trade.mqh>

//--- ENUMs for strategy settings
enum ENUM_ENTRY_METHOD { ENTRY_METHOD_RETEST, ENTRY_METHOD_BREAKOUT, ENTRY_METHOD_IMMEDIATE };
enum ENUM_MONEY_MANAGEMENT { MM_FIXED_LOT, MM_RISK_PERCENTAGE };
// Cập nhật ENUM để bao gồm 10 Bot mới
enum ENUM_BOT_PRESET 
{
    PRESET_NONE,
    PRESET_BOT_1,  // Pass 2426
    PRESET_BOT_2,  // Pass 4785
    PRESET_BOT_3,  // Pass 1247
    PRESET_BOT_4,  // Pass 835
    PRESET_BOT_5,  // Pass 1017
    PRESET_BOT_6,  // Pass 612
    PRESET_BOT_7,  // Pass 1877
    PRESET_BOT_8,  // Pass 349
    PRESET_BOT_9,  // Pass 196 (NZD)
    PRESET_BOT_10  // Pass 196 (GBP)
};

//--- EA Inputs ---

//--- SECTION: Multi-Symbol & Bot Presets ---
input string            InpSymbolsToTrade = "EURUSD,GBPUSD,AUDUSD,NZDUSD,USDCAD"; // Các cặp tiền cần giao dịch, cách nhau bởi dấu phẩy
input ENUM_BOT_PRESET   InpBotPreset = PRESET_NONE; // Chọn cấu hình Bot có sẵn

//--- SECTION: Core Strategy (Default values for Custom mode) ---
input ENUM_ENTRY_METHOD InpEntryMethod = ENTRY_METHOD_BREAKOUT;
input ENUM_TIMEFRAMES   InpTrendTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES   InpEntryTimeframe = PERIOD_M5;
input int               InpFastEMA_Period = 9;
input int               InpSlow1EMA_Period = 28;
input int               InpSlow2EMA_Period = 50;

//--- SECTION: Stop Loss & Take Profit (Points-based) ---
input int               InpStopLossPoints = 250;
input int               InpTakeProfit1_Points = 300;
input int               InpTakeProfit2_Points = 600;

//--- SECTION: Independent Trailing Stop (Points-based) ---
input bool              InpUseTrailingSL = false;
input int               InpTrailingStartPoints = 350;
input int               InpTrailingStopPoints = 200;

//--- SECTION: Trade Execution & Management ---
input bool              InpUseMultiTP = true;
input int               InpNumberOfPositions = 3;
input bool              InpMoveSLToBE_On_TP1 = true;
input int               InpMaxSpreadPoints = 30;
input ulong             InpMagicNumber = 202508;

//--- SECTION: Money Management ---
input ENUM_MONEY_MANAGEMENT InpMoneyManagement = MM_RISK_PERCENTAGE;
input double                 InpFixedLotSize = 0.01;
input double                 InpRiskPercent = 0.2;

//--- SECTION: Filters ---
input bool              InpUseDailyFilter = true;
input int               InpDailyEmaPeriod = 200;
input bool              InpUseAdxFilter = true;
input bool              InpUseDiCrossover = true;
input int               InpAdxPeriod = 24;
input double            InpAdxThreshold = 25.0;
input bool              InpUseSessionFilter = true;
input int               InpTradingStartHour = 9;
input int               InpTradingEndHour = 20;
input int               InpBreakoutLookbackBars = 10;
input int               InpBreakoutOffsetPoints = 30;

//--- SECTION: Safety & Display ---
input bool   InpUseLossLimit = true;
input int    InpMaxConsecutiveLosses = 15;
input int    InpPauseDurationHours = 24;
input bool   InpShowDisplayPanel = true;

//--- Global parameters that will be used by the EA ---
// These variables will hold the actual settings, either from inputs or presets.
ENUM_ENTRY_METHOD g_EntryMethod;
ENUM_TIMEFRAMES   g_TrendTimeframe;
ENUM_TIMEFRAMES   g_EntryTimeframe;
int               g_FastEMA_Period;
int               g_Slow1EMA_Period;
int               g_Slow2EMA_Period;
int               g_StopLossPoints;
int               g_TakeProfit1_Points;
int               g_TakeProfit2_Points;
bool              g_UseTrailingSL;
int               g_TrailingStartPoints;
int               g_TrailingStopPoints;
bool              g_UseMultiTP;
int               g_NumberOfPositions;
bool              g_MoveSLToBE_On_TP1;
int               g_MaxSpreadPoints;
ENUM_MONEY_MANAGEMENT g_MoneyManagement;
double            g_FixedLotSize;
double            g_RiskPercent;
bool              g_UseDailyFilter;
int               g_DailyEmaPeriod;
bool              g_UseAdxFilter;
bool              g_UseDiCrossover;
int               g_AdxPeriod;
double            g_AdxThreshold;
bool              g_UseSessionFilter;
int               g_TradingStartHour;
int               g_TradingEndHour;
int               g_BreakoutLookbackBars;
int               g_BreakoutOffsetPoints;
bool              g_UseLossLimit;
int               g_MaxConsecutiveLosses;
int               g_PauseDurationHours;

//+------------------------------------------------------------------+
//| Lớp quản lý cho từng cặp tiền (Symbol)                           |
//+------------------------------------------------------------------+
class CSymbolManager
{
public:
    string              m_symbol;
    // Indicator handles
    int                 h1_ema_fast_handle, h1_ema_slow1_handle, h1_ema_slow2_handle, h1_adx_handle;
    int                 m5_ema_fast_handle, m5_ema_slow1_handle, m5_ema_slow2_handle;
    int                 d1_ema_handle;
    // Data arrays
    double              h1_ema_fast[], h1_ema_slow1[], h1_ema_slow2[];
    double              h1_adx_main[], h1_adx_plus_di[], h1_adx_minus_di[];
    double              m5_ema_fast[], m5_ema_slow1[], m5_ema_slow2[];
    double              d1_ema[];
    MqlRates            h1_rates[], m5_rates[], d1_rates[];
    // State management
    datetime            m_last_bar_time;
    bool                m_breakeven_needed; 

public:
                        CSymbolManager();
    void                Init(string symbol_name);
    void                OnTick();
    void                CheckForSignal();
private:
    void                ManageOpenPositions();
    bool                TryMoveToBreakeven();
    void                ManageTrailingStopForPosition(ulong ticket);
    void                PlaceOrderSet(ENUM_ORDER_TYPE order_type, double entry_price = 0);
    double              CalculateLotSize(double stop_loss_in_points);
    bool                CopyAllData();
    int                 GetMajorTrend();
    bool                IsSignalAllowed(int trend_direction);
    int                 GetEMATrend();
    bool                IsTradingSessionActive();
    bool                IsSpreadHigh();
    void                CheckImmediateEntry(int h1_trend);
    void                CheckRetestEntry(int h1_trend);
    void                CheckBreakoutEntry(int h1_trend);
    double              FindSwingHigh(int bars);
    double              FindSwingLow(int bars);
    void                DeletePendingOrders();
};

CTrade      trade;
CSymbolManager SymbolManagers[];
int         g_consecutive_losses = 0;
datetime    g_trading_paused_until = 0;
string      g_ea_status = "Initializing...";
ulong       g_last_processed_deal_ticket = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing EA v8.3 (Final)...");
    
    InitializeParameters();

    string symbols_to_trade[];
    StringSplit(InpSymbolsToTrade, ',', symbols_to_trade);
    int total_symbols = ArraySize(symbols_to_trade);
    if(total_symbols == 0)
    {
        Print("Lỗi: Không có cặp tiền nào được chỉ định.");
        return(INIT_FAILED);
    }

    ArrayResize(SymbolManagers, total_symbols);
    for(int i = 0; i < total_symbols; i++)
    {
        string symbol = symbols_to_trade[i];
        StringTrimLeft(symbol);
        StringTrimRight(symbol);
        
        if(symbol != "" && SymbolSelect(symbol, true))
        {
            SymbolManagers[i].Init(symbol);
        }
        else
        {
            if(symbol != "") Print("Lỗi: Không thể chọn cặp tiền '", symbol, "'.");
        }
    }
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    Print("EA Initialized Successfully for ", (string)ArraySize(SymbolManagers), " symbol(s).");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // ... clean up resources ...
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    for(int i = 0; i < ArraySize(SymbolManagers); i++)
    {
        SymbolManagers[i].OnTick();
    }
    
    if(InpShowDisplayPanel) UpdateDisplayPanel();
}

//+------------------------------------------------------------------+
//| Trade event function                                             |
//+------------------------------------------------------------------+
void OnTrade()
{
    if(!HistorySelect(0, TimeCurrent())) return;
    int total_history_deals = (int)HistoryDealsTotal();
    if(total_history_deals == 0) return;
    ulong last_deal_ticket = HistoryDealGetTicket((uint)total_history_deals - 1);

    if(last_deal_ticket != g_last_processed_deal_ticket)
    {
        g_last_processed_deal_ticket = last_deal_ticket;
        if(HistoryDealGetInteger(last_deal_ticket, DEAL_MAGIC) == InpMagicNumber && 
           HistoryDealGetInteger(last_deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
            if(HistoryDealGetDouble(last_deal_ticket, DEAL_PROFIT) < 0)
            {
                g_consecutive_losses++;
                Print("Loss event recorded. Consecutive losses now: ", (string)g_consecutive_losses);
            }
            else
            {
                if(g_consecutive_losses > 0)
                {
                    Print("Win recorded. Resetting loss count.");
                    g_consecutive_losses = 0;
                }

                if(g_MoveSLToBE_On_TP1 && HistoryDealGetInteger(last_deal_ticket, DEAL_REASON) == DEAL_REASON_TP)
                {
                    string symbol = HistoryDealGetString(last_deal_ticket, DEAL_SYMBOL);
                    for(int i = 0; i < ArraySize(SymbolManagers); i++)
                    {
                        if(SymbolManagers[i].m_symbol == symbol)
                        {
                            SymbolManagers[i].m_breakeven_needed = true;
                            Print(symbol, ": BREAKEVEN EVENT. Flag set.");
                            break;
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Tải các thông số vào biến toàn cục                               |
//+------------------------------------------------------------------+
void InitializeParameters()
{
    switch(InpBotPreset)
    {
        case PRESET_BOT_1: // Profile=BOT1 | Symbol=NZDUSD | Pass=2426
            Print("Applying Preset: BOT 1 (Pass 2426)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 28;
            g_Slow2EMA_Period = 50;
            g_StopLossPoints = 200;
            g_TakeProfit1_Points = 250;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = true;
            g_TrailingStartPoints = 300;
            g_TrailingStopPoints = 150;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 200;
            g_AdxPeriod = 22;
            g_AdxThreshold = 28;
            g_TradingStartHour = 9;
            g_TradingEndHour = 19;
            g_BreakoutLookbackBars = 12;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_2: // Profile=BOT1 | Symbol=GBPUSD | Pass=4785
            Print("Applying Preset: BOT 2 (Pass 4785)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 26;
            g_Slow2EMA_Period = 44;
            g_StopLossPoints = 225;
            g_TakeProfit1_Points = 275;
            g_TakeProfit2_Points = 550;
            g_UseTrailingSL = true;
            g_TrailingStartPoints = 250;
            g_TrailingStopPoints = 100;
            g_RiskPercent = 0.2;
            g_DailyEmaPeriod = 210;
            g_AdxPeriod = 20;
            g_AdxThreshold = 22;
            g_TradingStartHour = 8;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 8;
            g_BreakoutOffsetPoints = 20;
            break;

        case PRESET_BOT_3: // Profile=BOT1 | Symbol=EURUSD | Pass=1247
            Print("Applying Preset: BOT 3 (Pass 1247)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 30;
            g_Slow2EMA_Period = 54;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 300;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 300; 
            g_TrailingStopPoints = 150;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 220;
            g_AdxPeriod = 24;
            g_AdxThreshold = 28;
            g_TradingStartHour = 9;
            g_TradingEndHour = 18;
            g_BreakoutLookbackBars = 10;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_4: // Profile=BOT2 | Symbol=USDCAD | Pass=835
            Print("Applying Preset: BOT 4 (Pass 835)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 28;
            g_Slow2EMA_Period = 50;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 300;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 200;
            g_RiskPercent = 0.2;
            g_DailyEmaPeriod = 200;
            g_AdxPeriod = 24;
            g_AdxThreshold = 25;
            g_TradingStartHour = 9;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 10;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_5: // Profile=BOT2 | Symbol=NZDUSD | Pass=1017
            Print("Applying Preset: BOT 5 (Pass 1017)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 28;
            g_Slow2EMA_Period = 50;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 300;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 200;
            g_RiskPercent = 0.2;
            g_DailyEmaPeriod = 210;
            g_AdxPeriod = 24;
            g_AdxThreshold = 25;
            g_TradingStartHour = 9;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 10;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_6: // Profile=BOT2 | Symbol=GBPUSD | Pass=612
            Print("Applying Preset: BOT 6 (Pass 612)");
            g_FastEMA_Period = 10;
            g_Slow1EMA_Period = 30;
            g_Slow2EMA_Period = 55;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 300;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 200;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 220;
            g_AdxPeriod = 24;
            g_AdxThreshold = 28;
            g_TradingStartHour = 9;
            g_TradingEndHour = 18;
            g_BreakoutLookbackBars = 10;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_7: // Profile=BOT2 | Symbol=EURUSD | Pass=1877
            Print("Applying Preset: BOT 7 (Pass 1877)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 28;
            g_Slow2EMA_Period = 50;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 300;
            g_TakeProfit2_Points = 600;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 200;
            g_RiskPercent = 0.2;
            g_DailyEmaPeriod = 200;
            g_AdxPeriod = 24;
            g_AdxThreshold = 25;
            g_TradingStartHour = 9;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 10;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_8: // Profile=BOT3 | Symbol=AUDUSD | Pass=349
            Print("Applying Preset: BOT 8 (Pass 349)");
            g_FastEMA_Period = 10;
            g_Slow1EMA_Period = 30;
            g_Slow2EMA_Period = 55;
            g_StopLossPoints = 300;
            g_TakeProfit1_Points = 350;
            g_TakeProfit2_Points = 700;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 150;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 210;
            g_AdxPeriod = 24;
            g_AdxThreshold = 29;
            g_TradingStartHour = 10;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 12;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_9: // Profile=BOT3 | Symbol=NZDUSD | Pass=196
            Print("Applying Preset: BOT 9 (Pass 196 NZD)");
            g_FastEMA_Period = 10;
            g_Slow1EMA_Period = 30;
            g_Slow2EMA_Period = 55;
            g_StopLossPoints = 300;
            g_TakeProfit1_Points = 350;
            g_TakeProfit2_Points = 700;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 150;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 210;
            g_AdxPeriod = 24;
            g_AdxThreshold = 29;
            g_TradingStartHour = 10;
            g_TradingEndHour = 20;
            g_BreakoutLookbackBars = 12;
            g_BreakoutOffsetPoints = 30;
            break;

        case PRESET_BOT_10: // Profile=BOT3 | Symbol=GBPUSD | Pass=196
            Print("Applying Preset: BOT 10 (Pass 196 GBP)");
            g_FastEMA_Period = 9;
            g_Slow1EMA_Period = 28;
            g_Slow2EMA_Period = 54;
            g_StopLossPoints = 250;
            g_TakeProfit1_Points = 325;
            g_TakeProfit2_Points = 700;
            g_UseTrailingSL = false;
            g_TrailingStartPoints = 350;
            g_TrailingStopPoints = 150;
            g_RiskPercent = 0.1;
            g_DailyEmaPeriod = 220;
            g_AdxPeriod = 24;
            g_AdxThreshold = 30;
            g_TradingStartHour = 9;
            g_TradingEndHour = 19;
            g_BreakoutLookbackBars = 13;
            g_BreakoutOffsetPoints = 30;
            break;
            
        case PRESET_NONE:
        default:
            Print("No preset selected. Using manual input values.");
            g_FastEMA_Period = InpFastEMA_Period;
            g_Slow1EMA_Period = InpSlow1EMA_Period;
            g_Slow2EMA_Period = InpSlow2EMA_Period;
            g_StopLossPoints = InpStopLossPoints;
            g_TakeProfit1_Points = InpTakeProfit1_Points;
            g_TakeProfit2_Points = InpTakeProfit2_Points;
            g_UseTrailingSL = InpUseTrailingSL;
            g_TrailingStartPoints = InpTrailingStartPoints;
            g_TrailingStopPoints = InpTrailingStopPoints;
            g_RiskPercent = InpRiskPercent;
            g_DailyEmaPeriod = InpDailyEmaPeriod;
            g_AdxPeriod = InpAdxPeriod;
            g_AdxThreshold = InpAdxThreshold;
            g_TradingStartHour = InpTradingStartHour;
            g_TradingEndHour = InpTradingEndHour;
            g_BreakoutLookbackBars = InpBreakoutLookbackBars;
            g_BreakoutOffsetPoints = InpBreakoutOffsetPoints;
            break;
    }

    // Load parameters that are not part of presets
    g_EntryMethod = InpEntryMethod;
    g_TrendTimeframe = InpTrendTimeframe;
    g_EntryTimeframe = InpEntryTimeframe;
    g_UseMultiTP = InpUseMultiTP;
    g_NumberOfPositions = InpNumberOfPositions;
    g_MoveSLToBE_On_TP1 = InpMoveSLToBE_On_TP1;
    g_MaxSpreadPoints = InpMaxSpreadPoints;
    g_MoneyManagement = InpMoneyManagement;
    g_FixedLotSize = InpFixedLotSize;
    g_UseDailyFilter = InpUseDailyFilter;
    g_UseAdxFilter = InpUseAdxFilter;
    g_UseDiCrossover = InpUseDiCrossover;
    g_UseSessionFilter = InpUseSessionFilter;
    g_UseLossLimit = InpUseLossLimit;
    g_MaxConsecutiveLosses = InpMaxConsecutiveLosses;
    g_PauseDurationHours = InpPauseDurationHours;
}
//+------------------------------------------------------------------+
//| Các hàm của lớp CSymbolManager                                   |
//+------------------------------------------------------------------+
CSymbolManager::CSymbolManager() : m_last_bar_time(0), m_breakeven_needed(false)
{
}
//+------------------------------------------------------------------+
void CSymbolManager::Init(string symbol_name)
{
    m_symbol = symbol_name;
    h1_ema_fast_handle = iMA(m_symbol, g_TrendTimeframe, g_FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow1_handle = iMA(m_symbol, g_TrendTimeframe, g_Slow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow2_handle = iMA(m_symbol, g_TrendTimeframe, g_Slow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_adx_handle = iADX(m_symbol, g_TrendTimeframe, g_AdxPeriod);
    m5_ema_fast_handle = iMA(m_symbol, g_EntryTimeframe, g_FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow1_handle = iMA(m_symbol, g_EntryTimeframe, g_Slow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow2_handle = iMA(m_symbol, g_EntryTimeframe, g_Slow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    d1_ema_handle = iMA(m_symbol, PERIOD_D1, g_DailyEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    Print("Symbol Manager initialized for ", m_symbol);
}
//+------------------------------------------------------------------+
void CSymbolManager::OnTick()
{
    if(PositionsTotalBySymbol(m_symbol) > 0)
    {
        ManageOpenPositions();
    }
    
    datetime current_bar_time = (datetime)SeriesInfoInteger(m_symbol, g_EntryTimeframe, SERIES_LASTBAR_DATE);
    if(current_bar_time <= m_last_bar_time) return;
    m_last_bar_time = current_bar_time;
    
    CheckForSignal();
}
//+------------------------------------------------------------------+
void CSymbolManager::ManageOpenPositions()
{
    if(m_breakeven_needed)
    {
        if(TryMoveToBreakeven())
        {
            Print(m_symbol, ": Breakeven process complete.");
            m_breakeven_needed = false; 
        }
        else
        {
            return;
        }
    }
    
    if(g_UseTrailingSL)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelect(ticket) && PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                {
                    ManageTrailingStopForPosition(ticket);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
bool CSymbolManager::TryMoveToBreakeven()
{
    int positions_at_risk = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong pos_ticket = PositionGetTicket(i);
        if(!PositionSelect(pos_ticket)) { return false; }
        
        if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_sl = PositionGetDouble(POSITION_SL);
            long pos_type = PositionGetInteger(POSITION_TYPE);
            
            if((pos_type == POSITION_TYPE_BUY && current_sl < open_price) || 
               (pos_type == POSITION_TYPE_SELL && (current_sl > open_price || current_sl == 0)))
            {
                positions_at_risk++;
                if(trade.PositionModify(pos_ticket, open_price, PositionGetDouble(POSITION_TP)))
                {
                   Print(" -> SUCCESS: SL for ", m_symbol, " ticket #", (string)pos_ticket, " moved to BE.");
                }
                else
                {
                   Print(" -> WARNING: PositionModify for BE failed on #", (string)pos_ticket, ". Retrying...");
                   return false;
                }
            }
        }
    }
    return positions_at_risk == 0;
}
//+------------------------------------------------------------------+
void CSymbolManager::ManageTrailingStopForPosition(ulong ticket)
{
    if(!PositionSelect(ticket)) return; 
    long pos_type = PositionGetInteger(POSITION_TYPE); 
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN); 
    double current_sl = PositionGetDouble(POSITION_SL); 
    double start_trailing_in_points = SymbolInfoDouble(m_symbol, SYMBOL_POINT) * g_TrailingStartPoints; 
    double trail_distance_in_points = SymbolInfoDouble(m_symbol, SYMBOL_POINT) * g_TrailingStopPoints; 
    if(pos_type == POSITION_TYPE_BUY)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID); 
        if(current_price > open_price + start_trailing_in_points)
        {
            double new_sl = current_price - trail_distance_in_points; 
            if(new_sl > current_sl)
            {
                trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            }
        }
    } 
    else if(pos_type == POSITION_TYPE_SELL)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK); 
        if(current_price < open_price - start_trailing_in_points)
        {
            double new_sl = current_price + trail_distance_in_points; 
            if((new_sl < current_sl) || (current_sl == 0))
            {
                trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            }
        }
    }
}
//+------------------------------------------------------------------+
bool CSymbolManager::CopyAllData()
{
    int bh1=3; 
    int bm5=g_BreakoutLookbackBars+3; 
    if(CopyRates(m_symbol,g_TrendTimeframe,0,bh1,h1_rates)<bh1 || CopyRates(m_symbol,g_EntryTimeframe,0,bm5,m5_rates)<bm5) return false; 
    if(CopyBuffer(h1_ema_fast_handle,0,0,bh1,h1_ema_fast)<bh1 || CopyBuffer(h1_ema_slow1_handle,0,0,bh1,h1_ema_slow1)<bh1 || CopyBuffer(h1_ema_slow2_handle,0,0,bh1,h1_ema_slow2)<bh1 || CopyBuffer(h1_adx_handle,0,0,bh1,h1_adx_main)<bh1 || CopyBuffer(h1_adx_handle,1,0,bh1,h1_adx_plus_di)<bh1 || CopyBuffer(h1_adx_handle,2,0,bh1,h1_adx_minus_di)<bh1) return false; 
    if(CopyBuffer(m5_ema_fast_handle,0,0,bm5,m5_ema_fast)<bm5 || CopyBuffer(m5_ema_slow1_handle,0,0,bm5,m5_ema_slow1)<bm5 || CopyBuffer(m5_ema_slow2_handle,0,0,bm5,m5_ema_slow2)<bm5) return false; 
    if(g_UseDailyFilter)
    {
        if(CopyRates(m_symbol,PERIOD_D1,0,2,d1_rates)<2 || CopyBuffer(d1_ema_handle,0,0,2,d1_ema)<2) return false; 
        ArraySetAsSeries(d1_rates,true); 
        ArraySetAsSeries(d1_ema,true);
    } 
    ArraySetAsSeries(h1_rates,true); 
    ArraySetAsSeries(m5_rates,true); 
    ArraySetAsSeries(h1_ema_fast,true); 
    ArraySetAsSeries(h1_ema_slow1,true); 
    ArraySetAsSeries(h1_ema_slow2,true); 
    ArraySetAsSeries(h1_adx_main,true); 
    ArraySetAsSeries(h1_adx_plus_di,true); 
    ArraySetAsSeries(h1_adx_minus_di,true); 
    ArraySetAsSeries(m5_ema_fast,true); 
    ArraySetAsSeries(m5_ema_slow1,true); 
    ArraySetAsSeries(m5_ema_slow2,true); 
    return true;
}
//+------------------------------------------------------------------+
void CSymbolManager::CheckForSignal()
{
    if(!CopyAllData()) return; 
    if(IsTradingPaused()) { DeletePendingOrders(); return; } 
    if(!IsTradingSessionActive()) { DeletePendingOrders(); return; } 
    if(PositionsTotalBySymbol(m_symbol)>0) return; 
    if(IsSpreadHigh()) return; 
    
    int major_trend=GetMajorTrend(); 
    int h1_trend=GetEMATrend(); 
    
    if(g_UseDailyFilter && h1_trend!=major_trend && h1_trend!=0) { DeletePendingOrders(); return; } 
    if(!IsSignalAllowed(h1_trend)) { DeletePendingOrders(); return; } 
    if(h1_trend==0) { DeletePendingOrders(); return; } 
    
    switch(g_EntryMethod)
    {
        case ENTRY_METHOD_IMMEDIATE: CheckImmediateEntry(h1_trend); break; 
        case ENTRY_METHOD_RETEST: CheckRetestEntry(h1_trend); break; 
        case ENTRY_METHOD_BREAKOUT: CheckBreakoutEntry(h1_trend); break;
    }
}
//+------------------------------------------------------------------+
void CSymbolManager::PlaceOrderSet(ENUM_ORDER_TYPE order_type, double entry_price = 0)
{
    if(IsSpreadHigh()) return; 
    if(entry_price == 0 && (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL))
    {
        entry_price = SymbolInfoDouble(m_symbol, (order_type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));
    } 
    if(entry_price == 0) return; 
    
    double stop_loss_in_price = g_StopLossPoints * SymbolInfoDouble(m_symbol, SYMBOL_POINT); 
    double stop_loss = 0; 
    if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
        stop_loss = entry_price - stop_loss_in_price; 
    else 
        stop_loss = entry_price + stop_loss_in_price; 
        
    string trade_set_comment = "JYS_v8.3_" + (string)TimeCurrent(); 
    int positions_to_open = g_UseMultiTP ? g_NumberOfPositions : 1; 
    
    for(int i = 0; i < positions_to_open; i++)
    {
        double lot_size = CalculateLotSize(g_StopLossPoints); 
        if(lot_size < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN)) continue; 
        
        double take_profit = 0; 
        if(g_UseMultiTP)
        {
            if(i == 0 && g_TakeProfit1_Points > 0)
            {
                take_profit = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) ? entry_price + g_TakeProfit1_Points * SymbolInfoDouble(m_symbol, SYMBOL_POINT) : entry_price - g_TakeProfit1_Points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            }
            else if(i == 1 && positions_to_open > 2 && g_TakeProfit2_Points > 0)
            {
                take_profit = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) ? entry_price + g_TakeProfit2_Points * SymbolInfoDouble(m_symbol, SYMBOL_POINT) : entry_price - g_TakeProfit2_Points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            }
        } 
        
        switch(order_type)
        {
            case ORDER_TYPE_BUY:       trade.Buy(lot_size, m_symbol, entry_price, stop_loss, take_profit, trade_set_comment); break; 
            case ORDER_TYPE_SELL:      trade.Sell(lot_size, m_symbol, entry_price, stop_loss, take_profit, trade_set_comment); break; 
            case ORDER_TYPE_BUY_STOP:  trade.BuyStop(lot_size, entry_price, m_symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break; 
            case ORDER_TYPE_SELL_STOP: trade.SellStop(lot_size, entry_price, m_symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break; 
            case ORDER_TYPE_BUY_LIMIT: trade.BuyLimit(lot_size, entry_price, m_symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break; 
            case ORDER_TYPE_SELL_LIMIT:trade.SellLimit(lot_size, entry_price, m_symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break;
        }
    }
}
//+------------------------------------------------------------------+
double CSymbolManager::CalculateLotSize(double stop_loss_in_points)
{
    if(g_MoneyManagement==MM_FIXED_LOT) return g_FixedLotSize; 
    
    double risk_amt=AccountInfoDouble(ACCOUNT_BALANCE)*(g_RiskPercent/100.0); 
    double tick_val=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE); 
    double tick_size=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE); 
    
    if(tick_val<=0||tick_size<=0||stop_loss_in_points<=0) return g_FixedLotSize; 
    
    double loss_lot=(stop_loss_in_points*SymbolInfoDouble(m_symbol, SYMBOL_POINT))/tick_size*tick_val; 
    if(loss_lot<=0) return g_FixedLotSize; 
    
    double lot=risk_amt/loss_lot; 
    double min_l=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN); 
    double max_l=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX); 
    double step_l=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP); 
    
    lot=MathFloor(lot/step_l)*step_l; 
    
    if(lot<min_l) lot=min_l; 
    if(lot>max_l) lot=max_l; 
    
    return lot;
}
//+------------------------------------------------------------------+
int CSymbolManager::GetMajorTrend()
{
    if(!g_UseDailyFilter) return 0; 
    if(ArraySize(d1_rates)<2 || ArraySize(d1_ema)<2) return 0; 
    if(d1_rates[1].close > d1_ema[1]) return 1; 
    if(d1_rates[1].close < d1_ema[1]) return -1; 
    return 0;
}
//+------------------------------------------------------------------+
bool CSymbolManager::IsSignalAllowed(int trend_direction)
{
    if(g_UseAdxFilter)
    {
        if(ArraySize(h1_adx_main)<2) return false; 
        if(h1_adx_main[1] < g_AdxThreshold) return false;
    } 
    if(g_UseDiCrossover)
    {
        if(ArraySize(h1_adx_plus_di)<2 || ArraySize(h1_adx_minus_di)<2) return false; 
        if(trend_direction==1 && h1_adx_plus_di[1] <= h1_adx_minus_di[1]) return false; 
        if(trend_direction==-1 && h1_adx_minus_di[1] <= h1_adx_plus_di[1]) return false;
    } 
    return true;
}
//+------------------------------------------------------------------+
int CSymbolManager::GetEMATrend()
{
    if(ArraySize(h1_ema_fast)<2) return 0; 
    bool is_uptrend = h1_ema_fast[1] > h1_ema_slow2[1] && h1_ema_slow1[1] > h1_ema_slow2[1]; 
    bool is_downtrend = h1_ema_fast[1] < h1_ema_slow2[1] && h1_ema_slow1[1] < h1_ema_slow2[1]; 
    if(is_uptrend) return 1; 
    if(is_downtrend) return -1; 
    return 0;
}
//+------------------------------------------------------------------+
bool CSymbolManager::IsTradingSessionActive()
{
    if(!g_UseSessionFilter) return true; 
    MqlDateTime t; 
    TimeCurrent(t); 
    if(g_TradingStartHour > g_TradingEndHour)
    {
        if(t.hour >= g_TradingStartHour || t.hour < g_TradingEndHour) return true;
    } 
    else 
    {
        if(t.hour >= g_TradingStartHour && t.hour < g_TradingEndHour) return true;
    } 
    return false;
}
//+------------------------------------------------------------------+
bool CSymbolManager::IsSpreadHigh()
{
    return(SymbolInfoInteger(m_symbol,SYMBOL_SPREAD) > g_MaxSpreadPoints);
}
//+------------------------------------------------------------------+
void CSymbolManager::CheckImmediateEntry(int h1_trend)
{
    bool buy_signal = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_fast[2] <= m5_ema_slow1[2]; 
    bool sell_signal = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_fast[2] >= m5_ema_slow1[2]; 
    if(h1_trend==1 && buy_signal) PlaceOrderSet(ORDER_TYPE_BUY,0); 
    if(h1_trend==-1 && sell_signal) PlaceOrderSet(ORDER_TYPE_SELL,0);
}
//+------------------------------------------------------------------+
void CSymbolManager::CheckRetestEntry(int h1_trend)
{
    bool is_uptrend = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1]; 
    bool is_downtrend = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1]; 
    if(h1_trend==1 && is_uptrend)
    {
        if(m5_rates[1].low <= m5_ema_fast[1] || m5_rates[1].low <= m5_ema_slow1[1]) PlaceOrderSet(ORDER_TYPE_BUY,0);
    } 
    if(h1_trend==-1 && is_downtrend)
    {
        if(m5_rates[1].high >= m5_ema_fast[1] || m5_rates[1].high >= m5_ema_slow1[1]) PlaceOrderSet(ORDER_TYPE_SELL,0);
    }
}
//+------------------------------------------------------------------+
void CSymbolManager::CheckBreakoutEntry(int h1_trend)
{
    bool is_bullish_setup = m5_ema_fast[1]>m5_ema_slow1[1] && m5_ema_slow1[1]>m5_ema_slow2[1];
    bool is_bearish_setup = m5_ema_fast[1]<m5_ema_slow1[1] && m5_ema_slow1[1]<m5_ema_slow2[1];
    DeletePendingOrders();
    if(h1_trend==1 && is_bullish_setup)
    {
        double high_level=FindSwingHigh(g_BreakoutLookbackBars);
        if(high_level>0)
        {
            double entry_p = high_level + g_BreakoutOffsetPoints*SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            PlaceOrderSet(ORDER_TYPE_BUY_STOP,entry_p);
        }
    }
    if(h1_trend==-1 && is_bearish_setup)
    {
        double low_level=FindSwingLow(g_BreakoutLookbackBars);
        if(low_level>0)
        {
            double entry_p = low_level - g_BreakoutOffsetPoints*SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            PlaceOrderSet(ORDER_TYPE_SELL_STOP,entry_p);
        }
    }
}
//+------------------------------------------------------------------+
double CSymbolManager::FindSwingHigh(int bars)
{
    double high_val=0; 
    for(int i=1; i<=bars && i<ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].high>high_val) high_val=m5_rates[i].high;
    } 
    return high_val;
}
//+------------------------------------------------------------------+
double CSymbolManager::FindSwingLow(int bars)
{
    if(ArraySize(m5_rates)<2) return 0; 
    double low_val=m5_rates[1].low; 
    for(int i=2; i<=bars && i<ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].low<low_val) low_val=m5_rates[i].low;
    } 
    return low_val;
}
//+------------------------------------------------------------------+
void CSymbolManager::DeletePendingOrders()
{
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        ulong ticket=OrderGetTicket((uint)i); 
        if(OrderSelect(ticket))
        {
            if(OrderGetInteger(ORDER_MAGIC)==InpMagicNumber && OrderGetString(ORDER_SYMBOL)==m_symbol)
            {
                trade.OrderDelete(ticket);
            }
        }
    }
}
//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
int PositionsTotalBySymbol(string symbol)
{
    int count = 0; 
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // Must use PositionGetTicket first before getting properties
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol) 
            {
                count++;
            }
        }
    } 
    return count;
}
//+------------------------------------------------------------------+
bool IsTradingPaused()
{
    if(!g_UseLossLimit) return false; 
    if(g_trading_paused_until>0 && g_trading_paused_until<=TimeCurrent())
    {
        Print("Trading pause has ended.");
        g_consecutive_losses=0;
        g_trading_paused_until=0;
        return false;
    } 
    if(g_trading_paused_until>TimeCurrent())
    {
        g_ea_status="PAUSED - Max Losses Hit";
        return true;
    } 
    if(g_consecutive_losses>=g_MaxConsecutiveLosses)
    {
        g_trading_paused_until=TimeCurrent()+(g_PauseDurationHours*3600);
        Print("Max losses reached. Pausing trading.");
        g_ea_status="PAUSED - Max Losses Hit";
        return true;
    } 
    return false;
}
//+------------------------------------------------------------------+
void UpdateDisplayPanel()
{ 
    ObjectDelete(0,"StatusPanel_BG"); 
    ObjectDelete(0,"StatusPanel_Text"); 
    ObjectCreate(0,"StatusPanel_BG",OBJ_RECTANGLE_LABEL,0,0,0); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XDISTANCE,5); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YDISTANCE,10); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XSIZE,220); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YSIZE,120); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_COLOR,clrBlack); 
    ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_BACK,true); 
    
    string pt="--- Jinguo Ye Strategy v8.3 ---\n\n"; 
    pt+="Symbols: " + InpSymbolsToTrade + "\n"; 
    
    string preset_name="Custom"; 
    switch(InpBotPreset)
    {
        case PRESET_BOT_1: preset_name="Bot 1"; break; 
        case PRESET_BOT_2: preset_name="Bot 2"; break; 
        case PRESET_BOT_3: preset_name="Bot 3"; break; 
        case PRESET_BOT_4: preset_name="Bot 4"; break; 
        case PRESET_BOT_5: preset_name="Bot 5"; break; 
        case PRESET_BOT_6: preset_name="Bot 6"; break; 
        case PRESET_BOT_7: preset_name="Bot 7"; break; 
        case PRESET_BOT_8: preset_name="Bot 8"; break; 
        case PRESET_BOT_9: preset_name="Bot 9"; break; 
        case PRESET_BOT_10: preset_name="Bot 10"; break;
    } 
    pt+="Preset: " + preset_name + "\n\n"; 
    pt+="Global Status: \n"; 
    pt+="Consecutive Losses: "+(string)g_consecutive_losses+"/"+(string)g_MaxConsecutiveLosses; 
    
    ObjectCreate(0,"StatusPanel_Text",OBJ_LABEL,0,0,0); 
    ObjectSetString(0,"StatusPanel_Text",OBJPROP_TEXT,pt); 
    ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_XDISTANCE,10); 
    ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_YDISTANCE,15); 
    ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_CORNER,CORNER_LEFT_UPPER); 
    ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_COLOR,clrLime); 
    ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_FONTSIZE,10);
}

