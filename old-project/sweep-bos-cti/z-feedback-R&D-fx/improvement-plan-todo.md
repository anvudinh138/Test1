# EURUSD Enablement TODO

- [x] Capture baseline metrics for XAUUSD presets (PF, DD, trade count) and export current EURUSD backtest logs.
- [x] Implement normalization module (`NormalizeFXUnits` + `VolatilityProfile`) and validate pip/ATR conversions on EURUSD.
- [x] Extend CSV loader to accept `*pip`/`*pipPoints`/`*ATR` for spread, trailing, add spacing, and verify backward compatibility.
- [x] Rework killzone + spread defaults per symbol; add CSV overrides and ensure filters unblock valid EUR sessions.
- [x] Introduce ATR-driven entry/exit parameters (buffers, TP, trailing) with toggleable legacy mode; run regression backtests.
- [x] Curate & document new preset library (EUR 201–208, preset 1342 baseline, ATR variants) and merge into resources.
- [ ] Build automated backtest matrix for XAU/EUR/GBP/JPY, collect KPIs, and add diff check against baseline metrics (see `regression-matrix-plan.md`).
- [ ] Retune or replace underperforming presets (e.g., 207, 204) before rolling into regression suite.
- [ ] Execute forward demo test on EURUSD for two weeks with logging review and sign-off.
