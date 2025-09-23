OK, mình đọc code EA của bạn kỹ rồi và thấy ngay vài “bẫy” khiến XAU chạy mượt nhưng EURUSD cắm vào là đuối. Tóm gọn:

Vì sao XAU “ngon” mà EURUSD “không đủ tốt”
Đơn vị tham số đang “theo USD tuyệt đối” → lệch nặng cho FX

Các tham số như SL_BufferUSD, RetestOffsetUSD, AddSpacingUSD, MaxSpreadUSD đều đang hiểu là “độ lệch giá theo USD” (thực chất là đơn vị giá), hợp với XAU (1.0 = $1) nhưng quá to với EURUSD (0.50 = 5000 pip!). Hàm ApplyAutoSymbolProfile() chỉ dùng MathMax(...) để “nâng” ngưỡng khi cần, KHÔNG hạ xuống — nên những default lớn kiểu XAU (0.50, 0.40, 0.07) vẫn giữ nguyên khi chạy EURUSD → dời điểm retest quá xa, SL quá rộng ⇒ lot tính ra siêu nhỏ, thậm chí < min lot và order không khớp/ít lệnh. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Killzone cứng theo XAU

Bạn bật UseKillzones=true mặc định, nhưng khung giờ KZ (KZ1..KZ4) lại được tune cho XAU; EURUSD peak lại ở phiên London/NY nên rất nhiều set-up bị block bởi FiltersPass() khi không trùng giờ. CSV hiện chưa cho set giờ KZ theo symbol. 

FX_SweepBOS_EA_v1_sprint_2_EXP

CSV chỉ cho “*pip / *pipPoints” ở MỘT VÀI field

ParseCSVValue() đã hỗ trợ chuỗi kiểu 2.0*pip và 2.0*pipPoints, nhưng loader chỉ áp dụng cho: EqTol, BOSBufferPoints, RNDelta, SL_BufferUSD, RetestOffsetUSD. Các field quan trọng khác như MaxSpreadUSD, TrailStepUSD, AddSpacingUSD vẫn parse số thường ⇒ không quy đổi theo pip được trong preset CSV. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Spread filter & RN grid đặt theo kim loại/crypto

DefaultSpreadForSymbol() chỉ set mặc định cho BTC/ETH/XAU, không có EURUSD; RoundMagnet() FX dùng lưới 25 pip là OK, nhưng RNDelta default 0.30 (quá lớn với EURUSD) lại không bị hạ khi auto profile. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Bộ testcase EURUSD “xịn” (8 preset sẵn dùng)

Mình đã chuẩn hóa sẵn 8 preset cho EURUSD (M1) theo đúng format usecases_list.csv của bạn, trong đó các field nhạy cảm đã dùng *pip/*pipPoints để tự scale theo pip (những field loader chưa hỗ trợ *pip mình nhập giá trị theo đơn vị giá EURUSD luôn, ví dụ 0.00020 = 2 pip). Bạn tải file CSV này và chép nội dung vào resource \Files\usecases_list.csv (hoặc merge vào resource hiện tại):

Download usecases_list_EURUSD.csv

Preset gợi ý (201–208) gồm đủ phong cách: scalp London, momentum NY, quiet Asia, trailing ATR/STEP, VSA on/off, RN filter mạnh/nhẹ, pyramiding bật/tắt.
Khi backtest: UsePreset=true và đặt PresetID tương ứng (201..208). Các preset này:

dùng EqTol, RNDelta, SL_BufferUSD, RetestOffsetUSD, BOSBufferPoints theo *pip/*pipPoints để không bị lệch đơn vị;

MaxSpreadUSD nhập thẳng theo giá EURUSD (0.00020 ≈ 2 pip);

có cả cấu hình UsePendingRetest=true với retest 1.2–1.5 pip cho môi trường “quiet”.

Mình đã hiển thị bảng preset kèm link tải ngay ở trên để bạn kiểm tra nhanh.

Code review: chốt lỗi & fix cụ thể
1) Chuẩn hóa đơn vị theo pip (fix lớn nhất)

Vấn đề: default “USD absolute” của XAU không phù hợp FX và ApplyAutoSymbolProfile() chỉ “nâng lên” chứ không “hạ xuống”. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Giải pháp nhanh (không phá CSV): thêm hàm normalize sau khi apply CSV/inputs để “kẹp” các tham số FX về mức theo pip nếu chúng quá lớn:

void NormalizeFXUnits()
{
   bool isXAU = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);
   if(isXAU || isCrypto) return;

   double pip = SymbolPipSize(SelectedSymbol);

   auto clampToPips = [&](double &x, double targetPips, double maxPipsAllowed) {
      double tp = targetPips * pip;
      double mp = maxPipsAllowed * pip;
      if(x > mp || x <= 0.0) x = tp;
   };

   clampToPips(P.SL_BufferUSD,     8.0, 25.0);
   clampToPips(P.RetestOffsetUSD,  2.0, 10.0);
   clampToPips(P.AddSpacingUSD,    6.0, 30.0);

   // Spread mặc định cho majors nếu chưa set
   if(P.MaxSpreadUSD >= 0.3)  // 0.3 giá = 3000 pip -> rõ là sai cho FX
      P.MaxSpreadUSD = 2.0 * pip; // 2 pip
}


Gọi hàm này ngay sau ApplyAutoSymbolProfile(); trong OnInit(). 

FX_SweepBOS_EA_v1_sprint_2_EXP

2) Cho phép *pip cho nhiều trường hơn (CSV mạnh hơn)

Trong loader, đổi 3 dòng parse sau (đang StringToDouble) sang ParseCSVValue(...) để CSV có thể ghi MaxSpreadUSD=2*pip, TrailStepUSD=3*pip, AddSpacingUSD=6*pip:

// Trước đây:
row.MaxSpreadUSD   = StringToDouble(fields[21]);
...
row.TrailStepUSD   = StringToDouble(fields[30]);
...
row.AddSpacingUSD  = StringToDouble(fields[34]);

// Sửa:
row.MaxSpreadUSD   = ParseCSVValue(fields[21], fields[1]);
...
row.TrailStepUSD   = ParseCSVValue(fields[30], fields[1]);
...
row.AddSpacingUSD  = ParseCSVValue(fields[34], fields[1]);


Nhờ vậy preset CSV của bạn sẽ “đa nền tảng symbol” thật sự. 

FX_SweepBOS_EA_v1_sprint_2_EXP

3) Killzones theo symbol (và theo server time)

Với EURUSD nên dùng KZ phiên London/NY. Hiện CSV không đưa KZ time được; mình đề xuất thêm 8 cột KZ1s,KZ1e,...,KZ4e vào UCRow + loader để override theo preset; nếu chưa muốn đổi CSV, tạm thời:

Preset “London/NY”: để UseKillzones=true, cập nhật inputs KZ như (giả sử server GMT+2):

KZ1: 07:55–10:15 GMT → 09:55–12:15 server ⇒ KZ1_StartMin=9*60+55, KZ1_EndMin=12*60+15

KZ2: 12:25–13:45 GMT → 14:25–15:45 server

KZ3: 14:55–16:15 GMT → 16:55–18:15 server

KZ4: 19:55–21:15 GMT → 21:55–23:15 server

Preset “All sessions/quiet”: để UseKillzones=false.
FiltersPass() sẽ không block khi UseKillzones=false. 

FX_SweepBOS_EA_v1_sprint_2_EXP

4) Spread guard theo symbol

Bổ sung EURUSD trong DefaultSpreadForSymbol():

if(StringFind(symbol_name,"EURUSD",0) >= 0) { hi = 0.00025; lo = 0.00010; return true; }


Và/hoặc cho phép CSV set MaxSpreadUSD=2*pip như ở (2). 

FX_SweepBOS_EA_v1_sprint_2_EXP

5) Nhỏ nhưng đáng chú ý

AddSpacingUSD/Pyramid: hiện tại bên trong ConsiderPyramidAdds() bạn có set g_addCount=0 ngay trước khi g_addCount++ — vẫn ra 1 nhưng reset không cần thiết; có thể bỏ reset đó để biến đếm nhất quán hơn. 

FX_SweepBOS_EA_v1_sprint_2_EXP

CsvHeader()/BuildDataRow(): đã ổn để log kết quả; giữ nguyên. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Cách dùng nhanh cho EURUSD

Thêm/merge file tải ở trên vào project như \Files\usecases_list.csv (resource).

Set UsePreset=true, PresetID = 201..208, InpSymbolSelector=2 (hoặc InpSymbol="EURUSD").

Cập nhật KZ inputs theo server (nếu dùng preset có KZ).

(Khuyến nghị) Thêm NormalizeFXUnits(); và sửa loader ở mục (2) để dùng *pip.

Kết luận

Lý do chính EURUSD “không chạy”: lệch đơn vị & KZ bị tune cho XAU → lệnh EURUSD hoặc không vào, hoặc lot siêu nhỏ/không hợp lệ.

Với bộ preset CSV EURUSD (201–208) mình đã chuẩn hoá, cộng thêm 2 sửa nhỏ trong code (normalize đơn vị FX + cho phép *pip ở nhiều field), EA sẽ chạy tốt cho mọi symbol FX, không chỉ XAU. 

FX_SweepBOS_EA_v1_sprint_2_EXP

Nếu bạn muốn, mình có thể tiếp tục dựng thêm bộ preset riêng cho GBPUSD/USDJPY, hoặc nâng loader để nhận cả *atr (ví dụ 1.5*atr) cho offsets/trailing — rất hợp với biến động khác nhau giữa majors