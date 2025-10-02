# Graceful Shutdown Feature

## Problem Statement

Khi cần tắt EA (maintenance, news, etc):
- User remove EA từ chart → Positions bị orphaned
- Không có time để close positions an toàn
- Manual close tất cả rất mất thời gian

## Proposed Solution: Shutdown Mode

### Option 1: Input Parameter (Simple)

```cpp
input bool InpShutdownMode = false;  // Enable shutdown mode
input int  InpShutdownTimeout = 30;  // Minutes to close all
```

**Logic**:
```cpp
void OnTick()
{
    if(InpShutdownMode)
    {
        // Cancel all pending orders
        g_executor.CancelPendingByDirection(DIR_BUY, g_params.magic);
        g_executor.CancelPendingByDirection(DIR_SELL, g_params.magic);

        // Close all positions at market
        g_executor.CloseAllByDirection(DIR_BUY, g_params.magic);
        g_executor.CloseAllByDirection(DIR_SELL, g_params.magic);

        Print("[Shutdown] All positions closed, EA can be removed safely");
        return;  // Stop processing
    }

    // Normal flow...
    if(g_controller != NULL)
        g_controller.Update();
}
```

**Pros**:
- ✅ Simple implementation
- ✅ No UI needed

**Cons**:
- ❌ Requires input change → EA reinit
- ❌ Close ngay lập tức (không có thời gian optimize)

---

### Option 2: Chart Button (Better UX)

```cpp
// Global
bool g_shutdown_mode = false;
datetime g_shutdown_start_time = 0;

void OnInit()
{
    // Create button
    ObjectCreate(0, "btnShutdown", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_YSIZE, 30);
    ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "SHUTDOWN MODE");
    ObjectSetInteger(0, "btnShutdown", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_BORDER_COLOR, clrBlack);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "btnShutdown")
        {
            if(!g_shutdown_mode)
            {
                g_shutdown_mode = true;
                g_shutdown_start_time = TimeCurrent();

                ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrGreen);
                ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "SHUTTING DOWN...");

                Print("[Shutdown] Mode activated, will close all in ", InpShutdownTimeout, " minutes");
            }
        }
    }
}

void OnTick()
{
    if(g_shutdown_mode)
    {
        int elapsed_minutes = (int)((TimeCurrent() - g_shutdown_start_time) / 60);

        if(elapsed_minutes >= InpShutdownTimeout)
        {
            // Timeout → force close all
            Print("[Shutdown] Timeout reached, force closing all");
            g_executor.CloseAllByDirection(DIR_BUY, g_params.magic);
            g_executor.CloseAllByDirection(DIR_SELL, g_params.magic);
            g_executor.CancelPendingByDirection(DIR_BUY, g_params.magic);
            g_executor.CancelPendingByDirection(DIR_SELL, g_params.magic);

            ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "READY TO REMOVE");
            return;
        }

        // Try to close gracefully
        if(g_controller != NULL)
        {
            // Stop opening new positions
            g_controller.SetAllowNewOrders(false);

            // Close profitable positions first
            if(g_buy != NULL && g_buy.BasketPnL() >= 0)
                g_buy.CloseBasket("Shutdown");

            if(g_sell != NULL && g_sell.BasketPnL() >= 0)
                g_sell.CloseBasket("Shutdown");

            // Update button with countdown
            int remaining = InpShutdownTimeout - elapsed_minutes;
            ObjectSetString(0, "btnShutdown", OBJPROP_TEXT,
                StringFormat("SHUTDOWN: %dm left", remaining));
        }

        return;  // Skip normal processing
    }

    // Normal flow
    if(g_controller != NULL)
        g_controller.Update();
}
```

**Pros**:
- ✅ User-friendly (1 click)
- ✅ Graceful close (profitable first)
- ✅ Visual feedback (button color + countdown)
- ✅ Time to optimize exits

**Cons**:
- ❌ More code
- ❌ Need `SetAllowNewOrders()` method in controller

---

### Option 3: Comment Command (Advanced)

```cpp
void OnTick()
{
    string comment = ChartGetString(0, CHART_COMMENT);

    if(StringFind(comment, "SHUTDOWN") >= 0)
    {
        // Parse timeout from comment
        // Example: "SHUTDOWN:30" = 30 minutes
        int timeout = 30;
        int pos = StringFind(comment, ":");
        if(pos >= 0)
            timeout = (int)StringToInteger(StringSubstr(comment, pos + 1));

        // Execute shutdown logic...
    }
}
```

---

## Recommended: Option 2 (Button)

### Full Implementation

**Step 1: Add Controller Method**
```cpp
// In LifecycleController.mqh
private:
    bool m_allow_new_orders;

public:
    void SetAllowNewOrders(bool allow) { m_allow_new_orders = allow; }

    bool TryReseedBasket(CGridBasket *basket, const EDirection dir, const bool allow_new_orders)
    {
        if(!allow_new_orders || !m_allow_new_orders)  // Check global flag
            return false;

        // ... rest of logic
    }
```

**Step 2: Add Shutdown Logic**
```cpp
// In RecoveryGridDirection_v2.mq5

bool g_shutdown_mode = false;
datetime g_shutdown_start = 0;

void OnInit()
{
    // ... existing init ...

    // Create shutdown button
    CreateShutdownButton();
}

void CreateShutdownButton()
{
    ObjectCreate(0, "btnShutdown", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_XSIZE, 180);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_YSIZE, 35);
    ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "⏻ SHUTDOWN EA");
    ObjectSetInteger(0, "btnShutdown", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrCrimson);
    ObjectSetInteger(0, "btnShutdown", OBJPROP_FONTSIZE, 10);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == "btnShutdown")
    {
        if(!g_shutdown_mode)
        {
            g_shutdown_mode = true;
            g_shutdown_start = TimeCurrent();
            ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrOrange);
            Print("[Shutdown] Activated, timeout = 30 minutes");
        }
        else
        {
            // Click again to cancel
            g_shutdown_mode = false;
            ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrCrimson);
            ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "⏻ SHUTDOWN EA");
            Print("[Shutdown] Cancelled");
        }
    }
}

void OnTick()
{
    if(g_shutdown_mode)
    {
        int elapsed = (int)((TimeCurrent() - g_shutdown_start) / 60);
        int timeout = 30;  // Or input parameter

        if(elapsed >= timeout)
        {
            // Force close all
            if(g_executor != NULL)
            {
                g_executor.SetMagic(g_params.magic);
                g_executor.CloseAllByDirection(DIR_BUY, g_params.magic);
                g_executor.CloseAllByDirection(DIR_SELL, g_params.magic);
                g_executor.CancelPendingByDirection(DIR_BUY, g_params.magic);
                g_executor.CancelPendingByDirection(DIR_SELL, g_params.magic);
            }

            ObjectSetInteger(0, "btnShutdown", OBJPROP_BGCOLOR, clrGreen);
            ObjectSetString(0, "btnShutdown", OBJPROP_TEXT, "✓ READY TO REMOVE");
            Print("[Shutdown] Complete, EA can be removed");
            return;
        }

        // Graceful close
        if(g_controller != NULL)
        {
            g_controller.SetAllowNewOrders(false);

            // Try to close profitable baskets
            // ... (logic from above)
        }

        // Update button
        int remaining = timeout - elapsed;
        ObjectSetString(0, "btnShutdown", OBJPROP_TEXT,
            StringFormat("⏱ SHUTDOWN: %dm", remaining));

        return;
    }

    // Normal flow
    // ...
}

void OnDeinit(const int reason)
{
    ObjectDelete(0, "btnShutdown");
    // ... existing cleanup
}
```

## Testing Checklist

- [ ] Button appears on chart init
- [ ] Click activates shutdown mode
- [ ] New orders stopped
- [ ] Profitable baskets close first
- [ ] Countdown updates every minute
- [ ] Force close at timeout
- [ ] Button shows "READY TO REMOVE"
- [ ] Click again cancels shutdown
- [ ] Object cleanup in OnDeinit

## Priority

⭐ **MEDIUM** - Nice to have for live trading

## Estimated Time

~45 minutes
