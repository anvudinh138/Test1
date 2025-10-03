# Enhancement: TRM Smart Close on News

**Feature**: Intelligent position closing before news events
**Priority**: 🟡 MEDIUM (User requested, safety feature)
**Status**: 📋 Proposed

---

## Problem Statement

### Current Behavior (TRM v1)

**Option 1**: `InpTrmCloseOnNews = false` (default)
- Tighten SL during news → partial close (profitable positions hit SL first)
- **Problem**: Keeps losing positions → dangerous if news spikes

**Option 2**: `InpTrmCloseOnNews = true`
- Close ALL positions (profitable + losing)
- **Problem**: Loses opportunity if positions are deeply profitable

### User Observation (Real Trading)

**Case** (Image #5, #6):
```
Before news:
- BUY basket: -$8 (loser)
- SELL basket (rescue): -$200 (bigger loser!)
- Net: -$208

TRM action: Close partial (profitable entries)
Result: Keep losing entries → risky
```

**User request**:
> "Close ALL when news, including losing positions"
> "Reason: Net P&L often breakeven or small profit (after sideway accumulation)"

---

## Proposed Solution: TRM Smart Close

### Logic

```cpp
// Smart close decision before news window
if (IsNewsTime()) {
    double net_pnl = buy_pnl + sell_pnl;

    // Strategy 1: Close if breakeven or better
    if (net_pnl >= InpTrmMinPnlToClose) {
        CloseAll("TRM: Safe exit before news");
    }
    // Strategy 2: Close if loss acceptable
    else if (net_pnl > -InpTrmMaxLossToClose) {
        CloseAll("TRM: Accept small loss before news");
    }
    // Strategy 3: Keep if winning big
    else if (net_pnl > InpTrmKeepIfProfitAbove) {
        Log("TRM: Keep positions (profitable)");
        return;
    }
    // Strategy 4: Close if losing too much (force exit)
    else {
        CloseAll("TRM: Force close (prevent bigger loss)");
    }
}
```

### Input Parameters

```cpp
input group "=== TRM Smart Close ==="
input bool   InpTrmSmartClose         = true;   // Enable smart close logic
input double InpTrmMinPnlToClose      = 0.0;    // Close if net PnL >= this (USD)
input double InpTrmMaxLossToClose     = 10.0;   // Close if loss < this (USD)
input double InpTrmKeepIfProfitAbove  = 20.0;   // Keep if profit > this (USD)
input bool   InpTrmForceCloseAll      = false;  // Force close ALL (ignore PnL)
```

### Decision Matrix

| Net P&L | Smart Close | Force Close | Action |
|---------|-------------|-------------|--------|
| +$50 | ON | - | ✅ Close (safe profit) |
| +$5 | ON | - | ✅ Close (breakeven+) |
| -$5 | ON | - | ✅ Close (small loss OK) |
| -$30 | ON | - | ✅ Close (prevent bigger loss) |
| +$50 | OFF | ON | ✅ Close ALL |
| -$50 | OFF | ON | ✅ Close ALL |
| +$50 | OFF | OFF | ⏸️ Keep (tighten SL) |

---

## Implementation Plan

### Files to Modify

1. **`Params.mqh`** (+4 fields)
```cpp
bool   trm_smart_close;
double trm_min_pnl_to_close;
double trm_max_loss_to_close;
double trm_keep_if_profit_above;
bool   trm_force_close_all;
```

2. **`RecoveryGridDirection_v2.mq5`** (+5 inputs)
```cpp
input group "=== TRM Smart Close ==="
input bool   InpTrmSmartClose         = true;
input double InpTrmMinPnlToClose      = 0.0;
input double InpTrmMaxLossToClose     = 10.0;
input double InpTrmKeepIfProfitAbove  = 20.0;
input bool   InpTrmForceCloseAll      = false;
```

3. **`LifecycleController.mqh`** (modify `HandleNewsWindow()`)
```cpp
void HandleNewsWindow() {
    if (!IsNewsTime()) return;

    // Force close (ignore PnL)
    if (m_params.trm_force_close_all) {
        CloseAll("TRM force close");
        return;
    }

    // Smart close (PnL-based decision)
    if (m_params.trm_smart_close) {
        double net_pnl = m_buy.PnL() + m_sell.PnL();

        if (net_pnl >= m_params.trm_min_pnl_to_close) {
            CloseAll("TRM: Safe exit (PnL >= 0)");
        }
        else if (net_pnl > -m_params.trm_max_loss_to_close) {
            CloseAll("TRM: Accept small loss");
        }
        else if (net_pnl > m_params.trm_keep_if_profit_above) {
            Log("[TRM] Keep positions (profitable)");
            return;
        }
        else {
            CloseAll("TRM: Force close (prevent loss)");
        }
        return;
    }

    // Legacy: Close on news (simple)
    if (m_params.trm_close_on_news) {
        CloseAll("TRM close_on_news");
        return;
    }

    // Legacy: Tighten SL
    if (m_params.trm_tighten_sl && m_params.ssl_enabled) {
        Log("[TRM] Tightening SL");
    }
}
```

---

## Configuration Examples

### Example 1: Conservative (Close on Breakeven+)
```properties
InpTrmSmartClose         = true
InpTrmMinPnlToClose      = 0.0   # Close if >= $0 (breakeven or profit)
InpTrmMaxLossToClose     = 5.0   # Close if loss < $5
InpTrmKeepIfProfitAbove  = 50.0  # Keep if profit > $50
InpTrmForceCloseAll      = false

Result: Close unless winning big ($50+)
```

### Example 2: Aggressive (Always Close)
```properties
InpTrmSmartClose         = false
InpTrmForceCloseAll      = true

Result: Close ALL positions, no questions asked
```

### Example 3: Balanced (Accept Small Loss)
```properties
InpTrmSmartClose         = true
InpTrmMinPnlToClose      = 0.0
InpTrmMaxLossToClose     = 20.0  # Accept up to $20 loss
InpTrmKeepIfProfitAbove  = 30.0  # Keep if profit > $30
InpTrmForceCloseAll      = false

Result: Close unless winning $30+ or losing $20+
```

---

## Advantages

1. **Intelligent**: PnL-based decision (not blind close)
2. **Safe**: Locks profit or limits loss before news
3. **Flexible**: User controls thresholds
4. **Backward Compatible**: Legacy options still work

---

## Risks

### Risk 1: Miss News Rally ⚠️ MEDIUM
**Scenario**: Close positions → news goes favorable direction
**Mitigation**: `InpTrmKeepIfProfitAbove` keeps big winners

### Risk 2: Complex Logic 🧩 LOW
**Impact**: More parameters to tune
**Mitigation**: Provide presets (conservative/balanced/aggressive)

---

## Testing Checklist

### Test 1: Close on Breakeven
**Setup**: Net PnL = $0, news in 10 min
**Expected**: ✅ Close ALL (safe exit)

### Test 2: Close on Small Loss
**Setup**: Net PnL = -$8, `MaxLossToClose = $10`, news in 10 min
**Expected**: ✅ Close ALL (accept small loss)

### Test 3: Keep Big Winner
**Setup**: Net PnL = +$60, `KeepIfProfitAbove = $50`
**Expected**: ⏸️ Keep positions (don't interrupt winner)

### Test 4: Force Close Big Loser
**Setup**: Net PnL = -$50, news in 10 min
**Expected**: ✅ Close ALL (prevent bigger loss)

### Test 5: Force Close (Ignore PnL)
**Setup**: `ForceCloseAll = true`, Net PnL = +$100
**Expected**: ✅ Close ALL (forced)

---

## User Scenario (From Image #5, #6)

**Before Enhancement**:
```
Before news:
- Net PnL: -$208
- TRM action: Tighten SL → partial close (keep losers)
- Result: Risky (losers remain during news)
```

**After Enhancement** (Smart Close):
```
Before news:
- Net PnL: -$208
- Check: -$208 < -$10 (max loss) ❌
- Decision: Close ALL (prevent bigger loss)
- Result: Exit with -$208 (acceptable), avoid news spike
```

**Alternative** (Sideway accumulation):
```
Before news:
- Net PnL: +$15 (after sideway trading)
- Check: +$15 >= $0 (min PnL) ✅
- Decision: Close ALL (safe exit)
- Result: Lock $15 profit, avoid news risk
```

---

## Priority

**Recommendation**: 🟡 MEDIUM priority
- **User pain**: High (losing money on news)
- **Implementation**: Medium (2-3 hours)
- **Impact**: High (safety improvement)

**Suggested Timeline**:
1. Fix lot % risk bug (DONE ✅)
2. Fix rescue v3 staged limits (DONE ✅)
3. **Implement TRM Smart Close** ← NEXT
4. Test on demo
5. Deploy to production

---

## Alternative: Quick Fix (5 minutes)

If you want immediate solution without coding:

**Change current settings**:
```properties
InpTrmCloseOnNews = true   # Close ALL on news (simple)
```

**Trade-off**:
- ✅ Fast (no code change)
- ✅ Safe (close ALL)
- ❌ No intelligence (ignores PnL)
- ❌ May close big winners

---

## Summary

**What it does**:
- Smart decision before news: close or keep based on net PnL
- Multiple strategies: breakeven exit, accept small loss, keep big winners

**Why better than current**:
- More intelligent (PnL-aware vs blind close)
- User control (thresholds configurable)
- Safe (prevents news spike damage)

**Ready for**: User approval → Implementation → Testing

---

## User Action Required

**Please confirm**:
1. Do you want **Smart Close** (PnL-based decision)?
   - OR **Force Close** (always close ALL on news)?

2. What thresholds?
   - `MinPnlToClose = $?` (close if >= this)
   - `MaxLossToClose = $?` (accept loss < this)
   - `KeepIfProfitAbove = $?` (keep if profit > this)

3. Priority?
   - 🔴 HIGH (implement now)
   - 🟡 MEDIUM (implement after testing current fixes)
   - 🟢 LOW (nice to have)
