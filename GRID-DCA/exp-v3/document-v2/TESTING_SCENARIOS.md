# 🧪 TESTING SCENARIOS - PLAN B & C

## 🎯 **PROBLEM SOLVED:**

### **❌ Previous Issue:**
```
Plan B & C: 0 trade -> available_balance < InpMinBalancePerLifecycle ($100)
```

### **✅ Solution Implemented:**
```cpp
// 1. REDUCED balance requirement
InpMinBalancePerLifecycle = 50.0;   // $100 → $50

// 2. RESCUE JOBS get 50% discount
if(creation_reason == "DCA_EXPANSION_LIMIT" || creation_reason == "TRAILING_TRIGGERED")
{
    required_balance = InpMinBalancePerLifecycle * 0.5; // $25 for rescue jobs
}

// 3. SMARTER DCA trigger
InpDCAExpansionLimit = 2;  // Trigger when DCA expanded 2+ times (not just active)
```

---

## 🧪 **TEST SCENARIOS:**

### **📋 PLAN A: TIME-BASED (BASELINE)**
```cpp
// Settings:
InpEnableTimeTrigger = true;
InpEnableTrailingTrigger = false;
InpEnableDCATrigger = false;
InpLifecycleIntervalMinutes = 5;

// Expected Result:
✅ New job every 5 minutes
✅ Logs: "🚀 NEW JOB #X CREATED (TIME_BASED)"
```

---

### **🏃 PLAN B: TRAILING-TRIGGERED**
```cpp
// Settings:
InpEnableTimeTrigger = false;        // ❌ Disable time-based
InpEnableTrailingTrigger = true;     // ✅ Enable trailing trigger
InpEnableDCATrigger = false;
InpDefaultProfitTarget = 10.0;       // Lower target for faster testing

// Test Steps:
1. Wait for Job #1 to reach $10 profit
2. Job #1 enters LIFECYCLE_TRAILING state
3. System should detect HasTrailingLifecycle() = true
4. New Job #2 should be created automatically

// Expected Logs:
✅ "Job #1 profit reached, entering trailing mode"
✅ "🚀 NEW JOB #2 CREATED (TRAILING_TRIGGERED)"
✅ "📊 Active Jobs: 2/3"

// Balance Check:
✅ Job #2 needs only $25 (50% discount for rescue jobs)
```

---

### **🚨 PLAN C: DCA EXPANSION LIMIT**
```cpp
// Settings:
InpEnableTimeTrigger = false;
InpEnableTrailingTrigger = false;
InpEnableDCATrigger = true;          // ✅ Enable DCA trigger
InpDCAExpansionLimit = 2;            // Trigger after 2 DCA expansions
InpMaxRescueJobs = 2;

// Test Steps:
1. Wait for Job #1 to lose money and trigger DCA (1st expansion)
2. Market continues against Job #1, triggers 2nd DCA expansion
3. System should detect GetDCAExpansions() >= 2
4. New rescue Job #2 should be created

// Expected Logs:
✅ "🔍 DCA DEBUG - SELL: expansions=1"
✅ "🔍 DCA DEBUG - SELL: expansions=2"  
✅ "🚨 JOB #1 reached DCA expansion limit: 2/2"
✅ "🚀 NEW JOB #2 CREATED (DCA_EXPANSION_LIMIT)"

// Smart Logic:
✅ Only creates rescue job when DCA has FAILED multiple times
✅ Not just when DCA is active (too early)
```

---

### **🔄 PLAN D: HYBRID (ADVANCED)**
```cpp
// Settings:
InpEnableTimeTrigger = true;         // ✅ All triggers enabled
InpEnableTrailingTrigger = true;     // ✅ Maximum flexibility  
InpEnableDCATrigger = true;          // ✅ Adaptive system
InpMaxRescueJobs = 2;

// Expected Behavior:
✅ Creates jobs based on ANY trigger condition
✅ Time-based: Every 5 minutes
✅ Trailing: When profitable jobs trail
✅ DCA: When jobs fail DCA expansion limit
✅ Smart balance management for rescue jobs
```

---

## 🎯 **KEY IMPROVEMENTS:**

### **💰 BALANCE MANAGEMENT:**
```cpp
// BEFORE: Fixed $100 requirement
if(available_balance < 100.0) return;

// AFTER: Dynamic requirements
double required_balance = InpMinBalancePerLifecycle;  // $50
if(rescue_job) required_balance *= 0.5;              // $25 for rescue
```

### **🚨 SMARTER DCA TRIGGER:**
```cpp
// BEFORE: Trigger when DCA active (too early)
if(HasDCALifecycle()) CreateRescueJob();

// AFTER: Trigger when DCA expansion limit reached (intelligent)
if(GetDCAExpansions() >= InpDCAExpansionLimit) CreateRescueJob();
```

### **🏃 TRAILING DETECTION:**
```cpp
// NEW: Detect when jobs are trailing profits
bool HasTrailingLifecycle()
{
    return any_job.GetState() == LIFECYCLE_TRAILING;
}
```

---

## 🔧 **TESTING CHECKLIST:**

### **✅ PLAN B TESTING:**
- [ ] Disable time trigger
- [ ] Enable trailing trigger  
- [ ] Set low profit target ($10)
- [ ] Wait for job to profit
- [ ] Verify new job created when trailing starts
- [ ] Check balance requirement ($25 vs $50)

### **✅ PLAN C TESTING:**
- [ ] Disable time & trailing triggers
- [ ] Enable DCA trigger
- [ ] Set DCA expansion limit = 2
- [ ] Force market against job (manual or news)
- [ ] Wait for 2 DCA expansions
- [ ] Verify rescue job created
- [ ] Check max rescue limit (2 jobs max)

### **✅ PLAN D TESTING:**
- [ ] Enable all triggers
- [ ] Test multiple scenarios simultaneously
- [ ] Verify no conflicts between triggers
- [ ] Check balance management across all job types

---

## 🎯 **SUCCESS METRICS:**

### **📊 PLAN B SUCCESS:**
```
✅ Job #1: $10 profit → TRAILING
✅ Job #2: Created automatically (TRAILING_TRIGGERED)
✅ Balance: $25 requirement (not $50)
✅ Timing: Immediate (not waiting 5 minutes)
```

### **📊 PLAN C SUCCESS:**
```
✅ Job #1: 2 DCA expansions → FAILING
✅ Job #2: Created automatically (DCA_EXPANSION_LIMIT)  
✅ Logic: Only after multiple DCA failures (not first DCA)
✅ Limit: Max 2 rescue jobs per original
```

---

## 🚀 **READY TO TEST!**

**The framework is complete. Choose your test:**

1. **🏃 Plan B**: Test trailing-triggered job creation
2. **🚨 Plan C**: Test DCA expansion limit job creation  
3. **🔄 Plan D**: Test hybrid multi-trigger system

**All balance issues have been resolved!** 💰✅
