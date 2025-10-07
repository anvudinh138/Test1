# Refactor: Input Simplification

**Goal**: Reduce input parameters from ~50 to ~30 by removing redundant/auto-detectable params
**Status**: 🔴 PENDING REVIEW
**Impact**: 🔴 HIGH (breaks existing .set files, needs migration guide)

---

## Changes Summary

### ✅ Completed (Issues #1, #2)
1. **News Calendar Spam** → Rate-limited to 1 error log per 5 minutes
2. **EA Resume After News** → Auto-reseed baskets when both empty

### 📋 Pending (Issue #3 - Refactor)

| # | Old | New | Reason |
|---|-----|-----|--------|
| 1 | `InpSpacingMode` (Pips/ATR/Hybrid) | **Removed** | Force ATR only (more adaptive) |
| 2 | `InpSpacingStepPips` | **Removed** | Not needed (ATR-based) |
| 3 | `InpMinSpacingPips` | **Removed** | Trust ATR (no floor needed) |
| 4 | `InpTSLStartPoints` | `InpTSLStartMultiplier` | Spacing-based (2× spacing) |
| 5 | `InpTSLStepPoints` | `InpTSLStepMultiplier` | Spacing-based (0.5× spacing) |
| 6 | `InpWarmLevels` | **Hidden** | DynamicGrid default ON |
| 7 | `InpRefillThreshold` | **Hidden** | Hardcoded optimal value |
| 8 | `InpRefillBatch` | **Hidden** | Hardcoded optimal value |
| 9 | `InpMaxPendings` | **Hidden** | Hardcoded optimal value |
| 10 | `InpRespectStops` | **Auto-detect** | False (backtest), True (live) |
| 11 | `InpOrderCooldownSec` | **Hardcoded** | Always 5 seconds |

**Total Removed**: 11 parameters (-22% complexity!)

---

## Detailed Changes

### 1. Remove Spacing Mode → Force ATR Only

**Current**:
```cpp
enum InpSpacingModeEnum { InpSpacingPips=0, InpSpacingATR=1, InpSpacingHybrid=2 };
input InpSpacingModeEnum InpSpacingMode = InpSpacingHybrid;
input double InpSpacingStepPips = 8.0;  // For PIPS mode
input double InpSpacingAtrMult = 0.8;   // For ATR/HYBRID
input double InpMinSpacingPips = 5.0;   // Floor for ATR/HYBRID
```

**New** (simplified):
```cpp
// Removed: InpSpacingMode, InpSpacingStepPips, InpMinSpacingPips
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_H4;  // H4 for stable ATR
input int InpAtrPeriod = 14;
input double InpSpacingAtrMult = 1.5;  // Direct ATR multiplier (no floor)
```

**Impact**:
- ✅ Simpler (1 param vs 4)
- ✅ Auto-adapts to volatility
- ✅ Works for all symbols
- ⚠️ Breaks .set files (need migration)

**Migration**:
```
Old: InpSpacingMode=PIPS, InpSpacingStepPips=8
New: InpSpacingAtrMult=1.5 (approximate, test on demo first)

Old: InpSpacingMode=ATR, InpSpacingAtrMult=0.8, InpMinSpacingPips=5
New: InpSpacingAtrMult=0.8 (remove floor, trust ATR)
```

---

### 2. TSL Points → Spacing Multiplier

**Current**:
```cpp
input int InpTSLStartPoints = 1000;  // Fixed 1000 points (bad for XAUUSD!)
input int InpTSLStepPoints = 200;    // Fixed 200 points
```

**New** (adaptive):
```cpp
input double InpTSLStartMultiplier = 2.0;  // TSL after 2× spacing profit
input double InpTSLStepMultiplier = 0.5;   // Trail by 0.5× spacing
```

**Calculation**:
```cpp
// Old (fixed points)
tsl_start = 1000 points;  // Same for EURUSD, XAUUSD, USDJPY

// New (adaptive)
spacing = iATR(...) × InpSpacingAtrMult;  // e.g., 50 points for EURUSD
tsl_start = spacing × InpTSLStartMultiplier;  // 50 × 2.0 = 100 points
tsl_step = spacing × InpTSLStepMultiplier;    // 50 × 0.5 = 25 points
```

**Benefit**:
- EURUSD (spacing 50): TSL start 100, step 25
- XAUUSD (spacing 500): TSL start 1000, step 250
- Auto-scales!

**Impact**:
- ⚠️ Breaks .set files
- ✅ More accurate TSL for all symbols

**Migration**:
```
Old: InpTSLStartPoints=1000, InpTSLStepPoints=200
Estimate spacing (e.g., 50 points for EURUSD):
  Start multiplier = 1000 / 50 = 20× (too high!)
  Step multiplier = 200 / 50 = 4×

Recommended: Start with defaults (2× and 0.5×), test on demo
```

---

### 3. DynamicGrid Default ON + Hide Sub-Params

**Current**:
```cpp
input bool InpDynamicGrid = true;
input int InpWarmLevels = 5;
input int InpRefillThreshold = 2;
input int InpRefillBatch = 3;
input int InpMaxPendings = 15;
```

**New** (simplified):
```cpp
// Hardcoded in code (optimal values)
const bool DYNAMIC_GRID = true;  // Always ON
const int WARM_LEVELS = 5;
const int REFILL_THRESHOLD = 2;
const int REFILL_BATCH = 3;
const int MAX_PENDINGS = 15;

// No input parameters needed!
```

**Impact**:
- ✅ Removes 5 confusing parameters
- ✅ Always optimal settings
- ⚠️ Advanced users can't tune (99% don't need to)

**Alternative** (if advanced tuning needed):
```cpp
input bool InpDynamicGrid = true;  // Keep this one

// Hide others behind #define
#ifdef ADVANCED_MODE
input int InpWarmLevels = 5;
// ...
#endif
```

---

### 4. Auto-Detect RespectStops

**Current**:
```cpp
input bool InpRespectStops = false;  // User must set manually
```

**New** (auto-detect):
```cpp
// In code
bool respect_stops = MQL5InfoInteger(MQL5_TESTER) ? false : true;
// Backtest → false
// Live/Demo → true
```

**Impact**:
- ✅ One less parameter
- ✅ Always correct setting
- ⚠️ Advanced users lose manual control (rarely needed)

---

### 5. Hardcode OrderCooldown

**Current**:
```cpp
input int InpOrderCooldownSec = 5;
```

**New** (hardcoded):
```cpp
const int ORDER_COOLDOWN_SEC = 5;  // Optimal for all scenarios
```

**Impact**:
- ✅ One less parameter
- ✅ 5 seconds is universally good
- ⚠️ Can't tune for very fast brokers (rare)

---

## Before/After Comparison

### Current Input Groups (50+ params)

```
=== Grid Configuration === (9 params)
  - InpSpacingMode, InpSpacingStepPips, InpSpacingAtrMult, InpMinSpacingPips
  - InpAtrTimeframe, InpAtrPeriod
  - InpGridLevels, InpDynamicGrid, InpWarmLevels, InpRefillThreshold, etc.

=== Lot Sizing === (2 params)
  - InpLotBase, InpLotOffset

=== Lot % Risk === (3 params)
  - InpLotPercentEnabled, InpLotPercentRisk, InpLotPercentMaxLot

=== Take Profit & TSL === (4 params)
  - InpTargetCycleUSD, InpTSLEnabled, InpTSLStartPoints, InpTSLStepPoints

=== Rescue v3 === (6 params)
  - InpRecoverySteps, InpRescueAdaptiveLot, InpMinDeltaTrigger, etc.

=== Risk Management === (4 params)
  - InpExposureCapLots, InpSessionSL_USD, InpOrderCooldownSec, InpRespectStops, etc.

Total: ~50 parameters
```

### After Refactor (30 params)

```
=== Grid Configuration === (3 params) ✅ -6
  - InpAtrTimeframe, InpAtrPeriod, InpSpacingAtrMult

=== Lot Sizing === (2 params) [unchanged]
  - InpLotBase, InpLotOffset

=== Lot % Risk === (3 params) [unchanged]
  - InpLotPercentEnabled, InpLotPercentRisk, InpLotPercentMaxLot

=== Take Profit & TSL === (3 params) ✅ -1
  - InpTargetCycleUSD, InpTSLEnabled, InpTSLStartMultiplier, InpTSLStepMultiplier

=== Rescue v3 === (5 params) ✅ -1 (remove InpRecoverySteps)
  - InpRescueAdaptiveLot, InpMinDeltaTrigger, InpRescueLotMultiplier, etc.

=== Risk Management === (2 params) ✅ -2
  - InpExposureCapLots, InpSessionSL_USD

Total: ~30 parameters (-40% complexity!)
```

---

## Migration Guide (For Existing .set Files)

### Step 1: Backup
```bash
cp my_config.set my_config_v27_backup.set
```

### Step 2: Update Parameters

**Spacing** (REQUIRED):
```
# Old
InpSpacingMode=1              # REMOVE
InpSpacingStepPips=8.0        # REMOVE
InpMinSpacingPips=5.0         # REMOVE
InpSpacingAtrMult=0.8

# New
InpAtrTimeframe=16388         # PERIOD_H4 (recommended)
InpAtrPeriod=14
InpSpacingAtrMult=1.5         # Start with 1.5, tune on demo
```

**TSL** (REQUIRED if using TSL):
```
# Old
InpTSLStartPoints=1000        # REMOVE
InpTSLStepPoints=200          # REMOVE

# New
InpTSLStartMultiplier=2.0     # ADD
InpTSLStepMultiplier=0.5      # ADD
```

**DynamicGrid** (AUTO):
```
# Old
InpDynamicGrid=true           # Keep or remove (always true now)
InpWarmLevels=5               # REMOVE (hardcoded)
InpRefillThreshold=2          # REMOVE (hardcoded)
InpRefillBatch=3              # REMOVE (hardcoded)
InpMaxPendings=15             # REMOVE (hardcoded)

# New
# (no params needed, all hardcoded)
```

**Other** (AUTO):
```
# Old
InpRespectStops=false         # REMOVE (auto-detect)
InpOrderCooldownSec=5         # REMOVE (hardcoded 5)

# New
# (no params needed, auto-detect)
```

### Step 3: Test on Demo
```
1. Load EA with new .set file
2. Run on demo for 1 day
3. Verify spacing is reasonable
4. Tune InpSpacingAtrMult if needed (1.0-2.0 range)
```

---

## Implementation Plan

**Phase 1**: Code Changes
1. Edit Params.mqh (remove fields)
2. Edit RecoveryGridDirection_v2.mq5 (remove inputs, add hardcodes)
3. Edit SpacingEngine.mqh (remove PIPS mode logic)
4. Edit GridBasket.mqh (TSL multiplier calculation)

**Phase 2**: Testing
1. Compile and fix errors
2. Backtest with default settings
3. Verify all features work

**Phase 3**: Documentation
1. Update STRATEGY_SPEC.md
2. Create migration guide (.set file converter?)
3. Update TROUBLESHOOTING.md

---

## Risks

1. **Breaking Change**: All existing .set files need manual migration
   - Mitigation: Provide converter script or detailed guide

2. **Loss of Flexibility**: Advanced users can't tune hidden params
   - Mitigation: 99% don't need to tune, optimal defaults work

3. **ATR-Only May Be Too Volatile**: Some users prefer fixed pips
   - Mitigation: InpSpacingAtrMult allows tuning (0.5 = conservative, 2.0 = wide)

---

## User Approval Required

**Question for User**:
1. ✅ Remove SpacingMode → Force ATR only?
2. ✅ Remove MinSpacingPips → Trust ATR (no floor)?
3. ✅ TSL Points → Spacing Multiplier?
4. ✅ DynamicGrid always ON + hide sub-params?
5. ✅ Auto-detect RespectStops?
6. ✅ Hardcode OrderCooldown = 5s?

**Confirm**: Type "YES" to proceed with refactor, or "REVIEW" to discuss changes first.

---

## Estimated Time

- Code changes: 2-3 hours
- Testing: 1 hour
- Documentation: 1 hour
- **Total**: 4-5 hours

**Worth it?** ✅ YES - 40% reduction in complexity = huge UX improvement!
