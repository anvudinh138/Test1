//+------------------------------------------------------------------+
//| Lifecycle controller orchestrating both directional baskets      |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_LIFECYCLE_CONTROLLER_MQH__
#define __RGD_V2_LIFECYCLE_CONTROLLER_MQH__

#include <Indicators/Trend.mqh>
#include "Types.mqh"
#include "Params.mqh"
#include "SpacingEngine.mqh"
#include "OrderExecutor.mqh"
#include "RescueEngine.mqh"
#include "PortfolioLedger.mqh"
#include "GridBasket.mqh"
#include "Logger.mqh"

class CLifecycleController
  {
private:
   string            m_symbol;
   SParams           m_params;
   CSpacingEngine   *m_spacing;
   COrderExecutor   *m_executor;
   CRescueEngine    *m_rescue;
   CPortfolioLedger *m_ledger;
   CLogger          *m_log;
   long              m_magic;

   CGridBasket      *m_buy;
   CGridBasket      *m_sell;
   bool              m_halted;

   int               m_pc_last_close_bar;
   bool              m_pc_guard_active;
   double            m_pc_guard_price;
   int               m_pc_guard_start_bar;

   // TRM (time-based risk management)
   SNewsWindow       m_news_windows[];
   bool              m_trm_initialized;
   bool              m_trm_in_news_window;  // State tracking to reduce log spam

   string            Tag() const { return StringFormat("[RGDv2][%s][LC]",m_symbol); }

   double           CurrentPrice(const EDirection dir) const
     {
      return (dir==DIR_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_ASK)
                           :SymbolInfoDouble(m_symbol,SYMBOL_BID);
     }

   double           NormalizeVolume(const double volume) const
     {
      if(volume<=0.0)
         return 0.0;
      double step=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      double min=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
      double max=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX);
      double result=volume;
      int digits=0;
      if(step>0.0)
        {
         double steps=MathRound(volume/step);
         result=steps*step;
         double tmp=step;
         while(tmp<1.0 && digits<8)
           {
            tmp*=10.0;
            digits++;
            if(MathAbs(tmp-MathRound(tmp))<1e-6)
               break;
           }
        }
      if(result<=0.0)
         result=(min>0.0)?min:volume;
      if(min>0.0 && result<min)
         result=min;
      if(max>0.0 && result>max)
         result=max;
      if(digits>0)
         result=NormalizeDouble(result,digits);
      return result;
     }

   CGridBasket*      Basket(const EDirection dir)
     {
      return (dir==DIR_BUY)?m_buy:m_sell;
     }

   void              UpdateRoles(CGridBasket *loser,CGridBasket *winner)
     {
      if(m_buy!=NULL)
         m_buy.SetKind(BASKET_PRIMARY);
      if(m_sell!=NULL)
         m_sell.SetKind(BASKET_PRIMARY);
      if(winner!=NULL)
         winner.SetKind(BASKET_HEDGE);
     }

   void              EnsureRescueReset()
     {
      bool active_buy=(m_buy!=NULL) && m_buy.IsActive();
      bool active_sell=(m_sell!=NULL) && m_sell.IsActive();
      if(!active_buy && !active_sell && m_rescue!=NULL)
         m_rescue.ResetCycleCounter();
     }

   bool              TryReseedBasket(CGridBasket *basket,const EDirection dir,const bool allow_new_orders)
     {
      if(!allow_new_orders)
         return false;
      // TRM: Block reseeding during news
      if(m_params.trm_enabled && m_params.trm_pause_orders && IsNewsTime())
         return false;
      if(basket==NULL)
         return false;
      if(basket.IsActive())
         return false;
      double seed_lot=NormalizeVolume(m_params.lot_base);
      if(seed_lot<=0.0)
         return false;
      if(m_ledger!=NULL && !m_ledger.ExposureAllowed(seed_lot,m_magic,m_symbol))
         return false;
      double price=CurrentPrice(dir);
      if(price<=0.0)
         return false;
      basket.ResetTargetReduction();
      if(basket.Init(price))
        {
         if(m_log!=NULL)
           m_log.Event(Tag(),StringFormat("Reseed %s grid", (dir==DIR_BUY)?"BUY":"SELL"));
         return true;
        }
      return false;
     }

   void              FlattenAll(const string reason)
     {
      if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("Flatten requested: %s",reason));
      if(m_executor!=NULL)
        {
         m_executor.SetMagic(m_magic);
         if(m_buy!=NULL)
           {
            m_executor.CloseAllByDirection(DIR_BUY,m_magic);
            m_executor.CancelPendingByDirection(DIR_BUY,m_magic);
           }
         if(m_sell!=NULL)
           {
            m_executor.CloseAllByDirection(DIR_SELL,m_magic);
            m_executor.CancelPendingByDirection(DIR_SELL,m_magic);
           }
        }
      if(m_buy!=NULL)
         m_buy.MarkInactive();
      if(m_sell!=NULL)
         m_sell.MarkInactive();
      m_halted=true;
      EnsureRescueReset();
     }

   int               CurrentBarIndex() const
     {
      return Bars(m_symbol,PERIOD_CURRENT);
     }

   int               BarsSince(int bar_index) const
     {
      return CurrentBarIndex()-bar_index;
     }

   bool              GuardExpired(double price,double atr_points)
     {
      if(!m_pc_guard_active)
         return true;
      if(BarsSince(m_pc_guard_start_bar)>=m_params.pc_guard_bars)
         return true;
      double distance=MathAbs(price-m_pc_guard_price);
      if(distance>=m_params.pc_guard_exit_atr*atr_points)
         return true;
      return false;
     }

   void              ActivatePcGuard(double price)
     {
      m_pc_guard_active=true;
      m_pc_guard_price=price;
      m_pc_guard_start_bar=CurrentBarIndex();
     }

   void              CancelPendingAround(double price,double offset_px)
     {
      if(offset_px<=0.0)
         return;
      double lower=price-offset_px;
      double upper=price+offset_px;
      int total=(int)OrdersTotal();
      CTrade trade;
      trade.SetExpertMagicNumber(m_magic);
      for(int i=total-1;i>=0;i--)
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
         double order_price=OrderGetDouble(ORDER_PRICE_OPEN);
         if(order_price>=lower && order_price<=upper)
            trade.OrderDelete(ticket);
        }
     }

   bool              CanPartialClose(CGridBasket *loser,double price,double atr_points)
     {
      if(!m_params.pc_enabled)
         return false;
      if(loser==NULL || !loser.IsActive())
         return false;
      if(loser.BasketPnL()>=0.0)
         return false;
      if(m_pc_guard_active && !GuardExpired(price,atr_points))
         return false;
      double total_lot=loser.TotalLot();
      if(total_lot<=m_params.pc_min_lots_remain)
         return false;
      if(BarsSince(m_pc_last_close_bar)<m_params.pc_cooldown_bars)
         return false;
      double furthest=loser.GetFurthestEntryPrice();
      if(furthest==0.0)
         return false;
      double retest_dist=MathAbs(furthest-price);
      if(atr_points<=0.0)
         atr_points=m_spacing.ToPrice(m_spacing.SpacingPips());
      if(retest_dist<m_params.pc_retest_atr*atr_points)
         return false;
      if(!loser.HasProfitableTickets(m_params.pc_min_profit_usd,
                                     m_params.pc_max_tickets,
                                     price))
         return false;
      return true;
     }

   void              ExecutePartialClose(CGridBasket *loser,double price,double spacing_px)
     {
      if(loser==NULL)
         return;
      double total_lot=loser.TotalLot();
      double target_volume=total_lot*m_params.pc_close_fraction;
      if(total_lot-target_volume<m_params.pc_min_lots_remain)
         target_volume=total_lot-m_params.pc_min_lots_remain;
      if(target_volume<=0.0)
         return;
      int closed=loser.CloseNearestTickets(target_volume,
                                          m_params.pc_max_tickets,
                                          m_params.pc_min_profit_usd,
                                          price);
      if(closed>0)
        {
         double realized=loser.TakePartialCloseProfit();
         if(realized>0.0)
            loser.ReduceTargetBy(realized);
         double guard_offset=spacing_px*m_params.pc_pending_guard_mult;
         CancelPendingAround(price,guard_offset);
         ActivatePcGuard(price);
         m_pc_last_close_bar=CurrentBarIndex();
         if(m_log!=NULL)
           {
            int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
            m_log.Event(Tag(),StringFormat("[PartialClose] tickets=%d profit=%.2f price=%s",
                                          closed,realized,DoubleToString(price,digits)));
           }
        }
     }

   void              ParseNewsWindows()
     {
      if(m_trm_initialized)
         return;
      if(!m_params.trm_enabled)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TRM] Disabled");
         m_trm_initialized=true;
         return;
        }
      string csv=m_params.trm_news_windows;
      if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("[TRM] Parsing windows: '%s'",csv));
      if(StringLen(csv)==0)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TRM] No windows configured");
         ArrayResize(m_news_windows,0);
         m_trm_initialized=true;
         return;
        }
      string parts[];
      int count=StringSplit(csv,',',parts);
      if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("[TRM] Split result: %d parts",count));
      if(count<=0)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TRM] ERROR: Failed to split CSV");
         ArrayResize(m_news_windows,0);
         m_trm_initialized=true;
         return;
        }
      ArrayResize(m_news_windows,count);
      int valid=0;
      for(int i=0;i<count;i++)
        {
         string trimmed=parts[i];
         StringTrimLeft(trimmed);
         StringTrimRight(trimmed);
         if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[TRM] Processing part[%d]: '%s'",i,trimmed));
         string time_parts[];
         if(StringSplit(trimmed,'-',time_parts)==2)
           {
            string start_parts[];
            string end_parts[];
            if(StringSplit(time_parts[0],':',start_parts)==2 &&
               StringSplit(time_parts[1],':',end_parts)==2)
              {
               SNewsWindow window;
               window.start_hour=(int)StringToInteger(start_parts[0]);
               window.start_minute=(int)StringToInteger(start_parts[1]);
               window.end_hour=(int)StringToInteger(end_parts[0]);
               window.end_minute=(int)StringToInteger(end_parts[1]);
               m_news_windows[valid]=window;
               if(m_log!=NULL)
                  m_log.Event(Tag(),StringFormat("[TRM] Window[%d]: %02d:%02d-%02d:%02d",
                                                valid,window.start_hour,window.start_minute,
                                                window.end_hour,window.end_minute));
               valid++;
              }
            else if(m_log!=NULL)
               m_log.Event(Tag(),StringFormat("[TRM] ERROR: Invalid time format in '%s'",trimmed));
           }
         else if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[TRM] ERROR: Missing '-' separator in '%s'",trimmed));
        }
      ArrayResize(m_news_windows,valid);
      m_trm_initialized=true;
      if(m_log!=NULL)
         m_log.Event(Tag(),StringFormat("[TRM] Initialization complete: %d windows active",valid));
     }

   bool              IsNewsTime()
     {
      if(!m_params.trm_enabled)
         return false;
      if(!m_trm_initialized)
         ParseNewsWindows();
      if(ArraySize(m_news_windows)==0)
         return false;
      MqlDateTime dt;
      TimeToStruct(TimeGMT(),dt);
      int current_minutes=dt.hour*60+dt.min;
      for(int i=0;i<ArraySize(m_news_windows);i++)
        {
         int start_minutes=m_news_windows[i].start_hour*60+m_news_windows[i].start_minute;
         int end_minutes=m_news_windows[i].end_hour*60+m_news_windows[i].end_minute;
         if(current_minutes>=start_minutes && current_minutes<=end_minutes)
           {
            // Log only on ENTRY to news window (state transition)
            if(!m_trm_in_news_window && m_log!=NULL)
               m_log.Event(Tag(),StringFormat("[TRM] News window ENTERED: %02d:%02d-%02d:%02d (UTC)",
                                            m_news_windows[i].start_hour,m_news_windows[i].start_minute,
                                            m_news_windows[i].end_hour,m_news_windows[i].end_minute));
            m_trm_in_news_window=true;
            return true;
           }
        }
      // Log only on EXIT from news window (state transition)
      if(m_trm_in_news_window && m_log!=NULL)
         m_log.Event(Tag(),"[TRM] News window EXITED - trading resumed");
      m_trm_in_news_window=false;
      return false;
     }

   void              HandleNewsWindow()
     {
      if(!IsNewsTime())
         return;
      if(m_params.trm_close_on_news)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TRM] Closing all positions (close_on_news=true)");
         if(m_buy!=NULL && m_buy.IsActive())
            m_buy.CloseBasket("TRM close_on_news");
         if(m_sell!=NULL && m_sell.IsActive())
            m_sell.CloseBasket("TRM close_on_news");
         m_halted=true;
         return;
        }
      if(m_params.trm_tighten_sl && m_params.ssl_enabled)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TRM] Tightening SL during news");
        }
     }

public:
                     CLifecycleController(const string symbol,
                                          const SParams &params,
                                          CSpacingEngine *spacing,
                                          COrderExecutor *executor,
                                          CRescueEngine *rescue,
                                          CPortfolioLedger *ledger,
                                          CLogger *log,
                                          const long magic)
                       : m_symbol(symbol),
                         m_params(params),
                         m_spacing(spacing),
                         m_executor(executor),
                         m_rescue(rescue),
                         m_ledger(ledger),
                         m_log(log),
                         m_magic(magic),
                         m_buy(NULL),
                         m_sell(NULL),
                         m_halted(false),
                         m_pc_last_close_bar(0),
                         m_pc_guard_active(false),
                         m_pc_guard_price(0.0),
                         m_pc_guard_start_bar(0),
                         m_trm_initialized(false),
                         m_trm_in_news_window(false)
     {
      ArrayResize(m_news_windows,0);
     }

   bool              Init()
     {
      double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
      if(ask<=0 || bid<=0)
        return false;

      double seed_lot=NormalizeVolume(m_params.lot_base);
      if(m_ledger!=NULL && !m_ledger.ExposureAllowed(seed_lot,m_magic,m_symbol))
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"Exposure cap reached before bootstrap");
         return false;
        }

      m_buy=new CGridBasket(m_symbol,DIR_BUY,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic);
      if(!m_buy.Init(ask))
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"Failed to seed BUY basket");
         delete m_buy;
         m_buy=NULL;
         return false;
        }

      if(m_ledger!=NULL && !m_ledger.ExposureAllowed(seed_lot,m_magic,m_symbol))
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"Exposure cap hit before SELL basket");
         if(m_executor!=NULL)
           {
            m_executor.SetMagic(m_magic);
            m_executor.CloseAllByDirection(DIR_BUY,m_magic);
            m_executor.CancelPendingByDirection(DIR_BUY,m_magic);
           }
         delete m_buy;
         m_buy=NULL;
         return false;
        }

      m_sell=new CGridBasket(m_symbol,DIR_SELL,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic);
      if(!m_sell.Init(bid))
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"Failed to seed SELL basket");
         if(m_executor!=NULL)
           {
            m_executor.SetMagic(m_magic);
            m_executor.CloseAllByDirection(DIR_BUY,m_magic);
            m_executor.CancelPendingByDirection(DIR_BUY,m_magic);
           }
         delete m_buy;
         m_buy=NULL;
         delete m_sell;
         m_sell=NULL;
         return false;
        }

      if(m_log!=NULL)
         m_log.Event(Tag(),"Lifecycle bootstrapped");
      return true;
     }

   void              Update()
     {
      if(m_halted)
         return;

      // TRM: Handle news windows first
      HandleNewsWindow();
      if(m_halted)
         return;

      datetime now=TimeCurrent();

      if(m_ledger!=NULL)
         m_ledger.UpdateEquitySnapshot();

      if(m_ledger!=NULL && m_ledger.SessionRiskBreached())
        {
         FlattenAll("Session SL");
         return;
        }

      if(m_buy!=NULL)
         m_buy.Update();
      if(m_sell!=NULL)
         m_sell.Update();

      double spacing_pips=m_spacing.SpacingPips();
      double spacing_px=m_spacing.ToPrice(spacing_pips);
      double atr_points=m_spacing.AtrPoints();
      if(atr_points<=0.0)
         atr_points=spacing_px;

      CGridBasket *loser=NULL;
      CGridBasket *winner=NULL;
      double worst=0.0;

      if(m_buy!=NULL && m_buy.IsActive())
        {
         double pnl=m_buy.BasketPnL();
         if(pnl<0 && pnl<worst)
           {
            worst=pnl;
            loser=m_buy;
           }
        }
      if(m_sell!=NULL && m_sell.IsActive())
        {
         double pnl=m_sell.BasketPnL();
         if(pnl<0 && pnl<worst)
           {
            worst=pnl;
            loser=m_sell;
           }
      }
      if(loser!=NULL)
        {
         winner=(loser==m_buy)?m_sell:m_buy;
         if(winner!=NULL && !winner.IsActive())
            winner=NULL;
        }

      UpdateRoles(loser,winner);

      if(loser!=NULL && winner!=NULL && m_rescue!=NULL)
        {
         // TRM: Block rescue during news
         bool news_active=(m_params.trm_enabled && m_params.trm_pause_orders && IsNewsTime());
         if(!news_active)
           {
            double price_winner=CurrentPrice(winner.Direction());
            double dd=-MathMin(0.0,loser.BasketPnL());
            double rescue_lot=winner.NormalizeLot(m_params.recovery_lot);
            if(rescue_lot>0.0 && m_rescue.CooldownOk() && m_rescue.CyclesAvailable())
              {
               if(m_rescue.ShouldRescue(loser.Direction(),loser.LastGridPrice(),spacing_px,price_winner,dd))
                 {
                  bool exposure_ok=(m_ledger==NULL) || m_ledger.ExposureAllowed(rescue_lot,m_magic,m_symbol);
                  if(exposure_ok)
                    {
                     winner.DeployRecovery(price_winner);
                     m_rescue.RecordRescue();
                     if(m_log!=NULL)
                        m_log.Event(Tag(),"Rescue deployed");
                    }
                  else
                    {
                     m_rescue.LogSkip("Exposure cap blocks rescue");
                    }
                 }
              }
           }
        }

      if(loser!=NULL && m_params.pc_enabled)
        {
         double price_loser=CurrentPrice(loser.Direction());
         if(CanPartialClose(loser,price_loser,atr_points))
           {
            ExecutePartialClose(loser,price_loser,spacing_px);
            loser.Update();
           }
        }

      if(m_buy!=NULL && m_buy.ClosedRecently())
        {
         double realized=m_buy.TakeRealizedProfit();
         if(realized>0 && m_sell!=NULL)
            m_sell.ReduceTargetBy(realized);
         TryReseedBasket(m_buy,DIR_BUY,true);
        }
      if(m_sell!=NULL && m_sell.ClosedRecently())
        {
         double realized=m_sell.TakeRealizedProfit();
         if(realized>0 && m_buy!=NULL)
            m_buy.ReduceTargetBy(realized);
         TryReseedBasket(m_sell,DIR_SELL,true);
        }

      EnsureRescueReset();
     }

   void              Shutdown()
     {
      if(m_buy!=NULL)
        {
         delete m_buy;
         m_buy=NULL;
        }
      if(m_sell!=NULL)
        {
         delete m_sell;
         m_sell=NULL;
        }
     }
  };

#endif // __RGD_V2_LIFECYCLE_CONTROLLER_MQH__