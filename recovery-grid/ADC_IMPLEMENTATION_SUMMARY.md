# Anti-Drawdown Cushion (ADC) - Implementation Summary

**Feature**: Priority 5 from Future_Features_Roadmap.md
**Version**: 2.4
**Date**: 2025-10-01
**Status**: ✅ Implemented & Ready for Testing

---

## 🎯 Purpose

Provide **equity-based drawdown protection** to achieve **sub-10% max equity DD** by pausing risky operations during drawdown periods and allowing existing positions to recover naturally.

---

## 🧠 Concept

**Problem**: Even with SSL (16.99% DD), strong adverse trends can still cause significant equity drawdown.

**Solution**: Monitor real-time equity DD% and enter "Cushion Mode" when threshold is breached:
- **Pause**: New grid reseeding, rescue hedge deployment
- **Allow**: Existing position closes (TP/SL), partial closes, basket completions
- **Resume**: Normal operations when equity recovers below threshold

**Key Insight**: Stop digging when in a hole. Let existing positions work their way out.

---

## 📊 How It Works

### 1. Equity Tracking (PortfolioLedger.mqh)
```cpp
double peak_equity = max(equity);  // Running maximum
double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
double dd_pct = ((peak - current) / peak) * 100.0;
```

### 2. Cushion State Detection
```cpp
if (dd_pct >= threshold) {
    // CUSHION MODE: Pause risky ops
} else {
    // NORMAL MODE: Resume trading
}
```

### 3. Blocking Logic (LifecycleController.mqh)

**Grid Reseeding** (TryReseedBasket):
```cpp
if (adc_enabled && adc_pause_new_grids) {
    if (equity_dd% > threshold) {
        Log("[ADC] BLOCKED reseed");
        return false;  // Don't seed new basket
    }
}
```

**Rescue Deployment** (Update):
```cpp
if (adc_enabled && adc_pause_rescue) {
    if (equity_dd% > threshold) {
        Log("[ADC] BLOCKED rescue");
        return;  // Don't deploy hedge
    }
}
```

### 4. State-Based Logging
```cpp
// Only log on transitions (no spam)
if (cushion_active && !was_cushion_active) {
    Log("[ADC] CUSHION ACTIVATED: Equity DD %.2f%% > %.2f%%", dd_pct, threshold);
}
if (!cushion_active && was_cushion_active) {
    Log("[ADC] CUSHION DEACTIVATED: Equity DD %.2f%% < %.2f%%", dd_pct, threshold);
}
```

---

## 🛠️ Implementation Details

### Files Modified

**1. src/core/Params.mqh**
- Added 4 new ADC parameters

**2. src/core/PortfolioLedger.mqh**
- Added `GetEquityDrawdownPercent()` - Calculate DD%
- Added `IsDrawdownCushionActive(threshold)` - Check cushion state

**3. src/core/LifecycleController.mqh**
- Added `m_adc_cushion_active` state variable
- Added ADC checks in `TryReseedBasket()` (blocks grid reseeding)
- Added ADC checks in `Update()` (blocks rescue, logs state transitions)
- Initialized state in constructor

**4. src/ea/RecoveryGridDirection_v2.mq5**
- Added 4 input parameters (ADC group)
- Mapped inputs to `g_params` in `BuildParams()`
- Updated version to 2.40
- Updated header comments

**5. preset/10_ADC_Test.set**
- Created test preset based on 08_Combo_SSL
- Enabled ADC with 10% threshold
- Disabled TRM to isolate ADC impact

**6. CHANGELOG.md**
- Added v2.4 section with full ADC documentation

**7. preset/README.md**
- Added Set 10 documentation with testing strategy

---

## 🎛️ Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpAdcEnabled` | bool | `false` | Master switch (DEFAULT OFF) |
| `InpAdcEquityDdThreshold` | double | `10.0` | % equity DD to activate cushion |
| `InpAdcPauseNewGrids` | bool | `true` | Block grid reseeding during cushion |
| `InpAdcPauseRescue` | bool | `true` | Block rescue deployment during cushion |

---

## 📝 Expected Logs

### Initialization
```
(No init logs - ADC calculates on-demand)
```

### Cushion Activation
```
[RGDv2][EURUSD][LC] [ADC] CUSHION ACTIVATED: Equity DD 10.23% > 10.00% - pausing risky operations
```

### Blocking Actions
```
[RGDv2][EURUSD][LC] [ADC] BLOCKED reseed BUY (equity DD 11.45% > 10.00%)
[RGDv2][EURUSD][LC] [ADC] BLOCKED rescue (equity DD 12.78% > 10.00%)
```

### Cushion Deactivation
```
[RGDv2][EURUSD][LC] [ADC] CUSHION DEACTIVATED: Equity DD 8.92% < 10.00% - resuming normal operations
```

**Log Volume**: ~2-10 logs per cushion event (entry + exit + occasional blocks)

---

## 🧪 Testing Strategy

### Test Setup
- **Preset**: `10_ADC_Test.set`
- **Symbol**: EURUSD
- **Period**: Same 2-month range as Set 8 (for direct comparison)
- **Baseline**: Set 8 (PC + DTS + SSL) - DD 16.99%, PF 5.76

### Success Criteria
✅ **Max Equity DD < 10%** (target: 40% reduction vs Set 8)
✅ **Profit Factor > 2.0** (acceptable tradeoff)
✅ **ADC activates during DD peaks** (check logs)
✅ **ADC deactivates during recovery** (check logs)
✅ **No infinite loops or stuck states**

### Comparison Table

| Metric | Set 8 (SSL) | Set 10 (ADC) | Target |
|--------|-------------|--------------|--------|
| Max Equity DD | 16.99% | **< 10%** | ✅ |
| Profit | $1,377 | $1,000+ | ✅ |
| Profit Factor | 5.76 | > 2.0 | ✅ |
| Trades | 230 | ~200-300 | ✅ |
| Win Rate | 73.04% | > 60% | ✅ |

---

## 🚀 Usage Examples

### Example 1: Conservative Trading (Default)
```cpp
InpAdcEnabled = true
InpAdcEquityDdThreshold = 10.0  // Activate at 10% DD
InpAdcPauseNewGrids = true
InpAdcPauseRescue = true
```
**Use Case**: Live trading with ultra-safe DD control

### Example 2: Aggressive (Higher Threshold)
```cpp
InpAdcEnabled = true
InpAdcEquityDdThreshold = 15.0  // More room before cushion
InpAdcPauseNewGrids = true
InpAdcPauseRescue = false      // Still allow rescue hedges
```
**Use Case**: Higher risk tolerance, allow some recovery attempts

### Example 3: Grid-Only Protection
```cpp
InpAdcEnabled = true
InpAdcEquityDdThreshold = 12.0
InpAdcPauseNewGrids = true      // Block grids
InpAdcPauseRescue = false       // Allow rescue (help recovery)
```
**Use Case**: Prevent grid martingale but allow hedge rescue

---

## 💡 Design Decisions

### Why 10% Default Threshold?
- SSL already reduced DD from 42.98% → 16.99%
- 10% gives ~40% additional reduction target
- Provides safety margin while allowing normal ops most of the time

### Why State-Based Logging?
- Prevents log spam (similar to TRM)
- Only logs on transitions (activate/deactivate)
- Easy to spot cushion events in Experts tab

### Why Pause Both Grids & Rescue?
- **Grids**: Prevent adding more exposure during adverse moves
- **Rescue**: Prevent counter-trend hedges that could increase risk
- **Allow Closes**: Existing positions can still hit TP/SL naturally

### Why Check on Every Tick?
- Equity changes every tick
- Need real-time detection to block risky ops immediately
- Efficient: Only calculates DD%, no heavy processing

---

## 🔧 Troubleshooting

### ADC Never Activates
**Symptom**: No `[ADC]` logs during test
**Cause**: Threshold too high OR DD never reached threshold
**Solution**:
- Check max equity DD in test report
- Lower `InpAdcEquityDdThreshold` to match actual DD range
- Verify `InpAdcEnabled = true`

### ADC Activates Too Frequently
**Symptom**: Cushion toggles rapidly
**Cause**: Threshold too low OR volatile equity
**Solution**:
- Increase threshold to 12-15%
- Add hysteresis (future enhancement)

### Profit Drops Too Much
**Symptom**: ADC reduces profit significantly
**Cause**: Blocking too many profitable opportunities
**Solution**:
- Increase threshold
- Set `InpAdcPauseRescue = false` (allow rescue)
- Consider hybrid approach (pause grids only)

### No Improvement in DD
**Symptom**: DD same as without ADC
**Cause**: ADC activates after DD peak
**Solution**:
- This is expected - ADC prevents DEEPER DD, not initial DD
- Compare DD duration, not just peak
- Look for prevention of "death spiral" scenarios

---

## 📈 Expected Impact

### Best Case Scenario
- **DD Reduction**: 16.99% → 8-10% (40-50% improvement)
- **Profit**: ~70-80% of Set 8 (acceptable tradeoff)
- **PF**: 3.0-4.0 (still strong)
- **Activation**: 2-5 times during 2-month test

### Realistic Scenario
- **DD Reduction**: 16.99% → 10-12% (30% improvement)
- **Profit**: ~80-90% of Set 8
- **PF**: 2.5-3.5
- **Activation**: 5-10 times

### Worst Case Scenario
- **DD Reduction**: 16.99% → 14-15% (minimal improvement)
- **Profit**: ~60% of Set 8 (too much blocking)
- **PF**: 1.8-2.2
- **Activation**: 15+ times (threshold too low)

→ If worst case occurs, increase threshold or disable feature.

---

## 🎯 Next Steps

1. **Compile** EA (F7 in MetaEditor)
2. **Load** Set 10 in Strategy Tester
3. **Run** backtest (EURUSD, 2 months, M1/M5)
4. **Check** logs for `[ADC]` activity
5. **Compare** metrics vs Set 8
6. **Optimize** threshold if needed (8%, 12%, 15%)
7. **Test** with TRM enabled (future: Set 11?)

---

## 🔮 Future Enhancements

### Phase 2 Ideas
- **Hysteresis**: Activate @ 10%, deactivate @ 8% (reduce toggling)
- **Partial Pause**: Allow rescue but with reduced lot size
- **Time-based**: Only pause if DD persists > X bars
- **Adaptive Threshold**: Adjust based on recent volatility

### Phase 3 Ideas
- **Multi-level Cushion**: 10% = pause grids, 15% = pause rescue, 20% = flatten
- **Integration with SSL**: Tighten SSL during cushion mode
- **Basket-specific**: Different thresholds for BUY vs SELL

---

**Implementation Time**: ~3 hours
**Complexity**: ⭐⭐ (Low)
**Impact**: ⭐⭐⭐⭐ (High - Target 10-15% additional DD reduction)
**Status**: ✅ Complete, Ready for Testing

---

**Files Summary**:
- Modified: 4 core files, 1 EA, 2 docs
- Created: 1 preset, 1 summary doc
- Total Lines Changed: ~150
- New Parameters: 4
- New Methods: 2

**Test Command**:
```
MetaEditor → Open RecoveryGridDirection_v2.mq5 → F7 (Compile)
MT5 Tester → Load 10_ADC_Test.set → Run
Check Experts tab for [ADC] logs
Compare Max Equity DD vs Set 8 (target < 10%)
```

🎉 **Implementation Complete!** Ready for backtest validation.
