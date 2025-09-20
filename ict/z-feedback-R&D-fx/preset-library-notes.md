# EURUSD ATR Preset Pack (Cases 201–208)

| Case | Style | Key Tweaks |
|------|-------|------------|
| 201 | London scalper (conservative) | Tight killzones, partial take-profit, ATR scaling (SL 0.6×, retest 0.3×), step trailing once 1.2R reached. |
| 202 | Session momentum (balanced) | ATR trailing mode, no pending retest, risk 0.5%, SL 0.7× ATR, max spread 0.18× ATR. |
| 203 | Breakout + pyramiding (aggressive) | Killzones off, pending retest enabled, first add-on after 1×ATR move, ATR multipliers emphasise wider spacing. |
| 204 | VSA-weighted mean reversion | Killzones off, VSA on, shorter expiry, no trailing; ATR step delta 0.30× for micro scalps. |
| 205 | NY continuation | Killzones stay on with lighter filters, long timer, ATR multipliers moderate (SL 0.75×). |
| 206 | All-session baseline | 0.65× SL multiplier, trailing ATR 1.8×, killzones on. |
| 207 | Trend capture + adds | Wider structure (K_swing 75), ATR multipliers tuned for strong trends, pyramiding allowed. |
| 208 | Retest specialist | Killzones off, pending retest, step trailing 1.4×ATR, adds 4.5× pip gap, pyramiding on. |

## Usage Guidance
- Requires EA build with `UseATRScaling` support (v1.2+). Presets default to ATR period 14; adjust via CSV or inputs for other timeframes.
- `*pip` and `*ATR` syntax allow platform to auto-scale units. Ensure tester/resource loader is refreshed after replacing `usecases_list.csv`.
- Recommended testing windows: EURUSD M1/M5 (2022-2024) with data covering London + NY overlaps.
- For multi-symbol suites, pair cases 201/202/206 as baseline run, keep 203/207 for stress tests.
