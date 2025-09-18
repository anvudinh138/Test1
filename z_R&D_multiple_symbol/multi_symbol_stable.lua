//+------------------------------------------------------------------+
//|                           XAU_SweepBOS_EA_v1.2_Refactored       |
//|                       Sweep -> BOS Multi-Symbol EA               |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS EA v1.2 Refactored"
#property version   "1.2"
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
input bool   AutoSymbolProfile   = true;     // Auto scale parameters by symbol

// Multi-Symbol Controls
input bool   UseMultiSymbol   = true;
input string InpSymbolsCSV    = "";         // Optional override list when preset lacks symbols
input bool   UseMsTimer       = true;
input int    InpTimerMs       = 200;
input int    InpTimerSeconds  = 1;
input bool   UseFixedLot      = true;
input double InpFixedLot      = 0.01;
input double MarginBufferPct  = 5.0;
input int    MagicBase        = 532100;

// Preset System
input bool   UsePreset           = true;
input int    PresetID            = 1;

// Logging
input string InpLogFileName   = "OptimizationResults1.csv";
input string InpRunTag        = "";
input bool   InpUseCommonFile = true;

// Trading Parameters
input bool   EnableLong          = true;
input bool   EnableShort         = true;
input int    K_swing             = 50;
input int    N_bos               = 6;
input int    LookbackInternal    = 12;
input int    M_retest            = 3;
input double EqTol               = 0.20;
input double BOSBufferPoints     = 2.0;

// Filters
input bool   UseKillzones        = true;
input bool   UseRoundNumber      = true;
input bool   UseVSA              = false;
input double RNDelta             = 0.30;
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
input double SL_BufferUSD        = 0.50;
input double TP1_R               = 1.0;
input double TP2_R               = 2.0;
input double BE_Activate_R       = 0.8;
input double PartialClosePct     = 50.0;
input int    TimeStopMinutes     = 5;
input double MinProgressR        = 0.5;
input double MaxSpreadUSD        = 0.50;
input int    MaxOpenPositions    = 1;

// Entry Style
input bool   UsePendingRetest    = false;
input double RetestOffsetUSD     = 0.07;
input int    PendingExpirySec    = 60;
input bool   Debug               = true;

// Advanced Features
enum ENUM_TrailMode { TRAIL_NONE=0, TRAIL_ATR=1, TRAIL_STEP=2 };
input bool   UseTrailing         = false;
input ENUM_TrailMode TrailMode   = TRAIL_NONE;
input int    TrailATRPeriod      = 14;
input double TrailATRMult        = 2.0;
input double TrailStepUSD        = 0.30;
input double TrailStartRR        = 1.0;
input bool   UsePyramid          = false;
input int    MaxAdds             = 0;
input double AddSpacingUSD       = 0.40;
input double AddSizeFactor       = 0.6;
input int    CooldownSec         = 0;

//=== GLOBAL STATE ===
CTrade         trade;
MqlRates       rates[];
datetime       last_bar_time = 0;

enum StateEnum { ST_IDLE=0, ST_BOS_CONF };
StateEnum      state = ST_IDLE;

// Multi-symbol runtime state
string   CurrSymbol   = "";
int      CurrSymIndex = -1;

struct SymState
  {
   string   sym;
   datetime last_bar_time;
   int      state_val;
   bool     bosIsShort;
   double   bosLevel;
   datetime bosBarTime;
   double   sweepHigh;
   double   sweepLow;
   datetime g_lastOpenTime;
   double   g_lastAddPriceBuy;
   double   g_lastAddPriceSell;
   int      g_addCount;
   int      atr_handle;
   double   last_atr;
  };

SymState gSymStates[];
string   gPresetSymbolsCSV = "";
string   gPresetSymbols[];
string   gSymbolsLogLabel = "";
bool     gTimerActive = false;

// BOS State
bool           bosIsShort = false;
double         bosLevel   = 0.0;
datetime       bosBarTime = 0;
double         sweepHigh  = 0.0;
double         sweepLow   = 0.0;

// Diagnostics
int g_block_rn = 0, g_block_kz = 0, g_block_spread = 0;

// Sprint-1 State
datetime g_lastOpenTime = 0;
double   g_lastAddPriceBuy = 0.0, g_lastAddPriceSell = 0.0;
int      g_addCount = 0;
int      atr_handle = INVALID_HANDLE;
double   last_atr = 0.0;

//=== LOGGING SYSTEM ===
int OpenCsvForAppend(const string fname, const bool use_common, bool &newfile)
  {
   int flags = FILE_READ|FILE_WRITE|FILE_CSV;
   if(use_common)
      flags |= FILE_COMMON;

   for(int i=0; i<200; i++)
     {
      ResetLastError();
      int h = FileOpen(fname, flags);
      if(h != INVALID_HANDLE)
        {
         newfile = (FileSize(h) == 0);
         FileSeek(h, 0, SEEK_END);
         return h;
        }
      int err = GetLastError();
      if(err==5019 || err==5004 || err==5018 || err==5001)
        {
         Sleep(10);
         continue;
        }
      PrintFormat("Open '%s' fail (err=%d)", fname, err);
      break;
     }
   return INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AppendCsvRow(const string fname, const bool use_common, const string header, const string row)
  {
   bool newfile = false;
   int h = OpenCsvForAppend(fname, use_common, newfile);
   if(h == INVALID_HANDLE)
      return false;

   bool needHeader = newfile;
   if(!newfile && header != "")
     {
      FileSeek(h, 0, SEEK_SET);
      string firstLine = FileReadString(h);
      if(StringFind(firstLine, "RunID") != 0)
         needHeader = true;
      FileSeek(h, 0, SEEK_END);
     }

   bool ok = true;
   if(needHeader && header != "")
      ok &= (FileWrite(h, header) > 0);
   ok &= (FileWrite(h, row) > 0);

   FileFlush(h);
   FileClose(h);
   return ok;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CsvHeader()
  {
   return "PresetID,Symbols,NetProfit,ProfitFactor,TotalTrades,WinTrades,LossTrades,WinRate,AvgWin,AvgLoss,LargestWin,LargestLoss,MaxDrawdownPercent,MaxDrawdownMoney,SharpeRatio,RecoveryFactor,ExpectedPayoff,MaxConsecutiveLosses,MaxConsecutiveLossesCount,FilterBlocks_RN,FilterBlocks_KZ,FilterBlocks_Spr,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,UseKillzones,UseRoundNumber,UseVSA,RNDelta,L_percentile,RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec,UseTrailing,TrailMode,TrailATRPeriod,TrailATRMult,TrailStepUSD,TrailStartRR,UsePyramid,MaxAdds,AddSpacingUSD,AddSizeFactor,CooldownSec";
  }

string JoinSymbols(const string &symbols[])
  {
   int count = ArraySize(symbols);
   if(count <= 0)
      return "";
   string acc = symbols[0];
   for(int i=1; i<count; ++i)
      acc += "_" + symbols[i];
   return acc;
  }

string SymbolsLogLabel()
  {
   if(gSymbolsLogLabel != "")
      return gSymbolsLogLabel;
   if(gPresetSymbolsCSV != "")
      return gPresetSymbolsCSV;
   if(ArraySize(gPresetSymbols) > 0)
      return JoinSymbols(gPresetSymbols);
   return SelectedSymbol;
  }

// Build dòng dữ liệu từ kết quả backtest
string BuildDataRow(double netProfit, double profitFactor, int totalTrades, int winTrades, int lossTrades,
                    double winRate, double avgWin, double avgLoss, double largestWin, double largestLoss,
                    double maxDrawdownPercent, double maxDrawdownMoney, double sharpeRatio, double recoveryFactor, 
                    double expectedPayoff, double maxConsecutiveLosses, int maxConsecutiveLossesCount)
  {
   string row =
      IntegerToString(PresetID) + "," +
      SymbolsLogLabel() + "," +
      DoubleToString(netProfit, 2) + "," +
      DoubleToString(profitFactor, 2) + "," +
      IntegerToString(totalTrades) + "," +
      IntegerToString(winTrades) + "," +
      IntegerToString(lossTrades) + "," +
      DoubleToString(winRate, 1) + "," +
      DoubleToString(avgWin, 2) + "," +
      DoubleToString(avgLoss, 2) + "," +
      DoubleToString(largestWin, 2) + "," +
      DoubleToString(largestLoss, 2) + "," +
      DoubleToString(maxDrawdownPercent, 2) + "," +
      DoubleToString(maxDrawdownMoney, 2) + "," +
      DoubleToString(sharpeRatio, 2) + "," +
      DoubleToString(recoveryFactor, 2) + "," +
      DoubleToString(expectedPayoff, 2) + "," +
      DoubleToString(maxConsecutiveLosses, 2) + "," +
      IntegerToString(maxConsecutiveLossesCount) + "," +
      IntegerToString(g_block_rn) + "," +
      IntegerToString(g_block_kz) + "," +
      IntegerToString(g_block_spread) + "," +
      IntegerToString(P.K_swing) + "," +
      IntegerToString(P.N_bos) + "," +
      IntegerToString(P.LookbackInternal) + "," +
      IntegerToString(P.M_retest) + "," +
      DoubleToString(P.EqTol, 2) + "," +
      DoubleToString(P.BOSBufferPoints, 2) + "," +
       (P.UseKillzones ? "true" : "false") + "," +
       (P.UseRoundNumber ? "true" : "false") + "," +
       (P.UseVSA ? "true" : "false") + "," +
      DoubleToString(P.RNDelta, 2) + "," +
      IntegerToString(P.L_percentile) + "," +
      DoubleToString(P.RiskPerTradePct, 2) + "," +
      DoubleToString(P.SL_BufferUSD, 2) + "," +
      DoubleToString(P.TP1_R, 1) + "," +
      DoubleToString(P.TP2_R, 1) + "," +
      DoubleToString(P.BE_Activate_R, 1) + "," +
      IntegerToString((int)P.PartialClosePct) + "," +
      IntegerToString(P.TimeStopMinutes) + "," +
      DoubleToString(P.MinProgressR, 2) + "," +
      DoubleToString(P.MaxSpreadUSD, 2) + "," +
      IntegerToString(P.MaxOpenPositions) + "," +
       (P.UsePendingRetest ? "true" : "false") + "," +
      DoubleToString(P.RetestOffsetUSD, 2) + "," +
      IntegerToString(P.PendingExpirySec) + "," +
       (P.UseTrailing ? "true" : "false") + "," +
      IntegerToString(P.TrailMode) + "," +
      IntegerToString(P.TrailATRPeriod) + "," +
      DoubleToString(P.TrailATRMult, 2) + "," +
      DoubleToString(P.TrailStepUSD, 2) + "," +
      DoubleToString(P.TrailStartRR, 2) + "," +
       (P.UsePyramid ? "true" : "false") + "," +
      IntegerToString(P.MaxAdds) + "," +
      DoubleToString(P.AddSpacingUSD, 2) + "," +
      DoubleToString(P.AddSizeFactor, 2) + "," +
      IntegerToString(P.CooldownSec);
   return row;
  }

struct TradeStats
  {
   double            netProfit;
   double            grossProfit;
   double            grossLoss;
   double            profitFactor;
   int               totalTrades;
   int               winTrades;
   int               lossTrades;
   double            winRate;
   double            avgWin;
   double            avgLoss;
   double            largestWin;
   double            largestLoss;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetTradeStats(TradeStats &stats)
  {
   stats.netProfit   = 0.0;
   stats.grossProfit = 0.0;
   stats.grossLoss   = 0.0;
   stats.profitFactor= 0.0;
   stats.totalTrades = 0;
   stats.winTrades   = 0;
   stats.lossTrades  = 0;
   stats.winRate     = 0.0;
   stats.avgWin      = 0.0;
   stats.avgLoss     = 0.0;
   stats.largestWin  = 0.0;
   stats.largestLoss = 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CollectTradeStats(TradeStats &stats)
  {
   ResetTradeStats(stats);

   const double eps = 1e-8;
   bool isTester = (MQLInfoInteger(MQL_TESTER) != 0 || MQLInfoInteger(MQL_OPTIMIZATION) != 0);

// Pull core numbers from tester statistics when available (covers optimization runs even if deal history is empty)
   if(isTester)
     {
      double testerNet         = TesterStatistics(STAT_PROFIT);
      double testerGrossProfit = TesterStatistics(STAT_GROSS_PROFIT);
      double testerGrossLoss   = TesterStatistics(STAT_GROSS_LOSS);
      int    testerWins        = (int)TesterStatistics(STAT_PROFIT_TRADES);
      int    testerLosses      = (int)TesterStatistics(STAT_LOSS_TRADES);
      int    testerTotal       = (int)TesterStatistics(STAT_TRADES);
      double testerPF          = TesterStatistics(STAT_PROFIT_FACTOR);

      stats.netProfit   = testerNet;
      stats.grossProfit = testerGrossProfit;
      stats.grossLoss   = MathAbs(testerGrossLoss);
      stats.winTrades   = testerWins;
      stats.lossTrades  = testerLosses;
      stats.totalTrades = testerTotal;
      stats.profitFactor= testerPF;

      if(stats.totalTrades > 0)
         stats.winRate = (double)stats.winTrades / stats.totalTrades * 100.0;
      if(stats.winTrades > 0)
         stats.avgWin = stats.grossProfit / stats.winTrades;
      if(stats.lossTrades > 0 && stats.grossLoss > 0.0)
         stats.avgLoss = -stats.grossLoss / stats.lossTrades;
     }

// Walk trade history for largest win/loss and to supply stats when running outside of tester
   double manualNet = 0.0;
   double manualGrossProfit = 0.0;
   double manualGrossLoss = 0.0;
   double manualLossSum = 0.0;
   int manualWins = 0;
   int manualLosses = 0;


   if(HistorySelect(0, TimeCurrent()))
     {
      int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; ++i)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;

         string dealSym="";
         HistoryDealGetString(ticket, DEAL_SYMBOL, dealSym);
         long dealMagic=0;
         HistoryDealGetInteger(ticket, DEAL_MAGIC, dealMagic);
         if(!IncludeDealForStats(dealSym, dealMagic))
            continue;

         long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
            continue;


         double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         if(pnl > stats.largestWin)
            stats.largestWin = pnl;
         if(pnl < stats.largestLoss)
            stats.largestLoss = pnl;

         if(!isTester)
           {
            manualNet += pnl;
            if(pnl > eps)
              {
               manualGrossProfit += pnl;
               manualWins++;
              }
            else
               if(pnl < -eps)
                 {
                  manualGrossLoss += MathAbs(pnl);
                  manualLossSum += pnl;
                  manualLosses++;
                 }
           }
        }
     }


   if(!isTester)
     {
      stats.netProfit   = manualNet;
      stats.grossProfit = manualGrossProfit;
      stats.grossLoss   = manualGrossLoss;
      stats.winTrades   = manualWins;
      stats.lossTrades  = manualLosses;
      stats.totalTrades = manualWins + manualLosses;

      if(stats.totalTrades > 0)
         stats.winRate = (double)stats.winTrades / stats.totalTrades * 100.0;
      if(stats.winTrades > 0)
         stats.avgWin = stats.grossProfit / stats.winTrades;
      if(stats.lossTrades > 0)
         stats.avgLoss = manualLossSum / stats.lossTrades;
      if(stats.grossLoss > eps)
         stats.profitFactor = stats.grossProfit / stats.grossLoss;
     }

   if(stats.totalTrades == 0)
      stats.totalTrades = stats.winTrades + stats.lossTrades;
   if(stats.totalTrades > 0)
      stats.winRate = (double)stats.winTrades / stats.totalTrades * 100.0;
  }


// Preset container
struct Params
  {
   // switches
   bool              EnableLong;
   bool              EnableShort;
   // core
   int               K_swing, N_bos, LookbackInternal, M_retest;
   double            EqTol, BOSBufferPoints;
   // filters
   bool              UseKillzones, UseRoundNumber, UseVSA;
   int               L_percentile;
   double            RNDelta;
   int               KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
   // risk
   double            RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
   int               TimeStopMinutes;
   double            MinProgressR;
   // exec
   double            MaxSpreadUSD;
   int               MaxOpenPositions;
   // entry style
   bool              UsePendingRetest;
   double            RetestOffsetUSD;
   int               PendingExpirySec;
   // sprint1
   bool              UseTrailing;
   int               TrailMode, TrailATRPeriod;
   double            TrailATRMult, TrailStepUSD, TrailStartRR;
   bool              UsePyramid;
   int               MaxAdds;
   double            AddSpacingUSD, AddSizeFactor;
   int               CooldownSec;
  };
Params P;



// Apply inputs to P (as defaults)
void UseInputsAsParams()
  {
   P.EnableLong=EnableLong;
   P.EnableShort=EnableShort;
   P.K_swing=K_swing;
   P.N_bos=N_bos;
   P.LookbackInternal=LookbackInternal;
   P.M_retest=M_retest;
   P.EqTol=EqTol;
   P.BOSBufferPoints=BOSBufferPoints;
   P.UseKillzones=UseKillzones;
   P.UseRoundNumber=UseRoundNumber;
   P.UseVSA=UseVSA;
   P.L_percentile=L_percentile;
   P.RNDelta=RNDelta;
   P.KZ1s=KZ1_StartMin;
   P.KZ1e=KZ1_EndMin;
   P.KZ2s=KZ2_StartMin;
   P.KZ2e=KZ2_EndMin;
   P.KZ3s=KZ3_StartMin;
   P.KZ3e=KZ3_EndMin;
   P.KZ4s=KZ4_StartMin;
   P.KZ4e=KZ4_EndMin;
   P.RiskPerTradePct=RiskPerTradePct;
   P.SL_BufferUSD=SL_BufferUSD;
   P.TP1_R=TP1_R;
   P.TP2_R=TP2_R;
   P.BE_Activate_R=BE_Activate_R;
   P.PartialClosePct=(int)PartialClosePct;
   P.TimeStopMinutes=TimeStopMinutes;
   P.MinProgressR=MinProgressR;
   P.MaxSpreadUSD=MaxSpreadUSD;
   P.MaxOpenPositions=MaxOpenPositions;
   P.UsePendingRetest=UsePendingRetest;
   P.RetestOffsetUSD=RetestOffsetUSD;
   P.PendingExpirySec=PendingExpirySec;
   P.UseTrailing=UseTrailing;
   P.TrailMode=(int)TrailMode;
   P.TrailATRPeriod=TrailATRPeriod;
   P.TrailATRMult=TrailATRMult;
   P.TrailStepUSD=TrailStepUSD;
   P.TrailStartRR=TrailStartRR;
   P.UsePyramid=UsePyramid;
   P.MaxAdds=MaxAdds;
   P.AddSpacingUSD=AddSpacingUSD;
   P.AddSizeFactor=AddSizeFactor;
   P.CooldownSec=CooldownSec;
  }

//===================== USECASE GENERATOR (NO CSV) =====================//

struct UCRow
  {
   string            SymbolsCSV;
   string            PrimarySymbol;
   int               K_swing, N_bos, LookbackInternal, M_retest;
   double            EqTol, BOSBufferPoints;
   int               UseKillzones, UseRoundNumber, UseVSA;
   double            RNDelta;
   int               L_percentile;
   double            RiskPerTradePct;
   double            SL_BufferUSD;
   double            TP1_R, TP2_R, BE_Activate_R;
   int               PartialClosePct;
   int               TimeStopMinutes;
   double            MinProgressR;
   double            MaxSpreadUSD;
   int               MaxOpenPositions;
   int               UsePendingRetest;
   double            RetestOffsetUSD;
   int               PendingExpirySec;
   int               UseTrailing;
   int               TrailMode;
   int               TrailATRPeriod;
   double            TrailATRMult;
   double            TrailStepUSD;
   double            TrailStartRR;
   int               UsePyramid;
   int               MaxAdds;
   double            AddSpacingUSD;
   double            AddSizeFactor;
   int               CooldownSec;
  };


// Helper functions removed - using CSV data directly

// Apply CSV row to parameters
void ApplyCSVRowToParams(const UCRow &r)
  {
   string primary = r.PrimarySymbol;
   if(primary == "")
      primary = SelectedSymbol;
   if(primary == "")
      primary = InpSymbol;
   SelectedSymbol = primary;

   ConfigureSymbolUniverse(r.SymbolsCSV);

   if(ArraySize(gPresetSymbols) > 0)
      SelectedSymbol = gPresetSymbols[0];

   for(int i=0; i<ArraySize(gPresetSymbols); ++i)
      SymbolSelect(gPresetSymbols[i], true);

   P.K_swing          = r.K_swing;
   P.N_bos            = r.N_bos;
   P.LookbackInternal = r.LookbackInternal;
   P.M_retest         = r.M_retest;
   P.EqTol            = r.EqTol;
   P.BOSBufferPoints  = r.BOSBufferPoints;
   P.UseKillzones     = r.UseKillzones;
   P.UseRoundNumber   = r.UseRoundNumber;
   P.UseVSA           = r.UseVSA;
   P.RNDelta          = r.RNDelta;
   P.L_percentile     = r.L_percentile;
   if(!P.UseKillzones)
     {
      P.KZ1s = KZ1_StartMin;
      P.KZ1e = KZ1_EndMin;
      P.KZ2s = KZ2_StartMin;
      P.KZ2e = KZ2_EndMin;
      P.KZ3s = KZ3_StartMin;
      P.KZ3e = KZ3_EndMin;
      P.KZ4s = KZ4_StartMin;
      P.KZ4e = KZ4_EndMin;
     }

// Then apply to P from globals
   P.RiskPerTradePct  = r.RiskPerTradePct;
   P.SL_BufferUSD     = r.SL_BufferUSD;
   P.TP1_R            = r.TP1_R;
   P.TP2_R            = r.TP2_R;
   P.BE_Activate_R    =  r.BE_Activate_R;
   P.PartialClosePct  = (double)r.PartialClosePct;
   P.TimeStopMinutes  = r.TimeStopMinutes;
   P.MinProgressR     = r.MinProgressR;
   P.MaxSpreadUSD     = r.MaxSpreadUSD;
   P.MaxOpenPositions = r.MaxOpenPositions;
   P.UsePendingRetest = r.UsePendingRetest;
   P.RetestOffsetUSD  = r.RetestOffsetUSD;
   P.PendingExpirySec = r.PendingExpirySec;
   P.UseTrailing      = r.UseTrailing;
   P.TrailMode        = r.TrailMode;
   P.TrailATRPeriod   = r.TrailATRPeriod;
   P.TrailATRMult     = r.TrailATRMult;
   P.TrailStepUSD     = r.TrailStepUSD;
   P.TrailStartRR     = r.TrailStartRR;
   P.UsePyramid       = r.UsePyramid;
   P.MaxAdds          = r.MaxAdds;
   P.AddSpacingUSD    = r.AddSpacingUSD;
   P.AddSizeFactor    = r.AddSizeFactor;
   P.CooldownSec      = r.CooldownSec;
  }

// CSV Utilities
string Trim(const string s) { string t = s; StringTrimLeft(t); StringTrimRight(t); return t; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool StringToBool(const string s)
  {
   string trimmed = Trim(s);
   StringToLower(trimmed);
   return (trimmed == "true" || trimmed == "1");
  }

int ParseSymbolsString(const string raw, string &out[])
  {
   ArrayResize(out, 0);
   string work = Trim(raw);
   if(work == "")
      return 0;

   string normalized = work;
   StringReplace(normalized, "\r", "");
   StringReplace(normalized, "\n", "");
   StringReplace(normalized, " ", "");
   // Allow both comma and underscore separated lists
   StringReplace(normalized, ",", "_");

   string parts[];
   int tokens = StringSplit(normalized, '_', parts);
   for(int i=0; i<tokens; ++i)
     {
      string token = Trim(parts[i]);
      if(token == "")
         continue;
      int cur = ArraySize(out);
      ArrayResize(out, cur+1);
      out[cur] = token;
     }
   return ArraySize(out);
  }

void ConfigureSymbolUniverse(const string presetSymbols)
  {
   string rawLabel = Trim(presetSymbols);
   string candidate = rawLabel;
   if(candidate == "" && InpSymbolsCSV != "")
      candidate = Trim(InpSymbolsCSV);
   if(candidate == "")
      candidate = SelectedSymbol;

   gPresetSymbolsCSV = candidate;
   ParseSymbolsString(candidate, gPresetSymbols);
   if(ArraySize(gPresetSymbols) == 0)
     {
      ArrayResize(gPresetSymbols, 1);
      gPresetSymbols[0] = (SelectedSymbol != "" ? SelectedSymbol : InpSymbol);
     }
   gSymbolsLogLabel = (rawLabel != "" ? rawLabel : JoinSymbols(gPresetSymbols));
   if(gSymbolsLogLabel == "" && ArraySize(gPresetSymbols) > 0)
      gSymbolsLogLabel = JoinSymbols(gPresetSymbols);
  }

int FindConfiguredSymbolIndex(const string sym)
  {
   for(int i=0; i<ArraySize(gPresetSymbols); ++i)
      if(gPresetSymbols[i] == sym)
         return i;
   return -1;
  }

bool IncludeDealForStats(const string sym, long magic)
  {
   int idx = FindConfiguredSymbolIndex(sym);
   if(idx < 0)
      return false;
   if(UseMultiSymbol)
      return (magic == MagicBase + idx);
   return (sym == SelectedSymbol);
  }

bool CanAfford(const string s, bool isShort, double vol, double bufferPct)
  {
   double price = SymbolInfoDouble(s, isShort ? SYMBOL_BID : SYMBOL_ASK);
   double marginNeeded = 0.0;
   if(!OrderCalcMargin(isShort ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, s, vol, price, marginNeeded))
     {
      PrintFormat("[%s] OrderCalcMargin failed (vol=%.2f) err=%d", s, vol, GetLastError());
      return false;
     }
   double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double required = marginNeeded * (1.0 + bufferPct/100.0);
   if(free < required)
     {
      PrintFormat("[%s] Not enough margin: need=%.2f (buffer %.1f%%) free=%.2f", s, required, bufferPct, free);
      return false;
     }
   return true;
  }

void InitSymbolStates()
  {
   int count = ArraySize(gPresetSymbols);
   ArrayResize(gSymStates, count);
   for(int i=0; i<count; ++i)
     {
      gSymStates[i].sym              = gPresetSymbols[i];
      gSymStates[i].last_bar_time    = 0;
      gSymStates[i].state_val        = (int)ST_IDLE;
      gSymStates[i].bosIsShort       = false;
      gSymStates[i].bosLevel         = 0.0;
      gSymStates[i].bosBarTime       = 0;
      gSymStates[i].sweepHigh        = 0.0;
      gSymStates[i].sweepLow         = 0.0;
      gSymStates[i].g_lastOpenTime   = 0;
      gSymStates[i].g_lastAddPriceBuy  = 0.0;
      gSymStates[i].g_lastAddPriceSell = 0.0;
      gSymStates[i].g_addCount       = 0;
      gSymStates[i].atr_handle       = INVALID_HANDLE;
      gSymStates[i].last_atr         = 0.0;
     }
   if(count>0)
     {
      CurrSymIndex = 0;
      CurrSymbol   = gSymStates[0].sym;
      SelectedSymbol = CurrSymbol;
     }
  }

void SelectConfiguredSymbols()
  {
   for(int i=0; i<ArraySize(gPresetSymbols); ++i)
      SymbolSelect(gPresetSymbols[i], true);
  }

void LoadStateFromIndex(int idx)
  {
   if(idx < 0 || idx >= ArraySize(gSymStates))
      return;
   CurrSymIndex = idx;
   CurrSymbol   = gSymStates[idx].sym;
   SelectedSymbol = CurrSymbol;

   last_bar_time       = gSymStates[idx].last_bar_time;
   state               = (StateEnum)gSymStates[idx].state_val;
   bosIsShort          = gSymStates[idx].bosIsShort;
   bosLevel            = gSymStates[idx].bosLevel;
   bosBarTime          = gSymStates[idx].bosBarTime;
   sweepHigh           = gSymStates[idx].sweepHigh;
   sweepLow            = gSymStates[idx].sweepLow;
   g_lastOpenTime      = gSymStates[idx].g_lastOpenTime;
   g_lastAddPriceBuy   = gSymStates[idx].g_lastAddPriceBuy;
   g_lastAddPriceSell  = gSymStates[idx].g_lastAddPriceSell;
   g_addCount          = gSymStates[idx].g_addCount;
   atr_handle          = gSymStates[idx].atr_handle;
   last_atr            = gSymStates[idx].last_atr;
  }

void SaveStateToIndex(int idx)
  {
   if(idx < 0 || idx >= ArraySize(gSymStates))
      return;
   gSymStates[idx].last_bar_time      = last_bar_time;
   gSymStates[idx].state_val          = (int)state;
   gSymStates[idx].bosIsShort         = bosIsShort;
   gSymStates[idx].bosLevel           = bosLevel;
   gSymStates[idx].bosBarTime         = bosBarTime;
   gSymStates[idx].sweepHigh          = sweepHigh;
   gSymStates[idx].sweepLow           = sweepLow;
   gSymStates[idx].g_lastOpenTime     = g_lastOpenTime;
   gSymStates[idx].g_lastAddPriceBuy  = g_lastAddPriceBuy;
   gSymStates[idx].g_lastAddPriceSell = g_lastAddPriceSell;
   gSymStates[idx].g_addCount         = g_addCount;
   gSymStates[idx].atr_handle         = atr_handle;
   gSymStates[idx].last_atr           = last_atr;
  }

long ActiveMagic()
  {
   int idx = CurrSymIndex;
   if(idx < 0)
      idx = 0;
   if(!UseMultiSymbol)
      idx = 0;
   return MagicBase + idx;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ParseCSVValue(const string csvValue, const string symbol)
  {
   string trimmed = Trim(csvValue);

   if(StringFind(trimmed, "*pip") >= 0 && StringFind(trimmed, "*pipPoints") < 0)
     {
      string numStr = trimmed;
      StringReplace(numStr, "*pip", "");
      return StringToDouble(Trim(numStr)) * SymbolPipSize(symbol);
     }

   if(StringFind(trimmed, "*pipPoints") >= 0)
     {
      string numStr = trimmed;
      StringReplace(numStr, "*pipPoints", "");
      double multiplier = StringToDouble(Trim(numStr));
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         point = SymbolPoint();
      double pip = SymbolPipSize(symbol);
      return multiplier * (point > 0.0 ? pip/point : 0.0);
     }

   return StringToDouble(trimmed);
  }

// Tách 1 dòng CSV thành mảng fields, có hỗ trợ "quotes" và "" escape
int SplitCsvQuoted(const string line, string &out[], const uchar delim=',')
  {
   ArrayResize(out, 0);
   string field = "";
   bool inQuotes = false;
   int L = StringLen(line);

   for(int i=0;i<L;i++)
     {
      uchar ch = (uchar)StringGetCharacter(line, i);

      if(ch=='"')
        {
         // "" -> 1 dấu "
         if(inQuotes && i+1<L && StringGetCharacter(line,i+1)=='"')
           {
            field += "\"";
            i++;
           }
         else
           {
            inQuotes = !inQuotes;
           }
        }
      else
         if(ch==delim && !inQuotes)
           {
            int n = ArraySize(out);
            ArrayResize(out, n+1);
            out[n] = Trim(field);
            field = "";
           }
         else
           {
            field += CharToString(ch);
           }
     }
   int n = ArraySize(out);
   ArrayResize(out, n+1);
   out[n] = Trim(field);
   return ArraySize(out);
  }

// Đọc usecase từ resource (#resource as string)
bool LoadUsecaseFromResource(const int presetID, UCRow &row)
  {
   string csv = usecases_list;
// Chuẩn hoá xuống dòng
   StringReplace(csv, "\r", "");

   string lines[];
   int lineCount = StringSplit(csv, '\n', lines);
   if(lineCount<=1)
     {
      Print("ERROR: Resource CSV seems empty or has no data lines.");
      return false;
     }

   bool found=false;
// Bỏ header (dòng 0). Nếu CSV không có header, vòng lặp vẫn parse được.
   for(int i = 1; i < lineCount; i++)
     {
      string ln = lines[i];
      if(ln == "" || ln == "\n")
         continue;

      string fields[];
      int c = SplitCsvQuoted(ln, fields, ',');


      // Case,Symbol,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,UseKillzones,UseRoundNumber,UseVSA,RNDelta,L_percentile,RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec,UseTrailing,TrailMode,TrailATRPeriod,TrailATRMult,TrailStepUSD,TrailStartRR,UsePyramid,MaxAdds,AddSpacingUSD,AddSizeFactor,CooldownSec
      int csvPresetID = (int)StringToInteger(fields[0]);
      if(csvPresetID == presetID)
        {
         row.SymbolsCSV          = fields[1];
         string tmpSyms[];
         ParseSymbolsString(row.SymbolsCSV, tmpSyms);
         if(ArraySize(tmpSyms) > 0)
            row.PrimarySymbol = tmpSyms[0];
         else
            row.PrimarySymbol = Trim(fields[1]);
         string refSymbol = (row.PrimarySymbol != "" ? row.PrimarySymbol : SelectedSymbol);
         if(refSymbol == "")
            refSymbol = InpSymbol;

         row.K_swing              = (int)StringToInteger(fields[2]);
         row.N_bos                = (int)StringToInteger(fields[3]);
         row.LookbackInternal     = (int)StringToInteger(fields[4]);
         row.M_retest             = (int)StringToInteger(fields[5]);
         row.EqTol                = ParseCSVValue(fields[6], refSymbol);
         row.BOSBufferPoints      = ParseCSVValue(fields[7], refSymbol);
         row.UseKillzones         = StringToBool(fields[8]);
         row.UseRoundNumber       = StringToBool(fields[9]);
         row.UseVSA               = StringToBool(fields[10]);
         row.RNDelta              = ParseCSVValue(fields[11], refSymbol);
         row.L_percentile         = (int)StringToInteger(fields[12]);
         row.RiskPerTradePct      = StringToDouble(fields[13]);
         row.SL_BufferUSD         = ParseCSVValue(fields[14], refSymbol);
         row.TP1_R                = StringToDouble(fields[15]);
         row.TP2_R                = StringToDouble(fields[16]);
         row.BE_Activate_R        = StringToDouble(fields[17]);
         row.PartialClosePct      = (int)StringToInteger(fields[18]);
         row.TimeStopMinutes      = (int)StringToInteger(fields[19]);
         row.MinProgressR         = StringToDouble(fields[20]);
         row.MaxSpreadUSD         = StringToDouble(fields[21]);
         row.MaxOpenPositions     = (int)StringToInteger(fields[22]);
         row.UsePendingRetest     = StringToBool(fields[23]);
         row.RetestOffsetUSD      = ParseCSVValue(fields[24], refSymbol);
         row.PendingExpirySec     = (int)StringToInteger(fields[25]);

         if(Debug)
           {
            Print("DEBUG CSV PARSING: Symbols=", row.SymbolsCSV,
                  ", Ref=", refSymbol,
                  ", EqTol=", fields[6], " -> ", row.EqTol,
                  ", BOSBuffer=", fields[7], " -> ", row.BOSBufferPoints,
                  ", RNDelta=", fields[11], " -> ", row.RNDelta,
                  ", SL_Buffer=", fields[14], " -> ", row.SL_BufferUSD,
                  ", RetestOffset=", fields[24], " -> ", row.RetestOffsetUSD);
           }

         row.UseTrailing          = StringToBool(fields[26]);
         row.TrailMode            = (int)StringToInteger(fields[27]);
         row.TrailATRPeriod       = (int)StringToInteger(fields[28]);
         row.TrailATRMult         = StringToDouble(fields[29]);
         row.TrailStepUSD         = StringToDouble(fields[30]);
         row.TrailStartRR         = StringToDouble(fields[31]);
         row.UsePyramid           = StringToBool(fields[32]);
         row.MaxAdds              = (int)StringToInteger(fields[33]);
         row.AddSpacingUSD        = StringToDouble(fields[34]);
         row.AddSizeFactor        = StringToDouble(fields[35]);
         row.CooldownSec          = (int)StringToInteger(fields[36]);

         found = true;
         break;
        }
     }

   if(!found)
     {
      Print("ERROR: PresetID ", presetID, " not found in embedded resource CSV.");
      return false;
     }

   Print("SUCCESS: Loaded PresetID=", presetID, " from embedded resource.");
   return true;
  }


//=== UTILITY FUNCTIONS ===
// Symbol & Pip Functions
double SymbolPipSize(const string sym="")
  {
   string symbol_name = (sym=="" ? SelectedSymbol : sym);
   if(StringFind(symbol_name,"XAU",0)>=0)
      return 0.1;
   if(StringFind(symbol_name,"XAG",0)>=0)
      return 0.01;
   if(StringFind(symbol_name,"BTC",0)>=0)
      return 10.0;
   if(StringFind(symbol_name,"ETH",0)>=0)
      return 0.1;
   bool isJPY = (StringFind(symbol_name,"JPY",0)>=0);
   return isJPY ? 0.01 : 0.0001;
  }

double ComputeFixedLot(const string s, double desired)
  {
   double minlot=0.0, maxlot=0.0, lotstep=0.0;
   SymbolInfoDouble(s, SYMBOL_VOLUME_MIN, minlot);
   SymbolInfoDouble(s, SYMBOL_VOLUME_MAX, maxlot);
   SymbolInfoDouble(s, SYMBOL_VOLUME_STEP, lotstep);

   double vol = desired;
   if(lotstep > 0.0)
      vol = MathFloor(vol / lotstep) * lotstep;
   if(vol < minlot)
      vol = minlot;
   if(maxlot > 0.0 && vol > maxlot)
      vol = maxlot;

   int lotDigits = 2;
   if(lotstep > 0.0)
     {
      double stepDigits = MathLog10(1.0 / lotstep);
      lotDigits = (int)MathMax(0.0, MathRound(stepDigits));
     }
   return NormalizeDouble(vol, lotDigits);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PipsToPrice(double pips, const string sym="") { return pips * SymbolPipSize(sym); }
double PriceToPips(double pricediff, const string sym="")
  {
   double pip = SymbolPipSize(sym);
   return (pip<=0.0) ? 0.0 : pricediff / pip;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SymbolPoint() { return SymbolInfoDouble(SelectedSymbol, SYMBOL_POINT); }
double SpreadUSD()
  {
   MqlTick t;
   return SymbolInfoTick(SelectedSymbol,t) ? (t.ask - t.bid) : 0.0;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DefaultSpreadForSymbol(string symbol_name, double &hi, double &lo)
  {
   if(StringFind(symbol_name,"BTC",0) >= 0)
     {
      hi = 12.0;
      lo = 6.0;
      return true;
     }
   if(StringFind(symbol_name,"ETH",0) >= 0)
     {
      hi = 1.20;
      lo = 0.60;
      return true;
     }
   if(StringFind(symbol_name,"XAU",0) >= 0)
     {
      hi = 0.60;
      lo = 0.30;
      return true;
     }
   return false;
  }


// Tự scale tham số theo symbol/pip (chỉ "điều chỉnh nhẹ" khi dùng Custom hoặc preset không chuyên EU)
void ApplyAutoSymbolProfile()
  {
   if(!AutoSymbolProfile)
      return;

   double pip       = SymbolPipSize(SelectedSymbol);
   double point     = SymbolPoint();
   double pipPoints = (point>0.0 ? pip/point : 0.0);

// Spread guard từ catalogue (nếu có)
   double hi=0.0, lo=0.0;
   if(DefaultSpreadForSymbol(SelectedSymbol, hi, lo))
      P.MaxSpreadUSD = hi;

   bool isXAU    = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isJPY    = (StringFind(SelectedSymbol,"JPY",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);

   if(isCrypto)
     {
      // Crypto 24/7 – scale rộng hơn FX, tắt KZ mặc định
      P.UseKillzones      = false;
      P.EqTol             = MathMax(P.EqTol,          1.5*pip);
      P.RNDelta           = MathMax(P.RNDelta,        3.0*pip);   // BTC mặc định ±30$ (pip=10$)
      P.SL_BufferUSD      = MathMax(P.SL_BufferUSD,   8.0*pip);
      P.BOSBufferPoints   = MathMax(P.BOSBufferPoints,1.5*pipPoints);
      P.RetestOffsetUSD   = MathMax(P.RetestOffsetUSD,1.5*pip);
      P.AddSpacingUSD     = MathMax(P.AddSpacingUSD,  4.0*pip);
     }
   else
      if(!isXAU) // FX generic (EUR, JPY…)
        {
         P.EqTol             = MathMax(P.EqTol,          2.0*pip);
         P.RNDelta           = MathMax(P.RNDelta,        2.5*pip);
         P.SL_BufferUSD      = MathMax(P.SL_BufferUSD,   8.0*pip);
         P.BOSBufferPoints   = MathMax(P.BOSBufferPoints,2.0*pipPoints);
         P.RetestOffsetUSD   = MathMax(P.RetestOffsetUSD,2.0*pip);
         P.AddSpacingUSD     = MathMax(P.AddSpacingUSD,  6.0*pip);
        }
// XAU: giữ preset gốc
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool UpdateRates(int need_bars=400)
  {
   ArraySetAsSeries(rates,true);
   return CopyRates(SelectedSymbol, InpTF, 0, need_bars, rates) > 0;
  }

// Filter Functions
bool IsKillzone(datetime t)
  {
   if(!P.UseKillzones)
      return true;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int hm = dt.hour*60 + dt.min;
   return (hm>=P.KZ1s && hm<=P.KZ1e) || (hm>=P.KZ2s && hm<=P.KZ2e) ||
          (hm>=P.KZ3s && hm<=P.KZ3e) || (hm>=P.KZ4s && hm<=P.KZ4e);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RoundMagnet(double price)
  {
   bool isXAU = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);

   if(isXAU)
     {
      double base = MathFloor(price);
      double arr[5] = {0.00,0.25,0.50,0.75,1.00};
      double best = base, bestd = 1e9;
      for(int i=0; i<5; i++)
        {
         double p = base + arr[i];
         double d = MathAbs(price - p);
         if(d < bestd)
           {
            best = p;
            bestd = d;
           }
        }
      return best;
     }
   if(isCrypto)
      return MathRound(price/RN_GridUSD_CRYPTO)*RN_GridUSD_CRYPTO;

   double pip = SymbolPipSize(SelectedSymbol);
   double inc = RN_GridPips_FX * pip;
   return MathRound(price/inc)*inc;
  }

bool NearRound(double price, double delta) { return MathAbs(price - RoundMagnet(price)) <= delta; }

// Array Helper Functions
int HighestIndex(int start_shift, int count)
  {
   int best = start_shift;
   double h = rates[best].high;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i)
      if(rates[i].high > h)
        {
         h = rates[i].high;
         best = i;
        }
   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int LowestIndex(int start_shift, int count)
  {
   int best = start_shift;
   double l = rates[best].low;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i)
      if(rates[i].low < l)
        {
         l = rates[i].low;
         best = i;
        }
   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PercentileDouble(double &arr[], double p)
  {
   int n = ArraySize(arr);
   if(n<=0)
      return 0.0;
   ArraySort(arr); // ASC by default
   double idx = (p/100.0)*(n-1);
   int lo = (int)MathFloor(idx);
   int hi = (int)MathCeil(idx);
   if(lo==hi)
      return arr[lo];
   double w = idx - lo;
   return arr[lo]*(1.0-w) + arr[hi]*w;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EffortResultOK(int bar)  // bar shift>=1
  {
   if(!P.UseVSA)
      return true;
   int from = bar+1;
   int cnt  = MathMin(P.L_percentile, ArraySize(rates)-from);
   if(cnt<30)
      return false;
   double vol[];
   ArrayResize(vol,cnt);
   double rng[];
   ArrayResize(rng,cnt);
   for(int i=0;i<cnt;i++)
     {
      int sh = from+i;
      vol[i] = (double)rates[sh].tick_volume;
      rng[i] = (rates[sh].high - rates[sh].low);
     }
   double vtmp[];
   ArrayCopy(vtmp,vol);
   double rtmp[];
   ArrayCopy(rtmp,rng);
   double v90 = PercentileDouble(vtmp, 90.0);
   double r60 = PercentileDouble(rtmp, 60.0);
   double thisVol = (double)rates[bar].tick_volume;
   double thisRng = (rates[bar].high - rates[bar].low);
   return (thisVol >= v90 && thisRng <= r60);
  }


// Sweep Detection Functions
bool IsSweepHighBar(int bar)
  {
   int start = bar + 1;
   int cnt = MathMin(P.K_swing, ArraySize(rates) - start);
   if(cnt < 3)
      return false;

   int ih = HighestIndex(start, cnt);
   double swingH = rates[ih].high;
   double pt = SymbolPoint();

   return ((rates[bar].high > swingH + pt && rates[bar].close < swingH) ||
           (MathAbs(rates[bar].high - swingH) <= P.EqTol && rates[bar].close < swingH));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSweepLowBar(int bar)
  {
   int start = bar + 1;
   int cnt = MathMin(P.K_swing, ArraySize(rates) - start);
   if(cnt < 3)
      return false;

   int il = LowestIndex(start, cnt);
   double swingL = rates[il].low;
   double pt = SymbolPoint();

   return ((rates[bar].low < swingL - pt && rates[bar].close > swingL) ||
           (MathAbs(rates[bar].low - swingL) <= P.EqTol && rates[bar].close > swingL));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriorInternalSwingLow(int bar)
  {
   int start = bar + 1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates) - start);
   return (cnt < 3) ? -1 : LowestIndex(start, cnt);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriorInternalSwingHigh(int bar)
  {
   int start = bar + 1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates) - start);
   return (cnt < 3) ? -1 : HighestIndex(start, cnt);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasBOSDownFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut)
  {
   int swing = PriorInternalSwingLow(sweepBar);
   if(swing<0)
      return false;

   double level = rates[swing].low;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1;
   int to   = MathMax(1, sweepBar - maxN);

   for(int i=from; i>=to; --i)
     {
      if(rates[i].close < level - buffer || rates[i].low < level - buffer)
        {
         outLevel = level;
         bosBarOut = i;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasBOSUpFrom(int sweepBar, int maxN, double &outLevel, int &bosBarOut)
  {
   int swing = PriorInternalSwingHigh(sweepBar);
   if(swing<0)
      return false;

   double level = rates[swing].high;
   double buffer = P.BOSBufferPoints * SymbolPoint();
   int from = sweepBar-1;
   int to   = MathMax(1, sweepBar - maxN);

   for(int i=from; i>=to; --i)
     {
      if(rates[i].close > level + buffer || rates[i].high > level + buffer)
        {
         outLevel = level;
         bosBarOut = i;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FiltersPass(int bar)
  {
   double sp = SpreadUSD();
   if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta))
     {
      g_block_rn++;
      if(Debug)
         Print("BLOCK RN @", rates[bar].close);
      return false;
     }
   if(!IsKillzone(rates[bar].time))
     {
      g_block_kz++;
      if(Debug)
         Print("BLOCK KZ @", TimeToString(rates[bar].time));
      return false;
     }
   if(sp > P.MaxSpreadUSD)
     {
      g_block_spread++;
      if(Debug)
         Print("BLOCK Spread=", DoubleToString(sp,2));
      return false;
     }
   return true;
  }


// Trading Helper Functions
bool AllowedToOpenNow()
  {
   return (P.CooldownSec <= 0 || g_lastOpenTime == 0 || (TimeCurrent() - g_lastOpenTime) >= P.CooldownSec);
  }

void ProcessActiveSymbol()
  {
   trade.SetExpertMagicNumber(ActiveMagic());

   if(!UpdateRates(450))
      return;

   if(ArraySize(rates)>=2 && rates[1].time != last_bar_time)
     {
      last_bar_time = rates[1].time;
      if(Debug && UseMultiSymbol)
         PrintFormat("[%s] New bar close=%.5f", SelectedSymbol, rates[1].close);
      DetectBOSAndArm();
      TryEnterAfterRetest();
     }
   ManageOpenPosition();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetATR()
  {
   if(P.TrailATRPeriod<=1)
      return 0.0;
   static int last_period = 0;
   if(atr_handle==INVALID_HANDLE || last_period!=P.TrailATRPeriod)
     {
      if(atr_handle!=INVALID_HANDLE)
         IndicatorRelease(atr_handle);
      atr_handle = iATR(SelectedSymbol, InpTF, P.TrailATRPeriod);
      last_period = P.TrailATRPeriod;
     }
   double buf[];
   if(CopyBuffer(atr_handle, 0, 0, 2, buf) > 0)
     {
      last_atr = buf[0];
     }
   return last_atr;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailing(double entry, double &sl, long type, double curr, double risk_per_lot, double reachedR)
  {
   if(!P.UseTrailing || P.TrailMode==TRAIL_NONE)
      return;
   if(reachedR < P.TrailStartRR)
      return;
   double dist = 0.0;
   if(P.TrailMode==TRAIL_ATR)
     {
      double atr = GetATR();
      dist = atr * P.TrailATRMult;
     }
   else
      if(P.TrailMode==TRAIL_STEP)
        {
         dist = P.TrailStepUSD;
        }
   if(dist<=0.0)
      return;
   double newSL = sl;
   if(type==POSITION_TYPE_BUY)
     {
      double cand = curr - dist;
      if(cand>newSL)
         newSL = cand;
     }
   else
     {
      double cand = curr + dist;
      if(cand<newSL || newSL==0.0)
         newSL = cand;
     }
   if(newSL!=sl)
     {
      trade.PositionModify(SelectedSymbol, newSL, PositionGetDouble(POSITION_TP));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ConsiderPyramidAdds(long type, double entry, double curr, double sl)
  {
   if(!P.UsePyramid || P.MaxAdds<=0)
      return;
   if(PositionsOnSymbol() >= P.MaxOpenPositions)
      return;
   double spacing = P.AddSpacingUSD;
   if(spacing<=0)
      return;
// price moved in favor by spacing since last add / entry
   if(type==POSITION_TYPE_BUY)
     {
      double base = (g_addCount==0 ? entry : g_lastAddPriceBuy);
      if(curr - base >= spacing && AllowedToOpenNow())
        {
         double lots = PositionGetDouble(POSITION_VOLUME) * P.AddSizeFactor;
         if(lots>0 && SpreadUSD()<=P.MaxSpreadUSD)
           {
            if(CanAfford(SelectedSymbol, false, lots, MarginBufferPct) && AllowedToOpenNow())
              {
               trade.Buy(lots, SelectedSymbol, 0.0, sl, 0.0);
               g_lastOpenTime=TimeCurrent();
               g_lastAddPriceBuy=SymbolInfoDouble(SelectedSymbol,SYMBOL_ASK);
               g_addCount=0;
              }
            g_lastOpenTime = TimeCurrent();
            g_lastAddPriceBuy = curr;
            g_addCount++;
           }
        }
     }
   else
      if(type==POSITION_TYPE_SELL)
        {
         double base = (g_addCount==0 ? entry : g_lastAddPriceSell);
         if(base - curr >= spacing && AllowedToOpenNow())
           {
            double lots = PositionGetDouble(POSITION_VOLUME) * P.AddSizeFactor;
            if(lots>0 && SpreadUSD()<=P.MaxSpreadUSD)
              {
               if(CanAfford(SelectedSymbol, true, lots, MarginBufferPct) && AllowedToOpenNow())
                 {
                  trade.Sell(lots, SelectedSymbol, 0.0, sl, 0.0);
                  g_lastOpenTime=TimeCurrent();
                  g_lastAddPriceSell=SymbolInfoDouble(SelectedSymbol,SYMBOL_BID);
                  g_addCount=0;
                 }
               g_lastOpenTime = TimeCurrent();
               g_lastAddPriceSell = curr;
               g_addCount++;
              }
           }
        }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PositionsOnSymbol()
  {
   int total = 0;
   long myMagic = ActiveMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(!PositionSelectByIndex(i))
         continue;
      string psym="";
      PositionGetString(POSITION_SYMBOL, psym);
      if(psym != SelectedSymbol)
         continue;
      long mg=0;
      PositionGetInteger(POSITION_MAGIC, mg);
      if(mg == myMagic)
         total++;
     }
   return total;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLotByRisk(double stop_usd)
  {
   if(UseFixedLot)
      return ComputeFixedLot(SelectedSymbol, InpFixedLot);

   if(stop_usd<=0)
      return 0.0;

   double risk_amt = AccountInfoDouble(ACCOUNT_BALANCE) * P.RiskPerTradePct/100.0;
   double tv=0, ts=0;
   SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_VALUE, tv);
   SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_SIZE, ts);
   if(tv<=0 || ts<=0)
      return 0.0;

   double ticks = stop_usd / ts;
   if(ticks<=0)
      return 0.0;

   double loss_per_lot = ticks * tv;
   if(loss_per_lot<=0)
      return 0.0;

   double lots = risk_amt / loss_per_lot;
   double minlot, maxlot, lotstep;
   SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_MIN, minlot);
   SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_MAX, maxlot);
   SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_STEP, lotstep);

   lots = MathMax(minlot, MathMin(lots, maxlot));
   if(lotstep > 0.0)
      lots = MathFloor(lots/lotstep)*lotstep;

// Final validation to prevent "Invalid volume" errors
   if(lots < minlot)
      lots = minlot;
   if(maxlot > 0.0 && lots > maxlot)
      lots = maxlot;
   if(lotstep > 0.0 && MathMod(lots, lotstep) != 0.0)
      lots = MathFloor(lots/lotstep)*lotstep;

   return NormalizeDouble(lots, (lotstep>0.0 ? (int)MathMax(0.0, MathRound(MathLog10(1.0/lotstep))) : 2));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(!PositionSelect(SelectedSymbol))
      return;

   long posMagic = 0;
   PositionGetInteger(POSITION_MAGIC, posMagic);
   if(posMagic != ActiveMagic())
      return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   long   type  = PositionGetInteger(POSITION_TYPE);
   datetime opent= (datetime)PositionGetInteger(POSITION_TIME);

   double bid = SymbolInfoDouble(SelectedSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(SelectedSymbol, SYMBOL_ASK);
   double curr = (type==POSITION_TYPE_SELL ? bid : ask);

   double risk_per_lot = MathAbs(entry - sl);
   double reachedR = 0.0;
   if(risk_per_lot>0)
      reachedR = (type==POSITION_TYPE_SELL ? (entry-curr)/risk_per_lot : (curr-entry)/risk_per_lot);

// BE move
   if(P.BE_Activate_R>0 && reachedR >= P.BE_Activate_R)
     {
      double newSL = entry;
      if(type==POSITION_TYPE_SELL && sl<newSL)
         trade.PositionModify(SelectedSymbol, newSL, tp);
      if(type==POSITION_TYPE_BUY  && sl>newSL)
         trade.PositionModify(SelectedSymbol, newSL, tp);
     }

// Partial at TP1
   if(P.TP1_R>0 && P.PartialClosePct>0 && reachedR >= P.TP1_R)
     {
      double closeVol = vol * (P.PartialClosePct/100.0);
      double minlot, lotstep;
      SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_MIN, minlot);
      SymbolInfoDouble(SelectedSymbol, SYMBOL_VOLUME_STEP, lotstep);
      if(closeVol >= minlot)
        {
         closeVol = MathFloor(closeVol/lotstep)*lotstep;
         if(closeVol >= minlot)
            trade.PositionClosePartial(SelectedSymbol, closeVol);
        }
     }

// Time-stop
   if(P.TimeStopMinutes>0 && P.MinProgressR>0)
     {
      datetime nowt = TimeCurrent();
      if((nowt - opent) >= P.TimeStopMinutes*60)
        {
         if(reachedR < P.MinProgressR)
            trade.PositionClose(SelectedSymbol);
        }
     }

// Sprint-1 trailing & pyramiding
   ManageTrailing(entry, sl, type, curr, risk_per_lot, reachedR);
   ConsiderPyramidAdds(type, entry, curr, sl);
  }

//=== ------------------------ SIGNAL/ENTRY --------------------------- ===
void DetectBOSAndArm()
  {
// Quét sweep cách đây 2..(N_bos+1) bar, rồi kiểm tra BOS xuất hiện sau đó (về phía hiện tại)
   int maxS = MathMin(1 + P.N_bos, ArraySize(rates) - 2); // sweep candidate cách tối đa N_bos bar
   for(int s = 2; s <= maxS; ++s) // s = shift của bar sweep trong quá khứ gần
     {
      // SHORT: sweep lên rồi BOS xuống
      if(P.EnableShort && IsSweepHighBar(s) && EffortResultOK(s))
        {
         double level;
         int bosbar;
         if(HasBOSDownFrom(s, P.N_bos, level, bosbar))
           {
            // Lọc tại BAR BOS (không dùng spread/killzone ở thời điểm hiện tại để quyết định)
            if(!FiltersPass(bosbar))
               continue;

            state = ST_BOS_CONF;
            bosIsShort = true;
            bosLevel   = level;
            bosBarTime = rates[bosbar].time;
            sweepHigh  = rates[s].high;
            sweepLow   = rates[s].low;
            if(Debug)
               Print("BOS-Short armed | sweep@",TimeToString(rates[s].time),
                     " BOS@",TimeToString(rates[bosbar].time));
            return;
           }
        }
      // LONG: sweep xuống rồi BOS lên
      if(P.EnableLong && IsSweepLowBar(s) && EffortResultOK(s))
        {
         double level;
         int bosbar;
         if(HasBOSUpFrom(s, P.N_bos, level, bosbar))
           {
            if(!FiltersPass(bosbar))
               continue;

            state = ST_BOS_CONF;
            bosIsShort = false;
            bosLevel   = level;
            bosBarTime = rates[bosbar].time;
            sweepHigh  = rates[s].high;
            sweepLow   = rates[s].low;
            if(Debug)
               Print("BOS-Long armed | sweep@",TimeToString(rates[s].time),
                     " BOS@",TimeToString(rates[bosbar].time));
            return;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ShiftOfTime(datetime t)
  {
   int n = ArraySize(rates);
   for(int i=1;i<n;i++)
      if(rates[i].time==t)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlacePendingAfterBOS(bool isShort)
  {
   datetime exp = TimeCurrent() + P.PendingExpirySec;
   if(isShort)
     {
      double price = bosLevel - P.RetestOffsetUSD;
      double sl    = sweepHigh + P.SL_BufferUSD;
      double lots  = CalcLotByRisk(MathAbs(sl - price));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
        {
         bool ok = false;
         if(CanAfford(SelectedSymbol, true, lots, MarginBufferPct) && AllowedToOpenNow())
           {
            ok = trade.SellStop(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
            g_lastOpenTime=TimeCurrent();
            g_lastAddPriceSell=price;
            g_addCount=0;
           }
         if(Debug)
            PrintFormat("Place SellStop %s @%.2f", ok?"OK":"FAIL", price);
         return ok;
        }
     }
   else
     {
      double price = bosLevel + P.RetestOffsetUSD;
      double sl    = sweepLow - P.SL_BufferUSD;
      double lots  = CalcLotByRisk(MathAbs(price - sl));
      if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
        {
         bool ok = false;
         if(CanAfford(SelectedSymbol, false, lots, MarginBufferPct) && AllowedToOpenNow())
           {
            ok = trade.BuyStop(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
            g_lastOpenTime=TimeCurrent();
            g_lastAddPriceBuy=price;
            g_addCount=0;
           }
         if(Debug)
            PrintFormat("Place BuyStop %s @%.2f", ok?"OK":"FAIL", price);
         return ok;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TryEnterAfterRetest()
  {
   if(state!=ST_BOS_CONF)
      return;
   int bosShift = ShiftOfTime(bosBarTime);
   if(bosShift<0)
      return;
   int maxCheck = MathMin(P.M_retest, bosShift-1);
   for(int i=1; i<=maxCheck; ++i)
     {
      if(bosIsShort)
        {
         if(rates[i].high >= bosLevel && rates[i].close <= bosLevel)
           {
            if(P.UsePendingRetest)
              {
               PlacePendingAfterBOS(true);
              }
            else
              {
               double sl = sweepHigh + P.SL_BufferUSD;
               double entry = SymbolInfoDouble(SelectedSymbol, SYMBOL_BID);
               double lots = CalcLotByRisk(MathAbs(sl - entry));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
                 {
                  if(CanAfford(SelectedSymbol, true, lots, MarginBufferPct) && AllowedToOpenNow())
                    {
                     trade.Sell(lots, SelectedSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceSell=SymbolInfoDouble(SelectedSymbol,SYMBOL_BID);
                     g_addCount=0;
                     if(Debug)
                        Print("Market SELL placed");
                    }
                  else
                    {
                     if(Debug)
                        Print("SELL blocked by margin or cooldown");
                    }
                 }
              }
            state = ST_IDLE;
            return;
           }
        }
      else
        {
         if(rates[i].low <= bosLevel && rates[i].close >= bosLevel)
           {
            if(P.UsePendingRetest)
              {
               PlacePendingAfterBOS(false);
              }
            else
              {
               double sl = sweepLow - P.SL_BufferUSD;
               double entry = SymbolInfoDouble(SelectedSymbol, SYMBOL_ASK);
               double lots = CalcLotByRisk(MathAbs(entry - sl));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
                 {
                  if(CanAfford(SelectedSymbol, false, lots, MarginBufferPct) && AllowedToOpenNow())
                    {
                     trade.Buy(lots, SelectedSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceBuy=SymbolInfoDouble(SelectedSymbol,SYMBOL_ASK);
                     g_addCount=0;
                     if(Debug)
                        Print("Market BUY placed");
                    }
                  else
                    {
                     if(Debug)
                        Print("BUY blocked by margin or cooldown");
                    }
                 }
              }
            state = ST_IDLE;
            return;
           }
        }
     }
   if(Debug)
      Print("Retest window expired");
   state = ST_IDLE;
  }




//=== ------------------------ INIT/TICK ------------------------------- ===
int OnInit()
  {
   trade.SetAsyncMode(false);

   bool presetLoaded = false;
   UCRow r;

   if(UsePreset)
     {
      if(LoadUsecaseFromResource(PresetID, r))
        {
         UseInputsAsParams();
         ApplyCSVRowToParams(r);
         ApplyAutoSymbolProfile();
         presetLoaded = true;
        }
      else
        {
         Print("ERROR: Failed to load usecase from CSV for PresetID=", PresetID);
        }
     }

   if(!presetLoaded)
     {
      if(InpSymbolSelector > 0)
        {
         switch(InpSymbolSelector)
           {
            case 1: SelectedSymbol = "XAUUSD"; break;
            case 2: SelectedSymbol = "EURUSD"; break;
            case 3: SelectedSymbol = "USDJPY"; break;
            case 4: SelectedSymbol = "BTCUSD"; break;
            case 5: SelectedSymbol = "ETHUSD"; break;
            default: SelectedSymbol = InpSymbol; break;
           }
         Print("Symbol Selector: Using ", SelectedSymbol, " (selector=", InpSymbolSelector, ")");
        }
      else
        {
         SelectedSymbol = InpSymbol;
        }

      UseInputsAsParams();
      ConfigureSymbolUniverse(InpSymbolsCSV != "" ? InpSymbolsCSV : SelectedSymbol);
      ApplyAutoSymbolProfile();
     }

   if(ArraySize(gPresetSymbols) == 0)
      ConfigureSymbolUniverse(SelectedSymbol);

   SelectConfiguredSymbols();
   InitSymbolStates();
   if(ArraySize(gSymStates) > 0)
      LoadStateFromIndex(0);

   if(UseMultiSymbol)
     {
      if(UseMsTimer && InpTimerMs > 0)
        {
         EventSetMillisecondTimer(InpTimerMs);
         gTimerActive = true;
        }
      else
        {
         int sec = (InpTimerSeconds > 0 ? InpTimerSeconds : 1);
         EventSetTimer(sec);
         gTimerActive = true;
        }
     }
   else
     {
      gTimerActive = false;
      CurrSymIndex = (ArraySize(gSymStates)>0 ? 0 : -1);
      if(CurrSymIndex >= 0)
        {
         CurrSymbol = gSymStates[CurrSymIndex].sym;
         SelectedSymbol = CurrSymbol;
        }
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(UseMultiSymbol)
      return;
   ProcessActiveSymbol();
  }

void OnTimer()
  {
   if(!UseMultiSymbol)
     {
      ProcessActiveSymbol();
      return;
     }

   int count = ArraySize(gSymStates);
   for(int i=0; i<count; ++i)
     {
      LoadStateFromIndex(i);
      ProcessActiveSymbol();
      SaveStateToIndex(i);
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
   Print("OnTesterPass() called for PresetID ", PresetID);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(gTimerActive)
     {
      EventKillTimer();
      gTimerActive = false;
     }

   for(int i=0; i<ArraySize(gSymStates); ++i)
     {
      if(gSymStates[i].atr_handle != INVALID_HANDLE)
        {
         IndicatorRelease(gSymStates[i].atr_handle);
         gSymStates[i].atr_handle = INVALID_HANDLE;
        }
     }

   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   atr_handle = INVALID_HANDLE;

   if(reason == REASON_INITFAILED)
      return;

   TradeStats stats;
   CollectTradeStats(stats);
   
   // Lấy các metrics quan trọng từ TesterStatistics
   double maxDrawdownPercent = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
   double maxDrawdownMoney = TesterStatistics(STAT_BALANCE_DD);
   double sharpeRatio = TesterStatistics(STAT_SHARPE_RATIO);
   double recoveryFactor = TesterStatistics(STAT_RECOVERY_FACTOR);
   double expectedPayoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double maxConsecutiveLosses = TesterStatistics(STAT_CONLOSSMAX);
   int maxConsecutiveLossesCount = (int)TesterStatistics(STAT_CONLOSSMAX_TRADES);

   string header = CsvHeader();
   string row = BuildDataRow(stats.netProfit, stats.profitFactor, stats.totalTrades, stats.winTrades, stats.lossTrades,
                             stats.winRate, stats.avgWin, stats.avgLoss, stats.largestWin, stats.largestLoss, 
                             maxDrawdownPercent, maxDrawdownMoney, sharpeRatio, recoveryFactor, expectedPayoff, 
                             maxConsecutiveLosses, maxConsecutiveLossesCount);

   AppendCsvRow(InpLogFileName, InpUseCommonFile, header, row);

// === CSV FORMAT FOR COMPARISON ===
   string csvLine = StringFormat("%d,%s,%d,%d,%d,%d,%.2f,%.1f,%s,%s,%s,%.2f,%d,%.1f,%.2f,%.1f,%.1f,%.1f,%d,%d,%.1f,%.2f,%d,%s,%.2f,%d,%s,%d,%d,%.1f,%.1f,%.1f,%s,%d,%.2f,%.1f,%d",
                                 PresetID,
                                 SymbolsLogLabel(),
                                 P.K_swing,
                                 P.N_bos,
                                 P.LookbackInternal,
                                 P.M_retest,
                                 P.EqTol,
                                 P.BOSBufferPoints,
                                 P.UseKillzones ? "true" : "false",
                                 P.UseRoundNumber ? "true" : "false",
                                 P.UseVSA ? "true" : "false",
                                 P.RNDelta,
                                 P.L_percentile,
                                 P.RiskPerTradePct,
                                 P.SL_BufferUSD,
                                 P.TP1_R,
                                 P.TP2_R,
                                 P.BE_Activate_R,
                                 (int)P.PartialClosePct,
                                 P.TimeStopMinutes,
                                 P.MinProgressR,
                                 P.MaxSpreadUSD,
                                 P.MaxOpenPositions,
                                 P.UsePendingRetest ? "true" : "false",
                                 P.RetestOffsetUSD,
                                 P.PendingExpirySec,
                                 P.UseTrailing ? "true" : "false",
                                 P.TrailMode,
                                 P.TrailATRPeriod,
                                 P.TrailATRMult,
                                 P.TrailStepUSD,
                                 P.TrailStartRR,
                                 P.UsePyramid ? "true" : "false",
                                 P.MaxAdds,
                                 P.AddSpacingUSD,
                                 P.AddSizeFactor,
                                 P.CooldownSec);
   Print("CSV_LINE: ", csvLine);

// Enhanced summary log with key metrics
   if(Debug)
     {
      Print("UC", PresetID, ": Net=", DoubleToString(stats.netProfit, 2),
            ", PF=", DoubleToString(stats.profitFactor, 2),
            ", DD%=", DoubleToString(maxDrawdownPercent, 1),
            ", Sharpe=", DoubleToString(sharpeRatio, 2),
            ", Recovery=", DoubleToString(recoveryFactor, 2),
            ", Trades=", stats.totalTrades,
            ", MaxConsLoss=", maxConsecutiveLossesCount,
            ", Blocks: RN=", g_block_rn, ", KZ=", g_block_kz, ", Spr=", g_block_spread);
     }
  }
//+------------------------------------------------------------------+
