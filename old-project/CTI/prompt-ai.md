You are an expert MQL5 (MT5) programmer. Build an Expert Advisor named "CTI_EA.mq5" that implements ICT-conform execution with multi-timeframe confirmation: BOS (Anchor TF) → FVG (Anchor TF) → Retest → Trigger on LTF (Micro BOS or IFVG), ATR-based risk, no pip hardcoding.

Inputs (use input + custom enums):
- in_magic_number (int, default 223344)
- in_fixed_lot (double, default 0.02)
- Timeframes:
  - enum CT_TF { TF_M1, TF_M5, TF_M15, TF_M30, TF_H1, TF_H4 }
  - input CT_TF in_anchor_tf (default TF_M5)
  - enum TRIGGER_TF_MODE { TRIG_AUTO_TABLE, TRIG_MANUAL }
  - input TRIGGER_TF_MODE in_trigger_tf_mode (default TRIG_AUTO_TABLE)
  - input CT_TF in_trigger_tf_manual (default TF_M1)
- Swing/BOS (Anchor):
  - input int in_swing_bars_anchor (default 5)
  - enum BOS_CONFIRM_MODE { BOS_CLOSE_ONLY, BOS_CLOSE_OR_WICK }
  - input BOS_CONFIRM_MODE in_bos_confirm_mode (default BOS_CLOSE_ONLY)
  - enum PADDING_MODE { PAD_ATR, PAD_POINTS, PAD_SWING_PCT }
  - input PADDING_MODE in_bos_padding_mode (default PAD_ATR)
  - input double in_bos_padding_atr_factor (default 0.00)
  - input int in_bos_padding_points (default 0)
  - input double in_bos_padding_swing_pct (default 0.00)
- FVG (Anchor):
  - input double in_fvg_min_atr_factor_anchor (default 0.30)
 - OB (Anchor):
  - input bool in_anchor_zone_allow_fvg (default true)
  - input bool in_anchor_zone_allow_ob (default true)
  - enum ZONE_PRIORITY { ZP_FVG_THEN_OB, ZP_OB_THEN_FVG, ZP_ANY }
  - input ZONE_PRIORITY in_zone_priority (default ZP_FVG_THEN_OB)
  - input bool in_ob_use_wick (default false)
  - input int in_ob_max_candles_back_in_A (default 5)
- Trigger (LTF):
  - input int in_trigger_window_bars_ltf (default 30)
  - input bool in_entry_allow_bos (default true)
  - input bool in_entry_allow_ifvg (default true)
  - enum ENTRY_PRIORITY { PRIORITY_BOS_THEN_IFVG, PRIORITY_IFVG_THEN_BOS, PRIORITY_ANY }
  - input ENTRY_PRIORITY in_entry_priority (default PRIORITY_BOS_THEN_IFVG)
  - input bool in_ifvg_strict (default false)
  - input double in_ifvg_min_atr_factor_ltf (default 0.00)
  - enum ENTRY_MODE { MARKET_ON_TRIGGER, LIMIT_AT_IFVG, SMART_BOTH }
  - input ENTRY_MODE in_entry_mode (default MARKET_ON_TRIGGER)
- SL/TP/Trailing:
  - enum SL_MODE { SL_LTF_STRUCTURE, SL_ANCHOR_100PCT }
  - input SL_MODE in_sl_mode (default SL_LTF_STRUCTURE)
  - input double in_sl_buffer_atr_factor (default 0.10)
  - input bool in_tp1_enable (default true)
  - input bool in_tp1_at_50pct_of_A (default true)
  - input double in_trailing_stop_atr_factor (default 1.5)
- Filters:
  - input bool in_enable_spread_filter (default true)
  - input int in_max_spread_points (default 40)
  - input bool in_enable_session_filter (default false)
  - input int in_session_start_hour (default 0)
  - input int in_session_end_hour (default 24)
  - input int in_setup_expiry_bars_anchor (default 10)
- input bool in_debug (default true)

Core requirements:
1) Timeframes & mapping
   - Provide helper to map CT_TF → MT5 PERIOD_*.
   - TRIG_AUTO_TABLE mapping: M1→M1, M5→M1, M15→M5, M30→M15, H1→M15, H4→M30.
2) Calculations
   - Use iATR handle for Anchor TF and LTF (period 14). All dynamic thresholds via ATR. Normalize prices via Digits.
3) Structure/BOS detection (Anchor)
   - Swing via fractal/lookback = in_swing_bars_anchor.
   - BOS valid if Close-only breaks swing level + padding according to in_bos_padding_mode.
4) Zone detection (Anchor): FVG and OB
   - FVG: 3-candle model. Gap size ≥ ATR(anchor) × in_fvg_min_atr_factor_anchor. Associate with leg A.
   - OB: last opposite candle at the origin of A (Buy→last bearish; Sell→last bullish). Zone = candle body by default; optional wick extension.
5) Retest monitoring (Anchor)
   - When price returns to an enabled zone (FVG or OB), open LTF trigger window of in_trigger_window_bars_ltf bars. If both zones enabled, respect in_zone_priority.
6) Trigger detection (LTF)
   - Micro BOS (preferred) and/or IFVG (sharkturn). By default accept any sharkturn; when in_ifvg_strict=true, require size ≥ ATR(ltf) × in_ifvg_min_atr_factor_ltf.
   - Entry per in_entry_mode and in_entry_priority.
7) Orders & risk
   - One setup at a time per symbol (use Magic Number consistently).
   - SL per in_sl_mode. TP at swing A extreme. TP1 logic (50%) then Trailing ATR.
8) Filters
   - Spread/session checks before placing orders. Setup expiry and invalidation rules.
9) State machine
   - IDLE→WAIT_BOS→WAIT_FVG→WAIT_RETEST→WAIT_TRIGGER→IN_TRADE→EXIT→IDLE.
10) Logging
   - Debug prints for each state transition, detections, and trade actions.

Deliverable: Single EA file CTI_EA.mq5 (may include internal helper classes in same file for now). Code must compile on MT5.
