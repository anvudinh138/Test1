//+------------------------------------------------------------------+
//|                                        XAU_SweepBOS_EA_v1_final  |
//|     Sweep -> BOS (XAUUSD M1) | Final v1 with top presets (101..) |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS Final v1"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//============================== INPUTS ==============================//
input string InpSymbol           = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;

// Preset control
input bool   UsePreset           = true;       // dùng preset hay không
input int    PresetID            = 101;        // 0=custom; 101..108 = final v1 winners

// Switches (khi UsePreset=false, dùng các input này)
input bool   EnableLong          = true;
input bool   EnableShort         = true;

// Sweep/BOS core
input int    K_swing             = 50;
input int    N_bos               = 6;
input int    LookbackInternal    = 12;
input double EqTol               = 0.20;    // USD
input double BOSBufferPoints     = 2.0;     // points

// Retest/Entry (nới lỏng + fallback)
input int    M_retest_input      = 6;       // số bar cho retest
input double RetestTouchUSD      = 0.05;    // chỉ cần wick chạm ±x USD quanh BOS
input bool   RequireRetestClose  = false;   // true = phải close đúng phía
input bool   EnterIfNoRetest     = true;    // fallback: nếu không retest, vẫn vào
input int    EnterIfNoRetestBars = 1;       // số bar sau BOS để vào nếu không retest

// Filters
input bool   UseKillzones_input  = true;
input bool   InpIgnoreKZ         = true;    // true = bỏ qua KZ (test baseline)
input int    KZ_Shift_Min        = 0;       // dịch toàn bộ KZ theo phút (theo giờ server)
input bool   UseRoundNumber      = true;
input bool   UseVSA              = false;
input int    L_percentile        = 150;
input double RNDelta             = 0.30;    // USD

// Killzones (server time, minutes from 00:00). All zero => off
input int    KZ1_StartMin        = 13*60+55;
input int    KZ1_EndMin          = 14*60+25;
input int    KZ2_StartMin        = 16*60+25;
input int    KZ2_EndMin          = 16*60+45;
input int    KZ3_StartMin        = 19*60+20;
input int    KZ3_EndMin          = 19*60+50;
input int    KZ4_StartMin        = 20*60+55;
input int    KZ4_EndMin          = 21*60+20;

// Risk & money
input double RiskPerTradePct     = 0.5;
input double SL_BufferUSD        = 0.60;
input double TP1_R               = 1.0;
input double TP2_R               = 2.0;
input double BE_Activate_R       = 0.8;
input double PartialClosePct     = 50.0;
input int    TimeStopMinutes     = 5;
input double MinProgressR        = 0.5;

// Execution guards
input double MaxSpreadUSD        = 0.50;
input int    MaxOpenPositions    = 1;

// Entry style (pending)
input bool   UsePendingRetest    = false;
input double RetestOffsetUSD     = 0.07;
input int    PendingExpirySec    = 60;

// Debug
input bool   Debug               = true;

//============================= GLOBALS ==============================//
CTrade   trade;
MqlRates rates[];
datetime last_bar_time = 0;

enum StateEnum { ST_IDLE=0, ST_BOS_CONF };
StateEnum state = ST_IDLE;

bool     bosIsShort = false;
double   bosLevel   = 0.0;
datetime bosBarTime = 0;
double   sweepHigh  = 0.0;
double   sweepLow   = 0.0;

// Debug counters
int cntBlockRN=0, cntBlockKZ=0, cntBlockSpread=0;
int cntArmed=0, cntRetestHit=0, cntNoRetest=0, cntLotsZero=0, cntMaxPosHit=0, cntSpreadAtEntry=0;

// Preset container
struct Params {
   bool   EnableLong, EnableShort;
   int    K_swing, N_bos, LookbackInternal, M_retest;
   double EqTol, BOSBufferPoints;
   bool   UseKillzones, UseRoundNumber, UseVSA;
   int    L_percentile; double RNDelta;
   int    KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
   double RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
   int    TimeStopMinutes; double MinProgressR;
   double MaxSpreadUSD; int MaxOpenPositions;
   bool   UsePendingRetest; double RetestOffsetUSD; int PendingExpirySec;
};
Params P;

//====================== UTILS: PRINTING / KZ ========================//
string MinToHHMM(int m){
   if(m<=0) return "00:00";
   int hh=(m/60)%24, mm=m%60;
   return StringFormat("%02d:%02d",hh,mm);
}
void DebugPrintKZ(){
   if(!Debug) return;
   PrintFormat("KZ cfg | UseKZ=%s IgnoreKZ=%s ShiftMin=%d | "
               "KZ1=%s-%s KZ2=%s-%s KZ3=%s-%s KZ4=%s-%s",
      P.UseKillzones?"true":"false",
      InpIgnoreKZ?"true":"false",
      KZ_Shift_Min,
      MinToHHMM(P.KZ1s), MinToHHMM(P.KZ1e),
      MinToHHMM(P.KZ2s), MinToHHMM(P.KZ2e),
      MinToHHMM(P.KZ3s), MinToHHMM(P.KZ3e),
      MinToHHMM(P.KZ4s), MinToHHMM(P.KZ4e)
   );
}

bool UpdateRates(int need_bars=450){
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(InpSymbol, InpTF, 0, need_bars, rates);
   return (copied>0);
}
double SymbolPoint(){ return SymbolInfoDouble(InpSymbol, SYMBOL_POINT); }

double SpreadUSD(){
   MqlTick t; if(!SymbolInfoTick(InpSymbol,t)) return 0.0;
   return (t.ask - t.bid);
}

bool IsKillzone(datetime t){
   if(InpIgnoreKZ || !P.UseKillzones) return true;
   if((P.KZ1s|P.KZ1e|P.KZ2s|P.KZ2e|P.KZ3s|P.KZ3e|P.KZ4s|P.KZ4e)==0) return true;
   MqlDateTime dt; TimeToStruct(t, dt);
   int hm  = dt.hour*60 + dt.min;
   int hms = (hm + KZ_Shift_Min) % (24*60);
   if(hms < 0) hms += 24*60;
   if(hms>=P.KZ1s && hms<=P.KZ1e) return true;
   if(hms>=P.KZ2s && hms<=P.KZ2e) return true;
   if(hms>=P.KZ3s && hms<=P.KZ3e) return true;
   if(hms>=P.KZ4s && hms<=P.KZ4e) return true;
   return false;
}

double RoundMagnet(double price){
   double base = MathFloor(price);
   double arr[5] = {0.00,0.25,0.50,0.75,1.00};
   double best = base, bestd = 1e9;
   for(int i=0;i<5;i++){
      double cand = base + arr[i];
      double d = MathAbs(price - cand);
      if(d<bestd){ bestd=d; best=cand; }
   }
   return best;
}
bool NearRound(double price, double delta){ return MathAbs(price - RoundMagnet(price)) <= delta; }

int HighestIndex(int start_shift, int count){
   int best = start_shift; double h = rates[best].high;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i)
      if(rates[i].high > h){ h = rates[i].high; best = i; }
   return best;
}
int LowestIndex(int start_shift, int count){
   int best = start_shift; double l = rates[best].low;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i)
      if(rates[i].low < l){ l = rates[i].low; best = i; }
   return best;
}

double PercentileDouble(double &arr[], double p){
   int n = ArraySize(arr); if(n<=0) return 0.0;
   ArraySort(arr);
   double idx = (p/100.0)*(n-1);
   int lo = (int)MathFloor(idx), hi = (int)MathCeil(idx);
   if(lo==hi) return arr[lo];
   double w = idx - lo;
   return arr[lo]*(1.0-w) + arr[hi]*w;
}

//========================== VSA & PATTERNS ==========================//
bool EffortResultOK(int bar){ // bar shift>=1
   if(!P.UseVSA) return true;
   int from = bar+1;
   int cnt  = MathMin(P.L_percentile, ArraySize(rates)-from);
   if(cnt<30) return false;
   double vol[]; ArrayResize(vol,cnt);
   double rng[]; ArrayResize(rng,cnt);
   for(int i=0;i<cnt;i++){
      int sh = from+i;
      vol[i] = (double)rates[sh].tick_volume;
      rng[i] = (rates[sh].high - rates[sh].low);
   }
   double vtmp[]; ArrayCopy(vtmp,vol);
   double rtmp[]; ArrayCopy(rtmp,rng);
   double v90 = PercentileDouble(vtmp, 90.0);
   double r60 = PercentileDouble(rtmp, 60.0);
   double thisVol = (double)rates[bar].tick_volume;
   double thisRng = (rates[bar].high - rates[bar].low);
   return (thisVol >= v90 && thisRng <= r60);
}

bool IsSweepHighBar(int bar){
   int start = bar+1; int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3) return false;
   int ih = HighestIndex(start, cnt);
   double swingH = rates[ih].high;
   double pt = SymbolPoint();
   if(rates[bar].high > swingH + pt && rates[bar].close < swingH) return true;
   if(MathAbs(rates[bar].high - swingH) <= P.EqTol && rates[bar].close < swingH) return true;
   return false;
}
bool IsSweepLowBar(int bar){
   int start = bar+1; int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3) return false;
   int il = LowestIndex(start, cnt);
   double swingL = rates[il].low;
   double pt = SymbolPoint();
   if(rates[bar].low < swingL - pt && rates[bar].close > swingL) return true;
   if(MathAbs(rates[bar].low - swingL) <= P.EqTol && rates[bar].close > swingL) return true;
   return false;
}

int PriorInternalSwingLow(int bar){
   int start = bar+1; int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3) return -1;
   return LowestIndex(start, cnt);
}
int PriorInternalSwingHigh(int bar){
   int start = bar+1; int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3) return -1;
   return HighestIndex(start, cnt);
}

bool HasBOSDownFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut){
   int swing = PriorInternalSwingLow(sweepBar); if(swing<0) return false;
   double level = rates[swing].low;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1; int to = MathMax(1, sweepBar - maxN);
   for(int i=from; i>=to; --i){
      if(rates[i].close < level - buffer || rates[i].low < level - buffer){
         outLevel = level; bosBarOut = i; return true;
      }
   }
   return false;
}
bool HasBOSUpFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut){
   int swing = PriorInternalSwingHigh(sweepBar); if(swing<0) return false;
   double level = rates[swing].high;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1; int to = MathMax(1, sweepBar - maxN);
   for(int i=from; i>=to; --i){
      if(rates[i].close > level + buffer || rates[i].high > level + buffer){
         outLevel = level; bosBarOut = i; return true;
      }
   }
   return false;
}

//========================== FILTERS & RISK ==========================//
bool FiltersPass(int bar){
   if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta)){
      cntBlockRN++;
      if(Debug) PrintFormat("BLOCK RN | price=%.2f delta=%.2f", rates[bar].close, P.RNDelta);
      return false;
   }
   if(!IsKillzone(rates[bar].time)){
      cntBlockKZ++;
      if(Debug) Print("BLOCK KZ @", TimeToString(rates[bar].time, TIME_DATE|TIME_MINUTES));
      return false;
   }
   double sp = SpreadUSD();
   if(sp > P.MaxSpreadUSD){
      cntBlockSpread++;
      if(Debug) PrintFormat("BLOCK Spread=%.3f > Max=%.3f", sp, P.MaxSpreadUSD);
      return false;
   }
   return true;
}

int PositionsOnSymbol(){
   int total=0;
   for(int i=0;i<PositionsTotal();++i){
      string sym = PositionGetSymbol(i);
      if(sym==InpSymbol) total++;
   }
   return total;
}

double CalcLotByRisk(double stop_usd){
   if(stop_usd<=0) return 0.0;
   double risk_amt = AccountInfoDouble(ACCOUNT_BALANCE) * P.RiskPerTradePct/100.0;
   double tv=0, ts=0;
   SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE, tv);
   SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE, ts);
   if(tv<=0 || ts<=0) return 0.0;
   double ticks = stop_usd / ts;
   if(ticks<=0) return 0.0;
   double loss_per_lot = ticks * tv;
   if(loss_per_lot<=0) return 0.0;
   double lots = risk_amt / loss_per_lot;
   double minlot, maxlot, lotstep;
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN, minlot);
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX, maxlot);
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP, lotstep);
   lots = MathMax(minlot, MathMin(lots, maxlot));
   lots = MathFloor(lots/lotstep)*lotstep;
   return lots;
}

//====================== POSITION MANAGEMENT =========================//
void ManageOpenPosition(){
   if(!PositionSelect(InpSymbol)) return;
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   long   type  = PositionGetInteger(POSITION_TYPE);
   datetime opent= (datetime)PositionGetInteger(POSITION_TIME);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double curr = (type==POSITION_TYPE_SELL ? bid : ask);
   double risk_per_lot = MathAbs(entry - sl);
   double reachedR = 0.0;
   if(risk_per_lot>0) reachedR = (type==POSITION_TYPE_SELL ? (entry-curr)/risk_per_lot : (curr-entry)/risk_per_lot);

   // BE move
   if(P.BE_Activate_R>0 && reachedR >= P.BE_Activate_R){
      double newSL = entry;
      if(type==POSITION_TYPE_SELL && sl<newSL) trade.PositionModify(InpSymbol, newSL, tp);
      if(type==POSITION_TYPE_BUY  && sl>newSL) trade.PositionModify(InpSymbol, newSL, tp);
   }

   // Partial at TP1
   if(P.TP1_R>0 && P.PartialClosePct>0 && reachedR >= P.TP1_R){
      double closeVol = vol * (P.PartialClosePct/100.0);
      double minlot, lotstep;
      SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN, minlot);
      SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP, lotstep);
      if(closeVol >= minlot){
         closeVol = MathFloor(closeVol/lotstep)*lotstep;
         if(closeVol >= minlot) trade.PositionClosePartial(InpSymbol, closeVol);
      }
   }

   // Time-stop
   if(P.TimeStopMinutes>0 && P.MinProgressR>0){
      datetime nowt = TimeCurrent();
      if((nowt - opent) >= P.TimeStopMinutes*60){
         if(reachedR < P.MinProgressR) trade.PositionClose(InpSymbol);
      }
   }
}

//========================= SIGNAL / ENTRIES =========================//
void UseInputsAsParams(){
   P.EnableLong=EnableLong; P.EnableShort=EnableShort;
   P.K_swing=K_swing; P.N_bos=N_bos; P.LookbackInternal=LookbackInternal; P.M_retest=M_retest_input;
   P.EqTol=EqTol; P.BOSBufferPoints=BOSBufferPoints;
   P.UseKillzones=UseKillzones_input; P.UseRoundNumber=UseRoundNumber; P.UseVSA=UseVSA;
   P.L_percentile=L_percentile; P.RNDelta=RNDelta;
   P.KZ1s=KZ1_StartMin; P.KZ1e=KZ1_EndMin; P.KZ2s=KZ2_StartMin; P.KZ2e=KZ2_EndMin;
   P.KZ3s=KZ3_StartMin; P.KZ3e=KZ3_EndMin; P.KZ4s=KZ4_StartMin; P.KZ4e=KZ4_EndMin;
   P.RiskPerTradePct=RiskPerTradePct; P.SL_BufferUSD=SL_BufferUSD; P.TP1_R=TP1_R; P.TP2_R=TP2_R;
   P.BE_Activate_R=BE_Activate_R; P.PartialClosePct=PartialClosePct;
   P.TimeStopMinutes=TimeStopMinutes; P.MinProgressR=MinProgressR;
   P.MaxSpreadUSD=MaxSpreadUSD; P.MaxOpenPositions=MaxOpenPositions;
   P.UsePendingRetest=UsePendingRetest; P.RetestOffsetUSD=RetestOffsetUSD; P.PendingExpirySec=PendingExpirySec;
}

// -------- FINAL V1 PRESETS: 101..108 (map từ UC thắng) -------- //
bool ApplyPresetBuiltIn(int id){
   UseInputsAsParams();

   const int KZ1s = 13*60+55, KZ1e = 14*60+25;
   const int KZ2s = 16*60+25, KZ2e = 16*60+45;
   const int KZ3s = 19*60+20, KZ3e = 19*60+50;
   const int KZ4s = 20*60+55, KZ4e = 21*60+20;

   switch(id){
      case 0:  return true; // custom

      case 101: // RN+KZ no-VSA (PF ~6.1)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ2s=KZ2s; P.KZ2e=KZ2e; P.KZ3s=KZ3s; P.KZ3e=KZ3e; P.KZ4s=KZ4s; P.KZ4e=KZ4e;
         P.UseRoundNumber=true; P.RNDelta=0.30;  P.UseVSA=false;
         P.K_swing=50; P.N_bos=6; P.LookbackInternal=12; P.M_retest=6; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;

      case 102: // precision RN (PF ~6.23)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ3s=KZ3s; P.KZ3e=KZ3e; P.KZ4s=KZ4s; P.KZ4e=KZ4e;
         P.UseRoundNumber=true; P.RNDelta=0.25;  P.UseVSA=false;
         P.K_swing=55; P.N_bos=6; P.M_retest=6; P.EqTol=0.18; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;

      case 103: // LDN RN+VSA (PF ~5.55)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ2s=KZ2s; P.KZ2e=KZ2e;
         P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=true; P.L_percentile=150;
         P.K_swing=55; P.N_bos=6; P.M_retest=6; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.50; return true;

      case 104: // NY RN+VSA
         P.UseKillzones=true;  P.KZ3s=KZ3s; P.KZ3e=KZ3e; P.KZ4s=KZ4s; P.KZ4e=KZ4e;
         P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=true; P.L_percentile=150;
         P.K_swing=55; P.N_bos=6; P.M_retest=6; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.50; return true;

      case 105: // RN-only solid (PF 3~4, nhiều kèo)
         P.UseKillzones=false;
         P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
         P.K_swing=55; P.N_bos=6; P.M_retest=6; P.EqTol=0.20; P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;

      case 106: // high precision (PF ~6.79)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ3s=KZ3s; P.KZ3e=KZ3e;
         P.UseRoundNumber=true; P.RNDelta=0.25; P.UseVSA=true; P.L_percentile=180;
         P.K_swing=60; P.N_bos=5; P.M_retest=6; P.EqTol=0.15; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.45; return true;

      case 107: // Aggressive mod (PF 3.3~3.9)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ3s=KZ3s; P.KZ3e=KZ3e;
         P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
         P.K_swing=45; P.N_bos=7; P.M_retest=6; P.EqTol=0.25; P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

      case 108: // Fast retest (PF ~3.3)
         P.UseKillzones=true;  P.KZ1s=KZ1s; P.KZ1e=KZ1e; P.KZ3s=KZ3s; P.KZ3e=KZ3e;
         P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
         P.K_swing=55; P.N_bos=6; P.M_retest=4; P.EqTol=0.20; P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;
   }
   return false;
}

//========================= DETECT & ENTER ===========================//
void DetectBOSAndArm()
{
   // quét sweep cách đây 2..(N_bos+1) bar
   int maxS = MathMin(1 + P.N_bos, ArraySize(rates) - 2);
   for(int s = 2; s <= maxS; ++s)
   {
      // SHORT: sweep lên -> BOS xuống
      if(P.EnableShort && IsSweepHighBar(s) && EffortResultOK(s))
      {
         double level; int bosbar;
         if(HasBOSDownFrom(s, P.N_bos, level, bosbar))
         {
            if(!FiltersPass(bosbar)) continue;
            state = ST_BOS_CONF;
            bosIsShort = true; bosLevel = level; bosBarTime = rates[bosbar].time;
            sweepHigh = rates[s].high; sweepLow = rates[s].low;
            cntArmed++; if(Debug) Print("BOS-Short armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
            return;
         }
      }
      // LONG: sweep xuống -> BOS lên
      if(P.EnableLong && IsSweepLowBar(s) && EffortResultOK(s))
      {
         double level; int bosbar;
         if(HasBOSUpFrom(s, P.N_bos, level, bosbar))
         {
            if(!FiltersPass(bosbar)) continue;
            state = ST_BOS_CONF;
            bosIsShort = false; bosLevel = level; bosBarTime = rates[bosbar].time;
            sweepHigh = rates[s].high; sweepLow = rates[s].low;
            cntArmed++; if(Debug) Print("BOS-Long armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
            return;
         }
      }
   }
}

int ShiftOfTime(datetime t){
   int n = ArraySize(rates);
   for(int i=1;i<n;i++) if(rates[i].time==t) return i;
   return -1;
}

bool PlacePendingAfterBOS(bool isShort){
   datetime exp = TimeCurrent() + P.PendingExpirySec;
   if(isShort){
      double price = bosLevel - RetestOffsetUSD;
      double sl    = sweepHigh + P.SL_BufferUSD;
      double lots  = CalcLotByRisk(MathAbs(sl - price));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
         bool ok = trade.SellStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
         if(Debug) Print("Place SellStop ",ok?"OK":"FAIL"," @",DoubleToString(price,2));
         return ok;
      }
   }else{
      double price = bosLevel + RetestOffsetUSD;
      double sl    = sweepLow - P.SL_BufferUSD;
      double lots  = CalcLotByRisk(MathAbs(price - sl));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
         bool ok = trade.BuyStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
         if(Debug) Print("Place BuyStop ",ok?"OK":"FAIL"," @",DoubleToString(price,2));
         return ok;
      }
   }
   return false;
}

void TryEnterAfterRetest(){
   if(state!=ST_BOS_CONF) return;

   int bosShift = ShiftOfTime(bosBarTime);
   if(bosShift<0){ state=ST_IDLE; return; }

   int maxCheck = MathMin(P.M_retest, bosShift-1);

   for(int i=1; i<=maxCheck; ++i){
      double hi=rates[i].high, lo=rates[i].low, cl=rates[i].close;

      if(bosIsShort){
         bool touched = (hi >= bosLevel - RetestTouchUSD);
         bool closed  = (cl <= bosLevel + 1e-6);
         if( (RequireRetestClose ? (touched && closed) : touched) ){
            if(P.UsePendingRetest){ PlacePendingAfterBOS(true); cntRetestHit++; state=ST_IDLE; return; }
            double sl   = sweepHigh + P.SL_BufferUSD;
            double ask  = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
            double bid  = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
            double sp   = ask-bid;
            if(sp > P.MaxSpreadUSD){ cntSpreadAtEntry++; state=ST_IDLE; return; }
            double entry= bid;
            double lots = CalcLotByRisk(MathAbs(sl - entry));
            if(lots<=0){ cntLotsZero++; state=ST_IDLE; return; }
            if(PositionsOnSymbol()>=P.MaxOpenPositions){ cntMaxPosHit++; state=ST_IDLE; return; }
            if(trade.Sell(lots, InpSymbol, 0.0, sl, 0.0)) cntRetestHit++;
            state=ST_IDLE; return;
         }
      }else{
         bool touched = (lo <= bosLevel + RetestTouchUSD);
         bool closed  = (cl >= bosLevel - 1e-6);
         if( (RequireRetestClose ? (touched && closed) : touched) ){
            if(P.UsePendingRetest){ PlacePendingAfterBOS(false); cntRetestHit++; state=ST_IDLE; return; }
            double sl   = sweepLow - P.SL_BufferUSD;
            double ask  = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
            double bid  = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
            double sp   = ask-bid;
            if(sp > P.MaxSpreadUSD){ cntSpreadAtEntry++; state=ST_IDLE; return; }
            double entry= ask;
            double lots = CalcLotByRisk(MathAbs(entry - sl));
            if(lots<=0){ cntLotsZero++; state=ST_IDLE; return; }
            if(PositionsOnSymbol()>=P.MaxOpenPositions){ cntMaxPosHit++; state=ST_IDLE; return; }
            if(trade.Buy(lots, InpSymbol, 0.0, sl, 0.0)) cntRetestHit++;
            state=ST_IDLE; return;
         }
      }
   }

   // Không retest trong cửa sổ => fallback
   if(EnterIfNoRetest && EnterIfNoRetestBars>0){
      int next = MathMax(1, bosShift-EnterIfNoRetestBars);
      double ask  = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      double bid  = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      double sp   = ask-bid;
      if(sp > P.MaxSpreadUSD){ cntSpreadAtEntry++; state=ST_IDLE; return; }

      if(bosIsShort){
         double sl   = sweepHigh + P.SL_BufferUSD;
         double entry= bid;
         double lots = CalcLotByRisk(MathAbs(sl - entry));
         if(lots<=0){ cntLotsZero++; state=ST_IDLE; return; }
         if(PositionsOnSymbol()>=P.MaxOpenPositions){ cntMaxPosHit++; state=ST_IDLE; return; }
         trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
      }else{
         double sl   = sweepLow - P.SL_BufferUSD;
         double entry= ask;
         double lots = CalcLotByRisk(MathAbs(entry - sl));
         if(lots<=0){ cntLotsZero++; state=ST_IDLE; return; }
         if(PositionsOnSymbol()>=P.MaxOpenPositions){ cntMaxPosHit++; state=ST_IDLE; return; }
         trade.Buy(lots, InpSymbol, 0.0, sl, 0.0);
      }
   }else{
      cntNoRetest++;
   }
   state = ST_IDLE;
}

//=========================== MT5 CALLBACKS ==========================//
bool SetupParamsFromPreset(){
   UseInputsAsParams();
   bool ok = true;
   if(UsePreset) ok = ApplyPresetBuiltIn(PresetID);
   if(Debug) PrintFormat("Preset applied: ID=%d ok=%s",PresetID, ok?"true":"false");
   return ok;
}

int OnInit(){
   trade.SetAsyncMode(false);
   SetupParamsFromPreset();
   DebugPrintKZ();
   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(!UpdateRates(500)) return;

   if(ArraySize(rates)>=2 && rates[1].time != last_bar_time){
      last_bar_time = rates[1].time;
      DetectBOSAndArm();
      TryEnterAfterRetest();
   }
   ManageOpenPosition();
}

void OnDeinit(const int reason){
   if(Debug)
      PrintFormat("Blocked | KZ=%d RN=%d Spread=%d | Armed=%d RetestHit=%d NoRetest=%d LotsZero=%d MaxPos=%d SpreadAtEntry=%d",
         cntBlockKZ,cntBlockRN,cntBlockSpread,cntArmed,cntRetestHit,cntNoRetest,cntLotsZero,cntMaxPosHit,cntSpreadAtEntry);
}
//+------------------------------------------------------------------+
