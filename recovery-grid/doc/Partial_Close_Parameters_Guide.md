# Partial Close Parameters Guide

## 📚 Overview

Partial Close là feature giúp giảm drawdown bằng cách đóng **một phần** positions của basket đang thua lỗ khi có dấu hiệu retest (giá quay đầu).

---

## 🎛️ Input Parameters Explained

### 1. **InpPcEnabled** (bool, default: `false`)
**Mô tả**: Bật/tắt toàn bộ Partial Close feature.

**Cách dùng**:
- `false`: Tắt PC → EA hoạt động như cũ (chỉ đóng khi full TP)
- `true`: Bật PC → EA sẽ đóng từng phần loser khi có cơ hội

**Khuyến nghị**:
- Backtest với `false` để có baseline
- Test với `true` để so sánh drawdown reduction

---

### 2. **InpPcRetestAtr** (double, default: `0.8`)
**Mô tả**: Hệ số ATR để xác định "retest đủ sâu".

**Công thức**:
```
retest_distance = |furthest_entry_price - current_price|
trigger_threshold = InpPcRetestAtr × ATR

Nếu retest_distance >= trigger_threshold → cho phép PC
```

**Ví dụ**:
- ATR = 50 pips
- `InpPcRetestAtr = 0.8` → cần retest ít nhất 40 pips
- Loser SELL có entry xa nhất là 1.1050
- Giá hiện tại: 1.1010 → retest = 40 pips → **trigger PC**

**Tác động**:
- **Tăng (0.8 → 1.2)**: PC ít hơn, chờ retest sâu hơn → ít risk đóng sớm
- **Giảm (0.8 → 0.5)**: PC nhiều hơn, trigger sớm → giảm DD tốt hơn nhưng có thể miss profit

**Khuyến nghị**: `0.6-0.8` cho balance tốt

---

### 3. **InpPcSlopeHysteresis** (double, default: `0.0002`)
**Mô tả**: Hysteresis cho slope momentum (hiện tại chưa implement đầy đủ).

**Tác động**: Reserved cho future enhancement (momentum-based trigger).

**Khuyến nghị**: Giữ mặc định `0.0002`

---

### 4. **InpPcMinProfitUsd** (double, default: `1.5`)
⭐ **QUAN TRỌNG** - Tham số này ảnh hưởng lớn đến performance!

**Mô tả**: PnL tối thiểu (USD) của nhóm tickets gần giá để cho phép PC.

**Cách hoạt động**:
1. EA sắp xếp tất cả positions theo khoảng cách tới giá (gần nhất trước)
2. Tính tổng PnL của `InpPcMaxTickets` tickets gần nhất
3. Nếu `total_PnL >= InpPcMinProfitUsd` → cho phép PC

**Ví dụ**:
- Loser SELL có 5 tickets:
  - Ticket A (gần nhất): PnL = -2.0
  - Ticket B: PnL = +1.0
  - Ticket C: PnL = +3.0
  - Ticket D: PnL = -5.0
  - Ticket E (xa nhất): PnL = -8.0

- `InpPcMaxTickets = 3`, `InpPcMinProfitUsd = 1.0`
- Check 3 tickets gần nhất: A + B + C = -2.0 + 1.0 + 3.0 = **+2.0 USD**
- 2.0 >= 1.0 → **Allow PC** ✅

**Backtest Results**:
- `MinProfitUsd = 1.0` (Image #1): Balance 12116, DD moderate
- `MinProfitUsd = 5.0` (Image #2): Balance 12170, DD slightly higher

**Tác động**:
- **Tăng (1.5 → 5.0)**:
  - PC ít hơn (chờ profitable tickets nhiều hơn)
  - Giữ profit tốt hơn
  - DD có thể cao hơn

- **Giảm (1.5 → 1.0)**:
  - PC nhiều hơn (dễ trigger)
  - Giảm DD tốt hơn
  - Có thể mất profit sớm

**Khuyến nghị**:
- Conservative (ít PC): `2.0-3.0`
- Balanced: `1.0-1.5`
- Aggressive (nhiều PC): `0.5-1.0`

---

### 5. **InpPcCloseFraction** (double, default: `0.30`)
**Mô tả**: Tỷ lệ tối đa của tổng lot loser được đóng mỗi lần PC.

**Ví dụ**:
- Loser có tổng lot: 1.0
- `InpPcCloseFraction = 0.30` → đóng tối đa 0.30 lot
- Nhưng còn giới hạn bởi `InpPcMaxTickets` và `InpPcMinLotsRemain`

**Tác động**:
- **Tăng (0.30 → 0.50)**: Đóng nhiều hơn mỗi lần → giảm DD nhanh hơn
- **Giảm (0.30 → 0.20)**: Đóng ít hơn → bảo toàn khả năng recovery

**Khuyến nghị**: `0.25-0.35`

---

### 6. **InpPcMaxTickets** (int, default: `3`)
**Mô tả**: Số ticket tối đa đóng trong một lần PC.

**Ví dụ**:
- Loser có 10 tickets
- `InpPcMaxTickets = 3` → chỉ đóng tối đa 3 tickets gần giá nhất

**Tác động**:
- **Tăng (3 → 5)**: Đóng nhiều tickets → giảm DD mạnh hơn
- **Giảm (3 → 2)**: Đóng ít tickets → conservative hơn

**Khuyến nghị**: `2-4` tickets

---

### 7. **InpPcCooldownBars** (int, default: `10`)
**Mô tả**: Số bars tối thiểu giữa hai lần PC.

**Lý do**: Tránh spam PC liên tục trong cùng một retest wave.

**Ví dụ**:
- Timeframe M15, `InpPcCooldownBars = 10` → cooldown = 150 phút = 2.5 giờ
- PC lần 1 lúc 10:00 → PC lần 2 sớm nhất lúc 12:30

**Tác động**:
- **Tăng (10 → 20)**: PC ít hơn, cooldown lâu hơn
- **Giảm (10 → 5)**: PC nhiều hơn, cooldown ngắn

**Khuyến nghị**: `8-15` bars

---

### 8. **InpPcGuardBars** (int, default: `6`)
**Mô tả**: Số bars phải chờ trước khi cho phép reseed vùng vừa đóng.

**Lý do**: Sau khi PC, EA cancel pending orders gần giá. Guard bars ngăn bot mở lại ngay vùng đó (tránh "đóng rồi mở lại" vô ích).

**Ví dụ**:
- PC đóng tickets ở vùng 1.1020-1.1030
- Guard active trong 6 bars (90 phút nếu M15)
- Trong thời gian này, bot KHÔNG reseed pending ở vùng đã đóng

**Tác động**:
- **Tăng (6 → 10)**: Guard lâu hơn, tránh re-enter sớm
- **Giảm (6 → 3)**: Guard ngắn, cho phép reseed nhanh hơn

**Khuyến nghị**: `5-8` bars

---

### 9. **InpPcPendingGuardMult** (double, default: `0.5`)
**Mô tả**: Hệ số nhân spacing để xác định vùng cancel pending sau PC.

**Công thức**:
```
guard_offset = spacing × InpPcPendingGuardMult
cancel_range = [current_price - guard_offset, current_price + guard_offset]
```

**Ví dụ**:
- Spacing = 30 pips
- `InpPcPendingGuardMult = 0.5` → guard_offset = 15 pips
- Giá PC: 1.1020 → cancel pending trong [1.1005, 1.1035]

**Tác động**:
- **Tăng (0.5 → 1.0)**: Cancel vùng rộng hơn
- **Giảm (0.5 → 0.3)**: Cancel vùng hẹp hơn

**Khuyến nghị**: `0.4-0.6`

---

### 10. **InpPcGuardExitAtr** (double, default: `0.6`)
**Mô tả**: Hệ số ATR để guard expire sớm nếu giá di chuyển xa.

**Cách hoạt động**:
- Guard bình thường expire sau `InpPcGuardBars` bars
- Nhưng nếu giá di chuyển >= `InpPcGuardExitAtr × ATR` → guard expire ngay

**Ví dụ**:
- ATR = 50 pips, `InpPcGuardExitAtr = 0.6` → threshold = 30 pips
- PC tại 1.1020
- Nếu giá chạy tới 1.1050 (30 pips) → guard expire ngay → cho phép reseed

**Tác động**:
- **Tăng (0.6 → 1.0)**: Cần giá chạy xa hơn mới expire
- **Giảm (0.6 → 0.4)**: Expire dễ hơn

**Khuyến nghị**: `0.5-0.7`

---

### 11. **InpPcMinLotsRemain** (double, default: `0.20`)
**Mô tả**: Lot tối thiểu phải còn lại sau PC (không đóng hết basket).

**Lý do**: Giữ lại một phần để nếu giá bounce lại, còn có positions để recovery.

**Ví dụ**:
- Loser có 1.0 lot
- `InpPcMinLotsRemain = 0.20` → đóng tối đa 0.80 lot

**Tác động**:
- **Tăng (0.20 → 0.40)**: Giữ lại nhiều hơn → bảo toàn recovery potential
- **Giảm (0.20 → 0.10)**: Đóng nhiều hơn → giảm DD mạnh hơn

**Khuyến nghị**: `0.15-0.25`

---

## 📊 Backtest Results Analysis

### Test 1: MinProfitUsd = 1.0 (Image #1)
- **Balance**: 12116
- **Drawdown**: Moderate (DD spike ~10.0%)
- **Behavior**: PC trigger nhiều hơn → đóng sớm hơn

### Test 2: MinProfitUsd = 5.0 (Image #2)
- **Balance**: 12170 (+0.4%)
- **Drawdown**: Slightly higher (DD spike ~10.8%)
- **Behavior**: PC trigger ít hơn → giữ profit lâu hơn

### Kết luận từ backtest:
`MinProfitUsd = 5.0` cho kết quả **tốt hơn một chút** trong trường hợp này:
- Balance cao hơn 54 USD (+0.4%)
- DD tăng nhẹ nhưng acceptable
- Ít PC không cần thiết → giữ profit tốt hơn

---

## 🎯 Recommended Settings

### **Conservative** (Ưu tiên giảm DD):
```
InpPcEnabled           = true
InpPcRetestAtr         = 0.6    // Trigger sớm
InpPcMinProfitUsd      = 1.0    // Dễ trigger
InpPcCloseFraction     = 0.35   // Đóng nhiều
InpPcMaxTickets        = 4
InpPcCooldownBars      = 8
InpPcGuardBars         = 6
InpPcPendingGuardMult  = 0.5
InpPcGuardExitAtr      = 0.6
InpPcMinLotsRemain     = 0.25   // Giữ lại nhiều
```

### **Balanced** (Balance giữa DD và profit):
```
InpPcEnabled           = true
InpPcRetestAtr         = 0.8    // Default
InpPcMinProfitUsd      = 2.0    // Moderate
InpPcCloseFraction     = 0.30
InpPcMaxTickets        = 3
InpPcCooldownBars      = 10
InpPcGuardBars         = 6
InpPcPendingGuardMult  = 0.5
InpPcGuardExitAtr      = 0.6
InpPcMinLotsRemain     = 0.20
```

### **Aggressive** (Ưu tiên profit):
```
InpPcEnabled           = true
InpPcRetestAtr         = 1.0    // Chờ retest sâu
InpPcMinProfitUsd      = 5.0    // Khó trigger
InpPcCloseFraction     = 0.25   // Đóng ít
InpPcMaxTickets        = 2
InpPcCooldownBars      = 15
InpPcGuardBars         = 8
InpPcPendingGuardMult  = 0.4
InpPcGuardExitAtr      = 0.7
InpPcMinLotsRemain     = 0.15   // Giữ lại ít
```

---

## 🔍 How to Optimize

### Step 1: Baseline
Test với `InpPcEnabled = false` để có baseline:
- Note final balance
- Note max DD
- Note DD duration

### Step 2: Enable với Default
Test với all defaults (`InpPcEnabled = true`):
- So sánh balance vs baseline
- So sánh DD reduction
- Observe PC frequency trong logs

### Step 3: Tune Key Params
Focus vào 3 params quan trọng nhất:
1. **InpPcMinProfitUsd** (1.0, 2.0, 5.0)
2. **InpPcRetestAtr** (0.6, 0.8, 1.0)
3. **InpPcCloseFraction** (0.25, 0.30, 0.35)

### Step 4: Fine-tune
Điều chỉnh cooldown/guard params nếu cần:
- Nếu PC quá nhiều → tăng cooldown
- Nếu re-enter liên tục → tăng guard

---

## 📝 Logs to Watch

Khi backtest, check logs:
```
[PartialClose] tickets=3 profit=2.45 price=1.10234
```

**Ideal frequency**:
- 1-3 PCs per major trend reversal
- Không quá 5 PCs/day

**Red flags**:
- PC mỗi 30 phút → cooldown quá ngắn
- Không có PC nào trong 1 tuần → params quá strict

---

## 🎓 Summary

**Top 3 params cần hiểu**:
1. **InpPcMinProfitUsd**: Điều khiển khi nào trigger (thấp = nhiều PC)
2. **InpPcRetestAtr**: Điều khiển retest phải sâu bao nhiêu
3. **InpPcCloseFraction**: Điều khiển đóng bao nhiêu mỗi lần

**Rule of thumb**:
- Muốn giảm DD → giảm MinProfitUsd, giảm RetestAtr, tăng CloseFraction
- Muốn tăng profit → tăng MinProfitUsd, tăng RetestAtr, giảm CloseFraction

**Từ backtest results**:
- `MinProfitUsd = 5.0` cho balance cao hơn (+0.4%)
- DD tăng nhẹ nhưng acceptable
- Recommend: Start với `5.0`, giảm xuống `2.0` nếu DD vẫn cao

---

**Document Version**: 1.0
**Last Updated**: 2025-10-01
**Author**: Recovery Grid Direction v2 Team
