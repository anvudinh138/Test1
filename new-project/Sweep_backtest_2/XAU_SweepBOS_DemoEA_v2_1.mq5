//+------------------------------------------------------------------+
//|                                       XAU_SweepBOS_DemoEA_v2_1  |
//|  Sweep -> BOS (XAUUSD M1)                                        |
//|  v2.1: Magic per preset + RetestNeedClose + Daily Guards         |
//|  Range khuyến nghị test (real tick): 2025-07-01 .. 2025-09-01    |
//|  Ghi chú: Real ticks XAUUSD bắt đầu từ 2025-05-28 (tuỳ broker).  |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS Demo EA (XAUUSD M1) v2.1"
#property version   "2.1"
#property strict

#include <Trade/Trade.mqh>

//============================= INPUTS ===============================//
input string           InpSymbol            = "XAUUSD";
input ENUM_TIMEFRAMES  InpTF                = PERIOD_M1;

// Preset / Usecase
input bool             UsePreset            = true;      // true = override inputs bằng preset
input int              PresetID             = 1;         // reset lại từ 1 ở v2.1
input long             MagicBase            = 41000;     // base magic; magic thực = MagicBase + PresetID

// Switches (khi UsePreset=false, hoặc làm default trước khi apply preset)
input bool             EnableLong           = true;
input bool             EnableShort          = true;

// Sweep/BOS core
input int              K_swing              = 50;        // tìm swing gần nhất
input int              N_bos                = 6;         // max bars sau sweep để thấy BOS
input int              LookbackInternal     = 12;        // nội bộ trước sweep
input int              M_retest             = 3;         // tối đa bars chờ retest sau BOS
input double           EqTol                = 0.20;      // USD tolerance equal high/low
input double           BOSBufferPoints      = 2.0;       // buffer vào/ra qua swing (đơn vị points)

// Filters
input bool             UseKillzones         = true;
input bool             UseRoundNumber       = true;
input bool             UseVSA               = true;      // effort-vs-result filter (tick_volume vs range)
input int              L_percentile         = 150;       // cửa sổ tính percentile
input double           RNDelta              = 0.30;      // USD gần RN (0.00/0.25/0.50/0.75)
input int              KZ1_StartMin         = 13*60+55;  // LDN pre-open (server time)
input int              KZ1_EndMin           = 14*60+20;
input int              KZ2_StartMin         = 16*60+25;
input int              KZ2_EndMin           = 16*60+40;
input int              KZ3_StartMin         = 19*60+25;  // NYO
input int              KZ3_EndMin           = 19*60+45;
input int              KZ4_StartMin         = 20*60+55;
input int              KZ4_EndMin           = 21*60+15;

// Risk & money
input double           RiskPerTradePct      = 0.50;      // % balance / trade
input double           SL_BufferUSD         = 0.60;      // thêm ngoài sweep extremum
input double           TP1_R                = 1.0;
input double           TP2_R                = 2.0;
input double           BE_Activate_R        = 0.8;
input double           PartialClosePct      = 50.0;      // % đóng tại TP1
input int              TimeStopMinutes      = 5;
input double           MinProgressR         = 0.5;

// Exec guards
input double           MaxSpreadUSD         = 0.60;      // block entries nếu spread vượt
input int              MaxOpenPositions     = 1;         // per-preset (magic)

// Entry style
input bool             UsePendingRetest     = false;     // false=market-on-retest, true=pending stop
input double           RetestOffsetUSD      = 0.07;
input int              PendingExpirySec     = 60;
input bool             RetestNeedClose_Default = true;   // true: retest phải close vượt BOS; false: chạm wick là đủ

// Daily guard (per magic/preset)
input int              DailyMaxTrades       = 12;        // 0=disable
input double           DailyMaxLossPct      = 2.0;       // % equity đầu ngày; <=0=disable
input int              MaxConsecLoss        = 3;         // 0=disable

// Debug
input bool             Debug                = true;

//============================= STATE ================================//
CTrade   trade;
MqlRates rates[];
datetime last_bar_time = 0;

enum StateEnum { ST_IDLE=0, ST_BOS_CONF };
StateEnum      state = ST_IDLE;

bool     bosIsShort   = false;
double   bosLevel     = 0.0;
datetime bosBarTime   = 0;
double   sweepHigh    = 0.0;
double   sweepLow     = 0.0;

long     g_magic      = 0;      // magic cho preset này

//=========================== PARAMS PACK ============================//
struct Params {
  // switches
  bool   EnableLong, EnableShort;
  // core
  int    K_swing, N_bos, LookbackInternal, M_retest;
  double EqTol, BOSBufferPoints;
  // filters
  bool   UseKillzones, UseRoundNumber, UseVSA;
  int    L_percentile;
  double RNDelta;
  int    KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
  // risk
  double RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
  int    TimeStopMinutes;
  double MinProgressR;
  // exec
  double MaxSpreadUSD;
  int    MaxOpenPositions;
  // entry
  bool   UsePendingRetest;
  double RetestOffsetUSD;
  int    PendingExpirySec;
  bool   RetestNeedClose;   // NEW v2.1
};
Params P;

//=========================== UTILITIES =============================//
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
  P.RetestNeedClose = RetestNeedClose_Default;
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
bool NearRound(double price, double delta){ return MathAbs(price - RoundMagnet(price)) <= delta; }

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
  ArraySort(arr); // ascending
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
  if(rates[bar].high > swingH + pt && rates[bar].close < swingH) return true; // raid rồi đóng dưới
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
  if(rates[bar].low < swingL - pt && rates[bar].close > swingL) return true; // raid rồi đóng trên
  if(MathAbs(rates[bar].low - swingL) <= P.EqTol && rates[bar].close > swingL) return true;
  return false;
}

int PriorInternalSwingLow (int bar){ int start=bar+1; int cnt=MathMin(P.LookbackInternal,ArraySize(rates)-start); if(cnt<3) return -1; return LowestIndex(start,cnt); }
int PriorInternalSwingHigh(int bar){ int start=bar+1; int cnt=MathMin(P.LookbackInternal,ArraySize(rates)-start); if(cnt<3) return -1; return HighestIndex(start,cnt); }

bool HasBOSDownFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut){
  int swing = PriorInternalSwingLow(sweepBar);
  if(swing<0) return false;
  double level = rates[swing].low;
  double buffer = P.BOSBufferPoints * SymbolPoint();
  int from = sweepBar-1;
  int to   = MathMax(1, sweepBar - maxN);
  for(int i=from; i>=to; --i){
    if(rates[i].close < level - buffer || rates[i].low < level - buffer){
      outLevel=level; bosBarOut=i; return true;
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
      outLevel=level; bosBarOut=i; return true;
    }
  }
  return false;
}

bool FiltersPass(int bar){
  if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta)){ if(Debug) Print("BLOCK RN @", DoubleToString(rates[bar].close,2)); return false; }
  if(!IsKillzone(rates[bar].time)) { if(Debug) Print("BLOCK KZ @", TimeToString(rates[bar].time)); return false; }
  double sp = SpreadUSD();
  if(sp > P.MaxSpreadUSD){ if(Debug) Print("BLOCK Spread=", DoubleToString(sp,2)); return false; }
  return true;
}

//------------------------ POSITIONS / RISK --------------------------//
int PositionsOnThisMagic(){
  int total=0;
  for(int i=0;i<PositionsTotal();++i){
    ulong ticket = PositionGetTicket(i);
    if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
    string sym = PositionGetString(POSITION_SYMBOL);
    long   mg  = (long)PositionGetInteger(POSITION_MAGIC);
    if(sym==InpSymbol && mg==g_magic) total++;
  }
  return total;
}

double CalcLotByRisk(double stop_usd){
  if(stop_usd<=0) return 0.0;
  double risk_amt = AccountInfoDouble(ACCOUNT_BALANCE) * P.RiskPerTradePct/100.0;
  double tv=0, ts=0;
  SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE, tv);
  SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE,  ts);
  if(tv<=0 || ts<=0) return 0.0;
  double ticks = stop_usd / ts;
  if(ticks<=0) return 0.0;
  double loss_per_lot = ticks * tv;
  if(loss_per_lot<=0) return 0.0;
  double lots = risk_amt / loss_per_lot;

  double minlot, maxlot, lotstep;
  SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN,  minlot);
  SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX,  maxlot);
  SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP, lotstep);
  lots = MathMax(minlot, MathMin(lots, maxlot));
  lots = MathFloor(lots/lotstep)*lotstep;
  return lots;
}

void ManageOpenPosition(){
  if(!PositionSelect(InpSymbol)) return;
  long mg = (long)PositionGetInteger(POSITION_MAGIC);
  if(mg!=g_magic) return;

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
  if(risk_per_lot>0)
    reachedR = (type==POSITION_TYPE_SELL ? (entry-curr)/risk_per_lot : (curr-entry)/risk_per_lot);

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
    SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN,  minlot);
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

//------------------------- DAILY GUARDS -----------------------------//
datetime day_anchor = 0;
double   day_equity0 = 0.0;

datetime TodayAnchor(){
  MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
  dt.hour=0; dt.min=0; dt.sec=0; return StructToTime(dt);
}
void RefreshDayAnchor(){
  datetime ta = TodayAnchor();
  if(ta!=day_anchor){ day_anchor=ta; day_equity0 = AccountInfoDouble(ACCOUNT_EQUITY); }
}

void TodayStats(int &trades_out, int &losses_out, int &consec_loss_out, double &pnl_out){
  trades_out=0; losses_out=0; consec_loss_out=0; pnl_out=0.0;
  RefreshDayAnchor();
  HistorySelect(day_anchor, TimeCurrent());
  int total = HistoryDealsTotal();
  int consec=0;
  for(int i=0;i<total;i++){
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket==0) continue;
    string sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    long   mg  = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
    long   entry= (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    if(sym!=InpSymbol || mg!=g_magic) continue;
    if(entry==DEAL_ENTRY_OUT){
      trades_out++;
      pnl_out += profit;
      if(profit<0){ losses_out++; consec++; } else consec=0;
    }
  }
  consec_loss_out = consec;
}

bool DailyGuardBlocks(){
  int t,l,cl; double pnl;
  TodayStats(t,l,cl,pnl);
  if(DailyMaxTrades>0 && t>=DailyMaxTrades){ if(Debug) Print("DAILY BLOCK: trades=",t); return true; }
  if(MaxConsecLoss>0 && cl>=MaxConsecLoss){ if(Debug) Print("DAILY BLOCK: consec_losses=",cl); return true; }
  if(DailyMaxLossPct>0 && day_equity0>0){
    double dd_pct = (pnl/day_equity0)*100.0;
    if(dd_pct <= -DailyMaxLossPct){ if(Debug) Print("DAILY BLOCK: loss%=", DoubleToString(dd_pct,2)); return true; }
  }
  return false;
}

//======================== SIGNAL / ENTRY ============================//
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
    if(lots>0 && PositionsOnThisMagic()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
      bool ok = trade.SellStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
      if(Debug) Print("Place SellStop ", ok?"OK":"FAIL"," @",DoubleToString(price,2));
      return ok;
    }
  }else{
    double price = bosLevel + P.RetestOffsetUSD;
    double sl    = sweepLow - P.SL_BufferUSD;
    double lots  = CalcLotByRisk(MathAbs(price - sl));
    if(lots>0 && PositionsOnThisMagic()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
      bool ok = trade.BuyStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
      if(Debug) Print("Place BuyStop ", ok?"OK":"FAIL"," @",DoubleToString(price,2));
      return ok;
    }
  }
  return false;
}

void DetectBOSAndArm(){
  if(DailyGuardBlocks()) return;

  int maxS = MathMin(1 + P.N_bos, ArraySize(rates) - 2);
  for(int s = 2; s <= maxS; ++s){
    // SHORT path
    if(P.EnableShort && IsSweepHighBar(s) && EffortResultOK(s)){
      double level; int bosbar;
      if(HasBOSDownFrom(s, P.N_bos, level, bosbar)){
        if(!FiltersPass(bosbar)) continue;
        state = ST_BOS_CONF;
        bosIsShort = true; bosLevel=level; bosBarTime=rates[bosbar].time;
        sweepHigh=rates[s].high; sweepLow=rates[s].low;
        if(Debug) Print("BOS-Short armed | sweep@",TimeToString(rates[s].time),
                        " BOS@",TimeToString(rates[bosbar].time));
        return;
      }
    }
    // LONG path
    if(P.EnableLong && IsSweepLowBar(s) && EffortResultOK(s)){
      double level; int bosbar;
      if(HasBOSUpFrom(s, P.N_bos, level, bosbar)){
        if(!FiltersPass(bosbar)) continue;
        state = ST_BOS_CONF;
        bosIsShort = false; bosLevel=level; bosBarTime=rates[bosbar].time;
        sweepHigh=rates[s].high; sweepLow=rates[s].low;
        if(Debug) Print("BOS-Long armed | sweep@",TimeToString(rates[s].time),
                        " BOS@",TimeToString(rates[bosbar].time));
        return;
      }
    }
  }
}

void TryEnterAfterRetest(){
  if(state!=ST_BOS_CONF) return;
  if(DailyGuardBlocks()){ state=ST_IDLE; return; }

  int bosShift = ShiftOfTime(bosBarTime);
  if(bosShift<0) { state=ST_IDLE; return; }

  int maxCheck = MathMin(P.M_retest, bosShift-1);
  for(int i=1; i<=maxCheck; ++i){
    if(bosIsShort){
      bool hit   = (rates[i].high >= bosLevel);
      bool close = (rates[i].close <= bosLevel);
      if( (P.RetestNeedClose ? (hit && close) : hit) ){
        if(P.UsePendingRetest){ PlacePendingAfterBOS(true); }
        else{
          double sl = sweepHigh + P.SL_BufferUSD;
          double entry = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
          double lots = CalcLotByRisk(MathAbs(sl - entry));
          if(lots>0 && PositionsOnThisMagic()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
            trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
            if(Debug) Print("Market SELL placed");
          }
        }
        state = ST_IDLE; return;
      }
    }else{
      bool hit   = (rates[i].low <= bosLevel);
      bool close = (rates[i].close >= bosLevel);
      if( (P.RetestNeedClose ? (hit && close) : hit) ){
        if(P.UsePendingRetest){ PlacePendingAfterBOS(false); }
        else{
          double sl = sweepLow - P.SL_BufferUSD;
          double entry = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
          double lots = CalcLotByRisk(MathAbs(entry - sl));
          if(lots>0 && PositionsOnThisMagic()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD){
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

//=========================== PRESETS v2.1 ===========================//
// Reset numbering từ #1. Gợi ý mapping:
//  1..5  : NY/LDN “core PF cao” (được tinh từ batch bạn báo: 91/92/123/125/107).
//  6..10 : Booster tăng tần suất (PF 2.5–3.4).
//  11..12: High-frequency (PF ~1.2–1.5) dùng lot nhỏ.
//  13..20: Biến thể (pending/wick-only/bridge/asia…).
bool ApplyPresetBuiltIn(int id){
  UseInputsAsParams();  // base từ inputs
  switch(id){
    case 0:  return true;  // Custom

    // ===== CORE PF CAO =====
    case 1:  // NY_CORE_PF6 (clone tinh thần UC31/92)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.30;
      P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
      P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=true; P.UsePendingRetest=false;
      return true;

    case 2:  // NY_CORE_PF6_8 (biến thể chặt hơn chút)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true;  P.RNDelta=0.30; P.L_percentile=150;
      P.KZ3s=1160; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1280;
      P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.50;
      P.RetestNeedClose=true; P.UsePendingRetest=false;
      return true;

    case 3:  // NY_CORE_CLASSIC_PF6_1
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.30; P.L_percentile=120;
      P.KZ3s=1160; P.KZ3e=1190; P.KZ4s=1255; P.KZ4e=1280;
      P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=true; P.UsePendingRetest=false;
      return true;

    case 4:  // LDN_CORE_PF5_5
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.35; P.L_percentile=150;
      P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
      P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=true; P.UsePendingRetest=false;
      return true;

    case 5:  // LDN_CORE_ALT (sniper hơn)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.30; P.L_percentile=180;
      P.KZ1s=835; P.KZ1e=865;
      P.K_swing=65; P.N_bos=5; P.M_retest=2; P.EqTol=0.15; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.45;
      P.RetestNeedClose=true; P.UsePendingRetest=false;
      return true;

    // ===== BOOSTERS (tăng số kèo) =====
    case 6:  // BOOSTER_PF3_2 (gần UC113)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.30; P.L_percentile=150;
      P.KZ3s=1160; P.KZ3e=1185;
      P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=false;  // wick-only để tăng tần suất
      return true;

    case 7:  // BOOSTER_PF3_4 (gần UC115)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.35; P.L_percentile=150;
      P.KZ1s=835; P.KZ1e=865;
      P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=false;
      return true;

    case 8:  // BOOSTER_PF2_5 (gần UC116)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.35;
      P.KZ1s=835; P.KZ1e=900;
      P.K_swing=55; P.N_bos=6; P.M_retest=4; P.EqTol=0.25; P.BOSBufferPoints=1.0;
      P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.70;
      P.RetestNeedClose=false;
      return true;

    case 9:  // BOOSTER_PF2_6 (gần UC120)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.30;
      P.KZ3s=1160; P.KZ3e=1185;
      P.K_swing=60; P.N_bos=5; P.M_retest=4; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=false;
      return true;

    case 10: // BOOSTER_PF3_6 (gần UC32/34/36)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.30;
      P.KZ3s=1160; P.KZ3e=1190;
      P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=false;
      return true;

    // ===== HIGH-FREQ (lot nhỏ) =====
    case 11: // HF_PF1_2 (gần UC111)
      P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.35;
      P.K_swing=45; P.N_bos=7; P.M_retest=4; P.EqTol=0.30; P.BOSBufferPoints=1.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.90;
      P.RiskPerTradePct = 0.25;   // lot nhỏ hơn
      P.RetestNeedClose=false;
      return true;

    case 12: // HF_PF1_5 (gần UC112)
      P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.30; P.L_percentile=120;
      P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.5;
      P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.80;
      P.RiskPerTradePct = 0.30;
      P.RetestNeedClose=false;
      return true;

    // ===== BIẾN THỂ / TUỲ CHỌN =====
    case 13: // NY_PENDING_05
      ApplyPresetBuiltIn(3); P.UsePendingRetest=true; P.RetestOffsetUSD=0.05; P.PendingExpirySec=60;
      return true;

    case 14: // NY_PENDING_10
      ApplyPresetBuiltIn(3); P.UsePendingRetest=true; P.RetestOffsetUSD=0.10; P.PendingExpirySec=45; P.SL_BufferUSD=0.75;
      return true;

    case 15: // NY_WICK_ONLY (core #1 nhưng wick-only)
      ApplyPresetBuiltIn(1); P.RetestNeedClose=false;
      return true;

    case 16: // LDN_WICK_ONLY (core #4 nhưng wick-only)
      ApplyPresetBuiltIn(4); P.RetestNeedClose=false;
      return true;

    case 17: // BRIDGE_LDN_NY (nối KZ2->KZ3)
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.35; P.L_percentile=150;
      P.KZ2s=985; P.KZ2e=1010; P.KZ3s=1160; P.KZ3e=1185;
      P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=true;
      return true;

    case 18: // ASIA_TIGHT
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.30; P.L_percentile=150;
      P.KZ1s=90; P.KZ1e=330;
      P.K_swing=60; P.N_bos=5; P.M_retest=4; P.EqTol=0.18; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60;
      P.RetestNeedClose=true;
      return true;

    case 19: // ALLDAY_RN_ONLY
      P.UseKillzones=false; P.UseRoundNumber=true; P.UseVSA=false; P.RNDelta=0.35;
      P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.0;
      P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.70;
      P.RetestNeedClose=false;
      return true;

    case 20: // ULTRA_CONSERVATIVE
      P.UseKillzones=true; P.UseRoundNumber=true; P.UseVSA=true; P.RNDelta=0.25; P.L_percentile=200;
      P.KZ1s=835; P.KZ1e=865; P.KZ3s=1160; P.KZ3e=1185;
      P.K_swing=75; P.N_bos=5; P.M_retest=2; P.EqTol=0.15; P.BOSBufferPoints=2.0;
      P.SL_BufferUSD=0.75; P.MaxSpreadUSD=0.45;
      P.RetestNeedClose=true;
      return true;

          // ===== SHIFT KZ để tránh 0-trade =====
    case 21: // NY_CORE_PF6_SHIFT_-10 (từ case 1)
    P=(ApplyPresetBuiltIn(1),P);
    P.KZ3s=1155; P.KZ3e=1175; P.KZ4s=1245; P.KZ4e=1265;
    return true;

  case 22: // NY_CORE_PF6_SHIFT_+10
    P=(ApplyPresetBuiltIn(1),P);
    P.KZ3s=1175; P.KZ3e=1195; P.KZ4s=1265; P.KZ4e=1285;
    return true;

  case 23: // LDN_CORE_PF5_5_SHIFT_-10 (từ case 4)
    P=(ApplyPresetBuiltIn(4),P);
    P.KZ1s=825; P.KZ1e=855; P.KZ2s=975; P.KZ2e=995;
    return true;

  case 24: // LDN_CORE_PF5_5_SHIFT_+10
    P=(ApplyPresetBuiltIn(4),P);
    P.KZ1s=845; P.KZ1e=875; P.KZ2s=995; P.KZ2e=1015;
    return true;

  // ===== Wick-only để tăng tần suất =====
  case 25: // NY_CORE_WICK (từ case 1)
    P=(ApplyPresetBuiltIn(1),P); P.RetestNeedClose=false; return true;

  case 26: // LDN_CORE_WICK (từ case 4)
    P=(ApplyPresetBuiltIn(4),P); P.RetestNeedClose=false; return true;

  // ===== BE/Pending tối ưu RR/fill =====
  case 27: // NY_CORE_BE_1R_PARTIAL30 (từ case 1)
    P=(ApplyPresetBuiltIn(1),P);
    P.BE_Activate_R=1.0; P.PartialClosePct=30; return true;

  case 28: // NY_CORE_PENDING_03 (từ case 1)
    P=(ApplyPresetBuiltIn(1),P);
    P.UsePendingRetest=true; P.RetestOffsetUSD=0.03; P.PendingExpirySec=60; return true;

  // ===== Boosters quanh UC8/9/10 (nhiều kèo, PF ~2–3) =====
  case 29: // BOOSTER_NY_RN32_BE1R
    P.UseKillzones=true; P.KZ3s=1160; P.KZ3e=1190;
    P.UseRoundNumber=true; P.RNDelta=0.32; P.UseVSA=false;
    P.K_swing=52; P.N_bos=6; P.M_retest=4; P.EqTol=0.22; P.BOSBufferPoints=1.5;
    P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65;
    P.BE_Activate_R=1.0; P.PartialClosePct=30;
    P.RetestNeedClose=false; return true;

  case 30: // BOOSTER_NY_RN30_PENDING05
    P.UseKillzones=true; P.KZ3s=1160; P.KZ3e=1185;
    P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
    P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.24; P.BOSBufferPoints=1.5;
    P.UsePendingRetest=true; P.RetestOffsetUSD=0.05; P.PendingExpirySec=60;
    P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65;
    P.RetestNeedClose=false; return true;

  case 31: // BOOSTER_LDN_RN35_WIDE
    P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
    P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
    P.K_swing=55; P.N_bos=6; P.M_retest=4; P.EqTol=0.24; P.BOSBufferPoints=1.5;
    P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65;
    P.RetestNeedClose=false; return true;

  case 32: // BOOSTER_ALLDAY_RN_ONLY_STRICT_SPREAD
    P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
    P.K_swing=50; P.N_bos=6; P.M_retest=4; P.EqTol=0.24; P.BOSBufferPoints=1.2;
    P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55;
    P.RetestNeedClose=false; return true;


    default: return false;
  }
}

//============================= INIT/TICK ============================//
bool SetupParamsFromPreset(){
  UseInputsAsParams();
  bool ok = true;
  if(UsePreset){ ok = ApplyPresetBuiltIn(PresetID); }
  if(Debug) Print("v2.1 Preset applied: ok=",ok," | PresetID=",PresetID);
  return ok;
}

int OnInit(){
  g_magic = MagicBase + (long)PresetID;
  trade.SetExpertMagicNumber(g_magic);
  trade.SetAsyncMode(false);
  SetupParamsFromPreset();
  return(INIT_SUCCEEDED);
}

void OnTick(){
  if(!UpdateRates()) return;

  if(ArraySize(rates)>=2 && rates[1].time != last_bar_time){
    last_bar_time = rates[1].time;
    DetectBOSAndArm();
    TryEnterAfterRetest();
  }
  ManageOpenPosition();
}

void OnDeinit(const int reason){}
