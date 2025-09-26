# ⚙️ FlexGrid DCA EA v3.0 - Configuration Guide

## 🎯 **CONFIGURATION OVERVIEW**

FlexGrid DCA EA v3.0 provides **50+ configurable parameters** organized into logical groups for easy optimization. This guide covers all parameters, recommended settings, and optimization strategies.

---

## 📋 **COMPLETE PARAMETER REFERENCE**

### **🎯 SYMBOL SELECTION**
```cpp
input ENUM_SYMBOLS InpTradingSymbol = SYMBOL_CURRENT;  // Trading Symbol Selection

Available Options:
├─ SYMBOL_CURRENT     // Use current chart symbol (default)
├─ EURUSD            // EUR/USD
├─ GBPUSD            // GBP/USD  
├─ USDJPY            // USD/JPY
├─ USDCHF            // USD/CHF
├─ AUDUSD            // AUD/USD
├─ USDCAD            // USD/CAD
├─ NZDUSD            // NZD/USD
├─ EURJPY            // EUR/JPY
├─ GBPJPY            // GBP/JPY
├─ EURGBP            // EUR/GBP
├─ XAUUSD            // Gold
├─ XAGUSD            // Silver
├─ BTCUSD            // Bitcoin (future)
├─ ETHUSD            // Ethereum (future)
└─ [Additional symbols as needed]

🎯 Recommendation: Start with SYMBOL_CURRENT for testing
```

### **📊 BASIC TRADING**
```cpp
input double InpFixedLotSize = 0.01;             // Fixed Lot Size
input int    InpMaxGridLevels = 5;               // Maximum Grid Levels (per direction)
input double InpATRMultiplier = 1.0;             // ATR Multiplier for Grid Spacing
input bool   InpEnableGridTrading = true;       // Enable Grid Trading
input bool   InpEnableDCATrading = true;        // Enable DCA Trading

Parameter Details:

InpFixedLotSize:
├─ Range: 0.01 - 1.0
├─ Recommended: 0.01 (always start minimum)
├─ Impact: Direct position size control
└─ Safety: Never increase until proven profitable

InpMaxGridLevels:
├─ Range: 3 - 10  
├─ Recommended: 3-5 for testing, 5-7 for live
├─ Impact: More levels = more opportunities + higher risk
└─ Symbol-specific: Adjust based on volatility

InpATRMultiplier:  
├─ Range: 0.5 - 2.5
├─ Recommended: 1.0 (standard), 0.8 (aggressive), 1.2 (conservative)
├─ Impact: Grid spacing width
└─ Market-dependent: Tighter for ranging, wider for trending
```

### **💰 RISK MANAGEMENT**
```cpp
input double InpMaxAccountRisk = 10.0;           // Maximum Account Risk %
input double InpProfitTargetPercent = 1.0;      // Profit Target % (Per Direction)
input double InpProfitTargetUSD = 4.0;          // Profit Target USD (Per Direction)
input bool   InpUseTotalProfitTarget = true;    // Use Total Profit Target (Both Directions)
input double InpMaxLossUSD = 10.0;              // Maximum Loss USD (Loss Protection)
input double InpMaxSpreadPips = 0.0;            // Maximum Spread (pips) - 0=Auto based on symbol
input double InpMaxSpreadPipsWait = 0.0;        // Maximum Spread Wait (pips) - 0=Auto (3x normal)
input bool   InpUseVolatilityFilter = false;    // Use Volatility Filter

Detailed Explanations:

InpMaxAccountRisk:
├─ Purpose: Account-level protection (currently placeholder)
├─ Range: 5.0 - 20.0
├─ Recommended: 10.0 for balanced risk
└─ Future: Will implement account percentage calculations

InpProfitTargetUSD:
├─ Purpose: Primary profit target in USD
├─ Range: 2.0 - 20.0  
├─ Recommended: $3-5 for major pairs, $8-15 for Gold
├─ Impact: Cycle frequency vs profit per cycle
└─ Symbol-specific: Higher for volatile symbols

InpMaxLossUSD:
├─ Purpose: Loss protection mechanism
├─ Range: 5.0 - 50.0
├─ Recommended: 2-3x profit target
├─ Critical: Always set this limit
└─ Trigger: Immediate closure of all positions

InpMaxSpreadPips (Auto-Adaptive):
├─ 0.0 = Auto-detection based on symbol type
├─ Major Forex: 10 pips
├─ JPY Pairs: 15 pips
├─ Minor Pairs: 25 pips  
├─ Gold: 150 pips
├─ Silver: 200 pips
└─ Override: Set specific value if needed
```

### **⏰ TIME FILTERS**
```cpp
input bool InpUseTimeFilter = false;            // Enable Time Filter
input int  InpStartHour = 8;                    // Start Trading Hour
input int  InpEndHour = 18;                     // End Trading Hour

Time Filter Strategy:
├─ Disabled (false): 24/7 trading
├─ Enabled (true): Trade only during specified hours
├─ London Session: 8-16 GMT
├─ NY Session: 13-21 GMT  
├─ Asian Session: 22-6 GMT
└─ Overlap Periods: Highest volatility

Recommended Settings:
├─ Beginners: InpUseTimeFilter = false (learn 24/7 behavior)
├─ Experienced: InpStartHour = 8, InpEndHour = 18 (active sessions)
├─ News Avoidance: Customize around major economic releases
└─ Symbol-specific: Adjust for symbol's most active hours
```

### **🧠 TREND FILTER**
```cpp
input bool   InpUseTrendFilter = false;         // Enable Trend Filter (Wait for Sideways)
input double InpMaxADXStrength = 25.0;          // Maximum ADX for Sideways (< 25 = weak trend)
input bool   InpUseDCARecoveryMode = false;     // DCA Recovery Mode (Lower targets after DCA expansion)

Trend Filter System:
├─ EMA Analysis: 8, 13, 21 periods on H1
├─ ADX Strength: Trend strength measurement  
├─ Sideways Detection: Weak ADX + mixed EMA alignment
└─ Grid Timing: Only setup during favorable conditions

Configuration Recommendations:

Conservative Approach:
├─ InpUseTrendFilter = true
├─ InpMaxADXStrength = 20.0 (stricter)
├─ InpUseDCARecoveryMode = true
└─ Result: Higher win rate, lower frequency

Aggressive Approach:
├─ InpUseTrendFilter = false  
├─ InpUseDCARecoveryMode = true (safety)
└─ Result: Higher frequency, more varied conditions

Balanced Approach:
├─ InpUseTrendFilter = true
├─ InpMaxADXStrength = 25.0 (standard)
├─ InpUseDCARecoveryMode = true
└─ Result: Good balance of safety and opportunity
```

### **🚀 ADVANCED FEATURES**
```cpp
input bool   InpEnableTrailingStop = false;     // Enable Trailing Stop
input bool   InpEnableMarketEntry = true;       // Enable Market Entry at Grid Setup
input bool   InpUseFibonacciSpacing = false;    // Use Fibonacci Grid Spacing (Golden Ratio)
input double InpTrailingStopATR = 2.0;          // Trailing Stop ATR Multiplier
input int    InpMagicNumber = 12345;            // Magic Number
input string InpEAComment = "FlexGridDCA";      // EA Comment

Feature Details:

InpEnableMarketEntry:
├─ true: Immediate 1 BUY + 1 SELL market orders at startup
├─ false: Only pending grid orders  
├─ Benefit: Instant exposure vs waiting for fills
├─ Risk: Immediate exposure to market moves
└─ Recommended: true for most strategies

InpUseFibonacciSpacing:
├─ true: Fibonacci ratios for grid level spacing
├─ false: Equal ATR-based spacing
├─ Benefit: Natural market rhythm alignment
├─ Complexity: More sophisticated calculations
└─ Recommended: false initially, true after optimization

InpEnableTrailingStop:
├─ Purpose: Protect profits with dynamic stops
├─ Currently: Advanced feature (limited implementation)
├─ Distance: ATR-based trailing distance
└─ Recommended: false (rely on profit targets)

InpMagicNumber:
├─ Purpose: Unique EA identification
├─ Range: 10000 - 99999
├─ Important: Different for each EA instance
└─ Default: 12345 (change if running multiple instances)
```

---

## 🎯 **PRESET CONFIGURATIONS**

### **🟢 BEGINNER CONFIGURATION**
```cpp
// SYMBOL SELECTION
InpTradingSymbol = SYMBOL_CURRENT

// BASIC TRADING  
InpFixedLotSize = 0.01
InpMaxGridLevels = 3
InpATRMultiplier = 1.2
InpEnableGridTrading = true
InpEnableDCATrading = true

// RISK MANAGEMENT
InpProfitTargetUSD = 3.0
InpMaxLossUSD = 5.0
InpUseTotalProfitTarget = true
InpMaxSpreadPips = 0.0

// TREND FILTER (ENABLED)
InpUseTrendFilter = true
InpMaxADXStrength = 20.0
InpUseDCARecoveryMode = true

// ADVANCED (MINIMAL)
InpEnableMarketEntry = true
InpUseFibonacciSpacing = false
InpUseTimeFilter = false

Target: Safety first, learn EA behavior, build confidence
Expected: $3-15/day, high win rate, minimal risk
```

### **🔶 INTERMEDIATE CONFIGURATION**
```cpp
// SYMBOL SELECTION
InpTradingSymbol = SYMBOL_CURRENT

// BASIC TRADING
InpFixedLotSize = 0.01
InpMaxGridLevels = 5  
InpATRMultiplier = 1.0
InpEnableGridTrading = true
InpEnableDCATrading = true

// RISK MANAGEMENT
InpProfitTargetUSD = 4.0
InpMaxLossUSD = 10.0
InpUseTotalProfitTarget = true
InpMaxSpreadPips = 0.0

// TREND FILTER (SELECTIVE)
InpUseTrendFilter = true
InpMaxADXStrength = 25.0
InpUseDCARecoveryMode = true

// ADVANCED (MODERATE)
InpEnableMarketEntry = true
InpUseFibonacciSpacing = true
InpUseTimeFilter = false

Target: Balanced performance, moderate frequency, good returns
Expected: $4-25/day, good win rate, managed risk
```

### **🔴 ADVANCED CONFIGURATION**
```cpp
// SYMBOL SELECTION  
InpTradingSymbol = EURUSD  // or specific symbol

// BASIC TRADING
InpFixedLotSize = 0.02
InpMaxGridLevels = 7
InpATRMultiplier = 0.8
InpEnableGridTrading = true
InpEnableDCATrading = true

// RISK MANAGEMENT
InpProfitTargetUSD = 6.0
InpMaxLossUSD = 20.0
InpUseTotalProfitTarget = true
InpMaxSpreadPips = 0.0

// TREND FILTER (MINIMAL)
InpUseTrendFilter = false
InpUseDCARecoveryMode = true

// ADVANCED (FULL)
InpEnableMarketEntry = true
InpUseFibonacciSpacing = true
InpUseTimeFilter = true
InpStartHour = 8
InpEndHour = 18

Target: Maximum performance, higher frequency, higher returns
Expected: $6-40/day, moderate win rate, higher risk
```

---

## 🌍 **SYMBOL-SPECIFIC CONFIGURATIONS**

### **💶 MAJOR FOREX PAIRS (EURUSD, GBPUSD, USDCHF)**
```cpp
InpMaxGridLevels = 5
InpATRMultiplier = 1.0
InpProfitTargetUSD = 4.0
InpMaxLossUSD = 10.0
InpMaxSpreadPips = 0.0  // Auto: ~10 pips

Characteristics:
├─ Moderate volatility
├─ Tight spreads (1-3 pips)
├─ High liquidity
├─ Standard settings work well
└─ Good for beginners

Expected Performance:
├─ 3-8 cycles per day
├─ $4-32 daily profit potential
├─ 80-90% win rate
└─ Low to moderate risk
```

### **🇯🇵 JPY PAIRS (USDJPY, EURJPY, GBPJPY)**
```cpp
InpMaxGridLevels = 4
InpATRMultiplier = 1.1
InpProfitTargetUSD = 5.0
InpMaxLossUSD = 12.0
InpMaxSpreadPips = 0.0  // Auto: ~15 pips

Characteristics:
├─ Different point value (100x vs 10x)
├─ Moderate spreads (2-4 pips)
├─ Good volatility
├─ ATR auto-adjusts for point difference
└─ Reliable performance

Expected Performance:
├─ 2-6 cycles per day
├─ $5-30 daily profit potential
├─ 75-85% win rate
└─ Moderate risk
```

### **🥇 GOLD (XAUUSD)**
```cpp
InpMaxGridLevels = 3
InpATRMultiplier = 1.3
InpProfitTargetUSD = 10.0
InpMaxLossUSD = 25.0
InpMaxSpreadPips = 0.0  // Auto: ~150 pips

Characteristics:
├─ High volatility
├─ Wide spreads (15-50 pips)
├─ Large point values
├─ Requires adjusted parameters
└─ Higher profit potential

Expected Performance:
├─ 1-4 cycles per day
├─ $10-40 daily profit potential
├─ 70-80% win rate
└─ Higher risk, higher reward

⚠️ Gold-Specific Notes:
- Monitor spread carefully (can spike to 100+ pips)
- Consider lower grid levels due to volatility
- Higher profit targets match the volatility
- DCA recovery mode highly recommended
```

### **🥈 SILVER (XAGUSD)**
```cpp
InpMaxGridLevels = 4
InpATRMultiplier = 1.2
InpProfitTargetUSD = 8.0
InpMaxLossUSD = 20.0
InpMaxSpreadPips = 0.0  // Auto: ~200 pips

Characteristics:
├─ Very high volatility
├─ Wide spreads (20-80 pips)
├─ Less liquid than Gold
├─ Requires careful management
└─ Good profit potential

Expected Performance:
├─ 1-3 cycles per day
├─ $8-24 daily profit potential
├─ 65-75% win rate
└─ High risk, high reward
```

### **🌐 MINOR PAIRS (AUDCAD, NZDCHF, etc.)**
```cpp
InpMaxGridLevels = 4
InpATRMultiplier = 1.3
InpProfitTargetUSD = 6.0
InpMaxLossUSD = 15.0
InpMaxSpreadPips = 0.0  // Auto: ~25 pips

Characteristics:
├─ Higher volatility than majors
├─ Wider spreads (3-8 pips)
├─ Lower liquidity
├─ Requires wider spacing
└─ Good diversification

Expected Performance:
├─ 2-5 cycles per day
├─ $6-30 daily profit potential
├─ 70-80% win rate
└─ Moderate to high risk
```

---

## 🔧 **OPTIMIZATION STRATEGIES**

### **📊 MT5 Strategy Tester Optimization**

#### **Phase 1: Core Parameter Optimization**
```cpp
// Primary parameters to optimize first:
InpMaxGridLevels:
├─ Start: 3, Step: 1, Stop: 8
├─ Impact: Risk vs opportunity balance
└─ Optimize per symbol

InpATRMultiplier:
├─ Start: 0.6, Step: 0.2, Stop: 2.0
├─ Impact: Entry frequency vs spacing
└─ Critical for performance

InpProfitTargetUSD:
├─ Start: 2.0, Step: 1.0, Stop: 10.0
├─ Impact: Cycle frequency vs profit per cycle
└─ Symbol-dependent optimization

Strategy Tester Settings:
├─ Optimization: Genetic algorithm
├─ Passes: Maximum for thorough testing
├─ Period: 3-6 months historical data
├─ Timeframe: M1 for precise execution
└─ Criteria: Balance + Profit Factor
```

#### **Phase 2: Risk Parameter Optimization**
```cpp
InpMaxLossUSD:
├─ Start: 5.0, Step: 2.5, Stop: 25.0
├─ Relationship: 2-3x profit target
└─ Balance protection vs trading freedom

Boolean Feature Testing:
├─ InpUseTrendFilter: [false, true]
├─ InpUseDCARecoveryMode: [false, true]
├─ InpUseFibonacciSpacing: [false, true]
├─ InpEnableMarketEntry: [false, true]
└─ Test all combinations for best performance
```

#### **Phase 3: Advanced Optimization**
```cpp
Time Filter Optimization:
├─ InpStartHour: 0, 2, 22
├─ InpEndHour: 2, 4, 23
├─ Test various session combinations
└─ Validate against symbol's active hours

ADX Threshold Optimization:
├─ InpMaxADXStrength: 15.0, 20.0, 25.0, 30.0
├─ Impact on trend filter effectiveness
└─ Symbol-specific optimization

Multi-Parameter Validation:
├─ Combine best individual parameters
├─ Test on out-of-sample data
├─ Validate across different market conditions
└─ Document final optimized settings
```

### **📈 Performance Metrics to Optimize For**

#### **Primary Targets**
```
Profit Factor: > 1.5
├─ Calculation: Gross Profit / Gross Loss
├─ Target: >1.5 good, >2.0 excellent
└─ Critical: Must be consistently > 1.2

Maximum Drawdown: < 30%
├─ Calculation: Largest equity decline
├─ Target: <20% excellent, <30% acceptable
└─ Critical: Must not exceed account loss tolerance

Win Rate: > 70%
├─ Calculation: Winning trades / Total trades
├─ Target: >70% good, >80% excellent
└─ Balance: High win rate vs profit per trade

Recovery Factor: > 2.0
├─ Calculation: Net Profit / Max Drawdown
├─ Target: >2.0 good, >3.0 excellent
└─ Measures: Ability to recover from losses
```

#### **Secondary Metrics**
```
Total Trades: > 100
├─ Purpose: Statistical significance
├─ Target: >100 for valid backtest
└─ More trades = more reliable statistics

Average Trade: Positive
├─ Calculation: Net Profit / Total Trades
├─ Target: Consistently positive
└─ Higher = better efficiency

Largest Loss: < 2x Average Win
├─ Purpose: Risk control validation
├─ Target: No single loss dominates
└─ Confirms: Risk management effectiveness

Consecutive Losses: < 10
├─ Purpose: Drawdown streak assessment
├─ Target: <5 excellent, <10 acceptable
└─ Impact: Psychological trading stress
```

---

## 📋 **CONFIGURATION CHECKLIST**

### **✅ Pre-Live Configuration Verification**
```
Basic Settings:
├─ [ ] InpFixedLotSize = 0.01 (confirmed minimum)
├─ [ ] InpMaxGridLevels appropriate for symbol
├─ [ ] InpProfitTargetUSD realistic for symbol  
├─ [ ] InpMaxLossUSD set as safety limit
└─ [ ] InpMagicNumber unique if multiple EAs

Risk Management:
├─ [ ] Loss protection enabled and tested
├─ [ ] Spread limits appropriate for symbol
├─ [ ] Account balance sufficient for strategy
├─ [ ] Margin requirements calculated
└─ [ ] Maximum exposure acceptable

Advanced Features:
├─ [ ] Trend filter configured if enabled
├─ [ ] DCA recovery mode tested
├─ [ ] Market entry preference set
├─ [ ] Time filters appropriate if enabled
└─ [ ] All boolean settings verified

Testing Validation:
├─ [ ] Backtest results positive
├─ [ ] Demo testing completed (minimum 2 weeks)
├─ [ ] All features tested in demo
├─ [ ] Performance metrics meet targets
└─ [ ] No unexpected behavior observed
```

### **🔄 Ongoing Configuration Management**
```
Daily Monitoring:
├─ [ ] Check EA status and performance
├─ [ ] Verify parameters still appropriate
├─ [ ] Monitor risk metrics
└─ [ ] Document any issues

Weekly Review:
├─ [ ] Analyze performance vs targets
├─ [ ] Review parameter effectiveness
├─ [ ] Consider minor adjustments
└─ [ ] Update configuration if needed

Monthly Optimization:
├─ [ ] Full performance analysis
├─ [ ] Compare vs market conditions
├─ [ ] Consider parameter updates
├─ [ ] Plan next month's strategy
└─ [ ] Document lessons learned
```

---

## 🎯 **CONFIGURATION SUCCESS FACTORS**

### **Key Principles**
```
1. Start Conservative:
   ✅ Begin with safe parameters
   ✅ Prove profitability first
   ✅ Scale gradually

2. Test Thoroughly:
   ✅ Demo test all configurations
   ✅ Validate across market conditions
   ✅ Document all results

3. Optimize Systematically:
   ✅ One parameter group at a time
   ✅ Use MT5 Strategy Tester properly
   ✅ Validate on out-of-sample data

4. Monitor Continuously:
   ✅ Track performance metrics
   ✅ Adjust based on market changes
   ✅ Maintain discipline
```

### **Common Configuration Mistakes**
```
❌ Over-optimization on limited data
❌ Changing parameters too frequently  
❌ Ignoring risk management settings
❌ Not testing before live deployment
❌ Using overly aggressive settings initially
❌ Copying settings without understanding
❌ Not adapting to symbol characteristics
❌ Disabling safety features too early
```

---

**🎯 Configuration is the foundation of EA success. Take time to understand each parameter and optimize systematically for your specific trading environment and risk tolerance.**

**🚀 Ready for precision-tuned performance!**
