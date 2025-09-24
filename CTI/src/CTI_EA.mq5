//+------------------------------------------------------------------+
//|                                                  CTI_EA.mq5      |
//| ICT-conform EA: BOS → FVG → Retest → LTF Trigger (Micro BOS/IFVG)|
//| Skeleton scaffolding – to be completed iteratively               |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

enum CT_TF { TF_M1, TF_M5, TF_M15, TF_M30, TF_H1, TF_H4 };
enum TRIGGER_TF_MODE { TRIG_AUTO_TABLE, TRIG_MANUAL };
enum BOS_CONFIRM_MODE { BOS_CLOSE_ONLY, BOS_CLOSE_OR_WICK };
enum PADDING_MODE { PAD_ATR, PAD_POINTS, PAD_SWING_PCT };
enum ENTRY_PRIORITY { PRIORITY_BOS_THEN_IFVG, PRIORITY_IFVG_THEN_BOS, PRIORITY_ANY };
enum ENTRY_MODE { MARKET_ON_TRIGGER, LIMIT_AT_IFVG, SMART_BOTH };
enum SL_MODE { SL_LTF_STRUCTURE, SL_ANCHOR_100PCT };
enum ZONE_PRIORITY { ZP_FVG_THEN_OB, ZP_OB_THEN_FVG, ZP_ANY };

// Inputs
input int               in_magic_number               = 223344;
input double            in_fixed_lot                  = 0.02;

input CT_TF             in_anchor_tf                  = TF_M5;
input TRIGGER_TF_MODE   in_trigger_tf_mode            = TRIG_AUTO_TABLE;
input CT_TF             in_trigger_tf_manual          = TF_M1;

input int               in_swing_bars_anchor          = 5;
input BOS_CONFIRM_MODE  in_bos_confirm_mode           = BOS_CLOSE_ONLY;
input PADDING_MODE      in_bos_padding_mode           = PAD_ATR;
input double            in_bos_padding_atr_factor     = 0.00;
input int               in_bos_padding_points         = 0;
input double            in_bos_padding_swing_pct      = 0.00;

input double            in_fvg_min_atr_factor_anchor  = 0.30;

// Anchor zones: enable both FVG and OB observation
input bool              in_anchor_zone_allow_fvg      = true;
input bool              in_anchor_zone_allow_ob       = true;
input ZONE_PRIORITY     in_zone_priority              = ZP_FVG_THEN_OB;
input bool              in_ob_use_wick                = false;
input int               in_ob_max_candles_back_in_A   = 5;

input int               in_trigger_window_bars_ltf    = 30;
input bool              in_entry_allow_bos            = true;
input bool              in_entry_allow_ifvg           = true;
input ENTRY_PRIORITY    in_entry_priority             = PRIORITY_BOS_THEN_IFVG;
input bool              in_ifvg_strict                = false;
input double            in_ifvg_min_atr_factor_ltf    = 0.00;
input ENTRY_MODE        in_entry_mode                 = MARKET_ON_TRIGGER;

input SL_MODE           in_sl_mode                    = SL_LTF_STRUCTURE;
input double            in_sl_buffer_atr_factor       = 0.10;
input bool              in_tp1_enable                 = true;
input bool              in_tp1_at_50pct_of_A          = true;
input double            in_trailing_stop_atr_factor   = 1.5;

input bool              in_enable_spread_filter       = true;
input int               in_max_spread_points          = 40;
input bool              in_enable_session_filter      = false;
input int               in_session_start_hour         = 0;
input int               in_session_end_hour           = 24;
input int               in_setup_expiry_bars_anchor   = 10;

input bool              in_debug                      = true;

// Logging inputs
input bool              in_log_enable                 = true;
input string            in_log_file_prefix            = "CTI";
input bool              in_log_use_common             = true;   // write to MQL5/Files/Common
input bool              in_log_also_print             = true;   // mirror to terminal log
input bool              in_summary_count_open_as_trade = true;  // count open position at end as a trade (uses floating P/L)

// Retest controls
input bool              in_enable_retest_intrabar     = true;   // detect retest on every tick
input double            in_retest_tolerance_atr_ratio = 0.02;   // tolerance around zone as ATR(anchor) * ratio
input bool              in_allow_preempt_on_new_bos   = false;  // allow new BOS to replace waiting setup

// Globals
CTrade Trade;
ENUM_TIMEFRAMES g_anchor_period = PERIOD_M5;
ENUM_TIMEFRAMES g_trigger_period = PERIOD_M1;
int     g_atr_anchor_handle = INVALID_HANDLE;
int     g_atr_ltf_handle = INVALID_HANDLE;
datetime g_last_ltf_bar_time = 0;

// Logging & stats
int     g_log_handle = INVALID_HANDLE;
string  g_log_name   = "";

struct Stats
{
  int    trades;
  int    wins;
  int    losses;
  int    entriesFVG;
  int    entriesOB;
  int    triggersBOS;
  int    triggersIFVG;
  int    tp1Hits;
  double grossProfit;
  double grossLoss;
  double netProfit;
};

Stats g_stats;
long  g_pos_ticket = -1;           // current position ticket
double g_trade_profit_accum = 0.0; // accumulates over all out deals of this trade
int    g_curr_trigger_type = 0;    // 1=BOS, 2=IFVG

enum EA_STATE { ST_IDLE, ST_WAIT_BOS, ST_WAIT_FVG, ST_WAIT_RETEST, ST_WAIT_TRIGGER, ST_IN_TRADE };
EA_STATE g_state = ST_IDLE;

datetime g_last_anchor_bar_time = 0;

struct Swing
{
  int     idxHigh;
  int     idxLow;
  double  high;
  double  low;
  datetime tHigh;
  datetime tLow;
};

struct FVGZone
{
  double  top;
  double  bottom;
  int     anchorIndex; // index on anchor TF
};

struct Setup
{
  bool     active;
  bool     isBuy;
  Swing    swingA;
  FVGZone  fvgA;
  FVGZone  obA;
  int      activeZone; // 0:none, 1:FVG, 2:OB
  int      expiryBarsLeft; // on anchor TF
  int      ltfBarsLeft;    // on LTF
  bool     tp1Done;
  datetime retestTime;
  datetime expiryTime;     // absolute expiry time for WAIT_RETEST
};

Setup g_setup;

// Helpers ------------------------------------------------------------
ENUM_TIMEFRAMES TfToPeriod(CT_TF tf)
{
  switch(tf)
  {
    case TF_M1:   return PERIOD_M1;
    case TF_M5:   return PERIOD_M5;
    case TF_M15:  return PERIOD_M15;
    case TF_M30:  return PERIOD_M30;
    case TF_H1:   return PERIOD_H1;
    case TF_H4:   return PERIOD_H4;
  }
  return PERIOD_CURRENT;
}

ENUM_TIMEFRAMES AutoTriggerForAnchor(CT_TF anchor)
{
  // AUTO_TABLE mapping agreed with user
  if(anchor==TF_M1)  return PERIOD_M1;
  if(anchor==TF_M5)  return PERIOD_M1;
  if(anchor==TF_M15) return PERIOD_M5;
  if(anchor==TF_M30) return PERIOD_M15;
  if(anchor==TF_H1)  return PERIOD_M15;
  if(anchor==TF_H4)  return PERIOD_M30;
  // fallback
  return PERIOD_M1;
}

bool NewBarArrived(ENUM_TIMEFRAMES period, datetime &lastTime)
{
  MqlRates rates[];
  if(CopyRates(_Symbol, period, 0, 2, rates) != 2) return false;
  datetime cur = rates[0].time;
  if(cur != lastTime)
  {
    lastTime = cur;
    return true;
  }
  return false;
}

double GetATR(int handle)
{
  double buff[];
  if(handle==INVALID_HANDLE) return 0.0;
  if(CopyBuffer(handle,0,0,1,buff)!=1) return 0.0;
  return buff[0];
}

bool CopyRatesSeries(const string sym, const ENUM_TIMEFRAMES period, const int count, MqlRates &arr[])
{
  int copied = CopyRates(sym, period, 0, count, arr);
  if(copied<=0) return false;
  ArraySetAsSeries(arr, true);
  return true;
}

string TfToStr(const ENUM_TIMEFRAMES p)
{
  switch(p)
  {
    case PERIOD_M1:  return "M1";
    case PERIOD_M5:  return "M5";
    case PERIOD_M15: return "M15";
    case PERIOD_M30: return "M30";
    case PERIOD_H1:  return "H1";
    case PERIOD_H4:  return "H4";
    default: return IntegerToString((int)p);
  }
}

void StatsInit()
{
  ZeroMemory(g_stats);
  g_stats.trades=g_stats.wins=g_stats.losses=0;
  g_stats.entriesFVG=g_stats.entriesOB=0;
  g_stats.triggersBOS=g_stats.triggersIFVG=0;
  g_stats.tp1Hits=0; g_stats.grossProfit=g_stats.grossLoss=g_stats.netProfit=0.0;
}

string NowStr()
{
  return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
}

void LogWrite(const string line)
{
  if(!in_log_enable) { if(in_log_also_print) Print(line); return; }
  if(g_log_handle==INVALID_HANDLE)
  {
    if(in_log_also_print) Print(line);
    return;
  }
  string s = NowStr()+" | "+line+"\r\n";
  FileWriteString(g_log_handle, s);
  FileFlush(g_log_handle);
  if(in_log_also_print) Print(line);
}

void OpenLog()
{
  if(!in_log_enable) return;
  MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
  string tstamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
  g_log_name = StringFormat("%s_%s_%s_%s.log", in_log_file_prefix, _Symbol, TfToStr(g_anchor_period), TfToStr(g_trigger_period));
  int flags = FILE_TXT|FILE_ANSI|FILE_READ|FILE_WRITE|FILE_SHARE_READ;
  if(in_log_use_common) flags |= FILE_COMMON;
  g_log_handle = FileOpen(g_log_name, flags);
  if(g_log_handle!=INVALID_HANDLE)
  {
    FileSeek(g_log_handle, 0, SEEK_END);
    LogWrite(StringFormat("=== CTI Log Start %s Symbol=%s Anchor=%s Trigger=%s ===", tstamp, _Symbol, TfToStr(g_anchor_period), TfToStr(g_trigger_period)));
  }
}

void CloseLog()
{
  if(g_log_handle!=INVALID_HANDLE)
  {
    LogWrite("=== CTI Log End ===");
    FileClose(g_log_handle);
    g_log_handle = INVALID_HANDLE;
  }
}

void DumpStats()
{
  LogWrite("==================== CTI SUMMARY ====================");
  LogWrite(StringFormat("Total Trades: %d", g_stats.trades));
  LogWrite(StringFormat("Wins: %d, Losses: %d", g_stats.wins, g_stats.losses));
  LogWrite(StringFormat("Entries by Zone → FVG: %d, OB: %d", g_stats.entriesFVG, g_stats.entriesOB));
  LogWrite(StringFormat("Triggers → MicroBOS: %d, IFVG: %d", g_stats.triggersBOS, g_stats.triggersIFVG));
  LogWrite(StringFormat("TP1 hits: %d", g_stats.tp1Hits));
  LogWrite(StringFormat("Gross Profit: %.2f, Gross Loss: %.2f, Net: %.2f", g_stats.grossProfit, g_stats.grossLoss, g_stats.netProfit));
  LogWrite("======================================================");
}

string StateToStr(EA_STATE s)
{
  switch(s)
  {
    case ST_IDLE:         return "IDLE(0)";
    case ST_WAIT_BOS:     return "WAIT_BOS(1)";
    case ST_WAIT_FVG:     return "WAIT_ZONES(2)";
    case ST_WAIT_RETEST:  return "WAIT_RETEST(3)";
    case ST_WAIT_TRIGGER: return "WAIT_TRIGGER(4)";
    case ST_IN_TRADE:     return "IN_TRADE(5)";
  }
  return "UNKNOWN";
}

bool IsFractalHigh(MqlRates &arr[], int i, int look)
{
  // arr is series (0 newest), i increases older
  double h = arr[i].high;
  for(int k=1;k<=look;k++)
  {
    if(i-k<0) return false;
    if(i+k>=ArraySize(arr)) break;
    if(!(h>arr[i-k].high && h>arr[i+k].high)) return false;
  }
  return true;
}

bool IsFractalLow(MqlRates &arr[], int i, int look)
{
  double l = arr[i].low;
  for(int k=1;k<=look;k++)
  {
    if(i-k<0) return false;
    if(i+k>=ArraySize(arr)) break;
    if(!(l<arr[i-k].low && l<arr[i+k].low)) return false;
  }
  return true;
}

bool GetLastSwingHigh(MqlRates &arr[], int bars, int look, int &idx, double &price, datetime &t)
{
  for(int i=look+1; i<bars-look; i++)
  {
    if(IsFractalHigh(arr,i,look))
    {
      idx=i; price=arr[i].high; t=arr[i].time; return true;
    }
  }
  return false;
}

bool GetLastSwingLow(MqlRates &arr[], int bars, int look, int &idx, double &price, datetime &t)
{
  for(int i=look+1; i<bars-look; i++)
  {
    if(IsFractalLow(arr,i,look))
    {
      idx=i; price=arr[i].low; t=arr[i].time; return true;
    }
  }
  return false;
}

double BosPadding(const bool isBuy, const Swing &s, const double atr)
{
  if(in_bos_padding_mode==PAD_ATR)
    return atr*in_bos_padding_atr_factor;
  if(in_bos_padding_mode==PAD_POINTS)
    return in_bos_padding_points*_Point;
  if(in_bos_padding_mode==PAD_SWING_PCT)
  {
    double range = MathMax(1e-8, MathAbs(s.high - s.low));
    return range*in_bos_padding_swing_pct;
  }
  return 0.0;
}

bool BarsOverlapZone(const double barLow, const double barHigh, const FVGZone &z)
{
  double top = MathMax(z.top, z.bottom);
  double bot = MathMin(z.top, z.bottom);
  if(top==0.0 && bot==0.0) return false;
  if(barHigh < bot) return false;
  if(barLow > top) return false;
  return true;
}

double RetestTolerance()
{
  double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  double tolSpread = 0.5 * spread_pts * _Point;
  double atrA = GetATR(g_atr_anchor_handle);
  double tolAtr = atrA * in_retest_tolerance_atr_ratio;
  return MathMax(tolSpread, tolAtr);
}

bool PriceInZone(const double price, const FVGZone &z, const double tol)
{
  double top = MathMax(z.top, z.bottom);
  double bot = MathMin(z.top, z.bottom);
  if(top==0.0 && bot==0.0) return false;
  return (price >= bot - tol && price <= top + tol);
}

int RetestHitNow(const FVGZone &fvg, const FVGZone &ob)
{
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  double lo = MathMin(ask,bid), hi=MathMax(ask,bid);
  double tol = RetestTolerance();
  bool hitF = PriceInZone(lo, fvg, tol) || PriceInZone(hi, fvg, tol);
  bool hitO = PriceInZone(lo, ob,  tol) || PriceInZone(hi, ob,  tol);
  if(hitF && hitO)
  {
    if(in_zone_priority==ZP_FVG_THEN_OB) return 1;
    if(in_zone_priority==ZP_OB_THEN_FVG) return 2;
    // ANY: prefer closer zone to mid price
    double mid = 0.5*(ask+bid);
    double fTop=MathMax(fvg.top,fvg.bottom), fBot=MathMin(fvg.top,fvg.bottom);
    double oTop=MathMax(ob.top,ob.bottom),  oBot=MathMin(ob.top,ob.bottom);
    double df = MathMin(MathAbs(mid-fTop), MathAbs(mid-fBot));
    double doo= MathMin(MathAbs(mid-oTop), MathAbs(mid-oBot));
    return (df<=doo)?1:2;
  }
  if(hitF) return 1;
  if(hitO) return 2;
  return 0;
}

bool SessionOk()
{
  if(!in_enable_session_filter) return true;
  MqlDateTime dt;
  datetime t = TimeCurrent();
  TimeToStruct(t, dt);
  int h = dt.hour;
  return (h>=in_session_start_hour && h<in_session_end_hour);
}

bool SpreadOk()
{
  if(!in_enable_spread_filter) return true;
  return (SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) <= in_max_spread_points);
}

// Detection stubs ----------------------------------------------------
bool DetectBOSAnchor(bool &isBuy, Swing &swingA)
{
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 400, ar)) return false;
  int bars = ArraySize(ar);
  if(bars<in_swing_bars_anchor*3+10) return false;

  int idxH=-1, idxL=-1; double prH=0, prL=0; datetime tH=0, tL=0;
  if(!GetLastSwingHigh(ar,bars,in_swing_bars_anchor,idxH,prH,tH)) return false;
  if(!GetLastSwingLow(ar,bars,in_swing_bars_anchor,idxL,prL,tL)) return false;

  // choose the nearer swing to the present for each side already handled
  // Align order: for Buy BOS, we expect last swing high newer than a prior swing low (idxH < idxL)
  // If not, attempt to find an older low after that high
  if(idxH >= idxL)
  {
    // try to find next swing low older than idxH
    for(int i=idxH+in_swing_bars_anchor+1; i<bars-in_swing_bars_anchor; i++)
    {
      if(IsFractalLow(ar,i,in_swing_bars_anchor)) { idxL=i; prL=ar[i].low; tL=ar[i].time; break; }
    }
  }

  // similarly for Sell BOS
  if(idxL >= idxH)
  {
    for(int i=idxL+in_swing_bars_anchor+1; i<bars-in_swing_bars_anchor; i++)
    {
      if(IsFractalHigh(ar,i,in_swing_bars_anchor)) { idxH=i; prH=ar[i].high; tH=ar[i].time; break; }
    }
  }

  if(idxH<0 || idxL<0) return false;

  double atrA = GetATR(g_atr_anchor_handle);
  Swing s; s.idxHigh=idxH; s.idxLow=idxL; s.high=prH; s.low=prL; s.tHigh=tH; s.tLow=tL;
  double pad = BosPadding(true, s, atrA); // pad magnitude same for both

  // Use last closed bar (index 1 in series)
  double c1 = ar[1].close;
  bool bosBuy = (c1 > prH + pad);
  bool bosSell = (c1 < prL - pad);

  if(in_bos_confirm_mode==BOS_CLOSE_OR_WICK)
  {
    bosBuy = bosBuy || (ar[1].high > prH + pad);
    bosSell = bosSell || (ar[1].low  < prL - pad);
  }

  if(!(bosBuy || bosSell)) return false;

  isBuy = bosBuy && !bosSell;
  // Normalize swing order to reflect leg A direction
  if(isBuy)
  {
    // ensure low is older than high
    if(s.idxLow < s.idxHigh)
    {
      // swap to enforce tLow older
      int ti=s.idxLow; s.idxLow=s.idxHigh; s.idxHigh=ti;
      double tp=s.low; s.low=s.high; s.high=tp;
      datetime tt=s.tLow; s.tLow=s.tHigh; s.tHigh=tt;
    }
  }
  else
  {
    if(s.idxHigh < s.idxLow)
    {
      int ti=s.idxHigh; s.idxHigh=s.idxLow; s.idxLow=ti;
      double tp=s.high; s.high=s.low; s.low=tp;
      datetime tt=s.tHigh; s.tHigh=s.tLow; s.tLow=tt;
    }
  }

  swingA = s;
  return true;
}

bool FindAnchorFVG(const bool isBuy, FVGZone &fvg)
{
  if(!g_setup.active) return false;
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 600, ar)) return false;
  int bars = ArraySize(ar);
  if(bars<10) return false;
  datetime tStart = g_setup.swingA.tLow;
  datetime tEnd   = g_setup.swingA.tHigh;
  double minSize = GetATR(g_atr_anchor_handle) * in_fvg_min_atr_factor_anchor;

  for(int k=2; k<bars-2; k++)
  {
    datetime tk = ar[k].time;
    if(!(tk<=tEnd && tk>=tStart)) continue; // within A window
    if(isBuy)
    {
      double top = ar[k].low;
      double bot = ar[k+2].high;
      if(top - bot > minSize)
      {
        fvg.top=top; fvg.bottom=bot; fvg.anchorIndex=k; return true;
      }
    }
    else
    {
      double top = ar[k+2].low;
      double bot = ar[k].high;
      if(top - bot < -minSize)
      {
        // For sell, ensure zone top<bottom to preserve band later normalize
        fvg.top=bot; fvg.bottom=top; fvg.anchorIndex=k; return true;
      }
    }
  }
  return false;
}

bool FindAnchorOB(const bool isBuy, FVGZone &ob)
{
  if(!g_setup.active) return false;
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 600, ar)) return false;
  int bars = ArraySize(ar);
  datetime tStart = g_setup.swingA.tLow;
  datetime tEnd   = g_setup.swingA.tHigh;

  int found=-1; int scans=0;
  // scan backwards from tEnd towards tStart to get the last opposite candle
  for(int k=1; k<bars-1; k++)
  {
    datetime tk = ar[k].time;
    if(tk>tEnd) continue; // newer than end
    if(tk<tStart) break;  // older than start
    bool bearish = (ar[k].close < ar[k].open);
    bool bullish = (ar[k].close > ar[k].open);
    if(isBuy && bearish) { found=k; if(++scans>=in_ob_max_candles_back_in_A) break; }
    if(!isBuy && bullish){ found=k; if(++scans>=in_ob_max_candles_back_in_A) break; }
  }
  if(found==-1) return false;
  double top, bot;
  if(in_ob_use_wick)
  {
    top = ar[found].high; bot = ar[found].low;
  }
  else
  {
    top = MathMax(ar[found].open, ar[found].close);
    bot = MathMin(ar[found].open, ar[found].close);
  }
  ob.top=top; ob.bottom=bot; ob.anchorIndex=found; return true;
}

int RetestIntoZones(const FVGZone &fvg, const FVGZone &ob)
{
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 2, ar)) return 0;
  // Use current forming anchor bar to avoid missing intrabar touches
  double barLow = ar[0].low;
  double barHigh= ar[0].high;
  bool hitF = BarsOverlapZone(barLow, barHigh, fvg);
  bool hitO = BarsOverlapZone(barLow, barHigh, ob);
  if(hitF && hitO)
  {
    if(in_zone_priority==ZP_FVG_THEN_OB) return 1;
    if(in_zone_priority==ZP_OB_THEN_FVG) return 2;
    // ANY: choose the one with larger overlap
    double fTop=MathMax(fvg.top,fvg.bottom), fBot=MathMin(fvg.top,fvg.bottom);
    double oTop=MathMax(ob.top,ob.bottom),  oBot=MathMin(ob.top,ob.bottom);
    double fOverlap = MathMax(0.0, MathMin(barHigh,fTop)-MathMax(barLow,fBot));
    double oOverlap = MathMax(0.0, MathMin(barHigh,oTop)-MathMax(barLow,oBot));
    return (fOverlap>=oOverlap)?1:2;
  }
  if(hitF) return 1;
  if(hitO) return 2;
  return 0;
}

bool TriggerOnLTF(const bool isBuy, double &outSLRef)
{
  MqlRates lr[];
  if(!CopyRatesSeries(_Symbol, g_trigger_period, 300, lr)) return false;
  int bars = ArraySize(lr);
  if(bars<20) return false;

  // Only consider bars after retest time
  int start = -1;
  for(int i=1;i<bars;i++) { if(lr[i].time <= g_setup.retestTime) { start=i-1; break; } }
  if(start<5) start=5;

  // Micro BOS heuristic: close[1] breaks recent swing extreme (lookback=3)
  int look=3;
  double c1 = lr[1].close;
  // manual highest/lowest strictly AFTER retest (from index 2 down to 'start')
  int right = (start>2? start : 2);
  double hi=lr[2].high, lo=lr[2].low; int idxHi=2, idxLo=2;
  for(int i=2; i<=right && i<bars; i++)
  {
    if(lr[i].high>hi){hi=lr[i].high; idxHi=i;}
    if(lr[i].low<lo){lo=lr[i].low; idxLo=i;}
  }

  bool microBOS=false;
  if(isBuy) microBOS = (c1 > hi);
  else      microBOS = (c1 < lo);

  // IFVG (sharkturn) loose: accept any 3-candle gap after retest
  bool ifvg=false;
  for(int k=2; k<bars-2; k++)
  {
    if(lr[k].time <= g_setup.retestTime) break;
    if(isBuy)
    {
      if(lr[k].low > lr[k+2].high) { ifvg=true; break; }
    }
    else
    {
      if(lr[k+2].low > lr[k].high) { ifvg=true; break; }
    }
  }

  bool ok=false;
  if(in_entry_allow_bos && in_entry_allow_ifvg)
  {
    if(in_entry_priority==PRIORITY_BOS_THEN_IFVG) ok = (g_curr_trigger_type = (microBOS?1:(ifvg?2:0)))>0;
    else if(in_entry_priority==PRIORITY_IFVG_THEN_BOS) ok = (g_curr_trigger_type = (ifvg?2:(microBOS?1:0)))>0;
    else { g_curr_trigger_type = microBOS?1:(ifvg?2:0); ok = g_curr_trigger_type>0; }
  }
  else if(in_entry_allow_bos) { ok = microBOS; g_curr_trigger_type = ok?1:0; }
  else if(in_entry_allow_ifvg) { ok = ifvg; g_curr_trigger_type = ok?2:0; }

  if(!ok) return false;

  // SL reference from LTF structure: nearest swing opposite extreme
  outSLRef = isBuy ? lo : hi;
  if(g_curr_trigger_type==1) { g_stats.triggersBOS++; LogWrite("Trigger LTF: Micro BOS"); }
  if(g_curr_trigger_type==2) { g_stats.triggersIFVG++; LogWrite("Trigger LTF: IFVG (sharkturn)"); }
  return true;
}

double NormalizePrice(double p)
{
  return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double NormalizeLots(double lots)
{
  double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  double minl = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double maxl = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double vol = MathMax(minl, MathMin(maxl, MathFloor(lots/step)*step));
  return vol;
}

double MinStopsDistance()
{
  long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  if(stops<0) stops=0;
  return (double)stops * _Point;
}

void AdjustStopsForEntry(const bool isBuy, double &sl, double &tp)
{
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  double minD = MinStopsDistance();
  if(isBuy)
  {
    double minSL = ask - minD;
    double minTP = ask + minD;
    if(sl > minSL) sl = minSL;   // push SL far enough
    if(tp < minTP) tp = minTP;   // push TP far enough
    // final sanity
    if(sl >= ask) sl = ask - (minD>0?minD:(_Point*10));
    if(tp <= ask) tp = ask + (minD>0?minD:(_Point*10));
  }
  else
  {
    double minSL = bid + minD;
    double minTP = bid - minD;
    if(sl < minSL) sl = minSL;
    if(tp > minTP) tp = minTP;
    if(sl <= bid) sl = bid + (minD>0?minD:(_Point*10));
    if(tp >= bid) tp = bid - (minD>0?minD:(_Point*10));
  }
  sl = NormalizePrice(sl);
  tp = NormalizePrice(tp);
}

bool PlaceEntry(const bool isBuy, const double slPrice, const double tpPrice)
{
  Trade.SetExpertMagicNumber((long)in_magic_number);
  if(in_entry_mode==MARKET_ON_TRIGGER)
  {
    double lots = NormalizeLots(in_fixed_lot);
    double sl = NormalizePrice(slPrice);
    double tp = NormalizePrice(tpPrice);
    // Ensure SL/TP satisfy broker min stops
    AdjustStopsForEntry(isBuy, sl, tp);
    LogWrite(StringFormat("Pre-Entry: %s lots=%.2f ask=%.5f bid=%.5f sl=%.5f tp=%.5f minStops=%.1fpt",
              isBuy?"BUY":"SELL", lots,
              SymbolInfoDouble(_Symbol, SYMBOL_ASK), SymbolInfoDouble(_Symbol, SYMBOL_BID),
              sl, tp, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)));
    bool ok=false;
    if(isBuy) ok = Trade.Buy(lots,_Symbol,0.0,sl,tp);
    else      ok = Trade.Sell(lots,_Symbol,0.0,sl,tp);
    if(ok)
    {
      // Try to capture current position ticket for stats
      if(PositionSelect(_Symbol))
      {
        g_pos_ticket = (long)PositionGetInteger(POSITION_TICKET);
        LogWrite(StringFormat("Entry: %s lots=%.2f sl=%.5f tp=%.5f zone=%s trigger=%s posTicket=%I64d",
                 isBuy?"BUY":"SELL", lots, sl, tp,
                 (g_setup.activeZone==1?"FVG":(g_setup.activeZone==2?"OB":"?")),
                 (g_curr_trigger_type==1?"BOS":"IFVG"), g_pos_ticket));
        if(g_setup.activeZone==1) g_stats.entriesFVG++; else if(g_setup.activeZone==2) g_stats.entriesOB++;
        g_trade_profit_accum = 0.0;
      }
      return true;
    }
    else
    {
      long rc = Trade.ResultRetcode();
      string rcd = Trade.ResultRetcodeDescription();
      LogWrite(StringFormat("Entry FAILED: %s retcode=%I64d (%s)", isBuy?"BUY":"SELL", rc, rcd));
      return false;
    }
  }
  // TODO: set SL/TP after open; implement LIMIT_AT_IFVG/SMART_BOTH
  return false;
}

void ManagePositions()
{
  if(!PositionSelect(_Symbol)) return;
  long mg = PositionGetInteger(POSITION_MAGIC);
  if(mg!=in_magic_number) return;
  long type = PositionGetInteger(POSITION_TYPE);
  double vol = PositionGetDouble(POSITION_VOLUME);
  double sl  = PositionGetDouble(POSITION_SL);
  double tp  = PositionGetDouble(POSITION_TP);

  // TP1 at 50% of A
  if(in_tp1_enable && !g_setup.tp1Done && in_tp1_at_50pct_of_A)
  {
    double tp1 = (g_setup.swingA.low + g_setup.swingA.high)*0.5;
    if(type==POSITION_TYPE_BUY)
    {
      double bid= SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid>=tp1)
      {
        double closeVol = NormalizeLots(vol*0.5);
        Trade.PositionClosePartial(_Symbol, closeVol);
        g_setup.tp1Done = true;
        g_stats.tp1Hits++;
        LogWrite(StringFormat("TP1 hit: partial close %.2f lots at %.5f", closeVol, bid));
      }
    }
    else if(type==POSITION_TYPE_SELL)
    {
      double ask= SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask<=tp1)
      {
        double closeVol = NormalizeLots(vol*0.5);
        Trade.PositionClosePartial(_Symbol, closeVol);
        g_setup.tp1Done = true;
        g_stats.tp1Hits++;
        LogWrite(StringFormat("TP1 hit: partial close %.2f lots at %.5f", closeVol, ask));
      }
    }
  }

  // Trailing after TP1
  if(g_setup.tp1Done)
  {
    double atr = GetATR(g_atr_ltf_handle);
    double dist = atr * in_trailing_stop_atr_factor;
    if(type==POSITION_TYPE_BUY)
    {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double newSL = NormalizePrice(bid - dist);
      if(newSL > sl) Trade.PositionModify(_Symbol, newSL, tp);
      if(newSL > sl) LogWrite(StringFormat("Trail SL moved to %.5f (BUY)", newSL));
    }
    else if(type==POSITION_TYPE_SELL)
    {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double newSL = NormalizePrice(ask + dist);
      if(sl==0 || newSL < sl) Trade.PositionModify(_Symbol, newSL, tp);
      if(sl==0 || newSL < sl) LogWrite(StringFormat("Trail SL moved to %.5f (SELL)", newSL));
    }
  }
}

// Lifecycle ----------------------------------------------------------
int OnInit()
{
  g_anchor_period = TfToPeriod(in_anchor_tf);
  g_trigger_period = (in_trigger_tf_mode==TRIG_AUTO_TABLE)
                     ? AutoTriggerForAnchor(in_anchor_tf)
                     : TfToPeriod(in_trigger_tf_manual);

  g_atr_anchor_handle = iATR(_Symbol, g_anchor_period, 14);
  g_atr_ltf_handle    = iATR(_Symbol, g_trigger_period, 14);
  if(g_atr_anchor_handle==INVALID_HANDLE || g_atr_ltf_handle==INVALID_HANDLE)
  {
    Print("[CTI] Failed to create ATR handles");
    return(INIT_FAILED);
  }

  // Logging & stats
  StatsInit();
  OpenLog();
  LogWrite(StringFormat("Init: Symbol=%s Anchor=%s Trigger=%s", _Symbol, TfToStr(g_anchor_period), TfToStr(g_trigger_period)));

  g_state = ST_WAIT_BOS;
  // Reset setup using safe initialization (no struct literal casts)
  ZeroMemory(g_setup);
  g_setup.active=false;
  g_setup.isBuy=false;
  g_setup.activeZone=0;
  g_setup.expiryBarsLeft=in_setup_expiry_bars_anchor;
  g_setup.ltfBarsLeft=0;
  g_setup.tp1Done=false;
  g_setup.retestTime=0;
  if(in_debug)
    PrintFormat("[CTI] Init OK. Anchor=%d Trigger=%d", g_anchor_period, g_trigger_period);
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  // If still in trade, report open P/L snapshot for transparency
  if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==in_magic_number)
  {
    double fpl = PositionGetDouble(POSITION_PROFIT);
    LogWrite(StringFormat("Deinit with open position. Floating P/L=%.2f", fpl));
    if(in_summary_count_open_as_trade)
    {
      g_stats.trades++;
      if(fpl>=0) { g_stats.wins++; g_stats.grossProfit += fpl; }
      else { g_stats.losses++; g_stats.grossLoss += -fpl; }
      g_stats.netProfit += fpl;
      LogWrite(StringFormat("Counted open position as trade in summary: net=%.2f", fpl));
    }
  }
  DumpStats();
  CloseLog();
}

// Track deals to aggregate profit/loss and finalize trades in stats
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
  // Ensure history window is available for HistoryDeal* calls
  HistorySelect(0, TimeCurrent());
  if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
  ulong deal = trans.deal;
  if(deal==0) return;
  long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
  if(magic!=in_magic_number) return; // not ours

  long entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
  double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
  double swap   = HistoryDealGetDouble(deal, DEAL_SWAP);
  double comm   = HistoryDealGetDouble(deal, DEAL_COMMISSION);
  long  posId   = (long)HistoryDealGetInteger(deal, DEAL_POSITION_ID);

  // Accumulate only exits (including partial)
  if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT)
  {
    g_trade_profit_accum += (profit+swap+comm);
    LogWrite(StringFormat("Deal OUT: pos=%I64d profit=%.2f accum=%.2f", posId, profit+swap+comm, g_trade_profit_accum));

    // If no more position open on symbol, finalize trade
    bool open = PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==in_magic_number;
    if(!open)
    {
      g_stats.trades++;
      if(g_trade_profit_accum>=0) { g_stats.wins++; g_stats.grossProfit += g_trade_profit_accum; }
      else { g_stats.losses++; g_stats.grossLoss += -g_trade_profit_accum; }
      g_stats.netProfit += g_trade_profit_accum;
      LogWrite(StringFormat("Trade closed: net=%.2f (W:%d L:%d)", g_trade_profit_accum, g_stats.wins, g_stats.losses));
      g_trade_profit_accum = 0.0;
      g_pos_ticket = -1;
      // Reset to wait BOS again
      g_state = ST_WAIT_BOS;
      g_setup.active=false;
    }
  }
}

void OnTick()
{
  if(!SessionOk() || !SpreadOk()) return;

  // Intrabar retest detection and expiry while waiting retest
  if(g_state==ST_WAIT_RETEST && in_enable_retest_intrabar)
  {
    // Expiry by absolute time if set
    if(g_setup.expiryTime>0 && TimeCurrent()>g_setup.expiryTime)
    {
      LogWrite("Setup expired in WAIT_RETEST (time-based). Reset to WAIT_BOS.");
      g_setup.active=false; g_state=ST_WAIT_BOS; g_setup.activeZone=0; g_setup.retestTime=0; g_setup.expiryTime=0;
    }
    else
    {
      int znow = RetestHitNow(g_setup.fvgA, g_setup.obA);
      if(znow>0)
      {
        g_setup.activeZone = znow;
        g_state = ST_WAIT_TRIGGER;
        g_setup.ltfBarsLeft = in_trigger_window_bars_ltf;
        g_setup.retestTime = TimeCurrent();
        if(g_setup.expiryTime==0) g_setup.expiryTime = TimeCurrent() + (datetime)PeriodSeconds(g_anchor_period) * (datetime)in_setup_expiry_bars_anchor;
        g_last_ltf_bar_time = 0;
        LogWrite(StringFormat("Intrabar retest hit in %s zone.", (znow==1?"FVG":"OB")));
      }
    }
  }

  // Safety: if we think we're in trade but there is no position anymore, try to finalize via history and reset state
  if(g_state==ST_IN_TRADE)
  {
    bool hasPos = PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==in_magic_number;
    if(!hasPos)
    {
      // Try finalize from history using stored position ticket
      HistorySelect(0, TimeCurrent());
      double sum=0.0; bool found=false;
      if(g_pos_ticket>0)
      {
        int total = HistoryDealsTotal();
        for(int i=total-1;i>=0;i--)
        {
          ulong d = HistoryDealGetTicket(i);
          if((long)HistoryDealGetInteger(d, DEAL_MAGIC)!=in_magic_number) continue;
          if((long)HistoryDealGetInteger(d, DEAL_POSITION_ID)!=(long)g_pos_ticket) continue;
          long entry = (long)HistoryDealGetInteger(d, DEAL_ENTRY);
          if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT)
          {
            double pr = HistoryDealGetDouble(d, DEAL_PROFIT)+HistoryDealGetDouble(d, DEAL_SWAP)+HistoryDealGetDouble(d, DEAL_COMMISSION);
            sum += pr; found=true;
          }
        }
      }
      if(found)
      {
        g_stats.trades++;
        if(sum>=0) { g_stats.wins++; g_stats.grossProfit += sum; }
        else { g_stats.losses++; g_stats.grossLoss += -sum; }
        g_stats.netProfit += sum;
        LogWrite(StringFormat("Recovered trade from history: pos=%I64d net=%.2f", g_pos_ticket, sum));
      }
      else
      {
        LogWrite("No open position found while in ST_IN_TRADE; resetting state.");
      }
      g_pos_ticket=-1;
      g_state = ST_WAIT_BOS;
      g_setup.active=false;
    }
  }

  // LTF handling for trigger window
  if(g_state==ST_WAIT_TRIGGER)
  {
    if(NewBarArrived(g_trigger_period, g_last_ltf_bar_time))
    {
      if(--g_setup.ltfBarsLeft<=0)
      {
        if(in_debug) Print("[CTI] Trigger window expired on LTF. Reset.");
        g_setup.active=false; g_state=ST_WAIT_BOS;
      }
      else
      {
        double slRef=0;
        if(TriggerOnLTF(g_setup.isBuy, slRef))
        {
          double atrA = GetATR(g_atr_anchor_handle);
          double atrL = GetATR(g_atr_ltf_handle);
          double sl = 0.0;
          if(in_sl_mode==SL_LTF_STRUCTURE)
            sl = g_setup.isBuy ? (slRef - atrL*in_sl_buffer_atr_factor) : (slRef + atrL*in_sl_buffer_atr_factor);
          else
            sl = g_setup.isBuy ? (g_setup.swingA.low - atrA*in_sl_buffer_atr_factor) : (g_setup.swingA.high + atrA*in_sl_buffer_atr_factor);
          double tp = g_setup.isBuy ? g_setup.swingA.high : g_setup.swingA.low;
          bool placed = PlaceEntry(g_setup.isBuy, sl, tp);
          if(placed)
          {
            g_state = ST_IN_TRADE;
            g_setup.tp1Done=false;
            if(in_debug) Print("[CTI] Entry placed from LTF trigger.");
          }
          else
          {
            // keep waiting for another trigger within window
            if(in_debug) Print("[CTI] Entry failed; still in WAIT_TRIGGER window.");
          }
        }
      }
    }
  }

  // State machine driven by anchor new bars
  if(!NewBarArrived(g_anchor_period, g_last_anchor_bar_time))
  {
    if(g_state==ST_IN_TRADE) ManagePositions();
    return;
  }

  if(in_debug && g_state!=ST_IN_TRADE) PrintFormat("[CTI] New anchor bar. State=%s", StateToStr(g_state));

  switch(g_state)
  {
    case ST_WAIT_BOS:
    {
      bool isBuy=false; Swing sA;
      if(DetectBOSAnchor(isBuy, sA))
      {
        g_setup.active=true; g_setup.isBuy=isBuy; g_setup.swingA=sA; g_setup.expiryBarsLeft=in_setup_expiry_bars_anchor;
        g_state = ST_WAIT_FVG;
        if(in_debug) Print("[CTI] BOS confirmed. Waiting FVG in leg A.");
        LogWrite(StringFormat("BOS confirmed: dir=%s swingA[low=%.5f high=%.5f]", isBuy?"BUY":"SELL", g_setup.swingA.low, g_setup.swingA.high));
      }
      break;
    }
    case ST_WAIT_FVG:
    {
      if(!g_setup.active){ g_state=ST_WAIT_BOS; break; }
      bool hasZone=false;
      if(in_anchor_zone_allow_fvg)
      {
        FVGZone fvg; if(FindAnchorFVG(g_setup.isBuy,fvg)) { g_setup.fvgA=fvg; hasZone=true; }
      }
      if(in_anchor_zone_allow_ob)
      {
        FVGZone ob; if(FindAnchorOB(g_setup.isBuy,ob)) { g_setup.obA=ob; hasZone=true; }
      }
      if(hasZone)
      {
        g_state = ST_WAIT_RETEST;
        if(in_debug) Print("[CTI] Zone(s) found (FVG/OB). Waiting retest.");
        if(g_setup.fvgA.top!=0 || g_setup.fvgA.bottom!=0)
          LogWrite(StringFormat("Zone FVG: [%.5f..%.5f]", MathMin(g_setup.fvgA.top,g_setup.fvgA.bottom), MathMax(g_setup.fvgA.top,g_setup.fvgA.bottom)));
        if(g_setup.obA.top!=0 || g_setup.obA.bottom!=0)
          LogWrite(StringFormat("Zone OB:  [%.5f..%.5f]", MathMin(g_setup.obA.top,g_setup.obA.bottom), MathMax(g_setup.obA.top,g_setup.obA.bottom)));
      }
      else if(--g_setup.expiryBarsLeft<=0)
      {
        if(in_debug) Print("[CTI] Setup expired while waiting zones.");
        g_setup.active=false; g_state=ST_WAIT_BOS;
      }
      break;
    }
    case ST_WAIT_RETEST:
    {
      // Optionally allow preemption by a new BOS (same direction)
      if(in_allow_preempt_on_new_bos)
      {
        bool nb=false; Swing sN;
        if(DetectBOSAnchor(nb, sN) && nb==g_setup.isBuy)
        {
          g_setup.swingA = sN;
          g_setup.fvgA.top=0; g_setup.fvgA.bottom=0; g_setup.fvgA.anchorIndex=0;
          g_setup.obA.top=0;  g_setup.obA.bottom=0;  g_setup.obA.anchorIndex=0;
          g_setup.activeZone=0;
          g_state = ST_WAIT_FVG;
          LogWrite("Preempt: New BOS detected, refreshing setup and searching zones.");
          break;
        }
      }
      int z = RetestIntoZones(g_setup.fvgA, g_setup.obA);
      if(z>0)
      {
        g_setup.activeZone = z;
        g_state = ST_WAIT_TRIGGER;
        g_setup.ltfBarsLeft = in_trigger_window_bars_ltf;
        // align retest time to last closed anchor bar
        MqlRates ar2[]; if(CopyRatesSeries(_Symbol, g_anchor_period, 2, ar2)) g_setup.retestTime = ar2[1].time; else { datetime now=TimeCurrent(); g_setup.retestTime = now; }
        // set absolute expiry for retest window as fallback
        g_setup.expiryTime = TimeCurrent() + (datetime)PeriodSeconds(g_anchor_period) * (datetime)in_setup_expiry_bars_anchor;
        g_last_ltf_bar_time = 0; // reset LTF bar detection window
        if(in_debug) PrintFormat("[CTI] Retest in zone: %s. Switching to LTF trigger window.", (z==1?"FVG":"OB"));
        LogWrite(StringFormat("Retest in %s zone at %s", (z==1?"FVG":"OB"), TimeToString(g_setup.retestTime, TIME_DATE|TIME_SECONDS)));
      }
      break;
    }
    case ST_WAIT_TRIGGER:
    {
      // handled by LTF bar clock above
      break;
    }
    case ST_IN_TRADE:
    {
      ManagePositions();
      break;
    }
    default: break;
  }
}

//+------------------------------------------------------------------+
