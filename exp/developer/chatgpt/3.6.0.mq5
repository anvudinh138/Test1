//+------------------------------------------------------------------+
//|                 PTG BALANCED v3.6.0 (M1 Push–Test–Go)            |
//|  - Same core as v3.5.0 (dynamic wick, soft sweep, safe pending)  |
//|  - NEW: InpUsecase (presets) to switch whole parameter packs     |
//|  - All runtime uses working struct P (not raw inputs)            |
//+------------------------------------------------------------------+
#property strict
#property version   "3.60"
#property description "PTG v3.6.0 – presets + dynamic wick + safe pending + contra-bias override"

#include <Trade/Trade.mqh>

//========================== INPUTS ==================================
input group "=== Preset Switch ==="
input int   InpUsecase = 1; // 0=Manual(inputs), 1..N=Presets (see list printed on init)

input group "=== General ==="
input long      InpMagic                = 360001;
input double    InpFixedLots            = 0.10;
input double    InpRiskPercent          = 0.0;
input bool      InpAllowShorts          = true;
input bool      InpAllowLongs           = true;

input group "=== PTG Pattern ==="
input int       InpLookback             = 10;        // bars to scan
input int       InpPushBars             = 1;         // 1–2
input double    InpPushAvgATRmult       = 0.60;      // default softer
input double    InpPushMaxATRmult       = 0.80;
input double    InpTestRetrMinPct       = -20.0;
input double    InpTestRetrMaxPct       = 130.0;
input double    InpWickFracBase         = 0.35;      // rule A: frac>=0.35 & pips>=min(12,0.25*ATR)
input double    InpWickFracAlt          = 0.18;      // rule B: frac>=0.18 & pips>=max(12,0.35*ATR)
input double    InpWickMinPipsCap       = 12.0;
input bool      InpRequireSweep         = true;
input bool      InpSweepSoftFallback    = true;
input double    InpStrongWickATR        = 0.35;      // wick pips >= 0.35*ATR => strong
input double    InpEntryBufferPips      = 3.0;

input group "=== Round Number Filter (XAU) ==="
input bool      InpRoundNumberAvoid     = true;
input double    InpRoundMajorGridPips   = 100.0;
input double    InpRoundMajorBufferPips = 4.0;
input double    InpRoundMinorGridPips   = 50.0;
input double    InpRoundMinorBufferPips = 3.0;

input group "=== Regime Filters ==="
input bool      InpUseSoftSqueeze       = true;
input double    InpATRMinPips           = 50.0;
input bool      InpM5Bias               = true;
input int       InpM5EMAPeriod          = 50;
input double    InpM5SlopeGatePips      = 35.0;
input bool      InpAllowContraBiasOnStrong = true;
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
input double    InpInvalidateBufferPips = 4.0;
input int       InpInvalidateDwellSec   = 10;
input int       InpAfterCancelCooldownS = 45;
input bool      InpDebug                = true;

//====================== WORKING PARAM STRUCT ========================
struct PTGParams {
  // General
  long   Magic; double FixedLots,RiskPercent; bool AllowShorts,AllowLongs;
  // Pattern
  int Lookback,PushBars; double PushAvgATRmult,PushMaxATRmult;
  double TestRetrMinPct,TestRetrMaxPct;
  double WickFracBase,WickFracAlt,WickMinPipsCap;
  bool RequireSweep,SweepSoftFallback; double StrongWickATR,EntryBufferPips;
  // RN filter
  bool RoundAvoid; double RNMajGrid,RNMajBuf,RNMinGrid,RNMinBuf;
  // Regime
  bool UseSoftSqueeze; double ATRMinPips; bool M5Bias; int M5EMAPeriod; double M5Slope;
  bool AllowContraBiasOnStrong; bool Blackout; string BOstart,BOend;
  // Spread
  double MaxSpread, MaxSpreadLowVol, LowVolThresh;
  // Risk/Exit
  double SL_Fixed, SL_ATRmult, BE_Pips, Partial_Pips, Partial_Perc, TrailStart, TrailStep;
  int TimeStopBars; double TimeStopMin; int EarlyCutBars; double EarlyCutPips;
  // CB
  bool CB_Enable; int CB_Loss60; int CB_CoolMin; int CB_DailyStop; double CB_MinATRResume;
  // Engine
  bool UsePending; int PendingExpiry; double InvalBufPips; int InvalDwellSec; int AfterCancelCD;
  bool Debug;
};
PTGParams P;

// fill from inputs
void LoadFromInputs(){
  P.Magic=InpMagic; P.FixedLots=InpFixedLots; P.RiskPercent=InpRiskPercent; P.AllowShorts=InpAllowShorts; P.AllowLongs=InpAllowLongs;
  P.Lookback=InpLookback; P.PushBars=InpPushBars; P.PushAvgATRmult=InpPushAvgATRmult; P.PushMaxATRmult=InpPushMaxATRmult;
  P.TestRetrMinPct=InpTestRetrMinPct; P.TestRetrMaxPct=InpTestRetrMaxPct;
  P.WickFracBase=InpWickFracBase; P.WickFracAlt=InpWickFracAlt; P.WickMinPipsCap=InpWickMinPipsCap;
  P.RequireSweep=InpRequireSweep; P.SweepSoftFallback=InpSweepSoftFallback; P.StrongWickATR=InpStrongWickATR; P.EntryBufferPips=InpEntryBufferPips;
  P.RoundAvoid=InpRoundNumberAvoid; P.RNMajGrid=InpRoundMajorGridPips; P.RNMajBuf=InpRoundMajorBufferPips; P.RNMinGrid=InpRoundMinorGridPips; P.RNMinBuf=InpRoundMinorBufferPips;
  P.UseSoftSqueeze=InpUseSoftSqueeze; P.ATRMinPips=InpATRMinPips; P.M5Bias=InpM5Bias; P.M5EMAPeriod=InpM5EMAPeriod; P.M5Slope=InpM5SlopeGatePips;
  P.AllowContraBiasOnStrong=InpAllowContraBiasOnStrong; P.Blackout=InpBlackoutEnable; P.BOstart=InpBlackout1Start; P.BOend=InpBlackout1End;
  P.MaxSpread=InpMaxSpreadPips; P.MaxSpreadLowVol=InpMaxSpreadLowVolPips; P.LowVolThresh=InpLowVolThresholdPips;
  P.SL_Fixed=InpSL_Pips_Fixed; P.SL_ATRmult=InpSL_ATR_Mult; P.BE_Pips=InpBE_Pips; P.Partial_Pips=InpPartial_Pips; P.Partial_Perc=InpPartial_Percent;
  P.TrailStart=InpTrailStart_Pips; P.TrailStep=InpTrailStep_Pips; P.TimeStopBars=InpTimeStopBars; P.TimeStopMin=InpTimeStopMinProfit;
  P.EarlyCutBars=InpEarlyCutBars; P.EarlyCutPips=InpEarlyCutAdversePips;
  P.CB_Enable=InpCB_Enable; P.CB_Loss60=InpCB_Losses_60m; P.CB_CoolMin=InpCB_Cooldown_Min; P.CB_DailyStop=InpCB_DailyLossesStop; P.CB_MinATRResume=InpCB_MinATRResume;
  P.UsePending=InpUsePendingStop; P.PendingExpiry=InpPendingExpirySec; P.InvalBufPips=InpInvalidateBufferPips; P.InvalDwellSec=InpInvalidateDwellSec; P.AfterCancelCD=InpAfterCancelCooldownS;
  P.Debug=InpDebug;
}

// apply preset
void ApplyUsecase(int id){
  // start from default (inputs) then override
  LoadFromInputs();

  // === Preset catalog (quick reference) ===
  // 0 = Manual (use all inputs as-is)
  // 1 = Default v3.5.0 tuned (recommended base)
  // 2 = Softer Wick (for your test "InpWickFracBase=0.30")
  // 3 = No Sweep (max entries)
  // 4 = Lower PUSH (0.58/0.78) like your H5
  // 5 = Pending Dwell strong (buffer 5p, dwell 15s)
  // 6 = Pending Dwell very strong (buffer 6p, dwell 20s)
  // 7 = Conservative (ATRMin 65, stricter wick, SL 28, require sweep)
  // 8 = Aggressive (ATRMin 45, M5Bias OFF, Push 0.56/0.76, sweep soft)
  // 9 = Tight BE scalper (BE12, partial16, trail start 18/step14)
  // 10 = Wide RR (SL 30, partial22, trail 24/20)
  // 11 = RN hard (RN buffers 6/4 + forbid entries inside)
  // 12 = Spread strict (max spread 12/10, ATRMin 55)
  // 13 = Bias hard (M5Bias ON, no contra override)
  // 14 = Bias soft (M5Bias ON but slope gate 25)

  if(id<=0) { Print("Usecase 0 (Manual inputs)"); return; }

  switch(id){
    case 1: // Default tuned
      P.PushAvgATRmult=0.60; P.PushMaxATRmult=0.80;
      P.WickFracBase=0.35; P.WickFracAlt=0.18; P.StrongWickATR=0.35;
      P.RequireSweep=true; P.SweepSoftFallback=true;
      P.ATRMinPips=50; P.M5Bias=true; P.AllowContraBiasOnStrong=true;
      P.InvalBufPips=4; P.InvalDwellSec=10; break;

    case 2: // Softer Wick
      P.WickFracBase=0.30; P.WickFracAlt=0.16; P.StrongWickATR=0.33; break;

    case 3: // No Sweep
      P.RequireSweep=false; P.SweepSoftFallback=true; break;

    case 4: // Lower PUSH (like your H5)
      P.PushAvgATRmult=0.58; P.PushMaxATRmult=0.78; break;

    case 5: // Pending dwell strong
      P.InvalBufPips=5; P.InvalDwellSec=15; break;

    case 6: // Pending dwell very strong
      P.InvalBufPips=6; P.InvalDwellSec=20; break;

    case 7: // Conservative
      P.ATRMinPips=65; P.WickFracBase=0.40; P.WickFracAlt=0.22; P.SL_Fixed=28; 
      P.RequireSweep=true; P.SweepSoftFallback=false; break;

    case 8: // Aggressive entries
      P.ATRMinPips=45; P.M5Bias=false; P.PushAvgATRmult=0.56; P.PushMaxATRmult=0.76;
      P.RequireSweep=false; P.SweepSoftFallback=true; break;

    case 9: // Tight BE scalper
      P.BE_Pips=12; P.Partial_Pips=16; P.TrailStart=18; P.TrailStep=14; break;

    case 10: // Wider RR
      P.SL_Fixed=30; P.Partial_Pips=22; P.TrailStart=24; P.TrailStep=20; break;

    case 11: // RN hard
      P.RNMajBuf=6; P.RNMinBuf=4; P.RoundAvoid=true; break;

    case 12: // Spread strict
      P.MaxSpread=12; P.MaxSpreadLowVol=10; P.ATRMinPips=55; break;

    case 13: // Bias hard
      P.M5Bias=true; P.AllowContraBiasOnStrong=false; P.M5Slope=35; break;

    case 14: // Bias soft slope
      P.M5Bias=true; P.AllowContraBiasOnStrong=true; P.M5Slope=25; break;

    default: break;
  }

  // Announce
  Print("✅ Applied Usecase #",id,
        " | PUSH ",DoubleToString(P.PushAvgATRmult,2),"/",DoubleToString(P.PushMaxATRmult,2),
        " | WickBase ",DoubleToString(P.WickFracBase,2)," alt ",DoubleToString(P.WickFracAlt,2),
        " | Sweep ",(P.RequireSweep?"ON":"OFF"),(P.SweepSoftFallback?"(soft)":""),
        " | ATRMin ",DoubleToString(P.ATRMinPips,1),
        " | Bias ",(P.M5Bias?"ON":"OFF"),(P.AllowContraBiasOnStrong?"(contraOK)":"(no-contra)"),
        " | Cancel buf/dwell ",DoubleToString(P.InvalBufPips,1),"p/",IntegerToString(P.InvalDwellSec),"s");
}

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
   if(!P.Blackout) return false;
   MqlDateTime t; TimeToStruct(TimeCurrent(),t); int now=t.hour*60+t.min;
   int sh,sm,eh,em; StringToTimeComponents(P.BOstart,sh,sm); StringToTimeComponents(P.BOend,eh,em);
   int s=sh*60+sm,e=eh*60+em; bool blk = (s<=e)? (now>=s && now<e) : (now>=s || now<e);
   if(P.Debug && blk) Print("🌙 BLACKOUT window");  return blk;
}

double ATRpips(){ double buf[]; if(CopyBuffer(atr_handle,0,0,16,buf)<=0) return 0; ArraySetAsSeries(buf,true); return buf[0]/Pip(); }

bool SoftSqueezeOK(double &atr_out){
   atr_out=ATRpips();
   bool ok = (!P.UseSoftSqueeze) || (atr_out >= P.ATRMinPips);
   if(P.Debug && !ok) Print("⛔ SoftSqueeze BLOCK  ATR=",DoubleToString(atr_out,1),"  Min=",DoubleToString(P.ATRMinPips,1));
   return ok;
}
bool SpreadOK(double atr_now){
   double s=SpreadPips(); double limit=(atr_now<P.LowVolThresh? P.MaxSpreadLowVol: P.MaxSpread);
   bool ok=(s<=limit); if(P.Debug && !ok) Print("⛔ Spread too wide: ",DoubleToString(s,1),"p > ",DoubleToString(limit,1),"p");
   return ok;
}
bool RoundNumberNearby(double price){
   if(!P.RoundAvoid) return false;
   double gMaj=ToPrice(P.RNMajGrid), gMin=ToPrice(P.RNMinGrid);
   double bMaj=ToPrice(P.RNMajBuf), bMin=ToPrice(P.RNMinBuf);
   double dMaj=fabs(price - MathRound(price/gMaj)*gMaj);
   double dMin=fabs(price - MathRound(price/gMin)*gMin);
   bool hit=(dMaj<=bMaj)||(dMin<=bMin);
   if(P.Debug && hit) Print("⚠️ Round number nearby (",DoubleToString(dMaj/Pip(),1)," / ",DoubleToString(dMin/Pip(),1)," pips)");
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
   double invalidLevel;
   bool   invalidIsBelow;
   bool   swept;
   double wickPips;
   double wickFrac;
   double atr;
   double maxRangePips;
};

bool BuildPTG(int idx, Setup &s){
   int pushShift = idx+2-(P.PushBars-1);
   if(pushShift<2) return false;
   double atr = ATRpips();

   double ph=-DBL_MAX, pl=DBL_MAX, sumR=0.0, maxR=0.0;
   for(int k=0;k<P.PushBars;k++){
      double r=Range(pushShift-k);
      sumR+=r; if(r>maxR) maxR=r;
      ph=MathMax(ph,H(pushShift-k)); pl=MathMin(pl,L(pushShift-k));
   }
   double avgRangePips = (sumR/P.PushBars)/Pip();
   double maxRangePips = (maxR)/Pip();
   bool pushOK = (avgRangePips >= P.PushAvgATRmult*atr) || (maxRangePips >= P.PushMaxATRmult*atr);
   if(!pushOK){ if(P.Debug) Print("⚠️ PUSH too small: avg=",DoubleToString(avgRangePips,1),"p / max=",DoubleToString(maxRangePips,1),
                                   "p  need ",DoubleToString(P.PushAvgATRmult*atr,1)," or ",DoubleToString(P.PushMaxATRmult*atr,1)); return false; }

   int t = idx+1;
   bool isLong = (C(pushShift) > O(pushShift));
   double retr = RetrPct(ph,pl,C(t),isLong);
   if(retr < P.TestRetrMinPct || retr > P.TestRetrMaxPct){
      if(P.Debug) Print("⚠️ TEST retr ",DoubleToString(retr,1),"% out of [",DoubleToString(P.TestRetrMinPct,1),",",DoubleToString(P.TestRetrMaxPct,1),"]");
   }

   // Dynamic wick with OR-rule
   double rng = Range(t); if(rng<=0) return false;
   double wick = isLong ? LowerWick(t) : UpperWick(t);
   double wickFrac = wick / rng;
   double wickMinA = MathMin(P.WickMinPipsCap, 0.25*atr);
   double wickMinB = MathMax(P.WickMinPipsCap, P.StrongWickATR*atr);
   bool ruleA = (wickFrac >= P.WickFracBase) && ((wick/Pip()) >= wickMinA);
   bool ruleB = (wickFrac >= P.WickFracAlt ) && ((wick/Pip()) >= wickMinB);
   if(!(ruleA || ruleB)){
      if(P.Debug) Print("⚠️ Wick too small: frac=",DoubleToString(100*wickFrac,1),"%, pips=",DoubleToString(wick/Pip(),1),
                         "  need A(frac≥",DoubleToString(100*P.WickFracBase,0),"%, p≥",DoubleToString(wickMinA,1),
                         ") OR B(frac≥",DoubleToString(100*P.WickFracAlt,0),"%, p≥",DoubleToString(wickMinB,1),")");
      return false;
   }

   // Sweep with soft fallback
   bool swept = isLong ? (L(t) < L(t+1)) : (H(t) > H(t+1));
   if(P.RequireSweep && !swept){
      bool strongMomentum = (maxRangePips >= 0.95*atr) || ruleB;
      if(!(P.SweepSoftFallback && strongMomentum)){
         if(P.Debug) Print("⚠️ No sweep (", (isLong?"long":"short"), ")"); 
         return false;
      }
   }

   // Entry buffer & RN
   double eb = MathMax(P.EntryBufferPips, MathMin(8.0, SpreadPips()+2.0));
   double trigger = isLong? (ph+ToPrice(eb)):(pl-ToPrice(eb));
   if(RoundNumberNearby(trigger)) return false;

   double dist_pips = MathMin(P.SL_Fixed, P.SL_ATRmult * atr);
   s.valid=true; s.isLong=isLong; s.entry=NormalizePrice(trigger);
   s.sl = isLong? NormalizePrice(s.entry - ToPrice(dist_pips)) : NormalizePrice(s.entry + ToPrice(dist_pips));
   s.invalidLevel = isLong ? L(t) : H(t);
   s.invalidIsBelow = isLong;
   s.swept = swept; s.wickPips=wick/Pip(); s.wickFrac=wickFrac; s.atr=atr; s.maxRangePips=maxRangePips;
   return true;
}

bool M5BiasFavor(const Setup &s){
   if(!P.M5Bias) return true;
   double ema[]; if(CopyBuffer(emaM5_handle,0,0,12,ema)<=0) return true; ArraySetAsSeries(ema,true);
   double slope=(ema[0]-ema[10])/Pip(); bool enforce=(fabs(slope)>=P.M5Slope);
   if(!enforce) return true;
   bool ok = s.isLong ? (slope>0) : (slope<0);
   if(!ok && P.AllowContraBiasOnStrong){
      bool strongWick = (s.wickPips >= P.StrongWickATR*s.atr);
      if(s.swept && strongWick) ok=true;
   }
   if(!ok && P.Debug) Print("⛔ M5 bias filter: slope=",DoubleToString(slope,1),"p  blocked ",(s.isLong?"LONG":"SHORT"));
   return ok;
}

bool FindSetup(Setup &s){ for(int i=0;i<P.Lookback;i++) if(BuildPTG(i,s)) return true; return false; }

//======================== ORDERING ==================================
CTrade trade;
double CalcPositionSize(double sl){
   if(P.FixedLots>0.0 && P.RiskPercent<=0.0) return P.FixedLots;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double risk=MathMax(0.0,P.RiskPercent/100.0)*bal; if(risk<=0) return P.FixedLots;
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID); double dist=MathAbs(price-sl);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=TickSizeVal();
   if(ts<=0) ts=PointSize(); if(tv<=0||dist<=0) return P.FixedLots;
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

ulong gPendingTicket=0; bool gPendingIsLong=true; double gPendingPrice=0; datetime gPendingExpire=0;
double gPendingInvalidLevel=0; bool gPendingInvalidIsBelow=true; datetime gInvalidStart=0; datetime gLastCancelTime=0;

bool PlacePending(bool isLong, double price, double sl){
   if(!P.UsePending)
      return (isLong? trade.Buy(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0) :
                      trade.Sell(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0));

   SafePendingPrices(isLong, price, sl);
   datetime now=TimeCurrent();
   if(gLastCancelTime>0 && now - gLastCancelTime < P.AfterCancelCD){
      if(P.Debug) Print("⏳ Cooldown after cancel: skip new pending"); return false;
   }
   datetime exp = now + P.PendingExpiry;
   bool ok = isLong? trade.BuyStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp) :
                     trade.SellStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp);
   if(ok){
      gPendingTicket = (ulong)trade.ResultOrder();
      gPendingIsLong = isLong; gPendingPrice=price; gPendingExpire=exp; gInvalidStart=0;
      if(P.Debug) Print("📝 Pending ",(isLong?"BUY STOP ":"SELL STOP "),"@",
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
   if(P.Debug) Print("🧹 Structure invalidated – cancel pending");
}

//===================== POSITION MANAGEMENT ==========================
bool gHasPosition=false; ulong gPosTicket=0; double gPosEntry=0.0, gPosVolume=0.0; bool gBE=false,gPartial=false; int gBarsSinceEntry=0;

void ResetPos(){ gHasPosition=false; gPosTicket=0; gPosEntry=0; gPosVolume=0; gBE=false; gPartial=false; gBarsSinceEntry=0; }
void AfterOpenSync(){ gHasPosition=true; gPosTicket=(ulong)PositionGetInteger(POSITION_TICKET); gPosEntry=PositionGetDouble(POSITION_PRICE_OPEN); gPosVolume=PositionGetDouble(POSITION_VOLUME); gBarsSinceEntry=0; gBE=false; gPartial=false; CancelPendingIfAny(); }

void ManagePosition(){
   if(!gHasPosition) return;
   if(!PositionSelect(_Symbol)){ ResetPos(); return; }
   long type=(long)PositionGetInteger(POSITION_TYPE);
   double px=(type==POSITION_TYPE_BUY)? SymbolInfoDouble(_Symbol,SYMBOL_BID): SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double pips=(type==POSITION_TYPE_BUY)? (px-gPosEntry)/Pip() : (gPosEntry-px)/Pip();
   gBarsSinceEntry++;

   if(gBarsSinceEntry<=P.EarlyCutBars && pips <= -P.EarlyCutPips){ trade.PositionClose(_Symbol); if(P.Debug) Print("✂️ Early-cut ",DoubleToString(pips,1),"p"); return; }
   if(gBarsSinceEntry>=P.TimeStopBars && pips < P.TimeStopMin){ trade.PositionClose(_Symbol); if(P.Debug) Print("⏹ Time-stop"); return; }

   if(!gPartial && pips >= P.Partial_Pips){
      double vol=PositionGetDouble(POSITION_VOLUME);
      double closeVol=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), NormalizeDouble(vol*P.Partial_Perc/100.0,2));
      trade.PositionClosePartial(_Symbol,closeVol); gPartial=true; if(P.Debug) Print("💰 Partial ",DoubleToString(closeVol,2)); return;
   }
   if(!gBE && pips >= P.BE_Pips){
      double sl=(type==POSITION_TYPE_BUY)? (gPosEntry+ToPrice(SpreadPips())):(gPosEntry-ToPrice(SpreadPips()));
      trade.PositionModify(_Symbol,NormalizePrice(sl),0.0); gBE=true; if(P.Debug) Print("🛡️ Move BE");
   }
   if(pips>=P.TrailStart){
      double trail=ToPrice(P.TrailStep); double newSL=(type==POSITION_TYPE_BUY)? (px-trail):(px+trail);
      if( (type==POSITION_TYPE_BUY && newSL>PositionGetDouble(POSITION_SL)) || (type==POSITION_TYPE_SELL && newSL<PositionGetDouble(POSITION_SL)) )
         trade.PositionModify(_Symbol,NormalizePrice(newSL),0.0);
   }
}

//===================== CIRCUIT BREAKER & HISTORY ====================
int gLastDay=-1; int gConsecLosses=0, gLossCount=0; datetime gCooldownUntil=0; ulong gLastProcessedDeal=0;

void ResetDailyIfNeeded(){
   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   if(gLastDay==-1) gLastDay=t.day;
   if(t.day != gLastDay){ gLastDay=t.day; gLossCount=0; gConsecLosses=0; gCooldownUntil=0; if(P.Debug) Print("🔄 New day – reset daily counters"); }
}
bool CircuitOK(double atr){
   if(!P.CB_Enable) return true;
   ResetDailyIfNeeded();
   if(TimeCurrent()<gCooldownUntil){ if(P.Debug) Print("⏸️ Cooldown active"); return false; }
   if(gLossCount>=P.CB_DailyStop){ if(P.Debug) Print("⛔ Daily stop reached"); return false; }
   if(gCooldownUntil>0 && TimeCurrent()>=gCooldownUntil){ if(atr<P.CB_MinATRResume){ if(P.Debug) Print("⛔ Resume blocked by low ATR"); return false; } gCooldownUntil=0; }
   return true;
}
void NoteLoss(){ if(!P.CB_Enable) return; gConsecLosses++; if(gConsecLosses>=P.CB_Loss60){ gCooldownUntil=TimeCurrent()+P.CB_CoolMin*60; if(P.Debug) Print("⚡ Cooldown ",P.CB_CoolMin,"m"); gConsecLosses=0; } gLossCount++; }
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
   // Build working params
   ApplyUsecase(InpUsecase);
   gPip=Pip(); gDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); gMagic=(ulong)P.Magic; trade.SetExpertMagicNumber((uint)gMagic);
   atr_handle=iATR(_Symbol,PERIOD_CURRENT,14); emaM5_handle=iMA(_Symbol,PERIOD_M5,P.M5EMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(atr_handle==INVALID_HANDLE || emaM5_handle==INVALID_HANDLE){ Print("Indicator init failed"); return INIT_FAILED; }
   gLastBarTime=iTime(_Symbol,PERIOD_CURRENT,0); EventSetTimer(1); Print("PTG v3.6.0 ready. Pip=",DoubleToString(gPip,5)); return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle); if(emaM5_handle!=INVALID_HANDLE) IndicatorRelease(emaM5_handle); CancelPendingIfAny(); }
void OnTimer(){
   // cancel when expired OR (beyond invalid +/- buffer AND held >= dwell)
   if(gPendingTicket!=0){
      datetime now=TimeCurrent();
      if(now>gPendingExpire){ if(P.Debug) Print("⌛ Pending expired – cancel"); CancelPendingIfAny(); return; }
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double px = gPendingInvalidIsBelow? bid : ask;
      double buffer=ToPrice(P.InvalBufPips);
      bool beyond = gPendingInvalidIsBelow ? (px < gPendingInvalidLevel - buffer) : (px > gPendingInvalidLevel + buffer);
      if(beyond){
         if(gInvalidStart==0) gInvalidStart=now;
         if(now - gInvalidStart >= P.InvalDwellSec) CancelPendingIfAny();
      }else{
         gInvalidStart=0;
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

   Setup s; s.valid=false; if(!FindSetup(s)){ if(P.Debug) Print("… no PTG setup"); return; }
   if(!M5BiasFavor(s)) return;
   if(!((s.isLong && P.AllowLongs) || (!s.isLong && P.AllowShorts))) return;

   gPendingInvalidLevel = s.invalidLevel;
   gPendingInvalidIsBelow= s.invalidIsBelow;
   PlacePending(s.isLong, s.entry, s.sl);
}
//+------------------------------------------------------------------+
