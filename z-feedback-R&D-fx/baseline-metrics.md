# Baseline Backtest Snapshot (pre-normalization)

## XAUUSD Reference
- Preset `290` (Tier A): Profit Factor 9.37, Net Profit 8,689.82, 110 trades, Win Rate 71.8%, Avg Win 123.14, Avg Loss -33.48, Risk 0.4%.
- Preset `254` (Tier S) : Profit Factor 12.58, Net Profit 7,385.07, 99 trades (Risk 0.3%), Win Rate 74.7%, Avg Win 108.42, Avg Loss -25.51.

## EURUSD Current Best
- Preset `1342` (Tier A): Profit Factor 8.56, Net Profit 136.74, 10 trades, Win Rate 90.0%, Avg Win 17.2, Avg Loss -18.09, Risk 0.8%.
- Preset `1058` (Tier B): Profit Factor 464.5, Net Profit 46.35, only 5 trades, Win Rate 80.0%, Avg Win 11.61, Avg Loss -0.10 → unstable sample size.

## EURUSD ATR Upgrade (2022 backtest snapshot)
- Preset `206` (ATR scalper): Net 678.97, PF 3.31, 53 trades, WinRate 77.4%, MaxDD 0.87%, Sharpe 21.91.
- Preset `208` (retest+trailing): Net 634.03, PF 1.92, 49 trades, WinRate 63.3%, MaxDD 2.18%, Recovery 12.38.
- Preset `202` (session momentum): Net 517.03, PF 1.96, 39 trades, WinRate 61.5%, MaxDD 2.10%.
- Preset `205` (high-frequency continuation): Net 343.30, PF 1.32, 144 trades, WinRate 80.6%, MaxDD 3.16%.
- Preset `207` (aggressive pyramiding) dropped: Net -309.18, PF 0.77, MaxDD 5.25%; needs retune.
- Preset `204` (VSA mean reversion) produced only 1 trade; sample too small.

## Observed Gaps
- EUR presets produce ≤10 trades/year versus >100 for XAU → indicates entry filters overly tight or buffers mis-scaled.
- SL/offset buffers on EUR presets average 77 pips (`0.0077` price) versus 8–12 pip targets for normalization.
- Killzones remain tuned to XAU (13:55–21:15), misaligned with EUR London/NY sessions.

These metrics form the regression baseline before applying the EURUSD normalization upgrade.
