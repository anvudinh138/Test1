# Preset map (InpUsecase)

0  = Manual (dùng input hiện tại)
15 = v3.7 – Wick mềm + buffer/dwell động + re-arm
16 = v3.7 – Push dễ (0.58/0.78) + bias slope mềm (25)
17 = v3.7 – SL rộng hơn (SL_ATR=0.50, SLfix=28) + BE/Partial/Trail nới nhẹ
18 = **Strict RN + strict spread** (baseline tốt)
19 = **18 + Adaptive Exits** (BE/Partial/Trail/Early-cut theo ATR)

## Batch (đều bật Adaptive Exits)
20 = Wick hơi mềm (0.33/0.16, Strong 0.33), Push 0.60/0.80
21 = Wick base (0.35/0.18), Push 0.58/0.78, Bias slope 25
22 = Wick chặt (0.37/0.20), Push chặt 0.62/0.82, ATRmin 55
23 = RN/Spread strict; **SL_ATR 0.50 + SLfix 28**
24 = RN medium (MajBuf=5, MinBuf=3), Spread strict
25 = RN strict, **Spread relaxed 15/12**, Push 0.62/0.82
26 = Bias rất chặt (slope 40, **no contra**)
27 = **Tắt require sweep** (soft momentum fallback), RN/Spread strict
28 = **RN off** (để so sánh ảnh hưởng RN), Spread strict
29 = ATRmin 60, Push 0.58/0.78 (lọc low-vol mạnh)

> Gợi ý:
> - Cancel nhiều → thử 21/25/27.
> - WR cao nhưng profit thấp → 22/23/29.
> - Broker spread cao → 25.
