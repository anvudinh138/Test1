//+------------------------------------------------------------------+
//|                        MR_MicroScalp_TrendFilter.mq5               |
//|         Phiên bản cuối cùng, tích hợp đầy đủ tính năng            |
//+------------------------------------------------------------------+
#property strict
#property description "Tích hợp Preset, Trailing Stop, Pyramid, và Bộ lọc Xu hướng."

// --- Input điều khiển ---
input string IN_SYMBOL = ""; // Để trống để Tùy chỉnh (chạy Optimization). Điền Symbol (vd: "XAUUSDm") để dùng Preset.

// --- (MỚI) Inputs cho Bộ lọc Xu hướng ---
input bool   IN_TREND_FILTER_ENABLED = true;   // Bật/tắt bộ lọc xu hướng
input int    IN_TREND_MA_PERIOD      = 200;    // Chu kỳ của đường MA
input ENUM_MA_METHOD IN_TREND_MA_METHOD    = MODE_SMA; // Phương pháp tính MA (SMA, EMA...)

// --- Inputs MẶC ĐỊNH (Sẽ được Preset ghi đè nếu IN_SYMBOL được điền) ---
input int    IN_CONSECUTIVE_BARS   = 2;
input int    IN_MIN_BAR_BODY_TICKS = 10;
input bool   IN_TRAIL_ENABLED        = true;
input int    IN_TRAIL_START_TICKS    = 20;
input int    IN_TRAIL_DISTANCE_TICKS = 10;
input int    IN_SPREAD_MAX_TICKS   = 30;
input double IN_TP_TICKS           = 40;
input double IN_SL_TICKS           = 15;
input int    IN_MAX_PYRAMID_ENTRIES = 3;

// --- Inputs Cấu hình chung ---
input bool   IN_ATR_FILTER_ENABLED = true;
input int    IN_ATR_PERIOD         = 14;
input int    IN_ATR_BASELINE_BARS  = 1440;
input double IN_ATR_MIN_MULT       = 0.5;
input double IN_ATR_MAX_MULT       = 2.5;
input bool   IN_KILLZONE_FILTER_ENABLED = false; // Tắt mặc định để test trên Forex dễ hơn
input string IN_KILLZONE_DENY_HOURS   = "0,1,2,3,4,5,22,23";
input double IN_LOT                = 0.01;
input int    IN_TIME_LIMIT_MS      = 60000;
input ulong  IN_MAGIC_NUMBER       = 12345;
input int    IN_SLIPPAGE_POINTS    = 100;
input int    IN_MIN_SECONDS_BETWEEN_TRADES = 15;

// --- Các biến toàn cục linh hoạt ---
string    G_SYMBOL;
int       G_CONSECUTIVE_BARS;
int       G_MIN_BAR_BODY_TICKS;
bool      G_TRAIL_ENABLED;
int       G_TRAIL_START_TICKS;
int       G_TRAIL_DISTANCE_TICKS;
int       G_SPREAD_MAX_TICKS;
double    G_TP_TICKS;
double    G_SL_TICKS;
int       G_MAX_PYRAMID_ENTRIES;

// --- Globals ---
double    G_POINT, G_TICK_SIZE, G_TICK_VALUE, G_DIGITS;
ENUM_ORDER_TYPE_FILLING G_FILLING_MODE;
datetime  g_last_bar_time = 0, g_last_trade_time = 0;
int       G_ATR_HANDLE = INVALID_HANDLE;
int       G_MA_HANDLE = INVALID_HANDLE;
double    G_ATR_BASELINE = 0.0;
bool      G_DENY_HOUR[24];
datetime  g_last_atr_update = 0;
int       g_last_entry_streak = 0;

//+------------------------------------------------------------------+
//| Nạp Preset dựa trên Symbol                                      |
//+------------------------------------------------------------------+
void ApplyPresetForSymbol(string symbol_name)
  {
   PrintFormat("Phát hiện Symbol: %s. Đang tìm Preset phù hợp...", symbol_name);

   if(StringFind(symbol_name, "XAU") >= 0)
     {
      Print("Đã nạp Preset cho XAUUSD.");
      G_CONSECUTIVE_BARS   = 2;
      G_MIN_BAR_BODY_TICKS = 10;
      G_TP_TICKS           = 60;
      G_SL_TICKS           = 20;
      G_TRAIL_ENABLED      = true;
      G_TRAIL_START_TICKS    = 25;
      G_TRAIL_DISTANCE_TICKS = 10;
      G_SPREAD_MAX_TICKS   = 150;
      G_MAX_PYRAMID_ENTRIES = 2;
      return;
     }
   else
      if(StringFind(symbol_name, "EURUSD") >= 0)
        {
         Print("Đã nạp Preset cho EURUSD.");
         G_CONSECUTIVE_BARS   = 1;
         G_MIN_BAR_BODY_TICKS = 5;
         G_TP_TICKS           = 80;
         G_SL_TICKS           = 40;
         G_TRAIL_ENABLED      = true;
         G_TRAIL_START_TICKS    = 30;
         G_TRAIL_DISTANCE_TICKS = 15;
         G_SPREAD_MAX_TICKS   = 20;
         G_MAX_PYRAMID_ENTRIES = 3;
         return;
        }
      else
        {
         Print("Không tìm thấy Preset riêng. Sử dụng thông số mặc định trong tab Inputs.");
        }
  }

//+------------------------------------------------------------------+
//| OnInit: Khởi tạo EA                                              |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Xác định Symbol mục tiêu G_SYMBOL trước tiên
   if(IN_SYMBOL == "")
     {
      G_SYMBOL = _Symbol;
     }
   else
     {
      G_SYMBOL = IN_SYMBOL;
     }

   PrintFormat("EA sẽ hoạt động trên Symbol: %s", G_SYMBOL);

// 2. Lấy tất cả thông tin dựa trên G_SYMBOL
   G_POINT = SymbolInfoDouble(G_SYMBOL, SYMBOL_POINT);
   G_TICK_SIZE = SymbolInfoDouble(G_SYMBOL, SYMBOL_TRADE_TICK_SIZE);
   G_TICK_VALUE = SymbolInfoDouble(G_SYMBOL, SYMBOL_TRADE_TICK_VALUE);
   G_DIGITS = SymbolInfoInteger(G_SYMBOL, SYMBOL_DIGITS);

   long modes = SymbolInfoInteger(G_SYMBOL, SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK))
     {
      G_FILLING_MODE = ORDER_FILLING_FOK;
     }
   else
      if((modes & SYMBOL_FILLING_IOC))
        {
         G_FILLING_MODE = ORDER_FILLING_IOC;
        }
      else
        {
         G_FILLING_MODE = ORDER_FILLING_RETURN;
        }

// 3. Khởi tạo các chỉ báo cho G_SYMBOL
   G_ATR_HANDLE = iATR(G_SYMBOL, PERIOD_M1, IN_ATR_PERIOD);
   G_MA_HANDLE = iMA(G_SYMBOL, PERIOD_M1, IN_TREND_MA_PERIOD, 0, IN_TREND_MA_METHOD, PRICE_CLOSE);

   ParseKillzoneHours(IN_KILLZONE_DENY_HOURS);

// 4. Sao chép và áp dụng Preset
   G_CONSECUTIVE_BARS   = IN_CONSECUTIVE_BARS;
   G_MIN_BAR_BODY_TICKS = IN_MIN_BAR_BODY_TICKS;
   G_TRAIL_ENABLED      = IN_TRAIL_ENABLED;
   G_TRAIL_START_TICKS    = IN_TRAIL_START_TICKS;
   G_TRAIL_DISTANCE_TICKS = IN_TRAIL_DISTANCE_TICKS;
   G_SPREAD_MAX_TICKS   = IN_SPREAD_MAX_TICKS;
   G_TP_TICKS           = IN_TP_TICKS;
   G_SL_TICKS           = IN_SL_TICKS;
   G_MAX_PYRAMID_ENTRIES = IN_MAX_PYRAMID_ENTRIES;

   if(IN_SYMBOL != "")
     {
      PrintFormat("Áp dụng Preset cho '%s'...", G_SYMBOL);
      ApplyPresetForSymbol(G_SYMBOL);
     }
   else
     {
      Print("Sử dụng thông số tùy chỉnh từ tab Inputs.");
     }

   Sleep(1000);
   UpdateATRBaseline();
   Print("EA TrendFilter đã khởi động.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnTick: Logic chính của EA                                       |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageOpenTrades();

   datetime current_bar_time = (datetime)SeriesInfoInteger(G_SYMBOL, PERIOD_M1, SERIES_LASTBAR_DATE);
   if(current_bar_time == g_last_bar_time)
      return;

   g_last_bar_time = current_bar_time;
   if((int)g_last_bar_time % (60 * 60) == 0 && TimeCurrent() - g_last_atr_update > 60)
      UpdateATRBaseline();

// --- CÁC BỘ LỌC CHUNG ---
   if(CountEAPositions() >= G_MAX_PYRAMID_ENTRIES)
      return;
   if(TimeCurrent() - g_last_trade_time < IN_MIN_SECONDS_BETWEEN_TRADES)
      return;

   double spread_ticks = SymbolInfoInteger(G_SYMBOL, SYMBOL_SPREAD) * G_POINT / G_TICK_SIZE;
   if(spread_ticks > G_SPREAD_MAX_TICKS)
      return;

   if(IN_ATR_FILTER_ENABLED && G_ATR_BASELINE > 0)
     {
      double atr_buffer[1];
      if(CopyBuffer(G_ATR_HANDLE, 0, 1, 1, atr_buffer) > 0)
        {
         double current_atr = atr_buffer[0];
         if(current_atr > G_ATR_BASELINE * IN_ATR_MAX_MULT)
            return;
         if(current_atr < G_ATR_BASELINE * IN_ATR_MIN_MULT)
            return;
        }
     }

   if(IN_KILLZONE_FILTER_ENABLED)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(G_DENY_HOUR[dt.hour])
         return;
     }

// --- PHÂN TÍCH TÍN HIỆU VÀ LỌC XU HƯỚNG ---
   int streak_signal = GetConsecutiveBarStreak();
   if(streak_signal != 0)
     {
      int abs_streak = MathAbs(streak_signal);
      if(abs_streak >= G_CONSECUTIVE_BARS && abs_streak > g_last_entry_streak)
        {
         // Logic đảo chiều tín hiệu (đã sửa lỗi)
         int trade_direction = (streak_signal > 0) ? -1 : 1; // Chuỗi tăng -> SELL, chuỗi giảm -> BUY

         // BỘ LỌC XU HƯỚNG
         if(IN_TREND_FILTER_ENABLED)
           {
            double ma_buffer[1];
            if(CopyBuffer(G_MA_HANDLE, 0, 1, 1, ma_buffer) > 0)
              {
               double ma_value = ma_buffer[0];
               double current_price = SymbolInfoDouble(G_SYMBOL, SYMBOL_BID);

               // Nếu xu hướng TĂNG (giá > MA), chỉ cho phép BUY
               if(current_price > ma_value && trade_direction == -1) // Muốn SELL trong trend tăng -> Cấm
                 {
                  PrintFormat("Filter: Bỏ qua tín hiệu SELL vì đang trong xu hướng tăng.");
                  return;
                 }

               // Nếu xu hướng GIẢM (giá < MA), chỉ cho phép SELL
               if(current_price < ma_value && trade_direction == 1) // Muốn BUY trong trend giảm -> Cấm
                 {
                  PrintFormat("Filter: Bỏ qua tín hiệu BUY vì đang trong xu hướng giảm.");
                  return;
                 }
              }
           }

         // Nếu qua được hết các bộ lọc, gửi lệnh
         if(SendMarketOrder(trade_direction))
           {
            g_last_trade_time = TimeCurrent();
            g_last_entry_streak = abs_streak;
           }
        }
     }
  }

// --- CÁC HÀM HELPER (Không thay đổi) ---
int GetConsecutiveBarStreak()
  {
   int max_check=10;
   MqlRates rates[];
   if(CopyRates(G_SYMBOL,PERIOD_M1,0,max_check,rates)<2)
      return 0;
   int first_dir=0;
   if(rates[0].close>rates[0].open&&(rates[0].close-rates[0].open)/G_POINT>=G_MIN_BAR_BODY_TICKS)
      first_dir=1;
   if(rates[0].close<rates[0].open&&(rates[0].open-rates[0].close)/G_POINT>=G_MIN_BAR_BODY_TICKS)
      first_dir=-1;
   if(first_dir==0)
      return 0;
   int streak=0;
   for(int i=0;i<max_check;i++)
     {
      double body = MathAbs(rates[i].close - rates[i].open)/G_POINT;
      int curr_dir=(rates[i].close>rates[i].open)?1:-1;
      if(curr_dir==first_dir&&body>=G_MIN_BAR_BODY_TICKS)
        {
         streak++;
        }
      else
        {
         break;
        }
     }
   return streak*first_dir;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpenTrades()
  {
   if(CountEAPositions()==0&&g_last_entry_streak!=0)
     {
      g_last_entry_streak=0;
     }

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC)!=IN_MAGIC_NUMBER||PositionGetString(POSITION_SYMBOL)!=G_SYMBOL)
            continue;
         double current_profit=PositionGetDouble(POSITION_PROFIT);
         datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);
         long type=PositionGetInteger(POSITION_TYPE);
         double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl=PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);

         // BƯỚC 1: Nếu lệnh mới mở chưa có SL/TP, hãy thêm vào
         if(current_sl == 0.0 && current_tp == 0.0)
           {
            double new_sl=0, new_tp=0;
            if(type == POSITION_TYPE_BUY)
              {
               new_sl = open_price - G_SL_TICKS * G_TICK_SIZE;
               new_tp = open_price + G_TP_TICKS * G_TICK_SIZE;
              }
            else // SELL
              {
               new_sl = open_price + G_SL_TICKS * G_TICK_SIZE;
               new_tp = open_price - G_TP_TICKS * G_TICK_SIZE;
              }

            ModifyPositionSLTP(ticket, new_sl, new_tp);
            continue; // Chuyển sang lệnh tiếp theo sau khi đã set SL/TP
           }

         if(current_sl > 0 && current_tp > 0)
           {
               if(G_TRAIL_ENABLED)
               {
                  double profit_in_ticks=0;
                  if(type==POSITION_TYPE_BUY)
                     profit_in_ticks=(SymbolInfoDouble(G_SYMBOL,SYMBOL_BID)-open_price)/G_TICK_SIZE;
                  else
                     profit_in_ticks=(open_price-SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK))/G_TICK_SIZE;

                  if(profit_in_ticks>=G_TRAIL_START_TICKS)
                  {
                     double new_sl_price=0;
                     if(type==POSITION_TYPE_BUY)
                        new_sl_price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID)-G_TRAIL_DISTANCE_TICKS*G_TICK_SIZE;
                     else
                        new_sl_price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK)+G_TRAIL_DISTANCE_TICKS*G_TICK_SIZE;

                     if((type==POSITION_TYPE_BUY&&new_sl_price>current_sl)||(type==POSITION_TYPE_SELL&&(new_sl_price<current_sl||current_sl==0)))
                     {
                        if(ModifyPositionSLTP(ticket,new_sl_price,PositionGetDouble(POSITION_TP)))
                        {
                           // Trailing stop updated
                        }
                     }
                  }
              }
           


            long time_elapsed_ms=(TimeCurrent()-open_time)*1000;
            if(time_elapsed_ms>=IN_TIME_LIMIT_MS)
              {
               ClosePosition(ticket);
               continue;
              }

           }

         double target_profit_usd=G_TP_TICKS*G_TICK_VALUE;
         double target_loss_usd=-G_SL_TICKS*G_TICK_VALUE;

         if(current_profit>=target_profit_usd)
           {
            ClosePosition(ticket);
            continue;
           }

         if(current_profit<=target_loss_usd)
           {
            ClosePosition(ticket);
            continue;
           }


        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ModifyPositionSLTP(ulong ticket, double sl, double tp)
  {
   MqlTradeRequest r;
   MqlTradeResult s;
   ZeroMemory(r);
   ZeroMemory(s);
   r.action=TRADE_ACTION_SLTP;
   r.position=ticket;
   r.sl=sl;
   r.tp=tp;
   if(!OrderSend(r,s))
     {
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseKillzoneHours(string s)
  {
   for(int i=0;i<24;i++)
      G_DENY_HOUR[i]=false;
   string parts[];
   StringSplit(s,',',parts);
   for(int i=0;i<ArraySize(parts);i++)
     {
      int h=(int)StringToInteger(parts[i]);
      if(h>=0&&h<24)
         G_DENY_HOUR[h]=true;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateATRBaseline()
  {
   if(G_ATR_HANDLE==INVALID_HANDLE)
      return;
   double atr_values[];
   if(CopyBuffer(G_ATR_HANDLE,0,0,IN_ATR_BASELINE_BARS,atr_values)>IN_ATR_PERIOD)
     {
      G_ATR_BASELINE=0;
      int count=0;
      for(int i=0;i<ArraySize(atr_values);i++)
        {
         if(atr_values[i]>0)
           {
            G_ATR_BASELINE+=atr_values[i];
            count++;
           }
        }
      if(count>0)
         G_ATR_BASELINE/=count;
      g_last_atr_update=TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountEAPositions()
  {
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetInteger(POSITION_MAGIC)==IN_MAGIC_NUMBER&&PositionGetString(POSITION_SYMBOL)==G_SYMBOL)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendMarketOrder(int direction)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;
   request.symbol=G_SYMBOL;
   request.volume=IN_LOT;
   request.magic=IN_MAGIC_NUMBER;
   request.deviation=IN_SLIPPAGE_POINTS;
   request.type_filling=G_FILLING_MODE;

   if(direction > 0)
     {
      request.type=ORDER_TYPE_BUY;
      request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);
     }
   else
     {
      request.type=ORDER_TYPE_SELL;
      request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
     }

   if(!OrderSend(request,result))
     {
      return false;
     }

   if(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_DONE_PARTIAL)
     {
      return true;
     }
   else
     {
      return false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
     {
      return false;
     }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;
   request.position=ticket;
   request.symbol=G_SYMBOL;
   request.volume=PositionGetDouble(POSITION_VOLUME);
   request.magic=IN_MAGIC_NUMBER;
   request.deviation=IN_SLIPPAGE_POINTS;
   request.type_filling=G_FILLING_MODE;

   if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      request.type=ORDER_TYPE_SELL;
      request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
     }
   else
     {
      request.type=ORDER_TYPE_BUY;
      request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);
     }

   if(!OrderSend(request,result))
     {
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
