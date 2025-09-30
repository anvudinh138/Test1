# 🔧 CTI Debug Guide - Troubleshooting BOS/CHoCH/FVG Issues

## 🚨 Vấn Đề: "Ko thấy BOS, FVG, CHoCH"

Chart hiện tại chỉ hiển thị **HH, HL, LH** labels mà không thấy các signals khác. Đây là vấn đề thường gặp với logic detection phức tạp.

## 🛠️ Debug Tools Đã Tạo:

### 1. `CTI_Debug_Simple.mq5` - Basic BOS/CHoCH Testing
```
✅ Simplified swing detection
✅ Clear trend change logic  
✅ Immediate CHoCH detection
✅ Debug prints to Experts tab
✅ Simplified BOS detection
```

### 2. `CTI_FVG_Simple.mq5` - Pure FVG Detection
```
✅ Simple 3-candle FVG pattern
✅ Visual rectangles với labels
✅ Debug info cho mỗi FVG found
✅ Configurable minimum size
✅ No dependencies trên swing logic
```

## 🎯 Debug Steps:

### Step 1: Test Basic Structure
```
1. Attach CTI_Debug_Simple.mq5 to chart
2. Check Experts tab for debug messages:
   "[CTI Debug] Added swing: HIGH at..."
   "[CTI Debug] Structure: HH at..."
   "[CTI Debug] CHoCH detected: CHoCH↑ at..."
3. Verify swing points appear: H/L dots
4. Look for structure labels: HH/HL/LH/LL
5. Watch for CHoCH labels: CHoCH↑/CHoCH↓
```

### Step 2: Test FVG Detection
```
1. Attach CTI_FVG_Simple.mq5 to chart
2. Check Experts tab cho:
   "[FVG Debug] Bullish FVG at bar..."
   "[FVG Debug] Bearish FVG at bar..."
3. Look for blue/pink rectangles
4. Verify FVG labels: FVG↑/FVG↓
```

### Step 3: Debug Parameters
```
// Nếu không thấy signals, adjust:
SwingLookback = 2-3 (nhỏ hơn = more signals)
MinFVGSize = 2-3 points (nhỏ hơn = more FVGs)
DebugMode = true (enable logging)
```

## 🔍 Common Issues & Fixes:

### Issue 1: Không Thấy Swing Points
```
❌ Problem: SwingLookback quá lớn
✅ Solution: Giảm xuống 2-3
❌ Problem: Market không volatile đủ
✅ Solution: Test trên higher timeframe
```

### Issue 2: Có Swing Nhưng Không Có CHoCH
```
❌ Problem: Trend change logic quá strict
✅ Solution: Check debug messages
   - "Structure: HL" should trigger CHoCH↑
   - "Structure: LH" should trigger CHoCH↓
```

### Issue 3: Không Thấy FVG
```
❌ Problem: MinFVGSize quá lớn
✅ Solution: Set = 1-2 points để test
❌ Problem: Market không có gaps
✅ Solution: Test trên volatile sessions
```

### Issue 4: Objects Không Hiển Thị
```
❌ Problem: Object prefix conflicts
✅ Solution: Check objPrefix unique
❌ Problem: Chart object limit
✅ Solution: CleanupObjects() regularly
```

## 📊 Expected Debug Output:

### Successful Swing Detection:
```
[CTI Debug] Added swing: HIGH at 2025.06.13 10:30 price 1.08450
[CTI Debug] Added swing: LOW at 2025.06.13 11:15 price 1.08320
[CTI Debug] Structure: HL at 2025.06.13 11:45 Trend: BULL
[CTI Debug] CHoCH detected: CHoCH↑ at 2025.06.13 11:45
```

### Successful FVG Detection:
```
[FVG Debug] Bullish FVG at bar 125 Time: 2025.06.13 12:00
Top: 1.08420 Bottom: 1.08380 Size: 4.0 points
```

## 🎮 Debug Workflow:

### Phase 1: Verify Basic Function
```
1. Use CTI_Debug_Simple.mq5
2. Enable DebugMode = true
3. Watch Experts tab for messages
4. Verify visual elements appear
```

### Phase 2: Test Individual Components
```
1. Test FVG detection với CTI_FVG_Simple.mq5
2. Look for rectangles on chart
3. Check debug messages cho pattern details
```

### Phase 3: Identify Root Cause
```
If Step 1 works but main indicator doesn't:
→ Complex logic issue in CTI_Strategy_Complete.mq5

If Step 1 doesn't work:
→ Basic swing detection problem

If Step 2 doesn't work:
→ FVG logic issue
```

## 🔧 Quick Fixes:

### Fix 1: Reduce Swing Sensitivity
```cpp
// In any indicator inputs:
SwingLookback = 2;        // Instead of 5
MinFVGSize = 1.0;        // Instead of 5.0
```

### Fix 2: Enable All Debug
```cpp
// Enable in inputs:
DebugMode = true;
ShowSwingPoints = true;
ShowStructure = true;
ShowBOS = true;
ShowCHoCH = true;
ShowFVG = true;
```

### Fix 3: Check Timeframe
```
// Test on different timeframes:
M1: Very sensitive, many signals
M5: Good for testing
M15: Cleaner signals
H1: Fewer but stronger signals
```

## 🎯 Troubleshooting Matrix:

| Symptom | Possible Cause | Debug Tool | Solution |
|---------|---------------|------------|----------|
| No H/L dots | Swing detection failed | CTI_Debug_Simple | Reduce SwingLookback |
| No HH/HL/LH/LL | Structure logic issue | CTI_Debug_Simple | Check debug messages |
| No CHoCH | Trend change logic | CTI_Debug_Simple | Verify HL/LH formation |
| No FVG rectangles | FVG detection failed | CTI_FVG_Simple | Reduce MinFVGSize |
| No debug messages | Debug not enabled | Both tools | Set DebugMode = true |

## 📈 Testing Recommendations:

### Best Timeframes for Testing:
```
✅ M5: Good balance of signals vs noise
✅ M15: Clear structure formation
✅ H1: Strong trend changes
❌ M1: Too noisy for initial testing
❌ D1: Too few signals
```

### Best Market Conditions:
```
✅ Trending markets: Clear structure
✅ Volatile sessions: More FVGs
✅ News events: Strong BOS/CHoCH
❌ Sideways markets: Confusing signals
❌ Low volume periods: Weak patterns
```

## 🚀 Next Steps:

### If Debug Tools Work:
```
1. Fix logic in CTI_Strategy_Complete.mq5
2. Compare working vs non-working code
3. Simplify complex detection algorithms
4. Add more debug prints to main indicator
```

### If Debug Tools Don't Work:
```
1. Check MT5 terminal settings
2. Verify indicator compilation
3. Test on different symbols
4. Check for EA/Script conflicts
```

---

## 🎯 Success Criteria:

**Phase 1 Success**: CTI_Debug_Simple shows H/L dots + HH/HL/LH/LL labels + CHoCH signals ✅

**Phase 2 Success**: CTI_FVG_Simple shows colored rectangles với FVG labels ✅

**Final Success**: Main indicator combines all elements correctly ✅

**Debug these tools first, then we'll fix the main strategy! 🔧📈**
