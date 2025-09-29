`// Include guard for MQL5
#ifndef __RGD_TYPES_MQH__
#define __RGD_TYPES_MQH__

enum EDirection { DIR_BUY = 0, DIR_SELL = 1 };

enum ESpacingMode { SPACING_PIPS = 0, SPACING_ATR = 1, SPACING_HYBRID = 2 };

struct SGridLevel {
  double price;
  double lot;
  ulong  ticket;
  bool   is_filled;
};

#endif // __RGD_TYPES_MQH__
`