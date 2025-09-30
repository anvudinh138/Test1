# FLEX GRID DCA EA - Technical Architecture

## System Architecture Overview

### 1. Core Engine Structure
```
FlexGridDCA_EA
├── MarketAnalyzer/
│   ├── ATRCalculator.mqh
│   ├── KillzoneDetector.mqh
│   ├── NewsMonitor.mqh
│   └── VolatilityAnalyzer.mqh
├── GridEngine/
│   ├── GridManager.mqh
│   ├── FibonacciCalculator.mqh
│   └── LevelTracker.mqh
├── DCAEngine/
│   ├── DCAManager.mqh
│   ├── PositionSizer.mqh
│   └── AveragingLogic.mqh
├── RiskController/
│   ├── RiskManager.mqh
│   ├── DrawdownController.mqh
│   └── EmergencyStop.mqh
├── PositionManager/
│   ├── OrderManager.mqh
│   ├── TrailingStop.mqh
│   └── ProfitTracker.mqh
└── Utils/
    ├── ATRUtils.mqh
    ├── TimeUtils.mqh
    └── MathUtils.mqh
```

## Component Details

### MarketAnalyzer Module

#### ATRCalculator
```cpp
class CATRCalculator {
private:
    double m_atr_values[5];  // M1, M15, H1, H4, D1
    int m_period;
    
public:
    bool CalculateATR(string symbol, ENUM_TIMEFRAMES tf, int period);
    double GetATR(ENUM_TIMEFRAMES tf);
    double GetNormalizedATR(string symbol);  // ATR as percentage of price
    bool IsVolatilityNormal();
};
```

#### KillzoneDetector
```cpp
class CKillzoneDetector {
private:
    struct SKillzone {
        int start_hour;
        int end_hour;
        string name;
        bool is_active;
    };
    SKillzone m_killzones[4];  // London, NY, Asian, Overlap
    
public:
    bool IsKillzoneActive();
    string GetCurrentKillzone();
    bool ShouldAvoidTrading();
};
```

#### NewsMonitor
```cpp
class CNewsMonitor {
private:
    struct SNewsEvent {
        datetime time;
        string currency;
        int impact;  // 1=Low, 2=Medium, 3=High
        bool is_active;
    };
    SNewsEvent m_events[];
    
public:
    bool IsNewsTime(int minutes_before = 30, int minutes_after = 30);
    bool IsHighImpactNews();
    datetime GetNextNewsTime();
};
```

### GridEngine Module

#### GridManager
```cpp
class CGridManager {
private:
    struct SGridLevel {
        double price;
        double lot_size;
        bool is_filled;
        ulong ticket;
        datetime fill_time;
    };
    SGridLevel m_grid_levels[];
    double m_base_price;
    double m_grid_spacing;
    
public:
    bool InitializeGrid(double base_price, double atr);
    bool UpdateGridLevels();
    bool PlaceGridOrders();
    double CalculateFibonacciSpacing(double atr, int level);
};
```

### DCAEngine Module

#### DCAManager
```cpp
class CDCAManager {
private:
    struct SDCALevel {
        double entry_price;
        double lot_size;
        datetime entry_time;
        bool is_active;
    };
    SDCALevel m_dca_levels[];
    double m_average_price;
    double m_total_lots;
    
public:
    bool ShouldTriggerDCA(double current_price);
    double CalculateDCALotSize(int level);
    bool ExecuteDCA();
    double GetAveragePrice();
};
```

### RiskController Module

#### RiskManager
```cpp
class CRiskManager {
private:
    double m_max_risk_percent;
    double m_current_exposure;
    double m_max_drawdown;
    double m_account_start_balance;
    
public:
    bool CheckRiskLimits();
    double CalculatePositionSize(double atr, double risk_percent);
    bool IsExposureExceeded();
    bool ShouldStopTrading();
};
```

## Data Structures

### Position Tracking
```cpp
struct SPosition {
    string symbol;
    ENUM_ORDER_TYPE type;  // Buy/Sell
    double entry_price;
    double current_lots;
    double unrealized_pnl;
    double realized_pnl;
    datetime entry_time;
    int grid_level;
    int dca_level;
    bool is_trailing;
};
```

### Market State
```cpp
struct SMarketState {
    double atr_h1;
    double atr_h4;
    double atr_d1;
    double volatility_ratio;
    bool is_killzone;
    bool is_news_time;
    ENUM_MARKET_CONDITION condition;  // NORMAL, HIGH_VOL, LOW_VOL
};
```

## Key Algorithms

### 1. ATR-Based Grid Calculation
```cpp
double CalculateGridSpacing(double atr, int level) {
    double fibonacci_ratios[] = {0.236, 0.382, 0.618, 1.0, 1.618, 2.618};
    double base_spacing = atr * GridSpacingATR;
    
    if(level < ArraySize(fibonacci_ratios)) {
        return base_spacing * fibonacci_ratios[level];
    }
    return base_spacing * MathPow(1.618, level - 5);  // Continue Fibonacci expansion
}
```

### 2. Dynamic Position Sizing
```cpp
double CalculatePositionSize(double atr, double risk_percent) {
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (risk_percent / 100.0);
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double atr_in_pips = atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    return NormalizeDouble(risk_amount / (atr_in_pips * pip_value), 2);
}
```

### 3. Dual Direction Logic
```cpp
class CDualDirectionManager {
private:
    SPosition m_long_positions[];
    SPosition m_short_positions[];
    
public:
    bool CanOpenLong();
    bool CanOpenShort();
    double GetNetExposure();
    bool ShouldHedge();
};
```

## Configuration Management

### Universal Settings
```cpp
// ATR-based universal settings
input group "Universal Grid Settings"
input double InpGridSpacingATR = 1.0;      // Grid spacing multiplier
input double InpDCASpacingATR = 0.5;       // DCA spacing multiplier
input int InpMaxGridLevels = 10;           // Maximum grid levels
input int InpMaxDCALevels = 5;             // Maximum DCA levels

input group "Risk Management"
input double InpMaxRiskPercent = 5.0;      // Max risk per position %
input double InpMaxAccountRisk = 20.0;     // Max total account risk %
input double InpProfitTarget = 3.0;        // Profit target %

input group "Market Intelligence"
input bool InpUseKillzoneFilter = true;    // Enable killzone filter
input bool InpUseNewsFilter = true;        // Enable news filter
input double InpMinVolatilityATR = 0.5;    // Min volatility threshold
input double InpMaxVolatilityATR = 3.0;    // Max volatility threshold

input group "Advanced Features"
input bool InpEnableDualDirection = true;  // Enable long/short together
input bool InpEnableTrailingStop = true;   // Enable trailing stop
input double InpTrailingStopATR = 2.0;     // Trailing stop distance
```

## Performance Optimization

### 1. Memory Management
- Use object pools for frequent allocations
- Implement circular buffers for price history
- Cache ATR calculations

### 2. Processing Efficiency
- Update grid only on significant price moves
- Batch order operations
- Use timer events instead of tick-by-tick processing

### 3. Error Handling
- Robust connection handling
- Order execution retry logic
- Graceful degradation during high volatility

## Testing Framework

### Unit Tests
- ATR calculation accuracy
- Grid level calculations
- Risk management limits
- Position sizing logic

### Integration Tests
- Full strategy simulation
- Multi-timeframe coordination
- Error condition handling

### Backtest Requirements
- EURUSD H1 data (minimum 1 year)
- Various market conditions (trending, ranging, volatile)
- Performance metrics tracking
- Risk metrics validation

## Next Development Steps

### Immediate (Week 1-2)
1. Implement basic ATR calculator
2. Create simple grid structure
3. Add position tracking
4. Basic risk management

### Short Term (Week 3-4)
1. DCA integration
2. Killzone detection
3. Basic trailing stop
4. EURUSD testing

### Medium Term (Month 2)
1. News integration
2. Advanced risk features
3. Dual direction logic
4. Performance optimization

### Long Term (Month 3+)
1. Multi-symbol adaptation
2. Machine learning integration
3. Advanced market analysis
4. Production deployment
