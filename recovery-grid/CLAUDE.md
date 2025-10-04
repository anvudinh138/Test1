# Claude Development Notes

## Feature Implementation Checklist

### ✅ Completed Features

#### 1. Timeframe Switch Fix (Issue #3)
- **Flag**: `InpPreserveOnTfSwitch = true` (default ON)
- **Purpose**: Prevent position duplication when switching chart timeframes
- **Safe**: Can disable if needed, no impact on core logic
- **Files**: LifecycleController.mqh, GridBasket.mqh, Params.mqh, EA main
- **Commit**: Ready to commit after testing

### 🔄 In Progress

#### 2. Manual Close Detection (Issue #1) - NEXT
- **Flag**: `InpMcdEnabled = true` (default ON for safety)
- **Purpose**: Detect when user manually closes positions and properly transfer profits
- **Problem**:
  - User close loser → winner profit lost (not transferred)
  - User close winner → loser orphaned (no rescue)
  - User close both → EA freezes
- **Solution**:
  - Track `prev_total_lot`, `prev_pnl` before RefreshState()
  - Detect position disappear → capture PnL → set `m_manual_close_detected = true`
  - Transfer profit to opposite basket in LifecycleController
- **Estimated Time**: ~30 minutes
- **Risk**: LOW (can disable via flag)

### 📋 Pending Features

#### 3. Graceful Shutdown (Issue #2) - AFTER #1
- **Flag**: Chart button (visual control, no input needed)
- **Purpose**: Safe EA shutdown before removal
- **Solution**:
  - Chart button "⏻ SHUTDOWN EA"
  - 30-minute timeout
  - Close profitable positions first
  - Force close all at timeout
  - Button shows countdown + status color
- **Estimated Time**: ~45 minutes
- **Risk**: LOW (manual trigger only)

## Safety Principles

### 🛡️ Always Follow These Rules

1. **Every new feature MUST have enable/disable flag**
   - Default value should be SAFE (usually OFF for new features, ON for fixes)
   - User can opt-in when ready

2. **Never break existing stable code**
   - New code wrapped in `if(flag_enabled)` checks
   - Fallback to original behavior if disabled

3. **Extensive logging for new features**
   - Tag all logs with feature identifier (e.g., `[TF-Preserve]`, `[ManualClose]`)
   - Log both success and failure paths

4. **Test scenarios documented**
   - Include edge cases
   - Document expected vs actual behavior

## Development Session Log

### Session: 2025-10-02 (Timeframe Switch Fix)

**Problem**: EA creates duplicate positions when switching chart timeframes (M5→M15→H1)

**Root Cause**: OnInit() always seeds new baskets without checking existing positions

**Solution Implemented**:
```cpp
// In LifecycleController::Init()
bool has_positions = m_params.preserve_on_tf_switch && HasExistingPositions();
if(has_positions) {
    // Reconstruct mode: no seeding, just discover
    m_buy.SetActive(true);
    m_sell.SetActive(true);
    m_buy.Update();
    m_sell.Update();
} else {
    // Fresh start: seed normally
}
```

**Files Modified**:
- RecoveryGridDirection_v2.mq5 (+3 lines)
- Params.mqh (+2 lines)
- LifecycleController.mqh (+50 lines)
- GridBasket.mqh (+2 lines)

**Testing Status**: ⏳ Pending MT5 compilation

**Documentation**: IMPLEMENTATION_TIMEFRAME_SWITCH.md

---

### Session: 2025-10-02 (Manual Close Detection) - COMPLETED

**Problem**: EA doesn't detect manual closes, profit transfer fails

**Root Cause**: `ClosedRecently()` returns false if user manually closes → no profit transfer logic triggered

**Solution Implemented**:
```cpp
// In GridBasket::Update()
// BEFORE RefreshState()
m_mcd_last_total_lot = m_total_lot;
m_mcd_last_pnl = m_pnl_usd;

RefreshState();  // Updates from terminal

// AFTER RefreshState()
if(had_positions && now_no_positions) {
    m_mcd_manual_close_detected = true;
    m_last_realized = m_mcd_last_pnl;  // Capture PnL
    m_closed_recently = true;          // Trigger controller
}
```

**Files Modified**:
- RecoveryGridDirection_v2.mq5 (+3 lines)
- Params.mqh (+2 lines)
- GridBasket.mqh (+40 lines)
- LifecycleController.mqh (+8 lines)

**Testing Status**: ⏳ Pending MT5 compilation

**Documentation**: IMPLEMENTATION_MANUAL_CLOSE_DETECTION.md

---

### Session: 2025-10-04 (Rescue v3 Stabilization) - COMPLETED

**Problem Set**: Multiple rescue v3 bugs causing instability:
1. Rescue only deploying once, then stopping
2. Margin pause confusing (user wants DD% instead)
3. Rescue delta only deploying 0.01 or max (missing 0.02-0.09)
4. TRM close-on-news infinite loop (open→close→reseed→close)
5. Rescue log spam (hundreds per second)

**Root Causes & Solutions**:

1. **Rescue Only Once**:
   - Cause: `UpdateRoles()` switching winner to BASKET_HEDGE type
   - Fix: Removed HEDGE type switching, both baskets stay PRIMARY always
   - Rescue identified by comment "RescueSeed" only
   - Lines: LifecycleController.mqh:92-101

2. **Margin Pause → DD% Pause**:
   - Changed from margin level % to equity DD %
   - Renamed: `margin_pause_threshold` → `dd_pause_grid_threshold`
   - Updated log tags from `[MARGIN-PAUSE]` to `[DD-PAUSE]`
   - Files: Params.mqh, RecoveryGridDirection_v2.mq5, LifecycleController.mqh

3. **Rescue Delta Exact Deployment**:
   - Removed multiplier logic
   - Deploy EXACT delta, cap only when delta > max
   - Now deploys 0.02, 0.03, 0.08, etc. correctly
   - Lines: LifecycleController.mqh:882-918

4. **TRM Close-on-News Loop**:
   - Added state flag `m_trm_already_closed` to prevent re-closing
   - Only close once per news window
   - Reset flag when exiting news
   - Lines: LifecycleController.mqh:42, 405, 416, 464-475

5. **Rescue Log Spam**:
   - Added rate limiting to cooldown/balanced logs
   - Log once per minute instead of every tick
   - Lines: LifecycleController.mqh:937-947, 949-961

**Files Modified**:
- LifecycleController.mqh (+60 lines)
- GridBasket.mqh (+2 lines)
- Params.mqh (+1 line)
- RecoveryGridDirection_v2.mq5 (+2 lines)

**Testing Status**: ✅ User confirmed working ("work ngon", "quá đỉnh")

**User Feedback**:
- "work ngon rồi bạn ơi, có rescus đầy đủ" - Rescue fix working
- "tuyệt vời work news quá ngon quá đỉnh" - TRM fix working

---

## Quick Reference

### Current EA Version
- **Version**: 2.4 → 2.5 (after TF fix merge)
- **Features**: PC + DTS + SSL + TRM + ADC + TF-Preserve
- **Next**: Manual Close Detection (MCD)

### File Structure
```
src/
├── ea/
│   └── RecoveryGridDirection_v2.mq5  (main EA, inputs, OnInit/OnTick)
└── core/
    ├── Types.mqh                      (enums, structs)
    ├── Params.mqh                     (SParams struct)
    ├── LifecycleController.mqh        (orchestrator, 2 baskets)
    ├── GridBasket.mqh                 (1 basket logic, PC, DTS)
    ├── SpacingEngine.mqh              (ATR/PIPS/HYBRID)
    ├── RescueEngine.mqh               (hedge deployment)
    ├── OrderExecutor.mqh              (place/modify/close orders)
    ├── OrderValidator.mqh             (broker rules)
    ├── PortfolioLedger.mqh            (exposure, session SL)
    ├── Logger.mqh                     (structured logging)
    └── MathHelpers.mqh                (utilities)
```

### Adding New Feature Checklist

1. ✅ Add input parameter with group header
2. ✅ Add field to SParams struct (Params.mqh)
3. ✅ Map input → params in BuildParams()
4. ✅ Implement logic with flag check: `if(m_params.feature_enabled)`
5. ✅ Add logging with unique tag: `[FeatureName]`
6. ✅ Document in IMPLEMENTATION_*.md
7. ✅ Test with flag ON and OFF
8. ✅ Commit with clear message

### Git Workflow

```bash
# Always commit after completing a feature
git add .
git commit -m "feat: Add Manual Close Detection with enable/disable flag"
git push origin master

# For experimental features, use feature branch
git checkout -b feature/manual-close-detection
# ... work ...
git commit -m "feat: ..."
git push origin feature/manual-close-detection
```

## Important Notes

- **Never remove old code** unless absolutely necessary (wrap in flags instead)
- **Default flags conservatively** (OFF for new features, ON for critical fixes)
- **Log everything** during development (can reduce later)
- **Keep master stable** - only merge tested code
- **Document edge cases** - they WILL happen in live trading

## Contact

If any issues arise:
1. Check logs with feature tag
2. Disable feature flag
3. Review IMPLEMENTATION_*.md
4. Check git history for changes
