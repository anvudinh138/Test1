//+------------------------------------------------------------------+
//| Lifecycle controller orchestrating both directional baskets      |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_LIFECYCLE_CONTROLLER_MQH__
#define __RGD_V2_LIFECYCLE_CONTROLLER_MQH__

#include <Indicators/Trend.mqh>
#include "Types.mqh"
#include "Params.mqh"
#include "NewsCalendar.mqh"
#include "SpacingEngine.mqh"
#include "OrderExecutor.mqh"
#include "RescueEngine.mqh"
#include "PortfolioLedger.mqh"
#include "GridBasket.mqh"
#include "Logger.mqh"

// Embed historical news CSV as resource
#resource "\\Files\\historical_news_2025.csv" as string HistoricalNewsCSV

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
   int               m_job_id;        // Multi-Job v3.0: Job identifier

   CGridBasket      *m_buy;
   CGridBasket      *m_sell;
   bool              m_halted;

   // TRM (time-based risk management)
   CNewsCalendar    *m_news_calendar;       // ForexFactory API integration
   SNewsWindow       m_news_windows[];      // Static fallback windows
   bool              m_trm_initialized;
   bool              m_trm_in_news_window;  // State tracking to reduce log spam
   bool              m_trm_already_closed;  // Flag to prevent close loop during news

   // ADC (anti-drawdown cushion)
   bool              m_adc_cushion_active;  // State tracking for cushion mode

   string            Tag() const
     {
      // Multi-Job v3.0: Include job_id in tag
      if(m_job_id > 0)
         return StringFormat("[RGDv2][%s][J%d][LC]",m_symbol,m_job_id);
      else
         return StringFormat("[RGDv2][%s][LC]",m_symbol);  // Legacy format
     }

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
      // v3: REMOVED - Both baskets stay PRIMARY, rescue orders identified by comment only
      // if(winner!=NULL)
      //    winner.SetKind(BASKET_HEDGE);
     }

   void              EnsureRescueReset()
     {
      bool active_buy=(m_buy!=NULL) && m_buy.IsActive();
      bool active_sell=(m_sell!=NULL) && m_sell.IsActive();
      if(!active_buy && !active_sell && m_rescue!=NULL)
         m_rescue.ResetCycleCounter();
     }

   void              CheckOrphanedBasket(CGridBasket *basket,CGridBasket *opposite)
     {
      if(basket==NULL || !basket.IsActive())
         return;

      // Throttle: check max once per 5 seconds per basket
      static datetime last_check_buy=0;
      static datetime last_check_sell=0;
      datetime now=TimeCurrent();

      bool is_buy=(basket.Direction()==DIR_BUY);

      // Check throttle for the correct basket
      if(is_buy && (now-last_check_buy<5))
         return;
      if(!is_buy && (now-last_check_sell<5))
         return;

      // Orphaned basket criteria:
      // 1. Has pending orders
      bool has_pendings=(basket.PendingCount()>0);

      // 2. But NO open positions
      bool no_positions=(basket.TotalLot()<=0.0);

      // 3. Opposite basket HAS positions (means this basket should be rescuing but can't)
      bool opposite_has_positions=(opposite!=NULL && opposite.TotalLot()>0.0);

      if(has_pendings && no_positions && opposite_has_positions)
        {
         // ORPHANED BASKET DETECTED
         if(m_log!=NULL)
           {
            string dir=is_buy?"BUY":"SELL";
            string opp_dir=(opposite.Direction()==DIR_BUY)?"BUY":"SELL";
            m_log.Event(Tag(),StringFormat("[ORPHAN] %s basket detected: %d pendings, 0 positions, %s has %.2f lots - RECOVERING",
                                         dir,basket.PendingCount(),opp_dir,opposite.TotalLot()));
           }

         // Recovery: Cancel all pendings and mark inactive
         basket.CancelAllPendings();
         basket.MarkInactive();

         if(m_log!=NULL)
           {
            string dir=is_buy?"BUY":"SELL";
            m_log.Event(Tag(),StringFormat("[ORPHAN] %s basket recovered: pendings cancelled, marked inactive, will reseed next cycle",dir));
           }

         // Update last check time after recovery
         if(is_buy)
            last_check_buy=now;
         else
            last_check_sell=now;
        }
      else
        {
         // Normal state or edge case - update timer
         if(is_buy)
            last_check_buy=now;
         else
            last_check_sell=now;
        }
     }

   bool              HasExistingPositions() const
     {
      int total=PositionsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=m_magic)
            continue;
         return true;
        }
      return false;
     }

   bool              TryReseedBasket(CGridBasket *basket,const EDirection dir,const bool allow_new_orders)
     {
      if(!allow_new_orders)
         return false;
      // TRM: Block reseeding during news
      if(m_params.trm_enabled && m_params.trm_pause_orders && IsNewsTime())
         return false;
      // ADC: Block reseeding during equity drawdown cushion (use cached state)
      // EXCEPTION: Allow reseed if opposite basket is orphaned (only 1 basket active)
      CGridBasket *opposite_basket = (dir==DIR_BUY) ? m_sell : m_buy;
      bool opposite_active = (opposite_basket != NULL && opposite_basket.IsActive());
      bool should_block_adc = (m_params.adc_enabled && m_params.adc_pause_new_grids && m_adc_cushion_active && opposite_active);

      if(should_block_adc)
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[ADC] BLOCKED reseed %s (equity DD %.2f%% >= %.2f%%)",
                                         dir==DIR_BUY?"BUY":"SELL",
                                         m_ledger.GetEquityDrawdownPercent(),
                                         m_params.adc_equity_dd_threshold));
         return false;
        }

      // ADC: Allow reseed if opposite basket is orphaned (anti-deadlock)
      if(m_params.adc_enabled && m_adc_cushion_active && !opposite_active && m_log!=NULL)
        {
         m_log.Event(Tag(),StringFormat("[ADC] ALLOW reseed %s (opposite orphaned, DD %.2f%%)",
                                      dir==DIR_BUY?"BUY":"SELL",
                                      m_ledger.GetEquityDrawdownPercent()));
        }
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

      // TRY: ForexFactory API (if enabled)
      if(m_params.trm_use_api_news && m_news_calendar!=NULL)
        {
         string active_event;
         bool is_news=m_news_calendar.IsNewsTime(active_event);

         // Log state transitions
         if(is_news && !m_trm_in_news_window && m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[TRM-API] News window ENTERED: %s",active_event));
         else if(!is_news && m_trm_in_news_window && m_log!=NULL)
            m_log.Event(Tag(),"[TRM-API] News window EXITED - trading resumed");

         m_trm_in_news_window=is_news;
         return is_news;
        }

      // FALLBACK: Static time windows
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
               m_log.Event(Tag(),StringFormat("[TRM-Static] News window ENTERED: %02d:%02d-%02d:%02d (UTC)",
                                            m_news_windows[i].start_hour,m_news_windows[i].start_minute,
                                            m_news_windows[i].end_hour,m_news_windows[i].end_minute));
            m_trm_in_news_window=true;
            return true;
           }
        }
      // Log only on EXIT from news window (state transition)
      if(m_trm_in_news_window && m_log!=NULL)
         m_log.Event(Tag(),"[TRM-Static] News window EXITED - trading resumed");
      m_trm_in_news_window=false;
      m_trm_already_closed=false;  // Reset close flag when exiting news
      return false;
     }

   void              HandleNewsWindow()
     {
      bool in_news_window = IsNewsTime();

      // Resume trading when news window exits
      if(!in_news_window && m_halted)
        {
         m_halted = false;
         m_trm_already_closed = false;  // Reset flag when exiting news window
         if(m_log != NULL)
            m_log.Event(Tag(), "[TRM] News window ended - EA resumed");

         // Reseed baskets if no positions remain (like fresh start)
         bool buy_has_positions = (m_buy != NULL && m_buy.TotalLot() > 0);
         bool sell_has_positions = (m_sell != NULL && m_sell.TotalLot() > 0);

         if(!buy_has_positions && !sell_has_positions)
           {
            // Both baskets empty → reseed like OnInit()
            if(m_log != NULL)
               m_log.Event(Tag(), "[TRM] No positions after news → Reseeding baskets");

            double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

            if(m_buy != NULL)
              {
               m_buy.SetActive(true);
               bool buy_ok = m_buy.Init(ask);
               if(!buy_ok && m_log != NULL)
                  m_log.Event(Tag(), "[TRM] WARNING: Failed to reseed BUY basket (ATR may not be ready)");
              }

            if(m_sell != NULL)
              {
               m_sell.SetActive(true);
               bool sell_ok = m_sell.Init(bid);
               if(!sell_ok && m_log != NULL)
                  m_log.Event(Tag(), "[TRM] WARNING: Failed to reseed SELL basket (ATR may not be ready)");
              }
           }

         return;
        }

      if(!in_news_window)
         return;

      // === Partial Close (Simple Strategy) ===
      if(m_params.trm_partial_close_enabled)
        {
         TrmPartialClose();
         // Note: Don't halt EA, let remaining positions run
         return;
        }

      // === Legacy: Close on news ===
      if(m_params.trm_close_on_news && !m_trm_already_closed)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), "[TRM] Closing all positions (legacy close_on_news=true)");

         if(m_buy != NULL && m_buy.IsActive())
            m_buy.CloseBasket("TRM close_on_news");
         if(m_sell != NULL && m_sell.IsActive())
            m_sell.CloseBasket("TRM close_on_news");

         // Set flag to prevent re-closing during same news window
         m_trm_already_closed = true;

         // Reseed baskets immediately after close (don't wait for news window to end)
         // This prevents EA from stopping during long news windows
         if(m_log != NULL)
            m_log.Event(Tag(), "[TRM] Reseeding baskets immediately after close_on_news");

         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

         if(m_buy != NULL)
           {
            m_buy.SetActive(true);
            bool buy_ok = m_buy.Init(ask);
            if(!buy_ok && m_log != NULL)
               m_log.Event(Tag(), "[TRM] WARNING: Failed to reseed BUY basket");
           }

         if(m_sell != NULL)
           {
            m_sell.SetActive(true);
            bool sell_ok = m_sell.Init(bid);
            if(!sell_ok && m_log != NULL)
               m_log.Event(Tag(), "[TRM] WARNING: Failed to reseed SELL basket");
           }

         // DON'T set m_halted = true (baskets reseeded, continue trading)
         return;
        }

      // === Tighten SL ===
      if(m_params.trm_tighten_sl && m_params.ssl_enabled)
        {
         if(m_log != NULL)
            m_log.Event(Tag(), "[TRM] Tightening SL during news window");
        }
     }

   void              TrmPartialClose()
     {
      // Per-order logic: Close big winners/losers, keep small ones with SL protection
      // Logic:
      //   PnL > $3 → Close (lock profit)
      //   0 < PnL <= $3 → Keep + SL breakeven
      //   -$3 <= PnL < 0 → Keep + SL -$6
      //   PnL < -$3 → Close (cut loss)

      if(m_executor == NULL)
         return;

      int total = PositionsTotal();
      int closed_count = 0;
      int kept_with_sl = 0;

      for(int i = total - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         double pnl = PositionGetDouble(POSITION_PROFIT);
         double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double lot = PositionGetDouble(POSITION_VOLUME);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         // Decision tree
         if(pnl > m_params.trm_close_threshold)
           {
            // Close big winner
            m_executor.ClosePosition(ticket, "TRM-Partial big profit");
            closed_count++;
            if(m_log != NULL)
               m_log.Event(Tag(), StringFormat("[TRM-Partial] Closed #%I64u (profit $%.2f > $%.2f)",
                                              ticket, pnl, m_params.trm_close_threshold));
           }
         else if(pnl < -m_params.trm_close_threshold)
           {
            // Close big loser
            m_executor.ClosePosition(ticket, "TRM-Partial big loss");
            closed_count++;
            if(m_log != NULL)
               m_log.Event(Tag(), StringFormat("[TRM-Partial] Closed #%I64u (loss $%.2f < -$%.2f)",
                                              ticket, pnl, m_params.trm_close_threshold));
           }
         else
           {
            // Keep position, set protective SL
            double sl_price = 0.0;

            if(pnl >= 0.0)
              {
               // Small profit → SL at breakeven
               sl_price = entry_price;
              }
            else
              {
               // Small loss → SL at -$6
               // Calculate SL price from USD distance
               double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
               double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);

               if(tick_value > 0 && lot > 0)
                 {
                  double point_value = (tick_value / tick_size) * point;
                  double sl_distance_points = m_params.trm_keep_sl_distance / (point_value * lot);

                  if(pos_type == POSITION_TYPE_BUY)
                     sl_price = entry_price - sl_distance_points * point;
                  else
                     sl_price = entry_price + sl_distance_points * point;
                 }
               else
                 {
                  sl_price = entry_price;  // Fallback to breakeven
                 }
              }

            // Modify SL
            if(sl_price > 0)
              {
               m_executor.ModifyPosition(ticket, sl_price, 0.0);
               kept_with_sl++;
               if(m_log != NULL)
                  m_log.Event(Tag(), StringFormat("[TRM-Partial] Keep #%I64u (PnL=$%.2f) SL=%.5f",
                                                 ticket, pnl, sl_price));
              }
           }
        }

      if(m_log != NULL)
         m_log.Event(Tag(), StringFormat("[TRM-Partial] Summary: Closed=%d, Kept+SL=%d",
                                        closed_count, kept_with_sl));
     }

public:
                     CLifecycleController(const string symbol,
                                          const SParams &params,
                                          CSpacingEngine *spacing,
                                          COrderExecutor *executor,
                                          CRescueEngine *rescue,
                                          CPortfolioLedger *ledger,
                                          CLogger *log,
                                          const long magic,
                                          const int job_id = 0)  // Multi-Job v3.0: Job ID (0 = legacy)
                       : m_symbol(symbol),
                         m_params(params),
                         m_spacing(spacing),
                         m_executor(executor),
                         m_rescue(rescue),
                         m_ledger(ledger),
                         m_log(log),
                         m_magic(magic),
                         m_job_id(job_id),
                         m_buy(NULL),
                         m_sell(NULL),
                         m_halted(false),
                         m_news_calendar(NULL),
                         m_trm_initialized(false),
                         m_trm_in_news_window(false),
                         m_trm_already_closed(false),
                         m_adc_cushion_active(false)
     {
      ArrayResize(m_news_windows,0);

      // Initialize ForexFactory API if enabled
      if(m_params.trm_enabled && m_params.trm_use_api_news)
        {
         m_news_calendar=new CNewsCalendar(true,
                                         m_params.trm_impact_filter,
                                         m_params.trm_buffer_minutes,
                                         m_log);

         // Load historical news from embedded resource (for backtesting)
         m_news_calendar.InitHistoricalFromResource(HistoricalNewsCSV);
        }
     }

   bool              Init()
     {
      double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
      if(ask<=0 || bid<=0)
        return false;

      // Check if we should preserve existing positions
      bool has_positions=m_params.preserve_on_tf_switch && HasExistingPositions();

      if(has_positions)
        {
         // Reconstruct mode: baskets will discover their positions
         if(m_log!=NULL)
            m_log.Event(Tag(),"[TF-Preserve] Existing positions detected, reconstructing baskets");

         m_buy=new CGridBasket(m_symbol,DIR_BUY,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic,m_job_id);
         m_sell=new CGridBasket(m_symbol,DIR_SELL,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic,m_job_id);

         // Mark baskets active without seeding
         m_buy.SetActive(true);
         m_sell.SetActive(true);

         // Force immediate refresh to discover positions
         m_buy.Update();
         m_sell.Update();

         if(m_log!=NULL)
           {
            m_log.Event(Tag(),StringFormat("[TF-Preserve] BUY reconstructed: avg=%.5f lot=%.2f pnl=%.2f",
                                          m_buy.AvgPrice(),m_buy.TotalLot(),m_buy.BasketPnL()));
            m_log.Event(Tag(),StringFormat("[TF-Preserve] SELL reconstructed: avg=%.5f lot=%.2f pnl=%.2f",
                                          m_sell.AvgPrice(),m_sell.TotalLot(),m_sell.BasketPnL()));
           }

         return true;
        }

      // Fresh start: seed new baskets
      double seed_lot=NormalizeVolume(m_params.lot_base);
      if(m_ledger!=NULL && !m_ledger.ExposureAllowed(seed_lot,m_magic,m_symbol))
        {
         if(m_log!=NULL)
            m_log.Event(Tag(),"Exposure cap reached before bootstrap");
         return false;
        }

      m_buy=new CGridBasket(m_symbol,DIR_BUY,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic,m_job_id);
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

      m_sell=new CGridBasket(m_symbol,DIR_SELL,BASKET_PRIMARY,m_params,m_spacing,m_executor,m_log,m_magic,m_job_id);
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

      // Margin Kill Switch: Emergency close all if margin level too low
      if(m_params.margin_kill_enabled)
        {
         double margin = AccountInfoDouble(ACCOUNT_MARGIN);
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double margin_level = (margin > 0) ? (equity / margin) * 100.0 : 999.0;

         if(margin_level < m_params.margin_kill_threshold)
           {
            if(m_log != NULL)
               m_log.Event(Tag(), StringFormat("[MARGIN-KILL] EMERGENCY: Margin level %.2f%% < %.2f%% threshold → Closing all positions",
                                              margin_level, m_params.margin_kill_threshold));
            FlattenAll("Margin Kill");
            return;
           }
        }

      // ADC: Check and log cushion state transitions (with hysteresis)
      if(m_params.adc_enabled && m_ledger!=NULL)
        {
         bool is_cushion=m_ledger.IsDrawdownCushionActive(m_params.adc_equity_dd_threshold, m_adc_cushion_active);
         double dd_pct=m_ledger.GetEquityDrawdownPercent();
         if(is_cushion && !m_adc_cushion_active && m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[ADC] CUSHION ACTIVATED: Equity DD %.2f%% >= %.2f%% - pausing risky operations",
                                         dd_pct,m_params.adc_equity_dd_threshold));
         if(!is_cushion && m_adc_cushion_active && m_log!=NULL)
            m_log.Event(Tag(),StringFormat("[ADC] CUSHION DEACTIVATED: Equity DD %.2f%% < %.2f%% - resuming normal operations",
                                         dd_pct,m_params.adc_equity_dd_threshold-1.0));
         m_adc_cushion_active=is_cushion;
        }

      if(m_ledger!=NULL && m_ledger.SessionRiskBreached())
        {
         FlattenAll("Session SL");
         return;
        }

      // Check equity DD for grid pause (BEFORE basket updates)
      // Pause grid expansion when DD reaches threshold (similar to ADC but for grid only)
      bool dd_grid_pause = false;
      if(m_params.dd_pause_grid_threshold > 0 && m_ledger != NULL)
        {
         double dd_pct = m_ledger.GetEquityDrawdownPercent();
         dd_grid_pause = (dd_pct >= m_params.dd_pause_grid_threshold);

         if(dd_grid_pause && m_log != NULL)
           {
            static datetime last_pause_log = 0;
            datetime now = TimeCurrent();
            if(now - last_pause_log >= 60)  // Log once per minute
              {
               m_log.Event(Tag(), StringFormat("[DD-PAUSE] Grid expansion paused (DD %.2f%% >= %.2f%%)",
                                            dd_pct, m_params.dd_pause_grid_threshold));
               last_pause_log = now;
              }
           }
        }

      if(m_buy!=NULL)
         m_buy.Update(dd_grid_pause);  // Pass DD pause flag
      if(m_sell!=NULL)
         m_sell.Update(dd_grid_pause);

      // Check for orphaned baskets (pendings only, no positions)
      CheckOrphanedBasket(m_buy,m_sell);
      CheckOrphanedBasket(m_sell,m_buy);

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
         // ADC: Block rescue during equity drawdown cushion (use cached state)
         bool cushion_active = (m_params.adc_enabled && m_params.adc_pause_rescue && m_adc_cushion_active);
         if(cushion_active && m_log!=NULL)
           {
            static datetime last_log_time=0;
            datetime now=TimeCurrent();
            if(now-last_log_time>=60)  // Log once per minute
              {
               m_log.Event(Tag(),StringFormat("[ADC] BLOCKED rescue (equity DD %.2f%% >= %.2f%%)",
                                            m_ledger.GetEquityDrawdownPercent(),
                                            m_params.adc_equity_dd_threshold));
               last_log_time=now;
              }
           }
         if(!news_active && !cushion_active)
           {
            // v3: Delta-based continuous rebalancing (FIX: absolute volume balance to prevent flip-flop)
            double buy_lot = m_buy.TotalLot();
            double sell_lot = m_sell.TotalLot();
            double delta = MathAbs(buy_lot - sell_lot);

            // Determine lighter basket (deploy rescue on lighter side for balance)
            CGridBasket *lighter = (buy_lot < sell_lot) ? m_buy : m_sell;
            CGridBasket *heavier = (buy_lot < sell_lot) ? m_sell : m_buy;
            double price_lighter = CurrentPrice(lighter.Direction());

            // Check delta threshold: Only rescue if imbalance >= trigger
            if(delta >= m_params.min_delta_trigger)
              {
               // v3: Deploy EXACT delta (no multiplier), cap at max
               double rescue_lot = delta;

               // Apply max cap
               if(m_params.rescue_max_lot > 0 && rescue_lot > m_params.rescue_max_lot)
                 {
                  if(m_log!=NULL)
                     m_log.Event(Tag(),StringFormat("[RESCUE-DELTA] Heavy=%.2f Light=%.2f Delta=%.2f → Deploy %.2f lot on %s (CAPPED from %.2f)",
                                                     heavier.TotalLot(), lighter.TotalLot(), delta,
                                                     m_params.rescue_max_lot, lighter.Direction()==DIR_BUY?"BUY":"SELL", rescue_lot));
                  rescue_lot = m_params.rescue_max_lot;
                 }
               else
                 {
                  if(m_log!=NULL)
                     m_log.Event(Tag(),StringFormat("[RESCUE-DELTA] Heavy=%.2f Light=%.2f Delta=%.2f → Deploy %.2f lot on %s (EXACT)",
                                                     heavier.TotalLot(), lighter.TotalLot(), delta,
                                                     rescue_lot, lighter.Direction()==DIR_BUY?"BUY":"SELL"));
                 }

               rescue_lot = lighter.NormalizeLot(rescue_lot);

               // Deploy rescue (delta trigger + cooldown anti-spam)
               if(rescue_lot>0.0 && m_rescue.CooldownOk())
                 {
                  bool exposure_ok=(m_ledger==NULL) || m_ledger.ExposureAllowed(rescue_lot,m_magic,m_symbol);
                  if(exposure_ok)
                    {
                     lighter.DeployRecovery(price_lighter,rescue_lot);
                     m_rescue.RecordRescue();
                     if(m_log!=NULL)
                        m_log.Event(Tag(),StringFormat("Rescue deployed: %.2f lot on %s (cooldown: %d bars)",
                                                     rescue_lot, lighter.Direction()==DIR_BUY?"BUY":"SELL",
                                                     m_params.rescue_cooldown_bars));
                    }
                  else
                    {
                     if(m_log!=NULL)
                        m_log.Event(Tag(),StringFormat("Rescue blocked: Exposure cap (%.2f lot exceeds limit)",rescue_lot));
                    }
                 }
              else if(rescue_lot>0.0 && !m_rescue.CooldownOk())
                 {
                  // Rate limit: Log once per minute to prevent spam
                  static datetime last_cooldown_log=0;
                  datetime now=TimeCurrent();
                  if(m_log!=NULL && (now-last_cooldown_log>=60))
                    {
                     m_log.Event(Tag(),StringFormat("[RESCUE-COOLDOWN] Delta=%.2f ready but cooldown active (%d bars)",delta,m_params.rescue_cooldown_bars));
                     last_cooldown_log=now;
                    }
                 }
              }
            else
              {
               // Balanced: delta too small, skip rescue
               // Rate limit: Log once per minute to prevent spam
               static datetime last_balanced_log=0;
               datetime now=TimeCurrent();
               if(m_log!=NULL && (now-last_balanced_log>=60))
                 {
                  m_log.Event(Tag(),StringFormat("[RESCUE-BALANCED] BUY=%.2f SELL=%.2f Delta=%.2f < %.2f (skip, balanced)",
                                                  buy_lot, sell_lot, delta, m_params.min_delta_trigger));
                  last_balanced_log=now;
                 }
              }
           }
        }


      if(m_buy!=NULL && m_buy.ClosedRecently())
        {
         double realized=m_buy.TakeRealizedProfit();
         if(realized>0 && m_sell!=NULL && m_sell.IsActive())
           {
            m_sell.ReduceTargetBy(realized);
            if(m_log!=NULL && m_params.mcd_enabled)
               m_log.Event(Tag(),StringFormat("[MCD] BUY profit $%.2f → SELL target reduced",realized));
           }
         TryReseedBasket(m_buy,DIR_BUY,true);
        }
      if(m_sell!=NULL && m_sell.ClosedRecently())
        {
         double realized=m_sell.TakeRealizedProfit();
         if(realized>0 && m_buy!=NULL && m_buy.IsActive())
           {
            m_buy.ReduceTargetBy(realized);
            if(m_log!=NULL && m_params.mcd_enabled)
               m_log.Event(Tag(),StringFormat("[MCD] SELL profit $%.2f → BUY target reduced",realized));
           }
         TryReseedBasket(m_sell,DIR_SELL,true);
        }

      EnsureRescueReset();
     }

   // Multi-Job v3.0: P&L tracking for JobManager
   double GetUnrealizedPnL() const
     {
      double pnl = 0.0;
      if(m_buy != NULL)
         pnl += m_buy.BasketPnL();
      if(m_sell != NULL)
         pnl += m_sell.BasketPnL();
      return pnl;
     }

   double GetRealizedPnL() const
     {
      // Note: Realized PnL is transferred and consumed by opposite basket
      // This method returns cumulative cycles profit
      // For accurate tracking, would need to add m_total_realized member
      // For now, return 0 (TODO: implement if needed)
      return 0.0;
     }

   double GetTotalPnL() const
     {
      return GetUnrealizedPnL() + GetRealizedPnL();
     }

   bool IsTSLActive() const
     {
      bool tsl_active = false;
      if(m_buy != NULL && m_buy.IsTSLActive())
         tsl_active = true;
      if(m_sell != NULL && m_sell.IsTSLActive())
         tsl_active = true;
      return tsl_active;
     }

   bool IsGridFull() const
     {
      bool grid_full = false;
      if(m_buy != NULL && m_buy.IsGridFull())
         grid_full = true;
      if(m_sell != NULL && m_sell.IsGridFull())
         grid_full = true;
      return grid_full;
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
      if(m_news_calendar!=NULL)
        {
         delete m_news_calendar;
         m_news_calendar=NULL;
        }
     }
  };

#endif // __RGD_V2_LIFECYCLE_CONTROLLER_MQH__