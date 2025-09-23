//+------------------------------------------------------------------+
//|                           XAU_SweepBOS_EA_v1.2_Refactored       |
//|                       Sweep -> BOS Multi-Symbol EA               |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS EA v1.2 Refactored"
#property version   "1.2"
#property strict

#include <Trade/Trade.mqh>

#resource "\\Files\\t1.csv" as string usecases_list;

//=== INPUTS ===
// Core Settings
input string InpSymbol           = "XAUUSD";
input int    InpSymbolSelector   = 0;        // 0=Custom, 1=XAUUSD, 2=EURUSD, 3=USDJPY, 4=BTCUSD, 5=ETHUSD
string SelectedSymbol = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;
input bool   AutoSymbolProfile   = true;     // Auto scale parameters by symbol

// Preset System
input bool   UsePreset           = true;
input int    PresetID            = 1;

// Logging
input string InpLogFileName   = "OptimizationResults.csv";
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
input double RNDelta             = 0.30;
input double RN_GridPips_FX      = 25.0;
input double RN_GridUSD_CRYPTO   = 100.0;





// === HTF FILTER INPUTS (IMPROVEMENT) ===
input bool   InpUseHTFFilter     = true;     // Bật/Tắt bộ lọc xu hướng HTF
input int    InpHTF_EMA_Period   = 50;       // Chu kỳ EMA trên khung HTF
input ENUM_MA_METHOD InpHTF_EMA_Method = MODE_EMA; // Phương pháp tính EMA

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

// ATR Scaling (always enabled)
input int    ATRScalingPeriod     = 14;
input double SL_ATR_Mult          = 0.60;
input double Retest_ATR_Mult      = 0.25;
input double AddSpacing_ATR_Mult  = 0.80;
input double TrailStep_ATR_Mult   = 0.50;
input double MaxSpread_ATR_Mult   = 0.15;
input double RNDelta_ATR_Mult     = 0.40;

// === NEWS FILTER INPUTS (IMPROVEMENT) ===
input bool   InpUseNewsFilter        = true;         // Bật/Tắt bộ lọc tin tức
input string InpNewsFilter_Symbols   = "USD";        // Lọc tin theo tiền tệ (cách nhau bởi dấu phẩy, vd: "USD,EUR")
input bool   InpNewsFilter_High      = true;         // Lọc tin tức tác động Mạnh
input bool   InpNewsFilter_Medium    = false;        // Lọc tin tức tác động Trung Bình
input int    InpNewsFilter_MinBefore = 30;           // Ngừng giao dịch TRƯỚC khi tin ra (phút)
input int    InpNewsFilter_MinAfter  = 30;           // Ngừng giao dịch SAU khi tin ra (phút)


// Entry Style
input bool   UsePendingRetest    = false;
input double RetestOffsetUSD     = 0.07;
input int    PendingExpirySec    = 60;

// FVG POI
input bool   InpUseFVGEntry          = true;   // Bật/Tắt vào lệnh theo FVG
input double InpFVGEntryOffsetPips   = 0.0;    // Đặt lệnh lệch vào trong FVG (tính bằng Pips)

// OB POI
enum ENUM_POI_TYPE // Loại vùng giá trị muốn sử dụng
  {
   POI_FVG,          // Sử dụng Fair Value Gap
   POI_ORDER_BLOCK   // Sử dụng Order Block
  };
input ENUM_POI_TYPE Inp_POIType          = POI_ORDER_BLOCK; // Chọn loại POI
input bool          InpOB_MustHaveImbalance = true;        // Bắt buộc OB phải có FVG đi kèm
input double        InpEntryOffsetPips   = 0.0;            // Đặt lệnh lệch vào trong POI (tính bằng Pips)
input int           InpPendingExpiryMinutes = 120;         // Thời gian hết hạn cho lệnh chờ (phút)
input bool   Debug               = true;

// Advanced Features
input int    CooldownSec         = 0;

//=== GLOBAL OVERRIDES FROM CSV ===
// These will override input values when loaded from CSV
bool g_csv_UseFVGEntry = false;
double g_csv_FVGEntryOffsetPips = 0.0;
int g_csv_PendingExpiryMinutes = 120;
bool g_csv_UseHTFFilter = false;
int g_csv_HTF_EMA_Period = 50;
int g_csv_HTF_EMA_Method = MODE_EMA;
bool g_csv_UseNewsFilter = false;
string g_csv_NewsFilter_Symbols = "USD";
bool g_csv_NewsFilter_High = true;
bool g_csv_NewsFilter_Medium = false;
int g_csv_NewsFilter_MinBefore = 30;
int g_csv_NewsFilter_MinAfter = 30;
int g_csv_POIType = POI_ORDER_BLOCK;
bool g_csv_OB_MustHaveImbalance = true;
double g_csv_EntryOffsetPips = 0.0;
bool g_csv_loaded = false; // Flag to indicate if CSV values were loaded

//=== GLOBAL STATE ===
CTrade         trade;
MqlRates       rates[];
datetime       last_bar_time = 0;

// === HTF FILTER  ===
ENUM_TIMEFRAMES g_htf_timeframe = PERIOD_CURRENT; // Biến lưu timeframe HTF được chọn
int             g_htf_ema_handle = INVALID_HANDLE;  // Biến lưu handle của chỉ báo iMA

// === NEWS FILTER GLOBALS (IMPROVEMENT) ===
struct NewsEvent
  {
   datetime          time;
   string            currency;
   string            impact;
  };
NewsEvent g_news_events[];
datetime  g_last_news_update = 0;

struct POI // Point of Interest
  {
   double            top;    // Mức giá trên của vùng POI
   double            bottom; // Mức giá dưới của vùng POI
   bool              isValid;
  };

enum StateEnum { ST_IDLE=0, ST_BOS_CONF };
StateEnum      state = ST_IDLE;

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
int      profile_atr_handle = INVALID_HANDLE;
int      profile_atr_period = 0;
string   profile_atr_symbol = "";
ENUM_TIMEFRAMES profile_atr_tf = PERIOD_CURRENT;

struct VolatilityProfile
  {
   double            pipSize;
   double            pointSize;
   double            pipPoints;
   double            tickValue;
   double            tickSize;
   double            atrValue;
   double            atrPips;
   int               atrPeriod;
  };
VolatilityProfile g_volProfile = {0.0,0.0,0.0,0.0,0.0,0.0,0.0,0};

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
      if(StringFind(firstLine, "PresetID") != 0)
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
   return "PresetID,Symbol,NetProfit,ProfitFactor,TotalTrades,WinTrades,LossTrades,WinRate,AvgWin,AvgLoss,LargestWin,LargestLoss,MaxDrawdownPercent,MaxDrawdownMoney,SharpeRatio,RecoveryFactor,ExpectedPayoff,MaxConsecutiveLosses,MaxConsecutiveLossesCount,FilterBlocks_RN,FilterBlocks_KZ,FilterBlocks_Spr,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,UseKillzones,UseRoundNumber,RNDelta,RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec,CooldownSec,ATRScalingPeriod,SL_ATR_Mult,Retest_ATR_Mult,MaxSpread_ATR_Mult,RNDelta_ATR_Mult,UseFVGEntry,FVGEntryOffsetPips,PendingExpiryMinutes,UseHTFFilter,HTF_EMA_Period,HTF_EMA_Method,UseNewsFilter,NewsFilter_Symbols,NewsFilter_High,NewsFilter_Medium,NewsFilter_MinBefore,NewsFilter_MinAfter,POIType,OB_MustHaveImbalance,EntryOffsetPips";
  }

// Build dòng dữ liệu từ kết quả backtest
string BuildDataRow(double netProfit, double profitFactor, int totalTrades, int winTrades, int lossTrades,
                    double winRate, double avgWin, double avgLoss, double largestWin, double largestLoss,
                    double maxDrawdownPercent, double maxDrawdownMoney, double sharpeRatio, double recoveryFactor,
                    double expectedPayoff, double maxConsecutiveLosses, int maxConsecutiveLossesCount)
  {
   string row =
      IntegerToString(PresetID) + "," +
      SelectedSymbol + "," +
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
      DoubleToString(P.RNDelta, 2) + "," +
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
      IntegerToString(P.CooldownSec) + "," +
      IntegerToString(P.ATRScalingPeriod) + "," +
      DoubleToString(P.SL_ATR_Mult, 2) + "," +
      DoubleToString(P.Retest_ATR_Mult, 2) + "," +
      DoubleToString(P.MaxSpread_ATR_Mult, 2) + "," +
      DoubleToString(P.RNDelta_ATR_Mult, 2) + "," +
      (GetEffectiveUseFVGEntry() ? "true" : "false") + "," +
      DoubleToString(GetEffectiveFVGEntryOffsetPips(), 2) + "," +
      IntegerToString(GetEffectivePendingExpiryMinutes()) + "," +
      (GetEffectiveUseHTFFilter() ? "true" : "false") + "," +
      IntegerToString(GetEffectiveHTF_EMA_Period()) + "," +
      IntegerToString(GetEffectiveHTF_EMA_Method()) + "," +
      (GetEffectiveUseNewsFilter() ? "true" : "false") + "," +
      GetEffectiveNewsFilter_Symbols() + "," +
      (GetEffectiveNewsFilter_High() ? "true" : "false") + "," +
      (GetEffectiveNewsFilter_Medium() ? "true" : "false") + "," +
      IntegerToString(GetEffectiveNewsFilter_MinBefore()) + "," +
      IntegerToString(GetEffectiveNewsFilter_MinAfter()) + "," +
      IntegerToString(GetEffectivePOIType()) + "," +
      (GetEffectiveOB_MustHaveImbalance() ? "true" : "false") + "," +
      DoubleToString(GetEffectiveEntryOffsetPips(), 2);
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

         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != SelectedSymbol)
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
   bool              UseKillzones, UseRoundNumber;
   double            RNDelta;
   int               KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e;
   // risk
   double            RiskPerTradePct, SL_BufferUSD, TP1_R, TP2_R, BE_Activate_R, PartialClosePct;
   int               TimeStopMinutes;
   double            MinProgressR;
   // exec
   double            MaxSpreadUSD;
   int               MaxOpenPositions;
   // atr scaling (always enabled)
   int               ATRScalingPeriod;
   double            SL_ATR_Mult;
   double            Retest_ATR_Mult;
   double            MaxSpread_ATR_Mult;
   double            RNDelta_ATR_Mult;
   // entry style
   bool              UsePendingRetest;
   double            RetestOffsetUSD;
   int               PendingExpirySec;
   // advanced
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
   P.ATRScalingPeriod=ATRScalingPeriod;
   P.SL_ATR_Mult=SL_ATR_Mult;
   P.Retest_ATR_Mult=Retest_ATR_Mult;
   P.MaxSpread_ATR_Mult=MaxSpread_ATR_Mult;
   P.RNDelta_ATR_Mult=RNDelta_ATR_Mult;
   P.UsePendingRetest=UsePendingRetest;
   P.RetestOffsetUSD=RetestOffsetUSD;
   P.PendingExpirySec=PendingExpirySec;
   P.CooldownSec=CooldownSec;
  }

//===================== USECASE GENERATOR (NO CSV) =====================//

struct UCRow
  {
   string            SelectedSymbol;
   int               K_swing, N_bos, LookbackInternal, M_retest;
   double            EqTol, BOSBufferPoints;
   int               UseKillzones, UseRoundNumber;
   double            RNDelta;
   double            RiskPerTradePct;
   double            SL_BufferUSD;
   double            TP1_R, TP2_R, BE_Activate_R;
   int               PartialClosePct;
   int               TimeStopMinutes;
   double            MinProgressR;
   double            MaxSpreadUSD;
   int               MaxOpenPositions;
   int               ATRScalingPeriod;
   double            SL_ATR_Mult;
   double            Retest_ATR_Mult;
   double            MaxSpread_ATR_Mult;
   double            RNDelta_ATR_Mult;
   int               UsePendingRetest;
   double            RetestOffsetUSD;
   int               PendingExpirySec;
   int               CooldownSec;
   // New FVG/HTF/News/POI parameters
   int               UseFVGEntry;
   double            FVGEntryOffsetPips;
   int               PendingExpiryMinutes;
   int               UseHTFFilter;
   int               HTF_EMA_Period;
   int               HTF_EMA_Method;
   int               UseNewsFilter;
   string            NewsFilter_Symbols;
   int               NewsFilter_High;
   int               NewsFilter_Medium;
   int               NewsFilter_MinBefore;
   int               NewsFilter_MinAfter;
   int               POIType;
   int               OB_MustHaveImbalance;
   double            EntryOffsetPips;
  };


// Helper functions removed - using CSV data directly

// Apply CSV row to parameters
void ApplyCSVRowToParams(const UCRow &r)
  {
   SelectedSymbol = r.SelectedSymbol;
   SymbolSelect(SelectedSymbol, true);

   P.K_swing          = r.K_swing;
   P.N_bos            = r.N_bos;
   P.LookbackInternal = r.LookbackInternal;
   P.M_retest         = r.M_retest;
   P.EqTol            = r.EqTol;
   P.BOSBufferPoints  = r.BOSBufferPoints;
   P.UseKillzones     = r.UseKillzones;
   P.UseRoundNumber   = r.UseRoundNumber;
   P.RNDelta          = r.RNDelta;
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
   P.ATRScalingPeriod = r.ATRScalingPeriod;
   P.SL_ATR_Mult      = r.SL_ATR_Mult;
   P.Retest_ATR_Mult  = r.Retest_ATR_Mult;
   P.MaxSpread_ATR_Mult  = r.MaxSpread_ATR_Mult;
   P.RNDelta_ATR_Mult    = r.RNDelta_ATR_Mult;
   P.UsePendingRetest = r.UsePendingRetest;
   P.RetestOffsetUSD  = r.RetestOffsetUSD;
   P.PendingExpirySec = r.PendingExpirySec;
   P.CooldownSec      = r.CooldownSec;
   
   // Apply new FVG/HTF/News/POI parameters to global variables
   g_csv_UseFVGEntry = (bool)r.UseFVGEntry;
   g_csv_FVGEntryOffsetPips = r.FVGEntryOffsetPips;
   g_csv_PendingExpiryMinutes = r.PendingExpiryMinutes;
   g_csv_UseHTFFilter = (bool)r.UseHTFFilter;
   g_csv_HTF_EMA_Period = r.HTF_EMA_Period;
   g_csv_HTF_EMA_Method = r.HTF_EMA_Method;
   g_csv_UseNewsFilter = (bool)r.UseNewsFilter;
   g_csv_NewsFilter_Symbols = r.NewsFilter_Symbols;
   g_csv_NewsFilter_High = (bool)r.NewsFilter_High;
   g_csv_NewsFilter_Medium = (bool)r.NewsFilter_Medium;
   g_csv_NewsFilter_MinBefore = r.NewsFilter_MinBefore;
   g_csv_NewsFilter_MinAfter = r.NewsFilter_MinAfter;
   g_csv_POIType = r.POIType;
   g_csv_OB_MustHaveImbalance = (bool)r.OB_MustHaveImbalance;
   g_csv_EntryOffsetPips = r.EntryOffsetPips;
   g_csv_loaded = true;
  }

// Helper functions to get effective values (CSV overrides inputs if loaded)
bool GetEffectiveUseFVGEntry() { return g_csv_loaded ? g_csv_UseFVGEntry : InpUseFVGEntry; }
double GetEffectiveFVGEntryOffsetPips() { return g_csv_loaded ? g_csv_FVGEntryOffsetPips : InpFVGEntryOffsetPips; }
int GetEffectivePendingExpiryMinutes() { return g_csv_loaded ? g_csv_PendingExpiryMinutes : InpPendingExpiryMinutes; }
bool GetEffectiveUseHTFFilter() { return g_csv_loaded ? g_csv_UseHTFFilter : InpUseHTFFilter; }
int GetEffectiveHTF_EMA_Period() { return g_csv_loaded ? g_csv_HTF_EMA_Period : InpHTF_EMA_Period; }
int GetEffectiveHTF_EMA_Method() { return g_csv_loaded ? g_csv_HTF_EMA_Method : InpHTF_EMA_Method; }
bool GetEffectiveUseNewsFilter() { return g_csv_loaded ? g_csv_UseNewsFilter : InpUseNewsFilter; }
string GetEffectiveNewsFilter_Symbols() { return g_csv_loaded ? g_csv_NewsFilter_Symbols : InpNewsFilter_Symbols; }
bool GetEffectiveNewsFilter_High() { return g_csv_loaded ? g_csv_NewsFilter_High : InpNewsFilter_High; }
bool GetEffectiveNewsFilter_Medium() { return g_csv_loaded ? g_csv_NewsFilter_Medium : InpNewsFilter_Medium; }
int GetEffectiveNewsFilter_MinBefore() { return g_csv_loaded ? g_csv_NewsFilter_MinBefore : InpNewsFilter_MinBefore; }
int GetEffectiveNewsFilter_MinAfter() { return g_csv_loaded ? g_csv_NewsFilter_MinAfter : InpNewsFilter_MinAfter; }
int GetEffectivePOIType() { return g_csv_loaded ? g_csv_POIType : Inp_POIType; }
bool GetEffectiveOB_MustHaveImbalance() { return g_csv_loaded ? g_csv_OB_MustHaveImbalance : InpOB_MustHaveImbalance; }
double GetEffectiveEntryOffsetPips() { return g_csv_loaded ? g_csv_EntryOffsetPips : InpEntryOffsetPips; }

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SampleATR(const string symbol, ENUM_TIMEFRAMES tf, const int period)
  {
   int usePeriod = (period<=1 ? 14 : period);
   if(profile_atr_handle==INVALID_HANDLE || profile_atr_symbol!=symbol || profile_atr_tf!=tf || profile_atr_period!=usePeriod)
     {
      if(profile_atr_handle!=INVALID_HANDLE)
         IndicatorRelease(profile_atr_handle);
      profile_atr_handle = iATR(symbol, tf, usePeriod);
      profile_atr_symbol = symbol;
      profile_atr_tf = tf;
      profile_atr_period = usePeriod;
     }

   if(profile_atr_handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   int copied = CopyBuffer(profile_atr_handle, 0, 0, 1, buf);
   if(copied <= 0)
      return 0.0;
   return buf[0];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ParseCSVValue(const string csvValue, const string symbol)
  {
   string trimmed = Trim(csvValue);
   if(trimmed == "")
      return 0.0;

   string lowered = trimmed;
   StringToLower(lowered);

   if(StringFind(lowered, "*pip") >= 0 && StringFind(lowered, "*pippoints") < 0)
     {
      string numStr = trimmed;
      StringReplace(numStr, "*pip", "");
      return StringToDouble(Trim(numStr)) * SymbolPipSize(symbol);
     }

   if(StringFind(lowered, "*pippoints") >= 0)
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

   int atrIdx = StringFind(lowered, "*atr");
   if(atrIdx >= 0)
     {
      string multiplierPart = Trim(StringSubstr(trimmed, 0, atrIdx));
      string suffix = Trim(StringSubstr(trimmed, atrIdx + 4));

      double multiplier = (multiplierPart=="" ? 1.0 : StringToDouble(multiplierPart));
      int period = (suffix=="" ? 14 : (int)StringToInteger(suffix));

      double atrValue = SampleATR(symbol, InpTF, period);
      if(atrValue <= 0.0)
         atrValue = SampleATR(symbol, PERIOD_H1, period); // Fallback timeframe

      if(atrValue <= 0.0)
         return 0.0;

      return multiplier * atrValue;
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
      if(c < 38)  // Updated to expect 38+ columns for new parameters
        {
         PrintFormat("WARN: Preset line %d has %d columns, expected at least 38", i, c);
         continue;
        }


      // Case,Symbol,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,UseKillzones,UseRoundNumber,RNDelta,
      // RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,MaxSpreadUSD,
      // MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec,CooldownSec,ATRScalingPeriod,SL_ATR_Mult,
      // Retest_ATR_Mult,MaxSpread_ATR_Mult,RNDelta_ATR_Mult,UseFVGEntry,FVGEntryOffsetPips,PendingExpiryMinutes,
      // UseHTFFilter,HTF_EMA_Period,HTF_EMA_Method,UseNewsFilter,NewsFilter_Symbols,NewsFilter_High,NewsFilter_Medium,
      // NewsFilter_MinBefore,NewsFilter_MinAfter,POIType,OB_MustHaveImbalance,EntryOffsetPips
      int csvPresetID = (int)StringToInteger(fields[0]);
      if(csvPresetID == presetID)
        {
         row.ATRScalingPeriod     = ATRScalingPeriod;
         row.SL_ATR_Mult          = SL_ATR_Mult;
         row.Retest_ATR_Mult      = Retest_ATR_Mult;
         row.MaxSpread_ATR_Mult   = MaxSpread_ATR_Mult;
         row.RNDelta_ATR_Mult     = RNDelta_ATR_Mult;
         SymbolSelect(fields[1], true);
         // Map fields according to CSV header order
         row.SelectedSymbol       = fields[1];
         row.K_swing              = (int)StringToInteger(fields[2]);
         row.N_bos                = (int)StringToInteger(fields[3]);
         row.LookbackInternal     = (int)StringToInteger(fields[4]);
         row.M_retest             = (int)StringToInteger(fields[5]);
         row.EqTol                = ParseCSVValue(fields[6], fields[1]);
         row.BOSBufferPoints      = ParseCSVValue(fields[7], fields[1]);
         row.UseKillzones         = StringToBool(fields[8]);
         row.UseRoundNumber       = StringToBool(fields[9]);
         row.RNDelta              = ParseCSVValue(fields[10], fields[1]);
         row.RiskPerTradePct      = StringToDouble(fields[11]);
         row.SL_BufferUSD         = ParseCSVValue(fields[12], fields[1]);
         row.TP1_R                = StringToDouble(fields[13]);
         row.TP2_R                = StringToDouble(fields[14]);
         row.BE_Activate_R        = StringToDouble(fields[15]);
         row.PartialClosePct      = (int)StringToInteger(fields[16]);
         row.TimeStopMinutes      = (int)StringToInteger(fields[17]);
         row.MinProgressR         = StringToDouble(fields[18]);
         row.MaxSpreadUSD         = ParseCSVValue(fields[19], fields[1]);
         row.MaxOpenPositions     = (int)StringToInteger(fields[20]);
         row.UsePendingRetest     = StringToBool(fields[21]);
         row.RetestOffsetUSD      = ParseCSVValue(fields[22], fields[1]);
         row.PendingExpirySec     = (int)StringToInteger(fields[23]);

         // Debug pip parsing
         if(Debug)
           {
            Print("DEBUG CSV PARSING: Symbol=", fields[1],
                  ", EqTol=", fields[6], " -> ", row.EqTol,
                  ", BOSBuffer=", fields[7], " -> ", row.BOSBufferPoints,
                  ", RNDelta=", fields[10], " -> ", row.RNDelta,
                  ", SL_Buffer=", fields[12], " -> ", row.SL_BufferUSD,
                  ", RetestOffset=", fields[22], " -> ", row.RetestOffsetUSD);
           }
         row.CooldownSec          = (int)StringToInteger(fields[24]);

         // ATR scaling fields - now parsed from CSV
         if(c > 25) row.ATRScalingPeriod = (int)StringToInteger(fields[25]);
         if(c > 26) row.SL_ATR_Mult = StringToDouble(fields[26]);
         if(c > 27) row.Retest_ATR_Mult = StringToDouble(fields[27]);
         if(c > 28) row.MaxSpread_ATR_Mult = StringToDouble(fields[28]);
         if(c > 29) row.RNDelta_ATR_Mult = StringToDouble(fields[29]);
         
         // New FVG/HTF/News/POI parameters
         if(c > 30) row.UseFVGEntry = StringToBool(fields[30]);
         if(c > 31) row.FVGEntryOffsetPips = StringToDouble(fields[31]);
         if(c > 32) row.PendingExpiryMinutes = (int)StringToInteger(fields[32]);
         if(c > 33) row.UseHTFFilter = StringToBool(fields[33]);
         if(c > 34) row.HTF_EMA_Period = (int)StringToInteger(fields[34]);
         if(c > 35) row.HTF_EMA_Method = (int)StringToInteger(fields[35]);
         if(c > 36) row.UseNewsFilter = StringToBool(fields[36]);
         if(c > 37) row.NewsFilter_Symbols = fields[37];
         if(c > 38) row.NewsFilter_High = StringToBool(fields[38]);
         if(c > 39) row.NewsFilter_Medium = StringToBool(fields[39]);
         if(c > 40) row.NewsFilter_MinBefore = (int)StringToInteger(fields[40]);
         if(c > 41) row.NewsFilter_MinAfter = (int)StringToInteger(fields[41]);
         if(c > 42) row.POIType = (int)StringToInteger(fields[42]);
         if(c > 43) row.OB_MustHaveImbalance = StringToBool(fields[43]);
         if(c > 44) row.EntryOffsetPips = StringToDouble(fields[44]);

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PipsToPrice(double pips, const string sym="") { return pips * SymbolPipSize(sym); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PriceToPips(double pricediff, const string sym="")
  {
   double pip = SymbolPipSize(sym);
   return (pip<=0.0) ? 0.0 : pricediff / pip;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SymbolPoint() { return SymbolInfoDouble(SelectedSymbol, SYMBOL_POINT); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   if(StringFind(symbol_name,"EURUSD",0) >= 0)
     {
      hi = 0.00025;
      lo = 0.00010;
      return true;
     }
   if(StringFind(symbol_name,"GBPUSD",0) >= 0)
     {
      hi = 0.00035;
      lo = 0.00015;
      return true;
     }
   if(StringFind(symbol_name,"USDJPY",0) >= 0)
     {
      hi = 0.05;
      lo = 0.02;
      return true;
     }
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


//+------------------------------------------------------------------+
//| Utility: clamp price-distance fields using pip units             |
//+------------------------------------------------------------------+
void ClampPriceField(double &value, double pip, double minPips, double maxPips)
  {
   if(pip <= 0.0)
      return;

   double minValue = minPips * pip;
   double maxValue = maxPips * pip;

   if(value <= 0.0)
     {
      value = minValue;
      return;
     }

   double asPips = value / pip;
   if(asPips < minPips)
      value = minValue;
   else
      if(asPips > maxPips)
         value = maxValue;
  }

//+------------------------------------------------------------------+
//| Utility: clamp point-based fields using pip-points               |
//+------------------------------------------------------------------+
void ClampPointField(double &value, double pipPoints, double minPips, double maxPips)
  {
   if(pipPoints <= 0.0)
      return;

   double minPts = minPips * pipPoints;
   double maxPts = maxPips * pipPoints;

   if(value <= 0.0)
     {
      value = minPts;
      return;
     }

   if(value < minPts)
      value = minPts;
   else
      if(value > maxPts)
         value = maxPts;
  }

//+------------------------------------------------------------------+
//| Tải dữ liệu tin tức từ Web                                        |
//+------------------------------------------------------------------+
void LoadNewsData()
  {
// Reset mảng tin tức
   ArrayResize(g_news_events, 0);
   string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.csv";
   char data[], result[];
   string headers;
   int timeout = 5000; // 5 giây

// Gửi yêu cầu WebRequest
   ResetLastError();
   int res = WebRequest("GET", url, NULL, NULL, timeout, data, 0, result, headers);

   if(res == -1)
     {
      PrintFormat("WebRequest failed. Error code: %d", GetLastError());
      return;
     }
   if(res != 200)
     {
      PrintFormat("WebRequest returned code: %d", res);
      return;
     }

// Chuyển đổi kết quả sang chuỗi
   string csv_data = CharArrayToString(result);
   string lines[];
   StringSplit(csv_data, '\n', lines);

// Phân tích từng dòng CSV
   for(int i = 1; i < ArraySize(lines); i++) // Bắt đầu từ 1 để bỏ qua dòng tiêu đề
     {
      string fields[];
      StringSplit(lines[i], ',', fields);
      if(ArraySize(fields) < 5)
         continue;

      // fields[0]=Title, fields[1]=Currency, fields[2]=Date, fields[3]=Time, fields[4]=Impact
      string currency = fields[1];
      string impact = fields[4];
      string datetime_str = fields[2] + " " + fields[3];
      datetime event_time = StringToTime(datetime_str);

      // Kiểm tra xem có cần lọc tin này không
      bool is_high = (impact == "High" && GetEffectiveNewsFilter_High());
      bool is_medium = (impact == "Medium" && GetEffectiveNewsFilter_Medium());

      // Chỉ thêm vào danh sách nếu nó khớp với các cài đặt
      if(StringFind(GetEffectiveNewsFilter_Symbols(), currency) >= 0 && (is_high || is_medium))
        {
         int last_idx = ArraySize(g_news_events);
         ArrayResize(g_news_events, last_idx + 1);
         g_news_events[last_idx].time = event_time;
         g_news_events[last_idx].currency = currency;
         g_news_events[last_idx].impact = impact;
        }
     }
   PrintFormat("News filter: Loaded %d events.", ArraySize(g_news_events));
   g_last_news_update = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Kiểm tra xem thời gian hiện tại có gần sự kiện tin tức không       |
//+------------------------------------------------------------------+
bool IsNearNewsEvent()
  {
   if(!GetEffectiveUseNewsFilter() || MQLInfoInteger(MQL_TESTER)) // Tự động tắt bộ lọc khi backtest
      return false; // Trả về false: "Không có tin tức", cho phép giao dịch

   datetime now = TimeCurrent();
   long min_before_sec = GetEffectiveNewsFilter_MinBefore() * 60;
   long min_after_sec = GetEffectiveNewsFilter_MinAfter() * 60;

   for(int i = 0; i < ArraySize(g_news_events); i++)
     {
      long time_to_event = g_news_events[i].time - now;

      // Kiểm tra xem có nằm trong vùng cấm không
      if(time_to_event > 0 && time_to_event <= min_before_sec)
        {
         if(Debug)
            PrintFormat("BLOCK NEWS: Approaching %s event in %d minutes.", g_news_events[i].currency, (int)(time_to_event / 60));
         return true; // Có tin sắp ra -> Cấm giao dịch
        }
      if(time_to_event < 0 && MathAbs(time_to_event) <= min_after_sec)
        {
         if(Debug)
            PrintFormat("BLOCK NEWS: Just after %s event. Waiting.", g_news_events[i].currency);
         return true; // Tin vừa ra -> Cấm giao dịch
        }
     }

   return false; // Không có tin tức nào gần đây -> Cho phép giao dịch
  }

//+------------------------------------------------------------------+
//| Tự động xác định Khung Thời Gian Lớn (HTF)                       |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES entry_tf)
  {
   switch(entry_tf)
     {
      case PERIOD_M1:
         return PERIOD_M5;
      case PERIOD_M5:
         return PERIOD_M15;
      case PERIOD_M15:
         return PERIOD_H1;
      case PERIOD_H1:
         return PERIOD_H4;
      case PERIOD_H4:
         return PERIOD_D1;
      default:
         return entry_tf; // Nếu không xác định được, trả về chính nó để vô hiệu hóa filter
     }
  }

  //+------------------------------------------------------------------+
//| Tìm Order Block "xịn" gần nhất với một mức giá mục tiêu            |
//+------------------------------------------------------------------+
POI FindBestOrderBlock(int startBar, int endBar, bool findBullishOB, double targetLevel)
  {
   POI bestOB = {0, 0, false};
   double closestDist = 1e9;

   // Quét từ nến mới đến nến cũ trong khoảng giá đẩy
   for(int i = startBar; i <= endBar; i++)
     {
      // Nến hiện tại là một OB tiềm năng
      MqlRates ob_candle = rates[i];
      POI currentOB = {0, 0, false};

      // --- Kiểm tra OB tăng giá (Bullish OB) ---
      // Là một nến giảm (Close < Open)
      if(findBullishOB && ob_candle.close < ob_candle.open)
        {
         currentOB.top = ob_candle.high;
         currentOB.bottom = ob_candle.low;
         currentOB.isValid = true;
        }
      // --- Kiểm tra OB giảm giá (Bearish OB) ---
      // Là một nến tăng (Close > Open)
      else if(!findBullishOB && ob_candle.close > ob_candle.open)
        {
         currentOB.top = ob_candle.high;
         currentOB.bottom = ob_candle.low;
         currentOB.isValid = true;
        }

      // Nếu tìm thấy một OB tiềm năng, kiểm tra các điều kiện chất lượng
      if(currentOB.isValid)
        {
         // 1. KIỂM TRA MẤT CÂN BẰNG (FVG đi kèm)
         if(GetEffectiveOB_MustHaveImbalance())
           {
            bool hasImbalance = false;
            // FVG thường được tạo bởi OB (i), nến đẩy (i-1) và nến tiếp theo (i-2)
            if(i >= 2)
              {
               if(findBullishOB && rates[i].high < rates[i-2].low) hasImbalance = true;
               if(!findBullishOB && rates[i].low > rates[i-2].high) hasImbalance = true;
              }
            if(!hasImbalance) continue; // Nếu không có FVG đi kèm, bỏ qua OB này
           }

         // 2. KIỂM TRA CHƯA BỊ KHAI THÁC (MITIGATION)
         bool isMitigated = false;
         for(int j = i - 1; j >= 0; j--) // Quét các nến sau khi OB hình thành
           {
            // Nếu giá đã quay lại chạm vào OB
            if((findBullishOB && rates[j].low <= currentOB.top) ||
               (!findBullishOB && rates[j].high >= currentOB.bottom))
              {
               isMitigated = true;
               break;
              }
           }
         if(isMitigated) continue; // Bỏ qua OB đã bị mitigate

         // 3. CHỌN OB GẦN ĐIỂM PHÁ VỠ NHẤT
         double midPoint = (currentOB.top + currentOB.bottom) / 2.0;
         double dist = MathAbs(midPoint - targetLevel);

         if(dist < closestDist)
           {
            closestDist = dist;
            bestOB = currentOB;
           }
        }
     }
   return bestOB;
  }
  
  //+------------------------------------------------------------------+
//| Tìm FVG gần nhất với một mức giá mục tiêu trong một khoảng nến     |
//+------------------------------------------------------------------+
POI FindBestFVG(int startBar, int endBar, bool findBullishFVG, double targetLevel)
  {
  POI bestPOI = {0, 0, false}; // Sửa tên biến
   double closestDist = 1e9; // Một số rất lớn

   // Quét từ nến mới đến nến cũ (từ startBar về endBar)
   for(int i = startBar; i <= endBar - 2; i++)
     {
      // FVG được tạo bởi 3 nến: i, i+1, i+2 (với i là nến mới nhất trong bộ 3)
      MqlRates n1 = rates[i+2]; // Nến 1 (cũ nhất)
      MqlRates n2 = rates[i+1]; // Nến 2 (giữa)
      MqlRates n3 = rates[i];   // Nến 3 (mới nhất)

      POI currentFVG = {0, 0, false};

      // Tìm FVG tăng giá (Bullish FVG)
      if(findBullishFVG && n1.high < n3.low)
        {
         currentFVG.top = n3.low;
         currentFVG.bottom = n1.high;
         currentFVG.isValid = true;
        }
      // Tìm FVG giảm giá (Bearish FVG)
      else if(!findBullishFVG && n1.low > n3.high)
        {
         currentFVG.top = n1.low;
         currentFVG.bottom = n3.high;
         currentFVG.isValid = true;
        }

      // Nếu tìm thấy một FVG hợp lệ
      if(currentFVG.isValid)
        {
         // Kiểm tra xem FVG này đã bị giá chạm vào chưa (đã mitigate chưa)
         bool isMitigated = false;
         for(int j=i-1; j>=0; j--) // Quét các nến sau khi FVG hình thành
         {
            if((findBullishFVG && rates[j].low <= currentFVG.top) || 
               (!findBullishFVG && rates[j].high >= currentFVG.bottom))
            {
               isMitigated = true;
               break;
            }
         }
         
         if(isMitigated) continue; // Bỏ qua FVG đã bị mitigate

         // Chọn FVG gần với mức giá phá vỡ (targetLevel) nhất
         double midPoint = (currentFVG.top + currentFVG.bottom) / 2.0;
         double dist = MathAbs(midPoint - targetLevel);

         if(dist < closestDist)
           {
            closestDist = dist;
            bestPOI = currentFVG;
           }
        }
     }
   return bestPOI;
  }

//+------------------------------------------------------------------+
//| Kiểm tra xem tín hiệu có thuận xu hướng trên HTF không            |
//| Trả về true nếu được phép giao dịch, false nếu bị chặn            |
//+------------------------------------------------------------------+
bool CheckHTF_Filter(bool isShort)
  {
// Nếu filter không bật hoặc có lỗi, luôn cho qua
   if(!GetEffectiveUseHTFFilter() || g_htf_ema_handle == INVALID_HANDLE || g_htf_timeframe == InpTF)
      return true;

// Lấy 1 giá trị EMA gần nhất từ HTF
   double ema_buffer[];
   if(CopyBuffer(g_htf_ema_handle, 0, 0, 1, ema_buffer) <= 0)
     {
      Print("Could not copy HTF EMA buffer. Filter skipped.");
      return true; // Lỗi thì cho qua để không làm gián đoạn EA
     }
   double htf_ema_value = ema_buffer[0];

// Lấy giá hiện tại
   double current_price = SymbolInfoDouble(SelectedSymbol, isShort ? SYMBOL_BID : SYMBOL_ASK);

// Logic lọc
   if(isShort)
     {
      // Nếu là lệnh Bán, giá hiện tại phải nằm DƯỚI đường EMA của HTF
      return (current_price < htf_ema_value);
     }
   else
     {
      // Nếu là lệnh Mua, giá hiện tại phải nằm TRÊN đường EMA của HTF
      return (current_price > htf_ema_value);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RefreshVolatilityProfile()
  {
   g_volProfile.pipSize  = SymbolPipSize(SelectedSymbol);
   g_volProfile.pointSize= SymbolPoint();
   g_volProfile.pipPoints= (g_volProfile.pointSize>0.0 ? g_volProfile.pipSize/g_volProfile.pointSize : 0.0);
   SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_VALUE, g_volProfile.tickValue);
   SymbolInfoDouble(SelectedSymbol, SYMBOL_TRADE_TICK_SIZE,  g_volProfile.tickSize);
   int period = (P.ATRScalingPeriod>1 ? P.ATRScalingPeriod : 14);
   double atr = SampleATR(SelectedSymbol, InpTF, period);
   if(atr <= 0.0)
      atr = SampleATR(SelectedSymbol, PERIOD_H1, period);
   if(atr <= 0.0 && period != 14)
      atr = SampleATR(SelectedSymbol, InpTF, 14);

   g_volProfile.atrValue  = atr;
   g_volProfile.atrPips   = (g_volProfile.pipSize>0.0 && atr>0.0) ? atr / g_volProfile.pipSize : 0.0;
   g_volProfile.atrPeriod = period;

   return (g_volProfile.pipSize > 0.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApplyKillzoneDefaultsForSymbol()
  {
   if(!P.UseKillzones)
      return;

   const int defaultKZ1s = 13*60 + 55;
   const int defaultKZ1e = 14*60 + 20;
   const int defaultKZ2s = 16*60 + 25;
   const int defaultKZ2e = 16*60 + 40;
   const int defaultKZ3s = 19*60 + 25;
   const int defaultKZ3e = 19*60 + 45;
   const int defaultKZ4s = 20*60 + 55;
   const int defaultKZ4e = 21*60 + 15;

   bool usingXAUDefaults = (P.KZ1s==defaultKZ1s && P.KZ1e==defaultKZ1e &&
                            P.KZ2s==defaultKZ2s && P.KZ2e==defaultKZ2e &&
                            P.KZ3s==defaultKZ3s && P.KZ3e==defaultKZ3e &&
                            P.KZ4s==defaultKZ4s && P.KZ4e==defaultKZ4e);

   if(StringFind(SelectedSymbol, "EURUSD", 0) >= 0 && usingXAUDefaults)
     {
      P.KZ1s = 7*60;
      P.KZ1e = 10*60 + 30;
      P.KZ2s = 12*60;
      P.KZ2e = 16*60;
      P.KZ3s = 0;
      P.KZ3e = 0;
      P.KZ4s = 0;
      P.KZ4e = 0;
      return;
     }

   if(StringFind(SelectedSymbol, "GBPUSD", 0) >= 0 && usingXAUDefaults)
     {
      P.KZ1s = 8*60;
      P.KZ1e = 11*60 + 30;
      P.KZ2s = 13*60;
      P.KZ2e = 17*60;
      P.KZ3s = 0;
      P.KZ3e = 0;
      P.KZ4s = 0;
      P.KZ4e = 0;
      return;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NormalizeFXUnits()
  {
   bool isXAU    = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);
   if(isXAU || isCrypto)
      return;

   double pip = (g_volProfile.pipSize>0.0 ? g_volProfile.pipSize : SymbolPipSize(SelectedSymbol));
   double pipPoints = (g_volProfile.pipPoints>0.0 ? g_volProfile.pipPoints : 0.0);
   double atr = g_volProfile.atrValue;

   if(pip <= 0.0)
      return;

// ATR scaling is always enabled
   if(atr > 0.0)
     {
      if(P.SL_ATR_Mult > 0.0)
         P.SL_BufferUSD = atr * P.SL_ATR_Mult;
      if(P.Retest_ATR_Mult > 0.0)
         P.RetestOffsetUSD = atr * P.Retest_ATR_Mult;
      if(P.MaxSpread_ATR_Mult > 0.0)
         P.MaxSpreadUSD = atr * P.MaxSpread_ATR_Mult;
      if(P.RNDelta_ATR_Mult > 0.0)
         P.RNDelta = atr * P.RNDelta_ATR_Mult;
     }

   ClampPriceField(P.SL_BufferUSD,    pip, 6.0, 40.0);
   ClampPriceField(P.RetestOffsetUSD, pip, 1.0, 15.0);
   ClampPriceField(P.MaxSpreadUSD,    pip, 0.8, 6.0);
   ClampPriceField(P.RNDelta,         pip, 1.0, 20.0);
   ClampPriceField(P.EqTol,           pip, 1.5, 25.0);
   ClampPointField(P.BOSBufferPoints, pipPoints, 1.0, 6.0);

// If ATR is available make sure buffers are not tighter than 0.6x ATR
   if(g_volProfile.atrValue > 0.0)
     {
      double minSL = 0.6 * g_volProfile.atrValue;
      if(P.SL_BufferUSD < minSL)
         P.SL_BufferUSD = minSL;

      double minRetest = 0.25 * g_volProfile.atrValue;
      if(P.RetestOffsetUSD < minRetest)
         P.RetestOffsetUSD = minRetest;

     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetHigherTimeframeProfile()
  {
   if(GetEffectiveUseHTFFilter())
     {
      g_htf_timeframe = GetHigherTimeframe(InpTF);

      // Nếu HTF giống TF vào lệnh, không cần filter
      if(g_htf_timeframe == InpTF)
        {
         Print("HTF is the same as Entry TF. Filter will be disabled.");
        }
      else
        {
         g_htf_ema_handle = iMA(SelectedSymbol, g_htf_timeframe, GetEffectiveHTF_EMA_Period(), 0, (ENUM_MA_METHOD)GetEffectiveHTF_EMA_Method(), PRICE_CLOSE);
         if(g_htf_ema_handle == INVALID_HANDLE)
           {
            Print("Error creating HTF EMA indicator. Filter will be disabled.");
           }
         else
           {
            PrintFormat("HTF Filter enabled. Entry TF: %s, HTF: %s, EMA Period: %d",
                        EnumToString(InpTF), EnumToString(g_htf_timeframe), GetEffectiveHTF_EMA_Period());
           }
        }
     }
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
     {
      if(P.MaxSpreadUSD <= 0.0)
         P.MaxSpreadUSD = lo;
      else
         P.MaxSpreadUSD = MathMin(P.MaxSpreadUSD, hi);
     }

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
     }
   else
      if(!isXAU) // FX generic (EUR, JPY…)
        {
         P.EqTol             = MathMax(P.EqTol,          2.0*pip);
         P.RNDelta           = MathMax(P.RNDelta,        2.5*pip);
         P.SL_BufferUSD      = MathMax(P.SL_BufferUSD,   8.0*pip);
         P.BOSBufferPoints   = MathMax(P.BOSBufferPoints,2.0*pipPoints);
         P.RetestOffsetUSD   = MathMax(P.RetestOffsetUSD,2.0*pip);
        }
// XAU: giữ preset gốc

   ApplyKillzoneDefaultsForSymbol();
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

   double pip = (g_volProfile.pipSize>0.0 ? g_volProfile.pipSize : SymbolPipSize(SelectedSymbol));
   double gridPips = RN_GridPips_FX;
   if(g_volProfile.atrPips > 0.0)
      gridPips = MathMax(5.0, MathMin(gridPips, g_volProfile.atrPips * 5.0));
   if(StringFind(SelectedSymbol,"EURUSD",0)>=0)
      gridPips = MathMin(gridPips, 5.0);
   if(StringFind(SelectedSymbol,"GBPUSD",0)>=0)
      gridPips = MathMin(gridPips, 8.0);
   double inc = MathMax(pip, gridPips * pip);
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PositionsOnSymbol()
  {
   int total = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
      if(PositionGetSymbol(i) == SelectedSymbol)
         total++;
   return total;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLotByRisk(double stop_usd)
  {
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
   lots = MathFloor(lots/lotstep)*lotstep;

// Final validation to prevent "Invalid volume" errors
   if(lots < minlot)
      lots = minlot;
   if(lots > maxlot)
      lots = maxlot;
   if(lotstep > 0 && MathMod(lots, lotstep) != 0)
     {
      lots = MathFloor(lots/lotstep)*lotstep;
     }

   return lots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(!PositionSelect(SelectedSymbol))
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

  }

//=== ------------------------ SIGNAL/ENTRY --------------------------- ===

//+------------------------------------------------------------------+
//| Quét tìm tín hiệu, xác định FVG và đặt lệnh chờ                  |
//+------------------------------------------------------------------+
void CheckSignalAndPlaceOrder()
  {
   // Các bộ lọc cơ bản
   if(IsNearNewsEvent() || PositionsOnSymbol() >= P.MaxOpenPositions || !AllowedToOpenNow())
      return;

   int maxScanRange = P.K_swing;
   for(int sweepBar = 2; sweepBar < maxScanRange; sweepBar++)
     {
      // --- TÌM TÍN HIỆU BÁN (SHORT) ---
      if(P.EnableShort && IsSweepHighBar(sweepBar))
        {
         double bosLevel_FVG;
         int bosBar;
         if(HasBOSDownFrom(sweepBar, P.N_bos, bosLevel_FVG, bosBar))
           {
            if(!FiltersPass(bosBar) || !CheckHTF_Filter(true)) continue;

            // --- TÌM POI (FVG hoặc OB) ---
            POI poi = {0, 0, false};
            if(GetEffectivePOIType() == POI_FVG)
              {
               poi = FindBestFVG(bosBar, sweepBar, false, bosLevel_FVG);
              }
            else // POI_ORDER_BLOCK
              {
               poi = FindBestOrderBlock(bosBar, sweepBar, false, bosLevel_FVG);
              }

            if(poi.isValid)
              {
               double point = SymbolPoint();
               double offset = PipsToPrice(GetEffectiveEntryOffsetPips());
               double entryPrice = poi.top - offset; // Với lệnh bán, vào lệnh ở mép trên của POI
               double stopLoss = rates[sweepBar].high + P.SL_BufferUSD;
               double riskDistance = MathAbs(stopLoss - entryPrice);
               
               if(riskDistance / point < 5) continue; 
               
               double takeProfit = entryPrice - riskDistance * P.TP2_R;
               double lots = CalcLotByRisk(riskDistance);
               datetime expiry = TimeCurrent() + GetEffectivePendingExpiryMinutes() * 60;
               
               if(lots > 0 && SymbolInfoDouble(SelectedSymbol, SYMBOL_ASK) > entryPrice)
                 {
                  if(trade.SellLimit(lots, entryPrice, SelectedSymbol, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiry))
                    {
                     g_lastOpenTime = TimeCurrent();
                     if(Debug) PrintFormat("SUCCESS: Placed Sell Limit at %s. Entry: %.2f, SL: %.2f", EnumToString((ENUM_POI_TYPE)GetEffectivePOIType()), entryPrice, stopLoss);
                     return; 
                    }
                 }
              }
           }
        }

      // --- TÌM TÍN HIỆU MUA (LONG) ---
      if(P.EnableLong && IsSweepLowBar(sweepBar))
        {
         double bosLevel_FVG;
         int bosBar;
         if(HasBOSUpFrom(sweepBar, P.N_bos, bosLevel_FVG, bosBar))
           {
            if(!FiltersPass(bosBar) || !CheckHTF_Filter(false)) continue;
            
            // --- TÌM POI (FVG hoặc OB) ---
            POI poi = {0, 0, false};
            if(GetEffectivePOIType() == POI_FVG)
              {
               poi = FindBestFVG(bosBar, sweepBar, true, bosLevel_FVG);
              }
            else // POI_ORDER_BLOCK
              {
               poi = FindBestOrderBlock(bosBar, sweepBar, true, bosLevel_FVG);
              }

            if(poi.isValid)
              {
               double point = SymbolPoint();
               double offset = PipsToPrice(GetEffectiveEntryOffsetPips());
               double entryPrice = poi.bottom + offset; // Với lệnh mua, vào lệnh ở mép dưới của POI
               double stopLoss = rates[sweepBar].low - P.SL_BufferUSD;
               double riskDistance = MathAbs(entryPrice - stopLoss);
               
               if(riskDistance / point < 5) continue;
               
               double takeProfit = entryPrice + riskDistance * P.TP2_R;
               double lots = CalcLotByRisk(riskDistance);
               datetime expiry = TimeCurrent() + GetEffectivePendingExpiryMinutes() * 60;
               
               if(lots > 0 && SymbolInfoDouble(SelectedSymbol, SYMBOL_BID) < entryPrice)
                 {
                  if(trade.BuyLimit(lots, entryPrice, SelectedSymbol, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiry))
                    {
                     g_lastOpenTime = TimeCurrent();
                     if(Debug) PrintFormat("SUCCESS: Placed Buy Limit at %s. Entry: %.2f, SL: %.2f", EnumToString((ENUM_POI_TYPE)GetEffectivePOIType()), entryPrice, stopLoss);
                     return;
                    }
                 }
              }
           }
        }
     }
  }

void DetectBOSAndArm()
  {
   if(IsNearNewsEvent())
      return; // Nếu gần tin tức, không tìm kiếm tín hiệu


// Quét sweep cách đây 2..(N_bos+1) bar, rồi kiểm tra BOS xuất hiện sau đó (về phía hiện tại)
   int maxS = MathMin(1 + P.N_bos, ArraySize(rates) - 2); // sweep candidate cách tối đa N_bos bar
   for(int s = 2; s <= maxS; ++s) // s = shift của bar sweep trong quá khứ gần
     {
      // SHORT: sweep lên rồi BOS xuống
      if(P.EnableShort && IsSweepHighBar(s))
        {
         double level;
         int bosbar;
         if(HasBOSDownFrom(s, P.N_bos, level, bosbar))
           {
            // Lọc tại BAR BOS (không dùng spread/killzone ở thời điểm hiện tại để quyết định)
            if(!FiltersPass(bosbar))
               continue;

            if(!CheckHTF_Filter(true)) // true vì đây là tín hiệu Short
              {
               if(Debug)
                  Print("BLOCK HTF: Short signal is against the HTF trend.");
               continue; // Bỏ qua tín hiệu này
              }

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
      if(P.EnableLong && IsSweepLowBar(s))
        {
         double level;
         int bosbar;
         if(HasBOSUpFrom(s, P.N_bos, level, bosbar))
           {
            if(!FiltersPass(bosbar))
               continue;

            if(!CheckHTF_Filter(true)) // true vì đây là tín hiệu Short
              {
               if(Debug)
                  Print("BLOCK HTF: Short signal is against the HTF trend.");
               continue; // Bỏ qua tín hiệu này
              }

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
         if(AllowedToOpenNow())
           {
            ok = trade.SellStop(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
            g_lastOpenTime=TimeCurrent();
            g_lastAddPriceSell=price;
            g_addCount=0;
           }
         if(Debug)
            Print("Place SellStop ",ok?"OK":"FAIL"," @",DoubleToString(price,2));
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
         if(AllowedToOpenNow())
           {
            ok = trade.BuyStop(lots, price, SelectedSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
            g_lastOpenTime=TimeCurrent();
            g_lastAddPriceBuy=price;
            g_addCount=0;
           }
         if(Debug)
            Print("Place BuyStop ",ok?"OK":"FAIL"," @",DoubleToString(price,2));
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
                  if(AllowedToOpenNow())
                    {
                     trade.Sell(lots, SelectedSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceSell=SymbolInfoDouble(SelectedSymbol,SYMBOL_BID);
                     g_addCount=0;
                    }
                  if(Debug)
                     Print("Market SELL placed");
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
                  if(AllowedToOpenNow())
                    {
                     trade.Buy(lots, SelectedSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceBuy=SymbolInfoDouble(SelectedSymbol,SYMBOL_ASK);
                     g_addCount=0;
                    }
                  if(Debug)
                     Print("Market BUY placed");
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



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handlePresetInput()
  {
   UCRow r;
   bool loaded = LoadUsecaseFromResource(PresetID, r);
   if(loaded)
     {
      UseInputsAsParams();        // baseline
      ApplyCSVRowToParams(r);     // CSV override
     }
   else
     {
      Print("ERROR: Failed to load usecase from CSV for PresetID=", PresetID);
      // Fallback to manual settings
      if(InpSymbolSelector > 0)
        {
         SelectedSymbol = SelectedSymbol;
         switch(InpSymbolSelector)
           {
            case 1:
               SelectedSymbol = "XAUUSD";
               break;
            case 2:
               SelectedSymbol = "EURUSD";
               break;
            case 3:
               SelectedSymbol = "USDJPY";
               break;
            case 4:
               SelectedSymbol = "BTCUSD";
               break;
            case 5:
               SelectedSymbol = "ETHUSD";
               break;
           }
         Print("Symbol Selector: Using ", SelectedSymbol, " (selector=", InpSymbolSelector, ")");
        }
      else
         SelectedSymbol = InpSymbol;

      UseInputsAsParams(); // Apply input settings as fallback
      SymbolSelect(SelectedSymbol, true);
     }
  }


//=== ------------------------ INIT/TICK ------------------------------- ===
int OnInit()
  {
   handlePresetInput();
   GetHigherTimeframeProfile();
   ApplyAutoSymbolProfile(); // Apply symbol-specific adjustments
   RefreshVolatilityProfile();
   NormalizeFXUnits();
   trade.SetAsyncMode(false);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

// Cập nhật tin tức mỗi 6 giờ một lần
   if(GetEffectiveUseNewsFilter() && (TimeCurrent() - g_last_news_update) > 6 * 3600 && !MQLInfoInteger(MQL_TESTER))
     {
      LoadNewsData();
     }


   if(!UpdateRates(450))
      return;

   if(ArraySize(rates) >= 2 && rates[1].time != last_bar_time)
     {
      last_bar_time = rates[1].time;
      RefreshVolatilityProfile();
      NormalizeFXUnits();
      DetectBOSAndArm();
      TryEnterAfterRetest();
     }

     // Chỉ chạy logic trên mỗi nến mới
   if(ArraySize(rates) >= 2 && rates[1].time != last_bar_time)
     {
      last_bar_time = rates[1].time;
      RefreshVolatilityProfile();
      NormalizeFXUnits();
      
      // Nếu bật FVG, chạy logic mới
      if(GetEffectiveUseFVGEntry())
        {
         CheckSignalAndPlaceOrder();
        }
      else // Giữ lại logic cũ nếu muốn so sánh
        {
          // Bạn cần giữ lại code cũ nếu muốn InpUseFVGEntry = false vẫn chạy được
          DetectBOSAndArm();
          TryEnterAfterRetest();
        }
     }

   ManageOpenPosition();
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
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   if(profile_atr_handle != INVALID_HANDLE)
     {
      IndicatorRelease(profile_atr_handle);
      profile_atr_handle = INVALID_HANDLE;
      profile_atr_symbol = "";
      profile_atr_period = 0;
      profile_atr_tf = PERIOD_CURRENT;
     }
   if(g_htf_ema_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_htf_ema_handle);
      g_htf_ema_handle = INVALID_HANDLE;
     }
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
   string csvLine = StringFormat("%d,%s,%d,%d,%d,%d,%.2f,%.1f,%s,%s,%.2f,%.1f,%.2f,%.1f,%.1f,%.1f,%d,%d,%.1f,%.2f,%d,%s,%.2f,%d,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
                                 PresetID,
                                 SelectedSymbol,
                                 P.K_swing,
                                 P.N_bos,
                                 P.LookbackInternal,
                                 P.M_retest,
                                 P.EqTol,
                                 P.BOSBufferPoints,
                                 P.UseKillzones ? "true" : "false",
                                 P.UseRoundNumber ? "true" : "false",
                                 P.RNDelta,
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
                                 P.CooldownSec,
                                 P.ATRScalingPeriod,
                                 P.SL_ATR_Mult,
                                 P.Retest_ATR_Mult,
                                 P.MaxSpread_ATR_Mult,
                                 P.RNDelta_ATR_Mult);
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

//+------------------------------------------------------------------+
