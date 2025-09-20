# 500 Use Cases Systematic Testing Plan

## 📋 Tổng Quan

File `UC_500_systematic_test.csv` chứa 500 test cases được tổ chức thành 5 gia đình để kiểm tra các giả thuyết cụ thể về hiệu suất của EA.

## 🏠 Cấu Trúc Gia Đình

### 🔵 **Gia Đình 1: Order Block Testing (UC 1-100)**

**Mục tiêu:** Tìm cấu hình tối ưu cho POI Type = Order Block

**Biến số kiểm tra:**
- `K_swing`: 40, 45, 50, 55, 60 (độ nhạy phát hiện swing)
- `N_bos`: 4, 5, 6, 7, 8 (số nến tối đa để tìm BOS)
- `TP2_R`: 1.5, 2.0, 2.5, 3.0 (tỷ lệ Risk:Reward)

**Cố định:**
- `POIType = 1` (Order Block)
- `OB_MustHaveImbalance = true`
- `UseHTFFilter = false`
- `EntryOffsetPips = 0.0`

**Giả thuyết:** Order Block với imbalance sẽ cho kết quả tốt hơn khi có cấu trúc thị trường phù hợp.

---

### 🟢 **Gia Đình 2: FVG Testing (UC 101-200)**

**Mục tiêu:** Tìm cấu hình tối ưu cho POI Type = FVG

**Biến số kiểm tra:** Giống Family 1
- `K_swing`: 40, 45, 50, 55, 60
- `N_bos`: 4, 5, 6, 7, 8  
- `TP2_R`: 1.5, 2.0, 2.5, 3.0

**Cố định:**
- `POIType = 0` (FVG)
- `OB_MustHaveImbalance = false` (không áp dụng cho FVG)
- `UseHTFFilter = false`
- `EntryOffsetPips = 0.0`

**Giả thuyết:** FVG có thể cho tín hiệu nhanh hơn nhưng có thể kém chính xác hơn Order Block.

---

### 🟡 **Gia Đình 3: Imbalance Importance Test (UC 201-275)**

**Mục tiêu:** Kiểm tra tầm quan trọng của việc lọc Order Block "xịn" có FVG đi kèm

**Biến số kiểm tra:**
- `OB_MustHaveImbalance`: true vs false
- `EntryOffsetPips`: 0.0, 0.5, 1.0 (vào lệnh sâu hơn trong POI)
- `LookbackInternal`: 10, 12, 14, 16, 18 (variations)
- `BE_Activate_R`: 0.7, 0.75, 0.8, 0.85, 0.9 (variations)

**Cấu hình base:** Lấy từ các config tốt nhất của Family 1
- Config A: K_swing=50, N_bos=6, TP2_R=2.0
- Config B: K_swing=45, N_bos=5, TP2_R=2.5  
- Config C: K_swing=55, N_bos=7, TP2_R=1.8

**Giả thuyết:** Order Block có imbalance sẽ cho win rate cao hơn nhưng có thể ít tín hiệu hơn.

---

### 🟠 **Gia Đình 4: HTF Filter Impact Test (UC 276-350)**

**Mục tiêu:** Đánh giá tác động của bộ lọc xu hướng Higher Timeframe

**Biến số kiểm tra:**
- `UseHTFFilter`: true vs false
- `HTF_EMA_Period`: 20, 50, 100 (độ mượt của xu hướng)
- `TP2_R`: 1.8, 2.0, 2.5 (điều chỉnh R:R khi có filter)

**Cấu hình base:** Sử dụng các config tốt từ Family 1

**Giả thuyết:** HTF filter sẽ giảm số lượng trades nhưng tăng win rate và giảm drawdown.

---

### 🔴 **Gia Đình 5: Risk & Entry Fine-tuning (UC 351-500)**

**Mục tiêu:** Tinh chỉnh quản lý rủi ro và điểm vào lệnh

**Biến số kiểm tra:**
- `RiskPerTradePct`: 0.3%, 0.5%, 0.8%, 1.0% (mức rủi ro mỗi lệnh)
- `EntryOffsetPips`: 0.0, 0.5, 1.0, 1.5 (độ sâu vào POI)
- `BE_Activate_R`: 0.6, 0.8, 1.0 (khi nào move to breakeven)
- `TimeStopMinutes`: 3, 5, 8, 10 (timeout cho lệnh không progress)

**Cấu hình base:** Mix các config tốt nhất từ các family trước
- Best OB config: K_swing=50, N_bos=6, TP2_R=2.0, POIType=1
- Best FVG config: K_swing=45, N_bos=5, TP2_R=2.5, POIType=0  
- Alternative: K_swing=55, N_bos=7, TP2_R=1.8, POIType=1

**Giả thuyết:** Entry offset và risk management sẽ có tác động lớn đến performance cuối cùng.

---

## 📊 Phân Tích Kết Quả

### Metrics Quan Trọng Cần Theo Dõi:

1. **Win Rate** - Tỷ lệ thắng
2. **Profit Factor** - Tỷ lệ lợi nhuận
3. **Max Drawdown** - Drawdown tối đa
4. **Sharpe Ratio** - Tỷ lệ Sharpe
5. **Total Trades** - Tổng số lệnh
6. **Expected Payoff** - Lợi nhuận kỳ vọng mỗi lệnh

### So Sánh Giữa Các Gia Đình:

```
Family 1 vs Family 2: OB vs FVG performance
Family 3: Impact of imbalance filtering  
Family 4: HTF filter effectiveness
Family 5: Optimal risk/entry settings
```

### Workflow Phân Tích:

1. **Chạy backtest** cho tất cả 500 UC
2. **Sắp xếp kết quả** theo Profit Factor hoặc Sharpe Ratio
3. **Phân tích theo family** để rút ra insights
4. **Kết hợp** các yếu tố tốt nhất từ mỗi family
5. **Tạo config cuối cùng** cho live trading

---

## 🚀 Cách Sử dụng

1. **Copy file CSV** vào `MetaTrader/Files/t1.csv`
2. **Set PresetID** từ 1-500 trong EA input
3. **Chạy backtest** với từng PresetID
4. **Thu thập kết quả** từ file log CSV output
5. **Phân tích** bằng Excel/Python để tìm patterns

## 📈 Kết Quả Mong Đợi

- **Top 10%** configs sẽ có Profit Factor > 2.0
- **Order Block** có thể cho win rate cao hơn FVG
- **HTF Filter** sẽ giảm trades nhưng tăng chất lượng
- **Entry offset** 0.5-1.0 pips có thể tối ưu cho Gold
- **Risk 0.5%** có thể cân bằng tốt giữa growth và safety
