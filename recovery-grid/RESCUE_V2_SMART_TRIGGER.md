# Rescue v2: Smart Trigger with Adaptive Lot Threshold

**Version**: 2.5
**Date**: 2025-10-02
**Branch**: `feature/rescue-v2-smart-trigger`
**Status**: ✅ Ready for Testing & PR

---

## Problem Statement

### Issue 1: Rescue Triggered Too Early
**Symptom**: Rescue deploys when loser basket has only 0.01-0.02 lot (first grid level).

**Root Cause**:
```cpp
// OLD LOGIC (RescueEngine.mqh)
bool breach = BreachLastGrid(...);  // Price beyond last grid
bool dd = (loser_dd_usd >= InpDDOpenUSD);  // DD threshold
return breach || dd;  // Trigger on EITHER condition
```

**Result**:
- Price breaches last grid → rescue triggers immediately
- Loser has only 0.01 lot → Adaptive rescue = 0.01 × 1.0 = 0.01 lot
- Ineffective rescue (too small to help)

### Issue 2: Too Many Unused Parameters
**Old Parameters** (now removed):
- `InpRecoveryLot` (replaced by `InpRescueMinLot`)
- `InpDDOpenUSD` (DD-based trigger removed)
- `InpOffsetRatio` (hardcoded to 1.0 spacing)
- `InpMaxCyclesPerSide` (no longer needed)
- `InpCooldownBars` (no longer needed)

**Problem**: Cluttered UI, confusing for users.

---

## Solution: Smart Adaptive Threshold

### New Logic Flow

```
1. Price breaches last grid level? (YES/NO)
   ↓ NO → No rescue
   ↓ YES
2. Calculate adaptive rescue lot:
   ├─ Get loser's total lot (e.g., 0.08)
   ├─ Check: loser_lot >= InpRescueMinLoserLot? (0.05)
   │  ├─ YES → Adaptive mode:
   │  │         rescue_lot = loser_lot × multiplier
   │  │         Apply caps: MIN(max_lot, MAX(min_lot, rescue_lot))
   │  │         Log: [RESCUE-ADAPTIVE]
   │  └─ NO  → Fixed mode:
   │            rescue_lot = InpRescueMinLot (0.02)
   │            Log: [RESCUE-FIXED] (loser too small)
   └─ Deploy rescue with calculated lot
```

### Key Changes

#### 1. Trigger Condition: Breach Only (Removed DD)
```cpp
// NEW LOGIC
bool ShouldRescue(...) const
{
   bool breach = BreachLastGrid(...);
   return breach;  // Only price breach, no DD check
}
```

**Why**:
- DD threshold (`InpDDOpenUSD = 10000`) was too high → never triggered
- Breach alone is sufficient (price running away from grid)
- Simpler logic, easier to understand

#### 2. Adaptive Lot Threshold
```cpp
// NEW LOGIC (LifecycleController.mqh)
double loser_lot = loser.TotalLot();

if(loser_lot >= m_params.rescue_min_loser_lot)  // e.g., >= 0.05
{
   // ADAPTIVE: Match loser's lot
   rescue_lot = loser_lot × multiplier;  // 0.08 × 1.0 = 0.08
}
else
{
   // FIXED: Use min lot (loser too small)
   rescue_lot = m_params.rescue_min_lot;  // 0.02
}
```

**Why**:
- Prevents rescue with 0.01 lot when loser has 0.08 lot
- Waits until loser accumulates enough position before adaptive matching
- Early rescues use fixed min lot (safe, predictable)

#### 3. Removed Unnecessary Guards
**OLD**: Cooldown + Cycles + DD threshold
**NEW**: Only exposure cap

**Why**:
- Cooldown: Rescue only triggers on breach (already rate-limited by price movement)
- Cycles: No longer needed (rescue effectiveness now based on lot size, not count)
- DD: Replaced by adaptive lot threshold (more precise control)

---

## New Parameters

### Simplified Rescue Inputs

```cpp
input group "=== Rescue/Hedge System ==="
input string InpRecoverySteps       = "1000,2000,3000";  // Staged limit offsets
input bool   InpRescueAdaptiveLot   = true;              // ✅ Match loser's lot
input double InpRescueLotMultiplier = 1.0;               // 1.0 = exact match
input double InpRescueMaxLot        = 0.50;              // Max rescue lot (cap)
input double InpRescueMinLot        = 0.02;              // Min rescue lot (floor)
input double InpRescueMinLoserLot   = 0.05;              // Threshold for adaptive

input group "=== Risk Management ==="
input double InpExposureCapLots  = 2.0;     // Max total lot exposure
input double InpSessionSL_USD    = 100000;  // Session stop loss
```

**Total**: 8 parameters (down from 13)

---

## Parameter Details

### 1. `InpRecoverySteps` (unchanged)
**Type**: `string`
**Default**: `"1000,2000,3000"`
**Purpose**: Points offsets for staged limit orders after market rescue entry
**Example**: Market @ 1.1380, Limits @ 1.1370, 1.1360, 1.1350 (for SELL rescue)

### 2. `InpRescueAdaptiveLot` ⭐ NEW FLAG
**Type**: `bool`
**Default**: `true`
**Purpose**: Enable adaptive lot matching based on loser's size
- `true`: Use adaptive logic (recommended)
- `false`: Always use fixed `InpRescueMinLot`

### 3. `InpRescueLotMultiplier` (unchanged)
**Type**: `double`
**Default**: `1.0`
**Purpose**: Scale factor for adaptive lot
**Examples**:
- `1.0` = Exact match (loser 0.08 → rescue 0.08)
- `0.8` = Conservative (loser 0.08 → rescue 0.064)
- `1.2` = Aggressive (loser 0.08 → rescue 0.096)

### 4. `InpRescueMaxLot` (unchanged)
**Type**: `double`
**Default**: `0.50`
**Purpose**: Maximum rescue lot (safety cap)
**Prevents**: Over-leveraging during extreme drawdowns
**Example**: Loser 2.00 lot → capped at 0.50 lot

### 5. `InpRescueMinLot` ⭐ RENAMED (was `InpRecoveryLot`)
**Type**: `double`
**Default**: `0.02`
**Purpose**: Minimum rescue lot (floor)
**Used when**:
- Adaptive disabled (`InpRescueAdaptiveLot = false`)
- Loser below threshold (`loser_lot < InpRescueMinLoserLot`)
- Calculated adaptive lot too small

### 6. `InpRescueMinLoserLot` ⭐ NEW
**Type**: `double`
**Default**: `0.05`
**Purpose**: Minimum loser lot to trigger adaptive matching
**Logic**:
- Loser >= 0.05 lot → Adaptive mode (match loser)
- Loser < 0.05 lot → Fixed mode (use min lot 0.02)

**Why 0.05 default?**:
- With linear scaling (0.01 offset), 0.05 = level 4 (0.01+0.02+0.03+0.04)
- Ensures loser has accumulated meaningful position before adaptive rescue
- Prevents tiny rescues (0.01 lot) that can't help

### 7. `InpExposureCapLots` (moved to Risk group)
**Type**: `double`
**Default**: `2.0`
**Purpose**: Global lot exposure limit
**Still enforced**: Rescue blocked if `total_exposure + rescue_lot > cap`

### 8. `InpSessionSL_USD` (moved to Risk group)
**Type**: `double`
**Default**: `100000`
**Purpose**: Session-wide stop loss in USD
**Halts EA**: When total realized + unrealized loss exceeds this

---

## Configuration Examples

### Example 1: Conservative (Small Account)
```properties
InpRescueAdaptiveLot   = true
InpRescueLotMultiplier = 0.8     # 80% of loser
InpRescueMaxLot        = 0.20    # Low cap
InpRescueMinLot        = 0.01    # Small floor
InpRescueMinLoserLot   = 0.03    # Low threshold
InpExposureCapLots     = 1.0     # Tight limit
```

**Behavior**:
- Loser 0.01-0.02 lot → Rescue 0.01 lot (fixed)
- Loser 0.05 lot → Rescue 0.04 lot (0.05 × 0.8)
- Loser 0.30 lot → Rescue 0.20 lot (capped)

### Example 2: Balanced (Medium Account)
```properties
InpRescueAdaptiveLot   = true
InpRescueLotMultiplier = 1.0     # 100% match
InpRescueMaxLot        = 0.50    # Medium cap
InpRescueMinLot        = 0.02    # Standard floor
InpRescueMinLoserLot   = 0.05    # Standard threshold
InpExposureCapLots     = 2.0     # Moderate limit
```

**Behavior**:
- Loser 0.01-0.04 lot → Rescue 0.02 lot (fixed)
- Loser 0.08 lot → Rescue 0.08 lot (exact match)
- Loser 0.80 lot → Rescue 0.50 lot (capped)

### Example 3: Aggressive (Large Account)
```properties
InpRescueAdaptiveLot   = true
InpRescueLotMultiplier = 1.2     # 120% of loser
InpRescueMaxLot        = 1.00    # High cap
InpRescueMinLot        = 0.05    # Large floor
InpRescueMinLoserLot   = 0.10    # High threshold
InpExposureCapLots     = 5.0     # Loose limit
```

**Behavior**:
- Loser 0.01-0.09 lot → Rescue 0.05 lot (fixed)
- Loser 0.15 lot → Rescue 0.18 lot (0.15 × 1.2)
- Loser 1.00 lot → Rescue 1.00 lot (capped)

---

## Real Trading Scenario (From Your Chart)

### Before (Old Logic)
```
Grid State:
- BUY basket: 0.01 lot @ 1.13845 (grid 1)
- Price drops to 1.13444 → Breaches last grid
- Rescue triggers: SELL 0.01 lot (too small!)

Problem:
- Price continues down, BUY accumulates: 0.02, 0.03, 0.04, 0.05, 0.06 lot
- BUY total: 0.21 lot (avg price ~1.13550)
- SELL rescue: 0.01 lot (ineffective, can't pull BUY TP closer)
```

### After (Rescue v2)
```
Grid State:
- BUY basket: 0.01 lot @ 1.13845 (grid 1)
- Price drops to 1.13444 → Breaches last grid
- Loser check: 0.01 lot < 0.05 threshold
- Rescue triggers: SELL 0.02 lot (fixed min lot)
  Log: [RESCUE-FIXED] Loser=0.01 lot < threshold 0.05 → Rescue=0.02 lot

Price continues down:
- BUY accumulates: 0.02, 0.03, 0.04 lot (total 0.10 lot)
- Price drops to 1.13205 → Breaches again
- Loser check: 0.10 lot >= 0.05 threshold ✅
- Rescue triggers: SELL 0.10 lot (adaptive match!)
  Log: [RESCUE-ADAPTIVE] Loser=0.10 lot → Rescue=0.10 lot (mult=1.00, cap=0.50)

Result:
- BUY 0.10 lot @ avg 1.13500
- SELL 0.10 lot @ avg 1.13300
- Symmetric hedge → Effective rescue!
```

---

## Implementation Details

### Files Modified

#### 1. `Params.mqh` (Lines 40-48)
**Removed**:
- `recovery_lot`
- `dd_open_usd`
- `offset_ratio`
- `max_cycles_per_side`
- `cooldown_bars`

**Added**:
- `rescue_min_lot`
- `rescue_min_loser_lot`

#### 2. `RecoveryGridDirection_v2.mq5` (Lines 62-72)
**Removed inputs**:
- `InpRecoveryLot`
- `InpDDOpenUSD`
- `InpOffsetRatio`
- `InpMaxCyclesPerSide`
- `InpCooldownBars`

**Added inputs**:
- `InpRescueMinLot`
- `InpRescueMinLoserLot`

**Reorganized**: Created `input group "=== Rescue/Hedge System ==="` and `input group "=== Risk Management ==="`

#### 3. `LifecycleController.mqh` (Lines 763-819)
**Changed**: Adaptive lot logic with threshold check
```cpp
if(loser_lot >= m_params.rescue_min_loser_lot)
{
   // Adaptive mode
   rescue_lot = loser_lot × multiplier;
   // caps...
   Log: [RESCUE-ADAPTIVE]
}
else
{
   // Fixed mode
   rescue_lot = min_lot;
   Log: [RESCUE-FIXED]
}
```

#### 4. `RescueEngine.mqh` (Lines 22-30, 60-69)
**Changed**: Removed `offset_ratio`, use full spacing for breach detection
**Changed**: `ShouldRescue()` returns only `breach` (removed DD condition)

---

## Log Output Examples

### Scenario 1: Loser Below Threshold (Fixed Mode)
```
[RGDv2][EURUSD] [RESCUE-FIXED] Loser=0.03 lot < threshold 0.05 → Rescue=0.02 lot (fixed)
[RGDv2][EURUSD] Rescue deployed: 0.02 lot
```

### Scenario 2: Loser Above Threshold (Adaptive Mode)
```
[RGDv2][EURUSD] [RESCUE-ADAPTIVE] Loser=0.12 lot → Rescue=0.12 lot (mult=1.00, cap=0.50)
[RGDv2][EURUSD] Rescue deployed: 0.12 lot
```

### Scenario 3: Rescue Capped
```
[RGDv2][EURUSD] [RESCUE-ADAPTIVE] Loser=0.80 lot → Rescue=0.50 lot (mult=1.00, cap=0.50)
[RGDv2][EURUSD] Rescue deployed: 0.50 lot
```

### Scenario 4: Exposure Cap Blocks Rescue
```
[RGDv2][EURUSD] [RESCUE-ADAPTIVE] Loser=0.15 lot → Rescue=0.15 lot (mult=1.00, cap=0.50)
[RGDv2][EURUSD] Rescue blocked: Exposure cap (0.15 lot exceeds limit)
```

---

## Testing Checklist

### Test Case 1: Early Breach (Loser < Threshold)
**Setup**:
- `InpRescueMinLoserLot = 0.05`
- BUY basket: 0.01 lot (grid 1)
- Price drops → breach

**Expected**:
- ✅ Rescue triggers with fixed `InpRescueMinLot` (0.02)
- ✅ Log: `[RESCUE-FIXED] Loser=0.01 lot < threshold 0.05`

### Test Case 2: Late Breach (Loser >= Threshold)
**Setup**:
- `InpRescueMinLoserLot = 0.05`
- BUY basket: 0.10 lot (accumulated)
- Price drops → breach

**Expected**:
- ✅ Rescue triggers with adaptive lot (0.10 × 1.0 = 0.10)
- ✅ Log: `[RESCUE-ADAPTIVE] Loser=0.10 lot → Rescue=0.10 lot`

### Test Case 3: Max Cap Applied
**Setup**:
- `InpRescueMaxLot = 0.50`
- BUY basket: 0.80 lot (large position)
- Price drops → breach

**Expected**:
- ✅ Rescue capped at 0.50 lot
- ✅ Log shows cap applied

### Test Case 4: Exposure Cap Blocks
**Setup**:
- `InpExposureCapLots = 2.0`
- Current exposure: 1.90 lot
- Adaptive rescue: 0.20 lot (total 2.10 > cap)

**Expected**:
- ✅ Rescue blocked
- ✅ Log: `Rescue blocked: Exposure cap`

### Test Case 5: Adaptive Disabled
**Setup**:
- `InpRescueAdaptiveLot = false`
- BUY basket: 0.15 lot

**Expected**:
- ✅ Rescue uses fixed `InpRescueMinLot` (ignore loser size)
- ✅ No adaptive log

---

## Migration Guide

### From Previous Version

**Old Config**:
```properties
InpRecoveryLot = 0.02
InpDDOpenUSD = 10000
InpOffsetRatio = 0.5
InpMaxCyclesPerSide = 3
InpCooldownBars = 5
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.0
InpRescueMaxLot = 0.50
```

**New Config** (Rescue v2):
```properties
# REMOVED: InpRecoveryLot, InpDDOpenUSD, InpOffsetRatio, InpMaxCyclesPerSide, InpCooldownBars

# NEW PARAMETERS:
InpRescueMinLot = 0.02          # Replaces InpRecoveryLot
InpRescueMinLoserLot = 0.05     # NEW threshold

# UNCHANGED:
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.0
InpRescueMaxLot = 0.50
```

**Steps**:
1. Remove old parameters from preset files
2. Add `InpRescueMinLot = 0.02` (use old `InpRecoveryLot` value)
3. Add `InpRescueMinLoserLot = 0.05` (start with default, tune later)
4. Test on demo account

---

## Performance Impact

**Expected Improvements**:
- ✅ **Better Rescue Effectiveness**: Adaptive lot matches loser's size
- ✅ **Fewer Wasted Rescues**: No rescue when loser too small
- ✅ **Faster DD Recovery**: Symmetric hedges pull TP closer
- ✅ **Simpler Configuration**: 8 parameters vs 13

**Trade-offs**:
- ⚠️ **Later First Rescue**: Waits until loser >= threshold (0.05 lot)
- ⚠️ **Higher Margin Usage**: Larger rescue lots when loser large
- ⚠️ **More Rescues Possible**: No cycle/cooldown limits (only exposure cap)

---

## Troubleshooting

### Issue: Rescue never triggers
**Check**:
1. `InpRescueAdaptiveLot = true`
2. Loser basket has positions
3. Price breached last grid level
4. Exposure cap not exceeded

### Issue: Rescue always uses fixed min lot
**Symptom**: Always see `[RESCUE-FIXED]` log

**Check**:
1. `InpRescueMinLoserLot` threshold (try lowering to 0.03)
2. Loser basket total lot (may be below threshold)

### Issue: Rescue lot too small/large
**Tune**:
- Too small: Increase `InpRescueLotMultiplier` (1.0 → 1.2)
- Too large: Decrease `InpRescueMaxLot` (0.50 → 0.30)

---

## Related Features

- **Linear Lot Scaling**: Works together (predictable loser lot growth)
- **Exposure Cap**: Still enforced (global safety)
- **Dynamic Target Scaling**: TP adjusts after rescue profit
- **Partial Close**: Reduces loser lot before rescue

---

## Version History

- **v2.5** (2025-10-02): Rescue v2 with smart adaptive threshold
  - Removed DD-based trigger
  - Added min loser lot threshold
  - Removed cooldown/cycles guards
  - Simplified parameters (13 → 8)

- **v2.4**: Initial adaptive rescue implementation

---

## PR Checklist

- [x] Create feature branch `feature/rescue-v2-smart-trigger`
- [x] Remove old parameters from `Params.mqh`
- [x] Add new parameters (`rescue_min_lot`, `rescue_min_loser_lot`)
- [x] Update `RecoveryGridDirection_v2.mq5` inputs
- [x] Implement threshold logic in `LifecycleController.mqh`
- [x] Update `RescueEngine.mqh` (remove DD trigger)
- [x] Add comprehensive logging (`[RESCUE-ADAPTIVE]`, `[RESCUE-FIXED]`)
- [x] Create documentation (this file)
- [ ] Test on demo account (user testing)
- [ ] Merge PR to master

---

## Summary

**What Changed**:
- Rescue triggers only on price breach (no DD check)
- Adaptive lot only activates when loser >= threshold (0.05 lot)
- Below threshold → fixed min lot (0.02)
- Removed 5 unused parameters
- Cleaner logs, better tracking

**Benefits**:
- No more ineffective tiny rescues (0.01 lot)
- Symmetric hedges when loser has accumulated position
- Simpler config, easier to understand
- More predictable behavior

**Ready for**: Demo testing → User feedback → PR merge
