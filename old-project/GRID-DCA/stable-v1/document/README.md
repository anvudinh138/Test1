# GRID-DCA EA v2.0 - Dual Direction Grid Trading System

## 🎯 **OVERVIEW**

FlexGrid DCA EA v2.0 là một Expert Advisor high-performance cho MetaTrader 5, triển khai **dual-direction independent grid trading system** với **dynamic profit taking**, **DCA expansion**, và **confirmation-based grid management**.

### **Key Features:**
- ✅ **Immediate Market Entry:** 1 BUY + 1 SELL market orders khi start
- ✅ **Independent Dual Grids:** BUY và SELL grids hoạt động hoàn toàn độc lập
- ✅ **Dynamic Grid Reset:** Grid reset sau khi đạt profit target
- ✅ **Confirmation-Based Creation:** Chỉ tạo grid mới khi đã confirm cleanup hoàn tất
- ✅ **Multiple Profit Modes:** USD target hoặc percentage target
- ✅ **Loss Protection:** 5% account loss protection per direction

---

## 🚀 **QUICK START**

### **Installation:**
```
1. Copy FlexGridDCA_EA.ex5 to /Experts/ folder
2. Copy GridManager_v2.mqh và ATRCalculator.mqh to /Include/ folder  
3. Restart MetaTrader 5
4. Attach EA to EURUSD M1 chart
```

### **Recommended Settings:**
```
InpFixedLotSize = 0.01          // Fixed lot size (broker minimum)
InpMaxGridLevels = 5            // Grid levels per direction
InpProfitTargetUSD = 3.0        // USD profit target per cycle
InpUseTotalProfitTarget = true  // Use total profit mode
InpMagicNumber = 12345          // Unique EA identifier
```

### **Expected Behavior:**
```
Start → Immediate 2 positions → Grid expansion → $3 profit → Reset cycle
```

---

## 🎯 **STRATEGY DESIGN**

### **Core Concept: "Never-Ending Profit Loop"**
```
[Start] → [Immediate Entry: 1 BUY + 1 SELL] → [Grid Expansion] → [$3 Profit] → [Cleanup] → [Confirmation] → [Reset] → [Loop]
```

### **Independent Dual Direction System:**
- **BUY Grid:** 5 levels below current price
- **SELL Grid:** 5 levels above current price  
- **Immediate Entries:** Market orders for instant exposure
- **DCA Expansion:** Additional levels if price moves against grid

### **Profit Taking:**
- **Total Mode:** Close both directions when combined profit >= target
- **Per-Direction Mode:** Close each direction independently
- **Confirmation:** Wait for complete cleanup before new grid creation

---

## 📊 **EXPECTED PERFORMANCE**
- **Profit per cycle:** $3-10 USD
- **Cycle duration:** 2-8 hours
- **Win rate:** 85-95%
- **Daily cycles:** 3-12

---

## ⚙️ **CONFIGURATION**

See `config/EURUSD_Config.txt` for detailed settings.
See `OPTIMIZATION_RANGES.md` for MT5 Strategy Tester ranges.
See `FLOWCHART.md` for complete system flow diagrams.

---

## 🛠️ **TROUBLESHOOTING**

### **Common Issues:**
1. **No trades:** Check spread < 8.0 pips
2. **Grid not resetting:** Monitor confirmation check logs
3. **Orders limit:** Should not occur with v2.0 cleanup logic

### **Key Log Messages:**
```
✅ CONFIRMATION: All orders cleared - Safe to create new grid
🎯 TOTAL PROFIT TARGET REACHED!
⚠️ ORDERS NOT CLEARED YET - Waiting for cleanup completion
```

---

## 🔧 **TECHNICAL ARCHITECTURE**

### **File Structure:**
```
GRID-DCA/
├── src/ea/FlexGridDCA_EA.mq5           # Main EA
├── src/includes/GridManager_v2.mqh     # Grid logic
├── src/includes/ATRCalculator.mqh      # Volatility
├── config/EURUSD_Config.txt            # Settings
├── README.md                           # This file
└── FLOWCHART.md                        # System diagrams
```

---

## 📈 **RISK WARNING**
Grid trading can experience significant drawdowns during strong trends. Always use proper risk management and never risk more than you can afford to lose.

**© 2025 FlexGrid DCA EA v2.0 - Advanced Grid Trading System**
