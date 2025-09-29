# FLOWCHARTS & DIAGRAMS (Mermaid)

These diagrams capture the control flow, state machine, rescue logic, and class relations. They are implementation-agnostic but assume OOP and multiple instances.

## 1) High-Level EA Flow (OnTick)
```mermaid
flowchart TD
    A[OnTick] --> B{Lifecycle exists?}
    B -- No --> C[Maybe start new Lifecycle (A side)]
    B -- Yes --> D[controller.Update()]
    D --> E[Update A-direction]
    D --> F[Update B-direction]
    E --> G{Basket TP/Trail/BE?}
    F --> H{Basket TP/Trail/BE?}
    G --> I[Apply closes/adjusts]
    H --> I[Apply closes/adjusts]
    D --> J{Rescue conditions?}
    J -- Yes --> K[Open opposite grid]
    J -- No --> L[Maintain]
    K --> L
    L --> M{Limits breached? (budget/exposure/session SL)}
    M -- Yes --> N[Close all & Halt]
    M -- No --> O[Done]
```

## 2) Lifecycle State Machine
```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> A_Active: Create A (SELL or BUY)
    A_Active --> B_Rescue: Rescue B opens (quick policy)
    B_Rescue --> Winner_Close: One side hits basket TP
    Winner_Close --> Reopen_Winner: Other side still losing ≥ dd_reenter
    Winner_Close --> Resolved: Net objectives met
    Reopen_Winner --> A_Active: Continue loop
    A_Active --> Halted: Session SL / Budget / Exposure cap
    B_Rescue --> Halted: Session SL / Budget / Exposure cap
    Resolved --> [*]
    Halted --> [*]
```

## 3) Rescue Decision (Quick Policy)
```mermaid
flowchart LR
    S[Update PnL/Exposure/Fills] --> A{Losing side?}
    A -- No --> X[No action]
    A -- Yes --> B{LastGridBreak + offset?}
    B -- Yes --> C[Open Opposite Grid]
    B -- No --> D{Unrealized DD ≥ dd_open?}
    D -- Yes --> C
    D -- No --> X
    C --> E{Cooldown & Cycles & Exposure OK?}
    E -- No --> X
    E -- Yes --> F[Execute Rescue (market+limits)]
```

## 4) Order Placement & Validation
```mermaid
flowchart TD
    A[Request Place Order] --> B{Cooldown passed?}
    B -- No --> Z[Skip + Log reason]
    B -- Yes --> C{Min distance OK (stops level/freeze)?}
    C -- No --> Z
    C -- Yes --> D{Spread/Slippage OK?}
    D -- No --> Z
    D -- Yes --> E{Duplicate level?}
    E -- Yes --> Z
    E -- No --> F[Send Order]
    F --> G{Broker OK?}
    G -- No --> Z
    G -- Yes --> H[Store ticket + State]
```

## 5) Class Diagram (OOP Structure)
```mermaid
classDiagram
    class CLifecycleController{
        +Init()
        +Update()
        +Shutdown()
        -OpenA(Direction)
        -OpenRescueOpposite()
        -CloseAllAndHalt()
        -m_id
        -m_budgetA
        -m_budgetB
        -m_cycles
    }
    class CGridDirection{
        +Init(startPrice)
        +Update()
        +BuildGrid()
        +UpdateBasketPnL()
        +TryCloseByBasketTP()
        +ApplyTrailingAndBE()
        +IsLosing() bool
        +LastGridPrice() double
        -m_levels
        -m_direction
        -m_symbol
    }
    class CSpacingEngine{
        +SpacingPips() double
        -m_mode
        -m_fixedPips
        -m_minPips
        -m_atrTf
        -m_atrPeriod
        -m_atrMult
    }
    class CRescueEngine{
        +ShouldRescue(lastGrid, price, dd) bool
        -m_offsetRatio
        -m_ddOpen
        -m_cooldown
        -m_maxCycles
    }
    class CPortfolioLedger{
        +CanSpendA(amount) bool
        +CanSpendB(amount) bool
        +RecordRealizedA(usd)
        +RecordRealizedB(usd)
        +NetExposureLots() double
        -m_budgetA
        -m_budgetB
        -m_exposureCap
    }
    class COrderExecutor{
        +PlaceMarket(dir, lot) ulong
        +PlaceLimit(dir, price, lot) ulong
        +Cancel(ticket) bool
        -ValidatePrice()
        -Cooldown()
    }
    class CLogger{
        +Event(msg)
        +Status(snapshot)
        -m_lastStatusTime
    }

    CLifecycleController --> CGridDirection : owns A & B
    CLifecycleController --> CRescueEngine : uses
    CLifecycleController --> CPortfolioLedger : uses
    CGridDirection --> CSpacingEngine : uses
    CGridDirection --> COrderExecutor : uses
    CLifecycleController --> COrderExecutor : uses (for lifecycle closure)
    CLifecycleController --> CLogger : uses
    CGridDirection --> CLogger : uses
```

## 6) Multi-Instance Concept
- Multiple lifecycles can exist (future multi-symbol). Each lifecycle is independent and holds its own instances of A/B directions and services; shared services (e.g., Logger) can be passed by reference.
