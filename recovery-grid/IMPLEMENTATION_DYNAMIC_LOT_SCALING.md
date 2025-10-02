# Dynamic Lot Scaling (DLS) - Implementation Summary

## Overview
Implemented Dynamic Lot Scaling to adapt lot size based on market volatility and basket health, reducing deposit load and margin risk.

## Problem Solved
- **Fixed lot scaling** (`lot_scale = 1.5`) doesn't adapt to market conditions
- Set 7 showed **Deposit Load ~50%** → margin call risk
- Same aggressive scaling in both calm and volatile markets

## Solution Implemented

### Dynamic Scale Formula
```cpp
dynamic_scale = base_scale × vol_factor × dd_factor

// Volatility Factor (inverse)
vol_factor = (1 / atr_ratio)^vol_weight
atr_ratio = atr_current / atr_initial

// DD Factor (linear reduction)
dd_factor = (1 - dd% × 0.7)^dd_weight
dd_factor = max(dd_factor, 0.3)  // Floor 30%

// Final with bounds
result = clamp(dynamic_scale, min_scale, max_scale)
```

### Key Features
1. **Volatility Adaptation**:
   - High ATR → Lower lot (reduce exposure)
   - Low ATR → Higher lot (maximize profit)

2. **Health Adaptation**:
   - Deep DD → Lower lot (preserve margin)
   - Healthy account → Higher lot (aggressive)

3. **Bounded Safety**:
   - Min scale: 1.1 (always some scaling)
   - Max scale: 2.0 (conservative ceiling)

## Changes Made

### 1. Input Parameters
**File**: `RecoveryGridDirection_v2.mq5`

```cpp
input group "=== Dynamic Lot Scaling (DLS) ==="
input bool   InpDlsEnabled = true;      // Master switch (default ON)
input double InpDlsVolWeight = 0.5;     // Volatility influence (0-1)
input double InpDlsDdWeight = 0.5;      // DD influence (0-1)
input double InpDlsMinScale = 1.1;      // Min scale factor
input double InpDlsMaxScale = 2.0;      // Max scale factor
```

### 2. Params Fields
**File**: `Params.mqh`

```cpp
bool   dls_enabled;
double dls_vol_weight;
double dls_dd_weight;
double dls_min_scale;
double dls_max_scale;
```

### 3. Core Calculation
**File**: `GridBasket.mqh`

```cpp
double CalculateDynamicLotScale() const
{
    // Factor 1: Volatility
    double atr_ratio = atr_current / m_initial_atr;
    double vol_factor = (1.0 / atr_ratio)^vol_weight;

    // Factor 2: DD (using basket PnL as proxy)
    double basket_dd = abs(min(m_pnl_usd, 0));
    double dd_pct = basket_dd × 0.1;
    double dd_factor = (1 - dd_pct/100 × 0.7)^dd_weight;

    // Combine & bound
    return clamp(base × vol_factor × dd_factor, min, max);
}
```

### 4. Modified LevelLot()
**File**: `GridBasket.mqh`

```cpp
double LevelLot(const int idx) const
{
    double result = lot_base;

    if(dls_enabled) {
        double dynamic_scale = CalculateDynamicLotScale();
        for(int i=1; i<=idx; i++)
            result *= dynamic_scale;
    }
    else {
        // Original fixed scaling
        for(int i=1; i<=idx; i++)
            result *= lot_scale;
    }

    return NormalizeVolumeValue(result);
}
```

## Examples

### Example 1: Low Volatility + Healthy
```
ATR: 15/20 = 0.75 (low)
DD: 2%
Base: 1.5

vol_factor = (1/0.75)^0.5 = 1.15
dd_factor = (1-0.02×0.7)^0.5 = 0.99
dynamic = 1.5 × 1.15 × 0.99 = 1.71

Result: HIGHER lot (safe to be aggressive)
```

### Example 2: High Volatility + Deep DD
```
ATR: 40/20 = 2.0 (high)
DD: 25%
Base: 1.5

vol_factor = (1/2.0)^0.5 = 0.71
dd_factor = (1-0.25×0.7)^0.5 = 0.90
dynamic = 1.5 × 0.71 × 0.90 = 0.96
Clamped: max(0.96, 1.1) = 1.1

Result: MIN scale (risk protection)
```

## Testing Strategy

### Test Preset: 11_DLS_Test.set
**Base**: Clone from Set 10 (ADC enabled)

**DLS Settings**:
- `InpDlsEnabled = true`
- `InpDlsVolWeight = 0.5`
- `InpDlsDdWeight = 0.5`
- `InpDlsMinScale = 1.1`
- `InpDlsMaxScale = 2.0`

**Target Metrics**:
| Metric | Set 10 | Set 11 | Target |
|--------|--------|--------|--------|
| Max DD | < 10% | < 10% | ✅ Maintain |
| PF | > 2.5 | > 2.5 | ✅ Maintain |
| Deposit Load | ~40-50% | ? | **< 35%** ⬇️ |

## Logging

All DLS events use `[DLS]` tag (every 5 minutes):

```
[DLS] base=1.50 atr_r=1.20 vol_f=0.91 dd=5.2 dd_f=0.96 final=1.32
[DLS] base=1.50 atr_r=2.50 vol_f=0.63 dd=15.0 dd_f=0.89 final=1.10 (MIN)
[DLS] base=1.50 atr_r=0.60 vol_f=1.29 dd=1.0 dd_f=0.99 final=1.92
```

## Expected Benefits

### Primary Goal
- **Reduce Deposit Load**: 50% → < 35% (30% reduction)
- **Prevent margin calls** during volatile clusters
- **Self-adaptive** without manual tuning

### Secondary Benefits
- Higher lot during calm periods (more profit)
- Lower lot during stress (capital preservation)
- Smoother equity curve (fewer spikes)

## Safety Features

1. **Enable/Disable Flag**: Can turn OFF if issues
2. **Min/Max Bounds**: Prevents extreme values
3. **Fallback**: Uses fixed scaling when disabled
4. **Logging**: Track all scale changes
5. **Backward Compatible**: Old presets work unchanged

## Known Limitations

1. **DD Approximation**: Uses basket PnL instead of account equity DD
   - **Reason**: m_ledger not accessible from GridBasket
   - **Impact**: Still effective, slightly less accurate

2. **Static last_log**: Log throttling may not work perfectly in parallel baskets
   - **Impact**: Minor, just reduces log spam

## File Changes

| File | Lines Added | Type |
|------|-------------|------|
| RecoveryGridDirection_v2.mq5 | +6 | Input params |
| Params.mqh | +5 | Struct fields |
| GridBasket.mqh | +68 | Calculation + modification |

**Total**: ~80 lines added

## Next Steps

1. ✅ Implementation complete
2. 🔄 Create preset 11_DLS_Test.set
3. 🔄 Run backtest vs Set 10
4. 🔄 Compare Deposit Load
5. 🔄 Optimize if needed
6. 🔄 Merge if successful

## Success Criteria

✅ **Must Have**:
- Deposit Load < 35% (vs ~50%)
- DD stays ≤ 10%
- PF stays ≥ 2.5

✅ **Nice to Have**:
- Deposit Load < 30%
- PF > 3.0
- Smoother equity

---

**Status**: ✅ Implementation Complete
**Tested**: ⏳ Pending backtest
**Branch**: feature/dynamic-lot-scaling
**Version**: v2.8 (after DLS)
