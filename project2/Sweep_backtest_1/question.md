2) EA v1 chạy trên EURUSD/GBPUSD… được không?

Được, nhưng: các ngưỡng hiện tại đang “scale theo XAU” (đơn vị giá chứ không phải USD). Bạn cần scale lại cho từng instrument:

Tham số	Ý nghĩa	XAU (đang dùng)	EURUSD (gợi ý)	GBPUSD (gợi ý)	USDJPY (gợi ý)
EqTol	tolerance equal high/low	0.20	0.0002 (2 pip)	0.00025 (2.5 pip)	0.02 (2 pip)
RNDelta	“gần round-number”	0.30	0.0005 (5 pip)	0.0007 (7 pip)	0.05 (5 pip)
SL_BufferUSD	đệm ngoài sweep	0.60	0.0010–0.0015 (10–15 pip)	0.0015–0.0020	0.15–0.20
RetestOffsetUSD	offset đặt pending	0.06–0.07	0.0003–0.0006	0.0004–0.0007	0.03–0.05
MaxSpreadUSD	chặn spread	0.50–0.70	0.00020 (2 pip)	0.00025	0.02