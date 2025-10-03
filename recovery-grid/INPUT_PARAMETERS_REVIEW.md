# Input Parameters Review & Reorganization

**Version**: 2.5
**Date**: 2025-10-02
**Purpose**: Consolidate and organize input parameters for better usability

---

## Current Issues

1. **Too Many Parameters**: 60+ inputs overwhelming for new users
2. **Poor Grouping**: Some groups mix unrelated parameters
3. **Unused Parameters**: Some inputs rarely used or ineffective
4. **No Priority Indication**: Hard to know which parameters are critical vs optional

---

## Proposed Reorganization

### GROUP 1: Core Settings (ESSENTIAL)
**Description**: Must configure these for any symbol

```cpp
input group "=== CORE SETTINGS (ESSENTIAL) ==="
input long   InpMagic            = 990045;  // ⚠️ UNIQUE per symbol/chart
input double InpLotBase          = 0.01;    // Starting lot size
input double InpLotOffset        = 0.01;    // Linear lot increment
input int    InpGridLevels       = 1000;    // Max grid levels
input double InpTargetCycleUSD   = 3.0;     // Profit target per cycle
input double InpExposureCapLots  = 2.0;     // Max total lot exposure
input double InpSessionSL_USD    = 100000;  // Session stop loss (USD)
```

**Reasoning**: These 7 parameters define the core strategy behavior.

---

### GROUP 2: Grid Spacing (ESSENTIAL)
**Description**: Controls grid spacing calculation

```cpp
input group "=== GRID SPACING ==="
input InpSpacingModeEnum InpSpacingMode = InpSpacingHybrid;  // PIPS/ATR/HYBRID
input double InpSpacingStepPips  = 8.0;    // Fixed pips (PIPS/HYBRID mode)
input double InpSpacingAtrMult   = 0.8;    // ATR multiplier (ATR/HYBRID mode)
input double InpMinSpacingPips   = 5.0;    // Minimum spacing (HYBRID mode)
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_M15;
input int    InpAtrPeriod        = 14;
```

**Reasoning**: Grouped all spacing-related parameters together.

---

### GROUP 3: Dynamic Grid (OPTIONAL)
**Description**: Gradual grid deployment to reduce init lag

```cpp
input group "=== DYNAMIC GRID (Optional) ==="
input bool   InpDynamicGrid      = true;   // Enable dynamic grid
input int    InpWarmLevels       = 5;      // Initial pending count
input int    InpRefillThreshold  = 2;      // Refill when pending <= this
input int    InpRefillBatch      = 3;      // Add this many per refill
input int    InpMaxPendings      = 15;     // Hard limit for safety
```

**Reasoning**: All dynamic grid parameters in one place, clearly marked optional.

---

### GROUP 4: Rescue/Hedge System
**Description**: Controls rescue hedge deployment and lot sizing

```cpp
input group "=== RESCUE/HEDGE SYSTEM ==="
input string InpRecoverySteps    = "1000,2000,3000";  // Points offsets for staged limits
input double InpRecoveryLot      = 0.02;              // Base rescue lot (min floor)
input bool   InpRescueAdaptiveLot = true;             // ✅ Match loser's lot size
input double InpRescueLotMultiplier = 1.0;            // 1.0 = exact match, 0.8 = 80%
input double InpRescueMaxLot     = 0.50;              // Safety cap for adaptive lot
input double InpDDOpenUSD        = 10000;             // DD threshold for rescue
input double InpOffsetRatio      = 0.5;               // Offset ratio for rescue entry
input int    InpMaxCyclesPerSide = 3;                 // Max rescue cycles per side
input int    InpCooldownBars     = 5;                 // Cooldown between rescues
```

**Reasoning**: All rescue parameters together, adaptive lot feature highlighted.

---

### GROUP 5: Trailing Stop Loss (TSL)
**Description**: TSL for hedge baskets only

```cpp
input group "=== TRAILING STOP LOSS (Hedge Only) ==="
input bool   InpTSLEnabled       = true;   // Enable TSL on hedge baskets
input int    InpTSLStartPoints   = 1000;   // Start trailing after this profit
input int    InpTSLStepPoints    = 200;    // Trail step size
```

**Reasoning**: Simple TSL group, clearly states "hedge only".

---

### GROUP 6: Smart Stop Loss (SSL) - PRODUCTION FEATURE
**Description**: Reduces DD by 60% (42.98% → 16.99%)

```cpp
input group "=== SMART STOP LOSS (SSL) ⭐ PRODUCTION ==="
input bool   InpSslEnabled           = false;  // ⚠️ DISABLED by default (enable for production)
input double InpSslSlMultiplier      = 3.0;    // SL distance = spacing × this
input double InpSslBreakevenThreshold = 5.0;   // USD profit to move to breakeven
input bool   InpSslTrailByAverage    = true;   // Trail from average price
input int    InpSslTrailOffsetPoints = 100;    // Trail offset in points
input bool   InpSslRespectMinStop    = true;   // Respect broker min stop level
```

**Reasoning**: Marked as production feature, benefits clearly stated.

---

### GROUP 7: Partial Close (PC) - PRODUCTION FEATURE
**Description**: Close profitable positions early to reduce exposure

```cpp
input group "=== PARTIAL CLOSE (PC) ⭐ PRODUCTION ==="
input bool   InpPcEnabled         = true;   // Master switch
input double InpPcMinProfitUsd    = 2.5;    // Min profit to trigger PC
input double InpPcCloseFraction   = 0.30;   // Close 30% of positions
input int    InpPcMaxTickets      = 3;      // Max tickets to close per cycle
input double InpPcMinLotsRemain   = 0.20;   // Min lot to keep open
input int    InpPcCooldownBars    = 10;     // Cooldown between PC cycles

// ⚠️ ADVANCED (rarely need adjustment)
input double InpPcRetestAtr       = 0.8;    // Retest detection threshold
input double InpPcSlopeHysteresis = 0.0002; // Slope change detection
input int    InpPcGuardBars       = 6;      // Guard period after PC
input double InpPcPendingGuardMult = 0.5;   // Pending guard multiplier
input double InpPcGuardExitAtr    = 0.6;    // Guard exit threshold
```

**Reasoning**: Essential PC parameters at top, advanced tuning parameters marked.

---

### GROUP 8: Dynamic Target Scaling (DTS) - PRODUCTION FEATURE
**Description**: Adjusts TP target based on market conditions

```cpp
input group "=== DYNAMIC TARGET SCALING (DTS) ⭐ PRODUCTION ==="
input bool   InpDtsEnabled        = true;   // Master switch
input double InpDtsMinMultiplier  = 0.7;    // Min TP multiplier
input double InpDtsMaxMultiplier  = 2.0;    // Max TP multiplier

// ATR Scaling
input bool   InpDtsAtrEnabled     = true;   // Enable ATR-based scaling
input double InpDtsAtrWeight      = 0.7;    // ATR weight (conservative)

// Time Decay
input bool   InpDtsTimeDecayEnabled = true; // Enable time decay
input double InpDtsTimeDecayRate  = 0.012;  // Decay rate (faster cool-down)
input double InpDtsTimeDecayFloor = 0.7;    // Decay floor (higher floor)

// Drawdown Scaling
input bool   InpDtsDdScalingEnabled = true; // Enable DD-based scaling
input double InpDtsDdThreshold    = 12.0;   // DD % to trigger scaling
input double InpDtsDdScaleFactor  = 50.0;   // Scaling factor
input double InpDtsDdMaxFactor    = 2.0;    // Max scaling multiplier
```

**Reasoning**: Organized by sub-feature (ATR/Time/DD), easy to enable/disable each.

---

### GROUP 9: Time-based Risk Management (TRM) - OPTIONAL
**Description**: Avoid trading during high-impact news

```cpp
input group "=== TIME-BASED RISK MANAGEMENT (TRM) ==="
input bool   InpTrmEnabled        = true;   // Master switch (DEFAULT OFF)
input bool   InpTrmUseApiNews     = true;   // Use ForexFactory API
input string InpTrmImpactFilter   = "High"; // High/Medium+/All
input int    InpTrmBufferMinutes  = 30;     // Buffer before/after news

// Actions During News
input bool   InpTrmPauseOrders    = true;   // Pause new orders
input bool   InpTrmTightenSL      = false;  // Tighten SSL (requires SSL enabled)
input double InpTrmSLMultiplier   = 0.5;    // SL tightening factor
input bool   InpTrmCloseOnNews    = false;  // Close all before news

// Fallback (if API fails)
input string InpTrmNewsWindows    = "08:30-09:00,14:00-14:30"; // UTC static windows
```

**Reasoning**: Actions grouped, fallback clearly marked.

---

### GROUP 10: Anti-Drawdown Cushion (ADC) - OPTIONAL
**Description**: Pause aggressive actions during high DD

```cpp
input group "=== ANTI-DRAWDOWN CUSHION (ADC) ==="
input bool   InpAdcEnabled         = true;   // Master switch (DEFAULT OFF)
input double InpAdcEquityDdThreshold = 10.0; // Equity DD % to activate
input bool   InpAdcPauseNewGrids   = true;   // Pause grid reseeding
input bool   InpAdcPauseRescue     = true;   // Pause rescue deployment
```

**Reasoning**: Simple group, 4 parameters only.

---

### GROUP 11: Execution & Broker Settings
**Description**: Order execution and broker constraints

```cpp
input group "=== EXECUTION & BROKER ==="
input int    InpOrderCooldownSec = 5;       // Cooldown between orders (sec)
input int    InpSlippagePips     = 1;       // Max slippage
input bool   InpRespectStops     = false;   // ⚠️ Set FALSE for backtest
input double InpCommissionPerLot = 0.0;     // Commission per lot (USD)
```

**Reasoning**: All execution-related parameters together.

---

### GROUP 12: Utility Features
**Description**: Misc features for stability

```cpp
input group "=== UTILITY FEATURES ==="
input bool   InpPreserveOnTfSwitch = true;  // Preserve positions on TF switch
input bool   InpMcdEnabled         = true;  // Manual close detection
input bool   InpLogEvents          = true;  // Enable logging
input int    InpStatusInterval     = 60;    // Status log interval (sec)
```

**Reasoning**: Small utility features grouped.

---

## Parameters to REMOVE (Unused/Ineffective)

### 1. `InpPcSlopeHysteresis` ❌
**Reason**: Rarely adjusted, default 0.0002 works for all symbols
**Action**: Hardcode to 0.0002, remove input

### 2. `InpPcPendingGuardMult` ❌
**Reason**: Advanced tuning, 99% users never touch
**Action**: Hardcode to 0.5, remove input

### 3. `InpPcGuardExitAtr` ❌
**Reason**: Auto-calculated from other params, no need for input
**Action**: Hardcode to 0.6, remove input

### 4. `InpDtsDdScaleFactor` ❌
**Reason**: Too complex for most users, default 50.0 works
**Action**: Hardcode to 50.0, remove input

### 5. `InpOffsetRatio` ❌
**Reason**: Rarely changed from default 0.5
**Action**: Hardcode to 0.5, remove input

---

## Final Organized Parameter Count

| Group | Parameters | Priority |
|-------|-----------|----------|
| 1. Core Settings | 7 | ⭐⭐⭐ ESSENTIAL |
| 2. Grid Spacing | 6 | ⭐⭐⭐ ESSENTIAL |
| 3. Dynamic Grid | 5 | ⭐⭐ OPTIONAL |
| 4. Rescue/Hedge | 9 | ⭐⭐⭐ ESSENTIAL |
| 5. Trailing Stop | 3 | ⭐⭐ OPTIONAL |
| 6. Smart Stop Loss (SSL) | 6 | ⭐⭐⭐ PRODUCTION |
| 7. Partial Close (PC) | 6 (advanced: 5) | ⭐⭐⭐ PRODUCTION |
| 8. Dynamic Target (DTS) | 11 | ⭐⭐⭐ PRODUCTION |
| 9. TRM | 9 | ⭐⭐ OPTIONAL |
| 10. ADC | 4 | ⭐⭐ OPTIONAL |
| 11. Execution/Broker | 4 | ⭐⭐ ESSENTIAL |
| 12. Utility | 4 | ⭐ OPTIONAL |
| **TOTAL** | **74** → **69** (after removing 5) | |

**Before Cleanup**: 60+ scattered parameters
**After Cleanup**: 69 organized (5 advanced hidden in PC group)
**User-facing (non-advanced)**: ~64 parameters

---

## Recommended Preset Templates

### Template 1: Conservative (Beginner)
```properties
# Core
InpLotBase = 0.01
InpLotOffset = 0.01
InpGridLevels = 200
InpTargetCycleUSD = 3.0
InpExposureCapLots = 1.0
InpSessionSL_USD = 50.0

# Rescue
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 0.8
InpRescueMaxLot = 0.20

# Features
InpSslEnabled = true   # DD protection
InpPcEnabled = true    # Early profit taking
InpDtsEnabled = true   # Adaptive TP
InpTrmEnabled = false  # OFF (optional)
InpAdcEnabled = false  # OFF (optional)
```

### Template 2: Balanced (Intermediate)
```properties
# Core
InpLotBase = 0.01
InpLotOffset = 0.01
InpGridLevels = 1000
InpTargetCycleUSD = 5.0
InpExposureCapLots = 2.0
InpSessionSL_USD = 100.0

# Rescue
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.0
InpRescueMaxLot = 0.50

# Features
InpSslEnabled = true
InpPcEnabled = true
InpDtsEnabled = true
InpTrmEnabled = true   # News avoidance
InpAdcEnabled = true   # DD cushion (10%)
```

### Template 3: Aggressive (Advanced)
```properties
# Core
InpLotBase = 0.01
InpLotOffset = 0.02
InpGridLevels = 2000
InpTargetCycleUSD = 10.0
InpExposureCapLots = 5.0
InpSessionSL_USD = 500.0

# Rescue
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.2
InpRescueMaxLot = 1.00

# Features
InpSslEnabled = false  # Disabled for higher profit
InpPcEnabled = true
InpDtsEnabled = true
InpTrmEnabled = true
InpAdcEnabled = true   # DD cushion (15%)
```

---

## Implementation Plan

### Phase 1: Reorganize Groups (High Priority)
- [x] Review current parameter organization
- [ ] Update RecoveryGridDirection_v2.mq5 with new groups
- [ ] Test compilation
- [ ] Verify all parameters mapped correctly

### Phase 2: Remove Unused Parameters (Medium Priority)
- [ ] Hardcode `InpPcSlopeHysteresis = 0.0002`
- [ ] Hardcode `InpPcPendingGuardMult = 0.5`
- [ ] Hardcode `InpPcGuardExitAtr = 0.6`
- [ ] Hardcode `InpDtsDdScaleFactor = 50.0`
- [ ] Hardcode `InpOffsetRatio = 0.5`
- [ ] Update all presets to remove these parameters

### Phase 3: Create Preset Templates (Low Priority)
- [ ] Create `00_Conservative_Template.set`
- [ ] Create `01_Balanced_Template.set`
- [ ] Create `02_Aggressive_Template.set`
- [ ] Document preset differences in README

---

## Benefits of Reorganization

1. **Easier Navigation**: Logical groups reduce cognitive load
2. **Clear Priorities**: ⭐ markers show what's essential
3. **Better Documentation**: Each group has purpose description
4. **Faster Setup**: Templates for common use cases
5. **Less Clutter**: Remove 5 rarely-used parameters
6. **Production Focus**: SSL/PC/DTS marked as production features

---

## Next Steps

1. Review this proposal with user
2. Get approval for parameters to remove
3. Implement new grouping in EA file
4. Update all existing presets
5. Create 3 template presets
6. Update documentation to reflect new organization
