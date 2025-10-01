# Crypto Protection Features - Emergency Improvements

**Context**: BTCUSD spike test revealed account blow-up during extreme price moves
**Date**: 2025-10-01
**Priority**: 🔥 HIGH (Crypto trading safety)

---

## 🚨 Critical Issues Found

### Test Results
- **Symbol**: BTCUSD
- **Account**: Started $10,000
- **Result**: Blown to near $0
- **Cause**: Extreme price spike at end of test (>5% move)
- **Current Protection**: ADC paused new orders but didn't close positions

### Root Causes
1. ❌ No emergency flatten on extreme moves
2. ❌ ADC cushion doesn't close positions (only pauses new ones)
3. ❌ Session SL set too high ($100,000 vs $10,000 account)
4. ❌ Crypto volatility much higher than forex

---

## 💡 Proposed Solutions

### **Priority 1: Session SL Fix** ⚡ (5 minutes)
**Complexity**: ⭐ (Trivial - just change parameter)
**Impact**: ⭐⭐⭐⭐⭐ (Would've prevented account blow-up)

**Problem**: `InpSessionSL_USD = 100000` too high for $10k account

**Solution**: Adjust to account-relative value
```cpp
InpSessionSL_USD = 1000  // 10% of $10k account
```

**Implementation**:
- Just update preset file
- No code changes needed
- ALREADY IMPLEMENTED in PortfolioLedger.mqh

**Expected Result**: Account stops at -$1,000 loss (10% DD), preserves $9,000

**Test**: Re-run BTCUSD test with lowered Session SL

---

### **Priority 2: ADC Hard Stop** ⭐⭐⭐⭐ (30 minutes)
**Complexity**: ⭐⭐ (Low - simple addition to existing ADC)
**Impact**: ⭐⭐⭐⭐ (Guaranteed max DD cap)

**Problem**: ADC pauses new orders but allows existing positions to grow losses

**Solution**: Add hard stop at cushion threshold + buffer
```cpp
// New parameters
bool   adc_hard_stop_enabled = true;
double adc_hard_stop_buffer  = 5.0;  // Close all at threshold + buffer

// In LifecycleController::Update()
if (m_params.adc_enabled && m_params.adc_hard_stop_enabled) {
    double equity_dd_pct = m_ledger->GetEquityDrawdownPercent();
    double hard_stop_threshold = m_params.adc_equity_dd_threshold + m_params.adc_hard_stop_buffer;

    if (equity_dd_pct >= hard_stop_threshold) {
        if (m_log != NULL)
            m_log.Event(Tag(), StringFormat("[ADC] HARD STOP: Equity DD %.2f%% >= %.2f%% - closing all positions",
                                           equity_dd_pct, hard_stop_threshold));
        FlattenAll("ADC hard stop");
        m_halted = true;
        return;
    }
}
```

**Parameters**:
- `InpAdcHardStopEnabled = true` (default ON for crypto)
- `InpAdcHardStopBuffer = 5.0` (close at cushion + 5%)

**Example**:
- ADC cushion activates @ 10% DD (pauses new orders)
- ADC hard stop triggers @ 15% DD (closes all positions, halts trading)

**Expected Result**: Maximum possible DD = 15% (vs unlimited currently)

**Files to Modify**:
- `src/core/Params.mqh` - Add 2 parameters
- `src/core/LifecycleController.mqh` - Add hard stop check in Update()
- `src/ea/RecoveryGridDirection_v2.mq5` - Add input parameters

---

### **Priority 3: Emergency Flatten on Extreme Moves** ⭐⭐⭐ (1 hour)
**Complexity**: ⭐⭐⭐ (Medium - need price tracking)
**Impact**: ⭐⭐⭐⭐ (Prevents flash crash wipeouts)

**Problem**: Sudden 5-10% price moves in minutes overwhelm grid system

**Solution**: Detect extreme price velocity → flatten all positions immediately

**Implementation**:
```cpp
// New parameters
bool   emergency_flatten_enabled      = true;
double emergency_move_threshold_pct   = 3.0;   // % move to trigger
int    emergency_lookback_bars        = 5;     // Check last N bars

// State variables in LifecycleController
double m_emergency_price_history[10];  // Circular buffer
int    m_emergency_history_index;

// In Update() - before any trading logic
void CheckEmergencyFlatten() {
    if (!m_params.emergency_flatten_enabled)
        return;

    // Update price history
    double current_price = (SymbolInfoDouble(m_symbol, SYMBOL_ASK) +
                           SymbolInfoDouble(m_symbol, SYMBOL_BID)) / 2.0;
    m_emergency_price_history[m_emergency_history_index % 10] = current_price;
    m_emergency_history_index++;

    // Need enough history
    if (m_emergency_history_index < m_params.emergency_lookback_bars)
        return;

    // Get price N bars ago
    int old_index = (m_emergency_history_index - m_params.emergency_lookback_bars) % 10;
    double old_price = m_emergency_price_history[old_index];

    if (old_price <= 0.0)
        return;

    // Calculate move %
    double move_pct = MathAbs((current_price - old_price) / old_price) * 100.0;

    if (move_pct >= m_params.emergency_move_threshold_pct) {
        if (m_log != NULL)
            m_log.Event(Tag(), StringFormat("[EMERGENCY] Extreme move %.2f%% in %d bars (threshold %.2f%%) - flattening all",
                                           move_pct, m_params.emergency_lookback_bars,
                                           m_params.emergency_move_threshold_pct));
        FlattenAll("Emergency spike");
        m_halted = true;
    }
}
```

**Parameters**:
- `InpEmergencyFlattenEnabled = true` (default ON for crypto)
- `InpEmergencyMoveThreshold = 3.0` (flatten at 3% move in lookback period)
- `InpEmergencyLookbackBars = 5` (check last 5 bars = ~5 minutes on M1)

**Example Scenarios**:
- BTCUSD moves from $60,000 → $61,800 in 5 bars (+3%) → Flatten all
- Flash crash: $60,000 → $57,000 in 3 bars (-5%) → Flatten all

**Expected Result**:
- Prevents grid martingale during extreme volatility
- Caps loss during flash events
- Can re-enter after volatility settles

**Files to Modify**:
- `src/core/Params.mqh` - Add 3 parameters
- `src/core/LifecycleController.mqh` - Add price history tracking + emergency check
- `src/ea/RecoveryGridDirection_v2.mq5` - Add input parameters

---

### **Priority 4: Basket Max Loss Stop** ⭐⭐⭐⭐ (1.5 hours)
**Complexity**: ⭐⭐⭐ (Medium - basket-level logic)
**Impact**: ⭐⭐⭐ (Prevents single basket blowout)

**Problem**: One basket can accumulate massive unrealized loss while waiting for Group TP

**Solution**: Close basket if unrealized loss exceeds threshold

**Implementation**:
```cpp
// New parameter in Params.mqh
double max_basket_loss_usd = 500.0;  // Close basket at -$500

// In GridBasket::Update()
void GridBasket::Update() {
    // ... existing code ...

    // Check basket max loss
    if (m_params.max_basket_loss_usd > 0.0 && IsActive()) {
        double pnl = BasketPnL();
        if (pnl < -m_params.max_basket_loss_usd) {
            if (m_log != NULL)
                m_log.Event(Tag(), StringFormat("[BASKET] Max loss hit: %.2f < -%.2f - closing basket",
                                               pnl, m_params.max_basket_loss_usd));
            CloseBasket("Max basket loss");
            return;
        }
    }
}
```

**Parameters**:
- `InpMaxBasketLossUsd = 500` (close basket at -$500 unrealized)

**Example**:
- BUY basket has -$450 unrealized → Still open
- BUY basket reaches -$500 unrealized → Close all positions immediately
- Prevents martingale death spiral in one direction

**Expected Result**: Limits single basket loss, forces flip sooner

**Files to Modify**:
- `src/core/Params.mqh` - Add parameter
- `src/core/GridBasket.mqh` - Add max loss check in Update()
- `src/ea/RecoveryGridDirection_v2.mq5` - Add input parameter

---

### **Priority 5: BTCUSD-Specific Preset** ⭐⭐ (30 minutes)
**Complexity**: ⭐ (Trivial - just parameter tuning)
**Impact**: ⭐⭐⭐ (Optimized for crypto volatility)

**Problem**: Forex settings don't work for crypto (10x more volatile)

**Solution**: Create crypto-optimized preset with wider spacing, smaller lots

**Preset: `12_Crypto_Safe.set`**
```ini
; BTCUSD / Crypto Safe Settings
; Wider spacing, smaller lots, tighter stops
InpSpacingStepPips=50.0          ; vs 25 for forex (2x wider)
InpSpacingAtrMult=0.8            ; Higher ATR multiplier
InpMinSpacingPips=25.0           ; Higher minimum

InpLotBase=0.005                 ; Smaller base (vs 0.01)
InpLotScale=1.0                  ; NO martingale
InpTargetCycleUSD=10.0           ; Higher TP target (vs $5)

InpTSLEnabled=true
InpTSLStartPoints=2000           ; Wider TSL start (vs 1000)
InpTSLStepPoints=400             ; Wider TSL step (vs 200)

InpRecoveryLot=0.01              ; Smaller rescue lot (vs 0.02)
InpDDOpenUSD=20.0                ; Higher DD threshold (vs 10)

InpExposureCapLots=1.0           ; Lower max exposure (vs 2.0)
InpMaxCyclesPerSide=2            ; Fewer cycles (vs 3)

; Session Protection
InpSessionSL_USD=1000            ; 10% of $10k account

; SSL - Enabled
InpSslEnabled=true
InpSslSlMultiplier=4.0           ; Wider SL (vs 3.0)
InpSslBreakevenThreshold=10.0    ; Later BE (vs 5.0)
InpSslTrailOffsetPoints=200      ; Looser trail (vs 100)

; TRM - Disabled (crypto = 24/7)
InpTrmEnabled=false

; ADC - Enabled with hard stop
InpAdcEnabled=true
InpAdcEquityDdThreshold=8.0      ; Tighter cushion (vs 10%)
InpAdcHardStopEnabled=true       ; NEW!
InpAdcHardStopBuffer=3.0         ; Close at 11% DD (8% + 3%)

; Emergency Flatten - Enabled
InpEmergencyFlattenEnabled=true  ; NEW!
InpEmergencyMoveThreshold=3.0    ; Flatten at 3% spike
InpEmergencyLookbackBars=5       ; Check last 5 bars
```

**Expected Result**: Safer crypto trading with controlled DD

---

### **Priority 6: Volatility-Adaptive Exposure** ⭐⭐⭐ (2-3 hours)
**Complexity**: ⭐⭐⭐⭐ (Medium-High - ATR tracking)
**Impact**: ⭐⭐⭐ (Dynamic risk adjustment)

**Problem**: Fixed lot size doesn't adapt to changing volatility

**Solution**: Reduce lot size when ATR spikes (high volatility period)

**Implementation**:
```cpp
// New parameters
bool   adaptive_exposure_enabled = true;
int    adaptive_atr_period       = 20;
double adaptive_high_vol_ratio   = 2.0;    // ATR > 2x average = high vol
double adaptive_lot_reduction    = 0.5;    // Half lot size during high vol

// In LifecycleController - add method
double GetVolatilityAdjustedLot(double base_lot) {
    if (!m_params.adaptive_exposure_enabled)
        return base_lot;

    // Get current ATR
    double atr_current = iATR(m_symbol, m_spacing->Timeframe(), m_params.atr_period, 0);

    // Get average ATR (last N periods)
    double atr_sum = 0.0;
    for (int i = 0; i < m_params.adaptive_atr_period; i++) {
        atr_sum += iATR(m_symbol, m_spacing->Timeframe(), m_params.atr_period, i);
    }
    double atr_avg = atr_sum / m_params.adaptive_atr_period;

    if (atr_avg <= 0.0)
        return base_lot;

    // Calculate volatility ratio
    double vol_ratio = atr_current / atr_avg;

    // If high volatility, reduce lot
    if (vol_ratio >= m_params.adaptive_high_vol_ratio) {
        double adjusted = base_lot * m_params.adaptive_lot_reduction;
        if (m_log != NULL)
            m_log.Event(Tag(), StringFormat("[ADAPTIVE] High volatility (ratio %.2f) - reducing lot %.3f -> %.3f",
                                           vol_ratio, base_lot, adjusted));
        return adjusted;
    }

    return base_lot;
}

// Use in TryReseedBasket
double seed_lot = GetVolatilityAdjustedLot(m_params.lot_base);
```

**Parameters**:
- `InpAdaptiveExposureEnabled = true`
- `InpAdaptiveAtrPeriod = 20` (compare to 20-period average)
- `InpAdaptiveHighVolRatio = 2.0` (trigger when ATR > 2x average)
- `InpAdaptiveLotReduction = 0.5` (half lot during high vol)

**Example**:
- Normal ATR = 50 pips, Current ATR = 50 pips → Full lot (0.01)
- Normal ATR = 50 pips, Current ATR = 120 pips (2.4x) → Half lot (0.005)

**Expected Result**: Lower exposure during volatile periods, reduce spike damage

---

## 📊 Feature Comparison

| Feature | Complexity | Time | Impact | Crypto-Specific |
|---------|-----------|------|--------|----------------|
| Session SL Fix | ⭐ | 5 min | ⭐⭐⭐⭐⭐ | ✅ |
| ADC Hard Stop | ⭐⭐ | 30 min | ⭐⭐⭐⭐ | ✅ |
| Emergency Flatten | ⭐⭐⭐ | 1 hr | ⭐⭐⭐⭐ | ✅ |
| Basket Max Loss | ⭐⭐⭐ | 1.5 hr | ⭐⭐⭐ | ❌ |
| Crypto Preset | ⭐ | 30 min | ⭐⭐⭐ | ✅ |
| Adaptive Exposure | ⭐⭐⭐⭐ | 2-3 hr | ⭐⭐⭐ | ❌ |

---

## 🎯 Recommended Implementation Order

### **Day 1 (Morning - 1 hour)**
1. ✅ Session SL Fix (5 min)
2. ✅ Test BTCUSD with lowered SL
3. ✅ Verify account stops at -10% DD

### **Day 1 (Afternoon - 2 hours)**
4. ✅ Implement ADC Hard Stop (30 min)
5. ✅ Test on BTCUSD spike scenario (30 min)
6. ✅ Create Crypto Preset (30 min)
7. ✅ Document & update CHANGELOG (30 min)

### **Day 2 (If needed - 3 hours)**
8. ⚠️ Implement Emergency Flatten (1 hr)
9. ⚠️ Test on extreme volatility scenarios (1 hr)
10. ⚠️ Implement Basket Max Loss OR Adaptive Exposure (1 hr)

---

## 🧪 Testing Strategy

### **Test Scenarios**

**Scenario 1: Flash Crash**
- BTCUSD drops 10% in 5 bars
- **Expected**: Emergency Flatten triggers @ 3% move
- **Max Loss**: ~$300 (stopped early)

**Scenario 2: Slow Bleed**
- BTCUSD trends down, equity DD grows to 8% → 10% → 15%
- **Expected**:
  - ADC cushion activates @ 8% (pause new orders)
  - ADC hard stop triggers @ 11% (8% + 3% buffer, close all)
- **Max Loss**: ~$1,100 (11% of $10k)

**Scenario 3: Session Loss**
- Multiple losing trades, cumulative -$1,000
- **Expected**: Session SL triggers, halts trading
- **Max Loss**: $1,000 (10% of account)

**Scenario 4: Normal Volatility**
- BTCUSD normal swings, ATR within 2x average
- **Expected**: Normal trading, no emergency triggers
- **Result**: Profitable cycles

---

## 📝 Implementation Checklist

### **Phase 1: Quick Fixes** (1 hour total)
- [ ] Update Session SL to $1,000 in test presets
- [ ] Re-run BTCUSD test
- [ ] Verify account preservation

### **Phase 2: ADC Hard Stop** (2 hours total)
- [ ] Add `adc_hard_stop_enabled` parameter to Params.mqh
- [ ] Add `adc_hard_stop_buffer` parameter to Params.mqh
- [ ] Add hard stop check in LifecycleController::Update()
- [ ] Add EA inputs (InpAdcHardStopEnabled, InpAdcHardStopBuffer)
- [ ] Test on BTCUSD
- [ ] Update CHANGELOG v2.5

### **Phase 3: Emergency Flatten** (3 hours total)
- [ ] Add 3 emergency parameters to Params.mqh
- [ ] Add price history tracking to LifecycleController
- [ ] Implement CheckEmergencyFlatten() method
- [ ] Add EA inputs (3 parameters)
- [ ] Test on extreme volatility scenarios
- [ ] Update CHANGELOG v2.5

### **Phase 4: Crypto Preset** (30 minutes)
- [ ] Create `12_Crypto_Safe.set` with tuned parameters
- [ ] Document in preset/README.md
- [ ] Test on BTCUSD, ETHUSD

### **Phase 5: Advanced Features** (Optional, 3-5 hours)
- [ ] Implement Basket Max Loss Stop
- [ ] OR Implement Volatility-Adaptive Exposure
- [ ] Test & document

---

## 🎯 Success Criteria

### **Minimum Viable Protection** (Phase 1-2)
✅ BTCUSD test preserves $9,000+ (max -10% loss)
✅ ADC hard stop caps DD at 11-15%
✅ No account blow-ups during testing

### **Complete Protection** (Phase 1-3)
✅ Emergency Flatten stops flash crash losses < 5%
✅ Combined features cap max DD at 15%
✅ Crypto preset shows stable equity curve

### **Advanced Features** (Phase 5)
✅ Volatility adaptation reduces exposure during spikes
✅ Basket max loss prevents one-sided blowouts

---

## 📚 Related Documents

- **ADC Implementation**: `ADC_IMPLEMENTATION_SUMMARY.md`
- **Roadmap**: `Future_Features_Roadmap.md`
- **CHANGELOG**: `CHANGELOG.md` (update to v2.5 when implemented)

---

## 💭 Future Considerations

### **Phase 6 Ideas** (Long-term)
1. **Multi-timeframe Volatility**: Check H1/H4 volatility, not just M1
2. **News Calendar Integration**: Auto-adjust thresholds before major events
3. **Correlation-based Risk**: Reduce exposure if correlated pairs show stress
4. **Machine Learning**: Predict spike probability, pre-flatten if high risk
5. **Portfolio-level Protection**: Coordinate across multiple symbols

---

## 🔥 Summary

**Critical Insight from BTCUSD Test**:
Current system protects against **gradual drawdown** (SSL, ADC) but not **sudden spikes**.

**Fix Strategy**:
1. **Immediate** (5 min): Lower Session SL
2. **Short-term** (2 hr): Add ADC Hard Stop
3. **Medium-term** (3 hr): Add Emergency Flatten
4. **Long-term** (5 hr): Adaptive exposure & advanced features

**Expected Outcome**:
Zero account blow-ups, max DD capped at 15%, safe crypto trading. 🚀

---

**Status**: 📋 Planned
**Target Version**: v2.5
**Estimated Total Time**: 5-8 hours (spread over 2 days)
**Priority**: 🔥 HIGH (Required for crypto trading)

---

**Good night! Sleep well knowing we have a solid plan! 😴🌙**
