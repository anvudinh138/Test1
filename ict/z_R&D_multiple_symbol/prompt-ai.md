PROMPT · Refactor EA MQL5 sang Multi-Symbol (1 chart chạy nhiều symbol)

Bạn là Senior MQL5 engineer. Tôi sẽ đưa một file EA MQL5 đơn (đang chạy XAU, có ~51 usecase logic: Sweep → BOS → Retest → Entry). Hãy refactor sang đa-symbol trên 1 chart với thay đổi tối thiểu (không đụng vào logic tín hiệu), theo yêu cầu dưới đây:

Mục tiêu

1 EA gắn 1 chart nhưng quét & giao dịch nhiều symbol trong InpSymbolsCSV.

Chạy bằng OnTimer (ưu tiên EventSetMillisecondTimer), không phụ thuộc OnTick của chart-symbol.

Không dùng _Symbol trực tiếp trong dữ liệu/lệnh — luôn dựa trên hàm Sym().

Lot cố định mặc định: 0.01 (clamp theo min/step), không auto-risk trừ khi tôi bật.

SL/TP an toàn: nếu tôi đưa khoảng cách giá (ví dụ 0.570), tự đổi sang giá tuyệt đối, đúng phía BUY/SELL, ≥ StopsLevel, và NormalizeDouble.

Đếm/giới hạn vị thế theo symbol + magic (an toàn khi có nhiều EA).

Log report per-symbol ở OnDeinit() (không cần CSV).

Kiến trúc bắt buộc

Inputs thêm mới

UseMultiSymbol (bool), InpSymbolsCSV (string), InpTF (ENUM_TIMEFRAMES)

Timer: UseMsTimer (bool), InpTimerMs (int), InpTimerSeconds (int)

Khối lệnh: UseFixedLot (bool=true), InpFixedLot (double=0.01), MaxSpreadPrice, MaxOpenPerSymbol=1, MarginBufferPct=5.0, Debug (bool)

MagicBase (int)

State đa-symbol

struct SymState { string sym; datetime last_bar_time; int state; /* giữ chỗ cho flags bạn cần */ };
SymState gSyms[];
string CurrSymbol="";
string Sym(){ return UseMultiSymbol ? CurrSymbol : InpSymbol; }
int FindSymIdx(const string s){ for(int i=0;i<ArraySize(gSyms);++i) if(gSyms[i].sym==s) return i; return 0; }


Vòng đời

OnInit: parse CSV → gSyms, SymbolSelect(sym,true), set timer (ms nếu bật).

OnTimer: for mỗi symbol: set CurrSymbol, set Magic = MagicBase + idx, nạp/lưu state, gọi ProcessSingle().

ProcessSingle():

CopyRates(Sym(), InpTF, …, rates); chạy khi bar đã đóng (rates[1].time thay đổi).

Gọi pipeline y như bản cũ (Sweep→BOS→Retest→Entry).

Quản lý lệnh nếu có.

OnTick để trống (mọi thứ chạy trên timer).

OnDeinit: tổng hợp History (backup) + log report per-symbol.

Quy tắc sửa code

Thay tất cả _Symbol/InpSymbol trong API dữ liệu/giao dịch bằng Sym().

Không đụng điều kiện 51 usecase — chỉ “bọc” quanh.

Dùng hằng mới: ACCOUNT_MARGIN_FREE (không dùng ACCOUNT_FREEMARGIN).

Luôn check trả về của OrderCalcMargin(...) (nếu fail → log + bỏ lệnh).

Hàm tiện ích phải có (signature chính xác)
// lot cố định & clamp
double ComputeFixedLot(const string s, double desired);
// spread hiện tại theo "price"
double SpreadPrice();
// kiểm tra margin trước khi gửi
bool CanAfford(const string s, bool isShort, double vol, double bufferPct);

// Đếm vị thế (netting-friendly) của đúng EA (symbol+magic)
int PositionsOnSymbol(){
  long myMagic = MagicBase + FindSymIdx(Sym());
  if(!PositionSelect(Sym())) return 0;
  long mg=0; PositionGetInteger(POSITION_MAGIC, mg);
  return (mg==myMagic ? 1 : 0);
}

// Stops helpers
struct StopSpec { double point; int digits; double stopLevel; };
void GetStopsSpec(const string s, StopSpec &sp);
// Sửa SL/TP: nếu sl/tp nhỏ → hiểu là "khoảng cách", đổi sang GIÁ; đúng phía; ≥ StopsLevel; normalize
void FixStopsForMarket(const string s, bool isShort, double &sl, double &tp);

// Wrapper gửi lệnh (CHỈ log "OK" khi retcode DONE/PLACED)
bool SendMarket(bool isShort, double lots, double sl, double tp);

Thay thế điểm vào lệnh

Ở chỗ vào BUY: SendMarket(false, lots, sl_input, tp_input);

Ở chỗ vào SELL: SendMarket(true, lots, sl_input, tp_input);

sl_input/tp_input có thể là khoảng cách giá (vd XAU 0.570). FixStopsForMarket tự đổi sang GIÁ hợp lệ.

Báo cáo cuối kỳ (log, không CSV)

Tạo mảng gRep[] theo symbol; thu thập qua OnTradeTransaction (lọc DEAL_ENTRY_OUT + DEAL_MAGIC đúng magic);

Cuối kỳ OnDeinit: gọi AggregateFromHistory() (backup) rồi in LogSymbolReport("OnDeinit"):
Symbol, Trades, Win, Loss, WinRate%, Volume, GP, GL, Commission, Swap, Net.

Những bẫy phải né (bắt buộc)

Không dùng PositionGetString(POSITION_SYMBOL) trả về trực tiếp. Dùng:
string psym=""; PositionGetString(POSITION_SYMBOL, psym);

Nếu IDE không ổn với PositionSelectByIndex, cho phép fallback netting như PositionsOnSymbol() ở trên.

Không in “Market BUY/SELL placed” trước khi kiểm tra ResultRetcode().

OrderCalcMargin(...) phải if(!OrderCalcMargin(...)) → log + return.

Đổi hết ACCOUNT_FREEMARGIN → ACCOUNT_MARGIN_FREE.

Khi backtest, tên file/log không chứa : nếu có ghi file (Windows).

Acceptance Criteria

Compile không lỗi (cảnh báo cho phép nhưng không còn deprecated/implicit).

Gắn EA vào 1 chart:

Timer chạy (ms nếu bật), mỗi bar đóng in log [SYMBOL] New bar … (nếu tôi bật Debug).

Trong Strategy Tester, phần log cuối có dòng total ticks for all symbols > ticks của chart-symbol (tức đã multi-symbol).

OnDeinit in bảng tổng hợp per-symbol.

Khi tôi đưa sl_input nhỏ (vd 0.570), không còn Invalid stops — wrapper tự chỉnh.

Với MaxOpenPerSymbol=1, EA không mở chồng lệnh trên cùng symbol.

Khi margin thiếu (ví dụ leverage 1:1), log hiển thị Not enough margin: need=..., free=....

Cách bạn làm việc với file của tôi

Đọc file EA tôi dán (hoặc attach).

Áp dụng kiến trúc & hàm ở trên trực tiếp vào file của tôi (đừng tạo EA mới trừ khi tôi yêu cầu).

Sửa tối thiểu: thay _Symbol/InpSymbol → Sym(), chèn OnTimer/state, thêm wrapper đặt lệnh, thêm logging cuối kỳ.

Trả về diff hoặc file hoàn chỉnh. Nếu có chỗ mơ hồ (ví dụ tp đang là price hay distance), ưu tiên coi là distance và ghi chú rõ.