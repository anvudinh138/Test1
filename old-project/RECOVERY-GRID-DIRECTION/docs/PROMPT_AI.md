# PROMPT-AI: Guidance & Prompts for Coders (MQL5 / OOP)

Use this document when asking an AI (or yourself) to implement or modify code. It encodes our architecture, constraints, and acceptance criteria.

## Project Mission (Short)
- Build a two-direction recovery grid on MT5 using OOP.
- One Lifecycle controls a pair of GridDirections (A = SELL or BUY, B = opposite) with quick rescue.
- Each GridDirection self-manages orders, basket PnL, trailing, breakeven, and status.

## Non-Functional Requirements
- Stability first: no spam orders/logs, idempotent actions, strict validation.
- Deterministic behavior across backtests; minimal hidden state.
- Clean OOP boundaries; no accidental globals except controlled services.
- Telemetry: concise logs/events; throttled status updates.

## OOP Design Rules
- Class prefix `C` (e.g., `CLifecycleController`, `CGridDirection`).
- Member fields prefix `m_`, globals `g_`, constants `k_`.
- Do not place strategy logic in `OnTick` directly; delegate to classes.
- Constructor injects symbol, settings, services. Avoid singletons.
- Each instance owns its resources; explicit `Init()` and `Shutdown()` methods.

## Core Classes & Responsibilities
- `CLifecycleController`
  - Owns A/B grid instances and budgets (50/50 split initially).
  - Decides rescue timing (last-grid-break+offset, drawdown). Enforces cooldowns, max cycles, exposure caps.
  - Handles session SL/TP (net), lifecycle halt/resolve.
- `CGridDirection`
  - Manages a direction (BUY or SELL): 1 market + (N-1) limit orders.
  - Tracks fills, basket PnL, drawdown, exposure, last grid price.
  - Executes basket TP, trailing, breakeven, optional partial TP.
- `CSpacingEngine`
  - Computes spacing in pips for PIPS/ATR/HYBRID modes. ATR uses higher TF (M5) to avoid too-small M1 ATR.
- `CRescueEngine`
  - Provides rescue decision helpers (last-grid-break+offset, drawdown threshold). Stores cooldown state.
- `CPortfolioLedger`
  - Shared wallet across lifecycles/symbols. Tracks portfolio exposure caps, optional portfolio SL/TP.
- `COrderExecutor`
  - Validates prices vs `SYMBOL_TRADE_STOPS_LEVEL`, spread, freeze; applies cooldown; places/cancels orders.
- `CLogger`
  - Event logging with throttled status. Tag logs with lifecycle id and direction.

## Inputs (EA Parameters)
See `docs/CONFIG.md` for names and defaults. Key groups: Spacing, Grid, Rescue, Budget/Session, Execution, Logging.

## Event Loop Contract
- `OnInit()`: read inputs → construct services → `controller.Init()`.
- `OnTick()`: `controller.Update()` (single entry-point) → delegates to A/B.
- `OnDeinit()`: `controller.Shutdown()` → cleanup orders/resources safely.

## Order Validation Checklist
- Respect `SYMBOL_TRADE_STOPS_LEVEL` and freeze level; ensure distance in points.
- Check spread ≤ allowed; slippage ≤ allowed; symbol trading allowed.
- Cooldown between placement attempts (e.g., ≥ 3s) to avoid retries.
- Idempotent placement: no duplicate pending/market orders at same price/lot for same level.
- Cleanup stale far-away orders when regime/grid resets.

## Rescue Decision (Quick Policy)
- Primary: open opposite grid when price beyond loser’s last grid by `offset_ratio × spacing`.
- Secondary: open opposite grid when loser’s basket drawdown ≥ `dd_open_usd`.
- Reopen winner after closing if the other side still loses ≥ `dd_reenter_usd` and cooldown ok.

## Logging Guidelines
- Event logs: create/close/rescue/violation with reasons.
- Status logs: every `InpStatusLogInterval_Sec` seconds per lifecycle.
- Use tags: `[LC#1][A-SELL]`, `[LC#1][B-BUY]`.

## Acceptance Criteria (MVP)
- No invalid price spam; orders respect min distance and cooldown.
- Basket TP/trailing/breakeven operate per direction as configured.
- Quick rescue triggers occur as specified; max cycles and cooldown enforced.
- Budget/exposure/session limits respected; halt on breach with clean close.
- Logs are concise and structured; no infinite loops.

## Example System Prompt (for AI)
"""
You are an expert MQL5 engineer. Implement a two-direction recovery grid EA using OOP. 
Follow docs/SPEC.md and docs/CONFIG.md. Prioritize stability, price validation, and idempotent order placement. 
Classes: CLifecycleController, CGridDirection, CSpacingEngine, CRescueEngine, CPortfolioLedger, COrderExecutor, CLogger.
No indicators/filters beyond ATR spacing for MVP. EURUSD M1, fixed lot 0.01, HYBRID spacing.
"""

## Example Task Prompts
1) "Create `CSpacingEngine` with modes PIPS/ATR/HYBRID. Constructor params: symbol, atr_tf, atr_period, atr_mult, fixed_pips, min_pips. Method: `double SpacingPips()` returns the current spacing using ATR(M5). Include caching for 5 seconds."

2) "Implement `CGridDirection` with methods: `Init(start_price)`, `Update()`, `BuildGrid()`, `UpdateBasketPnL()`, `TryCloseByBasketTP()`, `ApplyTrailingAndBE()`, `IsLosing()`, `LastGridPrice()`. Track levels: price, lot, ticket, filled flag."

3) "Implement `CLifecycleController` that owns A(SELL) and B(BUY). Logic: on loser last-grid-break + offset OR dd trigger, `OpenRescueOpposite()`. Enforce cooldown/max cycles/exposure cap. Close winner by basket TP; optionally reopen winner if other side still loses."

4) "Implement `COrderExecutor` with price/stop-level validation, cooldown, and de-duplication. Provide `PlaceMarket(Direction, lot)` and `PlaceLimit(Direction, price, lot)`; return ticket or 0."

## Edge Cases to Consider
- ATR too small on M1 → HYBRID spacing with floor (min_pips).
- Spread spikes during news → placement rejected; ensure graceful log and retry after cooldown.
- Freeze level changes → revalidate before placement; skip if too close.
- Net exposure cap reached → skip rescue; log reason.
- Budget exhausted → trigger session halt; close positions safely.

## Directory & Naming
- `src/ea/RecoveryGridEA.mq5` (main EA shell)
- `src/core/CLifecycleController.mqh`
- `src/core/CGridDirection.mqh`
- `src/core/CSpacingEngine.mqh`
- `src/core/CRescueEngine.mqh`
- `src/core/CRiskLedger.mqh`
- `src/core/COrderExecutor.mqh`
- `src/core/CLogger.mqh`

## Backtest Checklist
- EURUSD M1, modeling every tick, default inputs from CONFIG.md.
- Scenarios: trend up/down, range, whipsaw. Capture session PnL, cycles, exposure peak.
