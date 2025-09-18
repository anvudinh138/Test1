# Prompt: EURUSD Enablement Sprint

You are an expert MQL5 engineer helping refactor the Sweep→BOS EA so it performs reliably on both XAUUSD and EURUSD.

## Context
- Current version uses USD-denominated buffers tuned for XAU → EURUSD generates few trades or fails risk checks.
- CSV presets exist; parser currently supports `*pip` and `*pipPoints` for a subset of fields.
- AutoSymbolProfile only increases thresholds; no mechanism to scale down for low-volatility pairs.

## Objectives
1. Normalize all price-distance parameters (SL/TP buffers, retest offsets, spread guards, trailing steps, add spacing) to symbol-aware units using pip and ATR data.
2. Extend preset infrastructure so CSV rows can specify either absolute numbers, pip multiples, or ATR multipliers without breaking old data.
3. Introduce volatility-aware execution (ATR-driven buffers, dynamic killzones, spread ratios) while retaining XAU results.
4. Build regression and optimization scripts covering XAU & EUR baseline presets.

## Key Requirements
- Add `NormalizeFXUnits()` or equivalent pipeline stage, executed after presets load.
- Create `VolatilityProfile` helper that exposes pip size, ATR(14), session averages.
- Refactor loader: `MaxSpreadUSD`, `TrailStepUSD`, `AddSpacingUSD`, etc. must use `ParseCSVValue` with context.
- Provide feature flags/inputs allowing legacy behavior (e.g., disable ATR normalization).
- Update killzone handling: allow CSV overrides or symbol defaults for London/NY windows.
- Ensure unit tests/backtests confirm XAU preset metrics change by <5%.

## Deliverables
- Updated EA source with comments for new modules.
- Migration note describing CSV schema changes and fallback logic.
- Automation script (e.g., MT5 tester CLI or custom harness) that runs both EUR & XAU suites and exports `OptimizationResults.csv` for diffing.

## Style & Constraints
- Keep code modular; prefer small helper functions over monolithic changes.
- Document non-trivial logic (normalization flow, ATR usage) with concise comments.
- Testing philosophy: prioritize repeatable MT5 tester runs; attach key result snapshots.

Begin by outlining the normalization pipeline, then implement step-by-step, running backtests after each major refactor.
