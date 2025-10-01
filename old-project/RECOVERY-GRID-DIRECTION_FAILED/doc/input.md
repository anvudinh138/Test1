1) Khoảng cách lưới (Spacing)

spacing_mode (ATR/HYBRID): cách tính bước lưới: ATR×mult hoặc lai (ATR×mult nhưng không nhỏ hơn min). 



spacing_atr_mult (float): hệ số nhân ATR (cả hai mode đều dùng ATR). 



min_spacing_pips (int): sàn khoảng cách khi dùng HYBRID. 



2) Xây lưới & bổ sung lệnh

grid_levels (int): tổng mức lưới mỗi phía (tính cả lệnh market khởi tạo). 



grid_warm_levels (int): số limit “khởi động” đặt ngay sau khi seed. 



grid_refill_threshold (int): khi số limit còn sống ≤ ngưỡng này thì nạp thêm. 

grid_refill_batch (int): số limit thêm mỗi lần nạp. 

grid_refill_mode (STATIC/LIVE): dùng spacing gốc hay spacing tính lại theo ATR khi nạp. 



grid_max_pendings (int): trần số lệnh chờ đồng thời của một basket. 



3) Khối lượng (Sizing)

lot_base (float): lot của lệnh seed. 


lot_scale (float): hệ số nhân theo độ sâu (1.0 = không đổi). 


4) Mục tiêu chốt gộp & trailing

target_cycle_usd (float): lợi nhuận δ khi đóng rổ đang âm ở mức BE+δ (Group TP). 



tsl_enabled (bool): bật trailing cho rổ hedge. 



tsl_start_points (int): giá đi đúng hướng bao nhiêu points thì kích hoạt trailing. 



tsl_step_points (int): mỗi bước kéo SL sau khi kích hoạt. 



5) “Rescue” / Hedge nhiều lớp

recovery_steps (list[float]): các bội số ATR cho những lớp cứu viện/hedge bậc thang (ví dụ 1.0/2.0/3.0). 



recovery_lot (float): lot cho mỗi lớp rescue. 



dd_open_usd (float): mở hedge nếu basket thua lỗ đạt mức USD này. 



offset_ratio (float): cũng mở hedge nếu giá vượt lưới ngoài cùng một đoạn = tỷ lệ × spacing. 



rescue_trend_filter (bool): chỉ cho mở rescue khi bộ lọc xu hướng “đồng ý”. 



6) Đo xu hướng (để rescue/lockdown)

trend_k_atr (float): giá phải kéo dài tối thiểu bao nhiêu ATR mới tính là “trend mạnh”. 



trend_slope_threshold (float): ngưỡng độ dốc EMA để coi là mạnh. 



trend_slope_lookback (int): số nến dùng để đo slope. 



trend_ema_period (int): chu kỳ EMA cho slope/lockdown. 



trend_ema_timeframe (enum): khung thời gian dùng cho EMA. 



7) “Retest gate” cho hedge (tránh vào lại quá sớm)

hedge_retest_enable (bool): bật cơ chế chờ-retest trước khi reseed hedge. 



hedge_wait_bars (int): phải chờ tối thiểu bấy nhiêu nến sau khi hedge đóng. 



hedge_wait_atr (float): giá phải tiếp diễn thêm ≥ X ATR (trend tiếp tục) trước khi xét retest. 



hedge_retest_atr (float): vùng pullback (tính bằng ATR) quay về gần giá đóng; vào vùng này mới cho reseed. 



hedge_retest_slope (float): momentum/slope phải nguội dưới ngưỡng này mới unlock reseed. 



hedge_retest_confirm_bars (int): cần X nến liên tiếp ngược hướng để xác nhận pullback. 



8) “Trend lockdown” (khóa lưới khi xu hướng quá gắt)

lock_min_lots (float): chỉ kích hoạt lockdown nếu khối lượng rổ thua ≥ mức này. 



lock_min_bars (int): đã khóa thì phải giữ tối thiểu bấy nhiêu nến mới xét mở. 



lock_max_bars (int): tối đa bao nhiêu nến thì tự thoát khóa (failsafe). 



lock_cancel_mult (float): khi vào lockdown, xóa các lệnh chờ quá xa: khoảng = mult × spacing. 



lock_hyst_atr (float) & lock_hyst_slope (float): “độ trễ” để tránh bật/tắt khóa liên tục (cần nguội thêm X ATR / slope). 



lock_hedge_close_pct (float): vào lockdown thì chốt bớt % khối lượng hedge ngay lập tức. 



9) Tinh chỉnh TP khi ở xa giá

tp_distance_z_atr (float): nếu TP cách giá > Z×ATR thì thắt chặt TP của rổ thua. 



tp_weaken_usd (float): giảm bớt mục tiêu USD (δ) để TP kéo lại gần hơn khi quá xa. 



10) Giới hạn rủi ro & vòng đời

session_trailing_dd_usd (float): “trailing” cho sụt giảm vốn toàn phiên. 



exposure_cap_lots (float): trần tổng lot mở (cả 2 rổ). 



max_cycles_per_side (int): tối đa số lần rescue cho mỗi chân xu hướng. 



session_sl_usd (float): hard stop cho cả phiên (equity). 



cooldown_bars (int): tối thiểu X nến giữa hai lần rescue. 



11) Điều kiện thị trường & phiên giao dịch

max_spread_pips (float): không vào lệnh nếu spread > ngưỡng. 



trading_time_filter_enabled (bool): bật bộ lọc giờ giao dịch. 



cutoff_hour / cutoff_minute (int): giờ-phút dừng mở lệnh (giờ broker). 



friday_flatten_enabled (bool): ép đóng hết lệnh cuối thứ Sáu. 



friday_flatten_hour / friday_flatten_minute (int): hạn chót đóng thứ Sáu. 



12) Khớp lệnh & phí

slippage_pips (int): cho phép trượt giá tối đa khi khớp. 



commission_per_lot (float): phí/lot để tính chính xác Group TP (PnL trừ phí). 


13) Logging & Export

cycle_csv_path (string): đường dẫn CSV xuất chu kỳ; hỗ trợ placeholder `%symbol%`, `%date%`. Bỏ trống = tắt.
