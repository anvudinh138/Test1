# UC 600-1199 Testing Guide

## 🎯 **OVERVIEW**
- **600 Use Cases** generated automatically for multi-symbol testing
- **Range**: UC 600-1199 (600 total)
- **Symbols**: EURUSD (600-799), USDJPY (800-999), BTCUSD (1000-1199)
- **CSV Export**: Automatic generation for batch optimization

## 📋 **PRESET RANGES**
```
UC 600-799:  EURUSD (200 presets)
UC 800-999:  USDJPY (200 presets) 
UC 1000-1199: BTCUSD (200 presets)
```

## 🚀 **HOW TO USE**

### **1. Single Test**
```
PresetID = 650  // Test specific EURUSD preset
UsePreset = true
```

### **2. Generate CSV File**
```
PresetID = 600  // Run UC 600 to generate CSV
Filename = "Usecases_600_1199.csv"
```
- CSV file will be created in `MQL5/Files/` folder
- Contains all 600 use cases with parameters

### **3. Batch Optimization**
1. Set MetaTrader Strategy Tester to **Optimization mode**
2. Set optimization parameter:
   ```
   PresetID: Start=600, Step=1, Stop=1199
   ```
3. Run optimization to test all 600 presets

## 📊 **CSV FORMAT**
```csv
PresetID,Symbol,K_swing,N_bos,M_retest,EqTol_pips,UseRoundNumber,RNDelta_pips,UseKillzones,RiskPerTradePct,TrailMode,SL_Buffer_pips,BOSBuffer_pips,UsePendingRetest,RetestOffset_pips,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,UsePyramid,MaxAdds,AddSizeFactor,AddSpacing_pips,MaxOpenPositions,TimeStopMinutes,MinProgressR
```

## 🔧 **PARAMETER RANGES**

### **EURUSD (600-799)**
- K_swing: 40-70
- N_bos: 6-8  
- M_retest: 3-4
- EqTol: 1.5-3.0 pips
- RNDelta: 2.0-3.0 pips
- Risk: 0.3-0.5%

### **USDJPY (800-999)**  
- K_swing: 40-70
- N_bos: 6-8
- M_retest: 3-4
- EqTol: 1.0-2.0 pips
- RNDelta: 2.0-3.0 pips
- Risk: 0.3-0.5%

### **BTCUSD (1000-1199)**
- K_swing: 35-75
- N_bos: 6-9
- M_retest: 3-5
- EqTol: 1.0-2.0 pips (scaled to $10-20)
- RNDelta: 2.0-4.0 pips (scaled to $20-40)
- Risk: 0.3-0.5%

## ⚠️ **IMPORTANT NOTES**

1. **CSV Generation**: Only runs when PresetID = 600
2. **Symbol Override**: Each preset automatically sets `SelectedSymbol`
3. **Pip Scaling**: All parameters auto-scaled per symbol
4. **Optimization**: Use Strategy Tester optimization mode, NOT single test
5. **File Location**: CSV saved to `MQL5/Files/Usecases_600_1199.csv`

## 🐛 **TROUBLESHOOTING**

### "No optimized parameter selected"
- **Solution**: Set PresetID as optimization parameter in Strategy Tester
- **Range**: Start=600, Step=1, Stop=1199

### CSV not generated
- **Solution**: Run single test with PresetID=600 first
- **Check**: MQL5/Files/ folder for output file

### Invalid volume errors
- **Solution**: Parameters auto-scaled, but check broker specs
- **Note**: BTC may need larger minimum lots

## 📈 **EXPECTED RESULTS**
- **EURUSD**: Moderate PF (1.2-2.0), many trades
- **USDJPY**: Variable PF, momentum-based
- **BTCUSD**: Higher volatility, fewer but larger trades

## 🎯 **NEXT STEPS**
1. Generate CSV with UC 600
2. Run optimization 600-1199  
3. Analyze top performers per symbol
4. Create refined preset ranges based on results
