#property strict

#include <Trade/Trade.mqh>

#include <RECOVERY-GRID-DIRECTION/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION/core/Settings.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CLogger.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CSpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION/core/COrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CRescueEngine.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CPortfolioLedger.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CGridDirection.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CLifecycleController.mqh>

// Inputs aligned with docs/CONFIG.md
enum InpSpacingModeEnum { InpSpacing_Pips=0, InpSpacing_ATR=1, InpSpacing_Hybrid=2 };
input InpSpacingModeEnum InpSpacingMode       = InpSpacing_Hybrid;
input double            InpFixedSpacingPips   = 5.0;
input int               InpAtrPeriod          = 14;
input ENUM_TIMEFRAMES   InpAtrTimeframe       = PERIOD_M5;
input double            InpAtrMultiplier      = 1.0;
input double            InpMinSpacingPips     = 5.0;

input int               InpGridLevelsPerSide  = 5;      // 1 market + 4 limits
input double            InpLotSize            = 0.01;
input bool              InpUseBasketTP        = true;
input double            InpBasketTP_UsdPerSide= 5.0;   // fixed profit per direction
input bool              InpUseTrailing        = false; // disable trailing by default
input double            InpBasketTrailStart   = 1.0;
input double            InpBasketTrailLock    = 0.5;
input bool              InpUseBreakeven       = false; // disable BE by default
input double            InpBasketBEAfter      = 0.7;
input bool              InpUsePartialTP       = false;
input int               InpPartialTP_Percent  = 50;

input bool              InpRescueUseLastGridBreak = true;
input double            InpRescueOffsetRatio  = 0.2;
input double            InpDDOpen_Usd         = 3.0;
input double            InpDDReenter_Usd      = 2.0;
input int               InpRescueCooldown_Sec = 15;
input int               InpMaxRescueCycles    = 3;

input double            InpPortfolioTargetNet_Usd = 0.0; // off by default
input double            InpPortfolioStopLoss_Usd  = 50.0;
input double            InpSymbolExposureCap_Lots = 0.30;
input double            InpPortfolioExposureCap_Lots = 1.00;

input int               InpOrderCooldown_Sec  = 3;
input int               InpMaxSlippage_Points = 10;
input int               InpCancelStaleOrdersAfter_Sec = 60;
input bool              InpRespectStopsLevel  = true;

input bool              InpDebug              = true;
input int               InpStatusLogInterval_Sec = 30;
input bool              InpEventLogs          = true;

enum InpStartDirectionEnum { StartSell=0, StartBuy=1 };
input InpStartDirectionEnum InpStartDirection = StartSell;
input long              InpMagic             = 880011;

// Auto-restart & EMA bias
input bool              InpAutoRestart       = true;
input bool              InpUseEMAStart       = false;
input int               InpEMAPeriod         = 200;
input ENUM_TIMEFRAMES   InpEMATimeframe      = PERIOD_M1;

// Globals
CLifecycleController *g_controller = NULL;
CLogger *g_logger = NULL;
CSpacingEngine *g_spacing = NULL;
COrderExecutor *g_executor = NULL;
CRescueEngine *g_rescue = NULL;
CPortfolioLedger *g_ledger = NULL;

int OnInit(){
  // Build settings
  SSettings cfg;
  cfg.spacing_mode = (ESpacingMode)InpSpacingMode;
  cfg.fixed_spacing_pips = InpFixedSpacingPips;
  cfg.atr_period = InpAtrPeriod;
  cfg.atr_timeframe = InpAtrTimeframe;
  cfg.atr_multiplier = InpAtrMultiplier;
  cfg.min_spacing_pips = InpMinSpacingPips;

  cfg.grid_levels_per_side = InpGridLevelsPerSide;
  cfg.lot_size = InpLotSize;
  cfg.use_basket_tp = InpUseBasketTP;
  cfg.basket_tp_usd = InpBasketTP_UsdPerSide;
  cfg.use_trailing = InpUseTrailing;
  cfg.basket_trailing_start_usd = InpBasketTrailStart;
  cfg.basket_trailing_lock_usd = InpBasketTrailLock;
  cfg.use_breakeven = InpUseBreakeven;
  cfg.basket_breakeven_after_usd = InpBasketBEAfter;
  cfg.use_partial_tp = InpUsePartialTP;
  cfg.partial_tp_percent = InpPartialTP_Percent;

  cfg.rescue_use_last_grid_break = InpRescueUseLastGridBreak;
  cfg.rescue_offset_ratio = InpRescueOffsetRatio;
  cfg.dd_open_usd = InpDDOpen_Usd;
  cfg.dd_reenter_usd = InpDDReenter_Usd;
  cfg.rescue_cooldown_sec = InpRescueCooldown_Sec;
  cfg.max_rescue_cycles = InpMaxRescueCycles;

  cfg.portfolio_target_net_usd = InpPortfolioTargetNet_Usd;
  cfg.portfolio_stop_loss_usd = InpPortfolioStopLoss_Usd;
  cfg.symbol_exposure_cap_lots = InpSymbolExposureCap_Lots;
  cfg.portfolio_exposure_cap_lots = InpPortfolioExposureCap_Lots;

  cfg.order_cooldown_sec = InpOrderCooldown_Sec;
  cfg.max_slippage_points = InpMaxSlippage_Points;
  cfg.cancel_stale_orders_after_sec = InpCancelStaleOrdersAfter_Sec;
  cfg.respect_stops_level = InpRespectStopsLevel;

  cfg.debug = InpDebug;
  cfg.status_log_interval_sec = InpStatusLogInterval_Sec;
  cfg.event_logs = InpEventLogs;
  cfg.magic = InpMagic;
  cfg.auto_restart = InpAutoRestart;
  cfg.use_ema_for_start = InpUseEMAStart;
  cfg.ema_period = InpEMAPeriod;
  cfg.ema_timeframe = InpEMATimeframe;

  // Services
  g_logger = new CLogger(cfg.status_log_interval_sec, cfg.event_logs);
  g_spacing = new CSpacingEngine(_Symbol, cfg.spacing_mode, cfg.atr_period, cfg.atr_timeframe, cfg.atr_multiplier, cfg.fixed_spacing_pips, cfg.min_spacing_pips);
  g_executor = new COrderExecutor(_Symbol, cfg.order_cooldown_sec, cfg.max_slippage_points, cfg.respect_stops_level);
  g_rescue = new CRescueEngine(cfg.rescue_offset_ratio, cfg.dd_open_usd, cfg.dd_reenter_usd, cfg.rescue_cooldown_sec, cfg.max_rescue_cycles);
  g_ledger = new CPortfolioLedger(cfg.symbol_exposure_cap_lots, cfg.portfolio_exposure_cap_lots, cfg.portfolio_stop_loss_usd);

  EDirection start_dir = (InpStartDirection==StartBuy)? DIR_BUY : DIR_SELL;
  g_controller = new CLifecycleController(_Symbol, start_dir, cfg, g_spacing, g_executor, g_rescue, g_ledger, g_logger, cfg.magic);
  g_controller.Init();

  return(INIT_SUCCEEDED);
}

void OnTick(){
  if(g_controller!=NULL) g_controller.Update();
}

void OnDeinit(const int reason){
  if(g_controller){ g_controller.Shutdown(); delete g_controller; g_controller=NULL; }
  if(g_logger){ delete g_logger; g_logger=NULL; }
  if(g_spacing){ delete g_spacing; g_spacing=NULL; }
  if(g_executor){ delete g_executor; g_executor=NULL; }
  if(g_rescue){ delete g_rescue; g_rescue=NULL; }
  if(g_ledger){ delete g_ledger; g_ledger=NULL; }
}
