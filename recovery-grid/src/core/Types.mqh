//+------------------------------------------------------------------+
//| Project: Recovery Grid Direction v2                              |
//| Purpose: Shared enums and POD structures                         |
//+------------------------------------------------------------------+
#ifndef __RGD_V2_TYPES_MQH__
#define __RGD_V2_TYPES_MQH__

enum EDirection
  {
   DIR_BUY  = 0,
   DIR_SELL = 1
  };

enum ESpacingMode
  {
   SPACING_PIPS   = 0,
   SPACING_ATR    = 1,
   SPACING_HYBRID = 2
  };

enum EBasketKind
  {
   BASKET_PRIMARY = 0,
   BASKET_HEDGE   = 1
  };

// Multi-Job System (v3.0)
enum EJobStatus
  {
   JOB_ACTIVE      = 0,  // Trading normally
   JOB_FULL        = 1,  // Grid full, may spawn new
   JOB_STOPPED     = 2,  // SL hit or manual stop
   JOB_ABANDONED   = 3   // DD too high, can't save
  };

struct SGridLevel
  {
   double price;   // entry price for pending level
   double lot;     // lot size for this level
   ulong  ticket;  // ticket once placed
   bool   filled;  // level already converted to position
  };

struct SBasketSummary
  {
   EDirection direction;
   EBasketKind kind;
   double total_lot;
   double avg_price;
   double pnl_usd;
   double tp_price;
   double last_grid_price;
   bool   trailing_active;
  };

struct SNewsWindow
  {
   int start_hour;      // UTC hour (0-23)
   int start_minute;    // 0-59
   int end_hour;        // UTC hour (0-23)
   int end_minute;      // 0-59
  };

struct SPcTicket
  {
   ulong  ticket;
   double volume;
   double entry;
   double pnl;
   double distance;
  };

#endif // __RGD_V2_TYPES_MQH__