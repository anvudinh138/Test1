# QUICK REFERENCE – Inputs chính (tối thiểu cần nhớ)

- **InpUsecase**: chọn preset. 18/19 an toàn, 21/23/29 cho performance khác.
- **Lots & Risk**
  - `InpFixedLots` (mặc định 0.10). 
  - Dùng %balance: `InpRiskPercent>0` và để `InpFixedLots=0`.
- **Push**
  - `InpPushAvgATRmult` / `InpPushMaxATRmult` → yêu cầu xung lực theo ATR.
- **Wick**
  - A: `WickFracBase` + `min(12p, 0.25*ATR)`
  - B: `WickFracAlt` + `min(45p, max(12p, StrongWickATR*ATR))` (nắp 45p).
- **Sweep**
  - `RequireSweep=true` + `SweepSoftFallback=true` ⇒ cho phép bỏ sweep nếu momentum mạnh (max-range ~ATR hoặc WickB).
- **Round Number**
  - `RoundNumberAvoid=true`, buffer Maj/Min (100p/50p grid) → 6p/4p (strict).
- **Spread gate**
  - `MaxSpread=12`, `MaxSpreadLowVol=10`, `LowVolThreshold=95` (ATRp).
- **Exits (floors)**
  - `SL_ATR_Mult=0.45`, `SL_Fixed=25` (chọn max với nắp ATR)
  - Adaptive (`v3.8.0`):  
    - BE ≈ max(14p, 0.10*ATR) cap 22  
    - Partial ≈ max(18p, 0.15*ATR) cap 30  
    - Trail ≈ max(20p, 0.20*ATR) start; step ≈ max(16p, 0.12*ATR) cap 26  
    - Early-cut ≈ max(12p, 0.22*ATR) cap 40
- **Pending engine**
  - `InvalidateBufferPips` & `InvalidateDwellSec` **được cộng thêm phần động theo ATR**.
  - `AfterCancelCooldownS=45` + **re-arm window 60s** (cho phép bỏ cooldown một lần).
- **Anti-chop**
  - Sau **early-cut** chặn re-entry cùng hướng **5 phút**.

Mẹo nhanh:
- Spread cảnh báo nhiều → tăng `MaxSpread` 2–3p *hoặc* dùng **usecase 25**.
- “wick too small” liên tục → dùng **usecase 20/21**.
- “bias block” nhiều và bạn thấy tín hiệu hợp lý → giảm slope (25) bằng **usecase 21**.
