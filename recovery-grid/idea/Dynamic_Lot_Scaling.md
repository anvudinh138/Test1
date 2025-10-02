# Dynamic Lot Scaling (DLS) - Feature Specification

## Problem Statement

### Current Behavior (Fixed Lot Scaling)
```cpp
// Level 0: 0.01 (base)
// Level 1: 0.01 × 1.5 = 0.015
// Level 2: 0.015 × 1.5 = 0.0225
// Level 3: 0.0225 × 1.5 = 0.03375
// ...
// Total lot grows exponentially: lot[i] = base × scale^i
```

**Issues**:
1. **Same scaling in all conditions**:
   - Low volatility: Could use higher lot safely
   - High volatility: Risk margin call with aggressive scaling

2. **Ignores account health**:
   - DD 5%: Uses same scaling as DD 40%
   - No risk adaptation

3. **Deposit Load spikes** (Set 7 example):
   - Peak ~50% margin usage
   - Risk margin call during volatile clusters
   - No mechanism to reduce exposure during stress

### Evidence from Backtest (Set 7)
- Profit Factor: 5.64 ✅
- Equity DD: 42.98% ❌
- **Deposit Load**: ~50% peak ⚠️
- Result: Great profit but too risky for live

---

## Proposed Solution: Dynamic Lot Scaling (DLS)

### Core Concept
Replace fixed `scale^i` with **dynamic scale factor** that adapts to:
1. **Market volatility** (ATR ratio)
2. **Account health** (Equity DD%)

### Formula

```cpp
double CalculateDynamicLotScale()
{
    // Base scale from input (e.g., 1.5)
    double base_scale = m_params.lot_scale;

    // === Factor 1: Volatility Adaptation ===
    double atr_current = m_spacing.AtrPoints();
    double atr_initial = m_initial_atr;  // Captured at basket init

    double atr_ratio = (atr_initial > 0) ? (atr_current / atr_initial) : 1.0;

    // Inverse relationship: high ATR → lower multiplier
    double vol_factor = 1.0 / MathMax(atr_ratio, 0.5);  // Prevent div by tiny number
    vol_factor = MathPow(vol_factor, m_params.dls_vol_weight);  // Weight influence

    // === Factor 2: DD Adaptation ===
    double dd_pct = 0.0;
    if(m_ledger != NULL)
        dd_pct = m_ledger.GetEquityDrawdownPercent();

    // Linear reduction: 0% DD → factor 1.0, 100% DD → factor 0.3
    double dd_factor = 1.0 - (dd_pct / 100.0) * 0.7;  // Max 70% reduction
    dd_factor = MathMax(dd_factor, 0.3);  // Floor at 30%
    dd_factor = MathPow(dd_factor, m_params.dls_dd_weight);  // Weight influence

    // === Combine Factors ===
    double dynamic_scale = base_scale * vol_factor * dd_factor;

    // === Apply Bounds ===
    dynamic_scale = MathMax(dynamic_scale, m_params.dls_min_scale);
    dynamic_scale = MathMin(dynamic_scale, m_params.dls_max_scale);

    // === Logging (if enabled) ===
    if(m_log != NULL && m_params.dls_enabled)
    {
        m_log.Event(Tag(), StringFormat("[DLS] base=%.2f atr_ratio=%.2f vol_f=%.2f dd=%.1f%% dd_f=%.2f final=%.2f",
                                        base_scale, atr_ratio, vol_factor, dd_pct, dd_factor, dynamic_scale));
    }

    return dynamic_scale;
}
```

### Usage in LevelLot()

```cpp
double LevelLot(const int idx) const
{
    if(idx < 0) return 0.0;

    double lot = m_params.lot_base;

    if(m_params.dls_enabled)
    {
        // Dynamic scaling
        double dynamic_scale = CalculateDynamicLotScale();
        for(int i = 1; i <= idx; i++)
            lot *= dynamic_scale;
    }
    else
    {
        // Fixed scaling (original)
        for(int i = 1; i <= idx; i++)
            lot *= m_params.lot_scale;
    }

    return NormalizeVolumeValue(lot);
}
```

---

## Parameters

### Input Parameters (EA)
```cpp
input group "=== Dynamic Lot Scaling (DLS) ==="
input bool   InpDlsEnabled      = true;   // Enable dynamic lot scaling
input double InpDlsVolWeight    = 0.5;    // Volatility influence (0-1)
input double InpDlsDdWeight     = 0.5;    // Drawdown influence (0-1)
input double InpDlsMinScale     = 1.1;    // Min scale factor
input double InpDlsMaxScale     = 2.0;    // Max scale factor
```

### SParams Fields
```cpp
// In Params.mqh
struct SParams
{
    // ... existing fields ...

    // dynamic lot scaling
    bool         dls_enabled;
    double       dls_vol_weight;     // 0-1, weight of volatility factor
    double       dls_dd_weight;      // 0-1, weight of DD factor
    double       dls_min_scale;      // minimum scale (e.g., 1.1)
    double       dls_max_scale;      // maximum scale (e.g., 2.0)
};
```

---

## Examples

### Example 1: Low Volatility + Healthy Account
```
Conditions:
- ATR current: 15 points
- ATR initial: 20 points (ATR ratio = 0.75)
- Equity DD: 2%
- Base scale: 1.5
- Vol weight: 0.5
- DD weight: 0.5

Calculation:
1. vol_factor = (1 / 0.75)^0.5 = 1.155
2. dd_factor = (1 - 0.02 * 0.7)^0.5 = 0.993
3. dynamic_scale = 1.5 × 1.155 × 0.993 = 1.72

Result: HIGHER lot (calm market + healthy account)
- Level 0: 0.01
- Level 1: 0.0172
- Level 2: 0.0296
```

### Example 2: High Volatility + Deep DD
```
Conditions:
- ATR current: 40 points
- ATR initial: 20 points (ATR ratio = 2.0)
- Equity DD: 25%
- Base scale: 1.5
- Vol weight: 0.5
- DD weight: 0.5

Calculation:
1. vol_factor = (1 / 2.0)^0.5 = 0.707
2. dd_factor = (1 - 0.25 * 0.7)^0.5 = 0.904
3. dynamic_scale = 1.5 × 0.707 × 0.904 = 0.96
4. Clamped to min: max(0.96, 1.1) = 1.1

Result: LOWER lot (volatile market + stressed account)
- Level 0: 0.01
- Level 1: 0.011
- Level 2: 0.0121
```

### Example 3: Extreme Volatility Spike
```
Conditions:
- ATR current: 80 points (4× spike!)
- ATR initial: 20 points
- Equity DD: 40%
- Base scale: 1.5

Calculation:
1. vol_factor = (1 / 4.0)^0.5 = 0.5
2. dd_factor = (1 - 0.40 * 0.7)^0.5 = 0.831
3. dynamic_scale = 1.5 × 0.5 × 0.831 = 0.62
4. Clamped to min: 1.1

Result: MIN scale (1.1) - risk protection active
```

---

## Implementation Plan

### Phase 1: Add Parameters (15 min)
1. Add fields to `SParams` struct
2. Add input parameters to EA
3. Map inputs to params in `BuildParams()`

### Phase 2: Implement Calculation (30 min)
1. Add `CalculateDynamicLotScale()` to `GridBasket` private section
2. Add logging for diagnostics
3. Handle edge cases (no ledger, zero ATR, etc.)

### Phase 3: Integrate into LevelLot() (20 min)
1. Modify `LevelLot()` to check `dls_enabled` flag
2. Use dynamic scale when enabled
3. Preserve original logic when disabled

### Phase 4: Testing (60 min)
1. Create preset `11_DLS_Test.set` (clone from Set 10)
2. Enable DLS with balanced settings
3. Compare vs Set 10:
   - Deposit Load (target < 35%)
   - Max DD (maintain < 10%)
   - Profit Factor (maintain > 2.5)

**Total Time**: ~2 hours

---

## Testing Strategy

### Test Set 11: DLS Test
**Base**: Clone from Set 10 (ADC enabled)

**DLS Settings**:
- `InpDlsEnabled = true`
- `InpDlsVolWeight = 0.5` - Balanced ATR influence
- `InpDlsDdWeight = 0.5` - Balanced DD influence
- `InpDlsMinScale = 1.1` - Conservative floor
- `InpDlsMaxScale = 2.0` - Reasonable ceiling

**Comparison Metrics**:
| Metric | Set 10 (No DLS) | Set 11 (DLS) | Target |
|--------|-----------------|--------------|--------|
| Max DD % | < 10% | < 10% | ✅ Maintain |
| Profit Factor | > 2.5 | > 2.5 | ✅ Maintain |
| Deposit Load | ~40-50% | ? | **< 35%** ⬇️ |
| Win Rate | ~60% | ~60% | ✅ Maintain |
| Avg Lot Size | Fixed | Dynamic | Monitor |

### Success Criteria
- ✅ Deposit Load reduced by 20-30%
- ✅ DD stays < 10%
- ✅ PF stays > 2.5
- ✅ Logs show adaptive scaling

---

## Expected Behavior

### Scenario 1: Normal Market
```
ATR stable, DD low → Dynamic scale ≈ base scale (1.5)
Result: Similar to original behavior
```

### Scenario 2: Volatile Spike
```
ATR doubles, DD increases → Dynamic scale drops to min (1.1)
Result: Lower lot exposure, reduced margin usage
Benefit: Avoid margin call
```

### Scenario 3: Calm After Storm
```
ATR decreases, DD recovers → Dynamic scale increases to max (2.0)
Result: Maximize profit in favorable conditions
Benefit: Higher returns when safe
```

### Scenario 4: Deep DD Recovery
```
ATR normal, but DD 30% → DD factor reduces scale
Result: Conservative lot sizing during recovery
Benefit: Gradual healing, avoid re-drawdown
```

---

## Logging & Diagnostics

### Log Tags
All DLS events use `[DLS]` tag:

```
[DLS] base=1.50 atr_ratio=1.20 vol_f=0.91 dd=5.2% dd_f=0.96 final=1.32
[DLS] base=1.50 atr_ratio=2.50 vol_f=0.63 dd=15.0% dd_f=0.89 final=1.10 (MIN clamped)
[DLS] base=1.50 atr_ratio=0.60 vol_f=1.29 dd=1.0% dd_f=0.99 final=1.92
```

### What to Monitor
1. **atr_ratio**: Should reflect market volatility changes
2. **vol_f**: Should inverse correlate with ATR (high ATR → low factor)
3. **dd**: Real-time equity DD%
4. **dd_f**: Should decrease as DD increases
5. **final**: Clamped result, should stay within [min, max]

---

## Safety Features

### 1. Bounds Enforcement
- **Min Scale**: Prevents lot from shrinking too much (1.1 = still some scaling)
- **Max Scale**: Prevents excessive leverage (2.0 = conservative ceiling)

### 2. Edge Case Handling
```cpp
// Prevent division by zero
double atr_ratio = (atr_initial > 0) ? (atr_current / atr_initial) : 1.0;

// Prevent extreme ATR from causing negative factors
vol_factor = 1.0 / MathMax(atr_ratio, 0.5);  // Min divisor 0.5

// Always enforce floor on DD factor
dd_factor = MathMax(dd_factor, 0.3);  // Never below 30%
```

### 3. Enable/Disable Flag
- **Enabled**: Uses dynamic calculation
- **Disabled**: Falls back to original fixed scaling
- No breaking changes when disabled

### 4. Backward Compatibility
- Old presets work unchanged (DLS disabled by default)
- New presets can opt-in to DLS
- No impact on existing strategies

---

## Optimization Guide

### If Deposit Load Still High (> 35%)
1. **Lower max scale**: `InpDlsMaxScale = 1.8` (from 2.0)
2. **Increase DD weight**: `InpDlsDdWeight = 0.7` (from 0.5)
3. **Lower min scale**: `InpDlsMinScale = 1.05` (from 1.1)

### If Performance Drops (PF < 2.0)
1. **Increase max scale**: `InpDlsMaxScale = 2.5`
2. **Reduce DD weight**: `InpDlsDdWeight = 0.3`
3. **Check if ATR weight too high**: Maybe reduce to 0.3

### If Too Conservative (Lot always at min)
1. **Check ATR tracking**: Maybe `m_initial_atr` captured during spike
2. **Widen bounds**: `InpDlsMaxScale = 3.0`
3. **Reduce vol weight**: `InpDlsVolWeight = 0.3`

---

## Risks & Mitigation

### Risk 1: Over-Reduction
**Scenario**: Lot becomes too small, misses profit opportunities

**Mitigation**:
- Min scale floor (1.1) ensures some scaling
- Weights (0.5 each) prevent single factor from dominating
- Max scale (2.0) allows upside when conditions improve

### Risk 2: Complex Tuning
**Scenario**: Too many parameters to optimize

**Mitigation**:
- Start with balanced defaults (0.5, 0.5)
- Use preset testing to find sweet spot
- Document optimal ranges in README

### Risk 3: Unexpected Behavior
**Scenario**: Dynamic scale behaves differently than expected

**Mitigation**:
- Extensive logging shows all factors
- Can disable via flag if issues arise
- Tested scenarios documented

---

## Files to Modify

### 1. `/src/core/Params.mqh`
```cpp
// Add 5 new fields to SParams struct
bool   dls_enabled;
double dls_vol_weight;
double dls_dd_weight;
double dls_min_scale;
double dls_max_scale;
```

### 2. `/src/ea/RecoveryGridDirection_v2.mq5`
```cpp
// Add input group (6 lines)
input group "=== Dynamic Lot Scaling (DLS) ==="
input bool   InpDlsEnabled = true;
// ... 5 params

// Add mapping in BuildParams() (5 lines)
g_params.dls_enabled = InpDlsEnabled;
// ...
```

### 3. `/src/core/GridBasket.mqh`
```cpp
// Add private method (~30 lines)
double CalculateDynamicLotScale()

// Modify LevelLot() (~10 lines)
if(m_params.dls_enabled) { /* dynamic */ }
else { /* fixed */ }
```

**Total**: ~55 lines added

---

## Success Definition

### Must Have (Critical)
- ✅ Deposit Load reduced by 20%+ (< 40% from ~50%)
- ✅ DD stays ≤ 10%
- ✅ PF stays ≥ 2.5
- ✅ Feature can be disabled without breaking

### Nice to Have (Bonus)
- ✅ Deposit Load < 35% (30% reduction)
- ✅ PF improves to > 3.0
- ✅ Smoother equity curve (fewer spikes)
- ✅ Faster DD recovery

---

## Next Steps

1. ✅ Spec created (this document)
2. 🔄 Create branch from master
3. 🔄 Implement DLS feature
4. 🔄 Create preset 11_DLS_Test.set
5. 🔄 Run backtest comparison
6. 🔄 Document results
7. 🔄 Optimize if needed
8. 🔄 Merge if successful

---

**Priority**: ⭐⭐⭐⭐⭐ (Highest)
**Status**: 📝 Spec Complete, Ready to Implement
**Estimated Completion**: 2-3 hours
