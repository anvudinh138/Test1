You are an expert MQL5 developer. Implement a complete, production-grade EA for MetaTrader 5 based on the following specification. Output a single .mq5 file with clear comments, robust error handling, logging, and configurable inputs.

Specification:
- Strategy: Mean-Reversion Micro-Scalper for XAUUSD
- Lot fixed: 0.01 (input LOT default 0.01, but cannot be auto-increased)
- Entry: detect micro-spike (fast price move over last N ticks with tick-volume spike and short rejection wick). Enter counter-direction immediately with market order.
- Exit: TP in ticks (input TP_ticks default 2), time-limit default 12000 ms, and SL_ticks default 6. Close on TP or TIME_LIMIT or SL. Optional trailing micro SL after profit threshold.
- Filters:
  - News filter: block entries within NEWS_BEFORE=20 min and NEWS_AFTER=30 min of high-impact events (use configurable calendar source; if none, allow to pass).
  - Spread filter: do not open if current spread in ticks > SPREAD_MAX_ticks or > EMA_spread * SPREAD_MULT.
  - Killzone (hour denylist) input array.
  - ATR(M1) filter: block if ATR(M1) > ATR_MAX_MULT * avg_ATR_week or < ATR_MIN_MULT * avg_ATR_week.
  - Tick-volume filter: require tick_volume_current > VOLUME_MULT * EMA_tick_volume.
  - Latency/health: block if ping > PING_MAX_MS.
  - Max concurrent trades input (default 4).
  - Consecutive loss stop (default 5) and cooldown minutes (default 30).
- Trading behavior:
  - Use OnTick, maintain tick buffer (last 200 ticks).
  - Use MqlTradeRequest/OrderSend with IOC filling and deviation handling; retry limited times for transient errors.
  - Robust logging: write CSV log of (send_ts, exec_ts, latency_ms, direction, open_price, exec_price, spread_ticks, slippage_ticks, profit_usd, duration_ms, error_codes).
  - Gracefully handle trade context busy and other MQL5 common errors.
  - Implement statistics panel (print to Experts log every X trades): fill rate, avg_slippage, avg_pnl_per_trade, max_drawdown, consecutive_losses.
- Safety: never increase lot size, implement max_daily_loss_usd and disable EA if exceeded.
- Provide comments on how to calibrate parameters and how to connect a news feed.

Edge cases: handle partial fills, rejections, requotes, weekend gaps, symbol not found.

Return the complete MQL5 source code only, no additional commentary. Ensure code compiles (syntax correct), and use defensive programming for all trade operations.
