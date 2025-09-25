# GRID-DCA EA v2.0 - System Flowchart

## 🔄 **MAIN SYSTEM FLOW**

```mermaid
flowchart TD
    A[EA Start] --> B[Initialize Systems]
    B --> C[Setup Immediate Entries]
    C --> D[1 BUY + 1 SELL Market Orders]
    D --> E[Setup Dual Grids]
    E --> F[5 BUY Levels Below + 5 SELL Levels Above]
    F --> G[Monitor Market]
    
    G --> H{Profit Check}
    H -->|< $3 USD| I[Continue Monitoring]
    H -->|>= $3 USD| J[Profit Target Reached!]
    
    J --> K[Close ALL Positions]
    K --> L[Cancel ALL Orders]
    L --> M[Confirmation Check]
    
    M --> N{Orders Count = 0?}
    N -->|No| O[Wait for Cleanup]
    O --> M
    N -->|Yes| P[Confirmed Clean]
    
    P --> Q[Reset Grid at Current Price]
    Q --> C
    
    I --> R{Grid Full?}
    R -->|No| G
    R -->|Yes| S[DCA Expansion]
    S --> T[Add 5 More Levels]
    T --> G
    
    G --> U{Loss > 5%?}
    U -->|No| G
    U -->|Yes| V[Loss Protection]
    V --> W[Close Losing Direction]
    W --> G
```

---

## ⚙️ **INITIALIZATION FLOW**

```mermaid
flowchart TD
    A[OnInit] --> B[Load Parameters]
    B --> C[Initialize ATR Calculator]
    C --> D[Initialize Grid Manager V2]
    D --> E[Set Magic Number]
    E --> F[Set Profit Targets]
    F --> G[Print Configuration]
    G --> H[Ready for Trading]
```

---

## 🎯 **PROFIT TAKING FLOW**

```mermaid
flowchart TD
    A[Every Tick] --> B[Calculate Direction Profits]
    B --> C[BUY Profit + SELL Profit]
    C --> D{Total >= Target?}
    
    D -->|No| E[Continue Trading]
    D -->|Yes| F[🎯 PROFIT TARGET REACHED!]
    
    F --> G[Call CloseAllPositions]
    G --> H[Scan All Market Positions]
    H --> I{Our Position?}
    I -->|Yes| J[Close Position]
    I -->|No| K[Skip]
    J --> L[Log Closure]
    K --> L
    L --> M[Scan All Orders]
    M --> N{Our Order?}
    N -->|Yes| O[Cancel Order]
    N -->|No| P[Skip]
    O --> Q[Log Cancellation]
    P --> Q
    Q --> R[Cleanup Complete]
```

---

## 🔍 **CONFIRMATION CHECK FLOW**

```mermaid
flowchart TD
    A[SetupGridSystem Called] --> B[Count BUY Orders/Positions]
    B --> C[Count SELL Orders/Positions]
    C --> D{BUY Count = 0?}
    D -->|No| E[⚠️ BUY Not Cleared]
    D -->|Yes| F{SELL Count = 0?}
    F -->|No| G[⚠️ SELL Not Cleared]
    F -->|Yes| H[✅ ALL CLEARED]
    
    E --> I[Print Status]
    G --> I
    I --> J[Return - Wait Next Tick]
    
    H --> K[Setup New Grid]
    K --> L[Place Immediate Entries]
    L --> M[Create Grid Orders]
    M --> N[Grid Ready]
```

---

## 🏗️ **GRID SETUP FLOW**

```mermaid
flowchart TD
    A[SetupDualGrid] --> B[Get Current Price]
    B --> C[Calculate ATR]
    C --> D[Determine Grid Spacing]
    D --> E[Place Immediate Market Orders]
    
    E --> F[Setup BUY Grid]
    F --> G[Level 0: Price - 1×Spacing]
    G --> H[Level 1: Price - 2×Spacing]
    H --> I[Level 2: Price - 3×Spacing]
    I --> J[Level 3: Price - 4×Spacing]
    J --> K[Level 4: Price - 5×Spacing]
    
    K --> L[Setup SELL Grid]
    L --> M[Level 0: Price + 1×Spacing]
    M --> N[Level 1: Price + 2×Spacing]
    N --> O[Level 2: Price + 3×Spacing]
    O --> P[Level 3: Price + 4×Spacing]
    P --> Q[Level 4: Price + 5×Spacing]
    
    Q --> R[Grid Complete]
```

---

## 🔄 **DCA EXPANSION FLOW**

```mermaid
flowchart TD
    A[Monitor Grid Status] --> B{All BUY Levels Filled?}
    B -->|No| C{All SELL Levels Filled?}
    B -->|Yes| D{Price Still Going Down?}
    
    D -->|Yes| E[DCA Expansion - BUY]
    E --> F[Add 5 More BUY Levels Below]
    F --> G[Update Grid Tracking]
    
    C -->|No| H[Continue Normal Operation]
    C -->|Yes| I{Price Still Going Up?}
    
    I -->|Yes| J[DCA Expansion - SELL]
    J --> K[Add 5 More SELL Levels Above]
    K --> G
    
    D -->|No| H
    I -->|No| H
    G --> H
```

---

## 🛡️ **LOSS PROTECTION FLOW**

```mermaid
flowchart TD
    A[Calculate Direction Losses] --> B[BUY Loss Amount]
    B --> C[SELL Loss Amount]
    C --> D{BUY Loss > 5% Account?}
    
    D -->|Yes| E[🚨 BUY Loss Protection]
    E --> F[Close All BUY Positions]
    F --> G[Disable BUY Grid]
    G --> H[Continue with SELL Only]
    
    D -->|No| I{SELL Loss > 5% Account?}
    I -->|Yes| J[🚨 SELL Loss Protection]
    J --> K[Close All SELL Positions]
    K --> L[Disable SELL Grid]
    L --> M[Continue with BUY Only]
    
    I -->|No| N[Both Directions Active]
    H --> N
    M --> N
```

---

## 🎛️ **POSITION MANAGEMENT FLOW**

```mermaid
flowchart TD
    A[Position Detection] --> B{Magic Number Match?}
    B -->|No| C[Skip Position]
    B -->|Yes| D{Comment Match?}
    
    D -->|Grid_*| E[Grid Position]
    D -->|IMMEDIATE_*| F[Immediate Position]
    D -->|Other| G[Unknown Position]
    
    E --> H[Track in Grid System]
    F --> I[Track as Immediate Entry]
    G --> J[Include in General Tracking]
    
    H --> K[Apply Grid Logic]
    I --> L[Apply Immediate Logic]
    J --> M[Apply General Logic]
    
    C --> N[Continue Scan]
    K --> N
    L --> N
    M --> N
```

---

## 📊 **PROFIT CALCULATION FLOW**

```mermaid
flowchart TD
    A[Profit Calculation] --> B[Scan All Positions]
    B --> C{Position Type?}
    
    C -->|BUY| D[Add to BUY Profit]
    C -->|SELL| E[Add to SELL Profit]
    
    D --> F[Include P&L + Swap]
    E --> G[Include P&L + Swap]
    
    F --> H[BUY Total]
    G --> I[SELL Total]
    
    H --> J[Calculate Combined Total]
    I --> J
    
    J --> K{Profit Mode?}
    K -->|Total Mode| L[Check: Total >= Target]
    K -->|Per Direction| M[Check: Each Direction >= Target]
    
    L --> N[Trigger Decision]
    M --> N
```

---

## 🔧 **ERROR HANDLING FLOW**

```mermaid
flowchart TD
    A[Operation Attempt] --> B{Success?}
    B -->|Yes| C[Log Success]
    B -->|No| D[Identify Error]
    
    D --> E{Error Type?}
    E -->|Orders Limit| F[Wait for Cleanup]
    E -->|Network Error| G[Retry Operation]
    E -->|Invalid Price| H[Recalculate]
    E -->|Insufficient Margin| I[Reduce Lot Size]
    
    F --> J[Continue Next Tick]
    G --> K[Exponential Backoff]
    H --> L[Use Current Market Price]
    I --> M[Use Minimum Lot]
    
    C --> N[Continue Operation]
    J --> N
    K --> N
    L --> N
    M --> N
```

---

## ⏰ **TICK PROCESSING FLOW**

```mermaid
flowchart TD
    A[OnTick Start] --> B[Update ATR Values]
    B --> C{Should Setup Grid?}
    C -->|Yes| D[SetupGridSystem]
    C -->|No| E[Check Trading Allowed]
    
    D --> F[Confirmation Check]
    F --> G{Grid Creation OK?}
    G -->|No| H[Wait Next Tick]
    G -->|Yes| I[Grid Created Successfully]
    
    E --> J{Trading Allowed?}
    J -->|No| H
    J -->|Yes| K[Check Profit Target]
    
    K --> L{Target Reached?}
    L -->|Yes| M[Close All Positions]
    L -->|No| N[Update Grid Status]
    
    M --> O[Return - Wait Cleanup]
    I --> N
    N --> P[Check DCA Expansion]
    P --> Q[Check Loss Protection]
    Q --> R[Handle Trailing Stop]
    R --> S[Place Grid Orders]
    S --> T[OnTick Complete]
    
    H --> T
    O --> T
```

**This flowchart represents the complete operational flow of the GRID-DCA EA v2.0 system! 🎯**
