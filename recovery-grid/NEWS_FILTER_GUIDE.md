# News Filter Integration Guide

## Overview

`NewsFilter.mqh` filters high-impact economic news using **MT5 built-in Calendar API**.

✅ Works in **backtest** (historical news)
✅ Works in **live trading** (upcoming news)
✅ Auto-filters by symbol currencies (EUR/USD for EURUSD, USD for XAUUSD)

---

## Quick Start

### 1. Add to EA (RecoveryGridDirection_v2.mq5)

```cpp
#include <RECOVERY-GRID-DIRECTION_v2/core/NewsFilter.mqh>

input group "=== News Filter ==="
input bool   InpNewsFilterEnabled = true;   // Enable news avoidance
input int    InpNewsPreMinutes    = 30;     // Minutes before news to pause
input int    InpNewsPostMinutes   = 15;     // Minutes after news to pause
input bool   InpNewsHighOnly      = true;   // Filter only HIGH impact (false = MEDIUM+)

CNewsFilter g_news_filter;
```

### 2. Initialize in OnInit()

```cpp
int OnInit()
{
   if(InpNewsFilterEnabled)
   {
      g_news_filter.Init(_Symbol, InpNewsPreMinutes, InpNewsPostMinutes, InpNewsHighOnly);

      // For backtest: load historical news
      datetime start = D'2025.01.01 00:00';  // Your backtest start
      datetime end   = TimeCurrent();         // Your backtest end

      if(!g_news_filter.LoadNews(start, end))
         Print("[EA] Warning: News filter enabled but no calendar data available");
      else
         Print("[EA] News filter loaded ", g_news_filter.GetEventCount(), " events");

      // Optional: Print upcoming news
      g_news_filter.PrintUpcoming(TimeCurrent(), 48);  // Next 48 hours
   }

   return INIT_SUCCEEDED;
}
```

### 3. Check Before Opening Orders (OnTick)

```cpp
void OnTick()
{
   // Skip trading during news windows
   if(InpNewsFilterEnabled && g_news_filter.IsNewsTime(TimeCurrent()))
   {
      // Do NOT open new positions
      return;
   }

   // Normal trading logic
   // ...
}
```

---

## Integration with JobManager

If using Multi-Job system, add check in `JobManager.mqh`:

```cpp
bool CJobManager::UpdateJobs()
{
   // News filter check BEFORE job updates
   if(m_params.news_filter_enabled && g_news_filter.IsNewsTime(TimeCurrent()))
   {
      // Skip spawning new jobs during news
      // Existing jobs continue managing positions
      return true;
   }

   // Normal job update logic
   // ...
}
```

---

## Configuration Examples

### Conservative (Avoid all major news)
```
InpNewsFilterEnabled = true
InpNewsPreMinutes    = 60   // 1 hour before
InpNewsPostMinutes   = 30   // 30 min after
InpNewsHighOnly      = false  // Include MEDIUM impact
```

### Aggressive (Only avoid extreme volatility)
```
InpNewsFilterEnabled = true
InpNewsPreMinutes    = 15   // 15 min before
InpNewsPostMinutes   = 10   // 10 min after
InpNewsHighOnly      = true   // HIGH impact only
```

### XAUUSD (Gold - Very sensitive to US news)
```
InpNewsFilterEnabled = true
InpNewsPreMinutes    = 90   // 1.5 hours before (FOMC/NFP/CPI)
InpNewsPostMinutes   = 30
InpNewsHighOnly      = true   // Only USD HIGH events
```

---

## How It Works

### Symbol Currency Detection

- **EURUSD**: Filters EUR + USD news
- **GBPJPY**: Filters GBP + JPY news
- **XAUUSD**: Filters USD news only (XAU has no calendar events)

### MT5 Calendar API

Uses `CalendarValueHistory()` to load past events:

```cpp
MqlCalendarValue vals[];
CalendarValueHistory(vals, start_time, end_time);
```

Works in Strategy Tester because MT5 includes historical calendar data.

---

## Testing

### Backtest Verification

1. Enable logging: `InpLogEvents = true`
2. Run backtest on volatile period (e.g., NFP week)
3. Check Experts log for:
   ```
   [NewsFilter] Loaded 25 events for XAUUSD (XAU/USD) | Period: 2025.01.01 → 2025.01.31
   [NewsFilter] 🔴 In news window: USD 2025.01.10 14:30 (±30/15min) | Impact: HIGH
   ```

### Manual Test

Add to EA OnInit():
```cpp
g_news_filter.PrintUpcoming(TimeCurrent(), 72);  // Next 3 days
```

Expected output:
```
[NewsFilter] Upcoming events (next 72h):
  📅 2025.10.05 12:30 | USD | HIGH
  📅 2025.10.06 08:00 | EUR | MED
  📅 2025.10.07 14:30 | USD | HIGH
```

---

## Troubleshooting

### "No calendar data available"

**Cause**: MT5 calendar not synced
**Fix**:
1. Open MT5 → Tools → Options → Events
2. Enable "Economic Calendar"
3. Restart MT5
4. Wait for auto-sync (1-2 minutes)

### Filter not working in backtest

**Cause**: Backtest date range outside loaded news period
**Fix**:
```cpp
// Expand load range to cover entire backtest
datetime start = D'2024.01.01';  // Year before backtest
datetime end   = D'2026.01.01';  // Year after backtest
g_news_filter.LoadNews(start, end);
```

### Too many events filtered (no trades)

**Cause**: `InpNewsHighOnly = false` includes MEDIUM + HIGH
**Fix**:
- Set `InpNewsHighOnly = true` (HIGH only)
- Reduce `InpNewsPreMinutes` (e.g., 30 → 15)

---

## Advanced: Custom Impact Filter

To add specific event filtering (e.g., only NFP, CPI, FOMC):

```cpp
// In NewsFilter.mqh::LoadNewsForPeriod()
// Add after importance filter:

string title = evt.name;  // Event title

// Only filter specific events
if(StringFind(title, "Non-Farm") == -1 &&  // NFP
   StringFind(title, "CPI") == -1 &&        // Inflation
   StringFind(title, "FOMC") == -1)         // Fed meeting
   continue;  // Skip other events
```

---

## Performance Notes

- **Memory**: ~50 KB per 1000 events (negligible)
- **CPU**: O(n) scan per tick (n = event count, typically <100)
- **Optimization**: Cache result for 1 minute to reduce scans

---

## References

- MT5 Calendar API: https://www.mql5.com/en/docs/calendar
- CLAUDE.md: Project conventions
- NewsCalendar.mqh: Alternative API-based implementation (more complex)
