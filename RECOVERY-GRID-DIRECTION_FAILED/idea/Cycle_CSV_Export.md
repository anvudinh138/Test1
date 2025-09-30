# Cycle CSV Export

## Mục tiêu
- Log một dòng CSV ngay khi mỗi basket (BUY/SELL) đóng, nhờ đó tái dựng timeline của từng chu kỳ.
- Cho phép phân tích nhanh trong Excel/Google Sheets: plot PnL, spacing, trạng thái lockdown.
- Bổ sung dữ liệu forensic cho backtest/forward test (PnL, DD, exposure theo cycle).

## Cột dữ liệu đề xuất
| Cột | Mô tả | Nguồn |
|---|---|---|
| `timestamp` | Thời điểm basket đóng | `TimeCurrent()` ngay sau `CloseBasket()` |
| `symbol` | Symbol đang chạy | `m_symbol` của controller |
| `cycle_id` | Bộ đếm chu kỳ của basket | `CGridBasket::CyclesDone()` |
| `direction` | BUY / SELL | `CGridBasket::Direction()` |
| `kind` | PRIMARY / HEDGE | `CGridBasket::Kind()` |
| `realized_usd` | PnL đã chốt của chu kỳ | `TakeRealizedProfit()` |
| `total_lot` | Tổng lot còn mở ngay trước khi đóng | Lưu `m_total_lot` tại `CloseBasket()` |
| `max_dd_usd` | Drawdown sâu nhất trong chu kỳ | Track giá trị nhỏ nhất của `m_pnl_usd` |
| `spacing_pips` | Spacing hiện hành | `m_spacing->SpacingPips()` |
| `adaptive_tier` | Tầng spacing (nếu có adaptive) | Tạm `"n/a"` nếu chưa có engine |
| `lockdown_active` | 0/1 trạng thái lockdown khi đóng | `m_lockdown_active` (tạm `false`) |
| `partial_close_volume` | Lot đã partial trước khi đóng hoàn toàn | Tích lũy khi `CloseFraction()` |
| `hedge_profit_pull` | USD đã dùng để kéo group TP | `m_target_reduction` |
| `session_equity` | Equity tại thời điểm đóng | `AccountInfoDouble(ACCOUNT_EQUITY)` |

## Kiến trúc & hook
1. **CSV writer**: lớp `CCycleCsvWriter` chịu trách nhiệm mở/ghi file CSV (support placeholder `%symbol%`, `%date%`). Ghi header khi file mới tạo.
2. **Cycle metrics**: mở rộng `CGridBasket` để lưu `m_cycle_max_dd`, `m_cycle_partial_volume`, `m_last_cycle_total_lot`. Reset khi seed basket mới; cập nhật ở `RefreshState()` và `CloseFraction()`.
3. **Controller hook**: khi `ClosedRecently()` true, controller lấy các số liệu (`TakeRealizedProfit`, `TakeCycleTotalLot`, `TakeCycleMaxDrawdown`, `TakeCyclePartialVolume`, `TargetReduction`) rồi gọi writer. Sau đó mới chuyển lợi nhuận sang basket đối diện và reseed.
4. **Input mới**: `cycle_csv_path` (string). Rỗng → tắt tính năng. Có thể nhập `logs/%symbol%_%date%_cycles.csv`.
5. **Đường dẫn**: writer tự tạo folder con trong `MQL5/Files` nếu chưa tồn tại (`FolderCreate`).

## Pseudocode
```cpp
if(params.cycle_csv_path != "")
{
    m_cycle_writer.Init(params.cycle_csv_path, symbol);
}

if(basket.ClosedRecently())
{
    double realized = basket.TakeRealizedProfit();
    double totalLot = basket.TakeCycleTotalLot();
    double maxDd    = basket.TakeCycleMaxDrawdown();
    double partial  = basket.TakeCyclePartialVolume();
    double pull     = basket.TargetReduction();

    SCycleCsvRow row = {...};
    m_cycle_writer.Append(row);

    if(realized > 0)
        otherBasket.ReduceTargetBy(realized);
}
```

## Lộ trình triển khai
1. Thêm input `cycle_csv_path` trong EA + `SParams`.
2. Viết `CCycleCsvWriter` (Init, Append, header, placeholder `%symbol%/%date%`).
3. Mở rộng `CGridBasket` cho các biến chu kỳ + method getter (`TakeCycleMaxDrawdown`, `TakeCyclePartialVolume`, `TakeCycleTotalLot`).
4. Hook controller để gọi writer khi basket đóng.
5. Test forward/backtest: bật log, kiểm tra CSV cập nhật sau mỗi cycle, import vào Excel để xác thực header và dữ liệu.

## Ý tưởng mở rộng
- Ghi thêm `mid_price`, `ATR`, `trend_slope` tại thời điểm đóng để phân tích sâu hơn.
- Tách riêng file `lockdown_events.csv` khi khóa/mở.
- Xuất JSON Lines (song song với CSV) để dễ ingest bằng Python.
