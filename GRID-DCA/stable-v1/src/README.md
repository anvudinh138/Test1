# FlexGridDCA EA - Source Code

## 📁 File Structure

```
src/
├── ea/
│   └── FlexGridDCA_EA.mq5     # Main Expert Advisor
├── includes/
│   ├── ATRCalculator.mqh      # ATR calculation system
│   └── GridManager.mqh        # Grid management system
└── README.md                  # This file
```

## 🚀 Quick Start Guide

### 1. Installation trong MT5
```bash
1. Mở MetaEditor trong MT5
2. Copy toàn bộ folder includes/ vào MQL5/Include/
3. Copy FlexGridDCA_EA.mq5 vào MQL5/Experts/
4. Compile EA trong MetaEditor (F7)
5. Restart MT5
```

### 2. Setup trên Chart
```bash
1. Drag FlexGridDCA_EA từ Navigator vào EURUSD chart
2. Chọn timeframe H1 (recommended)
3. Điều chỉnh inputs theo config/EURUSD_Config.txt
4. Enable Expert Advisors trong Tools > Options
5. Click OK để start
```

## ⚙️ Core Components

### ATRCalculator.mqh
**Tính năng:**
- Multi-timeframe ATR calculation (M1, M15, H1, H4, D1)
- Normalized ATR for universal symbol support
- Volatility condition assessment
- Grid spacing calculations

**Key Methods:**
```cpp
bool Initialize(string symbol)           // Setup ATR handles
bool UpdateATRValues()                   // Update all timeframes
double GetATR(ENUM_TIMEFRAMES tf)        // Get specific ATR
double GetNormalizedATR(ENUM_TIMEFRAMES) // ATR as % of price
bool IsVolatilityNormal()                // Check volatility range
```

### GridManager.mqh
**Tính năng:**
- Fibonacci-based grid level calculation
- Fixed lot size support (safe for high margin)
- Automatic order placement and management
- DCA integration ready

**Key Methods:**
```cpp
bool Initialize(string symbol, double lot, int levels)  // Setup grid
bool SetupGrid(double base_price, double atr_mult)      // Create levels
bool PlaceGridOrders()                                  // Place pending orders
void UpdateGridStatus()                                 // Check filled orders
bool CloseAllGridPositions()                           // Emergency close
```

### FlexGridDCA_EA.mq5
**Tính năng:**
- Complete EA shell with all integrations
- Fixed lot size protection
- Profit target management
- Risk controls and filters
- Timer-based status monitoring

## 🔧 Configuration

### Input Parameters
```cpp
// Basic Settings
InpFixedLotSize = 0.01;         // SAFE for high margin
InpMaxGridLevels = 5;           // Conservative start
InpATRMultiplier = 1.0;         // Grid spacing

// Risk Management  
InpMaxAccountRisk = 10.0;       // Max account exposure
InpProfitTargetPercent = 5.0;   // Take profit level
InpMaxSpreadPips = 3.0;         // Spread filter

// Time Filters
InpUseTimeFilter = false;       // 24/7 trading
InpStartHour = 8;               // London open
InpEndHour = 18;                // NY close
```

## 🎯 Strategy Logic

### Grid Placement
1. **Base Price**: Current market price
2. **Spacing**: ATR(H1) × ATR_Multiplier  
3. **Levels**: Fibonacci ratios (0.236, 0.382, 0.618, 1.0, 1.618)
4. **Buy Levels**: Below current price
5. **Sell Levels**: Above current price

### DCA Integration
- First level: Normal grid entry
- Subsequent levels: DCA averaging  
- Fixed lot size prevents exponential risk
- Cost basis tracking for profit calculation

### Risk Management
- **Fixed Lot Size**: Prevents account explosion
- **Max Levels**: Limits total exposure
- **Spread Filter**: Avoids high cost entries
- **Volatility Filter**: Skips dangerous conditions
- **Profit Target**: Automatic profit taking

## 📊 Expected Behavior cho EURUSD

### Normal Market Conditions
```
ATR H1: ~50-100 pips
Grid Spacing: 50-100 pips (1.0x ATR)
Max Exposure: 5 levels × 0.01 lot = 0.05 lots
Risk per Grid: ~5-10 pips × 0.05 lots = minimal
```

### Grid Example (nếu EURUSD = 1.1000)
```
Sell Levels:
1.1100 (Level 4 - 1.618 ATR)
1.1062 (Level 3 - 1.0 ATR)
1.1038 (Level 2 - 0.618 ATR)
1.1023 (Level 1 - 0.382 ATR)

Current: 1.1000

Buy Levels:
1.0977 (Level 1 - 0.382 ATR)
1.0962 (Level 2 - 0.618 ATR)
1.0938 (Level 3 - 1.0 ATR)
1.0900 (Level 4 - 1.618 ATR)
```

## ⚠️ Safety Features

### Anti-Explosion Protection
```cpp
// Fixed lot size - no martingale risk
InpFixedLotSize = 0.01;  // Same size all levels

// Limited levels - capped exposure  
InpMaxGridLevels = 5;    // Max 5 positions

// Profit target - regular profit taking
InpProfitTargetPercent = 5.0;  // Close all at 5% gain
```

### Market Condition Filters
```cpp
// Spread protection
if(spread > InpMaxSpreadPips) return false;

// Volatility protection  
if(!IsVolatilityNormal()) return false;

// Time-based filters (optional)
if(hour < InpStartHour || hour >= InpEndHour) return false;
```

## 🧪 Testing Workflow

### 1. Demo Testing (1-2 weeks)
```bash
1. Load EA on EURUSD H1 demo account
2. Use config/EURUSD_Config.txt settings
3. Monitor daily via Experts log
4. Check Journal for any errors
5. Analyze profit/loss patterns
```

### 2. Live Testing (Start small)
```bash
1. Use minimum account size
2. Keep InpFixedLotSize = 0.01
3. Monitor closely for 1 week
4. Gradually increase if successful
5. Document performance metrics
```

## 📈 Performance Monitoring

### Key Metrics to Track
- **Total Profit**: Target 5% per cycle
- **Max Drawdown**: Should be < 5%
- **Win Rate**: Expect 60-70%
- **Grid Fill Rate**: How often levels fill
- **ATR Accuracy**: Grid spacing effectiveness

### Log Analysis
```bash
# Check EA logs for:
- Grid setup confirmations
- Order placement success
- Fill notifications  
- Profit target achievements
- Error messages or warnings
```

## 🔧 Customization Options

### Easy Modifications
```cpp
// Adjust risk per position
InpFixedLotSize = 0.02;  // Double the exposure

// More aggressive grid
InpMaxGridLevels = 8;    // More levels
InpATRMultiplier = 0.8;  // Tighter spacing

// Faster profit taking
InpProfitTargetPercent = 3.0;  // 3% instead of 5%
```

### Advanced Modifications
- Add news filter integration
- Implement killzone detection  
- Add trailing stop logic
- Multi-symbol adaptation
- Progressive lot sizing (careful!)

## 🚨 Troubleshooting

### Common Issues
```bash
# EA not trading:
- Check Expert Advisors enabled
- Verify AutoTrading button active
- Check spread filter (may be too restrictive)
- Ensure sufficient margin

# Orders not filling:
- Check price levels vs current market
- Verify order types (LIMIT orders)
- Check broker execution mode
- Review slippage settings

# Unexpected behavior:
- Check Journal tab for errors
- Review input parameters
- Verify ATR calculations
- Check position management
```

### Debug Mode
```cpp
// Add to OnTick() for detailed logging:
if(TerminalInfoInteger(TERMINAL_DEBUG_MODE))
{
    g_atr_calculator.PrintATRInfo();
    g_grid_manager.PrintGridInfo();
}
```

---

**📞 Next Steps:**
1. Test trên demo account với EURUSD
2. Monitor performance metrics
3. Adjust parameters based on results  
4. Scale up gradually if successful
5. Consider multi-symbol expansion

**⚠️ Remember:** Fixed lot size là safety net chính để tránh cháy account với high margin. Luôn test kỹ trước khi tăng exposure!
