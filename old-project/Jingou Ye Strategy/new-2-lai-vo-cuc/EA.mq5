//+------------------------------------------------------------------+
//|                                            ye_strategy_v2_7.mq5  |
//|                                  Copyright 2024, Gemini Advisor  |
//|                   Version 2.7 (ADX Sideways Filter)              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Advisor"
#property link      ""
#property version   "2.7"
#property description "Integrates an ADX filter to avoid trading in sideways markets."
#property strict

#include <Trade/Trade.mqh>

//--- ENUM for Entry Methods
enum ENUM_ENTRY_METHOD
{
    ENTRY_METHOD_RETEST,     // Wait for pullback to EMA 8/13
    ENTRY_METHOD_BREAKOUT,   // Place Buy/Sell Stop at swing high/low
    ENTRY_METHOD_IMMEDIATE   // Enter on crossover candle close
};

//--- EA Inputs
//--- Strategy Core Settings ---
input ENUM_ENTRY_METHOD InpEntryMethod = ENTRY_METHOD_BREAKOUT; // Choose your entry method
input ENUM_TIMEFRAMES   InpTrendTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES   InpEntryTimeframe = PERIOD_M5;
input int               InpFastEMA_Period = 8;
input int               InpSlow1EMA_Period = 13;
input int               InpSlow2EMA_Period = 21;

//--- ADX Filter Settings ---
input bool              InpUseAdxFilter = true;           // Enable/Disable the ADX sideways filter
input int               InpAdxPeriod = 14;                // ADX Period
input double            InpAdxThreshold = 25.0;           // Min ADX value to consider a trend

//--- Breakout Settings ---
input int               InpBreakoutLookbackBars = 8;      // How many bars to look back for swing high/low
input int               InpBreakoutOffsetPips = 3;        // How many pips to offset the pending order

//--- Lot & Multi-TP Settings ---
input double            InpLotSize = 0.01;                // Lot size for EACH position in a set.
input bool              InpUseMultiTP = true;             // Enable/Disable the Multi-TP system
input int               InpNumberOfPositions = 3;         // How many positions to open (e.g., 2 or 3)
input double            InpRR_TP1 = 1.0;                  // Risk:Reward Ratio for TP1
input double            InpRR_TP2 = 2.0;                  // Risk:Reward Ratio for TP2 (only used if NumberOfPositions is 3)
input bool              InpMoveSLToBE_On_TP1 = true;      // Automatically move SL to BreakEven when TP1 hits

//--- General Trade Settings ---
input int               InpMaxSpreadPoints = 30;
input ulong             InpMagicNumber = 202407;          // New magic number for new version

//--- SL/TP & Trailing Stop ---
input int               InpAtrPeriod = 14;
input double            InpAtrMultiplierSL = 2.0;
input bool              InpUseTrailingSL = true;
input double            InpTrailingAtrMultiplier = 2.5;


//--- Global variables
CTrade trade;
int h1_ema_fast_handle, h1_ema_slow1_handle, h1_ema_slow2_handle, h1_adx_handle;
int m5_ema_fast_handle, m5_ema_slow1_handle, m5_ema_slow2_handle;
int m5_atr_handle;

double h1_ema_fast[], h1_ema_slow1[], h1_ema_slow2[], h1_adx_buffer[];
double m5_ema_fast[], m5_ema_slow1[], m5_ema_slow2[];
double m5_atr[];
MqlRates h1_rates[], m5_rates[];

//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing EA v2.7 (ADX Sideways Filter)...");
    trade.SetExpertMagicNumber(InpMagicNumber);

    h1_ema_fast_handle = iMA(_Symbol, InpTrendTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow1_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow2_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_adx_handle = iADX(_Symbol, InpTrendTimeframe, InpAdxPeriod);
    
    m5_ema_fast_handle = iMA(_Symbol, InpEntryTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow1_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow2_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_atr_handle = iATR(_Symbol, InpEntryTimeframe, InpAtrPeriod);

    Print("EA Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
// ... (Các hàm OnDeinit, OnTrade, OnTick giữ nguyên như v2.6)
void OnDeinit(const int reason)
{
    Print("Deinitializing EA v2.7. Reason: ", reason);
    if(reason != REASON_CHARTCLOSE)
    {
      DeletePendingOrders();
    }
}

void OnTrade()
{
    if(InpUseMultiTP && InpMoveSLToBE_On_TP1)
    {
        ManageBreakeven();
    }
}

void OnTick()
{
    if(InpUseTrailingSL && PositionsTotal() > 0)
    {
        ManageTrailingStop();
    }

    static datetime last_bar_time = 0;
    datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, InpEntryTimeframe, SERIES_LASTBAR_DATE);
    if(current_bar_time <= last_bar_time) return;
    last_bar_time = current_bar_time;

    CheckForSignal();
}
//+------------------------------------------------------------------+

void CheckForSignal()
{
    if(!CopyAllData()) 
    {
        Print("Failed to copy data. Skipping signal check.");
        return;
    }
    
    // --- NEW ADX FILTER ---
    if(!IsMarketTrending())
    {
        // Print("Market is sideways (ADX < ", (string)InpAdxThreshold, "). No trades allowed.");
        DeletePendingOrders(); // Clean up old orders if market goes sideways
        return;
    }
    
    if(PositionsTotal() > 0) return;
    if(IsSpreadHigh()) return;
    
    int h1_trend = GetH1Trend();

    if(h1_trend == 0)
    {
       DeletePendingOrders();
       return;
    }

    switch(InpEntryMethod)
    {
        case ENTRY_METHOD_IMMEDIATE: CheckImmediateEntry(h1_trend); break;
        case ENTRY_METHOD_RETEST: CheckRetestEntry(h1_trend); break;
        case ENTRY_METHOD_BREAKOUT: CheckBreakoutEntry(h1_trend); break;
    }
}

// ... (Các hàm vào lệnh và quản lý lệnh giữ nguyên như v2.6)
//+------------------------------------------------------------------+
// ENTRY LOGIC FUNCTIONS (Unchanged from v2.6)
//+------------------------------------------------------------------+
void CheckImmediateEntry(int h1_trend)
{
    bool is_buy_cross = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_fast[2] <= m5_ema_slow1[2];
    bool is_sell_cross = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_fast[2] >= m5_ema_slow1[2];

    if(h1_trend == 1 && is_buy_cross) PlaceOrderSet(ORDER_TYPE_BUY, 0);
    if(h1_trend == -1 && is_sell_cross) PlaceOrderSet(ORDER_TYPE_SELL, 0);
}

void CheckRetestEntry(int h1_trend)
{
    bool m5_trend_up = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1];
    bool m5_trend_down = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1];

    if(h1_trend == 1 && m5_trend_up)
    {
        if(m5_rates[1].low <= m5_ema_fast[1] || m5_rates[1].low <= m5_ema_slow1[1])
            PlaceOrderSet(ORDER_TYPE_BUY, 0);
    }
    if(h1_trend == -1 && m5_trend_down)
    {
        if(m5_rates[1].high >= m5_ema_fast[1] || m5_rates[1].high >= m5_ema_slow1[1])
            PlaceOrderSet(ORDER_TYPE_SELL, 0);
    }
}

void CheckBreakoutEntry(int h1_trend)
{
    bool m5_trend_up = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1];
    bool m5_trend_down = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1];

    DeletePendingOrders();

    if(h1_trend == 1 && m5_trend_up)
    {
        double swing_high = FindSwingHigh(InpBreakoutLookbackBars);
        if(swing_high > 0)
        {
            double point_val = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double entry_price = swing_high + InpBreakoutOffsetPips * point_val;
            PlaceOrderSet(ORDER_TYPE_BUY_STOP, entry_price);
        }
    }
    if(h1_trend == -1 && m5_trend_down)
    {
        double swing_low = FindSwingLow(InpBreakoutLookbackBars);
        if(swing_low > 0)
        {
            double point_val = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double entry_price = swing_low - InpBreakoutOffsetPips * point_val;
            PlaceOrderSet(ORDER_TYPE_SELL_STOP, entry_price);
        }
    }
}


//+------------------------------------------------------------------+
// MAIN ORDER PLACEMENT FUNCTION (Unchanged from v2.6)
//+------------------------------------------------------------------+
void PlaceOrderSet(ENUM_ORDER_TYPE order_type, double entry_price = 0)
{
    if(IsSpreadHigh()) return;
    
    if(entry_price == 0 && (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL))
    {
        entry_price = SymbolInfoDouble(_Symbol, (order_type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));
    }
    
    if(entry_price == 0) return;

    double atr_val = m5_atr[1];
    if(atr_val <= 0) return;

    double risk_distance = atr_val * InpAtrMultiplierSL;
    double stop_loss;
    
    if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
        stop_loss = entry_price - risk_distance;
    else
        stop_loss = entry_price + risk_distance;

    string trade_set_comment = "MultiTP_" + (string)TimeCurrent();
    int positions_to_open = InpUseMultiTP ? InpNumberOfPositions : 1;

    for(int i = 0; i < positions_to_open; i++)
    {
        double take_profit = 0;
        
        if(InpUseMultiTP)
        {
            if(i == 0 && InpRR_TP1 > 0)
            {
                if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
                    take_profit = entry_price + (risk_distance * InpRR_TP1);
                else
                    take_profit = entry_price - (risk_distance * InpRR_TP1);
            }
            else if(i == 1 && positions_to_open > 2 && InpRR_TP2 > 0)
            {
                if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
                    take_profit = entry_price + (risk_distance * InpRR_TP2);
                else
                    take_profit = entry_price - (risk_distance * InpRR_TP2);
            }
        }
        
        switch(order_type)
        {
            case ORDER_TYPE_BUY:
                trade.Buy(InpLotSize, _Symbol, entry_price, stop_loss, take_profit, trade_set_comment);
                break;
            case ORDER_TYPE_SELL:
                trade.Sell(InpLotSize, _Symbol, entry_price, stop_loss, take_profit, trade_set_comment);
                break;
            case ORDER_TYPE_BUY_STOP:
                trade.BuyStop(InpLotSize, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment);
                break;
            case ORDER_TYPE_SELL_STOP:
                trade.SellStop(InpLotSize, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment);
                break;
            case ORDER_TYPE_BUY_LIMIT:
                trade.BuyLimit(InpLotSize, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment);
                break;
            case ORDER_TYPE_SELL_LIMIT:
                trade.SellLimit(InpLotSize, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment);
                break;
        }
    }
}


//+------------------------------------------------------------------+
// TRADE MANAGEMENT FUNCTIONS (Unchanged from v2.6)
//+------------------------------------------------------------------+
void ManageBreakeven()
{
    if(HistorySelect(0, TimeCurrent()))
    {
        int start = (int)HistoryDealsTotal() - 1;
        int end = MathMax(0, start - 10);

        for(int i = start; i >= end; i--)
        {
            ulong deal_ticket = HistoryDealGetTicket((uint)i);
            if(deal_ticket > 0)
            {
                if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == InpMagicNumber && 
                   HistoryDealGetInteger(deal_ticket, DEAL_REASON) == DEAL_REASON_TP)
                {
                    string comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
                    if(comment != "")
                    {
                        for(int j = PositionsTotal() - 1; j >= 0; j--)
                        {
                            ulong pos_ticket = PositionGetTicket((uint)j);
                            if(PositionSelect(pos_ticket))
                            {
                                if(PositionGetString(POSITION_COMMENT) == comment && PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN))
                                {
                                    trade.PositionModify(pos_ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
                                    Print("Moved SL to Breakeven for ticket: ", (string)pos_ticket);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

void ManageTrailingStop()
{
    if(ArraySize(m5_atr) < 1) return;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket((uint)i);
        if(PositionSelect(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
                continue;

            long pos_type = PositionGetInteger(POSITION_TYPE);
            double current_sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double atr_val = m5_atr[0];
            if(atr_val <= 0) continue;

            double new_sl = 0;
            if(pos_type == POSITION_TYPE_BUY)
            {
                double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                new_sl = current_price - (atr_val * InpTrailingAtrMultiplier);
                if(new_sl > current_sl && new_sl > open_price)
                {
                    trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                }
            }
            else if(pos_type == POSITION_TYPE_SELL)
            {
                double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                new_sl = current_price + (atr_val * InpTrailingAtrMultiplier);
                if(new_sl < current_sl && new_sl < open_price)
                {
                    trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// UTILITY FUNCTIONS
//+------------------------------------------------------------------+
bool IsMarketTrending()
{
    if(!InpUseAdxFilter) return true; // If filter is off, always return true
    
    if(ArraySize(h1_adx_buffer) < 2) return false; // Not enough data
    
    // The main ADX line is at buffer index 0
    if(h1_adx_buffer[1] >= InpAdxThreshold)
    {
        return true; // Market is trending
    }
    
    return false; // Market is sideways
}


int GetH1Trend()
{
    if(ArraySize(h1_ema_fast) < 2) return 0;

    bool is_uptrend = h1_ema_fast[1] > h1_ema_slow2[1] && h1_ema_slow1[1] > h1_ema_slow2[1];
    bool is_downtrend = h1_ema_fast[1] < h1_ema_slow2[1] && h1_ema_slow1[1] < h1_ema_slow2[1];

    if(is_uptrend) return 1;
    if(is_downtrend) return -1;
    
    return 0;
}

double FindSwingHigh(int bars)
{
    double swing_high = 0;
    for(int i = 1; i <= bars && i < ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].high > swing_high) swing_high = m5_rates[i].high;
    }
    return swing_high;
}

double FindSwingLow(int bars)
{
    if(ArraySize(m5_rates) < 2) return 0;
    double swing_low = m5_rates[1].low;
    for(int i = 2; i <= bars && i < ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].low < swing_low) swing_low = m5_rates[i].low;
    }
    return swing_low;
}

void DeletePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket((uint)i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}

bool IsSpreadHigh()
{
    return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints);
}

bool CopyAllData()
{
    int bars_needed_h1 = 3;
    int bars_needed_m5 = InpBreakoutLookbackBars + 3;

    if(CopyRates(_Symbol, InpTrendTimeframe, 0, bars_needed_h1, h1_rates) < bars_needed_h1 ||
       CopyRates(_Symbol, InpEntryTimeframe, 0, bars_needed_m5, m5_rates) < bars_needed_m5)
    {
        Print("Failed to copy rates.");
        return false;
    }
    
    if(CopyBuffer(h1_ema_fast_handle, 0, 0, bars_needed_h1, h1_ema_fast) < bars_needed_h1 ||
       CopyBuffer(h1_ema_slow1_handle, 0, 0, bars_needed_h1, h1_ema_slow1) < bars_needed_h1 ||
       CopyBuffer(h1_ema_slow2_handle, 0, 0, bars_needed_h1, h1_ema_slow2) < bars_needed_h1 ||
       CopyBuffer(h1_adx_handle, 0, 0, bars_needed_h1, h1_adx_buffer) < bars_needed_h1) // Copy ADX data
    {
       Print("Failed to copy H1 indicator data.");
       return false;
    }

    if(CopyBuffer(m5_ema_fast_handle, 0, 0, bars_needed_m5, m5_ema_fast) < bars_needed_m5 ||
       CopyBuffer(m5_ema_slow1_handle, 0, 0, bars_needed_m5, m5_ema_slow1) < bars_needed_m5 ||
       CopyBuffer(m5_ema_slow2_handle, 0, 0, bars_needed_m5, m5_ema_slow2) < bars_needed_m5 ||
       CopyBuffer(m5_atr_handle, 0, 0, 2, m5_atr) < 2)
    {
        Print("Failed to copy M5 indicator data.");
        return false;
    }
       
    ArraySetAsSeries(h1_rates, true);
    ArraySetAsSeries(m5_rates, true);
    ArraySetAsSeries(h1_ema_fast, true);
    ArraySetAsSeries(h1_ema_slow1, true);
    ArraySetAsSeries(h1_ema_slow2, true);
    ArraySetAsSeries(h1_adx_buffer, true); // Set ADX buffer as series
    ArraySetAsSeries(m5_ema_fast, true);
    ArraySetAsSeries(m5_ema_slow1, true);
    ArraySetAsSeries(m5_ema_slow2, true);
    ArraySetAsSeries(m5_atr, true);

    return true;
}
