//+------------------------------------------------------------------+
//|                                       FVG_Fibonacci_Scaler.mq5   |
//|                                         (Upgraded Feature Set)   |
//|                                  Copyright 2024, Gemini Project |
//|                        https://github.com/GoogleCloudPlatform   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Project"
#property link      "https://github.com/GoogleCloudPlatform"
#property version   "1.30"
#property description "FVG + Fibonacci with 50% buffer, spread/session filters, and TP1 BE option"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

//--- Class để lưu thông tin về một FVG
class FairValueGap : public CObject
{
public:
   double high_price;
   double low_price;
   int    bar_index;
          FairValueGap() { bar_index = -1; high_price = 0; low_price = 0; };
};

//--- Cấu trúc để lưu thông tin về một Swing
struct SwingStructure
{
   double high_price;
   int    high_bar_index;
   double low_price;
   int    low_bar_index;
   bool   is_bullish_swing;
};

//--- Cấu trúc để lưu thông tin thống kê
struct TradeStats
{
   int total_trades;
   int win_trades;
};

// Dùng cho Plan C khi xếp hạng range theo mật độ FVG
struct RangeScore
{
   int id;
   int count;
};

//--- Enum cho chế độ Stop Loss
enum ENUM_SL_MODE
{
   SL_AT_SWING,      // SL tại đỉnh/đáy Swing + padding (an toàn)
   SL_FROM_ENTRY_ATR // SL theo ATR từ điểm vào lệnh
};

//--- Hậu TP1
enum ENUM_AFTER_TP1_MODE
{
   AFTER_TP1_TRAIL_ATR = 0,   // Trailing như bình thường (dùng in_trailing_stop_atr_factor)
   AFTER_TP1_MOVE_BE    = 1,   // Dời SL về hòa vốn (BE)
   AFTER_TP1_TRAIL_SLOW = 2    // Trailing chậm hơn (dùng in_trailing_stop_atr_factor_after_tp1)
};

//--- Các tham số đầu vào cho EA
input group           "QUẢN LÝ GIAO DỊCH"
input double          in_fixed_lot = 0.02;
input ulong           in_magic_number = 112233;
input int             in_slippage = 3;

input group           "THIẾT LẬP TÍN HIỆU"
input ENUM_TIMEFRAMES in_anchor_tf = PERIOD_M15;           // Khung thời gian phân tích (Anchor TF)
input int             in_swing_bars = 80;
input double          in_fvg_min_atr_factor = 0.3;
input int             in_atr_period = 14;

input group           "QUẢN LÝ RỦI RO"
input ENUM_SL_MODE    in_sl_mode = SL_AT_SWING;             // Chế độ đặt Stop Loss
input double          in_sl_atr_factor_from_entry = 2.0;    // Hệ số ATR cho SL (chế độ SL_FROM_ENTRY_ATR)
input double          in_sl_padding_atr_factor = 0.2;       // Đệm SL (chế độ SL_AT_SWING)
input double          in_trailing_stop_atr_factor = 1.5;

input group           "BỘ LỌC GIAO DỊCH"
input bool            in_enable_spread_filter = true;       // Bật lọc Spread
input int             in_max_spread_points = 30;            // Tối đa spread (points)
input bool            in_enable_session_filter = false;     // Bật lọc phiên giao dịch
input int             in_session_start_hour = 7;            // Giờ bắt đầu phiên (server time)
input int             in_session_end_hour   = 22;           // Giờ kết thúc phiên (server time)

input group           "BUFFER 50% DISCOUNT/PREMIUM"
input bool            in_enable_fifty_buffer = true;        // Bật buffer quanh mức 50%
input double          in_fifty_buffer = 0.02;               // Tỷ lệ (0..0.5) của range để tránh vùng sát 50%

input group           "HẬU TP1"
input ENUM_AFTER_TP1_MODE in_after_tp1_mode = AFTER_TP1_TRAIL_ATR;  // Cách quản lý sau TP1
input double          in_trailing_stop_atr_factor_after_tp1 = 2.8;   // Hệ số ATR trailing chậm
input double          in_be_offset_points = 0;                        // Offset (points) khi dời SL về BE

input group           "CHỌN SYMBOL (TEST/THỰC THI)"
enum ENUM_SYMBOL_PRESET {
  PRESET_USE_CHART = 0,
  PRESET_CUSTOM = 1,
  // Majors + Metals
  PRESET_XAUUSD = 2,
  PRESET_XAGUSD = 3,
  PRESET_EURUSD = 4,
  PRESET_GBPUSD = 5,
  PRESET_AUDUSD = 6,
  PRESET_NZDUSD = 7,
  PRESET_USDJPY = 8,
  PRESET_USDCHF = 9,
  PRESET_USDCAD = 10,
  // Crosses
  PRESET_EURJPY = 11,
  PRESET_EURGBP = 12,
  PRESET_EURAUD = 13,
  PRESET_GBPJPY = 14,
  PRESET_AUDJPY = 15,
  PRESET_CADJPY = 16,
  PRESET_CHFJPY = 17,
  PRESET_NZDJPY = 18,
  // Indices (names vary by broker)
  PRESET_US30 = 19,
  PRESET_SPX500 = 20,
  PRESET_NAS100 = 21,
  PRESET_US2000 = 22,
  PRESET_JP225 = 23,
  PRESET_HK50 = 24,
  PRESET_GER40 = 25,
  PRESET_UK100 = 26,
  // Crypto (names vary widely)
  PRESET_BTCUSD = 27,
  PRESET_ETHUSD = 28,
  PRESET_LTCUSD = 29,
  PRESET_SOLUSD = 30,
  PRESET_XRPUSD = 31,
  PRESET_ADAUSD = 32,
  PRESET_DOGEUSD = 33
};
input ENUM_SYMBOL_PRESET in_symbol_preset = PRESET_USE_CHART;
input string         in_custom_symbol = "";  // nếu preset = CUSTOM, nhập tên symbol tại đây

input group          "PLAN C (PHÂN TÍCH ĐỘNG)"
input bool           in_enable_plan_c = false;  // Bật Plan C: tự chọn range/entry động

input group          "PLAN D (ADAPTIVE REGIME)"
input bool           in_enable_plan_d = false;  // Bật Plan D: thích ứng theo biến động
input double         in_plan_d_low_vol_ratio = 0.12;   // ATR/swing_range dưới ngưỡng => LowVol
input double         in_plan_d_high_vol_ratio = 0.25;  // ATR/swing_range trên ngưỡng => HighVol
input double         in_plan_d_buffer_lowvol = 0.02;   // Buffer 50% khi LowVol
input double         in_plan_d_buffer_highvol = 0.06;  // Buffer 50% khi HighVol

//--- Biến toàn cục
CTrade         trade;
int            h_atr_anchor; // Handle ATR cho Anchor TF
int            h_atr_chart;  // Handle ATR cho Chart TF
string         g_symbol = _Symbol; // Symbol đang sử dụng (preset/custom)

// Các biến trạng thái để quản lý logic
SwingStructure last_processed_swing;
double         pending_e2_price = 0;
string         pending_e2_comment = "";
bool           is_tp1_hit = false;
ulong          active_setup_ticket_e1 = 0;


//+------------------------------------------------------------------+
//| Utilities: Filters                                               |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   if(!in_enable_spread_filter) return true;
   long spread_points = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD); // points
   return (spread_points <= in_max_spread_points);
}

bool IsTradingSession()
{
   if(!in_enable_session_filter) return true;
   datetime now = TimeCurrent();
   MqlDateTime st; TimeToStruct(now, st); int hour = st.hour;
   if(in_session_start_hour == in_session_end_hour) return true; // no limit
   if(in_session_start_hour < in_session_end_hour)
      return (hour >= in_session_start_hour && hour < in_session_end_hour);
   // qua đêm: ví dụ 22 -> 5
   return (hour >= in_session_start_hour || hour < in_session_end_hour);
}

//+------------------------------------------------------------------+
//| Helpers: Effective 50% buffer (Plan D)                           |
//+------------------------------------------------------------------+
double EffectiveFiftyBuffer(double swing_range, double atr_value)
{
   if(swing_range <= 0.0) return in_fifty_buffer;
   double ratio = atr_value / swing_range;
   if(ratio >= in_plan_d_high_vol_ratio)
      return MathMax(in_fifty_buffer, in_plan_d_buffer_highvol);
   if(ratio <= in_plan_d_low_vol_ratio)
      return MathMin(in_fifty_buffer, in_plan_d_buffer_lowvol);
   return in_fifty_buffer;
}

//+------------------------------------------------------------------+
//| Symbol helpers                                                   |
//+------------------------------------------------------------------+
string ResolvePresetSymbol()
{
   switch(in_symbol_preset)
   {
      case PRESET_USE_CHART: return _Symbol;
      case PRESET_CUSTOM:    return in_custom_symbol;
      // Majors + Metals
      case PRESET_XAUUSD:    return "XAUUSD";
      case PRESET_XAGUSD:    return "XAGUSD";
      case PRESET_EURUSD:    return "EURUSD";
      case PRESET_GBPUSD:    return "GBPUSD";
      case PRESET_AUDUSD:    return "AUDUSD";
      case PRESET_NZDUSD:    return "NZDUSD";
      case PRESET_USDJPY:    return "USDJPY";
      case PRESET_USDCHF:    return "USDCHF";
      case PRESET_USDCAD:    return "USDCAD";
      // Crosses
      case PRESET_EURJPY:    return "EURJPY";
      case PRESET_EURGBP:    return "EURGBP";
      case PRESET_EURAUD:    return "EURAUD";
      case PRESET_GBPJPY:    return "GBPJPY";
      case PRESET_AUDJPY:    return "AUDJPY";
      case PRESET_CADJPY:    return "CADJPY";
      case PRESET_CHFJPY:    return "CHFJPY";
      case PRESET_NZDJPY:    return "NZDJPY";
      // Indices
      case PRESET_US30:      return "US30";
      case PRESET_SPX500:    return "SPX500";   // có thể là US500/US500Cash...
      case PRESET_NAS100:    return "NAS100";   // có thể là USTEC/US100...
      case PRESET_US2000:    return "US2000";   // Russell 2000
      case PRESET_JP225:     return "JP225";    // Nikkei
      case PRESET_HK50:      return "HK50";
      case PRESET_GER40:     return "GER40";
      case PRESET_UK100:     return "UK100";
      // Crypto
      case PRESET_BTCUSD:    return "BTCUSD";
      case PRESET_ETHUSD:    return "ETHUSD";
      case PRESET_LTCUSD:    return "LTCUSD";
      case PRESET_SOLUSD:    return "SOLUSD";
      case PRESET_XRPUSD:    return "XRPUSD";
      case PRESET_ADAUSD:    return "ADAUSD";
      case PRESET_DOGEUSD:   return "DOGEUSD";
   }
   return _Symbol;
}

bool SetupSymbol()
{
   g_symbol = ResolvePresetSymbol();
   if(StringLen(g_symbol) == 0) g_symbol = _Symbol;
   if(!SymbolSelect(g_symbol, true))
   {
      Print("Cảnh báo: Không thể chọn symbol ", g_symbol, ". Dùng chart symbol: ", _Symbol);
      g_symbol = _Symbol;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Hàm khởi tạo EA                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   SetupSymbol();
   trade.SetExpertMagicNumber(in_magic_number);
   trade.SetDeviationInPoints(in_slippage);
   trade.SetTypeFillingBySymbol(g_symbol);

   h_atr_anchor = iATR(g_symbol, in_anchor_tf, in_atr_period);
   if(h_atr_anchor == INVALID_HANDLE)
     {
      Print("Lỗi: Không thể tạo handle ATR cho Anchor TF.");
      return(INIT_FAILED);
     }
   h_atr_chart = iATR(g_symbol, _Period, in_atr_period);
   if(h_atr_chart == INVALID_HANDLE)
     {
      Print("Lỗi: Không thể tạo handle ATR cho Chart TF.");
      return(INIT_FAILED);
     }
     
   last_processed_swing.high_bar_index = -1;
   last_processed_swing.low_bar_index = -1;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Hàm kết thúc EA                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(MQLInfoInteger(MQL_TESTER))
     {
      AnalyzeAndPrintStats();
     }
}


//+------------------------------------------------------------------+
//| Hàm chạy mỗi khi có tick mới                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime new_bar_time = 0;
   datetime current_time = iTime(g_symbol, _Period, 0);
   if(current_time > new_bar_time)
     {
      new_bar_time = current_time;
      
      ManageActiveTrades();
      
      if(CountMyPositions() == 0)
      {
         is_tp1_hit = false;
         pending_e2_price = 0;
         pending_e2_comment = "";
         active_setup_ticket_e1 = 0;
         
         // Áp dụng filter trước khi tạo setup mới
         if(IsSpreadOK() && IsTradingSession())
            CheckForNewSignal();
      }
     }
}

//+------------------------------------------------------------------+
//| Hàm chính để kiểm tra tín hiệu giao dịch mới                      |
//+------------------------------------------------------------------+
void CheckForNewSignal()
{
   MqlRates rates[];
   if(CopyRates(g_symbol, in_anchor_tf, 0, in_swing_bars + 2, rates) < in_swing_bars + 2) return;
      
   ArraySetAsSeries(rates, true);

   SwingStructure current_swing;
   if(!FindLastSwing(rates, current_swing)) return;
      
   if(current_swing.high_bar_index == last_processed_swing.high_bar_index && current_swing.low_bar_index == last_processed_swing.low_bar_index) return;

   double fibo_range_3_top, fibo_range_3_bottom;
   double fibo_range_4_top, fibo_range_4_bottom;
   double fibo_range_5_top, fibo_range_5_bottom;
   
   double swing_range = MathAbs(current_swing.high_price - current_swing.low_price);
   if(swing_range == 0) return;

   if(current_swing.is_bullish_swing)
   {
      double L = current_swing.low_price;
      fibo_range_3_top = L + swing_range * (1.0 - 0.5);
      fibo_range_3_bottom = L + swing_range * (1.0 - 0.618);
      fibo_range_4_top = fibo_range_3_bottom;
      fibo_range_4_bottom = L + swing_range * (1.0 - 0.705);
      fibo_range_5_top = fibo_range_4_bottom;
      fibo_range_5_bottom = L + swing_range * (1.0 - 0.786);
   }
   else
   {
      double H = current_swing.high_price;
      fibo_range_3_top = H - swing_range * (1.0 - 0.618);
      fibo_range_3_bottom = H - swing_range * (1.0 - 0.5);
      fibo_range_4_top = H - swing_range * (1.0 - 0.705);
      fibo_range_4_bottom = fibo_range_3_top;
      fibo_range_5_top = H - swing_range * (1.0 - 0.786);
      fibo_range_5_bottom = fibo_range_4_top;
   }
   
   CArrayObj* fvg_list = ScanForFVGs(rates, current_swing);
   if(fvg_list == NULL || fvg_list.Total() == 0)
   {
      delete fvg_list;
      return;
   }
      
   FairValueGap* fvg_r3 = FindFVGInRange(fvg_list, 3, fibo_range_3_top, fibo_range_3_bottom);
   FairValueGap* fvg_r4 = FindFVGInRange(fvg_list, 4, fibo_range_4_top, fibo_range_4_bottom);
   FairValueGap* fvg_r5 = FindFVGInRange(fvg_list, 5, fibo_range_5_top, fibo_range_5_bottom);

   bool is_high_confluence = (fvg_list.Total() >= 3);
   
   if(in_enable_plan_d)
   {
      FairValueGap *e1=NULL, *e2=NULL; bool dual=false; int r1=0, r2=0;
      if(SelectEntriesPlanD(current_swing, fvg_list,
                            fibo_range_3_top, fibo_range_3_bottom,
                            fibo_range_4_top, fibo_range_4_bottom,
                            fibo_range_5_top, fibo_range_5_bottom,
                            e1, e2, dual, r1, r2))
      {
         PlaceTrade(current_swing, e1, e2, dual, r1, r2);
      }
   }
   else if(in_enable_plan_c)
   {
      FairValueGap *e1=NULL, *e2=NULL; bool dual=false; int r1=0, r2=0;
      if(SelectEntriesPlanC(current_swing, fvg_list,
                            fibo_range_3_top, fibo_range_3_bottom,
                            fibo_range_4_top, fibo_range_4_bottom,
                            fibo_range_5_top, fibo_range_5_bottom,
                            e1, e2, dual, r1, r2))
      {
         PlaceTrade(current_swing, e1, e2, dual, r1, r2);
      }
   }
   else
   {
      if (is_high_confluence && fvg_r4 != NULL && fvg_r5 != NULL)
      {
         PlaceTrade(current_swing, fvg_r4, fvg_r5, true, 4, 5);
      }
      else if (!is_high_confluence && fvg_r3 != NULL && fvg_r4 != NULL)
      {
         PlaceTrade(current_swing, fvg_r3, fvg_r4, true, 3, 4);
      }
      else
      {
         // Fallback single-entry mặc định (luôn cho phép)
         if(fvg_r5 != NULL) PlaceTrade(current_swing, fvg_r5, NULL, false, 5, 0);
         else if(fvg_r4 != NULL) PlaceTrade(current_swing, fvg_r4, NULL, false, 4, 0);
         else if(fvg_r3 != NULL) PlaceTrade(current_swing, fvg_r3, NULL, false, 3, 0);
      }
   }

   delete fvg_list;
}

//+------------------------------------------------------------------+
//| Hàm đặt lệnh                                                     |
//+------------------------------------------------------------------+
void PlaceTrade(SwingStructure &swing, FairValueGap* fvg1, FairValueGap* fvg2, bool is_dual_entry, int range1, int range2)
{
   // Kiểm tra filter trước khi đặt lệnh
   if(!IsSpreadOK() || !IsTradingSession())
      return;

   double entry_price_e1 = (fvg1.high_price + fvg1.low_price) / 2.0;
   
   //--- Logic SL mới ---
   ENUM_SL_MODE effective_sl_mode = in_sl_mode;
   if (range1 >= 4) // Nếu entry ở vùng sâu
   {
       effective_sl_mode = SL_AT_SWING; // Bắt buộc SL theo Swing
   }
   double sl_price = GetSLPrice(swing, entry_price_e1, effective_sl_mode);
   //--- Hết logic SL mới ---
   
   double tp_price = swing.is_bullish_swing ? swing.high_price : swing.low_price;
   double lot_size = is_dual_entry ? NormalizeDouble(in_fixed_lot / 2.0, 2) : in_fixed_lot;
   string comment = StringFormat("%s_R%d", is_dual_entry ? "E1" : "S1", range1);

   if(lot_size < SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN)) lot_size = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
      
   if(!IsPriceValidForLimitOrder(entry_price_e1, swing.is_bullish_swing)) return;
      
   bool result = false;
   if(swing.is_bullish_swing)
   {
      result = trade.BuyLimit(lot_size, entry_price_e1, g_symbol, sl_price, tp_price, ORDER_TIME_GTC, 0, comment);
   }
   else
   {
      result = trade.SellLimit(lot_size, entry_price_e1, g_symbol, sl_price, tp_price, ORDER_TIME_GTC, 0, comment);
   }
   
   if(result)
   {
      last_processed_swing = swing;
      if(is_dual_entry && fvg2 != NULL)
      {
         pending_e2_price = (fvg2.high_price + fvg2.low_price) / 2.0;
         pending_e2_comment = StringFormat("E2_R%d", range2);
      }
      active_setup_ticket_e1 = trade.ResultOrder();
   }
}


//+------------------------------------------------------------------+
//| Tìm kiếm Swing cao/thấp gần nhất                                 |
//+------------------------------------------------------------------+
bool FindLastSwing(MqlRates &rates[], SwingStructure &swing)
{
   int high_bar = -1, low_bar = -1;
   double highest_high = 0, lowest_low = 99999999;

   for(int i = 1; i < in_swing_bars; i++)
   {
      if(i >= ArraySize(rates)) break; 
      
      if(rates[i].high > highest_high)
      {
         highest_high = rates[i].high;
         high_bar = i;
      }
      if(rates[i].low < lowest_low)
      {
         lowest_low = rates[i].low;
         low_bar = i;
      }
   }

   if(high_bar == -1 || low_bar == -1 || high_bar == low_bar) return false;

   swing.high_price = highest_high;
   swing.high_bar_index = high_bar;
   swing.low_price = lowest_low;
   swing.low_bar_index = low_bar;
   swing.is_bullish_swing = (low_bar < high_bar); 
   return true;
}

//+------------------------------------------------------------------+
//| Quét tìm tất cả các FVG hợp lệ trong một Swing                     |
//+------------------------------------------------------------------+
CArrayObj* ScanForFVGs(MqlRates &rates[], SwingStructure &swing)
{
   CArrayObj* fvg_array = new CArrayObj();
   fvg_array.FreeMode(true);
   double atr_value = GetAnchorATR(1);
   double min_fvg_size = atr_value * in_fvg_min_atr_factor;

   int start_bar = MathMin(swing.high_bar_index, swing.low_bar_index);
   int end_bar = MathMax(swing.high_bar_index, swing.low_bar_index);
   double swing_range = MathAbs(swing.high_price - swing.low_price);
   
   for(int i = start_bar + 1; i < end_bar; i++)
   {
      if (i + 1 >= ArraySize(rates) || i - 1 < 0) continue;
       
      // Bullish FVG (gap up)
      if(rates[i+1].high < rates[i-1].low)
      {
         double fvg_size = rates[i-1].low - rates[i+1].high;
         if(fvg_size >= min_fvg_size && swing.is_bullish_swing)
         {
            double fvg_mid_price = (rates[i-1].low + rates[i+1].high) / 2.0;
            double fifty_percent_level = swing.low_price + (swing.high_price - swing.low_price) * 0.5;
            bool pass_discount = (fvg_mid_price < fifty_percent_level);
            if(in_enable_fifty_buffer)
            {
               double buffer_factor = in_enable_plan_d ? EffectiveFiftyBuffer(swing_range, atr_value) : in_fifty_buffer;
               double buffer_price = swing_range * buffer_factor;
               pass_discount = (fvg_mid_price < (fifty_percent_level - buffer_price));
            }
            if (pass_discount)
            {
               FairValueGap *fvg = new FairValueGap();
               fvg.high_price = rates[i-1].low;
               fvg.low_price = rates[i+1].high;
               fvg.bar_index = i;
               fvg_array.Add((CObject*)fvg);
            }
         }
      }
      
      // Bearish FVG (gap down)
      if(rates[i+1].low > rates[i-1].high)
      {
         double fvg_size = rates[i+1].low - rates[i-1].high;
         if(fvg_size >= min_fvg_size && !swing.is_bullish_swing)
         {
            double fvg_mid_price = (rates[i+1].low + rates[i-1].high) / 2.0;
            double fifty_percent_level = swing.high_price - (swing.high_price - swing.low_price) * 0.5;
            bool pass_premium = (fvg_mid_price > fifty_percent_level);
            if(in_enable_fifty_buffer)
            {
               double buffer_factor = in_enable_plan_d ? EffectiveFiftyBuffer(swing_range, atr_value) : in_fifty_buffer;
               double buffer_price = swing_range * buffer_factor;
               pass_premium = (fvg_mid_price > (fifty_percent_level + buffer_price));
            }
            if(pass_premium)
            {
               FairValueGap *fvg = new FairValueGap();
               fvg.high_price = rates[i+1].low;
               fvg.low_price = rates[i-1].high;
               fvg.bar_index = i;
               fvg_array.Add((CObject*)fvg);
            }
         }
      }
   }
   return fvg_array;
}

//+------------------------------------------------------------------+
//| Tìm FVG nằm trong range Fib                                       |
//+------------------------------------------------------------------+
FairValueGap* FindFVGInRange(CArrayObj *fvg_list, int range_id, double top, double bottom)
{
   if(fvg_list == NULL) return NULL;
   for(int i = 0; i < fvg_list.Total(); i++)
   {
      FairValueGap *fvg = (FairValueGap*)fvg_list.At(i);
      if(fvg == NULL) continue;
      double mid = (fvg.high_price + fvg.low_price) / 2.0;
      if(mid <= top && mid >= bottom)
         return fvg;
   }
   return NULL;
}

// Đếm số FVG trong một range
int CountFVGsInRange(CArrayObj *fvg_list, double top, double bottom)
{
   if(fvg_list == NULL) return 0;
   int cnt = 0;
   for(int i = 0; i < fvg_list.Total(); i++)
   {
      FairValueGap *fvg = (FairValueGap*)fvg_list.At(i);
      if(fvg == NULL) continue;
      double mid = (fvg.high_price + fvg.low_price) / 2.0;
      if(mid <= top && mid >= bottom) cnt++;
   }
   return cnt;
}

// Chọn FVG "tốt nhất" trong range: ưu tiên kích thước lớn, rồi ưu tiên sâu hơn theo hướng swing
FairValueGap* PickBestFVGInRange(CArrayObj *fvg_list, double top, double bottom, bool is_bullish)
{
   FairValueGap *best = NULL;
   double best_size = -1.0;
   double best_mid  = 0.0;
   for(int i = 0; i < fvg_list.Total(); i++)
   {
      FairValueGap *fvg = (FairValueGap*)fvg_list.At(i);
      if(fvg == NULL) continue;
      double mid = (fvg.high_price + fvg.low_price) / 2.0;
      if(!(mid <= top && mid >= bottom)) continue;
      double size = MathAbs(fvg.high_price - fvg.low_price);
      if(size > best_size)
      {
         best = fvg; best_size = size; best_mid = mid;
      }
      else if(size == best_size && best != NULL)
      {
         // tie-break: sâu hơn: buy -> mid thấp hơn; sell -> mid cao hơn
         if((is_bullish && mid < best_mid) || (!is_bullish && mid > best_mid))
         {
            best = fvg; best_mid = mid;
         }
      }
   }
   return best;
}

// Plan C: Phân tích động để chọn E1/E2 và range
bool SelectEntriesPlanC(const SwingStructure &swing,
                        CArrayObj *fvg_list,
                        double r3_top, double r3_bottom,
                        double r4_top, double r4_bottom,
                        double r5_top, double r5_bottom,
                        FairValueGap* &e1, FairValueGap* &e2,
                        bool &dual, int &range1, int &range2)
{
   int c3 = CountFVGsInRange(fvg_list, r3_top, r3_bottom);
   int c4 = CountFVGsInRange(fvg_list, r4_top, r4_bottom);
   int c5 = CountFVGsInRange(fvg_list, r5_top, r5_bottom);
   int total = c3 + c4 + c5;

   // Ưu tiên theo mật độ FVG, tie-break theo độ sâu (4 > 5 > 3 cho cả buy/sell)
   RangeScore scores[3];
   scores[0].id=3; scores[0].count=c3;
   scores[1].id=4; scores[1].count=c4;
   scores[2].id=5; scores[2].count=c5;

   // bubble nhỏ để xếp giảm dần theo count; khi bằng nhau, ưu tiên 4,5,3
   for(int i=0;i<3;i++)
      for(int j=i+1;j<3;j++)
      {
         bool swap=false;
         if(scores[j].count > scores[i].count) swap=true;
         else if(scores[j].count == scores[i].count)
         {
            // thứ tự ưu tiên id: 4 > 5 > 3
            int pri_i = (scores[i].id==4?3:(scores[i].id==5?2:1));
            int pri_j = (scores[j].id==4?3:(scores[j].id==5?2:1));
            if(pri_j > pri_i) swap=true;
         }
         if(swap) { RangeScore tmp=scores[i]; scores[i]=scores[j]; scores[j]=tmp; }
      }

   // Chọn range 1 và 2 nếu có
   range1 = scores[0].count>0 ? scores[0].id : 0;
   range2 = (scores[1].count>0 && scores[1].id!=range1) ? scores[1].id : 0;

   if(total >= 3)
   {
      // Hợp lưu mạnh: ưu tiên 4 và 5 nếu có
      if(c4>0 && c5>0) { range1=4; range2=5; }
   }
   else
   {
      // Tiêu chuẩn: ưu tiên 3 & 4 nếu có
      if(c3>0 && c4>0) { range1=3; range2=4; }
   }

   // Xác định E1/E2 theo range đã chọn; nếu chỉ có 1 range -> single
   if(range1==3) e1 = PickBestFVGInRange(fvg_list, r3_top, r3_bottom, swing.is_bullish_swing);
   else if(range1==4) e1 = PickBestFVGInRange(fvg_list, r4_top, r4_bottom, swing.is_bullish_swing);
   else if(range1==5) e1 = PickBestFVGInRange(fvg_list, r5_top, r5_bottom, swing.is_bullish_swing);
   else e1 = NULL;
   if(range2==3) e2 = PickBestFVGInRange(fvg_list, r3_top, r3_bottom, swing.is_bullish_swing);
   else if(range2==4) e2 = PickBestFVGInRange(fvg_list, r4_top, r4_bottom, swing.is_bullish_swing);
   else if(range2==5) e2 = PickBestFVGInRange(fvg_list, r5_top, r5_bottom, swing.is_bullish_swing);
   else e2 = NULL;
   dual = (e1!=NULL && e2!=NULL);

   // Nếu không chọn được, fallback cố gắng 1 range bất kỳ theo ưu tiên (4,5,3)
   if(e1==NULL)
   {
      if(c4>0) { range1=4; e1 = PickBestFVGInRange(fvg_list, r4_top, r4_bottom, swing.is_bullish_swing); }
      else if(c5>0) { range1=5; e1 = PickBestFVGInRange(fvg_list, r5_top, r5_bottom, swing.is_bullish_swing); }
      else if(c3>0) { range1=3; e1 = PickBestFVGInRange(fvg_list, r3_top, r3_bottom, swing.is_bullish_swing); }
   }

   return (e1 != NULL);
}

// Plan D: Thích ứng theo biến động (ATR/swing_range)
bool SelectEntriesPlanD(const SwingStructure &swing,
                        CArrayObj *fvg_list,
                        double r3_top, double r3_bottom,
                        double r4_top, double r4_bottom,
                        double r5_top, double r5_bottom,
                        FairValueGap* &e1, FairValueGap* &e2,
                        bool &dual, int &range1, int &range2)
{
   e1=NULL; e2=NULL; dual=false; range1=0; range2=0;
   int c3 = CountFVGsInRange(fvg_list, r3_top, r3_bottom);
   int c4 = CountFVGsInRange(fvg_list, r4_top, r4_bottom);
   int c5 = CountFVGsInRange(fvg_list, r5_top, r5_bottom);
   int total = c3 + c4 + c5;
   double swing_range = MathAbs(swing.high_price - swing.low_price);
   double atr = GetAnchorATR(1);
   double ratio = (swing_range>0? atr/swing_range : 0.0);

   // High vol: ưu tiên 4 & 5 nếu có, sau đó 4 hoặc 5 đơn lẻ
   if(ratio >= in_plan_d_high_vol_ratio)
   {
      if(c4>0 && c5>0) { range1=4; range2=5; }
      else if(c4>0) { range1=4; }
      else if(c5>0) { range1=5; }
   }
   // Low vol: ưu tiên 3 & 4 nếu có, sau đó 3 hoặc 4 đơn lẻ
   else if(ratio <= in_plan_d_low_vol_ratio)
   {
      if(c3>0 && c4>0) { range1=3; range2=4; }
      else if(c3>0) { range1=3; }
      else if(c4>0) { range1=4; }
   }

   // Trung tính hoặc không chọn được gì theo ưu tiên => fallback Plan C
   if(range1==0)
   {
      return SelectEntriesPlanC(swing, fvg_list,
                                r3_top, r3_bottom,
                                r4_top, r4_bottom,
                                r5_top, r5_bottom,
                                e1, e2, dual, range1, range2);
   }

   // Pick FVG theo range đã chọn
   if(range1==3) e1 = PickBestFVGInRange(fvg_list, r3_top, r3_bottom, swing.is_bullish_swing);
   else if(range1==4) e1 = PickBestFVGInRange(fvg_list, r4_top, r4_bottom, swing.is_bullish_swing);
   else if(range1==5) e1 = PickBestFVGInRange(fvg_list, r5_top, r5_bottom, swing.is_bullish_swing);

   if(range2==3) e2 = PickBestFVGInRange(fvg_list, r3_top, r3_bottom, swing.is_bullish_swing);
   else if(range2==4) e2 = PickBestFVGInRange(fvg_list, r4_top, r4_bottom, swing.is_bullish_swing);
   else if(range2==5) e2 = PickBestFVGInRange(fvg_list, r5_top, r5_bottom, swing.is_bullish_swing);

   dual = (e1!=NULL && e2!=NULL);

   // Nếu chưa có e1 thì vẫn fallback Plan C để chắc chắn
   if(e1==NULL)
   {
      return SelectEntriesPlanC(swing, fvg_list,
                                r3_top, r3_bottom,
                                r4_top, r4_bottom,
                                r5_top, r5_bottom,
                                e1, e2, dual, range1, range2);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Quản lý lệnh đang hoạt động                                      |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
   // Nếu E1 đã khớp và có pending E2, cân nhắc đặt E2 nếu phù hợp điều kiện
   if(pending_e2_price > 0 && CountMyPositions() > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
         {
            long type = PositionGetInteger(POSITION_TYPE);
            double lot_size = NormalizeDouble(in_fixed_lot / 2.0, 2);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            if(IsTradingSession() && IsSpreadOK() && IsPriceValidForLimitOrder(pending_e2_price, (type == POSITION_TYPE_BUY)))
            {
               if(type == POSITION_TYPE_BUY)
               {
                  if(trade.BuyLimit(lot_size, pending_e2_price, g_symbol, sl, tp, ORDER_TIME_GTC, 0, pending_e2_comment))
                  {
                     pending_e2_price = 0;
                     pending_e2_comment = "";
                  }
               }
               else if(type == POSITION_TYPE_SELL)
               {
                  if(trade.SellLimit(lot_size, pending_e2_price, g_symbol, sl, tp, ORDER_TIME_GTC, 0, pending_e2_comment))
                  {
                     pending_e2_price = 0;
                     pending_e2_comment = "";
                  }
               }
            } else {
               // Điều kiện không phù hợp => hủy pending E2
               pending_e2_price = 0;
               pending_e2_comment = "";
            }
         }
      }
   }
   
   // Xử lý TP1 (đóng 50% khi chạm mức TP) và trailing/BE sau TP1
   if(!is_tp1_hit && CountMyPositions() > 0)
   {
      bool should_close_partial = false;
      double total_volume = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
         {
            long type = PositionGetInteger(POSITION_TYPE);
            double tp = PositionGetDouble(POSITION_TP);
            
            if((type == POSITION_TYPE_BUY && SymbolInfoDouble(g_symbol, SYMBOL_ASK) >= tp) ||
               (type == POSITION_TYPE_SELL && SymbolInfoDouble(g_symbol, SYMBOL_BID) <= tp))
            {
               should_close_partial = true;
            }
            total_volume += PositionGetDouble(POSITION_VOLUME);
         }
      }
      
      if(should_close_partial)
      {
         ClosePartialPositions(total_volume * 0.5);
         is_tp1_hit = true;
         CancelPendingE2();
      }
   }

   if(is_tp1_hit)
   {
      ApplyPostTP1Management();
   }
}

//+------------------------------------------------------------------+
//| Đóng một phần khối lượng của tất cả các vị thế                    |
//+------------------------------------------------------------------+
void ClosePartialPositions(double volume_to_close)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
        {
            double current_volume = PositionGetDouble(POSITION_VOLUME);
            double close_vol = MathMin(current_volume, volume_to_close);
            
            if(close_vol > 0)
            {
               MqlTradeRequest request;
               ZeroMemory(request);
               MqlTradeResult  result;
               ZeroMemory(result);
               
               request.action       = TRADE_ACTION_DEAL;
               request.position     = ticket;
               request.symbol       = g_symbol;
               request.volume       = NormalizeDouble(close_vol, 2);
               request.magic        = in_magic_number;
               request.deviation    = in_slippage;
               
               ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               if(pos_type == POSITION_TYPE_BUY)
               {
                  request.type = ORDER_TYPE_SELL;
                  request.price = SymbolInfoDouble(g_symbol, SYMBOL_BID);
               }
               else if(pos_type == POSITION_TYPE_SELL)
               {
                  request.type = ORDER_TYPE_BUY;
                  request.price = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
               }
               
               if(OrderSend(request, result))
               {
                  volume_to_close -= close_vol;
               }
               else
               {
                  Print("Lỗi khi đóng một phần lệnh #", ticket, ": ", result.retcode, " - ", result.comment);
               }
            }
            
            if(volume_to_close <= 0.00001) break;
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop Loss (theo hệ số chỉ định)                         |
//+------------------------------------------------------------------+
void TrailStopLossWithFactor(double factor)
{
   double atr_value = GetChartATR(1);
   if(atr_value == 0) return;
   double trail_distance = atr_value * factor;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         double new_sl = 0;
         
         if(type == POSITION_TYPE_BUY)
         {
            new_sl = SymbolInfoDouble(g_symbol, SYMBOL_BID) - trail_distance;
            if(new_sl > open_price && (new_sl > current_sl || current_sl == 0) )
            {
               trade.PositionModify(ticket, new_sl, tp);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            new_sl = SymbolInfoDouble(g_symbol, SYMBOL_ASK) + trail_distance;
            if(new_sl < open_price && (new_sl < current_sl || current_sl == 0))
            {
               trade.PositionModify(ticket, new_sl, tp);
            }
         }
      }
   }
}

// Giữ tương thích hàm cũ
void TrailStopLoss()
{
   TrailStopLossWithFactor(in_trailing_stop_atr_factor);
}

//+------------------------------------------------------------------+
//| Dời SL về BE sau TP1                                             |
//+------------------------------------------------------------------+
void MoveSLToBreakeven(double offset_points)
{
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double offset = offset_points * point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double new_sl = current_sl;

         if(type == POSITION_TYPE_BUY)
         {
            double be = open_price - offset; // SL dưới giá vào (an toàn)
            if(current_sl < be || current_sl == 0)
               new_sl = be;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double be = open_price + offset; // SL trên giá vào (an toàn)
            if(current_sl == 0 || current_sl > be)
               new_sl = be;
         }

         if(new_sl != current_sl)
            trade.PositionModify(ticket, new_sl, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Quy tắc quản lý sau TP1                                          |
//+------------------------------------------------------------------+
void ApplyPostTP1Management()
{
   switch(in_after_tp1_mode)
   {
      case AFTER_TP1_MOVE_BE:
      {
         MoveSLToBreakeven(in_be_offset_points);
         break;
      }
      case AFTER_TP1_TRAIL_SLOW:
      {
         TrailStopLossWithFactor(in_trailing_stop_atr_factor_after_tp1);
         break;
      }
      case AFTER_TP1_TRAIL_ATR:
      default:
      {
         TrailStopLossWithFactor(in_trailing_stop_atr_factor);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Hủy lệnh chờ E2 nếu nó chưa khớp                                   |
//+------------------------------------------------------------------+
void CancelPendingE2()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket))
        {
            if(OrderGetInteger(ORDER_MAGIC) == in_magic_number)
            {
                if(OrderGetInteger(ORDER_TICKET) != active_setup_ticket_e1)
                {
                   trade.OrderDelete(ticket);
                }
            }
        }
    }
    pending_e2_price = 0;
}

//+------------------------------------------------------------------+
//| Tính toán giá Stop Loss                                          |
//+------------------------------------------------------------------+
double GetSLPrice(const SwingStructure &swing, double entry_price, ENUM_SL_MODE sl_mode)
{
    double sl = 0;
    double atr = GetAnchorATR(1);
    
    switch(sl_mode)
    {
        case SL_AT_SWING:
        {
            double fibo_100_price = swing.is_bullish_swing ? swing.low_price : swing.high_price;
            double padding = atr * in_sl_padding_atr_factor;
            sl = swing.is_bullish_swing ? (fibo_100_price - padding) : (fibo_100_price + padding);
            break;
        }
        
        case SL_FROM_ENTRY_ATR:
        {
            double distance = atr * in_sl_atr_factor_from_entry;
            sl = swing.is_bullish_swing ? (entry_price - distance) : (entry_price + distance);
            break;
        }
    }
    return sl;
}


//+------------------------------------------------------------------+
//| Đếm số lượng vị thế và lệnh chờ của EA                           |
//+------------------------------------------------------------------+
int CountMyTrades()
{
   int count = 0;
   count += CountMyPositions();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == in_magic_number)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Đếm số lượng vị thế đang mở của EA                               |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == in_magic_number)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Lấy giá trị ATR                                                  |
//+------------------------------------------------------------------+
double GetAnchorATR(int shift)
{
   double buffer[1];
   if(CopyBuffer(h_atr_anchor, 0, shift, 1, buffer) > 0) return buffer[0];
   return 0.0;
}
double GetChartATR(int shift)
{
   double buffer[1];
   if(CopyBuffer(h_atr_chart, 0, shift, 1, buffer) > 0) return buffer[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| BỘ LỌC AN TOÀN: Kiểm tra giá trước khi đặt lệnh limit            |
//+------------------------------------------------------------------+
bool IsPriceValidForLimitOrder(double price, bool is_buy)
{
    MqlTick tick;
    SymbolInfoTick(g_symbol, tick);
    double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
    double stop_level_points = (double)SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

    if(is_buy)
    {
        return (price < tick.ask - stop_level_points);
    }
    else
    {
        return (price > tick.bid + stop_level_points);
    }
}

//+------------------------------------------------------------------+
//| Phân tích lịch sử và in ra thống kê                              |
//+------------------------------------------------------------------+
void AnalyzeAndPrintStats()
{
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("Không thể truy cập lịch sử giao dịch!");
      return;
   }

   TradeStats stats_r3, stats_r4, stats_r5, stats_single, stats_dual;
   ZeroMemory(stats_r3); ZeroMemory(stats_r4); ZeroMemory(stats_r5);
   ZeroMemory(stats_single); ZeroMemory(stats_dual);

   int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealSelect(ticket))
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == in_magic_number && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            double profit = 0;
            
            long position_id = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            for(int j = i; j < total_deals; j++)
            {
               ulong exit_ticket = HistoryDealGetTicket(j);
               if(HistoryDealSelect(exit_ticket))
               {
                  if(HistoryDealGetInteger(exit_ticket, DEAL_POSITION_ID) == position_id && 
                    (HistoryDealGetInteger(exit_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT || HistoryDealGetInteger(exit_ticket, DEAL_ENTRY) == DEAL_ENTRY_INOUT))
                  {
                     profit += HistoryDealGetDouble(exit_ticket, DEAL_PROFIT);
                  }
               }
            }

            bool is_win = (profit >= 0);

            if(StringFind(comment, "S1") >= 0)
            {
               stats_single.total_trades++;
               if(is_win) stats_single.win_trades++;
            }
            if(StringFind(comment, "E1") >= 0)
            {
                stats_dual.total_trades++;
                if(is_win) stats_dual.win_trades++;
            }

            if(StringFind(comment, "R3") >= 0)
            {
               stats_r3.total_trades++;
               if(is_win) stats_r3.win_trades++;
            }
            else if(StringFind(comment, "R4") >= 0)
            {
               stats_r4.total_trades++;
               if(is_win) stats_r4.win_trades++;
            }
            else if(StringFind(comment, "R5") >= 0)
            {
               stats_r5.total_trades++;
               if(is_win) stats_r5.win_trades++;
            }
         }
      }
   }

   Print("\n\n==================== BÁO CÁO THỐNG KÊ GIAO DỊCH ====================");
   
   int total_wins = stats_single.win_trades + stats_dual.win_trades;
   int total_trades = stats_single.total_trades + stats_dual.total_trades;
   
   PrintFormat("TỔNG QUAN:");
   PrintFormat("   - Tổng số Trade: %d", total_trades);
   PrintFormat("   - Tỷ lệ thắng chung: %.2f %% (%d/%d)", total_trades > 0 ? (double)total_wins / total_trades * 100 : 0, total_wins, total_trades);
   
   Print("\n--- PHÂN TÍCH THEO FIBO RANGE ---");
   PrintFormat("Range 3 (50%% - 61.8%%):  %.2f %% Thắng (%d/%d trades)", stats_r3.total_trades > 0 ? (double)stats_r3.win_trades / stats_r3.total_trades * 100 : 0, stats_r3.win_trades, stats_r3.total_trades);
   PrintFormat("Range 4 (61.8%% - 70.5%%): %.2f %% Thắng (%d/%d trades)", stats_r4.total_trades > 0 ? (double)stats_r4.win_trades / stats_r4.total_trades * 100 : 0, stats_r4.win_trades, stats_r4.total_trades);
   PrintFormat("Range 5 (70.5%% - 78.6%%): %.2f %% Thắng (%d/%d trades)", stats_r5.total_trades > 0 ? (double)stats_r5.win_trades / stats_r5.total_trades * 100 : 0, stats_r5.win_trades, stats_r5.total_trades);

   Print("\n--- PHÂN TÍCH THEO LOẠI LỆNH ---");
   PrintFormat("Lệnh Đơn (Plan B):  %.2f %% Thắng (%d/%d trades)", stats_single.total_trades > 0 ? (double)stats_single.win_trades / stats_single.total_trades * 100 : 0, stats_single.win_trades, stats_single.total_trades);
   PrintFormat("Lệnh Kép (Lý tưởng): %.2f %% Thắng (%d/%d trades)", stats_dual.total_trades > 0 ? (double)stats_dual.win_trades / stats_dual.total_trades * 100 : 0, stats_dual.win_trades, stats_dual.total_trades);
   
   Print("====================================================================\n");
}
//+------------------------------------------------------------------+
