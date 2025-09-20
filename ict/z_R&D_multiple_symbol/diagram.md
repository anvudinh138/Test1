+-----------------------------------------------------------+
|                    Chart bất kỳ (VD: EURUSD)              |
|  Attach EA: Multi-Symbol Sweep/BOS                        |
|                                                           |
|  Inputs: InpSymbolsCSV, InpTF, MagicBase, RiskPct, ...    |
|                                                           |
|  OnInit:                                                  |
|    - Parse "XAUUSD,EURUSD,GBPUSD,USDJPY,..."              |
|    - SymbolSelect(symbol, true)  -> đảm bảo có dữ liệu    |
|    - Tạo gSyms[]: 1 state / symbol (rates[], lastBar, ..) |
|    - EventSetTimer(1s)                                    |
|                                                           |
|  OnTimer (mỗi 1 giây):                                    |
|    for each symbol in gSyms:                              |
|       ProcessSymbol(symbol)                               |
|                                                           |
|  OnDeinit: EventKillTimer()                               |
+-----------------------------------------------------------+

[EA gắn 1 chart] 
   └── OnInit:
        - Parse "XAUUSD,EURUSD,GBPUSD,USDJPY..."
        - Tạo 1 state cho mỗi symbol (lastBar, BOS flags, v.v.)
        - EventSetTimer(1s)
   └── OnTimer (mỗi 1s):
        for từng symbol:
           - CurrSymbol = symbol
           - nạp state(symbol) → biến global
           - CopyRates(CurrSymbol, TF, ...)
           - nếu bar mới (rates[1]) → DetectBOSAndArm → TryEnterAfterRetest
           - ManageOpenPosition (mỗi nhịp)
           - trade.SetExpertMagicNumber(MagicBase + idx)
           - lưu biến global → state(symbol)


ProcessSymbol(symbol):
  1) CopyRates(symbol, TF, ... , rates[])  (ArraySetAsSeries=true)
  2) Nếu CHƯA có bar mới đã đóng (rates[1].time == lastClosedBar) -> THOÁT
  3) Cập nhật lastClosedBar = rates[1].time
  4) Chạy pipeline tín hiệu theo SYMBOL:
        Sweep  -> BOS -> Retest -> Filters (KZ/RN/VSA/Spread)
  5) Tính khối lượng theo rủi ro (CalcLotByRisk(symbol, ...))
  6) Đặt lệnh ĐÚNG symbol (trade.Buy/Sell(..., symbol, ...))
        + Magic = MagicBase + idx(symbol)


CheckAndTrade_SweepBOS(symbol, rates[]):
  - Detect Sweep @bar=1 (không dùng bar 0)
  - Xác nhận BOS trong N bar gần nhất
  - Filters (Killzone, Round Number, VSA, MaxSpread)  <-- dùng dữ liệu của symbol đang xét
  - Retest (M bar tối đa)
  - Entry + SL/TP  (theo preset hiện có)
  - Ghi log theo symbol (để debug)

Ghi nhớ 5 nguyên tắc “đa-symbol” (rất quan trọng)

Không dùng _Symbol trong data & trade → luôn truyền symbol vào CopyRates/CopyTicks, trade.Buy/Sell, v.v.

OnTimer là “đồng hồ” cho tất cả symbol (OnTick chỉ kích hoạt theo chart-symbol, dễ lỡ nhịp).

SymbolSelect(symbol, true) ở OnInit để Market Watch nạp dữ liệu cho các symbol “ngầm”.

Chạy trên bar đã đóng (shift=1) để tránh repaint; lưu lastClosedBar riêng cho từng symbol.

MagicNumber theo symbol (MagicBase + index) để quản lý vị thế/đóng lệnh đúng cặp.