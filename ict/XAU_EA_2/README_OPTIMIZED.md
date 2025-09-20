# XAU EA v1.2 - Optimized Version 🚀

## 🎯 Tổng Quan

Đây là phiên bản tối ưu của EA XAU dựa trên **feedback analysis** từ backtest trước đó. Code đã được **refactor** và **simplified** để tập trung vào những yếu tố thực sự hiệu quả.

## ✅ Cải Tiến Chính

### 🔥 **Loại Bỏ Các Yếu Tố Không Hiệu Quả:**
- ❌ **Bỏ FVG** - 100% sử dụng Order Block (POIType removed)
- ❌ **Bỏ OB_MustHaveImbalance option** - Mặc định true (hardcoded)
- ❌ **Bỏ News Filter options** - Mặc định enabled với settings cố định
- ❌ **Bỏ HTF_EMA_Method** - Mặc định EMA (hardcoded)

### 🎯 **Tập Trung Vào "Vùng Vàng":**
- ✅ **K_swing**: 40-70 (thay vì 20-100)
- ✅ **N_bos**: 5-9 (thay vì 3-12)
- ✅ **LookbackInternal**: 10-16 (thay vì 5-20)
- ✅ **TP2_R**: 2.2-4.5 (thay vì 1.0-5.0)

### 🔧 **Tinh Chỉnh Entry Offset:**
- ✅ **EntryOffsetPips**: 0.0-0.5 (fine-tuning chính xác)
- ✅ **HTF_EMA_Period**: 20, 50, 100 (3 giá trị tối ưu)
- ✅ **RiskPerTradePct**: 0.3%, 0.5%, 0.8% (risk management)

## 📁 Files Trong Package

### Core Files:
- `FX_SweepBOS_EA_v1_sprint_2_EXP.lua` - EA đã được refactor
- `UC_100_optimized.csv` - 100 UC tối ưu theo feedback
- `preset_optimized_sample.csv` - Sample preset để test

### Tools:
- `generate_100_optimized_uc.py` - Script tạo UC tối ưu
- `README_OPTIMIZED.md` - Documentation này

## 🚀 Cách Sử Dụng

### Bước 1: Copy Files
```bash
# Copy UC file vào MetaTrader
cp UC_100_optimized.csv /path/to/MetaTrader/Files/t1.csv
```

### Bước 2: Test Sample Preset
```bash
# Copy sample preset để test nhanh
cp preset_optimized_sample.csv /path/to/MetaTrader/Files/t1.csv
```

### Bước 3: Chạy Backtest
1. Load EA trong Strategy Tester
2. Set `PresetID = 1` (hoặc 1-100)
3. Set `UsePreset = true`
4. Chạy backtest

## 📊 Cấu Trúc 100 UC Tối Ưu

### 🔵 **Core Structure Testing (UC 1-60)**
- **Mục tiêu:** Tìm cấu trúc thị trường tối ưu
- **Focus:** K_swing, N_bos, TP2_R combinations
- **Range:** Trong "vùng vàng" đã xác định

### 🟢 **Entry Offset Fine-tuning (UC 61-85)**
- **Mục tiêu:** Tối ưu điểm vào lệnh
- **Focus:** EntryOffsetPips từ 0.0 đến 0.5 pips
- **Base:** Sử dụng configs tốt nhất từ Core Structure

### 🟠 **HTF & Risk Optimization (UC 86-100)**
- **Mục tiêu:** Tối ưu HTF filter và risk management
- **Focus:** HTF_EMA_Period và RiskPerTradePct
- **Base:** Sử dụng config tốt nhất overall

## 🎯 Fixed Settings (Hardcoded)

```cpp
// Không cần config - đã được fix dựa trên feedback
const bool FIXED_UseNewsFilter = true;
const string FIXED_NewsFilter_Symbols = "USD";
const bool FIXED_NewsFilter_High = true;
const bool FIXED_NewsFilter_Medium = false;
const int FIXED_NewsFilter_MinBefore = 30;
const int FIXED_NewsFilter_MinAfter = 30;
const bool FIXED_OB_MustHaveImbalance = true;
const ENUM_MA_METHOD FIXED_HTF_EMA_Method = MODE_EMA;
```

## 📈 Expected Results

### Performance Targets:
- **Excellent:** PF > 2.0, WR > 60%, DD < 15%
- **Good:** PF > 1.5, WR > 55%, DD < 20%
- **Acceptable:** PF > 1.2, WR > 50%, DD < 25%

### Key Insights Expected:
1. **Entry Offset 0.2-0.3 pips** có thể tối ưu nhất
2. **HTF EMA 50** có thể cân bằng tốt nhất
3. **Risk 0.5%** có thể optimal cho growth/safety
4. **K_swing 50-55** có thể hiệu quả nhất với Gold
5. **TP2_R 2.5-3.0** có thể sustainable nhất

## 🔧 CSV Format Mới

```csv
Case,Symbol,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,UseKillzones,UseRoundNumber,RNDelta,RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec,CooldownSec,ATRScalingPeriod,SL_ATR_Mult,Retest_ATR_Mult,MaxSpread_ATR_Mult,RNDelta_ATR_Mult,PendingExpiryMinutes,UseHTFFilter,HTF_EMA_Period,EntryOffsetPips
```

**Removed fields:**
- `UseFVGEntry`, `FVGEntryOffsetPips` (FVG removed)
- `UseNewsFilter`, `NewsFilter_*` (hardcoded)
- `POIType`, `OB_MustHaveImbalance` (hardcoded)
- `HTF_EMA_Method` (hardcoded to EMA)

## 🎯 Workflow Tối Ưu

1. **Quick Test:** Chạy 2-3 sample presets để verify
2. **Full Run:** Chạy tất cả 100 UC
3. **Analysis:** Tìm top 10 configs
4. **Validation:** Test top configs trên out-of-sample
5. **Live Deploy:** Implement config tốt nhất

## ⚡ Performance Improvements

### Code Optimizations:
- **Reduced complexity** - Bỏ các logic không cần thiết
- **Fixed constants** - Không cần parse từ CSV
- **Simplified entry logic** - Chỉ Order Block
- **Cleaner code structure** - Dễ maintain hơn

### Testing Efficiency:
- **Focused parameters** - Chỉ test vùng vàng
- **Reduced UC count** - 100 thay vì 500
- **Higher hit rate** - Tỷ lệ configs tốt cao hơn

## 🤝 Support & Next Steps

### If Results Are Good:
1. **Scale up** lot size cho live trading
2. **Add more symbols** (EURUSD, GBPUSD)
3. **Implement portfolio** management

### If Need Further Optimization:
1. **Narrow ranges** thêm nữa
2. **Add new parameters** (trailing stop, etc.)
3. **Test different timeframes**

---

**Ready for Optimized Testing! 🎯📈**

*"Focus on what works, eliminate what doesn't."*
