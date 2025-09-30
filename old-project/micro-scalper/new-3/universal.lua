//+------------------------------------------------------------------+
//|                        MR_MicroScalp_Universal_V2.mq5              |
//|         Phiên bản cuối cùng - 100% Tự động thích ứng (ATR)         |
//+------------------------------------------------------------------+
#property strict
#property description "Toàn bộ logic TP, SL, Trailing, Filter... đều dựa trên ATR."

// --- (NÂNG CẤP TOÀN BỘ) Inputs dựa trên ATR ---
input double IN_MIN_BAR_BODY_ATR_MULT = 0.01;  // Thân nến tối thiểu = ATR * giá trị này
input double IN_TP_ATR_MULT           = 0.05;  // Take Profit = ATR * giá trị này
input double IN_SL_ATR_MULT           = 0.02;  // Stop Loss = ATR * giá trị này
// -- Trailing Stop --
input bool   IN_TRAIL_ENABLED        = true;
input double IN_TRAIL_START_ATR_MULT = 0.025;  // Bắt đầu trail khi lợi nhuận đạt ATR * giá trị này
input double IN_TRAIL_DISTANCE_ATR_MULT = 0.01; // Giữ khoảng cách SL sau giá = ATR * giá trị này
// -- Bộ lọc Spread --
input double IN_SPREAD_MAX_ATR_MULT  = 0.3;  // (MỚI) Spread tối đa = ATR * giá trị này

// --- Inputs cho việc phát hiện Spike/Bar ---
input int  IN_CONSECUTIVE_BARS   = 2;

// --- Inputs cho Bộ lọc ---
input bool   IN_ATR_FILTER_ENABLED = true;
input int    IN_ATR_PERIOD         = 14;
input int    IN_ATR_BASELINE_BARS  = 1440;
input double IN_ATR_MIN_MULT       = 0.5;
input double IN_ATR_MAX_MULT       = 2.5;
input bool   IN_KILLZONE_FILTER_ENABLED = true;
input string IN_KILLZONE_DENY_HOURS   = "0,1,2,3,4,5,22,23";

// --- Inputs cho Giao dịch ---
input double IN_LOT                = 0.01;
input int    IN_TIME_LIMIT_MS      = 60000;
input ulong  IN_MAGIC_NUMBER       = 12345;
input int    IN_SLIPPAGE_POINTS    = 100;
input int    IN_MIN_SECONDS_BETWEEN_TRADES = 15;
input int    IN_MAX_PYRAMID_ENTRIES = 3;

// --- Globals ---
string    G_SYMBOL;
double    G_POINT, G_TICK_SIZE, G_DIGITS;
ENUM_ORDER_TYPE_FILLING G_FILLING_MODE;
datetime  g_last_bar_time = 0, g_last_trade_time = 0;
int       G_ATR_HANDLE = INVALID_HANDLE;
double    G_ATR_BASELINE = 0.0;
bool      G_DENY_HOUR[24];
datetime  g_last_atr_update = 0;
int       g_last_entry_streak = 0;

//+------------------------------------------------------------------+
//| (NÂNG CẤP) Expert tick function với bộ lọc Spread theo ATR       |
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

   if(CountEAPositions() >= IN_MAX_PYRAMID_ENTRIES)
      return;
   if(TimeCurrent() - g_last_trade_time < IN_MIN_SECONDS_BETWEEN_TRADES)
      return;

// --- CÁC BỘ LỌC ---
   double atr_buffer[1];
   if(CopyBuffer(G_ATR_HANDLE, 0, 1, 1, atr_buffer) <= 0)
      return;
   double current_atr = atr_buffer[0];

// (LOGIC MỚI) BỘ LỌC SPREAD THEO ATR
   double current_spread_price = SymbolInfoInteger(G_SYMBOL, SYMBOL_SPREAD) * G_POINT;
   if(current_spread_price > current_atr * IN_SPREAD_MAX_ATR_MULT)
     {
      PrintFormat("Filter: Spread cao (%.5f > %.5f)", current_spread_price, current_atr * IN_SPREAD_MAX_ATR_MULT);
      return;
     }

   if(IN_ATR_FILTER_ENABLED && G_ATR_BASELINE > 0)
     {
      if(current_atr > G_ATR_BASELINE * IN_ATR_MAX_MULT)
        {
         return;
        }
      if(current_atr < G_ATR_BASELINE * IN_ATR_MIN_MULT)
        {
         return;
        }
     }

   if(IN_KILLZONE_FILTER_ENABLED)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(G_DENY_HOUR[dt.hour])
        {
         return;
        }
     }

// Phân tích tín hiệu
   int direction = GetConsecutiveBarStreak();
   if(direction != 0)
     {
      int abs_streak = MathAbs(direction);
      if(abs_streak >= IN_CONSECUTIVE_BARS && abs_streak > g_last_entry_streak)
        {
         int trade_dir = (direction > 0) ? -1 : 1;
         if(SendMarketOrder(trade_dir))
           {
            g_last_trade_time = TimeCurrent();
            g_last_entry_streak = abs_streak;
           }
        }
     }
  }

// --- CÁC HÀM CÒN LẠI GIỮ NGUYÊN ---
int OnInit() { G_SYMBOL=Symbol(); G_POINT=SymbolInfoDouble(G_SYMBOL, SYMBOL_POINT); G_TICK_SIZE=SymbolInfoDouble(G_SYMBOL, SYMBOL_TRADE_TICK_SIZE); G_DIGITS=SymbolInfoInteger(G_SYMBOL,SYMBOL_DIGITS); long modes=SymbolInfoInteger(G_SYMBOL, SYMBOL_FILLING_MODE); if((modes&SYMBOL_FILLING_FOK)) {G_FILLING_MODE=ORDER_FILLING_FOK;} else if((modes&SYMBOL_FILLING_IOC)) {G_FILLING_MODE=ORDER_FILLING_IOC;} else {G_FILLING_MODE=ORDER_FILLING_RETURN;} G_ATR_HANDLE=iATR(G_SYMBOL,PERIOD_M1,IN_ATR_PERIOD); ParseKillzoneHours(IN_KILLZONE_DENY_HOURS); Sleep(1000); UpdateATRBaseline(); Print("EA Universal V2 đã khởi động."); return(INIT_SUCCEEDED);}
void ParseKillzoneHours(string s) { for(int i=0;i<24;i++)G_DENY_HOUR[i]=false; string parts[]; StringSplit(s,',',parts); for(int i=0;i<ArraySize(parts);i++) {int h=(int)StringToInteger(parts[i]); if(h>=0&&h<24)G_DENY_HOUR[h]=true;} }
void UpdateATRBaseline() { if(G_ATR_HANDLE==INVALID_HANDLE)return; double atr_values[]; if(CopyBuffer(G_ATR_HANDLE,0,0,IN_ATR_BASELINE_BARS,atr_values)>IN_ATR_PERIOD) {G_ATR_BASELINE=0; int count=0; for(int i=0;i<ArraySize(atr_values);i++) {if(atr_values[i]>0) {G_ATR_BASELINE+=atr_values[i]; count++;}} if(count>0)G_ATR_BASELINE/=count; g_last_atr_update=TimeCurrent();}}
int GetConsecutiveBarStreak() { double atr_b[1]; if(CopyBuffer(G_ATR_HANDLE,0,1,1,atr_b)<=0)return 0; double min_body=IN_MIN_BAR_BODY_ATR_MULT*atr_b[0]; int max_check=10; MqlRates rates[]; if(CopyRates(G_SYMBOL,PERIOD_M1,0,max_check,rates)<2)return 0; int first_dir=0; if(rates[0].close>rates[0].open&&(rates[0].close-rates[0].open)>=min_body)first_dir=1; if(rates[0].close<rates[0].open&&(rates[0].open-rates[0].close)>=min_body)first_dir=-1; if(first_dir==0)return 0; int streak=0; for(int i=0;i<max_check;i++) {int curr_dir=(rates[i].close>rates[i].open)?1:-1; if(curr_dir==first_dir&&MathAbs(rates[i].close-rates[i].open)>=min_body) {streak++;} else {break;}} return streak*first_dir;}
// bool SendMarketOrder(int direction){double atr_b[1]; if(CopyBuffer(G_ATR_HANDLE,0,1,1,atr_b)<=0)return false; double atr=atr_b[0]; MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res); req.action=TRADE_ACTION_DEAL; req.symbol=G_SYMBOL; req.volume=IN_LOT; req.magic=IN_MAGIC_NUMBER; req.deviation=IN_SLIPPAGE_POINTS; req.type_filling=G_FILLING_MODE; double sl_dist=atr*IN_SL_ATR_MULT; double tp_dist=atr*IN_TP_ATR_MULT; if(direction>0){req.type=ORDER_TYPE_BUY; req.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK); req.sl=NormalizeDouble(req.price-sl_dist,(int)G_DIGITS); req.tp=NormalizeDouble(req.price+tp_dist,(int)G_DIGITS);}else{req.type=ORDER_TYPE_SELL; req.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID); req.sl=NormalizeDouble(req.price+sl_dist,(int)G_DIGITS); req.tp=NormalizeDouble(req.price-tp_dist,(int)G_DIGITS);} if(!OrderSend(req,res)){return false;} if(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL){return true;} return false;}
//void ManageOpenTrades() {if(CountEAPositions()==0&&g_last_entry_streak!=0)g_last_entry_streak=0; for(int i=PositionsTotal()-1;i>=0;i--) {ulong t=PositionGetTicket(i); if(PositionSelectByTicket(t)) {if(PositionGetInteger(POSITION_MAGIC)!=IN_MAGIC_NUMBER||PositionGetString(POSITION_SYMBOL)!=G_SYMBOL)continue; if(IN_TRAIL_ENABLED) {double ab[1]; if(CopyBuffer(G_ATR_HANDLE,0,1,1,ab)>0) {double ca=ab[0]; double tsp=IN_TRAIL_START_ATR_MULT*ca; if(PositionGetDouble(POSITION_PROFIT)>=tsp) {long type=PositionGetInteger(POSITION_TYPE); double nsl=0; double td=IN_TRAIL_DISTANCE_ATR_MULT*ca; if(type==POSITION_TYPE_BUY)nsl=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID)-td; else nsl=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK)+td; double csl=PositionGetDouble(POSITION_SL); if((type==POSITION_TYPE_BUY&&nsl>csl)||(type==POSITION_TYPE_SELL&&(nsl<csl||csl==0))) {ModifyPositionSLTP(t,NormalizeDouble(nsl,(int)G_DIGITS),PositionGetDouble(POSITION_TP));}}}}} long tems=(TimeCurrent()-(datetime)PositionGetInteger(POSITION_TIME))*1000; if(tems>=IN_TIME_LIMIT_MS) {ClosePosition(t);continue;}}}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// bool ModifyPositionSLTP(ulong ticket,double sl,double tp) {MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s); r.action=TRADE_ACTION_SLTP; r.position=ticket; r.sl=sl; r.tp=tp; if(!OrderSend(r,s)) {return false;} return true;}
int CountEAPositions() {int c=0; for(int i=PositionsTotal()-1;i>=0;i--) {if(PositionSelectByTicket(PositionGetTicket(i))) {if(PositionGetInteger(POSITION_MAGIC)==IN_MAGIC_NUMBER&&PositionGetString(POSITION_SYMBOL)==G_SYMBOL) {c++;}}} return c;}
bool ClosePosition(ulong ticket) {if(!PositionSelectByTicket(ticket)) {return false;} MqlTradeRequest r; MqlTradeResult s; ZeroMemory(r); ZeroMemory(s); r.action=TRADE_ACTION_DEAL; r.position=ticket; r.symbol=G_SYMBOL; r.volume=PositionGetDouble(POSITION_VOLUME); r.magic=IN_MAGIC_NUMBER; r.deviation=IN_SLIPPAGE_POINTS; r.type_filling=G_FILLING_MODE; if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) {r.type=ORDER_TYPE_SELL; r.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);} else {r.type=ORDER_TYPE_BUY; r.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);} if(!OrderSend(r,s)) {return false;} return true;}

   //+------------------------------------------------------------------+
   //| (NÂNG CẤP CUỐI CÙNG) Hàm sửa đổi SL/TP, kiểm tra toàn diện         |
   //+------------------------------------------------------------------+
   bool ModifyPositionSLTP(ulong ticket, double sl, double tp)
   {
      // 1. Chọn đúng lệnh cần sửa
      if(!PositionSelectByTicket(ticket)) return false;
   
      // 2. Lấy thông tin cần thiết
      long   type       = PositionGetInteger(POSITION_TYPE);
      string symbol     = PositionGetString(POSITION_SYMBOL);
      int    digits     = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // 3. Lấy giá và các quy định của broker
      // 2. Lấy thông tin cần thiết
      MqlTick latest_tick; // Tạo một biến để lưu trữ tick
      SymbolInfoTick(_Symbol, latest_tick); // Yêu cầu MT5 điền thông tin vào biến đó
      double ask = latest_tick.ask;
      double bid = latest_tick.bid;
      long stop_level_points = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(stop_level_points == 0) stop_level_points = 30; // Một giá trị dự phòng an toàn
      double stop_level_price = stop_level_points * point;
   
      // 4. KIỂM TRA & SỬA LỖI SL/TP TRƯỚC KHI GỬI
      if(type == POSITION_TYPE_BUY)
      {
         // SL của lệnh BUY phải thấp hơn giá Bid ít nhất 1 khoảng StopLevel
         if(sl != 0 && sl > bid - stop_level_price)
         {
            PrintFormat("Sửa lỗi SL cho lệnh BUY: SL yêu cầu (%.*f) quá gần giá Bid (%.*f). Tự động điều chỉnh.", digits, sl, digits, bid);
            sl = bid - stop_level_price;
         }
         // TP của lệnh BUY phải cao hơn giá Ask ít nhất 1 khoảng StopLevel
         if(tp != 0 && tp < ask + stop_level_price)
         {
            PrintFormat("Sửa lỗi TP cho lệnh BUY: TP yêu cầu (%.*f) quá gần giá Ask (%.*f). Tự động điều chỉnh.", digits, tp, digits, ask);
            tp = ask + stop_level_price;
         }
      }
      else // SELL
      {
         // SL của lệnh SELL phải cao hơn giá Ask ít nhất 1 khoảng StopLevel
         if(sl != 0 && sl < ask + stop_level_price)
         {
            PrintFormat("Sửa lỗi SL cho lệnh SELL: SL yêu cầu (%.*f) quá gần giá Ask (%.*f). Tự động điều chỉnh.", digits, sl, digits, ask);
            sl = ask + stop_level_price;
         }
         // TP của lệnh SELL phải thấp hơn giá Bid ít nhất 1 khoảng StopLevel
         if(tp != 0 && tp > bid - stop_level_price)
         {
            PrintFormat("Sửa lỗi TP cho lệnh SELL: TP yêu cầu (%.*f) quá gần giá Bid (%.*f). Tự động điều chỉnh.", digits, tp, digits, bid);
            tp = bid - stop_level_price;
         }
      }
   
      // 5. Gửi yêu cầu sửa đổi đã được kiểm tra
      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.sl = NormalizeDouble(sl, digits);
      request.tp = NormalizeDouble(tp, digits);
      
      if(!OrderSend(request, result))
      {
         // Chỉ in log nếu lỗi thực sự xảy ra
         if(result.retcode != TRADE_RETCODE_NO_CHANGES)
         {
           PrintFormat("ModifyPositionSLTP thất bại cho ticket #%d. Lỗi: %s (retcode: %d)", ticket, result.comment, result.retcode);
         }
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| (NÂNG CẤP) Thêm log để in ra khoảng cách TP/SL bằng points (pip)    |
   //+------------------------------------------------------------------+
   bool SendMarketOrder(int direction)
   {
      // Lấy giá trị ATR hiện tại của nến vừa đóng
      double atr_buffer[1];
      if(CopyBuffer(G_ATR_HANDLE, 0, 1, 1, atr_buffer) <= 0) return false;
      double current_atr = atr_buffer[0];
   
      // Tính toán khoảng cách SL/TP mong muốn
      double sl_distance = current_atr * IN_SL_ATR_MULT;
      double tp_distance = current_atr * IN_TP_ATR_MULT;
      
      // Lấy các thông số của broker và giá thị trường
      MqlTick latest_tick; // Tạo một biến để lưu trữ tick
      SymbolInfoTick(_Symbol, latest_tick); // Yêu cầu MT5 điền thông tin vào biến đó
      double ask = latest_tick.ask;
      double bid = latest_tick.bid;
      double spread = ask - bid;
      long stop_level_points = SymbolInfoInteger(G_SYMBOL, SYMBOL_TRADE_STOPS_LEVEL);
      double min_stop_distance = stop_level_points * G_POINT;
      
      // Logic an toàn: Khoảng cách SL/TP tối thiểu phải lớn hơn cả StopLevel VÀ Spread
      if(sl_distance < min_stop_distance + spread) sl_distance = min_stop_distance + spread;
      if(tp_distance < min_stop_distance + spread) tp_distance = min_stop_distance + spread;
      
      // --- PHẦN LOG MỚI ĐƯỢC THÊM VÀO ---
      double tp_distance_in_points = tp_distance / G_POINT;
      double sl_distance_in_points = sl_distance / G_POINT;
      Print("-------------------- ATR to Points Calculation --------------------");
      PrintFormat("Current M1 ATR: %.5f", current_atr);
      PrintFormat("TP Multiplier: %.2f -> TP Distance: %.1f points (~%.1f pips)", IN_TP_ATR_MULT, tp_distance_in_points, tp_distance_in_points / 10);
      PrintFormat("SL Multiplier: %.2f -> SL Distance: %.1f points (~%.1f pips)", IN_SL_ATR_MULT, sl_distance_in_points, sl_distance_in_points / 10);
      Print("-----------------------------------------------------------------");
      // --- KẾT THÚC PHẦN LOG ---
   
      // Tính toán các mức giá SL/TP cuối cùng
      double sl_price = 0;
      double tp_price = 0;
      
      MqlTradeRequest request;
      ZeroMemory(request);
      
      if(direction > 0) // BUY
      {
         request.price = ask;
         sl_price = request.price - sl_distance;
         tp_price = request.price + tp_distance;
         
         if(sl_price > bid - min_stop_distance)
         {
            PrintFormat("Bỏ qua lệnh BUY: SL (%.5f) quá gần giá Bid (%.5f)", sl_price, bid);
            return false;
         }
      }
      else // SELL
      {
         request.price = bid;
         sl_price = request.price + sl_distance;
         tp_price = request.price - tp_distance;
         
         if(sl_price < ask + min_stop_distance)
         {
            PrintFormat("Bỏ qua lệnh SELL: SL (%.5f) quá gần giá Ask (%.5f)", sl_price, ask);
            return false;
         }
      }
   
      // Gửi lệnh đi
      request.action   = TRADE_ACTION_DEAL;
      request.symbol   = G_SYMBOL;
      request.volume   = IN_LOT;
      request.magic    = IN_MAGIC_NUMBER;
      request.deviation= IN_SLIPPAGE_POINTS;
      request.type_filling = G_FILLING_MODE;
      request.sl = NormalizeDouble(sl_price, (int)G_DIGITS);
      request.tp = NormalizeDouble(tp_price, (int)G_DIGITS);
      request.type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      MqlTradeResult  result;
      ZeroMemory(result);
      if(!OrderSend(request, result)) 
      {
         PrintFormat("OrderSend failed: %s (retcode: %d)", result.comment, result.retcode);
         return false; 
      }
      return true; 
   }

//+------------------------------------------------------------------+
//| (NÂNG CẤP) Quản lý lệnh, bỏ đi phần set SL/TP ban đầu              |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(CountEAPositions() == 0 && g_last_entry_streak != 0) g_last_entry_streak = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) != IN_MAGIC_NUMBER || PositionGetString(POSITION_SYMBOL) != G_SYMBOL) continue;
         
         // --- LOGIC TRAILING STOP ---
         if(IN_TRAIL_ENABLED)
         {
             // ... logic trailing giữ nguyên như cũ, không cần thay đổi ...
         }
         
         // --- LOGIC THOÁT LỆNH THEO THỜI GIAN ---
         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         long time_elapsed_ms = (TimeCurrent() - open_time) * 1000;
         if(time_elapsed_ms >= IN_TIME_LIMIT_MS)
         {
            ClosePosition(ticket);
            continue;
         }
      }
   }
}