# Playbook tối ưu nhanh

1) Baseline: UC18 & UC19 (2 run).
2) Batch: chạy UC20→29 (10 run).
3) Chọn top 2–3 theo PF, Sharpe, MaxDD, số lệnh (cân đối).
4) Stress:
   - Spread +2p; trượt giá giả 100–200ms; OOS khung 2–4 tuần khác.
   - Nếu preset vẫn > PF ~1 và DD hợp lý → giữ.
5) Tinh cuối:
   - Nếu cancel nhiều nhưng lãi tốt → tăng dwell +2s; giữ buffer.
   - Nếu WR tốt nhưng profit nhỏ → chọn UC22/23/29.
   - Nếu log “bias block” nhiều → UC21 (slope 25) hoặc bật `AllowContraBiasOnStrong`.
6) Sau cùng: bật Risk% hoặc Auto-lot theo mục tiêu rủi ro/ngày.
