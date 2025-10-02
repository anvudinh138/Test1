# Recovery Grid v3.0 - Development Roadmap

## 🎯 Current Status (v2.7)

**Completed Features:**
- ✅ Partial Close (PC)
- ✅ Dynamic Target Scaling (DTS)
- ✅ Smart Stop Loss (SSL)
- ✅ Time-based Risk Management (TRM)
- ✅ Anti-Drawdown Cushion (ADC)
- ✅ Timeframe Switch Fix
- ✅ Manual Close Detection
- ✅ Graceful Shutdown

**Best Results:**
- **Set 7** (PC + DTS): PF 5.64, DD 42.98% ❌
- **Set 8** (+ SSL): DD reduced to 16.99% ✅ (60% reduction!)
- **Set 10** (+ ADC): Target < 10% DD 🎯 (pending test)

---

## 📋 Feature Ideas Priority Queue

### 💡 **Idea #1: Dynamic Lot Scaling (DLS)** - NEXT
**Priority**: ⭐⭐⭐⭐⭐ (Highest)
**Difficulty**: Medium
**Estimated Time**: 2-3 hours
**Target Impact**: Reduce Deposit Load 30%, avoid margin calls

**Problem**:
- Fixed lot scaling (`InpLotScale = 1.5`) doesn't adapt to market
- Set 7 shows Deposit Load spike ~50% → risk margin call
- Same lot multiplier in calm and volatile markets is inefficient

**Solution**:
```cpp
// Dynamic: lot[i] = base × (dynamic_scale_factor)^i
// Factors: Volatility (ATR) + Account Health (DD%)

double CalculateDynamicLotScale() {
    double base_scale = m_params.lot_scale;  // 1.5 default

    // Factor 1: Volatility - reduce lot when ATR high
    double atr_ratio = atr_current / m_initial_atr;
    double vol_factor = 1.0 / MathMax(atr_ratio, 0.5);

    // Factor 2: Account DD - reduce lot when DD high
    double dd_pct = m_ledger.GetEquityDrawdownPercent();
    double dd_factor = 1.0 - (dd_pct / 100.0) * 0.5;
    dd_factor = MathMax(dd_factor, 0.3);  // Floor 30%

    // Combine
    double dynamic_scale = base_scale × vol_factor × dd_factor;
    return MathClamp(dynamic_scale, min_scale, max_scale);
}
```

**New Parameters**:
- `InpDlsEnabled = true` - Master switch
- `InpDlsVolWeight = 0.5` - ATR influence (0-1)
- `InpDlsDdWeight = 0.5` - DD influence (0-1)
- `InpDlsMinScale = 1.1` - Min scale factor
- `InpDlsMaxScale = 2.0` - Max scale factor

**Benefits**:
- Lower margin usage during DD → avoid margin call
- Higher profit during calm periods
- Self-adaptive without manual tuning

**Files to Modify**:
- `Params.mqh` (+5 fields)
- `GridBasket.mqh` (+50 lines for calculation)
- `RecoveryGridDirection_v2.mq5` (+6 input params)

**Testing Strategy**:
- Clone Set 10 → "11_DLS_Test.set"
- Enable DLS with balanced settings
- Compare Deposit Load: Set 10 vs Set 11
- Target: Max Deposit Load < 35% (down from 50%)

**Status**: 📝 Spec created, ready to implement

---

### 💡 **Idea #2: Smart Grid Spacing (SGS)** - QUEUED
**Priority**: ⭐⭐⭐⭐
**Difficulty**: Medium
**Estimated Time**: 2 hours
**Target Impact**: Reduce whipsaw 20%, better entry timing

**Problem**:
- Fixed HYBRID spacing doesn't adapt to trend vs range
- Get filled too early in strong trends (whipsaw)
- Miss opportunities in ranging markets

**Solution**:
- Widen spacing when trending (avoid premature fills)
- Tighten spacing when ranging (catch more bounces)
- Use recent_range / long_range ratio to detect

**Status**: 💭 Idea stage

---

### 💡 **Idea #3: Basket Health Score (BHS)** - QUEUED
**Priority**: ⭐⭐⭐⭐
**Difficulty**: Low
**Estimated Time**: 1.5 hours
**Target Impact**: Better decision clarity, improved UX

**Problem**:
- Binary "loser/winner" is too simplistic
- No gradual risk assessment
- Hard to visualize basket state

**Solution**:
- Score 0-100 based on DD%, time underwater, grid depth
- Status: CRITICAL/WARNING/HEALTHY/OPTIMAL
- Show on chart button: "BUY: 67% HEALTHY"
- Control actions based on score thresholds

**Status**: 💭 Idea stage

---

### 💡 **Idea #4: Volatility Regime Detection (VRD)** - QUEUED
**Priority**: ⭐⭐⭐⭐⭐
**Difficulty**: Medium
**Estimated Time**: 2.5 hours
**Target Impact**: Avoid "death spiral" in extreme volatility

**Problem**:
- Same strategy in all volatility regimes
- Set 7 Deposit Load spikes during volatile clusters
- No protection against flash crashes

**Solution**:
```cpp
enum EVolatilityRegime {
    VOL_ULTRA_LOW,   // ATR < 50% avg → Tighten spacing, increase lot
    VOL_LOW,         // ATR < 80% avg
    VOL_NORMAL,      // ATR 80-120% avg → Default
    VOL_HIGH,        // ATR 120-150% avg → Widen spacing
    VOL_EXTREME      // ATR > 150% avg → Pause rescue, reduce lot
};
```

**Adapt strategy per regime**:
- ULTRA_LOW: Aggressive (tight spacing, high lot)
- EXTREME: Defensive (wide spacing, low lot, pause rescue)

**Status**: 💭 Idea stage

---

### 💡 **Idea #5: Multi-Timeframe Confirmation (MTC)** - QUEUED
**Priority**: ⭐⭐⭐
**Difficulty**: Low
**Estimated Time**: 1 hour
**Target Impact**: Reduce counter-trend losses

**Problem**:
- Grid fights trend without higher TF awareness
- Rescue deployed against major trend direction

**Solution**:
- Check higher TF MA (e.g., 50 SMA on H1 when trading M15)
- Block rescue if counter to higher TF trend
- Simple but effective trend filter

**Status**: 💭 Idea stage

---

### 💡 **Idea #6: Emergency Flatten (EF)** - QUEUED
**Priority**: ⭐⭐⭐
**Difficulty**: Low
**Estimated Time**: 45 minutes
**Target Impact**: Capital preservation in black swan events

**Problem**:
- No emergency stop mechanism
- Graceful Shutdown takes 30 minutes (too slow for flash crash)

**Solution**:
- Chart button: "🚨 EMERGENCY FLATTEN"
- Auto-trigger conditions:
  - Equity DD > 25% AND
  - Both baskets DD < -$20 AND
  - ATR spike > 2× average
- Close all immediately + halt trading

**Status**: 💭 Idea stage

---

## 🗓️ Development Timeline

### Phase 1: Optimization (Current) - Week 1-2
- ✅ Complete Set 10 (ADC) testing
- ✅ Analyze results, optimize params
- ✅ Document best practices

### Phase 2: Dynamic Lot Scaling - Week 3-4
- 🔄 **Implement DLS feature**
- 🔄 Test on Set 11 (ADC + DLS)
- 🔄 Target: Deposit Load < 35%, DD < 10%
- 🔄 Compare PF: maintain > 3.0

### Phase 3: Volatility Regime - Week 5-6
- ⏳ Implement VRD feature
- ⏳ Test regime adaptation
- ⏳ Target: Reduce extreme vol losses 30%

### Phase 4: Smart Spacing + Health Score - Week 7-8
- ⏳ Implement SGS + BHS
- ⏳ UI improvements (health display)
- ⏳ Final optimization

### Phase 5: Safety Features - Week 9-10
- ⏳ Multi-TF Confirmation
- ⏳ Emergency Flatten
- ⏳ Portfolio-level risk dashboard

---

## 📊 Success Metrics

### Current Baseline (Set 10 - ADC)
- Max DD: < 10% (target)
- Profit Factor: > 2.5
- Deposit Load: ~40-50%
- Win Rate: ~60%

### Target After All Features (v3.0)
- Max DD: **< 8%** ⬇️
- Profit Factor: **> 4.0** ⬆️
- Deposit Load: **< 30%** ⬇️
- Win Rate: **> 65%** ⬆️
- Recovery Speed: **< 50 bars** ⬆️

---

## 🛠️ Implementation Rules

### Every New Feature MUST Have:
1. ✅ **Enable/Disable Flag** - `InpFeatureEnabled = true/false`
2. ✅ **Separate Branch** - `feature/feature-name`
3. ✅ **Spec Document** - `/idea/Feature_Name.md`
4. ✅ **Implementation Doc** - `IMPLEMENTATION_FEATURE_NAME.md`
5. ✅ **Testing Preset** - `XX_Feature_Test.set`
6. ✅ **Logging Tags** - `[FEATURE]` in all logs
7. ✅ **Backward Compatibility** - Old behavior when disabled

### Development Workflow:
```bash
# 1. Create spec
idea/Dynamic_Lot_Scaling.md

# 2. Create branch from master
git checkout master
git checkout -b feature/dynamic-lot-scaling

# 3. Implement with flag
InpDlsEnabled = true  # Default

# 4. Test thoroughly
preset/11_DLS_Test.set

# 5. Document
IMPLEMENTATION_DYNAMIC_LOT_SCALING.md

# 6. Commit & push
git commit -m "feat: Add Dynamic Lot Scaling (DLS)"
git push origin feature/dynamic-lot-scaling

# 7. Review & merge (after testing)
```

---

## 📝 Notes from Testing

### Set 7 Insights:
- ✅ PC + DTS synergy is excellent (PF 5.64)
- ❌ Equity DD 42.98% too high for live
- ❌ Deposit Load spike ~50% → margin risk
- 💡 Need adaptive lot sizing

### Set 8 Insights:
- ✅ SSL reduced DD 60% (42.98% → 16.99%)
- ✅ Hard SL prevents catastrophic losses
- ✅ Breakeven + trailing locks profits
- 💡 SSL is production-critical

### Set 10 Expectations:
- 🎯 ADC should reduce DD to < 10%
- 🎯 Pause risky ops during equity DD
- ⚠️ May reduce PF slightly (tradeoff)
- 💡 Combine with DLS for best results

---

## 🚀 Next Actions

### Immediate (This Week):
1. ✅ Save this roadmap
2. 🔄 Create DLS spec document
3. 🔄 Create branch `feature/dynamic-lot-scaling`
4. 🔄 Implement DLS with enable flag
5. 🔄 Test on Set 11
6. 🔄 Document results

### Short-term (Next 2 Weeks):
- Complete DLS + merge if successful
- Plan VRD implementation
- Optimize Set 10 params

### Long-term (Month 2-3):
- Implement remaining features
- Production deployment
- Live testing with small capital

---

## 🎯 Final Goal: Recovery Grid v3.0

**Vision**: Fully adaptive grid system that:
- Adjusts lot size based on volatility + account health
- Detects market regimes and adapts strategy
- Provides clear health metrics and emergency controls
- Achieves < 8% DD with > 4.0 PF consistently

**Release Target**: 3 months from now

---

*Last Updated*: 2025-10-02
*Current Version*: v2.7
*Next Feature*: Dynamic Lot Scaling (DLS)
*Status*: 🟢 Ready to implement
