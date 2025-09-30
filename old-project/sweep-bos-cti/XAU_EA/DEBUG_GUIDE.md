# 🔧 DEBUG GUIDE: EA KHÔNG TRIGGER ENTRY

## ❌ **NGUYÊN NHÂN PHỔ BIẾN:**

### **1. SPREAD QUÁ CAO** 
```lua
// Function: SpreadUSD() trong FiltersPass()
if(sp > P.MaxSpreadUSD) return false;
```
**✅ SOLUTION:**
- **Kiểm tra:** `MaxSpreadUSD = 0.50` (default)
- **XAU spread thường:** 1.5-5.0 pips ($1.50-$5.00)
- **🔧 FIX:** Tăng `MaxSpreadUSD = 5.0` cho XAU

### **2. KILLZONE FILTER**
```lua
// Function: IsKillzone() trong FiltersPass()  
if(!IsKillzone(rates[bar].time)) return false;
```
**✅ SOLUTION:**
- **Kiểm tra:** `UseKillzones = true/false`
- **Thời gian KZ:** KZ1s=420, KZ1e=660 (7:00-11:00)
- **🔧 FIX:** Set `UseKillzones = false` để test

### **3. ROUND NUMBER FILTER**
```lua
// Function: NearRound() trong FiltersPass()
if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta))
```
**✅ SOLUTION:**
- **Kiểm tra:** `UseRoundNumber = true/false`
- **RNDelta:** 0.28-0.35 (default)
- **🔧 FIX:** Set `UseRoundNumber = false` để test

### **4. BOS DETECTION ISSUES**
```lua
// Function: DetectBOSAndArm()
// Cần: Sweep → BOS → Retest
```
**✅ SOLUTION:**
- **Kiểm tra:** `K_swing, N_bos, LookbackInternal, M_retest`
- **🔧 FIX:** Giảm `K_swing = 20`, `N_bos = 3`

### **5. DEMO ACCOUNT ISSUES**
**✅ SOLUTION:**
- **Kiểm tra:** Auto trading enabled
- **Expert Advisors:** Allow live trading
- **Symbol:** XAUUSD available và active
- **Timeframe:** M1 (default)

## 🛠️ **DEBUG STEPS:**

### **STEP 1: ENABLE DEBUG MODE**
```lua
input bool Debug = true;  // Set to true
```

### **STEP 2: SIMPLIFY FILTERS**
```lua
input bool UseKillzones = false;      // Disable KZ
input bool UseRoundNumber = false;    // Disable RN  
input double MaxSpreadUSD = 10.0;     // Increase spread limit
```

### **STEP 3: RELAXED BOS DETECTION**
```lua
input int K_swing = 20;               // Lower detection threshold
input int N_bos = 3;                  // Fewer bars for BOS
input int LookbackInternal = 8;       // Shorter lookback
input int M_retest = 2;               // Fewer retest bars
```

### **STEP 4: CHECK LOGS**
Trong Expert tab, tìm:
- `"BLOCK RN @"` - Round number blocked
- `"BLOCK KZ @"` - Killzone blocked  
- `"BLOCK Spread="` - Spread blocked
- `"BOS detected"` - BOS found
- `"Entry triggered"` - Entry executed

### **STEP 5: MANUAL VERIFICATION**
1. Check current XAU spread: **Should be < 5.0**
2. Check current time vs killzones
3. Check if price near round numbers
4. Look for recent sweep + BOS patterns

## 🎯 **RECOMMENDED SETTINGS CHO DEBUG:**

```lua
// === RELAXED SETTINGS FOR TESTING ===
input int K_swing = 15;
input int N_bos = 3; 
input int LookbackInternal = 8;
input int M_retest = 2;
input double EqTol = 0.30;
input double BOSBufferPoints = 1.0;
input bool UseKillzones = false;
input bool UseRoundNumber = false;
input double RNDelta = 0.50;
input double MaxSpreadUSD = 10.0;
input bool UsePendingRetest = false;  // Immediate entry
input bool Debug = true;
```

## 🚨 **COMMON FIXES:**

1. **Không có entry:** Giảm `K_swing`, tắt filters
2. **Entry quá ít:** Tăng `MaxSpreadUSD`, tắt `UseRoundNumber`
3. **Entry quá nhiều:** Tăng `K_swing`, bật filters
4. **Demo không hoạt động:** Check Expert Advisors settings

**📞 Support:** Gửi Expert logs với Debug=true để phân tích chi tiết.
