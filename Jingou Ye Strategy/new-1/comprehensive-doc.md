A. Functional requirements

Multi-timeframe:

Read H1 EMA using PRICE_MEDIAN (HL2) as filter.

Read M5 EMA using PRICE_CLOSE.

Entry rule:

EMA4 crosses EMA8 on M5 in same direction as H1 trend.

Price has already broken EMA21 on M5 (confirmation).

Place pending order: BuyStop above recent swing high (+offset) or SellStop below recent swing low (-offset).

Pending order expiry: configurable (default 60 minutes).

Order execution:

When pending triggers, create market position with configured SL & TP.

Position management:

SL & TP fixed (pips) or ATR/EMA-based; optional trailing stop.

Break-even move when position reaches configured R (e.g., 1R).

Optional scaling rules (add on pullback).

Money management:

Lot sizing by fixed or risk% per trade.

Respect max open trades and max daily drawdown.

Safety & filters:

Max spread check, avoidance near big news, trading hours window, max slippage.

Logging:

Full trade logs (reason, time H1/M5 values at entry, SL/TP, drawdown).

Error logs for order rejections.

B. Input parameters (defaults suggested)

EMA periods: [4, 8, 13, 21]

Trend TF: H1

Entry TF: M5

PriceType_H1 = PRICE_MEDIAN (HL2)

PriceType_M5 = PRICE_CLOSE

Pending offset: 3 pips (symbol dependent)

Pending expiry: 60 minutes

SL: 30 pips (config)

TP: 30 pips (RR 1:1)

Lot mode: fixed_lot = 0.01

Risk%: 1% (if risk-based)

Max open trades: 1

Max spread allowed: symbol-specific (e.g., XAU <= 6 points)

News filter: ON (optional)

Trading hours: e.g., 01:00–23:00 server

Max daily loss: 10% equity

Trailing: off by default

C. Edge cases & how EA handles them

Price gap when pending triggers: permit slippage up to configured value; if slippage > max_slippage, cancel or adjust SL/TP.

Partial fills: handle by moving SL/TP according to filled volume.

Rejected orders: retry with reduced lot or log and skip.

Market closed / holiday: disable trading.

Broker minimal distance to market: ensure pending level respects SymbolInfoInteger(SYMBOL_TRADE_CALC_MODE) and minimal distances; if unable to place pending at desired level, log and skip.

D. Testing & backtest plan

Historical backtest on MT5:

Use real tick data (TickDataSuite or Birt Tick Converter) or MT5 ticks if available.

Backtest period: at least 2–3 years, different market regimes.

Parameters to forward test/optimize (grid ranges):

pending_offset_pips: [1,2,3,5]

SL_pips: [15,20,30,50]

TP_pips: [15,20,30,50]

pending_expiry_minutes: [30,60,120]

lookback_swing: [3,5,8]

lot_rule: fixed vs risk-percent

Walk-forward: optimize on 12 months, test on next 3 months; repeat.

Robustness checks:

Monte Carlo: randomize slippage, spread, order execution delays.

Out-of-sample test (different brokers, tick data).

Metrics to record:

Net profit, max drawdown, profit factor, Sharpe, CAGR, winrate, avg R:R, average trade duration.

E. Implementation checklist for dev

 Implement MA calculation (H1 PRICE_MEDIAN, M5 PRICE_CLOSE).

 Cross detection engine (edge-safe: compare previous candle values).

 Swing high/low finder (configurable lookback).

 Pending order creation with validation (distance, lot, spread).

 Order lifecycle management (on fill, place SL/TP).

 Risk manager: lot calc, max daily loss, equity stop.

 News/time filter and spread checks.

 Trailing/breakeven module.

 Logging & debugging outputs (CSV/Journal).

 Optimization parameters exposed.

 Unit tests & backtest harness.

F. Pitfalls & recommendations before live

Broker quirks: symbol pip size, min distance, lot step. Must read SymbolInfo* APIs.

Unrealistic expectations: a very high winrate in a month (like Jinguo Ye) may come from high frequency + many tiny wins or from copy trading—EA must be tested long term.

News events: EAs struggle in low-liquidity/high-spread windows.

Optimization overfitting: keep parameter ranges narrow and prefer robust settings.

Margin unlimited: DO NOT use margin unlimited to open huge positions; EA must cap lot by risk to avoid ruin.

4) Example parameter set for your starting EA (conservative)

Symbol: XAUUSD

TF_trend = H1 (PRICE_MEDIAN)

TF_entry = M5 (PRICE_CLOSE)

EMA periods: 4,8,13,21

pending_offset = 3 pips (for XAU = 0.03 if you treat pip differently; BUT for XAU 1 pip = 0.01 USD ⇒ 3 pips = 0.03 USD — you earlier used 0.30? Note: confirm pip definition: earlier we used 1 pip XAU = 0.01 USD → then 3 pip = 0.03 USD; if you intend 0.30 USD then use 30 pips. Set consistent.)

pending_expiry = 60 min

SL = 30 pips

TP = 30 pips

lot_mode = fixed_lot = 0.01

max_open_trades = 1

max_spread = 6 points

news_filter = ON

equity_stop_loss = 20% (HARD)

Important: Clarify your pip definition for XAU before coding (many traders think 3 pip = 0.30 USD; ensure consistency in code).

5) Backtest & deployment plan (recommended)

Implement EA on demo account; run 2-4 weeks forward test with live data.

Parallel paper trading with same settings for 1–2 months.

Once consistent (edge persists), slowly scale up (small real money).

Monitor logs daily: unexpected slippage, rejections, behavior during news.

6) Deliverables I can give you next (pick any)

A. Convert pseudo-code to full MQL5 EA code (ready to compile for MT5) — I can do this if you confirm: symbol(s), exact pip definition for XAU, lot sizing rule, and whether you want ATR-based SL/TP option.

B. Provide a detailed test script and parameter grid for Walk-Forward optimization.

C. Provide a simple MT5 backtest report template (CSV columns and visualization recommendations).

D. Create a visual flowchart image (graphic) for you to save