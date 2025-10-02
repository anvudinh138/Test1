# ForexFactory News Calendar API Setup Guide

## Overview

The **Recovery Grid Direction v2 EA** now supports real-time economic news detection via the **ForexFactory Calendar API**. This replaces static time windows with dynamic news event tracking.

---

## Features

- **Real-time news data**: Fetches upcoming economic events from ForexFactory
- **Impact filtering**: High, Medium+, or All impact levels
- **Buffer window**: Configurable minutes before/after news events
- **Automatic fallback**: Uses static time windows if API fails
- **Smart caching**: Fetches calendar once per hour to minimize network overhead

---

## Step 1: Enable WebRequest in MetaTrader 5

**IMPORTANT**: MT5 blocks all WebRequest calls by default for security reasons. You must whitelist the ForexFactory API URL.

### Instructions:

1. **Open MT5** → Click **Tools** → **Options**
2. Go to **Expert Advisors** tab
3. Check **"Allow WebRequest for listed URLs:"**
4. Add this URL to the list:

```
https://nfs.faireconomy.media/ff_calendar_thisweek.json
```

5. Click **OK** to save

### Visual Guide:

![MT5 WebRequest Settings](https://i.imgur.com/placeholder.png)

```
┌─────────────────────────────────────────┐
│ Options                                 │
├─────────────────────────────────────────┤
│ Expert Advisors                         │
│                                         │
│ ☑ Allow WebRequest for listed URLs:    │
│                                         │
│ https://nfs.faireconomy.media/         │
│ ff_calendar_thisweek.json               │
│                                         │
│ [Add]  [Edit]  [Delete]                │
└─────────────────────────────────────────┘
```

---

## Step 2: Configure EA Parameters

When attaching the EA to a chart, configure the **Time-based Risk Management (TRM)** section:

### API Mode (Recommended):

```ini
InpTrmEnabled = true              # Master switch
InpTrmUseApiNews = true           # Use ForexFactory API
InpTrmImpactFilter = "High"       # High, Medium+, or All
InpTrmBufferMinutes = 30          # Minutes before/after news
InpTrmPauseOrders = true          # Pause grid during news
InpTrmCloseOnNews = false         # (Optional) Close positions before news
```

### Fallback Mode (Static Windows):

If you prefer manual control or API is unavailable:

```ini
InpTrmEnabled = true
InpTrmUseApiNews = false          # Disable API, use static windows
InpTrmNewsWindows = "08:30-09:00,14:00-14:30"  # UTC time windows
InpTrmPauseOrders = true
```

---

## Step 3: Verify API Connection

After attaching the EA, check the **Experts** tab logs:

### Success:

```
[RGDv2][XAUUSD][NewsCalendar] Initialized: filter=High, buffer=30 min
[RGDv2][XAUUSD][NewsCalendar] Loaded 15 events (filter: High impact)
[RGDv2][XAUUSD][LC][TRM-API] News window ENTERED: High [USD] Non-Farm Payrolls
```

### WebRequest Error:

```
[RGDv2][XAUUSD][NewsCalendar] WebRequest failed: error 4060 - Check Tools->Options->Expert Advisors->Allow WebRequest for URL: https://nfs.faireconomy.media/ff_calendar_thisweek.json
```

**Solution**: Go back to Step 1 and add the URL to whitelist.

### Fallback Activated:

```
[RGDv2][XAUUSD][NewsCalendar] Failed to fetch calendar - using cached events
[RGDv2][XAUUSD][LC][TRM-Static] News window ENTERED: 08:30-09:00 (UTC)
```

**Solution**: API temporarily unavailable, EA uses static windows from `InpTrmNewsWindows`.

---

## Step 4: Testing

### Test 1: API Fetch

1. Attach EA to chart with `InpTrmUseApiNews = true`
2. Check logs for `"Loaded X events"`
3. Verify no error 4060

### Test 2: News Detection

1. Wait for upcoming news event (or manually adjust system time for testing)
2. Watch for log: `"News window ENTERED: [event details]"`
3. Verify EA pauses grid orders (no new pendings during news)
4. After buffer expires, verify log: `"News window EXITED - trading resumed"`

### Test 3: Fallback

1. Temporarily block the URL (remove from whitelist)
2. Restart EA
3. Verify EA falls back to static windows: `"[TRM-Static] News window ENTERED"`

---

## Impact Filter Levels

| Filter    | Description                                      | Events Included          |
|-----------|--------------------------------------------------|--------------------------|
| `High`    | Only high-impact news (NFP, FOMC, GDP, etc.)     | ~5-10 events/week       |
| `Medium+` | High + medium impact (PMI, CPI, retail sales)    | ~20-30 events/week      |
| `All`     | All news events (low impact included)            | ~50+ events/week        |

**Recommendation**: Use `High` for most strategies. Use `Medium+` for conservative risk management.

---

## ForexFactory API Details

### Endpoint:

```
https://nfs.faireconomy.media/ff_calendar_thisweek.json
```

### JSON Structure:

```json
[
  {
    "title": "Non-Farm Payrolls",
    "country": "USD",
    "date": "2025-10-03 12:30:00",  // UTC
    "impact": "High",
    "forecast": "150K",
    "previous": "142K"
  },
  ...
]
```

### Caching:

- EA fetches calendar **every 1 hour**
- Cached events used between fetches
- If fetch fails, EA uses last successful cache

---

## Troubleshooting

### Issue: Error 4060 (WebRequest blocked)

**Solution**: Add URL to whitelist (Step 1)

### Issue: No events loaded

**Possible Causes**:
1. **No internet connection**: Check MT5 connectivity
2. **ForexFactory API down**: Wait or switch to fallback mode
3. **Impact filter too strict**: Try `Medium+` or `All`

**Solution**: Enable fallback with `InpTrmUseApiNews = false`

### Issue: API works but no news detected

**Check**:
1. Verify `InpTrmBufferMinutes` is reasonable (30 min recommended)
2. Check system time is UTC-synchronized
3. Confirm upcoming events exist in current week

**Debug**: Enable logging and check `"Loaded X events"` count

### Issue: Too many news pauses

**Solution**: Use stricter filter (`High` instead of `All`)

---

## Security Notes

### Why WebRequest is disabled by default:

MT5 blocks WebRequest to prevent:
- **Malicious EAs** sending account data to external servers
- **Unauthorized API calls** consuming network bandwidth
- **Man-in-the-middle attacks** via unverified URLs

### Is ForexFactory API safe?

✅ **Yes**:
- Read-only data (news calendar)
- No account credentials transmitted
- HTTPS encrypted connection
- Reputable source (ForexFactory = trusted forex community)

❌ **Never whitelist**:
- Unknown URLs
- HTTP (non-encrypted) endpoints
- Domains you don't recognize

---

## Advanced Configuration

### Custom News Window Logic:

You can modify `NewsCalendar.mqh` to add custom logic:

```cpp
// Example: Skip news on Fridays
bool ShouldIncludeEvent(const string impact, const datetime event_time) {
    MqlDateTime dt;
    TimeToStruct(event_time, dt);
    if(dt.day_of_week == 5)  // Friday
        return false;
    return impact == "High";
}
```

### Multiple Symbol Support:

Each EA instance (per chart) fetches its own calendar. To reduce network overhead:
- Consider using a global singleton for shared calendar data
- Or increase `m_fetch_interval_sec` from 3600 to 7200 (2 hours)

---

## Preset Configuration

### XAUUSD with News API:

```ini
; XAUUSD_Production.set
InpMagic=990045
InpSpacingStepPips=25.0
InpSpacingAtrMult=0.6
InpMinSpacingPips=12.0
InpSslEnabled=false

; TRM with API
InpTrmEnabled=true
InpTrmUseApiNews=true
InpTrmImpactFilter=High
InpTrmBufferMinutes=30
InpTrmPauseOrders=true
InpTrmCloseOnNews=false
```

### EURUSD with Static Fallback:

```ini
; EURUSD_Production.set
InpMagic=990046
InpSslEnabled=false

; TRM with static windows (API disabled)
InpTrmEnabled=true
InpTrmUseApiNews=false
InpTrmNewsWindows=08:30-09:00,14:00-14:30
InpTrmPauseOrders=true
```

---

## FAQ

### Q: Does this work in Strategy Tester (backtest)?

**A**: No. WebRequest is **disabled** in Strategy Tester. EA will automatically fall back to static windows defined in `InpTrmNewsWindows`.

### Q: How much network bandwidth does this use?

**A**: Minimal. ~50KB per fetch, once per hour = ~1MB per day per EA instance.

### Q: Can I use this with other brokers/servers?

**A**: Yes. ForexFactory API is broker-independent. Works with any MT5 broker that allows WebRequest.

### Q: What happens if ForexFactory changes their API?

**A**: EA will fail gracefully and fall back to static windows. You'll see log: `"Failed to fetch calendar - using cached events"`. Update `NewsCalendar.mqh` parsing logic if needed.

---

## Summary Checklist

- [ ] Enable WebRequest in MT5 (Tools → Options → Expert Advisors)
- [ ] Add URL: `https://nfs.faireconomy.media/ff_calendar_thisweek.json`
- [ ] Set `InpTrmEnabled = true`
- [ ] Set `InpTrmUseApiNews = true`
- [ ] Choose impact filter (`High` recommended)
- [ ] Set buffer minutes (30 recommended)
- [ ] Check logs for `"Loaded X events"`
- [ ] Verify no error 4060
- [ ] Test with upcoming news event

---

## Support

If you encounter issues:
1. Check logs in **Experts** tab
2. Verify WebRequest whitelist
3. Test fallback mode (`InpTrmUseApiNews = false`)
4. Contact support with log snippet

**Status**: ✅ Feature complete and ready for production testing

**Version**: Recovery Grid Direction v2.5+

**Last Updated**: 2025-10-02
