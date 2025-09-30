# PTG Strategy - Quick Reference & Status

## 📊 Current Status (as of Sept 12, 2025)

### ✅ WORKING VERSION: `PTG_REAL_TICK_FINAL.mq5`
- **622 trades executed** ✅ (vs 0 in broken versions)
- **Win Rate: 20.90%** ⚠️ (needs improvement to 35%+)
- **Risk Controlled**: 25p fixed SL ✅
- **Real Tick Compatible** ✅

---

## 🎯 Priority Issues to Solve

| Priority | Issue | Current | Target | AI Analysis Topic |
|----------|-------|---------|---------|-------------------|
| 🔥 HIGH | Win Rate | 20.90% | 35%+ | "False signal reduction & entry quality" |
| 🔥 HIGH | Profit Factor | 0.36 | 1.2+ | "Risk-reward optimization" | 
| 🟡 MED | Signal Frequency | Good | Maintain | "Signal quality vs quantity balance" |
| 🟡 MED | Spread Costs | Handled | Optimize | "Dynamic spread-based filters" |
| 🟢 LOW | Multi-TF | M1 only | M1+M5 | "Multi-timeframe confirmation" |

---

## 🚀 How to Use AI Analysis System

### Step 1: Choose Analysis Topic
Pick from priority list above, e.g., "Win Rate Optimization"

### Step 2: Use Template
```bash
# Open file:
AI_ANALYSIS_PROMPT_TEMPLATE.md

# Replace [SPECIFIC_ISSUE] with:
"Win rate optimization: 20.90% → 35%+ target. 
Need analysis of false signals and entry timing."

# Attach files:
- Latest log.txt
- PTG_REAL_TICK_FINAL.mq5  
- Backtest screenshots
```

### Step 3: Get Analysis
Paste prompt + data into Claude/ChatGPT/other AI

### Step 4: Forward to Coding AI  
```
"Here's professional analysis of my PTG strategy. 
Please implement these recommendations: [paste analysis]"
```

---

## 📁 Key Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `PTG_REAL_TICK_FINAL.mq5` | **Current working EA** | Load in MT5 for testing |
| `PTG_PROJECT_README.md` | **Complete documentation** | Share with any AI for context |
| `AI_ANALYSIS_PROMPT_TEMPLATE.md` | **Analysis template** | Use with analysis AIs |
| `PTG_QUICK_REFERENCE.md` | **This file** | Quick status check |

---

## 🎯 Success Metrics to Track

### After Each Optimization:
- [ ] Win Rate: ___% (target 35%+)
- [ ] Profit Factor: ___ (target 1.2+)  
- [ ] Total Trades: ___ (maintain 500+/month)
- [ ] Max Drawdown: ___% (target <20%)
- [ ] Average Win: ___ pips (maintain 20+)
- [ ] Average Loss: ___ pips (maintain <20)

### Testing Checklist:
- [ ] "Every tick based on real ticks" mode ✅
- [ ] XAUUSD M1 ✅  
- [ ] Initial deposit $5000+ ✅
- [ ] Test period: 1+ months data ✅
- [ ] No compilation errors ✅

---

## 💡 Quick Fixes Already Applied

### ✅ FIXED: Order Execution Issues
- **Problem**: STOP-LIMIT "Invalid price" errors
- **Solution**: Switched to Market Orders
- **Result**: 0 trades → 622 trades ✅

### ✅ FIXED: Spread Handling
- **Problem**: Dynamic real tick spreads caused failures
- **Solution**: MaxSpreadPips = 12, spread-buffered breakeven  
- **Result**: EA runs stable in real conditions ✅

### ✅ FIXED: Risk Management
- **Problem**: ATR-based SL too wide (100-400 pips)
- **Solution**: Fixed 25 pip SL
- **Result**: Controlled risk per trade ✅

---

## 🔧 Current EA Settings (Optimized)

```mq5
// Core PTG Detection
PushRangePercent = 0.35;    // 35% above average range
VolHighMultiplier = 1.2;    // 120% volume spike
ClosePercent = 0.45;        // Close in top 45%
OppWickPercent = 0.55;      // Opposite wick ≤55%

// Risk Management (ChatGPT Optimized)
FixedSLPips = 25.0;         // Fixed 25 pip SL
BreakevenPips = 15.0;       // BE at +15 pips
PartialTPPips = 22.0;       // Take 30% profit at +22 pips
TrailStepPips = 18.0;       // Trail every 18 pips

// Real Tick Adaptations  
MaxSpreadPips = 12.0;       // Skip when spread >12 pips
UseStopLimit = false;       // Market orders (STOP-LIMIT failed)
```

---

## 🎉 Project Achievements

### Major Breakthrough ✅
**Successfully adapted PTG strategy for real tick data** - This was the core challenge that blocked the entire project.

### Technical Wins ✅
- Fixed all "Invalid price" order failures
- Implemented proper Gold pip calculations  
- Added spread-dynamic entry buffers
- Created stable real-tick position management

### Performance Progress ✅
- **v1.0**: Synthetic tick only, ~40% win rate
- **v2.0**: Real tick attempt, 0 trades (broken)
- **v2.1**: Partial fix, 161 trades, 27% win rate  
- **v2.2**: Current version, 622 trades, 21% win rate

### Next Target 🎯
**Win Rate: 21% → 35%** = Turn strategy profitable

---

*Last Updated: September 12, 2025*  
*Status: ✅ EA Working, 🎯 Optimizing Win Rate*
