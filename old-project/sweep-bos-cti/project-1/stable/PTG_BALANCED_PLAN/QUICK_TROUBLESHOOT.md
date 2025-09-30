# QUICK TROUBLESHOOT
• Compile lỗi “override system function / Point()”:
  - Bản v4 không dùng tên xung đột rồi. Nếu gặp lại, xóa cache *.ex5, compile sạch.

• Pending không khớp, “Invalid stops”:
  - Broker StopsLevel cao → tăng SL_Fixed 2–4p, hoặc tạm `InpUsePendingStop=false`.

• Không có lệnh:
  - Thử 21/30/40 (nới bias), 24/28 (nới RN), giảm ATRmin (43), hạ Push (21), hoặc tắt require sweep (27).

• Lệnh khớp rồi hay bị Early-cut:
  - Dùng exits bảo thủ: 38/49; hoặc engine kiên nhẫn 35/45.

• DD tăng khi market nhiễu:
  - 32 (RN chặt), 35/45 (giảm cancel, giảm hớt stop), 38 (exits chặt), bật blackout quanh rollover.

• Spread cảnh báo liên tục:
  - 25 (15/12) hoặc 34/47 (10/9 – cần ECN).
