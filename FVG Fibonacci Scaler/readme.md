1. Tài Liệu Đặc Tả Kỹ Thuật (Comprehensive Document)
Tên dự án: Expert Advisor "FVG Fibonacci Scaler"
Phiên bản: 1.0
Mục tiêu: Tự động thực hiện giao dịch trên khung thời gian M1 dựa trên sự hợp lưu của Fair Value Gap (FVG) và các mức Fibonacci Retracement trong vùng Chiết khấu/Phí vượt mức (Discount/Premium).

1. Các Tham Số Đầu Vào (Input Parameters)
FixedLot: double (Mặc định = 0.02) - Khối lượng giao dịch tổng cho mỗi setup. Sẽ được chia 2 cho 2 lần vào lệnh.

MagicNumber: int (Mặc định = 112233) - Số định danh để EA quản lý các lệnh của chính nó.

FVG_Min_Size_ATR_Factor: double (Mặc định = 0.3) - Kích thước FVG tối thiểu phải lớn hơn (ATR(14) * Factor) để được coi là hợp lệ.

Swing_Detection_Bars: int (Mặc định = 24) - Số lượng nến để xác định một Swing High/Low.

TrailingStop_ATR_Factor: double (Mặc định = 1.5) - Khoảng cách Trailing Stop dựa trên (ATR(14) * Factor).

2. Logic Cốt Lõi
2.1. Xác định Swing & Fibonacci
EA sẽ liên tục quét Swing_Detection_Bars nến gần nhất để xác định đỉnh cao nhất (Swing High) và đáy thấp nhất (Swing Low) gần nhất tạo thành một cú đẩy (impulse leg) rõ ràng.

Khi một cú swing được xác nhận, Fibonacci Retracement sẽ được tự động vẽ từ điểm bắt đầu đến điểm kết thúc của swing đó.

2.2. Nhận diện Fair Value Gap (FVG)
Một FVG tăng giá hợp lệ được tạo bởi 3 nến, khi có một khoảng trống giữa đỉnh (high) của nến 1 và đáy (low) của nến 3.

FVG phải thỏa mãn điều kiện FVG_Min_Size_ATR_Factor.

EA chỉ xem xét các FVG nằm trong vùng Discount (dưới mức 50%) cho lệnh Mua, và vùng Premium (trên mức 50%) cho lệnh Bán.

2.3. Logic Lựa Chọn Vùng Entry Tự Động
EA sẽ tự động quyết định cặp Range để vào lệnh dựa trên bối cảnh:

Kịch bản A: Tín hiệu Tiêu chuẩn

Điều kiện: Tìm thấy 1-2 FVG trong vùng Discount/Premium.

Hành động: Chọn cặp Range 3 (0.5-0.618) và 4 (0.618-0.786).

Kịch bản B: Tín hiệu Hợp lưu Mạnh

Điều kiện: Tìm thấy cụm 3+ FVG, hoặc có vùng thanh khoản (EQH/EQL) rõ ràng phía sau điểm bắt đầu của swing.

Hành động: Chọn cặp Range 4 (0.618-0.786) và 5 (0.786-1.0).

3. Quản Lý & Thực Thi Lệnh
3.1. Logic Vào Lệnh Theo Tầng
Khối lượng tổng FixedLot được chia 50/50 cho 2 Entry (E1 và E2).

EA đặt lệnh Limit E1 tại FVG trong Range đầu tiên được chọn.

Nếu E1 được khớp, EA mới đặt tiếp lệnh Limit E2 tại FVG trong Range thứ hai.

3.2. Quản lý Lệnh
Stop Loss: Một mức SL duy nhất được đặt tại mức 100% của Fibonacci (vượt qua điểm bắt đầu của swing một chút).

Take Profit 1 (Chốt lời 1/2): Đặt tại mức 0% của Fibonacci. Khi giá chạm mức này, 50% tổng khối lượng đang mở sẽ được đóng lại.

Trailing Stop: Sau khi TP1 được khớp, Trailing Stop sẽ được kích hoạt cho 50% khối lượng còn lại với khoảng cách đã được định nghĩa ở tham số đầu vào.

4. Plan C (Phân Tích Động – Dynamic Entry)
- Bật/tắt bằng input: `in_enable_plan_c` (EA_upgrade.lua).
- Ý tưởng: Tự động phân tích mật độ FVG trong các vùng Fibonacci (Range 3/4/5), chọn cặp Range có xác suất tốt hơn thay vì cố định.
- Cách chọn Range:
  - Đếm số FVG nằm trong mỗi Range (3, 4, 5). Xếp hạng theo số lượng (mật độ).
  - Nếu Hợp lưu mạnh (tổng FVG ≥ 3): ưu tiên cặp 4 & 5 khi đều có FVG.
  - Nếu Tiêu chuẩn (< 3): ưu tiên cặp 3 & 4 khi đều có FVG.
  - Nếu chỉ còn 1 Range hợp lệ: vào Single Entry với Range đó.
- Cách chọn FVG trong mỗi Range:
  - Ưu tiên FVG có kích thước gap lớn nhất.
  - Nếu bằng nhau: ưu tiên “sâu hơn” theo hướng swing (Buy → midpoint thấp hơn; Sell → midpoint cao hơn).
- Fallback: nếu Plan C không chọn được Entry, EA quay về logic mặc định (3&4 khi tiêu chuẩn, 4&5 khi hợp lưu; cuối cùng là Single Entry nếu có FVG ở R5→R4→R3).

Ghi chú bổ sung (EA_upgrade.lua):
- Có bộ lọc Spread (`in_enable_spread_filter`, `in_max_spread_points`) và bộ lọc Phiên (`in_enable_session_filter`, `in_session_start_hour`, `in_session_end_hour`).
- Có buffer tránh 50% Fib (`in_enable_fifty_buffer`, `in_fifty_buffer`) giúp tránh fill sớm/whipsaw khi FVG nằm sát 0.5.

5. Plan D (Adaptive Regime – Thích Ứng Theo Biến Động)
- Bật/tắt bằng input: `in_enable_plan_d` (EA_upgrade.lua). Khi bật, Plan D được ưu tiên chạy trước Plan C.
- Ý tưởng cốt lõi: Ưu tiên vùng Fibonacci theo chế độ biến động của thị trường để cân bằng xác suất khớp lệnh và chất lượng điểm vào.
- Chỉ số chế độ (regime): `ratio = ATR(Anchor TF) / swing_range`.
  - `swing_range = |swing.high_price - swing.low_price|` của swing hiện hành.
  - ATR lấy từ Anchor TF (cùng period với Plan C/logic chung).
- Ngưỡng và tham số:
  - `in_plan_d_low_vol_ratio` (mặc định 0.12): dưới ngưỡng này xem là LowVol.
  - `in_plan_d_high_vol_ratio` (mặc định 0.25): trên ngưỡng này xem là HighVol.
  - `in_plan_d_buffer_lowvol` (mặc định 0.02) và `in_plan_d_buffer_highvol` (mặc định 0.06): buffer quanh mức 50% được chọn động khi bật `in_enable_fifty_buffer`.
- Lựa chọn Fibonacci Range theo chế độ:
  - HighVol (ratio ≥ high): ưu tiên cặp Range 4 & 5; nếu không đủ, ưu tiên 4 rồi 5.
  - LowVol (ratio ≤ low): ưu tiên cặp Range 3 & 4; nếu không đủ, ưu tiên 3 rồi 4.
  - Trung tính (giữa low–high) hoặc không có cặp phù hợp: fallback về Plan C (mật độ FVG).
- Cách chọn FVG trong mỗi range: giống Plan C (ưu tiên gap lớn; hòa thì chọn “sâu” theo hướng swing).
- Buffer 50% động: khi `in_enable_fifty_buffer` bật, Plan D dùng `EffectiveFiftyBuffer(swing_range, ATR)` để nội suy buffer:
  - HighVol → buffer = max(`in_fifty_buffer`, `in_plan_d_buffer_highvol`).
  - LowVol → buffer = min(`in_fifty_buffer`, `in_plan_d_buffer_lowvol`).
  - Trung tính → buffer = `in_fifty_buffer`.
- Tương thích: Plan D chỉ tác động tới khâu chọn range/entry và bộ lọc 50%. Phần SL/TP/TP1/Trailing giữ nguyên như cấu hình hiện tại (kể cả các chế độ AFTER_TP1).

Khuyến nghị test nhanh:
- Bật `in_enable_session_filter=true` với khung giờ 0–16 hoặc 3–18 (server time).
- Bật `in_enable_spread_filter=true`, `in_max_spread_points` trong khoảng 32–40.
- Bật `in_enable_fifty_buffer=true`, đặt `in_fifty_buffer=0.02`; Plan D sẽ tự mở rộng lên 0.06 khi HighVol.
- AFTER TP1: dùng `AFTER_TP1_TRAIL_SLOW` để phù hợp HighVol, hoặc `AFTER_TP1_TRAIL_ATR` nếu ưu tiên Sharpe/PF.
