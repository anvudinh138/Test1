1) Tổng quan

EA: XAU_SweepBOS_DemoEA_v2_1.mq5

Khung thời gian: M1 (XAUUSD)

Ý tưởng: ICT-style Liquidity Sweep → Break of Structure (BOS), sau BOS chờ retest ngắn để vào.

Bộ lọc: Killzones (LDN/NY), Round Number (RN ±0.25/0.50), VSA effort-vs-result.

Quản trị: risk theo % balance, BE/partials, time-stop, daily guard (max trades/day, consecutive loss, daily loss%).

2) Logic tín hiệu (không repaint)

Sweep bar (đã đóng):

Sweep high: phá đỉnh K_swing gần nhất (hoặc equal high trong EqTol) rồi đóng dưới.

Sweep low: tương tự với đáy.

BOS (trong ≤ N_bos bars sau sweep):

Short: phá đáy internal swing trước sweep.

Long: phá đỉnh internal swing trước sweep.

Retest (≤ M_retest bars sau BOS):

Market: chạm & (tuỳ chọn) đóng vượt ngưỡng BOS (controlled bởi RetestNeedClose).

Pending: đặt BuyStop/SellStop at bosLevel ± RetestOffsetUSD (hết hạn PendingExpirySec).

SL/TP & quản trị:

SL ngoài sweep extremum ± SL_BufferUSD.

TP1 = TP1_R R, TP2 = TP2_R R, BE tại BE_Activate_R, partial = PartialClosePct.

Time-stop: nếu sau TimeStopMinutes chưa đạt MinProgressR → đóng.

3) Inputs quan trọng (tóm tắt)

Core: K_swing, N_bos, LookbackInternal, M_retest, EqTol, BOSBufferPoints

Filters: UseKillzones, UseRoundNumber, UseVSA, RNDelta, L_percentile, KZ1..KZ4

Risk: RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct

Exec: MaxSpreadUSD, MaxOpenPositions

Entry style: UsePendingRetest, RetestOffsetUSD, PendingExpirySec, RetestNeedClose_Default

Daily guard: DailyMaxTrades, DailyMaxLossPct, MaxConsecLoss

Magic: MagicBase → magic = MagicBase + PresetID (mỗi preset = 1 chart)

4) Presets (v2.1)

#1–5: Core PF cao (NY/LDN).

#6–10: Booster (tăng kèo, PF 2–3+).

#11–12: High-freq PF ~1.2–1.5 (lot nhỏ).

#13–20: Biến thể (pending, wick-only, bridge, asia, conservative).

#21–24: KZ shift ±10 phút để cứu lệch giờ server.

#25–26: Wick-only cho core.

#27–28: BE=1R/Partial & Pending=0.03.

#29–32: Booster tinh chỉnh quanh các case nhiều kèo (UC8/9/10).

Mẹo mapping:
– Bạn rất thích profile kiểu UC PF > 6: chạy #1, #2, #3, #4, #5.
– Muốn nhiều kèo: thêm #6–10, #29–32 và bật vài KZ shift (#21–24).
– Nếu preset nào 0 trade: dùng biến thể wick-only (#25/#26) hoặc shift KZ.

5) Thiết lập Backtest/Optimization

Model: Every tick based on real ticks, delay 50 ms.

XAUUSD real ticks có từ 2025-05-28 (broker của bạn).

Range đề xuất:

IS: 2025-06-01 → 2025-09-01

OOS: 2025-09-01 → 2025-09-15

Giữ nhất quán model tick, commission, swap, spread.

Thông số cần lưu: PF, Net, MaxDD%, #Trades, Win%, AvgP/L, LargestP/L.

6) Portfolio multi-chart (live/demo)

Mỗi chart = 1 PresetID, magic tự động (tránh đè nhau).

Track A (PF cao): #1, #2, #3, #4, #5 — RetestNeedClose=true, risk 0.45–0.5%.

Track B (booster): #6, #7, #8, #9, #10, #29–32 — RetestNeedClose=false, risk 0.2–0.35%.

Daily guard áp dụng trên từng chart (theo magic).

Cap đồng thời: tổng rủi ro mở ≤ 1.5%.

Dừng ngày: -2.0% hoặc -6R.

7) Quy tắc đánh giá / chọn preset

Giữ nếu PF OOS ≥ 1.8, #trades ≥ 20/fold, MaxDD ≤ 8%, Win ≥ 55%.

Ưu tiên preset có PF ổn định qua 2 fold, không chỉ “bùng nổ” 1 giai đoạn.

Nếu boost số kèo bằng wick-only/pending → giảm lot thay vì giữ risk như core.

8) Ghi log/kết quả (template)
Symbol: XAUUSD M1 | Model: Real ticks + 50ms
Range IS: 2025-06-01 → 2025-09-01
Range OOS: 2025-09-01 → 2025-09-15

PresetID: <n> | Name: <ghi chú ngắn>
PF(IS/OOS): x.xx / x.xx
Net(IS/OOS): $xxx / $xxx
Trades(IS/OOS): xxx / xxx | Win%: xx%
MaxDD(IS/OOS): x.x% / x.x%
Notes: (spread cao? KZ im? wick-only hiệu quả? …)
Decision: (Keep / Drop / Tune params: RNDelta, BOSBuffer, RetestNeedClose, KZ shift)

9) Troubleshooting nhanh

0 trade: lệch giờ → dùng #21–24 (KZ shift) hoặc bật RetestNeedClose=false (#25/#26).

PF giảm khi tăng kèo: hạ RiskPerTradePct của booster; siết MaxSpreadUSD 0.55; bật BE 1R (#27/#29).

Slippage/Spread cắn SL: tăng SL_BufferUSD 0.05–0.1; giảm MaxSpreadUSD; dùng pending offset (#28/#30).

Nhiễu phiên Á: hạn chế KZ Asia, chỉ giữ 18 nếu PF tốt OOS.