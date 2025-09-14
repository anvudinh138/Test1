Sweep→BOS EA (XAU M1) – Tài liệu tổng hợp
0) Mục tiêu

Tín hiệu cốt lõi: Liquidity Sweep (quét equal highs/lows gần) → BOS (break of structure) ngược hướng trong ≤ N nến.

Ưu tiên: độ chính xác (ít lệnh nhưng sạch); dễ backtest real ticks, không repaint (chỉ dùng bar đã đóng – shift=1).

Tuỳ biến nhanh: input thủ công hoặc preset (built-in/CSV) cho 70+ usecase.

1) Kiến trúc & luồng logic
1.1 State machine

ST_IDLE → (phát hiện Sweep + BOS) → ST_BOS_CONF → (đợi Retest ≤ M_retest) → đặt lệnh → quay về ST_IDLE.

Tất cả quyết định dựa trên bar đã đóng (series rates[], shift≥1).

1.2 Điều kiện tín hiệu (SELL; BUY ngược lại)

SweepHigh tại bar b=1:

Cao hơn swing-high gần nhất trong K_swing bar trước đó và đóng dưới swing-high,

Hoặc chạm equal highs trong dung sai EqTol.

BOS xuống trong ≤ N_bos bar sau sweep:

Phá internal swing-low (lấy trong LookbackInternal) với buffer BOSBufferPoints.

Filter (tuỳ chọn):

Killzones (khung giờ server),

Round number (…00/25/50/75 ± RNDelta),

VSA effort–result: TickVol ≥ p90 và Range ≤ p60 trong L_percentile bar.

Spread sống ask-bid ≤ MaxSpreadUSD.

Entry: sau BOS, đợi Retest ≤ M_retest bar:

Market (mặc định) hoặc Pending stop (SellStop/BuyStop) tại bosLevel ± RetestOffsetUSD, hết hạn PendingExpirySec.

SL/TP/RR:

SL = sweep extremum ± SL_BufferUSD,

TP1/TP2 theo R,

BE_Activate_R, partial % tại TP1,

Time-stop: nếu sau TimeStopMinutes chưa đạt MinProgressR thì đóng.

2) Cấu trúc mã & hàm quan trọng

Dữ liệu nến: CopyRates(InpSymbol, InpTF, ...) → rates[] (đã ArraySetAsSeries(true)).

Sweep: IsSweepHighBar(int bar) / IsSweepLowBar(int bar)

BOS: HasBOSDownFrom(int sweepBar, int N, double &level, int &bosBar) (+ bản Up)

Internal swing: PriorInternalSwingLow/High(bar) trong LookbackInternal

Filter: FiltersPass(int bar) (Killzones, RN, Spread)

VSA: EffortResultOK(int bar) dùng PercentileDouble()

Quản trị lệnh: CalcLotByRisk(stop_usd), ManageOpenPosition()

Đặt lệnh: Market hoặc PlacePendingAfterBOS(bool isShort)

Patch compile quan trọng (đã áp vào v1.2, bạn nên copy nếu đang sửa bản cũ):

// Percentile: sort ASC (khác nhiều build MQL5)
double PercentileDouble(double &arr[], double p){
   int n=ArraySize(arr); if(n<=0) return 0.0;
   ArraySort(arr); // ASC mặc định
   double idx=(p/100.0)*(n-1);
   int lo=(int)MathFloor(idx), hi=(int)MathCeil(idx);
   if(lo==hi) return arr[lo];
   double w=idx-lo; return arr[lo]*(1.0-w)+arr[hi]*w;
}

// Spread sống (tránh widen bất chợt)
double SpreadUSD(){ MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return 0.0; return t.ask - t.bid; }

// Đếm vị thế đúng API MQL5
int PositionsOnSymbol(){
   int total=0;
   for(int i=0;i<PositionsTotal();++i)
      if(PositionSelectByIndex(i))
         if(PositionGetString(POSITION_SYMBOL)==_Symbol) total++;
   return total;
}

3) Tham số & preset
3.1 Input chính (ý nghĩa ngắn)

K_swing: số bar quét swing gần

N_bos: số bar tối đa để thấy BOS

LookbackInternal: cửa sổ tìm swing nội bộ trước sweep

M_retest: số bar chờ retest sau BOS

EqTol: dung sai equal HL (USD)

BOSBufferPoints: buffer BOS (đơn vị point)

UseKillzones/RoundNumber/VSA: bật/tắt filter

L_percentile: lookback cho percentile VSA

RNDelta: biên coi là “gần RN”

Risk: RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct, TimeStopMinutes, MinProgressR

Exec: MaxSpreadUSD, MaxOpenPositions

Entry style: UsePendingRetest, RetestOffsetUSD, PendingExpirySec

Debug: in log vì sao bị block (RN/KZ/Spread/VSA), khi arm BOS/đặt lệnh…

3.2 Preset (built-in) – gợi ý dùng nhanh

1 Baseline-Loose: tắt filter → sanity check (nhiều lệnh).

2 RN-Only: chỉ RN; dễ tối ưu RN/Spread.

3 London / 4 NY: killzone + RN + VSA (precision tốt).

5 Conservative: ít lệnh, sạch.

6 Aggressive: nhiều lệnh hơn.

7 Asia Range: chuyên phiên Á.

8 Pending-Retest: vào bằng pending stop.

9 Strict KZ+RN (No-VSA)

10 Ultra-tight: precision cao, rất ít lệnh.

Muốn giữ workflow “sửa input bằng tay” như ảnh: đặt UsePreset=false.

3.3 CSV Presets (tuỳ chọn)

Vị trí: MQL5/Files/XAU_SweepBOS_Presets.csv.

Trong EA: UsePreset=true, điền PresetNameCSV="TenProfile" → EA nạp dòng tương ứng.

Format cột:

name,EnableLong,EnableShort,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,
UseKillzones,UseRoundNumber,UseVSA,L_percentile,RNDelta,
KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e,
RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,
MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec


Ví dụ 3 dòng:

LDN_RN_VSA,1,1,60,6,12,3,0.20,2,1,1,1,150,0.35,835,860,985,1000,1165,1185,1255,1275,0.5,0.7,1,2,0.8,50,5,0.5,0.6,1,0,0.07,60
NY_Aggressive,1,1,35,8,10,4,0.30,1,0,1,0,120,0.50,1160,1190,0,0,1255,1280,0,0,0.5,0.55,1,2,0.8,50,5,0.5,0.9,1,1,0.07,60
Asia_Range,1,1,50,6,12,5,0.30,1,1,1,0,150,0.40,60,360,0,0,1320,1380,0,0,0.5,0.5,1,2,0.8,50,5,0.5,0.6,1,0,0.07,60


Các mốc KZ là phút từ 00:00 (server), ví dụ 13:55 → 13*60+55 = 835.

4) Cài đặt & backtest

Dán code (v1.2 mình đã gửi full) → Compile.

Tester:

Model: Every tick based on real ticks + Variable spread

Symbol: XAUUSD, TF: M1

Baseline: UsePreset=true, PresetID=1 (đảm bảo có lệnh)

Sau đó chuyển PresetID=3/4/5 để nâng precision.

Nếu vẫn không có lệnh:

UsePreset=false, tắt hết filter (UseKillzones=false, UseRoundNumber=false, UseVSA=false), tăng MaxSpreadUSD=0.8–0.9, SL_BufferUSD=0.6.

Kiểm tra log: “BLOCK RN/KZ/Spread/VSA” để biết chặn ở đâu.

Nhớ dịch killzones theo giờ server broker.

5) Tối ưu (theo thứ tự nên làm)

Spread/SL buffer: đặt MaxSpreadUSD ≥ p80 spread của broker; SL_BufferUSD=0.6–0.8.

RN: bật UseRoundNumber, thử RNDelta=0.30–0.50.

Killzones: set đúng giờ server; bật dần khung London/NY.

BOS window: N_bos=5–8, retest M_retest=3–4.

VSA: bật sau cùng; L_percentile=120–200.

Risk: 0.3–0.7%/lệnh; partial 30–50% ở TP1; BE tại 0.8–1.0R.

6) Các tình huống biên & guard

Double-sweep: chỉ vào khi có BOS thật (+ retest).

Tin mạnh/whipsaw: dùng MaxSpreadUSD + (tuỳ chọn) news filter (chưa code).

Broker khác nhau: tick-volume lệch ⇒ VSA dùng percentile nội phiên (đã xử lý).

Repaint do bar 0: không sử dụng dữ liệu bar đang chạy trong xác nhận.

Pending fill → SL ngay: dùng SL_BufferUSD lớn hơn + RetestOffsetUSD (0.05–0.10).

7) FAQ nhanh

Muốn dùng như project cũ (chỉnh input tay)? → UsePreset=false.

Tại sao không trade? → xem log “BLOCK …”; thường là Killzone lệch giờ, spread gắt, hoặc RN bắt buộc làm lệnh ít.

XAU spread cao → tăng MaxSpreadUSD (0.6–0.9) và SL_BufferUSD (0.6–0.8).

Tối ưu nhiều usecase → dùng CSV hoặc thêm case vào ApplyPresetBuiltIn() (ID 11..80).

Compile lỗi ArraySort → dùng 1 tham số như patch ở trên.

Compile lỗi PositionGetSymbol → MQL5 không có; dùng PositionSelectByIndex(i) + PositionGetString(POSITION_SYMBOL).

8) Lộ trình nâng cấp

v1.3 (đề xuất):

News guard (lịch cơ bản; tắt EA ±X phút quanh tin).

VWAP/ADR filter (mean-revert magnet).

ECR hybrid: E (ATR spike) → C (inside 2–4) → R (phá ngược) chỉ khi vừa có sweep & gần RN/killzone (làm trigger phụ).

Multi-symbol + log CSV trade để phân tích out-of-sample.

9) Checklist “đêm nay triển”

 Dán v1.2 vào MetaEditor, compile.

 Chạy PresetID=1 (baseline) để xác nhận tín hiệu.

 Chuyển PresetID=3/4 (London/NY) hoặc UsePreset=false và set input theo ảnh cũ.

 Nếu lỗi compile: áp 3 patch (Percentile/Spread/Positions) ở mục 2.

 Khi đã có lệnh, bật dần filter (RN → KZ → VSA).

 Tạo XAU_SweepBOS_Presets.csv nếu muốn quản lý 70+ usecase trong 1 file.