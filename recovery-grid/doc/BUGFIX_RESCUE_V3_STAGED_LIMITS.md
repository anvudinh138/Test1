# BugFix: Rescue v3 Staged Limits Removal

**Date**: 2025-10-03
**Branch**: `feature/lot-percent-risk`
**Status**: ✅ Fixed
**Severity**: 🔴 CRITICAL

---

## Problem Report (from User)

### Issue #1: Excessive Rescue Orders
**Observation** (Image #1):
```
Expected: 1 market order @ 0.01 lot
Actual:
  - 1 market @ 0.01 lot ✅
  - 3 limits @ 0.06 lot ❌
  - 3 limits @ 0.1 lot ❌
Total: 7 orders instead of 1
```

**Impact**:
- If price drops 1 grid → 2 rescue limits fill → 0.06 + 0.06 = 0.12 lot
- With loser @ 0.06 lot → rescue @ 0.12 lot = 200% imbalance (OPPOSITE direction!)
- Margin explosion, incorrect hedge ratio

### Issue #2: Wrong Rescue Spacing
**Observation** (Image #2):
```
Rescue limits placed at:
  - 1.17296
  - 1.16296  (100 pips gap)
  - 1.15296  (100 pips gap)
```

**Expected**: No limits at all (Rescue v3 = market only)

### Issue #3: Pending Orders Not Cleared
**Observation** (Image #4):
```
09:34 - BUY limit 0.06 lot placed (rescue)
15:03 - BUY limit 0.06 lot STILL THERE (5+ hours later)
```

**Impact**:
- Old rescue pendings remain after basket flip
- Can trigger later and mess up new cycle
- Clutters order book

---

## Root Cause Analysis

### Code Investigation

**File**: `GridBasket.mqh:791-835`

**Old Logic** (BUGGY):
```cpp
void DeployRecovery(const double price, const double rescue_lot) {
    // Deploy 1 market order
    m_executor.Market(m_direction, normalized_lot, "RGDv2_RescueSeed");

    // Deploy staged limit orders (WRONG!)
    for(int i=0; i < ArraySize(m_params.recovery_steps); i++) {
        double level = price - m_params.recovery_steps[i] * point;
        m_executor.Limit(DIR_BUY, level, normalized_lot, "RGDv2_RescueGrid");
    }
}
```

**Problem**:
1. **Lot duplication**: Each limit uses **same lot** as market order
2. **Incompatible with v3**: Delta-based rescue doesn't need staged limits
3. **Legacy from v1/v2**: Staged limits were for DD-based rescue (removed)

### Why This Happened

**Rescue Evolution**:
- **v1**: DD-based → deploy big hedge with staged limits (DCA if price continues)
- **v2**: Threshold-based → deploy once, staged limits for safety
- **v3**: Delta-based → deploy small frequent rescues, **NO NEED for staged limits**

**Mistake**: Code kept v1/v2 staged limits logic in v3 implementation

---

## Solution

### Fix Applied

**File**: `GridBasket.mqh:791-813`

**New Logic** (FIXED):
```cpp
void DeployRecovery(const double price, const double rescue_lot) {
    // Rescue v3: ONLY market order, NO staged limits
    // Reason: Delta-based continuous rebalancing doesn't need staged limits
    // Each rescue deployment = 1 market order matching current delta
    m_executor.BypassNext(1);
    double normalized_lot = NormalizeVolumeValue(rescue_lot);
    if(normalized_lot <= 0.0) return;

    // Deploy single market order
    ulong ticket = m_executor.Market(m_direction, normalized_lot, "RGDv2_RescueSeed");

    RefreshState();
    if(m_log != NULL)
        m_log.Event(Tag(), StringFormat("Rescue deployed: %.2f lot (delta-based)", normalized_lot));
}
```

**Changes**:
- ✅ Removed all staged limits logic (lines 806-831)
- ✅ Deploy **ONLY 1 market order** per rescue
- ✅ Lot = delta × multiplier (exactly what's needed)
- ✅ Updated log message to reflect delta-based deployment

### Deprecated Parameter

**File**: `RESCUE_V3_DELTA_REBALANCING.md`

```cpp
input string InpRecoverySteps = "1000,2000,3000";  // ⚠️ DEPRECATED (not used in v3)
```

**Note**: Parameter still exists for backward compatibility, but is **ignored** in Rescue v3.

---

## Verification

### Before Fix (BUGGY)

**Test**: Loser = 0.06 lot, Rescue = 0.00 lot, Delta = 0.06

**Expected**:
- Deploy 1 market @ 0.06 lot

**Actual**:
- Deploy 1 market @ 0.06 lot ✅
- Deploy 3 limits @ 0.06 lot ❌
- **Total rescue**: 0.06 + (3 × 0.06) = 0.24 lot (400% of needed!)

### After Fix (CORRECT)

**Test**: Same scenario

**Expected**:
- Deploy 1 market @ 0.06 lot

**Actual**:
- Deploy 1 market @ 0.06 lot ✅
- **Total rescue**: 0.06 lot (100% of needed ✅)

---

## Impact Assessment

### Issue #1: ✅ FIXED
**Status**: Rescue now deploys exactly 1 market order
**Verification**: No more excessive orders

### Issue #2: ✅ AUTO-FIXED
**Status**: No staged limits → no spacing issue
**Verification**: Only market order, no limits to space

### Issue #3: ✅ AUTO-FIXED
**Status**: No pending rescue orders → nothing to clear
**Verification**: Market orders execute immediately

---

## Risk Analysis

### Risk 1: Breaks Backward Compatibility ⚠️ MEDIUM
**Impact**: Users with `InpRecoverySteps` configured won't see staged limits anymore
**Mitigation**:
- Parameter still exists (no input error)
- Documented as deprecated
- Users should migrate to v3 logic (delta-based)

### Risk 2: Less DCA on Continued Trend ⚠️ LOW
**Old**: Staged limits provided DCA if price continued away
**New**: No staged limits → rescue waits for next delta trigger
**Mitigation**:
- Delta triggers frequently (every `InpMinDeltaTrigger` lot gap)
- More responsive than staged limits (reacts to actual imbalance)
- **Net positive**: Better balance maintenance

### Risk 3: More Market Orders = Higher Spread Cost 💰 LOW
**Impact**: Market orders pay spread, limits don't (when filled)
**Analysis**:
- Example: 5 rescues × 1 pip spread = 5 pips cost
- Benefit: Immediate balance vs waiting for limit fill
- **Worth it**: Speed > cost for grid recovery

---

## Testing Checklist

### Test 1: Single Rescue Deployment ✅
**Setup**:
- Loser: 0.08 lot, Rescue: 0.00 lot, Delta: 0.08
- `InpMinDeltaTrigger = 0.05`

**Expected**:
- ✅ Deploy 1 market @ 0.08 lot
- ✅ No limit orders
- ✅ Log: "Rescue deployed: 0.08 lot (delta-based)"

### Test 2: Multiple Rescues (Rebalancing) ✅
**Setup**:
- Round 1: Loser 0.08, Rescue 0.00 → Deploy 0.08
- Round 2: Loser 0.15, Rescue 0.08 → Deploy 0.07
- Round 3: Loser 0.25, Rescue 0.15 → Deploy 0.10

**Expected**:
- ✅ Each round deploys exactly 1 market order
- ✅ Total rescue matches loser lot
- ✅ No pending orders left behind

### Test 3: Basket Flip (No Orphan Pendings) ✅
**Setup**:
- Deploy rescue → basket flips → check for orphan orders

**Expected**:
- ✅ No pending orders remain after flip
- ✅ Only market positions closed

---

## Migration Guide

### For Users on Rescue v1/v2

**Old Config** (v1/v2 with staged limits):
```properties
InpRecoverySteps       = "1000,2000,3000"  # Used
InpRescueMinLoserLot   = 0.05              # Threshold
InpRescueLotMultiplier = 1.0
InpRescueMaxLot        = 0.50
```

**New Config** (v3 delta-based):
```properties
InpRecoverySteps       = "1000,2000,3000"  # ⚠️ IGNORED (keep for compatibility)
InpMinDeltaTrigger     = 0.05              # NEW - delta threshold
InpRescueLotMultiplier = 1.0               # UNCHANGED
InpRescueMaxLot        = 0.50              # UNCHANGED
```

**What Changed**:
- ✅ `InpRecoverySteps` → ignored (no staged limits)
- ✅ `InpRescueMinLoserLot` → removed → replaced by `InpMinDeltaTrigger`
- ✅ Rescue behavior: 1 deployment → continuous deployments

---

## Performance Impact

### Expected Improvements
- ✅ **Correct Lot Sizing**: No more 400% oversized rescue
- ✅ **Faster Balance**: Immediate market fills vs waiting for limits
- ✅ **Cleaner Order Book**: No orphan pendings
- ✅ **Lower Margin Spikes**: Exactly-sized rescue vs over-deployment

### Trade-offs
- ⚠️ **Higher Spread Cost**: Market orders pay spread
- ⚠️ **More Rescues**: Continuous rebalancing = more orders
- ⚠️ **No DCA Safety Net**: No staged limits if price runs away fast

### Net Result
**Hugely Positive**: Fixing 400% over-deployment bug >> trade-off costs

---

## Commit Message

```
fix: Remove staged limits from Rescue v3 (delta-based)

CRITICAL BUG: Rescue v3 was deploying 1 market + N limits with SAME lot
- Result: 400% over-deployment (0.06 needed → 0.24 deployed)
- Impact: Margin explosion, wrong hedge ratio, orphan pendings

FIX: Deploy ONLY 1 market order per rescue
- Reason: Delta-based continuous rebalancing doesn't need staged limits
- Each deployment = exactly delta × multiplier
- Immediate fills, no pending orphans

DEPRECATED: InpRecoverySteps (kept for compatibility, but ignored)

Files:
- src/core/GridBasket.mqh (simplified DeployRecovery)
- RESCUE_V3_DELTA_REBALANCING.md (documented deprecation)
- doc/BUGFIX_RESCUE_V3_STAGED_LIMITS.md (new)

Severity: CRITICAL (400% over-deployment)
Tested: ✅ Single rescue, ✅ Multiple rescues, ✅ Basket flip
```

---

## References

- Rescue v3 Spec: [RESCUE_V3_DELTA_REBALANCING.md](../RESCUE_V3_DELTA_REBALANCING.md)
- Grid Basket: [ARCHITECTURE.md](ARCHITECTURE.md)
- User Report: Screenshots #1, #2, #4 (2025-10-03)
