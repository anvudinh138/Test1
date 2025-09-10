## Development Tracking

### v1.3.2-clean-ui.lua ⭐ LATEST
- 🚨 EMERGENCY: Fixed UI clutter/crash issue
- ✅ REMOVED: All debug markers (diamonds, triangles, "EX" labels)
- ✅ REMOVED: Complex label management system (was causing UI overload)
- ✅ SIMPLIFIED: Only essential signals remain
- ✅ CLEAN: P↑/P↓ → T → B/S → Dots + Simple P&L labels
- ✅ PERFORMANCE: No more array management or excessive plotshapes
- ✅ STABLE: Clean, fast, reliable visualization
- ✅ WORKING: All core functionality preserved
- ✅ FIXED: Enhanced P&L detection with multiple fallbacks
- ✅ FIXED: Always show exit labels (either P&L or exit reason)
- ✅ IMPROVED: Clear EMA line identification in legend
- ✅ GUARANTEED: Exit info will always appear when position closes
- ✅ FIXED: Variable declaration error for exitText and labelColor
- ✅ FIXED: P&L labels now positioned away from candles (visible)
- ✅ FIXED: SL/TP lines disappear immediately when position closes
- ✅ FIXED: Prevent multiple same-direction entries (no more 3 Longs)
- ✅ IMPROVED: Clear exit labels with direction and P&L (e.g., "SHORT TP +9.2p")

### v1.3.1-fix-entry-logic.lua ❌ UI BROKEN
- ✅ FIXED: Entry logic reverted to v1.0.1 (working version)
- ✅ FIXED: GO Long/Short labels now appear on chart
- ✅ FIXED: Proper Push-Test-Go sequence like v1.0.1
- ✅ FIXED: Results table matches v1.0.1 format
- ✅ NEW: Enhanced exit info labels with P&L in pips
- ✅ NEW: Exit labels show "TP: +15.3p" or "SL: -8.7p"
- ✅ FIXED: Improved exit detection with entry price tracking
- ✅ FIXED: Fallback labels if P&L calculation fails
- ✅ NEW: Ultra clean SL/TP lines (hide immediately when position closes)
- ✅ NEW: Limited exit labels (max 20, auto-delete old ones)
- ✅ NEW: Chart cleanup system for better visualization
- ✅ FIXED: Undeclared variable error in label creation
- ✅ NEW: Compact entry signals "B" (Buy) and "S" (Sell) instead of "GO"
- ✅ FIXED: Simplified entry price tracking (remove complex conditions)
- ✅ FIXED: Added fallback to strategy.position_avg_price for P&L
- ✅ DEBUG: Added yellow/orange diamonds to test exit detection
- ✅ NEW: Clean dot markers at exact SL/TP exit prices
- ✅ NEW: Green dots = TP exits, Red dots = SL exits
- ✅ NEW: Dots positioned precisely where price hit TP/SL level
- ✅ FIXED: Robust exit reason detection using strategy.closedtrades.profit
- ✅ FIXED: Better P&L calculation with multiple fallback methods
- ✅ DEBUG: Added backup exit markers (blue/purple triangles) that always work
- ✅ FIXED: All text colors changed to white for better visibility
- ✅ FIXED: Push Up "P↑" now white text (was black, hard to see)
- ✅ FIXED: Test Long "T" now white text (was black on lime background)
- ✅ FIXED: Buy "B" now white text (was black on green background)
- ✅ NEW: Color-coded exit labels (green=profit, red=loss)
- ✅ Original TP: tpMultiplier=2.0 (flexible, proven logic)
- ✅ Session filter retained (Full Time default)
- ✅ No hedging (close_entries_rule="ANY")
- ✅ Enhanced alerts + exit visualization
- ✅ Anti-spam alerts (10+ bars gap)
- ✅ Same parameters as v1.0.1 (working baseline)

### v1.3.0-revert-original-tp.lua ❌ BROKEN
- ✅ REVERTED: Back to original TP logic for better win rate (50-55%)
- ✅ Fixed: 1:1 ratio caused win rate drop to 20-28%
- ✅ Original TP: tp1Multiplier=1.0, tp2Multiplier=2.0 (flexible)
- ✅ FIXED: Pine Script syntax error (multiline input string)
- ✅ Session filter default changed to "Full Time" (24/7 trading)
- ✅ No hedging (close_entries_rule="ANY")
- ✅ Enhanced alerts + exit visualization
- ✅ Anti-spam alerts (10+ bars gap)
- ✅ Ready for MT5 EA integration
- ✅ Optimized for scalping M1/M5

### v1.2.0-session-1to1-ratio.lua ❌ FAILED
- ✅ COMBINED: Session filter + 1:1 TP/SL ratio
- ✅ Session filter with 4 options (default: London/NY Overlap)
- ✅ Customizable TP/SL ratio (default: 1.0 = 1:1)
- ✅ Dynamic TP calculation based on actual SL distance
- ✅ No hedged positions (close_entries_rule="ANY")
- ✅ Enhanced alerts with session + R:R info
- ✅ Exit visualization (L-TP, S-SL, etc.)
- ✅ Session background visualization
- ✅ Anti-spam alerts (10+ bars gap)
- ✅ FIXED: Pine Script switch statement return type error
- ✅ Ready for testing

### v1.0.1-fix-alerts-exits.lua
- ✅ FIXED: Alert spam (5-6 alerts → 1 alert per signal)
- ✅ FIXED: Exit visualization (now shows "L-SL", "S-TP", etc.)
- ✅ FIXED: Pine Script error - dynamic strings in plotshape
- ✅ FIXED: Hedged positions - no more Long+Short at same time
- ✅ Enhanced anti-spam: 10+ bars gap or different direction
- ✅ Simplified alert modes: "Entry Only", "Entry + Push", "All Signals"
- ✅ Added exit alerts: "✅ PTG LONG EXIT - SL at 2650.123"
- ✅ Better exit detection using position_size changes
- ✅ Separate plotshapes for TP/SL exits (const strings)
- ✅ Added close_entries_rule="ANY" to prevent hedging
- ✅ Auto-close opposite position when new signal appears
- ✅ Completed - merged into v1.2.0

### v1.1.0-session-filter.lua
- ✅ Added session filter with 4 options:
  - Full Time (default - no filter)
  - London Open (07:00-16:00 UTC)
  - New York Open (12:00-21:00 UTC) 
  - London/NY Overlap (12:00-16:00 UTC)
- ✅ Session background visualization
- ✅ Enhanced alerts include session info
- ✅ Updated results table with session status
- ✅ Only trade during selected session
- ✅ Completed - merged into v1.2.0

### Next planned features:
- Multi-timeframe confirmation
- Advanced position sizing
- News filter integration