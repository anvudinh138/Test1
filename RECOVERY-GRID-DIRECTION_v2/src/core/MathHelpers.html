//+------------------------------------------------------------------+
//| Math helpers for grid calculations                               |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_MATH_HELPERS_MQH__
#define __RGD_V2_MATH_HELPERS_MQH__

inline double PipPoints(const string symbol)
  {
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   if(digits==3 || digits==5)
      return 10.0*_Point;
   return _Point;
  }

inline int   NormalizeDecimals(const string symbol)
  {
   return (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
  }

inline double AveragePrice(const double &lots[],const double &prices[],const int count)
  {
   double vol=0.0;
   double weighted=0.0;
   for(int i=0;i<count;i++)
     {
      vol+=lots[i];
      weighted+=lots[i]*prices[i];
     }
   if(vol<=0.0)
      return 0.0;
   return weighted/vol;
  }

  // Parse CSV "1000,2000,3000" -> mảng int (points)
  int ParseCSVPoints(const string csv, int &out_arr[])
  {
    StringTrimLeft(csv); StringTrimRight(csv);
    if(StringLen(csv)==0) return 0;
    string parts[];
    int n = StringSplit(csv, ',', parts);
    ArrayResize(out_arr, n);
    for(int i=0;i<n;i++)
    {
        string s = parts[i];
        StringTrimLeft(s); StringTrimRight(s);
        out_arr[i] = (int)StringToInteger(s);
    }
    return n;
  }

  // Tính spacing hiện hành (đơn vị: points)
  int ComputeSpacingPoints()
  {
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 1);
    int by_atr_pts = (int)MathMax(1, MathRound((atr/_Point) * spacing_atr_mult));

    if(spacing_mode==SPACING_ATR)
        return by_atr_pts;

    // HYBRID giữ khoảng cách tối thiểu theo min_spacing_pips
    int minpts = PipToPoints(min_spacing_pips);
    return (int)MathMax(minpts, by_atr_pts);
  }

#endif // __RGD_V2_MATH_HELPERS_MQH__
