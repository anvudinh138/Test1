# Timeframe Switch Bug Fix

## Problem Statement

Khi user switch timeframe trên chart (M5 → M15 → H1):
- MQL5 gọi `OnDeinit()` → `OnInit()` mỗi lần
- `LifecycleController::Init()` tạo **NEW baskets**
- Positions cũ bị **orphaned** (không ai quản lý)
- Mỗi lần switch → thêm 1 đôi basket mới
- Result: Duplicate positions, lost control

## Root Cause

```cpp
// In RecoveryGridDirection_v2.mq5 OnInit()
void OnInit()
{
    // ... setup ...

    g_controller = new CLifecycleController();
    g_controller.Init(params);  // ❌ ALWAYS creates new baskets!

    // ... UI ...
}

// In LifecycleController::Init()
void Init(SParams &p)
{
    // ❌ Always creates new baskets, ignores existing positions
    m_buy  = new CGridBasket();
    m_sell = new CGridBasket();

    m_buy.Init(DIR_BUY, ...);
    m_sell.Init(DIR_SELL, ...);
}
```

**Issue**: Không check positions đã tồn tại → tạo basket mới mỗi lần.

## MQL5 OnInit() Triggers

`OnInit()` được gọi khi:
1. ✅ EA first load
2. ⚠️ Timeframe switch (M5 → M15)
3. ⚠️ EA recompile
4. ⚠️ Input parameters change
5. ⚠️ Chart template change

→ Cần distinguish giữa **fresh start** và **reload**.

## Solution: Detect & Reconstruct

### Option 1: Check Existing Positions (Recommended)

**Logic**:
1. Trong `OnInit()`, check xem có positions với `magic` không
2. Nếu có → **reconstruct baskets** từ positions
3. Nếu không → seed mới như bình thường

**Implementation**:

```cpp
// In LifecycleController
bool HasExistingPositions(const long magic) const
{
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

        return true;  // Found at least one
    }
    return false;
}

void Init(SParams &p)
{
    m_params = p;
    m_symbol = p.symbol;
    m_magic  = p.magic;

    // Create baskets
    m_buy  = new CGridBasket();
    m_sell = new CGridBasket();

    // Check if positions already exist
    bool has_positions = HasExistingPositions(m_magic);

    if(has_positions)
    {
        // Reconstruct mode
        if(m_log)
            m_log.Event(Tag(), "[Init] Existing positions detected, reconstructing baskets");

        m_buy.Init(DIR_BUY, ...);
        m_sell.Init(DIR_SELL, ...);

        // Let baskets discover their positions in first Update()
        m_buy.SetActive(true);   // Mark active so Update() runs
        m_sell.SetActive(true);

        // Force immediate refresh
        m_buy.Update();
        m_sell.Update();

        if(m_log)
        {
            m_log.Event(Tag(), StringFormat("[Reconstruct] BUY: %.2f lots, PnL=%.2f",
                m_buy.TotalLot(), m_buy.BasketPnL()));
            m_log.Event(Tag(), StringFormat("[Reconstruct] SELL: %.2f lots, PnL=%.2f",
                m_sell.TotalLot(), m_sell.BasketPnL()));
        }
    }
    else
    {
        // Fresh start - seed normally
        if(m_log)
            m_log.Event(Tag(), "[Init] No existing positions, seeding new baskets");

        m_buy.Init(DIR_BUY, ...);
        m_sell.Init(DIR_SELL, ...);

        TryReseedBasket(m_buy, DIR_BUY, true);
        TryReseedBasket(m_sell, DIR_SELL, true);
    }
}
```

**Pros**:
- ✅ Simple logic
- ✅ No global variables needed
- ✅ Works for all OnInit() triggers
- ✅ Baskets auto-discover positions via RefreshState()

**Cons**:
- ⚠️ Loses some state (cycles_this_session, etc.)

---

### Option 2: Global Variables (Persistent State)

Use MQL5 `GlobalVariableSet/Get` để persist state:

```cpp
void LifecycleController::SaveState()
{
    string prefix = StringFormat("EA_%d_", m_magic);

    GlobalVariableSet(prefix + "BuyActive", m_buy.IsActive() ? 1.0 : 0.0);
    GlobalVariableSet(prefix + "SellActive", m_sell.IsActive() ? 1.0 : 0.0);
    GlobalVariableSet(prefix + "Cycles", (double)m_cycles_this_session);
    // ... other state
}

void LifecycleController::LoadState()
{
    string prefix = StringFormat("EA_%d_", m_magic);

    if(!GlobalVariableCheck(prefix + "BuyActive"))
        return;  // No saved state

    bool buy_active  = (GlobalVariableGet(prefix + "BuyActive") > 0.5);
    bool sell_active = (GlobalVariableGet(prefix + "SellActive") > 0.5);
    m_cycles_this_session = (int)GlobalVariableGet(prefix + "Cycles");

    if(m_log)
        m_log.Event(Tag(), "[LoadState] Restored from global vars");
}

void Init(SParams &p)
{
    // ... create baskets ...

    LoadState();  // Try to restore

    if(HasExistingPositions(m_magic))
    {
        // Reconstruct + restore state
        m_buy.Update();
        m_sell.Update();
    }
}
```

**In OnDeinit()**:
```cpp
void OnDeinit(const int reason)
{
    // Save state before cleanup
    if(g_controller != NULL)
        g_controller.SaveState();

    // ... cleanup ...
}
```

**Pros**:
- ✅ Full state preservation
- ✅ Works across EA recompile

**Cons**:
- ❌ More complex
- ❌ Global vars need cleanup

---

### Option 3: Detect Reason (Simple Guard)

```cpp
void OnInit()
{
    // Get init reason
    if(UninitializeReason() == REASON_CHARTCHANGE)
    {
        // Timeframe switch - skip full reinit
        if(g_controller != NULL)
        {
            Print("[Init] Timeframe switch detected, skipping reinit");
            return;  // Keep existing controller
        }
    }

    // Normal init
    // ...
}
```

**Pros**:
- ✅ Very simple

**Cons**:
- ❌ `UninitializeReason()` only available in `OnDeinit()`
- ❌ Can't use in `OnInit()`

---

## Recommended: Option 1 (Check & Reconstruct)

### Full Implementation

**Step 1: Add Helper to LifecycleController**

```cpp
// In LifecycleController.mqh

private:
    bool HasExistingPositions() const
    {
        int total = PositionsTotal();
        for(int i = 0; i < total; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
            return true;
        }
        return false;
    }
```

**Step 2: Modify Init() Logic**

```cpp
void Init(SParams &p)
{
    m_params = p;
    m_symbol = p.symbol;
    m_magic  = p.magic;

    // Create executor, logger, etc.
    // ...

    // Create baskets
    m_buy  = new CGridBasket();
    m_sell = new CGridBasket();

    // Always init baskets (they need dependencies)
    m_buy.Init(DIR_BUY, m_symbol, m_magic, m_params, m_executor, m_spacing, m_rescue, m_log);
    m_sell.Init(DIR_SELL, m_symbol, m_magic, m_params, m_executor, m_spacing, m_rescue, m_log);

    // Check if we're reconstructing
    bool has_positions = HasExistingPositions();

    if(has_positions)
    {
        if(m_log)
            m_log.Event(Tag(), "[Init] Existing positions detected, reconstructing");

        // Mark baskets active
        m_buy.SetActive(true);
        m_sell.SetActive(true);

        // Force refresh to discover positions
        m_buy.Update();
        m_sell.Update();

        if(m_log)
        {
            m_log.Event(Tag(), StringFormat("[Reconstruct] BUY: avg=%.5f lot=%.2f pnl=%.2f",
                m_buy.AvgPrice(), m_buy.TotalLot(), m_buy.BasketPnL()));
            m_log.Event(Tag(), StringFormat("[Reconstruct] SELL: avg=%.5f lot=%.2f pnl=%.2f",
                m_sell.AvgPrice(), m_sell.TotalLot(), m_sell.BasketPnL()));
        }
    }
    else
    {
        if(m_log)
            m_log.Event(Tag(), "[Init] Fresh start, seeding baskets");

        // Seed new baskets
        TryReseedBasket(m_buy, DIR_BUY, true);
        TryReseedBasket(m_sell, DIR_SELL, true);
    }
}
```

**Step 3: Add SetActive() to GridBasket**

```cpp
// In GridBasket.mqh
public:
    void SetActive(bool active) { m_active = active; }
```

**Step 4: Test**

```cpp
// In OnInit() add logging
void OnInit()
{
    Print("[OnInit] Reason: ", UninitializeReason());  // Won't work, only in OnDeinit

    // ... existing init ...
}

void OnDeinit(const int reason)
{
    Print("[OnDeinit] Reason: ", reason);
    Print("  REASON_CHARTCHANGE = ", (reason == REASON_CHARTCHANGE));
    Print("  REASON_REMOVE = ", (reason == REASON_REMOVE));

    // ... cleanup ...
}
```

## Testing Checklist

- [ ] Fresh start → seeds 2 baskets normally
- [ ] Switch M5 → M15 → positions preserved
- [ ] Switch back M15 → M5 → no duplication
- [ ] EA recompile → positions preserved
- [ ] Change input → positions preserved
- [ ] Manual remove EA → positions NOT preserved (expected)
- [ ] Log shows "Reconstructing" message on timeframe switch
- [ ] Baskets show correct avg/lot/pnl after reconstruct

## Edge Cases

1. **User changes magic number in inputs**:
   - Old positions orphaned (expected)
   - New magic → fresh start

2. **Positions closed externally during OnDeinit/OnInit**:
   - Reconstruct finds 0 positions → seeds new

3. **Multiple EAs same symbol different magic**:
   - Each EA only sees own magic → works correctly

## Priority

🔥 **CRITICAL** - Prevents position duplication in production

## Estimated Time

~20 minutes

## Alternative: Deinit Reason Check

If we CAN access deinit reason in OnInit (via global var):

```cpp
// Global
int g_last_deinit_reason = -1;

void OnDeinit(const int reason)
{
    g_last_deinit_reason = reason;
    // ... cleanup ...
}

void OnInit()
{
    if(g_last_deinit_reason == REASON_CHARTCHANGE)
    {
        Print("[Init] Timeframe switch, preserving controller");

        if(g_controller != NULL)
        {
            // Just refresh UI, don't reinit
            CreateUI();
            return;
        }
    }

    // Normal init
    // ...
}
```

But this is **fragile** - global var reset on EA reload.
