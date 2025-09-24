
//+------------------------------------------------------------------+
//|                                                   BOS_CHoCH.mq5  |
//|                          © 2025, YourName (free to use/modify)   |
//|   Indicator marks Break of Structure (BOS) and CHoCH using       |
//|   *BODY CLOSE* beyond last swing High/Low (fractals).            |
//|   Works on any symbol / timeframe.                               |
//+------------------------------------------------------------------+
#property copyright "© 2025, Open-Source"
#property link      "https://"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//---- inputs
input int    LeftBars   = 2;          // Swing left (fractals)
input int    RightBars  = 2;          // Swing right (fractals)
input double BreakBufferPoints = 0;   // Extra points required beyond the level (0 = just close beyond)
input bool   DrawSwingToBreak = true; // Draw dashed line from swing to break
input bool   MarkSwings       = false;// Draw tiny markers on confirmed swings

// Label styles
input color  ColorBOS_Up      = clrLime;
input color  ColorBOS_Down    = clrTomato;
input color  ColorCHOCH_Up    = clrDeepSkyBlue;
input color  ColorCHOCH_Down  = clrOrange;
input int    TextSize         = 10;
input int    VertOffsetPixels = 10;   // Vertical text offset in pixels
input string ObjPrefix        = "BOSCHOCH_";

//---- enums / state
enum TrendMS {MS_None=0, MS_Bull=1, MS_Bear=2};

//---- helper to make unique names
string Prefix()
{
   return(ObjPrefix + _Symbol + "_" + IntegerToString(Period()) + "_");
}

//---- object helpers
void CreateText(const string name, const datetime t, const double price, const color col, const string txt)
{
   long cid = ChartID();
   if(ObjectFind(cid,name) == -1)
   {
      ObjectCreate(cid,name,OBJ_TEXT,0,t,price);
      ObjectSetInteger(cid,name,OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(cid,name,OBJPROP_BACK,false);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(cid,name,OBJPROP_FONTSIZE,TextSize);
      ObjectSetString (cid,name,OBJPROP_FONT,"Arial");
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetDouble (cid,name,OBJPROP_ANGLE,0);
   }
   // keep text positioned with a small vertical offset (in pixels)
   int x,y;
   datetime new_time = t;
   double new_price = price;
   ChartTimePriceToXY(0,0,t,price,x,y);
   y -= VertOffsetPixels;
   ChartXYToTimePrice(0,0,x,y,new_time,new_price);
   ObjectSetInteger(0,name,OBJPROP_TIME,new_time);
   ObjectSetDouble (0,name,OBJPROP_PRICE,new_price);
   ObjectSetString (0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
}

void CreateHSegment(string name, datetime t1, double price, datetime t2, color col, int width=1)
{
   long cid = ChartID();
   if(ObjectFind(cid,name) == -1)
   {
      ObjectCreate(cid,name,OBJ_TREND,0,t1,price,t2,price);
      ObjectSetInteger(cid,name,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_RAY,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,true);
   }
   else
   {
      ObjectSetInteger(cid,name,OBJPROP_TIME,0,t1);
      ObjectSetDouble (cid,name,OBJPROP_PRICE,0,price);
      ObjectSetInteger(cid,name,OBJPROP_TIME,1,t2);
      ObjectSetDouble (cid,name,OBJPROP_PRICE,1,price);
   }
}

void CreateSwingDot(string name, datetime t, double price, color col)
{
   long cid = ChartID();
   if(ObjectFind(cid,name) == -1)
   {
      ObjectCreate(cid,name,OBJ_ARROW,0,t,price);
      ObjectSetInteger(cid,name,OBJPROP_ARROWCODE,159); // small dot
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,true);
   }
   else
   {
      ObjectSetInteger(cid,name,OBJPROP_TIME,t);
      ObjectSetDouble (cid,name,OBJPROP_PRICE,price);
   }
}

//---- scratch arrays in chronological order (0 = oldest)
double  hi[], lo[], cl[];
datetime tm[];
bool isHigh[], isLow[];

//---- mapping helper: convert chronological index m to chart index i (time-series)
int m2i(const int m, const int N){ return(N-1-m); }

//---- detection helpers
void BuildChronological(const int N, const double &High[], const double &Low[], const double &Close[], const datetime &Time[])
{
   ArrayResize(hi,N);
   ArrayResize(lo,N);
   ArrayResize(cl,N);
   ArrayResize(tm,N);
   // Fill so that m=0 is oldest, m=N-1 is newest (current bar)
   for(int m=0; m<N; m++)
   {
      int i = N-1-m;
      hi[m] = High[i];
      lo[m] = Low[i];
      cl[m] = Close[i];
      tm[m] = Time[i];
   }
}

void DetectSwings(const int N)
{
   ArrayResize(isHigh,N);
   ArrayResize(isLow ,N);
   ArrayInitialize(isHigh,false);
   ArrayInitialize(isLow ,false);
   for(int m=LeftBars; m<=N-1-RightBars; m++)
   {
      bool sh=true, sl=true;
      // left side
      for(int k=1;k<=LeftBars;k++)
      {
         if(hi[m] <= hi[m-k]) sh=false;
         if(lo[m] >= lo[m-k]) sl=false;
         if(!sh && !sl) break;
      }
      // right side
      if(sh || sl)
      {
         for(int k=1;k<=RightBars;k++)
         {
            if(hi[m] <= hi[m+k]) sh=false;
            if(lo[m] >= lo[m+k]) sl=false;
            if(!sh && !sl) break;
         }
      }
      if(sh) isHigh[m]=true;
      if(sl) isLow[m]=true;
   }
}

// small utility
double BufferInPoints()
{
   return(BreakBufferPoints * _Point);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   int N = rates_total;
   if(N < LeftBars+RightBars+10)
      return(rates_total);

   // Pull standard timeseries arrays
   MqlRates rates[];
   int copied = CopyRates(_Symbol,Period(),0,N,rates);
   if(copied != N) N = copied;
   if(N < LeftBars+RightBars+10) return(rates_total);

   double H[],L[],C[];
   datetime T[];
   ArrayResize(H,N); ArrayResize(L,N); ArrayResize(C,N); ArrayResize(T,N);
   for(int i=0;i<N;i++)
   {
      H[i]=rates[i].high;
      L[i]=rates[i].low;
      C[i]=rates[i].close;
      T[i]=rates[i].time;
   }
   // Note: CopyRates gives time-series (0=current). We will rebuild chronological arrays.
   BuildChronological(N,H,L,C,T);
   DetectSwings(N);

   // State across calculations (static persists)
   static int last_broken_high_m = -1;
   static int last_broken_low_m  = -1;
   static int last_created_up_on_m = -1;
   static int last_created_dn_on_m = -1;
   static TrendMS ms = MS_None;

   // If chart/indicator was refreshed, avoid duplicating: reset when prev_calculated==0
   if(prev_calculated==0)
   {
      // remove old prefixed objects
      long total_objects = ObjectsTotal(0,-1,-1);
      string pref = Prefix();
      for(long idx=total_objects-1; idx>=0; idx--)
      {
         string name = ObjectName(0,idx,-1,-1);
         if(StringFind(name,pref)==0)
            ObjectDelete(0,name);
      }
      last_broken_high_m=-1;
      last_broken_low_m=-1;
      last_created_up_on_m=-1;
      last_created_dn_on_m=-1;
      ms=MS_None;
   }

   // We will scan from oldest to newest and create objects for
   // BOS/CHoCH exactly once per broken swing.
   int lastHigh_m = -1;
   int lastLow_m  = -1;

   for(int m=0; m<N; m++)
   {
      // 1) Check breaks against the last *confirmed* swings (which by construction have m' < m)
      double buf = BufferInPoints();

      if(lastHigh_m>=0 && m>lastHigh_m)
      {
         if(cl[m] > hi[lastHigh_m] + buf && last_broken_high_m != lastHigh_m)
         {
            // bullish break using body close
            bool isCHOCH = (ms==MS_Bear);
            ms = MS_Bull;

            int i_break = m2i(m,N);
            int i_swing = m2i(lastHigh_m,N);

            // Draw line from swing to break
            if(DrawSwingToBreak)
            {
               string lName = Prefix()+"Hseg_"+IntegerToString(i_swing)+"_"+IntegerToString(i_break);
               CreateHSegment(lName, tm[lastHigh_m], hi[lastHigh_m], tm[m], (isCHOCH? ColorCHOCH_Up: ColorBOS_Up));
            }
            // Text label
            string tName = Prefix()+"LBL_UP_"+IntegerToString(i_break);
            string text  = (isCHOCH? "CHoCH": "BOS");
            color  col   = (isCHOCH? ColorCHOCH_Up: ColorBOS_Up);
            // place just above the candle close
            double price = cl[m];
            CreateText(tName,tm[m],price,col,text);

            last_broken_high_m = lastHigh_m;
            last_created_up_on_m = m;
         }
      }
      if(lastLow_m>=0 && m>lastLow_m)
      {
         if(cl[m] < lo[lastLow_m] - buf && last_broken_low_m != lastLow_m)
         {
            // bearish break using body close
            bool isCHOCH = (ms==MS_Bull);
            ms = MS_Bear;

            int i_break = m2i(m,N);
            int i_swing = m2i(lastLow_m,N);

            if(DrawSwingToBreak)
            {
               string lName = Prefix()+"Lseg_"+IntegerToString(i_swing)+"_"+IntegerToString(i_break);
               CreateHSegment(lName, tm[lastLow_m], lo[lastLow_m], tm[m], (isCHOCH? ColorCHOCH_Down: ColorBOS_Down));
            }
            string tName = Prefix()+"LBL_DN_"+IntegerToString(i_break);
            string text  = (isCHOCH? "CHoCH": "BOS");
            color  col   = (isCHOCH? ColorCHOCH_Down: ColorBOS_Down);
            double price = cl[m];
            CreateText(tName,tm[m],price,col,text);

            last_broken_low_m = lastLow_m;
            last_created_dn_on_m = m;
         }
      }

      // 2) After we have evaluated break on bar m, update swing holders if bar m itself is a confirmed swing
      if(isHigh[m])
      {
         lastHigh_m = m;
         if(MarkSwings)
         {
            string sName = Prefix()+"SWH_"+IntegerToString(m2i(m,N));
            CreateSwingDot(sName,tm[m],hi[m],clrCornflowerBlue);
         }
      }
      if(isLow[m])
      {
         lastLow_m = m;
         if(MarkSwings)
         {
            string sName = Prefix()+"SWL_"+IntegerToString(m2i(m,N));
            CreateSwingDot(sName,tm[m],lo[m],clrYellowGreen);
         }
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Keep drawings by default. If you want auto-cleanup, uncomment:
//   string pref = Prefix();
//   long total = ObjectsTotal(0,-1,-1);
//   for(int idx=total-1; idx>=0; idx--)
//   {
//      string name = ObjectName(0,idx,-1,-1);
//      if(StringFind(name,pref)==0) ObjectDelete(0,name);
//   }
}