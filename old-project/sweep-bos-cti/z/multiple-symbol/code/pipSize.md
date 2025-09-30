double PipSize(const string s){
  int d=(int)SymbolInfoInteger(s, SYMBOL_DIGITS);
  double pt=SymbolInfoDouble(s, SYMBOL_POINT);
  return (d==5 || d==3) ? 10.0*pt : pt;  // 1 pip
}
double PipsToPrice(const string s, double pips){ return pips * PipSize(s); }

// Normal cap theo nhóm (có thể chỉnh)
double DefaultMaxSpreadPrice(const string s, bool tight=false){
  double pips = 0.0;
  if(s=="EURUSD"||s=="GBPUSD"||s=="USDCHF"||s=="EURGBP") pips = tight?2.5:4.0;
  else if(s=="AUDUSD"||s=="NZDUSD")                       pips = tight?2.0:3.5;
  else if(s=="USDCAD"||s=="EURCHF"||s=="AUDCAD")          pips = tight?3.0:4.5;
  else if(s=="USDJPY"||s=="EURJPY"||s=="AUDJPY"||
          s=="CADJPY"||s=="NZDJPY"||s=="CHFJPY")          pips = tight?2.5:4.0;
  else                                                    pips = tight?3.0:5.0; // fallback
  return PipsToPrice(s, pips);
}