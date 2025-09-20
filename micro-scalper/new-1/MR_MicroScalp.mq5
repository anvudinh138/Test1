//+------------------------------------------------------------------+
//| MR_MicroScalp.mq5                                               |
//| Mean-Reversion Micro-Scalper (MT5)                              |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

// Fallback defines for older terminals lacking these constants
#ifndef TRADE_RETCODE_TRADE_CONTEXT_BUSY
  #define TRADE_RETCODE_TRADE_CONTEXT_BUSY 10004
#endif


// Inputs
input double IN_LOT = 0.01;
input int    IN_TP_TICKS = 2;
input int    IN_SL_TICKS = 6;
input int    IN_TIME_LIMIT_MS = 12000;
input int    IN_MAX_CONCURRENT = 4;
input int    IN_SPREAD_MAX_TICKS = 130;
input double IN_SPREAD_MULT = 1.05;
input double IN_VOLUME_MULT = 3.0;
input int    IN_SPIKE_TICKS = 150;     // spike threshold in ticks (XAU ~0.3 USD)
input int    IN_CONSECUTIVE_LOSS_STOP = 5;
input int    IN_COOLDOWN_MIN = 30;
input double IN_MAX_DAILY_LOSS_USD = 1000.0;
input int    IN_PING_MAX_MS = 300;
input bool   IN_ENABLE_NEWS_FILTER = false;
input string IN_KILLZONE_DENY_HOURS = ""; // e.g. "0,1,2,3"
input int    IN_TICK_BUFFER = 200;
input int    IN_SEND_RETRIES = 3;
input int    IN_DEVIATION_POINTS = 50;
input bool   IN_ENABLE_TRAIL = false;
input int    IN_BE_TICKS = 2;
input int    IN_TRAIL_OFFSET_TICKS = 1;
input int    IN_LOG_FLUSH_EVERY = 500;
input bool   IN_DEBUG = false;
input int    IN_MIN_SECS_BETWEEN_OPENS = 120; // hard cooldown between entries
input int    IN_MIN_DISTANCE_TICKS = 150;     // minimum price distance from last entry
input bool   IN_ALLOW_MULTIDIRECTION = false; // allow both BUY and SELL concurrently
input bool   IN_REQUIRE_FLAT = true;          // require no open position to enter
input bool   IN_ONE_TRADE_PER_BAR = true;     // allow only one trade per M1 bar
input ENUM_TIMEFRAMES IN_ONE_TRADE_TF = PERIOD_M5; // timeframe for one-trade-per-bar
input int    IN_POST_CLOSE_COOLDOWN_SECS = 120; // block new entries after a close
input int    IN_TRACE_LEVEL = 2;              // 0=off,1=open/close,2+gate/skips
input int    IN_BLOCK_AFTER_FAIL_SECS = 60;    // cooldown after open failed
input int    IN_MAX_ORDERS_PER_MIN = 1;        // cap orders per minute
input int    IN_MIN_MSC_BETWEEN_SENDS = 1000;  // hard throttle by tick time (ms)
input int    IN_PRELOCK_SECS = 2;              // pre-lock seconds before sending
input int    IN_MAX_TRADES_TOTAL = 1;          // cap total trades this run (debug)
input int    IN_MAX_TRADES_PER_DAY = 1;        // cap trades per day

// ATR filter inputs
input int    IN_ATR_PERIOD = 14;
input double IN_ATR_MIN_MULT = 0.5;
input double IN_ATR_MAX_MULT = 2.0;
input int    IN_ATR_BASE_BARS = 1440; // M1 bars

// Globals
string  G_SYMBOL = "";
int     G_DIGITS = 0;
double  G_POINT = 0.0;
double  G_TICK_SIZE = 0.0;
double  G_TICK_VALUE = 0.0;

struct TickEntry { datetime t; double bid; double ask; double mid; double vol; };
TickEntry g_ticks[];
int g_tick_i = 0;
int g_tick_n = 0;

double g_ema_vol = 0.0;
double g_ema_spread = 0.0;
double g_alpha = 0.2;

bool g_deny_hour[24];

int    g_atr_handle = INVALID_HANDLE;
double g_atr_baseline = 0.0;
datetime g_last_atr_base_update = 0;

int     g_consecutive_losses = 0;
datetime g_last_disable_time = 0;
double  g_daily_start_balance = 0.0;
double  g_session_max_balance = 0.0;
double  g_worst_dd = 0.0;
int     g_total_trades = 0;
double  g_total_pnl = 0.0;
int     g_open_attempts = 0;
int     g_open_fills = 0;
double  g_slip_sum = 0.0;
datetime g_last_open_time = 0;
double   g_last_open_price = 0.0;
int      g_last_open_dir = 0; // +1 buy, -1 sell
datetime g_last_trade_bar_time = 0;
datetime g_last_close_time = 0;
datetime g_block_until = 0;
int      g_minute_key = -1;
int      g_minute_count = 0;
bool     g_sending = false;
datetime g_prelock_until = 0;
long     g_last_send_msc = 0;
int      g_total_opens = 0;
int      g_trades_today = 0;
int      g_today_ymd = -1;

// Trailing storage per position
ulong   g_tickets[64];
bool    g_be_armed[64];
int     g_trk_count = 0;

// Logging
int     g_log = INVALID_HANDLE;
string  g_log_file = "mr_micro_scalper_log.csv";
int     g_log_since_flush = 0;
int     g_decision_log = INVALID_HANDLE;
string  g_decision_file = "mr_micro_scalper_decisions.csv";

// Utils
int PingMs() { return 50; }

string Trim(string s) { StringTrimLeft(s); StringTrimRight(s); return s; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ParseKillzone(const string s)
  {
   for(int i=0;i<24;i++)
      g_deny_hour[i]=false;
   if(Trim(s)=="")
      return true;
   string parts[];
   int n=StringSplit(s,',',parts);
   for(int i=0;i<n;i++)
     {
      int h=(int)StringToInteger(Trim(parts[i]));
      if(h>=0 && h<24)
         g_deny_hour[h]=true;
     }
  return true;
  }

bool DecisionLogInit()
  {
   if(g_decision_log!=INVALID_HANDLE) return true;
   if(IN_TRACE_LEVEL<=0) return false;
   g_decision_log=FileOpen(g_decision_file,FILE_WRITE|FILE_READ|FILE_ANSI|FILE_COMMON);
   if(g_decision_log==INVALID_HANDLE)
      g_decision_log=FileOpen(g_decision_file,FILE_WRITE|FILE_READ|FILE_ANSI);
   if(g_decision_log==INVALID_HANDLE)
     {
      Print("DecisionLog open failed: ",g_decision_file);
      return false;
     }
   ulong sz=FileSize(g_decision_log);
   if(sz==0)
     {
      FileWrite(g_decision_log,
                "ts,event,reason,bid,ask,spread_ticks,ema_spread,tick_vol,ema_vol,dticks,thresh,dir,open_now,has_dir,require_flat,allow_multidir,secs_since_last,min_secs,dist_ticks,min_dist,bar_ts,last_bar_ts");
      FileWrite(g_decision_log,"");
      FileFlush(g_decision_log);
     }
   else
     {
      FileSeek(g_decision_log,0,SEEK_END);
     }
   return true;
  }

void DecisionLog(string event,string reason,double dticks,double thresh,int dir)
  {
   if(IN_TRACE_LEVEL<=0) return;
   if(!DecisionLogInit()) return;
   double bid=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
   double ask=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);
   double sp=SpreadTicks();
   int open_now=CountOpenPositions();
   bool has_dir=HasOpenInDirection(dir);
   double secs_since=(g_last_open_time>0)?(TimeCurrent()-g_last_open_time):0;
   double dist=(g_last_open_price>0)?(MathAbs(((dir>0)?ask:bid)-g_last_open_price)/G_POINT):0;
   datetime bar=iTime(G_SYMBOL,PERIOD_M1,0);
   FileWrite(g_decision_log,
             TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             event,
             reason,
             DoubleToString(bid,G_DIGITS),
             DoubleToString(ask,G_DIGITS),
             DoubleToString(sp,2),
             DoubleToString(g_ema_spread,2),
             DoubleToString(g_ticks[(g_tick_i-1+IN_TICK_BUFFER)%IN_TICK_BUFFER].vol,0),
             DoubleToString(g_ema_vol,0),
             DoubleToString(dticks,2),
             DoubleToString(thresh,2),
             (dir>0)?"BUY":"SELL",
             open_now,
             has_dir,
             IN_REQUIRE_FLAT,
             IN_ALLOW_MULTIDIRECTION,
             (int)secs_since,
             IN_MIN_SECS_BETWEEN_OPENS,
             DoubleToString(dist,2),
             IN_MIN_DISTANCE_TICKS,
             TimeToString(bar,TIME_DATE|TIME_MINUTES),
             TimeToString(g_last_trade_bar_time,TIME_DATE|TIME_MINUTES));
   FileWrite(g_decision_log,"");
   if(IN_TRACE_LEVEL>1) FileFlush(g_decision_log);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LogInit()
  {
   if(g_log!=INVALID_HANDLE)
      return true;
   g_log=FileOpen(g_log_file,FILE_WRITE|FILE_READ|FILE_ANSI|FILE_COMMON);
   if(g_log==INVALID_HANDLE)
      g_log=FileOpen(g_log_file,FILE_WRITE|FILE_READ|FILE_ANSI);
   if(g_log==INVALID_HANDLE)
     {
      Print("Log open failed: ",g_log_file);
      return false;
     }
   ulong sz=FileSize(g_log);
   if(sz==0)
     {
      FileWrite(g_log,"send_ts,exec_ts,latency_ms,side,req_price,exec_price,spread_ticks,slip_ticks,profit_usd,duration_ms,retcode,comment");
      FileWrite(g_log,"");
      FileFlush(g_log);
     }
   else
     {
      FileSeek(g_log,0,SEEK_END);
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogRow(datetime ts_send, datetime ts_exec, int lat_ms, string side, double req_price, double ex_price, double spread_ticks, double slip_ticks, double profit_usd, int dur_ms, int retcode, string comment)
  {
   if(!LogInit())
      return;
   FileWrite(g_log,
             TimeToString(ts_send,TIME_DATE|TIME_SECONDS),
             TimeToString(ts_exec,TIME_DATE|TIME_SECONDS),
             lat_ms,
             side,
             DoubleToString(req_price,G_DIGITS),
             DoubleToString(ex_price,G_DIGITS),
             DoubleToString(spread_ticks,2),
             DoubleToString(slip_ticks,2),
             DoubleToString(profit_usd,2),
             dur_ms,
             retcode,
             comment);
   FileWrite(g_log,"");
   g_log_since_flush++;
   if(g_log_since_flush>=IN_LOG_FLUSH_EVERY)
     {
      FileFlush(g_log);
      g_log_since_flush=0;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SpreadTicks()
  {
   double b=SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
   double a=SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);
   if(b==0||a==0)
      return 1e9;
  return MathAbs(a-b)/G_POINT;
  }

int TodayYMD()
  {
   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   return t.year*10000 + t.mon*100 + t.day;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int cnt=0;
   int total = PositionsTotal();
   for(int i=0; i<total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL)==G_SYMBOL)
            cnt++;
        }
     }
   return cnt;
  }

bool HasOpenInDirection(int dir)
  {
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=G_SYMBOL) continue;
      int type=(int)PositionGetInteger(POSITION_TYPE);
      if(dir>0 && type==POSITION_TYPE_BUY) return true;
      if(dir<0 && type==POSITION_TYPE_SELL) return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDaily()
  {
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_daily_start_balance==0.0)
     {
      g_daily_start_balance=bal;
      g_session_max_balance=bal;
      g_worst_dd=0.0;
     }
   if(bal>g_session_max_balance)
      g_session_max_balance=bal;
   double dd=g_session_max_balance-bal;
   if(dd>g_worst_dd)
      g_worst_dd=dd;
  }

bool IsNewsBlock() { return IN_ENABLE_NEWS_FILTER?false:false; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Cooldown()
  {
   if(g_last_disable_time==0)
      return false;
   if((TimeCurrent()-g_last_disable_time) >= IN_COOLDOWN_MIN*60)
     {
      g_last_disable_time=0;
      g_consecutive_losses=0;
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ATRUpdateBaseline()
  {
   if(g_atr_handle==INVALID_HANDLE)
      return false;
   int need=IN_ATR_BASE_BARS;
   if(need<IN_ATR_PERIOD*4)
      need=IN_ATR_PERIOD*4;
   double buf[];
   ArraySetAsSeries(buf,true);
   int got=CopyBuffer(g_atr_handle,0,0,need,buf);
   if(got<=0)
      return false;
   double sum=0;
   int n=0;
   for(int i=0;i<got;i++)
     {
      if(buf[i]>0)
        {
         sum+=buf[i];
         n++;
        }
     }
   if(n>0)
      g_atr_baseline=sum/n;
   g_last_atr_base_update=TimeCurrent();
   return (n>0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ATRFilter()
  {
   if(g_atr_handle==INVALID_HANDLE)
      return true;
   double val[];
   ArraySetAsSeries(val,true);
   if(CopyBuffer(g_atr_handle,0,0,1,val)<=0)
      return true;
   double atr=val[0];
   if(atr<=0 || g_atr_baseline<=0)
      return true;
   if(atr > g_atr_baseline*IN_ATR_MAX_MULT)
      return false;
   if(atr < g_atr_baseline*IN_ATR_MIN_MULT)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EAAllowed()
  {
  if(Cooldown())
    {
      if(IN_DEBUG)
         Print("Cooldown active");
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","cooldown",0,0,0);
      return false;
    }
  if(IsNewsBlock())
    {
      if(IN_DEBUG)
         Print("News block");
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","news",0,0,0);
      return false;
    }
     
MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int h = tm.hour;


   if(h>=0 && h<24 && g_deny_hour[h])
     {
      if(IN_DEBUG)
         Print("Killzone deny hour: ",h);
      return false;
     }
  if(PingMs()>IN_PING_MAX_MS)
    {
      if(IN_DEBUG)
         Print("Ping high");
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","ping",0,0,0);
      return false;
    }
   double sp=SpreadTicks();
  if(sp>IN_SPREAD_MAX_TICKS)
    {
      if(IN_DEBUG)
         Print("Spread max fail: ",sp);
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","spread_max",0,0,0);
      return false;
    }
  if(g_ema_spread>0 && sp>g_ema_spread*IN_SPREAD_MULT)
    {
      if(IN_DEBUG)
         Print("EMA spread fail: ",sp," > ",g_ema_spread*IN_SPREAD_MULT);
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","ema_spread",0,0,0);
      return false;
    }
  if(!ATRFilter())
    {
      if(IN_DEBUG)
         Print("ATR filter fail");
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","atr",0,0,0);
      return false;
    }
  if((g_daily_start_balance-AccountInfoDouble(ACCOUNT_BALANCE))>=IN_MAX_DAILY_LOSS_USD)
    {
      if(IN_DEBUG)
         Print("Daily loss exceeded");
      g_last_disable_time=TimeCurrent();
      if(IN_TRACE_LEVEL>=2) DecisionLog("FILTER_BLOCK","daily_loss",0,0,0);
      return false;
    }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrackTicket(ulong ticket)
  {
   int idx=-1;
   for(int i=0;i<g_trk_count;i++)
     {
      if(g_tickets[i]==ticket)
        {
         idx=i;
         break;
        }
     }
   if(idx==-1 && g_trk_count<(int)ArraySize(g_tickets))
     {
      idx=g_trk_count++;
      g_tickets[idx]=ticket;
      g_be_armed[idx]=false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetBEArmed(ulong ticket)
  {
   for(int i=0;i<g_trk_count;i++)
      if(g_tickets[i]==ticket)
         return g_be_armed[i];
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetBEArmed(ulong ticket, bool v)
  {
   for(int i=0;i<g_trk_count;i++)
      if(g_tickets[i]==ticket)
        {
         g_be_armed[i]=v;
         return;
        }
   if(g_trk_count<(int)ArraySize(g_tickets))
     {
      g_tickets[g_trk_count]=ticket;
      g_be_armed[g_trk_count]=v;
      g_trk_count++;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   double vol=PositionGetDouble(POSITION_VOLUME);
   long   type=PositionGetInteger(POSITION_TYPE);
   MqlTradeRequest r;
   MqlTradeResult rs;
   ZeroMemory(r);
   r.action=TRADE_ACTION_DEAL;
   r.symbol=sym;
   r.volume=vol;
   r.type=(type==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   r.price=(r.type==ORDER_TYPE_BUY)?SymbolInfoDouble(sym,SYMBOL_ASK):SymbolInfoDouble(sym,SYMBOL_BID);
   r.deviation=IN_DEVIATION_POINTS;
   r.type_time=ORDER_TIME_GTC;
   int fill=(int)SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
      r.type_filling=ORDER_FILLING_FOK;
   else
      if((fill & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
         r.type_filling=ORDER_FILLING_IOC;
      else
         r.type_filling=ORDER_FILLING_RETURN;
   if(!OrderSend(r,rs))
      return false;
   return (rs.retcode==TRADE_RETCODE_DONE || rs.retcode==TRADE_RETCODE_DONE_PARTIAL);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendMarket(int dir, double lot, int &o_err, double &o_exec, ulong &o_order, double &o_slip_ticks)
  {
   o_err=0;
   o_exec=0;
   o_order=0;
   o_slip_ticks=0;
   if(g_sending) { o_err=4756; return false; }
   g_sending=true;
   MqlTradeRequest r;
   MqlTradeResult rs;
   int fill=(int)SymbolInfoInteger(G_SYMBOL,SYMBOL_FILLING_MODE);
   for(int k=0;k<IN_SEND_RETRIES;k++)
     {
      ZeroMemory(r);
      ZeroMemory(rs);
      r.action=TRADE_ACTION_DEAL;
      r.symbol=G_SYMBOL;
      r.volume=lot;
      r.type=(dir>0)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
      double req=(r.type==ORDER_TYPE_BUY)?SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK):SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
      r.price=req;
      r.deviation=IN_DEVIATION_POINTS;
      r.type_time=ORDER_TIME_GTC;
      if((fill & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
         r.type_filling=ORDER_FILLING_FOK;
      else
         if((fill & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
            r.type_filling=ORDER_FILLING_IOC;
         else
            r.type_filling=ORDER_FILLING_RETURN;
      datetime ts=TimeCurrent();
      bool sent=OrderSend(r,rs);
      if(!sent)
        {
         o_err=GetLastError();
         if(IN_DEBUG)
            Print("OrderSend failed low-level ",o_err);
         Sleep(50);
         continue;
        }
      if(rs.retcode==TRADE_RETCODE_DONE || rs.retcode==TRADE_RETCODE_DONE_PARTIAL)
        {
         o_exec=rs.price;
         o_order=rs.order;
         o_slip_ticks=MathAbs(o_exec-req)/G_POINT;
         g_sending=false;
         return true;
        }
      o_err=(int)rs.retcode;
      if(IN_DEBUG)
         Print("Retcode ",rs.retcode,": ",rs.comment);
      if(rs.retcode==TRADE_RETCODE_REQUOTE || rs.retcode==TRADE_RETCODE_PRICE_CHANGED || rs.retcode==TRADE_RETCODE_REJECT || rs.retcode==TRADE_RETCODE_TOO_MANY_REQUESTS || rs.retcode==TRADE_RETCODE_TRADE_CONTEXT_BUSY)
        {
         Sleep(50);
         continue;
        }
      break;
     }
   g_sending=false;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DetectSpike(int &out_dir)
  {
   if(g_tick_n<3)
      return false;
   int N=3;
   int i0=(g_tick_i - N + IN_TICK_BUFFER) % IN_TICK_BUFFER;
   int i1=(g_tick_i - 1 + IN_TICK_BUFFER) % IN_TICK_BUFFER;
   double p0=g_ticks[i0].mid;
   double p1=g_ticks[i1].mid;
   double dv=g_ticks[i1].vol;
   double delta=p1-p0;
   double dticks=MathAbs(delta)/G_POINT;
   if(dticks < IN_SPIKE_TICKS)
      return false;
   if(g_ema_vol>0 && dv < g_ema_vol*IN_VOLUME_MULT)
     {
      if(IN_TRACE_LEVEL>=2) DecisionLog("CANDIDATE_REJECT","volume_low",dticks,IN_SPIKE_TICKS,(delta>0)?-1:+1);
      return false;
     }
   out_dir = (delta>0)?-1:+1; // fade
   if(IN_TRACE_LEVEL>=1) DecisionLog("CANDIDATE_OK","",dticks,IN_SPIKE_TICKS,out_dir);
   return (dticks >= IN_SPIKE_TICKS);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
     {
      ulong ticket_sel = PositionGetTicket(i);
      if(ticket_sel<=0 || !PositionSelectByTicket(ticket_sel))
         continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      if(sym!=G_SYMBOL)
         continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      int type=(int)PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double vol=PositionGetDouble(POSITION_VOLUME);
      datetime t_open=(datetime)PositionGetInteger(POSITION_TIME);
      double curr=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(G_SYMBOL,SYMBOL_BID):SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK);
      double tp=(type==POSITION_TYPE_BUY)?open+IN_TP_TICKS*G_POINT:open-IN_TP_TICKS*G_POINT;
      double sl=(type==POSITION_TYPE_BUY)?open-IN_SL_TICKS*G_POINT:open+IN_SL_TICKS*G_POINT;
      datetime current_time = TimeCurrent();
      int dur_ms=(int)((current_time-t_open)*1000);

      if(IN_ENABLE_TRAIL)
        {
         double profit_ticks=(type==POSITION_TYPE_BUY)?(curr-open)/G_POINT:(open-curr)/G_POINT;
         bool armed=GetBEArmed(ticket);
         if(!armed && profit_ticks>=IN_BE_TICKS)
           {
            SetBEArmed(ticket,true);
           }
         if(armed)
           {
            double be=(type==POSITION_TYPE_BUY)?open+IN_TRAIL_OFFSET_TICKS*G_POINT:open-IN_TRAIL_OFFSET_TICKS*G_POINT;
            if(type==POSITION_TYPE_BUY)
              {
               if(curr<=be)
                  ClosePosition(ticket);
              }
            else
              {
               if(curr>=be)
                  ClosePosition(ticket);
              }
           }
        }

      bool hit_tp = (type==POSITION_TYPE_BUY)?(curr>=tp):(curr<=tp);
      bool hit_sl = (type==POSITION_TYPE_BUY)?(curr<=sl):(curr>=sl);
      bool hit_time = (dur_ms>=IN_TIME_LIMIT_MS);
      if(hit_tp || hit_sl || hit_time)
        {
         double bal_before=AccountInfoDouble(ACCOUNT_BALANCE);
         bool ok=ClosePosition(ticket);
         double pnl=AccountInfoDouble(ACCOUNT_BALANCE)-bal_before;
         if(ok)
           {
            g_total_trades++;
            g_total_pnl+=pnl;
            if(pnl<0)
               g_consecutive_losses++;
            else
               g_consecutive_losses=0;
            UpdateDaily();
            datetime close_time = TimeCurrent();
            LogRow(t_open,close_time,0,(type==POSITION_TYPE_BUY)?"BUY":"SELL",open,curr,SpreadTicks(),0.0,pnl,dur_ms,0, hit_tp?"tp":(hit_sl?"sl":"time"));
            g_last_close_time = close_time;
            if(g_consecutive_losses>=IN_CONSECUTIVE_LOSS_STOP)
              {
               g_last_disable_time=close_time;
               if(IN_DEBUG)
                  Print("Loss stop, cooldown");
              }
            if((g_daily_start_balance-AccountInfoDouble(ACCOUNT_BALANCE))>=IN_MAX_DAILY_LOSS_USD)
              {
               g_last_disable_time=close_time;
               if(IN_DEBUG)
                  Print("Daily loss stop");
              }
            if(g_total_trades>0 && (g_total_trades%IN_LOG_FLUSH_EVERY==0))
              {
               double fill_rate=(g_open_attempts>0)?(100.0*g_open_fills/g_open_attempts):0.0;
               double avg_slip=(g_open_fills>0)?(g_slip_sum/g_open_fills):0.0;
               double avg_pnl=(g_total_trades>0)?(g_total_pnl/g_total_trades):0.0;
               PrintFormat("[Stats] trades=%d fills=%d attempts=%d fill_rate=%.1f%% avg_slip=%.2f ticks avg_pnl=%.2f USD max_dd=%.2f consec_losses=%d",
                           g_total_trades,g_open_fills,g_open_attempts,fill_rate,avg_slip,avg_pnl,g_worst_dd,g_consecutive_losses);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(G_SYMBOL,tk))
      return;
   if(ArraySize(g_ticks)!=IN_TICK_BUFFER)
     {
      ArrayResize(g_ticks,IN_TICK_BUFFER);
      g_tick_i=0;
      g_tick_n=0;
     }
   TickEntry te;
   te.t=tk.time;
   te.bid=tk.bid;
   te.ask=tk.ask;
   te.mid=(tk.bid+tk.ask)/2.0;
   te.vol=(double)tk.volume;
   g_ticks[g_tick_i]=te;
   g_tick_i=(g_tick_i+1)%IN_TICK_BUFFER;
   if(g_tick_n<IN_TICK_BUFFER)
      g_tick_n++;
   if(g_ema_vol<=0)
      g_ema_vol=te.vol;
   else
      g_ema_vol=g_alpha*te.vol + (1.0-g_alpha)*g_ema_vol;
   double sp=MathAbs(te.ask-te.bid)/G_POINT;
   if(g_ema_spread<=0)
      g_ema_spread=sp;
   else
      g_ema_spread=g_alpha*sp + (1.0-g_alpha)*g_ema_spread;
  }

// Events
int OnInit()
  {
   G_SYMBOL=Symbol();
   G_DIGITS=(int)SymbolInfoInteger(G_SYMBOL,SYMBOL_DIGITS);
   G_POINT=SymbolInfoDouble(G_SYMBOL,SYMBOL_POINT);
   G_TICK_SIZE=SymbolInfoDouble(G_SYMBOL,SYMBOL_TRADE_TICK_SIZE);
   G_TICK_VALUE=SymbolInfoDouble(G_SYMBOL,SYMBOL_TRADE_TICK_VALUE);
   if(G_POINT<=0)
      G_POINT=0.01;
   ArrayResize(g_ticks,IN_TICK_BUFFER);
   g_tick_i=0;
   g_tick_n=0;
   ParseKillzone(IN_KILLZONE_DENY_HOURS);
   g_atr_handle = iATR(G_SYMBOL,PERIOD_M1,IN_ATR_PERIOD);
   ATRUpdateBaseline();
   LogInit();
   g_daily_start_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   g_session_max_balance=g_daily_start_balance;
   g_worst_dd=0.0;
   Print("MR_MicroScalp init ",G_SYMBOL, " lot=",DoubleToString(IN_LOT,2));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(g_log!=INVALID_HANDLE)
     {
      FileFlush(g_log);
      FileClose(g_log);
      g_log=INVALID_HANDLE;
     }
   if(g_decision_log!=INVALID_HANDLE)
     {
      FileFlush(g_decision_log);
      FileClose(g_decision_log);
      g_decision_log=INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateTick();
   UpdateDaily();
   if((TimeCurrent()-g_last_atr_base_update) > 600)
      ATRUpdateBaseline();
  ManagePositions();
  if(!EAAllowed())
      return;
  // Daily counter rollover
  int ymd = TodayYMD();
  if(g_today_ymd!=ymd){ g_today_ymd=ymd; g_trades_today=0; }
  // Single-entry / daily caps
  if(IN_MAX_TRADES_TOTAL>=0 && g_total_opens>=IN_MAX_TRADES_TOTAL){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","max_total",0,0,0); return; }
  if(IN_MAX_TRADES_PER_DAY>=0 && g_trades_today>=IN_MAX_TRADES_PER_DAY){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","max_daily",0,0,0); return; }
  // Require flat or enforce concurrency cap
  int open_now = CountOpenPositions();
  if(IN_REQUIRE_FLAT){ if(open_now>0){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","require_flat",0,0,0); return; } }
  else { if(open_now>=IN_MAX_CONCURRENT){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","max_concurrent",0,0,0); return; } }
   // Minute cap
   int minute_key = (int)(TimeCurrent()/60);
   if(g_minute_key!=minute_key){ g_minute_key=minute_key; g_minute_count=0; }
   if(g_minute_count>=IN_MAX_ORDERS_PER_MIN){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","max_per_min",0,0,0); return; }
  int dir=0;
  if(!DetectSpike(dir))
      return;
  datetime ts=TimeCurrent();
  // Pre-lock to avoid multiple sends within same second in tester
  if(g_prelock_until>0 && ts < g_prelock_until){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","prelock",0,0,dir); return; }
  // Hard throttle by tick time (ms)
  MqlTick tk_now; if(SymbolInfoTick(G_SYMBOL,tk_now)){
    if(g_last_send_msc>0 && (long)tk_now.time_msc - g_last_send_msc < IN_MIN_MSC_BETWEEN_SENDS){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","min_msc_between_sends",0,0,dir); return; }
  }
   if(IN_ONE_TRADE_PER_BAR)
     {
      datetime bar=iTime(G_SYMBOL,IN_ONE_TRADE_TF,0);
      if(g_last_trade_bar_time==bar){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","one_per_bar",0,0,dir); return; }
     }
   // Global throttle by time
   if(g_last_open_time>0 && (ts - g_last_open_time) < IN_MIN_SECS_BETWEEN_OPENS){ if(IN_DEBUG) Print("Skip: cooldown between opens"); if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","cooldown_time",0,0,dir); return; }
   // Post-close cooldown
   if(g_last_close_time>0 && (ts - g_last_close_time) < IN_POST_CLOSE_COOLDOWN_SECS){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","post_close_cooldown",0,0,dir); return; }
   // Global block window
   if(g_block_until>0 && ts < g_block_until){ if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","block_until",0,0,dir); return; }
   // Do not stack same-direction trades if not allowed
   if(!IN_ALLOW_MULTIDIRECTION && HasOpenInDirection(dir)){ if(IN_DEBUG) Print("Skip: already has position in this direction"); if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","direction_exists",0,0,dir); return; }
   double req=(dir>0)?SymbolInfoDouble(G_SYMBOL,SYMBOL_ASK):SymbolInfoDouble(G_SYMBOL,SYMBOL_BID);
   // Enforce minimum distance from last entry price
   if(g_last_open_price>0.0)
     {
      double dist_ticks=MathAbs(req - g_last_open_price)/G_POINT;
      if(dist_ticks < IN_MIN_DISTANCE_TICKS){ if(IN_DEBUG) Print("Skip: too close to last entry (",dist_ticks," ticks)"); if(IN_TRACE_LEVEL>=2) DecisionLog("GATE_FAIL","min_distance",dist_ticks,IN_MIN_DISTANCE_TICKS,dir); return; }
     }
   int err=0;
   double exec=0;
   ulong ord=0;
   double slip_ticks=0;
  g_open_attempts++;
  g_prelock_until = ts + IN_PRELOCK_SECS; // set prelock before sending
  bool ok=SendMarket(dir,IN_LOT,err,exec,ord,slip_ticks);
  datetime exec_time = TimeCurrent();
  if(ok)
    {
      g_last_open_time = ts;
      g_last_open_price = exec;
      g_last_open_dir = dir;
      if(IN_ONE_TRADE_PER_BAR) g_last_trade_bar_time = iTime(G_SYMBOL,IN_ONE_TRADE_TF,0);
      if(IN_TRACE_LEVEL>=1) DecisionLog("OPEN_OK","",0,0,dir);
      g_minute_count++;
      g_block_until = ts + IN_MIN_SECS_BETWEEN_OPENS;
      if(tk_now.time_msc>0) g_last_send_msc = (long)tk_now.time_msc;
      g_total_opens++;
      g_trades_today++;
    }
   if(ok)
     {
      LogRow(ts,exec_time,0,(dir>0)?"BUY":"SELL",req,exec,SpreadTicks(),slip_ticks,0.0,0, 0, "open");
      TrackTicket(ord);
     }
   else
     {
     LogRow(ts,exec_time,0,(dir>0)?"BUY":"SELL",req,exec,SpreadTicks(),slip_ticks,0.0,0, err, "open_fail");
     if(IN_TRACE_LEVEL>=1) DecisionLog("OPEN_FAIL",IntegerToString(err),0,0,dir);
     g_block_until = ts + IN_BLOCK_AFTER_FAIL_SECS;
     if(tk_now.time_msc>0) g_last_send_msc = (long)tk_now.time_msc;
    }
   if(ok)
     {
      g_open_fills++;
      g_slip_sum+=slip_ticks;
     }
  }
//+------------------------------------------------------------------+
