# EURUSD Enablement Upgrade Plan

## 1. Context & Goals
- Current Sweep→BOS EA excels on XAUUSD because defaults are tuned to high-volatility, USD-denominated ticks; EURUSD underperforms (few trades, misleading PF, equity chop).
- Goal: deliver a hardened version that keeps XAU performance while becoming symbol-aware so majors like EURUSD run reliably in both backtests and live.
- Success metrics: ≥60 trades / year on EURUSD M1-M5 datasets (2022–2024), PF ≥2.5, win rate ≥58%, max DD ≤15%, no degradation >5% on baseline XAU preset suite.

## 2. Root Causes (from multi-AI review)
- **Unit coupling**: buffers, spreads, offsets stored as USD absolutes; scaling only increases values (ChatGPT5, Grok).
- **Killzone rigidity**: time filters locked to XAU hours (ChatGPT5, DeepSeek).
- **CSV limitations**: `ParseCSVValue` not used consistently, cannot express pip-based overrides (ChatGPT5).
- **Volatility unawareness**: no ATR/relative sizing, trailing/TP tuned to precious metals (Gemini, Grok).
- **Testing bias**: small EUR sample sizes hide brittleness (Gemini).

## 3. Guiding Principles
1. Normalize everything to symbol-aware units (pip, ATR) before trading logic runs.
2. Separate core logic from symbol overlays via layered parameter pipeline (defaults → preset/CSV → auto profile → normalization → runtime adapters).
3. Provide data-driven presets and walk-forward tests for each symbol.
4. Maintain XAU performance via regression suite on legacy presets before shipping.

## 4. Delivery Roadmap
### Phase A – Instrumentation & Baseline
- Add metrics: track `FilterBlocks_*` per symbol, trade frequency, ATR distribution.
- Export equity curves, trade logs for baseline XAU + current EURUSD to set regression checkpoints.

### Phase B – Parameter Normalization
- Implement `NormalizeFXUnits()` post `ApplyAutoSymbolProfile()` (ChatGPT5 recommendation) to clamp buffers, max spread, add spacing using pip conversions.
- Broaden CSV loader to parse `MaxSpreadUSD`, `TrailStepUSD`, `AddSpacingUSD`, etc. via `ParseCSVValue()` (ChatGPT5).
- Abstract new `struct VolatilityProfile` capturing pip size, ATR(14), session volatility bands for runtime use.

### Phase C – Volatility-Adaptive Logic
- Introduce ATR-based multipliers: `SL_BufferATR`, `BOSBufferATR`, trailing step, TP targets (Gemini, Grok).
- Allow mixed mode: if preset supplies USD value -> convert; if ATR multiplier provided -> compute dynamic per symbol per bar.
- Expand risk sizing: support min lot guard, dynamic risk reduction when ATR spikes.
- ✅ Status: `UseATRScaling` + per-field ATR multipliers now wired into `NormalizeFXUnits`, with CSV support for `*ATR` values and runtime refresh each new bar.

### Phase D – Symbol-Specific Filters & Sessions
- Killzones: add CSV columns or per-symbol defaults, include DeepSeek’s London/NY windows; allow presets to disable.
- Spread guard: extend `DefaultSpreadForSymbol()` for majors; add runtime spread ATR ratio filter.
- Round numbers: compute grid from ATR or pip multiple (Grok suggestion) and support fine grids (e.g., 0.0005 for EURUSD).
- Optional news filter hook for EUR macro events.

### Phase E – Presets & Testing
- Curate preset library: merge ChatGPT5’s EURUSD (201–208), Gemini’s preset 1342 baseline, plus new ATR-driven variants (conservative/balanced/aggressive).
- ✅ Status: `P_CODEX_EURUSD_ATR.csv` now holds cases 201–208 with ATR multipliers and documentation in `preset-library-notes.md`.
- Backtest snapshot (2022): 206 PF 3.31 (53 trades), 208 PF 1.92 (49 trades), 202 PF 1.96 (39 trades); retire or retune 207 (PF 0.77) and 204 (no sample).
- Build backtest matrix: symbols (XAU, EUR, GBP, JPY), timeframes (M1, M5), regimes (2020 crash, 2022 volatility, 2023 range).
- Automate in MT5 tester CLI: scripts to run regression suite, compute PF, trades, DD, and flag deviations.
- Forward-test: deploy on demo with logging for 2 weeks before release.

## 5. Risk & Mitigation
- **Regression risk (XAU)**: run nightly suite on legacy presets; flag metric deltas >5%.
- **Under-scaling on low-vol pairs**: unit normalization includes lower/upper pip clamps to avoid zeroing; ATR fallback ensures dynamic sizing.
- **Complexity creep**: encapsulate normalization in dedicated module with unit tests; keep preset schema backward-compatible (CSV version flag).
- **Data drift**: schedule quarterly re-optimisation and seasonality review.

## 6. Deliverables Overview
1. Refactored EA with normalization, ATR adapters, widened CSV semantics.
2. Expanded preset pack + documentation describing symbol-specific guidance.
3. Automated test harness (scripts + result CSVs + diff tool).
4. Ops checklist for deployment (broker sessions, news calendar sync).

## 7. Immediate Next Actions
- Lock baseline metrics on current code for XAU (24h).
- Draft normalization module & extend CSV parsing.
- Prototype ATR-based buffer calculation on EURUSD backtest (2023 data).
- Iterate on killzone config UI & preset schema.
