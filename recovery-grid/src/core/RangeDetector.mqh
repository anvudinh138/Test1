//+------------------------------------------------------------------+
//| RangeDetector.mqh                                                |
//| Range Detection and Market Classification                        |
//| Part of Phase 4: Profit Optimization System                      |
//+------------------------------------------------------------------+
#property copyright "Recovery Grid v3.0"
#property link      "https://github.com/recovery-grid"
#property version   "3.0"

#include "Types.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Market condition types                                          |
//+------------------------------------------------------------------+
enum EMarketCondition
  {
   MARKET_TRENDING_UP = 0,      // Strong uptrend
   MARKET_TRENDING_DOWN = 1,    // Strong downtrend
   MARKET_RANGING = 2,          // Range-bound, sideways
   MARKET_VOLATILE = 3,         // High volatility, unclear
   MARKET_UNKNOWN = 4           // Not enough data
  };

//+------------------------------------------------------------------+
//| Range detection parameters                                      |
//+------------------------------------------------------------------+
struct SRangeParams
  {
   int      atr_period;         // ATR period for volatility
   double   range_threshold;    // ATR ratio to classify as range (e.g., 0.5)
   double   trend_threshold;    // ATR ratio for trend (e.g., 1.5)
   int      lookback_bars;      // Bars to analyze for range
   int      min_bounces;        // Min bounces for range confirmation
   double   bounce_tolerance;   // Points tolerance for bounce detection
  };

//+------------------------------------------------------------------+
//| Range information                                                |
//+------------------------------------------------------------------+
struct SRangeInfo
  {
   EMarketCondition condition;  // Current market condition
   double   range_high;         // Range upper boundary
   double   range_low;          // Range lower boundary
   double   range_width;        // Range width in points
   int      bounce_count;       // Number of bounces detected
   double   atr_value;          // Current ATR value
   double   volatility_ratio;   // Current volatility vs average
   datetime last_update;        // Last calculation time
  };

//+------------------------------------------------------------------+
//| Range Detector Class                                            |
//+------------------------------------------------------------------+
class CRangeDetector
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   SRangeParams      m_params;
   SRangeInfo        m_info;
   CLogger          *m_logger;

   // ATR handle
   int               m_atr_handle;

   // Price history buffers
   double            m_highs[];
   double            m_lows[];
   double            m_closes[];

   // Internal methods
   bool              LoadPriceData();
   int               CountBounces(double high_level, double low_level);
   double            CalculateVolatilityRatio();
   void              ClassifyMarketCondition();

public:
                     CRangeDetector();
                    ~CRangeDetector();

   // Initialization
   bool              Init(string symbol, ENUM_TIMEFRAMES tf, const SRangeParams &params, CLogger *logger);
   void              Deinit();

   // Core functionality
   bool              Update();                    // Update market analysis
   EMarketCondition  GetCondition() const;        // Get current condition
   SRangeInfo        GetRangeInfo() const;        // Get full range info

   // Adaptive parameters based on market
   double            GetGridSpacingMultiplier() const;   // Adjust grid spacing
   double            GetLotSizeMultiplier() const;       // Adjust lot size
   double            GetTPMultiplier() const;            // Adjust TP target
   int               GetOptimalGridLevels() const;       // Optimal grid levels

   // Utility
   bool              IsRanging() const;
   bool              IsTrending() const;
   string            ConditionToString(EMarketCondition cond) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRangeDetector::CRangeDetector()
  {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_logger = NULL;
   m_atr_handle = INVALID_HANDLE;

   // Initialize info
   m_info.condition = MARKET_UNKNOWN;
   m_info.range_high = 0;
   m_info.range_low = 0;
   m_info.range_width = 0;
   m_info.bounce_count = 0;
   m_info.atr_value = 0;
   m_info.volatility_ratio = 1.0;
   m_info.last_update = 0;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRangeDetector::~CRangeDetector()
  {
   Deinit();
  }

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CRangeDetector::Init(string symbol, ENUM_TIMEFRAMES tf, const SRangeParams &params, CLogger *logger)
  {
   m_symbol = symbol;
   m_timeframe = tf;
   m_params = params;
   m_logger = logger;

   // Create ATR indicator
   m_atr_handle = iATR(m_symbol, m_timeframe, m_params.atr_period);
   if(m_atr_handle == INVALID_HANDLE)
     {
      if(m_logger) m_logger.Event("[RangeDetector]", "ERROR: Failed to create ATR indicator");
      return false;
     }

   // Size arrays
   ArrayResize(m_highs, m_params.lookback_bars);
   ArrayResize(m_lows, m_params.lookback_bars);
   ArrayResize(m_closes, m_params.lookback_bars);

   if(m_logger)
      m_logger.Event("[RangeDetector]", StringFormat("Initialized for %s %s, ATR=%d, Lookback=%d",
                    m_symbol, EnumToString(m_timeframe), m_params.atr_period, m_params.lookback_bars));

   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize                                                     |
//+------------------------------------------------------------------+
void CRangeDetector::Deinit()
  {
   if(m_atr_handle != INVALID_HANDLE)
     {
      IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Load price data                                                 |
//+------------------------------------------------------------------+
bool CRangeDetector::LoadPriceData()
  {
   // Copy high prices
   if(CopyHigh(m_symbol, m_timeframe, 0, m_params.lookback_bars, m_highs) != m_params.lookback_bars)
      return false;

   // Copy low prices
   if(CopyLow(m_symbol, m_timeframe, 0, m_params.lookback_bars, m_lows) != m_params.lookback_bars)
      return false;

   // Copy close prices
   if(CopyClose(m_symbol, m_timeframe, 0, m_params.lookback_bars, m_closes) != m_params.lookback_bars)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Count bounces from support/resistance                           |
//+------------------------------------------------------------------+
int CRangeDetector::CountBounces(double high_level, double low_level)
  {
   int bounces = 0;
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double tolerance = m_params.bounce_tolerance * point;

   for(int i = 1; i < m_params.lookback_bars - 1; i++)
     {
      // Check high bounce (resistance)
      if(MathAbs(m_highs[i] - high_level) <= tolerance)
        {
         // Confirm with reversal
         if(m_closes[i+1] < m_highs[i] - tolerance)
            bounces++;
        }

      // Check low bounce (support)
      if(MathAbs(m_lows[i] - low_level) <= tolerance)
        {
         // Confirm with reversal
         if(m_closes[i+1] > m_lows[i] + tolerance)
            bounces++;
        }
     }

   return bounces;
  }

//+------------------------------------------------------------------+
//| Calculate volatility ratio                                      |
//+------------------------------------------------------------------+
double CRangeDetector::CalculateVolatilityRatio()
  {
   double atr_values[];
   ArrayResize(atr_values, 1);

   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_values) != 1)
      return 1.0;

   m_info.atr_value = atr_values[0];

   // Calculate average range
   double avg_range = 0;
   for(int i = 0; i < m_params.lookback_bars; i++)
     {
      avg_range += (m_highs[i] - m_lows[i]);
     }
   avg_range /= m_params.lookback_bars;

   // Volatility ratio
   if(avg_range > 0)
      return m_info.atr_value / avg_range;

   return 1.0;
  }

//+------------------------------------------------------------------+
//| Classify market condition                                       |
//+------------------------------------------------------------------+
void CRangeDetector::ClassifyMarketCondition()
  {
   // Find highest high and lowest low
   int high_idx = ArrayMaximum(m_highs);
   int low_idx = ArrayMinimum(m_lows);

   m_info.range_high = m_highs[high_idx];
   m_info.range_low = m_lows[low_idx];
   m_info.range_width = m_info.range_high - m_info.range_low;

   // Count bounces
   m_info.bounce_count = CountBounces(m_info.range_high, m_info.range_low);

   // Calculate volatility
   m_info.volatility_ratio = CalculateVolatilityRatio();

   // Classify based on range vs ATR
   double range_to_atr = 0;
   if(m_info.atr_value > 0)
      range_to_atr = m_info.range_width / m_info.atr_value;

   // Decision logic
   if(range_to_atr < m_params.range_threshold && m_info.bounce_count >= m_params.min_bounces)
     {
      m_info.condition = MARKET_RANGING;
     }
   else if(range_to_atr > m_params.trend_threshold)
     {
      // Check trend direction
      double close_position = (m_closes[m_params.lookback_bars-1] - m_info.range_low) / m_info.range_width;

      if(close_position > 0.7)
         m_info.condition = MARKET_TRENDING_UP;
      else if(close_position < 0.3)
         m_info.condition = MARKET_TRENDING_DOWN;
      else
         m_info.condition = MARKET_VOLATILE;
     }
   else
     {
      m_info.condition = MARKET_VOLATILE;
     }
}

//+------------------------------------------------------------------+
//| Update market analysis                                          |
//+------------------------------------------------------------------+
bool CRangeDetector::Update()
  {
   // Load latest price data
   if(!LoadPriceData())
     {
      if(m_logger) m_logger.Event("[RangeDetector]", "ERROR: Failed to load price data");
      return false;
     }

   // Classify market
   ClassifyMarketCondition();

   // Update timestamp
   m_info.last_update = TimeCurrent();

   // Log if condition changed
   static EMarketCondition last_condition = MARKET_UNKNOWN;
   if(m_info.condition != last_condition)
     {
      if(m_logger)
         m_logger.Event("[RangeDetector]", StringFormat("Market changed: %s → %s (Bounces=%d, ATR=%.5f)",
                       ConditionToString(last_condition),
                       ConditionToString(m_info.condition),
                       m_info.bounce_count,
                       m_info.atr_value));
      last_condition = m_info.condition;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Get current market condition                                    |
//+------------------------------------------------------------------+
EMarketCondition CRangeDetector::GetCondition() const
  {
   return m_info.condition;
  }

//+------------------------------------------------------------------+
//| Get full range info                                             |
//+------------------------------------------------------------------+
SRangeInfo CRangeDetector::GetRangeInfo() const
  {
   return m_info;
  }

//+------------------------------------------------------------------+
//| Get grid spacing multiplier based on market                     |
//+------------------------------------------------------------------+
double CRangeDetector::GetGridSpacingMultiplier() const
  {
   switch(m_info.condition)
     {
      case MARKET_RANGING:
         return 0.5;      // Tight spacing in range

      case MARKET_TRENDING_UP:
      case MARKET_TRENDING_DOWN:
         return 1.0;      // Normal spacing in trend

      case MARKET_VOLATILE:
         return 2.0;      // Wide spacing in volatile

      default:
         return 1.0;
     }
  }

//+------------------------------------------------------------------+
//| Get lot size multiplier based on market                         |
//+------------------------------------------------------------------+
double CRangeDetector::GetLotSizeMultiplier() const
  {
   switch(m_info.condition)
     {
      case MARKET_RANGING:
         return 2.0;      // Larger lots in range (quick profit)

      case MARKET_TRENDING_UP:
      case MARKET_TRENDING_DOWN:
         return 1.0;      // Normal lots in trend

      case MARKET_VOLATILE:
         return 0.5;      // Smaller lots in volatile

      default:
         return 1.0;
     }
  }

//+------------------------------------------------------------------+
//| Get TP multiplier based on market                               |
//+------------------------------------------------------------------+
double CRangeDetector::GetTPMultiplier() const
  {
   switch(m_info.condition)
     {
      case MARKET_RANGING:
         return 0.3;      // Quick TP in range (30% of normal)

      case MARKET_TRENDING_UP:
      case MARKET_TRENDING_DOWN:
         return 1.0;      // Normal TP in trend

      case MARKET_VOLATILE:
         return 1.5;      // Larger TP in volatile

      default:
         return 1.0;
     }
  }

//+------------------------------------------------------------------+
//| Get optimal grid levels based on market                         |
//+------------------------------------------------------------------+
int CRangeDetector::GetOptimalGridLevels() const
  {
   switch(m_info.condition)
     {
      case MARKET_RANGING:
         return 20;       // More levels in range

      case MARKET_TRENDING_UP:
      case MARKET_TRENDING_DOWN:
         return 10;       // Normal levels in trend

      case MARKET_VOLATILE:
         return 5;        // Few levels in volatile

      default:
         return 10;
     }
  }

//+------------------------------------------------------------------+
//| Check if market is ranging                                      |
//+------------------------------------------------------------------+
bool CRangeDetector::IsRanging() const
  {
   return (m_info.condition == MARKET_RANGING);
  }

//+------------------------------------------------------------------+
//| Check if market is trending                                     |
//+------------------------------------------------------------------+
bool CRangeDetector::IsTrending() const
  {
   return (m_info.condition == MARKET_TRENDING_UP ||
           m_info.condition == MARKET_TRENDING_DOWN);
  }

//+------------------------------------------------------------------+
//| Convert condition to string                                     |
//+------------------------------------------------------------------+
string CRangeDetector::ConditionToString(EMarketCondition cond) const
  {
   switch(cond)
     {
      case MARKET_TRENDING_UP:   return "TREND_UP";
      case MARKET_TRENDING_DOWN: return "TREND_DOWN";
      case MARKET_RANGING:       return "RANGING";
      case MARKET_VOLATILE:      return "VOLATILE";
      default:                   return "UNKNOWN";
     }
  }
//+------------------------------------------------------------------+