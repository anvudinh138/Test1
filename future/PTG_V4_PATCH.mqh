
//+------------------------------------------------------------------+
//|                                               PTG_V4_PATCH.mqh   |
//| Drop-in helper for PTG_BALANCED v4.x (MQL5-safe)                 |
//| - Adaptive scoring (ATR-based)                                   |
//| - RN penalty (soft), bias gate (counter exceptions)              |
//| - Retracement clamp                                             |
//| - Margin-aware lot sizing                                       |
//| - Time-stop / Partial / ATR trail                               |
//| - Daily kill-switch                                             |
//| - Usecase loader (UC50..UC55)                                   |
//+------------------------------------------------------------------+
#property strict

// ------------------------------
// Config
// ------------------------------
struct PTGScoreConfig {
   // scoring weights (sum typical around 100)
   int w_wick;       
   int w_push;       
   int w_rn;         // penalty (negative)
   int w_bias_bonus; // bonus if along bias
   int w_retr;       // penalty
   int w_spread;     // penalty
   int w_tod;        // penalty

   // thresholds / parameters
   int    atr_period;     // ATR period (M5)
   double eps_pips;       // anti-rounding epsilon
   double rn_frac;        // RN threshold as fraction of ATR
   double rn_cap_pips;    // max absolute RN threshold
   int    time_stop_bars; // bars to give trade to work
   double be_after_rr;    // move to BE threshold (R)
   double partial_rr;     // R to partial close
   double partial_close_pct; // 0..1
   double trail_atr_mult; // ATR multiple for trail
   int    daily_max_losses;
   double daily_max_R;

   // scoring enter thresholds
   double score_enter_min;
   double score_counter_min;
};

void PTG_DefaultConfig(PTGScoreConfig &cfg){
   cfg.w_wick = 50;
   cfg.w_push = 50;
   cfg.w_rn = -20;
   cfg.w_bias_bonus = 10;
   cfg.w_retr = -10;
   cfg.w_spread = -10;
   cfg.w_tod = -5;

   cfg.atr_period = 14;
   cfg.eps_pips = 0.2;
   cfg.rn_frac = 0.15;
   cfg.rn_cap_pips = 3.0;

   cfg.time_stop_bars = 10;
   cfg.be_after_rr = 0.5;
   cfg.partial_rr = 0.8;
   cfg.partial_close_pct = 0.5;
   cfg.trail_atr_mult = 1.2;

   cfg.daily_max_losses = 3;
   cfg.daily_max_R = 2.0;

   cfg.score_enter_min = 60.0;
   cfg.score_counter_min = 80.0;
}

// ------------------------------
// Utilities
// ------------------------------

// ATR in pips (MQL5-safe, handle-based)
double PTG_ATR_Pips(string symbol, ENUM_TIMEFRAMES tf, int period){
   int h = iATR(symbol, tf, period);
   if(h==INVALID_HANDLE) return 0.0;
   double buff[];
   if(CopyBuffer(h, 0, 0, 1, buff) <= 0){
      IndicatorRelease(h);
      return 0.0;
   }
   IndicatorRelease(h);
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0) pt=_Point;
   return buff[0]/pt;
}


// Overload with shift (compatibility): returns ATR at 'shift' bar
double PTG_ATR_Pips(string symbol, ENUM_TIMEFRAMES tf, int period, int shift){
   int h = iATR(symbol, tf, period);
   if(h==INVALID_HANDLE) return 0.0;
   double buff[];
   if(CopyBuffer(h, 0, shift, 1, buff) <= 0){
      IndicatorRelease(h);
      return 0.0;
   }
   IndicatorRelease(h);
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0) pt=_Point;
   return buff[0]/pt;
}
// current spread in pips
double PTG_Spread_Pips(string symbol){
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0) pt=_Point;
   long sp_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(sp_points>0) return (double)sp_points;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   return (ask-bid)/pt;
}

// nearest RN distance in pips (considers .00 and .50)
double PTG_DistToRN_Pips(string symbol, double price){
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0) pt=_Point;
   double p2  = price*2.0;
   double rn2 = MathRound(p2);
   double rn_price = rn2/2.0;
   double d1 = MathAbs(price - rn_price)/pt;
   double rni = MathRound(price);
   double d2 = MathAbs(price - rni)/pt;
   return MathMin(d1,d2);
}

// ------------------------------
// Scoring components
// ------------------------------
int PTG_Score_Wick(double frac_percent, double wick_pips, double atr_pips, const PTGScoreConfig &cfg){
   int s=0;
   if(frac_percent >= 24.0) s += cfg.w_wick/2;
   if(frac_percent >= 25.0 - 1.0) s += cfg.w_wick/4;
   double need = MathMax(10.0, 0.40*atr_pips) - cfg.eps_pips;
   if(wick_pips >= need) s += cfg.w_wick/4;
   return s;
}

int PTG_Score_Push(double push_avg_pips, double push_max_pips, double atr_pips, const PTGScoreConfig &cfg){
   int s=0;
   double need1 = 0.90*atr_pips - cfg.eps_pips;
   double need2 = 1.30*atr_pips - cfg.eps_pips;
   if(push_avg_pips >= need1) s += cfg.w_push/2;
   if(push_max_pips >= need2) s += cfg.w_push/2;
   return s;
}

int PTG_Penalty_RN(double dist_to_rn_pips, double atr_pips, const PTGScoreConfig &cfg){
   double thresh = MathMin(cfg.rn_frac*atr_pips, cfg.rn_cap_pips);
   return (dist_to_rn_pips < thresh ? cfg.w_rn : 0);
}

int PTG_Penalty_Retr(double retr_percent, const PTGScoreConfig &cfg){
   if(retr_percent < -40.0 || retr_percent > 180.0) return cfg.w_retr;
   return 0;
}

int PTG_Penalty_Spread(double spread_pips, double atr_pips, const PTGScoreConfig &cfg){
   if(spread_pips > MathMax(12.0, 0.20*atr_pips)) return cfg.w_spread;
   return 0;
}

int PTG_Penalty_TimeOfDay(int hour_local, const PTGScoreConfig &cfg){
   if(hour_local<7 || hour_local>22) return cfg.w_tod;
   return 0;
}

bool PTG_AllowCounter(double total_score, bool has_sweep, bool has_fvg, double adx){
   if(total_score>=80.0 && has_sweep && has_fvg) return true;
   if(adx>=25.0 && total_score>=70.0) return true;
   return false;
}

double PTG_ComputeScore(
   string symbol,
   double entry_price,
   double wick_frac_percent,
   double wick_pips,
   double push_avg_pips,
   double push_max_pips,
   double retr_percent,
   bool   along_bias,
   bool   has_sweep,
   bool   has_fvg,
   double adx_m5,
   int    hour_local,
   const PTGScoreConfig &cfg)
{
   double atr_pips = PTG_ATR_Pips(symbol, PERIOD_M5, cfg.atr_period);
   double dist_rn  = PTG_DistToRN_Pips(symbol, entry_price);
   double spread   = PTG_Spread_Pips(symbol);
   int s=0;
   s += PTG_Score_Wick(wick_frac_percent, wick_pips, atr_pips, cfg);
   s += PTG_Score_Push(push_avg_pips, push_max_pips, atr_pips, cfg);
   s += PTG_Penalty_RN(dist_rn, atr_pips, cfg);
   s += PTG_Penalty_Retr(retr_percent, cfg);
   s += PTG_Penalty_Spread(spread, atr_pips, cfg);
   s += PTG_Penalty_TimeOfDay(hour_local, cfg);
   if(along_bias) s += cfg.w_bias_bonus;
   return (double)s;
}

// ------------------------------
// Margin-aware lot sizing
// ------------------------------
double PTG_FitLot(double desired_lot, ENUM_ORDER_TYPE type, double price){
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(minv<=0) minv=0.01;
   if(step<=0) step=minv;
   if(maxv<=0) maxv=100.0;
   double lot = MathMin(MathMax(desired_lot, minv), maxv);
   double margin=0.0;
   if(!OrderCalcMargin(type, _Symbol, lot, price, margin)) return 0.0;
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.90; // MQL5: ACCOUNT_MARGIN_FREE
   if(margin>fm){
      double ratio = (fm/margin);
      lot = lot*ratio;
      lot = MathFloor(lot/step)*step;
   }
   if(lot < minv) return 0.0;
   return lot;
}

// ------------------------------
// Trade management
// ------------------------------
struct PTGTradeState {
   long   ticket;
   double entry;
   double sl;
   double tp;
   datetime open_time;
   int     open_bar_index;
   double  risk_pips;
   bool    partial_done;
};

string PTG_ManageTradeSuggest(
   const PTGTradeState &st,
   const PTGScoreConfig &cfg,
   double atr_pips_now,
   int    current_bar_index,
   double current_price,
   double current_position_volume,
   double &new_sl,
   double &new_tp,
   double &partial_qty)
{
   new_sl = st.sl;
   new_tp = st.tp;
   partial_qty = 0.0;

   double rr_now = 0.0;
   if(st.risk_pips>0){
      double pnl_pips = (current_price - st.entry)/_Point;
      bool is_long = (st.tp>st.entry);
      if(!is_long) pnl_pips = -pnl_pips;
      rr_now = pnl_pips / st.risk_pips;
   }

   // time stop
   if(current_bar_index - st.open_bar_index >= cfg.time_stop_bars){
      double be_price = st.entry;
      double minus_quarter = st.entry + ((st.sl - st.entry)*0.75);
      bool is_long = (st.tp>st.entry);
      double propose = (rr_now < cfg.be_after_rr ? minus_quarter : be_price);
      if(is_long) new_sl = MathMax(new_sl, propose);
      else        new_sl = MathMin(new_sl, propose);
      return "time_stop_adjust";
   }

   // partial
   if(!st.partial_done && rr_now >= cfg.partial_rr){
      partial_qty = current_position_volume * cfg.partial_close_pct;
      bool is_long = (st.tp>st.entry);
      if(is_long) new_sl = MathMax(new_sl, st.entry);
      else        new_sl = MathMin(new_sl, st.entry);
      return "partial_close_at_rr";
   }

   // trail
   if(rr_now >= cfg.be_after_rr){
      bool is_long = (st.tp>st.entry);
      double trail_pips = cfg.trail_atr_mult * atr_pips_now;
      double trail_price = (is_long ? current_price - trail_pips*_Point
                                    : current_price + trail_pips*_Point);
      if(is_long) new_sl = MathMax(new_sl, trail_price);
      else        new_sl = MathMin(new_sl, trail_price);
      return "atr_trailing";
   }

   return "hold";
}

// ------------------------------
// Daily kill switch (by date key)
// ------------------------------
class PTGDayGuard {
private:
   int  last_date_key;
   int  losses_today;
   double r_today;
   int MakeDateKey(datetime t){
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.year*10000 + dt.mon*100 + dt.day;
   }
public:
   PTGDayGuard(){ last_date_key = 0; losses_today=0; r_today=0.0; }
   void ResetIfNewDay(){
      int k = MakeDateKey(TimeCurrent());
      if(k!=last_date_key){ last_date_key=k; losses_today=0; r_today=0.0; }
   }
   void OnTradeClosed(double rr_result){
      ResetIfNewDay();
      if(rr_result<0) losses_today++;
      r_today += rr_result;
   }
   bool Halt(const PTGScoreConfig &cfg){
      ResetIfNewDay();
      if(losses_today >= cfg.daily_max_losses) return true;
      if(r_today <= -cfg.daily_max_R) return true;
      return false;
   }
};

// ------------------------------
// Usecase loader UC50..UC55
// ------------------------------
void PTG_LoadUsecase(int uc, PTGScoreConfig &cfg){
   PTG_DefaultConfig(cfg); // start from defaults
   switch(uc){
      case 50: // Balanced A (default-like)
         cfg.score_enter_min = 60;
         cfg.score_counter_min = 80;
         break;

      case 51: // Aggressive A: softer RN & spread penalties, shorter time-stop
         cfg.w_rn = -10;
         cfg.w_spread = -8;
         cfg.time_stop_bars = 8;
         cfg.partial_rr = 0.7;
         cfg.trail_atr_mult = 1.0;
         cfg.score_enter_min = 58;
         cfg.score_counter_min = 78;
         break;

      case 52: // Conservative: stricter RN/spread, longer time-stop, later partial
         cfg.w_rn = -30;
         cfg.w_spread = -15;
         cfg.time_stop_bars = 12;
         cfg.partial_rr = 1.0;
         cfg.trail_atr_mult = 1.4;
         cfg.score_enter_min = 64;
         cfg.score_counter_min = 84;
         break;

      case 53: // Counter-friendly (allow more reversals with structure)
         cfg.w_bias_bonus = 5;
         cfg.w_rn = -15;
         cfg.score_enter_min = 60;
         cfg.score_counter_min = 72; // easier to allow counter when sweep+FVG
         cfg.partial_rr = 0.75;
         break;

      case 54: // Low-vol regime (ATR small → reduce thresholds)
         cfg.atr_period = 10;
         cfg.rn_frac = 0.12;
         cfg.w_spread = -8;
         cfg.score_enter_min = 58;
         cfg.partial_rr = 0.7;
         break;

      case 55: // High-vol regime (ATR big → stricter entry, looser trail)
         cfg.atr_period = 14;
         cfg.rn_frac = 0.18;
         cfg.w_spread = -12;
         cfg.trail_atr_mult = 1.5;
         cfg.score_enter_min = 62;
         cfg.partial_rr = 0.9;
         break;

      default:
         // keep defaults
         break;
   }
}
