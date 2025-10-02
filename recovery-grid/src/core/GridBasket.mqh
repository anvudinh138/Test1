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

   double         m_partial_realized;
   double         m_furthest_entry;

   double         m_initial_atr;
   int            m_entry_bar;

   double         m_volume_step;
   double         m_volume_min;
   double         m_volume_max;
   int            m_volume_digits;

   // SSL state
   bool           m_ssl_be_moved;           // breakeven already triggered
   double         m_ssl_current_trail_sl;   // current trailing SL level

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

   double         CalculateDynamicLotScale() const
     {
      if(!m_params.dls_enabled)
         return m_params.lot_scale;

      double base_scale=m_params.lot_scale;

      // === Factor 1: Volatility Adaptation ===
      double atr_current=(m_spacing!=NULL)?m_spacing.AtrPoints():0.0;
      double atr_ratio=(m_initial_atr>0.0)?(atr_current/m_initial_atr):1.0;

      // Inverse: high ATR → lower multiplier
      double vol_factor=1.0/MathMax(atr_ratio,0.5);
      vol_factor=MathPow(vol_factor,m_params.dls_vol_weight);

      // === Factor 2: DD Adaptation ===
      double dd_pct=0.0;
      // Note: m_ledger is in LifecycleController, not accessible here
      // Use basket's own PnL as proxy
      double basket_dd=MathAbs(MathMin(m_pnl_usd,0.0));
      dd_pct=basket_dd*0.1;  // Rough approximation

      double dd_factor=1.0-(dd_pct/100.0)*0.7;
      dd_factor=MathMax(dd_factor,0.3);
      dd_factor=MathPow(dd_factor,m_params.dls_dd_weight);

      // === Combine ===
      double dynamic_scale=base_scale*vol_factor*dd_factor;

      // === Bounds ===
      dynamic_scale=MathMax(dynamic_scale,m_params.dls_min_scale);
      dynamic_scale=MathMin(dynamic_scale,m_params.dls_max_scale);

      // === Logging ===
      if(m_log!=NULL && m_params.dls_enabled)
        {
         static datetime last_log=0;
         datetime now=TimeCurrent();
         if(now-last_log>=300)  // Log every 5 minutes
           {
            m_log.Event(Tag(),StringFormat("[DLS] base=%.2f atr_r=%.2f vol_f=%.2f dd=%.1f dd_f=%.2f final=%.2f",
                                          base_scale,atr_ratio,vol_factor,dd_pct,dd_factor,dynamic_scale));
            last_log=now;
           }
        }

      return dynamic_scale;
     }

   double         LevelLot(const int idx) const
     {
      double result=m_params.lot_base;

      if(m_params.dls_enabled)
        {
         // Dynamic scaling
         double dynamic_scale=CalculateDynamicLotScale();
         for(int i=1;i<=idx;i++)
            result*=dynamic_scale;
        }
      else
        {
         // Fixed scaling (original)
         for(int i=1;i<=idx;i++)
            result*=m_params.lot_scale;
        }

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

   void           AppendLevel(const double price,const double lot)
     {
      int idx=ArraySize(m_levels);
      ArrayResize(m_levels,idx+1);
      m_levels[idx].price=price;
      m_levels[idx].lot=NormalizeVolumeValue(lot);
      m_levels[idx].ticket=0;
      m_levels[idx].filled=false;
     }

   void           BuildGrid(const double anchor_price,const double spacing_px)
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
         CalculateGroupTP();
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

   void           ManageSmartStopLoss()
     {
      if(!m_params.ssl_enabled)
         return;
      if(m_total_lot<=0.0)
         return;

      double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
         point=_Point;
      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);

      // 1. Check if we should move to breakeven
      if(!m_ssl_be_moved && m_pnl_usd>=m_params.ssl_breakeven_threshold)
        {
         if(MoveAllStopsToBreakeven())
           {
            m_ssl_be_moved=true;
            if(m_log!=NULL)
               m_log.Event(Tag(),StringFormat("[SSL] Breakeven triggered at PnL=%.2f USD, SL moved to avg=%."+IntegerToString(digits)+"f",
                                            m_pnl_usd,m_avg_price));
           }
         return;
        }

      // 2. Trail by average if in profit and enabled
      if(m_params.ssl_trail_by_average && m_pnl_usd>0.0)
        {
         double offset=m_params.ssl_trail_offset_points*point;
         double new_sl=0.0;
         if(m_direction==DIR_BUY)
            new_sl=m_avg_price+offset;
         else
            new_sl=m_avg_price-offset;

         new_sl=NormalizeDouble(new_sl,digits);

         // Only update if better
         if(IsBetterSL(new_sl,m_ssl_current_trail_sl))
           {
            if(ApplySmartStopLoss(new_sl))
              {
               m_ssl_current_trail_sl=new_sl;
               if(m_log!=NULL)
                  m_log.Event(Tag(),StringFormat("[SSL] Trail SL to %."+IntegerToString(digits)+"f (avg=%."+IntegerToString(digits)+"f offset=%d pts)",
                                               new_sl,m_avg_price,m_params.ssl_trail_offset_points));
              }
           }
        }
     }

   bool           IsBetterSL(const double new_sl,const double current_sl) const
     {
      if(current_sl==0.0)
         return true;
      if(m_direction==DIR_BUY)
         return (new_sl>current_sl);
      return (new_sl<current_sl);
     }

   bool           MoveAllStopsToBreakeven()
     {
      if(m_avg_price<=0.0)
         return false;
      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
      double be_price=NormalizeDouble(m_avg_price,digits);
      return ApplySmartStopLoss(be_price);
     }

   bool           ApplySmartStopLoss(const double sl_price)
     {
      if(sl_price<=0.0)
         return false;

      CTrade trade;
      trade.SetExpertMagicNumber(m_magic);
      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
      double norm_sl=NormalizeDouble(sl_price,digits);

      // Check broker min stop level if enabled
      if(m_params.ssl_respect_min_stop)
        {
         long stops_level=SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL);
         double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
         if(point<=0.0)
            point=_Point;
         double min_distance=stops_level*point;
         double current_price=(m_direction==DIR_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_BID)
                                                    :SymbolInfoDouble(m_symbol,SYMBOL_ASK);
         double distance=MathAbs(current_price-norm_sl);
         if(distance<min_distance)
           {
            if(m_log!=NULL)
               m_log.Event(Tag(),StringFormat("[SSL] SL %."+IntegerToString(digits)+"f too close (min=%d points), adjusting",
                                            norm_sl,(int)stops_level));
            if(m_direction==DIR_BUY)
               norm_sl=current_price-min_distance;
            else
               norm_sl=current_price+min_distance;
            norm_sl=NormalizeDouble(norm_sl,digits);
           }
        }

      bool applied=false;
      int modified_count=0;
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

         // Only modify if new SL is better
         if(!IsBetterSL(norm_sl,current_sl))
            continue;

         if(trade.PositionModify(ticket,norm_sl,current_tp))
           {
            applied=true;
            modified_count++;
           }
         else
           {
            if(m_log!=NULL)
               m_log.Event(Tag(),StringFormat("[SSL] Failed to modify ticket=%I64u err=%d",ticket,GetLastError()));
           }
        }

      if(applied && m_log!=NULL)
         m_log.Event(Tag(),StringFormat("[SSL] Applied SL=%."+IntegerToString(digits)+"f to %d positions",
                                      norm_sl,modified_count));

      return applied;
     }

   void           PlaceInitialStopLoss()
     {
      if(!m_params.ssl_enabled)
         return;
      if(m_params.ssl_sl_multiplier<=0.0)
         return;
      if(m_total_lot<=0.0)
         return;

      double spacing_px=m_spacing.ToPrice(m_initial_spacing_pips);
      if(spacing_px<=0.0)
         return;

      double sl_distance=spacing_px*m_params.ssl_sl_multiplier;
      double sl_price=0.0;

      if(m_direction==DIR_BUY)
         sl_price=m_avg_price-sl_distance;
      else
         sl_price=m_avg_price+sl_distance;

      int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
      sl_price=NormalizeDouble(sl_price,digits);

      if(ApplySmartStopLoss(sl_price))
        {
         m_ssl_current_trail_sl=sl_price;
         if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[SSL] Initial SL placed at %."+IntegerToString(digits)+"f (spacing=%.1f × mult=%.1f)",
                                         sl_price,m_initial_spacing_pips,m_params.ssl_sl_multiplier));
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
   void           CloseBasket(const string reason)
      {
         if(!m_active)
            return;
         m_last_realized=m_pnl_usd;
         if(m_executor!=NULL)
         {
            m_executor.SetMagic(m_magic);
            m_executor.CloseAllByDirection(m_direction,m_magic);
            m_executor.CancelPendingByDirection(m_direction,m_magic);
         }
         m_active=false;
         m_closed_recently=true;
         m_cycles_done++;
         if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("Basket closed: %s",reason));
      }


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
      int pendings=1+ArraySize(m_params.recovery_steps);
      if(pendings<1)
         pendings=1;
      m_executor.BypassNext(pendings);
      double rescue_lot=NormalizeVolumeValue(m_params.recovery_lot);
      if(rescue_lot<=0.0)
         return;
      m_executor.Market(m_direction,rescue_lot,"RGDv2_RescueSeed");
      double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
         point=_Point;
      double updated_last=m_last_grid_price;
      if(m_direction==DIR_BUY)
        {
         for(int i=0;i<ArraySize(m_params.recovery_steps);i++)
           {
            double level=price-m_params.recovery_steps[i]*point;
            ulong ticket=m_executor.Limit(DIR_BUY,level,rescue_lot,"RGDv2_RescueGrid");
            if(ticket>0 && (updated_last==0.0 || level<updated_last))
               updated_last=level;
           }
        }
      else
        {
         for(int i=0;i<ArraySize(m_params.recovery_steps);i++)
           {
            double level=price+m_params.recovery_steps[i]*point;
            ulong ticket=m_executor.Limit(DIR_SELL,level,rescue_lot,"RGDv2_RescueGrid");
            if(ticket>0 && (updated_last==0.0 || level>updated_last))
               updated_last=level;
           }
        }
      if(updated_last!=0.0)
         m_last_grid_price=updated_last;
      RefreshState();
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
                         m_ssl_be_moved(false),
                         m_ssl_current_trail_sl(0.0),
                         m_initial_atr(0.0),
                         m_entry_bar(0),
                         m_volume_step(0.0),
                         m_volume_min(0.0),
                         m_volume_max(0.0),
                         m_volume_digits(0)
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
      if(m_spacing==NULL)
         return false;
      double spacing_pips=m_spacing.SpacingPips();
      double spacing_px=m_spacing.ToPrice(spacing_pips);
      if(spacing_px<=0.0)
         return false;
      m_initial_spacing_pips=spacing_pips;
      BuildGrid(anchor_price,spacing_px);
      m_target_reduction=0.0;
      m_last_realized=0.0;
      m_trailing_on=false;
      m_trail_anchor=0.0;
      m_initial_atr=(m_spacing!=NULL)?m_spacing.AtrPoints():0.0;
      m_entry_bar=Bars(m_symbol,PERIOD_CURRENT);
      m_ssl_be_moved=false;
      m_ssl_current_trail_sl=0.0;
      PlaceInitialOrders();
      m_active=true;
      m_closed_recently=false;
      RefreshState();
      PlaceInitialStopLoss();
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
      ManageSmartStopLoss();
      if((m_pnl_usd>=EffectiveTargetUsd()) || PriceReachedTP())
        {
         CloseBasket("GroupTP");
        }
      if(m_active)
        {
         bool no_positions=(m_total_lot<=0.0);
         bool no_pending=true;
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
            no_pending=false;
            break;
           }
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
   void           SetActive(bool active) { m_active=active; }
   bool           ClosedRecently() const { return m_closed_recently; }
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
   double         AvgPrice() const { return m_avg_price; }
   double         TotalLot() const { return m_total_lot; }
   double         GroupTPPrice() const { return m_tp_price; }
   void           SetKind(const EBasketKind kind) { m_kind=kind; }
   int            PendingCount() const { return m_pending_count; }

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

   void           CancelAllPendings()
     {
      if(m_executor==NULL)
         return;
      m_executor.SetMagic(m_magic);
      m_executor.CancelPendingByDirection(m_direction,m_magic);
      m_pending_count=0;
      if(m_log!=NULL)
         m_log.Event(Tag(),"All pending orders cancelled");
     }
  };

#endif // __RGD_V2_GRID_BASKET_MQH__