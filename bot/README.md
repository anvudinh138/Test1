# PTG Smart EA for MetaTrader 5

## 🚀 Overview
This Expert Advisor (EA) implements the PTG (Push → Test → Go) trading strategy for MetaTrader 5, converted from the original Pine Script version.

## 📊 Strategy Logic

### Core PTG Concept:
1. **PUSH**: Detect strong directional movement with high volume
2. **TEST**: Wait for pullback with low volume (consolidation)
3. **GO**: Enter trade when price breaks above/below the test range

## ⚙️ Installation

1. Copy `PTG_Smart_EA.mq5` to your MT5 `Experts` folder:
   ```
   C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Instance]\MQL5\Experts\
   ```

2. Restart MetaTrader 5

3. Drag the EA onto your chart (M1, M5, or M15 recommended)

4. Configure the parameters in the EA settings

## 🎛️ Parameters

### PTG Core Settings
- **TradingPair**: Symbol to trade (EURUSD/XAUUSD)
- **UseEMAFilter**: Enable EMA 34/55 trend filter
- **UseVWAPFilter**: Enable VWAP trend filter
- **LookbackPeriod**: Period for range calculations (default: 20)

### Push Parameters
- **PushRangePercent**: Minimum range as % of max range (default: 0.60)
- **ClosePercent**: Close position within extremes (default: 0.60)
- **OppWickPercent**: Max opposite wick size (default: 0.40)
- **VolHighMultiplier**: Volume threshold for PUSH (default: 1.2)

### Test Parameters
- **TestBars**: Max bars to wait for TEST (default: 5)
- **PullbackMax**: Max pullback allowed (default: 0.50)
- **VolLowMultiplier**: Volume threshold for TEST (default: 1.0)

### Risk Management
- **EntryBufferPips**: Entry buffer in pips (default: 0.1)
- **SLBufferPips**: Stop loss buffer in pips (default: 0.1)
- **TPMultiplier**: Take profit multiplier (default: 2.0)
- **RiskPercent**: Risk per trade as % of balance (default: 2.0)
- **MaxSpreadPips**: Maximum spread allowed (default: 3.0)

### Trading Hours
- **UseTimeFilter**: Enable time-based trading
- **StartTime**: Trading start time (default: "07:00")
- **EndTime**: Trading end time (default: "22:00")

### Alert Integration
- **EnableAlerts**: Enable MT5 alerts
- **AlertKeyword**: Keyword for TradingView integration (default: "PTG")

## 🔧 Key Features

### ✅ Automated PTG Logic
- Real-time PUSH detection with volume confirmation
- Smart TEST phase identification
- Precise GO entry with pending orders

### ✅ Risk Management
- Dynamic position sizing based on account risk
- Automatic stop loss and take profit placement
- Spread filtering for optimal execution

### ✅ TradingView Integration Ready
- Alert keyword detection
- Webhook support preparation
- External signal handling

### ✅ Professional Features
- Comprehensive logging
- Error handling
- Magic number identification
- Trade transaction monitoring

## 📈 Recommended Settings

### For XAUUSD (Gold):
```
RiskPercent = 1.0-2.0%
TPMultiplier = 2.0-3.0
MaxSpreadPips = 3.0
UseTimeFilter = true (London/NY sessions)
```

### For EURUSD:
```
RiskPercent = 2.0%
TPMultiplier = 2.0
MaxSpreadPips = 2.0
UseEMAFilter = true
```

## 🚨 Important Notes

### Risk Warning
- This EA is for educational and testing purposes
- Always test on demo account first
- Past performance doesn't guarantee future results
- Never risk more than you can afford to lose

### Optimization Tips
1. **Backtest thoroughly** on historical data
2. **Forward test** on demo account for at least 1 month
3. **Monitor performance** and adjust parameters
4. **Use proper risk management** (max 2% per trade)

## 🔗 Integration with TradingView

The EA can work standalone or receive signals from TradingView:

1. **Standalone Mode**: EA detects PTG patterns automatically
2. **Signal Mode**: Receives alerts from TradingView Pine Script
3. **Hybrid Mode**: Combines both for enhanced accuracy

### TradingView Alert Setup:
```
Alert Message: PTG LONG ENTRY - {{ticker}} | Entry: {{close}}
Alert Message: PTG SHORT ENTRY - {{ticker}} | Entry: {{close}}
```

## 📊 Performance Tracking

The EA logs:
- Entry/exit prices
- Pip profit/loss
- Risk per trade
- Win rate statistics
- Execution quality

## 🛠️ Troubleshooting

### Common Issues:
1. **No trades**: Check symbol, timeframe, and spread
2. **Orders rejected**: Verify lot size and margin
3. **Wrong signals**: Adjust PTG parameters
4. **High spread**: Increase MaxSpreadPips or trade during active hours

## 📞 Support

For questions and support:
- Check MT5 Expert tab for logs
- Verify all parameters are correct
- Test on demo account first
- Review strategy logic in TradingView

## 🎯 Next Steps

1. Install and configure the EA
2. Backtest on historical data  
3. Forward test on demo account
4. Optimize parameters for your trading style
5. Consider TradingView integration
6. Monitor and adjust as needed

---

**Good luck trading with PTG Smart EA!** 🚀📈
