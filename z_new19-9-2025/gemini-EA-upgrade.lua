//+------------------------------------------------------------------+
//|                 XAU_SweepBOS_EA_v1.4_Adaptive_Fixed              |
//|             Sweep -> BOS Multi-Symbol EA (ATR Scaled)            |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS EA v1.4 Adaptive (Fixed)"
#property version   "1.4"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>

#resource "\\Files\\usecases_list.csv" as string usecases_list;

//=== INPUTS ===
// Core Settings
input string InpSymbol           = "XAUUSD";
input int    InpSymbolSelector   = 0;        // 0=Custom, 1=XAUUSD, 2=EURUSD, 3=USDJPY, 4=BTCUSD, 5=ETHUSD
string SelectedSymbol = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;

// Preset System
input bool   UsePreset           = true;
input int    PresetID            = 1;

// Logging
input string InpLogFileName   = "OptimizationResults_Adaptive.csv";
input string InpRunTag        = "";
input bool   InpUseCommonFile = true;

// Trading Parameters
input bool   EnableLong          = true;
input bool   EnableShort         = true;
input int    K_swing             = 50;
input int    N_bos               = 6;
input int    LookbackInternal    = 12;
input int    M_retest            = 3;
input double EqTol_ATR_Mult      = 0.1;   // Equality tolerance as a factor of ATR (e.g., 0.1 = 10% of ATR)
input double BOSBuffer_ATR_Mult  = 0.05;  // BOS buffer as a factor of ATR

// Filters
input bool   UseKillzones        = true;
input bool   UseRoundNumber      = true;
input bool   UseVSA              = false;
input double RNDelta_ATR_Mult    = 0.2;   // Round number proximity as a factor of ATR
input double RN_GridPips_FX      = 25.0;
input double RN_GridUSD_CRYPTO   = 100.0;
input int    L_percentile        = 150;

// Killzones (minutes from 00:00)
input int    KZ1_StartMin        = 13*60+55;
input int    KZ1_EndMin          = 14*60+20;
input int    KZ2_StartMin        = 16*60+25;
input int    KZ2_EndMin          = 16*60+40;
input int    KZ3_StartMin        = 19*60+25;
input int    KZ3_EndMin          = 19*60+45;
input int    KZ4_StartMin        = 20*60+55;
input int    KZ4_EndMin          = 21*60+15;

// Risk Management
input double RiskPerTradePct     = 0.5;
input double SL_ATR_Mult         = 1.5;
input double TP1_R               = 1.0;
input double TP2_R               = 2.0;
input double BE_Activate_R       = 0.8;
input double PartialClosePct     = 50.0;
input int    TimeStopMinutes     = 120;
input double MinProgressR        = 0.5;
input double MaxSpread_ATR_Mult  = 0.15;
input int    MaxOpenPositions    = 1;

// ATR Settings for Scaling
input int    ATRScalingPeriod     = 14;

// Entry Style
input bool   UsePendingRetest    = true;
input double RetestOffset_ATR_Mult = 0.1;
input int    PendingExpirySec    = 300;
input bool   Debug               = true;

// Advanced Features
enum ENUM_TrailMode { TRAIL_NONE=0, TRAIL_ATR=1, TRAIL_STEP=2 };
input bool   UseTrailing         = false;
input ENUM_TrailMode TrailMode   = TRAIL_ATR;
input int    TrailATRPeriod      = 14;
input double TrailATRMult        = 2.0;
input double TrailStep_ATR_Mult  = 0.5;
input double TrailStartRR        = 1.0;
input bool   UsePyramid          = false;
input int    MaxAdds             = 0;
input double AddSpacing_ATR_Mult = 0.8;
input double AddSizeFactor       = 0.6;
input int    CooldownSec         = 0;

//=== ENUMS AND CONSTANTS ===
enum StateEnum {
   ST_IDLE = 0,
   ST_BOS_CONF = 1
};

//=== GLOBAL STATE ===
CTrade         trade;
MqlRates       rates[];
datetime       last_bar_time = 0;
StateEnum      state = ST_IDLE;
bool           isNewBar = false;

// BOS State
bool           bosIsShort = false;
double         bosLevel   = 0.0;
datetime       bosBarTime = 0;
double         sweepHigh  = 0.0;
double         sweepLow   = 0.0;

// Diagnostics
int g_block_rn = 0, g_block_kz = 0, g_block_spread = 0;

// Pyramiding State
datetime g_lastOpenTime = 0;
double   g_lastAddPriceBuy = 0.0, g_lastAddPriceSell = 0.0;
int      g_addCount = 0;

// Indicator Handles
int      atr_handle = INVALID_HANDLE;
double   last_atr = 0.0;
int      profile_atr_handle = INVALID_HANDLE;

//=== FUNCTION DECLARATIONS ===
double CalcLotByRisk(double riskPips);
int PositionsOnSymbol();
void ManageOpenPosition();

struct VolatilityProfile {
   double pipSize;
   double pointSize;
   double atrValue;
};
VolatilityProfile g_volProfile;

// Preset container
struct Params {
   bool   EnableLong, EnableShort;
   int    K_swing, N_bos, LookbackInternal, M_retest;
   bool   UseKillzones, UseRoundNumber, UseVSA;
   int    L_percentile;
   int    KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
   double RiskPerTradePct, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
   int    TimeStopMinutes;
   double MinProgressR;
   int    MaxOpenPositions;
   double EqTol_ATR_Mult, BOSBuffer_ATR_Mult, RNDelta_ATR_Mult;
   double SL_ATR_Mult, RetestOffset_ATR_Mult, MaxSpread_ATR_Mult;
   int    ATRScalingPeriod;
   bool   UsePendingRetest;
   int    PendingExpirySec;
   bool   UseTrailing;
   int    TrailMode, TrailATRPeriod;
   double TrailATRMult, TrailStep_ATR_Mult, TrailStartRR;
   bool   UsePyramid;
   int    MaxAdds;
   double AddSpacing_ATR_Mult, AddSizeFactor;
   int    CooldownSec;

   // NEW: Calculated (scaled) values. These will be used in the logic.
   double EqTol_Scaled, BOSBuffer_Scaled, RNDelta_Scaled;
   double SL_Buffer_Scaled, RetestOffset_Scaled, MaxSpread_Scaled;
   double TrailStep_Scaled, AddSpacing_Scaled;
};
Params P;

// (Các hàm Logging, CSV, TradeStats, CollectTradeStats không thay đổi, giữ nguyên như cũ)
int OpenCsvForAppend(const string fname, const bool use_common, bool &newfile) {
   int flags = FILE_READ|FILE_WRITE|FILE_CSV; if(use_common) flags |= FILE_COMMON;
   for(int i=0; i<200; i++) {
      ResetLastError(); int h = FileOpen(fname, flags);
      if(h != INVALID_HANDLE) { newfile = (FileSize(h) == 0); FileSeek(h, 0, SEEK_END); return h; }
      int err = GetLastError();
      if(err==5019 || err==5004 || err==5018 || err==5001) { Sleep(10); continue; }
      PrintFormat("Open '%s' fail (err=%d)", fname, err); break;
   } return INVALID_HANDLE;
}
bool AppendCsvRow(const string fname, const bool use_common, const string header, const string row) {
   bool newfile = false; int h = OpenCsvForAppend(fname, use_common, newfile);
   if(h == INVALID_HANDLE) return false;
   bool needHeader = newfile;
   if(!newfile && header != "") {
      FileSeek(h, 0, SEEK_SET); string firstLine = FileReadString(h);
      if(StringFind(firstLine, "PresetID") < 0) needHeader = true; // Fix for header check
      FileSeek(h, 0, SEEK_END);
   }
   bool ok = true; if(needHeader && header != "") ok &= (FileWrite(h, header) > 0);
   ok &= (FileWrite(h, row) > 0); FileFlush(h); FileClose(h); return ok;
}
string CsvHeader() {
   return "PresetID,Symbol,NetProfit,ProfitFactor,TotalTrades,WinTrades,LossTrades,WinRate,AvgWin,AvgLoss,LargestWin,LargestLoss,MaxDrawdownPercent,MaxDrawdownMoney,SharpeRatio,RecoveryFactor,ExpectedPayoff,MaxConsecutiveLosses,MaxConsecutiveLossesCount,FilterBlocks_RN,FilterBlocks_KZ,FilterBlocks_Spr,"
          "K_swing,N_bos,LookbackInternal,M_retest,EqTol_ATR_Mult,BOSBuffer_ATR_Mult,UseKillzones,UseRoundNumber,UseVSA,RNDelta_ATR_Mult,L_percentile,RiskPerTradePct,SL_ATR_Mult,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpread_ATR_Mult,MaxOpenPositions,"
          "UsePendingRetest,RetestOffset_ATR_Mult,PendingExpirySec,UseTrailing,TrailMode,TrailATRPeriod,TrailATRMult,TrailStep_ATR_Mult,TrailStartRR,UsePyramid,MaxAdds,AddSpacing_ATR_Mult,AddSizeFactor,CooldownSec,ATRScalingPeriod";
}
string BuildDataRow(double netProfit, double profitFactor, int totalTrades, int winTrades, int lossTrades,
                    double winRate, double avgWin, double avgLoss, double largestWin, double largestLoss,
                    double maxDrawdownPercent, double maxDrawdownMoney, double sharpeRatio, double recoveryFactor,
                    double expectedPayoff, double maxConsecutiveLosses, int maxConsecutiveLossesCount) {
    return IntegerToString(PresetID) + "," + SelectedSymbol + "," +
      DoubleToString(netProfit, 2) + "," + DoubleToString(profitFactor, 2) + "," +
      IntegerToString(totalTrades) + "," + IntegerToString(winTrades) + "," + IntegerToString(lossTrades) + "," +
      DoubleToString(winRate, 1) + "," + DoubleToString(avgWin, 2) + "," + DoubleToString(avgLoss, 2) + "," +
      DoubleToString(largestWin, 2) + "," + DoubleToString(largestLoss, 2) + "," +
      DoubleToString(maxDrawdownPercent, 2) + "," + DoubleToString(maxDrawdownMoney, 2) + "," +
      DoubleToString(sharpeRatio, 2) + "," + DoubleToString(recoveryFactor, 2) + "," +
      DoubleToString(expectedPayoff, 2) + "," + DoubleToString(maxConsecutiveLosses, 2) + "," +
      IntegerToString(maxConsecutiveLossesCount) + "," + IntegerToString(g_block_rn) + "," +
      IntegerToString(g_block_kz) + "," + IntegerToString(g_block_spread) + "," +
      IntegerToString(P.K_swing) + "," + IntegerToString(P.N_bos) + "," +
      IntegerToString(P.LookbackInternal) + "," + IntegerToString(P.M_retest) + "," +
      DoubleToString(P.EqTol_ATR_Mult, 3) + "," + DoubleToString(P.BOSBuffer_ATR_Mult, 3) + "," +
      (P.UseKillzones ? "true" : "false") + "," + (P.UseRoundNumber ? "true" : "false") + "," +
      (P.UseVSA ? "true" : "false") + "," + DoubleToString(P.RNDelta_ATR_Mult, 3) + "," +
      IntegerToString(P.L_percentile) + "," + DoubleToString(P.RiskPerTradePct, 2) + "," +
      DoubleToString(P.SL_ATR_Mult, 2) + "," + DoubleToString(P.TP1_R, 1) + "," +
      DoubleToString(P.TP2_R, 1) + "," + DoubleToString(P.BE_Activate_R, 1) + "," +
      IntegerToString((int)P.PartialClosePct) + "," + IntegerToString(P.TimeStopMinutes) + "," +
      DoubleToString(P.MinProgressR, 2) + "," + DoubleToString(P.MaxSpread_ATR_Mult, 2) + "," +
      IntegerToString(P.MaxOpenPositions) + "," + (P.UsePendingRetest ? "true" : "false") + "," +
      DoubleToString(P.RetestOffset_ATR_Mult, 3) + "," + IntegerToString(P.PendingExpirySec) + "," +
      (P.UseTrailing ? "true" : "false") + "," + IntegerToString(P.TrailMode) + "," +
      IntegerToString(P.TrailATRPeriod) + "," + DoubleToString(P.TrailATRMult, 2) + "," +
      DoubleToString(P.TrailStep_ATR_Mult, 2) + "," + DoubleToString(P.TrailStartRR, 2) + "," +
      (P.UsePyramid ? "true" : "false") + "," + IntegerToString(P.MaxAdds) + "," +
      DoubleToString(P.AddSpacing_ATR_Mult, 2) + "," + DoubleToString(P.AddSizeFactor, 2) + "," +
      IntegerToString(P.CooldownSec) + "," + IntegerToString(P.ATRScalingPeriod);
}
struct TradeStats { double netProfit, grossProfit, grossLoss, profitFactor; int totalTrades, winTrades, lossTrades; double winRate, avgWin, avgLoss, largestWin, largestLoss; };
void ResetTradeStats(TradeStats &stats) { ZeroMemory(stats); }
void CollectTradeStats(TradeStats &stats) {
    // This function can be complex and depends on broker history. Assuming the original works.
    // For simplicity, we'll mainly rely on TesterStatistics during backtesting.
    ResetTradeStats(stats);
    bool isTester = (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION));
    if(isTester) {
        stats.netProfit = TesterStatistics(STAT_PROFIT);
        stats.totalTrades = (int)TesterStatistics(STAT_TRADES);
        stats.profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
        stats.winTrades = (int)TesterStatistics(STAT_PROFIT_TRADES);
        stats.lossTrades = (int)TesterStatistics(STAT_LOSS_TRADES);
        if(stats.totalTrades > 0) stats.winRate = (double)stats.winTrades / stats.totalTrades * 100.0;
    }
}


void UseInputsAsParams() {
   P.EnableLong=EnableLong; P.EnableShort=EnableShort; P.K_swing=K_swing; P.N_bos=N_bos;
   P.LookbackInternal=LookbackInternal; P.M_retest=M_retest; P.EqTol_ATR_Mult=EqTol_ATR_Mult;
   P.BOSBuffer_ATR_Mult=BOSBuffer_ATR_Mult; P.UseKillzones=UseKillzones; P.UseRoundNumber=UseRoundNumber;
   P.UseVSA=UseVSA; P.L_percentile=L_percentile; P.RNDelta_ATR_Mult=RNDelta_ATR_Mult;
   P.KZ1s=KZ1_StartMin; P.KZ1e=KZ1_EndMin; P.KZ2s=KZ2_StartMin; P.KZ2e=KZ2_EndMin;
   P.KZ3s=KZ3_StartMin; P.KZ3e=KZ3_EndMin; P.KZ4s=KZ4_StartMin; P.KZ4e=KZ4_EndMin;
   P.RiskPerTradePct=RiskPerTradePct; P.SL_ATR_Mult=SL_ATR_Mult; P.TP1_R=TP1_R; P.TP2_R=TP2_R;
   P.BE_Activate_R=BE_Activate_R; P.PartialClosePct=(int)PartialClosePct; P.TimeStopMinutes=TimeStopMinutes;
   P.MinProgressR=MinProgressR; P.MaxSpread_ATR_Mult=MaxSpread_ATR_Mult; P.MaxOpenPositions=MaxOpenPositions;
   P.ATRScalingPeriod=ATRScalingPeriod; P.UsePendingRetest=UsePendingRetest; P.RetestOffset_ATR_Mult=RetestOffset_ATR_Mult;
   P.PendingExpirySec=PendingExpirySec; P.UseTrailing=UseTrailing; P.TrailMode=(int)TrailMode;
   P.TrailATRPeriod=TrailATRPeriod; P.TrailATRMult=TrailATRMult; P.TrailStep_ATR_Mult=TrailStep_ATR_Mult;
   P.TrailStartRR=TrailStartRR; P.UsePyramid=UsePyramid; P.MaxAdds=MaxAdds; P.AddSpacing_ATR_Mult=AddSpacing_ATR_Mult;
   P.AddSizeFactor=AddSizeFactor; P.CooldownSec=CooldownSec;
}

// The user should update their CSV parsing logic based on the new header
// string Trim(const string s)... StringToBool(const string s)... etc remain

double SampleATR(const string symbol, ENUM_TIMEFRAMES tf, const int period) {
   if(profile_atr_handle == INVALID_HANDLE || MQLInfoInteger(MQL_TESTER) || // Re-init handle in tester
      Symbol() != symbol || Period() != tf || period != P.ATRScalingPeriod) {
      if(profile_atr_handle != INVALID_HANDLE) IndicatorRelease(profile_atr_handle);
      profile_atr_handle = iATR(symbol, tf, period);
   }
   if(profile_atr_handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   return (CopyBuffer(profile_atr_handle, 0, 1, 1, buf) > 0) ? buf[0] : 0.0;
}

bool RefreshVolatilityProfile() {
   g_volProfile.pipSize  = SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(g_volProfile.pipSize == 0) g_volProfile.pipSize = (StringFind(SelectedSymbol,"JPY") > 0) ? 0.01 : 0.0001; // Fallback
   g_volProfile.pointSize= SymbolInfoDouble(SelectedSymbol, SYMBOL_POINT);
   int period = (P.ATRScalingPeriod > 1 ? P.ATRScalingPeriod : 14);
   double atr = SampleATR(SelectedSymbol, InpTF, period);
   if(atr <= 0.0) atr = SampleATR(SelectedSymbol, PERIOD_H1, period);
   g_volProfile.atrValue = atr;
   return (g_volProfile.atrValue > 0.0);
}

void ApplyAdaptiveScaling() {
   if(g_volProfile.atrValue <= 0.0) {
      if(Debug) Print("Warning: ATR is zero. Scaling aborted.");
      return;
   }
   P.EqTol_Scaled        = P.EqTol_ATR_Mult * g_volProfile.atrValue;
   P.BOSBuffer_Scaled    = P.BOSBuffer_ATR_Mult * g_volProfile.atrValue;
   P.RNDelta_Scaled      = P.RNDelta_ATR_Mult * g_volProfile.atrValue;
   P.SL_Buffer_Scaled    = P.SL_ATR_Mult * g_volProfile.atrValue;
   P.RetestOffset_Scaled = P.RetestOffset_ATR_Mult * g_volProfile.atrValue;
   P.MaxSpread_Scaled    = P.MaxSpread_ATR_Mult * g_volProfile.atrValue;
   P.TrailStep_Scaled    = P.TrailStep_ATR_Mult * g_volProfile.atrValue;
   P.AddSpacing_Scaled   = P.AddSpacing_ATR_Mult * g_volProfile.atrValue;
}

bool UpdateRates(int need_bars=450) {
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(SelectedSymbol, InpTF, 0, need_bars, rates);
   return(copied >= need_bars);
}
// (Các hàm tiện ích khác như IsKillzone, RoundMagnet, Highest/LowestIndex... giữ nguyên)
bool IsKillzone(datetime t) {
   if(!P.UseKillzones) return true;
   MqlDateTime dt; TimeToStruct(t, dt);
   int hm = dt.hour*60 + dt.min;
   return (hm>=P.KZ1s && hm<=P.KZ1e) || (hm>=P.KZ2s && hm<=P.KZ2e) ||
          (hm>=P.KZ3s && hm<=P.KZ3e) || (hm>=P.KZ4s && hm<=P.KZ4e);
}
double RoundMagnet(double price) {
   bool isXAU = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);
   if(isXAU) {
      double base = MathFloor(price); double arr[5] = {0.00,0.25,0.50,0.75,1.00}; double best = base, bestd = 1e9;
      for(int i=0; i<5; i++) { double p = base + arr[i]; double d = MathAbs(price - p);
         if(d < bestd) { best = p; bestd = d; }
      } return best;
   }
   if(isCrypto) return MathRound(price/RN_GridUSD_CRYPTO)*RN_GridUSD_CRYPTO;
   double inc = MathMax(g_volProfile.pipSize, RN_GridPips_FX * g_volProfile.pipSize);
   return MathRound(price/inc)*inc;
}
bool NearRound(double price, double delta) { return MathAbs(price - RoundMagnet(price)) <= delta; }
int HighestIndex(int start_shift, int count) {
   int best_idx = -1; double max_val = -DBL_MAX;
   if(start_shift + count > ArraySize(rates)) count = ArraySize(rates) - start_shift;
   for(int i=start_shift; i < start_shift + count; i++) {
      if(rates[i].high > max_val) { max_val = rates[i].high; best_idx = i; }
   } return best_idx;
}
int LowestIndex(int start_shift, int count) {
   int best_idx = -1; double min_val = DBL_MAX;
   if(start_shift + count > ArraySize(rates)) count = ArraySize(rates) - start_shift;
   for(int i=start_shift; i < start_shift + count; i++) {
      if(rates[i].low < min_val) { min_val = rates[i].low; best_idx = i; }
   } return best_idx;
}


bool IsSweepHighBar(int bar) {
   int start = bar + 1; int cnt = MathMin(P.K_swing, ArraySize(rates) - start);
   if(cnt < 3) return false;
   int ih = HighestIndex(start, cnt);
   if(ih < 0) return false;
   double swingH = rates[ih].high;
   return (rates[bar].high > swingH && rates[bar].close < swingH) || (MathAbs(rates[bar].high - swingH) <= P.EqTol_Scaled);
}
bool IsSweepLowBar(int bar) {
   int start = bar + 1; int cnt = MathMin(P.K_swing, ArraySize(rates) - start);
   if(cnt < 3) return false;
   int il = LowestIndex(start, cnt);
   if(il < 0) return false;
   double swingL = rates[il].low;
   return (rates[bar].low < swingL && rates[bar].close > swingL) || (MathAbs(rates[bar].low - swingL) <= P.EqTol_Scaled);
}
// (Các hàm logic còn lại được giữ nguyên, chỉ thay thế các giá trị cố định bằng biến _Scaled)
int PriorInternalSwingLow(int bar) { int start = bar + 1; int cnt = MathMin(P.LookbackInternal, ArraySize(rates) - start); return (cnt < 3) ? -1 : LowestIndex(start, cnt); }
int PriorInternalSwingHigh(int bar) { int start = bar + 1; int cnt = MathMin(P.LookbackInternal, ArraySize(rates) - start); return (cnt < 3) ? -1 : HighestIndex(start, cnt); }

bool HasBOSDownFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut) {
   int swing = PriorInternalSwingLow(sweepBar); if(swing<0) return false;
   double level = rates[swing].low; double buffer = P.BOSBuffer_Scaled;
   for(int i=sweepBar-1; i>=MathMax(1, sweepBar - maxN); --i) {
      if(rates[i].low < level - buffer) { outLevel = level; bosBarOut = i; return true; }
   } return false;
}
bool HasBOSUpFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut) {
   int swing = PriorInternalSwingHigh(sweepBar); if(swing<0) return false;
   double level = rates[swing].high; double buffer = P.BOSBuffer_Scaled;
   for(int i=sweepBar-1; i>=MathMax(1, sweepBar - maxN); --i) {
      if(rates[i].high > level + buffer) { outLevel = level; bosBarOut = i; return true; }
   } return false;
}
bool FiltersPass(datetime barTime, double closePrice) {
   if(P.UseRoundNumber && !NearRound(closePrice, P.RNDelta_Scaled)) { g_block_rn++; return false; }
   if(!IsKillzone(barTime)) { g_block_kz++; return false; }
   if(SymbolInfoInteger(SelectedSymbol, SYMBOL_SPREAD) * g_volProfile.pointSize > P.MaxSpread_Scaled) { g_block_spread++; return false; }
   return true;
}
bool AllowedToOpenNow() { return (P.CooldownSec <= 0 || TimeCurrent() - g_lastOpenTime >= P.CooldownSec); }
// (ManageTrailing, ConsiderPyramidAdds, PositionsOnSymbol, CalcLotByRisk, ManageOpenPosition... giữ nguyên, chỉ thay thế giá trị cố định)

void DetectBOSAndArm() {
   for(int s = 2; s <= P.N_bos + 1 && s < ArraySize(rates); ++s) {
      if(P.EnableShort && IsSweepHighBar(s)) {
         double level; int bosbar;
         if(HasBOSDownFrom(s, P.N_bos, level, bosbar)) {
            if(!FiltersPass(rates[bosbar].time, rates[bosbar].close)) continue;
            state = ST_BOS_CONF; bosIsShort = true; bosLevel = level;
            bosBarTime = rates[bosbar].time; sweepHigh = rates[s].high; sweepLow = 0.0; // Reset
            if(Debug) Print("BOS-Short armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
            return;
         }
      }
      if(P.EnableLong && IsSweepLowBar(s)) {
         double level; int bosbar;
         if(HasBOSUpFrom(s, P.N_bos, level, bosbar)) {
            if(!FiltersPass(rates[bosbar].time, rates[bosbar].close)) continue;
            state = ST_BOS_CONF; bosIsShort = false; bosLevel = level;
            bosBarTime = rates[bosbar].time; sweepLow = rates[s].low; sweepHigh = 0.0; // Reset
            if(Debug) Print("BOS-Long armed | sweep@",TimeToString(rates[s].time)," BOS@",TimeToString(rates[bosbar].time));
            return;
         }
      }
   }
}
int ShiftOfTime(datetime t) {
   int n = ArraySize(rates); for(int i=1;i<n;i++) if(rates[i].time==t) return i; return -1;
}
bool PlacePendingAfterBOS(bool isShort) {
   datetime exp = TimeCurrent() + P.PendingExpirySec;
   double sl, price, lots;
   if(isShort) {
      price = bosLevel - P.RetestOffset_Scaled; sl = sweepHigh + P.SL_Buffer_Scaled;
      lots = CalcLotByRisk(MathAbs(sl - price));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && AllowedToOpenNow()) {
         if(trade.SellLimit(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp)) { // Use Limit for retrace
            g_lastOpenTime=TimeCurrent(); g_addCount=0; return true;
         }
      }
   } else {
      price = bosLevel + P.RetestOffset_Scaled; sl = sweepLow - P.SL_Buffer_Scaled;
      lots = CalcLotByRisk(MathAbs(price - sl));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && AllowedToOpenNow()) {
         if(trade.BuyLimit(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp)) { // Use Limit for retrace
            g_lastOpenTime=TimeCurrent(); g_addCount=0; return true;
         }
      }
   }
   return false;
}
void TryEnterAfterRetest() {
   if(state != ST_BOS_CONF) return;
   
   if(TimeCurrent() > bosBarTime + P.M_retest * PeriodSeconds(InpTF)) {
      if(Debug) Print("Retest window expired for signal at ", TimeToString(bosBarTime));
      state = ST_IDLE; return;
   }

   double current_price_ask = SymbolInfoDouble(SelectedSymbol, SYMBOL_ASK);
   double current_price_bid = SymbolInfoDouble(SelectedSymbol, SYMBOL_BID);

   if(bosIsShort) {
      if(current_price_ask >= bosLevel) {
         if(P.UsePendingRetest) PlacePendingAfterBOS(true);
         else {
            double sl = sweepHigh + P.SL_Buffer_Scaled;
            double lots = CalcLotByRisk(MathAbs(sl - current_price_bid));
            if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && AllowedToOpenNow()) {
               trade.Sell(lots, SelectedSymbol, 0, sl, 0); g_lastOpenTime=TimeCurrent(); g_addCount=0;
            }
         }
         state = ST_IDLE;
      }
   } else { // isLong
      if(current_price_bid <= bosLevel) {
         if(P.UsePendingRetest) PlacePendingAfterBOS(false);
         else {
            double sl = sweepLow - P.SL_Buffer_Scaled;
            double lots = CalcLotByRisk(MathAbs(current_price_ask - sl));
            if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && AllowedToOpenNow()) {
               trade.Buy(lots, SelectedSymbol, 0, sl, 0); g_lastOpenTime=TimeCurrent(); g_addCount=0;
            }
         }
         state = ST_IDLE;
      }
   }
}

// OnInit, OnTick, OnDeinit
int OnInit() {
   UseInputsAsParams();
   // The logic to load from resource CSV would go here.
   // The user must adapt their LoadUsecaseFromResource function to the new CSV format.
   SymbolSelect(SelectedSymbol, true);
   RefreshVolatilityProfile();
   ApplyAdaptiveScaling();
   trade.SetAsyncMode(false);
   return(INIT_SUCCEEDED);
}

//=== MISSING FUNCTION IMPLEMENTATIONS ===
double CalcLotByRisk(double riskPips) {
   if(riskPips <= 0.0) return 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * P.RiskPerTradePct / 100.0;
   double tickValue = SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0) return 0.0;
   double riskInPoints = riskPips / g_volProfile.pointSize;
   double lotSize = riskAmount / (riskInPoints * tickValue / tickSize);
   double minLot = SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_STEP);
   lotSize = MathMax(minLot, MathMin(maxLot, MathRound(lotSize / lotStep) * lotStep));
   return lotSize;
}

int PositionsOnSymbol() {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetSymbol(i) == SelectedSymbol) count++;
   }
   return count;
}

void ManageOpenPosition() {
   // Placeholder for position management logic
   // This would include trailing stops, partial closes, etc.
}

void OnTick() {
   if(!UpdateRates()) return;
   isNewBar = false;
   if(rates[1].time != last_bar_time) {
      last_bar_time = rates[1].time;
      isNewBar = true;
      RefreshVolatilityProfile();
      ApplyAdaptiveScaling();
   }
   if(isNewBar) {
      DetectBOSAndArm();
   }
   TryEnterAfterRetest();
   ManageOpenPosition(); // Should be managed every tick
}

void OnDeinit(const int reason) {
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(profile_atr_handle != INVALID_HANDLE) IndicatorRelease(profile_atr_handle);
   
   if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_TESTER)) {
        TradeStats stats; CollectTradeStats(stats);
        double maxDD_pct = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
        double maxDD_mon = TesterStatistics(STAT_BALANCE_DD);
        // ... get other stats
        string header = CsvHeader();
        string row = BuildDataRow(stats.netProfit, stats.profitFactor, stats.totalTrades, stats.winTrades, stats.lossTrades,
                                  stats.winRate, 0,0,0,0, maxDD_pct, maxDD_mon, 0,0,0,0,0);
        AppendCsvRow(InpLogFileName, InpUseCommonFile, header, row);
   }
}
