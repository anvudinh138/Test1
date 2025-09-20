
bool ApplyPresetBuiltIn(int id)
  {
   UseInputsAsParams();
   if(id==0) return true;
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

         case 27:
            // SPRINT-1 EXPERIMENT
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

         case 28:
            // SPRINT-1 EXPERIMENT
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
            P.TrailStartRR=1.2;
            return true;

         case 29:
            // SPRINT-1 EXPERIMENT
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
            P.TrailStartRR=0.8;
            return true;

         case 30:
            // SPRINT-1 EXPERIMENT
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
            P.TrailStepUSD=0.45;
            P.TrailStartRR=1.0;
            return true;

         case 31:
            // SPRINT-1 EXPERIMENT
            P.UseKillzones=true;
            P.KZ1s=835;
            P.KZ1e=865;
            P.KZ3s=1160;
            P.KZ3e=1185;
            P.UseRoundNumber=true;
            P.RNDelta=0.35;
            P.UseVSA=false;
            P.UsePyramid=true;
            P.MaxAdds=2;
            P.AddSpacingUSD=0.4;
            P.AddSizeFactor=0.6;
            P.MaxOpenPositions=3;
            return true;

         case 32:
            // SPRINT-1 EXPERIMENT
            P.UseKillzones=true;
            P.KZ1s=835;
            P.KZ1e=865;
            P.KZ3s=1160;
            P.KZ3e=1185;
            P.UseRoundNumber=true;
            P.RNDelta=0.35;
            P.UseVSA=false;
            P.UsePyramid=true;
            P.MaxAdds=3;
            P.AddSpacingUSD=0.35;
            P.AddSizeFactor=0.5;
            P.MaxOpenPositions=4;
            return true;

         case 33:
            // SPRINT-1 EXPERIMENT
            P.UseKillzones=true;
            P.KZ1s=835;
            P.KZ1e=865;
            P.KZ3s=1160;
            P.KZ3e=1185;
            P.UseRoundNumber=true;
            P.RNDelta=0.35;
            P.UseVSA=false;
            P.UsePyramid=true;
            P.MaxAdds=2;
            P.AddSpacingUSD=0.5;
            P.AddSizeFactor=0.7;
            P.MaxOpenPositions=3;
            P.BE_Activate_R=0.9;
            return true;

         case 34:
            // SPRINT-1 EXPERIMENT
            P.UseKillzones=true;
            P.KZ1s=835;
            P.KZ1e=865;
            P.KZ3s=1160;
            P.KZ3e=1185;
            P.UseRoundNumber=true;
            P.RNDelta=0.35;
            P.UseVSA=false;
            P.UsePyramid=true;
            P.MaxAdds=1;
            P.AddSpacingUSD=0.6;
            P.AddSizeFactor=0.8;
            P.MaxOpenPositions=2;
            P.PartialClosePct=40.0;
            return true;

         case 35:
            // SPRINT-1 EXPERIMENT
            P.UseKillzones=true;
            P.KZ1s=835;
            P.KZ1e=865;
            P.KZ3s=1160;
            P.KZ3e=1185;
            P.UseRoundNumber=true;
            P.RNDelta=0.35;
            P.UseVSA=false;
            P.BE_Activate_R=0.8;
            P.TP1_R=1.2;
            P.PartialClosePct=40.0;
            P.UseTrailing=true;
            P.TrailMode=2;
            P.TrailStepUSD=0.25;
            P.TrailStartRR=1.0;
            return true;

         case 36:
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
      case 37:
         // TRAIL-DoE: ATR14x1.5 start0.8
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         return true;

      case 38:
         // TRAIL-DoE: ATR14x2.0 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=2.0;
         P.TrailStartRR=1.0;
         return true;

      case 39:
         // TRAIL-DoE: ATR21x1.8 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=1.8;
         P.TrailStartRR=1.0;
         return true;

      case 40:
         // TRAIL-DoE: ATR21x2.2 start1.2
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=21;
         P.TrailATRMult=2.2;
         P.TrailStartRR=1.2;
         return true;

      case 41:
         // TRAIL-DoE: STEP0.25 start0.8
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.25;
         P.TrailStartRR=0.8;
         return true;

      case 42:
         // TRAIL-DoE: STEP0.30 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=1.0;
         return true;

      case 43:
         // TRAIL-DoE: STEP0.35 start1.0
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.35;
         P.TrailStartRR=1.0;
         return true;

      case 44:
         // TRAIL-DoE: STEP0.45 start1.2
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.45;
         P.TrailStartRR=1.2;
         return true;

      case 45:
         // TRAIL-DoE: ATR14x1.5 + BE0.8/TP1=1.2/PC40%
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=1;
         P.TrailATRPeriod=14;
         P.TrailATRMult=1.5;
         P.TrailStartRR=0.8;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         return true;

      case 46:
         // TRAIL-DoE: STEP0.30 + BE0.8/TP1=1.2/PC40%
         P.UseKillzones=true;
         P.KZ1s=835;  P.KZ1e=865;
         P.KZ3s=1160; P.KZ3e=1185;
         P.UseRoundNumber=true; P.RNDelta=0.35;
         P.UseVSA=false;
         P.CooldownSec=60;
         P.UseTrailing=true;
         P.TrailMode=2;
         P.TrailStepUSD=0.3;
         P.TrailStartRR=1.0;
         P.BE_Activate_R=0.8;
         P.TP1_R=1.2;
         P.PartialClosePct=40.0;
         return true;
      \1
            return false;
        }
   return false;
  }