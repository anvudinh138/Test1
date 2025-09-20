# Regression Test Matrix Plan

## Coverage Targets
- **Symbols:** XAUUSD, EURUSD, GBPUSD, USDJPY
- **Timeframes:** M1 + M5 for EURUSD/XAUUSD; M5 for GBPUSD, M15 for USDJPY (matches volatility regimes)
- **Data Windows:**
  - 2020-03-01 → 2020-09-01 (crisis stress)
  - 2022-01-01 → 2022-12-31 (high volatility year)
  - 2023-01-01 → 2023-12-31 (range-bound baseline)
- **Presets:**
  - XAU: 254, 272, 290
  - EUR: 201–208, 1342 legacy
  - GBP: 1359, 1407
  - JPY: 1912, 1759

## Automation Approach
1. **Config manifest:** maintain `tests/regression_suite.yaml` mapping each run → symbol, timeframe, preset, date range, deposit.
2. **Runner script:** Python wrapper invoking MT5 command-line tester (or `wine mt5strategytester64.exe` on macOS). Example:
   ```bash
   ./scripts/run_mt5_backtest.py \
     --symbol EURUSD \
     --timeframe M1 \
     --from 2022-01-01 --to 2022-12-31 \
     --preset_id 201 \
     --deposit 10000 \
     --ea z-feedback-R&D-fx/FX_SweepBOS_EA_v1_sprint_2_EXP.ex5 \
     --log_dir results/2022_EURUSD
   ```
3. **Result parsing:** reuse EA export `OptimizationResults.csv`; merge per-run metrics via pandas and compute diff vs `baseline-metrics.md` thresholds (PF, trades ±5%, DD ≤15%).
4. **Alerting:** flag regressions in terminal output + write `results/regression_report.md` with ✅/❌ per run.
5. **CI hook:** optional Git hook to ensure suite passes before tagging release; skip for quick dev by gating on env var.

## Next Steps
- [ ] Define YAML manifest with above combinations.
- [ ] Implement `run_mt5_backtest.py` (accept sandbox path to tester, spawn w/ `subprocess`).
- [ ] Add notebook or script to aggregate CSV outputs and compare with baselines.
- [ ] Integrate into TODO checklist once scripts committed.
