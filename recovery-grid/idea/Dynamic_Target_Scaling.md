# Dynamic Target Scaling (DTS) Specification

## 📋 Overview

**Feature**: Dynamic Target Scaling - Tự động điều chỉnh profit target dựa trên volatility, drawdown, và thời gian hold.

**Goal**: Tăng profit trong volatile markets, giảm holding time trong consolidation, thoát nhanh khi deep DD.

**Status**: Planning Phase

---

## 🎯 Problem Statement

### Current Behavior (Fixed Target)
```cpp
// In GridBasket::CalculateGroupTP()
double target = m_params.target_cycle_usd - m_target_reduction;
```

**Issues**:
1. **High volatility**: Target $3 quá gần → đóng sớm, bỏ lỡ move lớn
2. **Low volatility**: Target $3 quá xa → hold lâu, tie up capital
3. **Deep DD**: Target cố định → recovery kéo dài, tâm lý áp lực
4. **Long holds**: Không có incentive để close stuck positions

### Example Scenarios

**Scenario 1: Volatile Market (ATR tăng 50%)**
- Fixed target: $3.00
- Price moves lớn, có thể đạt $5-6 dễ dàng
- Close sớm tại $3 → **bỏ lỡ $2-3 profit**

**Scenario 2: Consolidation (ATR giảm 30%)**
- Fixed target: $3.00
- Price moves nhỏ, phải chờ lâu
- Hold 50+ bars → **capital inefficiency**

**Scenario 3: Deep Drawdown ($-15)**
- Fixed target: $3.00
- Chờ winner cứu đủ $3 mới close
- Loser bị stuck 100+ bars → **psychological pain**

---

## 💡 Solution: Dynamic Target Scaling

### Core Concept

**Adaptive Target Formula**:
```
adjusted_target = base_target × ATR_factor × Time_factor ÷ DD_factor
```

**Constraints**:
```
min_target = base_target × InpDtsMinMultiplier  (default: 0.5)
max_target = base_target × InpDtsMaxMultiplier  (default: 2.5)
```

---

## 🔧 Algorithm Design

### Factor 1: ATR Multiplier (Volatility Adaptation)

**Purpose**: Scale target UP trong high volatility, DOWN trong low volatility.

**Formula**:
```cpp
double atr_current = m_spacing->AtrPoints();
double atr_ratio = 1.0;

if(InpDtsAtrEnabled && m_initial_atr > 0 && atr_current > 0)
{
    atr_ratio = atr_current / m_initial_atr;

    // Apply weight
    atr_ratio = 1.0 + (atr_ratio - 1.0) * InpDtsAtrWeight;

    // Cap extremes
    atr_ratio = MathMax(atr_ratio, 0.5);  // Min 50%
    atr_ratio = MathMin(atr_ratio, 2.0);  // Max 200%
}
```

**Example**:
- Initial ATR = 40 pips
- Current ATR = 60 pips → ratio = 1.5
- Weight = 0.8 → effective = 1.0 + (1.5 - 1.0) × 0.8 = 1.4
- Target = $3 × 1.4 = **$4.20**

**Variables to track**:
```cpp
// In GridBasket class
double m_initial_atr;  // Captured at Init()
```

---

### Factor 2: Time Decay (Reduce Long Holds)

**Purpose**: Giảm target dần theo thời gian để incentivize close stuck positions.

**Formula**:
```cpp
double time_factor = 1.0;

if(InpDtsTimeDecayEnabled)
{
    int bars_in_trade = CurrentBars() - m_entry_bar;

    // Exponential decay
    time_factor = 1.0 / (1.0 + bars_in_trade * InpDtsTimeDecayRate);

    // Floor
    time_factor = MathMax(time_factor, InpDtsTimeDecayFloor);
}
```

**Example**:
- Entry bar = 1000, Current bar = 1050 → 50 bars
- Decay rate = 0.01
- Factor = 1.0 / (1.0 + 50 × 0.01) = 1.0 / 1.5 = **0.67**
- Target = $3 × 0.67 = **$2.00**

**Variables to track**:
```cpp
// In GridBasket class
int m_entry_bar;  // Captured at Init()
```

---

### Factor 3: DD Scaling (Faster Escape)

**Purpose**: Giảm target khi DD sâu để escape nhanh hơn.

**Formula**:
```cpp
double dd_factor = 1.0;

if(InpDtsDdScalingEnabled && m_pnl_usd < 0)
{
    double dd_abs = MathAbs(m_pnl_usd);

    // DD beyond threshold triggers scaling
    if(dd_abs > InpDtsDdThreshold)
    {
        double excess_dd = dd_abs - InpDtsDdThreshold;
        dd_factor = 1.0 + (excess_dd / InpDtsDdScaleFactor);

        // Cap max reduction
        dd_factor = MathMin(dd_factor, InpDtsDdMaxFactor);
    }
}
```

**Example**:
- Current PnL = -$20
- DD threshold = $10
- Excess DD = $20 - $10 = $10
- Scale factor = 50.0
- DD factor = 1.0 + ($10 / $50) = **1.2**
- Target = $3 ÷ 1.2 = **$2.50**

---

### Combined Logic

**Full implementation**:
```cpp
double GridBasket::CalculateDynamicTarget()
{
    if(!m_params.dts_enabled)
        return m_params.target_cycle_usd;  // Original behavior

    double base_target = m_params.target_cycle_usd;

    // Factor 1: ATR
    double atr_factor = CalculateAtrFactor();

    // Factor 2: Time decay
    double time_factor = CalculateTimeFactor();

    // Factor 3: DD scaling
    double dd_factor = CalculateDdFactor();

    // Combine
    double adjusted = base_target * atr_factor * time_factor;
    if(dd_factor > 1.0)
        adjusted = adjusted / dd_factor;

    // Apply constraints
    double min_target = base_target * m_params.dts_min_multiplier;
    double max_target = base_target * m_params.dts_max_multiplier;

    adjusted = MathMax(adjusted, min_target);
    adjusted = MathMin(adjusted, max_target);

    return adjusted;
}

void GridBasket::CalculateGroupTP()
{
    // ... existing tick_value, tick_size calculation ...

    double target = CalculateDynamicTarget() - m_target_reduction;

    // Add commission
    if(m_params.commission_per_lot > 0.0)
        target += m_params.commission_per_lot * m_total_lot;

    // ... rest of TP calculation ...
}
```

---

## 🎛️ Parameters

### Master Switch
```cpp
input group "=== Dynamic Target Scaling ==="
input bool   InpDtsEnabled           = false;   // Enable DTS
```

### ATR Factor
```cpp
input bool   InpDtsAtrEnabled        = true;    // Use ATR scaling
input double InpDtsAtrWeight         = 0.8;     // ATR influence (0-1)
```

### Time Decay
```cpp
input bool   InpDtsTimeDecayEnabled  = true;    // Enable time decay
input double InpDtsTimeDecayRate     = 0.01;    // Decay per bar
input double InpDtsTimeDecayFloor    = 0.5;     // Min time factor
```

### DD Scaling
```cpp
input bool   InpDtsDdScalingEnabled  = true;    // Enable DD scaling
input double InpDtsDdThreshold       = 10.0;    // DD threshold (USD)
input double InpDtsDdScaleFactor     = 50.0;    // Scaling sensitivity
input double InpDtsDdMaxFactor       = 2.0;     // Max DD factor
```

### Global Constraints
```cpp
input double InpDtsMinMultiplier     = 0.5;     // Min target (× base)
input double InpDtsMaxMultiplier     = 2.5;     // Max target (× base)
```

---

## 📊 Parameter Mapping (SParams)

```cpp
// In Params.mqh
struct SParams
{
    // ... existing params ...

    // Dynamic Target Scaling
    bool   dts_enabled;
    bool   dts_atr_enabled;
    double dts_atr_weight;
    bool   dts_time_decay_enabled;
    double dts_time_decay_rate;
    double dts_time_decay_floor;
    bool   dts_dd_scaling_enabled;
    double dts_dd_threshold;
    double dts_dd_scale_factor;
    double dts_dd_max_factor;
    double dts_min_multiplier;
    double dts_max_multiplier;
};
```

```cpp
// In RecoveryGridDirection_v2.mq5::BuildParams()
g_params.dts_enabled              = InpDtsEnabled;
g_params.dts_atr_enabled          = InpDtsAtrEnabled;
g_params.dts_atr_weight           = InpDtsAtrWeight;
g_params.dts_time_decay_enabled   = InpDtsTimeDecayEnabled;
g_params.dts_time_decay_rate      = InpDtsTimeDecayRate;
g_params.dts_time_decay_floor     = InpDtsTimeDecayFloor;
g_params.dts_dd_scaling_enabled   = InpDtsDdScalingEnabled;
g_params.dts_dd_threshold         = InpDtsDdThreshold;
g_params.dts_dd_scale_factor      = InpDtsDdScaleFactor;
g_params.dts_dd_max_factor        = InpDtsDdMaxFactor;
g_params.dts_min_multiplier       = InpDtsMinMultiplier;
g_params.dts_max_multiplier       = InpDtsMaxMultiplier;
```

---

## 🏗️ Implementation Plan

### Phase 1: Infrastructure (30 min)
1. Add DTS params to `Params.mqh`
2. Add DTS inputs to EA main file
3. Map inputs in `BuildParams()`

### Phase 2: GridBasket Extension (60 min)
4. Add tracking fields:
   ```cpp
   double m_initial_atr;
   int    m_entry_bar;
   ```
5. Capture initial values in `Init()`:
   ```cpp
   m_initial_atr = m_spacing->AtrPoints();
   m_entry_bar = Bars(m_symbol, PERIOD_CURRENT);
   ```
6. Implement helper methods:
   - `CalculateAtrFactor()`
   - `CalculateTimeFactor()`
   - `CalculateDdFactor()`
   - `CalculateDynamicTarget()`

### Phase 3: Integration (20 min)
7. Modify `CalculateGroupTP()` to use `CalculateDynamicTarget()`
8. Add logging for adjusted target

### Phase 4: Testing (60 min)
9. Compile and fix errors
10. Backtest scenarios:
    - High volatility period (ATR × 1.5)
    - Low volatility period (ATR × 0.7)
    - Deep DD (-$20+)
    - Long hold (100+ bars)
11. Compare vs baseline (DTS disabled)

### Phase 5: Optimization (30 min)
12. Tune `InpDtsAtrWeight`
13. Tune `InpDtsTimeDecayRate`
14. Tune `InpDtsDdScaleFactor`
15. Find optimal `MinMultiplier` / `MaxMultiplier`

### Phase 6: Documentation (20 min)
16. Update implementation plan
17. Add to parameter guide
18. Commit

**Total Estimated Time**: ~3.5 hours

---

## 🧪 Testing Scenarios

### Test 1: Baseline Comparison
**Setup**:
- Period: 2025.05-2025.07 (same as PC tests)
- `InpDtsEnabled = false`

**Metrics to capture**:
- Final balance
- Max DD
- Avg holding time
- Total trades

### Test 2: High Volatility
**Setup**:
- `InpDtsEnabled = true`
- All sub-features enabled
- Test during volatile period (e.g., 2025.06.15-2025.06.25)

**Expected**:
- Higher profit per trade
- Target scales up → capture bigger moves

### Test 3: Low Volatility
**Setup**:
- Test during consolidation (e.g., 2025.07.01-2025.07.10)

**Expected**:
- Shorter holding time
- Target scales down → faster closes

### Test 4: Deep DD Recovery
**Setup**:
- Test period with deep DD events

**Expected**:
- Faster recovery
- Lower max DD duration

### Test 5: Extreme Parameters
**Setup**:
- Test with extreme multipliers (0.3, 3.0)
- Verify constraints work

**Expected**:
- No crashes
- Targets stay within bounds

---

## 📈 Success Criteria

**Minimum Requirements** (vs baseline):
- ✅ Win rate: +3% or more
- ✅ Avg profit per trade: +10% or more
- ✅ Avg holding time: -15% or more
- ✅ Max DD: No worse than baseline
- ✅ No logic breaks when disabled

**Stretch Goals**:
- 🎯 Win rate: +5-10%
- 🎯 Avg profit: +15-25%
- 🎯 Holding time: -20-30%
- 🎯 Profit factor: 1.8 → 2.0+

---

## 🔍 Logging

Add detailed logs for debugging:

```cpp
if(m_log && m_params.dts_enabled)
{
    string msg = StringFormat(
        "[DTS] base=%.2f atr_f=%.2f time_f=%.2f dd_f=%.2f → adjusted=%.2f",
        base_target, atr_factor, time_factor, dd_factor, adjusted_target
    );
    m_log.Event(Tag(), msg);
}
```

**Example log output**:
```
[RGDv2][BTCUSD][SELL][PRI] [DTS] base=3.00 atr_f=1.35 time_f=0.85 dd_f=1.00 → adjusted=3.44
[RGDv2][BTCUSD][SELL][PRI] [DTS] base=3.00 atr_f=1.10 time_f=0.65 dd_f=1.50 → adjusted=1.43
```

---

## ⚠️ Risks & Mitigations

### Risk 1: Target too aggressive
**Impact**: Close too late, give back profits
**Mitigation**:
- Cap at `InpDtsMaxMultiplier = 2.5`
- Test with conservative defaults first

### Risk 2: Time decay too fast
**Impact**: Close prematurely, miss recovery
**Mitigation**:
- Default `InpDtsTimeDecayRate = 0.01` (slow)
- Floor at `InpDtsTimeDecayFloor = 0.5`

### Risk 3: DD scaling over-reduces
**Impact**: Exit too early in DD, miss full recovery
**Mitigation**:
- Threshold `InpDtsDdThreshold = 10.0` (only deep DD)
- Cap `InpDtsDdMaxFactor = 2.0` (max 50% reduction)

### Risk 4: Breaking existing logic
**Impact**: Regression bugs
**Mitigation**:
- ✅ **Master switch `InpDtsEnabled = false` by default**
- Maintain backward compatibility
- Extensive testing disabled vs enabled

---

## 🎯 Recommended Default Settings

### Conservative (Safe start)
```cpp
InpDtsEnabled           = true
InpDtsAtrEnabled        = true
InpDtsAtrWeight         = 0.5    // Gentle ATR influence
InpDtsTimeDecayEnabled  = true
InpDtsTimeDecayRate     = 0.005  // Very slow decay
InpDtsTimeDecayFloor    = 0.7    // Don't reduce below 70%
InpDtsDdScalingEnabled  = false  // Disable DD scaling initially
InpDtsMinMultiplier     = 0.7    // Conservative floor
InpDtsMaxMultiplier     = 1.5    // Conservative ceiling
```

### Balanced (Recommended)
```cpp
InpDtsEnabled           = true
InpDtsAtrEnabled        = true
InpDtsAtrWeight         = 0.8    // Default
InpDtsTimeDecayEnabled  = true
InpDtsTimeDecayRate     = 0.01   // Default
InpDtsTimeDecayFloor    = 0.5    // Default
InpDtsDdScalingEnabled  = true
InpDtsDdThreshold       = 10.0   // Default
InpDtsDdScaleFactor     = 50.0   // Default
InpDtsDdMaxFactor       = 2.0    // Default
InpDtsMinMultiplier     = 0.5    // Default
InpDtsMaxMultiplier     = 2.5    // Default
```

### Aggressive (High profit seeking)
```cpp
InpDtsEnabled           = true
InpDtsAtrEnabled        = true
InpDtsAtrWeight         = 1.0    // Full ATR weight
InpDtsTimeDecayEnabled  = true
InpDtsTimeDecayRate     = 0.015  // Faster decay
InpDtsTimeDecayFloor    = 0.4    // Lower floor
InpDtsDdScalingEnabled  = true
InpDtsDdThreshold       = 5.0    // Earlier trigger
InpDtsDdScaleFactor     = 30.0   // More aggressive
InpDtsDdMaxFactor       = 3.0    // Allow 67% reduction
InpDtsMinMultiplier     = 0.4    // Lower floor
InpDtsMaxMultiplier     = 3.0    // Higher ceiling
```

---

## 🔄 Future Enhancements

### v2.3+: ML-based Target Prediction
- Train model on historical data
- Predict optimal target per regime
- Auto-adjust factors

### v2.4+: Multi-timeframe ATR
- Use multiple ATR timeframes (M15, H1, H4)
- Weighted average for smoother scaling

### v2.5+: Volatility Regime Classification
- Detect: Low / Normal / High / Extreme
- Pre-defined multipliers per regime

---

**Document Version**: 1.0
**Created**: 2025-10-01
**Status**: Ready for Implementation
**Estimated Completion**: 2-3 hours

**Next Step**: Begin Phase 1 - Infrastructure setup
