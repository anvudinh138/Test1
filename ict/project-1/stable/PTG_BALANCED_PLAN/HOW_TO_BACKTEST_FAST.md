# HOW TO BACKTEST FAST (PTG v4)
1) Tester:
   - Model: Every tick based on real ticks
   - Symbol: XAUUSD, Period: M1
   - Date: (ví dụ) 2025-08-01 -> 2025-09-10
   - Deposit: 10k (tuỳ), Leverage: broker default
   - Visual mode: OFF (để nhanh), rồi ON khi cần soi lệnh.

2) Baseline (2 run):
   - UC18 (strict), UC19 (strict + adaptive exits)
   → chọn mốc có PF/Sharpe tốt hơn.

3) Batch nhanh (chọn 4–6 preset tuỳ ngày):
   - High-vol: 42, 47
   - Low-vol / spread lớn: 43, 25
   - Trend carry vs protective: 48, 49
   - Chop control: 35, 45

4) Ghi log:
   - Mở `PTG_BACKTEST_LOG_v4.txt`, copy block RUN, điền số liệu, dán SUMMARY 1 dòng.

5) Đọc log để quyết định:
   - “bias block” nhiều → 21/30/40
   - “round number nearby” nhiều → 24/28/32/44
   - “spread too wide” nhiều → 25/34/47
   - “cancel invalid” nhiều → 35/45 (engine kiên nhẫn) hoặc 27 (tắt require sweep)
