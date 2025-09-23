//+------------------------------------------------------------------+
//|                                     ye_strategy_v7_0_prod.mq5    |
//|                                  Copyright 2024, Gemini Advisor  |
//|                   Version 7.0 (Production Ready)                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Advisor"
#property link      ""
#property version   "7.0"
#property description "Final, stable, production-ready version. Incorporates the PositionSelectByTicket fix for maximum reliability in all environments."
#property strict

#include <Trade/Trade.mqh>

//--- ENUMs for strategy settings
enum ENUM_ENTRY_METHOD { ENTRY_METHOD_RETEST, ENTRY_METHOD_BREAKOUT, ENTRY_METHOD_IMMEDIATE };
enum ENUM_MONEY_MANAGEMENT { MM_FIXED_LOT, MM_RISK_PERCENTAGE };

//--- EA Inputs ---
//--- SECTION: Core Strategy ---
input ENUM_ENTRY_METHOD InpEntryMethod = ENTRY_METHOD_BREAKOUT;
input ENUM_TIMEFRAMES   InpTrendTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES   InpEntryTimeframe = PERIOD_M5;
input int               InpFastEMA_Period = 8;
input int               InpSlow1EMA_Period = 13;
input int               InpSlow2EMA_Period = 21;

//--- SECTION: Stop Loss & Take Profit (Points-based) ---
input int               InpStopLossPoints = 250;      // Stop Loss in Points (e.g., 25 pips = 250 points)
input int               InpTakeProfit1_Points = 300;  // Take Profit 1 in Points (e.g., 30 pips = 300 points)
input int               InpTakeProfit2_Points = 600;  // Take Profit 2 in Points (e.g., 60 pips = 600 points)

//--- SECTION: Independent Trailing Stop (Points-based) ---
input bool              InpUseTrailingSL = true;
input int               InpTrailingStartPoints = 250; // Bắt đầu trailing khi lợi nhuận đạt số Points này (e.g., 25 pips = 250 points)
input int               InpTrailingStopPoints = 250;  // Giữ khoảng cách trailing theo số Points này (e.g., 25 pips = 250 points)

//--- SECTION: Trade Execution & Management ---
input bool              InpUseMultiTP = true;
input int               InpNumberOfPositions = 3;
input bool              InpMoveSLToBE_On_TP1 = true;
input int               InpMaxSpreadPoints = 30;
input ulong             InpMagicNumber = 202506;

//--- SECTION: Money Management ---
input ENUM_MONEY_MANAGEMENT InpMoneyManagement = MM_FIXED_LOT;
input double                 InpFixedLotSize = 0.01;
input double                 InpRiskPercent = 0.5;

//--- SECTION: Filters ---
input bool              InpUseDailyFilter = true;
input int               InpDailyEmaPeriod = 200;
input bool              InpUseAdxFilter = true;
input bool              InpUseDiCrossover = true;
input int               InpAdxPeriod = 14;
input double            InpAdxThreshold = 25.0;
input bool              InpUseSessionFilter = true;
input int               InpTradingStartHour = 8;
input int               InpTradingEndHour = 22;
input int               InpBreakoutLookbackBars = 8;
input int               InpBreakoutOffsetPoints = 30; // Offset in Points (e.g., 3 pips = 30 points)

//--- SECTION: Safety & Display ---
input bool   InpUseLossLimit = true;
input int    InpMaxConsecutiveLosses = 15;
input int    InpPauseDurationHours = 24;
input bool   InpShowDisplayPanel = true;

//--- Global variables ---
CTrade      trade;
int         h1_ema_fast_handle, h1_ema_slow1_handle, h1_ema_slow2_handle, h1_adx_handle;
int         m5_ema_fast_handle, m5_ema_slow1_handle, m5_ema_slow2_handle;
int         d1_ema_handle;
double      h1_ema_fast[], h1_ema_slow1[], h1_ema_slow2[];
double      h1_adx_main[], h1_adx_plus_di[], h1_adx_minus_di[];
double      m5_ema_fast[], m5_ema_slow1[], m5_ema_slow2[];
MqlRates    h1_rates[], m5_rates[], d1_rates[];
double      d1_ema[];
int         g_consecutive_losses = 0;
datetime    g_trading_paused_until = 0;
string      g_ea_status = "Initializing...";
ulong       g_last_processed_deal_ticket = 0;
bool        g_breakeven_needed = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Initializing EA v7.0 (Production)...");
   trade.SetExpertMagicNumber(InpMagicNumber);
   h1_ema_fast_handle = iMA(_Symbol, InpTrendTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h1_ema_slow1_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h1_ema_slow2_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h1_adx_handle = iADX(_Symbol, InpTrendTimeframe, InpAdxPeriod);
   m5_ema_fast_handle = iMA(_Symbol, InpEntryTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   m5_ema_slow1_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   m5_ema_slow2_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   d1_ema_handle = iMA(_Symbol, PERIOD_D1, InpDailyEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   Print("EA Initialized Successfully.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(PositionsTotal() > 0)
     {
      ManageOpenPositions();
     }

   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, InpEntryTimeframe, SERIES_LASTBAR_DATE);
   if(current_bar_time <= last_bar_time)
      return;
   last_bar_time = current_bar_time;

   if(InpShowDisplayPanel)
      UpdateDisplayPanel();
   CheckForSignal();
  }

//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   if(g_breakeven_needed)
     {
      if(TryMoveToBreakeven())
        {
         g_breakeven_needed = false;
        }
      else
        {
         return;
        }
     }

   if(InpUseTrailingSL)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) // Using the robust selection method
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
bool TryMoveToBreakeven()
  {
   int positions_at_risk = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong pos_ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(pos_ticket)) // Using the robust selection method
        {
         return false;
        }

      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         long pos_type = PositionGetInteger(POSITION_TYPE);

         if((pos_type == POSITION_TYPE_BUY && current_sl < open_price) ||
            (pos_type == POSITION_TYPE_SELL && (current_sl > open_price || current_sl == 0)))
           {
            positions_at_risk++;

            if(!trade.PositionModify(pos_ticket, open_price, PositionGetDouble(POSITION_TP)))
              {
               return false;
              }
           }
        }
     }

   return (positions_at_risk == 0);
  }

//+------------------------------------------------------------------+
void ManageTrailingStopForPosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return; // Using the robust selection method

   long pos_type = PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double start_trailing_in_points = _Point * InpTrailingStartPoints;
   double trail_distance_in_points = _Point * InpTrailingStopPoints;

   if(pos_type == POSITION_TYPE_BUY)
     {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(current_price > open_price + start_trailing_in_points)
        {
         double new_sl = current_price - trail_distance_in_points;
         if(new_sl > current_sl)
           {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
           }
        }
     }
   else
      if(pos_type == POSITION_TYPE_SELL)
        {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
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
void OnTrade()
  {
   if(!HistorySelect(0, TimeCurrent()))
      return;

   int total_history_deals=(int)HistoryDealsTotal();
   if(total_history_deals == 0)
      return;

   ulong last_deal_ticket=HistoryDealGetTicket((uint)total_history_deals-1);

   if(last_deal_ticket != g_last_processed_deal_ticket)
     {
      g_last_processed_deal_ticket = last_deal_ticket;

      if(HistoryDealGetInteger(last_deal_ticket, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetInteger(last_deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
         if(HistoryDealGetDouble(last_deal_ticket, DEAL_PROFIT) < 0)
           {
            g_consecutive_losses++;
           }
         else
           {
            if(g_consecutive_losses > 0)
              {
               g_consecutive_losses = 0;
              }

            if(InpMoveSLToBE_On_TP1 && HistoryDealGetInteger(last_deal_ticket, DEAL_REASON) == DEAL_REASON_TP)
              {
               g_breakeven_needed = true;
               Print("BREAKEVEN EVENT: TP hit. Flag set to process BE on subsequent ticks.");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
void PlaceOrderSet(ENUM_ORDER_TYPE order_type, double entry_price = 0) {if(IsSpreadHigh()) return;if(entry_price == 0 && (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL)) {entry_price = SymbolInfoDouble(_Symbol, (order_type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));} if(entry_price == 0) return;double stop_loss_in_price = InpStopLossPoints * _Point;double stop_loss = 0; if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)stop_loss = entry_price - stop_loss_in_price;else stop_loss = entry_price + stop_loss_in_price;string trade_set_comment = "JYS_v7.0_" + (string)TimeCurrent();int positions_to_open = InpUseMultiTP ? InpNumberOfPositions : 1;for(int i = 0; i < positions_to_open; i++) {double lot_size = CalculateLotSize(InpStopLossPoints);if(lot_size < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) continue;double take_profit = 0;if(InpUseMultiTP) {if(i == 0 && InpTakeProfit1_Points > 0) {take_profit = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) ? entry_price + InpTakeProfit1_Points * _Point : entry_price - InpTakeProfit1_Points * _Point;} else if(i == 1 && positions_to_open > 2 && InpTakeProfit2_Points > 0) {take_profit = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) ? entry_price + InpTakeProfit2_Points * _Point : entry_price - InpTakeProfit2_Points * _Point;}} switch(order_type) {case ORDER_TYPE_BUY:
         trade.Buy(lot_size, _Symbol, entry_price, stop_loss, take_profit, trade_set_comment); break;case ORDER_TYPE_SELL:
         trade.Sell(lot_size, _Symbol, entry_price, stop_loss, take_profit, trade_set_comment); break;case ORDER_TYPE_BUY_STOP:
         trade.BuyStop(lot_size, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break;case ORDER_TYPE_SELL_STOP:
         trade.SellStop(lot_size, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break;case ORDER_TYPE_BUY_LIMIT:
         trade.BuyLimit(lot_size, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break;case ORDER_TYPE_SELL_LIMIT:
            trade.SellLimit(lot_size, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, trade_set_comment); break;}}}
double CalculateLotSize(double stop_loss_in_points) {if(InpMoneyManagement==MM_FIXED_LOT) return InpFixedLotSize;double risk_pct=InpRiskPercent;double risk_amt=AccountInfoDouble(ACCOUNT_BALANCE)*(risk_pct/100.0);double tick_val=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);if(tick_val<=0||tick_size<=0||stop_loss_in_points<=0) return InpFixedLotSize;double loss_lot=(stop_loss_in_points*_Point)/tick_size*tick_val;if(loss_lot<=0) return InpFixedLotSize;double lot=risk_amt/loss_lot;double min_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);double max_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);double step_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);lot=MathFloor(lot/step_l)*step_l;if(lot<min_l) lot=min_l;if(lot>max_l) lot=max_l;return lot;}
void CheckBreakoutEntry(int h1_trend) {bool is_bullish_setup = m5_ema_fast[1]>m5_ema_slow1[1] && m5_ema_slow1[1]>m5_ema_slow2[1];bool is_bearish_setup = m5_ema_fast[1]<m5_ema_slow1[1] && m5_ema_slow1[1]<m5_ema_slow2[1];DeletePendingOrders();if(h1_trend==1 && is_bullish_setup) {double high_level=FindSwingHigh(InpBreakoutLookbackBars);if(high_level>0) {double entry_p = high_level + InpBreakoutOffsetPoints*_Point;PlaceOrderSet(ORDER_TYPE_BUY_STOP,entry_p);}} if(h1_trend==-1 && is_bearish_setup) {double low_level=FindSwingLow(InpBreakoutLookbackBars);if(low_level>0) {double entry_p = low_level - InpBreakoutOffsetPoints*_Point;PlaceOrderSet(ORDER_TYPE_SELL_STOP,entry_p);}}}
void CheckForSignal() {if(!CopyAllData()) {g_ea_status="Error: Cannot copy data";return;} if(IsTradingPaused()) {DeletePendingOrders();return;} if(!IsTradingSessionActive()) {g_ea_status="DISABLED - Outside Session";DeletePendingOrders();return;} if(PositionsTotal()>0) {g_ea_status="Position is Open";return;} if(IsSpreadHigh()) {g_ea_status="Spread is too high";return;} int major_trend=GetMajorTrend();int h1_trend=GetEMATrend();if(InpUseDailyFilter && h1_trend!=major_trend && h1_trend!=0) {g_ea_status="DISABLED - D1/H1 Mismatch";DeletePendingOrders();return;} if(!IsSignalAllowed(h1_trend)) {if(InpUseAdxFilter && ArraySize(h1_adx_main)>1 && h1_adx_main[1]<InpAdxThreshold)g_ea_status="DISABLED - Sideways (ADX)";else if(InpUseDiCrossover)g_ea_status="DISABLED - DI not crossed";else g_ea_status="Signal Not Allowed";DeletePendingOrders();return;} if(h1_trend==0) {g_ea_status="WAITING - No H1 Trend";DeletePendingOrders();return;} g_ea_status="WAITING FOR ENTRY SIGNAL...";switch(InpEntryMethod) {case ENTRY_METHOD_IMMEDIATE:
CheckImmediateEntry(h1_trend); break;case ENTRY_METHOD_RETEST:
CheckRetestEntry(h1_trend);    break;case ENTRY_METHOD_BREAKOUT:
   CheckBreakoutEntry(h1_trend);  break;}}
bool IsTradingPaused() {if(!InpUseLossLimit) return false;if(g_trading_paused_until>0 && g_trading_paused_until<=TimeCurrent()) {Print("Trading pause has ended. Resuming operation and resetting loss count.");g_consecutive_losses=0;g_trading_paused_until=0;return false;} if(g_trading_paused_until>TimeCurrent()) {long rem_sec=g_trading_paused_until-TimeCurrent();g_ea_status="PAUSED - "+(string)(rem_sec/60)+" min remaining";return true;} if(g_consecutive_losses>=InpMaxConsecutiveLosses) {g_trading_paused_until=TimeCurrent()+(InpPauseDurationHours*3600);Print("Max consecutive losses of ",(string)InpMaxConsecutiveLosses," reached. Pausing trading for ",(string)InpPauseDurationHours," hours.");g_ea_status="PAUSED - Max Losses Hit";return true;} return false;}
int GetMajorTrend() {if(!InpUseDailyFilter) return 0;if(ArraySize(d1_rates)<2 || ArraySize(d1_ema)<2) return 0;if(d1_rates[1].close > d1_ema[1]) return 1;if(d1_rates[1].close < d1_ema[1]) return -1;return 0;}
bool IsSignalAllowed(int trend_direction) {if(InpUseAdxFilter) {if(ArraySize(h1_adx_main)<2) return false;if(h1_adx_main[1] < InpAdxThreshold) return false;} if(InpUseDiCrossover) {if(ArraySize(h1_adx_plus_di)<2 || ArraySize(h1_adx_minus_di)<2) return false;if(trend_direction==1 && h1_adx_plus_di[1] <= h1_adx_minus_di[1]) return false;if(trend_direction==-1 && h1_adx_minus_di[1] <= h1_adx_plus_di[1]) return false;} return true;}
int GetEMATrend() {if(ArraySize(h1_ema_fast)<2) return 0;bool is_uptrend = h1_ema_fast[1] > h1_ema_slow2[1] && h1_ema_slow1[1] > h1_ema_slow2[1];bool is_downtrend = h1_ema_fast[1] < h1_ema_slow2[1] && h1_ema_slow1[1] < h1_ema_slow2[1];if(is_uptrend) return 1;if(is_downtrend) return -1;return 0;}
bool IsTradingSessionActive() {if(!InpUseSessionFilter) return true;MqlDateTime t;TimeCurrent(t);if(InpTradingStartHour > InpTradingEndHour) {if(t.hour >= InpTradingStartHour || t.hour < InpTradingEndHour) return true;} else {if(t.hour >= InpTradingStartHour && t.hour < InpTradingEndHour) return true;} return false;}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSpreadHigh() {return(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints);}
void CheckImmediateEntry(int h1_trend) {bool buy_signal = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_fast[2] <= m5_ema_slow1[2];bool sell_signal = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_fast[2] >= m5_ema_slow1[2];if(h1_trend==1 && buy_signal) PlaceOrderSet(ORDER_TYPE_BUY,0);if(h1_trend==-1 && sell_signal) PlaceOrderSet(ORDER_TYPE_SELL,0);}
void CheckRetestEntry(int h1_trend) {bool is_uptrend = m5_ema_fast[1] > m5_ema_slow1[1] && m5_ema_slow1[1] > m5_ema_slow2[1];bool is_downtrend = m5_ema_fast[1] < m5_ema_slow1[1] && m5_ema_slow1[1] < m5_ema_slow2[1];if(h1_trend==1 && is_uptrend) {if(m5_rates[1].low <= m5_ema_fast[1] || m5_rates[1].low <= m5_ema_slow1[1]) PlaceOrderSet(ORDER_TYPE_BUY,0);} if(h1_trend==-1 && is_downtrend) {if(m5_rates[1].high >= m5_ema_fast[1] || m5_rates[1].high >= m5_ema_slow1[1]) PlaceOrderSet(ORDER_TYPE_SELL,0);}}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {ObjectDelete(0,"StatusPanel_BG");ObjectDelete(0,"StatusPanel_Text");Print("Deinitializing EA v7.0. Reason: ",(string)reason);if(reason!=REASON_CHARTCLOSE) {DeletePendingOrders();}}
double FindSwingHigh(int bars) {double high_val=0;for(int i=1; i<=bars && i<ArraySize(m5_rates); i++) {if(m5_rates[i].high>high_val) high_val=m5_rates[i].high;} return high_val;}
double FindSwingLow(int bars) {if(ArraySize(m5_rates)<2) return 0;double low_val=m5_rates[1].low;for(int i=2; i<=bars && i<ArraySize(m5_rates); i++) {if(m5_rates[i].low<low_val) low_val=m5_rates[i].low;} return low_val;}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeletePendingOrders() {for(int i=OrdersTotal()-1; i>=0; i--) {ulong ticket=OrderGetTicket((uint)i);if(OrderSelect(ticket)) {if(OrderGetInteger(ORDER_MAGIC)==InpMagicNumber && OrderGetString(ORDER_SYMBOL)==_Symbol) {trade.OrderDelete(ticket);}}}}
bool CopyAllData() {int bh1=3;int bm5=InpBreakoutLookbackBars+3;if(CopyRates(_Symbol,InpTrendTimeframe,0,bh1,h1_rates)<bh1 || CopyRates(_Symbol,InpEntryTimeframe,0,bm5,m5_rates)<bm5) return false;if(CopyBuffer(h1_ema_fast_handle,0,0,bh1,h1_ema_fast)<bh1 || CopyBuffer(h1_ema_slow1_handle,0,0,bh1,h1_ema_slow1)<bh1 || CopyBuffer(h1_ema_slow2_handle,0,0,bh1,h1_ema_slow2)<bh1 || CopyBuffer(h1_adx_handle,0,0,bh1,h1_adx_main)<bh1 || CopyBuffer(h1_adx_handle,1,0,bh1,h1_adx_plus_di)<bh1 || CopyBuffer(h1_adx_handle,2,0,bh1,h1_adx_minus_di)<bh1) return false;if(CopyBuffer(m5_ema_fast_handle,0,0,bm5,m5_ema_fast)<bm5 || CopyBuffer(m5_ema_slow1_handle,0,0,bm5,m5_ema_slow1)<bm5 || CopyBuffer(m5_ema_slow2_handle,0,0,bm5,m5_ema_slow2)<bm5) return false;if(InpUseDailyFilter) {if(CopyRates(_Symbol,PERIOD_D1,0,2,d1_rates)<2 || CopyBuffer(d1_ema_handle,0,0,2,d1_ema)<2) return false;ArraySetAsSeries(d1_rates,true);ArraySetAsSeries(d1_ema,true);} ArraySetAsSeries(h1_rates,true);ArraySetAsSeries(m5_rates,true);ArraySetAsSeries(h1_ema_fast,true);ArraySetAsSeries(h1_ema_slow1,true);ArraySetAsSeries(h1_ema_slow2,true);ArraySetAsSeries(h1_adx_main,true);ArraySetAsSeries(h1_adx_plus_di,true);ArraySetAsSeries(h1_adx_minus_di,true);ArraySetAsSeries(m5_ema_fast,true);ArraySetAsSeries(m5_ema_slow1,true);ArraySetAsSeries(m5_ema_slow2,true);return true;}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDisplayPanel() {ObjectCreate(0,"StatusPanel_BG",OBJ_RECTANGLE_LABEL,0,0,0);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XDISTANCE,5);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YDISTANCE,10);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XSIZE,220);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YSIZE,120);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_COLOR,clrBlack);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_BACK,true);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);string pt="--- Jinguo Ye Strategy v7.0 ---\n\n";pt+="EA Status: "+g_ea_status+"\n\n";string d1t="N/A";if(InpUseDailyFilter) {int dt=GetMajorTrend();if(dt==1) d1t="UP";else if(dt==-1) d1t="DOWN";else d1t="Neutral";} string h1r="N/A";if(InpUseAdxFilter) {if(ArraySize(h1_adx_main)>1 && h1_adx_main[1]>=InpAdxThreshold) h1r="Trending";else h1r="Sideways";} pt+="Major Trend (D1): "+d1t+"\n";pt+="Market Regime (H1): "+h1r+"\n\n";pt+="Consecutive Losses: "+(string)g_consecutive_losses+"/"+(string)InpMaxConsecutiveLosses;ObjectCreate(0,"StatusPanel_Text",OBJ_LABEL,0,0,0);ObjectSetString(0,"StatusPanel_Text",OBJPROP_TEXT,pt);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_XDISTANCE,10);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_YDISTANCE,15);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_COLOR,clrLime);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_FONTSIZE,10);}
//+------------------------------------------------------------------+
