# Adaptive Rescue Lot Implementation

**Version**: 2.5
**Date**: 2025-10-02
**Status**: ✅ Completed & Ready for Testing

---

## Problem Statement

**Issue**: Fixed rescue lot (e.g., `InpRecoveryLot = 0.02`) is ineffective when loser basket has accumulated large position.

**Real Trading Scenario** (XAG/USD Live):
```
Basket A (SELL - Rescue): 0.01-0.02 lot market entry
Basket B (BUY - Loser):   0.08 lot (accumulated from grid scale 1.5)

Problem: A tries to rescue B, but 0.02 lot cannot hedge 0.08 lot effectively
Result: Asymmetric hedge → rescue fails → both baskets lose
```

**Root Cause**: Fixed rescue lot ignores loser's actual position size, creating imbalanced hedge.

---

## Solution: Adaptive Rescue Lot Matching

**New Approach**: Calculate rescue lot dynamically based on loser's total lot size.

**Formula**: `rescue_lot = loser_total_lot × multiplier`

**Safety Caps**:
- `rescue_lot = MIN(rescue_lot, rescue_max_lot)`  // Prevent over-leveraging
- `rescue_lot = MAX(rescue_lot, recovery_lot)`    // Minimum = original fixed lot

**Example**:
```
Loser has 0.08 lot
Multiplier = 1.0 (100% match)
Max cap = 0.50 lot

Calculation:
rescue_lot = 0.08 × 1.0 = 0.08 lot ✅ (within cap)

Result: Symmetric hedge, rescue effective
```

---

## Implementation Details

### 1. Files Modified

#### **src/core/Params.mqh**
```cpp
// Lines 43-45: Added adaptive rescue parameters
bool   rescue_adaptive_lot;       // Enable adaptive lot matching
double rescue_lot_multiplier;     // Scale factor (1.0 = exact match)
double rescue_max_lot;            // Safety cap for adaptive lot
```

#### **src/ea/RecoveryGridDirection_v2.mq5**
```cpp
// Lines 64-66: Added input parameters
input bool   InpRescueAdaptiveLot   = true;   // Match loser's lot size
input double InpRescueLotMultiplier = 1.0;    // 1.0 = exact, 0.8 = 80%
input double InpRescueMaxLot        = 0.50;   // Safety cap

// Lines 207-209: Parameter mapping
g_params.rescue_adaptive_lot      = InpRescueAdaptiveLot;
g_params.rescue_lot_multiplier    = InpRescueLotMultiplier;
g_params.rescue_max_lot           = InpRescueMaxLot;
```

#### **src/core/LifecycleController.mqh**
```cpp
// Lines 763-785: Adaptive rescue logic
if(m_params.rescue_adaptive_lot)
{
   double loser_lot = loser.TotalLot();
   rescue_lot = loser_lot * m_params.rescue_lot_multiplier;

   // Apply safety caps
   if(rescue_lot > m_params.rescue_max_lot)
      rescue_lot = m_params.rescue_max_lot;
   if(rescue_lot < m_params.recovery_lot)
      rescue_lot = m_params.recovery_lot;

   rescue_lot = winner.NormalizeLot(rescue_lot);

   // Log calculation
   m_log.Event(Tag(), StringFormat("[RESCUE-ADAPTIVE] Loser=%.2f lot → Rescue=%.2f lot",
                                   loser_lot, rescue_lot));
}
else
{
   // Fallback to fixed lot
   rescue_lot = winner.NormalizeLot(m_params.recovery_lot);
}
```

---

## Configuration Examples

### 1. Exact Match (100%)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.0
InpRescueMaxLot = 0.50

Example:
Loser: 0.08 lot → Rescue: 0.08 lot (symmetric)
Loser: 0.15 lot → Rescue: 0.15 lot
Loser: 0.80 lot → Rescue: 0.50 lot (capped)
```

### 2. Conservative Match (80%)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 0.8
InpRescueMaxLot = 0.50

Example:
Loser: 0.10 lot → Rescue: 0.08 lot (80%)
Loser: 0.20 lot → Rescue: 0.16 lot (80%)
Loser: 0.80 lot → Rescue: 0.50 lot (capped, not 0.64)
```

### 3. Aggressive Match (120%)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.2
InpRescueMaxLot = 1.00

Example:
Loser: 0.10 lot → Rescue: 0.12 lot (120%)
Loser: 0.20 lot → Rescue: 0.24 lot (120%)
Loser: 0.80 lot → Rescue: 0.96 lot (120%)
Loser: 1.00 lot → Rescue: 1.00 lot (capped at 1.00)
```

### 4. Disabled (Original Fixed Lot)
```properties
InpRescueAdaptiveLot = false
InpRecoveryLot = 0.02

Example:
Loser: 0.08 lot → Rescue: 0.02 lot (fixed)
Loser: 0.20 lot → Rescue: 0.02 lot (fixed)
Loser: 0.80 lot → Rescue: 0.02 lot (fixed - ineffective!)
```

---

## How It Works

### Decision Flow

```
1. Check if rescue needed (DD breach OR price breach)
   ↓
2. If InpRescueAdaptiveLot = true:
   ├─ Get loser's total lot (e.g., 0.08)
   ├─ Calculate: rescue_lot = 0.08 × 1.0 = 0.08
   ├─ Apply max cap: MIN(0.08, 0.50) = 0.08
   ├─ Apply min floor: MAX(0.08, 0.02) = 0.08
   └─ Normalize to broker step: 0.08 → 0.08
   ↓
3. Else (disabled):
   └─ Use fixed lot: 0.02
   ↓
4. Deploy rescue with calculated lot
```

### Log Output Example

```
[RGDv2][XAGUSD] [RESCUE-ADAPTIVE] Loser=0.08 lot → Rescue=0.08 lot (mult=1.00, cap=0.50)
[RGDv2][XAGUSD] Rescue deployed
```

---

## Integration with Linear Lot Scaling

**Synergy**: Adaptive rescue works perfectly with linear lot scaling.

**Example Scenario**:
```
Grid Configuration:
InpLotBase = 0.01
InpLotOffset = 0.01

Grid Progression (Loser):
Level 0: 0.01 lot
Level 1: 0.02 lot
Level 2: 0.03 lot
Level 3: 0.04 lot
Total: 0.10 lot

Adaptive Rescue (Winner):
Loser total = 0.10 lot
Rescue lot = 0.10 × 1.0 = 0.10 lot ✅ (balanced hedge)

Result: Price moves against rescue → Loser profits ≈ Rescue loss (symmetric)
        Price moves with rescue → Rescue profits pull loser's TP closer
```

**Previous Exponential Scaling Issue**:
```
Grid Configuration:
InpLotBase = 0.01
InpLotScale = 1.5 (exponential)

Grid Progression (Loser):
Level 0: 0.01 lot
Level 1: 0.015 lot
Level 2: 0.023 lot
Level 3: 0.034 lot
Total: 0.082 lot

Fixed Rescue (Winner):
Rescue lot = 0.02 lot ❌ (asymmetric, ineffective)
```

---

## Safety Features

### 1. Hard Cap (`rescue_max_lot`)
**Purpose**: Prevent over-leveraging during extreme drawdowns.

**Example**:
```
Loser: 2.00 lot (huge accumulated position)
Multiplier: 1.0
Max cap: 0.50 lot

Result: Rescue = 0.50 lot (not 2.00) → Prevents margin blow-up
```

### 2. Minimum Floor (`recovery_lot`)
**Purpose**: Ensure minimum hedge size even for small loser positions.

**Example**:
```
Loser: 0.01 lot (just started)
Multiplier: 1.0
Min floor: 0.02 lot

Result: Rescue = 0.02 lot (not 0.01) → Effective initial hedge
```

### 3. Exposure Cap Integration
**Still Enforced**: Global `InpExposureCapLots` applies to adaptive rescue lot.

**Example**:
```
InpExposureCapLots = 2.0
Current exposure: 1.85 lot
Adaptive rescue: 0.30 lot
Total would be: 2.15 lot ❌

Result: Rescue blocked, logged as "Exposure cap blocks rescue"
```

---

## Testing Strategy

### Test Case 1: Small Loser Position
```
Loser: 0.03 lot
Expected: Rescue = 0.03 lot (if mult=1.0, cap=0.50)
Verify: Log shows correct calculation
```

### Test Case 2: Medium Loser Position
```
Loser: 0.15 lot
Expected: Rescue = 0.15 lot
Verify: Symmetric hedge, rescue effective
```

### Test Case 3: Large Loser Position (Cap Triggered)
```
Loser: 0.80 lot
Expected: Rescue = 0.50 lot (capped)
Verify: Log shows cap applied
```

### Test Case 4: Disabled Mode
```
InpRescueAdaptiveLot = false
Loser: 0.20 lot
Expected: Rescue = 0.02 lot (fixed)
Verify: Original behavior preserved
```

### Test Case 5: Exposure Cap Block
```
Current exposure: 1.90 lot
Loser: 0.20 lot
Adaptive rescue: 0.20 lot
Exposure cap: 2.00 lot
Expected: Rescue blocked (1.90 + 0.20 > 2.00)
Verify: Log shows "Exposure cap blocks rescue"
```

---

## Recommended Settings

### Conservative (Low Risk)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 0.8     # 80% of loser
InpRescueMaxLot = 0.30           # Low cap
InpRecoveryLot = 0.01            # Small floor
InpExposureCapLots = 1.00        # Tight exposure limit
```

### Balanced (Medium Risk)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.0     # 100% match
InpRescueMaxLot = 0.50           # Medium cap
InpRecoveryLot = 0.02            # Standard floor
InpExposureCapLots = 2.00        # Moderate exposure
```

### Aggressive (High Risk)
```properties
InpRescueAdaptiveLot = true
InpRescueLotMultiplier = 1.2     # 120% of loser
InpRescueMaxLot = 1.00           # High cap
InpRecoveryLot = 0.05            # Large floor
InpExposureCapLots = 5.00        # Loose exposure limit
```

---

## Performance Impact

**Expected Improvement**:
- ✅ Better DD recovery (symmetric hedge)
- ✅ Reduced max DD (rescue more effective)
- ✅ Faster basket flip (loser reaches TP sooner)
- ✅ Lower exposure waste (no under-hedging)

**Trade-offs**:
- ⚠️ Higher rescue lot → higher margin usage
- ⚠️ Max cap may still be insufficient for extreme DDs
- ⚠️ Requires careful `rescue_max_lot` tuning per account size

---

## Troubleshooting

### Issue: Rescue lot too small
**Symptom**: Log shows `Rescue=0.02 lot` when loser has 0.20 lot

**Solution**:
1. Check `InpRescueAdaptiveLot = true`
2. Increase `InpRescueLotMultiplier` to 1.0 or higher
3. Verify `InpRescueMaxLot` not too low

### Issue: Rescue lot capped unexpectedly
**Symptom**: Log shows `Rescue=0.50 lot` when calculation was 0.80 lot

**Solution**:
1. Check `InpRescueMaxLot` setting (may be too low)
2. Increase cap if account margin allows
3. Verify global `InpExposureCapLots` not blocking

### Issue: Rescue blocked by exposure cap
**Symptom**: Log shows "Exposure cap blocks rescue"

**Solution**:
1. Increase `InpExposureCapLots`
2. Reduce `InpRescueLotMultiplier` to lower rescue size
3. Enable Partial Close to reduce loser's lot before rescue

---

## Known Limitations

1. **Cap May Be Insufficient**: If loser has 2.00 lot but cap is 0.50, rescue still asymmetric
2. **Margin Requirements**: Adaptive lot increases margin usage dynamically
3. **Slippage Impact**: Large rescue lot may face more slippage on thin markets
4. **Not PnL-Based**: Uses lot size, not actual USD loss (could be added in future)

---

## Future Enhancements

### Idea 1: PnL-Based Matching
```cpp
// Calculate rescue lot from loser's actual USD loss
double loser_loss = -loser.BasketPnL();  // e.g., -50 USD
double price_per_lot = ...;              // Calculate from symbol point value
rescue_lot = loser_loss / price_per_lot; // Match USD exposure
```

### Idea 2: Dynamic Cap Based on Equity
```cpp
// Adjust max cap based on current equity
double equity = AccountInfoDouble(ACCOUNT_EQUITY);
rescue_max_lot = equity * 0.001;  // 0.1% of equity per rescue
```

### Idea 3: Multi-Level Adaptive Rescue
```cpp
// Deploy multiple rescue orders with scaled lots
Level 0: 50% of loser lot (market)
Level 1: 30% of loser lot (limit +1000 points)
Level 2: 20% of loser lot (limit +2000 points)
```

---

## Related Features

- **Linear Lot Scaling**: Works together to keep all lot sizes predictable
- **Exposure Cap**: Global safety limit applies to adaptive rescue
- **Partial Close**: Reduces loser's lot before rescue, lowering adaptive rescue size
- **Dynamic Target Scaling**: TP adjustment after rescue profit

---

## Checklist for New Users

- [x] Enable `InpRescueAdaptiveLot = true`
- [x] Set `InpRescueLotMultiplier = 1.0` (start with 100% match)
- [x] Set `InpRescueMaxLot` based on account size (e.g., 0.50 for $1000 account)
- [x] Keep `InpRecoveryLot` as minimum floor (e.g., 0.02)
- [x] Adjust `InpExposureCapLots` to allow adaptive lot
- [x] Test on demo account with various scenarios
- [x] Monitor logs for `[RESCUE-ADAPTIVE]` messages
- [x] Verify rescue effectiveness in drawdown situations

---

## Version History

- **v2.5** (2025-10-02): Implemented adaptive rescue lot with multiplier and caps
- **v2.4**: (Previous) Used fixed `InpRecoveryLot` only
