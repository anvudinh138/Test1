// Base 1..47 + map 48..51 from 232,234,236,239; keep 200..231 & 232..239
// Added BotB fine-tune 232..239 (orthogonal set)
// Base 1..39 + new BotB winners remapped to 40..47; keep 200..231
// Bot B fine-tune pack 220..231
// === XAU_SweepBOS_EA_v1_sprint_2_selected.mq5 ===
// Base 1..26 kept; 27..31 = Sprint1 winners; 32..39 = Sprint2 winners; experiments 200..219 + DoE 37..46 preserved
//+------------------------------------------------------------------+
//|                                                XAU_SweepBOS_Demo |
//|                       Sweep -> BOS (XAUUSD M1) - v1.2 Presets     |
//+------------------------------------------------------------------+
#property copyright "Sweep->BOS Demo EA (XAUUSD M1)"
#property version   "1.2"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>

/*
  v1.2 Highlights - FINAL CLEAN VERSION
  ---------------
  - Preset USECASES: choose PresetID (built-in) or load from CSV (MQL5/Files/XAU_SweepBOS_Presets.csv)
  - Fix Percentile sort (ASC), PositionsOnSymbol(), live spread (bid/ask)
  - Optional Pending Retest orders (SellStop/BuyStop) with expiration
  - Debug logs to trace why signals are blocked (RN/KZ/Spread/VSA)
  - EUR Support added with presets 201-204
  - ALL COMPILATION ERRORS FIXED
*/

//=== ------------------------ INPUTS -------------------------------- ===
input string InpSymbol           = "XAUUSD";
input int    InpSymbolSelector   = 0;        // Quick Symbol: 0=Custom, 1=XAUUSD, 2=EURUSD, 3=USDJPY, 4=BTCUSD, 5=ETHUSD
string SelectedSymbol = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;
// === NEW: auto tune theo symbol/pip
input bool   AutoSymbolProfile   = true;   // tự scale EqTol/RN/Spread/SL theo pip symbol

// Preset system
input bool   UsePreset           = true;     // if true -> override inputs by preset
input int    PresetID            = 1;        // 0=Custom, 1..N built-include
input string Filename = "Usecases_600_1199.csv";  // Tên file CSV

// Switches (used when UsePreset=false, or as defaults before preset override)
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
input double RN_GridPips_FX   = 25.0;  // lưới RN cho FX (pips). 10/25/50 đều hợp lý để test
input double RN_GridUSD_CRYPTO= 100.0; // lưới RN cho Crypto (USD). 50/100/200

// Killzone windows (server time, minutes from 00:00). Adjust per broker.
input int    KZ1_StartMin        = 13*60+55;
input int    KZ1_EndMin          = 14*60+20;
input int    KZ2_StartMin        = 16*60+25;
input int    KZ2_EndMin          = 16*60+40;
input int    KZ3_StartMin        = 19*60+25;
input int    KZ3_EndMin          = 19*60+45;
input int    KZ4_StartMin        = 20*60+55;
input int    KZ4_EndMin          = 21*60+15;

// VSA percentile window
input int    L_percentile        = 150;

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
input bool   UsePendingRetest    = false;    // false=market after retest (default), true=pending stop
input double RetestOffsetUSD     = 0.07;     // pending offset from BOS level
input int    PendingExpirySec    = 60;

// Debug
input bool   Debug               = true;

// === Sprint-1 Feature Testing Inputs ===
enum ENUM_TrailMode { TRAIL_NONE=0, TRAIL_ATR=1, TRAIL_STEP=2 };
input bool   UseTrailing         = false;
input ENUM_TrailMode TrailMode   = TRAIL_NONE;
input int    TrailATRPeriod      = 14;
input double TrailATRMult        = 2.0;
input double TrailStepUSD        = 0.30;
input double TrailStartRR        = 1.0;   // start trailing after R multiple reached
input bool   UsePyramid          = false;
input int    MaxAdds             = 0;
input double AddSpacingUSD       = 0.40;
input double AddSizeFactor       = 0.6;   // 0..1 volume for each add
input int    CooldownSec         = 0;     // block new entries for N seconds after open

//=== ------------------------ GLOBAL STATE --------------------------- ===
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


// --- diagnostics counters (GLOBAL SCOPE) ---
int g_block_rn     = 0;
int g_block_kz     = 0;
int g_block_spread = 0;


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
   P.PartialClosePct=PartialClosePct;
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

struct UCRow {
   string SelectedSymbol;
   int    K_swing, N_bos, M_retest;
   double EqTol_pips;
   int    UseRoundNumber;
   double RNDelta_pips;
   int    UseKillzones;
   double RiskPerTradePct;
   int    TrailMode;
   double SL_Buffer_pips;
   double BOSBuffer_pips;
   int    UsePendingRetest;
   double RetestOffset_pips;
   double TP1_R, TP2_R, BE_Activate_R;
   int    PartialClosePct;
   int    UsePyramid;
   int    MaxAdds;
   double AddSizeFactor;
   double AddSpacing_pips;
   int    MaxOpenPositions;
   int    TimeStopMinutes;
   double MinProgressR;
};

// RNG nhẹ, ổn định giữa lần chạy
uint LCG(uint &s){ s = 1664525u*s + 1013904223u; return s; }
int  PickIdx(const int n, uint &s){ return (int)(LCG(s) % (uint)n); }
int  PickI(const int &arr[], int size, uint &s){ return arr[PickIdx(size,s)]; }
double PickD(const double &arr[], int size, uint &s){ return arr[PickIdx(size,s)]; }

// đổi pips sang tham số P (dùng biến P & SelectedSymbol của EA ông)
void ApplyUCRowToParams(const UCRow &r)
{
   SelectedSymbol = r.SelectedSymbol; // nếu SelectedSymbol là input khác, thì bỏ dòng này

   double pip       = SymbolPipSize(SelectedSymbol);
   double point     = SymbolPoint();
   double pipPoints = (point>0.0 ? pip/point : 0.0);

   P.K_swing          = r.K_swing;
   P.N_bos            = r.N_bos;
   P.M_retest         = r.M_retest;
   P.EqTol            = r.EqTol_pips * pip;
   P.UseRoundNumber   = (r.UseRoundNumber==1);
   P.RNDelta          = r.RNDelta_pips * pip;
   P.UseKillzones     = (r.UseKillzones==1);
   P.RiskPerTradePct  = r.RiskPerTradePct;
   P.TrailMode        = r.TrailMode;
   P.SL_BufferUSD     = r.SL_Buffer_pips * pip;
   P.BOSBufferPoints  = r.BOSBuffer_pips * pipPoints;
   P.UsePendingRetest = (r.UsePendingRetest==1);
   P.RetestOffsetUSD  = r.RetestOffset_pips * pip;
   P.TP1_R            = r.TP1_R;
   P.TP2_R            = r.TP2_R;
   P.BE_Activate_R    = r.BE_Activate_R;
   P.PartialClosePct  = r.PartialClosePct;
   P.UsePyramid       = (r.UsePyramid==1);
   P.MaxAdds          = r.MaxAdds;
   P.AddSizeFactor    = r.AddSizeFactor;
   P.AddSpacingUSD    = r.AddSpacing_pips * pip;

   P.MaxOpenPositions = r.MaxOpenPositions;
   P.TimeStopMinutes  = r.TimeStopMinutes;
   P.MinProgressR     = r.MinProgressR;
}

// sinh UC theo PresetID (600–1199)
bool GetUsecaseByPreset(const int presetID, UCRow &row) {
   if(presetID>=600 && presetID<=799)  row.SelectedSymbol = "EURUSD";
   else if(presetID>=800 && presetID<=999)  row.SelectedSymbol = "USDJPY";
   else if(presetID>=1000 && presetID<=1199)row.SelectedSymbol = "BTCUSD";
   else return false;

   uint s = (uint)presetID * 2654435761u + 12345u;

   // --- lưới giá trị ---
   int     use01[]      = {0,1};
   int     partialPct[] = {40,50,60};
   int     maxAdds[]    = {0,1,2};
   double  addSize[]    = {0.50,0.75};
   int     trailMode[]  = {1,2};
   double  riskPct[]    = {0.3,0.4,0.5};
   double  tp1r[]       = {1.0,1.2,1.5};
   double  tp2r[]       = {2.0,2.5,3.0};
   double  beAct[]      = {0.6,0.8,1.0};

   int     K_EUR[]      = {40,50,60,70};
   int     N_EUR[]      = {6,7,8};
   int     M_EUR[]      = {3,4};
   double  eq_EUR[]     = {1.5,2.0,2.5,3.0};
   double  rn_EUR[]     = {2.0,2.5,3.0};
   int     kz_EUR[]     = {0,1};
   double  sl_EUR[]     = {6,8,10,12};
   double  bos_EUR[]    = {1.0,1.5,2.0};
   double  ret_EUR[]    = {1.5,2.0,2.5};
   double  addsp_EUR[]  = {3,4,5};

   int     K_JPY[]      = {40,50,60,70};
   int     N_JPY[]      = {6,7,8};
   int     M_JPY[]      = {3,4};
   double  eq_JPY[]     = {1.0,1.5,2.0};
   double  rn_JPY[]     = {2.0,2.5,3.0};
   int     kz_JPY[]     = {0,1};
   double  sl_JPY[]     = {6,8,10,12};
   double  bos_JPY[]    = {1.0,1.5,2.0};
   double  ret_JPY[]    = {1.0,1.5,2.0};
   double  addsp_JPY[]  = {3,4,5};

   int     K_BTC[]      = {35,45,55,65,75};
   int     N_BTC[]      = {6,7,8,9};
   int     M_BTC[]      = {3,4,5};
   double  eq_BTC[]     = {1.0,1.5,2.0};
   double  rn_BTC[]     = {2.0,3.0,4.0};
   int     kz_BTC[]     = {0};
   double  sl_BTC[]     = {6,8,10,12};
   double  bos_BTC[]    = {1.0,1.5,2.0};
   double  ret_BTC[]    = {1.0,1.5,2.0};
   double  addsp_BTC[]  = {4,6,8};

   if(row.SelectedSymbol=="EURUSD"){
      row.K_swing          = PickI(K_EUR,  ArraySize(K_EUR),  s);
      row.N_bos            = PickI(N_EUR,  ArraySize(N_EUR),  s);
      row.M_retest         = PickI(M_EUR,  ArraySize(M_EUR),  s);
      row.EqTol_pips       = PickD(eq_EUR, ArraySize(eq_EUR), s);
      row.UseRoundNumber   = PickI(use01,  ArraySize(use01),  s);
      row.RNDelta_pips     = PickD(rn_EUR, ArraySize(rn_EUR), s);
      row.UseKillzones     = PickI(kz_EUR, ArraySize(kz_EUR), s);
      row.RiskPerTradePct  = PickD(riskPct,ArraySize(riskPct),s);
      row.TrailMode        = PickI(trailMode,ArraySize(trailMode),s);
      row.SL_Buffer_pips   = PickD(sl_EUR, ArraySize(sl_EUR), s);
      row.BOSBuffer_pips   = PickD(bos_EUR,ArraySize(bos_EUR),s);
      row.UsePendingRetest = PickI(use01,  ArraySize(use01),  s);
      row.RetestOffset_pips= PickD(ret_EUR,ArraySize(ret_EUR),s);
      row.TP1_R            = PickD(tp1r,  ArraySize(tp1r),   s);
      row.TP2_R            = PickD(tp2r,  ArraySize(tp2r),   s);
      row.BE_Activate_R    = PickD(beAct, ArraySize(beAct),  s);
      row.PartialClosePct  = PickI(partialPct,ArraySize(partialPct),s);
      row.UsePyramid       = PickI(use01,  ArraySize(use01),  s);
      row.MaxAdds          = PickI(maxAdds,ArraySize(maxAdds),s);
      row.AddSizeFactor    = PickD(addSize,ArraySize(addSize),s);
      row.AddSpacing_pips  = PickD(addsp_EUR,ArraySize(addsp_EUR),s);
   }
   else if(row.SelectedSymbol=="USDJPY"){
      row.K_swing          = PickI(K_JPY,  ArraySize(K_JPY),  s);
      row.N_bos            = PickI(N_JPY,  ArraySize(N_JPY),  s);
      row.M_retest         = PickI(M_JPY,  ArraySize(M_JPY),  s);
      row.EqTol_pips       = PickD(eq_JPY, ArraySize(eq_JPY), s);
      row.UseRoundNumber   = PickI(use01,  ArraySize(use01),  s);
      row.RNDelta_pips     = PickD(rn_JPY, ArraySize(rn_JPY), s);
      row.UseKillzones     = PickI(kz_JPY, ArraySize(kz_JPY), s);
      row.RiskPerTradePct  = PickD(riskPct,ArraySize(riskPct),s);
      row.TrailMode        = PickI(trailMode,ArraySize(trailMode),s);
      row.SL_Buffer_pips   = PickD(sl_JPY, ArraySize(sl_JPY), s);
      row.BOSBuffer_pips   = PickD(bos_JPY,ArraySize(bos_JPY),s);
      row.UsePendingRetest = PickI(use01,  ArraySize(use01),  s);
      row.RetestOffset_pips= PickD(ret_JPY,ArraySize(ret_JPY),s);
      row.TP1_R            = PickD(tp1r,  ArraySize(tp1r),   s);
      row.TP2_R            = PickD(tp2r,  ArraySize(tp2r),   s);
      row.BE_Activate_R    = PickD(beAct, ArraySize(beAct),  s);
      row.PartialClosePct  = PickI(partialPct,ArraySize(partialPct),s);
      row.UsePyramid       = PickI(use01,  ArraySize(use01),  s);
      row.MaxAdds          = PickI(maxAdds,ArraySize(maxAdds),s);
      row.AddSizeFactor    = PickD(addSize,ArraySize(addSize),s);
      row.AddSpacing_pips  = PickD(addsp_JPY,ArraySize(addsp_JPY),s);
   }
   else{ // BTCUSD
      row.K_swing          = PickI(K_BTC,  ArraySize(K_BTC),  s);
      row.N_bos            = PickI(N_BTC,  ArraySize(N_BTC),  s);
      row.M_retest         = PickI(M_BTC,  ArraySize(M_BTC),  s);
      row.EqTol_pips       = PickD(eq_BTC, ArraySize(eq_BTC), s);
      row.UseRoundNumber   = PickI(use01,  ArraySize(use01),  s);
      row.RNDelta_pips     = PickD(rn_BTC, ArraySize(rn_BTC), s);
      row.UseKillzones     = PickI(kz_BTC, ArraySize(kz_BTC), s);
      row.RiskPerTradePct  = PickD(riskPct,ArraySize(riskPct),s);
      row.TrailMode        = PickI(trailMode,ArraySize(trailMode),s);
      row.SL_Buffer_pips   = PickD(sl_BTC, ArraySize(sl_BTC), s);
      row.BOSBuffer_pips   = PickD(bos_BTC,ArraySize(bos_BTC),s);
      row.UsePendingRetest = PickI(use01,  ArraySize(use01),  s);
      row.RetestOffset_pips= PickD(ret_BTC,ArraySize(ret_BTC),s);
      row.TP1_R            = PickD(tp1r,  ArraySize(tp1r),   s);
      row.TP2_R            = PickD(tp2r,  ArraySize(tp2r),   s);
      row.BE_Activate_R    = PickD(beAct, ArraySize(beAct),  s);
      row.PartialClosePct  = PickI(partialPct,ArraySize(partialPct),s);
      row.UsePyramid       = PickI(use01,  ArraySize(use01),  s);
      row.MaxAdds          = PickI(maxAdds,ArraySize(maxAdds),s);
      row.AddSizeFactor    = PickD(addSize,ArraySize(addSize),s);
      row.AddSpacing_pips  = PickD(addsp_BTC,ArraySize(addsp_BTC),s);
   }

   row.MaxOpenPositions = 1;
   row.TimeStopMinutes  = 5;
   row.MinProgressR     = 0.5;
   return true;
}

//=== ------------------------ UTILS ---------------------------------- ===
// --- Symbol / Pip adapters ---
double SymbolPipSize(const string sym="")
  {
   string symbol_name = (sym=="" ? SelectedSymbol : sym);
// Metals
   if(StringFind(symbol_name,"XAU",0)>=0)
      return 0.1;           // 1 pip = 0.1 for XAU (2475.0 -> 2475.1)
   if(StringFind(symbol_name,"XAG",0)>=0)
      return 0.01;          // 1 pip = 0.01 for Silver
// Crypto - FIXED VALUES
   if(StringFind(symbol_name,"BTC",0)>=0)
      return 10.0;          // 1 pip = 10.0 for BTC (65000 -> 65010)
   if(StringFind(symbol_name,"ETH",0)>=0)
      return 0.1;           // 1 pip = 0.1 for ETH (3500.0 -> 3500.1)
// FX
   bool isJPY = (StringFind(symbol_name,"JPY",0)>=0);
   if(isJPY)
      return 0.01;                             // 1 pip = 0.01 for JPY crosses (150.00 -> 150.01)
   return 0.0001;                                     // 1 pip = 0.0001 for most FX (1.1750 -> 1.1751)
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PipsToPrice(double pips, const string sym="")
  {
   return pips * SymbolPipSize(sym);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PriceToPips(double pricediff, const string sym="")
  {
   double pip = SymbolPipSize(sym);
   if(pip<=0.0)
      return 0.0;
   return pricediff / pip;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DefaultSpreadForSymbol(string symbol_name, double &hi, double &lo)
  {
   string s = symbol_name;

// ... (giữ nguyên các cặp FX sẵn có)

// BTC/ETH – điển hình cho CFD (tùy broker, ông chỉnh lại theo thực tế spread live)
   if(StringFind(s,"BTC",0) >= 0)
     {
      hi = 12.0;   // USD
      lo = 6.0;
      return true;
     }
   if(StringFind(s,"ETH",0) >= 0)
     {
      hi = 1.20;   // USD
      lo = 0.60;
      return true;
     }

// XAU giữ nguyên
   if(StringFind(s,"XAU",0) >= 0)
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
   int copied = CopyRates(SelectedSymbol, InpTF, 0, need_bars, rates);
   return (copied>0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SymbolPoint()
  {
   return SymbolInfoDouble(SelectedSymbol, SYMBOL_POINT);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SpreadUSD()
  {
   MqlTick t;
   if(!SymbolInfoTick(SelectedSymbol,t))
      return 0.0;
   return (t.ask - t.bid);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsKillzone(datetime t)
  {
   if(!P.UseKillzones)
      return true;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int hm = dt.hour*60 + dt.min;
   if(hm>=P.KZ1s && hm<=P.KZ1e)
      return true;
   if(hm>=P.KZ2s && hm<=P.KZ2e)
      return true;
   if(hm>=P.KZ3s && hm<=P.KZ3e)
      return true;
   if(hm>=P.KZ4s && hm<=P.KZ4e)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RoundMagnet(double price)
  {
   bool isXAU    = (StringFind(SelectedSymbol,"XAU",0)>=0);
   bool isCrypto = (StringFind(SelectedSymbol,"BTC",0)>=0 || StringFind(SelectedSymbol,"ETH",0)>=0);

   if(isXAU)
     {
      // XAU: 0.25
      double base = MathFloor(price);
      double arr[5] = {0.00,0.25,0.50,0.75,1.00};
      double best = base, bestd = 1e9;
      for(int i=0;i<5;i++)
        {
         double p=base+arr[i];
         double d=MathAbs(price-p);
         if(d<bestd)
           {
            best=p;
            bestd=d;
           }
        }
      return best;
     }
   if(isCrypto)
     {
      double inc = RN_GridUSD_CRYPTO;           // USD
      return MathRound(price/inc)*inc;
     }
// FX mặc định: pips → USD
   double pip = SymbolPipSize(SelectedSymbol);
   double inc = RN_GridPips_FX * pip;          // giá
   return MathRound(price/inc)*inc;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NearRound(double price, double delta)
  {
   return MathAbs(price - RoundMagnet(price)) <= delta;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int HighestIndex(int start_shift, int count)
  {
   int best = start_shift;
   double h = rates[best].high;
   for(int i=start_shift; i<start_shift+count && i<ArraySize(rates); ++i)
     {
      if(rates[i].high > h)
        {
         h = rates[i].high;
         best = i;
        }
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
     {
      if(rates[i].low < l)
        {
         l = rates[i].low;
         best = i;
        }
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

// === NEW: Preset block cho EUR (ID 201..204)
bool ApplyPresetEUR(int id)
  {
   UseInputsAsParams(); // lấy default từ input trước
   double pip       = SymbolPipSize(SelectedSymbol);
   double point     = SymbolPoint();
   double pipPoints = (point>0.0 ? pip/point : 0.0);

   switch(id)
     {
      case 201: // Multi_Symbol_Baseline: Universal baseline for all symbols
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=2.0*pip;
         P.BOSBufferPoints=2.0*pipPoints;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false; // No filters for baseline
         P.L_percentile=150;
         P.RNDelta=5.0*pip; // Loose RN if enabled
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=7.0*pip;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50.0;
         P.TimeStopMinutes=50;
         P.MinProgressR=0.5;
         // Dynamic spread based on symbol
         if(StringFind(SelectedSymbol,"BTC",0)>=0)
            P.MaxSpreadUSD=50.0; // $50 for BTC
         else
            if(StringFind(SelectedSymbol,"ETH",0)>=0)
               P.MaxSpreadUSD=5.0; // $5 for ETH
            else
               if(StringFind(SelectedSymbol,"XAU",0)>=0)
                  P.MaxSpreadUSD=0.5; // $0.5 for Gold
               else
                  if(StringFind(SelectedSymbol,"JPY",0)>=0)
                     P.MaxSpreadUSD=0.03; // 3 pips for JPY
                  else
                     P.MaxSpreadUSD=0.0005; // 5 pips for EUR/GBP etc
         P.MaxOpenPositions=2;
         P.UsePendingRetest=false;
         P.RetestOffsetUSD=2.0*pip;
         P.PendingExpirySec=60;
         return true;

      case 202: // EUR_LDN_RN_VSA: London + RN + VSA (precision tốt)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=60;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=2.0*pip;
         P.BOSBufferPoints=2.0*pipPoints;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=1.0*pip; // Fixed for EUR
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=8.0*pip;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.9;
         P.PartialClosePct=40.0;
         P.TimeStopMinutes=45;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.00030;
         P.MaxOpenPositions=2;
         P.UsePendingRetest=false;
         P.RetestOffsetUSD=2.0*pip;
         P.PendingExpirySec=60;
         return true;

      case 203: // EUR_NY_Aggressive: nhiều lệnh hơn
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=35;
         P.N_bos=8;
         P.LookbackInternal=10;
         P.M_retest=4;
         P.EqTol=3.0*pip;
         P.BOSBufferPoints=2.0*pipPoints;
         P.UseKillzones=true;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=120;
         P.RNDelta=2.5*pip;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=7.0*pip;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50.0;
         P.TimeStopMinutes=40;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.00035;
         P.MaxOpenPositions=3;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=2.0*pip;
         P.PendingExpirySec=120;
         return true;

      case 204: // EUR_Pending_Retest: vào bằng pending sau BOS
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=4;
         P.EqTol=2.0*pip;
         P.BOSBufferPoints=2.0*pipPoints;
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=2.5*pip;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=8.0*pip;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.9;
         P.PartialClosePct=40.0;
         P.TimeStopMinutes=45;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.00030;
         P.MaxOpenPositions=2;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=2.0*pip;
         P.PendingExpirySec=90;
         return true;

      case 205: // JPY_Loose: USDJPY with loose filters
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=40;
         P.N_bos=4;
         P.LookbackInternal=8;
         P.M_retest=2; // Looser detection
         P.EqTol=3.0*pip;
         P.BOSBufferPoints=1.5*pipPoints;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false; // No filters
         P.L_percentile=120;
         P.RNDelta=5.0*pip; // Very loose if enabled
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=6.0*pip;
         P.TP1_R=1.5;
         P.TP2_R=3.0;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40.0;
         P.TimeStopMinutes=60;
         P.MinProgressR=0.3; // More patient
         P.MaxSpreadUSD=0.05;
         P.MaxOpenPositions=3; // 5 pip spread, more positions
         P.UsePendingRetest=false;
         P.RetestOffsetUSD=1.5*pip;
         P.PendingExpirySec=60;
         return true;

      // === FIXED: NO KILLZONES VERSION ===
      // Problem: Killzones too restrictive for non-XAU symbols

      case 300:
         SelectedSymbol="BTCUSD"; // BTC_24H_NoKZ (24h trading + trail + pyramid)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=20.0;
         P.BOSBufferPoints=2.0;
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false; // NO KILLZONES!
         P.L_percentile=150;
         P.RNDelta=50.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=30.0;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=50.0;
         P.MaxOpenPositions=3;
         // XAU-style features but 24h trading
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=25.0;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=100.0;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 301:
         SelectedSymbol="BTCUSD"; // BTC_Conservative_NoKZ (quality over quantity)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=60;
         P.N_bos=7;
         P.LookbackInternal=15;
         P.M_retest=4; // More selective
         P.EqTol=10.0;
         P.BOSBufferPoints=1.5;
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false; // NO KILLZONES!
         P.L_percentile=170;
         P.RNDelta=25.0; // Tighter RN
         P.RiskPerTradePct=0.3;
         P.SL_BufferUSD=20.0;
         P.TP1_R=2.0;
         P.TP2_R=4.0; // Higher R:R
         P.BE_Activate_R=1.0;
         P.PartialClosePct=30.0; // Conservative partials
         P.MaxSpreadUSD=30.0;
         P.MaxOpenPositions=2; // Fewer positions
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=20.0;
         P.TrailStartRR=1.0;
         P.UsePyramid=false;
         P.MaxAdds=0; // No pyramid - quality focus
         P.CooldownSec=60;
         return true;

      case 302:
         SelectedSymbol="BTCUSD"; // BTC Aggressive
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=30;
         P.N_bos=3;
         P.LookbackInternal=6;
         P.M_retest=1;
         P.EqTol=30.0;
         P.BOSBufferPoints=15.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=100;
         P.RNDelta=200.0;
         P.RiskPerTradePct=1.0;
         P.SL_BufferUSD=80.0;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.MaxSpreadUSD=150.0;
         P.MaxOpenPositions=3;
         return true;

      // ETH Presets 320-340
      case 320:
         SelectedSymbol="ETHUSD"; // ETH_24H_ATR_Trail (24h ATR trailing)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=2.0;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false; // NO KILLZONES!
         P.L_percentile=150;
         P.RNDelta=5.0; // Looser RN
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=6.0;
         P.TP1_R=1.5;
         P.TP2_R=3.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=10.0;
         P.MaxOpenPositions=3;
         // ATR trailing for crypto volatility
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.8;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=8.0;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 321:
         SelectedSymbol="ETHUSD"; // ETH Precision
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=60;
         P.N_bos=6;
         P.LookbackInternal=15;
         P.M_retest=4;
         P.EqTol=1.0;
         P.BOSBufferPoints=0.5;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=160;
         P.RNDelta=2.0;
         P.RiskPerTradePct=0.3;
         P.SL_BufferUSD=5.0;
         P.TP1_R=2.0;
         P.TP2_R=4.0;
         P.MaxSpreadUSD=5.0;
         P.MaxOpenPositions=1;
         return true;

      // EURUSD Presets 340-360
      case 340:
         SelectedSymbol="EURUSD"; // EUR_24H_STEP_Trail (24h STEP trailing)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=45;
         P.N_bos=5;
         P.LookbackInternal=10;
         P.M_retest=2; // Faster signals
         P.EqTol=0.0002;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false; // NO FILTERS!
         P.L_percentile=120;
         P.RNDelta=0.0008; // Loose RN
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.005;
         P.TP1_R=1.5;
         P.TP2_R=2.5;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=0.0008;
         P.MaxOpenPositions=3;
         // STEP trailing for FX precision
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.0025;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.004;
         P.AddSizeFactor=0.6;
         P.CooldownSec=20;
         return true;

      case 341:
         SelectedSymbol="EURUSD"; // EUR London Session
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=5;
         P.LookbackInternal=10;
         P.M_retest=2;
         P.EqTol=0.0002;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=140;
         P.RNDelta=0.0005;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.005;
         P.TP1_R=1.5;
         P.TP2_R=2.5;
         P.MaxSpreadUSD=0.0003;
         P.MaxOpenPositions=2;
         return true;

      case 342:
         SelectedSymbol="EURUSD"; // EUR Conservative
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=70;
         P.N_bos=7;
         P.LookbackInternal=15;
         P.M_retest=4;
         P.EqTol=0.0003;
         P.BOSBufferPoints=2.0;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=170;
         P.RNDelta=0.0003;
         P.RiskPerTradePct=0.2;
         P.SL_BufferUSD=0.008;
         P.TP1_R=2.0;
         P.TP2_R=4.0;
         P.MaxSpreadUSD=0.0002;
         P.MaxOpenPositions=1;
         return true;

      // USDJPY Presets 360-380
      case 360:
         SelectedSymbol="USDJPY"; // JPY_24H_Active (24h active trading)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=40;
         P.N_bos=5;
         P.LookbackInternal=8;
         P.M_retest=2; // Active settings
         P.EqTol=0.025;
         P.BOSBufferPoints=1.5; // Looser for more trades
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false; // NO FILTERS!
         P.L_percentile=120;
         P.RNDelta=0.08; // Very loose RN
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.06;
         P.TP1_R=1.5;
         P.TP2_R=2.5;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50.0;
         P.MaxSpreadUSD=0.08;
         P.MaxOpenPositions=3;
         // Aggressive trailing for JPY momentum
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.03;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.05;
         P.AddSizeFactor=0.6;
         P.CooldownSec=15; // Fast re-entry
         return true;

      case 361:
         SelectedSymbol="USDJPY"; // JPY Tight
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=60;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=0.015;
         P.BOSBufferPoints=0.5;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=0.03;
         P.RiskPerTradePct=0.3;
         P.SL_BufferUSD=0.04;
         P.TP1_R=2.0;
         P.TP2_R=4.0;
         P.MaxSpreadUSD=0.03;
         P.MaxOpenPositions=1;
         return true;

      // === PHASE 1: QUALITY FOCUS (UC380-384) ===
      case 380:
         SelectedSymbol="XAUUSD"; // XAU_REFERENCE (Keep original success)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=0.35;
         P.BOSBufferPoints=2.0;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=7.0;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=0.5;
         P.MaxOpenPositions=3;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.35;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.35;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 381:
         SelectedSymbol="BTCUSD"; // BTC_QUALITY_FOCUS (Tight detection) - FIXED PIP VALUES
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=70;
         P.N_bos=8;
         P.LookbackInternal=18;
         P.M_retest=5; // MUCH TIGHTER
         P.EqTol=100.0;
         P.BOSBufferPoints=10.0; // 10 pip tolerance for BTC
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=200;
         P.RNDelta=50.0; // 5 pip RN for BTC (50.0/10.0)
         P.RiskPerTradePct=0.3;
         P.SL_BufferUSD=20.0;
         P.TP1_R=2.0;
         P.TP2_R=4.0; // Higher R:R
         P.BE_Activate_R=1.0;
         P.PartialClosePct=25.0; // Conservative exits
         P.MaxSpreadUSD=30.0;
         P.MaxOpenPositions=2; // Fewer positions
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=2.0;
         P.TrailStartRR=1.0;
         P.UsePyramid=false;
         P.MaxAdds=0; // NO PYRAMID = Quality focus
         P.CooldownSec=120; // Long cooldown
         return true;

      case 382:
         SelectedSymbol="ETHUSD"; // ETH_PRECISION (Quality over quantity) - FIXED PIP VALUES
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=80;
         P.N_bos=7;
         P.LookbackInternal=20;
         P.M_retest=4; // TIGHT
         P.EqTol=1.0;
         P.BOSBufferPoints=0.5; // 10 pip tolerance for ETH (1.0/0.1)
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=180;
         P.RNDelta=0.5; // 5 pip RN for ETH (0.5/0.1)
         P.RiskPerTradePct=0.3;
         P.SL_BufferUSD=4.0;
         P.TP1_R=2.5;
         P.TP2_R=5.0; // High R:R
         P.BE_Activate_R=1.2;
         P.PartialClosePct=20.0;
         P.MaxSpreadUSD=6.0;
         P.MaxOpenPositions=1; // Single position focus
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=2.2;
         P.TrailStartRR=1.0;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.CooldownSec=180; // Very selective
         return true;

      case 383:
         SelectedSymbol="EURUSD"; // EUR_PRECISION (FX quality focus)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=75;
         P.N_bos=7;
         P.LookbackInternal=15;
         P.M_retest=4; // Tighter
         P.EqTol=0.0001;
         P.BOSBufferPoints=0.5; // FX precision
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=170;
         P.RNDelta=0.0005; // Tight 0.5 pip RN
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.003;
         P.TP1_R=2.0;
         P.TP2_R=3.5;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=30.0;
         P.MaxSpreadUSD=0.0003;
         P.MaxOpenPositions=2;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.0015;
         P.TrailStartRR=1.0;
         P.UsePyramid=false;
         P.MaxAdds=0; // Quality focus
         P.CooldownSec=90;
         return true;

      case 384:
         SelectedSymbol="USDJPY"; // JPY_PRECISION (Asian precision)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=65;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3; // Moderate tight
         P.EqTol=0.012;
         P.BOSBufferPoints=0.8;
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=160;
         P.RNDelta=0.025; // 2.5 pip RN
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.04;
         P.TP1_R=1.8;
         P.TP2_R=3.0;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=35.0;
         P.MaxSpreadUSD=0.04;
         P.MaxOpenPositions=2;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.02;
         P.TrailStartRR=1.0;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.CooldownSec=60;
         return true;

      // === PHASE 2: XAU PROVEN CLONES (UC385-389) ===
      // Copy exact UC32,40,46,47,48,49 settings with symbol scaling

      case 385:
         SelectedSymbol="BTCUSD"; // BTC_XAU_UC32_Clone (Conservative pyramid)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=15.0;
         P.BOSBufferPoints=2.0; // Scaled from XAU 0.15
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=35.0; // Scaled from XAU 0.35
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=25.0;
         P.TP1_R=1.5;
         P.TP2_R=3.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=30.0;
         P.MaxSpreadUSD=40.0;
         P.MaxOpenPositions=3;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=30.0;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=1;
         P.AddSpacingUSD=50.0;
         P.AddSizeFactor=0.7;
         P.CooldownSec=45;
         return true;

      case 386:
         SelectedSymbol="BTCUSD"; // BTC_XAU_UC40_Clone (Active pyramid)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=17.5;
         P.BOSBufferPoints=2.0; // UC40 style
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=35.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=28.0;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=45.0;
         P.MaxOpenPositions=3;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=35.0;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=35.0;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 387:
         SelectedSymbol="ETHUSD"; // ETH_XAU_UC46_Clone (ATR trailing)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=1.75;
         P.BOSBufferPoints=1.0; // Scaled from XAU
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=3.5; // Scaled from XAU 0.35
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=6.0;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=8.0;
         P.MaxOpenPositions=3;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.4;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=3.5;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 388:
         SelectedSymbol="EURUSD"; // EUR_XAU_UC47_Clone (STEP trail)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=0.000175;
         P.BOSBufferPoints=1.0; // Perfect scale from XAU
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=0.00035; // Perfect scale
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.007;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40.0;
         P.MaxSpreadUSD=0.0005;
         P.MaxOpenPositions=3;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.0025;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.003;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      case 389:
         SelectedSymbol="USDJPY"; // JPY_XAU_UC48_Clone (STEP trail)
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=50;
         P.N_bos=6;
         P.LookbackInternal=12;
         P.M_retest=3;
         P.EqTol=0.0175;
         P.BOSBufferPoints=1.0; // Perfect scale
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=0.035; // Perfect scale
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.05;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=30.0;
         P.MaxSpreadUSD=0.05;
         P.MaxOpenPositions=4;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.022;
         P.TrailStartRR=0.8;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.032;
         P.AddSizeFactor=0.6;
         P.CooldownSec=30;
         return true;

      // GBPUSD Presets 400-420
      case 400:
         SelectedSymbol="GBPUSD"; // GBP Baseline
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=45;
         P.N_bos=5;
         P.LookbackInternal=10;
         P.M_retest=2;
         P.EqTol=0.0002;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=130;
         P.RNDelta=0.0008;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.008;
         P.TP1_R=1.5;
         P.TP2_R=3.0;
         P.MaxSpreadUSD=0.0008;
         P.MaxOpenPositions=2;
         return true;

      case 401:
         SelectedSymbol="GBPUSD"; // GBP Volatile
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=35;
         P.N_bos=4;
         P.LookbackInternal=7;
         P.M_retest=1;
         P.EqTol=0.0003;
         P.BOSBufferPoints=1.5;
         P.UseKillzones=true;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=110;
         P.RNDelta=0.001;
         P.RiskPerTradePct=0.7;
         P.SL_BufferUSD=0.012;
         P.TP1_R=1.2;
         P.TP2_R=2.0;
         P.MaxSpreadUSD=0.001;
         P.MaxOpenPositions=3;
         return true;

      // === EXTENDED PRESET SYSTEM 420-500 ===
      // More BTC variations 420-430
      case 420:
         SelectedSymbol="BTCUSD"; // BTC Scalp Ultra
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=20;
         P.N_bos=2;
         P.LookbackInternal=4;
         P.M_retest=1;
         P.EqTol=50.0;
         P.BOSBufferPoints=25.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=80;
         P.RNDelta=300.0;
         P.RiskPerTradePct=1.5;
         P.SL_BufferUSD=100.0;
         P.TP1_R=0.8;
         P.TP2_R=1.2;
         P.MaxSpreadUSD=200.0;
         P.MaxOpenPositions=5;
         return true;

      case 421:
         SelectedSymbol="BTCUSD"; // BTC Conservative
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=80;
         P.N_bos=8;
         P.LookbackInternal=20;
         P.M_retest=5;
         P.EqTol=5.0;
         P.BOSBufferPoints=2.5;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=200;
         P.RNDelta=25.0;
         P.RiskPerTradePct=0.2;
         P.SL_BufferUSD=20.0;
         P.TP1_R=3.0;
         P.TP2_R=6.0;
         P.MaxSpreadUSD=30.0;
         P.MaxOpenPositions=1;
         return true;

      // More ETH variations 430-440
      case 430:
         SelectedSymbol="ETHUSD"; // ETH Scalp
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=25;
         P.N_bos=2;
         P.LookbackInternal=5;
         P.M_retest=1;
         P.EqTol=5.0;
         P.BOSBufferPoints=2.5;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=80;
         P.RNDelta=10.0;
         P.RiskPerTradePct=1.2;
         P.SL_BufferUSD=15.0;
         P.TP1_R=0.8;
         P.TP2_R=1.5;
         P.MaxSpreadUSD=20.0;
         P.MaxOpenPositions=4;
         return true;

      case 431:
         SelectedSymbol="ETHUSD"; // ETH Conservative
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=70;
         P.N_bos=7;
         P.LookbackInternal=18;
         P.M_retest=4;
         P.EqTol=0.5;
         P.BOSBufferPoints=0.25;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=180;
         P.RNDelta=1.0;
         P.RiskPerTradePct=0.25;
         P.SL_BufferUSD=3.0;
         P.TP1_R=2.5;
         P.TP2_R=5.0;
         P.MaxSpreadUSD=3.0;
         P.MaxOpenPositions=1;
         return true;

      // More EUR variations 440-450
      case 440:
         SelectedSymbol="EURUSD"; // EUR Ultra Scalp
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=20;
         P.N_bos=2;
         P.LookbackInternal=4;
         P.M_retest=1;
         P.EqTol=0.00005;
         P.BOSBufferPoints=0.25;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=70;
         P.RNDelta=0.002;
         P.RiskPerTradePct=1.2;
         P.SL_BufferUSD=0.002;
         P.TP1_R=0.6;
         P.TP2_R=1.0;
         P.MaxSpreadUSD=0.0015;
         P.MaxOpenPositions=8;
         return true;

      case 441:
         SelectedSymbol="EURUSD"; // EUR News Trading
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=40;
         P.N_bos=4;
         P.LookbackInternal=8;
         P.M_retest=2;
         P.EqTol=0.0004;
         P.BOSBufferPoints=2.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=100;
         P.RNDelta=0.002;
         P.RiskPerTradePct=0.8;
         P.SL_BufferUSD=0.01;
         P.TP1_R=1.8;
         P.TP2_R=3.5;
         P.MaxSpreadUSD=0.0008;
         P.MaxOpenPositions=3;
         return true;

      // More JPY variations 450-460
      case 450:
         SelectedSymbol="USDJPY"; // JPY Scalp
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=25;
         P.N_bos=3;
         P.LookbackInternal=5;
         P.M_retest=1;
         P.EqTol=0.04;
         P.BOSBufferPoints=2.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=90;
         P.RNDelta=0.1;
         P.RiskPerTradePct=1.0;
         P.SL_BufferUSD=0.04;
         P.TP1_R=0.8;
         P.TP2_R=1.5;
         P.MaxSpreadUSD=0.08;
         P.MaxOpenPositions=4;
         return true;

      case 451:
         SelectedSymbol="USDJPY"; // JPY Conservative
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=70;
         P.N_bos=7;
         P.LookbackInternal=18;
         P.M_retest=4;
         P.EqTol=0.01;
         P.BOSBufferPoints=0.5;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=180;
         P.RNDelta=0.02;
         P.RiskPerTradePct=0.25;
         P.SL_BufferUSD=0.03;
         P.TP1_R=2.5;
         P.TP2_R=5.0;
         P.MaxSpreadUSD=0.02;
         P.MaxOpenPositions=1;
         return true;

      // More XAU variations 460-470
      case 460:
         SelectedSymbol="XAUUSD"; // XAU News
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=35;
         P.N_bos=4;
         P.LookbackInternal=8;
         P.M_retest=2;
         P.EqTol=0.02;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=110;
         P.RNDelta=0.2;
         P.RiskPerTradePct=0.8;
         P.SL_BufferUSD=0.8;
         P.TP1_R=1.8;
         P.TP2_R=3.5;
         P.MaxSpreadUSD=1.5;
         P.MaxOpenPositions=3;
         return true;

      case 461:
         SelectedSymbol="XAUUSD"; // XAU Ultra Conservative
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=100;
         P.N_bos=10;
         P.LookbackInternal=25;
         P.M_retest=6;
         P.EqTol=0.002;
         P.BOSBufferPoints=0.1;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=220;
         P.RNDelta=0.02;
         P.RiskPerTradePct=0.1;
         P.SL_BufferUSD=0.15;
         P.TP1_R=4.0;
         P.TP2_R=8.0;
         P.MaxSpreadUSD=0.2;
         P.MaxOpenPositions=1;
         return true;

      // Cross pairs 470-490
      case 470:
         SelectedSymbol="EURJPY"; // EURJPY Baseline
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=45;
         P.N_bos=5;
         P.LookbackInternal=10;
         P.M_retest=2;
         P.EqTol=0.02;
         P.BOSBufferPoints=1.0;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=130;
         P.RNDelta=0.05;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.08;
         P.TP1_R=1.5;
         P.TP2_R=3.0;
         P.MaxSpreadUSD=0.06;
         P.MaxOpenPositions=2;
         return true;

      case 471:
         SelectedSymbol="GBPJPY"; // GBPJPY Volatile
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=30;
         P.N_bos=3;
         P.LookbackInternal=6;
         P.M_retest=1;
         P.EqTol=0.03;
         P.BOSBufferPoints=1.5;
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.L_percentile=100;
         P.RNDelta=0.08;
         P.RiskPerTradePct=0.8;
         P.SL_BufferUSD=0.12;
         P.TP1_R=1.2;
         P.TP2_R=2.5;
         P.MaxSpreadUSD=0.1;
         P.MaxOpenPositions=3;
         return true;

      case 472:
         SelectedSymbol="EURGBP"; // EURGBP Range
         P.EnableLong=true;
         P.EnableShort=true;
         P.K_swing=60;
         P.N_bos=6;
         P.LookbackInternal=15;
         P.M_retest=3;
         P.EqTol=0.0001;
         P.BOSBufferPoints=0.5;
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=160;
         P.RNDelta=0.0003;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.004;
         P.TP1_R=1.8;
         P.TP2_R=3.0;
         P.MaxSpreadUSD=0.0004;
         P.MaxOpenPositions=2;
         return true;
     }
   return false;
  }

// XAU preset function with key presets
bool ApplyPresetBuiltIn(int id)
  {
   UseInputsAsParams();

   if(id==0)
      return true; // custom

   double pip       = SymbolPipSize(SelectedSymbol);
   double point     = SymbolPoint();
   double pipPoints = (point>0.0 ? pip/point : 0.0);

   switch(id)
     {
      case 1: // MAPPING-> original 91
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.28;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      case 2: // MAPPING-> original 90 // NY_C31_STRICT_SPREAD45
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.45;
         return true;

      case 3: // MAPPING-> original 123
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.48;
         P.BE_Activate_R=1.0;
         return true;

      // Add more key presets as needed...
      default:
         // Default XAU case
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.28;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SetupParamsFromPreset()
  {
   UseInputsAsParams();
   bool ok = false;

   if(UsePreset)
     {
      // Handle different preset ranges
      if(PresetID >= 600 && PresetID <= 1199)
        {
         // UC 600-1199 are handled separately in OnInit via ApplyUCRowToParams
         ok = true; // Already applied
        }
      else if(PresetID>=200)
        {
         ok = ApplyPresetEUR(PresetID);
        }
      else
        {
         ok = ApplyPresetBuiltIn(PresetID);
        }

      ApplyAutoSymbolProfile();
     }

   if(Debug)
      Print("Preset applied: ok=", ok, " ID=", PresetID, " Symbol=", SelectedSymbol);
   return ok;
  }

// Helper functions
bool IsSweepHighBar(int bar)
  {
   int start = bar+1;
   int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3)
      return false;

   int ih = HighestIndex(start, cnt);
   double swingH = rates[ih].high;
   double pt = SymbolPoint();

   if(rates[bar].high > swingH + pt && rates[bar].close < swingH)
      return true;
   if(MathAbs(rates[bar].high - swingH) <= P.EqTol && rates[bar].close < swingH)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSweepLowBar(int bar)
  {
   int start = bar+1;
   int cnt = MathMin(P.K_swing, ArraySize(rates)-start);
   if(cnt<3)
      return false;

   int il = LowestIndex(start, cnt);
   double swingL = rates[il].low;
   double pt = SymbolPoint();

   if(rates[bar].low < swingL - pt && rates[bar].close > swingL)
      return true;
   if(MathAbs(rates[bar].low - swingL) <= P.EqTol && rates[bar].close > swingL)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriorInternalSwingLow(int bar)
  {
   int start = bar+1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3)
      return -1;
   return LowestIndex(start, cnt);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriorInternalSwingHigh(int bar)
  {
   int start = bar+1;
   int cnt = MathMin(P.LookbackInternal, ArraySize(rates)-start);
   if(cnt<3)
      return -1;
   return HighestIndex(start, cnt);
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

// === Sprint-1 helpers ===
datetime g_lastOpenTime = 0;
double   g_lastAddPriceBuy = 0.0, g_lastAddPriceSell = 0.0;
int      g_addCount = 0;
int      atr_handle = INVALID_HANDLE;
double   last_atr = 0.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AllowedToOpenNow()
  {
   if(P.CooldownSec<=0)
      return true;
   if(g_lastOpenTime==0)
      return true;
   return (TimeCurrent() - g_lastOpenTime) >= P.CooldownSec;
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
            if(AllowedToOpenNow())
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
               if(AllowedToOpenNow())
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
   int total=0;
   for(int i=0;i<PositionsTotal();++i)
     {
      string sym = PositionGetSymbol(i);
      if(sym==SelectedSymbol)
         total++;
     }
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


//=== ------------------------ INIT/TICK ------------------------------- ===
int OnInit()
  {
// Generate CSV file only once when PresetID = 600 (first usecase)
 

// Handle symbol selector and preset application
   if(PresetID >= 600 && PresetID <= 1199)
        {
         UCRow r;
         if(GetUsecaseByPreset(PresetID, r))
           {
            ApplyUCRowToParams(r);
            trade.SetAsyncMode(false);
            // Don't call SetupParamsFromPreset again - already applied via ApplyUCRowToParams
            Print("Applied UC", PresetID, " for symbol: ", SelectedSymbol);
            return(INIT_SUCCEEDED);
           }
         else
           {
            Print("ERROR: Failed to get usecase for PresetID=", PresetID);
            return(INIT_FAILED);
           }
        }

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
      // Note: SelectedSymbol is const input, so we can't change it.
      // The selector is for UI convenience only - user must still set SelectedSymbol manually
     }
   else
      SelectedSymbol = InpSymbol;

   trade.SetAsyncMode(false);
   SetupParamsFromPreset();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void OnTick()
  {
   if(!UpdateRates(450))
      return;

   if(ArraySize(rates)>=2 && rates[1].time != last_bar_time)
     {
      last_bar_time = rates[1].time;
      DetectBOSAndArm();
      TryEnterAfterRetest();
     }
   ManageOpenPosition();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atr_handle!=INVALID_HANDLE)
      IndicatorRelease(atr_handle);

// Get backtest statistics
   double initialDeposit = 5000.0; // Default starting balance
   double finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double netProfit = finalBalance - initialDeposit;
   double grossProfit = 0.0;
   double grossLoss = 0.0;
   int totalDeals = 0;
   int profitTrades = 0;
   int lossTrades = 0;
   double largestProfit = 0.0;
   double largestLoss = 0.0;
   double totalProfitAmount = 0.0;
   double totalLossAmount = 0.0;

// Calculate statistics from deals (simpler approach)
   if(HistorySelect(0, TimeCurrent()))
     {
      totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
           {
            // Only count deals for our symbol and exclude balance operations
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == SelectedSymbol)
              {
               long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
               if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
                 {
                  double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                  double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                  double totalProfit = profit + swap + commission;

                  if(totalProfit > 0.01) // Avoid rounding errors
                    {
                     grossProfit += totalProfit;
                     profitTrades++;
                     totalProfitAmount += totalProfit;
                     if(totalProfit > largestProfit)
                        largestProfit = totalProfit;
                    }
                  else
                     if(totalProfit < -0.01)
                       {
                        grossLoss += totalProfit;
                        lossTrades++;
                        totalLossAmount += totalProfit;
                        if(totalProfit < largestLoss)
                           largestLoss = totalProfit;
                       }
                 }
              }
           }
        }
     }

   double profitFactor = (grossLoss != 0) ? (grossProfit / MathAbs(grossLoss)) : 0.0;
   double avgProfit = (profitTrades > 0) ? (totalProfitAmount / profitTrades) : 0.0;
   double avgLoss = (lossTrades > 0) ? (totalLossAmount / lossTrades) : 0.0;

// === DETAILED ANALYSIS LOGS ===
   Print("=== UC", PresetID, " (", SelectedSymbol, ") ANALYSIS ===");
   Print("PERFORMANCE: Net $", DoubleToString(netProfit, 2), ", PF ", DoubleToString(profitFactor, 2),
         ", Trades ", (profitTrades + lossTrades), " (", profitTrades, "W/", lossTrades, "L)");
   Print("PROFIT DETAILS: Gross $", DoubleToString(grossProfit, 2), ", Loss $", DoubleToString(grossLoss, 2),
         ", Avg Win $", DoubleToString(avgProfit, 2), ", Avg Loss $", DoubleToString(avgLoss, 2));
   Print("EXTREME TRADES: Largest Win $", DoubleToString(largestProfit, 2), ", Largest Loss $", DoubleToString(largestLoss, 2));

// Filter analysis with CORRECTED pip display
   string filterStatus = "";
   if(P.UseKillzones)
      filterStatus += "KZ-ON ";
   if(P.UseRoundNumber)
      filterStatus += "RN-ON ";
   if(P.UseVSA)
      filterStatus += "VSA-ON ";
   if(filterStatus == "")
      filterStatus = "NO-FILTERS";
   double pipSize = SymbolPipSize(SelectedSymbol);
   double rnDeltaPips = P.RNDelta / pipSize; // CORRECT pip calculation
   Print("FILTERS: ", filterStatus, ", RNDelta=", DoubleToString(rnDeltaPips, 1), "pips");

// Trading style analysis
   string styleInfo = "";
   if(P.UseTrailing)
      styleInfo += "TRAIL-" + IntegerToString(P.TrailMode) + " ";
   if(P.UsePyramid)
      styleInfo += "PYRAMID-" + IntegerToString(P.MaxAdds) + " ";
   styleInfo += "Risk" + DoubleToString(P.RiskPerTradePct, 1) + "%";
   Print("STYLE: ", styleInfo, ", TP ", DoubleToString(P.TP1_R, 1), "R/", DoubleToString(P.TP2_R, 1), "R");

// Detection settings with CORRECTED pip display
   double eqTolPips = P.EqTol / pipSize; // CORRECT pip calculation
   Print("DETECTION: K=", P.K_swing, ", N=", P.N_bos, ", M=", P.M_retest,
         ", EqTol=", DoubleToString(eqTolPips, 1), "pips");

   // Đếm "BLOCK RN/KZ/Spread" để chẩn đoán nhanh
   Print("FILTER BLOCKS: RN=", g_block_rn, ", KZ=", g_block_kz, ", Spread=", g_block_spread);


// SUMMARY STATS (requested by user)
// Note: Block counts would require global counters throughout the EA
// For now, showing key metrics that explain PF performance
   double winRate = (totalDeals > 0) ? ((double)profitTrades / (profitTrades + lossTrades) * 100.0) : 0.0;
   string summary = "SUMMARY: WinRate=" + DoubleToString(winRate, 1) + "%, ";
   summary += "AvgR=" + DoubleToString((avgLoss != 0) ? (avgProfit / MathAbs(avgLoss)) : 0, 2) + ", ";
   summary += "MaxDD=" + DoubleToString(largestLoss, 2);
   Print(summary);
   Print("=== END UC", PresetID, " ===");
  }
//+------------------------------------------------------------------+
