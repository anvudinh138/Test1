//+------------------------------------------------------------------+
//|                                                PTG_VSA_Momentum   |
//|                           Push–Test–Go + VSA (real-ticks tuned)    |
//|   v1.0.0                                                           |
//|   Notes:                                                           |
//|   - Single-file EA, no custom indicators required                  |
//|   - Works best on XAUUSD M1 real-ticks                             |
//|   - Two presets included: HUNTER-A (72), HUNTER-B (73)             |
//+--------------------------------------------------------------------+
#property copyright "PTG x VSA – public test build"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//========================= INPUTS ====================================
input group "=== Preset ==="
input int   InpUsecase                  = 72;   // 70..73 (72=Hunter-A, 73=Hunter-B)

input group "=== Risk & Lots ==="
input double InpFixedLots               = 0.10;
input double InpRiskPercent             = 0.20; // 0.10..0.30 typical
input long   InpMagic                   = 720073;

input group "=== VSA Core ==="
input int    InpVSA_Window              = 120;  // bars for median/quantile
input double InpVolSpikeMult            = 1.80; // vol / medianVol
input double InpWideSpreadQuantile      = 0.70; // 0..1, e.g. 0.70 = 70th percentile
input double InpWickRatioMin            = 0.70; // max(wick)/spread
input double InpLowVolRatio             = 0.80; // “no demand/supply” threshold (vol/median)

input group "=== Momentum (PTG-lite) ==="
input int    InpPushBars                = 2;    // lookback bars for push
input double InpPushScoreMin            = 0.90; // avg(range)/ATR over PushBars
input int    InpMomFast                 = 6;    // EMA slope fast
input int    InpMomSlow                 = 24;   // EMA slope slow

input group "=== Liquidity & Gates ==="
input bool   InpUseSoftSqueeze          = true;
input double InpATRfloorK               = 0.70; // ATR must be >= k * medianATR
input double InpMaxSpreadATR            = 0.30; // allow if spread <= k * ATR
input double InpRN_DistPipsMin          = 1.00; // minimal distance from RN (pips)
input double InpRN_DistATR              = 0.15; // extra RN distance = k*ATR

input group "=== Order Engine ==="
input bool   InpUsePending              = true;
input int    InpPendingExpirySec        = 60;
input double InpEntryBufferPips         = 0.8;
input double InpSL_ATRmult              = 0.90; // SL = max(3*spread, mult*ATR)
input double InpTP_R_Ratio              = 1.20; // partial take-profit at R
input double InpTrail_ATRmult           = 2.50; // Chandelier

input group "=== Sessions (UTC) ==="
input bool   InpUseSession              = true;
input string InpSessStart               = "12:00";
input string InpSessEnd                 = "17:00";

input group "=== Debug ==="
input bool   InpDebug                   = true;

// === Round Number (RN) dynamic buffer ===
input double InpRN_MinPips  = 0.8;   // sàn tuyệt đối (pips) cách RN
input double InpRN_ATRfrac  = 0.10;  // hệ số ATR cho RN buffer (buf = max(MinPips, ATRfrac*ATR))


//======================== GLOBALS ====================================
CTrade   trade;
ulong    gMagic;
double   gPip;  int gDigits;
int      atrH = INVALID_HANDLE, emaFastH = INVALID_HANDLE, emaSlowH = INVALID_HANDLE;
datetime gLastBar = 0;

struct Params {
  // derived thresholds (dynamic)
  double ATRp, MedianATRp;
} Pdyn;

struct Setup {
  bool valid; bool isLong;
  double entry, sl;
  double testLow, testHigh;
  double atr;
};

//======================== UTILS ======================================
double Pip() { string s=_Symbol;
  if(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0) return 0.01;
  int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
  double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  if(d==5||d==3) return 10*pt; return pt;
}
double ToPrice(double pips){ return pips*Pip(); }
double SpreadPips(){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); return (ask-bid)/Pip(); }
double NormalizePrice(double p){ return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
double RangePips(int i){ return (iHigh(_Symbol,PERIOD_CURRENT,i)-iLow(_Symbol,PERIOD_CURRENT,i))/Pip(); }
double BodyPips(int i){ return MathAbs(iClose(_Symbol,PERIOD_CURRENT,i)-iOpen(_Symbol,PERIOD_CURRENT,i))/Pip(); }
double MaxWickOverSpread(int i){
  double H=iHigh(_Symbol,PERIOD_CURRENT,i), L=iLow(_Symbol,PERIOD_CURRENT,i);
  double O=iOpen(_Symbol,PERIOD_CURRENT,i), C=iClose(_Symbol,PERIOD_CURRENT,i);
  double spread=H-L; if(spread<=0) return 0;
  double upper=H-MathMax(O,C), lower=MathMin(O,C)-L;
  return MathMax(upper,lower)/spread;
}

void HHMM(string ss,int &h,int &m){ h=0;m=0; string a[]; if(StringSplit(ss,':',a)>=2){ h=(int)StringToInteger(a[0]); m=(int)StringToInteger(a[1]); } }
bool InSession(){
  if(!InpUseSession) return true;
  MqlDateTime t; TimeToStruct(TimeCurrent(),t); int now=t.hour*60+t.min;
  int sh, sm, eh, em; HHMM(InpSessStart,sh,sm); HHMM(InpSessEnd,eh,em);
  int s=sh*60+sm, e=eh*60+em;
  return (s<=e)? (now>=s && now<e):(now>=s || now<e);
}

// Quantile of recent range in pips
double QuantileRangePips(int window,double q){
  int n=MathMin(window, (int)iBars(_Symbol,PERIOD_CURRENT));
  if(n<5) return 0;
  double arr[]; ArrayResize(arr,n-1);
  for(int i=1;i<n;i++) arr[i-1]=RangePips(i);
  ArraySort(arr);
  int idx=(int)MathFloor((n-2)*MathMax(0.0,MathMin(1.0,q)));
  idx= MathMax(0, MathMin(idx, n-2));
  return arr[idx];
}
double Median(double &arr[]){
  int n=ArraySize(arr); if(n==0) return 0;
  double tmp[]; ArrayCopy(tmp,arr); ArraySort(tmp);
  if(n%2==0) return 0.5*(tmp[n/2-1]+tmp[n/2]); else return tmp[n/2];
}
double MedianVol(int window){
  int n=MathMin(window,(int)iBars(_Symbol,PERIOD_CURRENT));
  if(n<5) return 0;
  double v[]; ArrayResize(v,n-1);
  for(int i=1;i<n;i++) v[i-1]=(double)iVolume(_Symbol,PERIOD_CURRENT,i);
  return Median(v);
}
double MedianATRpips(int window){
  double a[]; ArrayResize(a, window);
  int copied = CopyBuffer(atrH,0,1,window,a);
  if(copied<=0) return 0;
  ArraySetAsSeries(a,true);
  for(int i=0;i<window;i++) a[i]/=Pip();
  return Median(a);
}

bool RNTooClose(double price,double atrp){
  // use grids at 50 & 100 pips
  double pips=price/Pip();
  double distMaj = MathAbs(pips - MathRound(pips/100.0)*100.0);
  double distMin = MathAbs(pips - MathRound(pips/50.0)*50.0);
  double need = MathMax(g_RN_DistPipsMin, g_RN_DistATR*atrp);
  return (distMaj<=need || distMin<=need);
}

//======================= DYNAMIC STATE ===============================
void RefreshDynamic(){
  double a[]; if(CopyBuffer(atrH,0,0,3,a)<=0){ Pdyn.ATRp=0; Pdyn.MedianATRp=0; return; }
  Pdyn.ATRp = a[0]/Pip();
  Pdyn.MedianATRp = MedianATRpips(MathMax(30, InpVSA_Window));
}

//========================= PATTERN LOGIC =============================
double PushScore(int bars,double atrp){
  bars = MathMax(1,bars);
  double sum=0; for(int k=0;k<bars;k++) sum += RangePips(1+k);
  return (sum/bars)/MathMax(1e-6, atrp);
}

bool VSA_OK_Long(int testShift,double atrp){
  // push bar bullish and wide spread
  double q = QuantileRangePips(InpVSA_Window, g_WideSpreadQuantile);
  bool pushWide = RangePips(testShift+1) >= q;
  bool pushBull = iClose(_Symbol,PERIOD_CURRENT,testShift+1) > iOpen(_Symbol,PERIOD_CURRENT,testShift+1);
  // test: down bar, lower volume, narrow-ish spread, decent wick ratio (spring)
  double volMed = MedianVol(InpVSA_Window);
  double vTest  = (double)iVolume(_Symbol,PERIOD_CURRENT,testShift);
  bool lowVol   = (volMed>0 && vTest <= InpLowVolRatio*volMed);
  bool downBar  = iClose(_Symbol,PERIOD_CURRENT,testShift) < iOpen(_Symbol,PERIOD_CURRENT,testShift);
  bool wickOK   = (MaxWickOverSpread(testShift) >= g_WickRatioMin);
  bool cond = pushWide && pushBull && lowVol && downBar && wickOK;
  if(InpDebug && cond==false){
    Print("VSA long fail | q=",DoubleToString(q,1)," testVol=",vTest," med=",volMed," wick=",DoubleToString(MaxWickOverSpread(testShift),2));
  }
  return cond;
}

bool VSA_OK_Short(int testShift,double atrp){
  double q = QuantileRangePips(InpVSA_Window, g_WideSpreadQuantile);
  bool pushWide = RangePips(testShift+1) >= q;
  bool pushBear = iClose(_Symbol,PERIOD_CURRENT,testShift+1) < iOpen(_Symbol,PERIOD_CURRENT,testShift+1);
  double volMed = MedianVol(InpVSA_Window);
  double vTest  = (double)iVolume(_Symbol,PERIOD_CURRENT,testShift);
  bool lowVol   = (volMed>0 && vTest <= InpLowVolRatio*volMed);
  bool upBar    = iClose(_Symbol,PERIOD_CURRENT,testShift) > iOpen(_Symbol,PERIOD_CURRENT,testShift);
  bool wickOK   = (MaxWickOverSpread(testShift) >= g_WickRatioMin);
  bool cond = pushWide && pushBear && lowVol && upBar && wickOK;
  if(InpDebug && cond==false){
    Print("VSA short fail | q=",DoubleToString(q,1)," testVol=",vTest," med=",volMed," wick=",DoubleToString(MaxWickOverSpread(testShift),2));
  }
  return cond;
}

bool BuildSetup(Setup &s){
  s.valid=false;
  RefreshDynamic();
  double atrp = Pdyn.ATRp;
  if(InpUseSoftSqueeze){
    double need = g_ATRfloorK * MathMax(1e-6, Pdyn.MedianATRp);
    if(atrp < need){ if(InpDebug) Print("BLOCK: soft-squeeze ATR=",DoubleToString(atrp,1)," < need ",DoubleToString(need,1)); return false; }
  }
  if(!InSession()){ if(InpDebug) Print("BLOCK: out of session"); return false; }
  // Spread gate
  if(SpreadPips() > InpMaxSpreadATR*atrp){ if(InpDebug) Print("BLOCK: spread ",DoubleToString(SpreadPips(),2)," > ",DoubleToString(InpMaxSpreadATR*atrp,2)); return false; }
  // Momentum gate (push score)
  double ps = PushScore(InpPushBars, atrp);
  if(ps < g_PushScoreMin){ if(InpDebug) Print("BLOCK: pushScore ",DoubleToString(ps,2)," < ",DoubleToString(g_PushScoreMin,2)); return false; }

  // Test bar is current closed bar (shift 1); push is 1..PushBars ahead
  int t=1;
  bool longOK  = VSA_OK_Long(t, atrp);
  bool shortOK = VSA_OK_Short(t, atrp);
  if(!(longOK||shortOK)) return false;

  // Direction choice by EMAs slope if both true; else whichever valid
  double eF[], eS[];
  ArraySetAsSeries(eF,true); ArraySetAsSeries(eS,true);
  bool emaOK = (CopyBuffer(emaFastH,0,0,20,eF)>0 && CopyBuffer(emaSlowH,0,0,20,eS)>0);
  double slope = 0.0; if(emaOK) slope = (eF[0]-eF[10])/Pip() - (eS[0]-eS[10])/Pip();

  bool isLong = longOK;
  if(longOK && shortOK){ isLong = (slope>=0); }
  if(!longOK && shortOK) isLong=false;

  double testH=iHigh(_Symbol,PERIOD_CURRENT,t), testL=iLow(_Symbol,PERIOD_CURRENT,t);
  double ebp = MathMax(InpEntryBufferPips, 0.04*atrp + SpreadPips());
  double entry = isLong? (testH + ToPrice(ebp)) : (testL - ToPrice(ebp));
  if(RNTooClose(entry, atrp)){ if(InpDebug) Print("BLOCK: RN too close"); return false; }

  double sl = isLong? (entry - ToPrice(MathMax(3*SpreadPips(), g_SL_ATRmult*atrp)))
                    : (entry + ToPrice(MathMax(3*SpreadPips(), g_SL_ATRmult*atrp)));

  s.valid=true; s.isLong=isLong; s.entry=NormalizePrice(entry); s.sl=NormalizePrice(sl);
  s.testLow=testL; s.testHigh=testH; s.atr=atrp;
  return true;
}

//======================== ORDERING ===================================
double VolumeStep(){ return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); }
double MinLot(){ return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN); }
double MaxLot(){ return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX); }

double CalcLotByRisk(double sl_price){
  if(g_RiskPercent<=0) return InpFixedLots;
  double bal=AccountInfoDouble(ACCOUNT_BALANCE);
  double risk = bal * g_RiskPercent/100.0;
  double price=(SymbolInfoDouble(_Symbol,SYMBOL_BID)+SymbolInfoDouble(_Symbol,SYMBOL_ASK))*0.5;
  double dist=MathAbs(price-sl_price); if(dist<=0) return InpFixedLots;
  double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(ts<=0) ts=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  if(tv<=0) return InpFixedLots;
  double lotPerPoint = tv/ts;
  double lots = risk/(dist*lotPerPoint);
  double step=VolumeStep();
  lots = MathMax(MinLot(), MathMin(MaxLot(), lots));
  lots = MathFloor(lots/step)*step;
  return lots;
}

double SafeLot(bool isLong,double desired,double price){
  double step=VolumeStep(); double vol=desired;
  double need=0.0; ENUM_ORDER_TYPE type=isLong? ORDER_TYPE_BUY:ORDER_TYPE_SELL;
  for(int i=0;i<12;i++){
    if(vol<MinLot()) break;
    if(OrderCalcMargin(type,_Symbol,vol,price,need)){
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= need*1.12) break;
    }
    vol=MathFloor((vol-step)/step)*step;
  }
  return MathMax(0.0, vol);
}

bool PlaceOrder(const Setup &s){
  double lot = CalcLotByRisk(s.sl);
  lot = SafeLot(s.isLong, lot, s.entry);
  if(lot < MinLot()){ if(InpDebug) Print("Skip: not enough margin @min lot"); return false; }

  // Expiry
  datetime exp = TimeCurrent()+InpPendingExpirySec;
  bool ok=false;
  if(InpUsePending){
    if(s.isLong){
      ok = trade.BuyStop(lot, s.entry, _Symbol, s.sl, 0.0, 0, exp);
    }else{
      ok = trade.SellStop(lot, s.entry, _Symbol, s.sl, 0.0, 0, exp);
    }
  }else{
    if(s.isLong) ok=trade.Buy(lot,_Symbol,0.0,s.sl,0.0); else ok=trade.Sell(lot,_Symbol,0.0,s.sl,0.0);
  }
  if(InpDebug) Print("SEND ",(s.isLong?"BUY":"SELL")," at ",DoubleToString(s.entry,gDigits)," SL=",DoubleToString(s.sl,gDigits),
                     " lot=",DoubleToString(lot,2)," exp=",TimeToString(exp,TIME_SECONDS));
  return ok;
}

//======================== POSITION MGMT ==============================
bool HasPosition(){
  if(!PositionSelect(_Symbol)) return false;
  return (PositionGetInteger(POSITION_MAGIC)==(long)gMagic);
}
void ManagePosition(){
  if(!HasPosition()) return;
  long type = (long)PositionGetInteger(POSITION_TYPE);
  double entry=PositionGetDouble(POSITION_PRICE_OPEN);
  double vol  = PositionGetDouble(POSITION_VOLUME);
  double px   = (type==POSITION_TYPE_BUY)? SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  double sl   = PositionGetDouble(POSITION_SL);
  // partial at R
  double riskPips = MathAbs(entry-sl)/Pip();
  double rrPips   = g_TP_R_Ratio * riskPips;
  double bePx     = (type==POSITION_TYPE_BUY)? (entry+ToPrice(SpreadPips())):(entry-ToPrice(SpreadPips()));
  // move to BE
  if( ((type==POSITION_TYPE_BUY) && (px-entry)/Pip() >= rrPips) ||
      ((type==POSITION_TYPE_SELL)&& (entry-px)/Pip() >= rrPips) ){
    // BE
    trade.PositionModify(_Symbol, NormalizePrice(bePx), 0.0);
  }
  // chandelier trail
  RefreshDynamic();
  double trail = g_TrailATRmult * Pdyn.ATRp;
  double newSL = (type==POSITION_TYPE_BUY)? (px - ToPrice(trail)) : (px + ToPrice(trail));
  if( (type==POSITION_TYPE_BUY && newSL>sl) || (type==POSITION_TYPE_SELL && newSL<sl) ){
    trade.PositionModify(_Symbol, NormalizePrice(newSL), 0.0);
  }
}

//======================= PRESETS =====================================
// Global variables to hold the dynamic values
double g_VolSpikeMult, g_WideSpreadQuantile, g_WickRatioMin, g_PushScoreMin;
double g_ATRfloorK, g_RN_DistPipsMin, g_RN_DistATR, g_SL_ATRmult;
double g_TP_R_Ratio, g_TrailATRmult, g_RiskPercent;

void ApplyUsecase(const int id){
  // --- start from current inputs (baseline) ---
  g_PushScoreMin        = InpPushScoreMin;
  g_VolSpikeMult        = InpVolSpikeMult;
  g_ATRfloorK           = InpATRfloorK;
  g_RN_DistATR          = InpRN_DistATR;
  g_RN_DistPipsMin      = InpRN_MinPips;
  g_WickRatioMin        = InpWickRatioMin;
  g_WideSpreadQuantile  = InpWideSpreadQuantile;

  // Notes for gating that still read inputs directly (cannot be overridden here):
  // - InpUseSession / InpSessStart / InpSessEnd (set in EA inputs)
  // - InpLowVolRatio (VSA "low volume" threshold)
  // - InpUseSoftSqueeze (Soft-squeeze on/off)
  // - InpMaxSpreadATR    (spread <= ATRp * InpMaxSpreadATR)

  // 70..74 = "HUNTER" family for real-ticks (looser gates; let price express; manage risk later)
  if(id==70){ // HUNTER-L (aggressive)
     g_ATRfloorK          = 0.58;     // allow thinner regimes
     g_PushScoreMin       = 0.78;     // accept moderate pushes
     g_VolSpikeMult       = 1.45;     // still want some momentum confirmation
     g_WideSpreadQuantile = 0.62;     // treat 62%ile as "wide" (more bars qualify)
     g_WickRatioMin       = 0.45;     // wick/spread relaxed
     g_RN_DistATR         = 0.10;     // less RN avoidance
     g_RN_DistPipsMin     = 0.50;
  }
  else if(id==71){ // HUNTER-M (balanced-aggressive)
     g_ATRfloorK          = 0.60;
     g_PushScoreMin       = 0.80;
     g_VolSpikeMult       = 1.55;
     g_WideSpreadQuantile = 0.66;
     g_WickRatioMin       = 0.48;
     g_RN_DistATR         = 0.12;
     g_RN_DistPipsMin     = 0.60;
  }
  else if(id==72){ // HUNTER-B (balanced)
     g_ATRfloorK          = 0.62;
     g_PushScoreMin       = 0.82;
     g_VolSpikeMult       = 1.60;
     g_WideSpreadQuantile = 0.68;
     g_WickRatioMin       = 0.50;
     g_RN_DistATR         = 0.12;
     g_RN_DistPipsMin     = 0.80;
  }
  else if(id==73){ // HUNTER-S (strict)
     g_ATRfloorK          = 0.65;
     g_PushScoreMin       = 0.85;
     g_VolSpikeMult       = 1.70;
     g_WideSpreadQuantile = 0.70;
     g_WickRatioMin       = 0.55;
     g_RN_DistATR         = 0.14;
     g_RN_DistPipsMin     = 1.00;
  }
  else if(id==74){ // HUNTER-MO (momentum-only bias)
     g_ATRfloorK          = 0.55;     // very permissive on regime
     g_PushScoreMin       = 0.86;     // but demand strong push to trade
     g_VolSpikeMult       = 1.75;
     g_WideSpreadQuantile = 0.72;
     g_WickRatioMin       = 0.40;     // wick/spread not strict (breakouts)
     g_RN_DistATR         = 0.10;
     g_RN_DistPipsMin     = 0.50;
  }

  Print("UC#",id,
        " | push>=",DoubleToString(g_PushScoreMin,2),
        " | Vspike>=",DoubleToString(g_VolSpikeMult,2),
        " | ATRfloor=",DoubleToString(g_ATRfloorK,2),"×median",
        " | RNdist=",DoubleToString(g_RN_DistATR,2),"×ATR/",DoubleToString(g_RN_DistPipsMin,1),"p",
        " | wick/spread>=",DoubleToString(g_WickRatioMin,2),
        " | wideQ=",DoubleToString(g_WideSpreadQuantile,2),
        " | NOTE: InpUseSession=", (InpUseSession? "ON":"OFF"),
        " InpLowVolRatio=", DoubleToString(InpLowVolRatio,2),
        " InpMaxSpreadATR=", DoubleToString(InpMaxSpreadATR,2));
}

//======================== EVENTS =====================================
int OnInit(){
  ApplyUsecase(InpUsecase);
  gPip=Pip(); gDigits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); gMagic=(ulong)InpMagic;
  trade.SetExpertMagicNumber((uint)gMagic);
  atrH = iATR(_Symbol, PERIOD_CURRENT, 14);
  emaFastH = iMA(_Symbol, PERIOD_CURRENT, InpMomFast, 0, MODE_EMA, PRICE_CLOSE);
  emaSlowH = iMA(_Symbol, PERIOD_CURRENT, InpMomSlow, 0, MODE_EMA, PRICE_CLOSE);
  if(atrH==INVALID_HANDLE || emaFastH==INVALID_HANDLE || emaSlowH==INVALID_HANDLE){
    Print("Indicator init failed"); return INIT_FAILED;
  }
  gLastBar = iTime(_Symbol,PERIOD_CURRENT,0);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
  if(atrH!=INVALID_HANDLE) IndicatorRelease(atrH);
  if(emaFastH!=INVALID_HANDLE) IndicatorRelease(emaFastH);
  if(emaSlowH!=INVALID_HANDLE) IndicatorRelease(emaSlowH);
}

void OnTick(){
  // manage open position
  ManagePosition();
  // new bar?
  datetime bt = iTime(_Symbol,PERIOD_CURRENT,0);
  if(bt==gLastBar) return;
  gLastBar=bt;

  // if pending exists, do nothing (let expiry handle)
  // simple check
  for(int i=0;i<OrdersTotal();++i){
    ulong ticket = OrderGetTicket(i);
    if(OrderSelect(ticket)){
      if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_TYPE)<=ORDER_TYPE_SELL_STOP){
        if(OrderGetInteger(ORDER_MAGIC)==(long)gMagic) return;
      }
    }
  }

  // build setup and place order
  Setup s; if(!BuildSetup(s)) return;
  PlaceOrder(s);
}
//+------------------------------------------------------------------+
