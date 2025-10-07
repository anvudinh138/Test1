# Implementation: Lot % Risk (Auto Lot Sizing)

**Feature**: Automatic lot size calculation based on percentage of account balance
**Branch**: `feature/lot-percent-risk`
**Version**: 2.8
**Status**: ✅ Implemented, pending testing

---

## Overview

The **Lot % Risk** feature allows the EA to automatically calculate position sizes based on a percentage of the account balance, rather than using fixed lot sizes. This enables better risk management and position sizing that scales with account growth.

## Problem Statement

**Issue**: Fixed lot sizing doesn't scale with account balance changes.

- Small accounts risk too much with fixed lots
- Large accounts risk too little with fixed lots
- Manual recalculation required after profits/losses

**Solution**: Calculate lot size dynamically based on:
- Account balance × risk percentage
- Grid spacing (as risk distance)
- Symbol tick value and tick size

---

## Implementation Details

### Files Modified

1. **`src/core/Params.mqh`** (+3 fields)
   - Added `lot_percent_enabled` (bool)
   - Added `lot_percent_risk` (double, % of balance)
   - Added `lot_percent_max_lot` (double, safety cap)

2. **`src/ea/RecoveryGridDirection_v2.mq5`** (+7 lines)
   - Added input group "Lot % Risk (Auto Lot Sizing)"
   - Added 3 input parameters
   - Mapped inputs to `g_params` struct

3. **`src/core/GridBasket.mqh`** (+38 lines)
   - Modified `LevelLot()` function
   - Added lot % risk calculation logic
   - Preserved original linear lot scaling when disabled

### Input Parameters

```cpp
input group "=== Lot % Risk (Auto Lot Sizing) ==="
input bool   InpLotPercentEnabled = false;  // ✅ Enable lot % risk calculation
input double InpLotPercentRisk    = 1.0;    // % of account balance to risk per level
input double InpLotPercentMaxLot  = 1.0;    // Max lot size cap for % risk
```

### Calculation Formula

```
risk_amount = balance × (lot_percent_risk / 100)
spacing_ticks = spacing_points / (tick_size / _Point)
lot_size = risk_amount / (tick_value × spacing_ticks)

// Apply max lot cap
if (lot_size > lot_percent_max_lot)
    lot_size = lot_percent_max_lot
```

**Example** (EURUSD, $10,000 balance, 1% risk, 50 points spacing):
```
risk_amount = 10000 × 0.01 = $100
spacing_ticks = 50 / (0.00001 / 0.00001) = 50 ticks
tick_value = $1 (standard for EURUSD)
lot_size = 100 / (1 × 50) = 2.0 lots

// If max_lot = 1.0 → final lot = 1.0 (capped)
```

---

## Usage Guide

### Enable Lot % Risk

1. Set `InpLotPercentEnabled = true`
2. Set `InpLotPercentRisk = 1.0` (1% of balance per level)
3. Set `InpLotPercentMaxLot = 1.0` (safety cap)

### Disable Lot % Risk (Use Fixed Lots)

1. Set `InpLotPercentEnabled = false`
2. EA will use `InpLotBase` + `InpLotOffset` (linear scaling)

### Recommended Settings

**Conservative** (1% risk):
```
InpLotPercentEnabled = true
InpLotPercentRisk    = 1.0
InpLotPercentMaxLot  = 0.5
```

**Moderate** (2% risk):
```
InpLotPercentEnabled = true
InpLotPercentRisk    = 2.0
InpLotPercentMaxLot  = 1.0
```

**Aggressive** (3% risk):
```
InpLotPercentEnabled = true
InpLotPercentRisk    = 3.0
InpLotPercentMaxLot  = 2.0
```

---

## Safety Features

1. **Enable/Disable Flag**: `InpLotPercentEnabled` (default OFF)
   - Allows users to opt-in when ready
   - Preserves original behavior when disabled

2. **Max Lot Cap**: `InpLotPercentMaxLot`
   - Prevents excessive lot sizes
   - Safety guard against calculation errors

3. **Fallback**: If calculation fails (invalid tick values)
   - Falls back to `lot_base` (safe default)
   - Logs error for troubleshooting

4. **Volume Normalization**: `NormalizeVolumeValue()`
   - Respects broker's lot step size
   - Ensures valid lot sizes

---

## Testing Checklist

### Unit Tests

- [ ] Enable lot % risk with 1% risk, verify lot calculation
- [ ] Disable lot % risk, verify linear scaling works
- [ ] Test with different account balances ($1k, $10k, $100k)
- [ ] Test max lot cap (risk > max lot)
- [ ] Test fallback (invalid tick values)

### Integration Tests

- [ ] Run backtest with lot % risk enabled
- [ ] Verify lot sizes scale with balance changes
- [ ] Verify max lot cap is respected
- [ ] Check logs for calculation errors

### Edge Cases

- [ ] Zero balance (should use lot_base)
- [ ] Very small balance ($100)
- [ ] Very large balance ($1M)
- [ ] Zero spacing (should use lot_base)
- [ ] Invalid symbol info (should use lot_base)

---

## Known Limitations

1. **Grid Spacing Dependency**: Lot size depends on current grid spacing
   - ATR/HYBRID modes → lot size varies with volatility
   - PIPS mode → consistent lot sizing

2. **No Per-Level Scaling**: All grid levels use same lot size
   - `InpLotOffset` is ignored when lot % risk is enabled
   - Consider adding per-level risk multiplier in future

3. **Balance-Based Only**: Uses `ACCOUNT_BALANCE`, not `ACCOUNT_EQUITY`
   - Unrealized PnL doesn't affect lot sizing
   - Consider using equity in future version

---

## Migration Notes

### Upgrading from v2.7

1. New input parameters added (default OFF, safe)
2. No breaking changes to existing code
3. Can enable feature via inputs (no recompile needed)

### Downgrading to v2.7

1. Remove lot % risk inputs from EA
2. Remove 3 fields from `SParams` struct
3. Revert `LevelLot()` function in `GridBasket.mqh`

---

## Future Enhancements

1. **Equity-Based Risk**: Use `ACCOUNT_EQUITY` instead of `ACCOUNT_BALANCE`
2. **Per-Level Risk Multiplier**: Increase/decrease risk per grid level
3. **Risk Per Trade vs Per Level**: Option to risk % per trade (not per level)
4. **Dynamic Risk Adjustment**: Reduce risk during drawdown (ADC integration)

---

## Commit Message

```
feat: Add Lot % Risk (Auto Lot Sizing) with enable/disable flag

- Add lot % risk calculation based on account balance
- Calculate lot size using: balance × risk% / (tick_value × spacing_ticks)
- Add max lot cap for safety
- Preserve original linear lot scaling when disabled
- Default OFF (opt-in feature)

Files:
- src/core/Params.mqh (+3 fields)
- src/ea/RecoveryGridDirection_v2.mq5 (+7 lines)
- src/core/GridBasket.mqh (+38 lines)
- doc/IMPLEMENTATION_LOT_PERCENT_RISK.md (new)
```

---

## References

- Risk Management: [STRATEGY_SPEC.md](STRATEGY_SPEC.md)
- GridBasket Module: [ARCHITECTURE.md](ARCHITECTURE.md)
- Testing Guide: [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)
