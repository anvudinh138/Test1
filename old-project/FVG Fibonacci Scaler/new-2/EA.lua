//+------------------------------------------------------------------+
//|                                       FVG_Fibonacci_Scaler.mq5 |
//|                                  Copyright 2024, Gemini Project |
//|                        https://github.com/GoogleCloudPlatform |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini Project"
#property link      "https://github.com/GoogleCloudPlatform"
#property version   "1.20"
#property description "Giao dịch theo FVG và Fibonacci - Thêm Anchor TF và tùy chọn SL"

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

//--- Enum cho chế độ Stop Loss
enum ENUM_SL_MODE
{
   SL_AT_SWING,      // SL tại đỉnh/đáy Swing + padding (an toàn)
   SL_FROM_ENTRY_ATR // SL theo ATR từ điểm vào lệnh
};

//--- Các tham số đầu vào cho EA
input group           "QUẢN LÝ GIAO DỊCH"
input double          in_fixed_lot = 0.02;
input ulong           in_magic_number = 112233;
input int             in_slippage = 3;
input bool            in_allow_single_entry = true;

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

//--- Biến toàn cục
CTrade         trade;
int            h_atr_anchor; // Handle ATR cho Anchor TF
int            h_atr_chart;  // Handle ATR cho Chart TF

// Các biến trạng thái để quản lý logic
SwingStructure last_processed_swing;
double         pending_e2_price = 0;
string         pending_e2_comment = "";
bool           is_tp1_hit = false;
ulong          active_setup_ticket_e1 = 0;


//+------------------------------------------------------------------+
//| Hàm khởi tạo EA                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(in_magic_number);
   trade.SetDeviationInPoints(in_slippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   h_atr_anchor = iATR(_Symbol, in_anchor_tf, in_atr_period);
   if(h_atr_anchor == INVALID_HANDLE)
     {
      Print("Lỗi: Không thể tạo handle ATR cho Anchor TF.");
      return(INIT_FAILED);
     }
   h_atr_chart = iATR(_Symbol, _Period, in_atr_period);
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
   datetime current_time = iTime(_Symbol, _Period, 0);
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
   if(CopyRates(_Symbol, in_anchor_tf, 0, in_swing_bars + 2, rates) < in_swing_bars + 2) return;
      
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
   
   if (is_high_confluence && fvg_r4 != NULL && fvg_r5 != NULL)
   {
      PlaceTrade(current_swing, fvg_r4, fvg_r5, true, 4, 5);
   }
   else if (!is_high_confluence && fvg_r3 != NULL && fvg_r4 != NULL)
   {
      PlaceTrade(current_swing, fvg_r3, fvg_r4, true, 3, 4);
   }
   else if (in_allow_single_entry)
   {
      if(fvg_r5 != NULL) PlaceTrade(current_swing, fvg_r5, NULL, false, 5, 0);
      else if(fvg_r4 != NULL) PlaceTrade(current_swing, fvg_r4, NULL, false, 4, 0);
      else if(fvg_r3 != NULL) PlaceTrade(current_swing, fvg_r3, NULL, false, 3, 0);
   }

   delete fvg_list;
}

//+------------------------------------------------------------------+
//| Hàm đặt lệnh                                                     |
//+------------------------------------------------------------------+
void PlaceTrade(SwingStructure &swing, FairValueGap* fvg1, FairValueGap* fvg2, bool is_dual_entry, int range1, int range2)
{
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

   if(lot_size < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      
   if(!IsPriceValidForLimitOrder(entry_price_e1, swing.is_bullish_swing)) return;
      
   bool result = false;
   if(swing.is_bullish_swing)
   {
      result = trade.BuyLimit(lot_size, entry_price_e1, _Symbol, sl_price, tp_price, ORDER_TIME_GTC, 0, comment);
   }
   else
   {
      result = trade.SellLimit(lot_size, entry_price_e1, _Symbol, sl_price, tp_price, ORDER_TIME_GTC, 0, comment);
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
   
   for(int i = start_bar + 1; i < end_bar; i++)
   {
      if (i + 1 >= ArraySize(rates) || i - 1 < 0) continue;
       
      if(rates[i+1].high < rates[i-1].low)
      {
         double fvg_size = rates[i-1].low - rates[i+1].high;
         if(fvg_size >= min_fvg_size && swing.is_bullish_swing)
         {
            double fvg_mid_price = (rates[i-1].low + rates[i+1].high) / 2.0;
            double fifty_percent_level = swing.low_price + (swing.high_price - swing.low_price) * 0.5;
            if (fvg_mid_price < fifty_percent_level)
            {
               FairValueGap *fvg = new FairValueGap();
               fvg.high_price = rates[i-1].low;
               fvg.low_price = rates[i+1].high;
               fvg.bar_index = i;
               fvg_array.Add((CObject*)fvg);
            }
         }
      }
      
      if(rates[i+1].low > rates[i-1].high)
      {
         double fvg_size = rates[i+1].low - rates[i-1].high;
         if(fvg_size >= min_fvg_size && !swing.is_bullish_swing)
         {
            double fvg_mid_price = (rates[i+1].low + rates[i-1].high) / 2.0;
            double fifty_percent_level = swing.high_price - (swing.high_price - swing.low_price) * 0.5;
            if(fvg_mid_price > fifty_percent_level)
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
//| Tìm FVG trong một Range Fibonacci cụ thể                          |
//+------------------------------------------------------------------+
FairValueGap* FindFVGInRange(CArrayObj *list, int range_num, double range_top, double range_bottom)
{
   for(int i=0; i < list.Total(); i++)
   {
      FairValueGap* fvg = dynamic_cast<FairValueGap*>(list.At(i)); 
      if(fvg == NULL) continue;
      
      double fvg_mid_point = (fvg.high_price + fvg.low_price)/2.0;
      
      double lo = MathMin(range_top, range_bottom);
      double hi = MathMax(range_top, range_bottom);
      
      if(fvg_mid_point >= lo && fvg_mid_point <= hi)
      {
         return fvg;
      }
   }
   return NULL;
}

//+------------------------------------------------------------------+
//| Quản lý các giao dịch đang mở hoặc đang chờ                       |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
   if(pending_e2_price > 0 && CountMyPositions() == 1 && PositionGetTicket(0) == active_setup_ticket_e1)
   {
      if(PositionSelectByTicket(active_setup_ticket_e1))
      {
         double lot_size = NormalizeDouble(in_fixed_lot / 2.0, 2);
         if(lot_size < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
             lot_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

         long type = PositionGetInteger(POSITION_TYPE);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         if(IsPriceValidForLimitOrder(pending_e2_price, (type == POSITION_TYPE_BUY)))
         {
             if(type == POSITION_TYPE_BUY)
             {
                 if(trade.BuyLimit(lot_size, pending_e2_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, pending_e2_comment))
                 {
                    pending_e2_price = 0;
                    pending_e2_comment = "";
                 }
             }
             else if(type == POSITION_TYPE_SELL)
             {
                 if(trade.SellLimit(lot_size, pending_e2_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, pending_e2_comment))
                 {
                    pending_e2_price = 0;
                    pending_e2_comment = "";
                 }
             }
         } else {
             pending_e2_price = 0;
             pending_e2_comment = "";
         }
      }
   }
   
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
            
            if((type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= tp) ||
               (type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= tp))
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
      TrailStopLoss();
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
               request.symbol       = _Symbol;
               request.volume       = NormalizeDouble(close_vol, 2);
               request.magic        = in_magic_number;
               request.deviation    = in_slippage;
               
               ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               if(pos_type == POSITION_TYPE_BUY)
               {
                  request.type = ORDER_TYPE_SELL;
                  request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               }
               else if(pos_type == POSITION_TYPE_SELL)
               {
                  request.type = ORDER_TYPE_BUY;
                  request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
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
//| Trailing Stop Loss                                               |
//+------------------------------------------------------------------+
void TrailStopLoss()
{
   double atr_value = GetChartATR(1);
   if(atr_value == 0) return;
   double trail_distance = atr_value * in_trailing_stop_atr_factor;

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
            new_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trail_distance;
            if(new_sl > open_price && (new_sl > current_sl || current_sl == 0) )
            {
               trade.PositionModify(ticket, new_sl, tp);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            new_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trail_distance;
            if(new_sl < open_price && (new_sl < current_sl || current_sl == 0))
            {
               trade.PositionModify(ticket, new_sl, tp);
            }
         }
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
    SymbolInfoTick(_Symbol, tick);
    double stop_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

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

