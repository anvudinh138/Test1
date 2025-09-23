# Presets 30–39 (đều bật Adaptive Exits)

30 = **No Bias** – tắt M5 bias gate; RN/Spread strict; Push 0.60/0.80  
    → Nhiều lệnh hơn, hợp khi bias làm rớt cơ hội.

31 = **Bias rất chặt** – slope 45, không contra; Push 0.62/0.82; ATRmin 55  
    → Ít lệnh, chọn trend rõ; tốt ở ngày có hướng mạnh.

32 = **RN super strict** – RN buffer lớn (Maj=7, Min=5)  
    → Né RN triệt để; giảm trap quanh số tròn.

33 = **RN medium-light + bias mềm** – RN (4/3), slope 25  
    → Cho phép khớp gần RN hơn, vẫn có bias.

34 = **Spread ultra strict** – 10/9  
    → Dùng khi broker ECN, muốn loại bỏ giai đoạn spread nở.

35 = **Engine kiên nhẫn** – dwell 14s, buffer 5p, cooldown 60s  
    → Giảm pending cancel trong chop.

36 = **Engine nhanh** – dwell 8s, buffer 5p, cooldown 30s  
    → Bắt nhịp thị trường nhanh, chấp nhận cancel nhiều hơn.

37 = **Hard sweep** – RequireSweep=ON, SoftFallback=OFF  
    → Chỉ vào khi có sweep đúng nghĩa.

38 = **Exits bảo thủ** – floors BE/PP/Trail/Step/EC = 16/22/24/18/14; SL 28p, SL_ATR 0.50  
    → Giữ lãi cẩn trọng, giảm stop-out do trail sớm.

39 = **Exits tích cực** – floors 12/16/18/14/10; SL 24p, SL_ATR 0.42  
    → Vào/ra nhanh, tăng số lệnh & tốc độ chốt.
