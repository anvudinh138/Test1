Kế hoạch (plan) sau đây

Mục tiêu 2 tuần tới

Ổn định core PF cao (NY/LDN ~ PF 5–7) và bơm tần suất lên 3–4 kèo/ngày bằng booster PF 2–3.

Kiểm nghiệm OOS (out-of-sample) để tránh overfit.

Khóa quản trị rủi ro/ngày cho chạy nhiều preset song song.

Pipeline khuyến nghị

Fold A (IS): 2025-06-01 → 2025-09-01
Fold A (OOS): 2025-09-01 → 2025-09-15

Batch hiện tại: v2.1 presets #1–20 + #21–32 (bạn đã note).

Chạy portfolio 1 tuần test:

Track A (PF cao): 1, 2, 3, 4, 5 (mỗi cái 1 chart riêng, magic tự set)
Risk: 0.45–0.50%/trade, RetestNeedClose=true

Track B (booster tần suất): 6, 7, 8, 9, 10, 29, 30, 31, 32
Risk: 0.20–0.35%/trade, RetestNeedClose=false

KZ shift cứu 0-trade: 21, 22, 23, 24 (bật nếu thấy preset core bị “im lặng”)

Bảo hiểm fill/RR: 27 (BE=1R+partial), 28 (pending 0.03)

Daily guard chung (trên từng chart/preset):

DailyMaxTrades=12, MaxConsecLoss=3, DailyMaxLossPct=2.0

Tổng rủi ro mở cùng lúc ≤ 1.5% (nếu nhiều chart).

Tiêu chí giữ preset: OOS PF ≥ 1.8, #trades ≥ 20/fold, MaxDD ≤ 8%, win ≥ 55%.

Sau 1 tuần, loại preset yếu, giữ lại “đội hình” 6–10 preset mạnh → v2.2 (nếu cần, mình sẽ soạn thêm #33–45 để tinh quanh winners).