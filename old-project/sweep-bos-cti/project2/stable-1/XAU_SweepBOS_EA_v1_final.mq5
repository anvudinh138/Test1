// ---- FINAL BUILD (kept 24 presets): 15, 18, 36, 60, 66, 76, 84, 86, 87, 89, 90, 91, 92, 97, 98, 102, 107, 115, 122, 123, 124, 125, 127, 128 ----
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
  }

// Built-in Presets (1..30)
// NOTE: chọn theo số -> PresetID; 0 = Custom (dùng inputs)
// name,EnableLong,EnableShort,K_swing,N_bos,LookbackInternal,M_retest,EqTol,BOSBufferPoints,
// UseKillzones,UseRoundNumber,UseVSA,L_percentile,RNDelta,KZ1s,KZ1e,KZ2s,KZ2e,KZ3s,KZ3e,KZ4s,KZ4e,
// RiskPerTradePct,SL_BufferUSD,TP1_R,TP2_R,BE_Activate_R,PartialClosePct,TimeStopMinutes,MinProgressR,
// MaxSpreadUSD,MaxOpenPositions,UsePendingRetest,RetestOffsetUSD,PendingExpirySec
bool ApplyPresetBuiltIn(int id)
{
   UseInputsAsParams();
   if(id==0) return true; // custom

   switch(id)
   {
      case 15:
               P.UseKillzones=true;
               P.UseRoundNumber=false;
               P.UseVSA=false;
               P.KZ3s=1160;
               P.KZ3e=1195;
               P.KZ4s=1250;
               P.KZ4e=1285;
               P.K_swing=55;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.25;
               P.BOSBufferPoints=1.0;
               P.RiskPerTradePct=0.5;
               P.SL_BufferUSD=0.60;
               P.TP1_R=1;
               P.TP2_R=2;
               P.BE_Activate_R=0.8;
               P.PartialClosePct=50;
               P.TimeStopMinutes=5;
               P.MinProgressR=0.5;
               P.MaxSpreadUSD=0.70;
               P.MaxOpenPositions=1;
               return true;
      
            // 16 AGG_MANY_TRADES
            

      case 18:
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
            

      case 36:
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
            

      case 60:
               P.UseKillzones=true;
               P.KZ3s=1160;
               P.KZ3e=1185;
               P.UseRoundNumber=true;
               P.RNDelta=0.30;
               P.UseVSA=false;
               P.K_swing=55;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.20;
               P.BOSBufferPoints=2.0;
               P.PartialClosePct=0;
               P.BE_Activate_R=0.8;
               P.SL_BufferUSD=0.65;
               P.MaxSpreadUSD=0.60;
               return true;
      
            // 61 NY_C31_TP2FULL  (clone 31, bỏ partial → full TP2)
            

      case 66:
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
            

      case 76: // LDN_34_SHORT_SWING
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
      
            

      case 84: // LDN_SHIFT_-15
               P.UseKillzones=true;
               P.KZ1s=820;
               P.KZ1e=850;
               P.KZ2s=970;
               P.KZ2e=995;
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
      
            

      case 86: // NY_SHIFT_-10
               P.UseKillzones=true;
               P.KZ3s=1150;
               P.KZ3e=1180;
               P.KZ4s=1245;
               P.KZ4e=1270;
               P.UseRoundNumber=true;
               P.RNDelta=0.30;
               P.UseVSA=false;
               P.K_swing=55;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.20;
               P.BOSBufferPoints=2.0;
               P.SL_BufferUSD=0.65;
               P.MaxSpreadUSD=0.60;
               return true;
      
            

      case 87: // NY_SHIFT_+10
               P.UseKillzones=true;
               P.KZ3s=1170;
               P.KZ3e=1200;
               P.KZ4s=1265;
               P.KZ4e=1290;
               P.UseRoundNumber=true;
               P.RNDelta=0.30;
               P.UseVSA=false;
               P.K_swing=55;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.20;
               P.BOSBufferPoints=2.0;
               P.SL_BufferUSD=0.65;
               P.MaxSpreadUSD=0.60;
               return true;
      
            

      case 89: // NY_C31_RN40
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
      
            

      case 90: // NY_C31_STRICT_SPREAD45
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
            

      case 91:
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
            

      case 92:
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
            

      case 97:
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
            

      case 98:
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
               P.TimeStopMinutes=8;
               P.MinProgressR=0.5;
               P.SL_BufferUSD=0.65;
               P.MaxSpreadUSD=0.60;
               return true;
      
            // 99 NY_C31_SPREAD48 (siết spread mạnh)
            

      case 102: // LDN_32_MICRO_RN37
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
      
            

      case 107: // LDN_SHIFT_-10 (để chống 0 trade)
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
      
            

      case 115:
               P.UseKillzones=true;
               P.KZ1s=835;
               P.KZ1e=900;
               P.KZ2s=980;
               P.KZ2e=1010;
               P.UseRoundNumber=true;
               P.RNDelta=0.30;
               P.UseVSA=false;
               P.K_swing=50;
               P.N_bos=6;
               P.M_retest=2;
               P.EqTol=0.22;
               P.BOSBufferPoints=1.5;
               P.SL_BufferUSD=0.55;
               P.MaxSpreadUSD=0.55;
               P.RiskPerTradePct=0.35;
               return true;
      
            // 116 LDN_SLOW_RETEST5
            

      case 122:
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
            

      case 123:
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
            

      case 124:
               P.UseKillzones=true;
               P.KZ1s=835;
               P.KZ1e=870;
               P.KZ2s=985;
               P.KZ2e=1008;
               P.UseRoundNumber=true;
               P.RNDelta=0.33;
               P.UseVSA=false;
               P.K_swing=60;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.22;
               P.BOSBufferPoints=2.0;
               P.SL_BufferUSD=0.60;
               P.MaxSpreadUSD=0.55;
               return true;
      
            // 125 LDN_RN37_BUFFER1_5
            

      case 125:
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
            

      case 127:
               P.UseKillzones=true;
               P.KZ1s=827;
               P.KZ1e=857;
               P.KZ2s=977;
               P.KZ2e=1007;
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
      
            // 128 NY_SHIFT_+8
            

      case 128:
               P.UseKillzones=true;
               P.KZ3s=1173;
               P.KZ3e=1201;
               P.KZ4s=1263;
               P.KZ4e=1288;
               P.UseRoundNumber=true;
               P.RNDelta=0.30;
               P.UseVSA=false;
               P.K_swing=55;
               P.N_bos=6;
               P.M_retest=3;
               P.EqTol=0.20;
               P.BOSBufferPoints=2.0;
               P.SL_BufferUSD=0.65;
               P.MaxSpreadUSD=0.55;
               return true;
      
            // 129 INTERNAL_WIDE (bắt BOS từ internal rộng hơn)
            
      default:
         return false;
   }
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
  }

//=== ------------------------ SIGNAL/ENTRY --------------------------- ===
void DetectBOSAndArm()
  {
// Quét sweep cách đây 2..(N_bos+1) bar, rồi kiểm tra BOS xuất hiện sau đó (về phía hiện tại)
   int maxS = MathMin(1 + N_bos, ArraySize(rates) - 2); // sweep candidate cách tối đa N_bos bar
   for(int s = 2; s <= maxS; ++s) // s = shift của bar sweep trong quá khứ gần
     {
      // SHORT: sweep lên rồi BOS xuống
      if(EnableShort && IsSweepHighBar(s) && EffortResultOK(s))
        {
         double level;
         int bosbar;
         if(HasBOSDownFrom(s, N_bos, level, bosbar))
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
      if(EnableLong && IsSweepLowBar(s) && EffortResultOK(s))
        {
         double level;
         int bosbar;
         if(HasBOSUpFrom(s, N_bos, level, bosbar))
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
         bool ok = trade.SellStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
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
         bool ok = trade.BuyStop(lots, price, InpSymbol, sl, 0.0, ORDER_TIME_SPECIFIED, exp);
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
                  trade.Sell(lots, InpSymbol, 0.0, sl, 0.0);
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
                  trade.Buy(lots, InpSymbol, 0.0, sl, 0.0);
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
bool SetupParamsFromPreset()
  {
   UseInputsAsParams();
   bool ok=false;
   if(UsePreset)
     {
      ok = ApplyPresetBuiltIn(PresetID);
     }
   else
      ok=true;
   if(Debug)
      Print("Preset applied: ok=",ok," ID=",PresetID);
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
