# 🥇 Gold (XAUUSD) Trading Guide

## ⚠️ CRITICAL: Gold is NOT Forex!

XAUUSD has **completely different** trading rules than currency pairs:

### 🔴 Lot Size Restrictions

| Symbol | Min Lot | Lot Step | Example Valid Lots |
|--------|---------|----------|-------------------|
| **EURUSD** | 0.01 | 0.01 | 0.01, 0.02, 0.03... |
| **XAUUSD** | 0.01 | 0.01 | **0.01 ONLY** (no 0.02, 0.03!) |

**Why this matters**:
- EURUSD: Can use 0.01, 0.02, 0.05, 0.10 ✅
- XAUUSD: Can ONLY use 0.01 ❌ (broker specific)

Some brokers allow 0.04, 0.05 but most **ONLY allow 0.01 increments**.

### 🔴 Features to DISABLE for Gold

1. **Profit Acceleration** ❌
   - Booster lots = base_lot * multiplier
   - Example: 0.01 * 2.0 = 0.02 → **INVALID VOLUME** ❌
   - Must set `InpProfitAccelEnabled = false`

2. **Range Detection Lot Multiplier** ❌
   - Range mode: lot * 2.0 = 0.02 → **INVALID VOLUME** ❌
   - Must set `InpRangeLotMultiplier = 1.0` (no change)

3. **Rescue Delta Deploy** ❌
   - Delta = 0.05 - 0.01 = 0.04 → Try deploy 0.04 → **INVALID VOLUME** ❌
   - Must set `InpRescueEnabled = false` OR keep delta = 0.01

4. **Lot Scaling** ❌
   - Martingale: 0.01 * 1.5 = 0.015 → **INVALID VOLUME** ❌
   - Must set `InpLotScale = 1.0` (flat lot only)

---

## ✅ Gold-Specific Settings

### 1. Wider Spacing
```
InpSpacingAtrMult = 2.0    // Gold moves 10x faster than forex
InpSpacingPips = 50        // Wide spacing
InpSpacingMode = ATR       // ATR better for Gold
```

### 2. Fewer Grid Levels
```
InpGridLevels = 5          // Gold too volatile for 10+ levels
InpWarmLevels = 3          // Start small
```

### 3. Higher Risk Parameters
```
InpJobSL_USD = 100.0       // Gold moves bigger
InpSessionSL_USD = 200.0   // Double the forex setting
InpTargetCycleUSD = 20.0   // Higher TP
```

### 4. Lower Exposure
```
InpExposureCapLots = 0.5   // Max 0.5 lot total (5 jobs * 0.01)
InpMaxJobs = 2             // Fewer concurrent jobs
```

### 5. Faster Spawn Cooldown
```
InpSpawnCooldownSec = 30   // Gold moves fast, need quick response
```

---

## 🧪 Testing Gold EA

### Step 1: Load XAUUSD Preset
```
Strategy Tester → Settings → Load
→ best-input/XAUUSD_MULTI_JOB.set
```

### Step 2: Symbol Settings
```
Symbol: XAUUSD
Period: M5
Date: Last 3 months
Model: Every tick
Deposit: $10,000
```

### Step 3: Verify Lot Settings
**Before starting test, check**:
- `InpLotBase = 0.01` ✅
- `InpLotScale = 1.0` ✅
- `InpProfitAccelEnabled = false` ✅
- `InpRescueEnabled = false` ✅
- `InpRangeLotMultiplier = 1.0` ✅

### Step 4: Expected Results
```
✅ All orders = 0.01 lot (never 0.02, 0.03, etc.)
✅ No "Invalid volume" errors
✅ EA runs full 3 months
✅ Session SL not hit (set to $200)
```

---

## 🔍 Common Errors & Fixes

### Error: "Invalid volume" on 0.0075 lot
**Cause**: Rescue delta trying to deploy 0.0075
**Fix**: `InpRescueEnabled = false`

### Error: "Invalid volume" on 0.02 lot
**Cause**: Booster multiplier (0.01 * 2 = 0.02)
**Fix**: `InpProfitAccelEnabled = false`

### Error: Session SL hit too early
**Cause**: Gold DD larger than forex
**Fix**: `InpSessionSL_USD = 200.0` (or higher)

### Error: Too many spawns, cooldown blocking
**Cause**: 120 sec cooldown too long for Gold
**Fix**: `InpSpawnCooldownSec = 30`

---

## 📊 Expected Performance (Gold)

### Conservative Target (XAUUSD_MULTI_JOB.set)
- Profit Factor: 1.5+
- Max DD: <25%
- Win Rate: 75%+
- Monthly Return: 10-15%

### Why Lower than Forex?
- Gold 10x more volatile
- Restricted lot sizes limit scaling
- No profit acceleration
- Fewer jobs (2 vs 3)
- Higher SL per job ($100 vs $50)

---

## 🎯 Optimization Tips

### For Stable Gold Market
```
InpSpacingAtrMult = 1.5    // Tighter spacing
InpGridLevels = 8          // More levels
InpMaxJobs = 3             // More jobs
```

### For Volatile Gold Market
```
InpSpacingAtrMult = 3.0    // Wider spacing
InpGridLevels = 3          // Fewer levels
InpMaxJobs = 1             // Single job only
InpSessionSL_USD = 500.0   // Much higher SL
```

### For News Trading (NFP, FOMC, CPI)
```
InpTRMEnabled = true
InpTRMImpactFilter = HIGH  // Only high-impact news
InpTRMBufferMinutes = 60   // 1 hour before/after
InpSpawnCooldownSec = 120  // Don't spawn during news
```

---

## ⚡ Quick Comparison

| Feature | EURUSD | XAUUSD |
|---------|--------|--------|
| **Lot Step** | 0.01 | 0.01 ONLY |
| **Spacing** | 0.5x ATR | 2.0x ATR |
| **Grid Levels** | 10 | 5 |
| **Max Jobs** | 3 | 2 |
| **Job SL** | $50 | $100 |
| **Session SL** | $100 | $200 |
| **Profit Accel** | ✅ ON | ❌ OFF |
| **Rescue** | ✅ ON | ❌ OFF |
| **Range Lot Mult** | 2.0x | 1.0x |
| **Spawn Cooldown** | 60s | 30s |

---

## 🚨 CRITICAL RULES

1. **ALWAYS use 0.01 lot base** for Gold
2. **NEVER enable lot multipliers** (Accel, Range, Rescue)
3. **NEVER use martingale** (LotScale = 1.0 only)
4. **ALWAYS use wider spacing** (2x+ ATR)
5. **ALWAYS use higher SL** (2x forex settings)

**Remember**: Gold is 10x more volatile and has strict lot rules. Conservative settings are key to survival!

---

## 📝 Checklist Before Going Live

- [ ] Tested on demo for 1+ month
- [ ] No "Invalid volume" errors in logs
- [ ] All lots = 0.01 (checked in history)
- [ ] Max DD acceptable for your account
- [ ] Session SL set to 2-5% of balance
- [ ] TRM enabled for news protection
- [ ] Spawn cooldown appropriate for market
- [ ] Verified broker allows 0.01 lot for Gold

Good luck trading Gold! 🥇