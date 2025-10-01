# Smart Stop Loss (SSL) Implementation Summary

**Version**: v2.2
**Date**: 2025-10-01
**Status**: ✅ Implemented & Ready for Testing

---

## 🎯 What Was Implemented

### 1. Core SSL Logic (GridBasket.mqh)
- **Initial SL Placement**: `PlaceInitialStopLoss()` - Places SL at `avg_price ± (spacing × multiplier)` on basket activation
- **Breakeven Move**: `MoveAllStopsToBreakeven()` - Moves all SLs to breakeven when PnL ≥ threshold
- **Trailing by Average**: `ManageSmartStopLoss()` - Trails SL based on basket average price + offset
- **SL Application**: `ApplySmartStopLoss()` - Modifies position SLs with broker constraint checks
- **Better SL Check**: `IsBetterSL()` - Ensures SL only moves in favorable direction

### 2. Parameters Added
**Params.mqh**:
```cpp
bool   ssl_enabled;              // Master switch
double ssl_sl_multiplier;        // SL distance = spacing × this
double ssl_breakeven_threshold;  // USD profit to move to breakeven
bool   ssl_trail_by_average;     // Trail from average price
int    ssl_trail_offset_points;  // Trail offset in points
bool   ssl_respect_min_stop;     // Respect broker min stop level
```

**EA Inputs** (RecoveryGridDirection_v2.mq5):
```cpp
input group "=== Smart Stop Loss (SSL) ==="
input bool   InpSslEnabled              = false;  // Default OFF
input double InpSslSlMultiplier         = 3.0;
input double InpSslBreakevenThreshold   = 5.0;
input bool   InpSslTrailByAverage       = true;
input int    InpSslTrailOffsetPoints    = 100;
input bool   InpSslRespectMinStop       = true;
```

### 3. State Variables
```cpp
bool   m_ssl_be_moved;           // Breakeven already triggered
double m_ssl_current_trail_sl;   // Current trailing SL level
```

### 4. Integration Points
- **Basket Activation**: Resets SSL state, calls `PlaceInitialStopLoss()` after `RefreshState()`
- **Update Loop**: Calls `ManageSmartStopLoss()` every tick after `ManageTrailing()`
- **Constructor**: Initializes SSL state to `false/0.0`

---

## 📦 New Presets Created

### 07_Combo_Safer_v1.set
- Conservative DTS tuning (AtrWeight=0.7, DdThreshold=12)
- PC MinProfit=2.5
- **SSL: Disabled**
- **Target**: DD < 30%, PF > 3.0

### 07_Combo_Safer_v2.set
- Ultra-conservative DTS (AtrWeight=0.6, DdThreshold=15)
- PC MinProfit=3.0, CloseFraction=0.35
- **SSL: Disabled**
- **Target**: DD < 25%

### 08_Combo_SSL.set ⭐ **SSL Test Preset**
- Conservative DTS (from Safer_v1)
- PC MinProfit=2.5
- **SSL: Enabled** with default parameters
- **Target**: DD < 30% + hard SL protection

---

## 🔍 How SSL Works (Step-by-Step)

### On Basket Activation:
1. Basket becomes active → `PlaceInitialStopLoss()` called
2. Calculates: `sl_price = avg_price ± (spacing_px × InpSslSlMultiplier)`
3. Applies SL to all positions in basket
4. Logs: `[SSL] Initial SL placed at X (spacing=Y × mult=Z)`

### Every Tick (if enabled):
1. `ManageSmartStopLoss()` called from `Update()`
2. **Phase 1: Breakeven Check**
   - If `!m_ssl_be_moved && m_pnl_usd >= InpSslBreakevenThreshold`:
     - Move all SLs to `avg_price`
     - Set `m_ssl_be_moved = true`
     - Logs: `[SSL] Breakeven triggered at PnL=X USD, SL moved to avg=Y`
3. **Phase 2: Trailing (if BE already moved or PnL > 0)**
   - If `InpSslTrailByAverage && m_pnl_usd > 0`:
     - Calculate: `new_sl = avg_price ± InpSslTrailOffsetPoints`
     - If `IsBetterSL(new_sl, m_ssl_current_trail_sl)`:
       - Apply `new_sl` to all positions
       - Logs: `[SSL] Trail SL to X (avg=Y offset=Z pts)`

### Broker Constraint Check:
- If `InpSslRespectMinStop = true`:
  - Checks `SYMBOL_TRADE_STOPS_LEVEL`
  - Adjusts SL to respect minimum distance
  - Logs: `[SSL] SL X too close (min=Y points), adjusting`

---

## 📊 Testing Plan

### Phase 1: Baseline Comparison (Priority)
1. **Test 07_Combo_Safer_v1.set** (no SSL)
   - Record: Final Balance, Max Equity DD%, PF, Win Rate
2. **Test 08_Combo_SSL.set** (with SSL)
   - Same metrics
3. **Compare**:
   - Did SSL reduce Max Equity DD?
   - Did SSL reduce Deposit Load peaks?
   - Did SSL lock profits earlier (check balance staircase)?
   - Were there premature SL hits (check total trades)?

### Phase 2: SSL Parameter Tuning (if Phase 1 shows promise)
**If SSL causes premature exits**:
- ↑ `InpSslSlMultiplier`: 3.0 → 4.0 (wider initial SL)
- ↑ `InpSslBreakevenThreshold`: 5.0 → 7.0-10.0 (later BE move)
- ↑ `InpSslTrailOffsetPoints`: 100 → 150-200 (looser trail)

**If SSL works well**:
- Test with Set 7 original DTS (aggressive) + SSL
- ↓ `InpSslBreakevenThreshold`: 5.0 → 3.0 (earlier profit lock)
- Consider enabling SSL in all future presets

### Phase 3: Edge Case Testing
- Test on flash crash periods (e.g., 2020-03-12, CHF spike 2015-01-15)
- Verify broker stops level handling
- Check SL spam frequency (should only modify when `IsBetterSL()`)
- Test interaction with Partial Close (PC should close, SSL should protect remaining)

---

## 📝 Expected Log Output (Example Session)

```
[RGDv2][EURUSD][BUY][PRI] Grid seeded levels=6
[SSL] Initial SL placed at 1.08123 (spacing=25.0 × mult=3.0)
[SSL] Applied SL=1.08123 to 3 positions

... (basket accumulates)...

[SSL] Breakeven triggered at PnL=5.23 USD, SL moved to avg=1.08450
[SSL] Applied SL=1.08450 to 8 positions

... (price moves favorably)...

[SSL] Trail SL to 1.08550 (avg=1.08450 offset=100 pts)
[SSL] Applied SL=1.08550 to 8 positions

[SSL] Trail SL to 1.08600 (avg=1.08500 offset=100 pts)
[SSL] Applied SL=1.08600 to 8 positions

... (Group TP or SL hit)...

[RGDv2][EURUSD][BUY][PRI] Basket closed: GroupTP
```

---

## ✅ Verification Checklist

- [x] SSL parameters added to `Params.mqh`
- [x] SSL inputs added to EA with `input group` separator
- [x] SSL state variables added to `GridBasket` private section
- [x] SSL methods implemented: `PlaceInitialStopLoss()`, `ManageSmartStopLoss()`, `ApplySmartStopLoss()`, `MoveAllStopsToBreakeven()`, `IsBetterSL()`
- [x] SSL state initialized in constructor
- [x] SSL state reset on basket activation
- [x] `ManageSmartStopLoss()` called in `Update()`
- [x] `PlaceInitialStopLoss()` called after `RefreshState()` on activation
- [x] Master switch (`InpSslEnabled`) defaults to `false`
- [x] All SSL actions logged with `[SSL]` tag
- [x] Broker stops level check implemented (optional via `InpSslRespectMinStop`)
- [x] Preset 08_Combo_SSL.set created with SSL enabled
- [x] Presets 07_Combo_Safer_v1/v2.set created for A/B testing
- [x] README.md updated with SSL documentation and testing guide

---

## 🚀 Next Steps for User

1. **Compile EA**: Open `RecoveryGridDirection_v2.mq5` in MetaEditor → Press F7
2. **Load Preset**: Strategy Tester → Settings → Load → `08_Combo_SSL.set`
3. **Run Backtest**: Same date range as Set 7 (for comparison)
4. **Check Logs**: Experts tab → Look for `[SSL]` tags
5. **Compare Metrics**:
   - Max Equity DD: Set 7 (42.98%) vs Set 8 (< 30% target?)
   - Deposit Load: Set 7 (~50% peak) vs Set 8 (< 35% target?)
   - Profit Factor: Set 7 (5.64) vs Set 8 (> 3.0 target?)
6. **Report Back**: Share screenshot of backtest report + graph

---

## 📚 Related Files

- **Core Logic**: `src/core/GridBasket.mqh` (lines 60-62, 518-698, 1030-1031, 1127)
- **Parameters**: `src/core/Params.mqh` (lines 86-92)
- **EA Inputs**: `src/ea/RecoveryGridDirection_v2.mq5` (lines 89-95, 204-209)
- **Presets**: `preset/07_Combo_Safer_v1.set`, `preset/07_Combo_Safer_v2.set`, `preset/08_Combo_SSL.set`
- **Documentation**: `preset/README.md` (lines 191-271, 360-368, 394-406)

---

**Implementation Complete** ✅
Ready for backtesting and optimization.
