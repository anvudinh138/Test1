# Hotfix: Orphaned Basket Recovery

## Issue Description

### Problem
**Orphaned basket state** occurs when:
1. Basket A (e.g., SELL) has open positions and is losing
2. Basket B (e.g., BUY) has ONLY pending limit orders, NO open positions
3. Basket B cannot rescue A because it has no active positions
4. Both baskets stuck indefinitely:
   - A waits for TP (never reached without B's help)
   - B waits for pendings to fill (may never happen if price doesn't reach)

### Root Causes
This can happen due to:
1. **Manual close** of B's seed position by user
2. **Stop loss hit** on B's seed position
3. **Timeframe switch** occurring right after seed placement
4. **EA restart** mid-cycle before pendings fill
5. **Order rejection** - seed failed but pendings succeeded

### User Report
```
Screenshot shows:
- SELL basket (A): 3 open positions, -8.98 USD (losing)
- BUY basket (B): 0 open positions, 6 pending limits only
- Result: B cannot help A, both stuck
```

---

## Solution: Automatic Orphaned Basket Detection & Recovery

### Detection Logic

**Orphaned basket criteria** (all must be true):
```cpp
bool IsOrphaned(basket, opposite)
{
    // 1. Has pending orders
    bool has_pendings = (basket.PendingCount() > 0);

    // 2. But NO open positions
    bool no_positions = (basket.TotalLot() <= 0.0);

    // 3. Opposite basket HAS positions (should be rescuing)
    bool opposite_has_positions = (opposite.TotalLot() > 0.0);

    return has_pendings && no_positions && opposite_has_positions;
}
```

### Recovery Action

When orphaned basket detected:
```cpp
void RecoverOrphanedBasket(basket)
{
    // 1. Cancel all pending orders
    basket.CancelAllPendings();

    // 2. Mark basket inactive
    basket.MarkInactive();

    // 3. Log the event
    Log("[ORPHAN] {basket} recovered - will reseed next cycle");
}
```

**Why this works**:
- Cancelling pendings prevents capital lock-up
- Marking inactive allows basket to reseed in next cycle
- Basket will restart according to normal rescue flow
- No manual intervention needed

---

## Implementation Details

### 1. GridBasket.mqh Changes

**Added public methods**:
```cpp
// Expose pending count for detection
int PendingCount() const { return m_pending_count; }

// Cancel all pending orders for this basket
void CancelAllPendings()
{
    if (m_executor == NULL) return;
    m_executor.SetMagic(m_magic);
    m_executor.CancelPendingByDirection(m_direction, m_magic);
    m_pending_count = 0;
    if (m_log != NULL)
        m_log.Event(Tag(), "All pending orders cancelled");
}
```

### 2. LifecycleController.mqh Changes

**Added detection method**:
```cpp
void CheckOrphanedBasket(CGridBasket *basket, CGridBasket *opposite)
{
    if (basket == NULL || !basket.IsActive())
        return;

    // Check orphaned criteria
    bool has_pendings = (basket.PendingCount() > 0);
    bool no_positions = (basket.TotalLot() <= 0.0);
    bool opposite_has_positions = (opposite != NULL && opposite.TotalLot() > 0.0);

    if (has_pendings && no_positions && opposite_has_positions)
    {
        // ORPHANED BASKET DETECTED
        if (m_log != NULL)
        {
            string dir = (basket.Direction() == DIR_BUY) ? "BUY" : "SELL";
            string opp_dir = (opposite.Direction() == DIR_BUY) ? "BUY" : "SELL";
            m_log.Event(Tag(), StringFormat(
                "[ORPHAN] %s basket detected: %d pendings, 0 positions, %s has %.2f lots - RECOVERING",
                dir, basket.PendingCount(), opp_dir, opposite.TotalLot()));
        }

        // Recovery action
        basket.CancelAllPendings();
        basket.MarkInactive();

        if (m_log != NULL)
        {
            string dir = (basket.Direction() == DIR_BUY) ? "BUY" : "SELL";
            m_log.Event(Tag(), StringFormat(
                "[ORPHAN] %s basket recovered: pendings cancelled, marked inactive, will reseed next cycle", dir));
        }
    }
}
```

**Added to Update() loop**:
```cpp
void Update()
{
    // ... (existing code)

    if (m_buy != NULL)
        m_buy.Update();
    if (m_sell != NULL)
        m_sell.Update();

    // NEW: Check for orphaned baskets
    CheckOrphanedBasket(m_buy, m_sell);
    CheckOrphanedBasket(m_sell, m_buy);

    // ... (continue with rescue logic)
}
```

---

## Logging

When orphaned basket detected, you will see:
```
[RGDv2][XAUUSD][BUY][PRI] [ORPHAN] BUY basket detected: 6 pendings, 0 positions, SELL has 0.03 lots - RECOVERING
[RGDv2][XAUUSD][BUY][PRI] All pending orders cancelled
[RGDv2][XAUUSD][BUY][PRI] [ORPHAN] BUY basket recovered: pendings cancelled, marked inactive, will reseed next cycle
```

---

## Testing Scenarios

### Scenario 1: Manual Close Seed Position
1. EA opens BUY seed + 6 pendings
2. User manually closes BUY seed
3. **Before fix**: BUY stuck with 6 pendings forever
4. **After fix**: EA detects orphan, cancels pendings, reseeds next cycle

### Scenario 2: SL Hit During Volatility
1. SELL basket losing
2. BUY seed placed with SL
3. Spike hits BUY SL, closes seed
4. **Before fix**: BUY pendings remain, cannot rescue SELL
5. **After fix**: EA recovers BUY, reseeds properly

### Scenario 3: EA Restart Mid-Cycle
1. EA places SELL seed + pendings
2. EA crashes/restarts before pendings fill
3. User manually closes SELL seed for safety
4. **Before fix**: SELL pendings orphaned
5. **After fix**: EA auto-recovers on next tick

---

## Safety Considerations

### Why This Approach is Safe

1. **Conservative**: Only cancels pendings, doesn't place new orders
2. **Targeted**: Only affects orphaned baskets (specific criteria)
3. **Logged**: All actions logged for transparency
4. **Automatic recovery**: Basket reseeds according to normal flow
5. **No capital risk**: Just cleanup, no new positions

### What Could Go Wrong?

**False positive detection** (extremely rare):
- If basket truly has 0 positions but pendings will fill soon
- Mitigation: Basket will reseed immediately, minimal disruption

**Timing edge case**:
- Detection runs right as pending fills
- Mitigation: Next Update() cycle will see position and not trigger

**User confusion**:
- User sees pendings disappear unexpectedly
- Mitigation: Clear `[ORPHAN]` log messages explain action

---

## File Changes

| File | Lines Added | Type |
|------|-------------|------|
| GridBasket.mqh | +12 | 2 new public methods |
| LifecycleController.mqh | +40 | Detection method + call |

**Total**: ~52 lines added

---

## Deployment

### Recommended Steps
1. ✅ Apply hotfix to production EA
2. ✅ Monitor logs for `[ORPHAN]` events
3. ✅ Verify baskets reseed correctly after recovery
4. ✅ If stable, merge to master

### Rollback Plan
If issues occur:
1. Revert to previous version
2. Orphaned baskets will remain stuck (manual intervention needed)
3. No data loss or capital at risk

---

## Expected Impact

### Before Fix
- Orphaned baskets stuck indefinitely
- Manual intervention required (close pendings, restart EA)
- Risk of unbalanced exposure
- Confusing for users

### After Fix
- Automatic detection within 1 tick
- Automatic recovery (cancel + reseed)
- No manual intervention needed
- Clear logging for transparency

---

**Status**: ✅ Implementation Complete
**Branch**: hotfix/orphaned-basket-recovery
**Priority**: HIGH (production issue)
**Risk Level**: LOW (conservative fix)
**Testing**: Manual scenarios verified

---

## Related Issues

This fix prevents the scenario where:
- One basket is desperately losing
- Other basket exists but cannot help
- User must manually intervene to unstuck

This is a **defensive safeguard** against edge cases in basket lifecycle management.
