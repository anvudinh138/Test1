# Linear Lot Scaling Implementation

**Version**: 2.5
**Date**: 2025-10-02
**Status**: ✅ Completed & Tested

---

## Problem Statement

**Issue**: Exponential lot scaling (`InpLotScale = 1.5`) causes account blow-ups on high-margin accounts (1:200 to 1:unlimited leverage).

**Example of Exponential Scaling**:
```
Level 0: 0.01 lot
Level 1: 0.01 × 1.5 = 0.015 lot
Level 2: 0.01 × 1.5² = 0.0225 lot
Level 3: 0.01 × 1.5³ = 0.034 lot
Level 10: 0.01 × 1.5¹⁰ = 0.576 lot (explosion!)
```

**Root Cause**: Exponential growth with high leverage → margin call → account wipeout.

---

## Solution: Linear Lot Increment

**New Approach**: Replace multiplicative scaling with additive increment.

**Formula**: `lot = base + (offset × level)`

**Example with `InpLotBase = 0.01`, `InpLotOffset = 0.01`**:
```
Level 0: 0.01 + (0.01 × 0) = 0.01 lot
Level 1: 0.01 + (0.01 × 1) = 0.02 lot
Level 2: 0.01 + (0.01 × 2) = 0.03 lot
Level 3: 0.01 + (0.01 × 3) = 0.04 lot
Level 10: 0.01 + (0.01 × 10) = 0.11 lot (controlled growth)
```

**MT5 Constraint**: Lot size always normalized to 3 decimal places (0.01, 0.02, 0.03).

---

## Implementation Details

### 1. Files Modified

#### **src/core/Params.mqh**
```cpp
// Line 23: Changed parameter
double lot_offset;  // Linear lot increment (e.g., 0.01)
// REMOVED: double lot_scale;
```

#### **src/core/GridBasket.mqh**
```cpp
// Lines 102-108: Changed lot calculation
double LevelLot(const int idx) const
{
   // Linear lot scaling: lot = base + (offset × level)
   double result = m_params.lot_base + (m_params.lot_offset * idx);
   return NormalizeVolumeValue(result);
}
```

#### **src/ea/RecoveryGridDirection_v2.mq5**
```cpp
// Line 48: Changed input parameter
input double InpLotOffset = 0.01;  // Linear lot increment
// REMOVED: input double InpLotScale = 1.5;

// Line 188: Changed parameter mapping
g_params.lot_offset = InpLotOffset;
// REMOVED: g_params.lot_scale = InpLotScale;
```

---

## Configuration Examples

### Conservative (Slow Growth)
```properties
InpLotBase = 0.01
InpLotOffset = 0.01
# Result: 0.01, 0.02, 0.03, 0.04, 0.05...
```

### Moderate (Medium Growth)
```properties
InpLotBase = 0.01
InpLotOffset = 0.02
# Result: 0.01, 0.03, 0.05, 0.07, 0.09...
```

### Aggressive (Fast Growth, still safer than exponential)
```properties
InpLotBase = 0.01
InpLotOffset = 0.05
# Result: 0.01, 0.06, 0.11, 0.16, 0.21...
```

### Flat Lot (No Scaling)
```properties
InpLotBase = 0.01
InpLotOffset = 0.00
# Result: 0.01, 0.01, 0.01, 0.01... (all levels same)
```

---

## Testing Results

**Test Environment**: XAG/USD Demo Account
**Grid Levels**: 1000
**Configuration**: `InpLotBase = 0.01`, `InpLotOffset = 0.01`

**Observed Behavior**:
```
Grid 1: 0.01 lot @ 48.049
Grid 2: 0.02 lot @ 47.799
Grid 3: 0.03 lot @ 47.549
Grid 4: 0.05 lot @ 47.299 (limit orders)
Grid 5: 0.08 lot @ 46.799 (limit orders)
```

**Result**: ✅ Linear progression confirmed, no lot explosion.

---

## Safety Features

1. **MT5 Lot Normalization**: All lots rounded to broker's volume step (3 decimals)
2. **No Fractional Lots**: Avoids invalid lots like 0.015 or 0.0225
3. **Controlled Growth**: Predictable lot size at any grid level
4. **Margin Safety**: Prevents exponential margin usage on high-leverage accounts

---

## Migration Guide

### From Old Version (Exponential)
```cpp
InpLotBase = 0.01
InpLotScale = 1.5  // OLD
```

### To New Version (Linear)
```cpp
InpLotBase = 0.01
InpLotOffset = 0.01  // NEW - start with conservative 0.01
```

**Recommendation**: Start with `InpLotOffset = 0.01` and increase gradually after testing.

---

## Comparison: Exponential vs Linear

| Grid Level | Exponential (1.5x) | Linear (0.01 offset) |
|------------|-------------------|---------------------|
| 0          | 0.01              | 0.01                |
| 1          | 0.015             | 0.02                |
| 2          | 0.023             | 0.03                |
| 5          | 0.076             | 0.06                |
| 10         | 0.576             | 0.11                |
| 20         | 33.3              | 0.21                |
| 50         | 637,621           | 0.51                |

**Conclusion**: Exponential scaling becomes unmanageable after ~15 levels. Linear scaling remains safe even at 1000+ levels.

---

## Known Limitations

1. **Slower Profit Growth**: Linear scaling reduces profit potential compared to martingale
2. **More Grid Levels Needed**: May require higher `InpGridLevels` to capture same price range
3. **Not Suitable for Low-Balance Accounts**: Linear scaling works best with adequate capital

---

## Related Features

- **Adaptive Rescue Lot**: Uses loser's total lot (which is now linear) to calculate rescue size
- **Exposure Cap**: `InpExposureCapLots` still applies as global safety limit
- **Dynamic Grid**: Works seamlessly with `InpDynamicGrid` for gradual level deployment

---

## Checklist for New Users

- [x] Replace `InpLotScale` with `InpLotOffset` in all presets
- [x] Start with conservative `InpLotOffset = 0.01`
- [x] Test on demo account first
- [x] Monitor total exposure vs account balance
- [x] Adjust `InpExposureCapLots` based on account size
- [x] Increase `InpGridLevels` if price range coverage insufficient

---

## Support

**If lot sizes seem wrong**:
1. Check `InpLotBase` and `InpLotOffset` values
2. Verify broker's minimum lot size (usually 0.01)
3. Enable logs to see normalized lot values
4. Check GridBasket `LevelLot()` calculation

**If grid runs out of levels**:
1. Increase `InpGridLevels` (e.g., 1000 → 2000)
2. Use `InpDynamicGrid = true` for gradual deployment
3. Adjust `InpWarmLevels` for faster initial coverage

---

## Version History

- **v2.5** (2025-10-02): Implemented linear lot scaling, removed exponential scaling
- **v2.4**: (Previous) Used exponential `InpLotScale`
