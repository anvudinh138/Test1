# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**MetaTrader 5 (MT5) trading bot repository** implementing a **Two-Sided Recovery Grid** strategy. The bot maintains dual BUY/SELL baskets and uses opposite-direction hedges with trailing stops to recover from drawdowns.

**Key Concept**: Always maintain 2 baskets (BUY/SELL). The losing basket gets supported by a small opposite hedge with TSL. Hedge profits pull the loser's Group TP closer to price. When Group TP is hit, close the entire basket and flip roles.

## Directory Structure

- **`RECOVERY-GRID-DIRECTION_Stable_1.0.0/`** — Current stable version (v1.0.0)
- **`RECOVERY-GRID-DIRECTION_v2/`** — Development version
- **`old-project/`** — Archived/failed strategies (ignore unless explicitly asked)

Both active versions share identical architecture:

```
src/
  core/                              # MQL5 .mqh modules (pure logic, broker-agnostic)
    LifecycleController.mqh          # Orchestrates baskets, rescue, flip, safety
    GridBasket.mqh                   # Grid management, avg price, PnL, Group TP, TSL
    RescueEngine.mqh                 # Drawdown detection, hedge deployment decisions
    SpacingEngine.mqh                # PIPS/ATR/HYBRID spacing computation
    OrderExecutor.mqh                # Broker order execution with retries
    OrderValidator.mqh               # Broker constraint checks (stops level, freeze)
    PortfolioLedger.mqh              # Exposure tracking, session risk limits
    Logger.mqh, Params.mqh, Types.mqh, MathHelpers.mqh
  ea/
    RecoveryGridDirection_v2.mq5     # Main EA entry point

doc/
  STRATEGY_SPEC.md                   # Full specification with parameters and math
  ARCHITECTURE.md                    # Module responsibilities and data flow
  PSEUDOCODE.md, FLOWCHARTS.md       # Implementation details
  TESTING_CHECKLIST.md               # Acceptance criteria
  TROUBLESHOOTING.md                 # Common issues (ESSENTIAL for debugging)

idea/                                # Future feature proposals
```

## Development Commands

### Compilation (MT5 MetaEditor)

1. Open **MetaEditor** from MT5 (Tools → MetaQuotes Language Editor)
2. Open `src/ea/RecoveryGridDirection_v2.mq5`
3. Press **F7** or click **Compile**
4. Output `.ex5` goes to `MQL5/Experts/`

**Include Path**: Code uses `#include <RECOVERY-GRID-DIRECTION_v2/core/...>`, ensure project folder is in MT5's `MQL5/Include/` or adjust paths.

### Backtesting (MT5 Strategy Tester)

1. Open Strategy Tester (**Ctrl+R**)
2. Select EA: `RecoveryGridDirection_v2`
3. Configure:
   - **Symbol**: EURUSD
   - **Period**: M1 or M5
   - **Date Range**: Start on weekday (avoid weekends), e.g., 2024-01-02
   - **Model**: Every tick or Real ticks
4. **Settings** tab: Set EA parameters
5. **Start** test

**Critical Setting**: `InpRespectStops = false` for backtests (avoids broker stops level conflicts)

### Safe Baseline Test Configuration

```properties
InpRespectStops = false              # Required for backtest
InpGridLevels = 6                    # Start small (can scale to 200)
InpLotBase = 0.01
InpLotScale = 1.0                    # Flat lot (no martingale)
InpDynamicGrid = true                # Reduces init lag
InpWarmLevels = 5
InpTargetCycleUSD = 3.0
InpTSLEnabled = true
InpTSLStartPoints = 1000
InpDDOpenUSD = 8.0
InpExposureCapLots = 2.0
InpSessionSL_USD = 30.0
```

## Core Architecture

### Strategy Flow (Tick Loop)

```
OnTick() →
  1. Update BUY/SELL baskets (avg price, PnL, TP price)
  2. Identify loser/winner
  3. If (DD breach OR price breach last grid) AND guards OK:
     → Deploy hedge on winner side (market + staged limits)
     → Enable TSL on hedge basket
  4. Check TSL triggers
  5. Check Group TP hits → Close entire basket → Flip roles
  6. Enforce risk limits → Halt if breached
```

### Module Responsibilities

- **LifecycleController**: Owns both baskets, calls rescue logic, handles flip, enforces safety guards
- **GridBasket**: Manages one basket's orders, computes avg/PnL/TP, TSL logic, rebuilds pending limits when filled
- **RescueEngine**: Pure decision logic—`ShouldRescue(loser, winner) → bool`; no execution
- **OrderExecutor**: Broker abstraction—atomic open/modify/close with retries
- **OrderValidator**: Pre-flight checks (stops level, freeze, lot size limits)
- **PortfolioLedger**: Global state—total exposure, realized/unrealized PnL, session SL tracking

**Design**: Core modules are UI-free and broker-agnostic (portable to cTrader, Python, C#).

### Key Formulas

- **Average Price**: `avg = Σ(lot_i × price_i) / Σ(lot_i)`
- **Basket PnL**:
  - BUY: `pnl = (Bid - avg) × point_value × Σ(lot_i) - fees`
  - SELL: `pnl = (avg - Ask) × point_value × Σ(lot_i) - fees`
- **Group TP**: Solve for `tp_price` where `PnL_at(tp_price) = target_cycle_usd`
- **TP Pulling**: When hedge closes with profit `H` → `target_cycle_usd -= H` → recompute TP closer to price

## Critical Invariants (When Editing)

1. Always update `avg_price` after adding/removing orders
2. TSL only on hedge baskets, never on primary grids
3. Group TP must be computed from current state (never hardcoded)
4. Enforce guards (cooldown, exposure, cycles) before rescue deployment
5. Use structured logging tags: `[module][symbol][basket_type][state]`

## Common Pitfalls (from TROUBLESHOOTING.md)

- **Lot Size Explosion**: `LotScale=2.0` with 200 levels → exponential growth. Use `LotScale=1.0` for flat lots.
- **Broker Stops Level**: `InpRespectStops=true` blocks orders in backtest. Set `false`.
- **Init Lag**: 200+ grid levels → use `InpDynamicGrid=true` (starts with few pendings, refills dynamically)
- **Weekend Data**: Backtest must start on weekdays (avoid Sat/Sun)
- **Market Closed Errors**: Check symbol exists, has historical data (Tools → History Center)

## Debugging

- **Enable Logging**: `InpLogEvents = true`
- **Expected Init Log**:
  ```
  [RGDv2] Init OK - Ask=1.08450 Bid=1.08440 LotBase=0.01 GridLevels=6 Dynamic=ON
  [RGDv2][EURUSD][BUY][PRI] Dynamic grid warm=6/6
  [RGDv2][EURUSD][SELL][PRI] Dynamic grid warm=6/6
  ```
- **Look for Tags**: `[BREACH]`, `[DD]`, `[TSL]`, `[TP]`, `[HALT]` in Experts tab
- **See `doc/TROUBLESHOOTING.md`** for detailed error resolution

## Testing Requirements (from TESTING_CHECKLIST.md)

**Scenarios to validate**:
- Strong trend up (little pullback)
- Strong trend down
- Range/whipsaw (frequent reversals)
- Gap open through multiple levels

**Expected behavior**:
- Seeds both baskets with correct spacing
- Opens hedge when (breach OR DD) AND guards OK
- TSL activates at `tsl_start_points`, trails by `tsl_step_points`
- Hedge profits pull loser TP closer
- Closes entire basket at Group TP atomically
- Flips roles correctly
- Enforces `exposure_cap_lots`, `session_sl_usd`

## Cursor Rules (from .cursor/rules/)

**Project execution mode**:
- **Plan → Do → Deliver**: Short plan (≤6 lines) → execute → concise summary (3-5 bullets)
- **Cost-aware**: Limit output to ≤1,800 tokens; use diffs over full rewrites; avoid "thinking mode" unless necessary
- **No chatter**: Minimal preamble/postamble; direct artifact delivery
- **Gộp nhiều mục trong 1 request** khi hợp lý (batch related tasks)

**Code style**:
- Tuân thủ style hiện có trong repo
- Tạo file mới → in: `// path: <relative/path>` followed by code block
- Không chèn lời giải thích trong khối diff
- Error handling: Nếu thiếu thông tin nhưng có thể giả định hợp lý → ghi rõ Assumptions (≤3 bullet) rồi tiếp tục

**Model policy**:
- Nhẹ (≤2 file, Q&A) → `gpt-5-fast`
- Vừa (3-5 file, refactor) → `gpt-5-medium` hoặc `claude-4-sonnet`
- Nặng (đọc nhiều file, kiến trúc) → `claude-4.5-sonnet`

## Documentation Hierarchy

1. **Start here**: `doc/STRATEGY_SPEC.md` (full spec), `ARCHITECTURE.md` (modules)
2. **Implementation**: `PSEUDOCODE.md`, `FLOWCHARTS.md`
3. **Operational**: `TESTING_CHECKLIST.md`, `TROUBLESHOOTING.md`, `GLOSSARY.md`
4. **Future**: `idea/` (Adaptive Spacing, Equity Cushion, Partial Close, etc.)

Always consult docs before making significant strategy logic changes.
