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
