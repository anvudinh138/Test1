# FLEX GRID DCA EA - Project Analysis

## Mục tiêu dự án
Xây dựng một bot EA tự quản lý kết hợp Grid Trading và DCA (Dollar Cost Averaging) với khả năng:
- Tự quản lý hoàn toàn không qua sàn
- Hoạt động trên tất cả symbol (universal design)
- Kết hợp Grid + DCA strategy
- Risk management thông minh
- Market awareness (News, Volatility, Killzone)
- Dual direction (Long/Short)

## Yêu cầu chi tiết

### 1. Universal Design
- **ATR-based calculations**: Sử dụng ATR thay vì pip/point để có thể hoạt động trên mọi symbol
- **Fibonacci levels**: Áp dụng fibonacci cho grid spacing
- **Dynamic sizing**: Lot size tự động dựa trên volatility và risk

### 2. Trading Strategy
- **Grid Trading**: Tạo lưới orders ở các mức giá khác nhau
- **DCA Integration**: Tăng position khi price đi ngược hướng
- **Dual Direction**: Có thể long và short simultaneously
- **Smart Entry**: Sử dụng market analysis để timing entry

### 3. Risk Management
- **ATR 1440 Volatility**: Đo volatility daily để adjust strategy
- **Trailing Stop**: Bảo vệ lợi nhuận khi có gain
- **Max Risk Control**: Giới hạn exposure tối đa
- **Profit Target**: Tự động close all khi đạt target profit

### 4. Market Intelligence
- **Killzone Detection**: Nhận biết các khung giờ quan trọng
- **News Awareness**: Tránh trade trong news events
- **Volatility Analysis**: Điều chỉnh strategy theo market condition

## Kiến trúc hệ thống

### Core Components
1. **Market Analyzer**
   - ATR Calculator (M1, M15, H1, H4, D1)
   - Killzone Detector
   - News Event Monitor
   - Volatility Assessment

2. **Grid Manager**
   - Fibonacci Grid Calculator
   - Dynamic Grid Spacing
   - Grid Level Management
   - Position Tracking

3. **DCA Engine**
   - Averaging Strategy
   - Position Sizing
   - Entry Timing
   - Cost Basis Calculation

4. **Risk Controller**
   - Exposure Monitoring
   - Drawdown Protection
   - Profit Target Management
   - Emergency Stop

5. **Position Manager**
   - Long/Short Coordination
   - Trailing Stop Logic
   - Partial Close Strategy
   - Total Portfolio P&L

### Data Flow
```
Market Data → Market Analyzer → Signal Generation
                ↓
Grid Manager ← Strategy Coordinator → DCA Engine
                ↓
Risk Controller → Position Manager → Order Execution
```

## Implementation Roadmap

### Phase 1: Core Foundation (EURUSD Focus)
- [ ] ATR calculation system
- [ ] Basic grid logic
- [ ] Simple DCA integration
- [ ] Risk management framework

### Phase 2: Market Intelligence
- [ ] Killzone detection
- [ ] Volatility analysis
- [ ] News integration
- [ ] Market condition assessment

### Phase 3: Advanced Features
- [ ] Dual direction trading
- [ ] Trailing stop system
- [ ] Profit optimization
- [ ] Emergency controls

### Phase 4: Universal Deployment
- [ ] Symbol adaptation
- [ ] Multi-symbol testing
- [ ] Performance optimization
- [ ] Final documentation

## Technical Specifications

### Inputs Parameters
```cpp
// Grid Settings
input double    GridSpacingATR = 1.0;        // Grid spacing in ATR multiplier
input double    FibonacciRatio = 1.618;      // Fibonacci expansion ratio
input int       MaxGridLevels = 10;          // Maximum grid levels

// DCA Settings  
input double    DCAMultiplier = 1.5;         // DCA lot multiplier
input int       MaxDCALevels = 5;            // Maximum DCA levels
input double    DCASpacingATR = 0.5;         // DCA spacing in ATR

// Risk Management
input double    MaxRiskPercent = 5.0;        // Maximum account risk %
input double    ProfitTargetPercent = 3.0;   // Profit target %
input double    TrailingStopATR = 2.0;       // Trailing stop in ATR

// Market Intelligence
input bool      UseKillzoneFilter = true;    // Enable killzone filtering
input bool      UseNewsFilter = true;        // Enable news filtering
input double    MinVolatilityATR = 0.5;      // Minimum volatility threshold
input double    MaxVolatilityATR = 3.0;      // Maximum volatility threshold
```

### Key Calculations
- **ATR-based Spacing**: `spacing = ATR(period) * multiplier`
- **Dynamic Lot Size**: `lot = (account_equity * risk_percent) / (atr * pip_value)`
- **Fibonacci Levels**: `level[i] = base_price ± (atr * fibonacci_sequence[i])`

## Focus Symbol: EURUSD
- **ATR Period**: 14 (H1 timeframe primary)
- **Grid Base**: Current price ± ATR levels
- **DCA Trigger**: Price moves against position > ATR threshold
- **Profit Target**: 2-3% account growth per complete cycle

## Next Steps
1. Implement core ATR calculation module
2. Build basic grid structure for EURUSD
3. Integrate simple DCA logic
4. Add basic risk controls
5. Test with small position sizes

## Success Metrics
- Consistent profit across different market conditions
- Maximum drawdown < 10%
- Win rate > 60% of completed cycles
- Adaptability to high/low volatility periods
- No manual intervention required
