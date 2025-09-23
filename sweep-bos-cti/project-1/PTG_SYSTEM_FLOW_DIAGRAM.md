# PTG TRADING SYSTEM - FLOW DIAGRAM (A-Z)

## 🏗️ KIẾN TRÚC TỔNG QUAN

```
┌─────────────────────────────────────────────────────────────────┐
│                        PTG TRADING SYSTEM                       │
│                    (Push-Test-Go Strategy)                     │
└─────────────────────────────────────────────────────────────────┘
                                    │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
        ┌───────▼────────┐  ┌──────▼──────┐  ┌───────▼────────┐
        │   INPUT LAYER   │  │ FILTER LAYER │  │ EXECUTION LAYER│
        │                │  │              │  │                │
        │ • Presets 0-49  │  │ • Market     │  │ • Pending      │
        │ • User Config   │  │   Conditions │  │   Orders       │
        │ • ATR/EMA Data  │  │ • Pattern    │  │ • Position     │
        │                │  │   Recognition│  │   Management   │
        └────────────────┘  └─────────────┘  └────────────────┘
```

## 🔄 MAIN EXECUTION FLOW

### Phase 1: INITIALIZATION & SETUP
```
OnInit() 
    │
    ├─► ApplyUsecase(InpUsecase) ──► Load preset parameters
    │                              ├─► Set RN filters
    │                              ├─► Set Spread limits  
    │                              ├─► Set Push/Wick rules
    │                              └─► Set Exit parameters
    │
    ├─► Initialize indicators ──────► ATR(14) + EMA_M5(50)
    │
    └─► Setup event handlers ──────► OnTick + OnTimer + OnNewBar
```

### Phase 2: TICK-BY-TICK MONITORING
```
OnTick()
    │
    ├─► Check new bar formation
    │   │
    │   └─► OnNewBar() ──► Main trading logic
    │
    └─► Position management (if exists)
```

### Phase 3: MAIN TRADING LOGIC (OnNewBar)
```
OnNewBar()
    │
    ├─► 1. UPDATE WIN/LOSS HISTORY
    │   └─► Track recent deals for circuit breaker
    │
    ├─► 2. POSITION CHECK
    │   ├─► If position exists ──► ManagePosition()
    │   └─► If no position ──────► Continue to filters
    │
    ├─► 3. MARKET CONDITION FILTERS
    │   ├─► SoftSqueezeOK(atr) ───► Check ATR >= ATRMinPips
    │   ├─► CircuitOK(atr) ───────► Check consecutive losses
    │   ├─► InBlackout() ─────────► Check time windows
    │   ├─► SpreadOK(atr) ────────► Check spread limits
    │   └─► No pending orders ───► Ensure clean state
    │
    ├─► 4. PATTERN RECOGNITION
    │   └─► FindSetup() ──────────► Search for PTG pattern
    │       │
    │       └─► BuildPTG(idx) ───► For each lookback bar
    │           │
    │           ├─► PUSH Analysis
    │           ├─► TEST Analysis  
    │           ├─► Wick Validation
    │           ├─► Sweep Check
    │           └─► Entry/SL calculation
    │
    ├─► 5. ADDITIONAL FILTERS
    │   ├─► M5BiasFavor() ────────► Check EMA slope bias
    │   ├─► Direction allowed ────► Long/Short permissions
    │   └─► Anti-chop logic ──────► 5min block after early-cut
    │
    └─► 6. ORDER PLACEMENT
        └─► PlacePending() ───────► BuyStop/SellStop with SL
```

## 🎯 PTG PATTERN RECOGNITION DETAIL

### PUSH Phase (Momentum Detection)
```
PUSH Analysis
    │
    ├─► Collect data from Push bars (usually 1-2 bars)
    │   ├─► Calculate average range: sumR/PushBars  
    │   ├─► Find maximum range: maxR
    │   └─► Determine push direction: C[push] vs O[push]
    │
    ├─► Validate momentum strength
    │   ├─► avgP >= PushAvgATRmult * ATR  (e.g., 0.60 * ATR)
    │   └─► OR maxP >= PushMaxATRmult * ATR (e.g., 0.80 * ATR)
    │
    └─► Result: Strong directional move confirmed
```

### TEST Phase (Retracement Analysis)
```
TEST Analysis
    │
    ├─► Calculate retracement percentage
    │   │   RetrPct = (push_range - current_position) / push_range * 100
    │   │
    │   └─► Must be within: TestRetrMinPct to TestRetrMaxPct
    │       └─► Default: -20% to 130% (allows some overshoot)
    │
    ├─► Wick Analysis (Two Rules)
    │   │
    │   ├─► Rule A (Base): 
    │   │   ├─► WickFrac >= WickFracBase (0.35)
    │   │   └─► WickPips >= min(12p, 0.25*ATR)
    │   │
    │   └─► Rule B (Alternative):
    │       ├─► WickFrac >= WickFracAlt (0.18)  
    │       └─► WickPips >= min(45p, max(12p, StrongWickATR*ATR))
    │
    └─► Sweep Requirement
        ├─► Long: L[test] < L[previous]
        ├─► Short: H[test] > H[previous]
        └─► Soft fallback: Allow skip if strong momentum
```

### GO Phase (Entry Setup)
```
GO Setup
    │
    ├─► Calculate Entry Price
    │   ├─► Long: Push_High + EntryBuffer
    │   ├─► Short: Push_Low - EntryBuffer
    │   └─► EntryBuffer = max(3p, min(8p, 0.04*ATR + Spread + 1.5))
    │
    ├─► Round Number Filter
    │   ├─► Check Major grid: 100p with 6p buffer
    │   ├─► Check Minor grid: 50p with 4p buffer  
    │   └─► Reject if too close to round numbers
    │
    ├─► Calculate Stop Loss
    │   │   SL_distance = max(min(SL_Fixed, SL_ATRmult*ATR), min(32p, 0.22*ATR))
    │   │
    │   ├─► Long: SL = Entry - SL_distance
    │   └─► Short: SL = Entry + SL_distance
    │
    └─► Set Invalidation Level
        ├─► Long: invalidLevel = L[test_bar]
        └─► Short: invalidLevel = H[test_bar]
```

## ⚙️ ORDER MANAGEMENT SYSTEM

### Pending Order Lifecycle
```
PlacePending()
    │
    ├─► Cooldown Check
    │   ├─► Recent cancel? ──► Block (unless re-arm window)
    │   └─► Re-arm logic ───► 60s skip cooldown for same direction
    │
    ├─► Order Placement
    │   ├─► BuyStop(price, SL) for long setups
    │   └─► SellStop(price, SL) for short setups
    │
    └─► Monitoring Setup
        ├─► Set expiry: now + PendingExpirySec (120s)
        ├─► Set invalidation tracking
        └─► Start OnTimer() monitoring
```

### Order Invalidation (OnTimer)
```
OnTimer() - Pending Monitoring
    │
    ├─► Check Expiry ──────────► Cancel if expired
    │
    └─► Structure Invalidation
        │
        ├─► Price beyond invalidLevel + buffer?
        │   ├─► Dynamic buffer = max(InvalBufPips, 0.06*ATR)
        │   └─► Dynamic dwell = max(InvalDwellSec, 8 + 0.05*ATR)
        │
        ├─► Start timer when price breaches
        │
        └─► Cancel if dwelling too long beyond level
            └─► CancelPendingIfAny() ──► Set re-arm window
```

### Position Management
```
ManagePosition()
    │
    ├─► Calculate current P&L in pips
    │
    ├─► Early Cut (first 2 bars)
    │   └─► If pips <= -EarlyCut_Target ──► Close & block re-entry 5min
    │
    ├─► Time Stop (after 10 bars)
    │   └─► If pips < TimeStopMin ────────► Close position
    │
    ├─► Partial Take Profit
    │   └─► If pips >= Partial_Target ────► Close 40% of position
    │
    ├─► Break Even
    │   └─► If pips >= BE_Target ─────────► Move SL to entry + spread
    │
    └─► Trailing Stop
        └─► If pips >= TrailStart_Target ─► Trail by TrailStep_Target
```

## 🛡️ ADAPTIVE EXITS SYSTEM

### ATR-Based Dynamic Exits (UseCase 19+)
```
ComputeAdaptiveExits(atr)
    │
    ├─► Breakeven = min(22p, max(BE_Floor, 0.10*atr))
    ├─► Partial = min(30p, max(Partial_Floor, 0.15*atr))  
    ├─► TrailStart = min(36p, max(TrailStart_Floor, 0.20*atr))
    ├─► TrailStep = min(26p, max(TrailStep_Floor, 0.12*atr))
    └─► EarlyCut = min(40p, max(EarlyCut_Floor, 0.22*atr))
```

## 🚨 RISK MANAGEMENT LAYERS

### Circuit Breaker System
```
Circuit Breaker
    │
    ├─► Consecutive Loss Tracking
    │   ├─► 4 losses in 60min ──► 60min cooldown
    │   └─► Daily loss limit ───► Stop for the day
    │
    ├─► Resume Conditions
    │   └─► ATR must be >= MinATRResume (70p)
    │
    └─► Anti-Chop Mechanisms
        ├─► 5min block after early-cut (same direction)
        ├─► Re-arm window (60s) after pending cancel
        └─► Cooldown after manual cancel (45s)
```

### Multi-Layer Filtering
```
Filter Stack (Must ALL Pass)
    │
    ├─► Market Condition Filters
    │   ├─► ATR >= ATRMinPips (volatility gate)
    │   ├─► Spread <= MaxSpread (execution quality)
    │   ├─► Not in blackout window
    │   └─► Circuit breaker OK
    │
    ├─► Pattern Quality Filters  
    │   ├─► Push strength validated
    │   ├─► Wick rules satisfied
    │   ├─► Sweep confirmed (or fallback)
    │   └─► Retracement in range
    │
    ├─► Bias & Directional Filters
    │   ├─► M5 EMA slope alignment
    │   ├─► Contra-bias exceptions for strong setups
    │   └─► Long/Short permissions
    │
    └─► Entry Quality Filters
        ├─► Round number avoidance
        ├─► Entry buffer adequate
        └─► No pending conflicts
```

## 📊 PRESET SYSTEM ARCHITECTURE

### Preset Categories
```
Preset Organization
    │
    ├─► Stable Baselines (18-19)
    │   ├─► 18: Strict RN + Spread
    │   └─► 19: 18 + Adaptive Exits
    │
    ├─► Volume-Based (20-29, 42-43)
    │   ├─► High-vol only: 42, 47
    │   ├─► Low-vol friendly: 25, 43
    │   └─► ATR filters: 22, 29
    │
    ├─► Bias Variations (21, 26, 30, 40-41)
    │   ├─► Bias off: 30, 41
    │   ├─► Soft bias: 21, 40
    │   └─► Strict bias: 26, 31
    │
    ├─► Engine Tuning (35-36, 45-46)
    │   ├─► Patient: 35, 45
    │   ├─► Fast: 36, 46
    │   └─► Chop control
    │
    └─► Exit Strategies (38-39, 48-49)
        ├─► Conservative: 38, 49
        ├─► Aggressive: 39, 46
        └─► Trend carry: 48
```

## 🔧 KEY TECHNICAL INNOVATIONS

### 1. Dynamic Buffer System
- **Buffer Size**: Adapts to ATR (0.06 * ATR)
- **Dwell Time**: Scales with volatility (8 + 0.05 * ATR)
- **Purpose**: Reduce false invalidations in volatile markets

### 2. Re-arm Mechanism
- **Trigger**: After pending order cancellation
- **Window**: 60 seconds to skip cooldown
- **Condition**: Same direction as cancelled order
- **Benefit**: Quick re-entry for legitimate setups

### 3. Wick Rule Dual-Path
- **Rule A**: Standard requirement (35% wick, 12p minimum)
- **Rule B**: Alternative for strong momentum (18% wick, higher pip requirement)
- **ATR Cap**: 45 pip maximum to handle extreme volatility

### 4. Anti-Chop Protection
- **Early-Cut Block**: 5 minutes same-direction block after early exit
- **Pattern Invalidation**: Dynamic monitoring of structure breakdown
- **Cooldown System**: Prevent rapid-fire failed attempts

## 🎯 OPTIMIZATION FRAMEWORK

### Performance Metrics Tracking
```
Key Metrics
    │
    ├─► Profit Factor (≥1.15 target)
    ├─► Win Rate (≥46% target)  
    ├─► Sharpe Ratio (>2.5 target)
    ├─► Max Drawdown (≤1.8x median win)
    ├─► Cancel/Trade Ratio (<0.55)
    └─► Early-Cut Rate (10-25% optimal)
```

### Adaptive Parameter Selection
```
Market Condition → Preset Recommendation
    │
    ├─► High Spread Environment ──► UC25 (15/12p limits)
    ├─► Low Volatility Periods ───► UC43 (ATRmin 45p)
    ├─► Choppy/Ranging Markets ───► UC35/45 (patient engine)
    ├─► Strong Trending Moves ────► UC42/47 (momentum-only)
    └─► Round Number Congestion ──► UC24/28/44 (RN variants)
```

## 🚀 FUTURE ENHANCEMENT VECTORS

### Planned v4.1+ Features
1. **Smart Preset Auto-Selection**: ML-based market regime detection
2. **Dynamic Lot Sizing**: Volatility-adjusted position sizing
3. **Multi-Symbol Support**: Correlation-aware portfolio management
4. **Advanced Pattern Recognition**: Deep learning pattern classification
5. **Real-time Optimization**: Parameter adaptation based on recent performance

---

**Tóm tắt**: PTG là một hệ thống scalping M1 tinh vi với 50+ preset configurations, sử dụng pattern Push-Test-Go để tận dụng các liquidity event trong thị trường Gold (XAUUSD). Hệ thống có cơ chế adaptive exits, multi-layer filtering, và advanced risk management để tối ưu hóa performance trong mọi điều kiện thị trường.
