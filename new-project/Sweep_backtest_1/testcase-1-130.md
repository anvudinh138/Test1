bool ApplyPresetBuiltIn(int id)
  {
   UseInputsAsParams();                    // default từ inputs
   if(id==0)
      return true;                  // custom

   switch(id)
     {
      // 1  BASELINE_LOOSE
      case 1:
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.K_swing=45;
         P.N_bos=7;
         P.M_retest=4;
         P.EqTol=0.30;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.80;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         P.RetestOffsetUSD=0.07;
         P.PendingExpirySec=60;
         return true;

      // 2  BASELINE_TIGHT
      case 2:
         P.UseKillzones=false;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         P.RetestOffsetUSD=0.07;
         P.PendingExpirySec=60;
         return true;

      // 3  RN_ONLY_30
      case 3:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.30;
         P.K_swing=50;
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
         P.UsePendingRetest=false;
         return true;

      // 4  RN_ONLY_40
      case 4:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.40;
         P.K_swing=50;
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
         P.MaxSpreadUSD=0.80;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 5  RN_VSA_35
      case 5:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 6  LDN_OPEN_STD
      case 6:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ2s=985;
         P.KZ2e=1005;
         P.KZ3s=0;
         P.KZ3e=0;
         P.KZ4s=0;
         P.KZ4e=0;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 7  LDN_OPEN_TIGHT
      case 7:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=180;
         P.RNDelta=0.30;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ2s=985;
         P.KZ2e=1005;
         P.K_swing=70;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.50;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 8  LDN_FADE_RN
      case 8:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.40;
         P.KZ1s=835;
         P.KZ1e=900;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=4;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.55;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 9  NY_OPEN_STD
      case 9:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=120;
         P.RNDelta=0.30;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 10 NY_OPEN_STRICT
      case 10:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=180;
         P.RNDelta=0.25;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.75;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.50;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 11 NY_RETRACE_PENDING
      case 11:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.07;
         P.PendingExpirySec=60;
         return true;

      // 12 ASIA_RANGE
      case 12:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.L_percentile=150;
         P.RNDelta=0.40;
         P.KZ1s=60;
         P.KZ1e=360;
         P.KZ3s=1320;
         P.KZ3e=1380;
         P.K_swing=50;
         P.N_bos=6;
         P.M_retest=5;
         P.EqTol=0.30;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.50;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40;
         P.TimeStopMinutes=6;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 13 ASIA_CONSERVATIVE
      case 13:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.30;
         P.KZ1s=90;
         P.KZ1e=330;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=4;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40;
         P.TimeStopMinutes=6;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.50;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 14 KZ_ONLY_LDN
      case 14:
         P.UseKillzones=true;
         P.UseRoundNumber=false;
         P.UseVSA=false;
         P.KZ1s=835;
         P.KZ1e=900;
         P.KZ2s=980;
         P.KZ2e=1010;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.55;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         return true;

      // 15 KZ_ONLY_NY
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
      case 16:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.50;
         P.K_swing=35;
         P.N_bos=8;
         P.M_retest=4;
         P.EqTol=0.35;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.55;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.90;
         P.MaxOpenPositions=1;
         return true;

      // 17 PRECISION_HIGH
      case 17:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=200;
         P.RNDelta=0.25;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.K_swing=75;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.12;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.75;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.45;
         P.MaxOpenPositions=1;
         return true;

      // 18 TREND_DAY_ANTISWEEP
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
      case 19:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.40;
         P.KZ1s=835;
         P.KZ1e=900;
         P.K_swing=60;
         P.N_bos=7;
         P.M_retest=5;
         P.EqTol=0.30;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.80;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=8;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.90;
         P.MaxOpenPositions=1;
         return true;

      // 20 HIGH_SPREAD_SAFE
      case 20:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.40;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.25;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.80;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=1.00;
         P.MaxOpenPositions=1;
         return true;

      // 21 LOW_SPREAD_SHARP
      case 21:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.30;
         P.KZ1s=835;
         P.KZ1e=865;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.40;
         P.MaxOpenPositions=1;
         return true;

      // 22 PENDING_OFFSET_05
      case 22:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.05;
         P.PendingExpirySec=60;
         return true;

      // 23 PENDING_OFFSET_10
      case 23:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.KZ1s=835;
         P.KZ1e=865;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.75;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.10;
         P.PendingExpirySec=45;
         return true;

      // 24 FAST_RETEST_ONLY
      case 24:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.40;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.65;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=4;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         return true;

      // 25 SLOW_RETEST_ONLY
      case 25:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.40;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=5;
         P.EqTol=0.28;
         P.BOSBufferPoints=1.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=8;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.70;
         P.MaxOpenPositions=1;
         return true;

      // 26 RN_MAGNET_HEAVY
      case 26:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.50;
         P.KZ3s=1160;
         P.KZ3e=1195;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=4;
         P.EqTol=0.25;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=6;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.80;
         P.MaxOpenPositions=1;
         return true;

      // 27 LDN_PULLBACK_ONLY
      case 27:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.35;
         P.KZ1s=835;
         P.KZ1e=900;
         P.KZ2s=980;
         P.KZ2e=1010;
         P.K_swing=65;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.65;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         return true;

      // 28 NY_BREAKER_ONLY
      case 28:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=150;
         P.RNDelta=0.30;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.5;
         P.SL_BufferUSD=0.70;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         return true;

      // 29 ASIA_STRICT_RN
      case 29:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=false;
         P.RNDelta=0.45;
         P.KZ1s=60;
         P.KZ1e=360;
         P.KZ3s=1320;
         P.KZ3e=1380;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=4;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.60;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=40;
         P.TimeStopMinutes=6;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.60;
         P.MaxOpenPositions=1;
         return true;

      // 30 ULTRA_TIGHT_COMBO (bonus)
      case 30:
         P.UseKillzones=true;
         P.UseRoundNumber=true;
         P.UseVSA=true;
         P.L_percentile=200;
         P.RNDelta=0.25;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.K_swing=80;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.12;
         P.BOSBufferPoints=2.0;
         P.RiskPerTradePct=0.4;
         P.SL_BufferUSD=0.75;
         P.TP1_R=1;
         P.TP2_R=2;
         P.BE_Activate_R=1.0;
         P.PartialClosePct=40;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.6;
         P.MaxSpreadUSD=0.45;
         P.MaxOpenPositions=1;
         return true;

      case 31:
         // Filters: strict KZ + RN, NO VSA
         P.UseKillzones = true;
         P.UseRoundNumber = true;
         P.UseVSA = false;
         P.RNDelta = 0.30;

         // Killzones đúng như log bạn từng chạy
         P.KZ1s=835;
         P.KZ1e=860;
         P.KZ2s=985;
         P.KZ2e=1000;
         P.KZ3s=1165;
         P.KZ3e=1185;
         P.KZ4s=1255;
         P.KZ4e=1275;

         // Core
         P.K_swing = 50;
         P.N_bos   = 6;
         P.M_retest= 3;
         P.EqTol   = 0.20;
         P.BOSBufferPoints = 2.0;

         // Risk/exec (giữ như bản cũ, hơi thoáng spread để đỡ block)
         P.SL_BufferUSD  = 0.60;
         P.MaxSpreadUSD  = 0.60;
         P.RiskPerTradePct = 0.5;
         P.TP1_R=1.0;
         P.TP2_R=2.0;
         P.BE_Activate_R=0.8;
         P.PartialClosePct=50;
         P.TimeStopMinutes=5;
         P.MinProgressR=0.5;
         P.MaxOpenPositions=1;
         P.UsePendingRetest=false;
         return true;

      // 32 LDN_OPEN_STD_LOOSE (London, bỏ VSA cho nhiều lệnh hơn)
      case 32:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ2s=985;
         P.KZ2e=1005;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.70;
         return true;

      // 33 LDN_OPEN_RN30 (RN chặt hơn, sniper)
      case 33:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ2s=985;
         P.KZ2e=1005;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.50;
         return true;

      // 34 LDN_OPEN_RN40 (RN rộng, chịu nhiễu hơn)
      case 34:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=900;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=4;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.70;
         return true;

      // 35 LDN_NY_BRIDGE (lấy nửa cuối LDN + nửa đầu NY)
      case 35:
         P.UseKillzones=true;
         P.KZ2s=985;
         P.KZ2e=1010;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 36 NY_OPEN_RN35_NOVSA (clone 31 nhưng RN 0.35)
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
      case 37:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.05;
         P.PendingExpirySec=60;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.70;
         return true;

      // 38 NY_OPEN_PENDING_10
      case 38:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.10;
         P.PendingExpirySec=45;
         P.SL_BufferUSD=0.75;
         P.MaxSpreadUSD=0.70;
         return true;

      // 39 NY_TREND_CONT (theo xu hướng, swing lớn)
      case 39:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=180;
         P.K_swing=75;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.75;
         P.MaxSpreadUSD=0.50;
         return true;

      // 40 ALLDAY_RN_ONLY
      case 40:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.70;
         return true;

      // 41 ALLDAY_VSA_STRICT
      case 41:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=200;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.50;
         return true;

      // 42 ASIA_RN30
      case 42:
         P.UseKillzones=true;
         P.KZ1s=90;
         P.KZ1e=330;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=4;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 43 ASIA_RN40
      case 43:
         P.UseKillzones=true;
         P.KZ1s=60;
         P.KZ1e=360;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=5;
         P.EqTol=0.28;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.70;
         return true;

      // 44 ASIA_PENDING
      case 44:
         P.UseKillzones=true;
         P.KZ1s=90;
         P.KZ1e=330;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.UsePendingRetest=true;
         P.RetestOffsetUSD=0.07;
         P.PendingExpirySec=60;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.70;
         return true;

      // 45 HIGH_SPREAD_AGG (broker spread dày)
      case 45:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=40;
         P.N_bos=8;
         P.M_retest=4;
         P.EqTol=0.35;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.80;
         P.MaxSpreadUSD=1.00;
         return true;

      // 46 LOW_SPREAD_SNIPER
      case 46:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=200;
         P.K_swing=70;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.45;
         return true;

      // 47 FAST_RETEST_NOVSA
      case 47:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.60;
         return true;

      // 48 SLOW_RETEST_VSA
      case 48:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=5;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.70;
         return true;

      // 49 EQTOL_STRICT (nhấn equal-high/low)
      case 49:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=180;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.12;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.75;
         P.MaxSpreadUSD=0.50;
         return true;

      // 50 EQTOL_LOOSE
      case 50:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=50;
         P.N_bos=7;
         P.M_retest=4;
         P.EqTol=0.35;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.80;
         return true;

      // 51 NY_BREAKER_STRICT
      case 51:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1190;
         P.KZ4s=1255;
         P.KZ4e=1280;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=180;
         P.K_swing=60;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.50;
         return true;

      // 52 SWEEP_EQUALITY_FOCUS (tăng trọng số equal)
      case 52:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.25;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.60;
         return true;

      // 53 BOS_BUFFER_STRICT (đòi phá mạnh)
      case 53:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=65;
         P.N_bos=5;
         P.M_retest=3;
         P.EqTol=0.18;
         P.BOSBufferPoints=3.0;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.50;
         return true;

      // 54 BOS_BUFFER_LOOSE
      case 54:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.40;
         P.UseVSA=false;
         P.K_swing=55;
         P.N_bos=7;
         P.M_retest=4;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.60;
         P.MaxSpreadUSD=0.70;
         return true;

      // 55 SWING_SHORT (đi săn cấu trúc nông)
      case 55:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=false;
         P.K_swing=40;
         P.N_bos=7;
         P.M_retest=3;
         P.EqTol=0.22;
         P.BOSBufferPoints=1.0;
         P.SL_BufferUSD=0.55;
         P.MaxSpreadUSD=0.70;
         return true;

      // 56 SWING_LONG (cấu trúc sâu)
      case 56:
         P.UseKillzones=true;
         P.KZ3s=1160;
         P.KZ3e=1185;
         P.UseRoundNumber=true;
         P.RNDelta=0.30;
         P.UseVSA=true;
         P.L_percentile=180;
         P.K_swing=80;
         P.N_bos=5;
         P.M_retest=2;
         P.EqTol=0.15;
         P.BOSBufferPoints=2.0;
         P.SL_BufferUSD=0.75;
         P.MaxSpreadUSD=0.50;
         return true;

      // 57 TIME_STOP_FAST
      case 57:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.TimeStopMinutes=4;
         P.MinProgressR=0.6;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.60;
         return true;

      // 58 TIME_STOP_SLOW
      case 58:
         P.UseKillzones=false;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=55;
         P.N_bos=6;
         P.M_retest=5;
         P.EqTol=0.25;
         P.BOSBufferPoints=1.0;
         P.TimeStopMinutes=8;
         P.MinProgressR=0.5;
         P.SL_BufferUSD=0.70;
         P.MaxSpreadUSD=0.70;
         return true;

      // 59 PARTIAL_40_BE_1R
      case 59:
         P.UseKillzones=true;
         P.KZ1s=835;
         P.KZ1e=865;
         P.UseRoundNumber=true;
         P.RNDelta=0.35;
         P.UseVSA=true;
         P.L_percentile=150;
         P.K_swing=60;
         P.N_bos=6;
         P.M_retest=3;
         P.EqTol=0.20;
         P.BOSBufferPoints=2.0;
         P.PartialClosePct=40;
         P.BE_Activate_R=1.0;
         P.SL_BufferUSD=0.65;
         P.MaxSpreadUSD=0.55;
         return true;

      // 60 PARTIAL_0_FULL (không chốt 1, full TP2)
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
     }

     // 61 NY_C31_TP2FULL  (clone 31, bỏ partial → full TP2)
case 61:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; P.PartialClosePct=0; return true;

// 62 NY_C31_RN25 (RN chặt hơn)
case 62:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.25; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 63 NY_C31_SPREAD50 (siết spread)
case 63:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;

// 64 NY_C31_RETEST2 (vào nhanh)
case 64:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=2; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// 65 NY_C31_RETEST4 (chậm hơn)
case 65:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=4; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// 66 NY_C31_EQTOL18 (equal strict)
case 66:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

// 67 NY_C31_EQTOL28 (equal loose)
case 67:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.28; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.65; return true;

// 68 NY_C31_BUFFER3 (đòi phá mạnh)
case 68:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=3.0;
   P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.55; return true;

// 69 NY_C31_PENDING05
case 69:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.UsePendingRetest=true; P.RetestOffsetUSD=0.05; P.PendingExpirySec=60;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; return true;

// 70 NY_C31_PENDING10
case 70:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.UsePendingRetest=true; P.RetestOffsetUSD=0.10; P.PendingExpirySec=45;
   P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.65; return true;

// --- London quanh UC32/34 ---
case 71: // LDN_32_TP2FULL
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.PartialClosePct=0; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; return true;

case 72: // LDN_32_RN30
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

case 73: // LDN_32_RN40
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=4; P.EqTol=0.25; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.70; return true;

case 74: // LDN_32_VSA_ON
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=true; P.L_percentile=150;
   P.K_swing=65; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

case 75: // LDN_32_SPREAD50
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.50; return true;

case 76: // LDN_34_SHORT_SWING
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.65; return true;

case 77: // LDN_34_FAST_RETEST2
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=2; P.EqTol=0.22; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.65; return true;

case 78: // LDN_34_SLOW_RETEST4
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=4; P.EqTol=0.25; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; return true;

case 79: // LDN_BRIDGE_WIDE_KZ (mở rộng để tránh 0 trade)
   P.UseKillzones=true; P.KZ2s=975; P.KZ2e=1015; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=true; P.L_percentile=150;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.20;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// --- Asia & All-day ---
case 80: // ASIA_RN30_FAST (từ 42)
   P.UseKillzones=true; P.KZ1s=90; P.KZ1e=330;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=60; P.N_bos=5; P.M_retest=2; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

case 81: // ASIA_RN40_SLOW (từ 43)
   P.UseKillzones=true; P.KZ1s=60; P.KZ1e=360;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=5; P.EqTol=0.28; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.70; return true;

case 82: // ALLDAY_RN35_LOOSE (từ 40, chỉnh để PF tăng)
   P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=50; P.N_bos=7; P.M_retest=3; P.EqTol=0.25; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 83: // ALLDAY_VSA_STRICT_SPREAD45 (từ 41)
   P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=true; P.L_percentile=200;
   P.K_swing=65; P.N_bos=5; P.M_retest=3; P.EqTol=0.15; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.45; return true;

// --- KZ shift để trị “0 trade” do lệch giờ ---
case 84: // LDN_SHIFT_-15
   P.UseKillzones=true; P.KZ1s=820; P.KZ1e=850; P.KZ2s=970; P.KZ2e=995;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 85: // LDN_SHIFT_+15
   P.UseKillzones=true; P.KZ1s=850; P.KZ1e=880; P.KZ2s=1000; P.KZ2e=1020;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 86: // NY_SHIFT_-10
   P.UseKillzones=true; P.KZ3s=1150; P.KZ3e=1180; P.KZ4s=1245; P.KZ4e=1270;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.60; return true;

case 87: // NY_SHIFT_+10
   P.UseKillzones=true; P.KZ3s=1170; P.KZ3e=1200; P.KZ4s=1265; P.KZ4e=1290;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.60; return true;

// --- NY biến thể quanh 31 (bật VSA / RN40 / spread siết) ---
case 88: // NY_C31_VSA_ON
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=true; P.L_percentile=150;
   P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

case 89: // NY_C31_RN40
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 90: // NY_C31_STRICT_SPREAD45
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=60; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.45; return true;

   return false;
  }

  // 91 NY_C31_MICRO_RN28  (vi tinh chỉnh quanh 31/62/90)
case 91:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.28; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 92 NY_C31_MICRO_RN32
case 92:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.32; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 93 NY_C31_BE_1R (dời BE muộn để giữ vị thế)
case 93:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.BE_Activate_R=1.0; P.PartialClosePct=50; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 94 NY_C31_PARTIAL0_BE1R (full TP2 + BE 1R)
case 94:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.PartialClosePct=0; P.BE_Activate_R=1.0; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 95 NY_C31_BUFFER_1_5 (BOS buffer 1.5pt)
case 95:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=1.5;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 96 NY_C31_BUFFER_2_5 (BOS buffer 2.5pt)
case 96:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.5;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

// 97 NY_C31_TIMEFAST (time-stop 4' @0.6R)
case 97:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3;
   P.TimeStopMinutes=4; P.MinProgressR=0.6; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 98 NY_C31_TIMESLOW (time-stop 8' @0.5R)
case 98:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=4;
   P.TimeStopMinutes=8; P.MinProgressR=0.5; P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.60; return true;

// 99 NY_C31_SPREAD48 (siết spread mạnh)
case 99:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.48; return true;

// 100 NY_C31_PENDING03 (pending sát hơn)
case 100:
   P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3;
   P.UsePendingRetest=true; P.RetestOffsetUSD=0.03; P.PendingExpirySec=60;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// --- London fine-tune quanh 32/34/76/77/78 ---
case 101: // LDN_32_MICRO_RN33
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.33; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

case 102: // LDN_32_MICRO_RN37
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005;
   P.UseRoundNumber=true; P.RNDelta=0.37; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 103: // LDN_34_BUFFER1_5
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.5;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.60; return true;

case 104: // LDN_34_BUFFER2_5
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.5;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 105: // LDN_76_SPREAD50 (siết spread)
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.50; return true;

case 106: // LDN_78_SLOWER (retest 5)
   P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
   P.UseRoundNumber=true; P.RNDelta=0.40; P.UseVSA=false;
   P.K_swing=55; P.N_bos=6; P.M_retest=5; P.EqTol=0.25; P.BOSBufferPoints=1.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; return true;

case 107: // LDN_SHIFT_-10 (để chống 0 trade)
   P.UseKillzones=true; P.KZ1s=825; P.KZ1e=855; P.KZ2s=975; P.KZ2e=1000;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

case 108: // LDN_SHIFT_+10
   P.UseKillzones=true; P.KZ1s=845; P.KZ1e=875; P.KZ2s=995; P.KZ2e=1015;
   P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// --- All-day / Asia tweak các case PF~0.8–1.0 để cứu ---
case 109: // ALLDAY_RN35_SPREAD55 (từ 82)
   P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
   P.K_swing=52; P.N_bos=6; P.M_retest=3; P.EqTol=0.24; P.BOSBufferPoints=1.2;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

case 110: // ASIA_RN30_RETEST3 (từ 80)
   P.UseKillzones=true; P.KZ1s=90; P.KZ1e=330;
   P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
   P.K_swing=60; P.N_bos=5; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
   P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

   // 111 DUAL_SESS_WIDE  (LDN + NY mở rộng)
case 111:
  P.UseKillzones=true; P.KZ1s=825; P.KZ1e=900; P.KZ2s=975; P.KZ2e=1015; P.KZ3s=1155; P.KZ3e=1195; P.KZ4s=1245; P.KZ4e=1290;
  P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.24; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.35; return true;

// 112 DUAL_SESS_RN_OFF  (tắt RN để tăng kèo)
case 112:
  P.UseKillzones=true; P.KZ1s=825; P.KZ1e=900; P.KZ2s=975; P.KZ2e=1015; P.KZ3s=1155; P.KZ3e=1195; P.KZ4s=1245; P.KZ4e=1290;
  P.UseRoundNumber=false; P.UseVSA=false;
  P.K_swing=50; P.N_bos=7; P.M_retest=4; P.EqTol=0.26; P.BOSBufferPoints=1.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.70; P.RiskPerTradePct=0.35; return true;

// 113 LDN_NY_RN25  (RN chặt nhưng vẫn 2 phiên)
case 113:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ2s=985; P.KZ2e=1005; P.KZ3s=1160; P.KZ3e=1190; P.KZ4s=1255; P.KZ4e=1285;
  P.UseRoundNumber=true; P.RNDelta=0.25; P.UseVSA=false;
  P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; P.RiskPerTradePct=0.35; return true;

// 114 ALLDAY_LOOSE  (không KZ, bắt cả ngày – kiểm soát bằng spread)
case 114:
  P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=45; P.N_bos=7; P.M_retest=4; P.EqTol=0.28; P.BOSBufferPoints=1.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; P.RiskPerTradePct=0.30; return true;

// 115 LDN_FAST_RETEST2
case 115:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900; P.KZ2s=980; P.KZ2e=1010;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=50; P.N_bos=6; P.M_retest=2; P.EqTol=0.22; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.55; P.RiskPerTradePct=0.35; return true;

// 116 LDN_SLOW_RETEST5
case 116:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900; P.KZ2s=980; P.KZ2e=1010;
  P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=55; P.N_bos=7; P.M_retest=5; P.EqTol=0.26; P.BOSBufferPoints=1.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.35; return true;

// 117 NY_PENDING05_WIDE (pending để tăng fill)
case 117:
  P.UseKillzones=true; P.KZ3s=1155; P.KZ3e=1195; P.KZ4s=1245; P.KZ4e=1290;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
  P.UsePendingRetest=true; P.RetestOffsetUSD=0.05; P.PendingExpirySec=60;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.35; return true;

// 118 NY_PENDING03_WIDE
case 118:
  P.UseKillzones=true; P.KZ3s=1155; P.KZ3e=1195; P.KZ4s=1245; P.KZ4e=1290;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.24; P.BOSBufferPoints=1.5;
  P.UsePendingRetest=true; P.RetestOffsetUSD=0.03; P.PendingExpirySec=60;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.30; return true;

// 119 NY_NOKZ_SPREAD55 (không KZ nhưng siết spread)
case 119:
  P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; P.RiskPerTradePct=0.30; return true;

// 120 EASY_EQUAL_BUFFER1 (nới equal + buffer nhỏ để tăng trigger)
case 120:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=865; P.KZ3s=1160; P.KZ3e=1185;
  P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=50; P.N_bos=7; P.M_retest=4; P.EqTol=0.30; P.BOSBufferPoints=1.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.30; return true;

// 121 NY_RN28_BUFFER2 (vi mô quanh 91)
case 121:
  P.UseKillzones=true; P.KZ3s=1160; P.KZ3e=1188; P.KZ4s=1253; P.KZ4e=1278;
  P.UseRoundNumber=true; P.RNDelta=0.28; P.UseVSA=false;
  P.K_swing=50; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 122 NY_BE_1R_PARTIAL40
case 122:
  P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=55; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
  P.PartialClosePct=40; P.BE_Activate_R=1.0; P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

// 123 NY_STRICT_SPREAD48_BE1R
case 123:
  P.UseKillzones=true; P.KZ3s=1165; P.KZ3e=1185; P.KZ4s=1255; P.KZ4e=1275;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=60; P.N_bos=5; P.M_retest=3; P.EqTol=0.18; P.BOSBufferPoints=2.0;
  P.SL_BufferUSD=0.70; P.MaxSpreadUSD=0.48; P.BE_Activate_R=1.0; return true;

// 124 LDN_RN33_BUFFER2 (vi mô quanh 101/102)
case 124:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=870; P.KZ2s=985; P.KZ2e=1008;
  P.UseRoundNumber=true; P.RNDelta=0.33; P.UseVSA=false;
  P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 125 LDN_RN37_BUFFER1_5
case 125:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
  P.UseRoundNumber=true; P.RNDelta=0.37; P.UseVSA=false;
  P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.60; return true;

// 126 LDN_BE_1R_PARTIAL0 (full TP2, BE muộn)
case 126:
  P.UseKillzones=true; P.KZ1s=835; P.KZ1e=900;
  P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
  P.PartialClosePct=0; P.BE_Activate_R=1.0; P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.55; return true;

// 127 LDN_SHIFT_-8  (chống lệch giờ – nhẹ hơn 84/85)
case 127:
  P.UseKillzones=true; P.KZ1s=827; P.KZ1e=857; P.KZ2s=977; P.KZ2e=1007;
  P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=60; P.N_bos=6; P.M_retest=3; P.EqTol=0.22; P.BOSBufferPoints=2.0;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// 128 NY_SHIFT_+8
case 128:
  P.UseKillzones=true; P.KZ3s=1173; P.KZ3e=1201; P.KZ4s=1263; P.KZ4e=1288;
  P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.K_swing=55; P.N_bos=6; P.M_retest=3; P.EqTol=0.20; P.BOSBufferPoints=2.0;
  P.SL_BufferUSD=0.65; P.MaxSpreadUSD=0.55; return true;

// 129 INTERNAL_WIDE (bắt BOS từ internal rộng hơn)
case 129:
  P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.30; P.UseVSA=false;
  P.LookbackInternal=16; P.K_swing=55; P.N_bos=7; P.M_retest=4; P.EqTol=0.26; P.BOSBufferPoints=1.5;
  P.SL_BufferUSD=0.60; P.MaxSpreadUSD=0.60; return true;

// 130 SWING_SHORT_AGG (swing nông để nhiều sweep)
case 130:
  P.UseKillzones=false; P.UseRoundNumber=true; P.RNDelta=0.35; P.UseVSA=false;
  P.K_swing=40; P.N_bos=7; P.M_retest=3; P.EqTol=0.26; P.BOSBufferPoints=1.0;
  P.SL_BufferUSD=0.55; P.MaxSpreadUSD=0.65; P.RiskPerTradePct=0.30; return true;

