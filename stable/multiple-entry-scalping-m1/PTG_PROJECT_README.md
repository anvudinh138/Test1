# PTG BALANCED – Push-Test-Go (v3.8.0)

**PTG** là EA scalping M1 (đặc biệt cho XAUUSD) dựa trên mô hình **Push → Test → Go**:
- **Push**: nến/xung lực đẩy mạnh theo ATR.
- **Test**: cú hồi test thanh khoản (wick sâu).
- **Go**: đặt *pending stop* theo hướng Push, có bộ *buffer/invalid* động và *re-arm*.

## Điểm nổi bật (v3.8.0)
- **Wick rule có nắp ATR**: tránh yêu cầu wick quá lớn khi ATR cao (cap 45p).
- **Buffer & dwell động theo ATR**: pending chỉ hủy khi cấu trúc *vi phạm có độ sâu + đủ thời gian*.
- **Re-arm thông minh**: hủy pending → mở “cửa sổ” re-arm 60s; sau *early-cut* thì chặn re-entry cùng hướng 5 phút.
- **Adaptive Exits**: BE/Partial/Trail/Early-cut tự co giãn theo ATR (có floor & cap).
- **Round-Number & Spread strict** (preset 18 trở lên): giảm trade xấu quanh RN/giãn spread.
- **Preset batch 20–29**: chạy như grid search nhẹ—chỉ đổi `InpUsecase`.

## Khuyến nghị
- **Symbol**: XAUUSD M1 (có thể thử XAUUSD M2/M5, nhưng chuẩn tối ưu là M1).
- **Data**: Tick chất lượng (mọi backtest trong thread dùng ~5.43M ticks / 2025-08→2025-09).
- **Spread**: 10–12p strict (XAU). Nếu broker giãn >15p thường xuyên, dùng usecase 25.
- **StopLevel**: EA tự kiểm soát, nhưng cần broker cho phép khoảng cách đủ nhỏ trong M1.

## Tư duy chiến lược
- PTG **không** là trend-follower truyền thống; nó là **liquidity event scalper**.
- Session filter **không cần**; cấu trúc M1 “manipulation” có thể xuất hiện 24/7, nhưng blackout có thể bật nếu muốn né rollover.

## Cách chạy nhanh
1. **Baseline**: `InpUsecase=18` (strict RN & spread).
2. **Adaptive**: `InpUsecase=19` (18 + adaptive exits).
3. **Batch**: chạy `20…29`, chọn top 2–3 theo PF/Sharpe/Drawdown.
4. **Stress**: tăng spread +2p, trượt giá 100–200ms, OOS 2–4 tuần khác—giữ preset nào vẫn ổn thì dùng.

## Lưu ý
- Mọi log debug đều “giải thích được”: *wick too small / push too small / structure invalidated / bias block / round number nearby* → xem `LOG_DECODER.md`.
- **Risk**: mặc định lot cố định. Nếu dùng %Balance, bật `InpRiskPercent` và để `InpFixedLots=0`.
