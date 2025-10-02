# Manual Close Detection & Recovery

## Problem Statement

Khi user manually close positions, EA không handle correctly:

1. **Manual close loser → winner profits lost**
   - User close basket A manually
   - Basket B đang lãi
   - B close tự động → profit KHÔNG được transfer cho A
   - A reseed → KHÔNG có target reduction
   - Result: Mất profit từ B

2. **Manual close winner → loser orphaned**
   - User close basket B (winner) manually
   - Basket A (loser) vẫn đang lỗ
   - A không được cứu nữa
   - Result: A stuck mãi mãi

3. **Manual close both → EA freezes**
   - User close cả A và B
   - EA set both inactive
   - Không có logic reseed
   - Result: EA dừng trade

## Current Code Flow

```cpp
// GridBasket::Update() - line 738-740
if(no_positions && no_pending)
    m_active=false;  // Only sets inactive, no profit tracking!

// LifecycleController::Update() - line 454-461
if(m_buy!=NULL && m_buy.ClosedRecently())
{
    double realized=m_buy.TakeRealizedProfit();  // ❌ Zero if manual close
    if(realized>0 && m_sell!=NULL)
        m_sell.ReduceTargetBy(realized);
    TryReseedBasket(m_buy,DIR_BUY,true);
}
```

**Issue**: `ClosedRecently()` returns `false` if manual close → no profit transfer.

## Solution: Enhanced Manual Close Detection

### Step 1: Track Last Known State

Add to `GridBasket` private:
```cpp
// Track state changes
double m_last_total_lot;
double m_last_pnl;
bool   m_manual_close_detected;
```

### Step 2: Detect Manual Close

```cpp
void GridBasket::Update()
{
    if(!m_active)
        return;

    m_closed_recently=false;

    // BEFORE RefreshState, save old values
    double prev_total_lot = m_total_lot;
    double prev_pnl = m_pnl_usd;

    RefreshState();

    // Check for manual close
    bool had_positions = (prev_total_lot > 0.0);
    bool now_no_positions = (m_total_lot <= 0.0);

    if(had_positions && now_no_positions)
    {
        // Positions disappeared → manual close detected
        m_manual_close_detected = true;
        m_last_realized = prev_pnl;  // Capture last PnL before close
        m_closed_recently = true;    // Trigger reseed logic

        if(m_log)
            m_log.Event(Tag(), StringFormat("[ManualClose] Detected, PnL=%.2f", prev_pnl));
    }

    // Dynamic grid refill...
    // ManageTrailing...
    // Check TP...

    // Check if fully closed
    if(m_active)
    {
        bool no_positions = (m_total_lot <= 0.0);
        bool no_pending = true;

        int total = (int)OrdersTotal();
        for(int i = 0; i < total; i++)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0) continue;
            if(!OrderSelect(ticket)) continue;
            if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
            if(OrderGetInteger(ORDER_MAGIC) != m_magic) continue;
            no_pending = false;
            break;
        }

        if(no_positions && no_pending)
            m_active = false;
    }
}
```

### Step 3: Handle Manual Close in Controller

```cpp
// In LifecycleController::Update()

// After normal Update() calls...
if(m_buy != NULL)
    m_buy.Update();
if(m_sell != NULL)
    m_sell.Update();

// Handle manual closes
if(m_buy != NULL && m_buy.ClosedRecently())
{
    double realized = m_buy.TakeRealizedProfit();

    // Transfer profit even if manual close
    if(realized > 0 && m_sell != NULL && m_sell.IsActive())
    {
        m_sell.ReduceTargetBy(realized);
        if(m_log)
            m_log.Event(Tag(), StringFormat("[ManualClose] BUY profit %.2f → SELL target reduced", realized));
    }

    // Reseed if allowed
    TryReseedBasket(m_buy, DIR_BUY, true);
}

if(m_sell != NULL && m_sell.ClosedRecently())
{
    double realized = m_sell.TakeRealizedProfit();

    if(realized > 0 && m_buy != NULL && m_buy.IsActive())
    {
        m_buy.ReduceTargetBy(realized);
        if(m_log)
            m_log.Event(Tag(), StringFormat("[ManualClose] SELL profit %.2f → BUY target reduced", realized));
    }

    TryReseedBasket(m_sell, DIR_SELL, true);
}
```

### Step 4: Add Manual Close Flag Check

```cpp
// In GridBasket
bool WasManualClose() const { return m_manual_close_detected; }

void ClearManualCloseFlag() { m_manual_close_detected = false; }
```

### Step 5: Enhanced Logging

```cpp
if(m_manual_close_detected && m_log)
{
    m_log.Event(Tag(), StringFormat(
        "[ManualClose] lot=%.2f pnl=%.2f → %s",
        prev_total_lot,
        prev_pnl,
        (prev_pnl >= 0) ? "profit transferred" : "loss recorded"
    ));
}
```

## Implementation Checklist

- [ ] Add tracking fields to GridBasket
- [ ] Detect manual close in Update()
- [ ] Capture PnL before close
- [ ] Transfer profit to opposite basket
- [ ] Log manual close events
- [ ] Test scenarios:
  - [ ] Manual close winner (profit transfer)
  - [ ] Manual close loser (no transfer)
  - [ ] Manual close both (reseed)
- [ ] Compile and backtest

## Expected Behavior After Fix

| Scenario | Before | After |
|----------|--------|-------|
| Close A (loser) manually | B profits lost | ✅ B profits transferred if B closes |
| Close B (winner) manually | A không được reduce target | ✅ A target reduced by B profit |
| Close both manually | EA freezes | ✅ Both reseed automatically |

## Safety Considerations

1. **Only transfer positive PnL** (don't transfer losses)
2. **Check opposite basket is active** before transfer
3. **Log all manual close events** for audit
4. **Reset manual close flag** after handling

## Priority

🔥 **HIGH** - Critical for live trading

## Estimated Implementation Time

~30 minutes
