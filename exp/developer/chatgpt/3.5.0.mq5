//+------------------------------------------------------------------+
//|                 PTG BALANCED v3.5.0 (M1 Push–Test–Go)            |
//|  - Softer PUSH 0.60/0.80 ATR                                      |
//|  - Dynamic Wick (OR rule) & TEST [-20..130]% + strong-wick override|
//|  - Pending invalidation with buffer & dwell                        |
//|  - M5 bias override if sweep + strong wick                         |
//|  - Safe pending (stops-level & tick-size)                          |
//+------------------------------------------------------------------+
#property strict
#property version   "3.50"
#property description "PTG v3.5.0 – more entries (safer), less premature cancels, better winrate tilt"

#include <Trade/Trade.mqh>

//========================== INPUTS ==================================
input group "=== General ==="
input long      InpMagic                = 350001;
input double    InpFixedLots            = 0.10;
input double    InpRiskPercent          = 0.0;
input bool      InpAllowShorts          = true;
input bool      InpAllowLongs           = true;

input group "=== PTG Pattern ==="
input int       InpLookback             = 10;        // bars to scan
input int       InpPushBars             = 1;         // 1–2
input double    InpPushAvgATRmult       = 0.60;      // AVG ≥ x*ATR
input double    InpPushMaxATRmult       = 0.80;      // OR MAX ≥ y*ATR
input double    InpTestRetrMinPct       = -20.0;     // widen
input double    InpTestRetrMaxPct       = 130.0;     // widen
input double    InpWickFracBase         = 0.35;      // rule A: frac>=0.35 & pips>=min(12,0.25*ATR)
input double    InpWickFracAlt          = 0.18;      // rule B: frac>=0.18 & pips>=max(12,0.35*ATR)
input double    InpWickMinPipsCap       = 12.0;
input bool      InpRequireSweep         = true;
input bool      InpSweepSoftFallback    = true;      // allow strong momentum without sweep
input double    InpStrongWickATR        = 0.35;      // strong wick pips >= 0.35*ATR
input double    InpEntryBufferPips      = 3.0;       // base buffer (pips)

input group "=== Round Number Filter (XAU) ==="
input bool      InpRoundNumberAvoid     = true;
input double    InpRoundMajorGridPips   = 100.0;
input double    InpRoundMajorBufferPips = 4.0;       // was 6
input double    InpRoundMinorGridPips   = 50.0;
input double    InpRoundMinorBufferPips = 3.0;       // was 4

input group "=== Regime Filters ==="
input bool      InpUseSoftSqueeze       = true;
input double    InpATRMinPips           = 50.0;
input bool      InpM5Bias               = true;
input int       InpM5EMAPeriod          = 50;
input double    InpM5SlopeGatePips      = 35.0;
input bool      InpAllowContraBiasOnStrong = true;   // NEW: override bias on sweep+strong wick
input bool      InpBlackoutEnable       = false;
input string    InpBlackout1Start       = "23:50";
input string    InpBlackout1End         = "00:10";

input group "=== Spread Gate ==="
input double    InpMaxSpreadPips        = 15.0;
input double    InpMaxSpreadLowVolPips  = 12.0;
input double    InpLowVolThresholdPips  = 95.0;

input group "=== Risk / Exits ==="
input double    InpSL_Pips_Fixed        = 25.0;
input double    InpSL_ATR_Mult          = 0.45;
input double    InpBE_Pips              = 14.0;
input double    InpPartial_Pips         = 18.0;
input double    InpPartial_Percent      = 40.0;
input double    InpTrailStart_Pips      = 20.0;
input double    InpTrailStep_Pips       = 16.0;
input int       InpTimeStopBars         = 10;
input double    InpTimeStopMinProfit    = 5.0;
input int       InpEarlyCutBars         = 2;
input double    InpEarlyCutAdversePips  = 12.0;

input group "=== Circuit Breakers ==="
input bool      InpCB_Enable            = true;
input int       InpCB_Losses_60m        = 4;
input int       InpCB_Cooldown_Min      = 60;
input int       InpCB_DailyLossesStop   = 999;
input double    InpCB_MinATRResume      = 70.0;

input group "=== Engine / Pending & Debug ==="
input bool      InpUsePendingStop       = true;
input int       InpPendingExpirySec     = 120;
input double    InpInvalidateBufferPips = 4.0;       // NEW: buffer around test extreme
input int       InpInvalidateDwellSec   = 10;        // NEW: must hold beyond buffer for N sec
input int       InpAfterCancelCooldownS = 45;        // NEW: avoid re-place spam
input bool      InpDebug                = true;

//========================== GLOBALS =================================
CTrade         trade;
int            atr_handle = INVALID_HANDLE;
int            emaM5_handle = INVALID_HANDLE;

double         gPip;  int gDigits;  ulong gMagic;
datetime       gLastBarTime = 0;

int            gConsecLosses = 0, gLossCount = 0;
datetime       gCooldownUntil = 0;
ulong          gLastProcessedDeal = 0;

bool           gHasPosition=false; ulong gPosTicket=0; double gPosEntry=0.0, gPosVolume=0.0;
bool           gBE=false, gPartial=false; int gBarsSinceEntry=0;

ulong          gPendingTicket = 0; bool gPendingIsLong = true;
double         gPendingPrice = 0.0; datetime gPendingExpire=0;
double         gPendingInvalidLevel = 0.0; bool gPendingInvalidIsBelow = true;
datetime       gInvalidStart = 0;              // dwell timer
datetime       gLastCancelTime = 0;            // cooldown after cancel

//======================= UTILS ======================================
double Pip(){ string s=_Symbol; if(StringFind(s,"XAU")>=0||StringFind(s,"GOLD")>=0) return 0.01;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(d==5||d==3) return 10*pt; return pt; }
double ToPrice(double pips){ return pips* Pip(); }
double NormalizePrice(double p){ return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
double SpreadPips(){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); return (ask-bid)/Pip(); }

double PointSize(){ return SymbolInfoDouble(_Symbol,SYMBOL_POINT); }
double TickSizeVal(){ return SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); }
double StopsLevelPoints(){ return (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); }
double RoundUpToTick(double price){ double ts=TickSizeVal(); return NormalizeDouble(MathCeil(price/ts)*ts,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
double RoundDnToTick(double price){ double ts=TickSizeVal(); return NormalizeDouble(MathFloor(price/ts)*ts,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }

void StringToTimeComponents(string hhmm,int &h,int &m){ h=0;m=0; string a[]; int n=StringSplit(hhmm,':',a); if(n>=1)h=(int)StringToInteger(a[0]); if(n>=2)m=(int)StringToInteger(a[1]); }
bool InBlackout(){
   if(!InpBlackoutEnable) return false;
   MqlDateTime t; TimeToStruct(TimeCurrent(),t); int now=t.hour*60+t.min;
   int sh,sm,eh,em; StringToTimeComponents(InpBlackout1Start,sh,sm); StringToTimeComponents(InpBlackout1End,eh,em);
   int s=sh*60+sm,e=eh*60+em; bool blk = (s<=e)? (now>=s && now<e) : (now>=s || now<e);
   if(InpDebug && blk) Print("🌙 BLACKOUT window");  return blk;
}

double ATRpips(){ double buf[]; if(CopyBuffer(atr_handle,0,0,16,buf)<=0) return 0; ArraySetAsSeries(buf,true); return buf[0]/Pip(); }

bool SoftSqueezeOK(double &atr_out){
   atr_out=ATRpips();
   bool ok = (!InpUseSoftSqueeze) || (atr_out >= InpATRMinPips);
   if(InpDebug && !ok) Print("⛔ SoftSqueeze BLOCK  ATR=",DoubleToString(atr_out,1),"  Min=",DoubleToString(InpATRMinPips,1));
   return ok;
}
bool SpreadOK(double atr_now){
   double s=SpreadPips(); double limit=(atr_now<InpLowVolThresholdPips? InpMaxSpreadLowVolPips: InpMaxSpreadPips);
   bool ok=(s<=limit); if(InpDebug && !ok) Print("⛔ Spread too wide: ",DoubleToString(s,1),"p > ",DoubleToString(limit,1),"p");
   return ok;
}
bool RoundNumberNearby(double price){
   if(!InpRoundNumberAvoid) return false;
   double gMaj=ToPrice(InpRoundMajorGridPips), gMin=ToPrice(InpRoundMinorGridPips);
   double bMaj=ToPrice(InpRoundMajorBufferPips), bMin=ToPrice(InpRoundMinorBufferPips);
   double dMaj=fabs(price - MathRound(price/gMaj)*gMaj);
   double dMin=fabs(price - MathRound(price/gMin)*gMin);
   bool hit=(dMaj<=bMaj)||(dMin<=bMin);
   if(InpDebug && hit) Print("⚠️ Round number nearby (",DoubleToString(dMaj/Pip(),1)," / ",DoubleToString(dMin/Pip(),1)," pips)");
   return hit;
}

//======================== PTG PATTERN ===============================
double H(int i){ return iHigh(_Symbol,PERIOD_CURRENT,i); }
double L(int i){ return iLow (_Symbol,PERIOD_CURRENT,i); }
double O(int i){ return iOpen(_Symbol,PERIOD_CURRENT,i); }
double C(int i){ return iClose(_Symbol,PERIOD_CURRENT,i); }
double Range(int i){ return H(i)-L(i); }

double RetrPct(double ph,double pl,double tclose,bool longdir){
   double r=(ph-pl); if(r<=0) return 0; return longdir? 100.0*((ph-tclose)/r): 100.0*((tclose-pl)/r);
}
double LowerWick(int i){ double bodyLow=MathMin(O(i),C(i)); return bodyLow - L(i); }
double UpperWick(int i){ double bodyHigh=MathMax(O(i),C(i)); return H(i) - bodyHigh; }

struct Setup {
   bool   valid;
   bool   isLong;
   double entry;
   double sl;
   double invalidLevel; // test low/high
   bool   invalidIsBelow;
   bool   swept;
   double wickPips;
   double wickFrac;
   double atr;
};

bool BuildPTG(int idx, Setup &s){
   int pushShift = idx+2-(InpPushBars-1);
   if(pushShift<2) return false;
   double atr = ATRpips();

   double ph=-DBL_MAX, pl=DBL_MAX, sumR=0.0, maxR=0.0;
   for(int k=0;k<InpPushBars;k++){
      double r=Range(pushShift-k);
      sumR+=r; if(r>maxR) maxR=r;
      ph=MathMax(ph,H(pushShift-k)); pl=MathMin(pl,L(pushShift-k));
   }
   double avgRangePips = (sumR/InpPushBars)/Pip();
   double maxRangePips = (maxR)/Pip();
   bool pushOK = (avgRangePips >= InpPushAvgATRmult*atr) || (maxRangePips >= InpPushMaxATRmult*atr);
   if(!pushOK){ if(InpDebug) Print("⚠️ PUSH too small: avg=",DoubleToString(avgRangePips,1),"p / max=",DoubleToString(maxRangePips,1),
                                   "p  need ",DoubleToString(InpPushAvgATRmult*atr,1)," or ",DoubleToString(InpPushMaxATRmult*atr,1)); return false; }

   int t = idx+1;
   bool isLong = (C(pushShift) > O(pushShift));
   double retr = RetrPct(ph,pl,C(t),isLong);
   if(retr < InpTestRetrMinPct || retr > InpTestRetrMaxPct){
      // allow override later if strong wick
      if(InpDebug) Print("⚠️ TEST retr ",DoubleToString(retr,1),"% out of [",DoubleToString(InpTestRetrMinPct,1),",",DoubleToString(InpTestRetrMaxPct,1),"]");
   }

   // Dynamic wick (OR rule)
   double rng = Range(t); if(rng<=0) return false;
   double wick = isLong ? LowerWick(t) : UpperWick(t);
   double wickFrac = wick / rng;
   double wickMinA = MathMin(InpWickMinPipsCap, 0.25*atr); // rule A pips
   double wickMinB = MathMax(InpWickMinPipsCap, InpStrongWickATR*atr); // rule B pips
   bool ruleA = (wickFrac >= InpWickFracBase) && ((wick/Pip()) >= wickMinA);
   bool ruleB = (wickFrac >= InpWickFracAlt ) && ((wick/Pip()) >= wickMinB);
   if(!(ruleA || ruleB)){
      if(InpDebug) Print("⚠️ Wick too small: frac=",DoubleToString(100*wickFrac,1),"%, pips=",DoubleToString(wick/Pip(),1),
                         "  need A(frac≥",DoubleToString(100*InpWickFracBase,0),"%, p≥",DoubleToString(wickMinA,1),
                         ") OR B(frac≥",DoubleToString(100*InpWickFracAlt,0),"%, p≥",DoubleToString(wickMinB,1),")");
      return false;
   }

   // Liquidity sweep (soft fallback on strong momentum)
   bool swept = isLong ? (L(t) < L(t+1)) : (H(t) > H(t+1));
   if(InpRequireSweep && !swept){
      bool strongMomentum = (maxRangePips >= 0.95*atr) || ruleB; // ruleB implies strong wick
      if(!(InpSweepSoftFallback && strongMomentum)){
         if(InpDebug) Print("⚠️ No sweep (", (isLong?"long":"short"), ")"); 
         return false;
      }
   }

   // entry buffer
   double eb = MathMax(InpEntryBufferPips, MathMin(8.0, SpreadPips()+2.0));
   double trigger = isLong? (ph+ToPrice(eb)):(pl-ToPrice(eb));
   if(RoundNumberNearby(trigger)) return false;

   double dist_pips = MathMin(InpSL_Pips_Fixed, InpSL_ATR_Mult * atr);
   s.valid=true; s.isLong=isLong; s.entry=NormalizePrice(trigger);
   s.sl = isLong? NormalizePrice(s.entry - ToPrice(dist_pips)) : NormalizePrice(s.entry + ToPrice(dist_pips));
   s.invalidLevel = isLong ? L(t) : H(t);
   s.invalidIsBelow = isLong;
   s.swept = swept; s.wickPips=wick/Pip(); s.wickFrac=wickFrac; s.atr=atr;
   return true;
}

bool M5BiasFavor(const Setup &s){
   if(!InpM5Bias) return true;
   double ema[]; if(CopyBuffer(emaM5_handle,0,0,12,ema)<=0) return true; ArraySetAsSeries(ema,true);
   double slope=(ema[0]-ema[10])/Pip(); bool enforce=(fabs(slope)>=InpM5SlopeGatePips);
   if(!enforce) return true;
   bool ok = s.isLong ? (slope>0) : (slope<0);
   if(!ok && InpAllowContraBiasOnStrong){
      bool strongWick = (s.wickPips >= InpStrongWickATR*s.atr);
      if(s.swept && strongWick) ok=true; // override for stop-hunt + strong wick
   }
   if(!ok && InpDebug) Print("⛔ M5 bias filter: slope=",DoubleToString(slope,1),"p  blocked ",(s.isLong?"LONG":"SHORT"));
   return ok;
}

bool FindSetup(Setup &s){ for(int i=0;i<InpLookback;i++) if(BuildPTG(i,s)) return true; return false; }

//======================== ORDERING ==================================
double CalcPositionSize(double sl){
   if(InpFixedLots>0.0 && InpRiskPercent<=0.0) return InpFixedLots;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double risk=MathMax(0.0,InpRiskPercent/100.0)*bal; if(risk<=0) return InpFixedLots;
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID); double dist=MathAbs(price-sl);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=TickSizeVal();
   if(ts<=0) ts=PointSize(); if(tv<=0||dist<=0) return InpFixedLots;
   double lotPerPoint=tv/ts; double lots=risk/(dist*lotPerPoint);
   double minlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathMax(minlot, MathMin(maxlot,lots)); lots=MathFloor(lots/step)*step; return lots;
}

void SafePendingPrices(bool isLong, double &entry, double &sl){
   double pt=PointSize(); double stops=StopsLevelPoints()*pt + 2*pt;
   if(isLong){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(entry < ask + stops) entry = ask + stops; entry = RoundUpToTick(entry);
      if(entry - sl < stops) sl = entry - stops; sl = RoundDnToTick(sl);
   }else{
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(entry > bid - stops) entry = bid - stops; entry = RoundDnToTick(entry);
      if(sl - entry < stops) sl = entry + stops; sl = RoundUpToTick(sl);
   }
   entry=NormalizePrice(entry); sl=NormalizePrice(sl);
}

bool PlacePending(bool isLong, double price, double sl){
   if(!InpUsePendingStop)
      return (isLong? trade.Buy(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0) :
                      trade.Sell(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0));

   SafePendingPrices(isLong, price, sl);
   datetime now=TimeCurrent();
   if(gLastCancelTime>0 && now - gLastCancelTime < InpAfterCancelCooldownS){
      if(InpDebug) Print("⏳ Cooldown after cancel: skip new pending");
      return false;
   }
   datetime exp = now + InpPendingExpirySec;
   bool ok = isLong? trade.BuyStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp) :
                     trade.SellStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp);
   if(ok){
      gPendingTicket = (ulong)trade.ResultOrder();
      gPendingIsLong = isLong;
      gPendingPrice  = price;
      gPendingExpire = exp;
      gInvalidStart  = 0;
      if(InpDebug) Print("📝 Pending ",(isLong?"BUY STOP ":"SELL STOP "),"@",
                         DoubleToString(price,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
                         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
                         " exp=",TimeToString(exp,TIME_SECONDS));
   }else{
      Print("❌ Pending send failed, ret=",trade.ResultRetcode());
   }
   return ok;
}
void CancelPendingIfAny(){
   if(gPendingTicket==0) return;
   if(OrderSelect((ulong)gPendingTicket)) trade.OrderDelete((ulong)gPendingTicket);
   gPendingTicket=0; gLastCancelTime=TimeCurrent(); gInvalidStart=0;
   if(InpDebug) Print("🧹 Structure invalidated – cancel pending");
}

//===================== POSITION MANAGEMENT ==========================
void ResetPos(){ gHasPosition=false; gPosTicket=0; gPosEntry=0; gPosVolume=0; gBE=false; gPartial=false; gBarsSinceEntry=0; }
void AfterOpenSync(){ gHasPosition=true; gPosTicket=(ulong)PositionGetInteger(POSITION_TICKET); gPosEntry=PositionGetDouble(POSITION_PRICE_OPEN); gPosVolume=PositionGetDouble(POSITION_VOLUME); gBarsSinceEntry=0; gBE=false; gPartial=false; CancelPendingIfAny(); }

void ManagePosition(){
   if(!gHasPosition) return;
   if(!PositionSelect(_Symbol)){ ResetPos(); return; }
   long type=(long)PositionGetInteger(POSITION_TYPE);
   double px=(type==POSITION_TYPE_BUY)? SymbolInfoDouble(_Symbol,SYMBOL_BID): SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double pips=(type==POSITION_TYPE_BUY)? (px-gPosEntry)/Pip() : (gPosEntry-px)/Pip();
   gBarsSinceEntry++;

   if(gBarsSinceEntry<=InpEarlyCutBars && pips <= -InpEarlyCutAdversePips){ trade.PositionClose(_Symbol); if(InpDebug) Print("✂️ Early-cut ",DoubleToString(pips,1),"p"); return; }
   if(gBarsSinceEntry>=InpTimeStopBars && pips < InpTimeStopMinProfit){ trade.PositionClose(_Symbol); if(InpDebug) Print("⏹ Time-stop"); return; }

   if(!gPartial && pips >= InpPartial_Pips){
      double vol=PositionGetDouble(POSITION_VOLUME);
      double closeVol=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), NormalizeDouble(vol*InpPartial_Percent/100.0,2));
      trade.PositionClosePartial(_Symbol,closeVol); gPartial=true; if(InpDebug) Print("💰 Partial ",DoubleToString(closeVol,2)); return;
   }
   if(!gBE && pips >= InpBE_Pips){
      double sl=(type==POSITION_TYPE_BUY)? (gPosEntry+ToPrice(SpreadPips())):(gPosEntry-ToPrice(SpreadPips()));
      trade.PositionModify(_Symbol,NormalizePrice(sl),0.0); gBE=true; if(InpDebug) Print("🛡️ Move BE");
   }
   if(pips>=InpTrailStart_Pips){
      double trail=ToPrice(InpTrailStep_Pips); double newSL=(type==POSITION_TYPE_BUY)? (px-trail):(px+trail);
      if( (type==POSITION_TYPE_BUY && newSL>PositionGetDouble(POSITION_SL)) || (type==POSITION_TYPE_SELL && newSL<PositionGetDouble(POSITION_SL)) )
         trade.PositionModify(_Symbol,NormalizePrice(newSL),0.0);
   }
}

//===================== CIRCUIT BREAKER & HISTORY ====================
void ResetDailyIfNeeded(){
   static int lastDay=-1; MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   if(lastDay==-1) lastDay=t.day;
   if(t.day != lastDay){ lastDay=t.day; gLossCount=0; gConsecLosses=0; gCooldownUntil=0; if(InpDebug) Print("🔄 New day – reset daily counters"); }
}
bool CircuitOK(double atr){
   if(!InpCB_Enable) return true;
   ResetDailyIfNeeded();
   if(TimeCurrent()<gCooldownUntil){ if(InpDebug) Print("⏸️ Cooldown active"); return false; }
   if(gLossCount>=InpCB_DailyLossesStop){ if(InpDebug) Print("⛔ Daily stop reached"); return false; }
   if(gCooldownUntil>0 && TimeCurrent()>=gCooldownUntil){ if(atr<InpCB_MinATRResume){ if(InpDebug) Print("⛔ Resume blocked by low ATR"); return false; } gCooldownUntil=0; }
   return true;
}
void NoteLoss(){ if(!InpCB_Enable) return; gConsecLosses++; if(gConsecLosses>=InpCB_Losses_60m){ gCooldownUntil=TimeCurrent()+InpCB_Cooldown_Min*60; if(InpDebug) Print("⚡ Cooldown ",InpCB_Cooldown_Min,"m"); gConsecLosses=0; } gLossCount++; }
void NoteWin(){ gConsecLosses=0; }

void UpdateWinLossFromHistory(){
   datetime from=TimeCurrent()-5*24*60*60; if(!HistorySelect(from,TimeCurrent())) return;
   int total=HistoryDealsTotal();
   for(int i=total-1;i>=0;--i){
      ulong deal=HistoryDealGetTicket(i); if(deal==0 || deal==gLastProcessedDeal) break;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue;
      long mg=(long)HistoryDealGetInteger(deal,DEAL_MAGIC); if((ulong)mg!=gMagic) continue;
      if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double p=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);
      if(p<0) NoteLoss(); else NoteWin(); gLastProcessedDeal=deal; break;
   }
}

//=========================== EVENTS =================================
int OnInit(){
   gPip=Pip(); gDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); gMagic=(ulong)InpMagic; trade.SetExpertMagicNumber((uint)gMagic);
   atr_handle=iATR(_Symbol,PERIOD_CURRENT,14); emaM5_handle=iMA(_Symbol,PERIOD_M5,InpM5EMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(atr_handle==INVALID_HANDLE || emaM5_handle==INVALID_HANDLE){ Print("Indicator init failed"); return INIT_FAILED; }
   gLastBarTime=iTime(_Symbol,PERIOD_CURRENT,0); EventSetTimer(1); Print("PTG v3.5.0 ready. Pip=",DoubleToString(gPip,5)); return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle); if(emaM5_handle!=INVALID_HANDLE) IndicatorRelease(emaM5_handle); CancelPendingIfAny(); }
void OnTimer(){
   // cancel when expired OR (beyond invalid +/- buffer AND held >= dwell)
   if(gPendingTicket!=0){
      datetime now=TimeCurrent();
      if(now>gPendingExpire){ if(InpDebug) Print("⌛ Pending expired – cancel"); CancelPendingIfAny(); return; }
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double px = gPendingInvalidIsBelow? bid : ask;
      double buffer=ToPrice(InpInvalidateBufferPips);
      bool beyond = gPendingInvalidIsBelow ? (px < gPendingInvalidLevel - buffer) : (px > gPendingInvalidLevel + buffer);
      if(beyond){
         if(gInvalidStart==0) gInvalidStart=now;
         if(now - gInvalidStart >= InpInvalidateDwellSec) CancelPendingIfAny();
      }else{
         gInvalidStart=0; // reset dwell if back inside
      }
   }
}
void OnTick(){
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,0);
   if(bt!=gLastBarTime){ gLastBarTime=bt; OnNewBar(); }
}
void OnNewBar(){
   UpdateWinLossFromHistory();

   if(PositionSelect(_Symbol)){ if(!gHasPosition) AfterOpenSync(); ManagePosition(); return; }
   else if(gHasPosition) ResetPos();

   double atr; if(!SoftSqueezeOK(atr)) return;
   if(!CircuitOK(atr)) return;
   if(InBlackout()) return;
   if(!SpreadOK(atr)) return;
   if(gPendingTicket!=0) return;

   Setup s; s.valid=false; if(!FindSetup(s)){ if(InpDebug) Print("… no PTG setup"); return; }
   if(!M5BiasFavor(s)) return;
   if(!((s.isLong && InpAllowLongs) || (!s.isLong && InpAllowShorts))) return;

   gPendingInvalidLevel = s.invalidLevel;
   gPendingInvalidIsBelow= s.invalidIsBelow;
   PlacePending(s.isLong, s.entry, s.sl);
}
//+------------------------------------------------------------------+
