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
  v1.2 Highlights
  ---------------
  - Preset USECASES: choose PresetID (built-in) or load from CSV (MQL5/Files/XAU_SweepBOS_Presets.csv)
  - Fix Percentile sort (ASC), PositionsOnSymbol(), live spread (bid/ask)
  - Optional Pending Retest orders (SellStop/BuyStop) with expiration
  - Debug logs to trace why signals are blocked (RN/KZ/Spread/VSA)
*/

//=== ------------------------ INPUTS -------------------------------- ===
input string InpSymbol           = "XAUUSD";
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;
// === NEW: auto tune theo symbol/pip
input bool   AutoSymbolProfile   = true;   // tự scale EqTol/RN/Spread/SL theo pip symbol

// Preset system
input bool   UsePreset           = true;     // if true -> override inputs by preset
input int    PresetID            = 1;        // 0=Custom, 1..N built-include

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
   P.TrailMode=TrailMode;
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApplyPresetBuiltIn(int id)
  {
   UseInputsAsParams(); // lấy default từ input trước


   if(id==0)
      return true; // custom

   // multiple symbol
   double pip       = SymbolPipSize(InpSymbol);
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

      // 92 NY_C31_MICRO_RN32

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

      // 91 NY_C31_MICRO_RN28  (vi tinh chỉnh quanh 31/62/90)

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

      // 124 LDN_RN33_BUFFER2 (vi mô quanh 101/102)

      case 4: // MAPPING-> original 36
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 37 NY_OPEN_PENDING_05

      case 5: // MAPPING-> original 62
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.25;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      // 63 NY_C31_SPREAD50 (siết spread)

      case 6: // MAPPING-> original 63
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.50;
         return true;

      // 64 NY_C31_RETEST2 (vào nhanh)

      case 7: // MAPPING-> original 64
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=2;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 65 NY_C31_RETEST4 (chậm hơn)

      case 8: // MAPPING-> original 65
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=4;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 66 NY_C31_EQTOL18 (equal strict)

      case 9: // MAPPING-> original 89 // NY_C31_RN40
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      case 10: // MAPPING-> original 92
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.32;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      // 93 NY_C31_BE_1R (dời BE muộn để giữ vị thế)

      case 11: // MAPPING-> original 93
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=50;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      // 94 NY_C31_PARTIAL0_BE1R (full TP2 + BE 1R)

      case 12: // MAPPING-> original 95
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=1.5;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      // 96 NY_C31_BUFFER_2_5 (BOS buffer 2.5pt)

      case 13: // MAPPING-> original 121
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1188;
         P.KZ4s=1253;
         P.KZ4e=1278;
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

      // 122 NY_BE_1R_PARTIAL40

      case 14: // MAPPING-> original 66
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.55;
         return true;

      // 67 NY_C31_EQTOL28 (equal loose)

      case 15: // MAPPING-> original 96
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.5;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.55;
         return true;

      // 97 NY_C31_TIMEFAST (time-stop 4' @0.6R)

      case 16: // MAPPING-> original 99
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.48;
         return true;

      // 100 NY_C31_PENDING03 (pending sát hơn)

      case 17: // MAPPING-> original 107 // LDN_SHIFT_-10 (để chống 0 trade)
         P.UseKillzones=true;
         P.KZ1s=825;
         P.KZ1e=855;
         P.KZ2s=975;
         P.KZ2e=1000;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      case 18: // MAPPING-> original 97
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.TimeStopMinutes=4;
         P.MinProgressR=0.6;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.55;
         return true;

      // 98 NY_C31_TIMESLOW (time-stop 8' @0.5R)

      case 19: // MAPPING-> original 122
         P.UseKillzones=true;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.PartialClosePct=40;
         P.BE_Activate_R=1.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.55;
         return true;

      // 123 NY_STRICT_SPREAD48_BE1R

      case 20: // MAPPING-> original 18
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.30;
         P.KZ3s=1160;
         P.KZ3e=1180;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         return true;

      // 19 CHOPPY_DAY_SAFE

      case 21: // MAPPING-> original 76 // LDN_34_SHORT_SWING
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.65;
         return true;

      case 22: // MAPPING-> original 77 // LDN_34_FAST_RETEST2
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=2;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.65;
         return true;

      case 23: // MAPPING-> original 102 // LDN_32_MICRO_RN37
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ2s=985;
         P.KZ2e=1005;
         P.UseRoundNumber=true;
         P.RNDelta=0.37;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      case 24: // MAPPING-> original 104 // LDN_34_BUFFER2_5
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=2.5;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+

      case 25: // MAPPING-> original 105 // LDN_76_SPREAD50 (siết spread)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.50;
         return true;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+

      case 26: // MAPPING-> original 125
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.37;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.5;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.60;
         return true;

      // 126 LDN_BE_1R_PARTIAL0 (full TP2, BE muộn)

      case 27: // MAPPING-> original 36
         // SPRINT-1 EXPERIMENT
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.BE_Activate_R=0.6;
         P.TP1_R=1.0;
         P.PartialClosePct=50.0;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         return true;

      case 28:
         // TRAIL-DoE: ATR14x1.5 start0.8
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         return true;

      case 29:
         // TRAIL-DoE: STEP0.25 start0.8
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.25;
         P.TrailStartRR=0.8;
         return true;

      case 30:
         // TRAIL-DoE: ATR14x1.5 + BE0.8/TP1=1.2/PC40%
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         return true;

      case 31:
         // TRAIL-DoE: STEP0.30 + BE0.8/TP1=1.2/PC40%
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=1.0;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         return true;

      case 32:
         // Sprint2 BotA: ATR14x1.5 | runner | no-partial
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.AddSpacingUSD=0.0;
         P.AddSizeFactor=0.0;
         P.MaxOpenPositions=1;
         P.CooldownSec=120;
         P.MaxSpreadUSD=0.4;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=1.0;
         P.TP1_R=9.9;
         P.PartialClosePct=0.0;
         return true;

      case 33:
         // Sprint2 BotA: ATR21x2.2 | BE1.0/TP1=1.4/PC30%
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.AddSpacingUSD=0.0;
         P.AddSizeFactor=0.0;
         P.MaxOpenPositions=1;
         P.CooldownSec=120;
         P.MaxSpreadUSD=0.4;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=2.2;
         P.TrailStartRR=1.2;
         P.BE_Activate_R=1.0;
         P.TP1_R=1.4;
         P.PartialClosePct=30.0;
         return true;

      case 34:
         // Sprint2 BotA: ATR14x1.5 | BE0.8/TP1=1.5/PC30%
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.AddSpacingUSD=0.0;
         P.AddSizeFactor=0.0;
         P.MaxOpenPositions=1;
         P.CooldownSec=120;
         P.MaxSpreadUSD=0.4;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.5;
         P.PartialClosePct=30.0;
         return true;

      case 35:
         // Sprint2 BotA: ATR14x1.6 | BE0.8/TP1=1.2/PC40%
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UsePyramid=false;
         P.MaxAdds=0;
         P.AddSpacingUSD=0.0;
         P.AddSizeFactor=0.0;
         P.MaxOpenPositions=1;
         P.CooldownSec=120;
         P.MaxSpreadUSD=0.4;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.6;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         return true;

      case 36:
         // Sprint2 BotB: STEP0.30 | StartRR=0.8 | BE0.8/TP1=1.2/PC40 | Py(2,0.35,0.6)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.35;
         P.AddSizeFactor=0.6;
         return true;

      case 37:
         // TRAIL-DoE: ATR14x1.5 start0.8
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         return true;

      case 38:
         // TRAIL-DoE: ATR14x2.0 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=2.0;
         P.TrailStartRR=1.0;
         return true;

      case 39:
         // TRAIL-DoE: ATR21x1.8 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=1.8;
         P.TrailStartRR=1.0;
         return true;

      case 40: // MAPPING-> original 228
         // Sprint2 BotB FT: STEP0.25 | StartRR=0.8 | BE1.0/PC30 | Py(2,0.30,0.6) | Cooldown=0
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=0;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.25;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=30.0;
         P.TP1_R=1.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.3;
         P.AddSizeFactor=0.6;
         return true;

      case 41: // MAPPING-> original 229
         // Sprint2 BotB FT: STEP0.35 | StartRR=0.8 | BE0.8/PC50 | Py(2,0.45,0.6)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.35;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50.0;
         P.TP1_R=1.2;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.45;
         P.AddSizeFactor=0.6;
         return true;

      case 42: // MAPPING-> original 230
         // Sprint2 BotB FT: STEP0.30 | StartRR=0.8 | BE0.8/TP1=1.2/PC30 | Py(3,0.40,0.6) | MaxSpread=0.40
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.4;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=30.0;
         P.MaxAdds=3;
         P.AddSpacingUSD=0.4;
         P.AddSizeFactor=0.6;
         return true;

      case 43: // MAPPING-> original 222
         // Sprint2 BotB FT: STEP0.30 | StartRR=0.8 | BE0.8/TP1=1.2/PC40 | Py(3,0.40,0.5) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=4;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         P.MaxAdds=3;
         P.AddSpacingUSD=0.4;
         P.AddSizeFactor=0.5;
         return true;

      case 44: // MAPPING-> original 223
         // Sprint2 BotB FT: STEP0.35 | StartRR=1.0 | BE0.8/TP1=1.2/PC30 | Py(2,0.45,0.6) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=4;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.35;
         P.TrailStartRR=1.0;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=30.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.45;
         P.AddSizeFactor=0.6;
         return true;

      case 45: // MAPPING-> original 226
         // Sprint2 BotB FT: STEP0.30 | StartRR=0.8 | BE0.8 | no-partial | Py(2,0.35,0.5)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=9.9;
         P.PartialClosePct=0.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.35;
         P.AddSizeFactor=0.5;
         return true;

      case 46: // MAPPING-> original 225
         // Sprint2 BotB FT: ATR14x1.4 | StartRR=0.8 | BE0.8/TP1=1.2/PC40 | Py(2,0.35,0.6)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.4;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.35;
         P.AddSizeFactor=0.6;
         return true;

      case 47: // MAPPING-> original 220
         // Sprint2 BotB FT: STEP0.25 | StartRR=0.8 | BE0.8/TP1=1.0/PC40 | Py(2,0.30,0.6)
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.MaxOpenPositions=3;
         P.UsePyramid=true;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.5;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.25;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.0;
         P.PartialClosePct=40.0;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.3;
         P.AddSizeFactor=0.6;
         return true;

      case 48: // MAPPING-> original 232
         // Sprint2 BotB FT (Orthogonal): STEP0.22 | StartRR=0.8 | BE0.8/TP1=1.2/PC30 | Py(2,0.32,0.6) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.22;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=30;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.32;
         P.AddSizeFactor=0.6;
         P.MaxOpenPositions=4;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.50;
         return true;

      case 49: // MAPPING-> original 234
         // Sprint2 BotB FT (Orthogonal): STEP0.22 | StartRR=0.8 | BE0.8/TP1=1.2/PC55 | Py(2,0.42,0.6) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.22;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=55;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.42;
         P.AddSizeFactor=0.6;
         P.MaxOpenPositions=4;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.50;
         return true;

      case 50: // MAPPING-> original 236
         // Sprint2 BotB FT (Orthogonal): STEP0.28 | StartRR=0.8 | BE0.8/TP1=1.2/PC55 | Py(2,0.38,0.6) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.28;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=55;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.38;
         P.AddSizeFactor=0.6;
         P.MaxOpenPositions=4;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.50;
         return true;

      case 51: // MAPPING-> original 239
         // Sprint2 BotB FT (Orthogonal): STEP0.33 | StartRR=0.8 | BE0.8/TP1=1.2/PC30 | Py(2,0.38,0.6) | MaxOpen=4
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;   // LDN window
         P.KZ3s=1160;
         P.KZ3e=1185;  // NY window
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.33;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=30;
         P.UsePyramid=true;
         P.MaxAdds=2;
         P.AddSpacingUSD=0.38;
         P.AddSizeFactor=0.6;
         P.MaxOpenPositions=4;
         P.CooldownSec=30;
         P.MaxSpreadUSD=0.50;
         return true;
         // Tiêu chí chọn: ưu tiên Net, sau đó Deals, sau đó PF, đồng thời phủ đủ 3 mức STEP (0.22 / 0.28 / 0.33) để tăng độ bền cho “daily flow”.


      
     }
   return false;
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string StripBOM(string s) { if(StringLen(s)>0 && StringGetCharacter(s,0)==0xFEFF) return StringSubstr(s,1); return s; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenCSVHandle(string fname, bool use_common, bool utf8)
  {
   int flags = FILE_READ|FILE_CSV|(use_common?FILE_COMMON:0)|(utf8?FILE_TXT:0);
   return FileOpen(fname, flags);
  }




//=== ------------------------ UTILS ---------------------------------- ===
// --- Symbol / Pip adapters ---
double SymbolPipSize(const string sym="")
{
   string s = (sym=="" ? InpSymbol : sym);
   // Metals
   if(StringFind(s,"XAU",0)>=0) return 0.01;          // 1 pip = 0.01 USD cho XAU
   // FX
   bool isJPY = (StringFind(s,"JPY",0)>=0);
   if(isJPY) return 0.01;                             // 1 pip = 0.01 cho JPY crosses
   return 0.0001;                                     // chuẩn 1 pip = 0.0001 cho hầu hết FX
}

double PipsToPrice(double pips, const string sym="")
{
   return pips * SymbolPipSize(sym);
}
double PriceToPips(double pricediff, const string sym="")
{
   double pip = SymbolPipSize(sym);
   if(pip<=0.0) return 0.0;
   return pricediff / pip;
}

// Bảng spread gợi ý theo symbol (để set MaxSpreadUSD). Trả về hi/lo (hi = ngưỡng MaxSpread đè)
bool DefaultSpreadForSymbol(string s, double &hi, double &lo)
{
   s = StringUpper(s);
   // các giá trị lấy từ list bạn đưa (≈ 3/2 pips...); hi = ngưỡng "nên chặn"
   if(s=="EURUSD"){ hi=0.00030; lo=0.00020; return true; }
   if(s=="USDJPY"){ hi=0.03000; lo=0.02000; return true; }
   if(s=="GBPUSD"){ hi=0.00040; lo=0.00025; return true; }
   if(s=="USDCHF"){ hi=0.00040; lo=0.00025; return true; }
   if(s=="USDCAD"){ hi=0.00045; lo=0.00030; return true; }
   if(s=="AUDUSD"){ hi=0.00035; lo=0.00020; return true; }
   if(s=="NZDUSD"){ hi=0.00035; lo=0.00025; return true; }
   if(s=="EURJPY"){ hi=0.04000; lo=0.02500; return true; }
   if(s=="GBPJPY"){ hi=0.06000; lo=0.04000; return true; }
   if(s=="EURGBP"){ hi=0.00030; lo=0.00020; return true; }
   if(s=="AUDJPY"){ hi=0.03500; lo=0.02500; return true; }
   if(s=="CHFJPY"){ hi=0.04000; lo=0.03000; return true; }
   if(s=="EURCHF"){ hi=0.00035; lo=0.00025; return true; }
   if(s=="AUDCAD"){ hi=0.00035; lo=0.00025; return true; }
   if(s=="CADJPY"){ hi=0.04000; lo=0.03000; return true; }
   if(s=="NZDJPY"){ hi=0.04000; lo=0.03000; return true; }
   // XAU mặc định (tuỳ broker), khuyến nghị theo doc
   if(StringFind(s,"XAU",0)>=0){ hi=0.60; lo=0.30; return true; }
   return false;
}

// Tự scale tham số theo symbol/pip (chỉ “điều chỉnh nhẹ” khi dùng Custom hoặc preset không chuyên EU)
void ApplyAutoSymbolProfile()
{
   if(!AutoSymbolProfile) return;

   double pip        = SymbolPipSize(InpSymbol);
   double point      = SymbolPoint();
   double pipPoints  = (point>0.0 ? pip/point : 0.0);

   double hi=0.0, lo=0.0;
   if(DefaultSpreadForSymbol(InpSymbol, hi, lo))
   {
      // Spread chặn theo catalogue
      P.MaxSpreadUSD = hi;
   }

   // Scale chung cho FX vs XAU (chỉ khi đang dùng Custom hoặc preset XAU)
   bool isXAU = (StringFind(InpSymbol,"XAU",0)>=0);
   bool isJPY = (StringFind(InpSymbol,"JPY",0)>=0);

   // Nếu là EURUSD: đè bộ thông số mặc định hợp lý cho test nhanh
   if(StringUpper(InpSymbol)=="EURUSD")
   {
      // các “USD” là độ lệch giá tuyệt đối; pip EURUSD = 0.0001
      P.EqTol            = 2.0 * pip;         // ≈ 2 pips để nhận equal highs/lows
      P.RNDelta          = 2.5 * pip;         // ≈ 2.5 pips quanh RN .00/.25/.50/.75
      P.SL_BufferUSD     = 7.0 * pip;         // ≈ 7 pips
      P.BOSBufferPoints  = 2.0 * pipPoints;   // ≈ 2 pips BOS buffer (vì biến này tính theo points)
      P.RetestOffsetUSD  = 2.0 * pip;         // pending offset nếu dùng pending
      P.AddSpacingUSD    = 6.0 * pip;         // khoảng cách add tiếp theo
      // Killzones giữ như XAU (theo phút server); chỉnh theo broker nếu cần
   }
   else if(!isXAU) // các cặp FX khác (generic)
   {
      // generic safe defaults
      P.EqTol            = MathMax(P.EqTol, 2.0 * pip);
      P.RNDelta          = MathMax(P.RNDelta, 3.0 * pip);
      P.SL_BufferUSD     = MathMax(P.SL_BufferUSD, 8.0 * pip);
      P.BOSBufferPoints  = MathMax(P.BOSBufferPoints, 2.0 * pipPoints);
      P.RetestOffsetUSD  = MathMax(P.RetestOffsetUSD, 2.0 * pip);
      P.AddSpacingUSD    = MathMax(P.AddSpacingUSD,   6.0 * pip);
   }
   // XAU giữ nguyên các preset gốc (đã tối ưu cho XAU)
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool UpdateRates(int need_bars=400)
  {
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(InpSymbol, InpTF, 0, need_bars, rates);
   return (copied>0);
  }
double SymbolPoint() { return SymbolInfoDouble(InpSymbol, SYMBOL_POINT); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SpreadUSD()
  {
   MqlTick t;
   if(!SymbolInfoTick(InpSymbol,t))
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
   double base = MathFloor(price);
   double arr[5] = {0.00,0.25,0.50,0.75,1.00};
   double best = base, bestd = 1e9;
   for(int i=0;i<5;i++)
     {
      double cand = base + arr[i];
      double d = MathAbs(price - cand);
      if(d<bestd)
        {
         bestd=d;
         best=cand;
        }
     }
   return best;
  }
bool NearRound(double price, double delta) { return MathAbs(price - RoundMagnet(price)) <= delta; }

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   if(P.UseRoundNumber && !NearRound(rates[bar].close, P.RNDelta))
     {
      if(Debug)
         Print("BLOCK RN @", rates[bar].close);
      return false;
     }
   if(!IsKillzone(rates[bar].time))
     {
      if(Debug)
         Print("BLOCK KZ @", TimeToString(rates[bar].time));
      return false;
     }
   double sp = SpreadUSD();
   if(sp > P.MaxSpreadUSD)
     {
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
      atr_handle = iATR(InpSymbol, InpTF, P.TrailATRPeriod);
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
      trade.PositionModify(InpSymbol, newSL, PositionGetDouble(POSITION_TP));
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
               trade.Buy(lots, InpSymbol, 0.0, sl, 0.0);
               g_lastOpenTime=TimeCurrent();
               g_lastAddPriceBuy=SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
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
                  trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
                  g_lastOpenTime=TimeCurrent();
                  g_lastAddPriceSell=SymbolInfoDouble(InpSymbol,SYMBOL_BID);
                  g_addCount=0;
                 }
               g_lastOpenTime = TimeCurrent();
               g_lastAddPriceSell = curr;
               g_addCount++;
              }
           }
        }
  }
// Position helpers
int PositionsOnSymbol()
  {
   int total=0;
   for(int i=0;i<PositionsTotal();++i)
     {
      string sym = PositionGetSymbol(i);
      if(sym==InpSymbol)
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
   SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE, tv);
   SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE, ts);
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
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN, minlot);
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX, maxlot);
   SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP, lotstep);
   lots = MathMax(minlot, MathMin(lots, maxlot));
   lots = MathFloor(lots/lotstep)*lotstep;
   return lots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(!PositionSelect(InpSymbol))
      return;
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
   if(P.BE_Activate_R>0 && reachedR >= P.BE_Activate_R)
     {
      double newSL = entry;
      if(type==POSITION_TYPE_SELL && sl<newSL)
         trade.PositionModify(InpSymbol, newSL, tp);
      if(type==POSITION_TYPE_BUY  && sl>newSL)
         trade.PositionModify(InpSymbol, newSL, tp);
     }

// Partial at TP1
   if(P.TP1_R>0 && P.PartialClosePct>0 && reachedR >= P.TP1_R)
     {
      double closeVol = vol * (P.PartialClosePct/100.0);
      double minlot, lotstep;
      SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN, minlot);
      SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP, lotstep);
      if(closeVol >= minlot)
        {
         closeVol = MathFloor(closeVol/lotstep)*lotstep;
         if(closeVol >= minlot)
            trade.PositionClosePartial(InpSymbol, closeVol);
        }
     }

// Time-stop
   if(P.TimeStopMinutes>0 && P.MinProgressR>0)
     {
      datetime nowt = TimeCurrent();
      if((nowt - opent) >= P.TimeStopMinutes*60)
        {
         if(reachedR < P.MinProgressR)
            trade.PositionClose(InpSymbol);
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
            ok = trade.SellStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
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
            ok = trade.BuyStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
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
               double entry = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
               double lots = CalcLotByRisk(MathAbs(sl - entry));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
                 {
                  if(AllowedToOpenNow())
                    {
                     trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceSell=SymbolInfoDouble(InpSymbol,SYMBOL_BID);
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
               double entry = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
               double lots = CalcLotByRisk(MathAbs(entry - sl));
               if(lots>0 && PositionsOnSymbol()<P.MaxOpenPositions && SpreadUSD()<=P.MaxSpreadUSD)
                 {
                  if(AllowedToOpenNow())
                    {
                     trade.Buy(lots, InpSymbol, 0.0, sl, 0.0);
                     g_lastOpenTime=TimeCurrent();
                     g_lastAddPriceBuy=SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
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

//=== ------------------------ INIT/TICK ------------------------------- ===
// --- REPLACE: SetupParamsFromPreset
bool SetupParamsFromPreset()
{
   UseInputsAsParams();
   bool ok = false;

   if(UsePreset)
   {
         ok = ApplyPresetBuiltIn(PresetID);
   }
   // Dù preset nào, vẫn auto chỉnh theo pip/symbol cho an toàn
   ApplyAutoSymbolProfile();

   if(Debug)
      Print("Preset applied: ok=", ok, " ID=", PresetID, " Symbol=", InpSymbol);
   return ok;
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
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
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
