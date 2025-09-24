Tên dự án: CTI (ICT-Conform Expert Advisor)
Mục tiêu: Vào lệnh chuẩn ICT với xác nhận đa pha: BOS (Structure) → Displacement FVG (Anchor TF) → Retest → Trigger trên LTF (Micro BOS hoặc IFVG), quản trị rủi ro bằng ATR, không phụ thuộc pip/point.

1. Khung Thời Gian & Mapping
- Anchor TF mặc định: M5. Cho phép chọn qua input `in_anchor_tf` (enum custom).
- Trigger TF: chọn bằng `in_trigger_tf_mode`.
  - AUTO_TABLE (mặc định): dùng bảng mapping sau (đề xuất của bạn):
    - M1 → M1
    - M5 → M1
    - M15 → M5
    - M30 → M15
    - H1 → M15
    - H4 → M30
  - MANUAL: chọn trực tiếp `in_trigger_tf_manual`.

2. Logic ICT (Tóm tắt)
- Phase 1 – Structure/BOS (Anchor TF):
  - Thị trường vừa tạo BOS ngược xu hướng trước (ví dụ Buy: giảm → BOS down → retest → sóng A phá đỉnh tạo BOS up).
  - Xác nhận BOS bằng “đóng cửa vượt” (CloseOnly). Có input buffer phá cấu trúc.
- Phase 2 – Displacement FVG (Anchor TF):
  - Sóng A tạo FVG đúng hướng (Buy: bullish FVG). Min size = ATR(14, Anchor) × `in_fvg_min_atr_factor_anchor`.
- Phase 3 – Retest (Anchor TF):
  - Giá hồi về vùng Hợp lệ trên Anchor: FVG của A hoặc OB của A.
  - OB (Order Block) – định nghĩa: nến ngược hướng cuối cùng tại gốc sóng A (Buy: nến giảm cuối cùng trước cú đẩy tăng của A; Sell: nến tăng cuối cùng trước cú đẩy giảm của A). Vùng OB mặc định là thân nến; có tùy chọn mở rộng theo râu.
  - Khi giá chạm FVG hoặc OB, chuyển sang LTF để chờ Trigger.
- Trigger (LTF):
  - Micro BOS cùng hướng (ưu tiên) hoặc IFVG (sharkturn) trong vùng retest.
  - IFVG: mặc định chấp nhận mọi sharkturn (không yêu cầu min size). Có tùy chọn chế độ nghiêm ngặt dùng ngưỡng ATR khi bật.
  - Cửa sổ chờ: tối đa `in_trigger_window_bars_ltf` nến LTF.
- Entry:
  - Mặc định Market on Trigger (khi thấy Micro BOS/IFVG xác nhận). Tùy chọn Limit tại mép IFVG.
- SL/TP:
  - SL: đáy/đỉnh LTF trước Trigger + buffer (ATR-based). Tùy chọn SL tại 100% Anchor (ít mặc định dùng).
  - TP: đỉnh/đáy sóng A (Anchor). Tùy chọn TP1=50% sóng A, sau đó kích hoạt Trailing ATR.

3. Tham Số Đầu Vào (Inputs)
- Magic & Lotting:
  - `in_magic_number` (mặc định 223344)
  - `in_fixed_lot` (mặc định 0.02)
- Timeframes:
  - `in_anchor_tf` (enum custom: M1/M5/M15/M30/H1/H4; mặc định M5)
  - `in_trigger_tf_mode` (AUTO_TABLE|MANUAL; mặc định AUTO_TABLE)
  - `in_trigger_tf_manual` (khi MANUAL)
- Swing/BOS (Anchor):
  - `in_swing_bars_anchor` (mặc định 5)
  - `in_bos_confirm_mode` (CLOSE_ONLY|CLOSE_OR_WICK; mặc định CLOSE_ONLY)
  - `in_bos_padding_mode` (ATR|POINTS|SWING_PCT; mặc định ATR)
  - `in_bos_padding_atr_factor` (mặc định 0.00)
  - `in_bos_padding_points` (fallback khi chọn POINTS)
  - `in_bos_padding_swing_pct` (0–0.2; khi chọn SWING_PCT)
- FVG & Retest (Anchor):
  - `in_fvg_min_atr_factor_anchor` (mặc định 0.30)
  - `in_enable_fifty_buffer` (mặc định false)
  - `in_fifty_buffer_ratio` (mặc định 0.02)
  - `in_anchor_zone_allow_fvg` (mặc định true)
  - `in_anchor_zone_allow_ob` (mặc định true)
  - `in_zone_priority` (FVG_THEN_OB | OB_THEN_FVG | ANY; mặc định FVG_THEN_OB)
  - OB options: `in_ob_use_wick` (mặc định false), `in_ob_max_candles_back_in_A` (mặc định 5)
- Trigger (LTF):
  - `in_trigger_window_bars_ltf` (mặc định 30)
  - `in_entry_allow_bos` (true) | `in_entry_allow_ifvg` (true)
  - `in_entry_priority` (BOS_THEN_IFVG | IFVG_THEN_BOS | ANY; mặc định BOS_THEN_IFVG)
  - `in_ifvg_strict` (mặc định false) – nếu bật, áp dụng ngưỡng size IFVG theo ATR
  - `in_ifvg_min_atr_factor_ltf` (mặc định 0.00 khi `in_ifvg_strict=false`)
  - `in_entry_mode` (MARKET_ON_TRIGGER | LIMIT_AT_IFVG | SMART_BOTH; mặc định MARKET_ON_TRIGGER)
- SL/TP/Trailing:
  - `in_sl_mode` (LTF_STRUCTURE | ANCHOR_100PCT; mặc định LTF_STRUCTURE)
  - `in_sl_buffer_atr_factor` (mặc định 0.10)
  - `in_tp1_enable` (true), `in_tp1_at_50pct_of_A` (true)
  - `in_trailing_stop_atr_factor` (mặc định 1.5; kích hoạt sau TP1)
- Filters & Guards:
  - `in_enable_spread_filter` (true), `in_max_spread_points` (vd 32–40)
  - `in_enable_session_filter` (false), `in_session_start_hour`, `in_session_end_hour`
  - `in_setup_expiry_bars_anchor` (mặc định 8–12) – hết hạn setup nếu không có Trigger
- Logging:
  - `in_debug` (true/false), mức log sự kiện và thống kê sau backtest.

4. Trạng Thái (State Machine)
- IDLE → WAIT_BOS → WAIT_FVG → WAIT_RETEST → WAIT_TRIGGER → IN_TRADE → (TP1/TRAIL/EXIT) → IDLE
  - Ghi chú: WAIT_FVG thực chất là “WAIT_ZONES”: tìm cả FVG và OB. WAIT_RETEST sẽ chờ chạm FVG/OB theo ưu tiên.
- Một setup duy nhất hoạt động trên mỗi symbol (tất cả lệnh gắn Magic Number).

5. Quy Tắc Chi Tiết
- BOS (Anchor):
  - Định nghĩa swing bằng `in_swing_bars_anchor` (fractal lookback). BOS hợp lệ khi nến đóng vượt đỉnh/đáy swing + padding.
- FVG (Anchor):
  - Dùng mẫu 3 nến: Bullish FVG nếu High[n-2] < Low[n] (gap) và size ≥ ATR × factor. Chỉ xét FVG thuộc sóng A.
- OB (Anchor):
  - Chọn nến ngược hướng cuối cùng tại gốc sóng A (Buy → nến giảm; Sell → nến tăng).
  - Vùng OB = [min(open, close), max(open, close)] khi `in_ob_use_wick=false`; nếu bật, mở rộng tới râu nến.
- Retest: Khi giá chạm vùng FVG, chuyển LTF và mở cửa sổ `in_trigger_window_bars_ltf` để tìm trigger.
  - Nếu bật cả FVG và OB: vùng nào được chạm trước sẽ kích hoạt cửa sổ; nếu chạm cả hai cùng lúc, áp dụng `in_zone_priority`.
- Trigger (LTF):
  - Micro BOS: đóng vượt swing gần nhất cùng hướng.
  - IFVG: gap nhỏ xuất hiện ngay sau retest, cùng hướng setup. Khi `in_ifvg_strict=true`, yêu cầu size ≥ ATR_LTF × `in_ifvg_min_atr_factor_ltf`; nếu không, chấp nhận mọi sharkturn.
- Entry/SL/TP: Theo mục Inputs; luôn chuẩn hóa số thập phân theo Digits; mọi kích thước động dùng ATR thay vì pip.

6. Invalidation & Hết Hạn
- Nếu trước entry, giá phá vỡ cấu trúc ngược hướng (ví dụ Buy: thủng đáy BOS) → hủy setup.
- Hết thời gian chờ trigger (LTF) hoặc hết hạn setup (Anchor) → hủy.

7. Backtest Khuyến Nghị
- Symbol: EURUSD (ưu tiên). EA thiết kế đa symbol (forex/crypto/indices/stocks/xau...).
- Anchor= M5, Trigger= M1 (AUTO_TABLE). Data chất lượng cao; lưu ý spread filter.
- So sánh: CTI (M5→M1) vs FVG-only M1.

8. Ghi Chú Triển Khai
- Không dùng pip cố định; mọi ngưỡng động dựa trên ATR hoặc tỉ lệ swing.
- Giữ code module hóa: DetectStructure.mqh, DetectFVG.mqh, TriggerLTF.mqh, TradeManager.mqh, StateMachine.mqh.
