//+------------------------------------------------------------------+
//| Represents one directional basket with grouped TP math           |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_GRID_BASKET_MQH__
#define __RGD_V2_GRID_BASKET_MQH__

#include <Trade/Trade.mqh>
#include "Types.mqh"
#include "Params.mqh"
#include "SpacingEngine.mqh"
#include "OrderExecutor.mqh"
#include "Logger.mqh"
#include "MathHelpers.mqh"

class CGridBasket
  {
private:
   string         m_symbol;
   EDirection     m_direction;
   EBasketKind    m_kind;
   SParams        m_params;
   CSpacingEngine *m_spacing;
   COrderExecutor *m_executor;
   CLogger       *m_log;
   long           m_magic;

   SGridLevel     m_levels[];
   bool           m_active;
   bool           m_closed_recently;
   int            m_cycles_done;
   bool           m_closed_as_hedge;

   double         m_total_lot;
   double         m_avg_price;
   double         m_pnl_usd;
   double         m_tp_price;
   double         m_last_grid_price;
   double         m_target_reduction;
   
   // dynamic grid state
   int            m_max_levels;
   int            m_levels_placed;
   int            m_pending_count;
   double         m_initial_spacing_pips;

   bool           m_trailing_on;
   double         m_last_realized;
   double         m_trail_anchor;
   double         m_trail_override;

   double         m_partial_realized;
   double         m_furthest_entry;

   double         m_initial_atr;
   int            m_entry_bar;

   double         m_volume_step;
   double         m_volume_min;
   double         m_volume_max;
   int            m_volume_digits;

   int            m_max_levels;
   int            m_levels_placed;
   int            m_pending_count;
   double         m_initial_spacing_pips;
   double         m_seed_price;
   double         m_last_limit_price;
   bool           m_trading_allowed;
   double         m_cycle_max_dd;
   double         m_cycle_partial_volume;
   double         m_last_cycle_total_lot;

   string         Tag() const
     {
      string side=(m_direction==DIR_BUY)?"BUY":"SELL";
      string role=(m_kind==BASKET_PRIMARY)?"PRI":"HEDGE";
      return StringFormat("[RGDv2][%s][%s][%s]",m_symbol,side,role);
     }

   string         DirectionLabel() const
     {
      return (m_direction==DIR_BUY)?"BUY":"SELL";
     }

   bool           MatchesOrderDirection(const ENUM_ORDER_TYPE type) const
     {
      if(m_direction==DIR_BUY)
         return (type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP);
      return (type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP);
     }

   void           LogDynamic(const string action,const int level,const double price)
     {
      if(m_log==NULL)
         return;
      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
      m_log.Event(Tag(),StringFormat("DG/%s dir=%s level=%d price=%s pendings=%d last=%s",
                                     action,
                                     DirectionLabel(),
                                     level,
                                     DoubleToString(price,digits),
                                     m_pending_count,
                                     DoubleToString(m_last_grid_price,digits)));
     }

   double         LevelLot(const int idx) const
     {
      double result=m_params.lot_base;
      for(int i=1;i<=idx;i++)
         result*=m_params.lot_scale;
      return NormalizeVolumeValue(result);
     }

   void           ClearLevels()
     {
      ArrayResize(m_levels,0);
     }

   double         NormalizeVolumeValue(double volume) const
     {
      if(volume<=0.0)
         return 0.0;
      double step=(m_volume_step>0.0)?m_volume_step:0.0;
      double normalized=volume;
      if(step>0.0)
        {
         double steps=MathRound(volume/step);
         normalized=steps*step;
        }
      if(normalized<=0.0)
        normalized=(m_volume_min>0.0)?m_volume_min:volume;
      if(m_volume_min>0.0 && normalized<m_volume_min)
         normalized=m_volume_min;
      if(m_volume_max>0.0 && normalized>m_volume_max)
         normalized=m_volume_max;
      if(m_volume_digits>0)
         normalized=NormalizeDouble(normalized,m_volume_digits);
      return normalized;
     }


void           RecordLevel(const double price,const double lot,const ulong ticket,const bool filled)
  {
   int idx=ArraySize(m_levels);
   ArrayResize(m_levels,idx+1);
   m_levels[idx].price=price;
   m_levels[idx].lot=NormalizeVolumeValue(lot);
   m_levels[idx].ticket=ticket;
   m_levels[idx].filled=filled;
   m_levels_placed=idx+1;
   if(idx==0 || (m_direction==DIR_BUY && price<m_last_grid_price) || (m_direction==DIR_SELL && price>m_last_grid_price))
      m_last_grid_price=price;
  }

ulong          PlaceLimit(const double price,const double lot,const string comment)
  {
   if(m_executor==NULL || lot<=0.0)
      return 0;
   if(m_direction==DIR_BUY)
      return m_executor.Limit(DIR_BUY,price,lot,comment);
   return m_executor.Limit(DIR_SELL,price,lot,comment);
  }

   void           UpdateExtremePrice(const double price,bool &have_extreme,double &extreme) const
     {
      if(!have_extreme)
        {
         extreme=price;
         have_extreme=true;
         return;
        }
      if(m_direction==DIR_BUY)
        {
         if(price<extreme)
            extreme=price;
        }
      else
        {
         if(price>extreme)
            extreme=price;
        }
     }

   void           SyncDepthMetrics()
     {
      ClearLevels();
      m_max_levels=m_params.grid_levels;
      m_levels_placed=0;
      m_pending_count=0;
      
      // Pre-allocate full array but only fill warm levels
      if(m_params.grid_dynamic_enabled)
        {
         ArrayResize(m_levels,m_max_levels);
         for(int i=0;i<m_max_levels;i++)
           {
            m_levels[i].price=0.0;
            m_levels[i].lot=0.0;
            m_levels[i].ticket=0;
            m_levels[i].filled=false;
           }
        }
      else
        {
         // Old behavior: build all levels
         AppendLevel(anchor_price,LevelLot(0));
         for(int i=1;i<m_params.grid_levels;i++)
           {
            double price=anchor_price;
            if(m_direction==DIR_BUY)
               price-=spacing_px*i;
            else
               price+=spacing_px*i;
            AppendLevel(price,LevelLot(i));
           }
         m_last_grid_price=m_levels[ArraySize(m_levels)-1].price;
        }
     }

   void           PlaceInitialOrders()
     {
      if(ArraySize(m_levels)==0)
         return;
      if(m_executor==NULL)
         return;

      m_executor.SetMagic(m_magic);
      
      if(m_params.grid_dynamic_enabled)
        {
         // Dynamic mode: only place seed + warm levels
         int warm=MathMin(m_params.grid_warm_levels,m_max_levels-1);
         int warm_cap=warm;
         if(m_params.grid_max_pendings>0)
            warm_cap=MathMin(warm,m_params.grid_max_pendings);
         m_executor.BypassNext(1+warm_cap);
         
         double spacing_px=m_spacing.ToPrice(m_initial_spacing_pips);
         double anchor=SymbolInfoDouble(m_symbol,(m_direction==DIR_BUY)?SYMBOL_ASK:SYMBOL_BID);
         
         // Place seed
         double seed_lot=LevelLot(0);
         ulong market_ticket=m_executor.Market(m_direction,seed_lot,"RGDv2_Seed");
         if(market_ticket>0)
           {
            m_levels[0].price=anchor;
            m_levels[0].lot=seed_lot;
            m_levels[0].ticket=market_ticket;
            m_levels[0].filled=true;
            m_levels_placed++;
            m_last_grid_price=anchor;
            LogDynamic("SEED",0,anchor);
           }
         
         // Place warm pending
         for(int i=1;i<=warm_cap;i++)
           {
            double price=anchor;
            if(m_direction==DIR_BUY)
               price-=spacing_px*i;
            else
               price+=spacing_px*i;
            double lot=LevelLot(i);
            ulong pending=(m_direction==DIR_BUY)?m_executor.Limit(DIR_BUY,price,lot,"RGDv2_Grid")
                                                :m_executor.Limit(DIR_SELL,price,lot,"RGDv2_Grid");
            if(pending>0)
              {
               m_levels[i].price=price;
               m_levels[i].lot=lot;
               m_levels[i].ticket=pending;
               m_levels[i].filled=false;
               m_levels_placed++;
               m_pending_count++;
               m_last_grid_price=price;
               LogDynamic("SEED",i,price);
              }
           }

         if((warm>warm_cap) || (m_params.grid_max_pendings>0 && m_pending_count>=m_params.grid_max_pendings))
            LogDynamic("LIMIT",m_levels_placed,m_last_grid_price);

         if(m_pending_count==0)
            m_last_grid_price=anchor;
         
         if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("Dynamic grid warm=%d/%d",m_levels_placed,m_max_levels));
        }
      else
        {
         // Old static mode: place all
         m_executor.BypassNext(ArraySize(m_levels));
         
         double seed_lot=m_levels[0].lot;
         if(seed_lot<=0.0)
            return;
         ulong market_ticket=m_executor.Market(m_direction,seed_lot,"RGDv2_Seed");
         if(market_ticket>0)
           {
            m_levels[0].ticket=market_ticket;
            m_levels[0].filled=true;
           }
         
         for(int i=1;i<ArraySize(m_levels);i++)
           {
            double price=m_levels[i].price;
            double lot=m_levels[i].lot;
            if(lot<=0.0)
               continue;
            ulong pending=0;
            if(m_direction==DIR_BUY)
               pending=m_executor.Limit(DIR_BUY,price,lot,"RGDv2_Grid");
            else
               pending=m_executor.Limit(DIR_SELL,price,lot,"RGDv2_Grid");
            if(pending>0)
               m_levels[i].ticket=pending;
           }
         
         if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("Grid seeded levels=%d",ArraySize(m_levels)));
        }
     }

double         ComputeSpacingPips() const
  {
   if(m_params.grid_refill_mode==GRID_REFILL_STATIC)
      return m_initial_spacing_pips;
   return m_spacing->SpacingPips();
  }

double         NextLimitPrice(const double current_price,const double spacing_px) const
  {
   double base=m_last_limit_price;
   if(m_levels_placed<=1)
      base=current_price;
   if(m_direction==DIR_BUY)
     {
      double reference=MathMin(base,current_price);
      return reference-spacing_px;
     }
   double reference=MathMax(base,current_price);
   return reference+spacing_px;
  }

void           MaintainDynamicGrid()
  {
   if(!m_trading_allowed || !m_active)
      return;
   if(m_max_levels<=0 || m_levels_placed>=m_max_levels)
      return;
   int pending=m_pending_count;
   int threshold=m_params.grid_refill_threshold;
   if(threshold<0)
      threshold=0;
   if(m_params.grid_max_pendings>0 && pending>=m_params.grid_max_pendings)
      return;
   if(pending>threshold)
      return;
   int available=m_max_levels-m_levels_placed;
   if(available<=0)
      return;
   int batch=m_params.grid_refill_batch;
   if(batch<1)
      batch=1;
   if(batch>available)
      batch=available;
   if(m_params.grid_max_pendings>0)
     {
      int free_slots=m_params.grid_max_pendings-pending;
      if(free_slots<=0)
         return;
      if(batch>free_slots)
         batch=free_slots;
     }
   if(batch<=0)
      return;
   double price=(m_direction==DIR_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_BID):SymbolInfoDouble(m_symbol,SYMBOL_ASK);
   for(int i=0;i<batch;i++)
     {
      double spacing_pips=ComputeSpacingPips();
      double spacing_px=m_spacing->ToPrice(spacing_pips);
      if(spacing_px<=0.0)
         break;
      double target=NextLimitPrice(price,spacing_px);
      double lot=LevelLot(m_levels_placed);
      ulong ticket=PlaceLimit(target,lot,"RGDv2_Grid");
      if(ticket>0)
        {
         RecordLevel(target,lot,ticket,false);
         m_last_limit_price=target;
         pending++;
         m_pending_count=pending;
         price=target;
         if(m_log!=NULL)
            m_log.Status(Tag(),StringFormat("Refill idx=%d price=%.5f lot=%.2f",m_levels_placed-1,target,lot));
        }
      else
        {
         break;
        }
     }
   m_pending_count=pending;
  }

   void           RefreshState()
     {
      m_total_lot=0.0;
      m_avg_price=0.0;
      m_pnl_usd=0.0;

      double lot_acc=0.0;
      double weighted_price=0.0;

      int total=(int)PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         long type=PositionGetInteger(POSITION_TYPE);
         if((m_direction==DIR_BUY && type!=POSITION_TYPE_BUY) ||
            (m_direction==DIR_SELL && type!=POSITION_TYPE_SELL))
            continue;
         double vol=PositionGetDouble(POSITION_VOLUME);
         double price=PositionGetDouble(POSITION_PRICE_OPEN);
         double profit=PositionGetDouble(POSITION_PROFIT);
         lot_acc+=vol;
         weighted_price+=vol*price;
         m_pnl_usd+=profit;
        }

      if(lot_acc>0.0)
        {
         m_total_lot=lot_acc;
         m_avg_price=weighted_price/lot_acc;
        }
      else
        {
         m_total_lot=0.0;
         m_avg_price=0.0;
        }

      if(m_total_lot>0.0)
        {
         if(m_pnl_usd<m_cycle_max_dd)
            m_cycle_max_dd=m_pnl_usd;
         CalculateGroupTP();
        }
     }

   double         CalculateAtrFactor() const
     {
      if(!m_params.dts_atr_enabled || m_initial_atr<=0.0)
         return 1.0;
      double atr_current=(m_spacing!=NULL)?m_spacing.AtrPoints():0.0;
      if(atr_current<=0.0)
         return 1.0;
      double atr_ratio=atr_current/m_initial_atr;
      atr_ratio=1.0+(atr_ratio-1.0)*m_params.dts_atr_weight;
      atr_ratio=MathMax(atr_ratio,0.5);
      atr_ratio=MathMin(atr_ratio,2.0);
      return atr_ratio;
     }

   double         CalculateTimeFactor() const
     {
      if(!m_params.dts_time_decay_enabled)
         return 1.0;
      int bars_in_trade=Bars(m_symbol,PERIOD_CURRENT)-m_entry_bar;
      if(bars_in_trade<0)
         bars_in_trade=0;
      double time_factor=1.0/(1.0+bars_in_trade*m_params.dts_time_decay_rate);
      time_factor=MathMax(time_factor,m_params.dts_time_decay_floor);
      return time_factor;
     }

   double         CalculateDdFactor() const
     {
      if(!m_params.dts_dd_scaling_enabled || m_pnl_usd>=0.0)
         return 1.0;
      double dd_abs=MathAbs(m_pnl_usd);
      if(dd_abs<=m_params.dts_dd_threshold)
         return 1.0;
      double excess_dd=dd_abs-m_params.dts_dd_threshold;
      double dd_factor=1.0+(excess_dd/m_params.dts_dd_scale_factor);
      dd_factor=MathMin(dd_factor,m_params.dts_dd_max_factor);
      return dd_factor;
     }

   double         CalculateDynamicTarget() const
     {
      if(!m_params.dts_enabled)
         return m_params.target_cycle_usd;
      double base_target=m_params.target_cycle_usd;
      double atr_factor=CalculateAtrFactor();
      double time_factor=CalculateTimeFactor();
      double dd_factor=CalculateDdFactor();
      double adjusted=base_target*atr_factor*time_factor;
      if(dd_factor>1.0)
         adjusted=adjusted/dd_factor;
      double min_target=base_target*m_params.dts_min_multiplier;
      double max_target=base_target*m_params.dts_max_multiplier;
      adjusted=MathMax(adjusted,min_target);
      adjusted=MathMin(adjusted,max_target);
      if(m_log && m_params.dts_enabled)
        {
         string msg=StringFormat("[DTS] base=%.2f atr_f=%.2f time_f=%.2f dd_f=%.2f adj=%.2f",
                                base_target,atr_factor,time_factor,dd_factor,adjusted);
         m_log.Event(Tag(),msg);
        }
      return adjusted;
     }

   void           CalculateGroupTP()
     {
      double tick_value=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE);
      double tick_size=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tick_value<=0.0 || tick_size<=0.0)
        {
         m_tp_price=m_avg_price;
         return;
        }
      double usd_per_point=(tick_value/tick_size)*m_total_lot;
      double target=CalculateDynamicTarget()-m_target_reduction;
      target=MathMax(0.0,target);
      if(m_params.commission_per_lot>0.0)
         target+=m_params.commission_per_lot*m_total_lot;
      if(usd_per_point<=0.0)
        {
         m_tp_price=m_avg_price;
         return;
        }
      double delta=target/usd_per_point;
      if(m_direction==DIR_BUY)
         m_tp_price=m_avg_price+delta;
      else
         m_tp_price=m_avg_price-delta;
     }

   bool           PriceReachedTP() const
     {
      if(m_total_lot<=0.0)
         return false;
      double bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      if(m_direction==DIR_BUY)
         return (bid>=m_tp_price);
      return (ask<=m_tp_price);
     }

   void           CloseBasket(const string reason)
     {
      if(!m_active)
         return;
      m_last_realized=m_pnl_usd;
      m_last_cycle_total_lot=m_total_lot;
      if(m_executor!=NULL)
        {
         m_executor.SetMagic(m_magic);
         m_executor.CloseAllByDirection(m_direction,m_magic);
         m_executor.CancelPendingByDirection(m_direction,m_magic);
        }
      m_active=false;
      m_closed_recently=true;
      m_cycles_done++;
      m_closed_as_hedge=(m_kind==BASKET_HEDGE);
      if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("Basket closed: %s",reason));
      SyncDepthMetrics();
      m_trail_override=0.0;
     }

   void           ManageTrailing()
     {
      if(!m_params.tsl_enabled)
         return;
      if(m_kind!=BASKET_HEDGE)
         return;
      if(m_total_lot<=0.0)
         return;

      double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
         point=_Point;
      double price=(m_direction==DIR_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_BID)
                                         :SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      double move_points=(m_direction==DIR_BUY)?((price-m_avg_price)/point)
                                              :((m_avg_price-price)/point);

      if(!m_trailing_on)
        {
         if(move_points>=m_params.tsl_start_points)
           {
            m_trailing_on=true;
            m_trail_anchor=price;
            if(m_log!=NULL)
              m_log.Event(Tag(),"TSL activated");
           }
         return;
        }

      double step=m_params.tsl_step_points*point;
      if(m_trail_override>0.0 && (step<=0.0 || m_trail_override<step))
         step=m_trail_override;
      if(step<=0.0)
         return;

      bool moved=false;
      double logged_sl=0.0;
      if(m_direction==DIR_BUY)
        {
         if(price-m_trail_anchor>=step)
           {
            double new_anchor=price;
            double new_sl=new_anchor-step;
            if(ApplyTrailingStop(new_sl))
              {
               m_trail_anchor=new_anchor;
               moved=true;
               logged_sl=new_sl;
              }
           }
        }
      else
        {
         if(m_trail_anchor-price>=step)
           {
            double new_anchor=price;
            double new_sl=new_anchor+step;
            if(ApplyTrailingStop(new_sl))
              {
               m_trail_anchor=new_anchor;
               moved=true;
               logged_sl=new_sl;
              }
           }
        }

      if(moved && m_log!=NULL)
        {
         int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
         m_log.Event(Tag(),StringFormat("TSL trail stop to %s",DoubleToString(logged_sl,digits)));
        }
     }

   bool           ApplyTrailingStop(const double new_sl)
     {
      bool applied=false;
      CTrade trade;
      trade.SetExpertMagicNumber(m_magic);
      double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
         point=_Point;
      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
      double norm_sl=NormalizeDouble(new_sl,digits);
      int total=(int)PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         long type=PositionGetInteger(POSITION_TYPE);
         if((m_direction==DIR_BUY && type!=POSITION_TYPE_BUY) ||
            (m_direction==DIR_SELL && type!=POSITION_TYPE_SELL))
            continue;
         double current_sl=PositionGetDouble(POSITION_SL);
         double current_tp=PositionGetDouble(POSITION_TP);
         bool better=false;
         if(m_direction==DIR_BUY)
           better=(current_sl==0.0 || norm_sl>current_sl+point/2.0);
         else
           better=(current_sl==0.0 || norm_sl<current_sl-point/2.0);
         if(!better)
            continue;
         if(trade.PositionModify(ticket,norm_sl,current_tp))
            applied=true;
        }
      return applied;
     }

   struct SPcTicket
     {
      ulong  ticket;
      double volume;
      double entry;
      double pnl;
      double distance;
     };

  void           AdjustTarget(const double delta,const string reason)
     {
      if(delta<=0.0)
         return;
      m_target_reduction+=delta;
      if(m_target_reduction<0.0)
         m_target_reduction=0.0;
      if(m_target_reduction>m_params.target_cycle_usd)
         m_target_reduction=m_params.target_cycle_usd;
      CalculateGroupTP();
      if(m_log!=NULL && reason!="" && delta>0.0)
         m_log.Event(Tag(),StringFormat("%s %.2f => %.2f",reason,delta,EffectiveTargetUsd()));
     }

public:
   double         GetFurthestEntryPrice() const
     {
      if(m_total_lot<=0.0)
         return 0.0;
      double furthest=0.0;
      int total=(int)PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         long type=PositionGetInteger(POSITION_TYPE);
         if((m_direction==DIR_BUY && type!=POSITION_TYPE_BUY) ||
            (m_direction==DIR_SELL && type!=POSITION_TYPE_SELL))
            continue;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         if(m_direction==DIR_SELL)
            furthest=(furthest==0.0)?entry:MathMax(furthest,entry);
         else
            furthest=(furthest==0.0)?entry:MathMin(furthest,entry);
        }
      return furthest;
     }

   bool           HasProfitableTickets(double min_profit_usd,int max_tickets,double ref_price)
     {
      SPcTicket tickets[];
      int count=0;
      int total=(int)PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         long type=PositionGetInteger(POSITION_TYPE);
         if((m_direction==DIR_BUY && type!=POSITION_TYPE_BUY) ||
            (m_direction==DIR_SELL && type!=POSITION_TYPE_SELL))
            continue;
         count++;
         ArrayResize(tickets,count);
         tickets[count-1].ticket=ticket;
         tickets[count-1].volume=PositionGetDouble(POSITION_VOLUME);
         tickets[count-1].entry=PositionGetDouble(POSITION_PRICE_OPEN);
         tickets[count-1].pnl=PositionGetDouble(POSITION_PROFIT);
         tickets[count-1].distance=MathAbs(tickets[count-1].entry-ref_price);
        }
      if(count==0)
         return false;
      for(int i=0;i<count-1;i++)
         for(int j=i+1;j<count;j++)
            if(tickets[i].distance>tickets[j].distance)
              {
               SPcTicket tmp=tickets[i];
               tickets[i]=tickets[j];
               tickets[j]=tmp;
              }
      double total_pnl=0.0;
      int check_count=MathMin(max_tickets,count);
      for(int i=0;i<check_count;i++)
         total_pnl+=tickets[i].pnl;
      return(total_pnl>=min_profit_usd);
     }

   int            CloseNearestTickets(double target_volume,int max_tickets,double min_profit_usd,double ref_price)
     {
      SPcTicket tickets[];
      int count=0;
      int total=(int)PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         long type=PositionGetInteger(POSITION_TYPE);
         if((m_direction==DIR_BUY && type!=POSITION_TYPE_BUY) ||
            (m_direction==DIR_SELL && type!=POSITION_TYPE_SELL))
            continue;
         count++;
         ArrayResize(tickets,count);
         tickets[count-1].ticket=ticket;
         tickets[count-1].volume=PositionGetDouble(POSITION_VOLUME);
         tickets[count-1].entry=PositionGetDouble(POSITION_PRICE_OPEN);
         tickets[count-1].pnl=PositionGetDouble(POSITION_PROFIT);
         tickets[count-1].distance=MathAbs(tickets[count-1].entry-ref_price);
        }
      if(count==0)
         return 0;
      for(int i=0;i<count-1;i++)
         for(int j=i+1;j<count;j++)
            if(tickets[i].distance>tickets[j].distance)
              {
               SPcTicket tmp=tickets[i];
               tickets[i]=tickets[j];
               tickets[j]=tmp;
              }
      double closed_volume=0.0;
      int closed_count=0;
      CTrade trade;
      trade.SetExpertMagicNumber(m_magic);
      for(int i=0;i<count && closed_count<max_tickets;i++)
        {
         if(closed_volume>=target_volume)
            break;
         if(tickets[i].pnl<-min_profit_usd*0.5)
            continue;
         if(trade.PositionClose(tickets[i].ticket))
           {
            m_partial_realized+=tickets[i].pnl;
            closed_volume+=tickets[i].volume;
            closed_count++;
           }
        }
      return closed_count;
     }

   double         TakePartialCloseProfit()
     {
      double val=m_partial_realized;
      m_partial_realized=0.0;
      return val;
     }


   void           DeployRecovery(const double price)
     {
      if(m_params.recovery_lot<=0.0)
         return;
      if(m_executor==NULL)
         return;
      m_executor.SetMagic(m_magic);
      int pendings=1+ArraySize(m_params.recovery_steps_atr);
      if(pendings<1)
         pendings=1;
      m_executor.BypassNext(pendings);
      double rescue_lot=NormalizeVolumeValue(m_params.recovery_lot);
      if(rescue_lot<=0.0)
         return;
      m_executor.Market(m_direction,rescue_lot,"RGDv2_RescueSeed");
      double updated_last=m_last_grid_price;
      double atr_points=m_spacing->AtrPoints();
      if(atr_points<=0.0)
        {
         double fallback_pips=m_spacing->SpacingPips();
         atr_points=m_spacing->ToPrice(MathMax(m_params.min_spacing_pips,fallback_pips));
        }
      for(int i=0;i<ArraySize(m_params.recovery_steps_atr);i++)
        {
         double mult=m_params.recovery_steps_atr[i];
         if(mult<=0.0)
            continue;
         double distance=atr_points*mult;
         if(distance<=0.0)
            continue;
         double level=(m_direction==DIR_BUY)?(price-distance):(price+distance);
         ulong ticket=m_executor.Limit(m_direction,level,rescue_lot,"RGDv2_RescueGrid");
         if(ticket>0)
           {
            if(updated_last==0.0)
               updated_last=level;
            else if(m_direction==DIR_BUY && level<updated_last)
               updated_last=level;
            else if(m_direction==DIR_SELL && level>updated_last)
               updated_last=level;
           }
        }
      if(updated_last!=0.0)
         m_last_grid_price=updated_last;
      RefreshState();
      SyncDepthMetrics();
      if(m_log!=NULL)
         m_log.Event(Tag(),"Rescue layer deployed");
     }

   CGridBasket(const string symbol,
                                 const EDirection direction,
                                 const EBasketKind kind,
                                 const SParams &params,
                                 CSpacingEngine *spacing,
                                 COrderExecutor *executor,
                                 CLogger *logger,
                                 const long magic)
                       : m_symbol(symbol),
                         m_direction(direction),
                         m_kind(kind),
                         m_params(params),
                         m_spacing(spacing),
                         m_executor(executor),
                         m_log(logger),
                         m_magic(magic),
                         m_active(false),
                         m_closed_recently(false),
                         m_cycles_done(0),
                         m_closed_as_hedge(false),
                         m_total_lot(0.0),
                         m_avg_price(0.0),
                         m_pnl_usd(0.0),
                         m_tp_price(0.0),
                         m_last_grid_price(0.0),
                         m_target_reduction(0.0),
                         m_max_levels(0),
                         m_levels_placed(0),
                         m_pending_count(0),
                         m_initial_spacing_pips(0.0),
                         m_trailing_on(false),
                         m_last_realized(0.0),
                         m_trail_anchor(0.0),
                         m_partial_realized(0.0),
                         m_furthest_entry(0.0),
                         m_initial_atr(0.0),
                         m_entry_bar(0),
                         m_volume_step(0.0),
                         m_volume_min(0.0),
                         m_volume_max(0.0),
                         m_volume_digits(0),
                         m_max_levels(0),
                         m_levels_placed(0),
                         m_pending_count(0),
                         m_initial_spacing_pips(0.0),
                         m_seed_price(0.0),
                         m_last_limit_price(0.0),
                         m_trading_allowed(true),
                         m_cycle_max_dd(0.0),
                         m_cycle_partial_volume(0.0),
                         m_last_cycle_total_lot(0.0)
     {
      m_volume_step=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      m_volume_min=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
      m_volume_max=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX);
      m_volume_digits=0;
      double step=m_volume_step;
      if(step>0.0)
        {
         double tmp=step;
         while(tmp<1.0 && m_volume_digits<8)
           {
            tmp*=10.0;
            m_volume_digits++;
            if(MathAbs(tmp-MathRound(tmp))<1e-6)
               break;
           }
        }
      ArrayResize(m_levels,0);
     }

   bool           Init(const double anchor_price)
     {
      ClearLevels();
      m_active=false;
      m_closed_recently=false;
      m_cycles_done=0;
      m_closed_as_hedge=false;
      m_seed_price=anchor_price;
      m_last_limit_price=anchor_price;
      m_last_grid_price=anchor_price;
      m_initial_spacing_pips=m_spacing->SpacingPips();
      m_max_levels=MathMax(1,m_params.grid_levels);
      m_levels_placed=0;
      m_pending_count=0;
      m_trading_allowed=true;

      if(m_executor==NULL)
         return false;

      if(m_params.grid_refill_batch<1) m_params.grid_refill_batch=1;
      if(m_params.grid_refill_threshold<0) m_params.grid_refill_threshold=0;
      if(m_params.grid_warm_levels<0) m_params.grid_warm_levels=0;
      if(m_params.grid_max_pendings<0) m_params.grid_max_pendings=0;

      int warm=m_params.grid_warm_levels;
      int available_limits=MathMax(0,m_max_levels-1);
      if(warm>available_limits) warm=available_limits;
      if(m_params.grid_max_pendings>0 && warm>m_params.grid_max_pendings) warm=m_params.grid_max_pendings;

      m_executor.SetMagic(m_magic);
      m_executor.BypassNext(1+warm);

      double seed_lot=LevelLot(0);
      if(seed_lot<=0.0)
         return false;
      m_initial_spacing_pips=spacing_pips;
      BuildGrid(anchor_price,spacing_px);
      m_target_reduction=0.0;
      m_last_realized=0.0;
      m_trailing_on=false;
      m_trail_anchor=0.0;
      m_initial_atr=(m_spacing!=NULL)?m_spacing.AtrPoints():0.0;
      m_entry_bar=Bars(m_symbol,PERIOD_CURRENT);
      PlaceInitialOrders();
      m_active=true;
      RefreshState();
      if(m_log!=NULL)
        m_log.Event(Tag(),StringFormat("Grid seeded warm=%d/%d",warm,available_limits));
      return true;
     }

   void           RefillBatch()
     {
      if(!m_params.grid_dynamic_enabled)
         return;
      if(m_levels_placed>=m_max_levels)
         return;
      if(m_pending_count>m_params.grid_refill_threshold)
         return;
      if(m_params.grid_max_pendings>0 && m_pending_count>=m_params.grid_max_pendings)
         return;
      
      double spacing_px=m_spacing.ToPrice(m_initial_spacing_pips);
      double anchor_price=SymbolInfoDouble(m_symbol,(m_direction==DIR_BUY)?SYMBOL_BID:SYMBOL_ASK);
      int to_add=MathMin(m_params.grid_refill_batch,m_max_levels-m_levels_placed);
      int added=0;
      
      for(int i=0;i<to_add;i++)
        {
         int idx=m_levels_placed;
         if(idx>=m_max_levels)
            break;
         
         double base_price=(m_levels_placed==0)?anchor_price:m_last_grid_price;
         double price=base_price;
         if(m_direction==DIR_BUY)
            price-=spacing_px;
         else
            price+=spacing_px;
         
         double lot=LevelLot(idx);
         if(lot<=0.0)
            continue;
         
         ulong pending=(m_direction==DIR_BUY)?m_executor.Limit(DIR_BUY,price,lot,"RGDv2_GridRefill")
                                             :m_executor.Limit(DIR_SELL,price,lot,"RGDv2_GridRefill");
         if(pending>0)
           {
            m_levels[idx].price=price;
            m_levels[idx].lot=lot;
            m_levels[idx].ticket=pending;
            m_levels[idx].filled=false;
            m_levels_placed++;
            m_pending_count++;
            m_last_grid_price=price;
            LogDynamic("REFILL",idx,price);
            added++;

            if(m_params.grid_max_pendings>0 && m_pending_count>=m_params.grid_max_pendings)
              {
               LogDynamic("LIMIT",idx,price);
               break;
              }
           }
        }
      
      if(added>0 && m_log!=NULL)
         m_log.Event(Tag(),StringFormat("Refill +%d placed=%d/%d pending=%d",added,m_levels_placed,m_max_levels,m_pending_count));
     }

   void           Update()
     {
      if(!m_active)
         return;
      m_closed_recently=false;
      RefreshState();
      
      // Dynamic grid refill
      if(m_params.grid_dynamic_enabled)
        {
         // Update pending count by direction
         m_pending_count=0;
         int total=(int)OrdersTotal();
         for(int i=0;i<total;i++)
           {
            ulong ticket=OrderGetTicket(i);
            if(ticket==0)
               continue;
            if(!OrderSelect(ticket))
               continue;
            if(OrderGetString(ORDER_SYMBOL)!=m_symbol)
               continue;
            if(OrderGetInteger(ORDER_MAGIC)!=m_magic)
               continue;
            ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(!MatchesOrderDirection(type))
               continue;
            m_pending_count++;
           }
         RefillBatch();
        }
      
      ManageTrailing();
      if((m_pnl_usd>=EffectiveTargetUsd()) || PriceReachedTP())
        {
         CloseBasket("GroupTP");
        }
      SyncDepthMetrics();
      if(m_trading_allowed)
         MaintainDynamicGrid();

      if(m_active)
        {
         bool no_positions=(m_total_lot<=0.0);
         bool no_pending=(m_pending_count==0);
         if(no_positions && no_pending)
            m_active=false;
        }
     }

   void           ReduceTargetBy(const double profit_usd)
     {
      AdjustTarget(profit_usd,"Pull target by");
     }

   void           TightenTarget(const double delta_usd,const string reason)
     {
      AdjustTarget(delta_usd,reason);
     }

   double         EffectiveTargetUsd() const
     {
      double target=m_params.target_cycle_usd-m_target_reduction;
      if(target<0.0)
         target=0.0;
      return target;
     }

   bool           IsActive() const { return m_active; }
   bool           ClosedRecently() const { return m_closed_recently; }
   bool           ClosedAsHedge()
     {
      bool flag=m_closed_as_hedge;
      m_closed_as_hedge=false;
      return flag;
     }
   double         TakeRealizedProfit()
     {
      double value=m_last_realized;
      m_last_realized=0.0;
      return value;
     }

   int            CyclesDone() const { return m_cycles_done; }
   double         BasketPnL() const { return m_pnl_usd; }
   double         LastGridPrice() const { return m_last_grid_price; }
   double         AveragePrice() const { return m_avg_price; }
   double         TotalLot() const { return m_total_lot; }
   double         GroupTPPrice() const { return m_tp_price; }
   double         TargetReduction() const { return m_target_reduction; }
   double         TakeCycleMaxDrawdown()
     {
      double value=m_cycle_max_dd;
      m_cycle_max_dd=0.0;
      return value;
     }
   double         TakeCyclePartialVolume()
     {
      double value=m_cycle_partial_volume;
      m_cycle_partial_volume=0.0;
      return value;
     }
   double         TakeCycleTotalLot()
     {
      double value=m_last_cycle_total_lot;
      m_last_cycle_total_lot=0.0;
      return value;
     }
   void           SetKind(const EBasketKind kind) { m_kind=kind; }

   EBasketKind    Kind() const { return m_kind; }
   EDirection     Direction() const { return m_direction; }

   double         NormalizeLot(const double volume) const { return NormalizeVolumeValue(volume); }

   SBasketSummary Snapshot() const
     {
      SBasketSummary snap;
      snap.direction=m_direction;
      snap.kind=m_kind;
      snap.total_lot=m_total_lot;
      snap.avg_price=m_avg_price;
      snap.pnl_usd=m_pnl_usd;
      snap.tp_price=m_tp_price;
      snap.last_grid_price=m_last_grid_price;
      snap.trailing_active=m_trailing_on;
      return snap;
     }

   void           ResetTargetReduction()
     {
      m_target_reduction=0.0;
     }

   void           MarkInactive()
     {
      m_active=false;
     }
  };

#endif // __RGD_V2_GRID_BASKET_MQH__
