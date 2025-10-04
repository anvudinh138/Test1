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
                                    const int atr_period,
                                    const ENUM_TIMEFRAMES atr_tf,
                                    const double atr_mult)
                       : m_symbol(symbol),
                         m_mode(SPACING_ATR),  // Always ATR mode
                         m_atr_period(atr_period),
                         m_atr_tf(atr_tf),
                         m_atr_mult(atr_mult),
                         m_fixed_pips(0.0),    // Not used (ATR only)
                         m_min_pips(0.0),      // Not used (trust ATR)
                         m_digits((int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                         m_atr_handle(INVALID_HANDLE),
                         m_cache_time(0),
                         m_cache_value(0.0),
                         m_last_atr_points(0.0)
     {
      // Always initialize ATR (forced ATR mode)
      m_atr_handle=iATR(symbol,atr_tf,atr_period);
      if(m_atr_handle==INVALID_HANDLE)
        {
         Print("[SpacingEngine] ERROR: Failed to create ATR indicator for ",symbol," TF=",atr_tf," period=",atr_period," error=",GetLastError());
        }
     }

   double            SpacingPips()
     {
      datetime now=TimeCurrent();
      if(now==m_cache_time && m_cache_value>0.0)
         return m_cache_value;

      // ATR-only mode (simplified logic)
      double result=0.0;
      double pip_points=PipPoints(m_symbol);

      // Retry ATR fetch with timeout (for visual mode compatibility)
      double atr_points=0.0;
      int retry_count=0;
      int max_retries=10;

      while(atr_points<=0.0 && retry_count<max_retries)
        {
         atr_points=FetchATR();
         if(atr_points>0.0)
            break;
         Sleep(100);  // Wait 100ms for indicator to init
         retry_count++;
        }

      if(atr_points>0.0)
         m_last_atr_points=atr_points;

      if(pip_points>0.0 && m_last_atr_points>0.0)
        {
         double atr_pips=m_last_atr_points/pip_points;
         result=atr_pips*m_atr_mult;  // No floor, trust ATR
        }
      else if(pip_points>0.0 && m_atr_mult>0.0)
        {
         // Fallback: If ATR still not ready after retries
         result=10.0*m_atr_mult;
         Print("[SpacingEngine] ATR not ready after ",retry_count," retries, using fallback: ",result," pips");
        }

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
      // Always return ATR (forced ATR mode)
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