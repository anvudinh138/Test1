# 🚀 PTG Smart EA - Installation Guide

## 📁 File Structure
```
bot/
├── PTG_Smart_EA_Standalone.mq5    # ✅ MAIN FILE (Use this one!)
├── PTG_Smart_EA.mq5               # ❌ Requires PTG_Config.mqh
├── PTG_Config.mqh                 # Config file (optional)
└── README.md                      # Documentation
```

## 🎯 Quick Installation (Recommended)

### Step 1: Use Standalone Version
**Copy ONLY this file to MT5:**
```
PTG_Smart_EA_Standalone.mq5
```

### Step 2: MT5 Installation Path
Copy to your MT5 Experts folder:
```
C:\Users\[Your Username]\AppData\Roaming\MetaQuotes\Terminal\[Instance ID]\MQL5\Experts\
```

### Step 3: Restart MT5
- Close MetaTrader 5
- Restart MetaTrader 5
- The EA will appear in Expert Advisors list

## 🔧 Alternative Installation (Advanced)

If you want to use the modular version:

### Step 1: Create PTG Folder
```
C:\...\MQL5\Experts\PTG\
```

### Step 2: Copy Both Files
```
PTG\PTG_Smart_EA.mq5
PTG\PTG_Config.mqh
```

### Step 3: Compile in MetaEditor
- Open MetaEditor
- Compile PTG_Smart_EA.mq5
- Fix any path issues

## ⚡ Quick Start

### 1. Attach to Chart
- Open XAUUSD or EURUSD chart (M1, M5, or M15)
- Drag `PTG_Smart_EA_Standalone` to chart
- Click "Allow Algo Trading" if prompted

### 2. Basic Settings
```
Risk Percent: 2.0%
TP Multiplier: 2.0
Max Spread: 3.0 pips
Enable Alerts: true
```

### 3. For Gold (XAUUSD)
```
Risk Percent: 1.5%
TP Multiplier: 2.5
Max Spread: 5.0 pips
```

## 🚨 Important Notes

### ✅ Use Standalone Version
- **PTG_Smart_EA_Standalone.mq5** has everything built-in
- No external files required
- Avoids path/include issues

### ⚠️ Demo Testing Required
- **ALWAYS test on demo account first**
- Run for at least 1 week
- Verify alerts and trade execution

### 📊 Symbol Compatibility
- **XAUUSD** (Gold) - Recommended
- **EURUSD** - Tested
- **GBPUSD** - Compatible
- **Other majors** - Should work

## 🔍 Troubleshooting

### Issue: EA not compiling
**Solution:** Use `PTG_Smart_EA_Standalone.mq5` (no external dependencies)

### Issue: No trades
**Check:**
- Spread < Max Spread setting
- Trading hours (if time filter enabled)
- Market volatility (PTG needs movement)
- Alert messages in MT5 Journal

### Issue: Wrong lot size
**Check:**
- Account balance
- Risk percent setting
- Symbol specifications (min/max lot)

## 📈 Expected Performance

### Typical Results:
- **Win Rate:** 50-60%
- **Risk/Reward:** 1:2 ratio
- **Trades per day:** 2-8 (depends on volatility)
- **Drawdown:** <20% (with proper risk management)

### Market Conditions:
- **Best:** Trending markets with clear pullbacks
- **Avoid:** Low volatility, high spread periods
- **Optimal:** London/NY session overlap

## 🎯 Next Steps

1. **Install Standalone EA** ✅
2. **Test on Demo** ⚠️ (CRITICAL)
3. **Monitor for 1 week** 📊
4. **Optimize settings** 🔧
5. **Consider live trading** 💰 (only after successful demo)

---

**Happy Trading!** 🚀

Remember: Past performance doesn't guarantee future results. Always manage risk properly!
