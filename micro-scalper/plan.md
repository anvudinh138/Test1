Tuyệt — mình làm ngay Comprehensive Document cho chiến thuật Mean-Reversion Micro-Scalping (fixed lot = 0.01) — kèm prompt AI để bạn copy/paste khi muốn gen code (MQL5) tự động. Mình sẽ đưa: mục tiêu, logic entry/exit chi tiết, tất cả filters bạn yêu cầu, tham số khởi điểm, state machine / pseudocode, skeleton MQL5 + checklist backtest & live, metrics cần log. Bạn đang ngoài nên mình giữ gọn nhưng đầy đủ để bạn có thể forward cho dev hoặc đưa vào AI code generator.

1 — Tóm tắt chiến thuật (one-liner)

Mean-reversion micro-scalper cho XAU: detect micro-spike (liquidity sweep / rejection) → vào counter-spike (fade) với lot cố định 0.01 → exit nhanh (TP nhỏ hoặc time-limit) → có bộ lọc mạnh (spread, ATR, news, killzone, tick-volume/VSA) và circuit breaker.

2 — Mục tiêu & constraints

Symbol: XAUUSD (XAUUSDm trên feed Exness)

Lot cố định: 0.01 mỗi lệnh (không tăng lot)

Timeframe decision: tick-level / M1 for ATR baseline only

Lifetime trade: 2–20s, mặc định TIME_LIMIT = 12s

TP mục tiêu: nhỏ (ví dụ 1–3 ticks) — tham số tối ưu hoá.

Không martingale, không tăng lot sau lỗ.

Dùng Exness (A/B test Pro/Zero/Raw for cost).

3 — Filters (những yếu tố không cho phép EA mở lệnh)

News filter

Block nếu high-impact news trong window: T_before = 20 min, T_after = 30 min.

Data source: economic calendar API (time zone normalized).

Spread filter

Do not enter if current_spread > SPREAD_MAX or current_spread > EMA_spread * SPREAD_MULT

Gợi ý: SPREAD_MAX_ticks = 2 ticks (tune).

Killzone filter (giờ)

Config denylist giờ (ví dụ avoid Fri 16:30 → Mon early; or low liquidity Asia hours if desired).

ATR filter

Compute ATR(M1) baseline. Block if ATR(M1) > ATR_max (too volatile) OR ATR(M1) < ATR_min (too dead).

Gợi ý: ATR_max = 2 * avg_ATR_week, ATR_min = 0.5 * avg_ATR_week.

VSA / Tick-volume filter

If tick_volume_spike AND spread_widening then block entries (signal of sweep or illiquidity) OR use as signal if combining with rejection pattern (very conservative).

Use as filter, không dùng làm độc lập trigger.

Latency/connection health

Block when ping > PING_MAX_ms or trade server errors.

Exposure / concurrent trades / batch risk

MAX_CONCURRENT_TRADES = 4 (ghi: bạn fixed lot 0.01 → cap số lệnh).

MAX_BATCH_RISK_USD = equity * 0.02 (tuneable).

Slippage limit

If last N orders slippage > SLIPPAGE_MAX -> cooldown.

Time filter per trade

If time_since_open > TIME_LIMIT_MS and not profitable → close.

4 — Entry logic (mean-reversion / fade spike) — chi tiết

We detect a micro-spike then fade:

A. Conditions to consider a spike (candidate for fade):

Price action: within last N_ticks (e.g., 3–6 ticks) there is a rapid one-direction move of at least SPIKE_PIPS (gần tương đương ticks).

Spread: not too wide (spread < SPREAD_MAX).

Tick-volume: tick_volume_current > VOLUME_MULT * EMA_tick_volume (indication of activity).

Wick/Rejection: if the last micro-candle (constructed from last X ms) shows immediate rejection (long wick) at spike extremum OR price fails to sustain beyond spike level for hold_ms (e.g., 200–500ms).

No news, ATR ok, killzone ok.

B. Entry trigger (sell on up-spike, buy on down-spike)

Enter counter to spike direction with Market Order (lot = 0.01) OR Limit placed slightly inside expected retrace to try be maker (lower cost) — default: Market order for reliability.

Entry price recorded, set TP and TIME_LIMIT.

5 — Exit rules

Primary: if profit >= TP_value → close (partial close not used since lot fixed 0.01).

Time-based: if time_since_open >= TIME_LIMIT_MS and profit <= 0 → close to avoid lingering. (TIME_LIMIT_MS default 12s)

Aggressive stop: if price moves against trade beyond SL_ticks → close (hard SL). But prefer time-exit + tight SL to reduce blowups.

Trailing micro SL (optional): if trade in +, move SL to breakeven + 0.5 tick once profit > threshold.

Batch management: if consecutive_losses >= CONSECUTIVE_LOSS_STOP or daily_loss >= MAX_DAILY_LOSS → disable EA for COOLDOWN.

6 — Parameter (giá trị khởi điểm — cần tối ưu tick-by-tick)

LOT = 0.01 (fixed)

TP_ticks = 2 (start)

SL_ticks = 6 (start) — you can prefer TIME_EXIT instead; SL to limit tail risk.

TIME_LIMIT_MS = 12000 (12s)

SPIKE_PIPS = 0.3–1.0 USD on XAU (tune to tick definition)

VOLUME_MULT = 2.0 (tick volume spike threshold)

SPREAD_MAX_ticks = 2

MAX_CONCURRENT_TRADES = 4

CONSECUTIVE_LOSS_STOP = 5

COOLDOWN_MIN = 30 minutes

NEWS_WINDOW_before = 20 min, NEWS_WINDOW_after = 30 min
(NOTE: tất cả dữ liệu cần chuyển về đơn vị tick/pips theo contract spec Exness)

7 — Position sizing & risk (fixed lot considerations)

Lot = 0.01 constant → risk per trade varies theo SL ticks. Vì không muốn cháy do unlimited margin, vẫn cần cap exposure:

MAX_TOTAL_EXPOSURE = price * contract_size * LOT * MAX_CONCURRENT_TRADES (theoretical).

MAX_BATCH_RISK_USD = equity * 0.02 recommended. If potential max loss per trade (SL_ticks * tick_value * 1) × MAX_CONCURRENT_TRADES > MAX_BATCH_RISK_USD → reduce concurrency.

8 — State machine & pseudocode (clear, enough to implement)
State: EA_RUNNING / EA_PAUSED

OnInit():
  load params, timezone normalize, load news feed, compute ATR baseline, start logs

OnTick():
  update tick buffer, spread, tick_volume_EMA, ATR(M1)
  if EA not allowed (news/killzone/latency/health): return
  manage_open_trades()
  if can_open_new_trade():
    if detect_spike_and_reject():
      send_market_order(direction = counter_spike, lot=0.01)
      record order (open_time, open_price, TP, SL, TIME_LIMIT_MS)

manage_open_trades():
  for each open_trade:
    update unrealized_pnl
    if unrealized_pnl >= TP_value: close_trade
    elif time_since_open >= TIME_LIMIT_MS:
      close_trade
    elif price moved beyond SL_ticks:
      close_trade
  update consecutive_losses and batch_risk
  if consecutive_losses >= CONSECUTIVE_LOSS_STOP or daily_loss exceeded:
    disable EA for COOLDOWN

detect_spike_and_reject():
  // compute delta over last N ticks
  if fast_move_exceeds_SPIKE_PIPS and tick_volume_spike and short_rejection_pattern:
    return True
  else return False

9 — MQL5 skeleton (trade handling + logging) — copy/paste ready (skeleton, cần dev hoàn thiện)
//--- inputs
input double LOT = 0.01;
input int TP_ticks = 2;
input int SL_ticks = 6;
input int TIME_LIMIT_MS = 12000;
input int MAX_CONCURRENT = 4;
input int SPREAD_MAX_ticks = 2;
input int CONSECUTIVE_LOSS_STOP = 5;
input int COOLDOWN_MIN = 30;

//--- globals
datetime last_disable_time = 0;
int consecutive_losses = 0;

//--- helper: convert ticks to price (use SymbolInfoDouble)
double TickValue() { return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); }
double TickSize()  { return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); }
double SpreadInTicks() {
  double spread = SymbolInfoDouble(_Symbol, SYMBOL_BID) - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  // Note: on some feeds ask > bid; use fabs
  double p = MathAbs(SymbolInfoDouble(_Symbol,SYMBOL_ASK) - SymbolInfoDouble(_Symbol,SYMBOL_BID));
  return p / TickSize();
}

//--- OnTick
void OnTick() {
  if (!EAAllowed()) return;
  ManageOpenTrades();
  if (CountOpenTrades() >= MAX_CONCURRENT) return;
  if (SpreadInTicks() > SPREAD_MAX_ticks) return;
  if (DetectSpikeAndReject()) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    // send market buy/sell depending on counter direction
    SendMarketOrder(direction, LOT, price);
  }
}

//--- SendMarketOrder (simplified)
bool SendMarketOrder(int direction, double lot, double price) {
  MqlTradeRequest req;
  MqlTradeResult  res;
  ZeroMemory(req);
  req.action = TRADE_ACTION_DEAL;
  req.symbol = _Symbol;
  req.volume = lot;
  req.type = (direction>0)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
  req.price = (direction>0)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
  req.deviation = 10; // slippage allowed ticks
  req.type_filling = ORDER_FILLING_IOC;
  req.type_time = ORDER_TIME_GTC;
  if (!OrderSend(req,res)) {
    Print("OrderSend failed code=", GetLastError());
    return false;
  }
  // log res
  LogTradeEvent("OPEN", res.order, req.volume, res.price, TimeCurrent());
  return true;
}

//--- ManageOpenTrades (simplified)
void ManageOpenTrades() {
  for (int i=PositionsTotal()-1;i>=0;i--) {
    ulong ticket = PositionGetTicket(i);
    if (PositionSelectByTicket(ticket)) {
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime t_open = (datetime)PositionGetInteger(POSITION_TIME);
      int elapsed_ms = (int)((TimeCurrent() - t_open) * 1000);
      if (profit >= TP_in_money || elapsed_ms >= TIME_LIMIT_MS) {
        ClosePosition(ticket);
      } else {
        // check SL_ticks
        if (PriceAgainstSLExceeded(...)) ClosePosition(ticket);
      }
    }
  }
}

//--- ClosePosition
bool ClosePosition(ulong ticket) {
  // implement OrderSend with opposite DEAL to close
  // on success log and update consecutive_losses if profit < 0
  return true;
}

//--- Other helper functions: DetectSpikeAndReject, EAAllowed, LogTradeEvent, CountOpenTrades, etc.


Ghi chú: đoạn trên là skeleton để dev làm tiếp — cần implement DetectSpikeAndReject (micro tick buffer analysis), EAAllowed (news/killzone/health), và full error handling (MQL5 return codes).

10 — Metrics / logs cần capture (bắt buộc)

timestamp_send, timestamp_exec, latency_ms

order_type, direction, open_price, exec_price, slippage_ticks

profit_at_close, pnl_usd, trade_duration_ms

spread_at_open, tick_volume_at_open

consecutive_losses counter, daily_pnl, max_drawdown

server errors / reject codes

11 — Backtest & live testing checklist (bắt buộc sequence)

Lấy tick data real từ Exness (ít nhất 2 tuần, bao gồm giờ Hà Nội/NY/London/Friday).

Tính distribution spread per hour — chọn account type dựa cost_roundtrip.

Tick-by-tick backtest campaign (momentum disabled, only mean-reversion): 1000s of trades.

Forward demo on VPS with same latency (1–2 days live demo).

Stress test: widen spread randomly (simulate flash spikes), simulate order rejects.

Collect metrics, tune TP/SL/TIME_LIMIT and SPREAD_MAX, VOLUME_MULT.

A/B test Pro / Zero / Raw: compute avg cost_roundtrip per trade = avg_spread* tick_value + commission_roundtrip. Chọn lowest.

12 — Prompt AI (để generate full EA MQL5) — copy/paste vào AI code generator
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

13 — Quick decisions for you to confirm (I assumed defaults; you don’t need to reply if OK)

Lot fixed 0.01 — confirmed.

TIME_LIMIT = 12s, TP = 2 ticks, SL = 6 ticks, MAX_CONCURRENT = 4, CONSECUTIVE_LOSS_STOP = 5.
If you want different defaults I can change — nhưng không cần bạn trả lời nếu chấp nhận.

14 — Next steps & deliverables I can produce right away

a) Generate full MQL5 EA code (based on prompt above) ready for compile/test (I can produce code now).

b) Produce a one-page PDF checklist for testing & deployment.

c) Produce a lightweight README (parameters and how to tune).

Bạn muốn mình: (1) tiếp tục và tạo full MQL5 EA source code luôn? hay (2) chỉ xuất file PDF/README?
Nói “code” — mình sẽ dốc luôn source MQL5 theo spec. Nếu ok thì mình bắt viết code đầy đủ.