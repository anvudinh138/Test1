//+------------------------------------------------------------------+
//| PTG_AdaptiveFilters.mqh                                          |
//| Adaptive Spread, Session filter, Dynamic ATR Gate, Cooldowns     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

class PTGAdaptiveFilters
{
public:
   // ==== Inputs ====
   bool   UseSessionFilter;         // disable trading in illiquid windows
   int    DenyStartHour1, DenyEndHour1;   // e.g. 1 -> 7 (broker time)
   int    DenyStartHour2, DenyEndHour2;   // optional second window

   bool   UseAdaptiveSpread;
   int    SpreadWindowMin;          // rolling window length (minutes)
   double SpreadQuantile;           // 0.70..0.95 recommended
   double HardSpreadMaxPts;         // 0 = disabled (only adaptive)

   bool   UseATRGate;
   ENUM_TIMEFRAMES ATR_TF;
   int    ATR_Period;
   double ATR_MinAsPctOfMedian;     // e.g. 0.70 -> require ATR >= 70% median
   double ATR_HardMinPts;           // 0 = disabled

   bool   UseCooldown;
   int    CooldownAfterWideSpreadSec;
   int    CooldownAfterLossSec;

   // ==== Runtime ====
   string LastBlockReason;

private:
   int       m_atrHandle;
   datetime  m_lastWideSpreadTime;
   datetime  m_lastLossTime;

   // simple ring buffer for spreads (points)
   static const int BUFMAX = 24*60; // up to 24h
   double   m_spreadBuf[BUFMAX];
   int      m_bufCount, m_bufIdx;

   // rolling median ATR (points) over many sessions
   double   m_atrMedianPts;

public:
   PTGAdaptiveFilters(void)
   {
      UseSessionFilter = true;
      DenyStartHour1=1;  DenyEndHour1=7;  // theo log: 01:51→~07:10 bị chặn rất nhiều
      DenyStartHour2=22; DenyEndHour2=23; // ví dụ: rollover; set 22–23 nếu cần

      UseAdaptiveSpread = true;
      SpreadWindowMin = 60;
      SpreadQuantile  = 0.80;
      HardSpreadMaxPts= 0; // chỉ dùng adaptive theo mặc định

      UseATRGate      = true;
      ATR_TF          = PERIOD_M5;
      ATR_Period      = 14;
      ATR_MinAsPctOfMedian = 0.70;
      ATR_HardMinPts  = 0;

      UseCooldown = true;
      CooldownAfterWideSpreadSec = 120;
      CooldownAfterLossSec       = 900;

      m_atrHandle = INVALID_HANDLE;
      m_lastWideSpreadTime = 0;
      m_lastLossTime       = 0;
      ArrayInitialize(m_spreadBuf, 0.0);
      m_bufCount = 0; m_bufIdx = 0;
      m_atrMedianPts = 0.0;
      LastBlockReason = "";
   }

   bool Init()
   {
      m_atrHandle = iATR(_Symbol, ATR_TF, ATR_Period);
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("ATR handle failed");
         return(false);
      }
      // pre-seed ATR median from history
      double atrBuf[];
      int copied = CopyBuffer(m_atrHandle, 0, 0, 1000, atrBuf);
      if(copied>0)
      {
         // convert price ATR to points
         double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         for(int i=0;i<copied;i++) atrBuf[i] = atrBuf[i]/pt;
         m_atrMedianPts = CalcMedian(atrBuf, MathMin(copied, 600));
      }
      return(true);
   }

   void OnDeinit() { if(m_atrHandle!=INVALID_HANDLE) IndicatorRelease(m_atrHandle); }

   // call each tick
   void TickUpdate()
   {
      CollectSpread();
      UpdateATRMedians();
   }

   // report loss to set cooldown
   void NotifyLoss()
   {
      if(UseCooldown) m_lastLossTime = TimeCurrent();
   }

   bool CanTrade()
   {
      LastBlockReason = "";
      if(UseSessionFilter && !SessionOK())
      { LastBlockReason = "SessionBlock"; return(false); }

      if(UseCooldown)
      {
         if((m_lastWideSpreadTime>0) && (TimeCurrent()-m_lastWideSpreadTime < CooldownAfterWideSpreadSec))
         { LastBlockReason = "CooldownWideSpread"; return(false); }
         if((m_lastLossTime>0) && (TimeCurrent()-m_lastLossTime < CooldownAfterLossSec))
         { LastBlockReason = "CooldownAfterLoss"; return(false); }
      }

      if(UseAdaptiveSpread || HardSpreadMaxPts>0)
      {
         double allowed = AllowedSpreadPts();
         double cur     = CurrentSpreadPts();
         if(cur > allowed)
         {
            LastBlockReason = StringFormat("Spread %.1f > %.1f pts", cur, allowed);
            if(UseCooldown) m_lastWideSpreadTime = TimeCurrent();
            return(false);
         }
      }

      if(UseATRGate)
      {
         double atrPts = CurrentATRPts();
         double minPts = ATRMinRequiredPts();
         if(atrPts < minPts)
         { LastBlockReason = StringFormat("ATR %.1f < %.1f pts", atrPts, minPts); return(false); }
      }

      return(true);
   }

   // ===== helpers =====
   bool SessionOK()
   {
      int h = TimeHour(TimeCurrent());
      if(InWindow(h, DenyStartHour1, DenyEndHour1)) return(false);
      if(InWindow(h, DenyStartHour2, DenyEndHour2)) return(false);
      return(true);
   }

   bool InWindow(int hour, int startH, int endH)
   {
      if(startH==endH) return(false);
      if(startH<endH)  return(hour>=startH && hour<endH);
      // overnight window
      return(hour>=startH || hour<endH);
   }

   void CollectSpread()
   {
      double cur = CurrentSpreadPts();
      m_spreadBuf[m_bufIdx] = cur;
      m_bufIdx = (m_bufIdx+1)%BUFMAX;
      if(m_bufCount<BUFMAX) m_bufCount++;
   }

   double CurrentSpreadPts()
   {
      long spread_points = 0;
      if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread_points))
         return(0.0);
      return((double)spread_points); // already in points
   }

   // quantile of last SpreadWindowMin items
   double AllowedSpreadPts()
   {
      double hard = (HardSpreadMaxPts>0 ? HardSpreadMaxPts : DBL_MAX);

      if(!UseAdaptiveSpread) return(hard);

      int need = MathMin(SpreadWindowMin, m_bufCount);
      if(need<=5) return(hard); // not enough data
      double tmp[];
      ArrayResize(tmp, need);
      // copy last 'need' values
      int idx = (m_bufIdx - need + BUFMAX) % BUFMAX;
      for(int i=0;i<need;i++){ tmp[i] = m_spreadBuf[(idx+i)%BUFMAX]; }
      double qv = Quantile(tmp, need, SpreadQuantile);
      return(MathMin(qv, hard));
   }

   // ATR in points (not price)
   double CurrentATRPts()
   {
      double v[];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, v)!=1) return(0.0);
      double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(pt<=0) pt=1.0;
      return(v[0]/pt);
   }

   // dynamic min ATR required (points)
   double ATRMinRequiredPts()
   {
      double dyn = 0.0;
      if(m_atrMedianPts>0.0) dyn = m_atrMedianPts * ATR_MinAsPctOfMedian;
      double hard = (ATR_HardMinPts>0 ? ATR_HardMinPts : 0.0);
      return(MathMax(dyn, hard));
   }

   void UpdateATRMedians()
   {
      // update slowly to avoid noise: take 1 sample every call
      double cur = CurrentATRPts();
      if(cur<=0) return;
      // exponential median approximation
      if(m_atrMedianPts<=0.0) m_atrMedianPts = cur;
      else m_atrMedianPts = 0.98*m_atrMedianPts + 0.02*cur;
   }

   // --------- small stats helpers ----------
   double CalcMedian(const double &arr[], int n)
   {
      if(n<=0) return(0.0);
      double tmp[];
      ArrayResize(tmp, n);
      for(int i=0;i<n;i++) tmp[i]=arr[i];
      ArraySort(tmp, WHOLE_ARRAY, 0, MODE_ASCEND);
      if(n%2) return(tmp[n/2]);
      return(0.5*(tmp[n/2-1]+tmp[n/2]));
   }

   double Quantile(const double &arr[], int n, double q)
   {
      if(n<=0) return(0.0);
      double tmp[];
      ArrayResize(tmp, n);
      for(int i=0;i<n;i++) tmp[i]=arr[i];
      ArraySort(tmp, WHOLE_ARRAY, 0, MODE_ASCEND);
      double pos = (n-1)*MathMax(0.0, MathMin(1.0, q));
      int lo = (int)MathFloor(pos), hi = (int)MathCeil(pos);
      if(lo==hi) return(tmp[lo]);
      double frac = pos - lo;
      return(tmp[lo]*(1.0-frac) + tmp[hi]*frac);
   }
};
