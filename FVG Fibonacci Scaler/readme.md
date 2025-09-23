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