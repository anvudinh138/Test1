//+------------------------------------------------------------------+
//|                                                 MR_MicroScalp.mq5 |
//|  Mean-Reversion Micro-Scalper for XAUUSD - Fixed lot 0.01         |
//|  - Entry: detect micro-spike and fade (counter-spike)            |
//|  - Exit: TP in ticks, time-limit in seconds, SL in ticks         |
//|  - Robust trade handling, logging, basic news placeholder        |
//|                                                                  |
//|  IMPORTANT: Calibrate parameters with tick-by-tick backtest.     |
//+------------------------------------------------------------------+
#property copyright "Generated"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade Trade;

//------------------------ Inputs --------------------------------------
input double   IN_LOT                    = 0.01;      // Fixed lot (will not auto-increase)
input int      IN_TP_TICKS               = 2;         // Take profit in ticks
input int      IN_SL_TICKS               = 6;         // Stop loss in ticks
input int      IN_TIME_LIMIT_SEC         = 12;        // Max trade lifetime in seconds
input int      IN_MAX_CONCURRENT         = 4;         // Max concurrent trades
input int      IN_SPREAD_MAX_TICKS       = 120;        // Max spread to allow new trade (XAU typically 112 tick)
input double   IN_VOLUME_MULT           = 1.5;        // Tick volume spike multiplier (reduced for more sensitivity)
input int      IN_SPIKE_TICKS            = 1;         // Min spike magnitude in ticks to consider (reduced for testing)
input int      IN_TICK_BUFFER            = 200;       // How many latest ticks to keep
input int      IN_CONSECUTIVE_LOSS_STOP  = 5;         // Stop EA after N consecutive losses
input int      IN_COOLDOWN_MIN           = 30;        // Minutes cooldown after stop
input double   IN_MAX_DAILY_LOSS_USD     = 1000.0;    // Max daily loss in USD
input bool     IN_ENABLE_NEWS_FILTER     = false;     // If true, EA will check news (placeholder)
input int      IN_NEWS_BEFORE_MIN        = 20;        // minutes before high-impact news to block
input int      IN_NEWS_AFTER_MIN         = 30;        // minutes after high-impact news to block
input int      IN_PING_MAX_MS            = 300;       // Max allowed ping (placeholder, user must implement env check)
input int      IN_LOG_FLUSH_EVERY        = 50;        // flush stats log every X trades
input bool     IN_DEBUG_MODE             = true;     // Enable debug logging for troubleshooting
input bool     IN_SIMPLE_MODE            = true;      // Use simplified spike detection (recommended for testing)

//------------------------ Globals -------------------------------------
string SYMBOL_NAME;
double TickSizeValue;
double TickValuePerPoint;
int    DigitsSymbol;
double PricePoint;                // tick price size
int    g_tickIndex = 0;
int    g_ticksStored = 0;

struct TickEntry {
   datetime time;
   double   bid;
   double   ask;
   double   price;    // mid or last
   double   tick_volume;  // Changed from ulong to double to avoid conversion warnings
};

TickEntry tickBuffer[];
double emaTickVol = 0.0;
double emaSpread  = 0.0;
double emaAlpha   = 0.2;

int consecutive_losses = 0;
datetime last_disable_time = 0;
double  daily_start_balance = 0.0;
double  session_max_balance = 0.0;
double  worst_drawdown = 0.0;
int     total_trades = 0;
int     filled_trades = 0;
double  total_slippage = 0.0;
double  total_pnl = 0.0;

string  log_filename = "mr_micro_scalper_log.csv";
int     log_handle = INVALID_HANDLE;
int     stats_since_flush = 0;

//------------------------ Utility functions ---------------------------
bool IsCoolingDown()
{
   if(last_disable_time==0) return(false);
   datetime now = TimeCurrent();
   if((now - last_disable_time) >= IN_COOLDOWN_MIN*60) {
      last_disable_time = 0;
      consecutive_losses = 0;
      return(false);
   }
   return(true);
}

double GetCurrentSpreadTicks()
{
   double bid = SymbolInfoDouble(SYMBOL_NAME,SYMBOL_BID);
   double ask = SymbolInfoDouble(SYMBOL_NAME,SYMBOL_ASK);
   if(bid==0 || ask==0) return(1000000);
   double spread = MathAbs(ask - bid);
   return(spread / PricePoint);
}

double GetTickValue()
{
   // SYMBOL_TRADE_TICK_VALUE might return contract-specific tick value; fallback compute approximate
   double val = SymbolInfoDouble(SYMBOL_NAME, SYMBOL_TRADE_TICK_VALUE);
   if(val>0) return(val);
   // approximation: contract size * tick size * point value (not precise for XAU on some brokers)
   double contract_size = SymbolInfoDouble(SYMBOL_NAME, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract_size==0) contract_size = 100.0;
   return(contract_size * PricePoint);
}

int CountOpenPositionsForSymbol()
{
   int cnt = 0;
   for(int i=0;i<PositionsTotal();i++){
      if(PositionGetSymbol(i)==SYMBOL_NAME) cnt++;
   }
   return(cnt);
}

void UpdateDailyTracking()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(daily_start_balance==0.0) {
      daily_start_balance = bal;
      session_max_balance = bal;
      worst_drawdown = 0.0;
   }
   if(bal > session_max_balance) session_max_balance = bal;
   double dd = session_max_balance - bal;
   if(dd > worst_drawdown) worst_drawdown = dd;
}

// placeholder: user should implement real ping check if available
int GetPingMs()
{
   // MQL5 doesn't provide direct network ping to broker; return small number so default doesn't block
   return(50);
}

// placeholder: news check - returns false by default (no news). If you want news filtering,
// implement this function to query external feed (via WebRequest or external DLL) and return true when blocking.
bool IsNewsNearby()
{
   if(!IN_ENABLE_NEWS_FILTER) return false;
   // No built-in calendar here; user can implement via WebRequest to a calendar API and cache events.
   // For safety, we return false to avoid blocking trades unless user implements.
   return(false);
}

// Logging
bool LogInit()
{
   // open for append
   if(log_handle==INVALID_HANDLE){
      log_handle = FileOpen(log_filename, FILE_WRITE|FILE_READ|FILE_ANSI|FILE_COMMON);
      if(log_handle==INVALID_HANDLE) {
         // try local folder
         log_handle = FileOpen(log_filename, FILE_WRITE|FILE_READ|FILE_ANSI);
      }
      if(log_handle==INVALID_HANDLE) {
         Print("Failed to open log file: ", log_filename);
         return(false);
      }
      // If file is newly created, write header
      ulong size = FileSize(log_handle);  // FileSize returns ulong
      if(size==0) {
         FileWrite(log_handle, "send_ts,exec_ts,latency_ms,direction,open_price,exec_price,spread_ticks,slippage_ticks,profit_usd,duration_s,error_code,comment");
         FileWrite(log_handle, ""); // newline
         FileFlush(log_handle);
      } else {
         // move to EOF to append
         FileSeek(log_handle, 0, SEEK_END);
      }
   }
   return(true);
}

void LogTradeRow(datetime send_ts, datetime exec_ts, int latency_ms, string direction, double open_price, double exec_price, double spread_ticks, double slippage_ticks, double profit_usd, int duration_s, int error_code, string comment)
{
   if(!LogInit()) return;
   FileWrite(log_handle,
             TimeToString(send_ts,TIME_DATE|TIME_SECONDS),
             TimeToString(exec_ts,TIME_DATE|TIME_SECONDS),
             latency_ms,
             direction,
             DoubleToString(open_price,DigitsSymbol),
             DoubleToString(exec_price,DigitsSymbol),
             DoubleToString(spread_ticks,2),
             DoubleToString(slippage_ticks,2),
             DoubleToString(profit_usd,2),
             duration_s,
             error_code,
             comment);
   FileWrite(log_handle, ""); // newline
   stats_since_flush++;
   if(stats_since_flush>=IN_LOG_FLUSH_EVERY) {
      FileFlush(log_handle);
      stats_since_flush = 0;
   }
}

//------------------------ Spike detection -----------------------------
bool DetectSpikeAndReject(int &out_direction)
{
   // Two modes: simple mode for testing, advanced mode for production
   // out_direction: +1 = buy (fade down-spike), -1 = sell (fade up-spike)
   
   // Need at least 3 ticks for analysis
   if(g_ticksStored < 3) return(false);
   
   if(IN_SIMPLE_MODE) {
      // SIMPLE MODE: Just detect any price movement > threshold
      // This is for testing to ensure EA generates trades
      
      int N = 2; // Look at last 2 ticks only
      double first_price = tickBuffer[(g_tickIndex - N + IN_TICK_BUFFER) % IN_TICK_BUFFER].price;
      double last_price  = tickBuffer[(g_tickIndex - 1 + IN_TICK_BUFFER) % IN_TICK_BUFFER].price;
      double delta = last_price - first_price;
      double delta_ticks = MathAbs(delta) / PricePoint;
      
      if(IN_DEBUG_MODE) {
         PrintFormat("Debug Simple: Price delta=%.5f (%.1f ticks), threshold=%d ticks", 
                     delta, delta_ticks, IN_SPIKE_TICKS);
      }
      
      if(delta_ticks >= IN_SPIKE_TICKS) {
         out_direction = (delta > 0) ? -1 : +1; // Fade the move
         if(IN_DEBUG_MODE) {
            PrintFormat("Debug Simple: Spike detected! Direction=%s, Delta=%.1f ticks", 
                        (out_direction>0)?"BUY":"SELL", delta_ticks);
         }
         return(true);
      }
      return(false);
   }
   
   // ADVANCED MODE: Original logic with rejection patterns
   // Need at least 4 ticks for analysis  
   if(g_ticksStored < 4) return(false);
   
   // Analyze last 3 ticks for micro-spike
   int N = 3;
   double first_price = tickBuffer[(g_tickIndex - N + IN_TICK_BUFFER) % IN_TICK_BUFFER].price;
   double last_price  = tickBuffer[(g_tickIndex - 1 + IN_TICK_BUFFER) % IN_TICK_BUFFER].price;
   double delta = last_price - first_price;
   double delta_ticks = MathAbs(delta) / PricePoint;
   
   // Check if movement exceeds minimum spike threshold
   if(delta_ticks < IN_SPIKE_TICKS) return(false);
   
   // Get current and previous tick for volume analysis
   TickEntry te_current = tickBuffer[(g_tickIndex - 1 + IN_TICK_BUFFER) % IN_TICK_BUFFER];
   TickEntry te_prev = tickBuffer[(g_tickIndex - 2 + IN_TICK_BUFFER) % IN_TICK_BUFFER];
   
   // Volume spike check - only if EMA is established
   if(emaTickVol > 0 && te_current.tick_volume < emaTickVol * IN_VOLUME_MULT) {
      if(IN_DEBUG_MODE) {
         PrintFormat("Debug Advanced: Volume too low: %.0f < %.0f (%.1fx)", 
                     te_current.tick_volume, emaTickVol * IN_VOLUME_MULT, IN_VOLUME_MULT);
      }
      return(false);
   }
   
   // Simplified rejection pattern - check if price momentum is slowing
   bool is_rejection = false;
   
   if(delta > 0) {
      // Up spike - check for rejection/stalling
      double current_spread = te_current.ask - te_current.bid;
      double prev_spread = te_prev.ask - te_prev.bid;
      
      if(te_current.ask <= te_prev.ask + PricePoint * 0.5 || current_spread > prev_spread * 1.2) {
         is_rejection = true;
      }
   } else {
      // Down spike - check for rejection/stalling  
      double current_spread = te_current.ask - te_current.bid;
      double prev_spread = te_prev.ask - te_prev.bid;
      
      if(te_current.bid >= te_prev.bid - PricePoint * 0.5 || current_spread > prev_spread * 1.2) {
         is_rejection = true;
      }
   }
   
   if(is_rejection) {
      out_direction = (delta > 0) ? -1 : +1; // Fade the spike
      if(IN_DEBUG_MODE) {
         PrintFormat("Debug Advanced: Rejection detected! Direction=%s, Delta=%.1f ticks", 
                     (out_direction>0)?"BUY":"SELL", delta_ticks);
      }
      return(true);
   }
   
   return(false);
}

//------------------------ Trading helpers ------------------------------
bool ClosePositionByTicket(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   string sym = PositionGetString(POSITION_SYMBOL);
   double vol = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  // Fixed: proper enum cast
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = sym;
   req.volume = vol;
   req.type = (type==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   req.price = (req.type==ORDER_TYPE_BUY)?SymbolInfoDouble(sym,SYMBOL_ASK):SymbolInfoDouble(sym,SYMBOL_BID);
   req.deviation = 50; // allow slippage in points (tune)
   
   // Auto-detect supported filling mode for the symbol
   int filling_mode = (int)SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
      req.type_filling = ORDER_FILLING_FOK;
   } else if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      req.type_filling = ORDER_FILLING_IOC;  
   } else {
      req.type_filling = ORDER_FILLING_RETURN; // fallback
   }
   
   req.type_time = ORDER_TIME_GTC;
   if(!OrderSend(req,res)) {
      PrintFormat("ClosePositionByTicket OrderSend failed, ret=%d", GetLastError());
      return(false);
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL) {  // Fixed: use TRADE_RETCODE_DONE_PARTIAL instead of non-existent DONE_REMAINDER
      PrintFormat("ClosePositionByTicket failed retcode=%u, comment=%s", res.retcode, res.comment);  // Fixed: use %u for uint
      return(false);
   }
   return(true);
}

bool SendMarketOrder(int direction, double lot, int &out_error_code, double &out_exec_price, ulong &out_order_ticket)
{
   out_error_code = 0;
   out_exec_price = 0;
   out_order_ticket = 0;
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = SYMBOL_NAME;
   req.volume = lot;
   req.type = (direction>0)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   req.price = (req.type==ORDER_TYPE_BUY)?SymbolInfoDouble(SYMBOL_NAME,SYMBOL_ASK):SymbolInfoDouble(SYMBOL_NAME,SYMBOL_BID);
   req.deviation = 50; // increased slippage allowance for XAU
   
   // Auto-detect supported filling mode for the symbol
   int filling_mode = (int)SymbolInfoInteger(SYMBOL_NAME, SYMBOL_FILLING_MODE);
   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
      req.type_filling = ORDER_FILLING_FOK;
      if(IN_DEBUG_MODE) Print("Debug: Using ORDER_FILLING_FOK");
   } else if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      req.type_filling = ORDER_FILLING_IOC;
      if(IN_DEBUG_MODE) Print("Debug: Using ORDER_FILLING_IOC");  
   } else {
      req.type_filling = ORDER_FILLING_RETURN; // fallback
      if(IN_DEBUG_MODE) Print("Debug: Using ORDER_FILLING_RETURN (fallback)");
   }
   
   req.type_time = ORDER_TIME_GTC;

   datetime send_ts = TimeCurrent();
   if(!OrderSend(req,res)) {
      out_error_code = GetLastError();
      PrintFormat("OrderSend low-level failed err=%d", out_error_code);
      return(false);
   }
   // handle retcodes
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL) {  // Fixed: use TRADE_RETCODE_DONE_PARTIAL
      out_exec_price = res.price;
      out_order_ticket = res.order;
      return(true);
   } else {
      out_error_code = (int)res.retcode;  // Fixed: explicit cast from uint to int
      PrintFormat("OrderSend retcode=%u comment=%s", res.retcode, res.comment);  // Fixed: use %u for uint
      return(false);
   }
}

//------------------------ Open/manage trades ---------------------------
void ManageOpenTrades()
{
   // iterate positions of this symbol
   int pos_total = PositionsTotal();
   for(int i = pos_total - 1; i >= 0; i--) {
    ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      string pos_sym = PositionGetString(POSITION_SYMBOL);
      if(pos_sym != SYMBOL_NAME) continue;
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double profit  = PositionGetDouble(POSITION_PROFIT);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  // Fixed: proper enum cast
      datetime t_open = (datetime)PositionGetInteger(POSITION_TIME);
      int duration = (int)(TimeCurrent() - t_open); // seconds

      // compute TP in price units
      double tp_price = (type==POSITION_TYPE_BUY) ? open_price + IN_TP_TICKS*PricePoint : open_price - IN_TP_TICKS*PricePoint;
      double sl_price = (type==POSITION_TYPE_BUY) ? open_price - IN_SL_TICKS*PricePoint : open_price + IN_SL_TICKS*PricePoint;

      double curr_price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(SYMBOL_NAME,SYMBOL_BID) : SymbolInfoDouble(SYMBOL_NAME,SYMBOL_ASK);

      bool must_close = false;

      // primary TP
      if((type==POSITION_TYPE_BUY && curr_price >= tp_price) || (type==POSITION_TYPE_SELL && curr_price <= tp_price)) must_close = true;

      // SL
      if((type==POSITION_TYPE_BUY && curr_price <= sl_price) || (type==POSITION_TYPE_SELL && curr_price >= sl_price)) must_close = true;

      // time-based exit
      if(duration >= IN_TIME_LIMIT_SEC) must_close = true;

      if(must_close) {
         double before_bal = AccountInfoDouble(ACCOUNT_BALANCE);
         bool closed = ClosePositionByTicket(ticket);
         double after_bal = AccountInfoDouble(ACCOUNT_BALANCE);
         double realized_profit = after_bal - before_bal;
         // update stats
         total_trades++;
         filled_trades++;
         total_pnl += realized_profit;
         if(realized_profit < 0) {
            consecutive_losses++;
         } else {
            consecutive_losses = 0;
         }
         UpdateDailyTracking();
         // log trade close
         LogTradeRow(t_open, TimeCurrent(), 0, (type==POSITION_TYPE_BUY)?"BUY":"SELL", open_price, curr_price, GetCurrentSpreadTicks(), 0.0, realized_profit, duration, 0, "closed_by_manager");
         // safety: check consecutive losses
         if(consecutive_losses >= IN_CONSECUTIVE_LOSS_STOP) {
            last_disable_time = TimeCurrent();
            Print("Consecutive loss stop reached. Cooling down for minutes: ", IN_COOLDOWN_MIN);
         }
         // check daily loss
         if((daily_start_balance - AccountInfoDouble(ACCOUNT_BALANCE)) >= IN_MAX_DAILY_LOSS_USD) {
            last_disable_time = TimeCurrent();
            Print("Max daily loss exceeded. EA disabled for cooldown.");
         }
      }
   }
}

//------------------------ OnTick main ---------------------------------
void OnTick()
{
   // basic symbol check
   if(SYMBOL_NAME == "") return;

   // fetch tick and push into buffer
   MqlTick mt;
   if(!SymbolInfoTick(SYMBOL_NAME, mt)) {
      Print("SymbolInfoTick failed for ", SYMBOL_NAME);
      return;
   }
   // maintain circular buffer
   if(ArraySize(tickBuffer) != IN_TICK_BUFFER) {
      ArrayResize(tickBuffer, IN_TICK_BUFFER);
      g_tickIndex = 0;
      g_ticksStored = 0;
   }
   TickEntry te;
   te.time = mt.time;
   te.bid = mt.bid;
   te.ask = mt.ask;
   te.price = (mt.bid + mt.ask) / 2.0;
   te.tick_volume = (double)mt.volume;  // Fixed: explicit cast from ulong to double

   tickBuffer[g_tickIndex] = te;
   g_tickIndex = (g_tickIndex + 1) % IN_TICK_BUFFER;
   if(g_ticksStored < IN_TICK_BUFFER) g_ticksStored++;

   // update EMAs
   if(emaTickVol <= 0) emaTickVol = te.tick_volume;
   else emaTickVol = emaAlpha * te.tick_volume + (1.0 - emaAlpha) * emaTickVol;

   double spread = MathAbs(te.ask - te.bid);
   double spread_ticks = spread / PricePoint;
   if(emaSpread <= 0) emaSpread = spread_ticks;
   else emaSpread = emaAlpha * spread_ticks + (1.0 - emaAlpha) * emaSpread;

   // update daily tracking
   UpdateDailyTracking();

   // checks: disabled or cooldown
   if(IsCoolingDown()) {
      if(IN_DEBUG_MODE) Print("Debug: EA in cooldown mode");
      return;
   }

   // basic health checks
   if(GetPingMs() > IN_PING_MAX_MS) {
      if(IN_DEBUG_MODE) PrintFormat("Debug: Ping too high: %d ms", GetPingMs());
      return;
   }
   if(IsNewsNearby()) {
      if(IN_DEBUG_MODE) Print("Debug: News filter blocking");
      return;
   }

   // prevent trading in weekend gaps or off market
   if(!SymbolInfoInteger(SYMBOL_NAME, SYMBOL_SELECT)) {
      if(IN_DEBUG_MODE) Print("Debug: Symbol not selected/available");
      return;
   }

   // manage existing trades
   ManageOpenTrades();

   // if too many concurrent trades, skip entry
   int current_positions = CountOpenPositionsForSymbol();
   if(current_positions >= IN_MAX_CONCURRENT) {
      if(IN_DEBUG_MODE) PrintFormat("Debug: Max concurrent trades reached: %d/%d", current_positions, IN_MAX_CONCURRENT);
      return;
   }

   // spread filter
   double current_spread = GetCurrentSpreadTicks();
   if(current_spread > IN_SPREAD_MAX_TICKS) {
      if(IN_DEBUG_MODE) PrintFormat("Debug: Spread too wide: %.1f > %d ticks", current_spread, IN_SPREAD_MAX_TICKS);
      return;
   }

   // more filters: ATR filter can be added here if needed (not implemented: requires M1 series ATR baseline)

   // detect spike
   int dir = 0;
   if(DetectSpikeAndReject(dir)) {
      // dir: +1 buy, -1 sell -> we enter counter spike => same sign as dir (buy to fade down spike)
      // final confirmation: volume and spread already checked in DetectSpike; proceed to send market order
      
      PrintFormat("Spike detected! Direction=%s, Spread=%.1f ticks, TickVol=%.0f, EMA_TickVol=%.0f", 
                  (dir>0)?"BUY":"SELL", GetCurrentSpreadTicks(), te.tick_volume, emaTickVol);
      
      int error_code = 0;
      double exec_price = 0;
      ulong order_ticket = 0;
      bool ok = SendMarketOrder(dir, IN_LOT, error_code, exec_price, order_ticket);
      datetime send_ts = TimeCurrent();
      datetime exec_ts = TimeCurrent();
      int latency_ms = 0;
      double slippage_ticks = 0;
      double spread_at_open = GetCurrentSpreadTicks();
      if(ok) {
         // log open
         LogTradeRow(send_ts, exec_ts, latency_ms, (dir>0)?"BUY":"SELL", te.price, exec_price, spread_at_open, slippage_ticks, 0.0, 0, 0, "opened");
         PrintFormat("Trade opened successfully! Ticket=%I64u, Price=%.5f", order_ticket, exec_price);
      } else {
         LogTradeRow(send_ts, exec_ts, latency_ms, (dir>0)?"BUY":"SELL", te.price, exec_price, spread_at_open, slippage_ticks, 0.0, 0, error_code, "open_failed");
         PrintFormat("Trade open failed! Error=%d", error_code);
      }
   }
}

//------------------------ OnInit / OnDeinit ----------------------------
int OnInit()
{
   SYMBOL_NAME = Symbol();
   DigitsSymbol = (int)SymbolInfoInteger(SYMBOL_NAME, SYMBOL_DIGITS);
   PricePoint = SymbolInfoDouble(SYMBOL_NAME, SYMBOL_POINT);
   TickSizeValue = SymbolInfoDouble(SYMBOL_NAME, SYMBOL_TRADE_TICK_SIZE);
   TickValuePerPoint = GetTickValue();

   // ensure tick buffer allocated
   ArrayResize(tickBuffer, IN_TICK_BUFFER);
   g_tickIndex = 0;
   g_ticksStored = 0;

   // init logging
   if(!LogInit()) {
      Print("Warning: LogInit failed. Logging disabled.");
   }

   // initial balance snapshot
   daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   session_max_balance = daily_start_balance;

   PrintFormat("MR_MicroScalp initialized for %s. Lot=%.2f TP=%d SL=%d TimeLimit=%ds", SYMBOL_NAME, IN_LOT, IN_TP_TICKS, IN_SL_TICKS, IN_TIME_LIMIT_SEC);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(log_handle != INVALID_HANDLE) {
      FileFlush(log_handle);
      FileClose(log_handle);
      log_handle = INVALID_HANDLE;
   }
   Print("MR_MicroScalp deinitialized.");
}

//------------------------ Helper: utility prints -----------------------
void PrintParams()
{
   PrintFormat("Params: LOT=%.2f TP=%d SL=%d TIME_LIMIT=%d MAX_CONCURRENT=%d SPREAD_MAX=%d", IN_LOT, IN_TP_TICKS, IN_SL_TICKS, IN_TIME_LIMIT_SEC, IN_MAX_CONCURRENT, IN_SPREAD_MAX_TICKS);
}
