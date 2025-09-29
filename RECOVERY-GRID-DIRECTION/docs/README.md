# RECOVERY-GRID-DIRECTION

Overview and orientation for the new project (MT5/MQL5).

## Goals
- Two-direction recovery grid: A (e.g., SELL) and B (e.g., BUY) hedge each other.
- Each grid direction self-manages: profit/loss, TP, trailing, breakeven, partial TP (configurable).
- Lifecycle controls the pair (A,B), budget split 50/50, quick rescue policy, no filters initially.
- EURUSD M1 focus, Exness Pro demo for backtests.

## Reading Order
1. SPEC.md (concepts, architecture, state machine, algorithms)
2. CONFIG.md (parameters and defaults for MVP)
3. MVP_NOTES.md (scope, validation, next steps)

## Status
- Phase: Documentation first. No trading code yet. After we agree on SPEC/CONFIG, we scaffold the MQL5 EA.

