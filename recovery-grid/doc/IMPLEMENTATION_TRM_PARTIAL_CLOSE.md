# Implementation: TRM Partial Close (Simple & Smart)

**Feature**: Per-order partial close with SL protection before news
**Branch**: `feature/lot-percent-risk`
**Version**: 2.9
**Status**: ✅ Implemented

---

## Overview

**TRM Partial Close** implements a simple "cầu may" (hope for luck) strategy before news events:
- Close big winners/losers
- Keep small positions near breakeven
- Set protective SL on kept positions
- Hope for breakeven or multiplication during news

---

## User Request (Simplified)

> "Mỗi lần news tới, giữ lại những lệnh lãi dưới $3 đặt SL ở breakeven, giữ lại những lệnh lỗ trên -$3 đặt SL ở -$6. Mình muốn cầu may: 1 là hoà vốn, 2 là lãi nhân lần."

**Example**: 4 orders with PnL: $6, $2, -$5, -$1
- **Close**: $6 (profit > $3), -$5 (loss < -$3)
- **Keep**: $2 (profit < $3, SL breakeven), -$1 (loss > -$3, SL -$6)

---

## Logic (Simple Decision Tree)

```
For each position:

IF PnL > $3:
    → Close (lock big profit)

ELSE IF PnL < -$3:
    → Close (cut big loss)

ELSE IF 0 <= PnL <= $3:
    → Keep + Set SL = entry_price (breakeven protection)

ELSE IF -$3 <= PnL < 0:
    → Keep + Set SL = entry_price ± $6 (loss protection)
```

---

## Input Parameters (Only 3!)

```cpp
input group "=== TRM Partial Close (Simple & Smart) ==="
input bool   InpTrmPartialCloseEnabled = false;  // Master switch
input double InpTrmCloseThreshold      = 3.0;    // Close if |PnL| > this (USD)
input double InpTrmKeepSLDistance      = 6.0;    // SL distance for kept losing orders (USD)
```

**Parameters**:
1. **InpTrmPartialCloseEnabled**: Enable/disable feature
2. **InpTrmCloseThreshold**: Close threshold ($3 = close if profit/loss > $3)
3. **InpTrmKeepSLDistance**: SL distance for kept losers ($6 = max loss allowed)

---

## Decision Matrix

| PnL | Threshold | Action | SL |
|-----|-----------|--------|-----|
| +$6 | $3 | ✅ Close | - |
| +$2 | $3 | ⏸️ Keep | Breakeven (entry price) |
| +$0.5 | $3 | ⏸️ Keep | Breakeven (entry price) |
| -$1 | $3 | ⏸️ Keep | Entry ± $6 distance |
| -$2.5 | $3 | ⏸️ Keep | Entry ± $6 distance |
| -$5 | $3 | ✅ Close | - |

---

## Example Scenarios

### Scenario 1: Mixed Positions

**Before News**:
```
Position #1: BUY 0.01 @ 1.18000, PnL = +$6.00
Position #2: BUY 0.01 @ 1.17900, PnL = +$2.00
Position #3: SELL 0.01 @ 1.17800, PnL = -$1.00
Position #4: SELL 0.01 @ 1.17700, PnL = -$5.00
```

**TRM Partial Close Action** (threshold = $3):
1. Position #1: PnL = +$6 > $3 → **Close** (lock profit)
2. Position #2: PnL = +$2 < $3 → **Keep**, SL = 1.17900 (breakeven)
3. Position #3: PnL = -$1 > -$3 → **Keep**, SL = 1.17800 + $6 distance
4. Position #4: PnL = -$5 < -$3 → **Close** (cut loss)

**After News**:
```
Closed: #1 (+$6), #4 (-$5)
Kept: #2 (+$2, SL breakeven), #3 (-$1, SL -$6)
Net result: +$6 - $5 = +$1 (locked)
Remaining positions: 2 (with SL protection)
```

**Possible Outcomes**:
- ✅ **Best case**: News goes favorable → Kept positions profit → Total +$10+
- ✅ **Good case**: Kept positions hit breakeven → Total +$1
- ⚠️ **Worst case**: Kept positions hit SL → Total +$1 - $6 - $6 = -$11

---

### Scenario 2: User's Real Case (From Backtest)

**Before News**:
```
BUY basket: -$8 (primary loser)
SELL basket (rescue): -$200 (bigger loser)
Net PnL: -$208

Individual positions (example):
- SELL #1: -$84.70
- SELL #2: -$83.10
- SELL #3: -$32.20
- BUY #1: -$8.49
```

**TRM Partial Close Action** (threshold = $3):
- SELL #1: -$84.70 < -$3 → **Close** (cut big loss)
- SELL #2: -$83.10 < -$3 → **Close** (cut big loss)
- SELL #3: -$32.20 < -$3 → **Close** (cut big loss)
- BUY #1: -$8.49 < -$3 → **Close** (cut big loss)

**Result**: All positions closed (all exceed -$3 threshold)

**Better Threshold**: Set `InpTrmCloseThreshold = 50.0` to keep more positions:
- SELL #3: -$32.20 > -$50 → **Keep**, SL = entry ± $6
- BUY #1: -$8.49 > -$50 → **Keep**, SL = entry ± $6
- Others: **Close**

---

## Configuration Examples

### Example 1: Conservative (Tight Threshold)

```properties
InpTrmPartialCloseEnabled = true
InpTrmCloseThreshold      = 3.0   # Close if |PnL| > $3
InpTrmKeepSLDistance      = 6.0   # SL at -$6 for kept losers

Behavior:
- Close most positions (tight threshold)
- Keep only small positions near breakeven
- Low risk (max loss = $6 per kept position)
```

### Example 2: Aggressive (Loose Threshold)

```properties
InpTrmPartialCloseEnabled = true
InpTrmCloseThreshold      = 10.0  # Close if |PnL| > $10
InpTrmKeepSLDistance      = 20.0  # SL at -$20 for kept losers

Behavior:
- Keep more positions (loose threshold)
- Higher "cầu may" potential
- Higher risk (max loss = $20 per kept position)
```

### Example 3: Recommended (Balanced)

```properties
InpTrmPartialCloseEnabled = true
InpTrmCloseThreshold      = 5.0   # Close if |PnL| > $5
InpTrmKeepSLDistance      = 10.0  # SL at -$10 for kept losers

Behavior:
- Balanced risk/reward
- Keep moderate positions
- Acceptable max loss ($10 per position)
```

---

## Implementation Details

### Files Modified

1. **`RecoveryGridDirection_v2.mq5`** (+3 inputs)
   ```cpp
   input bool   InpTrmPartialCloseEnabled;
   input double InpTrmCloseThreshold;
   input double InpTrmKeepSLDistance;
   ```

2. **`Params.mqh`** (+3 fields)
   ```cpp
   bool   trm_partial_close_enabled;
   double trm_close_threshold;
   double trm_keep_sl_distance;
   ```

3. **`LifecycleController.mqh`** (+100 lines)
   - New function: `TrmPartialClose()`
   - Per-order loop and decision logic
   - SL calculation from USD distance

4. **`OrderExecutor.mqh`** (+11 lines)
   - New method: `ModifyPosition(ticket, sl, tp)`

---

## SL Calculation (Technical Details)

### Breakeven SL (for small profits)
```cpp
sl_price = entry_price;  // Simple!
```

### USD Distance SL (for small losses)
```cpp
// Calculate point value
point_value = (tick_value / tick_size) × point

// Calculate SL distance in points
sl_distance_points = usd_distance / (point_value × lot_size)

// Calculate SL price
if (BUY):
    sl_price = entry_price - sl_distance_points × point
else (SELL):
    sl_price = entry_price + sl_distance_points × point
```

**Example** (EURUSD, 0.01 lot, -$6 distance):
```
point_value = ($1 / 0.00001) × 0.00001 = $1 per point
sl_distance_points = $6 / ($1 × 0.01) = 600 points = 60 pips
BUY @ 1.18000 → SL = 1.18000 - 0.00600 = 1.17400
```

---

## Advantages vs Smart Close

### Smart Close (Old, Complex)
- ❌ 7 parameters (complex)
- ❌ Net PnL only (basket-level)
- ❌ Close ALL or Keep ALL
- ❌ No per-order control

### Partial Close (New, Simple)
- ✅ 3 parameters (simple)
- ✅ Per-order PnL (position-level)
- ✅ Selective close (keep some, close others)
- ✅ SL protection on kept positions
- ✅ "Cầu may" strategy (hope for breakeven/profit)

---

## Testing Checklist

### Test 1: Close Big Winner ✅
**Setup**: Position PnL = +$6, threshold = $3
**Expected**: ✅ Close position, log "Closed (profit $6.00 > $3.00)"

### Test 2: Keep Small Winner + Breakeven SL ✅
**Setup**: Position PnL = +$2, threshold = $3
**Expected**: ⏸️ Keep position, SL = entry_price, log "Keep (PnL=$2.00) SL=..."

### Test 3: Close Big Loser ✅
**Setup**: Position PnL = -$5, threshold = $3
**Expected**: ✅ Close position, log "Closed (loss $-5.00 < -$3.00)"

### Test 4: Keep Small Loser + USD SL ✅
**Setup**: Position PnL = -$1, threshold = $3, SL distance = $6
**Expected**: ⏸️ Keep position, SL = entry ± $6 distance, log "Keep (PnL=-$1.00) SL=..."

### Test 5: Mixed Scenario ✅
**Setup**: 4 positions ($6, $2, -$1, -$5), threshold = $3
**Expected**:
- ✅ Close 2 positions ($6, -$5)
- ⏸️ Keep 2 positions ($2, -$1) with SL
- ✅ Summary log: "Closed=2, Kept+SL=2"

---

## Known Limitations

1. **No Per-Basket Awareness**: Closes positions individually, ignores basket structure
   - May break basket balance (BUY vs SELL ratio)
   - Future: Add basket-aware logic

2. **Static USD Thresholds**: Not % of balance
   - $3 threshold fixed regardless of account size
   - Future: Add % mode

3. **No News Impact Prediction**: Blindly keeps positions
   - Doesn't know if news will be favorable
   - User takes full risk ("cầu may")

4. **SL May Hit During News Spike**: Volatile news can hit all SLs
   - All kept positions may close at -$6 each
   - Total loss can exceed expectations

---

## Risk Warning

**This is a "cầu may" (gambling) strategy!**

**Best Case**: News goes your way → Kept positions profit → Big win

**Worst Case**: News goes against you → All SLs hit → Max loss

**Example** (10 kept positions, $6 SL each):
- Max loss = 10 × $6 = $60 (if all SLs hit)
- User accepts this risk for chance of big win

**Recommendation**:
- Use tight threshold ($3-$5) to keep few positions
- Use small SL distance ($6-$10) to limit max loss
- Monitor during news (manual intervention if needed)

---

## Migration from Smart Close

### Old Config (Smart Close - Removed)
```properties
InpTrmSmartCloseEnabled = true
InpTrmCloseStrategy = BREAKEVEN
InpTrmAcceptLoss = true
InpTrmMaxLossToClose = 10.0
InpTrmKeepIfProfitAbove = 3.0
# 5+ parameters, complex logic
```

### New Config (Partial Close - Simplified)
```properties
InpTrmPartialCloseEnabled = true
InpTrmCloseThreshold = 3.0
InpTrmKeepSLDistance = 6.0
# Only 3 parameters, simple logic
```

**Why Better**:
- ✅ Simpler (3 params vs 5+)
- ✅ Per-order control (not just net PnL)
- ✅ SL protection (automatic risk management)
- ✅ User's requested strategy ("cầu may")

---

## Commit Message

```
feat: Add TRM Partial Close (simple per-order strategy)

USER REQUEST: "Cầu may" strategy - keep positions near breakeven with SL protection

LOGIC:
- Close if PnL > threshold (lock big profit/loss)
- Keep if |PnL| <= threshold (hope for recovery)
- Set SL: breakeven (if profit) or -$6 distance (if loss)

PARAMETERS (only 3!):
- InpTrmPartialCloseEnabled (bool, default OFF)
- InpTrmCloseThreshold (double, $3.0)
- InpTrmKeepSLDistance (double, $6.0)

EXAMPLE: 4 orders ($6, $2, -$1, -$5)
- Close: $6, -$5 (exceed $3 threshold)
- Keep: $2 (SL breakeven), -$1 (SL -$6)

ADVANTAGES:
- Simple (3 params vs old Smart Close 7 params)
- Per-order control (not basket-level)
- SL protection (automatic risk management)
- User's "cầu may" strategy

FILES:
- src/ea/RecoveryGridDirection_v2.mq5 (+3 inputs)
- src/core/Params.mqh (+3 fields)
- src/core/LifecycleController.mqh (TrmPartialClose function)
- src/core/OrderExecutor.mqh (ModifyPosition method)
- doc/IMPLEMENTATION_TRM_PARTIAL_CLOSE.md (new)

REPLACES: TRM Smart Close (too complex, removed)
```

---

## Recommended Settings (For User)

Based on user's request and backtest scenario:

```properties
InpTrmPartialCloseEnabled = true
InpTrmCloseThreshold      = 3.0   # As requested
InpTrmKeepSLDistance      = 6.0   # As requested
```

**Expected Behavior**:
- Close all positions with |PnL| > $3
- Keep positions near breakeven with SL protection
- Hope for: (1) breakeven or (2) profit multiplication
- Accept risk: Max loss = $6 per kept position

---

## References

- User Request: Chat 2025-10-03 ("cầu may" strategy)
- Previous Implementation: IMPLEMENTATION_TRM_SMART_CLOSE.md (replaced)
- OrderExecutor: [OrderExecutor.mqh](../src/core/OrderExecutor.mqh)
