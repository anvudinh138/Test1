//+------------------------------------------------------------------+
//|                 PTG BALANCED v4.0.0 (M1 Push–Test–Go)            |
//|  - Lõi: wick ATR-cap, buffers/dwell động, re-arm, adaptive exits |
//|  - RN/Spread filters, bias M5 theo slope                         |
//|  - Presets 0..39 như v3.9.0 + NEW batch 40..49                   |
//+------------------------------------------------------------------+
#property strict
#property version   "4.00"
#property description "PTG v4.0.0 – presets 0..49 (18/19 stable; 20..49 batch)"

#include <Trade/Trade.mqh>

//========================== INPUTS ==================================
input group "=== Preset Switch ==="
input int   InpUsecase = 18; // 0=Manual; 15..19=v3.7 family; 20..49=batch

input group "=== General ==="
input long      InpMagic                = 400001;
input double    InpFixedLots            = 0.10;
input double    InpRiskPercent          = 0.0;
input bool      InpAllowShorts          = true;
input bool      InpAllowLongs           = true;

input group "=== PTG Pattern ==="
input int       InpLookback             = 10;
input int       InpPushBars             = 1;         // 1–2
input double    InpPushAvgATRmult       = 0.60;
input double    InpPushMaxATRmult       = 0.80;
input double    InpTestRetrMinPct       = -20.0;
input double    InpTestRetrMaxPct       = 130.0;
input double    InpWickFracBase         = 0.35;      // rule A
input double    InpWickFracAlt          = 0.18;      // rule B
input double    InpWickMinPipsCap       = 12.0;
input bool      InpRequireSweep         = true;
input bool      InpSweepSoftFallback    = true;
input double    InpStrongWickATR        = 0.35;
input double    InpEntryBufferPips      = 3.0;

input group "=== Round Number Filter (XAU) ==="
input bool      InpRoundNumberAvoid     = true;
input double    InpRoundMajorGridPips   = 100.0;
input double    InpRoundMajorBufferPips = 6.0;
input double    InpRoundMinorGridPips   = 50.0;
input double    InpRoundMinorBufferPips = 4.0;

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
input double    InpMaxSpreadPips        = 12.0;
input double    InpMaxSpreadLowVolPips  = 10.0;
input double    InpLowVolThresholdPips  = 95.0;

input group "=== Risk / Exits (floors) ==="
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

//====================== PARAM STRUCT =================================
struct PTGParams {
  long Magic; double FixedLots,RiskPercent; bool AllowShorts,AllowLongs;
  int Lookback,PushBars; double PushAvgATRmult,PushMaxATRmult;
  double TestRetrMinPct,TestRetrMaxPct;
  double WickFracBase,WickFracAlt,WickMinPipsCap;
  bool RequireSweep,SweepSoftFallback; double StrongWickATR,EntryBufferPips;
  bool RoundAvoid; double RNMajGrid,RNMajBuf,RNMinGrid,RNMinBuf;
  bool UseSoftSqueeze; double ATRMinPips; bool M5Bias; int M5EMAPeriod; double M5Slope;
  bool AllowContraBiasOnStrong; bool Blackout; string BOstart,BOend;
  double MaxSpread, MaxSpreadLowVol, LowVolThresh;
  double SL_Fixed,SL_ATRmult,BE_Floor,Partial_Floor,Partial_Perc,TrailStart_Floor,TrailStep_Floor;
  int TimeStopBars; double TimeStopMin; int EarlyCutBars; double EarlyCutFloor;
  bool CB_Enable; int CB_Loss60; int CB_CoolMin; int CB_DailyStop; double CB_MinATRResume;
  bool UsePending; int PendingExpiry; double InvalBufPips; int InvalDwellSec; int AfterCancelCD;
  bool Debug;
};
PTGParams P;

//---------------- helpers (setter ngắn)
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
  P.SL_Fixed=InpSL_Pips_Fixed; P.SL_ATRmult=InpSL_ATR_Mult; P.BE_Floor=InpBE_Pips; P.Partial_Floor=InpPartial_Pips; P.Partial_Perc=InpPartial_Percent;
  P.TrailStart_Floor=InpTrailStart_Pips; P.TrailStep_Floor=InpTrailStep_Pips; P.TimeStopBars=InpTimeStopBars; P.TimeStopMin=InpTimeStopMinProfit;
  P.EarlyCutBars=InpEarlyCutBars; P.EarlyCutFloor=InpEarlyCutAdversePips;
  P.CB_Enable=InpCB_Enable; P.CB_Loss60=InpCB_Losses_60m; P.CB_CoolMin=InpCB_Cooldown_Min; P.CB_DailyStop=InpCB_DailyLossesStop; P.CB_MinATRResume=InpCB_MinATRResume;
  P.UsePending=InpUsePendingStop; P.PendingExpiry=InpPendingExpirySec; P.InvalBufPips=InpInvalidateBufferPips; P.InvalDwellSec=InpInvalidateDwellSec; P.AfterCancelCD=InpAfterCancelCooldownS;
  P.Debug=InpDebug;
}
void SetRN(bool on,double majBuf,double minBuf){ P.RoundAvoid=on; P.RNMajBuf=majBuf; P.RNMinBuf=minBuf; }
void SetSpread(double maxS,double lowS){ P.MaxSpread=maxS; P.MaxSpreadLowVol=lowS; }
void SetPush(double a,double m){ P.PushAvgATRmult=a; P.PushMaxATRmult=m; }
void SetWick(double base,double alt,double strongATR){ P.WickFracBase=base; P.WickFracAlt=alt; P.StrongWickATR=strongATR; }
void SetSL(double fix,double atrm){ P.SL_Fixed=fix; P.SL_ATRmult=atrm; }
void SetBias(bool on,double slope,bool contra=true){ P.M5Bias=on; P.M5Slope=slope; P.AllowContraBiasOnStrong=contra; }
void SetSweep(bool require,bool soft){ P.RequireSweep=require; P.SweepSoftFallback=soft; }
void SetEngine(int dwell,double buf,double cooldown){ P.InvalDwellSec=dwell; P.InvalBufPips=buf; P.AfterCancelCD=cooldown; }
void SetExitFloors(double be,double pp,double ts,double step,double ec){
  P.BE_Floor=be; P.Partial_Floor=pp; P.TrailStart_Floor=ts; P.TrailStep_Floor=step; P.EarlyCutFloor=ec;
}

void ApplyUsecase(int id){
  LoadFromInputs();

  // v3.7 family / stable
  switch(id){
    case 15: SetWick(0.33,0.16,0.30); SetEngine(12,5,45); break;
    case 16: SetPush(0.58,0.78); SetBias(true,25,true); break;
    case 17: SetSL(28,0.50); SetExitFloors(15,20,22,18,12); break;
    case 18: SetRN(true,6,4); SetSpread(12,10); break;
    case 19: SetRN(true,6,4); SetSpread(12,10); break; // 18 + adaptive exits (runtime)
  }

  // Batch 20..29
  if(id>=20 && id<=29){
    SetRN(true,6,4); SetSpread(12,10); SetBias(true,35,true); SetSweep(true,true);
    switch(id){
      case 20: SetWick(0.33,0.16,0.33); SetPush(0.60,0.80); break;
      case 21: SetWick(0.35,0.18,0.33); SetPush(0.58,0.78); SetBias(true,25,true); break;
      case 22: SetWick(0.37,0.20,0.35); SetPush(0.62,0.82); P.ATRMinPips=55; break;
      case 23: SetSL(28,0.50); break;
      case 24: SetRN(true,5,3); break;
      case 25: SetSpread(15,12); SetPush(0.62,0.82); break;
      case 26: SetBias(true,40,false); break;
      case 27: SetSweep(false,true); break;
      case 28: SetRN(false,0,0); break;
      case 29: P.ATRMinPips=60; SetPush(0.58,0.78); break;
    }
  }

  // Batch 30..39
  if(id>=30 && id<=39){
    SetRN(true,6,4); SetSpread(12,10); SetBias(true,35,true); SetSweep(true,true);
    switch(id){
      case 30: SetBias(false,0,true); SetPush(0.60,0.80); break;
      case 31: SetBias(true,45,false); SetPush(0.62,0.82); P.ATRMinPips=55; break;
      case 32: SetRN(true,7,5); break;
      case 33: SetRN(true,4,3); SetBias(true,25,true); break;
      case 34: SetSpread(10,9); break;
      case 35: SetEngine(14,5,60); break;
      case 36: SetEngine(8,5,30); break;
      case 37: SetSweep(true,false); break;
      case 38: SetExitFloors(16,22,24,18,14); SetSL(28,0.50); break;
      case 39: SetExitFloors(12,16,18,14,10); SetSL(24,0.42); break;
    }
  }

  // NEW Batch 40..49
  if(id>=40 && id<=49){
    // nền tảng: RN/Spread strict + adaptive exits
    SetRN(true,6,4); SetSpread(12,10); SetBias(true,35,true); SetSweep(true,true);
    switch(id){
      case 40: // Bias mềm + push base – mở độ phủ
        SetBias(true,20,true); SetPush(0.60,0.80); SetEngine(12,5,45); break;
      case 41: // Không bias + RN cực chặt + push chặt
        SetBias(false,0,true); SetRN(true,7,5); SetPush(0.62,0.82); P.ATRMinPips=55; break;
      case 42: // Chỉ high-vol mạnh
        P.ATRMinPips=70; SetPush(0.64,0.86); SetSweep(true,false); SetBias(true,40,false); SetSpread(11,10); break;
      case 43: // Ưu tiên low-vol (tăng cơ hội)
        P.ATRMinPips=45; SetSpread(15,12); SetPush(0.56,0.76); SetBias(true,25,true); break;
      case 44: // RN bất đối xứng (ưu tiên né Major)
        SetRN(true,8,3); break;
      case 45: // Engine rất kiên nhẫn – giảm hủy
        SetEngine(18,6,75); break;
      case 46: // Engine rất nhanh – scalpy
        SetEngine(6,4,20); SetExitFloors(12,16,18,14,10); SetSL(24,0.42); break;
      case 47: // Momentum-only – ít nhưng “chất”
        SetSpread(10,9); SetPush(0.66,0.90); SetSweep(true,false); SetBias(true,40,false); P.ATRMinPips=55; break;
      case 48: // Trend carry – trail muộn, không contra
        SetExitFloors(16,24,26,18,16); SetSL(28,0.50); SetBias(true,35,false); break;
      case 49: // Protective/mean-revert – early-cut sớm, RN medium
        SetExitFloors(12,18,20,16,8); SetSL(24,0.42); SetRN(true,5,3); SetSweep(false,true); SetBias(false,0,true); SetSpread(13,11); break;
    }
  }

  Print("Preset#",id," | Push ",DoubleToString(P.PushAvgATRmult,2),"/",DoubleToString(P.PushMaxATRmult,2),
        " | Wick ",DoubleToString(P.WickFracBase,2),"/",DoubleToString(P.WickFracAlt,2),
        " | Sweep ",(P.RequireSweep?"ON":"OFF"),(P.SweepSoftFallback?"(soft)":"(hard)"),
        " | RN ",(P.RoundAvoid?"ON":"OFF")," (",DoubleToString(P.RNMajBuf,1),"/",DoubleToString(P.RNMinBuf,1),")",
        " | Spread ",DoubleToString(P.MaxSpread,1),"/",DoubleToString(P.MaxSpreadLowVol,1),
        " | ATRmin ",DoubleToString(P.ATRMinPips,1),
        " | Bias ",(P.M5Bias?"ON":"OFF")," slope=",DoubleToString(P.M5Slope,1),
        " | Engine dwell/buf/cd=",P.InvalDwellSec,"/",DoubleToString(P.InvalBufPips,1),"/",P.AfterCancelCD,
        " | Floors BE/PP/Trail/Step/EC=",P.BE_Floor,"/",P.Partial_Floor,"/",P.TrailStart_Floor,"/",P.TrailStep_Floor,"/",P.EarlyCutFloor);
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
int            gLastDay = -1;

bool           gHasPosition=false; ulong gPosTicket=0; double gPosEntry=0.0, gPosVolume=0.0;
bool           gBE=false, gPartial=false; int gBarsSinceEntry=0;

// exits snapshot
double         gBE_Target=0, gPartial_Target=0, gTrailStart_Target=0, gTrailStep_Target=0, gEarlyCut_Target=0;

ulong          gPendingTicket = 0; bool gPendingIsLong = true;
double         gPendingPrice = 0.0; datetime gPendingExpire=0;
double         gPendingInvalidLevel = 0.0; bool gPendingInvalidIsBelow = true;
datetime       gInvalidStart = 0;
datetime       gLastCancelTime = 0;

// rearm & anti-chop
bool           gRearmSkipCooldown=false;
datetime       gRearmWindowUntil=0;
bool           gRearmDirLong=true;
datetime       gLastEarlyCutTime=0; bool gLastEarlyCutDirLong=true;

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
   int s=sh*60+sm,e=eh*60+em; bool blk=(s<=e)? (now>=s && now<e):(now>=s || now<e);
   if(P.Debug && blk) Print("🌙 BLACKOUT window");  return blk;
}

double ATRpips(){ double b[]; if(CopyBuffer(atr_handle,0,0,16,b)<=0) return 0; ArraySetAsSeries(b,true); return b[0]/Pip(); }

bool SoftSqueezeOK(double &atr_out){
   atr_out=ATRpips(); bool ok=(!P.UseSoftSqueeze)||(atr_out>=P.ATRMinPips);
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

double RetrPct(double ph,double pl,double tclose,bool isLong){
   double r=(ph-pl); if(r<=0) return 0; return isLong? 100.0*((ph-tclose)/r): 100.0*((tclose-pl)/r);
}
double LowerWick(int i){ double bl=MathMin(O(i),C(i)); return bl - L(i); }
double UpperWick(int i){ double bh=MathMax(O(i),C(i)); return H(i) - bh; }

struct Setup{
  bool valid; bool isLong; double entry,sl,invalidLevel; bool invalidIsBelow;
  bool swept; double wickPips,wickFrac,atr,maxRangePips;
};

bool BuildPTG(int idx, Setup &s){
   int pushShift = idx+2-(P.PushBars-1); if(pushShift<2) return false;
   double atr=ATRpips();

   // PUSH
   double ph=-DBL_MAX, pl=DBL_MAX, sumR=0.0, maxR=0.0;
   for(int k=0;k<P.PushBars;k++){ double r=Range(pushShift-k); sumR+=r; if(r>maxR) maxR=r; ph=MathMax(ph,H(pushShift-k)); pl=MathMin(pl,L(pushShift-k)); }
   double avgP=(sumR/P.PushBars)/Pip(), maxP=maxR/Pip();
   bool pushOK=(avgP>=P.PushAvgATRmult*atr) || (maxP>=P.PushMaxATRmult*atr);
   if(!pushOK){ if(P.Debug) Print("⚠️ PUSH too small: avg=",DoubleToString(avgP,1),"p / max=",DoubleToString(maxP,1),"p  need ",
                                   DoubleToString(P.PushAvgATRmult*atr,1)," or ",DoubleToString(P.PushMaxATRmult*atr,1)); return false; }

   int t=idx+1; bool isLong=(C(pushShift)>O(pushShift));
   double retr=RetrPct(ph,pl,C(t),isLong);
   if(retr<P.TestRetrMinPct || retr>P.TestRetrMaxPct){ if(P.Debug) Print("⚠️ TEST retr ",DoubleToString(retr,1),"% out of [",DoubleToString(P.TestRetrMinPct,1),",",DoubleToString(P.TestRetrMaxPct,1),"]"); }

   // Wick rules
   double rng=Range(t); if(rng<=0) return false;
   double wick=isLong? LowerWick(t): UpperWick(t);
   double wickFrac=wick/rng;
   double wickMinA=MathMin(P.WickMinPipsCap, 0.25*atr);
   double wickMinB_raw=MathMax(P.WickMinPipsCap, P.StrongWickATR*atr);
   double wickMinB=MathMin(45.0, wickMinB_raw); // cap 45p
   bool ruleA=(wickFrac>=P.WickFracBase) && ((wick/Pip())>=wickMinA);
   bool ruleB=(wickFrac>=P.WickFracAlt ) && ((wick/Pip())>=wickMinB);
   if(!(ruleA||ruleB)){ if(P.Debug) Print("⚠️ Wick too small: frac=",DoubleToString(100*wickFrac,1),"%, pips=",DoubleToString(wick/Pip(),1),
                       " need A(frac≥",DoubleToString(100*P.WickFracBase,0),"%, p≥",DoubleToString(wickMinA,1),
                       ") OR B(frac≥",DoubleToString(100*P.WickFracAlt,0),"%, p≥",DoubleToString(wickMinB,1),")"); return false; }

   bool swept=isLong? (L(t)<L(t+1)):(H(t)>H(t+1));
   if(P.RequireSweep && !swept){
      bool strong=(maxP>=0.95*atr)||ruleB;
      if(!(P.SweepSoftFallback && strong)){ if(P.Debug) Print("⚠️ No sweep (", (isLong?"long":"short"), ")"); return false; }
   }

   // Entry buffer (ATR-weighted) & RN
   double eb=MathMax(P.EntryBufferPips, MathMin(8.0, 0.04*atr + SpreadPips() + 1.5));
   double phh=0.0, pll=0.0;
   for(int k=0;k<P.PushBars;k++){ phh=MathMax(phh,H(pushShift-k)); pll=(k==0?L(pushShift):MathMin(pll,L(pushShift-k))); }
   double trigger=isLong? (phh+ToPrice(eb)):(pll-ToPrice(eb));
   if(RoundNumberNearby(trigger)) return false;

   // SL dynamic floor
   double dist_pips=MathMax( MathMin(P.SL_Fixed, P.SL_ATRmult*atr), MathMin(32.0, 0.22*atr) );
   s.valid=true; s.isLong=isLong;
   s.entry=NormalizePrice(trigger);
   s.sl=isLong? NormalizePrice(s.entry - ToPrice(dist_pips)) : NormalizePrice(s.entry + ToPrice(dist_pips));
   s.invalidLevel=isLong? L(t): H(t); s.invalidIsBelow=isLong;
   s.swept=swept; s.wickPips=wick/Pip(); s.wickFrac=wickFrac; s.atr=atr; s.maxRangePips=maxP;
   return true;
}

bool M5BiasFavor(const Setup &s){
   if(!P.M5Bias) return true;
   double ema[]; if(CopyBuffer(emaM5_handle,0,0,12,ema)<=0) return true; ArraySetAsSeries(ema,true);
   double slope=(ema[0]-ema[10])/Pip(); bool enforce=(fabs(slope)>=P.M5Slope);
   if(!enforce) return true;
   bool ok = s.isLong ? (slope>0) : (slope<0);
   if(!ok && P.AllowContraBiasOnStrong){
      bool strongWick = (s.wickPips >= MathMax(P.WickMinPipsCap, P.StrongWickATR*s.atr));
      if(s.swept && strongWick) ok=true;
   }
   if(!ok && P.Debug) Print("⛔ M5 bias filter: slope=",DoubleToString(slope,1),"p  blocked ",(s.isLong?"LONG":"SHORT"));
   return ok;
}

bool FindSetup(Setup &s){ for(int i=0;i<P.Lookback;i++) if(BuildPTG(i,s)) return true; return false; }

//======================== ORDERING ==================================
double CalcPositionSize(double sl){
   if(P.FixedLots>0.0 && P.RiskPercent<=0.0) return P.FixedLots;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double risk=MathMax(0.0,P.RiskPercent/100.0)*bal; if(risk<=0) return P.FixedLots;
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID); double dist=fabs(price-sl);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=TickSizeVal(); if(ts<=0) ts=PointSize();
   if(tv<=0||dist<=0) return P.FixedLots;
   double lotPerPoint=tv/ts; double lots=risk/(dist*lotPerPoint);
   double minlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathMax(minlot, MathMin(maxlot,lots)); lots=MathFloor(lots/step)*step; return lots;
}

bool PlacePending(bool isLong, double price, double sl){
   if(!P.UsePending)
      return (isLong? trade.Buy(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0) :
                      trade.Sell(CalcPositionSize(sl), _Symbol, 0.0, sl, 0.0));

   double pt=PointSize(); double stops=StopsLevelPoints()*pt + 2*pt;
   if(isLong){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(price < ask + stops) price = ask + stops; price = RoundUpToTick(price);
      if(price - sl < stops) sl = price - stops; sl = RoundDnToTick(sl);
   }else{
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(price > bid - stops) price = bid - stops; price = RoundDnToTick(price);
      if(sl - price < stops) sl = price + stops; sl = RoundUpToTick(sl);
   }
   price=NormalizePrice(price); sl=NormalizePrice(sl);

   datetime now=TimeCurrent();
   bool cooldownActive = (now - gLastCancelTime < P.AfterCancelCD);
   if(cooldownActive && !(gRearmSkipCooldown && now <= gRearmWindowUntil)){
      if(P.Debug) Print("⏳ Cooldown after cancel: skip new pending");
      return false;
   }
   if(gRearmSkipCooldown && now <= gRearmWindowUntil) gRearmSkipCooldown=false;

   datetime exp = now + P.PendingExpiry;
   bool ok = isLong? trade.BuyStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp)
                   : trade.SellStop(CalcPositionSize(sl), price, _Symbol, sl, 0.0, 0, exp);
   if(ok){
      gPendingTicket = (ulong)trade.ResultOrder();
      gPendingIsLong = isLong; gPendingPrice=price; gPendingExpire=exp; gInvalidStart=0;
      if(P.Debug) Print("📝 Pending ",(isLong?"BUY STOP ":"SELL STOP "),"@",
                         DoubleToString(price,gDigits)," SL=",DoubleToString(sl,gDigits),
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
   gRearmSkipCooldown=true; gRearmWindowUntil=TimeCurrent()+60; gRearmDirLong=gPendingIsLong;
   if(P.Debug) Print("🧹 Structure invalidated – cancel pending (re-arm window 60s)");
}

//===================== ADAPTIVE EXITS ===============================
void ComputeAdaptiveExits(double atr, double &be,double &pp,double &ts,double &step,double &ec){
   be   = MathMin(22.0, MathMax(P.BE_Floor,        0.10*atr));
   pp   = MathMin(30.0, MathMax(P.Partial_Floor,   0.15*atr));
   ts   = MathMin(36.0, MathMax(P.TrailStart_Floor,0.20*atr));
   step = MathMin(26.0, MathMax(P.TrailStep_Floor, 0.12*atr));
   ec   = MathMin(40.0, MathMax(P.EarlyCutFloor,   0.22*atr));
}

//===================== POSITION MANAGEMENT ==========================
void ResetPos(){ gHasPosition=false; gPosTicket=0; gPosEntry=0; gPosVolume=0; gBE=false; gPartial=false; gBarsSinceEntry=0; }
void AfterOpenSync(){
   gHasPosition=true; gPosTicket=(ulong)PositionGetInteger(POSITION_TICKET);
   gPosEntry=PositionGetDouble(POSITION_PRICE_OPEN); gPosVolume=PositionGetDouble(POSITION_VOLUME);
   gBarsSinceEntry=0; gBE=false; gPartial=false; CancelPendingIfAny();
   double atr=ATRpips(); ComputeAdaptiveExits(atr,gBE_Target,gPartial_Target,gTrailStart_Target,gTrailStep_Target,gEarlyCut_Target);
   if(P.Debug) Print("🎚 Adaptive exits @entry ATR=",DoubleToString(atr,1),"p  BE=",gBE_Target,"  PP=",gPartial_Target,"  Trail=",gTrailStart_Target,"/",gTrailStep_Target,"  EC=",gEarlyCut_Target);
}

void ManagePosition(){
   if(!gHasPosition) return;
   if(!PositionSelect(_Symbol)){ ResetPos(); return; }
   long type=(long)PositionGetInteger(POSITION_TYPE);
   double px=(type==POSITION_TYPE_BUY)? SymbolInfoDouble(_Symbol,SYMBOL_BID): SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double pips=(type==POSITION_TYPE_BUY)? (px-gPosEntry)/Pip() : (gPosEntry-px)/Pip();
   gBarsSinceEntry++;

   if(gBarsSinceEntry<=P.EarlyCutBars && pips <= -gEarlyCut_Target){
      if(P.Debug) Print("✂️ Early-cut ",DoubleToString(pips,1),"p (target ",gEarlyCut_Target,")");
      gLastEarlyCutTime=TimeCurrent(); gLastEarlyCutDirLong=(type==POSITION_TYPE_BUY);
      trade.PositionClose(_Symbol); return;
   }

   if(gBarsSinceEntry>=P.TimeStopBars && pips < P.TimeStopMin){ trade.PositionClose(_Symbol); if(P.Debug) Print("⏹ Time-stop"); return; }

   if(!gPartial && pips >= gPartial_Target){
      double vol=PositionGetDouble(POSITION_VOLUME);
      double minv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
      double closeVol=MathMax(minv, NormalizeDouble(vol*P.Partial_Perc/100.0,2));
      trade.PositionClosePartial(_Symbol,closeVol); gPartial=true; if(P.Debug) Print("💰 Partial ",DoubleToString(closeVol,2)); return;
   }
   if(!gBE && pips >= gBE_Target){
      double sl=(type==POSITION_TYPE_BUY)? (gPosEntry+ToPrice(SpreadPips())):(gPosEntry-ToPrice(SpreadPips()));
      trade.PositionModify(_Symbol,NormalizePrice(sl),0.0); gBE=true; if(P.Debug) Print("🛡️ Move BE");
   }
   if(pips>=gTrailStart_Target){
      double trail=ToPrice(gTrailStep_Target); double newSL=(type==POSITION_TYPE_BUY)? (px-trail):(px+trail);
      if( (type==POSITION_TYPE_BUY && newSL>PositionGetDouble(POSITION_SL)) || (type==POSITION_TYPE_SELL && newSL<PositionGetDouble(POSITION_SL)) )
         trade.PositionModify(_Symbol,NormalizePrice(newSL),0.0);
   }
}

//===================== CIRCUIT BREAKER & HISTORY ====================
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
      ulong d=HistoryDealGetTicket(i); if(d==0 || d==gLastProcessedDeal) break;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      long mg=(long)HistoryDealGetInteger(d,DEAL_MAGIC); if((ulong)mg!=gMagic) continue;
      if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);
      if(p<0) NoteLoss(); else NoteWin(); gLastProcessedDeal=d; break;
   }
}

//=========================== EVENTS =================================
int OnInit(){
   ApplyUsecase(InpUsecase);
   gPip=Pip(); gDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); gMagic=(ulong)InpMagic; trade.SetExpertMagicNumber((uint)gMagic);
   atr_handle=iATR(_Symbol,PERIOD_CURRENT,14); emaM5_handle=iMA(_Symbol,PERIOD_M5,P.M5EMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(atr_handle==INVALID_HANDLE || emaM5_handle==INVALID_HANDLE){ Print("Indicator init failed"); return INIT_FAILED; }
   gLastBarTime=iTime(_Symbol,PERIOD_CURRENT,0); EventSetTimer(1);
   Print("PTG v4.0.0 ready. Pip=",DoubleToString(gPip,5)); return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle); if(emaM5_handle!=INVALID_HANDLE) IndicatorRelease(emaM5_handle); CancelPendingIfAny(); }

void OnTimer(){
   if(gPendingTicket!=0){
      datetime now=TimeCurrent();
      if(now>gPendingExpire){ if(P.Debug) Print("⌛ Pending expired – cancel"); CancelPendingIfAny(); return; }
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double px = gPendingInvalidIsBelow? bid : ask;
      double atr=ATRpips();
      double dynBuf=MathMax(P.InvalBufPips, 0.06*atr);
      int    dynDwell=(int)MathMax(P.InvalDwellSec, MathFloor(8 + 0.05*atr));
      double buffer=ToPrice(dynBuf);
      bool beyond = gPendingInvalidIsBelow ? (px < gPendingInvalidLevel - buffer) : (px > gPendingInvalidLevel + buffer);
      if(beyond){ if(gInvalidStart==0) gInvalidStart=now; if(now - gInvalidStart >= dynDwell) CancelPendingIfAny(); }
      else gInvalidStart=0;
   }
}

void OnTick(){ MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return; datetime bt=iTime(_Symbol,PERIOD_CURRENT,0); if(bt!=gLastBarTime){ gLastBarTime=bt; OnNewBar(); } }

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

   // anti-chop sau early-cut: block 5 phút cùng hướng
   if(gLastEarlyCutTime>0 && (TimeCurrent()-gLastEarlyCutTime)<=300 && (s.isLong==gLastEarlyCutDirLong)){
      if(P.Debug) Print("🧯 Skip re-entry 5m after early-cut (same dir)");
      return;
   }

   if(gRearmWindowUntil>0 && TimeCurrent()<=gRearmWindowUntil){ if(s.isLong==gRearmDirLong) gRearmSkipCooldown=true; }

   gPendingInvalidLevel=s.invalidLevel; gPendingInvalidIsBelow=s.invalidIsBelow;
   PlacePending(s.isLong, s.entry, s.sl);
}
//+------------------------------------------------------------------+
