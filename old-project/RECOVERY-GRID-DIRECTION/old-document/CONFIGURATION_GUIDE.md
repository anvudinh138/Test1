# ⚙️ EXP-V3 CONFIGURATION GUIDE

## 📋 **PARAMETER OVERVIEW**

EXP-V3 có hơn 30 input parameters được tổ chức thành các nhóm logic. Mỗi parameter có tác động trực tiếp đến hiệu suất và risk của system.

### **🎯 PARAMETER CATEGORIES:**
1. **Portfolio Risk Management** - Global risk controls
2. **Job Creation Rules** - When and how to create new jobs
3. **Job Triggers** - Plan A/B/C activation settings
4. **Emergency Controls** - Kill switches and safety mechanisms
5. **Testing & Debug** - Development and testing tools

---

## 🛡️ **PORTFOLIO RISK MANAGEMENT**

### **📊 CORE RISK PARAMETERS:**

#### **`InpMaxPortfolioRisk = 100.0`**
- **Purpose**: Maximum total risk across all jobs ($)
- **Impact**: Controls overall exposure
- **Recommended**: 5-10% of account balance
- **Example**: $1000 account → $50-100 max risk

#### **`InpMaxDrawdownPercent = 20.0`**
- **Purpose**: Maximum portfolio drawdown (%)
- **Impact**: Emergency shutdown trigger
- **Recommended**: 15-25% for aggressive, 10-15% for conservative
- **Example**: 20% = shutdown if equity drops 20% from peak

#### **`InpMaxConcurrentLifecycles = 2`**
- **Purpose**: Maximum simultaneous jobs
- **Impact**: System complexity and risk distribution
- **Recommended**: Start with 1-2, max 5
- **Example**: 2 = maximum 2 jobs running at once

#### **`InpMinBalancePerLifecycle = 50.0`**
- **Purpose**: Minimum balance required per job ($)
- **Impact**: Job creation frequency
- **Recommended**: 5-10% of account balance
- **Example**: $1000 account → $50-100 per job

---

## 🎯 **JOB CREATION RULES**

### **📊 JOB SPECIFICATIONS:**

#### **`InpDefaultProfitTarget = 20.0`**
- **Purpose**: Profit target per job ($)
- **Impact**: When trailing stop activates (at 50% of this)
- **Recommended**: 2-5% of account balance
- **Example**: $20 target → trailing starts at $10 profit

#### **`InpDefaultStopLoss = 50.0`**
- **Purpose**: Stop loss per job ($)
- **Impact**: Maximum loss per job, DCA trigger (at 50% of this)
- **Recommended**: 5-10% of account balance
- **Example**: $50 stop → DCA triggers at $25 loss

#### **`InpDefaultGridLevels = 8`**
- **Purpose**: Number of grid levels per job
- **Impact**: Position density, DCA sensitivity
- **Recommended**: 5-10 levels
- **Example**: 8 levels → DCA triggers when 4 levels filled (50%)

#### **`InpDefaultLotSize = 0.01`**
- **Purpose**: Position size per grid level
- **Impact**: Risk per position
- **Recommended**: Start with minimum (0.01)
- **Example**: 0.01 lot = $1 per pip for major pairs

#### **`InpATRMultiplier = 1.2`**
- **Purpose**: Grid spacing multiplier
- **Impact**: Distance between grid levels
- **Recommended**: 1.0-2.0 (1.2 is balanced)
- **Example**: 1.2 × ATR = grid spacing in pips

#### **`InpLifecycleIntervalMinutes = 5`**
- **Purpose**: Time between job creations (Plan A)
- **Impact**: Job creation frequency
- **Recommended**: 5-30 minutes
- **Example**: 5 minutes = new job every 5 minutes (if conditions met)

---

## 🚀 **JOB TRIGGERS (PLANS A/B/C)**

### **📊 PLAN A: TIME-BASED CREATION**

#### **`InpEnableTimeTrigger = true`**
- **Purpose**: Enable time-based job creation
- **Impact**: Regular job creation based on interval
- **Recommended**: true (primary trigger)
- **Usage**: Foundation trigger, always enabled

### **📊 PLAN B: TRAILING-TRIGGERED CREATION**

#### **`InpEnableTrailingTrigger = false`**
- **Purpose**: Create job when existing job starts trailing
- **Impact**: Creates rescue/hedge positions
- **Recommended**: false initially, true after testing
- **Cooldown**: 10 minutes between triggers

### **📊 PLAN C: DCA-TRIGGERED CREATION**

#### **`InpEnableDCATrigger = false`**
- **Purpose**: Create job when DCA expansion limit reached
- **Impact**: Creates rescue jobs for failing positions
- **Recommended**: false initially, true after testing
- **Cooldown**: 3 minutes between triggers

#### **`InpDCAExpansionLimit = 2`**
- **Purpose**: DCA expansions before triggering Plan C
- **Impact**: How many DCA attempts before rescue
- **Recommended**: 2-3 expansions
- **Example**: After 2 DCA expansions, create rescue job

#### **`InpMaxRescueJobs = 2`**
- **Purpose**: Maximum rescue jobs per original job
- **Impact**: Limits cascade job creation
- **Recommended**: 1-3 rescue jobs
- **Example**: Each original job can spawn max 2 rescue jobs

---

## 🚨 **EMERGENCY CONTROLS**

### **📊 SAFETY MECHANISMS:**

#### **`InpEmergencyKillSwitch = false`**
- **Purpose**: Immediately shutdown all jobs
- **Impact**: Closes all positions and stops trading
- **Usage**: Emergency use only
- **Action**: Set to true to trigger emergency shutdown

#### **`InpForceCreateFirstJob = true`**
- **Purpose**: Force create first job for testing
- **Impact**: Bypasses normal creation conditions
- **Usage**: Testing only, disable in production
- **Recommended**: true for testing, false for live

#### **`InpEnableDebugMode = true`**
- **Purpose**: Enable detailed logging
- **Impact**: More verbose logs for troubleshooting
- **Usage**: Development and testing
- **Recommended**: true for testing, false for production

#### **`InpEnableDashboard = true`**
- **Purpose**: Enable on-chart display
- **Impact**: Shows real-time portfolio status
- **Usage**: Visual monitoring
- **Recommended**: true (always useful)

#### **`InpBypassMarketFilters = true`**
- **Purpose**: Skip market condition checks
- **Impact**: Allows job creation in any conditions
- **Usage**: Testing only
- **Recommended**: true for testing, false for live

---

## 🎛️ **CONFIGURATION SCENARIOS**

### **🎯 CONSERVATIVE SETUP (BEGINNER):**
```cpp
// Risk Management
InpMaxPortfolioRisk = 50.0              // Low total risk
InpMaxDrawdownPercent = 15.0            // Conservative drawdown
InpMaxConcurrentLifecycles = 1          // Single job only
InpMinBalancePerLifecycle = 100.0       // Higher balance requirement

// Job Settings
InpDefaultProfitTarget = 15.0           // Modest profit targets
InpDefaultStopLoss = 30.0              // Tight stop losses
InpDefaultGridLevels = 5               // Fewer grid levels
InpDefaultLotSize = 0.01               // Minimum position size
InpATRMultiplier = 1.5                 // Wider grid spacing

// Triggers
InpEnableTimeTrigger = true            // Time-based only
InpEnableTrailingTrigger = false       // Disable advanced triggers
InpEnableDCATrigger = false            // Disable advanced triggers
InpLifecycleIntervalMinutes = 15       // Slower job creation
```

### **🎯 BALANCED SETUP (INTERMEDIATE):**
```cpp
// Risk Management
InpMaxPortfolioRisk = 100.0             // Moderate total risk
InpMaxDrawdownPercent = 20.0            // Standard drawdown
InpMaxConcurrentLifecycles = 2          // Two concurrent jobs
InpMinBalancePerLifecycle = 50.0        // Standard balance requirement

// Job Settings
InpDefaultProfitTarget = 20.0           // Standard profit targets
InpDefaultStopLoss = 50.0              // Standard stop losses
InpDefaultGridLevels = 8               // Standard grid levels
InpDefaultLotSize = 0.01               // Standard position size
InpATRMultiplier = 1.2                 // Balanced grid spacing

// Triggers
InpEnableTimeTrigger = true            // Primary trigger
InpEnableTrailingTrigger = true        // Enable Plan B
InpEnableDCATrigger = false            // Plan C disabled initially
InpLifecycleIntervalMinutes = 5        // Standard job creation
InpDCAExpansionLimit = 2               // Moderate DCA limit
InpMaxRescueJobs = 2                   // Standard rescue limit
```

### **🎯 AGGRESSIVE SETUP (ADVANCED):**
```cpp
// Risk Management
InpMaxPortfolioRisk = 200.0             // Higher total risk
InpMaxDrawdownPercent = 25.0            // Higher drawdown tolerance
InpMaxConcurrentLifecycles = 3          // Multiple concurrent jobs
InpMinBalancePerLifecycle = 30.0        // Lower balance requirement

// Job Settings
InpDefaultProfitTarget = 30.0           // Higher profit targets
InpDefaultStopLoss = 75.0              // Higher stop losses
InpDefaultGridLevels = 10              // More grid levels
InpDefaultLotSize = 0.02               // Larger position size
InpATRMultiplier = 1.0                 // Tighter grid spacing

// Triggers
InpEnableTimeTrigger = true            // Primary trigger
InpEnableTrailingTrigger = true        // Enable Plan B
InpEnableDCATrigger = true             // Enable Plan C
InpLifecycleIntervalMinutes = 3        // Faster job creation
InpDCAExpansionLimit = 3               // Higher DCA limit
InpMaxRescueJobs = 3                   // More rescue jobs
```

### **🎯 TESTING SETUP:**
```cpp
// Testing Flags
InpForceCreateFirstJob = true          // Force first job
InpEnableDebugMode = true              // Detailed logging
InpBypassMarketFilters = true          // Skip market checks
InpEnableDashboard = true              // Visual monitoring

// Conservative Testing
InpMaxConcurrentLifecycles = 1         // Single job for testing
InpDefaultLotSize = 0.01               // Minimum risk
InpLifecycleIntervalMinutes = 2        // Fast testing cycles
```

---

## 📊 **PARAMETER RELATIONSHIPS**

### **🎯 RISK CALCULATION:**
```
Total Portfolio Risk = 
    (Number of Jobs × Stop Loss per Job) + 
    (DCA Risk × DCA Expansion Factor)

Example:
2 Jobs × $50 Stop Loss = $100 Base Risk
+ DCA Risk (additional $25 per job × 2 expansions) = $100 DCA Risk
= $200 Total Portfolio Risk
```

### **🎯 JOB CREATION LOGIC:**
```
New Job Created IF:
    Available Balance ≥ InpMinBalancePerLifecycle AND
    Active Jobs < InpMaxConcurrentLifecycles AND
    Portfolio Risk < InpMaxPortfolioRisk AND
    Trigger Conditions Met (Plan A/B/C)
```

### **🎯 DCA TRIGGER LOGIC:**
```
DCA Activates IF:
    Job Loss ≥ (Stop Loss × 0.5) OR
    Filled Levels ≥ (Grid Levels × 0.5)

Example: $50 Stop Loss
    DCA triggers at $25 loss OR 4/8 grid levels filled
```

### **🎯 TRAILING ACTIVATION:**
```
Trailing Starts IF:
    Job Profit ≥ (Profit Target × 0.5)

Example: $20 Profit Target
    Trailing starts at $10 profit
```

---

## 🔧 **OPTIMIZATION GUIDELINES**

### **🎯 ACCOUNT SIZE SCALING:**

#### **Small Account ($100-500):**
- Lower lot sizes (0.01)
- Fewer concurrent jobs (1-2)
- Conservative risk limits (5-10%)
- Longer intervals between jobs

#### **Medium Account ($500-2000):**
- Standard lot sizes (0.01-0.02)
- Moderate concurrent jobs (2-3)
- Balanced risk limits (10-15%)
- Standard intervals

#### **Large Account ($2000+):**
- Higher lot sizes (0.02+)
- More concurrent jobs (3-5)
- Aggressive risk limits (15-25%)
- Shorter intervals

### **🎯 MARKET CONDITION ADAPTATION:**

#### **High Volatility Markets:**
- Increase ATR multiplier (1.5-2.0)
- Reduce grid levels (5-6)
- Increase stop losses
- Longer job intervals

#### **Low Volatility Markets:**
- Decrease ATR multiplier (0.8-1.0)
- Increase grid levels (10-12)
- Decrease stop losses
- Shorter job intervals

#### **Trending Markets:**
- Enable Plan B (trailing-triggered)
- Increase profit targets
- Reduce DCA expansion limits
- Focus on trend direction

#### **Ranging Markets:**
- Disable Plan B/C initially
- Standard grid configuration
- Balanced profit/stop ratios
- Regular time-based creation

---

## 🎯 **MONITORING & ADJUSTMENT**

### **🎯 KEY METRICS TO WATCH:**
1. **Win Rate**: Percentage of profitable jobs
2. **Average Profit**: Profit per successful job
3. **Average Loss**: Loss per failed job
4. **DCA Success Rate**: Percentage of successful DCA rescues
5. **Portfolio Drawdown**: Maximum equity decline

### **🎯 ADJUSTMENT TRIGGERS:**
- **Low Win Rate (<60%)**: Increase stop losses, reduce grid levels
- **High Drawdown (>15%)**: Reduce concurrent jobs, increase intervals
- **DCA Failures**: Increase DCA expansion limits, reduce grid density
- **Slow Growth**: Increase lot sizes, reduce profit targets

### **🎯 OPTIMIZATION CYCLE:**
1. **Week 1**: Test with conservative settings
2. **Week 2**: Gradually increase risk parameters
3. **Week 3**: Enable advanced triggers (Plan B/C)
4. **Week 4**: Fine-tune based on performance data
5. **Monthly**: Review and adjust based on market conditions

---

**🎯 Proper configuration is crucial for EXP-V3 success. Start conservative, monitor performance closely, and adjust parameters gradually based on real trading results.**
