# Smart Grid Spacing (SGS) - Implementation Summary

## Overview
Implemented Smart Grid Spacing to adapt spacing based on trend/range regime and volatility clustering, reducing whipsaw and improving entry timing.

## Problem Solved
- **Fixed spacing multiplier** (`atr_mult = 0.6`) doesn't adapt to market regime
- Trending markets: Grid fills too early → whipsaw losses
- Ranging markets: Misses bounce opportunities with wide spacing
- No volatility cluster awareness

## Solution Implemented

### Adaptive Spacing Formula
```cpp
effective_mult = base_mult × regime_factor × vol_factor

// Regime Detection (range ratio)
range_ratio = recent_range(20) / long_range(100)
- ratio < 0.3: RANGING → mult × 0.75 (tighter)
- ratio > 0.6: TRENDING → mult × 1.4 (wider)
- 0.3-0.6: NORMAL → keep base mult

// Volatility Acceleration
atr_accel = atr_current / atr_ma(20)
- accel > 1.3: HIGH vol → mult × 1.2 (wider)
- accel < 0.8: LOW vol → mult × 0.9 (tighter)

// Final with bounds
result = clamp(effective_mult, min_mult, max_mult)
```

### Key Features
1. **Trend/Range Awareness**:
   - RANGING: Tighter spacing (catch bounces)
   - TRENDING: Wider spacing (avoid premature fills)

2. **Volatility Clustering**:
   - HIGH vol cluster: Widen spacing (reduce risk)
   - LOW vol: Tighten spacing (maximize profit)

3. **Bounded Safety**:
   - Min mult: 0.4 (prevent over-tightening)
   - Max mult: 1.2 (prevent over-widening)

## Changes Made

### 1. Input Parameters
**File**: `RecoveryGridDirection_v2.mq5`

```cpp
input group "=== Smart Grid Spacing (SGS) ==="
input bool   InpSgsEnabled = true;              // Master switch (default ON)
input int    InpSgsRecentBars = 20;             // Recent range bars
input int    InpSgsLongBars = 100;              // Long-term range bars
input double InpSgsRangingThreshold = 0.3;      // Range ratio < this = RANGING
input double InpSgsTrendingThreshold = 0.6;     // Range ratio > this = TRENDING
input double InpSgsRangingMult = 0.75;          // Spacing mult in RANGING (tighter)
input double InpSgsTrendingMult = 1.4;          // Spacing mult in TRENDING (wider)
input int    InpSgsAtrMaPeriod = 20;            // ATR MA period for acceleration
input double InpSgsMinMult = 0.4;               // Min spacing multiplier
input double InpSgsMaxMult = 1.2;               // Max spacing multiplier
```

### 2. Params Fields
**File**: `Params.mqh`

```cpp
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

**Added private members** (10 fields):
```cpp
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
```

**Added helper methods**:
```cpp
double CalculateRangeRatio()
{
    // Recent range
    int recent_high_idx = iHighest(symbol, tf, MODE_HIGH, recent_bars, 0);
    int recent_low_idx = iLowest(symbol, tf, MODE_LOW, recent_bars, 0);
    double recent_range = recent_high - recent_low;

    // Long-term range
    int long_high_idx = iHighest(symbol, tf, MODE_HIGH, long_bars, 0);
    int long_low_idx = iLowest(symbol, tf, MODE_LOW, long_bars, 0);
    double long_range = long_high - long_low;

    return recent_range / long_range;
}

double CalculateAtrAcceleration()
{
    double atr_current = FetchATR();

    // Calculate ATR MA
    double atr_buf[];
    CopyBuffer(m_atr_handle, 0, 0, m_sgs_atr_ma_period, atr_buf);
    double atr_ma = ArrayAverage(atr_buf);

    return atr_current / atr_ma;
}

double CalculateAdaptiveSpacing()
{
    double spacing_mult = m_atr_mult;

    // Factor 1: Regime
    double range_ratio = CalculateRangeRatio();
    if (range_ratio < ranging_threshold)
        spacing_mult *= ranging_mult;  // Tighten
    else if (range_ratio > trending_threshold)
        spacing_mult *= trending_mult;  // Widen

    // Factor 2: Volatility
    double atr_accel = CalculateAtrAcceleration();
    if (atr_accel > 1.3)
        spacing_mult *= 1.2;  // Widen
    else if (atr_accel < 0.8)
        spacing_mult *= 0.9;  // Tighten

    // Bounds
    return clamp(spacing_mult, min_mult, max_mult);
}
```

**Modified SpacingPips()**:
```cpp
double SpacingPips()
{
    // ... (cache check)

    if (m_mode == SPACING_ATR || m_mode == SPACING_HYBRID)
    {
        double atr_pips = atr_points / pip_points;

        // === SGS: Adaptive multiplier ===
        double effective_mult = m_atr_mult;
        if (m_sgs_enabled) {
            effective_mult = CalculateAdaptiveSpacing();
        }

        double atr_spacing = MathMax(m_min_pips, atr_pips × effective_mult);
        // ...
    }

    return result;
}
```

**Modified constructor**:
```cpp
CSpacingEngine(..., const SParams &params)
    : ...,
      m_sgs_enabled(params.sgs_enabled),
      m_sgs_recent_bars(params.sgs_recent_bars),
      // ... (initialize all SGS fields)
{
    // ...
}
```

### 4. OnInit() Update
**File**: `RecoveryGridDirection_v2.mq5`

```cpp
g_spacing = new CSpacingEngine(_Symbol, g_params.spacing_mode,
                               g_params.atr_period, g_params.atr_timeframe,
                               g_params.spacing_atr_mult, g_params.spacing_pips,
                               g_params.min_spacing_pips, g_params);  // ← Pass full params
```

## Examples

### Example 1: Ranging Market
```
Recent range (20 bars): 50 pips
Long range (100 bars): 200 pips
range_ratio = 50 / 200 = 0.25 < 0.3 → RANGING

Base mult: 0.6
Regime: 0.6 × 0.75 = 0.45
ATR accel: 0.9 (LOW)
Final: 0.45 × 0.9 = 0.405

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
Regime: 0.6 × 1.4 = 0.84
ATR accel: 1.4 (HIGH cluster)
Final: 0.84 × 1.2 = 1.008

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
Final: 0.6

ATR = 25 pips
Spacing = 25 × 0.6 = 15 pips (same as before)

Result: Default behavior ✅
```

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

## Expected Benefits

### Primary Goal
- **Reduce whipsaw**: 20% fewer premature fills in trends
- **Better entry timing**: Adaptive to market regime
- **Higher win rate**: +5% from better bounce captures

### Secondary Benefits
- Smoother equity curve (fewer early fills)
- Better capital efficiency (right spacing for right regime)
- Synergy with DLS (both adapt to volatility)

## Safety Features

1. **Enable/Disable Flag**: Can turn OFF if issues
2. **Min/Max Bounds**: Prevents extreme spacing (0.4 - 1.2×)
3. **Fallback**: Uses base multiplier when disabled
4. **Backward Compatible**: Old presets work unchanged
5. **Lookback validation**: Returns NORMAL if data insufficient

## Known Limitations

1. **Lookback dependency**: Needs 100 bars minimum to stabilize
2. **Lag**: Range ratio uses historical data (not predictive)
3. **Single timeframe**: Doesn't check higher TF trend (future: MTC feature)
4. **Cache invalidation**: Cache resets every tick when SGS enabled (acceptable overhead)

## File Changes

| File | Lines Added | Type |
|------|-------------|------|
| RecoveryGridDirection_v2.mq5 | +11 (inputs) + 10 (mapping) + 1 (OnInit) | Input params + init |
| Params.mqh | +10 | Struct fields |
| SpacingEngine.mqh | +10 (members) + 110 (methods) | Detection + calculation |

**Total**: ~152 lines added

## Next Steps

1. ✅ Implementation complete
2. 🔄 Create preset 12_SGS_Test.set
3. 🔄 Run backtest vs Set 10
4. 🔄 Compare whipsaw reduction
5. 🔄 Optimize thresholds if needed
6. 🔄 Merge if successful

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

**Status**: ✅ Implementation Complete
**Tested**: ⏳ Pending backtest
**Branch**: feature/smart-grid-spacing
**Version**: v2.9 (after SGS)
**Merge After**: Can merge independently (no conflict with DLS)
