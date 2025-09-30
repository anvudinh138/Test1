1) Khoảng cách lưới (Spacing)
Tham số	Default	Start	Step	Stop
spacing_mode (0=ATR,1=HYBRID)	1	0	1	1
spacing_atr_mult	1.0	0.5	0.25	3.0
min_spacing_pips	10	5	5	40
2) Xây lưới & bổ sung lệnh
Tham số	Default	Start	Step	Stop
grid_levels	10	6	2	20
grid_warm_levels	2	0	1	5
grid_refill_threshold	3	1	1	5
grid_refill_batch	2	1	1	5
grid_refill_mode (0=STATIC,1=LIVE)	1	0	1	1
grid_max_pendings	12	6	2	30
3) Khối lượng (Sizing)
Tham số	Default	Start	Step	Stop
lot_base	0.10	0.01	0.01	0.50
lot_scale	1.00	1.00	0.10	1.60
4) Mục tiêu chốt gộp & trailing (hedge)
Tham số	Default	Start	Step	Stop
target_cycle_usd	15	5	5	100
tsl_enabled (0/1)	1	0	1	1
tsl_start_points	300	100	50	1500
tsl_step_points	100	20	10	500
5) “Rescue” / Hedge nhiều lớp

recovery_steps là CSV khó tối ưu trực tiếp. Khuyến nghị tối ưu 1 biến recovery_step_base (bội số ATR) rồi sinh chuỗi 1x,2x,3x. Bảng dưới gồm cả 2 biến.
| Tham số | Default | Start | Step | Stop |
|---|---:|---:|---:|---:|
| recovery_step_base (ATR)* | 1.0 | 0.6 | 0.2 | 3.0 |
| recovery_steps (CSV) | 1.0,2.0,3.0 | (sinh từ base) | — | — |
| recovery_lot | 0.10 | 0.01 | 0.01 | 0.30 |
| dd_open_usd | 60 | 20 | 10 | 300 |
| offset_ratio | 0.75 | 0.50 | 0.10 | 1.50 |
| rescue_trend_filter (0/1) | 1 | 0 | 1 | 1 |

6) Đo xu hướng (cho rescue/lockdown)
Tham số	Default	Start	Step	Stop
trend_k_atr	2.0	1.0	0.25	4.0
trend_slope_threshold	0.0005	0.0001	0.00005	0.0010
trend_slope_lookback	20	10	5	60
trend_ema_period	89	34	5	200
trend_ema_timeframe (M15=15,H1=60,H4=240,…)**	H1	M15	—	H4
7) “Retest gate” cho hedge
Tham số	Default	Start	Step	Stop
hedge_retest_enable (0/1)	1	0	1	1
hedge_wait_bars	10	3	1	30
hedge_wait_atr	1.0	0.5	0.1	2.0
hedge_retest_atr	0.8	0.5	0.1	1.5
hedge_retest_slope	0.0002	0.00005	0.00005	0.0005
hedge_retest_confirm_bars	2	1	1	5
8) “Trend lockdown”
Tham số	Default	Start	Step	Stop
lock_min_lots	0.30	0.10	0.10	2.00
lock_min_bars	6	3	1	24
lock_max_bars	48	12	6	96
lock_cancel_mult	2.5	1.0	0.25	4.0
lock_hyst_atr	0.5	0.2	0.1	1.5
lock_hyst_slope	0.00015	0.00005	0.00005	0.0005
lock_hedge_close_pct	0.50	0.25	0.05	0.90
9) Tinh chỉnh TP khi ở xa giá
Tham số	Default	Start	Step	Stop
tp_distance_z_atr	2.5	1.5	0.25	4.0
tp_weaken_usd	5	0	2	50
10) Giới hạn rủi ro & vòng đời
Tham số	Default	Start	Step	Stop
session_trailing_dd_usd	75	20	10	300
exposure_cap_lots	1.50	0.50	0.10	5.00
max_cycles_per_side	3	1	1	6
session_sl_usd	150	50	10	600
cooldown_bars	5	1	1	20
11) Điều kiện thị trường & phiên giao dịch
Tham số	Default	Start	Step	Stop
max_spread_pips	2.0	0.5	0.1	5.0
trading_time_filter_enabled (0/1)	0	0	1	1
cutoff_hour	22	0	1	23
cutoff_minute	30	0	5	55
friday_flatten_enabled (0/1)	1	0	1	1
friday_flatten_hour	22	18	1	23
friday_flatten_minute	45	0	5	55
12) Khớp lệnh & phí
Tham số	Default	Start	Step	Stop
slippage_pips	1	0	1	3
commission_per_lot	7.0	0.0	0.5	15.0
13) Logging & Export
Tham số	Default	Start	Step	Stop
cycle_csv_path	( trống )	—	—	—
