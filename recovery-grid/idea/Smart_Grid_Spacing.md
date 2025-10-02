# Smart Grid Spacing (SGS) - Feature Specification

## Problem Statement

### Current Behavior (Fixed/Hybrid Spacing)
```cpp
// SPACING_PIPS: Always 25 pips
// SPACING_ATR: Always ATR × 0.6
// SPACING_HYBRID: max(25, ATR × 0.6)
```

**Issues**:
1. **No trend/range awareness**:
   - Trending: Gets filled too early → whipsaw losses
   - Ranging: Misses bounce opportunities with wide spacing

2. **Static multiplier**:
   - Same `atr_mult = 0.6` in all market conditions
   - No adaptation to volatility clustering

3. **Premature grid fills**:
   - Strong trend blows through tight grid levels
   - Results in deep DD before reversal

### Evidence
- Set 7: High whipsaw during trending periods
- Grid fills quickly then reverses → unrealized DD spikes
- Range-bound periods: Could catch more bounces with tighter spacing

---

## Proposed Solution: Smart Grid Spacing (SGS)

### Core Concept
**Adaptive spacing multiplier** based on:
1. **Trend/Range regime** (recent price behavior)
2. **Volatility clustering** (ATR acceleration)

### Detection Logic

#### 1. Trend/Range Detection
Use **ATR-normalized range ratio**:

```cpp
// Measure recent vs long-term range
double recent_high = iHigh(symbol, tf, iHighest(symbol, tf, MODE_HIGH, 20, 0));
double recent_low = iLow(symbol, tf, iLowest(symbol, tf, MODE_LOW, 20, 0));
double recent_range = recent_high - recent_low;

double long_high = iHigh(symbol, tf, iHighest(symbol, tf, MODE_HIGH, 100, 0));
double long_low = iLow(symbol, tf, iLowest(symbol, tf, MODE_LOW, 100, 0));
double long_range = long_high - long_low;

double range_ratio = recent_range / long_range;
```

**Interpretation**:
- `range_ratio < 0.3`: **RANGING** (tight recent range)
- `range_ratio > 0.6`: **TRENDING** (wide recent range)
- `0.3 - 0.6`: **NORMAL**

#### 2. Volatility Acceleration
```cpp
double atr_current = FetchATR();
double atr_ma = iMA(atr_handle, 0, 20, 0, MODE_SMA, PRICE_TYPICAL);
double atr_accel = atr_current / atr_ma;
```

**Interpretation**:
- `atr_accel > 1.3`: **HIGH volatility cluster** → Widen spacing
- `atr_accel < 0.8`: **LOW volatility** → Tighten spacing

### Adaptive Spacing Formula

```cpp
double CalculateAdaptiveSpacing()
{
    double base_mult = m_atr_mult;  // e.g., 0.6
    double spacing_mult = base_mult;

    // === Factor 1: Trend/Range Regime ===
    double range_ratio = CalculateRangeRatio();

    if (range_ratio < 0.3) {
        // RANGING: Tighten spacing (more entries, catch bounces)
        spacing_mult *= 0.75;  // 25% tighter
    }
    else if (range_ratio > 0.6) {
        // TRENDING: Widen spacing (fewer entries, avoid whipsaw)
        spacing_mult *= 1.4;   // 40% wider
    }
    // else NORMAL: keep base_mult

    // === Factor 2: Volatility Acceleration ===
    double atr_accel = CalculateAtrAcceleration();

    if (atr_accel > 1.3) {
        // HIGH vol cluster: Widen further
        spacing_mult *= 1.2;
    }
    else if (atr_accel < 0.8) {
        // LOW vol: Tighten
        spacing_mult *= 0.9;
    }

    // === Bounds ===
    spacing_mult = MathMax(spacing_mult, min_mult);  // e.g., 0.4
    spacing_mult = MathMin(spacing_mult, max_mult);  // e.g., 1.2

    return spacing_mult;
}
```

### Modified SpacingPips()

```cpp
double SpacingPips()
{
    datetime now = TimeCurrent();
    if (now == m_cache_time && m_cache_value > 0.0)
        return m_cache_value;

    double result = m_fixed_pips;

    if (m_mode == SPACING_ATR || m_mode == SPACING_HYBRID)
    {
        double atr_points = FetchATR();
        double pip_points = PipPoints(m_symbol);

        if (atr_points > 0.0) m_last_atr_points = atr_points;

        if (pip_points > 0.0)
        {
            double atr_pips = atr_points / pip_points;

            // === SGS: Adaptive multiplier ===
            double effective_mult = m_atr_mult;
            if (m_sgs_enabled) {
                effective_mult = CalculateAdaptiveSpacing();
            }

            double atr_spacing = MathMax(m_min_pips, atr_pips * effective_mult);

            if (m_mode == SPACING_ATR)
                result = atr_spacing;
            else
                result = MathMax(m_fixed_pips, atr_spacing);
        }
    }

    result = MathMax(result, m_min_pips);
    m_cache_time = now;
    m_cache_value = result;
    return result;
}
```

---

## Implementation Plan

### 1. Input Parameters
**File**: `RecoveryGridDirection_v2.mq5`

```cpp
input group "=== Smart Grid Spacing (SGS) ==="
input bool   InpSgsEnabled = true;          // Enable smart grid spacing
input int    InpSgsRecentBars = 20;         // Recent range bars
input int    InpSgsLongBars = 100;          // Long-term range bars
input double InpSgsRangingThreshold = 0.3;  // Range ratio < this = RANGING
input double InpSgsTrendingThreshold = 0.6; // Range ratio > this = TRENDING
input double InpSgsRangingMult = 0.75;      // Spacing mult in RANGING (tighter)
input double InpSgsTrendingMult = 1.4;      // Spacing mult in TRENDING (wider)
input int    InpSgsAtrMaPeriod = 20;        // ATR MA period for acceleration
input double InpSgsMinMult = 0.4;           // Min spacing multiplier
input double InpSgsMaxMult = 1.2;           // Max spacing multiplier
```

### 2. Params Fields
**File**: `Params.mqh`

```cpp
// smart grid spacing (SGS)
bool   sgs_enabled;              // enable smart grid spacing
int    sgs_recent_bars;          // recent range lookback
int    sgs_long_bars;            // long-term range lookback
double sgs_ranging_threshold;    // range ratio threshold for RANGING
double sgs_trending_threshold;   // range ratio threshold for TRENDING
double sgs_ranging_mult;         // spacing multiplier in RANGING
double sgs_trending_mult;        // spacing multiplier in TRENDING
int    sgs_atr_ma_period;        // ATR MA period
double sgs_min_mult;             // minimum multiplier
double sgs_max_mult;             // maximum multiplier
```

### 3. SpacingEngine Modifications
**File**: `SpacingEngine.mqh`

**Add private members**:
```cpp
// SGS state
bool   m_sgs_enabled;
int    m_sgs_recent_bars;
int    m_sgs_long_bars;
double m_sgs_ranging_threshold;
double m_sgs_trending_threshold;
double m_sgs_ranging_mult;
double m_sgs_trending_mult;
int    m_sgs_atr_ma_period;
double m_sgs_min_mult;
double m_sgs_max_mult;
ENUM_TIMEFRAMES m_sgs_tf;  // Use same TF as ATR
```

**Add helper methods**:
```cpp
double CalculateRangeRatio();
double CalculateAtrAcceleration();
double CalculateAdaptiveSpacing();
```

**Modify constructor** to accept SGS params

**Modify `SpacingPips()`** to use adaptive multiplier when enabled

---

## Examples

### Example 1: Ranging Market
```
Recent range (20 bars): 50 pips
Long range (100 bars): 200 pips
range_ratio = 50 / 200 = 0.25 < 0.3 → RANGING

Base mult: 0.6
Regime mult: 0.6 × 0.75 = 0.45 (tighter)
ATR accel: 0.9 (low vol)
Final mult: 0.45 × 0.9 = 0.405

ATR = 30 pips
Spacing = 30 × 0.405 = 12.15 pips (vs 18 pips original)

Result: TIGHTER spacing → catch more bounces ✅
```

### Example 2: Strong Trend
```
Recent range (20 bars): 150 pips
Long range (100 bars): 200 pips
range_ratio = 150 / 200 = 0.75 > 0.6 → TRENDING

Base mult: 0.6
Regime mult: 0.6 × 1.4 = 0.84 (wider)
ATR accel: 1.4 (high vol cluster)
Final mult: 0.84 × 1.2 = 1.008

ATR = 40 pips
Spacing = 40 × 1.008 = 40.32 pips (vs 24 pips original)

Result: WIDER spacing → avoid premature fills ✅
```

### Example 3: Normal Conditions
```
range_ratio = 0.45 (NORMAL)
atr_accel = 1.05 (NORMAL)

Base mult: 0.6
No regime adjustment
No accel adjustment
Final mult: 0.6

ATR = 25 pips
Spacing = 25 × 0.6 = 15 pips (same as before)

Result: Default behavior ✅
```

---

## Testing Strategy

### Test Preset: 12_SGS_Test.set
**Base**: Clone from Set 10 (ADC enabled)

**SGS Settings**:
- `InpSgsEnabled = true`
- `InpSgsRecentBars = 20`
- `InpSgsLongBars = 100`
- `InpSgsRangingThreshold = 0.3`
- `InpSgsTrendingThreshold = 0.6`
- `InpSgsRangingMult = 0.75`
- `InpSgsTrendingMult = 1.4`
- `InpSgsAtrMaPeriod = 20`
- `InpSgsMinMult = 0.4`
- `InpSgsMaxMult = 1.2`

**Target Metrics**:
| Metric | Set 10 | Set 12 | Target |
|--------|--------|--------|--------|
| Whipsaw % | Baseline | ? | **-20%** ⬇️ |
| PF | > 2.5 | > 2.5 | ✅ Maintain |
| Max DD | < 10% | < 10% | ✅ Maintain |
| Win Rate | Baseline | ? | **+5%** ⬆️ |

---

## Logging

All SGS events use `[SGS]` tag (every 5 minutes):

```
[SGS] regime=RANGING ratio=0.28 mult=0.45 spacing=12.5 pips
[SGS] regime=TRENDING ratio=0.72 mult=0.95 spacing=38.0 pips
[SGS] regime=NORMAL ratio=0.48 atr_accel=1.15 mult=0.60 spacing=15.0 pips
```

---

## Expected Benefits

### Primary Goal
- **Reduce whipsaw**: 20% fewer premature fills in trends
- **Better entry timing**: Adaptive to market conditions
- **Higher win rate**: +5% from better bounce captures in ranging

### Secondary Benefits
- Smoother equity curve (fewer early fills)
- Better capital efficiency (right spacing for right regime)
- Synergy with DLS (both adapt to volatility)

---

## Safety Features

1. **Enable/Disable Flag**: Can turn OFF if issues
2. **Min/Max Bounds**: Prevents extreme spacing (0.4 - 1.2×)
3. **Fallback**: Uses base multiplier when disabled
4. **Logging**: Track all regime changes
5. **Backward Compatible**: Old presets work unchanged

---

## Known Limitations

1. **Lookback dependency**: Needs 100 bars minimum to stabilize
2. **Lag**: Range ratio uses historical data (not predictive)
3. **Single timeframe**: Doesn't check higher TF trend (future: MTC feature)

---

## File Changes

| File | Lines Added | Type |
|------|-------------|------|
| RecoveryGridDirection_v2.mq5 | +11 | Input params |
| Params.mqh | +10 | Struct fields |
| SpacingEngine.mqh | +120 | Detection + calculation |

**Total**: ~140 lines added

---

## Next Steps

1. ✅ Specification complete
2. 🔄 Implement input parameters
3. 🔄 Implement range ratio detection
4. 🔄 Implement ATR acceleration
5. 🔄 Implement adaptive spacing logic
6. 🔄 Modify SpacingPips() method
7. 🔄 Create preset 12_SGS_Test.set
8. 🔄 Run backtest vs Set 10
9. 🔄 Compare whipsaw reduction
10. 🔄 Merge if successful

---

## Success Criteria

✅ **Must Have**:
- Whipsaw reduction > 15%
- DD stays ≤ 10%
- PF stays ≥ 2.5

✅ **Nice to Have**:
- Win rate +5%
- PF > 3.0
- Synergy with DLS when both enabled

---

**Status**: ✅ Specification Complete
**Tested**: ⏳ Pending implementation
**Branch**: feature/smart-grid-spacing
**Version**: v2.9 (after SGS)
