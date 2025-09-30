// === INPUT / CONFIG ===
INPUT:
  TF_trend = PERIOD_H1
  TF_entry  = PERIOD_M5
  EMA_short = 4
  EMA_mid1  = 8
  EMA_mid2  = 13
  EMA_long  = 21
  PriceType_H1 = PRICE_MEDIAN   // HL2 on H1
  PriceType_M5 = PRICE_CLOSE    // Close on M5
  pending_offset_pips = 3       // +3 pip for forex: convert per symbol
  pending_expiry_minutes = 60
  SL_pips = 30
  TP_pips = 30                  // RR 1:1 default
  max_spread_points = ...       // set per symbol
  max_open_trades = 1
  lot_rule = "fixed" or "risk_percent"
  fixed_lot = 0.01
  risk_percent = 1.0            // percent equity per trade if risk-based
  max_daily_loss_percent = 10
  allow_trading_hours = true/false  // add trading window
  news_filter = ON/OFF
  max_consecutive_losses = 5
  use_trailing = true
  trailing_start_pips = 10
  trailing_step_pips = 5

// === HELPERS ===
function pip_to_price(symbol, pips):
  // For XAU/USD: 1 pip = 0.01
  // For forex pairs: 1 pip = 0.0001 (or 0.01 for JPY pairs)
  return pips * pip_size(symbol)

function compute_lot_by_risk(SL_pips):
  if lot_rule == "fixed":
    return fixed_lot
  else:
    // Risk-based: risk_percent% of equity -> convert to lot size using pip value
    risk_usd = AccountEquity() * (risk_percent / 100)
    value_per_pip = pip_value_per_lot(symbol) // e.g., 1 lot XAU = $1 per pip
    lot = risk_usd / (SL_pips * value_per_pip)
    return normalize_lot(lot)

// === MAIN LOOP (on new M5 candle) ===
on_new_M5_candle():
  if news_filter active and is_important_news_next(minutes=30): return
  if spread_current > max_spread_points: return
  if account_equity < min_equity_threshold: return
  if daily_loss_exceeded(): disable_trading_till_next_day(); return

  // compute H1 EMAs (use PRICE_MEDIAN)
  ema4_H1  = iMA(symbol, TF_trend, EMA_short, 0, MODE_EMA, PriceType_H1, 0)
  ema8_H1  = iMA(symbol, TF_trend, EMA_mid1, 0, MODE_EMA, PriceType_H1, 0)
  ema13_H1 = iMA(symbol, TF_trend, EMA_mid2, 0, MODE_EMA, PriceType_H1, 0)
  ema21_H1 = iMA(symbol, TF_trend, EMA_long, 0, MODE_EMA, PriceType_H1, 0)

  // determine trend on H1
  if ema4_H1 > ema8_H1 and ema8_H1 > ema13_H1 and ema13_H1 > ema21_H1:
    trend = UP
  else if ema4_H1 < ema8_H1 and ema8_H1 < ema13_H1 and ema13_H1 < ema21_H1:
    trend = DOWN
  else:
    trend = NONE

  // compute M5 EMAs (use PRICE_CLOSE)
  ema4_M5  = iMA(symbol, TF_entry, EMA_short, 0, MODE_EMA, PriceType_M5, 0)
  ema8_M5  = iMA(symbol, TF_entry, EMA_mid1, 0, MODE_EMA, PriceType_M5, 0)
  ema4_M5_prev = iMA(symbol, TF_entry, EMA_short, 0, MODE_EMA, PriceType_M5, 1)
  ema8_M5_prev = iMA(symbol, TF_entry, EMA_mid1, 0, MODE_EMA, PriceType_M5, 1)

  // detect crossing EMA4 crossing EMA8 on M5
  if ema4_M5_prev <= ema8_M5_prev and ema4_M5 > ema8_M5:
    cross = UP
  else if ema4_M5_prev >= ema8_M5_prev and ema4_M5 < ema8_M5:
    cross = DOWN
  else:
    cross = NONE

  if cross == NONE or trend == NONE: return

  if cross == trend:
    // check price has broken EMA21 on M5 (confirmation)
    price = SymbolBidAskMidOrClose()
    ema21_M5 = iMA(symbol, TF_entry, EMA_long, 0, MODE_EMA, PriceType_M5, 0)
    if (trend == UP and price > ema21_M5) or (trend == DOWN and price < ema21_M5):
      // compute swing high/low on last N candles (e.g., 5 candles)
      swingHigh = highestHigh(TF_entry, lookback=5)
      swingLow  = lowestLow(TF_entry, lookback=5)

      if trend == UP:
        entryPrice = swingHigh + pip_to_price(pending_offset_pips)
        orderType = ORDER_TYPE_BUY_STOP
      else:
        entryPrice = swingLow - pip_to_price(pending_offset_pips)
        orderType = ORDER_TYPE_SELL_STOP

      lot = compute_lot_by_risk(SL_pips)
      SL_price = (trend == UP) ? entryPrice - pip_to_price(SL_pips) : entryPrice + pip_to_price(SL_pips)
      TP_price = (trend == UP) ? entryPrice + pip_to_price(TP_pips) : entryPrice - pip_to_price(TP_pips)

      // create pending order with expiry
      place_pending_order(symbol, orderType, lot, entryPrice, SL_price, TP_price, expiry_minutes=pending_expiry_minutes)
