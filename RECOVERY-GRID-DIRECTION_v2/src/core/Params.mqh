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
  };

#endif // __RGD_V2_PARAMS_MQH__
