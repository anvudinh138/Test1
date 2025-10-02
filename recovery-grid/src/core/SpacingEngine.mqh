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
   double          m_fixed_pips;
   double          m_min_pips;
   int             m_digits;
   int             m_atr_handle;
   datetime        m_cache_time;
   double          m_cache_value;
   double          m_last_atr_points;

   // SGS state
   bool            m_sgs_enabled;
   int             m_sgs_recent_bars;
   int             m_sgs_long_bars;
   double          m_sgs_ranging_threshold;
   double          m_sgs_trending_threshold;
   double          m_sgs_ranging_mult;
   double          m_sgs_trending_mult;
   int             m_sgs_atr_ma_period;
   double          m_sgs_min_mult;
   double          m_sgs_max_mult;

   double          FetchATR() const
     {
      if(m_atr_handle==INVALID_HANDLE)
         return 0.0;
      double buf[];
      if(CopyBuffer(m_atr_handle,0,0,1,buf)!=1)
         return 0.0;
      return buf[0];
     }

   double          CalculateRangeRatio()
     {
      if(!m_sgs_enabled)
         return 0.5;  // NORMAL

      // Recent range
      int recent_high_idx=iHighest(m_symbol,m_atr_tf,MODE_HIGH,m_sgs_recent_bars,0);
      int recent_low_idx=iLowest(m_symbol,m_atr_tf,MODE_LOW,m_sgs_recent_bars,0);
      if(recent_high_idx<0 || recent_low_idx<0)
         return 0.5;

      double recent_high=iHigh(m_symbol,m_atr_tf,recent_high_idx);
      double recent_low=iLow(m_symbol,m_atr_tf,recent_low_idx);
      double recent_range=recent_high-recent_low;

      // Long-term range
      int long_high_idx=iHighest(m_symbol,m_atr_tf,MODE_HIGH,m_sgs_long_bars,0);
      int long_low_idx=iLowest(m_symbol,m_atr_tf,MODE_LOW,m_sgs_long_bars,0);
      if(long_high_idx<0 || long_low_idx<0)
         return 0.5;

      double long_high=iHigh(m_symbol,m_atr_tf,long_high_idx);
      double long_low=iLow(m_symbol,m_atr_tf,long_low_idx);
      double long_range=long_high-long_low;

      if(long_range<=0.0)
         return 0.5;

      return recent_range/long_range;
     }

   double          CalculateAtrAcceleration()
     {
      if(!m_sgs_enabled || m_atr_handle==INVALID_HANDLE)
         return 1.0;  // NORMAL

      double atr_current=FetchATR();
      if(atr_current<=0.0)
         return 1.0;

      // Calculate ATR MA
      double atr_buf[];
      int copied=CopyBuffer(m_atr_handle,0,0,m_sgs_atr_ma_period,atr_buf);
      if(copied!=m_sgs_atr_ma_period)
         return 1.0;

      double atr_sum=0.0;
      for(int i=0;i<m_sgs_atr_ma_period;i++)
         atr_sum+=atr_buf[i];

      double atr_ma=atr_sum/m_sgs_atr_ma_period;

      if(atr_ma<=0.0)
         return 1.0;

      return atr_current/atr_ma;
     }

   double          CalculateAdaptiveSpacing()
     {
      if(!m_sgs_enabled)
         return m_atr_mult;

      double spacing_mult=m_atr_mult;

      // === Factor 1: Trend/Range Regime ===
      double range_ratio=CalculateRangeRatio();

      if(range_ratio<m_sgs_ranging_threshold)
        {
         // RANGING: Tighten spacing
         spacing_mult*=m_sgs_ranging_mult;
        }
      else if(range_ratio>m_sgs_trending_threshold)
        {
         // TRENDING: Widen spacing
         spacing_mult*=m_sgs_trending_mult;
        }
      // else NORMAL: keep base mult

      // === Factor 2: Volatility Acceleration ===
      double atr_accel=CalculateAtrAcceleration();

      if(atr_accel>1.3)
        {
         // HIGH vol cluster: Widen further
         spacing_mult*=1.2;
        }
      else if(atr_accel<0.8)
        {
         // LOW vol: Tighten
         spacing_mult*=0.9;
        }

      // === Bounds ===
      spacing_mult=MathMax(spacing_mult,m_sgs_min_mult);
      spacing_mult=MathMin(spacing_mult,m_sgs_max_mult);

      return spacing_mult;
     }

public:
                     CSpacingEngine(const string symbol,
                                    const ESpacingMode mode,
                                    const int atr_period,
                                    const ENUM_TIMEFRAMES atr_tf,
                                    const double atr_mult,
                                    const double fixed_pips,
                                    const double min_pips,
                                    const SParams &params)
                       : m_symbol(symbol),
                         m_mode(mode),
                         m_atr_period(atr_period),
                         m_atr_tf(atr_tf),
                         m_atr_mult(atr_mult),
                         m_fixed_pips(fixed_pips),
                         m_min_pips(min_pips),
                         m_digits((int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                         m_atr_handle(INVALID_HANDLE),
                         m_cache_time(0),
                         m_cache_value(0.0),
                         m_last_atr_points(0.0),
                         m_sgs_enabled(params.sgs_enabled),
                         m_sgs_recent_bars(params.sgs_recent_bars),
                         m_sgs_long_bars(params.sgs_long_bars),
                         m_sgs_ranging_threshold(params.sgs_ranging_threshold),
                         m_sgs_trending_threshold(params.sgs_trending_threshold),
                         m_sgs_ranging_mult(params.sgs_ranging_mult),
                         m_sgs_trending_mult(params.sgs_trending_mult),
                         m_sgs_atr_ma_period(params.sgs_atr_ma_period),
                         m_sgs_min_mult(params.sgs_min_mult),
                         m_sgs_max_mult(params.sgs_max_mult)
     {
      if(mode!=SPACING_PIPS)
        {
         m_atr_handle=iATR(symbol,atr_tf,atr_period);
        }
     }

   double            SpacingPips()
     {
      datetime now=TimeCurrent();
      if(now==m_cache_time && m_cache_value>0.0)
         return m_cache_value;

      double result=m_fixed_pips;
      if(m_mode==SPACING_ATR || m_mode==SPACING_HYBRID)
        {
         double atr_points=FetchATR();
         double pip_points=PipPoints(m_symbol);
         if(atr_points>0.0) m_last_atr_points=atr_points;
         if(pip_points>0.0)
           {
            double atr_pips=atr_points/pip_points;

            // === SGS: Adaptive multiplier ===
            double effective_mult=m_atr_mult;
            if(m_sgs_enabled)
              {
               effective_mult=CalculateAdaptiveSpacing();
              }

            double atr_spacing=MathMax(m_min_pips,atr_pips*effective_mult);
            if(m_mode==SPACING_ATR)
               result=atr_spacing;
            else
               result=MathMax(m_fixed_pips,atr_spacing);
           }
        }

      result=MathMax(result,m_min_pips);
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
      if(m_mode==SPACING_PIPS)
         return 0.0;
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