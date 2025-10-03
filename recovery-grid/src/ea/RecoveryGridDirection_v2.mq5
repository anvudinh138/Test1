//+------------------------------------------------------------------+
//| Recovery Grid Direction v2.7                                     |
//| Two-sided recovery grid with DTS + SSL + TRM + ADC + Rescue v3  |
//+------------------------------------------------------------------+
//| PRODUCTION DEFAULTS: Rescue v3 Delta-Based (PC removed)          |
//| - Rescue v3: Delta-based continuous rebalancing                  |
//| - Symbol Presets: 10 presets for easy optimization (NEW)         |
//| - Features: Conservative DTS + SSL Protection                    |
//| - TRM: Time-based Risk Management (DEFAULT OFF, enable for NFP)  |
//| - ADC: Anti-Drawdown Cushion (DEFAULT OFF, target sub-10% DD)   |
//| - PC: Partial Close REMOVED (incompatible with Grid DCA)         |
//+------------------------------------------------------------------+
#property strict
#property version "2.70"

#include <Trade/Trade.mqh>

#include <RECOVERY-GRID-DIRECTION_v2/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Params.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Logger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/NewsCalendar.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/SpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderValidator.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/PortfolioLedger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/RescueEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/GridBasket.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/LifecycleController.mqh>

//--- Inputs
input group "=== IMPORTANT: Set Unique Magic Number ==="
input long              InpMagic            = 990045;  // ⚠️ CHANGE THIS for each symbol/chart!

input group "=== Symbol Preset (For Optimization) ==="
enum SymbolPresetEnum
  {
   PRESET_CUSTOM      = 0,  // Auto-detect OR use manual params
   PRESET_EURUSD      = 1,  // Force EURUSD params (Med Vol)
   PRESET_GBPUSD      = 2,  // Force GBPUSD params (Med Vol)
   PRESET_USDJPY      = 3,  // Force USDJPY params (Med Vol)
   PRESET_USDCHF      = 4,  // Force USDCHF params (Low Vol)
   PRESET_EURCHF      = 5,  // Force EURCHF params (Low Vol)
   PRESET_GBPJPY      = 6,  // Force GBPJPY params (High Vol)
   PRESET_XAUUSD      = 7,  // Force XAUUSD params (High Vol)
   PRESET_AUDUSD      = 8,  // Force AUDUSD params (Med Vol)
   PRESET_NZDUSD      = 9,  // Force NZDUSD params (Med Vol)
   PRESET_USDCAD      = 10  // Force USDCAD params (Med Vol)
  };
input SymbolPresetEnum  InpSymbolPreset     = PRESET_CUSTOM;  // Preset Mode (0=Auto, 1-10=Force)

input int               InpStatusInterval   = 60;
input bool              InpLogEvents        = true;

input group "=== Grid Configuration ==="
enum InpSpacingModeEnum { InpSpacingPips=0, InpSpacingATR=1, InpSpacingHybrid=2 };
input InpSpacingModeEnum InpSpacingMode     = InpSpacingHybrid;  // Grid spacing method
input double            InpSpacingStepPips  = 8.0;   // PIPS mode: Fixed step
input double            InpSpacingAtrMult   = 0.8;   // ATR/HYBRID: ATR multiplier
input double            InpMinSpacingPips   = 5.0;   // ATR/HYBRID: Min spacing floor

input ENUM_TIMEFRAMES InpAtrTimeframe       = PERIOD_M15;  // ATR calculation timeframe
input int             InpAtrPeriod          = 14;          // ATR period

input int               InpGridLevels       = 1000;  // Max grid levels (high = infinite)
input bool              InpDynamicGrid      = true;  // ✅ Dynamic refill (recommended)
input int               InpWarmLevels       = 5;     // Initial pendings per basket
input int               InpRefillThreshold  = 2;     // Refill when pendings drop to this
input int               InpRefillBatch      = 3;     // Add this many pendings per refill
input int               InpMaxPendings      = 15;    // Max pending orders per basket

input group "=== Lot Sizing ==="
input double            InpLotBase          = 0.01;  // First grid level lot
input double            InpLotOffset        = 0.02;  // Linear increment per level

input group "=== Lot % Risk (Auto Lot Sizing) ==="
input bool              InpLotPercentEnabled = false;  // ✅ Enable lot % risk calculation
input double            InpLotPercentRisk    = 1.0;    // % of account balance to risk per level
input double            InpLotPercentMaxLot  = 1.0;    // Max lot size cap for % risk

input group "=== Take Profit & TSL ==="
input double            InpTargetCycleUSD   = 5.0;   // Group TP target (USD)
input bool              InpTSLEnabled       = true;  // ✅ Enable TSL on rescue hedge
input int               InpTSLStartPoints   = 1000;  // TSL activation threshold
input int               InpTSLStepPoints    = 200;   // TSL step size

input group "=== Rescue/Hedge System v3 (Delta + Cooldown) ==="
input bool              InpRescueAdaptiveLot   = true;   // ✅ Enable delta-based rescue
input double            InpMinDeltaTrigger     = 0.02;   // Min imbalance to trigger (lot)
input double            InpRescueLotMultiplier = 1;    // Delta multiplier (1.0 = 100%)
input double            InpRescueMaxLot        = 0.1;   // Max per rescue deployment
input int               InpRescueCooldownBars  = 3;      // Bars between rescues (anti-spam)

input group "=== Risk Management ==="
input double            InpExposureCapLots  = 2.0;     // Max total lot exposure
input double            InpSessionSL_USD    = 100000;  // Session stop loss (USD)

input int               InpOrderCooldownSec = 5;
input int               InpSlippagePips     = 1;
input bool              InpRespectStops     = false;  // Set false for backtest

input double            InpCommissionPerLot = 0.0;

input group "=== Dynamic Target Scaling ==="
input bool              InpDtsEnabled           = false;  // ENABLED for production
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
input bool              InpSslEnabled              = false;   // ENABLED for production (DD: 42.98% -> 16.99%)
input double            InpSslSlMultiplier         = 3.0;    // SL distance = spacing × this
input double            InpSslBreakevenThreshold   = 5.0;    // USD profit to move to breakeven
input bool              InpSslTrailByAverage       = true;   // Trail from average price
input int               InpSslTrailOffsetPoints    = 100;    // Trail offset in points
input bool              InpSslRespectMinStop       = true;   // Respect broker min stop level

input group "=== Time-based Risk Management (TRM) ==="
input bool              InpTrmEnabled              = true;  // Master switch (DEFAULT OFF)
input bool              InpTrmUseApiNews           = true;   // Use ForexFactory API (if false, use static windows)
input string            InpTrmImpactFilter         = "High"; // API filter: High, Medium+, All
input int               InpTrmBufferMinutes        = 30;     // Minutes before/after news event
input string            InpTrmNewsWindows          = "08:30-09:00,14:00-14:30";  // CSV format HH:MM-HH:MM (UTC) - FALLBACK ONLY
input bool              InpTrmPauseOrders          = true;   // Pause new orders during news
input bool              InpTrmTightenSL            = false;  // Tighten SSL during news (requires SSL)
input int               InpTrmTightenSLBuffer      = 5;      // Tighten SL only N minutes before news (not full buffer)
input double            InpTrmSLMultiplier         = 0.5;    // SL tightening factor (0.5 = half distance)
input bool              InpTrmCloseOnNews          = false;  // Close all positions before news window (legacy)

input group "=== TRM Partial Close (Simple & Smart) ==="
input bool              InpTrmPartialCloseEnabled  = false;  // ✅ Enable partial close (per-order logic)
input double            InpTrmCloseThreshold       = 3.0;    // Close if |PnL| > this (USD, both profit/loss)
input double            InpTrmKeepSLDistance       = 6.0;    // SL distance for kept losing orders (USD)

input group "=== Anti-Drawdown Cushion (ADC) ==="
input bool              InpAdcEnabled              = true;  // Master switch (DEFAULT OFF)
input double            InpAdcEquityDdThreshold    = 10.0;   // Equity DD % threshold to activate cushion
input bool              InpAdcPauseNewGrids        = true;   // Pause grid reseeding during cushion
input bool              InpAdcPauseRescue          = true;   // Pause rescue hedge deployment during cushion

input group "=== Timeframe Preservation ==="
input bool              InpPreserveOnTfSwitch      = true;   // Preserve positions on timeframe switch

input group "=== Manual Close Detection ==="
input bool              InpMcdEnabled              = true;   // Enable manual close detection & profit transfer

//--- Globals
SParams              g_params;
CLogger             *g_logger        = NULL;
CSpacingEngine      *g_spacing       = NULL;
COrderValidator     *g_validator     = NULL;
COrderExecutor      *g_executor      = NULL;
CPortfolioLedger    *g_ledger        = NULL;
CRescueEngine       *g_rescue        = NULL;
CLifecycleController*g_controller    = NULL;

//--- Preset override variables (non-const)
InpSpacingModeEnum   g_spacing_mode;
double               g_spacing_pips;
double               g_spacing_atr_mult;
double               g_min_spacing_pips;
double               g_lot_base;
double               g_lot_offset;
double               g_target_cycle_usd;
double               g_min_delta_trigger;
double               g_rescue_lot_multiplier;
double               g_rescue_max_lot;
int                  g_rescue_cooldown_bars;
string               g_symbol_override = "";  // Override symbol if preset selected

string TrimAll(const string value)
  {
   string tmp=value;
   StringTrimLeft(tmp);
   StringTrimRight(tmp);
   return tmp;
  }

SymbolPresetEnum DetectSymbolPreset(const string symbol)
  {
   // Auto-detect preset based on current chart symbol
   if(symbol=="EURUSD" || symbol=="EURUSDm" || symbol=="EURUSD.m")
      return PRESET_EURUSD;
   if(symbol=="GBPUSD" || symbol=="GBPUSDm" || symbol=="GBPUSD.m")
      return PRESET_GBPUSD;
   if(symbol=="USDJPY" || symbol=="USDJPYm" || symbol=="USDJPY.m")
      return PRESET_USDJPY;
   if(symbol=="USDCHF" || symbol=="USDCHFm" || symbol=="USDCHF.m")
      return PRESET_USDCHF;
   if(symbol=="EURCHF" || symbol=="EURCHFm" || symbol=="EURCHF.m")
      return PRESET_EURCHF;
   if(symbol=="GBPJPY" || symbol=="GBPJPYm" || symbol=="GBPJPY.m")
      return PRESET_GBPJPY;
   if(symbol=="XAUUSD" || symbol=="XAUUSDm" || symbol=="XAUUSD.m" || symbol=="GOLD")
      return PRESET_XAUUSD;
   if(symbol=="AUDUSD" || symbol=="AUDUSDm" || symbol=="AUDUSD.m")
      return PRESET_AUDUSD;
   if(symbol=="NZDUSD" || symbol=="NZDUSDm" || symbol=="NZDUSD.m")
      return PRESET_NZDUSD;
   if(symbol=="USDCAD" || symbol=="USDCADm" || symbol=="USDCAD.m")
      return PRESET_USDCAD;

   return PRESET_CUSTOM; // Unknown symbol
  }

void ApplySymbolPreset()
  {
   // First, copy inputs to globals
   g_spacing_mode = InpSpacingMode;
   g_spacing_pips = InpSpacingStepPips;
   g_spacing_atr_mult = InpSpacingAtrMult;
   g_min_spacing_pips = InpMinSpacingPips;
   g_lot_base = InpLotBase;
   g_lot_offset = InpLotOffset;
   g_target_cycle_usd = InpTargetCycleUSD;
   g_min_delta_trigger = InpMinDeltaTrigger;
   g_rescue_lot_multiplier = InpRescueLotMultiplier;
   g_rescue_max_lot = InpRescueMaxLot;
   g_rescue_cooldown_bars = InpRescueCooldownBars;

   // Determine which preset to use
   SymbolPresetEnum active_preset = InpSymbolPreset;

   // If CUSTOM, try auto-detect based on chart symbol
   if(active_preset == PRESET_CUSTOM)
     {
      active_preset = DetectSymbolPreset(_Symbol);
      if(active_preset != PRESET_CUSTOM)
        {
         Print("[Preset] Auto-detected symbol: ",_Symbol," → Using preset ",active_preset);
        }
      else
        {
         Print("[Preset] Unknown symbol: ",_Symbol," → Using manual params");
         return; // Use manual params
        }
     }

   // Apply preset-specific parameters and set symbol override
   switch(active_preset)
     {
      case PRESET_EURUSD:
         g_symbol_override = "EURUSD";
         Print("[Preset] Loading EURUSD");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_GBPUSD:
         g_symbol_override = "GBPUSD";
         Print("[Preset] Loading GBPUSD");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_USDJPY:
         g_symbol_override = "USDJPY";
         Print("[Preset] Loading USDJPY");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_AUDUSD:
         g_symbol_override = "AUDUSD";
         Print("[Preset] Loading AUDUSD");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_NZDUSD:
         g_symbol_override = "NZDUSD";
         Print("[Preset] Loading NZDUSD");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_USDCAD:
         g_symbol_override = "USDCAD";
         Print("[Preset] Loading USDCAD");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 8.0;
         // g_spacing_atr_mult = 0.8;
         // g_min_spacing_pips = 5.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 10.0;
         // g_min_delta_trigger = 0.03;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.10;
         // g_rescue_cooldown_bars = 30;
         break;

      case PRESET_USDCHF:
         g_symbol_override = "USDCHF";
         Print("[Preset] Loading USDCHF");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 6.0;
         // g_spacing_atr_mult = 0.7;
         // g_min_spacing_pips = 3.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 5.0;
         // g_min_delta_trigger = 0.02;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.08;
         // g_rescue_cooldown_bars = 20;
         break;

      case PRESET_EURCHF:
         g_symbol_override = "EURCHF";
         Print("[Preset] Loading EURCHF");
         // g_spacing_mode = InpSpacingHybrid;
         // g_spacing_pips = 6.0;
         // g_spacing_atr_mult = 0.7;
         // g_min_spacing_pips = 3.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 5.0;
         // g_min_delta_trigger = 0.02;
         // g_rescue_lot_multiplier = 0.5;
         // g_rescue_max_lot = 0.08;
         // g_rescue_cooldown_bars = 20;
         break;

      case PRESET_GBPJPY:
         g_symbol_override = "GBPJPY";
         Print("[Preset] Loading GBPJPY");
         // g_spacing_mode = InpSpacingATR;
         // g_spacing_pips = 10.0;
         // g_spacing_atr_mult = 1.0;
         // g_min_spacing_pips = 8.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 15.0;
         // g_min_delta_trigger = 0.05;
         // g_rescue_lot_multiplier = 0.4;
         // g_rescue_max_lot = 0.15;
         // g_rescue_cooldown_bars = 50;
         break;

      case PRESET_XAUUSD:
         g_symbol_override = "XAUUSD";
         Print("[Preset] Loading XAUUSD");
         // g_spacing_mode = InpSpacingATR;
         // g_spacing_pips = 10.0;
         // g_spacing_atr_mult = 1.0;
         // g_min_spacing_pips = 8.0;
         // g_lot_base = 0.01;
         // g_lot_offset = 0.0;
         // g_target_cycle_usd = 15.0;
         // g_min_delta_trigger = 0.05;
         // g_rescue_lot_multiplier = 0.4;
         // g_rescue_max_lot = 0.15;
         // g_rescue_cooldown_bars = 50;
         break;
     }
  }

void BuildParams()
  {
   // Apply preset BEFORE building params (fills global vars)
   ApplySymbolPreset();

   // Use global vars instead of input constants
   g_params.spacing_mode       =(ESpacingMode)g_spacing_mode;
   g_params.spacing_pips       =g_spacing_pips;
   g_params.spacing_atr_mult   =g_spacing_atr_mult;
   g_params.min_spacing_pips   =g_min_spacing_pips;
   g_params.atr_period         =InpAtrPeriod;
   g_params.atr_timeframe      =InpAtrTimeframe;

   g_params.grid_levels        =InpGridLevels;
   g_params.lot_base           =g_lot_base;
   g_params.lot_offset         =g_lot_offset;

   g_params.lot_percent_enabled =InpLotPercentEnabled;
   g_params.lot_percent_risk    =InpLotPercentRisk;
   g_params.lot_percent_max_lot =InpLotPercentMaxLot;

   g_params.grid_dynamic_enabled=InpDynamicGrid;
   g_params.grid_warm_levels   =InpWarmLevels;
   g_params.grid_refill_threshold=InpRefillThreshold;
   g_params.grid_refill_batch  =InpRefillBatch;
   g_params.grid_max_pendings  =InpMaxPendings;

   g_params.target_cycle_usd   =g_target_cycle_usd;

   g_params.tsl_enabled        =InpTSLEnabled;
   g_params.tsl_start_points   =InpTSLStartPoints;
   g_params.tsl_step_points    =InpTSLStepPoints;

   g_params.rescue_adaptive_lot    =InpRescueAdaptiveLot;
   g_params.min_delta_trigger      =g_min_delta_trigger;
   g_params.rescue_lot_multiplier  =g_rescue_lot_multiplier;
   g_params.rescue_max_lot         =g_rescue_max_lot;
   g_params.rescue_cooldown_bars   =g_rescue_cooldown_bars;
   g_params.exposure_cap_lots      =InpExposureCapLots;
   g_params.session_sl_usd         =InpSessionSL_USD;

   g_params.slippage_pips      =InpSlippagePips;
   g_params.order_cooldown_sec =InpOrderCooldownSec;
   g_params.respect_stops_level=InpRespectStops;
   g_params.commission_per_lot =InpCommissionPerLot;

   g_params.magic              =InpMagic;

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
   g_params.trm_use_api_news       =InpTrmUseApiNews;
   g_params.trm_impact_filter      =InpTrmImpactFilter;
   g_params.trm_buffer_minutes     =InpTrmBufferMinutes;
   g_params.trm_pause_orders       =InpTrmPauseOrders;
   g_params.trm_tighten_sl         =InpTrmTightenSL;
   g_params.trm_tighten_sl_buffer  =InpTrmTightenSLBuffer;
   g_params.trm_sl_multiplier      =InpTrmSLMultiplier;
   g_params.trm_close_on_news      =InpTrmCloseOnNews;
   g_params.trm_news_windows       =InpTrmNewsWindows;

   g_params.trm_partial_close_enabled=InpTrmPartialCloseEnabled;
   g_params.trm_close_threshold     =InpTrmCloseThreshold;
   g_params.trm_keep_sl_distance    =InpTrmKeepSLDistance;

   g_params.adc_enabled            =InpAdcEnabled;
   g_params.adc_equity_dd_threshold=InpAdcEquityDdThreshold;
   g_params.adc_pause_new_grids    =InpAdcPauseNewGrids;
   g_params.adc_pause_rescue       =InpAdcPauseRescue;

   g_params.preserve_on_tf_switch  =InpPreserveOnTfSwitch;
   g_params.mcd_enabled            =InpMcdEnabled;
  }

int OnInit()
  {
   BuildParams();

   // Determine trading symbol: use override if preset selected, otherwise use chart symbol
   string trading_symbol = (g_symbol_override != "") ? g_symbol_override : _Symbol;

   if(g_symbol_override != "")
     {
      Print("[RGDv2] Using symbol override: ",g_symbol_override," (chart symbol: ",_Symbol,")");
     }

   g_logger   = new CLogger(InpStatusInterval,InpLogEvents);
   g_spacing  = new CSpacingEngine(trading_symbol,g_params.spacing_mode,g_params.atr_period,g_params.atr_timeframe,g_params.spacing_atr_mult,g_params.spacing_pips,g_params.min_spacing_pips);
   g_validator= new COrderValidator(trading_symbol,g_params.respect_stops_level);
   g_executor = new COrderExecutor(trading_symbol,g_validator,g_params.slippage_pips,g_params.order_cooldown_sec);
   if(g_executor!=NULL)
      g_executor.SetMagic(g_params.magic);
   g_ledger   = new CPortfolioLedger(g_params.exposure_cap_lots,g_params.session_sl_usd);
   g_rescue   = new CRescueEngine(trading_symbol,g_params,g_logger);
   g_controller = new CLifecycleController(trading_symbol,g_params,g_spacing,g_executor,g_rescue,g_ledger,g_logger,g_params.magic);

   if(g_controller==NULL || !g_controller.Init())
     {
      if(g_logger!=NULL)
         g_logger.Event("[RGDv2]","Controller init failed");
      return(INIT_FAILED);
     }

   // Debug info
   if(g_logger!=NULL)
     {
      double ask=SymbolInfoDouble(trading_symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(trading_symbol,SYMBOL_BID);
      g_logger.Event("[RGDv2]",StringFormat("Init OK - Symbol=%s Ask=%.5f Bid=%.5f LotBase=%.2f GridLevels=%d Dynamic=%s",
                                            trading_symbol,ask,bid,g_params.lot_base,g_params.grid_levels,
                                            g_params.grid_dynamic_enabled?"ON":"OFF"));
     }

   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   // Check if market is open
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   // Skip weekend
   if(dt.day_of_week==0 || dt.day_of_week==6)
      return;

   // Use trading symbol (override or chart symbol)
   string trading_symbol = (g_symbol_override != "") ? g_symbol_override : _Symbol;

   // Check symbol trading allowed
   if(!SymbolInfoInteger(trading_symbol,SYMBOL_TRADE_MODE))
      return;

   if(g_controller!=NULL)
      g_controller.Update();
  }

void OnDeinit(const int reason)
  {
   if(g_controller!=NULL){ g_controller.Shutdown(); delete g_controller; g_controller=NULL; }
   if(g_rescue!=NULL){ delete g_rescue; g_rescue=NULL; }
   if(g_ledger!=NULL){ delete g_ledger; g_ledger=NULL; }
   if(g_executor!=NULL){ delete g_executor; g_executor=NULL; }
   if(g_validator!=NULL){ delete g_validator; g_validator=NULL; }
   if(g_spacing!=NULL){ delete g_spacing; g_spacing=NULL; }
   if(g_logger!=NULL){ delete g_logger; g_logger=NULL; }
  }