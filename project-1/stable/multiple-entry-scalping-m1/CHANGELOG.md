# CHANGELOG

## v3.8.0
- Thêm **batch usecase 20–29** (grid nhẹ).
- Giữ adaptive exits + RN/Spread strict; tinh preset theo nhóm usecase.
- Dọn code & log – dễ đọc nguyên nhân.

## v3.7.1
- **Adaptive exits** (BE/Partial/Trail/Early-cut theo ATR).
- **Anti-chop**: block re-entry 5 phút cùng hướng sau early-cut.
- Giữ re-arm 60s sau cancel.

## v3.7.0
- Wick B có **nắp ATR (≤45p)**, buffer/dwell động.
- Re-arm sau cancel, SL tối thiểu có thành phần ATR.
- Preset 15–18 (RN/Spread strict).
