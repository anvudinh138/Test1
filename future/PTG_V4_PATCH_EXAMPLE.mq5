
//+------------------------------------------------------------------+
//|                                    PTG_V4_PATCH_EXAMPLE.mq5      |
//| Example: how to call patch functions from your EA                |
//+------------------------------------------------------------------+
#property strict
#include "PTG_V4_PATCH.mqh"

PTGScoreConfig g_cfg;
PTGDayGuard    g_guard;

int OnInit(){
   PTG_DefaultConfig(g_cfg);
   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(g_guard.Halt(g_cfg)) return; // daily kill switch

   // ----- Example scoring usage (replace with your real feature extract) -----
   // Suppose you already computed the features for a candidate setup:
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double wick_frac_percent = 25.0;
   double wick_pips = 12.0;
   double push_avg = 15.0;
   double push_max = 22.0;
   double retr_pct = 30.0;
   bool   along_bias = true;
   bool   has_sweep = true;
   bool   has_fvg = true;
   double adx_m5 = 18.0;
   int    hour_local = TimeHour(TimeCurrent());

   double score = PTG_ComputeScore(_Symbol, entry_price, wick_frac_percent, wick_pips, push_avg, push_max, retr_pct,
                                   along_bias, has_sweep, has_fvg, adx_m5, hour_local, g_cfg);

   bool allow_counter = PTG_AllowCounter(score, has_sweep, has_fvg, adx_m5);

   if(score >= 60 || allow_counter){
      // size lot safely
      double lot = PTG_FitLot(0.10, ORDER_TYPE_BUY, entry_price);
      // ... place order with your engine if lot>0.0
   }
}

// Call on each closed trade with the trade's R multiple (profit in R)
void PTG_OnClosedTrade(double r_multiple){
   g_guard.OnTradeClosed(r_multiple);
}

// Example for managing an open trade
void ManageOpen(){
   // Build state from your position/order
   PTGTradeState st;
   st.ticket = 0; // your ticket
   st.entry = 1900.00;
   st.sl = 1899.00;
   st.tp = 1903.00;
   st.open_time = TimeCurrent() - 30*60;
   st.open_bar_index = 100; // your bar index state
   st.risk_pips = MathAbs((st.entry - st.sl)/_Point);
   st.partial_done = false;

   double new_sl, new_tp, partial_qty;
   double atr_now = PTG_ATR_Pips(_Symbol, PERIOD_M5, g_cfg.atr_period, 0);
   string action = PTG_ManageTradeSuggest(st, g_cfg, atr_now, 110, SymbolInfoDouble(_Symbol, SYMBOL_BID),
                                          0.10, new_sl, new_tp, partial_qty);
   // Apply the suggestion: modify SL/TP or close partial_qty
}
