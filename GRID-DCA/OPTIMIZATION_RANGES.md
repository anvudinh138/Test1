# MT5 OPTIMIZATION RANGES - FlexGridDCA EA V2

## 🎯 **Optimization Strategy cho Independent Dual Grid System**

### **⚠️ UPDATED FOR V2 DESIGN:**
- Independent Buy/Sell grids
- Dynamic grid reset after profit
- DCA expansion support  
- 5% loss protection
- Fixed 0.01 lot size

### 📊 **Primary Parameters (Tối ưu hóa chính)**

#### 1. **InpFixedLotSize** (Lot Size) - FIXED
```
Value: 0.01 (KHÔNG OPTIMIZE)
```
**Lý do:** Always fixed 0.01 (broker minimum) theo yêu cầu của bạn

#### 2. **InpMaxGridLevels** (Grid Levels)
```
Start: 3
Step:  1
Stop:  10
```
**Lý do:** Fewer levels = less risk, more levels = more opportunities

#### 3. **InpATRMultiplier** (ATR Multiplier)
```
Start: 0.5
Step:  0.2
Stop:  2.5
```
**Lý do:** Critical for grid spacing - ảnh hưởng trực tiếp đến entry frequency

#### 4. **InpProfitTargetPercent** (Profit Target % PER DIRECTION)
```
Start: 1.0
Step:  0.5
Stop:  5.0
```
**Lý do:** Per-direction profit taking, lower values = more frequent cycles

### 📈 **Secondary Parameters (Tối ưu hóa phụ)**

#### 5. **InpMaxAccountRisk** (Account Risk %)
```
Start: 5.0
Step:  2.5
Stop:  15.0
```
**Lý do:** Risk vs reward balance

#### 6. **InpMaxSpreadPips** (Max Spread)
```
Start: 5.0
Step:  1.0
Stop:  12.0
```
**Lý do:** Market condition filtering

#### 7. **InpTrailingStopATR** (Trailing Stop)
```
Start: 1.0
Step:  0.5
Stop:  3.0
```
**Lý do:** Profit protection mechanism (chỉ khi InpEnableTrailingStop = true)

### 🔄 **Boolean Parameters (On/Off Testing)**

#### 8. **InpEnableDCATrading**
```
Values: false, true
```

#### 9. **InpUseVolatilityFilter**
```
Values: false, true
```

#### 10. **InpEnableTrailingStop**
```
Values: false, true
```

#### 11. **InpUseTimeFilter**
```
Values: false, true
```

### ⏰ **Time Filter Parameters (Nếu InpUseTimeFilter = true)**

#### 12. **InpStartHour**
```
Start: 0
Step:  2
Stop:  22
```

#### 13. **InpEndHour**
```
Start: 2
Step:  2
Stop:  23
```

---

## 🚀 **Optimization Phases**

### **Phase 1: Core Parameters (Quick Test)**
Chỉ optimize 3 parameters chính:
1. InpMaxGridLevels (3-8) - Per direction
2. InpATRMultiplier (0.5-2.0) - Grid spacing
3. InpProfitTargetPercent (1-5) - Per direction profit

**Estimated combinations:** ~1,000 runs
**Time:** 2-4 hours

### **Phase 2: Risk Parameters**
Add risk management:
5. InpMaxAccountRisk (5-15)
6. InpMaxSpreadPips (5-12)

**Estimated combinations:** ~5,000 runs
**Time:** 8-12 hours

### **Phase 3: Advanced Features**
Add trailing stop và filters:
7. InpTrailingStopATR (1-3)
8. Boolean switches

**Estimated combinations:** ~20,000 runs
**Time:** 1-2 days

---

## 📋 **MT5 Strategy Tester Setup**

### **Optimization Settings:**
- **Optimization:** Complete algorithm (Genetic algorithm recommended)
- **Optimization criterion:** Balance + Profit Factor
- **Period:** 3-6 months historical data
- **Models:** Every tick (M1 basis)
- **Deposit:** 500-1000 USD
- **Currency:** USD
- **Leverage:** 1:100 or higher

### **Target Metrics:**
```
✅ Profit Factor > 1.2
✅ Maximum Drawdown < 30%
✅ Total Trades > 100
✅ Win Rate > 50%
✅ Recovery Factor > 2.0
```

---

## 🎯 **Expected Best Ranges (Based on Analysis)**

### **Conservative Setup V2 (Recommended start):**
```
InpFixedLotSize = 0.01           // Fixed (không đổi)
InpMaxGridLevels = 5             // 5 levels per direction
InpATRMultiplier = 1.0           // Standard spacing
InpProfitTargetPercent = 2.0     // 2% per direction (frequent cycles)
InpMaxAccountRisk = 10.0         // 10% account protection
InpMaxSpreadPips = 8.0           // EURUSD suitable
InpEnableDCATrading = true       // DCA expansion enabled
InpUseVolatilityFilter = false   // Disabled initially
InpEnableTrailingStop = false    // Not needed with new logic
```

### **Aggressive Setup V2 (Higher frequency):**
```
InpFixedLotSize = 0.01           // Still fixed 0.01
InpMaxGridLevels = 8             // More levels per direction
InpATRMultiplier = 0.8           // Tighter spacing
InpProfitTargetPercent = 1.5     // Frequent profit taking
InpMaxAccountRisk = 15.0         // Higher risk tolerance
InpMaxSpreadPips = 10.0          // More flexible
InpEnableDCATrading = true       // DCA expansion enabled
InpUseVolatilityFilter = false   // Keep disabled
InpEnableTrailingStop = false    // Not needed with new logic
```

---

## ⚡ **Quick Start Optimization**

**Copy paste này vào MT5 Strategy Tester V2:**

```
InpMaxGridLevels: 3, 1, 8
InpATRMultiplier: 0.6, 0.2, 2.0
InpProfitTargetPercent: 1.0, 0.5, 4.0
(InpFixedLotSize fixed at 0.01)
```

**Run này trước để có baseline results!** 🎯
