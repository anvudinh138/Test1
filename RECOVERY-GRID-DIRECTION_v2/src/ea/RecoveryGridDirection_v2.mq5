#property strict

#include <Trade/Trade.mqh>

#include <RECOVERY-GRID-DIRECTION_v2/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Params.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/Logger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/SpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderValidator.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/OrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/PortfolioLedger.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/RescueEngine.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/GridBasket.mqh>
#include <RECOVERY-GRID-DIRECTION_v2/core/LifecycleController.mqh>

//----------------------------- ENUMS --------------------------------
enum SPACING_MODE
{
   SPACING_ATR  = 0,
   SPACING_HYBRID = 1
};

enum GRID_REFILL_MODE
{
   REFILL_STATIC = 0,
   REFILL_LIVE   = 1
};

//------------------------- NHÓM 1: SPACING --------------------------
input group "1) Spacing / Khoảng cách lưới";
input SPACING_MODE  spacing_mode      = SPACING_HYBRID;   // Cách tính bước lưới
input double        spacing_atr_mult  = 1.0;              // Hệ số ATR nếu ATR/HYBRID
input int           min_spacing_pips  = 10;               // Sàn spacing cho HYBRID

//--------------------- NHÓM 2: GRID & REFILL ------------------------
input group "2) Grid & Refill / Xây lưới & nạp lệnh";
input int           grid_levels           = 10;           // Mức lưới mỗi phía (kể cả seed)
input int           grid_warm_levels      = 2;            // Số limit khởi động sau seed
input int           grid_refill_threshold = 3;            // Khi lệnh chờ ≤ ngưỡng thì nạp
input int           grid_refill_batch     = 2;            // Số lệnh thêm mỗi lần nạp
input GRID_REFILL_MODE grid_refill_mode   = REFILL_LIVE;  // STATIC: spacing cũ, LIVE: ATR
input int           grid_max_pendings     = 12;           // Trần lệnh chờ/basket

//---------------------- NHÓM 3: SIZING / LOT ------------------------
input group "3) Sizing / Khối lượng";
input double        lot_base          = 0.10;             // Lot seed
input double        lot_scale         = 1.00;             // Hệ số nhân theo độ sâu (1.0 = giữ nguyên)

//------------------- NHÓM 4: TARGET & TSL (HEDGE) -------------------
input group "4) Group TP & TSL (Hedge)";
input double        target_cycle_usd  = 15.0;             // BE + δ khi đóng rổ đang âm
input bool          tsl_enabled       = true;             // Bật trailing cho hedge
input int           tsl_start_points  = 300;              // Kích hoạt trailing sau X points
input int           tsl_step_points   = 100;              // Bước kéo SL sau khi kích hoạt

//---------------- NHÓM 5: RESCUE / HEDGE (NHIỀU LỚP) ---------------
input group "5) Rescue / Hedge nhiều lớp";
input string        InpRecoverySteps   = "1.0,2.0,3.0";    // Danh sách bội số ATR (CSV)
input double        recovery_lot       = 0.10;             // Lot cho mỗi lớp rescue
input double        dd_open_usd        = 60.0;             // Mở hedge nếu DD USD vượt ngưỡng
input double        offset_ratio       = 0.75;             // Breach = ratio * spacing mở hedge
input bool          rescue_trend_filter= true;             // Yêu cầu trend filter đồng ý

//---------------------- NHÓM 6: TREND FILTER ------------------------
input group "6) Trend filter (ATR + Slope/EMA)";
input double        trend_k_atr           = 2.0;           // Giá phải kéo ≥ k*ATR để coi “mạnh”
input double        trend_slope_threshold = 0.0005;        // Ngưỡng độ dốc EMA
input int           trend_slope_lookback  = 20;            // Số nến đo slope
input int           trend_ema_period      = 89;            // EMA dùng cho slope/lockdown
input ENUM_TIMEFRAMES trend_ema_timeframe = PERIOD_H1;     // Khung thời gian EMA

//------------------- NHÓM 7: HEDGE RESEED RETEST --------------------
input group "7) Retest gate cho reseed hedge";
input bool          hedge_retest_enable   = true;          // Bật cơ chế chờ-retest
input int           hedge_wait_bars       = 10;            // Chờ tối thiểu X nến sau khi đóng hedge
input double        hedge_wait_atr        = 1.0;           // Trend tiếp diễn thêm ≥ X*ATR
input double        hedge_retest_atr      = 0.8;           // Vùng pullback tính theo ATR
input double        hedge_retest_slope    = 0.0002;        // Momentum phải nguội dưới ngưỡng này
input int           hedge_retest_confirm_bars = 2;         // Số nến ngược hướng để xác nhận

//-------------------- NHÓM 8: TREND LOCKDOWN ------------------------
input group "8) Trend lockdown (khóa lưới khi quá gắt)";
input double        lock_min_lots      = 0.30;             // Chỉ khóa nếu volume loser ≥ ngưỡng
input int           lock_min_bars      = 6;                // Tối thiểu phải giữ khóa X nến
input int           lock_max_bars      = 48;               // Failsafe tự thoát khóa sau X nến
input double        lock_cancel_mult   = 2.5;              // Xóa pending quá xa = mult * spacing
input double        lock_hyst_atr      = 0.5;              // Hysteresis ATR tránh bật/tắt liên tục
input double        lock_hyst_slope    = 0.00015;          // Hysteresis slope
input double        lock_hedge_close_pct= 0.50;            // Vào lockdown: chốt bớt % hedge tức thì

//------------------ NHÓM 9: TP TUNING KHI Ở XA ----------------------
input group "9) TP tuning khi TP quá xa giá";
input double        tp_distance_z_atr  = 2.5;              // Nếu TP cách giá > Z*ATR thì thắt TP
input double        tp_weaken_usd      = 5.0;              // Giảm mục tiêu USD để kéo TP lại gần

//------------------- NHÓM 10: RỦI RO & VÒNG ĐỜI ---------------------
input group "10) Risk & lifecycle";
input double        session_trailing_dd_usd = 75.0;        // Trailing drawdown toàn phiên
input double        exposure_cap_lots       = 1.50;        // Trần tổng lot (hai rổ)
input int           max_cycles_per_side     = 3;           // Tối đa lần rescue mỗi chân
input double        session_sl_usd          = 150.0;       // Hard stop equity/phiên
input int           cooldown_bars           = 5;           // Khoảng cách giữa 2 lần rescue

//------------------ NHÓM 11: PHIÊN & ĐIỀU KIỆN THỊ TRƯỜNG ----------
input group "11) Trading session & market guards";
input double        max_spread_pips     = 2.0;             // Không vào lệnh nếu spread > ngưỡng
input bool          trading_time_filter_enabled = false;   // Bật lọc giờ giao dịch
input int           cutoff_hour         = 22;              // Giờ cutoff (broker time)
input int           cutoff_minute       = 30;              // Phút cutoff
input bool          friday_flatten_enabled = true;         // Ép đóng thứ Sáu
input int           friday_flatten_hour   = 22;            // Hạn chót giờ
input int           friday_flatten_minute = 45;            // Hạn chót phút

//-------------------- NHÓM 12: THỰC THI & PHÍ ----------------------
input group "12) Execution & Costs";
input int           slippage_pips       = 1;               // Cho phép trượt giá
input double        commission_per_lot  = 7.0;             // Phí/lot để tính Group TP

//------------------- NHÓM 13: LOGGING & EXPORT --------------------
input group "13) Logging & Export";
input string        cycle_csv_path     = "";              // Đường dẫn CSV (rỗng = tắt)

//--- Globals
SParams              g_params;
CLogger             *g_logger        = NULL;
CSpacingEngine      *g_spacing       = NULL;
COrderValidator     *g_validator     = NULL;
COrderExecutor      *g_executor      = NULL;
CPortfolioLedger    *g_ledger        = NULL;
CRescueEngine       *g_rescue        = NULL;
CLifecycleController*g_controller    = NULL;

string TrimAll(const string value)
  {
   string tmp=value;
   StringTrimLeft(tmp);
   StringTrimRight(tmp);
   return tmp;
  }

int ParseRecoveryStepsAtr(const string csv,double &buffer[])
  {
   ArrayResize(buffer,0);
   if(StringLen(csv)==0)
      return 0;
   string parts[];
   int count=StringSplit(csv,',',parts);
   if(count<=0)
      return 0;
   ArrayResize(buffer,count);
   int actual=0;
   for(int i=0;i<count;i++)
     {
      string trimmed=TrimAll(parts[i]);
      if(StringLen(trimmed)==0)
         continue;
      double value=StringToDouble(trimmed);
      if(value<=0.0)
         continue;
      buffer[actual]=value;
      actual++;
     }
   ArrayResize(buffer,actual);
   return actual;
  }

void BuildParams()
  {
   g_params.spacing_mode       =(ESpacingMode)InpSpacingMode;
   g_params.spacing_atr_mult   =InpSpacingAtrMult;
   g_params.min_spacing_pips   =InpMinSpacingPips;
   g_params.atr_period         =InpAtrPeriod;
   g_params.atr_timeframe      =InpAtrTimeframe;

   g_params.grid_levels        =InpGridLevels;
   g_params.grid_warm_levels   =InpGridWarmLevels;
   g_params.grid_refill_threshold =InpGridRefillThreshold;
   g_params.grid_refill_batch  =InpGridRefillBatch;
   g_params.grid_refill_mode   =(EGridRefillMode)InpGridRefillMode;
   g_params.grid_max_pendings  =InpGridMaxPendings;
   g_params.lot_base           =InpLotBase;
   g_params.lot_scale          =InpLotScale;
   g_params.target_cycle_usd   =InpTargetCycleUSD;

   g_params.tsl_enabled        =InpTSLEnabled;
   g_params.tsl_start_points   =InpTSLStartPoints;
   g_params.tsl_step_points    =InpTSLStepPoints;

   ParseRecoveryStepsAtr(InpRecoverySteps,g_params.recovery_steps_atr);
   g_params.recovery_lot       =InpRecoveryLot;
   g_params.dd_open_usd        =InpDDOpenUSD;
   g_params.offset_ratio       =InpOffsetRatio;
   g_params.exposure_cap_lots  =InpExposureCapLots;
   g_params.max_cycles_per_side=InpMaxCyclesPerSide;
   g_params.session_sl_usd     =InpSessionSL_USD;
   g_params.cooldown_bars      =InpCooldownBars;
   g_params.session_trailing_dd_usd = InpSessionTrailingDD_USD;
   g_params.rescue_trend_filter = InpRescueTrendFilter;
   g_params.trend_k_atr        = InpTrendKAtr;
   g_params.trend_slope_threshold = InpTrendSlopeThreshold;
   g_params.trend_slope_lookback = InpTrendSlopeLookback;
   g_params.trend_ema_period   = InpTrendEmaPeriod;
   g_params.trend_ema_timeframe= InpTrendEmaTimeframe;
   g_params.hedge_retest_enable = InpHedgeRetestEnable;
   g_params.hedge_wait_bars     = InpHedgeWaitBars;
   g_params.hedge_wait_atr      = InpHedgeWaitAtr;
   g_params.hedge_retest_atr    = InpHedgeRetestAtr;
   g_params.hedge_retest_slope  = InpHedgeRetestSlope;
   g_params.hedge_retest_confirm_bars = InpHedgeRetestConfirmBars;
   g_params.lock_min_lots      = InpLockMinLots;
   g_params.lock_min_bars      = InpLockMinBars;
   g_params.lock_max_bars      = InpLockMaxBars;
   g_params.lock_cancel_mult   = InpLockCancelMultiplier;
   g_params.lock_hyst_atr      = InpLockHysteresisAtr;
   g_params.lock_hyst_slope    = InpLockHysteresisSlope;
   g_params.lock_hedge_close_pct = InpLockHedgeClosePct;
   g_params.tp_distance_z_atr  = InpTPDistance_Z_ATR;
   g_params.tp_weaken_usd      = InpTPWeakenUsd;
   g_params.trading_time_filter_enabled = InpTradingCutoffEnabled;
   g_params.max_spread_pips     = InpMaxSpreadPips;
   g_params.cutoff_hour        = InpCutoffHour;
   g_params.cutoff_minute      = InpCutoffMinute;
   g_params.friday_flatten_enabled = InpFridayFlattenEnabled;
   g_params.friday_flatten_hour= InpFridayFlattenHour;
   g_params.friday_flatten_minute= InpFridayFlattenMinute;

   g_params.slippage_pips      =InpSlippagePips;
   g_params.order_cooldown_sec =InpOrderCooldownSec;
   g_params.respect_stops_level=InpRespectStops;
   g_params.commission_per_lot =InpCommissionPerLot;

   g_params.magic              =InpMagic;
   g_params.cycle_csv_path     =cycle_csv_path;
  }

int OnInit()
  {
   BuildParams();

   g_logger   = new CLogger(InpStatusInterval,InpLogEvents);
   g_spacing  = new CSpacingEngine(_Symbol,g_params.spacing_mode,g_params.atr_period,g_params.atr_timeframe,g_params.spacing_atr_mult,g_params.min_spacing_pips);
   g_validator= new COrderValidator(_Symbol,g_params.respect_stops_level);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   int pip_points=(digits==3 || digits==5)?10:1;
   int slippage_points=(int)MathMax(1,MathRound(g_params.slippage_pips*pip_points));
   g_executor = new COrderExecutor(_Symbol,g_validator,slippage_points,g_params.order_cooldown_sec);
   if(g_executor!=NULL)
      g_executor.SetMagic(g_params.magic);
   g_ledger   = new CPortfolioLedger(g_params.exposure_cap_lots,g_params.session_sl_usd);
   g_rescue   = new CRescueEngine(_Symbol,g_params,g_logger);
   g_controller = new CLifecycleController(_Symbol,g_params,g_spacing,g_executor,g_rescue,g_ledger,g_logger,g_params.magic);

   if(g_controller==NULL || !g_controller.Init())
     {
      if(g_logger!=NULL)
         g_logger.Event("[RGDv2]","Controller init failed");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   if(g_controller!=NULL)
      g_controller.Update();
  }

void OnDeinit(const int reason)
  {
   if(g_controller!=NULL){ g_controller.Shutdown(); delete g_controller; g_controller=NULL; }
   if(g_rescue!=NULL){ delete g_rescue; g_rescue=NULL; }
   if(g_ledger!=NULL){ delete g_ledger; g_ledger=NULL; }
   if(g_executor!=NULL){ delete g_executor; g_executor=NULL; }
   if(g_validator!=NULL){ delete g_validator; g_validator=NULL; }
   if(g_spacing!=NULL){ delete g_spacing; g_spacing=NULL; }
   if(g_logger!=NULL){ delete g_logger; g_logger=NULL; }
  }
