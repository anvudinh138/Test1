//+------------------------------------------------------------------+
//| PTG_TacticalExits.mqh                                            |
//| Breakeven + ATR trailing + loss streak pause                     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

class PTGExitConfig
{
public:
   double ATR_SLmult;      // e.g. 1.8
   double ATR_TPmult;      // e.g. 2.2  (tăng RR)
   double BreakEvenRR;     // move to BE at >= this R
   double TrailStepATR;    // step trailing in ATR units
   int    Magic;
   ENUM_TIMEFRAMES ATR_TF;
   int    ATR_Period;
   int    PauseAfterLosses;   // pause when consec losses >= N
   int    PauseMinutes;

   PTGExitConfig()
   {
      ATR_SLmult=1.8; ATR_TPmult=2.2;
      BreakEvenRR=1.0; TrailStepATR=0.8;
      Magic=202509; ATR_TF=PERIOD_M5; ATR_Period=14;
      PauseAfterLosses=3; PauseMinutes=60;
   }
};

class PTGTacticalExits
{
private:
   CTrade m_trade;
   int    m_atrHandle;
   double m_point;
   int    m_digits;
   int    m_consecLoss;
   datetime m_pauseUntil;

public:
   PTGExitConfig cfg;

   PTGTacticalExits(){ m_atrHandle=INVALID_HANDLE; m_point=0; m_digits=0; m_consecLoss=0; m_pauseUntil=0; }

   bool Init()
   {
      m_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      m_digits= (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      m_atrHandle = iATR(_Symbol, cfg.ATR_TF, cfg.ATR_Period);
      return(m_atrHandle!=INVALID_HANDLE);
   }

   void OnDeinit(){ if(m_atrHandle!=INVALID_HANDLE) IndicatorRelease(m_atrHandle); }

   // compute SL/TP (price) from ATR multiples
   bool ComputeStops(bool isBuy, double &sl, double &tp)
   {
      double atrPts = CurrentATRPts();
      if(atrPts<=0) return(false);
      double atrPrice = atrPts * m_point;

      double price = (isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
      double slPrice = (isBuy ? price - cfg.ATR_SLmult*atrPrice : price + cfg.ATR_SLmult*atrPrice);
      double tpPrice = (isBuy ? price + cfg.ATR_TPmult*atrPrice : price - cfg.ATR_TPmult*atrPrice);
      sl = NormalizeDouble(slPrice, m_digits);
      tp = NormalizeDouble(tpPrice, m_digits);
      return(true);
   }

   // manage trailing + breakeven on every tick
   void ManageOpenPositions()
   {
      double atrPts = CurrentATRPts();
      if(atrPts<=0) return;
      double step = cfg.TrailStepATR * atrPts * m_point;

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         string sym; ulong ticket; long type; double price_open, sl, tp;
         if(!PositionGet(i)) continue;
         sym  = PositionGetString(POSITION_SYMBOL);
         if(sym!=_Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC)!=cfg.Magic) continue;

         type = PositionGetInteger(POSITION_TYPE);
         price_open = PositionGetDouble(POSITION_PRICE_OPEN);
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
         double price = (type==POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
         double profitPts = MathAbs((price - price_open)/m_point);
         double riskPts   = MathAbs((price_open - sl)/m_point);

         // Breakeven
         if(riskPts>0 && profitPts >= cfg.BreakEvenRR * riskPts)
         {
            double be = (type==POSITION_TYPE_BUY? price_open + 1*m_point : price_open - 1*m_point);
            if( (type==POSITION_TYPE_BUY && (sl<be)) || (type==POSITION_TYPE_SELL && (sl>be)) )
            {
               m_trade.PositionModify(_Symbol, NormalizeDouble(be, m_digits), tp);
            }
         }

         // ATR trailing step
         double trailSL = (type==POSITION_TYPE_BUY ? price - step : price + step);
         if( (type==POSITION_TYPE_BUY && trailSL>sl) || (type==POSITION_TYPE_SELL && trailSL<sl) )
         {
            m_trade.PositionModify(_Symbol, NormalizeDouble(trailSL, m_digits), tp);
         }
      }
   }

   // call inside OnTradeTransaction to track losses
   void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
   {
      if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
      {
         if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC)!=cfg.Magic) return;
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(entry==DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            if(profit<0)
            {
               m_consecLoss++;
               if(m_consecLoss>=cfg.PauseAfterLosses)
               {
                  m_pauseUntil = TimeCurrent() + cfg.PauseMinutes*60;
                  m_consecLoss = 0;
               }
            }
            else if(profit>0) m_consecLoss=0;
         }
      }
   }

   bool IsPaused() const { return(TimeCurrent() < m_pauseUntil); }

private:
   double CurrentATRPts()
   {
      double v[]; if(CopyBuffer(m_atrHandle, 0, 0, 1, v)!=1) return(0.0);
      return(v[0]/m_point);
   }
};
