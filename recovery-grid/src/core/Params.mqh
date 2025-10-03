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
   double       lot_offset;         // linear lot increment (e.g., 0.01)

   // lot % risk
   bool         lot_percent_enabled;     // enable lot % risk calculation
   double       lot_percent_risk;        // % of account balance to risk per grid level
   double       lot_percent_max_lot;     // max lot size when using % risk
   
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

   // rescue (v3: delta-based continuous rebalancing with cooldown)
   int          recovery_steps[];        // points offsets for staged pending orders
   bool         rescue_adaptive_lot;     // enable delta-based rescue
   double       min_delta_trigger;       // min imbalance to trigger rescue (lot)
   double       rescue_lot_multiplier;   // delta multiplier (1.0 = 100% of delta)
   double       rescue_max_lot;          // max lot per rescue deployment
   int          rescue_cooldown_bars;    // bars between rescue deployments (anti-spam)
   double       exposure_cap_lots;       // global lot exposure limit
   double       session_sl_usd;          // session stop loss (USD)

   // execution
   int          slippage_pips;
   int          order_cooldown_sec;
   bool         respect_stops_level;
   double       commission_per_lot;

   // misc
   long         magic;

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

   // smart stop loss (SSL)
   bool         ssl_enabled;              // master switch
   double       ssl_sl_multiplier;        // SL distance = spacing × this
   double       ssl_breakeven_threshold;  // USD profit to move to breakeven
   bool         ssl_trail_by_average;     // trail from average price
   int          ssl_trail_offset_points;  // trail offset in points
   bool         ssl_respect_min_stop;     // respect broker min stop level

   // time-based risk management (TRM)
   bool         trm_enabled;              // master switch
   bool         trm_use_api_news;         // use ForexFactory API (if false, use static windows)
   string       trm_impact_filter;        // API filter: High, Medium+, All
   int          trm_buffer_minutes;       // minutes before/after news event
   bool         trm_pause_orders;         // pause new orders during news
   bool         trm_tighten_sl;           // tighten SSL during news (requires ssl_enabled)
   int          trm_tighten_sl_buffer;    // tighten SL only N minutes before news (not full buffer)
   double       trm_sl_multiplier;        // SL tightening factor (e.g. 0.5 = half distance)
   bool         trm_close_on_news;        // close all positions before news window (legacy)
   string       trm_news_windows;         // CSV format: "HH:MM-HH:MM,HH:MM-HH:MM" (UTC) - FALLBACK ONLY

   // TRM partial close
   bool         trm_partial_close_enabled; // enable partial close (per-order logic)
   double       trm_close_threshold;       // close if |PnL| > this (USD)
   double       trm_keep_sl_distance;      // SL distance for kept losing orders (USD)

   // anti-drawdown cushion (ADC)
   bool         adc_enabled;              // master switch
   double       adc_equity_dd_threshold;  // % equity DD to activate cushion (e.g. 10.0)
   bool         adc_pause_new_grids;      // pause grid reseeding during cushion
   bool         adc_pause_rescue;         // pause rescue hedge deployment during cushion

   // timeframe preservation
   bool         preserve_on_tf_switch;    // preserve positions on timeframe switch

   // manual close detection
   bool         mcd_enabled;              // enable manual close detection & profit transfer
  };

#endif // __RGD_V2_PARAMS_MQH__