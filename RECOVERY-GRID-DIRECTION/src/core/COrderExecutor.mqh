// Include guard for MQL5
#ifndef __RGD_CORDEREXECUTOR_MQH__
#define __RGD_CORDEREXECUTOR_MQH__

#include <Trade/Trade.mqh>

class COrderExecutor {
private:
  string m_symbol;
  int m_cooldown_sec;
  int m_slippage_points;
  bool m_respect_stops;
  datetime m_last_order_time;
  CTrade m_trade;
  int m_bypass_remaining;

  bool CooldownReady() {
    datetime now = TimeCurrent();
    if(m_bypass_remaining>0){ m_bypass_remaining--; return true; }
    if(now - m_last_order_time < m_cooldown_sec) return false;
    return true;
  }

  bool ValidateLimitPrice(ENUM_ORDER_TYPE type, double price) {
    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    int stops_level_pts  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze_level_pts = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    double min_dist = MathMax(stops_level_pts, freeze_level_pts) * _Point;
    double eps = 2*_Point;

    // If broker reports 0 for both, still enforce tiny epsilon
    if(min_dist <= 0) min_dist = eps;

    switch(type){
      case ORDER_TYPE_BUY_LIMIT:
        // Must be sufficiently below current Bid (and Ask)
        if(!(price <= bid - min_dist)) return false;
        break;
      case ORDER_TYPE_SELL_LIMIT:
        // Must be sufficiently above current Ask
        if(!(price >= ask + min_dist)) return false;
        break;
      default:
        return true;
    }
    return true;
  }

  bool ValidateStopPrice(ENUM_ORDER_TYPE type, double price) {
    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    int stops_level_pts  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze_level_pts = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    double min_dist = MathMax(stops_level_pts, freeze_level_pts) * _Point;
    double eps = 2*_Point;
    if(min_dist <= 0) min_dist = eps;

    switch(type){
      case ORDER_TYPE_BUY_STOP:
        // Must be sufficiently above current Ask
        if(!(price >= ask + min_dist)) return false;
        break;
      case ORDER_TYPE_SELL_STOP:
        // Must be sufficiently below current Bid
        if(!(price <= bid - min_dist)) return false;
        break;
      default:
        return true;
    }
    return true;
  }

public:
  COrderExecutor(const string symbol, const int cooldown_sec, const int slippage_points, const bool respect_stops)
    : m_symbol(symbol), m_cooldown_sec(cooldown_sec), m_slippage_points(slippage_points),
      m_respect_stops(respect_stops), m_last_order_time(0), m_bypass_remaining(0) {
    m_trade.SetExpertMagicNumber(0);
    m_trade.SetDeviationInPoints(m_slippage_points);
  }

  void SetMagic(long magic) { m_trade.SetExpertMagicNumber(magic); }

  // Allow next N orders to skip cooldown (for initial grid batch)
  void BypassCooldownCount(const int n){ if(n>0) m_bypass_remaining += n; }

  ulong PlaceMarket(EDirection dir, double lot, string comment="") {
    if(!CooldownReady()) return 0;
    bool ok=false;
    if(dir==DIR_BUY) ok = m_trade.Buy(lot, m_symbol, 0.0, 0.0, 0.0, comment);
    else ok = m_trade.Sell(lot, m_symbol, 0.0, 0.0, 0.0, comment);
    if(ok){ m_last_order_time = TimeCurrent(); return m_trade.ResultOrder(); }
    return 0;
  }

  ulong PlaceLimit(EDirection dir, double price, double lot, string comment="") {
    if(!CooldownReady()) return 0;
    ENUM_ORDER_TYPE type = (dir==DIR_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    if(!ValidateLimitPrice(type, price)) return 0;
    bool ok=false;
    double p = NormalizeDouble(price, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
    if(type==ORDER_TYPE_BUY_LIMIT) ok = m_trade.BuyLimit(lot, p, m_symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, comment);
    else ok = m_trade.SellLimit(lot, p, m_symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, comment);
    if(ok){ m_last_order_time = TimeCurrent(); return m_trade.ResultOrder(); }
    return 0;
  }

  ulong PlaceStop(EDirection dir, double price, double lot, string comment="") {
    if(!CooldownReady()) return 0;
    ENUM_ORDER_TYPE type = (dir==DIR_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
    if(!ValidateStopPrice(type, price)) return 0;
    bool ok=false;
    double p = NormalizeDouble(price, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
    if(type==ORDER_TYPE_BUY_STOP) ok = m_trade.BuyStop(lot, p, m_symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, comment);
    else ok = m_trade.SellStop(lot, p, m_symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, comment);
    if(ok){ m_last_order_time = TimeCurrent(); return m_trade.ResultOrder(); }
    return 0;
  }
};

#endif // __RGD_CORDEREXECUTOR_MQH__
