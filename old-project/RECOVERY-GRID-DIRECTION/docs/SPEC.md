# SPEC: Recovery Grid Direction (MQL5 / MT5)

This spec captures the A–Z design for a two-direction recovery grid with a single lifecycle managing both sides.

## Core Concepts
- Direction: BUY or SELL.
- GridDirection (A or B): 1 market order at open + (N-1) limit orders, spaced by pips or ATR.
- Recovery: If A is losing (failed), open B to hedge/rescue (and vice versa). Quick rescue policy.
- Lifecycle: The controller of one A↔B pair, deciding rescue timing and limits. No per-lifecycle budget; all funds are shared globally.

## Objectives
- Self-managing grids (per direction) with clear status: PnL, drawdown, TP, trailing, breakeven, partial TP (on/off).
- Quick rescue to avoid too-wide spacing between hedges.
- No filters initially (no RSI/news/session) for MVP; add later.
- Safety: price validation, cooldowns, cleanup; portfolio-level exposure caps and portfolio stop.

## Architecture
- LifecycleController
  - Orchestrates A/B, owns budgets, net targets/limits, rescue timing, cooldowns.
  - Decides when to open B to rescue A (or reopen winner after closing, if needed).
- GridDirection
  - Builds grid: market + (N-1) limits.
  - Tracks per-direction basket PnL, drawdown, fills, last grid price, exposure.
  - Executes TP, trailing, breakeven, partial TP according to settings.
- SpacingEngine
  - PIPS, ATR, or HYBRID spacing with floors/ceilings.
  - ATR uses higher TF (default M5) to avoid being too small on M1.
- RescueEngine
  - Triggers rescue on last-grid-break + offset and/or drawdown threshold.
  - Enforces rescue cooldown, max cycles, exposure caps.
- PortfolioLedger
  - Shared wallet across all lifecycles/symbols. No per-lifecycle capital split.
  - Tracks portfolio-level net exposure caps and optional portfolio stop-loss/target.
- Execution & Validation
  - Price validation (stops level/min distance), spread awareness, cooldowns.
  - Cleanup stale/far orders, idempotent placement.

## State Machine (high level)
- Idle → A_Active → {B_Rescue?} → Winner_Close → {Reopen_Winner?} → Resolved | Halted
- Halted when: lifecycle budget exhausted, session stop-loss hit, net exposure cap exceeded.

## Key Algorithms

### Spacing
- Modes:
  - PIPS: spacing_pips = max(min_pips, fixed_pips)
  - ATR: spacing_pips = max(min_pips, ATR(TF)*k_atr converted to pips)
  - HYBRID (default): spacing_pips = max(fixed_pips, ATR(TF)*k_atr, min_pips)
- Defaults: TF=M5 (to avoid tiny M1 ATR), k_atr=1.0, fixed_pips=5.0, min_pips=5.0.

### Grid Build
- SELL A: place 1 market SELL at P0, then SELL limit at P0 + i*spacing (i=1..N-1).
- BUY B: place 1 market BUY at P0, then BUY limit at P0 - i*spacing (i=1..N-1).
- Validate prices against `SYMBOL_TRADE_STOPS_LEVEL` and current spread.

### Direction Basket Management
- Basket TP per direction (default): close all positions of that direction when basket_PnL >= target_usd.
- Trailing: when basket_PnL ≥ trailing_start_usd, lock trailing_lock_usd and trail with increments.
- Breakeven: move basket stop to breakeven when basket_PnL ≥ breakeven_trigger_usd.
- Partial TP (optional): close a portion of the basket when step profit reached.

### Rescue Triggers (Quick Rescue)
- Last Grid Break + Offset (primary):
  - If price has moved beyond the furthest grid level of the losing side by `rescue_offset_ratio * spacing`, open the opposite grid immediately.
  - Default `rescue_offset_ratio = 0.2` (i.e., 20% of spacing beyond last grid level).
- Drawdown Threshold (secondary):
  - If direction basket unrealized_loss ≥ `dd_open_usd`, open opposite grid.
- Reopen Winner (Case 1/2 loop):
  - If B closed in profit and A still losing ≥ `dd_reenter_usd`, reopen B after `rescue_cooldown_sec` if exposure/budget allow.
  - Symmetric for A.
- Limits and Cadence:
  - `max_rescue_cycles` per lifecycle.
  - `rescue_cooldown_sec` between consecutive rescues.
  - Respect `net_exposure_cap_lots` and lifecycle budget.

### Capital & Sharing
- Single shared wallet (account equity/balance) for all lifecycles/symbols.
- Winners on one symbol can offset losers on another.
- If portfolio stop triggers → close all and halt.

### Portfolio Targets & Stops
- Portfolio Target Profit (optional; off by default for MVP).
- Portfolio Stop Loss (USD): on breach, close all and halt.
- Exposure Caps: per-symbol and portfolio net exposure caps in lots.

### Execution Guards
- Price validation: respect `SYMBOL_TRADE_STOPS_LEVEL` and minimum distance.
- Order cooldown: avoid spam (e.g., ≥ 3 seconds per instrument for placement attempts).
- Cleanup: cancel stale far-away pending orders when regime changes or grid resets.

## Logging & Telemetry (MVP)
- Direction-level: state, fills, basket PnL, drawdown, exposure, last grid price.
- Lifecycle-level: budget A/B, realized A/B, net PnL, cycles, reasons for rescue/close/halt.
- Log frequency throttled (e.g., status every 30s, events immediate).

## MVP Scope
- One lifecycle per chart (EURUSD M1), shared wallet model.
- Fixed lot 0.01, N=5 levels per side (1 market + 4 limits).
- Spacing mode HYBRID; ATR from M5; default floors to avoid tiny spacing.
- Quick rescue on last-grid-break + small offset; dd threshold as backup.
- Per-direction basket TP + simple trailing + breakeven; partial TP off by default.
- No RSI/news/time filters.
- Safety: price validation, cooldown, cleanup; per-symbol and portfolio exposure caps; portfolio stop.

## Future
- Multiple symbols in 1 chart (each symbol = its own lifecycle managed by controller).
- Additional signals for “timing đẹp”: RSI/Bollinger/BOS/CHOCH/FVG/SD/MA z-score.
- Portfolio-level risk across symbols; advanced analytics.
