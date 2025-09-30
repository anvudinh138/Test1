Roadmap ưu tiên (cao → thấp)

Trend Lockdown — “kill-switch” khi trend kéo xa
Tác động: chặn DCA/rescue chạy đua theo trend, giữ hedge gọn, giảm DD cực nhanh. Độc lập, dễ test.
Chạm code: CLifecycleController (flags + enter/exit), CGridBasket (cancel pending xa, tighten trail). 

Trend_Lockdown

Partial Close — cắt bớt rổ thua ở nhịp retest
Tác động: kéo gần Group TP, giải phóng margin, phối hợp cực tốt với lockdown. Độ phức tạp vừa.
Chạm code: CLifecycleController::Can/ExecutePartialClose, CGridBasket (close subset, guard reseed vùng vừa đóng). 

Partial_Close

Adaptive Spacing — nới spacing/giảm lot theo thời gian ở DD
Tác động: giảm tốc độ DCA khi “gồng” lâu, tránh runaway exposure; tương thích lockdown + partial close.
Chạm code: CGridBasket (EffectiveSpacing/LotScale, tier state), dùng ATR floor từ CSpacingEngine. 

Adaptive_Spacing

Hedge Retest (reseeding thông minh)
Tác động: tránh reseed hedge ngay sau khi chốt lời; đợi retest rõ ràng → vào “đúng nhịp”, bớt spam lệnh.
Chạm code: CLifecycleController (state “waiting_for_retest”, điều kiện ATR/slope/confirm bars trước TryReseedBasket). 

Hedge_Retest

Dynamic Grid (refill theo lô nhỏ)
Tác động: giảm lag khi grid_levels lớn, spacing/lot của level mới bám ATR “thời điểm refill”. Cấu trúc nhưng ít rủi ro logic.
Chạm code: CGridBasket (warm levels, refill threshold/batch, live vs static spacing). 

Dynamic_Grid

Swap / Rollover Guard
Tác động: tránh mở/giữ lệnh xấu qua giờ swap; option partial/flatten ngày triple swap. Dễ triển khai, lợi ích dài hạn.
Chạm code: CLifecycleController (window detect, block orders, optional partial/flatten). 

Swap_Rollover_Guard

Equity Cushion (insurance basket)
Tác động: thêm nguồn lợi nhuận “đi cùng trend” khi loser kẹt lâu; nhưng tăng độ phức tạp & exposure → làm sau khi 1–6 ổn.
Chạm code: CLifecycleController (insurance state, kích hoạt/thoát, áp lợi nhuận giảm TP loser). 

Equity_Cushion

Parallel Lifecycle (nhiều controller chạy song song)
Tác động: mở rộng chiến lược theo “đợt” mới khi lifecycle cũ kẹt; nhưng thay đổi kiến trúc lớn → để cuối.
Chạm code: thêm CStrategySupervisor, nhiều CLifecycleController + mở rộng CPortfolioLedger để gộp exposure. 

Parallel_Lifecycle