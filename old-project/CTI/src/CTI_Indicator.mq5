//+------------------------------------------------------------------+
//|                                                CTI_Indicator.mq5 |
//| ICT visual helper: highlights BOS, FVG, and OB zones on chart   |
//| Pairs with CTI_EA.mq5 logic for quicker discretionary review    |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0

enum CT_TF { TF_M1, TF_M5, TF_M15, TF_M30, TF_H1, TF_H4 };
enum BOS_CONFIRM_MODE { BOS_CLOSE_ONLY, BOS_CLOSE_OR_WICK };
enum PADDING_MODE { PAD_ATR, PAD_POINTS, PAD_SWING_PCT };

input CT_TF            in_anchor_tf                 = TF_M5;
input int              in_swing_bars_anchor         = 5;
input BOS_CONFIRM_MODE in_bos_confirm_mode          = BOS_CLOSE_ONLY;
input PADDING_MODE     in_bos_padding_mode          = PAD_ATR;
input double           in_bos_padding_atr_factor    = 0.00;
input int              in_bos_padding_points        = 0;
input double           in_bos_padding_swing_pct     = 0.00;

input int              in_atr_period                = 14;
input double           in_fvg_min_atr_factor_anchor = 0.30;
input int              in_fvg_extend_bars_after_bos = 5;
input bool             in_show_fvg                  = true;
input bool             in_show_ob                   = true;
input bool             in_ob_use_wick               = false;
input int              in_ob_max_candles_back_in_A  = 5;
input int              in_zone_extend_bars          = 30;
// Swing sizing/preferences
input bool             in_anchor_prefer_external    = true;   // expand to external swing if range too small
input int              in_anchor_search_bars        = 120;    // how far older to scan for external pivot
input double           in_anchor_min_range_atr      = 0.60;   // min A range (ATR multiples) before expanding

input color            in_color_buy_zone            = clrLime;
input color            in_color_sell_zone           = clrTomato;
input color            in_color_swing_line          = clrDodgerBlue;
input color            in_color_text                = clrWhite;
input int              in_label_corner              = CORNER_RIGHT_LOWER;

struct Swing
{
  int      idxHigh;
  int      idxLow;
  double   high;
  double   low;
  datetime tHigh;
  datetime tLow;
};

struct Zone
{
  double   top;
  double   bottom;
  datetime left;
  datetime right;
  int      anchorIndex;
};

ENUM_TIMEFRAMES g_anchor_period = PERIOD_CURRENT;
int             g_atr_handle    = INVALID_HANDLE;
datetime        g_last_swing_time = 0;
bool            g_last_is_buy     = true;

const string CTI_PREFIX = "CTI_IND_";

//--- helpers --------------------------------------------------------
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
    default:         return IntegerToString((int)p);
  }
}

bool CopyRatesSeries(const string symbol, const ENUM_TIMEFRAMES period, const int count, MqlRates &arr[])
{
  int copied = CopyRates(symbol, period, 0, count, arr);
  if(copied <= 0) return false;
  ArraySetAsSeries(arr, true);
  return true;
}

double GetATR(int handle)
{
  double buff[];
  if(handle==INVALID_HANDLE) return 0.0;
  if(CopyBuffer(handle,0,0,1,buff)!=1) return 0.0;
  return buff[0];
}

double BosPadding(const Swing &s, const double atr)
{
  if(in_bos_padding_mode==PAD_ATR)
    return atr * in_bos_padding_atr_factor;
  if(in_bos_padding_mode==PAD_POINTS)
    return in_bos_padding_points * _Point;
  if(in_bos_padding_mode==PAD_SWING_PCT)
  {
    double range = MathMax(1e-8, MathAbs(s.high - s.low));
    return range * in_bos_padding_swing_pct;
  }
  return 0.0;
}

bool IsFractalHigh(MqlRates &arr[], int i, int look)
{
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

// Expand the selected swing to a more external pivot to satisfy a minimum range (in ATR multiples).
void ExpandSwingExternal(MqlRates &ar[], const int bars, const int look, const bool isBuy,
                         const double minRange, const int maxSearchBars, Swing &s)
{
  if(minRange<=0.0 || maxSearchBars<=0) return;
  // Array is series: larger index = older bar
  if(isBuy)
  {
    // Ensure low is older than high
    if(s.idxLow < s.idxHigh)
    {
      int ti=s.idxLow; s.idxLow=s.idxHigh; s.idxHigh=ti;
      double tp=s.low; s.low=s.high; s.high=tp;
      datetime tt=s.tLow; s.tLow=s.tHigh; s.tHigh=tt;
    }
    double bestLow = s.low; int bestIdx = s.idxLow; datetime bestT = s.tLow;
    int limit = MathMin(bars-look-1, s.idxLow + maxSearchBars);
    for(int i=s.idxLow+look+1; i<=limit; i++)
    {
      if(IsFractalLow(ar,i,look))
      {
        if(ar[i].low < bestLow)
        {
          bestLow = ar[i].low; bestIdx=i; bestT=ar[i].time;
        }
        if(s.high - bestLow >= minRange) break;
      }
    }
    s.idxLow = bestIdx; s.low=bestLow; s.tLow=bestT;
  }
  else
  {
    // Ensure high is older than low
    if(s.idxHigh < s.idxLow)
    {
      int ti=s.idxHigh; s.idxHigh=s.idxLow; s.idxLow=ti;
      double tp=s.high; s.high=s.low; s.low=tp;
      datetime tt=s.tHigh; s.tHigh=s.tLow; s.tLow=tt;
    }
    double bestHigh = s.high; int bestIdx = s.idxHigh; datetime bestT = s.tHigh;
    int limit = MathMin(bars-look-1, s.idxHigh + maxSearchBars);
    for(int i=s.idxHigh+look+1; i<=limit; i++)
    {
      if(IsFractalHigh(ar,i,look))
      {
        if(ar[i].high > bestHigh)
        {
          bestHigh = ar[i].high; bestIdx=i; bestT=ar[i].time;
        }
        if(bestHigh - s.low >= minRange) break;
      }
    }
    s.idxHigh = bestIdx; s.high=bestHigh; s.tHigh=bestT;
  }
}

bool DetectBOSAnchor(bool &isBuy, Swing &swingA)
{
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 400, ar)) return false;
  int bars = ArraySize(ar);
  if(bars < in_swing_bars_anchor*3 + 10) return false;

  int idxH=-1, idxL=-1; double prH=0, prL=0; datetime tH=0, tL=0;
  if(!GetLastSwingHigh(ar,bars,in_swing_bars_anchor,idxH,prH,tH)) return false;
  if(!GetLastSwingLow(ar,bars,in_swing_bars_anchor,idxL,prL,tL)) return false;

  if(idxH >= idxL)
  {
    for(int i=idxH+in_swing_bars_anchor+1; i<bars-in_swing_bars_anchor; i++)
    {
      if(IsFractalLow(ar,i,in_swing_bars_anchor)) { idxL=i; prL=ar[i].low; tL=ar[i].time; break; }
    }
  }
  if(idxL >= idxH)
  {
    for(int i=idxL+in_swing_bars_anchor+1; i<bars-in_swing_bars_anchor; i++)
    {
      if(IsFractalHigh(ar,i,in_swing_bars_anchor)) { idxH=i; prH=ar[i].high; tH=ar[i].time; break; }
    }
  }
  if(idxH<0 || idxL<0) return false;

  double atrA = GetATR(g_atr_handle);
  Swing s; s.idxHigh=idxH; s.idxLow=idxL; s.high=prH; s.low=prL; s.tHigh=tH; s.tLow=tL;
  double pad = BosPadding(s, atrA);

  double c1 = ar[1].close;
  bool bosBuy = (c1 > prH + pad);
  bool bosSell = (c1 < prL - pad);

  if(in_bos_confirm_mode==BOS_CLOSE_OR_WICK)
  {
    bosBuy = bosBuy || (ar[1].high > prH + pad);
    bosSell = bosSell || (ar[1].low  < prL - pad);
  }

  if(!(bosBuy || bosSell)) return false;
  isBuy = (bosBuy && !bosSell);
  if(!isBuy && bosSell) isBuy = false;
  if(isBuy)
  {
    if(s.idxLow < s.idxHigh)
    {
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

  // Optionally expand to a more external swing if current A-range is too small
  double atrA2 = GetATR(g_atr_handle);
  if(in_anchor_prefer_external && atrA2>0.0)
  {
    double minRange = atrA2 * in_anchor_min_range_atr;
    double range    = MathAbs(s.high - s.low);
    if(range < minRange)
      ExpandSwingExternal(ar, bars, in_swing_bars_anchor, isBuy, minRange, in_anchor_search_bars, s);
  }

  swingA = s;
  return true;
}

bool FindAnchorFVG(const bool isBuy, const Swing &swingA, const double atrA, Zone &fvg)
{
  if(!in_show_fvg) return false;
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 600, ar)) return false;
  int bars = ArraySize(ar);
  if(bars < 10) return false;

  datetime tStart = swingA.tLow;
  datetime tEnd   = swingA.tHigh;
  double minSize  = atrA * in_fvg_min_atr_factor_anchor;
  int afterCount  = 0;

  for(int k=2; k<bars-2; k++)
  {
    datetime tk = ar[k].time;
    if(tk < tStart) break;
    if(tk > tEnd)
    {
      if(afterCount >= in_fvg_extend_bars_after_bos) continue;
      afterCount++;
    }

    if(isBuy)
    {
      double top = ar[k].low;
      double bot = ar[k+2].high;
      if(top - bot > minSize)
      {
        fvg.top = top;
        fvg.bottom = bot;
        fvg.anchorIndex = k;
        datetime left  = (ar[k].time   < ar[k+2].time) ? ar[k].time   : ar[k+2].time;
        fvg.left  = left;
        fvg.right = TimeCurrent() + (datetime)PeriodSeconds(g_anchor_period) * in_zone_extend_bars;
        return true;
      }
    }
    else
    {
      double top = ar[k].high;
      double bot = ar[k+2].low;
      if(top - bot > minSize)
      {
        fvg.top = top;
        fvg.bottom = bot;
        fvg.anchorIndex = k;
        datetime left  = (ar[k].time   < ar[k+2].time) ? ar[k].time   : ar[k+2].time;
        fvg.left  = left;
        fvg.right = TimeCurrent() + (datetime)PeriodSeconds(g_anchor_period) * in_zone_extend_bars;
        return true;
      }
    }
  }
  return false;
}

bool FindAnchorOB(const bool isBuy, const Swing &swingA, Zone &ob)
{
  if(!in_show_ob) return false;
  MqlRates ar[];
  if(!CopyRatesSeries(_Symbol, g_anchor_period, 600, ar)) return false;
  int bars = ArraySize(ar);

  datetime tStart = swingA.tLow;
  datetime tEnd   = swingA.tHigh;

  int found=-1; int scans=0;
  for(int k=1; k<bars-1; k++)
  {
    datetime tk = ar[k].time;
    if(tk > tEnd) continue;
    if(tk < tStart) break;
    bool bearish = (ar[k].close < ar[k].open);
    bool bullish = (ar[k].close > ar[k].open);
    if(isBuy && bearish)
    {
      found = k;
      if(++scans >= in_ob_max_candles_back_in_A) break;
    }
    if(!isBuy && bullish)
    {
      found = k;
      if(++scans >= in_ob_max_candles_back_in_A) break;
    }
  }
  if(found==-1) return false;

  double top, bot;
  if(in_ob_use_wick)
  {
    top = ar[found].high;
    bot = ar[found].low;
  }
  else
  {
    top = MathMax(ar[found].open, ar[found].close);
    bot = MathMin(ar[found].open, ar[found].close);
  }
  ob.top = top;
  ob.bottom = bot;
  ob.anchorIndex = found;
  ob.left = ar[found].time;
  ob.right = TimeCurrent() + (datetime)PeriodSeconds(g_anchor_period) * in_zone_extend_bars;
  return true;
}

void EnsureRectangle(const string name, const Zone &z, const color col)
{
  double top    = MathMax(z.top, z.bottom);
  double bottom = MathMin(z.top, z.bottom);
  datetime left = z.left;
  datetime right = (z.right>left ? z.right : left + (datetime)PeriodSeconds(g_anchor_period)*in_zone_extend_bars);

  if(ObjectFind(0, name) < 0)
  {
    ObjectCreate(0, name, OBJ_RECTANGLE, 0, left, top, right, bottom);
  }
  else
  {
    ObjectMove(0, name, 0, left, top);
    ObjectMove(0, name, 1, right, bottom);
  }
  ObjectSetInteger(0, name, OBJPROP_COLOR, col);
  ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
  ObjectSetInteger(0, name, OBJPROP_BACK, true);
  ObjectSetInteger(0, name, OBJPROP_FILL, true);
  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void EnsureSwingLine(const Swing &swingA, const bool isBuy)
{
  string name = CTI_PREFIX + "SWING";
  datetime t1 = isBuy ? swingA.tLow : swingA.tHigh;
  double   p1 = isBuy ? swingA.low  : swingA.high;
  datetime t2 = isBuy ? swingA.tHigh: swingA.tLow;
  double   p2 = isBuy ? swingA.high : swingA.low;
  if(ObjectFind(0, name) < 0)
  {
    ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
  }
  else
  {
    ObjectMove(0, name, 0, t1, p1);
    ObjectMove(0, name, 1, t2, p2);
  }
  ObjectSetInteger(0, name, OBJPROP_COLOR, in_color_swing_line);
  ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
  ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void EnsureBosLine(const Swing &swingA, const bool isBuy)
{
  string name = CTI_PREFIX + "BOS";
  double level = isBuy ? swingA.high : swingA.low;
  if(ObjectFind(0, name) < 0)
  {
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, level);
  }
  ObjectSetDouble(0, name, OBJPROP_PRICE, level);
  ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? in_color_buy_zone : in_color_sell_zone);
  ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
  ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void EnsureInfoLabel(const Swing &swingA, const bool isBuy, const bool hasFVG, const bool hasOB)
{
  string name = CTI_PREFIX + "INFO";
  string txt = StringFormat("CTI %s %s BOS\nSwing: %.5f ↔ %.5f\nFVG: %s | OB: %s",
                            TfToStr(g_anchor_period), isBuy?"BULL" : "BEAR",
                            swingA.low, swingA.high,
                            hasFVG?"yes":"no",
                            hasOB?"yes":"no");
  if(ObjectFind(0, name) < 0)
  {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
  }
  ObjectSetInteger(0, name, OBJPROP_CORNER, in_label_corner);
  ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
  ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
  ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
  ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  ObjectSetInteger(0, name, OBJPROP_COLOR, in_color_text);
  ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void DeleteObject(const string suffix)
{
  string name = CTI_PREFIX + suffix;
  if(ObjectFind(0, name) >= 0)
    ObjectDelete(0, name);
}

void ClearVisuals()
{
  DeleteObject("SWING");
  DeleteObject("BOS");
  DeleteObject("FVG");
  DeleteObject("OB");
  DeleteObject("INFO");
}

//--- lifecycle ------------------------------------------------------
int OnInit()
{
  g_anchor_period = TfToPeriod(in_anchor_tf);
  g_atr_handle = iATR(_Symbol, g_anchor_period, in_atr_period);
  if(g_atr_handle==INVALID_HANDLE)
  {
    Print("[CTI_IND] Failed to create ATR handle");
    return INIT_FAILED;
  }
  IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CTI BOS/FVG (%s)", TfToStr(g_anchor_period)));
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  ClearVisuals();
  if(g_atr_handle!=INVALID_HANDLE)
  {
    IndicatorRelease(g_atr_handle);
    g_atr_handle = INVALID_HANDLE;
  }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[] ,
                const double &open[] ,
                const double &high[] ,
                const double &low[] ,
                const double &close[] ,
                const long &tick_volume[] ,
                const long &volume[] ,
                const int &spread[])
{
  double atrA = GetATR(g_atr_handle);
  if(atrA <= 0.0)
  {
    ClearVisuals();
    return rates_total;
  }

  bool isBuy=false;
  Swing swingA;
  if(!DetectBOSAnchor(isBuy, swingA))
  {
    ClearVisuals();
    return rates_total;
  }

  Zone fvg; ZeroMemory(fvg); bool hasFVG = FindAnchorFVG(isBuy, swingA, atrA, fvg);
  Zone ob;  ZeroMemory(ob);  bool hasOB  = FindAnchorOB(isBuy, swingA, ob);

  EnsureSwingLine(swingA, isBuy);
  EnsureBosLine(swingA, isBuy);

  if(hasFVG)
    EnsureRectangle(CTI_PREFIX+"FVG", fvg, isBuy?in_color_buy_zone:in_color_sell_zone);
  else
    DeleteObject("FVG");

  if(hasOB)
    EnsureRectangle(CTI_PREFIX+"OB", ob, isBuy?in_color_buy_zone:in_color_sell_zone);
  else
    DeleteObject("OB");

  EnsureInfoLabel(swingA, isBuy, hasFVG, hasOB);

  g_last_swing_time = swingA.tHigh;
  g_last_is_buy     = isBuy;
  return rates_total;
}
//+------------------------------------------------------------------+
