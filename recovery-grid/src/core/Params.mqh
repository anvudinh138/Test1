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
   double       spacing_pips;
   double       spacing_atr_mult;
   double       min_spacing_pips;
   int          atr_period;
   ENUM_TIMEFRAMES atr_timeframe;

   // grid
   int          grid_levels;        // number of levels including market seed
   double       lot_base;
   double       lot_scale;
   
   // dynamic grid
   bool         grid_dynamic_enabled;
   int          grid_warm_levels;      // initial pending count
   int          grid_refill_threshold; // refill when pending <= this
   int          grid_refill_batch;     // add this many per refill
   int          grid_max_pendings;     // hard limit for safety

   // profit target
   double       target_cycle_usd;

   // trailing stop for hedge basket
   bool         tsl_enabled;
   int          tsl_start_points;
   int          tsl_step_points;

   // rescue
   int          recovery_steps[];   // points offsets for staged pending orders
   double       recovery_lot;
   double       dd_open_usd;
   double       offset_ratio;
   double       exposure_cap_lots;
   int          max_cycles_per_side;
   double       session_sl_usd;
   int          cooldown_bars;

   // execution
   int          slippage_pips;
   int          order_cooldown_sec;
   bool         respect_stops_level;
   double       commission_per_lot;

   // misc
   long         magic;

   // partial close
   bool         pc_enabled;
   double       pc_retest_atr;
   double       pc_slope_hysteresis;
   double       pc_min_profit_usd;
   double       pc_close_fraction;
   int          pc_max_tickets;
   int          pc_cooldown_bars;
   int          pc_guard_bars;
   double       pc_pending_guard_mult;
   double       pc_guard_exit_atr;
   double       pc_min_lots_remain;

   // dynamic target scaling
   bool         dts_enabled;
   bool         dts_atr_enabled;
   double       dts_atr_weight;
   bool         dts_time_decay_enabled;
   double       dts_time_decay_rate;
   double       dts_time_decay_floor;
   bool         dts_dd_scaling_enabled;
   double       dts_dd_threshold;
   double       dts_dd_scale_factor;
   double       dts_dd_max_factor;
   double       dts_min_multiplier;
   double       dts_max_multiplier;
  };

#endif // __RGD_V2_PARAMS_MQH__