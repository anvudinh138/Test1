# Presets 40–49 (đều bật Adaptive Exits)

40 = Bias mềm (slope 20, cho phép contra) + Push 0.60/0.80 → độ phủ cao, vẫn có RN/Spread strict.  
41 = Không bias + RN **rất chặt** (7/5) + Push 0.62/0.82 + ATRmin 55 → lọc mạnh quanh RN.  
42 = **High-vol only**: ATRmin 70, Push 0.64/0.86, Hard sweep, Bias 40 no-contra, Spread 11/10 → ít lệnh nhưng chất.  
43 = **Low-vol friendly**: ATRmin 45, Spread 15/12, Push 0.56/0.76, Bias 25 → tăng hoạt động khi thị trường hiền.  
44 = RN **bất đối xứng**: Major 8p / Minor 3p → né số tròn lớn quyết liệt, nhỏ thì mềm.  
45 = Engine **rất kiên nhẫn**: dwell 18s, buffer 6p, cooldown 75s → giảm cancel trong chop.  
46 = Engine **rất nhanh**: dwell 6s, buffer 4p, cooldown 20s + floors 12/16/18/14/10 + SL 24/0.42 → scalpy.  
47 = **Momentum-only**: Push 0.66/0.90, Hard sweep, Bias 40 no-contra, Spread 10/9, ATRmin 55 → chất lượng cao.  
48 = **Trend carry**: floors 16/24/26/18/16, SL 28/0.50, Bias 35 no-contra → giữ lãi xu hướng.  
49 = **Protective/mean-revert**: floors 12/18/20/16/8, SL 24/0.42, RN 5/3, Sweep OFF (soft), Bias OFF, Spread 13/11 → bảo thủ, ra nhanh.
