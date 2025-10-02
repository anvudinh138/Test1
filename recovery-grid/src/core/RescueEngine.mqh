//+------------------------------------------------------------------+
//| Rescue engine deciding when to deploy opposite basket            |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_RESCUE_ENGINE_MQH__
#define __RGD_V2_RESCUE_ENGINE_MQH__

#include "Types.mqh"
#include "Params.mqh"
#include "Logger.mqh"

class CRescueEngine
  {
private:
   string   m_symbol;
   SParams  m_params;
   CLogger *m_log;
   datetime m_last_rescue_time;
   int      m_cycles;

   string   Tag() const { return StringFormat("[RGDv2][%s][Rescue]",m_symbol); }

   bool     BreachLastGrid(const EDirection loser_dir,const double last_grid_price,const double spacing_px,const double price) const
     {
      if(spacing_px<=0.0)
         return false;
      // Price breach beyond last grid level (trigger rescue)
      if(loser_dir==DIR_BUY)
         return price<=(last_grid_price-spacing_px);
      return price>=(last_grid_price+spacing_px);
     }

public:
            CRescueEngine(const string symbol,const SParams &params,CLogger *logger)
              : m_symbol(symbol),
                m_params(params),
                m_log(logger),
                m_last_rescue_time(0),
                m_cycles(0)
     {
     }

   // REMOVED: CooldownOk() - no longer needed (rescue rate-limited by price movement)
   // REMOVED: CyclesAvailable() - no longer needed (rescue effectiveness based on lot size)

   bool     ShouldRescue(const EDirection loser_dir,
                         const double last_grid_price,
                         const double spacing_px,
                         const double current_price,
                         const double loser_dd_usd) const
     {
      // Trigger rescue only on price breach (removed DD condition)
      bool breach=BreachLastGrid(loser_dir,last_grid_price,spacing_px,current_price);
      return breach;
     }

   void     RecordRescue()
     {
      m_cycles++;
      m_last_rescue_time=TimeCurrent();
     }

   void     ResetCycleCounter()
     {
      m_cycles=0;
     }

   void     LogSkip(const string reason) const
     {
      if(m_log!=NULL)
         m_log.Status(Tag(),reason);
     }
  };

#endif // __RGD_V2_RESCUE_ENGINE_MQH__