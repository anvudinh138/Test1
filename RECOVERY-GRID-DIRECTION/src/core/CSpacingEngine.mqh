// Include guard for MQL5
#ifndef __RGD_CSPACINGENGINE_MQH__
#define __RGD_CSPACINGENGINE_MQH__

#include <RECOVERY-GRID-DIRECTION/core/Types.mqh>


class CSpacingEngine {
private:
  string m_symbol;
  ESpacingMode m_mode;
  int m_atr_period;
  ENUM_TIMEFRAMES m_atr_tf;
  double m_atr_mult;
  double m_fixed_pips;
  double m_min_pips;
  datetime m_cache_time;
  double m_cache_pips;
  int m_atr_handle;

  double PipPoints() const {
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    if(digits==3 || digits==5) return 10.0 * _Point;
    return 1.0 * _Point;
  }

  double ATRPoints() {
    // Lazy-create ATR handle and fetch latest value
    if(m_atr_handle==INVALID_HANDLE)
      m_atr_handle = iATR(m_symbol, m_atr_tf, m_atr_period);
    if(m_atr_handle==INVALID_HANDLE) return 0.0;
    double buf[];
    if(CopyBuffer(m_atr_handle, 0, 0, 1, buf) != 1) return 0.0;
    return buf[0];
  }

public:
  CSpacingEngine(const string symbol,
                 const ESpacingMode mode,
                 const int atr_period,
                 const ENUM_TIMEFRAMES atr_tf,
                 const double atr_mult,
                 const double fixed_pips,
                 const double min_pips)
    : m_symbol(symbol), m_mode(mode), m_atr_period(atr_period), m_atr_tf(atr_tf),
      m_atr_mult(atr_mult), m_fixed_pips(fixed_pips), m_min_pips(min_pips),
      m_cache_time(0), m_cache_pips(0.0), m_atr_handle(INVALID_HANDLE) {}

  double SpacingPips() {
    datetime now = TimeCurrent();
    if(now - m_cache_time <= 5 && m_cache_pips>0) return m_cache_pips; // cache 5s

    double pip_points = PipPoints();
    double fixed = MathMax(m_fixed_pips, m_min_pips);
    if(m_mode==SPACING_PIPS) {
      m_cache_pips = fixed;
    } else if(m_mode==SPACING_ATR) {
      double atr_points = ATRPoints();
      double atr_pips = (pip_points>0) ? (atr_points / pip_points) : 0.0;
      m_cache_pips = MathMax(m_min_pips, atr_pips * m_atr_mult);
    } else { // HYBRID
      double atr_points = ATRPoints();
      double atr_pips = (pip_points>0) ? (atr_points / pip_points) : 0.0;
      double hybrid = MathMax(fixed, atr_pips * m_atr_mult);
      m_cache_pips = MathMax(m_min_pips, hybrid);
    }

    m_cache_time = now;
    return m_cache_pips;
  }

  double PipsToPrice(const double pips) const { return pips * PipPoints(); }
};

#endif // __RGD_CSPACINGENGINE_MQH__
