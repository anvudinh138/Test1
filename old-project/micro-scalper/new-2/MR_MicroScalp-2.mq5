//+------------------------------------------------------------------+
//|                        MR_MicroScalp_Final_Trailing.mq5            |
//|         Phiên bản Hoàn thiện + Trailing Stop                      |
//+------------------------------------------------------------------+
#property strict
#property description "Phiên bản cuối cùng với đầy đủ bộ lọc và Trailing Stop."

// --- Inputs cho việc phát hiện Spike/Bar ---
input int  IN_CONSECUTIVE_BARS   = 2;
input int  IN_MIN_BAR_BODY_TICKS = 10;

// --- (MỚI) Inputs cho Trailing Stop ---
input bool IN_TRAIL_ENABLED        = true;   // Bật/tắt Trailing Stop
input int  IN_TRAIL_START_TICKS    = 20;     // Bắt đầu trail khi lợi nhuận đạt số ticks này
input int  IN_TRAIL_DISTANCE_TICKS = 10;     // Giữ khoảng cách SL phía sau giá

// --- Inputs cho Bộ lọc ---
input int    IN_SPREAD_MAX_TICKS   = 120;
input bool   IN_ATR_FILTER_ENABLED = true;
input int    IN_ATR_PERIOD         = 14;
input int    IN_ATR_BASELINE_BARS  = 1440;
input double IN_ATR_MIN_MULT       = 0.5;
input double IN_ATR_MAX_MULT       = 2.5;
input bool   IN_KILLZONE_FILTER_ENABLED = true;
input string IN_KILLZONE_DENY_HOURS   = "0,1,2,3,4,5,22,23";

// --- Inputs cho Giao dịch ---
input double IN_LOT                = 0.01;
input int    IN_TP_TICKS           = 40;     
input int    IN_SL_TICKS           = 15;     
input int    IN_TIME_LIMIT_MS      = 60000;  
input ulong  IN_MAGIC_NUMBER       = 12345;  
input int    IN_SLIPPAGE_POINTS    = 100;    
input int    IN_MIN_SECONDS_BETWEEN_TRADES = 15;
input int    IN_MAX_PYRAMID_ENTRIES = 3;

// --- Globals ---
string    G_SYMBOL;
double    G_POINT, G_TICK_SIZE, G_TICK_VALUE; 
ENUM_ORDER_TYPE_FILLING G_FILLING_MODE;
datetime  g_last_bar_time = 0, g_last_trade_time = 0;
int       G_ATR_HANDLE = INVALID_HANDLE;
double    G_ATR_BASELINE = 0.0;
bool      G_DENY_HOUR[24];
datetime  g_last_atr_update = 0;
int       g_last_entry_streak = 0;

//+------------------------------------------------------------------+
//| (MỚI) Hàm sửa đổi SL/TP cho một lệnh                              |
//+------------------------------------------------------------------+
bool ModifyPositionSLTP(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = sl;
   request.tp = tp;
   
   if(!OrderSend(request, result))
   {
      PrintFormat("ModifyPositionSLTP failed for ticket #%d. Error: %d", ticket, GetLastError());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| (NÂNG CẤP) Quản lý lệnh, thêm logic Trailing Stop                 |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(CountEAPositions() == 0 && g_last_entry_streak != 0)
   {
      Print("Tất cả lệnh đã đóng. Reset bộ đếm chuỗi Pyramid.");
      g_last_entry_streak = 0;
   }

   double target_profit_usd = IN_TP_TICKS * G_TICK_VALUE;
   double target_loss_usd = -IN_SL_TICKS * G_TICK_VALUE;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) != IN_MAGIC_NUMBER || PositionGetString(POSITION_SYMBOL) != G_SYMBOL) continue;
         
         double current_profit = PositionGetDouble(POSITION_PROFIT);
         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         long type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

         // --- LOGIC TRAILING STOP ---
         if(IN_TRAIL_ENABLED)
         {
            double profit_in_ticks = 0;
            if(type == POSITION_TYPE_BUY)
               profit_in_ticks = (SymbolInfoDouble(G_SYMBOL, SYMBOL_BID) - open_price) / G_TICK_SIZE;
            else
               profit_in_ticks = (open_price - SymbolInfoDouble(G_SYMBOL, SYMBOL_ASK)) / G_TICK_SIZE;
               
            if(profit_in_ticks >= IN_TRAIL_START_TICKS)
            {
               double new_sl_price = 0;
               if(type == POSITION_TYPE_BUY)
                  new_sl_price = SymbolInfoDouble(G_SYMBOL, SYMBOL_BID) - IN_TRAIL_DISTANCE_TICKS * G_TICK_SIZE;
               else
                  new_sl_price = SymbolInfoDouble(G_SYMBOL, SYMBOL_ASK) + IN_TRAIL_DISTANCE_TICKS * G_TICK_SIZE;
                  
               double current_sl = PositionGetDouble(POSITION_SL);
               
               // Chỉ dời SL nếu SL mới tốt hơn SL cũ
               if( (type == POSITION_TYPE_BUY && new_sl_price > current_sl) || 
                   (type == POSITION_TYPE_SELL && (new_sl_price < current_sl || current_sl == 0)) )
               {
                  if(ModifyPositionSLTP(ticket, new_sl_price, PositionGetDouble(POSITION_TP)))
                  {
                     PrintFormat("Trailing Stop moved for #%d to %.5f", ticket, new_sl_price);
                  }
               }
            }
         }
         
         // --- LOGIC THOÁT LỆNH CỐ ĐỊNH ---
         if(current_profit >= target_profit_usd) { ClosePosition(ticket); continue; }
         if(current_profit <= target_loss_usd) { ClosePosition(ticket); continue; }
         long time_elapsed_ms = (TimeCurrent() - open_time) * 1000;
         if(time_elapsed_ms >= IN_TIME_LIMIT_MS) { ClosePosition(ticket); continue; }
      }
   }
}

// --- CÁC HÀM CÒN LẠI GIỮ NGUYÊN ---
int OnInit() { G_SYMBOL=Symbol(); G_POINT=SymbolInfoDouble(G_SYMBOL, SYMBOL_POINT); G_TICK_SIZE=SymbolInfoDouble(G_SYMBOL, SYMBOL_TRADE_TICK_SIZE); G_TICK_VALUE=SymbolInfoDouble(G_SYMBOL, SYMBOL_TRADE_TICK_VALUE); long modes=SymbolInfoInteger(G_SYMBOL, SYMBOL_FILLING_MODE); if((modes&SYMBOL_FILLING_FOK)){G_FILLING_MODE=ORDER_FILLING_FOK;}else if((modes&SYMBOL_FILLING_IOC)){G_FILLING_MODE=ORDER_FILLING_IOC;}else{G_FILLING_MODE=ORDER_FILLING_RETURN;} G_ATR_HANDLE=iATR(G_SYMBOL,PERIOD_M1,IN_ATR_PERIOD); ParseKillzoneHours(IN_KILLZONE_DENY_HOURS); Sleep(1000); UpdateATRBaseline(); Print("EA Trailing Stop đã khởi động."); return(INIT_SUCCEEDED);}
void OnTick(){ManageOpenTrades(); datetime cbt=(datetime)SeriesInfoInteger(G_SYMBOL,PERIOD_M1,SERIES_LASTBAR_DATE); if(cbt==g_last_bar_time)return; g_last_bar_time=cbt; if((int)g_last_bar_time%(60*60)==0&&TimeCurrent()-g_last_atr_update>60)UpdateATRBaseline(); if(CountEAPositions()>=IN_MAX_PYRAMID_ENTRIES)return; if(TimeCurrent()-g_last_trade_time<IN_MIN_SECONDS_BETWEEN_TRADES)return; double st=SymbolInfoInteger(G_SYMBOL,SYMBOL_SPREAD)*G_POINT/G_TICK_SIZE; if(st>IN_SPREAD_MAX_TICKS)return; if(IN_ATR_FILTER_ENABLED&&G_ATR_BASELINE>0){double ab[1]; if(CopyBuffer(G_ATR_HANDLE,0,1,1,ab)>0){double ca=ab[0]; if(ca>G_ATR_BASELINE*IN_ATR_MAX_MULT)return; if(ca<G_ATR_BASELINE*IN_ATR_MIN_MULT)return;}} if(IN_KILLZONE_FILTER_ENABLED){MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); if(G_DENY_HOUR[dt.hour])return;} int dir=GetConsecutiveBarStreak(); if(dir!=0){int abs_streak=MathAbs(dir); if(abs_streak>=IN_CONSECUTIVE_BARS&&abs_streak>g_last_entry_streak){int trade_dir=(dir>0)?-1:1; if(SendMarketOrder(trade_dir)){g_last_trade_time=TimeCurrent(); g_last_entry_streak=abs_streak;}}}}
void ParseKillzoneHours(string s) { for(int i=0;i<24;i++)G_DENY_HOUR[i]=false; string parts[]; StringSplit(s,',',parts); for(int i=0;i<ArraySize(parts);i++){int h=(int)StringToInteger(parts[i]); if(h>=0&&h<24)G_DENY_HOUR[h]=true;} }
void UpdateATRBaseline() { if(G_ATR_HANDLE==INVALID_HANDLE)return; double atr_values[]; if(CopyBuffer(G_ATR_HANDLE,0,0,IN_ATR_BASELINE_BARS,atr_values)>IN_ATR_PERIOD){G_ATR_BASELINE=0; int count=0; for(int i=0;i<ArraySize(atr_values);i++){if(atr_values[i]>0){G_ATR_BASELINE+=atr_values[i]; count++;}} if(count>0)G_ATR_BASELINE/=count; g_last_atr_update=TimeCurrent();}}
int GetConsecutiveBarStreak() { int max_check=10; MqlRates rates[]; if(CopyRates(G_SYMBOL,PERIOD_M1,0,max_check,rates)<2)return 0; int first_dir=0; if(rates[0].close>rates[0].open&&(rates[0].close-rates[0].open)/G_POINT>=IN_MIN_BAR_BODY_TICKS)first_dir=1; if(rates[0].close<rates[0].open&&(rates[0].open-rates[0].close)/G_POINT>=IN_MIN_BAR_BODY_TICKS)first_dir=-1; if(first_dir==0)return 0; int streak=0; for(int i=0;i<max_check;i++){double body=MathAbs(rates[i].close-rates[i].open)/G_POINT; int curr_dir=(rates[i].close>rates[i].open)?1:-1; if(curr_dir==first_dir&&body>=IN_MIN_BAR_BODY_TICKS){streak++;}else{break;}} return streak*first_dir;}
int CountEAPositions() { int count=0; for(int i=PositionsTotal()-1;i>=0;i--){if(PositionSelectByTicket(PositionGetTicket(i))){if(PositionGetInteger(POSITION_MAGIC)==IN_MAGIC_NUMBER&&PositionGetString(POSITION_SYMBOL)==G_SYMBOL){count++;}}} return count;}
bool SendMarketOrder(int direction) { MqlTradeRequest request; MqlTradeResult result; ZeroMemory(request); ZeroMemory(result); request.action=TRADE_ACTION_DEAL; request.symbol=G_SYMBOL; request.volume=IN_LOT; request.magic=IN_MAGIC_NUMBER; request.deviation=IN_SLIPPAGE_POINTS; request.type_filling=G_FILLING_MODE; if(direction > 0){request.type=ORDER_TYPE_BUY; request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);}else{request.type=ORDER_TYPE_SELL; request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);} if(!OrderSend(request,result)){return false;} if(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_DONE_PARTIAL){return true;}else{return false;} }
bool ClosePosition(ulong ticket) { if(!PositionSelectByTicket(ticket)){return false;} MqlTradeRequest request; MqlTradeResult result; ZeroMemory(request); ZeroMemory(result); request.action=TRADE_ACTION_DEAL; request.position=ticket; request.symbol=G_SYMBOL; request.volume=PositionGetDouble(POSITION_VOLUME); request.magic=IN_MAGIC_NUMBER; request.deviation=IN_SLIPPAGE_POINTS; request.type_filling=G_FILLING_MODE; if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){request.type=ORDER_TYPE_SELL; request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);}else{request.type=ORDER_TYPE_BUY; request.price=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);} if(!OrderSend(request,result)){return false;} return true; }