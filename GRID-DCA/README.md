# FLEX GRID DCA EA Project

## 📋 Tổng quan dự án

Bot EA tự quản lý kết hợp Grid Trading và DCA với khả năng hoạt động universal trên tất cả symbols, focus ban đầu cho **EURUSD**.

## 🎯 Mục tiêu chính

- ✅ Tự quản lý hoàn toàn (không qua sàn)
- ✅ Universal design (ATR-based, Fibonacci)
- ✅ Kết hợp Grid + DCA strategy
- ✅ Dual direction (Long/Short)
- ✅ Market intelligence (Killzone, News, Volatility)
- ✅ Advanced risk management
- ✅ Trailing stop và profit targeting

## 📁 Document Structure

### Core Documentation
1. **[PROJECT_ANALYSIS.md](./PROJECT_ANALYSIS.md)** - Phân tích tổng quan yêu cầu và kiến trúc hệ thống
2. **[TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md)** - Chi tiết kỹ thuật và cấu trúc code
3. **[GETTING_STARTED.md](./GETTING_STARTED.md)** - Hướng dẫn bắt đầu phát triển

### Development Files (✅ READY)
- `src/` - Source code directory (EA + includes)
- `config/` - Configuration files for EURUSD
- `INSTALLATION_GUIDE.md` - Quick setup guide
- `tests/` - Test files (future)
- `backtest/` - Backtest results (future)

## 🚀 Quick Start

### Yêu cầu để bắt đầu:
1. **MT5 Platform** với demo account
2. **MQL5 knowledge** - lập trình Expert Advisor
3. **Trading concepts** - Grid, DCA, Risk Management
4. **EURUSD market data** cho testing

### Bước đầu tiên:
```bash
1. ⚡ READY TO USE: Đọc INSTALLATION_GUIDE.md để setup ngay
2. Hoặc đọc PROJECT_ANALYSIS.md để hiểu tổng quan
3. Chi tiết kỹ thuật trong TECHNICAL_ARCHITECTURE.md  
4. Source code guide trong src/README.md
```

## 🏗️ Development Roadmap

### Phase 1: Foundation ✅ COMPLETED
- [x] ATR Calculator system
- [x] Basic Grid structure
- [x] Position tracking
- [x] Risk management framework
- [x] EURUSD prototype

### Phase 2: Intelligence (3-4 weeks)  
- [ ] Market analyzer (Killzone, News)
- [ ] DCA integration
- [ ] Trailing stop system
- [ ] Dual direction logic

### Phase 3: Advanced (4+ weeks)
- [ ] Multi-symbol adaptation
- [ ] Performance optimization
- [ ] Advanced risk features
- [ ] Production deployment

## 💡 Key Features

### Universal Design
- **ATR-based calculations** thay vì hardcode pips
- **Fibonacci grid spacing** cho optimal levels
- **Dynamic position sizing** theo volatility

### Market Intelligence
- **Killzone detection** - London, NY, Asian sessions
- **News filtering** - tránh high impact events
- **Volatility analysis** - ATR 1440 monitoring

### Risk Management
- **Maximum exposure control**
- **Drawdown protection** 
- **Emergency stop mechanisms**
- **Profit target automation**

### Advanced Trading
- **Grid + DCA combination**
- **Long/Short simultaneous**
- **Trailing stop protection**
- **Automatic profit taking**

## 📊 Performance Targets

| Metric | Target |
|--------|---------|
| Win Rate | > 60% |
| Max Drawdown | < 10% |
| Profit Factor | > 1.5 |
| Recovery Factor | > 3.0 |
| Uptime | 99%+ |

## 🔧 Technical Stack

- **Language**: MQL5
- **Platform**: MetaTrader 5
- **Architecture**: Object-Oriented Design
- **Testing**: Strategy Tester + Demo Account
- **Deployment**: VPS with low latency

## 📈 Focus Symbol: EURUSD

**Tại sao chọn EURUSD:**
- Liquidity cao, spread thấp
- Volatility ổn định và predictable
- Nhiều data available cho backtesting
- Killzone patterns rõ ràng
- Good for ATR-based calculations

## ⚠️ Important Notes

### Universal Design Principles
```cpp
// ❌ Avoid hardcoded values
double stop_loss = 20 * Point;

// ✅ Use ATR-based calculations  
double stop_loss = atr_h1 * 2.0;
```

### Risk First Approach
```cpp
// Always check risk before trading
if(!risk_manager.CheckLimits()) {
    return false; // Skip trade
}
```

## 📞 Next Steps

1. **Setup development environment**
2. **Start with ATR Calculator** 
3. **Build basic grid for EURUSD**
4. **Add simple risk controls**
5. **Test and iterate**

---

**Created:** September 25, 2025  
**Focus:** EURUSD Initial Development  
**Status:** ✅ PROTOTYPE READY - Ready for Demo Testing

> 💡 **Tip:** Bắt đầu với component nhỏ và test kỹ trước khi move to next phase. Quality over speed!
