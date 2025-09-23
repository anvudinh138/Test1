BẮT ĐẦU (Trên mỗi nến mới)
    |
    V
[Có giao dịch nào đang hoạt động không?] --(CÓ)--> KẾT THÚC
    |
    (KHÔNG)
    |
    V
[Quét tìm Swing High/Low hợp lệ]
    |
    V
[Tìm thấy Swing?] --(KHÔNG)--> KẾT THÚC
    |
    (CÓ)
    |
    V
[Vẽ Fibonacci & Xác định vùng Discount/Premium]
    |
    V
[Quét tìm FVG hợp lệ trong vùng Discount/Premium]
    |
    V
[Tìm thấy FVG?] --(KHÔNG)--> KẾT THÚC
    |
    (CÓ)
    |
    V
[Phân tích bối cảnh: Đếm số FVG, kiểm tra thanh khoản]
    |
    V
[Đây là tín hiệu Hợp lưu mạnh?] --(CÓ)--> [Chọn cặp Range 4 & 5]
    |                                            |
    (KHÔNG)                                       |
    |                                            |
    V                                            |
[Chọn cặp Range 3 & 4] <--------------------------+
    |
    V
[Đặt lệnh Limit E1 (50% lot) tại Range đầu tiên]
    |
    V
[Theo dõi trạng thái lệnh...]
    |
    +--> [Nếu E1 được khớp] --> [Đặt lệnh Limit E2 (50% lot) tại Range thứ hai] --> [Quản lý lệnh hợp nhất (SL/TP)]
    |
    +--> [Nếu giá chạy đến TP mà không khớp E1] --> [Hủy lệnh] --> KẾT THÚC