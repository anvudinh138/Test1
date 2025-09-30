BẮT ĐẦU (OnTick)
  |
  v
[Đã có Setup/Lệnh đang hoạt động?] --(CÓ)--> [Quản lý lệnh (TP1/Trail/Exit)] → KẾT THÚC
  |
 (KHÔNG)
  |
  v
[Anchor TF: Kiểm tra nến mới] → [Cập nhật swing]
  |
  v
[BOS hợp lệ (CloseOnly + padding)?] --(KHÔNG)--> KẾT THÚC
  |
 (CÓ)
  |
  v
[Sóng A hình thành] → [Tìm FVG/OB đúng hướng trong sóng A]
  |
  v
[Có FVG hoặc OB?] --(KHÔNG)--> KẾT THÚC
  |
 (CÓ)
  |
  v
[Đợi Retest về vùng FVG/OB (Anchor)]
  |
  v
[Retest xảy ra?] --(KHÔNG trong thời hạn)--> [Hết hạn Setup] → KẾT THÚC
  |
 (CÓ)
  |
  v
[Chuyển sang Trigger TF] → [Mở cửa sổ nến LTF]
  |
  +--> [Trigger A: Micro BOS LTF?] --(CÓ)--> [ENTRY] → [Đặt SL/TP1/TP/Trail]
  |
  +--> [Trigger B: IFVG (sharkturn)?] --(CÓ)--> [ENTRY] → [Đặt SL/TP1/TP/Trail]
  |
  +--> (HẾT CỬA SỔ) --> [Hủy Setup] → KẾT THÚC
  |
  v
[Quản lý sau vào lệnh]
  - Khi chạm TP1 (50% sóng A): chốt 50% và bật Trailing ATR.
  - Khi vi phạm cấu trúc/SL: đóng toàn bộ.
  - Khi đạt TP (đỉnh/đáy sóng A): đóng toàn bộ.
