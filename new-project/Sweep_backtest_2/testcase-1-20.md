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
      P= (ApplyPresetBuiltIn(3), P); P.UsePendingRetest=true; P.RetestOffsetUSD=0.05; P.PendingExpirySec=60;
      return true;

    case 14: // NY_PENDING_10
      P= (ApplyPresetBuiltIn(3), P); P.UsePendingRetest=true; P.RetestOffsetUSD=0.10; P.PendingExpirySec=45; P.SL_BufferUSD=0.75;
      return true;

    case 15: // NY_WICK_ONLY (core #1 nhưng wick-only)
      P= (ApplyPresetBuiltIn(1), P); P.RetestNeedClose=false;
      return true;

    case 16: // LDN_WICK_ONLY (core #4 nhưng wick-only)
      P= (ApplyPresetBuiltIn(4), P); P.RetestNeedClose=false;
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