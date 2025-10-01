//+------------------------------------------------------------------+
//| Spacing engine: converts parameter mode into pip distance        |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_SPACING_ENGINE_MQH__
#define __RGD_V2_SPACING_ENGINE_MQH__

#include <Indicators/Trend.mqh>
#include "Types.mqh"
#include "Params.mqh"
#include "MathHelpers.mqh"

class CSpacingEngine
  {
private:
   string          m_symbol;
   ESpacingMode    m_mode;
   int             m_atr_period;
   ENUM_TIMEFRAMES m_atr_tf;
   double          m_atr_mult;
   double          m_min_pips;
   int             m_digits;
   int             m_atr_handle;
   datetime        m_cache_time;
   double          m_cache_value;
   double          m_last_atr_points;

   double          FetchATR() const
     {
      if(m_atr_handle==INVALID_HANDLE)
         return 0.0;
      double buf[];
      if(CopyBuffer(m_atr_handle,0,0,1,buf)!=1)
         return 0.0;
      return buf[0];
     }

public:
                     CSpacingEngine(const string symbol,
                                    const ESpacingMode mode,
                                    const int atr_period,
                                    const ENUM_TIMEFRAMES atr_tf,
                                    const double atr_mult,
                                    const double min_pips)
                       : m_symbol(symbol),
                         m_mode(mode),
                         m_atr_period(atr_period),
                         m_atr_tf(atr_tf),
                         m_atr_mult(atr_mult),
                         m_min_pips(min_pips),
                         m_digits((int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                         m_atr_handle(INVALID_HANDLE),
                         m_cache_time(0),
                         m_cache_value(0.0),
                         m_last_atr_points(0.0)
     {
      if(mode==SPACING_ATR || mode==SPACING_HYBRID)
        {
         m_atr_handle=iATR(symbol,atr_tf,atr_period);
        }
     }

   double            SpacingPips()
     {
      datetime now=TimeCurrent();
      if(now==m_cache_time && m_cache_value>0.0)
         return m_cache_value;

      double result=0.0;
      double atr_points=FetchATR();
      double pip_points=PipPoints(m_symbol);
      if(atr_points>0.0)
         m_last_atr_points=atr_points;
      if(pip_points>0.0 && m_last_atr_points>0.0)
        {
         double atr_pips=m_last_atr_points/pip_points;
         double atr_spacing=atr_pips*m_atr_mult;
         if(m_mode==SPACING_ATR)
            result=atr_spacing;
         else
            result=MathMax(m_min_pips,atr_spacing);
        }

      if(result<=0.0)
        {
         if(m_mode==SPACING_HYBRID)
            result=m_min_pips;
         else if(m_min_pips>0.0)
            result=MathMax(result,m_min_pips);
        }
      if(result<=0.0)
         result=(m_min_pips>0.0)?m_min_pips:1.0;
      m_cache_time=now;
      m_cache_value=result;
      return result;
     }

   double            ToPrice(const double pips) const
     {
      return pips*PipPoints(m_symbol);
     }


   double            AtrPoints()
     {
      double atr_points=FetchATR();
      if(atr_points>0.0)
         m_last_atr_points=atr_points;
      return m_last_atr_points;
     }

   double            AtrPips()
     {
      double points=AtrPoints();
      double pip_points=PipPoints(m_symbol);
      if(pip_points<=0.0)
         return 0.0;
      return points/pip_points;
     }

   int               Digits() const { return m_digits; }
  };

#endif // __RGD_V2_SPACING_ENGINE_MQH__
