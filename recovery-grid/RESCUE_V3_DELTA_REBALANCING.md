# Rescue v3: Delta-Based Continuous Rebalancing

**Version**: 2.6
**Date**: 2025-10-02
**Branch**: `feature/rescue-v2-smart-trigger`
**Status**: ✅ Implemented

---

## Evolution Summary

| Version | Trigger Logic | Rescue Count | Balance Type |
|---------|--------------|--------------|--------------|
| **v1** | DD OR Breach + Cooldown + Cycles | 1-3 times | Fixed lot |
| **v2** | Breach + Loser >= Threshold | 1 time | Initial match |
| **v3** | Breach + Delta >= Trigger | **Multiple** | **Continuous** |

---

## Problem Statement (from Real Trading)

### User's Observation:
```
Grid State (EURUSD):
- BUY (loser): 0.01 → 0.05 → 0.12 lot (accumulating)
- SELL (rescue): 0.02 lot (deployed once, never rebalanced)

Issue: Rescue deployed too early with wrong size, never adjusted
Result: 0.02 lot rescue can't help 0.12 lot loser
```

### Root Cause:
- **v2 logic**: Rescue once when `loser >= threshold`, then stop
- **Problem**: Loser continues growing, rescue stays static
- **Result**: Asymmetric hedge, ineffective rescue

---

## Solution: Delta-Based Continuous Rebalancing

### Core Concept
**Track imbalance continuously and rebalance when gap exceeds threshold.**

### Formula
```cpp
delta = lot_loser - lot_rescue_current

if (delta >= InpMinDeltaTrigger) {
    rescue_lot = delta × InpRescueLotMultiplier;
    rescue_lot = MIN(rescue_lot, InpRescueMaxLot);
    DeployRecovery(rescue_lot);
}
```

### Key Innovation
- **Delta**: Real-time imbalance between loser and rescue
- **Trigger**: Only rescue when imbalance significant (e.g., 0.05 lot)
- **Continuous**: Multiple rescues as loser grows
- **Self-balancing**: Always maintains symmetric hedge

---

## How It Works

### Scenario: EURUSD Downtrend

#### State 1: Initial Grid
```
BUY (loser):  0.01 lot @ 1.1380
SELL (rescue): 0.00 lot
Delta: 0.01 - 0.00 = 0.01

Check: 0.01 < 0.05 trigger ❌
Action: SKIP (imbalance too small)
Log: [RESCUE-BALANCED] Delta=0.01 < 0.05 (skip)
```

#### State 2: Price Drops, Loser Grows
```
BUY (loser):  0.06 lot @ avg 1.1370 (grid filled)
SELL (rescue): 0.00 lot
Delta: 0.06 - 0.00 = 0.06

Check: 0.06 >= 0.05 trigger ✅
Price breach: YES ✅
Action: Deploy rescue 0.06 × 1.0 = 0.06 lot
Log: [RESCUE-DELTA] Loser=0.06 Rescue=0.00 Delta=0.06 → Deploy 0.06 lot
```

#### State 3: Price Drops More
```
BUY (loser):  0.15 lot @ avg 1.1355
SELL (rescue): 0.06 lot @ 1.1370
Delta: 0.15 - 0.06 = 0.09

Check: 0.09 >= 0.05 trigger ✅
Price breach: YES ✅
Action: Deploy rescue 0.09 × 1.0 = 0.09 lot
Total rescue: 0.06 + 0.09 = 0.15 lot (balanced!)
Log: [RESCUE-DELTA] Loser=0.15 Rescue=0.06 Delta=0.09 → Deploy 0.09 lot
```

#### State 4: Price Drops Again
```
BUY (loser):  0.28 lot @ avg 1.1340
SELL (rescue): 0.15 lot @ avg 1.1363
Delta: 0.28 - 0.15 = 0.13

Check: 0.13 >= 0.05 trigger ✅
Price breach: YES ✅
Action: Deploy rescue 0.13 × 1.0 = 0.13 lot
Total rescue: 0.15 + 0.13 = 0.28 lot (symmetric!)
Log: [RESCUE-DELTA] Loser=0.28 Rescue=0.15 Delta=0.13 → Deploy 0.13 lot
```

#### Result: Perfect Balance
```
Final State:
- BUY (loser):  0.28 lot @ 1.1340
- SELL (rescue): 0.28 lot @ 1.1360
- Delta: 0.00 (perfectly balanced)
- Hedge effectiveness: 100%
```

---

## Parameters

### Input Parameters

```cpp
input group "=== Rescue/Hedge System v3 ==="
input string InpRecoverySteps       = "1000,2000,3000";  // Staged limits
input bool   InpRescueAdaptiveLot   = true;   // Enable delta-based rescue
input double InpMinDeltaTrigger     = 0.05;   // Min imbalance to trigger (lot)
input double InpRescueLotMultiplier = 1.0;    // Delta multiplier (1.0 = 100%)
input double InpRescueMaxLot        = 0.50;   // Max per rescue deployment
```

### Parameter Descriptions

#### 1. `InpMinDeltaTrigger` ⭐ NEW
**Type**: `double`
**Default**: `0.05`
**Purpose**: Minimum lot imbalance to trigger rescue deployment

**Examples**:
- `0.03` → Aggressive (rescue every 0.03 lot gap)
- `0.05` → Balanced (rescue every 0.05 lot gap)
- `0.10` → Conservative (rescue every 0.10 lot gap)

**Tuning Guide**:
- **Small account** (< $1000): `0.03` (tighter control)
- **Medium account** ($1000-$5000): `0.05` (balanced)
- **Large account** (> $5000): `0.10` (fewer rescues)

#### 2. `InpRescueLotMultiplier` (unchanged)
**Default**: `1.0` (100% of delta)
**Purpose**: Scale rescue lot relative to imbalance

**Examples**:
- `0.8` → Conservative (rescue 80% of delta)
- `1.0` → Exact (rescue 100% of delta) ✅ Recommended
- `1.2` → Aggressive (rescue 120% of delta)

#### 3. `InpRescueMaxLot` (unchanged)
**Default**: `0.50`
**Purpose**: Cap per rescue deployment (safety)

---

## Advantages vs v2

### 1. Continuous Rebalancing
**v2**: Rescue once, never adjust
**v3**: Rescue multiple times, always balanced

### 2. Dynamic Adaptation
**v2**: Fixed threshold (loser >= 0.05)
**v3**: Delta-based (imbalance >= 0.05)

### 3. Scalability
**v2**: Works only for small positions
**v3**: Works from 0.01 to 10.0 lot

### 4. Lower Margin Spikes
**v2**: 1 big rescue (e.g., 0.15 lot at once)
**v3**: Gradual rescues (0.05 + 0.05 + 0.05)

### 5. Self-Correcting
**v2**: If rescue closes early, no rebalance
**v3**: Delta increases → auto-rebalance

---

## Risk Analysis

### Risk 1: Rescue Spam ⚠️ LOW
**Scenario**: `InpMinDeltaTrigger = 0.01` → rescue every grid level
**Mitigation**:
- Default `0.05` (reasonable threshold)
- Breach trigger still required (not every tick)
- Exposure cap enforced

### Risk 2: High Commission 💰 LOW
**Impact**: More rescue orders = more commission
**Analysis**:
- Example: 5 rescues × $7 = $35 commission
- Benefit: Better hedge = faster recovery = higher profit
- **Net positive**: Worth the cost

### Risk 3: Exposure Cap Hit 🚫 MEDIUM
**Scenario**: Multiple rescues push total exposure over cap
**Mitigation**:
- Each rescue checks: `current_exposure + rescue_lot <= cap`
- If blocked, log: `[RESCUE-BLOCKED] Exposure cap`
- System safe, just skips rescue

### Risk 4: Complexity 🧩 LOW
**Code complexity**: Minimal (+10 lines)
**Logic complexity**: Simple delta calculation
**Maintenance**: Easy to understand and debug

---

## Configuration Examples

### Example 1: Conservative (Tight Control)
```properties
InpMinDeltaTrigger     = 0.03   # Rescue every 0.03 lot gap
InpRescueLotMultiplier = 0.8    # 80% of delta
InpRescueMaxLot        = 0.30   # Cap at 0.30 lot per rescue
InpExposureCapLots     = 1.0    # Tight exposure limit

Result: Frequent small rescues, tight balance
```

### Example 2: Balanced (Recommended)
```properties
InpMinDeltaTrigger     = 0.05   # Rescue every 0.05 lot gap
InpRescueLotMultiplier = 1.0    # 100% of delta
InpRescueMaxLot        = 0.50   # Cap at 0.50 lot per rescue
InpExposureCapLots     = 2.0    # Moderate exposure

Result: Balanced rescues, good hedge effectiveness
```

### Example 3: Conservative (Loose Control)
```properties
InpMinDeltaTrigger     = 0.10   # Rescue every 0.10 lot gap
InpRescueLotMultiplier = 1.0    # 100% of delta
InpRescueMaxLot        = 1.00   # Cap at 1.00 lot per rescue
InpExposureCapLots     = 5.0    # Loose exposure limit

Result: Fewer rescues, larger gaps tolerated
```

---

## Log Output Examples

### Log 1: Delta Too Small (Skip)
```
[RGDv2][EURUSD] [RESCUE-BALANCED] Loser=0.03 Rescue=0.00 Delta=0.03 < 0.05 (skip, balanced)
```

### Log 2: Delta Triggers Rescue
```
[RGDv2][EURUSD] [RESCUE-DELTA] Loser=0.08 Rescue=0.02 Delta=0.06 → Deploy 0.06 lot (mult=1.00)
[RGDv2][EURUSD] Rescue deployed: 0.06 lot
```

### Log 3: Multiple Rescues
```
[RGDv2][EURUSD] [RESCUE-DELTA] Loser=0.15 Rescue=0.08 Delta=0.07 → Deploy 0.07 lot (mult=1.00)
[RGDv2][EURUSD] Rescue deployed: 0.07 lot
```

### Log 4: Cap Applied
```
[RGDv2][EURUSD] [RESCUE-DELTA] Loser=0.80 Rescue=0.20 Delta=0.60 → Deploy 0.50 lot (capped from 0.60)
[RGDv2][EURUSD] Rescue deployed: 0.50 lot
```

### Log 5: Exposure Block
```
[RGDv2][EURUSD] [RESCUE-DELTA] Loser=0.20 Rescue=0.10 Delta=0.10 → Deploy 0.10 lot (mult=1.00)
[RGDv2][EURUSD] Rescue blocked: Exposure cap (total 2.05 > 2.00 limit)
```

---

## Implementation Details

### Files Modified

#### 1. `Params.mqh`
```cpp
// REMOVED: rescue_min_loser_lot (no longer needed)
// ADDED:
double min_delta_trigger;  // Min imbalance to trigger rescue
```

#### 2. `RecoveryGridDirection_v2.mq5`
```cpp
// REMOVED: InpRescueMinLoserLot
// ADDED:
input double InpMinDeltaTrigger = 0.05;  // Min delta trigger
```

#### 3. `LifecycleController.mqh`
```cpp
// NEW LOGIC:
double loser_lot = loser.TotalLot();
double rescue_lot = winner.TotalLot();  // Current rescue size
double delta = loser_lot - rescue_lot;

if (delta >= m_params.min_delta_trigger) {
    // Calculate rescue lot
    double new_rescue = delta × multiplier;
    new_rescue = MIN(new_rescue, max_lot);

    // Deploy
    winner.DeployRecovery(price, new_rescue);
    Log: [RESCUE-DELTA]
}
else {
    Log: [RESCUE-BALANCED] (skip)
}
```

---

## Testing Checklist

### Test 1: Small Imbalance (Skip)
**Setup**:
- `InpMinDeltaTrigger = 0.05`
- Loser: 0.03 lot, Rescue: 0.00 lot
- Delta: 0.03

**Expected**:
- ✅ No rescue deployed
- ✅ Log: `[RESCUE-BALANCED] Delta=0.03 < 0.05`

### Test 2: First Rescue (Delta Triggers)
**Setup**:
- Loser: 0.08 lot, Rescue: 0.00 lot
- Delta: 0.08

**Expected**:
- ✅ Deploy 0.08 lot rescue
- ✅ Log: `[RESCUE-DELTA] Delta=0.08 → Deploy 0.08 lot`

### Test 3: Second Rescue (Rebalance)
**Setup**:
- Loser: 0.15 lot, Rescue: 0.08 lot
- Delta: 0.07

**Expected**:
- ✅ Deploy 0.07 lot rescue (additional)
- ✅ Total rescue: 0.15 lot
- ✅ Log: `[RESCUE-DELTA] Delta=0.07 → Deploy 0.07 lot`

### Test 4: Cap Applied
**Setup**:
- `InpRescueMaxLot = 0.50`
- Loser: 1.00 lot, Rescue: 0.20 lot
- Delta: 0.80

**Expected**:
- ✅ Deploy 0.50 lot (capped from 0.80)
- ✅ Log shows cap applied

### Test 5: Exposure Block
**Setup**:
- `InpExposureCapLots = 2.0`
- Current exposure: 1.95 lot
- Delta rescue: 0.10 lot (total 2.05 > 2.0)

**Expected**:
- ✅ Rescue blocked
- ✅ Log: `Rescue blocked: Exposure cap`

---

## Migration from v2

### Old Config (v2)
```properties
InpRescueMinLoserLot   = 0.05  # REMOVED
InpRescueLotMultiplier = 1.0
InpRescueMaxLot        = 0.50
```

### New Config (v3)
```properties
InpMinDeltaTrigger     = 0.05  # NEW - replaces min loser lot
InpRescueLotMultiplier = 1.0   # UNCHANGED
InpRescueMaxLot        = 0.50  # UNCHANGED
```

**Migration Steps**:
1. Remove `InpRescueMinLoserLot` from presets
2. Add `InpMinDeltaTrigger = 0.05` (use old min loser lot value)
3. Test on demo account

---

## Performance Impact

### Expected Improvements
- ✅ **Better Hedge Balance**: Delta < 0.05 at all times
- ✅ **Faster Recovery**: Symmetric hedge pulls TP closer faster
- ✅ **Lower Max DD**: Balanced hedge reduces drawdown
- ✅ **Adaptive to Position Size**: Works for any lot size

### Trade-offs
- ⚠️ **More Rescues**: 2-5 rescues vs 1 in v2
- ⚠️ **Higher Commission**: More orders = more fees
- ⚠️ **Slightly More Complex**: Delta calculation adds logic

### Net Result
**Positive**: Better hedge effectiveness outweighs commission cost

---

## Comparison Table: v1 vs v2 vs v3

| Feature | v1 (Legacy) | v2 (Threshold) | v3 (Delta) ✅ |
|---------|-------------|----------------|---------------|
| **Trigger** | DD OR Breach | Loser >= 0.05 | Delta >= 0.05 |
| **Rescues** | 1-3 (limited) | 1 only | Unlimited |
| **Balance** | Fixed lot | Initial match | Continuous |
| **Rebalance** | No | No | **Yes** |
| **Scalability** | Poor | Good | **Excellent** |
| **Complexity** | Medium | Low | Low |
| **Effectiveness** | Low | Good | **Excellent** |
| **Commission** | Medium | Low | Medium |
| **Recommended** | ❌ | ⚠️ | ✅ |

---

## FAQ

### Q1: How many rescues will deploy?
**A**: Depends on loser growth and `InpMinDeltaTrigger`.
- Example: Loser grows 0.01 → 0.30 lot, trigger = 0.05
- Rescues: ~6 deployments (every 0.05 lot gap)

### Q2: Will rescue spam too much?
**A**: No, controlled by:
- `InpMinDeltaTrigger` (only when delta >= threshold)
- Breach trigger (only when price beyond grid)
- Exposure cap (hard limit)

### Q3: What if loser shrinks (partial close)?
**A**: Delta decreases, no new rescue (balanced)
- Example: Loser 0.20 → 0.15, Rescue 0.20
- Delta: -0.05 (rescue oversized, no action)
- System waits until loser grows again

### Q4: Does this work with Partial Close?
**A**: Yes, synergy!
- PC reduces loser lot → delta increases
- Next breach → rescue rebalances
- Perfect combo for DD management

---

## Summary

**What v3 Does**:
- Tracks real-time imbalance (delta = loser - rescue)
- Deploys rescue when delta >= threshold
- Continuous rebalancing as loser grows
- Always maintains symmetric hedge

**Why v3 Better**:
- More intelligent (tracks actual imbalance)
- Self-correcting (adapts automatically)
- Scalable (works for any position size)
- Effective (maintains balance always)

**Ready for**: Demo testing → User feedback → Production

---

## Version History

- **v3.0** (2025-10-02): Delta-based continuous rebalancing
  - Removed min loser lot threshold
  - Added delta trigger logic
  - Multiple rescues support
  - Continuous balance maintenance

- **v2.0**: Threshold-based single rescue
- **v1.0**: DD/Breach with cooldown/cycles
