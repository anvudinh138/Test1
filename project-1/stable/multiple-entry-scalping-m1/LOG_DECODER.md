# LOG DECODER

- `⚠️ PUSH too small ... need X or Y`  
  → X/Y = ngưỡng ATR cho avg/max range. Giảm yêu cầu: dùng UC21 (0.58/0.78) hoặc UC20.
- `⚠️ Wick too small: frac=p%, pips=q`  
  → Thử UC20/21 để nới wick, hoặc giảm `StrongWickATR` chút (preset 20/21 đã làm).
- `⚠️ No sweep`  
  → UC27 tắt require sweep (có soft momentum).
- `⚠️ Round number nearby`  
  → Dùng UC24 (RN buffer nhẹ hơn) **hoặc** UC28 (RN off).
- `⛔ Spread too wide`  
  → UC25 (spread relaxed 15/12).
- `🧹 Structure invalidated – cancel pending`  
  → Bình thường; nếu quá nhiều, tăng `InvalidateBuffer/Dwell` hoặc dùng UC21/27.
- `🧯 Skip re-entry 5m after early-cut`  
  → Anti-chop đang làm việc; nếu muốn tái nhập sớm, giảm thời gian này trong code (mặc định 300s).
