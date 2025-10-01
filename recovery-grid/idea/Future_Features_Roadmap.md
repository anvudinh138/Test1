# Future Features Roadmap

## 📋 Overview

Danh sách các features được đề xuất để cải thiện Recovery Grid Direction v2, được sắp xếp theo độ ưu tiên và tác động.

**Current Status**: ✅ Partial Close implemented (v2.1)

---

## 🎯 Priority 1: Dynamic Target Scaling

### Problem
- `InpTargetCycleUSD` cố định → không adapt với market volatility
- High volatility: Target quá gần, bỏ lỡ profit lớn
- Low volatility: Target quá xa, hold positions quá lâu
- Deep DD: Target cố định kéo dài recovery time

### Solution
Scale target động dựa trên 3 factors:

**1. ATR Factor** (Volatility adaptation):
```cpp
double atr_current = ATRPoints();
double atr_ratio = (atr_current > 0 && m_initial_atr > 0)
                   ? (atr_current / m_initial_atr)
                   : 1.0;
```

**2. DD Factor** (Faster escape):
```cpp
double dd_ratio = (m_pnl_usd < 0)
                  ? (1.0 + MathAbs(m_pnl_usd) / InpDdScaleFactor)
                  : 1.0;
```

**3. Time Factor** (Reduce long-tail):
```cpp
double bars_in_trade = CurrentBarIndex() - m_entry_bar;
double time_ratio = 1.0 / (1.0 + bars_in_trade * InpTimeDecayRate);
```

**Combined formula**:
```cpp
double adjusted_target = base_target * atr_ratio * time_ratio;
if(m_pnl_usd < 0)
    adjusted_target = adjusted_target / dd_ratio;
adjusted_target = MathMax(adjusted_target, base_target * 0.5); // Floor
adjusted_target = MathMin(adjusted_target, base_target * 3.0); // Cap
```

### Parameters
```cpp
input double InpDtsAtrWeight      = 1.0;   // ATR influence (0=disable)
input double InpDtsTimeDecayRate  = 0.01;  // Time decay per bar
input double InpDdScaleFactor     = 50.0;  // DD threshold for scaling
input double InpDtsMinMultiplier  = 0.5;   // Min target multiplier
input double InpDtsMaxMultiplier  = 3.0;   // Max target multiplier
```

### Benefits
- ✅ Catch bigger moves in volatile markets (+10-20% profit)
- ✅ Exit faster when stuck in consolidation
- ✅ Reduce average holding time
- ✅ Better profit factor

### Complexity
⭐⭐⭐ (Medium) - ~2 hours implementation

### Expected Impact
- Win rate: +5-10%
- Avg profit per trade: +15-25%
- Max holding time: -20-30%

---

## 🛡️ Priority 2: Smart Stop Loss with Breakeven Trail

### Problem
- Không có hard SL per position → flash crash risk
- Extreme news events có thể wipe account
- Winner không được protect khi revert

### Solution

**1. Initial Stop Loss**:
```cpp
double sl_distance = spacing_px * InpSlMultiplier;
if(direction == DIR_BUY)
    sl_price = entry - sl_distance;
else
    sl_price = entry + sl_distance;
```

**2. Breakeven Trigger**:
```cpp
if(basket_pnl >= InpBreakevenThreshold_USD)
{
    // Move all SLs to breakeven (entry price)
    for(each position in basket)
        ModifySL(ticket, entry_price);
}
```

**3. Trailing by Basket Average**:
```cpp
if(InpTrailByAverage && basket_pnl > 0)
{
    double new_sl = m_avg_price + (InpTrailOffset_Points * point);
    if(IsBetterSL(new_sl, current_sl))
        ModifyAllSL(new_sl);
}
```

### Parameters
```cpp
input bool   InpSslEnabled           = false; // Master switch
input double InpSlMultiplier         = 3.0;   // SL distance (× spacing)
input double InpBreakevenThreshold   = 5.0;   // USD profit to move BE
input bool   InpTrailByAverage       = true;  // Trail from avg price
input int    InpTrailOffset_Points   = 100;   // Trail offset in points
input bool   InpSslRespectMinStop    = true;  // Respect broker min stop
```

### Benefits
- ✅ **Hard protection** against flash crashes
- ✅ Lock profits earlier (reduce givebacks)
- ✅ Professional risk management
- ✅ Suitable for live trading

### Complexity
⭐⭐⭐⭐ (Medium-High) - ~3-4 hours implementation

### Risks to Consider
- Broker stop level restrictions
- Slippage during execution
- Potential premature SL hits in volatile markets

### Testing Checklist
- [ ] Test with broker min stop level
- [ ] Backtest on flash crash events (2020-03-12, CHF spike)
- [ ] Verify SL modification frequency (avoid spam)
- [ ] Test interaction with Partial Close

---

## 📊 Priority 3: Adaptive Grid Spacing

### Problem
- Fixed spacing → overtrading trong low volatility
- Fixed spacing → miss entries trong high volatility
- Market regime changes không được adapt

### Solution

**Real-time Spacing Adjustment**:
```cpp
void UpdateAdaptiveSpacing()
{
    if(!InpAdaptiveSpacingEnabled) return;

    double atr_current = ATRPoints();
    double new_spacing = atr_current * InpAgsAtrMultiplier;

    // Apply constraints
    new_spacing = MathMax(new_spacing, InpAgsMinSpacingPips);
    new_spacing = MathMin(new_spacing, InpAgsMaxSpacingPips);

    // Check if change is significant
    double spacing_change = MathAbs(new_spacing - m_current_spacing);
    if(spacing_change > InpAgsRebuildThreshold)
    {
        RebuildGridLevels(new_spacing);
        LogEvent("Spacing adjusted: " + DoubleToString(m_current_spacing)
                 + " → " + DoubleToString(new_spacing));
    }
}

void RebuildGridLevels(double new_spacing)
{
    // Keep filled positions unchanged
    // Cancel existing pendings
    // Place new pendings with new_spacing
    // Update m_current_spacing
}
```

### Parameters
```cpp
input bool   InpAdaptiveSpacingEnabled = false;
input double InpAgsAtrMultiplier       = 0.7;   // Spacing = ATR × this
input double InpAgsMinSpacingPips      = 10.0;  // Floor
input double InpAgsMaxSpacingPips      = 50.0;  // Ceiling
input double InpAgsRebuildThreshold    = 5.0;   // Min change to rebuild (pips)
input int    InpAgsUpdateBars          = 10;    // Check every N bars
```

### Benefits
- ✅ Optimal entry distribution per regime
- ✅ Reduce overtrading (-30-40% total orders)
- ✅ Better capture trending moves
- ✅ Lower commission costs

### Complexity
⭐⭐⭐⭐⭐ (High) - ~5-6 hours implementation

### Technical Challenges
- Maintain grid integrity during rebuild
- Prevent order spam during adjustment
- Handle edge cases (all positions filled)
- Coordinate with dynamic grid refill

---

## ⏰ Priority 4: Time-based Risk Management

### Problem
- Grid active 24/7 → exposed to high-impact news
- NFP, FOMC, CPI releases cause whipsaws
- No awareness of illiquid sessions (Asian open)

### Solution

**News Avoidance Windows**:
```cpp
struct SNewsWindow
{
    int start_hour;
    int start_minute;
    int end_hour;
    int end_minute;
};

bool IsNewsTime()
{
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);

    for(int i = 0; i < ArraySize(m_news_windows); i++)
    {
        if(IsWithinWindow(dt, m_news_windows[i]))
            return true;
    }
    return false;
}

void Update()
{
    if(IsNewsTime())
    {
        // Pause new orders
        m_allow_new_orders = false;

        // Optional: Tighten SL if SSL enabled
        if(InpTrmTightenSL && InpSslEnabled)
            TightenStopLoss(InpTrmSLMultiplier);

        // Log warning
        if(m_log) m_log.Event(Tag(), "News window active - paused");
        return;
    }

    // Normal flow...
}
```

**Parse news schedule**:
```cpp
// Input: "08:30-09:00,14:00-14:30,20:00-20:15" (UTC)
void ParseNewsWindows(string csv)
{
    string parts[];
    StringSplit(csv, ',', parts);

    for(int i = 0; i < ArraySize(parts); i++)
    {
        // Parse "HH:MM-HH:MM" format
        // Add to m_news_windows[]
    }
}
```

### Parameters
```cpp
input bool   InpTrmEnabled       = false;
input string InpNewsWindows      = "08:30-09:00,14:00-14:30"; // UTC
input bool   InpTrmPauseOrders   = true;   // Stop new orders
input bool   InpTrmTightenSL     = false;  // Tighten SL (requires SSL)
input double InpTrmSLMultiplier  = 0.5;    // SL tightening factor
input bool   InpTrmCloseOnNews   = false;  // Close all before news
```

### Benefits
- ✅ Avoid news spike whipsaws
- ✅ Reduce unexpected drawdowns
- ✅ Professional risk approach
- ✅ Easy to configure

### Complexity
⭐⭐ (Low-Medium) - ~1-2 hours implementation

### Use Cases
- Avoid NFP (first Friday, 08:30 EST)
- Avoid FOMC (2pm EST, 8 times/year)
- Avoid illiquid Asian session (optional)

---

## 📈 Priority 5: Profit Compounding Mode

### Problem
- Fixed `InpLotBase` → không tận dụng profit growth
- Account tăng 50% nhưng vẫn trade same lot
- Missed exponential growth opportunity

### Solution

**Auto-adjust Lot Base**:
```cpp
void UpdateCompoundedLot()
{
    if(!InpCompoundingEnabled) return;

    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double growth_ratio = current_balance / m_initial_balance;

    double new_lot_base = InpLotBase * growth_ratio;

    // Apply constraints
    new_lot_base = MathMin(new_lot_base, InpMaxCompoundedLot);
    new_lot_base = NormalizeVolume(new_lot_base);

    if(new_lot_base != m_params.lot_base)
    {
        m_params.lot_base = new_lot_base;
        if(m_log)
            m_log.Event(Tag(), "Lot base adjusted: "
                        + DoubleToString(new_lot_base, 2));
    }
}
```

**Trigger Points**:
1. After each basket close (cycle complete)
2. Every `InpCompoundCheckBars` bars
3. When balance increases > `InpCompoundThreshold`%

### Parameters
```cpp
input bool   InpCompoundingEnabled  = false;
input double InpMaxCompoundedLot    = 1.0;    // Safety cap
input double InpCompoundThreshold   = 10.0;   // Min % growth to adjust
input int    InpCompoundCheckBars   = 100;    // Check frequency
input bool   InpCompoundOnDD        = false;  // Also reduce on DD
```

### Benefits
- ✅ Exponential growth potential
- ✅ Natural position sizing
- ✅ Adapt to account evolution
- ✅ Simple implementation

### Complexity
⭐⭐ (Low) - ~1 hour implementation

### Safety Considerations
- **MUST have `InpMaxCompoundedLot` cap**
- Consider drawdown reduction on losses
- Log all adjustments clearly
- Test thoroughly before live

---

## 📅 Implementation Roadmap

### Phase 1: Risk Reduction (Week 1-2)
- ✅ Partial Close (Done)
- 🔲 Dynamic Target Scaling
- 🔲 Smart Stop Loss

### Phase 2: Optimization (Week 3-4)
- 🔲 Time-based Risk Management
- 🔲 Adaptive Grid Spacing

### Phase 3: Growth (Week 5+)
- 🔲 Profit Compounding Mode

---

## 🎯 Current Focus: Dynamic Target Scaling

**Next steps**:
1. Create detailed spec: `/idea/Dynamic_Target_Scaling.md`
2. Design algorithm with backtest scenarios
3. Implement in `GridBasket::CalculateGroupTP()`
4. Add parameters to EA inputs
5. Backtest with multiple ATR regimes
6. Compare vs fixed target baseline
7. Optimize multipliers
8. Document and commit

**Estimated completion**: 2-3 days

---

## 📊 Success Metrics

Track these KPIs per feature:

| Metric | Baseline (v2.0) | Target (v2.2) |
|--------|-----------------|---------------|
| Max DD % | 65% | < 20% |
| Avg Win Rate | 70% | > 75% |
| Profit Factor | 1.8 | > 2.0 |
| Avg Hold Time | 12 bars | < 8 bars |
| Recovery Speed | 50 bars | < 30 bars |

---

## 💡 Additional Ideas (Backlog)

### Low Priority / Nice to Have:
1. **Martingale Mode**: Optional lot multiplier > 1.0 for faster recovery (risky)
2. **Correlation Filter**: Avoid opening hedge when correlated pairs already active
3. **Volatility Regime Detection**: ML-based regime classification
4. **Web Dashboard**: Real-time monitoring via web interface
5. **Telegram Notifications**: Push alerts for PC triggers, DD warnings
6. **Multi-Symbol Support**: Run same magic on multiple pairs with shared ledger
7. **Sentiment Integration**: Use COT/sentiment data for directional bias

---

**Document Version**: 1.0
**Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Author**: Recovery Grid Direction v2 Team

**Note**: Always backtest thoroughly before live deployment. Risk management is paramount.
