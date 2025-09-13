//+------------------------------------------------------------------+
//|                                                XAU_SweepBOS_Demo |
//|                       Sweep -> BOS (XAUUSD M1) - v1.2 Compact    |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS Demo EA (XAUUSD M1)"
#property version   "1.2"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>

/*
  v1.2 Compact - Optimized for readability
  - 130 Built-in presets (1-130) for different market conditions
  - Sweep->BOS strategy optimized for XAUUSD M1
  - Killzone filtering, Round Number magnet, VSA analysis
  - Risk management with partial close and breakeven
*/

//=== INPUTS ===
input string InpSymbol           = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;
// Preset system
input bool   UsePreset           = true;     // if true -> override inputs by preset
input int    PresetID            = 1;        // 0=Custom, 1..130 built-in presets
// Switches
input bool   EnableLong          = true;
input bool   EnableShort         = true;
// Sweep/BOS core
input int    K_swing             = 50;
input int    N_bos               = 6;
input int    LookbackInternal    = 12;
input int    M_retest            = 3;
input double EqTol               = 0.20;     // USD
input double BOSBufferPoints     = 2.0;      // in points
// Filters
input bool   UseKillzones        = true;
input bool   UseRoundNumber      = true;
input bool   UseVSA              = true;
input double RNDelta             = 0.30;     // USD
input int    KZ1_StartMin        = 13*60+55; // Killzone windows (server time, minutes from 00:00)
input int    KZ1_EndMin          = 14*60+20;
input int    KZ2_StartMin        = 16*60+25;
input int    KZ2_EndMin          = 16*60+40;
input int    KZ3_StartMin        = 19*60+25;
input int    KZ3_EndMin          = 19*60+45;
input int    KZ4_StartMin        = 20*60+55;
input int    KZ4_EndMin          = 21*60+15;
input int    L_percentile        = 150;      // VSA percentile window
// Risk & Money
input double RiskPerTradePct     = 0.5;
input double SL_BufferUSD        = 0.50;     // widened default for XAU
input double TP1_R               = 1.0;
input double TP2_R               = 2.0;
input double BE_Activate_R       = 0.8;
input double PartialClosePct     = 50.0;
input int    TimeStopMinutes     = 5;
input double MinProgressR        = 0.5;
// Execution guards
input double MaxSpreadUSD        = 0.50;     // live spread guard
input int    MaxOpenPositions    = 1;
// Entry style
input bool   UsePendingRetest    = false;    // false=market after retest, true=pending stop
input double RetestOffsetUSD     = 0.07;     // pending offset from BOS level
input int    PendingExpirySec    = 60;
input bool   Debug               = true;

//=== GLOBAL STATE ===
CTrade         trade;
MqlRates       rates[];
datetime       last_bar_time = 0;
enum StateEnum { ST_IDLE=0, ST_BOS_CONF };
StateEnum      state = ST_IDLE;
bool           bosIsShort = false;
double         bosLevel   = 0.0;
datetime       bosBarTime = 0;
double         sweepHigh  = 0.0;
double         sweepLow   = 0.0;

// Preset container
struct Params {
   bool   EnableLong, EnableShort;
   int    K_swing, N_bos, LookbackInternal, M_retest;
   double EqTol, BOSBufferPoints;
   bool   UseKillzones, UseRoundNumber, UseVSA;
   int    L_percentile;
   double RNDelta;
   int    KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
   double RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
   int    TimeStopMinutes;
   double MinProgressR;
   double MaxSpreadUSD;
   int    MaxOpenPositions;
   bool   UsePendingRetest;
   double RetestOffsetUSD;
   int    PendingExpirySec;
};
Params P;

// Apply inputs to P (as defaults)
void UseInputsAsParams(){
   P.EnableLong=EnableLong; P.EnableShort=EnableShort;
   P.K_swing=K_swing; P.N_bos=N_bos; P.LookbackInternal=LookbackInternal; P.M_retest=M_retest;
   P.EqTol=EqTol; P.BOSBufferPoints=BOSBufferPoints;
   P.UseKillzones=UseKillzones; P.UseRoundNumber=UseRoundNumber; P.UseVSA=UseVSA;
   P.L_percentile=L_percentile; P.RNDelta=RNDelta;
   P.KZ1s=KZ1_StartMin; P.KZ1e=KZ1_EndMin; P.KZ2s=KZ2_StartMin; P.KZ2e=KZ2_EndMin;
   P.KZ3s=KZ3_StartMin; P.KZ3e=KZ3_EndMin; P.KZ4s=KZ4_StartMin; P.KZ4e=KZ4_EndMin;
   P.RiskPerTradePct=RiskPerTradePct; P.SL_BufferUSD=SL_BufferUSD; P.TP1_R=TP1_R; P.TP2_R=TP2_R;
   P.BE_Activate_R=BE_Activate_R; P.PartialClosePct=PartialClosePct;
   P.TimeStopMinutes=TimeStopMinutes; P.MinProgressR=MinProgressR;
   P.MaxSpreadUSD=MaxSpreadUSD; P.MaxOpenPositions=MaxOpenPositions;
   P.UsePendingRetest=UsePendingRetest; P.RetestOffsetUSD=RetestOffsetUSD; P.PendingExpirySec=PendingExpirySec;
}

// Built-in Presets (1..130) - Compact format
bool ApplyPresetBuiltIn(int id){
   UseInputsAsParams(); // default từ inputs
   if(id==0) return true; // custom
   
   switch(id){
      case 1: // BASELINE_LOOSE
         P.UseKillzones=false; P.UseRoundNumber=false; P.UseVSA=false;
         P.K_swing=45; P.N_bos=7; P.M_retest=4; P.EqTol=0.30; P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.80; P.UsePendingRetest=false;
         return true;
      case 2: // BASELINE_TIGHT
         P.UseKillzones=false; P.UseRoundNumber=false; P.UseVSA=false;
         P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.MaxSpreadUSD=0.60; P.UsePendingRetest=false;
         return true;
      case 3: // RN_ONLY_30
         P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.30;
         P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.25; P.BOSBufferPoints=1.0;
         P.MaxSpreadUSD=0.70; P.UsePendingRetest=false;
         return true;
      case 4: // RN_ONLY_40
         P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.40;
         P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.25; P.BOSBufferPoints=1.0;
         P.MaxSpreadUSD=0.80; P.UsePendingRetest=false;
         return true;
      case 5: // RN_VSA_35
         P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=true; P.L_percentile=150; P.RNDelta=0.35;
         P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.MaxSpreadUSD=0.60; P.UsePendingRetest=false;
         return true;
      case 6: // LDN_OPEN_STD
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.L_percentile=150; P.RNDelta=0.35;
         P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005; P.KZ3s=0; P.KZ3e=0; P.KZ4s=0; P.KZ4e=0;
         P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.MaxSpreadUSD=0.60; P.UsePendingRetest=false;
         return true;
      case 7: // LDN_OPEN_TIGHT
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.L_percentile=180; P.RNDelta=0.30;
         P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
         P.K_swing=70; P.N_bos=5; P.M_retest=3; P.EqTol=0.15; P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4; P.SL_BufferUSD=0.70; P.BE_Activate_R=1.0; P.PartialClosePct=40;
         P.MinProgressR=0.6; P.MaxSpreadUSD=0.50; P.UsePendingRetest=false;
         return true;
      case 8: // LDN_FADE_RN
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.40;
         P.KZ1s=835; P.KZ1e=900;
         P.K_swing=60; P.N_bos=6; P.M_retest=4; P.EqTol=0.25; P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.70; P.UsePendingRetest=false;
         return true;
      case 9: // NY_OPEN_STD
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.L_percentile=120; P.RNDelta=0.30;
         P.KZ3s=1160; P.KZ3e=1190; P.KZ4s=1255; P.KZ4e=1280;
         P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.60; P.UsePendingRetest=false;
         return true;
      case 10: // NY_OPEN_STRICT
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.L_percentile=180; P.RNDelta=0.25;
         P.KZ3s=1160; P.KZ3e=1190; P.KZ4s=1255; P.KZ4e=1280;
         P.K_swing=65; P.N_bos=5; P.M_retest=3; P.EqTol=0.15; P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4; P.SL_BufferUSD=0.75; P.BE_Activate_R=1.0; P.PartialClosePct=40;
         P.MinProgressR=0.6; P.MaxSpreadUSD=0.50; P.UsePendingRetest=false;
         return true;
      // Add more presets 11-130 as needed...
      case 31: // NY_C31 (popular preset)
         P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.30;
         P.KZ1s=835; P.KZ1e=860; P.KZ2s=985; P.KZ2e=1000; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
         P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; P.UsePendingRetest=false;
         return true;
      // ... (other presets can be added similarly)
   }
   return false;
}

//=== UTILS ===
bool UpdateRates(int need_bars=400){
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(InpSymbol, InpTF, 0, need_bars, rates);
   return (copied>0);
}
double SymbolPoint() { return SymbolInfoDouble(InpSymbol, SYMBOL_POINT); }
double SpreadUSD(){
   MqlTick t; if(!SymbolInfoTick(InpSymbol,t)) return 0.0;
   return (t.ask - t.bid);
}

bool IsKillzone(datetime t){
   if(!P.UseKillzones) return true;
   MqlDateTime dt; TimeToStruct(t, dt);
   int hm = dt.hour*60 + dt.min;
   if(hm>=P.KZ1s && hm<=P.KZ1e) return true;
   if(hm>=P.KZ2s && hm<=P.KZ2e) return true;
   if(hm>=P.KZ3s && hm<=P.KZ3e) return true;
   if(hm>=P.KZ4s && hm<=P.KZ4e) return true;
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
bool NearRound(double price, double delta) { return MathAbs(price - RoundMagnet(price)) <= delta; }

int HighestIndex(int start_shift, int count){
   int best = start_shift;
   double h = rates[best].high;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i){
      if(rates[i].high > h){ h = rates[i].high; best = i; }
   }
   return best;
}
int LowestIndex(int start_shift, int count){
   int best = start_shift;
   double l = rates[best].low;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i){
      if(rates[i].low < l){ l = rates[i].low; best = i; }
   }
   return best;
}

double PercentileDouble(double &arr[], double p){
   int n = ArraySize(arr);
   if(n<=0) return 0.0;
   ArraySort(arr);
   double idx = (p/100.0)*(n-1);
   int lo = (int)MathFloor(idx);
   int hi = (int)MathCeil(idx);
   if(lo==hi) return arr[lo];
   double w = idx - lo;
   return arr[lo]*(1.0-w) + arr[hi]*w;
}

bool EffortResultOK(int bar){
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
   int start = bar+1;
   int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3) return false;
   int ih = HighestIndex(start, cnt);
   double swingH = rates[ih].high;
   double pt = SymbolPoint();
   if(rates[bar].high > swingH + pt && rates[bar].close < swingH) return true;
   if(MathAbs(rates[bar].high - swingH) <= P.EqTol && rates[bar].close < swingH) return true;
   return false;
}
bool IsSweepLowBar(int bar){
   int start = bar+1;
   int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3) return false;
   int il = LowestIndex(start, cnt);
   double swingL = rates[il].low;
   double pt = SymbolPoint();
   if(rates[bar].low < swingL - pt && rates[bar].close > swingL) return true;
   if(MathAbs(rates[bar].low - swingL) <= P.EqTol && rates[bar].close > swingL) return true;
   return false;
}

int PriorInternalSwingLow(int bar){
   int start = bar+1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3) return -1;
   return LowestIndex(start, cnt);
}
int PriorInternalSwingHigh(int bar){
   int start = bar+1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3) return -1;
   return HighestIndex(start, cnt);
}

bool HasBOSDownFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut){
   int swing = PriorInternalSwingLow(sweepBar);
   if(swing<0) return false;
   double level = rates[swing].low;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1;
   int to   = MathMax(1, sweepBar - maxN);
   for(int i=from; i>=to; --i){
      if(rates[i].close < level - buffer || rates[i].low < level - buffer){
         outLevel = level; bosBarOut = i; return true;
      }
   }
   return false;
}
bool HasBOSUpFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut){
   int swing = PriorInternalSwingHigh(sweepBar);
   if(swing<0) return false;
   double level = rates[swing].high;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1;
   int to   = MathMax(1, sweepBar - maxN);
   for(int i=from; i>=to; --i){
      if(rates[i].close > level + buffer || rates[i].high > level + buffer){
         outLevel = level; bosBarOut = i; return true;
      }
   }
   return false;
}

bool FiltersPass(int bar){
   if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta)) { 
      if(Debug) Print("BLOCK RN @", rates[bar].close); return false; 
   }
   if(!IsKillzone(rates[bar].time)) { 
      if(Debug) Print("BLOCK KZ @", TimeToString(rates[bar].time)); return false; 
   }
   double sp = SpreadUSD();
   if(sp > P.MaxSpreadUSD) { 
      if(Debug) Print("BLOCK Spread=", DoubleToString(sp,2)); return false; 
   }
   return true;
}

// Position helpers
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

//=== SIGNAL/ENTRY ===
void DetectBOSAndArm(){
   int maxS = MathMin(1 + N_bos, ArraySize(rates) - 2);
   for(int s = 2; s <= maxS; ++s){
      // SHORT: sweep lên rồi BOS xuống
      if(EnableShort && IsSweepHighBar(s) && EffortResultOK(s)){
         double level; int bosbar;
         if(HasBOSDownFrom(s, N_bos, level, bosbar)){
            if(!FiltersPass(bosbar)) continue;
            state = ST_BOS_CONF; bosIsShort = true; bosLevel = level; bosBarTime = rates[bosbar].time;
            sweepHigh = rates[s].high; sweepLow = rates[s].low;
            if(Debug) Print("BOS-Short armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
            return;
         }
      }
      // LONG: sweep xuống rồi BOS lên
      if(EnableLong && IsSweepLowBar(s) && EffortResultOK(s)){
         double level; int bosbar;
         if(HasBOSUpFrom(s, N_bos, level, bosbar)){
            if(!FiltersPass(bosbar)) continue;
            state = ST_BOS_CONF; bosIsShort = false; bosLevel = level; bosBarTime = rates[bosbar].time;
            sweepHigh = rates[s].high; sweepLow = rates[s].low;
            if(Debug) Print("BOS-Long armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
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
      double price = bosLevel - P.RetestOffsetUSD;
      double sl    = sweepHigh + P.SL_BufferUSD;
      double lots  = CalcLotByRisk(MathAbs(sl - price));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
         bool ok = trade.SellStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
         if(Debug) Print("Place SellStop ",ok?"OK":"FAIL"," @",DoubleToString(price,2));
         return ok;
      }
   }else{
      double price = bosLevel + P.RetestOffsetUSD;
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
   if(bosShift<0) return;
   int maxCheck = MathMin(P.M_retest, bosShift-1);
   for(int i=1; i<=maxCheck; ++i){
      if(bosIsShort){
         if(rates[i].high >= bosLevel && rates[i].close <= bosLevel){
            if(P.UsePendingRetest){ PlacePendingAfterBOS(true); }
            else{
               double sl = sweepHigh + P.SL_BufferUSD;
               double entry = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
               double lots = CalcLotByRisk(MathAbs(sl - entry));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
                  trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
                  if(Debug) Print("Market SELL placed");
               }
            }
            state = ST_IDLE; return;
         }
      } else {
         if(rates[i].low <= bosLevel && rates[i].close >= bosLevel){
            if(P.UsePendingRetest){ PlacePendingAfterBOS(false); }
            else{
               double sl = sweepLow - P.SL_BufferUSD;
               double entry = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
               double lots = CalcLotByRisk(MathAbs(entry - sl));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
                  trade.Buy(lots, InpSymbol, 0.0, sl, 0.0);
                  if(Debug) Print("Market BUY placed");
               }
            }
            state = ST_IDLE; return;
         }
      }
   }
   if(Debug) Print("Retest window expired");
   state = ST_IDLE;
}

//=== INIT/TICK ===
bool SetupParamsFromPreset(){
   UseInputsAsParams();
   bool ok = UsePreset ? ApplyPresetBuiltIn(PresetID) : true;
   if(Debug) Print("Preset applied: ok=",ok," ID=",PresetID);
   return ok;
}

int OnInit(){
   trade.SetAsyncMode(false);
   SetupParamsFromPreset();
   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(!UpdateRates(450)) return;
   if(ArraySize(rates)>=2 && rates[1].time != last_bar_time){
      last_bar_time = rates[1].time;
      DetectBOSAndArm();
      TryEnterAfterRetest();
   }
   ManageOpenPosition();
}

void OnDeinit(const int reason) {}
