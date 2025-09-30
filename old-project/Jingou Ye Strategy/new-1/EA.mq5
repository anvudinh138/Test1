//+------------------------------------------------------------------+
//|                                            ye_strategy_v2_1.mq5  |
//|                                  Copyright 2024, Gemini Advisor  |
//|                    Version 2.1 (Bug Fix for v2.0)                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Advisor"
#property link      ""
#property version   "2.1"
#property description "Fixes all compilation and logic errors from v2.0."
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
input ENUM_ENTRY_METHOD InpEntryMethod = ENTRY_METHOD_RETEST; // Choose your entry method
input ENUM_TIMEFRAMES   InpTrendTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES   InpEntryTimeframe = PERIOD_M5;
input int               InpFastEMA_Period = 8;
input int               InpSlow1EMA_Period = 13;
input int               InpSlow2EMA_Period = 21;

//--- Breakout Settings ---
input int               InpBreakoutLookbackBars = 8;      // How many bars to look back for swing high/low
input int               InpBreakoutOffsetPips = 3;        // How many pips to offset the pending order

//--- Trade Settings ---
input double            InpLotSize = 0.01;
input int               InpMaxSpreadPoints = 30;
input ulong             InpMagicNumber = 202401; // New magic number for new strategy

//--- SL/TP & Trailing Stop ---
input bool              InpUseAtrSL = true;
input int               InpAtrPeriod = 14;
input double            InpAtrMultiplierSL = 2.0;
input double            InpAtrMultiplierTP = 4.0;
input bool              InpUseTrailingSL = true;
input double            InpTrailingAtrMultiplier = 2.5;

//--- Global variables
CTrade trade;
int h1_ema_fast_handle, h1_ema_slow1_handle, h1_ema_slow2_handle;
int m5_ema_fast_handle, m5_ema_slow1_handle, m5_ema_slow2_handle;
int m5_atr_handle;

double h1_ema_fast[], h1_ema_slow1[], h1_ema_slow2[];
double m5_ema_fast[], m5_ema_slow1[], m5_ema_slow2[];
double m5_atr[];
MqlRates h1_rates[], m5_rates[];


//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing EA v2.1 (Retest & Breakout)...");
    trade.SetExpertMagicNumber(InpMagicNumber);

    h1_ema_fast_handle = iMA(_Symbol, InpTrendTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow1_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow2_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    
    m5_ema_fast_handle = iMA(_Symbol, InpEntryTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow1_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow2_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_atr_handle = iATR(_Symbol, InpEntryTimeframe, InpAtrPeriod);

    Print("EA Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing EA v2.1. Reason: ", reason);
    DeletePendingOrders();
}

//+------------------------------------------------------------------+
void OnTick()
{
    if(InpUseTrailingSL && PositionsTotal() > 0)
    {
        ManageTrailingStop();
    }

    static datetime last_bar_time = 0;
    if(TimeCurrent() < last_bar_time + PeriodSeconds(InpEntryTimeframe))
    {
        return;
    }
    last_bar_time = (datetime)SeriesInfoInteger(_Symbol, InpEntryTimeframe, SERIES_LASTBAR_DATE);

    if(!CopyAllData()) return;

    CheckForSignal();
}

//+------------------------------------------------------------------+
void CheckForSignal()
{
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
        case ENTRY_METHOD_IMMEDIATE:
            CheckImmediateEntry(h1_trend);
            break;
        case ENTRY_METHOD_RETEST:
            CheckRetestEntry(h1_trend);
            break;
        case ENTRY_METHOD_BREAKOUT:
            CheckBreakoutEntry(h1_trend);
            break;
    }
}

//+------------------------------------------------------------------+
int GetH1Trend()
{
    bool price_ok_up = h1_rates[1].close > h1_ema_fast[1] && h1_rates[1].close > h1_ema_slow1[1] && h1_rates[1].close > h1_ema_slow2[1];
    bool price_ok_down = h1_rates[1].close < h1_ema_fast[1] && h1_rates[1].close < h1_ema_slow1[1] && h1_rates[1].close < h1_ema_slow2[1];
    bool stacked_up = h1_ema_fast[1] > h1_ema_slow1[1] && h1_ema_slow1[1] > h1_ema_slow2[1];
    bool stacked_down = h1_ema_fast[1] < h1_ema_slow1[1] && h1_ema_slow1[1] < h1_ema_slow2[1];
    bool sloped_up = h1_ema_fast[1] > h1_ema_fast[2] && h1_ema_slow1[1] > h1_ema_slow1[2] && h1_ema_slow2[1] > h1_ema_slow2[2];
    bool sloped_down = h1_ema_fast[1] < h1_ema_fast[2] && h1_ema_slow1[1] < h1_ema_slow1[2] && h1_ema_slow2[1] < h1_ema_slow2[2];

    if(price_ok_up && stacked_up && sloped_up) return 1;
    if(price_ok_down && stacked_down && sloped_down) return -1;

    return 0;
}

//+------------------------------------------------------------------+
void CheckImmediateEntry(int h1_trend)
{
    bool is_buy_cross = m5_ema_fast[2] <= m5_ema_slow1[2] && m5_ema_fast[1] > m5_ema_slow1[1];
    bool is_sell_cross = m5_ema_fast[2] >= m5_ema_slow1[2] && m5_ema_fast[1] < m5_ema_slow1[1];

    if(h1_trend == 1 && is_buy_cross) PlaceMarketOrder(ORDER_TYPE_BUY);
    if(h1_trend == -1 && is_sell_cross) PlaceMarketOrder(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
void CheckRetestEntry(int h1_trend)
{
    bool m5_trend_up = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1];
    bool m5_trend_down = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1];

    if(h1_trend == 1 && m5_trend_up)
    {
        bool touched_ema = (m5_rates[1].low <= m5_ema_fast[1] || m5_rates[1].low <= m5_ema_slow1[1]);
        if(touched_ema) PlaceMarketOrder(ORDER_TYPE_BUY);
    }
    if(h1_trend == -1 && m5_trend_down)
    {
        bool touched_ema = (m5_rates[1].high >= m5_ema_fast[1] || m5_rates[1].high >= m5_ema_slow1[1]);
        if(touched_ema) PlaceMarketOrder(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
void CheckBreakoutEntry(int h1_trend)
{
    bool m5_trend_up = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1];
    bool m5_trend_down = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1];

    DeletePendingOrders();

    if(h1_trend == 1 && m5_trend_up)
    {
        double swing_high = FindSwingHigh(InpBreakoutLookbackBars);
        double point = _Point * (_Digits == 3 || _Digits == 5 ? 10 : 1);
        double entry_price = swing_high + InpBreakoutOffsetPips * point;
        PlacePendingOrder(ORDER_TYPE_BUY_STOP, entry_price);
    }
    if(h1_trend == -1 && m5_trend_down)
    {
        double swing_low = FindSwingLow(InpBreakoutLookbackBars);
        double point = _Point * (_Digits == 3 || _Digits == 5 ? 10 : 1);
        double entry_price = swing_low - InpBreakoutOffsetPips * point;
        PlacePendingOrder(ORDER_TYPE_SELL_STOP, entry_price);
    }
}

//+------------------------------------------------------------------+
void PlaceMarketOrder(ENUM_ORDER_TYPE order_type)
{
    double price = SymbolInfoDouble(_Symbol, (order_type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));
    double stop_loss = 0, take_profit = 0;
    
    if(InpUseAtrSL)
    {
        double atr_value = m5_atr[1];
        if(order_type == ORDER_TYPE_BUY)
        {
            stop_loss = price - (atr_value * InpAtrMultiplierSL);
            take_profit = price + (atr_value * InpAtrMultiplierTP);
        }
        else
        {
            stop_loss = price + (atr_value * InpAtrMultiplierSL);
            take_profit = price - (atr_value * InpAtrMultiplierTP);
        }
    }

    if(order_type == ORDER_TYPE_BUY) trade.Buy(InpLotSize, _Symbol, price, NormalizeDouble(stop_loss, _Digits), NormalizeDouble(take_profit, _Digits));
    else trade.Sell(InpLotSize, _Symbol, price, NormalizeDouble(stop_loss, _Digits), NormalizeDouble(take_profit, _Digits));
}

//+------------------------------------------------------------------+
void PlacePendingOrder(ENUM_ORDER_TYPE order_type, double entry_price)
{
    double stop_loss = 0, take_profit = 0;
    
    if(InpUseAtrSL)
    {
        double atr_value = m5_atr[1];
        if(order_type == ORDER_TYPE_BUY_STOP)
        {
            stop_loss = entry_price - (atr_value * InpAtrMultiplierSL);
            take_profit = entry_price + (atr_value * InpAtrMultiplierTP);
        }
        else // SELL_STOP
        {
            stop_loss = entry_price + (atr_value * InpAtrMultiplierSL);
            take_profit = entry_price - (atr_value * InpAtrMultiplierTP);
        }
    }

    if(order_type == ORDER_TYPE_BUY_STOP) trade.BuyStop(InpLotSize, entry_price, _Symbol, NormalizeDouble(stop_loss, _Digits), NormalizeDouble(take_profit, _Digits));
    else trade.SellStop(InpLotSize, entry_price, _Symbol, NormalizeDouble(stop_loss, _Digits), NormalizeDouble(take_profit, _Digits));
}

//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    if(!CopyAllData()) return;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelect(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                long position_type = PositionGetInteger(POSITION_TYPE);
                double current_sl = PositionGetDouble(POSITION_SL);
                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

                double atr_value = m5_atr[0];
                double new_sl = 0;

                if(position_type == POSITION_TYPE_BUY)
                {
                    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    new_sl = current_price - (atr_value * InpTrailingAtrMultiplier);
                    if(new_sl > current_sl && new_sl > open_price)
                    {
                        trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                    }
                }
                else if(position_type == POSITION_TYPE_SELL)
                {
                    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    new_sl = current_price + (atr_value * InpTrailingAtrMultiplier);
                    if(new_sl < current_sl && new_sl < open_price)
                    {
                        trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
double FindSwingHigh(int bars)
{
    double swing_high = 0;
    for(int i = 1; i <= bars && i < ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].high > swing_high) swing_high = m5_rates[i].high;
    }
    return swing_high;
}

//+------------------------------------------------------------------+
double FindSwingLow(int bars)
{
    double swing_low = 999999;
    for(int i = 1; i <= bars && i < ArraySize(m5_rates); i++)
    {
        if(m5_rates[i].low < swing_low) swing_low = m5_rates[i].low;
    }
    return swing_low;
}

//+------------------------------------------------------------------+
void DeletePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool IsSpreadHigh()
{
    return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
bool CopyAllData()
{
    if(CopyBuffer(h1_ema_fast_handle, 0, 0, 3, h1_ema_fast) < 3 ||
       CopyBuffer(h1_ema_slow1_handle, 0, 0, 3, h1_ema_slow1) < 3 ||
       CopyBuffer(h1_ema_slow2_handle, 0, 0, 3, h1_ema_slow2) < 3 ||
       CopyRates(_Symbol, InpTrendTimeframe, 0, 3, h1_rates) < 3)
        return false;

    if(CopyBuffer(m5_ema_fast_handle, 0, 0, 3, m5_ema_fast) < 3 ||
       CopyBuffer(m5_ema_slow1_handle, 0, 0, 3, m5_ema_slow1) < 3 ||
       CopyBuffer(m5_ema_slow2_handle, 0, 0, 3, m5_ema_slow2) < 3 ||
       CopyBuffer(m5_atr_handle, 0, 0, 2, m5_atr) < 2 ||
       CopyRates(_Symbol, InpEntryTimeframe, 0, InpBreakoutLookbackBars + 2, m5_rates) < InpBreakoutLookbackBars + 2)
       return false;
       
    ArraySetAsSeries(h1_rates, true);
    ArraySetAsSeries(m5_rates, true);
    ArraySetAsSeries(h1_ema_fast, true);
    ArraySetAsSeries(h1_ema_slow1, true);
    ArraySetAsSeries(h1_ema_slow2, true);
    ArraySetAsSeries(m5_ema_fast, true);
    ArraySetAsSeries(m5_ema_slow1, true);
    ArraySetAsSeries(m5_ema_slow2, true);
    ArraySetAsSeries(m5_atr, true);

    return true;
}
