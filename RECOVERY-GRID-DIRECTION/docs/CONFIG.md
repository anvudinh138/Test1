# CONFIG: Parameters & Defaults (MVP)

Defaults tuned for EURUSD M1 demo, Exness Pro (0 commission, ~0.1 pip spread). All values are configurable in EA inputs.

## Spacing
- InpSpacingMode: "HYBRID"  # PIPS | ATR | HYBRID
- InpFixedSpacingPips: 5.0
- InpAtrPeriod: 14
- InpAtrTimeframe: M5        # use higher TF to avoid tiny M1 ATR
- InpAtrMultiplier: 1.0
- InpMinSpacingPips: 5.0     # floor to avoid too-dense grids on low vol

Formula (HYBRID): spacing_pips = max(InpFixedSpacingPips, ATR(M5)*InpAtrMultiplier (in pips), InpMinSpacingPips)

## Grid
- InpGridLevelsPerSide: 5    # 1 market + 4 pending limits
- InpLotSize: 0.01           # fixed per order
- InpUseBasketTP: true
- InpBasketTP_UsdPerSide: 2.0
- InpBasketTrailingStart_Usd: 1.0
- InpBasketTrailingLock_Usd: 0.5
- InpBasketBreakevenAfter_Usd: 0.7
- InpUsePartialTP: false
- InpPartialTP_Percent: 50   # if enabled later

Notes:
- Basket TP/Trailing/Breakeven operate per direction (A or B) independently.
- Partial TP is disabled for MVP; leave parameters for future.

## Rescue (Quick)
- InpRescueUseLastGridBreak: true
- InpRescueOffsetRatio: 0.2         # open opposite grid when price beyond last grid by 20% of spacing
- InpDDOpen_Usd: 3.0                # backup trigger if unrealized loss exceeds this
- InpDDReenter_Usd: 2.0             # reopen winner if loser still draws down after close
- InpRescueCooldown_Sec: 15         # min gap between rescues
- InpMaxRescueCycles: 3             # per lifecycle

## Portfolio & Exposure Limits (Shared Wallet)
- InpPortfolioTargetNet_Usd: 0.0    # 0 = off for MVP
- InpPortfolioStopLoss_Usd: 50.0    # hard cap; closes all and halts
- InpSymbolExposureCap_Lots: 0.30   # sum lots per symbol must not exceed
- InpPortfolioExposureCap_Lots: 1.00# total across symbols (future multi-symbol)

## Execution Guards
- InpOrderCooldown_Sec: 3
- InpMaxSlippage_Points: 10
- InpCancelStaleOrdersAfter_Sec: 60
- InpRespectStopsLevel: true

## Logging & Debug
- InpDebug: true
- InpStatusLogInterval_Sec: 30
- InpEventLogs: true

## Symbol/Timeframe
- InpSymbol: ""              # empty = use current chart symbol
- InpTimeframe: M1           # operate on M1; ATR uses M5 by default

## Rationale Highlights
- HYBRID spacing ensures ATR never makes spacing too short in low volatility; floor at 5 pips.
- Quick rescue uses last-grid break with a small offset; dd trigger is secondary.
- Fixed 0.01 lot aligns with your margin preference; exposure caps prevent runaway.
- Shared wallet: winners fund losers across symbols; no per-lifecycle capital split.
- No filters (RSI/news/session) in MVP; toggles will be added later.
