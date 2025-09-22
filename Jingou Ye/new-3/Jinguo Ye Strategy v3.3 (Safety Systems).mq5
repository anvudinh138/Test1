//+------------------------------------------------------------------+
//|                                            ye_strategy_v4_4.mq5  |
//|                                  Copyright 2024, Gemini Advisor  |
//|                Version 4.4 (Proactive Trade Management)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Advisor"
#property link      ""
#property version   "4.4"
#property description "Implements proactive trade management in OnTick for robust breakeven and trailing."
#property strict

#include <Trade/Trade.mqh>

//--- ENUMs for strategy settings
enum ENUM_ENTRY_METHOD { ENTRY_METHOD_RETEST, ENTRY_METHOD_BREAKOUT, ENTRY_METHOD_IMMEDIATE };
enum ENUM_MONEY_MANAGEMENT { MM_FIXED_LOT, MM_RISK_PERCENTAGE };

//--- EA Inputs (same as v4.3)
//--- SECTION: Safety Systems ---
input bool   InpUseLossLimit = true;
input int    InpMaxConsecutiveLosses = 15;
input int    InpPauseDurationHours = 24;

//--- SECTION: On-Chart Display ---
input bool   InpShowDisplayPanel = true;

//--- SECTION: Money Management ---
input ENUM_MONEY_MANAGEMENT InpMoneyManagement = MM_FIXED_LOT;
input double                 InpFixedLotSize = 0.01;
input double                 InpRiskPercent = 0.5;

//--- SECTION: Core Strategy ---
input ENUM_ENTRY_METHOD InpEntryMethod = ENTRY_METHOD_BREAKOUT;
input ENUM_TIMEFRAMES   InpTrendTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES   InpEntryTimeframe = PERIOD_M5;
input int               InpFastEMA_Period = 8;
input int               InpSlow1EMA_Period = 13;
input int               InpSlow2EMA_Period = 21;

//--- SECTION: Strategy Filters ---
input bool              InpUseDailyFilter = true;
input int               InpDailyEmaPeriod = 200;
input bool              InpUseAdxFilter = true;
input bool              InpUseDiCrossover = true;
input int               InpAdxPeriod = 14;
input double            InpAdxThreshold = 25.0;
input bool              InpUseSessionFilter = true;
input int               InpTradingStartHour = 8;
input int               InpTradingEndHour = 22;

//--- SECTION: Trade Execution ---
input int               InpBreakoutLookbackBars = 8;
input int               InpBreakoutOffsetPips = 3;
input bool              InpUseMultiTP = true;
input int               InpNumberOfPositions = 3;
input double            InpRR_TP1 = 1.0;
input double            InpRR_TP2 = 2.0;
input bool              InpMoveSLToBE_On_TP1 = true;
input int               InpMaxSpreadPoints = 30;
input ulong             InpMagicNumber = 202505;
input int               InpAtrPeriod = 14;
input double            InpAtrMultiplierSL = 2.0;
input bool              InpUseTrailingSL = true;
input double            InpTrailingAtrMultiplier = 2.5;

//--- Global variables ---
CTrade      trade;
// Indicator handles
int         h1_ema_fast_handle, h1_ema_slow1_handle, h1_ema_slow2_handle, h1_adx_handle;
int         m5_ema_fast_handle, m5_ema_slow1_handle, m5_ema_slow2_handle, m5_atr_handle;
int         d1_ema_handle;
// Data arrays
double      h1_ema_fast[], h1_ema_slow1[], h1_ema_slow2[];
double      h1_adx_main[], h1_adx_plus_di[], h1_adx_minus_di[];
double      m5_ema_fast[], m5_ema_slow1[], m5_ema_slow2[], m5_atr[];
MqlRates    h1_rates[], m5_rates[], d1_rates[];
double      d1_ema[];
// State management variables
int         g_consecutive_losses = 0;
datetime    g_trading_paused_until = 0;
string      g_ea_status = "Initializing...";
ulong       g_last_processed_deal_ticket = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing EA v4.4 (Proactive Management)...");
    trade.SetExpertMagicNumber(InpMagicNumber);
    // Initialize indicators (same as before)
    h1_ema_fast_handle = iMA(_Symbol, InpTrendTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow1_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow2_handle = iMA(_Symbol, InpTrendTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    h1_adx_handle = iADX(_Symbol, InpTrendTimeframe, InpAdxPeriod);
    m5_ema_fast_handle = iMA(_Symbol, InpEntryTimeframe, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow1_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow1EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_ema_slow2_handle = iMA(_Symbol, InpEntryTimeframe, InpSlow2EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    m5_atr_handle = iATR(_Symbol, InpEntryTimeframe, InpAtrPeriod);
    d1_ema_handle = iMA(_Symbol, PERIOD_D1, InpDailyEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    Print("EA Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function - NOW THE HUB FOR ALL ACTIONS               |
//+------------------------------------------------------------------+
void OnTick()
{
    // --- HIGH-FREQUENCY TASKS (Run every tick) ---
    if(PositionsTotal() > 0)
    {
        // Manage all open positions (BE, Trailing, etc.)
        ManageOpenPositions();
    }

    // --- LOW-FREQUENCY TASKS (Run once per new bar) ---
    static datetime last_bar_time = 0;
    datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, InpEntryTimeframe, SERIES_LASTBAR_DATE);
    if(current_bar_time <= last_bar_time) return;
    last_bar_time = current_bar_time;
    
    // Update display and check for new trade signals
    if(InpShowDisplayPanel) UpdateDisplayPanel();
    CheckForSignal();
}

//+------------------------------------------------------------------+
//|                 PROACTIVE TRADE MANAGEMENT HUB                   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    bool is_tp1_hit_this_tick = false;
    string set_comment_of_tp1_hit = "";

    // First loop: Check for TP1 hit and Trailing Stop
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket((uint)i);
        if(!PositionSelect(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

        // Check if a position has reached its breakeven target (TP1)
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double initial_sl = PositionGetDouble(POSITION_SL);
        double initial_tp = PositionGetDouble(POSITION_TP);
        long pos_type = PositionGetInteger(POSITION_TYPE);
        
        // This logic is for positions that have a TP set (i.e., the TP1 position)
        if(InpUseMultiTP && InpMoveSLToBE_On_TP1 && initial_tp > 0)
        {
            double current_price = (pos_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double risk_distance = MathAbs(open_price - initial_sl);
            double be_target_price = (pos_type == POSITION_TYPE_BUY) ? open_price + (risk_distance * InpRR_TP1) : open_price - (risk_distance * InpRR_TP1);

            if((pos_type == POSITION_TYPE_BUY && current_price >= be_target_price) ||
               (pos_type == POSITION_TYPE_SELL && current_price <= be_target_price))
            {
                is_tp1_hit_this_tick = true;
                set_comment_of_tp1_hit = PositionGetString(POSITION_COMMENT);
            }
        }
        
        // Manage Trailing Stop for all positions
        if(InpUseTrailingSL)
        {
            ManageTrailingStopForPosition(ticket);
        }
    }

    // Second loop: If a TP1 was hit, move all related positions to Breakeven
    if(is_tp1_hit_this_tick)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket((uint)i);
            if(!PositionSelect(ticket)) continue;
            
            if(PositionGetString(POSITION_COMMENT) == set_comment_of_tp1_hit &&
               PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN))
            {
                Print("Breakeven target hit for set ", set_comment_of_tp1_hit, ". Moving SL for ticket: ", (string)ticket);
                trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
            }
        }
    }
}

// Manages trailing stop for a SINGLE position
void ManageTrailingStopForPosition(ulong ticket)
{
    if(!CopyRates(_Symbol, InpEntryTimeframe, 0, 2, m5_rates) || !CopyBuffer(m5_atr_handle, 0, 0, 2, m5_atr)) return;
    ArraySetAsSeries(m5_rates, true);
    ArraySetAsSeries(m5_atr, true);

    if(PositionSelect(ticket))
    {
        long pos_type = PositionGetInteger(POSITION_TYPE);
        double current_sl = PositionGetDouble(POSITION_SL);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double atr_val = m5_atr[1];
        if(atr_val <= 0) return;

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


// --- All other functions (OnTrade, Signal Logic, etc.) remain the same ---
// They are included below for completeness
void OnTrade(){if(HistorySelect(0, TimeCurrent())){int total_history_deals = (int)HistoryDealsTotal();if(total_history_deals > 0){ulong last_deal_ticket = HistoryDealGetTicket((uint)total_history_deals - 1);if(last_deal_ticket != g_last_processed_deal_ticket){g_last_processed_deal_ticket = last_deal_ticket;if(HistoryDealGetInteger(last_deal_ticket, DEAL_MAGIC) == InpMagicNumber && HistoryDealGetInteger(last_deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT){static string last_loss_comment = "";string current_comment = HistoryDealGetString(last_deal_ticket, DEAL_COMMENT);if(HistoryDealGetDouble(last_deal_ticket, DEAL_PROFIT) < 0){if(current_comment != last_loss_comment){g_consecutive_losses++;last_loss_comment = current_comment;Print("Loss event recorded. Consecutive losses now: ", (string)g_consecutive_losses);}}else{if(g_consecutive_losses > 0){Print("Win recorded. Resetting loss count.");g_consecutive_losses = 0;}}}}}}}
void CheckForSignal(){if(!CopyAllData()){g_ea_status="Error: Cannot copy data";return;}if(IsTradingPaused()){DeletePendingOrders();return;}if(!IsTradingSessionActive()){g_ea_status="DISABLED - Outside Session";DeletePendingOrders();return;}if(PositionsTotal()>0){g_ea_status="Position is Open";return;}if(IsSpreadHigh()){g_ea_status="Spread is too high";return;}int major_trend=GetMajorTrend();int h1_trend=GetEMATrend();if(InpUseDailyFilter&&h1_trend!=major_trend&&h1_trend!=0){g_ea_status="DISABLED - D1/H1 Mismatch";DeletePendingOrders();return;}if(!IsSignalAllowed(h1_trend)){if(InpUseAdxFilter&&ArraySize(h1_adx_main)>1&&h1_adx_main[1]<InpAdxThreshold)g_ea_status="DISABLED - Sideways (ADX)";else if(InpUseDiCrossover)g_ea_status="DISABLED - DI not crossed";else g_ea_status="Signal Not Allowed";DeletePendingOrders();return;}if(h1_trend==0){g_ea_status="WAITING - No H1 Trend";DeletePendingOrders();return;}g_ea_status="WAITING FOR ENTRY SIGNAL...";switch(InpEntryMethod){case ENTRY_METHOD_IMMEDIATE:CheckImmediateEntry(h1_trend);break;case ENTRY_METHOD_RETEST:CheckRetestEntry(h1_trend);break;case ENTRY_METHOD_BREAKOUT:CheckBreakoutEntry(h1_trend);break;}}
bool IsTradingPaused(){if(!InpUseLossLimit)return false;if(g_trading_paused_until>0&&g_trading_paused_until<=TimeCurrent()){Print("Trading pause has ended. Resuming operation and resetting loss count.");g_consecutive_losses=0;g_trading_paused_until=0;return false;}if(g_trading_paused_until>TimeCurrent()){long rem_sec=g_trading_paused_until-TimeCurrent();g_ea_status="PAUSED - "+(string)(rem_sec/60)+" min remaining";return true;}if(g_consecutive_losses>=InpMaxConsecutiveLosses){g_trading_paused_until=TimeCurrent()+(InpPauseDurationHours*3600);Print("Max consecutive losses of ",(string)InpMaxConsecutiveLosses," reached. Pausing trading for ",(string)InpPauseDurationHours," hours.");g_ea_status="PAUSED - Max Losses Hit";return true;}return false;}
int GetMajorTrend(){if(!InpUseDailyFilter)return 0;if(ArraySize(d1_rates)<2||ArraySize(d1_ema)<2)return 0;if(d1_rates[1].close>d1_ema[1])return 1;if(d1_rates[1].close<d1_ema[1])return -1;return 0;}
bool IsSignalAllowed(int trend_direction){if(InpUseAdxFilter){if(ArraySize(h1_adx_main)<2)return false;if(h1_adx_main[1]<InpAdxThreshold)return false;}if(InpUseDiCrossover){if(ArraySize(h1_adx_plus_di)<2||ArraySize(h1_adx_minus_di)<2)return false;if(trend_direction==1&&h1_adx_plus_di[1]<=h1_adx_minus_di[1])return false;if(trend_direction==-1&&h1_adx_minus_di[1]<=h1_adx_plus_di[1])return false;}return true;}
int GetEMATrend(){if(ArraySize(h1_ema_fast)<2)return 0;bool is_uptrend=h1_ema_fast[1]>h1_ema_slow2[1]&&h1_ema_slow1[1]>h1_ema_slow2[1];bool is_downtrend=h1_ema_fast[1]<h1_ema_slow2[1]&&h1_ema_slow1[1]<h1_ema_slow2[1];if(is_uptrend)return 1;if(is_downtrend)return -1;return 0;}
bool IsTradingSessionActive(){if(!InpUseSessionFilter)return true;MqlDateTime t;TimeCurrent(t);if(InpTradingStartHour>InpTradingEndHour){if(t.hour>=InpTradingStartHour||t.hour<InpTradingEndHour)return true;}else{if(t.hour>=InpTradingStartHour&&t.hour<InpTradingEndHour)return true;}return false;}
bool IsSpreadHigh(){return(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints);}
void CheckImmediateEntry(int h1_trend){bool b=m5_ema_fast[1]>m5_ema_slow1[1]&&m5_ema_fast[2]<=m5_ema_slow1[2];bool s=m5_ema_fast[1]<m5_ema_slow1[1]&&m5_ema_fast[2]>=m5_ema_slow1[2];if(h1_trend==1&&b)PlaceOrderSet(ORDER_TYPE_BUY,0);if(h1_trend==-1&&s)PlaceOrderSet(ORDER_TYPE_SELL,0);}
void CheckRetestEntry(int h1_trend){bool u=m5_ema_fast[1]>m5_ema_slow1[1]&&m5_ema_slow1[1]>m5_ema_slow2[1];bool d=m5_ema_fast[1]<m5_ema_slow1[1]&&m5_ema_slow1[1]<m5_ema_slow2[1];if(h1_trend==1&&u){if(m5_rates[1].low<=m5_ema_fast[1]||m5_rates[1].low<=m5_ema_slow1[1])PlaceOrderSet(ORDER_TYPE_BUY,0);}if(h1_trend==-1&&d){if(m5_rates[1].high>=m5_ema_fast[1]||m5_rates[1].high>=m5_ema_slow1[1])PlaceOrderSet(ORDER_TYPE_SELL,0);}}
void CheckBreakoutEntry(int h1_trend){bool u=m5_ema_fast[1]>m5_ema_slow1[1]&&m5_ema_slow1[1]>m5_ema_slow2[1];bool d=m5_ema_fast[1]<m5_ema_slow1[1]&&m5_ema_slow1[1]<m5_ema_slow2[1];DeletePendingOrders();if(h1_trend==1&&u){double h=FindSwingHigh(InpBreakoutLookbackBars);if(h>0){double p=h+InpBreakoutOffsetPips*_Point;PlaceOrderSet(ORDER_TYPE_BUY_STOP,p);}}if(h1_trend==-1&&d){double l=FindSwingLow(InpBreakoutLookbackBars);if(l>0){double p=l-InpBreakoutOffsetPips*_Point;PlaceOrderSet(ORDER_TYPE_SELL_STOP,p);}}}
double CalculateLotSize(double sl_pips){if(InpMoneyManagement==MM_FIXED_LOT)return InpFixedLotSize;double risk_pct=InpRiskPercent;double risk_amt=AccountInfoDouble(ACCOUNT_BALANCE)*(risk_pct/100.0);double tick_val=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);if(tick_val<=0||tick_size<=0||sl_pips<=0)return InpFixedLotSize;double loss_lot=(sl_pips*_Point)/tick_size*tick_val;if(loss_lot<=0)return InpFixedLotSize;double lot=risk_amt/loss_lot;double min_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);double max_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);double step_l=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);lot=MathFloor(lot/step_l)*step_l;if(lot<min_l)lot=min_l;if(lot>max_l)lot=max_l;return lot;}
void PlaceOrderSet(ENUM_ORDER_TYPE order_type,double entry_price=0){if(IsSpreadHigh())return;if(entry_price==0&&(order_type==ORDER_TYPE_BUY||order_type==ORDER_TYPE_SELL)){entry_price=SymbolInfoDouble(_Symbol,order_type==ORDER_TYPE_BUY?SYMBOL_ASK:SYMBOL_BID);}if(entry_price==0)return;double atr=m5_atr[1];if(atr<=0)return;double risk_dist=atr*InpAtrMultiplierSL;double min_stop_points=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);if(min_stop_points>0){double min_risk_dist=min_stop_points*_Point;if(risk_dist<min_risk_dist){risk_dist=min_risk_dist;}}double sl;if(order_type==ORDER_TYPE_BUY||order_type==ORDER_TYPE_BUY_STOP||order_type==ORDER_TYPE_BUY_LIMIT)sl=entry_price-risk_dist;else sl=entry_price+risk_dist;double sl_pips=MathAbs(entry_price-sl)/_Point;string comment="JYS_v4.4_"+(string)TimeCurrent();int num_pos=InpUseMultiTP?InpNumberOfPositions:1;for(int i=0;i<num_pos;i++){double lot=CalculateLotSize(sl_pips);if(lot<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))continue;double tp=0;if(InpUseMultiTP){if(i==0&&InpRR_TP1>0){tp=(order_type==ORDER_TYPE_BUY||order_type==ORDER_TYPE_BUY_STOP||order_type==ORDER_TYPE_BUY_LIMIT)?entry_price+(risk_dist*InpRR_TP1):entry_price-(risk_dist*InpRR_TP1);}else if(i==1&&num_pos>2&&InpRR_TP2>0){tp=(order_type==ORDER_TYPE_BUY||order_type==ORDER_TYPE_BUY_STOP||order_type==ORDER_TYPE_BUY_LIMIT)?entry_price+(risk_dist*InpRR_TP2):entry_price-(risk_dist*InpRR_TP2);}}switch(order_type){case ORDER_TYPE_BUY:trade.Buy(lot,_Symbol,entry_price,sl,tp,comment);break;case ORDER_TYPE_SELL:trade.Sell(lot,_Symbol,entry_price,sl,tp,comment);break;case ORDER_TYPE_BUY_STOP:trade.BuyStop(lot,entry_price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);break;case ORDER_TYPE_SELL_STOP:trade.SellStop(lot,entry_price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);break;case ORDER_TYPE_BUY_LIMIT:trade.BuyLimit(lot,entry_price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);break;case ORDER_TYPE_SELL_LIMIT:trade.SellLimit(lot,entry_price,_Symbol,sl,tp,ORDER_TIME_GTC,0,comment);break;}}}
void ManageBreakeven(){} // Logic is now in ManageOpenPositions
void OnDeinit(const int reason){ObjectDelete(0,"StatusPanel_BG");ObjectDelete(0,"StatusPanel_Text");Print("Deinitializing EA v4.4. Reason: ",(string)reason);if(reason!=REASON_CHARTCLOSE){DeletePendingOrders();}}
double FindSwingHigh(int bars){double h=0;for(int i=1;i<=bars&&i<ArraySize(m5_rates);i++){if(m5_rates[i].high>h)h=m5_rates[i].high;}return h;}
double FindSwingLow(int bars){if(ArraySize(m5_rates)<2)return 0;double l=m5_rates[1].low;for(int i=2;i<=bars&&i<ArraySize(m5_rates);i++){if(m5_rates[i].low<l)l=m5_rates[i].low;}return l;}
void DeletePendingOrders(){for(int i=OrdersTotal()-1;i>=0;i--){ulong t=OrderGetTicket((uint)i);if(OrderSelect(t)){if(OrderGetInteger(ORDER_MAGIC)==InpMagicNumber&&OrderGetString(ORDER_SYMBOL)==_Symbol){trade.OrderDelete(t);}}}}
bool CopyAllData(){int bh1=3;int bm5=InpBreakoutLookbackBars+3;if(CopyRates(_Symbol,InpTrendTimeframe,0,bh1,h1_rates)<bh1||CopyRates(_Symbol,InpEntryTimeframe,0,bm5,m5_rates)<bm5)return false;if(CopyBuffer(h1_ema_fast_handle,0,0,bh1,h1_ema_fast)<bh1||CopyBuffer(h1_ema_slow1_handle,0,0,bh1,h1_ema_slow1)<bh1||CopyBuffer(h1_ema_slow2_handle,0,0,bh1,h1_ema_slow2)<bh1||CopyBuffer(h1_adx_handle,0,0,bh1,h1_adx_main)<bh1||CopyBuffer(h1_adx_handle,1,0,bh1,h1_adx_plus_di)<bh1||CopyBuffer(h1_adx_handle,2,0,bh1,h1_adx_minus_di)<bh1)return false;if(CopyBuffer(m5_ema_fast_handle,0,0,bm5,m5_ema_fast)<bm5||CopyBuffer(m5_ema_slow1_handle,0,0,bm5,m5_ema_slow1)<bm5||CopyBuffer(m5_ema_slow2_handle,0,0,bm5,m5_ema_slow2)<bm5||CopyBuffer(m5_atr_handle,0,0,2,m5_atr)<2)return false;if(InpUseDailyFilter){if(CopyRates(_Symbol,PERIOD_D1,0,2,d1_rates)<2||CopyBuffer(d1_ema_handle,0,0,2,d1_ema)<2)return false;ArraySetAsSeries(d1_rates,true);ArraySetAsSeries(d1_ema,true);}ArraySetAsSeries(h1_rates,true);ArraySetAsSeries(m5_rates,true);ArraySetAsSeries(h1_ema_fast,true);ArraySetAsSeries(h1_ema_slow1,true);ArraySetAsSeries(h1_ema_slow2,true);ArraySetAsSeries(h1_adx_main,true);ArraySetAsSeries(h1_adx_plus_di,true);ArraySetAsSeries(h1_adx_minus_di,true);ArraySetAsSeries(m5_ema_fast,true);ArraySetAsSeries(m5_ema_slow1,true);ArraySetAsSeries(m5_ema_slow2,true);ArraySetAsSeries(m5_atr,true);return true;}
void UpdateDisplayPanel(){ObjectCreate(0,"StatusPanel_BG",OBJ_RECTANGLE_LABEL,0,0,0);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XDISTANCE,5);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YDISTANCE,10);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_XSIZE,220);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_YSIZE,120);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_COLOR,clrBlack);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_BACK,true);ObjectSetInteger(0,"StatusPanel_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);string pt="--- Jinguo Ye Strategy v4.4 ---\n\n";pt+="EA Status: "+g_ea_status+"\n\n";string d1t="N/A";if(InpUseDailyFilter){int dt=GetMajorTrend();if(dt==1)d1t="UP";else if(dt==-1)d1t="DOWN";else d1t="Neutral";}string h1r="N/A";if(InpUseAdxFilter){if(ArraySize(h1_adx_main)>1&&h1_adx_main[1]>=InpAdxThreshold)h1r="Trending";else h1r="Sideways";}pt+="Major Trend (D1): "+d1t+"\n";pt+="Market Regime (H1): "+h1r+"\n\n";pt+="Consecutive Losses: "+(string)g_consecutive_losses+"/"+(string)InpMaxConsecutiveLosses;ObjectCreate(0,"StatusPanel_Text",OBJ_LABEL,0,0,0);ObjectSetString(0,"StatusPanel_Text",OBJPROP_TEXT,pt);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_XDISTANCE,10);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_YDISTANCE,15);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_COLOR,clrLime);ObjectSetInteger(0,"StatusPanel_Text",OBJPROP_FONTSIZE,10);}

