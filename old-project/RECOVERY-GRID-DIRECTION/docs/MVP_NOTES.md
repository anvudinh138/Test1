# MVP Notes

Scope we will implement after SPEC/CONFIG are approved.

## What We Will Build First
- Single lifecycle per chart (EURUSD M1), two directions A↔B, shared wallet model.
- Grid per direction: 1 market + (N-1) limits, fixed lot 0.01.
- Spacing: HYBRID (max of fixed pips and ATR(M5)*k, floor at min pips).
- Per-direction basket TP + simple trailing + breakeven.
- Quick rescue on last-grid-break + small offset; backup on dd threshold.
- Safety: price validation, order cooldown, stale cleanup; per-symbol/portfolio exposure caps; portfolio SL.

## How We Validate
- MT5 Strategy Tester (EURUSD M1) with default CONFIG.
- Scenarios: one-way trend, range, whipsaw.
- Metrics: session net PnL, number of rescue cycles, exposure peak, time-to-resolve.

## Out of Scope (Phase 1)
- RSI/Bollinger/BOS/CHOCH/FVG/SD/MA z-score filters.
- Multi-symbol controller; per-symbol lifecycles sharing one wallet (planned next).
- Partial TP (kept off by default).

## Open Items to Confirm
- Default numeric values okay for your testing?
  - Grid levels N=5, fixed spacing 5 pips, ATR M5 * 1.0, min 5 pips.
  - Rescue offset 0.2×spacing; dd open $3; dd re-enter $2.
  - Portfolio SL $50; per-symbol exposure cap 0.30 lots; portfolio cap 1.00 lots.
  - Basket TP $2 per side; trailing start $1, lock $0.5; breakeven $0.7.

If you want different defaults (tighter rescue, larger target, etc.), list them and we’ll update CONFIG.md.
