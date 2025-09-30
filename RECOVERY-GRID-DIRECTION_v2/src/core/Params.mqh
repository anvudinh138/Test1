//+------------------------------------------------------------------+
//| Strategy parameters                                              |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_PARAMS_MQH__
#define __RGD_V2_PARAMS_MQH__

#include <Trade\Trade.mqh>
#include "Types.mqh"

struct SParams
  {
   // spacing
   ESpacingMode spacing_mode;
   double       spacing_atr_mult;
   double       min_spacing_pips;
   int          atr_period;
   ENUM_TIMEFRAMES atr_timeframe;

   // grid
   int          grid_levels;        // number of levels including market seed
   double       lot_base;
   double       lot_scale;

   // profit target
   double       target_cycle_usd;

   // trailing stop for hedge basket
   bool         tsl_enabled;
   int          tsl_start_points;
   int          tsl_step_points;

   // rescue
   double       recovery_steps_atr[]; // ATR multiples for staged pending orders
   double       recovery_lot;
   double       dd_open_usd;
   double       offset_ratio;
   double       exposure_cap_lots;
   int          max_cycles_per_side;
   double       session_sl_usd;
   int          cooldown_bars;
   double       session_trailing_dd_usd;
   int          grid_warm_levels;
   int          grid_refill_threshold;
   int          grid_refill_batch;
   EGridRefillMode grid_refill_mode;
   int          grid_max_pendings;
   bool         rescue_trend_filter;
   double       trend_k_atr;
   double       trend_slope_threshold;
   int          trend_slope_lookback;
   int          trend_ema_period;
   ENUM_TIMEFRAMES trend_ema_timeframe;
   double       tp_distance_z_atr;
   double       tp_weaken_usd;
   double       max_spread_pips;
   bool         trading_time_filter_enabled;
   int          cutoff_hour;
   int          cutoff_minute;
   bool         friday_flatten_enabled;
   int          friday_flatten_hour;
   int          friday_flatten_minute;
   bool         hedge_retest_enable;
   int          hedge_wait_bars;
   double       hedge_wait_atr;
   double       hedge_retest_atr;
   double       hedge_retest_slope;
   int          hedge_retest_confirm_bars;
   double       lock_min_lots;
   int          lock_min_bars;
   int          lock_max_bars;
   double       lock_cancel_mult;
   double       lock_hyst_atr;
   double       lock_hyst_slope;
   double       lock_hedge_close_pct;

   // execution
   int          slippage_pips;
   int          order_cooldown_sec;
   bool         respect_stops_level;
   double       commission_per_lot;

   // misc
   long         magic;
   string       cycle_csv_path;
  };

#endif // __RGD_V2_PARAMS_MQH__
