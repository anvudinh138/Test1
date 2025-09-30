START
 │
 ▼
Load settings (timeframes, EMA periods, price types, risk params)
 │
 ▼
Every new candle on M5: (main loop)
 ├─> If trading_disabled_by_time_or_news OR spread > max_spread OR equity < min_equity: skip
 ├─> Ensure H1 EMAs computed (using HL2 / PRICE_MEDIAN)
 ├─> Determine H1 trend:
 │     - if EMA21_H1 > EMA13_H1 > EMA8_H1 > EMA4_H1 => TREND = UP
 │     - if EMA21_H1 < EMA13_H1 < EMA8_H1 < EMA4_H1 => TREND = DOWN
 │     - else TREND = NONE
 ├─> On M5, compute EMA4/8/13/21 (Close)
 ├─> Detect EMA4 cross EMA8 on M5 (direction = crossing direction)
 ├─> If crossing direction == TREND:
 │     ├─> Check if price has "broken" EMA21 (price > EMA21 for UP, price < EMA21 for DOWN)
 │     ├─> If broken:
 │     │    ├─> Place pending order at (swing high + offset) or (swing low - offset)
 │     │    ├─> Store pending order with expiration (e.g., 60 min)
 │     │    └─> Monitor pending; if it triggers:
 │     │         ├─> Place SL and TP per settings
 │     │         └─> Activate position management (breakeven, trailing, scale-in rules)
 │     └─> Else: do nothing
 └─> Else: do nothing
Loop every tick/candle
 │
 ▼
Risk checks (max open trades, max daily loss, equity stop)
 │
 ▼
END (loop continues)
