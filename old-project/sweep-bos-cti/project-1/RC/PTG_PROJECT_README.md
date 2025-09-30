# PTG Trading Strategy Project

## 🎯 Project Overview

**PTG (Push-Test-Go)** is an automated trading strategy for **Gold (XAUUSD) M1** that identifies high-probability breakout opportunities through volume and price action analysis.

### Core Concept
- **PUSH**: Detect strong momentum candle with high volume and range
- **TEST**: Wait for pullback/consolidation 
- **GO**: Execute breakout trade when price breaks test range

---

## 📊 Current Status & Results

### Latest Version: PTG_REAL_TICK_FINAL v2.2.0
- **Environment**: MetaTrader 5, "Every tick based on real ticks"
- **Symbol**: XAUUSD M1
- **Win Rate**: 20.90% (130/622 trades)
- **Net Profit**: -5,016 USD (622 trades executed)
- **Average Win**: 22.15 pips | Average Loss: -16.05 pips
- **Risk per Trade**: 25 pips fixed SL

### Key Achievements ✅
- Successfully adapted strategy for real tick data
- Fixed "Invalid price" issues with STOP-LIMIT orders
- Implemented ChatGPT-recommended optimizations
- Achieved 622 trades execution vs 0 trades in broken versions
- Controlled risk management (25p SL vs 400p+ in broken versions)

---

## 🚨 Critical Problem Solved

### The "Every Tick" vs "Real Tick" Issue
**Problem**: EA worked perfectly in "Every tick" mode but failed in "Every tick based on real ticks"

**Root Causes Identified**:
1. **Spread Handling**: Real tick has dynamic spreads (8-15 pips) vs synthetic constant spread
2. **Order Execution**: STOP-LIMIT orders failed due to minimum distance requirements  
3. **Position Management**: Breakeven/Trail too aggressive for real spread fluctuations
4. **Risk Management**: ATR-based SL too wide (100-400 pips) for Gold real volatility
5. **Entry Confirmation**: Confirmation logic too strict for real tick noise

**Solutions Applied**:
- Fixed spread filter (MaxSpreadPips = 12)
- Switched to Market Orders from STOP-LIMIT
- Implemented spread-buffered breakeven
- Fixed SL distance (25 pips) instead of swing-based
- Disabled strict confirmation logic

---

## 📁 File Structure

```
PTG Trading Project/
├── bot/backtest/
│   ├── PTG_REAL_TICK_FINAL.mq5           # Latest optimized version
│   ├── PTG_EXNESS_PRO_REAL_TICK.mq5      # Development version
│   ├── PTG_EXNESS_PRO.mq5                # Original synthetic tick version
│   └── feedback-realtick-chatGPT.txt     # Professional analysis
├── bot/version/
│   └── BEST_PTG_Natural_Flow.mq5         # Best synthetic tick version
├── tradingview/
│   └── [Pine Script versions]
└── PTG_PROJECT_README.md                 # This file
```

---

## ⚙️ Technical Specifications

### PTG Signal Detection Logic
```mq5
// PUSH Criteria
bool range_criteria = current_range >= avg_range * 0.35;  // 35% above average
bool volume_criteria = volume >= avg_volume * 1.2;        // 120% volume spike  
bool momentum_criteria = close_position >= 0.45;          // Close in top 45%
bool wick_criteria = opposite_wick <= 0.55;               // Opposite wick ≤55%

// TEST Criteria  
bool pullback_max = pullback <= 0.85;                     // Max 85% retracement
bool low_volume = test_volume <= avg_volume * 2.0;        // Lower volume on test
bool timeout = bars_since_push <= 10;                     // Within 10 bars

// GO Execution
// Market order with 25 pip fixed SL when breakout confirmed
```

### Risk Management (ChatGPT Optimized)
```mq5
// Fixed Risk Parameters
FixedSLPips = 25.0;                    // Fixed SL distance
MaxRiskPips = 35.0;                    // Max risk per trade
BreakevenPips = 15.0;                  // Move to BE at +15 pips
PartialTPPips = 22.0;                  // Take 30% profit at +22 pips  
TrailStepPips = 18.0;                  // Trail every 18 pips
MaxSpreadPips = 12.0;                  // Skip trades when spread > 12 pips
```

### Gold-Specific Adaptations
```mq5
// Proper Gold pip calculation
double Pip() {
    if(StringFind(Symbol(), "XAU") >= 0) return 0.01;  // Gold = 0.01
    // ... other symbols
}

// Spread-buffered breakeven for real tick
double be_price = original_entry + spread + 0.5_pip;  // Prevent spread spike triggers

// Dynamic entry buffer based on current spread
double buffer = MathMax(1.5, current_spread * 1.2);
```

---

## 📈 Performance Analysis

### Synthetic Tick vs Real Tick Comparison
| Metric | Synthetic Tick | Real Tick v2.2.0 | Improvement |
|--------|----------------|------------------|-------------|
| Total Trades | ~50-100 | 622 | +600% execution |
| Win Rate | ~45% | 20.90% | Need optimization |
| Risk Control | Variable | 25p fixed | ✅ Controlled |
| Spread Issues | None | Fixed | ✅ Resolved |
| Order Failures | 0% | 0% | ✅ Stable |

### Current Optimization Targets
1. **Win Rate**: 20.90% → 35%+ (primary focus)
2. **Signal Quality**: Filter false breakouts
3. **Entry Timing**: Reduce noise-based entries
4. **Position Sizing**: Dynamic lot sizing based on volatility

---

## 🛠️ Development History

### v1.0.0 - Original PTG (Synthetic Tick)
- Basic PTG implementation
- Works well in "Every tick" mode
- Win rate ~40-50%

### v2.0.0 - Real Tick Adaptation (Failed)
- First attempt at real tick compatibility
- Issues: Spread filter too strict, ATR SL too wide
- Result: 0 trades executed

### v2.1.0 - Improved Real Tick (Partial Success)  
- Fixed spread handling
- Disabled ATR stops
- Result: 161 trades, 27% win rate

### v2.2.0 - ChatGPT Optimized (Current)
- Implemented professional analysis recommendations
- Market orders instead of STOP-LIMIT
- Result: 622 trades, 20.9% win rate, controlled risk

---

## 🎯 Next Steps & Optimization Areas

### Priority 1: Signal Quality Improvement
- **Current Issue**: 20.9% win rate too low
- **Target**: 35%+ win rate  
- **Approach**: Analyze false signals, add filters

### Priority 2: Entry Timing Optimization
- **Current**: Immediate market entry
- **Consider**: Delayed confirmation, momentum filters

### Priority 3: Dynamic Risk Management
- **Current**: Fixed 25p SL
- **Consider**: Volatility-adjusted SL, correlation filters

### Priority 4: Multi-Timeframe Analysis
- **Current**: M1 only
- **Consider**: M5/M15 trend confirmation

---

## 📚 Key Learnings

### Real Tick vs Synthetic Tick Differences
1. **Spread Behavior**: Real tick has dynamic, volatile spreads
2. **Order Execution**: Real tick has minimum distance requirements
3. **Price Movement**: Real tick has more noise and microstructure effects
4. **Position Management**: BE/Trail need wider buffers for real conditions

### Professional Insights (from ChatGPT Analysis)
1. Use STOP-LIMIT orders with proper distance calculation
2. Implement spread-buffered breakeven to prevent false triggers  
3. Dynamic entry buffers based on current market conditions
4. Fixed SL distances work better than swing-based for Gold
5. Order expiration through server (ORDER_TIME_SPECIFIED) vs manual cleanup

---

## 🔧 Technical Requirements

### MetaTrader 5 Setup
- **Account Type**: Raw Spread recommended
- **Symbol**: XAUUSD (Gold)  
- **Timeframe**: M1
- **Testing Mode**: "Every tick based on real ticks"
- **Initial Deposit**: $5000+ recommended

### Compilation Requirements
- MT5 Build 3815+
- No external libraries required
- Standard MQL5 functions only

---

## 📞 Support & Contribution

This is an active trading strategy development project. The codebase represents extensive research into real vs synthetic tick trading differences and practical solutions for high-frequency scalping strategies.

**Current Status**: ✅ Working EA with controlled risk, optimizing for higher win rate

**Last Updated**: September 12, 2025
**Version**: PTG_REAL_TICK_FINAL v2.2.0
