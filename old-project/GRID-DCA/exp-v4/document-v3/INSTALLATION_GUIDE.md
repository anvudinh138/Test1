# 🚀 EXP-V3 INSTALLATION GUIDE

## 📋 **SYSTEM REQUIREMENTS**

### **✅ MINIMUM REQUIREMENTS:**
- **MetaTrader 5**: Build 3815 or higher
- **Account Type**: Any (Demo/Live)
- **Minimum Balance**: $100 USD (recommended $500+)
- **Leverage**: 1:100 or higher (recommended 1:500)
- **Spread**: Low spread broker (< 2 pips average)

### **✅ RECOMMENDED SETUP:**
- **VPS**: For 24/7 operation
- **Stable Internet**: Reliable connection
- **Low Latency**: Close to broker servers
- **Multiple Symbols**: EURUSD, GBPUSD, USDJPY (major pairs)

---

## 📁 **FILE INSTALLATION**

### **🎯 STEP 1: DOWNLOAD FILES**
Ensure you have all required files:

```
📂 EXP-V3 Package
├── 📄 MultiLifecycleEA_v3.html (Main EA)
├── 📄 IndependentLifecycle.mqh (Core Job Class)
├── 📄 GridManager_v2.html (Grid Logic)
├── 📄 ATRCalculator.html (Spacing Calculator)
├── 📄 PortfolioRiskManager.html (Risk Management)
├── 📄 LifecycleFactory.html (Job Factory)
└── 📄 Other Service Files...
```

### **🎯 STEP 2: COPY TO MT5 DIRECTORY**

#### **Windows Installation:**
```
C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Terminal_ID]\MQL5\
├── Experts\
│   └── MultiLifecycleEA_v3.html
├── Include\
│   ├── core\
│   │   └── IndependentLifecycle.mqh
│   ├── includes\
│   │   ├── GridManager_v2.html
│   │   └── ATRCalculator.html
│   └── services\
│       ├── PortfolioRiskManager.html
│       ├── LifecycleFactory.html
│       └── [Other Services...]
```

#### **Mac Installation:**
```
~/Library/Application Support/MetaTrader 5/Bases/Default/MQL5/
├── Experts/
│   └── MultiLifecycleEA_v3.html
├── Include/
│   ├── core/
│   │   └── IndependentLifecycle.mqh
│   ├── includes/
│   │   ├── GridManager_v2.html
│   │   └── ATRCalculator.html
│   └── services/
│       ├── PortfolioRiskManager.html
│       ├── LifecycleFactory.html
│       └── [Other Services...]
```

### **🎯 STEP 3: COMPILATION**

1. **Open MetaEditor** (F4 in MT5)
2. **Navigate** to `Experts/MultiLifecycleEA_v3.html`
3. **Compile** (F7 or Ctrl+F7)
4. **Check for Errors** in the Toolbox

#### **Expected Compilation Output:**
```
✅ 0 error(s), 0 warning(s)
✅ MultiLifecycleEA_v3.ex5 generated successfully
```

#### **If Compilation Fails:**
- **Check File Paths**: Ensure all includes are in correct folders
- **Verify File Extensions**: `.html` for main files, `.mqh` for includes
- **Review Error Messages**: Fix any missing dependencies

---

## 🎛️ **EA ATTACHMENT**

### **🎯 STEP 1: CHART SETUP**
1. **Open Chart**: EURUSD H1 (recommended)
2. **Chart Settings**: 
   - Timeframe: H1 or H4
   - Auto-scroll: Enabled
   - Shift: Disabled

### **🎯 STEP 2: ATTACH EA**
1. **Navigator Panel** → **Expert Advisors**
2. **Find** `MultiLifecycleEA_v3`
3. **Drag & Drop** to chart
4. **EA Settings Dialog** will appear

### **🎯 STEP 3: BASIC CONFIGURATION**

#### **📊 PORTFOLIO RISK MANAGEMENT:**
```cpp
InpMaxPortfolioRisk = 100.0         // Total portfolio risk ($)
InpMaxDrawdownPercent = 20.0        // Max portfolio drawdown (%)
InpMaxConcurrentLifecycles = 2      // Max simultaneous jobs (START LOW)
InpMinBalancePerLifecycle = 50.0    // Min balance per job ($)
```

#### **📊 JOB CREATION RULES:**
```cpp
InpDefaultProfitTarget = 20.0       // Profit target per job ($)
InpDefaultStopLoss = 50.0          // Stop loss per job ($)
InpDefaultGridLevels = 8           // Grid levels per job
InpDefaultLotSize = 0.01           // Lot size per job
InpATRMultiplier = 1.2             // Grid spacing multiplier
InpLifecycleIntervalMinutes = 5    // Time between jobs (minutes)
```

#### **📊 JOB TRIGGERS:**
```cpp
InpEnableTimeTrigger = true        // Plan A: Time-based creation
InpEnableTrailingTrigger = false   // Plan B: Trailing-triggered (DISABLE INITIALLY)
InpEnableDCATrigger = false        // Plan C: DCA-triggered (DISABLE INITIALLY)
InpDCAExpansionLimit = 2           // DCA expansions before rescue
InpMaxRescueJobs = 2               // Max rescue jobs per original
```

#### **📊 TESTING & DEBUG:**
```cpp
InpForceCreateFirstJob = true      // ENABLE for testing
InpEnableDebugMode = true          // Enable detailed logging
InpEnableDashboard = true          // Enable on-chart display
InpBypassMarketFilters = true      // ENABLE for testing
```

### **🎯 STEP 4: ENABLE AUTO-TRADING**
1. **Click** "Enable Algo Trading" button in MT5 toolbar
2. **Verify** green "AutoTrading" indicator
3. **Check** EA smiley face on chart (should be green)

---

## ✅ **VERIFICATION CHECKLIST**

### **🎯 IMMEDIATE CHECKS:**
- [ ] **EA Attached**: Green smiley face on chart
- [ ] **Auto-Trading**: Enabled in MT5
- [ ] **No Errors**: Clean compilation
- [ ] **Log Messages**: EA initialization messages appear

### **🎯 FIRST 5 MINUTES:**
- [ ] **Job Creation**: First job created (if `InpForceCreateFirstJob = true`)
- [ ] **Grid Orders**: Limit orders appear on chart
- [ ] **Dashboard**: On-chart display shows portfolio status
- [ ] **Clean Logs**: No error messages or spam

### **🎯 FIRST HOUR:**
- [ ] **Multiple Jobs**: Additional jobs created based on time trigger
- [ ] **Order Management**: Orders placed and managed correctly
- [ ] **Risk Management**: Portfolio limits respected
- [ ] **Performance**: System running smoothly

---

## 🚨 **TROUBLESHOOTING INSTALLATION**

### **❌ COMPILATION ERRORS:**

#### **"File not found" Errors:**
```
Solution: Check file paths and folder structure
- Ensure all .mqh files are in Include/ subdirectories
- Verify .html files are in correct locations
- Check for typos in #include statements
```

#### **"Undeclared identifier" Errors:**
```
Solution: Missing dependencies
- Ensure all service files are included
- Check for circular dependencies
- Verify all required classes are defined
```

### **❌ RUNTIME ERRORS:**

#### **"Invalid volume" Errors:**
```
Solution: Lot size configuration
- Check minimum lot size for your broker
- Verify InpDefaultLotSize is valid (usually 0.01)
- Ensure account has sufficient margin
```

#### **"Invalid price" Errors:**
```
Solution: Price validation (FIXED in EXP-V3)
- Price validation system prevents this
- If still occurring, check broker specifications
- Verify symbol specifications and spreads
```

#### **"Market closed" Errors:**
```
Solution: Trading hours
- Check if market is open for your symbol
- Verify broker trading sessions
- Consider enabling InpBypassMarketFilters for testing
```

### **❌ NO JOBS CREATED:**

#### **Check Configuration:**
```cpp
InpForceCreateFirstJob = true      // Must be enabled for testing
InpMinBalancePerLifecycle = 50.0   // Must be <= account balance
InpBypassMarketFilters = true      // Bypass market conditions
```

#### **Check Logs:**
```
Look for messages like:
✅ "NEW JOB #1 CREATED (FORCE_FIRST_JOB)"
❌ "Insufficient balance for new job"
❌ "Market conditions unsuitable"
```

---

## 🎯 **POST-INSTALLATION SETUP**

### **🎯 STEP 1: INITIAL TESTING**
1. **Enable Testing Mode**:
   - `InpForceCreateFirstJob = true`
   - `InpBypassMarketFilters = true`
   - `InpEnableDebugMode = true`

2. **Start with Conservative Settings**:
   - `InpMaxConcurrentLifecycles = 1` (single job)
   - `InpDefaultLotSize = 0.01` (minimum)
   - `InpDefaultStopLoss = 50.0` (reasonable limit)

3. **Monitor for 1 Hour**:
   - Verify job creation and grid setup
   - Check order placement and management
   - Observe DCA and trailing behavior

### **🎯 STEP 2: GRADUAL SCALING**
1. **Increase Concurrent Jobs**: 1 → 2 → 3 (max recommended: 5)
2. **Enable Advanced Triggers**: Plan B and C after basic testing
3. **Optimize Parameters**: Based on initial results
4. **Scale Position Sizes**: Increase lot sizes gradually

### **🎯 STEP 3: PRODUCTION DEPLOYMENT**
1. **Disable Testing Flags**:
   - `InpForceCreateFirstJob = false`
   - `InpBypassMarketFilters = false`
   - `InpEnableDebugMode = false` (optional)

2. **Set Production Parameters**:
   - Appropriate risk levels for account size
   - Realistic profit targets and stop losses
   - Suitable number of concurrent jobs

3. **Enable Monitoring**:
   - CSV export for trade analysis
   - Dashboard for real-time monitoring
   - Regular log review for issues

---

## 📞 **INSTALLATION SUPPORT**

### **🎯 BEFORE CONTACTING SUPPORT:**
1. **Review Error Messages**: Check compilation and runtime logs
2. **Verify File Structure**: Ensure all files are in correct locations
3. **Test Basic Functionality**: Follow verification checklist
4. **Check Documentation**: Review configuration guides

### **🎯 INFORMATION TO PROVIDE:**
- **MT5 Build Number**: Help → About
- **Account Type**: Demo/Live, Broker name
- **Error Messages**: Complete compilation/runtime errors
- **Configuration**: EA input parameters used
- **Log Files**: Recent Expert Advisor logs

---

**🎯 Successful installation should result in a smoothly operating multi-lifecycle system with clean logs, proper job creation, and effective risk management. Take time to verify each step before proceeding to production use.**
