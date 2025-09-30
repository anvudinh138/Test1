// Include guard for MQL5
#ifndef __RGD_SETTINGS_MQH__
#define __RGD_SETTINGS_MQH__

#include <RECOVERY-GRID-DIRECTION/core/Types.mqh>

struct SSettings {
  // spacing
  ESpacingMode spacing_mode;
  double fixed_spacing_pips;
  int atr_period;
  ENUM_TIMEFRAMES atr_timeframe;
  double atr_multiplier;
  double min_spacing_pips;

  // grid
  int grid_levels_per_side; // includes market order
  double lot_size;
  bool use_basket_tp;
  double basket_tp_usd;
  double basket_trailing_start_usd;
  double basket_trailing_lock_usd;
  double basket_breakeven_after_usd;
  bool use_partial_tp;
  int partial_tp_percent;

  // rescue
  bool rescue_use_last_grid_break;
  double rescue_offset_ratio;
  double dd_open_usd;
  double dd_reenter_usd;
  int rescue_cooldown_sec;
  int max_rescue_cycles;

  // portfolio (shared wallet)
  double portfolio_target_net_usd; // 0 = off
  double portfolio_stop_loss_usd;
  double symbol_exposure_cap_lots;
  double portfolio_exposure_cap_lots;

  // execution
  int order_cooldown_sec;
  int max_slippage_points;
  int cancel_stale_orders_after_sec;
  bool respect_stops_level;

  // logging
  bool debug;
  int status_log_interval_sec;
  bool event_logs;

  // misc
  long magic;

  // auto-restart & EMA bias
  bool auto_restart;
  bool use_ema_for_start;
  int  ema_period;
  ENUM_TIMEFRAMES ema_timeframe;

  // controls
  bool use_trailing;
  bool use_breakeven;
};

#endif // __RGD_SETTINGS_MQH__
