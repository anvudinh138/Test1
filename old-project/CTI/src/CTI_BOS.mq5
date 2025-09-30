#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//================= Inputs =================
input int      LeftBars               = 3;        // fractal trái
input int      RightBars              = 3;        // fractal phải
input bool     UseCloseForBreak       = true;     // dùng Close xác nhận phá (nếu false dùng Wick)
input bool     ConfirmOnBarClose      = true;     // chỉ báo khi nến ĐÓNG
input double   BreakBufferPoints      = 0.0;      // đệm phá vỡ (points)
input bool     LabelFirstBreakAsCHOCH = true;     // phá đầu tiên gắn CHoCH
input bool     DrawStructureLines     = true;     // vẽ mức khi có BOS/CHoCH
input int      LineHistoryBars        = 3000;     // số nến quét
input bool RequireWholeBodyBeyond = false; // true = thân nến phải vượt hẳn mức

// Cách vẽ mức
enum LevelDrawMode { LEVEL_NONE=0, LEVEL_SEGMENT=1, LEVEL_RAY=2, LEVEL_HLINE=3 };
input LevelDrawMode LevelMode         = LEVEL_SEGMENT; // mặc định: đoạn ngắn tại nến phá
input int           SegmentBarsAtBreak= 6;             // độ dài đoạn quanh nến phá (nến)
input int           LevelLengthBars   = 40;            // dùng cho RAY (tia sang phải)

// Giới hạn object cho gọn chart
input int      MaxSignalsToKeep       = 60;
input int      MaxStructureLines      = 24;

// Màu sắc + hiển thị
input color    ColorBOSUp             = clrLime;
input color    ColorBOSDown           = clrRed;
input color    ColorCHOCHUp           = clrDeepSkyBlue;
input color    ColorCHOCHDown         = clrOrange;

input int      ArrowSize              = 1;
input int      FontSize               = 9;
input double   LabelOffsetPoints      = 20;
input string   ObjectPrefix           = "SMC_BOS_CHOCH_";

// Cảnh báo
input bool     AlertsOn               = true;
input bool     PushOn                 = false;
input bool     SoundOn                = false;
input string   SoundFile              = "alert2.wav";

// Debug
input bool     DebugMode              = false;

//================= Globals =================
enum Trend { TREND_NONE=0, TREND_BULL=1, TREND_BEAR=-1 };
bool  gSwingHigh[];
bool  gSwingLow[];
Trend gTrend = TREND_NONE;

//----------------- Helpers -----------------
string I64ToString(const long v){ return StringFormat("%I64d", v); }
long   StringToI64(const string s){ return (long)StringToInteger(s); }
void   DPrint(const string s){ if(DebugMode) Print(s); }
void   DPrintf(const string fmt, double a1=0,double a2=0,double a3=0,double a4=0,double a5=0)
{ if(DebugMode) PrintFormat(fmt,a1,a2,a3,a4,a5); }

//================= Init/Deinit =================
int OnInit()
{
   ClearAllObjects();
   if(DebugMode)
   {
      Print("==== SMC_BOS_CHOCH v12 ====");
      PrintFormat("ConfirmOnBarClose=%s UseCloseForBreak=%s Buffer=%.1fpts",
                  ConfirmOnBarClose?"true":"false", UseCloseForBreak?"true":"false", BreakBufferPoints);
      PrintFormat("Fractal L=%d R=%d   LevelMode=%d SegmentBars=%d",
                  LeftBars, RightBars, (int)LevelMode, SegmentBarsAtBreak);
   }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){}

//================= Core =================
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < (LeftBars+RightBars+5)) return 0;

   const int lastIndex = rates_total-1;
   const int firstIndex = MathMax(LeftBars, lastIndex - MathMax(LineHistoryBars, 500));
   const int endIndex   = lastIndex - RightBars;

   ResetSwingArrays(rates_total);

   // xác định swing fractal
   for(int i=LeftBars; i<=endIndex; i++)
   {
      if(IsSwingHigh(i, high)) gSwingHigh[i] = true;
      if(IsSwingLow(i,  low )) gSwingLow[i]  = true;
   }

   int lastSwingHighIdx=-1, lastSwingLowIdx=-1;
   double lastSwingHigh=0.0, lastSwingLow=0.0;
   int lastBrokenHighIdx=-1, lastBrokenLowIdx=-1;

   // duyệt từ cũ -> mới (index giảm dần vì series array)
   for(int i=endIndex; i>=firstIndex; i--)
   {
      const bool barClosed = (i>0);
      if(ConfirmOnBarClose && !barClosed) continue;

      const double buf = BreakBufferPoints * _Point;

      // ---- Break lên
      if(lastSwingHighIdx!=-1)
      {
         bool breakUp = (UseCloseForBreak ? (close[i] > lastSwingHigh + buf)
                                          : (high[i]  > lastSwingHigh + buf));
         if(breakUp && lastBrokenHighIdx!=lastSwingHighIdx)
         {
            bool isCHOCH = (gTrend==TREND_BEAR) || (gTrend==TREND_NONE && LabelFirstBreakAsCHOCH);
            string tag = isCHOCH ? "CHOCH↑" : "BOS↑";
            color  c   = isCHOCH ? ColorCHOCHUp : ColorBOSUp;

            DrawSignalUp(time[i], time, low, tag, c);
            if(DrawStructureLines) DrawLevelLine(time[lastSwingHighIdx], time[i], lastSwingHigh, c);

            if(DebugMode)
               PrintFormat("%s at %s close=%.5f brokeHigh=%.5f (swing@%s) trend->BULL",
                           tag, TimeToString(time[i], TIME_DATE|TIME_SECONDS),
                           close[i], lastSwingHigh,
                           TimeToString(time[lastSwingHighIdx], TIME_DATE|TIME_SECONDS));

            if(AlertsOn && i==0) DoAlert(tag+" @ "+_Symbol+" "+DoubleToString(close[0], _Digits));
            if(PushOn && i==0)   SendNotification(tag+" "+_Symbol);
            if(SoundOn && i==0)  PlaySound(SoundFile);

            gTrend = TREND_BULL;
            lastBrokenHighIdx = lastSwingHighIdx;

            PruneSignals();
            if(DrawStructureLines) PruneLevels();
         }
      }

      // ---- Break xuống
      if(lastSwingLowIdx!=-1)
      {
         bool breakDn = (UseCloseForBreak ? (close[i] < lastSwingLow - buf)
                                          : (low[i]   < lastSwingLow - buf));
         if(breakDn && lastBrokenLowIdx!=lastSwingLowIdx)
         {
            bool isCHOCH = (gTrend==TREND_BULL) || (gTrend==TREND_NONE && LabelFirstBreakAsCHOCH);
            string tag = isCHOCH ? "CHOCH↓" : "BOS↓";
            color  c   = isCHOCH ? ColorCHOCHDown : ColorBOSDown;

            DrawSignalDown(time[i], time, high, tag, c);
            if(DrawStructureLines) DrawLevelLine(time[lastSwingLowIdx], time[i], lastSwingLow, c);

            if(DebugMode)
               PrintFormat("%s at %s close=%.5f brokeLow=%.5f (swing@%s) trend->BEAR",
                           tag, TimeToString(time[i], TIME_DATE|TIME_SECONDS),
                           close[i], lastSwingLow,
                           TimeToString(time[lastSwingLowIdx], TIME_DATE|TIME_SECONDS));

            if(AlertsOn && i==0) DoAlert(tag+" @ "+_Symbol+" "+DoubleToString(close[0], _Digits));
            if(PushOn && i==0)   SendNotification(tag+" "+_Symbol);
            if(SoundOn && i==0)  PlaySound(SoundFile);

            gTrend = TREND_BEAR;
            lastBrokenLowIdx = lastSwingLowIdx;

            PruneSignals();
            if(DrawStructureLines) PruneLevels();
         }
      }

      // cập nhật swing gần nhất
      if(gSwingHigh[i]) { lastSwingHighIdx=i; lastSwingHigh=high[i]; }
      if(gSwingLow[i])  { lastSwingLowIdx =i; lastSwingLow =low[i];  }
   }

   return(rates_total);
}

//================= Swing detection =================
bool IsSwingHigh(const int i, const double &high[])
{
   for(int k=1;k<=LeftBars;k++)  if(high[i] <= high[i+k]) return false;
   for(int k=1;k<=RightBars;k++) if(high[i] <= high[i-k]) return false;
   return true;
}
bool IsSwingLow(const int i, const double &low[])
{
   for(int k=1;k<=LeftBars;k++)  if(low[i] >= low[i+k]) return false;
   for(int k=1;k<=RightBars;k++) if(low[i] >= low[i-k]) return false;
   return true;
}

//================= Drawing =================
void DrawSignalUp(const datetime t, const datetime &time[], const double &low[], const string tag, const color c)
{
   long chart_id = ChartID();
   string base   = ObjectPrefix + "SIG_UP_" + I64ToString((long)t);
   string nameA  = base + "_A";
   string nameT  = base + "_T";

   int i = iBarShift(_Symbol, _Period, t, true);
   if(i<0) return;
   double y = low[i] - LabelOffsetPoints*_Point;

   if(ObjectFind(chart_id, nameA)==-1)
   {
      ObjectCreate(chart_id, nameA, OBJ_ARROW_UP, 0, t, y);
      ObjectSetInteger(chart_id, nameA, OBJPROP_COLOR, c);
      ObjectSetInteger(chart_id, nameA, OBJPROP_WIDTH, ArrowSize);
      ObjectSetInteger(chart_id, nameA, OBJPROP_BACK, false);
   }
   if(ObjectFind(chart_id, nameT)==-1)
   {
      ObjectCreate(chart_id, nameT, OBJ_TEXT, 0, t, y);
      ObjectSetInteger(chart_id, nameT, OBJPROP_COLOR, c);
      ObjectSetInteger(chart_id, nameT, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(chart_id,  nameT, OBJPROP_TEXT, tag);
      ObjectSetInteger(chart_id, nameT, OBJPROP_BACK, false);
   }
}

void DrawSignalDown(const datetime t, const datetime &time[], const double &high[], const string tag, const color c)
{
   long chart_id = ChartID();
   string base   = ObjectPrefix + "SIG_DN_" + I64ToString((long)t);
   string nameA  = base + "_A";
   string nameT  = base + "_T";

   int i = iBarShift(_Symbol, _Period, t, true);
   if(i<0) return;
   double y = high[i] + LabelOffsetPoints*_Point;

   if(ObjectFind(chart_id, nameA)==-1)
   {
      ObjectCreate(chart_id, nameA, OBJ_ARROW_DOWN, 0, t, y);
      ObjectSetInteger(chart_id, nameA, OBJPROP_COLOR, c);
      ObjectSetInteger(chart_id, nameA, OBJPROP_WIDTH, ArrowSize);
      ObjectSetInteger(chart_id, nameA, OBJPROP_BACK, false);
   }
   if(ObjectFind(chart_id, nameT)==-1)
   {
      ObjectCreate(chart_id, nameT, OBJ_TEXT, 0, t, y);
      ObjectSetInteger(chart_id, nameT, OBJPROP_COLOR, c);
      ObjectSetInteger(chart_id, nameT, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(chart_id,  nameT, OBJPROP_TEXT, tag);
      ObjectSetInteger(chart_id, nameT, OBJPROP_BACK, false);
   }
}

// Vẽ mức: SEGMENT (ngắn tại nến phá) / RAY / HLINE / NONE
void DrawLevelLine(const datetime t_swing, const datetime t_break, const double price, const color c)
{
   if(!DrawStructureLines || LevelMode==LEVEL_NONE || price<=0) return;

   long chart_id = ChartID();
   string name = ObjectPrefix + "LVL_" + DoubleToString(price, _Digits) + "_" +
                 I64ToString((long)t_swing) + "_" + I64ToString((long)t_break);
   if(ObjectFind(chart_id, name)!=-1) return;

   if(LevelMode==LEVEL_HLINE)
   {
      ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, c);
      ObjectSetInteger(chart_id, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(chart_id, name, OBJPROP_BACK,  true);
      return;
   }

   if(LevelMode==LEVEL_SEGMENT)
   {
      int sec = PeriodSeconds(_Period) * MathMax(1, SegmentBarsAtBreak);
      datetime t_left = t_break - (datetime)sec;
      if(t_left < t_swing) t_left = t_swing;

      ObjectCreate(chart_id, name, OBJ_TREND, 0, t_left, price, t_break, price);
      ObjectSetInteger(chart_id, name, OBJPROP_RAY_RIGHT, false);
   }
   else if(LevelMode==LEVEL_RAY)
   {
      int sec = PeriodSeconds(_Period) * MathMax(1, LevelLengthBars);
      datetime t_right = t_break + (datetime)sec;

      ObjectCreate(chart_id, name, OBJ_TREND, 0, t_break, price, t_right, price);
      ObjectSetInteger(chart_id, name, OBJPROP_RAY_RIGHT, true);
   }

   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, c);
   ObjectSetInteger(chart_id, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chart_id, name, OBJPROP_BACK,  true);
}

//================= Housekeeping =================
void PruneSignals()
{
   long chart_id = ChartID();
   string names[];
   datetime times[];
   int cnt=0, total = ObjectsTotal(chart_id, 0, -1);

   for(int i=0;i<total;i++)
   {
      string nm = ObjectName(chart_id, i, 0, -1);
      if(StringFind(nm, ObjectPrefix+"SIG_")==0)
      {
         // lấy timestamp giữa "SIG_[UP/DN]_" và "_[A/T]"
         int p = StringFind(nm, "_", StringLen(ObjectPrefix)+4); // sau "SIG_"
         if(p>0)
         {
            string ts = StringSubstr(nm, p+1);
            int q = StringFind(ts, "_");
            if(q>0) ts = StringSubstr(ts, 0, q);
            ArrayResize(names, ++cnt); names[cnt-1]=nm;
            ArrayResize(times,  cnt   ); times[cnt-1]=(datetime)StringToI64(ts);
         }
      }
   }
   if(cnt<=MaxSignalsToKeep) return;

   // sort desc theo time, xoá cũ
   for(int k=0;k<cnt-1;k++)
      for(int j=k+1;j<cnt;j++)
         if(times[k] < times[j]) { datetime T=times[k]; times[k]=times[j]; times[j]=T; string S=names[k]; names[k]=names[j]; names[j]=S; }

   for(int r=MaxSignalsToKeep; r<cnt; r++)
      ObjectDelete(chart_id, names[r]);
}

void PruneLevels()
{
   long chart_id = ChartID();
   string names[];
   datetime times[]; // dùng t_break để sắp xếp
   int cnt=0, total = ObjectsTotal(chart_id, 0, -1);

   for(int i=0;i<total;i++)
   {
      string nm = ObjectName(chart_id, i, 0, -1);
      if(StringFind(nm, ObjectPrefix+"LVL_")==0)
      {
         // tên: PREFIX + LVL_price_tSwing_tBreak -> lấy phần cuối (tBreak)
         int last=-1, L=(int)StringLen(nm);
         for(int k=0;k<L;k++) if((ushort)StringGetCharacter(nm,k)=='_') last=k;
         if(last>0)
         {
            string tbreak_str = StringSubstr(nm, last+1);
            ArrayResize(names, ++cnt); names[cnt-1]=nm;
            ArrayResize(times,  cnt   ); times[cnt-1]=(datetime)StringToI64(tbreak_str);
         }
      }
   }
   if(cnt<=MaxStructureLines) return;

   for(int k=0;k<cnt-1;k++)
      for(int j=k+1;j<cnt;j++)
         if(times[k] < times[j]) { datetime T=times[k]; times[k]=times[j]; times[j]=T; string S=names[k]; names[k]=names[j]; names[j]=S; }

   for(int r=MaxStructureLines; r<cnt; r++)
      ObjectDelete(chart_id, names[r]);
}

void DoAlert(const string msg){ Alert(msg); }

void ClearAllObjects()
{
   long chart_id = ChartID();
   int total = ObjectsTotal(chart_id, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(chart_id, i, 0, -1);
      if(StringFind(name, ObjectPrefix)==0) ObjectDelete(chart_id, name);
   }
}

void ResetSwingArrays(const int size)
{
   if(ArraySize(gSwingHigh)!=size) ArrayResize(gSwingHigh, size);
   if(ArraySize(gSwingLow)!=size)  ArrayResize(gSwingLow,  size);
   ArrayInitialize(gSwingHigh, false);
   ArrayInitialize(gSwingLow,  false);
}
