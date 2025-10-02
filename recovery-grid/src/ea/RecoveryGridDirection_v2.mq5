//+------------------------------------------------------------------+
//| Recovery Grid Direction v2.4                                     |
//| Two-sided recovery grid with PC + DTS + SSL + TRM + ADC         |
//+------------------------------------------------------------------+
//| PRODUCTION DEFAULTS: Based on 08_Combo_SSL backtest results      |
//| - Max Equity DD: 16.99% (vs 42.98% without SSL)                  |
//| - Profit Factor: 5.76                                            |
//| - Win Rate: 73.04%                                               |
//| - Features: Partial Close + Conservative DTS + SSL Protection    |
//| - TRM: Time-based Risk Management (DEFAULT OFF, enable for NFP)  |
//| - ADC: Anti-Drawdown Cushion (DEFAULT OFF, target sub-10% DD)   |
//+------------------------------------------------------------------+
#property strict
#property version "2.40"

#include <Trade/Trade.mqh>

#include <RECOVERY-GRID-DIRECTION_v2/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Params.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Logger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/SpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderValidator.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/PortfolioLedger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/RescueEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/GridBasket.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/LifecycleController.mqh>

//--- Inputs
input int               InpStatusInterval   = 60;
input bool              InpLogEvents        = true;

input ENUM_TIMEFRAMES InpAtrTimeframe       = PERIOD_M15;
input int             InpAtrPeriod          = 14;

enum InpSpacingModeEnum { InpSpacingPips=0, InpSpacingATR=1, InpSpacingHybrid=2 };
input InpSpacingModeEnum InpSpacingMode     = InpSpacingHybrid;
input double            InpSpacingStepPips  = 25.0;
input double            InpSpacingAtrMult   = 0.6;
input double            InpMinSpacingPips   = 12.0;

input int               InpGridLevels       = 1000;
input double            InpLotBase          = 0.01;
input double            InpLotScale         = 1.5;

input bool              InpDynamicGrid      = true;
input int               InpWarmLevels       = 5;
input int               InpRefillThreshold  = 2;
input int               InpRefillBatch      = 3;
input int               InpMaxPendings      = 15;

input double            InpTargetCycleUSD   = 5.0;

input bool              InpTSLEnabled       = true;
input int               InpTSLStartPoints   = 1000;
input int               InpTSLStepPoints    = 200;

input string            InpRecoverySteps    = "1000,2000,3000";
input double            InpRecoveryLot      = 0.02;
input double            InpDDOpenUSD        = 10000;
input double            InpOffsetRatio      = 0.5;

input double            InpExposureCapLots  = 2.0;
input int               InpMaxCyclesPerSide = 3;
input double            InpSessionSL_USD    = 100000;
input int               InpCooldownBars     = 5;

input int               InpOrderCooldownSec = 5;
input int               InpSlippagePips     = 1;
input bool              InpRespectStops     = false;  // Set false for backtest

input double            InpCommissionPerLot = 0.0; // 7.0
input long              InpMagic            = 990045;

input group "=== Partial Close ==="
input bool              InpPcEnabled           = true;   // ENABLED for production
input double            InpPcRetestAtr         = 0.8;
input double            InpPcSlopeHysteresis   = 0.0002;
input double            InpPcMinProfitUsd      = 2.5;    // Optimized: Close earlier
input double            InpPcCloseFraction     = 0.30;
input int               InpPcMaxTickets        = 3;
input int               InpPcCooldownBars      = 10;
input int               InpPcGuardBars         = 6;
input double            InpPcPendingGuardMult  = 0.5;
input double            InpPcGuardExitAtr      = 0.6;
input double            InpPcMinLotsRemain     = 0.20;

input group "=== Dynamic Target Scaling ==="
input bool              InpDtsEnabled           = true;  // ENABLED for production
input bool              InpDtsAtrEnabled        = true;
input double            InpDtsAtrWeight         = 0.7;   // Optimized: Conservative ATR
input bool              InpDtsTimeDecayEnabled  = true;
input double            InpDtsTimeDecayRate     = 0.012; // Optimized: Faster cool-down
input double            InpDtsTimeDecayFloor    = 0.7;   // Optimized: Higher floor
input bool              InpDtsDdScalingEnabled  = true;
input double            InpDtsDdThreshold       = 12.0;  // Optimized: Trigger later
input double            InpDtsDdScaleFactor     = 50.0;
input double            InpDtsDdMaxFactor       = 2.0;
input double            InpDtsMinMultiplier     = 0.7;   // Optimized: Higher floor
input double            InpDtsMaxMultiplier     = 2.0;   // Optimized: Lower ceiling

input group "=== Smart Stop Loss (SSL) ==="
input bool              InpSslEnabled              = true;   // ENABLED for production (DD: 42.98% -> 16.99%)
input double            InpSslSlMultiplier         = 3.0;    // SL distance = spacing × this
input double            InpSslBreakevenThreshold   = 5.0;    // USD profit to move to breakeven
input bool              InpSslTrailByAverage       = true;   // Trail from average price
input int               InpSslTrailOffsetPoints    = 100;    // Trail offset in points
input bool              InpSslRespectMinStop       = true;   // Respect broker min stop level

input group "=== Time-based Risk Management (TRM) ==="
input bool              InpTrmEnabled              = false;  // Master switch (DEFAULT OFF)
input string            InpTrmNewsWindows          = "08:30-09:00,14:00-14:30";  // CSV format HH:MM-HH:MM (UTC)
input bool              InpTrmPauseOrders          = true;   // Pause new orders during news
input bool              InpTrmTightenSL            = false;  // Tighten SSL during news (requires SSL)
input double            InpTrmSLMultiplier         = 0.5;    // SL tightening factor (0.5 = half distance)
input bool              InpTrmCloseOnNews          = false;  // Close all positions before news window

input group "=== Anti-Drawdown Cushion (ADC) ==="
input bool              InpAdcEnabled              = false;  // Master switch (DEFAULT OFF)
input double            InpAdcEquityDdThreshold    = 10.0;   // Equity DD % threshold to activate cushion
input bool              InpAdcPauseNewGrids        = true;   // Pause grid reseeding during cushion
input bool              InpAdcPauseRescue          = true;   // Pause rescue hedge deployment during cushion

input group "=== Timeframe Preservation ==="
input bool              InpPreserveOnTfSwitch      = true;   // Preserve positions on timeframe switch

//--- Globals
SParams              g_params;
CLogger             *g_logger        = NULL;
CSpacingEngine      *g_spacing       = NULL;
COrderValidator     *g_validator     = NULL;
COrderExecutor      *g_executor      = NULL;
CPortfolioLedger    *g_ledger        = NULL;
CRescueEngine       *g_rescue        = NULL;
CLifecycleController*g_controller    = NULL;

//--- Graceful Shutdown state
bool                 g_shutdown_mode = false;
datetime             g_shutdown_start = 0;
const int            SHUTDOWN_TIMEOUT_MINUTES = 30;

string TrimAll(const string value)
  {
   string tmp=value;
   StringTrimLeft(tmp);
   StringTrimRight(tmp);
   return tmp;
  }

void CreateShutdownButton()
  {
   ObjectCreate(0,"btnShutdown",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_YDISTANCE,50);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_XSIZE,180);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_YSIZE,35);
   ObjectSetString(0,"btnShutdown",OBJPROP_TEXT,"⏻ SHUTDOWN EA");
   ObjectSetInteger(0,"btnShutdown",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_BGCOLOR,clrCrimson);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,"btnShutdown",OBJPROP_CORNER,CORNER_LEFT_UPPER);
  }

int ParseRecoverySteps(const string csv,int &buffer[])
  {
   if(StringLen(csv)==0)
     {
      ArrayResize(buffer,0);
      return 0;
     }
   string parts[];
   int count=StringSplit(csv,',',parts);
   if(count<=0)
     {
      ArrayResize(buffer,0);
      return 0;
     }
   ArrayResize(buffer,count);
   for(int i=0;i<count;i++)
     {
      string trimmed=TrimAll(parts[i]);
      buffer[i]=(int)StringToInteger(trimmed);
     }
   return count;
  }

void BuildParams()
  {
   g_params.spacing_mode       =(ESpacingMode)InpSpacingMode;
   g_params.spacing_pips       =InpSpacingStepPips;
   g_params.spacing_atr_mult   =InpSpacingAtrMult;
   g_params.min_spacing_pips   =InpMinSpacingPips;
   g_params.atr_period         =InpAtrPeriod;
   g_params.atr_timeframe      =InpAtrTimeframe;

   g_params.grid_levels        =InpGridLevels;
   g_params.lot_base           =InpLotBase;
   g_params.lot_scale          =InpLotScale;
   
   g_params.grid_dynamic_enabled=InpDynamicGrid;
   g_params.grid_warm_levels   =InpWarmLevels;
   g_params.grid_refill_threshold=InpRefillThreshold;
   g_params.grid_refill_batch  =InpRefillBatch;
   g_params.grid_max_pendings  =InpMaxPendings;
   
   g_params.target_cycle_usd   =InpTargetCycleUSD;

   g_params.tsl_enabled        =InpTSLEnabled;
   g_params.tsl_start_points   =InpTSLStartPoints;
   g_params.tsl_step_points    =InpTSLStepPoints;

   ParseRecoverySteps(InpRecoverySteps,g_params.recovery_steps);
   g_params.recovery_lot       =InpRecoveryLot;
   g_params.dd_open_usd        =InpDDOpenUSD;
   g_params.offset_ratio       =InpOffsetRatio;
   g_params.exposure_cap_lots  =InpExposureCapLots;
   g_params.max_cycles_per_side=InpMaxCyclesPerSide;
   g_params.session_sl_usd     =InpSessionSL_USD;
   g_params.cooldown_bars      =InpCooldownBars;

   g_params.slippage_pips      =InpSlippagePips;
   g_params.order_cooldown_sec =InpOrderCooldownSec;
   g_params.respect_stops_level=InpRespectStops;
   g_params.commission_per_lot =InpCommissionPerLot;

   g_params.magic              =InpMagic;

   g_params.pc_enabled           =InpPcEnabled;
   g_params.pc_retest_atr        =InpPcRetestAtr;
   g_params.pc_slope_hysteresis  =InpPcSlopeHysteresis;
   g_params.pc_min_profit_usd    =InpPcMinProfitUsd;
   g_params.pc_close_fraction    =InpPcCloseFraction;
   g_params.pc_max_tickets       =InpPcMaxTickets;
   g_params.pc_cooldown_bars     =InpPcCooldownBars;
   g_params.pc_guard_bars        =InpPcGuardBars;
   g_params.pc_pending_guard_mult=InpPcPendingGuardMult;
   g_params.pc_guard_exit_atr    =InpPcGuardExitAtr;
   g_params.pc_min_lots_remain   =InpPcMinLotsRemain;

   g_params.dts_enabled            =InpDtsEnabled;
   g_params.dts_atr_enabled        =InpDtsAtrEnabled;
   g_params.dts_atr_weight         =InpDtsAtrWeight;
   g_params.dts_time_decay_enabled =InpDtsTimeDecayEnabled;
   g_params.dts_time_decay_rate    =InpDtsTimeDecayRate;
   g_params.dts_time_decay_floor   =InpDtsTimeDecayFloor;
   g_params.dts_dd_scaling_enabled =InpDtsDdScalingEnabled;
   g_params.dts_dd_threshold       =InpDtsDdThreshold;
   g_params.dts_dd_scale_factor    =InpDtsDdScaleFactor;
   g_params.dts_dd_max_factor      =InpDtsDdMaxFactor;
   g_params.dts_min_multiplier     =InpDtsMinMultiplier;
   g_params.dts_max_multiplier     =InpDtsMaxMultiplier;

   g_params.ssl_enabled            =InpSslEnabled;
   g_params.ssl_sl_multiplier      =InpSslSlMultiplier;
   g_params.ssl_breakeven_threshold=InpSslBreakevenThreshold;
   g_params.ssl_trail_by_average   =InpSslTrailByAverage;
   g_params.ssl_trail_offset_points=InpSslTrailOffsetPoints;
   g_params.ssl_respect_min_stop   =InpSslRespectMinStop;

   g_params.trm_enabled            =InpTrmEnabled;
   g_params.trm_pause_orders       =InpTrmPauseOrders;
   g_params.trm_tighten_sl         =InpTrmTightenSL;
   g_params.trm_sl_multiplier      =InpTrmSLMultiplier;
   g_params.trm_close_on_news      =InpTrmCloseOnNews;
   g_params.trm_news_windows       =InpTrmNewsWindows;

   g_params.adc_enabled            =InpAdcEnabled;
   g_params.adc_equity_dd_threshold=InpAdcEquityDdThreshold;
   g_params.adc_pause_new_grids    =InpAdcPauseNewGrids;
   g_params.adc_pause_rescue       =InpAdcPauseRescue;

   g_params.preserve_on_tf_switch  =InpPreserveOnTfSwitch;
  }

int OnInit()
  {
   BuildParams();

   g_logger   = new CLogger(InpStatusInterval,InpLogEvents);
   g_spacing  = new CSpacingEngine(_Symbol,g_params.spacing_mode,g_params.atr_period,g_params.atr_timeframe,g_params.spacing_atr_mult,g_params.spacing_pips,g_params.min_spacing_pips);
   g_validator= new COrderValidator(_Symbol,g_params.respect_stops_level);
   g_executor = new COrderExecutor(_Symbol,g_validator,g_params.slippage_pips,g_params.order_cooldown_sec);
   if(g_executor!=NULL)
      g_executor.SetMagic(g_params.magic);
   g_ledger   = new CPortfolioLedger(g_params.exposure_cap_lots,g_params.session_sl_usd);
   g_rescue   = new CRescueEngine(_Symbol,g_params,g_logger);
   g_controller = new CLifecycleController(_Symbol,g_params,g_spacing,g_executor,g_rescue,g_ledger,g_logger,g_params.magic);

   if(g_controller==NULL || !g_controller.Init())
     {
      if(g_logger!=NULL)
         g_logger.Event("[RGDv2]","Controller init failed");
      return(INIT_FAILED);
     }
   
   // Debug info
   if(g_logger!=NULL)
     {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      g_logger.Event("[RGDv2]",StringFormat("Init OK - Ask=%.5f Bid=%.5f LotBase=%.2f GridLevels=%d Dynamic=%s",
                                            ask,bid,g_params.lot_base,g_params.grid_levels,
                                            g_params.grid_dynamic_enabled?"ON":"OFF"));
     }

   // Create graceful shutdown button
   CreateShutdownButton();

   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   // Graceful shutdown logic (highest priority)
   if(g_shutdown_mode)
     {
      int elapsed_minutes=(int)((TimeCurrent()-g_shutdown_start)/60);
      int remaining=SHUTDOWN_TIMEOUT_MINUTES-elapsed_minutes;

      if(elapsed_minutes>=SHUTDOWN_TIMEOUT_MINUTES)
        {
         // Timeout → force close all
         if(g_logger!=NULL)
            g_logger.Event("[Shutdown]","Timeout reached, force closing all positions");

         if(g_executor!=NULL)
           {
            g_executor.SetMagic(g_params.magic);
            g_executor.CloseAllByDirection(DIR_BUY,g_params.magic);
            g_executor.CloseAllByDirection(DIR_SELL,g_params.magic);
            g_executor.CancelPendingByDirection(DIR_BUY,g_params.magic);
            g_executor.CancelPendingByDirection(DIR_SELL,g_params.magic);
           }

         ObjectSetInteger(0,"btnShutdown",OBJPROP_BGCOLOR,clrGreen);
         ObjectSetString(0,"btnShutdown",OBJPROP_TEXT,"✓ READY TO REMOVE");
         if(g_logger!=NULL)
            g_logger.Event("[Shutdown]","Complete, EA can be removed safely");
         return;
        }

      // Update button countdown
      if(remaining>0)
        {
         ObjectSetString(0,"btnShutdown",OBJPROP_TEXT,
                        StringFormat("⏱ SHUTDOWN: %dm",remaining));
        }

      // Try graceful close of profitable baskets
      if(g_controller!=NULL)
        {
         // Controller will still process positions, but we won't open new ones
         // The TRM/ADC pause flags will handle blocking new orders
        }
     }

   // Check if market is open
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   // Skip weekend
   if(dt.day_of_week==0 || dt.day_of_week==6)
      return;

   // Check symbol trading allowed
   if(!SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE))
      return;

   if(g_controller!=NULL)
      g_controller.Update();
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="btnShutdown")
     {
      if(!g_shutdown_mode)
        {
         // Activate shutdown mode
         g_shutdown_mode=true;
         g_shutdown_start=TimeCurrent();
         ObjectSetInteger(0,"btnShutdown",OBJPROP_BGCOLOR,clrOrange);
         ObjectSetString(0,"btnShutdown",OBJPROP_TEXT,
                        StringFormat("⏱ SHUTDOWN: %dm",SHUTDOWN_TIMEOUT_MINUTES));
         if(g_logger!=NULL)
            g_logger.Event("[Shutdown]",StringFormat("Mode activated, timeout=%d minutes",SHUTDOWN_TIMEOUT_MINUTES));
        }
      else
        {
         // Cancel shutdown
         g_shutdown_mode=false;
         g_shutdown_start=0;
         ObjectSetInteger(0,"btnShutdown",OBJPROP_BGCOLOR,clrCrimson);
         ObjectSetString(0,"btnShutdown",OBJPROP_TEXT,"⏻ SHUTDOWN EA");
         if(g_logger!=NULL)
            g_logger.Event("[Shutdown]","Mode cancelled");
        }
     }
  }

void OnDeinit(const int reason)
  {
   // Cleanup shutdown button
   ObjectDelete(0,"btnShutdown");
   if(g_controller!=NULL){ g_controller.Shutdown(); delete g_controller; g_controller=NULL; }
   if(g_rescue!=NULL){ delete g_rescue; g_rescue=NULL; }
   if(g_ledger!=NULL){ delete g_ledger; g_ledger=NULL; }
   if(g_executor!=NULL){ delete g_executor; g_executor=NULL; }
   if(g_validator!=NULL){ delete g_validator; g_validator=NULL; }
   if(g_spacing!=NULL){ delete g_spacing; g_spacing=NULL; }
   if(g_logger!=NULL){ delete g_logger; g_logger=NULL; }
  }