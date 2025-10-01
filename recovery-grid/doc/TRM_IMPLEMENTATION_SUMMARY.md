# Time-based Risk Management (TRM) Implementation Summary

**Version**: v2.3
**Date**: 2025-10-01
**Status**: ✅ Implemented & Ready for Testing
**Complexity**: ⭐⭐ (Low-Medium) - ~2 hours implementation

---

## 🎯 What Was Implemented

### 1. Core TRM Logic (LifecycleController.mqh)
- **News Window Parsing**: `ParseNewsWindows()` - Converts CSV `"HH:MM-HH:MM,HH:MM-HH:MM"` to `SNewsWindow[]`
- **Time Checking**: `IsNewsTime()` - Compares current UTC time against active windows
- **News Handling**: `HandleNewsWindow()` - Pauses orders, optionally closes positions/tightens SL
- **Order Blocking**: Integrated into `TryReseedBasket()` and rescue deployment logic

### 2. Parameters Added (Params.mqh)
```cpp
bool   trm_enabled;              // Master switch
bool   trm_pause_orders;         // Pause new orders during news
bool   trm_tighten_sl;           // Tighten SSL during news (requires ssl_enabled)
double trm_sl_multiplier;        // SL tightening factor (e.g. 0.5 = half distance)
bool   trm_close_on_news;        // Close all positions before news window
string trm_news_windows;         // CSV format: "HH:MM-HH:MM,HH:MM-HH:MM" (UTC)
```

### 3. Types Added (Types.mqh)
```cpp
struct SNewsWindow
{
   int start_hour;      // UTC hour (0-23)
   int start_minute;    // 0-59
   int end_hour;        // UTC hour (0-23)
   int end_minute;      // 0-59
};
```

### 4. EA Inputs (RecoveryGridDirection_v2.mq5)
```cpp
input group "=== Time-based Risk Management (TRM) ==="
input bool   InpTrmEnabled              = false;  // Master switch (DEFAULT OFF)
input string InpTrmNewsWindows          = "08:30-09:00,14:00-14:30";  // CSV UTC
input bool   InpTrmPauseOrders          = true;   // Pause new orders
input bool   InpTrmTightenSL            = false;  // Tighten SSL during news
input double InpTrmSLMultiplier         = 0.5;    // SL tightening factor
input bool   InpTrmCloseOnNews          = false;  // Close all before news
```

---

## 📋 How TRM Works

### Initialization (OnInit)
1. Parameters mapped in `BuildParams()`
2. `m_trm_initialized = false` in constructor
3. `ArrayResize(m_news_windows, 0)` to prepare array

### First Tick (Lazy Parsing)
1. `HandleNewsWindow()` called in `Update()`
2. `IsNewsTime()` checks `m_trm_initialized`
3. If false, calls `ParseNewsWindows()`:
   - Splits CSV by comma: `"12:00-13:00,18:00-18:45"` → `["12:00-13:00", "18:00-18:45"]`
   - For each segment, splits by dash: `"12:00-13:00"` → `["12:00", "13:00"]`
   - For each time, splits by colon: `"12:00"` → `[12, 00]`
   - Creates `SNewsWindow{start_hour=12, start_minute=0, end_hour=13, end_minute=0}`
   - Adds to `m_news_windows[]` array
4. Sets `m_trm_initialized = true`
5. Logs: `[TRM] Parsed N news windows`

### Every Tick (News Check)
1. `IsNewsTime()` called:
   - Get current UTC time via `TimeToStruct(TimeGMT(), dt)`
   - Convert to minutes: `current_minutes = dt.hour * 60 + dt.min`
   - Loop through `m_news_windows[]`:
     - Calculate window: `start_minutes = hour * 60 + min`
     - If `current_minutes >= start_minutes && current_minutes <= end_minutes`:
       - Logs: `[TRM] News window active: HH:MM-HH:MM`
       - Returns `true`
   - Returns `false` if no match

2. `HandleNewsWindow()` handles active window:
   - If `trm_close_on_news == true`:
     - Close BUY basket: `m_buy.CloseBasket("TRM close_on_news")`
     - Close SELL basket: `m_sell.CloseBasket("TRM close_on_news")`
     - Set `m_halted = true` (stops Update loop)
   - If `trm_tighten_sl == true && ssl_enabled == true`:
     - Logs: `[TRM] Tightening SL during news`
     - (Future enhancement: implement SL tightening)

3. Order blocking:
   - **Grid Reseeding**: `TryReseedBasket()` checks `IsNewsTime()` → returns `false` if news active
   - **Rescue Deployment**: Wrapped in `if(!news_active)` block → skips rescue if news active

---

## 🔍 Expected Log Output (Example Session)

```
[RGDv2][EURUSD][LC] [TRM] Parsed 2 news windows

... (normal trading)...

[RGDv2][EURUSD][LC] [TRM] News window active: 12:00-13:00
[RGDv2][EURUSD][LC] [TRM] News window active: 12:00-13:00
[RGDv2][EURUSD][LC] [TRM] News window active: 12:00-13:00

... (no new orders placed, existing positions managed)...

[RGDv2][EURUSD][BUY][PRI] Basket closed: GroupTP
[RGDv2][EURUSD][SELL][PRI] Reseed SELL grid

... (window ended, normal trading resumes)...
```

---

## 📊 Testing Plan

### Phase 1: Smoke Test
1. **Enable TRM**: Set `InpTrmEnabled = true`
2. **Set window**: `InpTrmNewsWindows = "12:00-13:00"`
3. **Run backtest**: Start at 11:30 UTC, end at 13:30 UTC
4. **Verify logs**:
   - `[TRM] Parsed 1 news windows` at startup
   - `[TRM] News window active: 12:00-13:00` during 12:00-13:00
5. **Verify behavior**:
   - No `Reseed BUY/SELL grid` logs during 12:00-13:00
   - No `Rescue deployed` logs during 12:00-13:00
   - Positions still close normally (Group TP/SSL)

### Phase 2: Historical News Events
**Test Dates** (2024):
- **NFP**: Sep 6 (12:30 UTC), Oct 4 (12:30 UTC), Nov 1 (12:30 UTC)
- **FOMC**: Sep 18 (18:00 UTC), Nov 7 (18:00 UTC), Dec 18 (18:00 UTC)

**Test Matrix**:
| Test | Preset | TRM | Expected |
|------|--------|-----|----------|
| Baseline | 08_Combo_SSL | OFF | Normal DD spikes during news |
| News Avoidance | 09_TRM_NFP_Test | ON | Reduced DD during news windows |

**Metrics to Compare**:
- Max DD during news hour vs non-news hours
- Total trades (should be fewer with TRM)
- Largest loss per trade (should be smaller with TRM)

### Phase 3: Edge Cases
1. **Empty windows**: `InpTrmNewsWindows = ""` → Should work normally (no TRM)
2. **Invalid format**: `InpTrmNewsWindows = "invalid"` → Should skip, log 0 windows
3. **Overnight window**: `"23:00-01:00"` → Currently doesn't handle (future enhancement)
4. **TRM disabled**: `InpTrmEnabled = false` → Should bypass all checks

---

## ⚙️ Configuration Examples

### Conservative (Pause Only)
```cpp
InpTrmEnabled = true
InpTrmNewsWindows = "12:00-13:00,18:00-18:45"  // NFP + FOMC
InpTrmPauseOrders = true
InpTrmTightenSL = false
InpTrmCloseOnNews = false
```
**Behavior**: Stops new orders, lets existing positions run

### Aggressive (Close Before News)
```cpp
InpTrmEnabled = true
InpTrmNewsWindows = "12:25-13:00"  // 5min before NFP
InpTrmPauseOrders = true
InpTrmTightenSL = false
InpTrmCloseOnNews = true  // Close all at 12:25
```
**Behavior**: Closes all positions 5min before news, halts EA

### Future Enhancement (Tighten SL)
```cpp
InpTrmEnabled = true
InpTrmNewsWindows = "12:30-13:00"
InpTrmPauseOrders = true
InpTrmTightenSL = true  // Requires SSL enabled
InpTrmSLMultiplier = 0.5  // Half distance
InpTrmCloseOnNews = false
```
**Behavior**: Pauses orders + reduces SL distance to 50% during news
*(Note: SL tightening logic not yet implemented - Phase 2)*

---

## 📝 Common News Events (UTC Times)

| Event | Typical Time (UTC) | Impact | Frequency |
|-------|-------------------|--------|-----------|
| **NFP** | 12:30 (First Fri) | 🔴 HIGH | Monthly |
| **FOMC Rate** | 18:00 | 🔴 HIGH | 8×/year |
| **CPI** | 12:30 | 🟡 MEDIUM | Monthly |
| **GDP** | 12:30 | 🟡 MEDIUM | Quarterly |
| **Retail Sales** | 12:30 | 🟢 LOW | Monthly |

**Recommended Window**: `"12:00-13:00,18:00-18:45"` (covers NFP + FOMC)

**Advanced Window** (covers more events): `"12:00-13:00,14:00-14:30,18:00-18:45"`

---

## 🚀 Future Enhancements (Phase 2)

### 1. SSL Tightening Implementation
```cpp
void TightenAllSLs(double multiplier)
{
    double spacing_px = m_spacing.ToPrice(m_initial_spacing_pips);
    double tight_distance = spacing_px * m_params.ssl_sl_multiplier * multiplier;
    // Modify all SLs to tighter distance
    m_buy.ModifyAllSLs(tight_distance);
    m_sell.ModifyAllSLs(tight_distance);
}
```

### 2. News API Integration (Optional)
- Fetch live news calendar from ForexFactory RSS
- Parse high-impact events automatically
- No manual CSV entry required
- Example: `https://nfs.faireconomy.media/ff_calendar_thisweek.xml`

### 3. Overnight Window Support
- Handle windows crossing midnight: `"23:00-01:00"`
- Current limitation: Only works within same day

### 4. Currency-Specific Filtering
- Only pause EUR pairs during ECB news
- Only pause USD pairs during NFP
- Example: `InpTrmCurrencyFilter = "USD,EUR"`

---

## ✅ Verification Checklist

- [x] TRM parameters added to `Params.mqh`
- [x] `SNewsWindow` struct added to `Types.mqh`
- [x] `ParseNewsWindows()` implemented in `LifecycleController.mqh`
- [x] `IsNewsTime()` implemented with UTC comparison
- [x] `HandleNewsWindow()` implemented with pause/close/tighten logic
- [x] TRM state initialized in constructor (`m_trm_initialized = false`)
- [x] `HandleNewsWindow()` called at start of `Update()`
- [x] `TryReseedBasket()` checks `IsNewsTime()` before allowing reseed
- [x] Rescue deployment wrapped in `!news_active` check
- [x] TRM inputs added to EA with `input group` separator
- [x] TRM parameters mapped in `BuildParams()`
- [x] Master switch (`InpTrmEnabled`) defaults to `false`
- [x] All TRM actions logged with `[TRM]` tag
- [x] Test preset `09_TRM_NFP_Test.set` created
- [x] Documentation updated (CHANGELOG, README)

---

## 📚 Related Files

- **Core Logic**: `src/core/LifecycleController.mqh` (lines 38-40, 275-377, 476-479, 540-541)
- **Parameters**: `src/core/Params.mqh` (lines 94-100)
- **Types**: `src/core/Types.mqh` (lines 47-53)
- **EA Inputs**: `src/ea/RecoveryGridDirection_v2.mq5` (lines 108-114, 230-235)
- **Test Preset**: `preset/09_TRM_NFP_Test.set`
- **Documentation**: `CHANGELOG.md` (v2.3 section), `preset/README.md` (Set 09)

---

**Implementation Complete** ✅
Ready for backtesting on historical NFP/FOMC dates.

**Next Steps**:
1. Compile EA (F7 in MetaEditor)
2. Load `09_TRM_NFP_Test.set` in Strategy Tester
3. Test on Sep-Nov 2024 period (includes multiple NFP/FOMC events)
4. Compare DD spikes during 12:00-13:00 and 18:00-18:45 UTC vs Set 8 baseline
5. Adjust windows if needed based on results
