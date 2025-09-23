Input Parameter	Start	Step	Stop	Ghi chú
InpFastEMA_Period	6	1	9	Range hẹp quanh giá trị 7 của top Pass
InpStopLossPoints	200	25	300	Giữ nguyên range từ image
InpTakeProfit1_Points	200	50	400	Mở rộng hơn so với image
InpTakeProfit2_Points	500	100	900	Mở rộng cho đa dạng
InpUseTrailingSL	true	false	true	Test cả 2 chế độ
InpTrailingStartPoints	300	50	400	Tối ưu quanh giá trị 350
InpTrailingStopPoints	80	20	150	Range hẹp hơn để ổn định
InpRiskPercent	0.3	0.1	0.5	Tăng risk so với image
InpUseDailyFilter	true	false	true	Test cả 2 chế độ
InpDailyEmaPeriod	160	20	200	Điều chỉnh cho phù hợp
InpUseAdxFilter	true	false	true	Giữ nguyên
InpUseDiCrossover	false	true	true	Mở rộng test cả 2
InpAdxPeriod	25	5	35	Range rộng hơn
InpAdxThreshold	25	2	32	Điều chỉnh threshold
InpUseSessionFilter	false	true	true	Test cả 2 chế độ
InpTradingStartHour	7	1	10	Mở rộng giờ giao dịch
InpTradingEndHour	16	2	20	Linh hoạt hơn
InpBreakoutLookbackBars	10	2	16	Tối ưu cho breakout
InpBreakoutOffsetPoints	15	5	35	Offset vừa phải
InpUseLossLimit	false	true	true	Test cả 2 chế độ