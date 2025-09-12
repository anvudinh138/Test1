//+------------------------------------------------------------------+
//|                 PTG TESTCASE SYSTEM v3.4.0                      |
//|            Systematic Testing Like ChatGPT (14 Presets)         |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.40"
#property description "PTG v3.4.0 - TESTCASE SYSTEM: Systematic multi-preset testing like ChatGPT"

//=== TESTCASE SYSTEM (ChatGPT Inspired) ===
input group "=== TESTCASE SELECTION ==="
input int      TestCase           = 1;                 // 0=Manual | 1-14=Preset configurations

input group "=== CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // Core lookback period

input group "=== MANUAL PARAMETERS (TestCase=0) ==="
input double   Manual_PushRange         = 0.35;        // Push Range %
input double   Manual_ClosePercent      = 0.45;        // Close Position %
input double   Manual_OppWick           = 0.55;        // Opposite Wick %
input double   Manual_VolMultiplier     = 1.20;        // Volume Multiplier
input double   Manual_MaxSpread         = 15.0;        // Max Spread Pips
input int      Manual_SessionStart      = 7;           // Session Start Hour
input int      Manual_SessionEnd        = 17;          // Session End Hour
input double   Manual_Momentum          = 6.0;         // Momentum Threshold Pips
input double   Manual_SL                = 25.0;        // Stop Loss Pips
input double   Manual_BE                = 30.0;        // Breakeven Pips
input double   Manual_TrailStart        = 50.0;        // Trail Start Pips
input double   Manual_TrailStep         = 25.0;        // Trail Step Pips
input int      Manual_MaxLosses         = 8;           // Max Consecutive Losses
input int      Manual_Cooldown          = 45;          // Cooldown Minutes

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.4.0-TestCase";

//=== DYNAMIC PARAMETERS ===
double   PushRangePercent;
double   ClosePercent;
double   OppWickPercent;
double   VolHighMultiplier;
double   MaxSpreadPips;
bool     UseSessionFilter;
int      SessionStartHour;
int      SessionEndHour;
bool     UseMomentumFilter;
double   MomentumThresholdPips;
double   FixedSLPips;
double   EarlyBEPips;
bool     UseTrailing;
double   TrailStartPips;
double   TrailStepPips;
int      MaxConsecutiveLosses;
int      CooldownMinutes;

//=== GLOBAL VARIABLES ===
int magic_number = 34000;  // v3.4.0 magic number
ulong active_position_ticket = 0;
int bars_since_entry = 0;
datetime entry_time = 0;
int last_signal_bar = -1;
int last_trade_bar = -1;
double original_entry_price = 0.0;
double pip_size = 0.0;
bool breakeven_activated = false;
bool trailing_activated = false;
double remaining_volume = 0.0;
int signal_count = 0;
int trade_count = 0;

// Circuit breaker
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;

//=== TESTCASE CONFIGURATIONS ===
void LoadTestCasePreset(int id)
{
   if(id <= 0) 
   { 
      Print("📋 TESTCASE 0 - MANUAL: Using manual input parameters");
      LoadFromInputs();
      return; 
   }
   
   switch(id)
   {
      case 1: // Default v3.2.5 tuned (recommended base)
         PushRangePercent = 0.34; ClosePercent = 0.44; OppWickPercent = 0.56; VolHighMultiplier = 1.18;
         MaxSpreadPips = 15.5; UseSessionFilter = true; SessionStartHour = 7; SessionEndHour = 17;
         UseMomentumFilter = true; MomentumThresholdPips = 6.0;
         FixedSLPips = 25.0; EarlyBEPips = 30.0; UseTrailing = true; TrailStartPips = 50.0; TrailStepPips = 25.0;
         MaxConsecutiveLosses = 8; CooldownMinutes = 45;
         Print("📊 TESTCASE 1 - DEFAULT: v3.2.5 proven profitable configuration");
         break;
         
      case 2: // Softer gates (InpWickFracBase=0.30")
         PushRangePercent = 0.30; ClosePercent = 0.40; OppWickPercent = 0.60; VolHighMultiplier = 1.15;
         MaxSpreadPips = 16.0; UseSessionFilter = true; SessionStartHour = 6; SessionEndHour = 18;
         UseMomentumFilter = true; MomentumThresholdPips = 5.0;
         FixedSLPips = 27.0; EarlyBEPips = 32.0; UseTrailing = true; TrailStartPips = 55.0; TrailStepPips = 28.0;
         MaxConsecutiveLosses = 10; CooldownMinutes = 40;
         Print("🌊 TESTCASE 2 - SOFTER: Relaxed criteria for more signals");
         break;
         
      case 3: // No Sweep (max entries)
         PushRangePercent = 0.28; ClosePercent = 0.38; OppWickPercent = 0.65; VolHighMultiplier = 1.10;
         MaxSpreadPips = 18.0; UseSessionFilter = true; SessionStartHour = 6; SessionEndHour = 18;
         UseMomentumFilter = false; MomentumThresholdPips = 0.0;
         FixedSLPips = 30.0; EarlyBEPips = 35.0; UseTrailing = true; TrailStartPips = 60.0; TrailStepPips = 30.0;
         MaxConsecutiveLosses = 12; CooldownMinutes = 30;
         Print("🚀 TESTCASE 3 - NO SWEEP: Maximum entry frequency");
         break;
         
      case 4: // Lower PUSH (0.58/0.78) like your H5
         PushRangePercent = 0.29; ClosePercent = 0.39; OppWickPercent = 0.61; VolHighMultiplier = 1.12;
         MaxSpreadPips = 17.0; UseSessionFilter = true; SessionStartHour = 7; SessionEndHour = 17;
         UseMomentumFilter = true; MomentumThresholdPips = 4.0;
         FixedSLPips = 28.0; EarlyBEPips = 33.0; UseTrailing = true; TrailStartPips = 58.0; TrailStepPips = 27.0;
         MaxConsecutiveLosses = 11; CooldownMinutes = 35;
         Print("📉 TESTCASE 4 - LOWER PUSH: Moderate relaxed criteria");
         break;
         
      case 5: // Pending Dwell strong (buffer 5p, dwell 15s)
         PushRangePercent = 0.32; ClosePercent = 0.42; OppWickPercent = 0.58; VolHighMultiplier = 1.16;
         MaxSpreadPips = 14.0; UseSessionFilter = true; SessionStartHour = 8; SessionEndHour = 16;
         UseMomentumFilter = true; MomentumThresholdPips = 7.0;
         FixedSLPips = 23.0; EarlyBEPips = 28.0; UseTrailing = true; TrailStartPips = 47.0; TrailStepPips = 23.0;
         MaxConsecutiveLosses = 7; CooldownMinutes = 50;
         Print("⏳ TESTCASE 5 - PENDING STRONG: Quality with patience");
         break;
         
      case 6: // Pending Dwell very strong (buffer 6p, dwell 20s)
         PushRangePercent = 0.36; ClosePercent = 0.46; OppWickPercent = 0.54; VolHighMultiplier = 1.22;
         MaxSpreadPips = 13.0; UseSessionFilter = true; SessionStartHour = 8; SessionEndHour = 16;
         UseMomentumFilter = true; MomentumThresholdPips = 8.0;
         FixedSLPips = 21.0; EarlyBEPips = 26.0; UseTrailing = true; TrailStartPips = 43.0; TrailStepPips = 21.0;
         MaxConsecutiveLosses = 6; CooldownMinutes = 55;
         Print("💪 TESTCASE 6 - VERY STRONG: Ultra quality focus");
         break;
         
      case 7: // Conservative (ATRMin 65, stricter wick, SL 28, require sweep)
         PushRangePercent = 0.40; ClosePercent = 0.50; OppWickPercent = 0.50; VolHighMultiplier = 1.25;
         MaxSpreadPips = 12.0; UseSessionFilter = true; SessionStartHour = 9; SessionEndHour = 15;
         UseMomentumFilter = true; MomentumThresholdPips = 8.0;
         FixedSLPips = 20.0; EarlyBEPips = 25.0; UseTrailing = true; TrailStartPips = 40.0; TrailStepPips = 20.0;
         MaxConsecutiveLosses = 5; CooldownMinutes = 60;
         Print("🛡️ TESTCASE 7 - CONSERVATIVE: Maximum protection (UseCase 2 style)");
         break;
         
      case 8: // Aggressive (ATRMin 45, M5Bias OFF, Push 0.56/0.76, sweep soft)
         PushRangePercent = 0.28; ClosePercent = 0.38; OppWickPercent = 0.62; VolHighMultiplier = 1.08;
         MaxSpreadPips = 20.0; UseSessionFilter = true; SessionStartHour = 6; SessionEndHour = 18;
         UseMomentumFilter = false; MomentumThresholdPips = 0.0;
         FixedSLPips = 32.0; EarlyBEPips = 38.0; UseTrailing = true; TrailStartPips = 65.0; TrailStepPips = 32.0;
         MaxConsecutiveLosses = 15; CooldownMinutes = 25;
         Print("⚡ TESTCASE 8 - AGGRESSIVE: Maximum opportunity capture");
         break;
         
      case 9: // Tight scalper (BE12, partial22, trail start 18/step14)
         PushRangePercent = 0.33; ClosePercent = 0.43; OppWickPercent = 0.57; VolHighMultiplier = 1.17;
         MaxSpreadPips = 13.5; UseSessionFilter = true; SessionStartHour = 8; SessionEndHour = 16;
         UseMomentumFilter = true; MomentumThresholdPips = 6.5;
         FixedSLPips = 22.0; EarlyBEPips = 18.0; UseTrailing = true; TrailStartPips = 25.0; TrailStepPips = 15.0;
         MaxConsecutiveLosses = 8; CooldownMinutes = 40;
         Print("🎯 TESTCASE 9 - TIGHT SCALPER: Quick profits, tight management");
         break;
         
      case 10: // Wide RR (SL 30, partial22, trail 24/20)
         PushRangePercent = 0.31; ClosePercent = 0.41; OppWickPercent = 0.59; VolHighMultiplier = 1.14;
         MaxSpreadPips = 16.5; UseSessionFilter = true; SessionStartHour = 7; SessionEndHour = 17;
         UseMomentumFilter = true; MomentumThresholdPips = 5.5;
         FixedSLPips = 30.0; EarlyBEPips = 35.0; UseTrailing = true; TrailStartPips = 60.0; TrailStepPips = 28.0;
         MaxConsecutiveLosses = 10; CooldownMinutes = 38;
         Print("📏 TESTCASE 10 - WIDE RR: Better risk/reward ratio");
         break;
         
      case 11: // RN hard (RN buffers 6/4 + forbid entries inside)
         PushRangePercent = 0.35; ClosePercent = 0.45; OppWickPercent = 0.55; VolHighMultiplier = 1.19;
         MaxSpreadPips = 14.5; UseSessionFilter = true; SessionStartHour = 8; SessionEndHour = 16;
         UseMomentumFilter = true; MomentumThresholdPips = 6.5;
         FixedSLPips = 24.0; EarlyBEPips = 29.0; UseTrailing = true; TrailStartPips = 48.0; TrailStepPips = 24.0;
         MaxConsecutiveLosses = 7; CooldownMinutes = 47;
         Print("🎰 TESTCASE 11 - RN HARD: Round number avoidance");
         break;
         
      case 12: // Spread strict (max spread 12/10, ATRMin 55)
         PushRangePercent = 0.36; ClosePercent = 0.46; OppWickPercent = 0.54; VolHighMultiplier = 1.21;
         MaxSpreadPips = 12.0; UseSessionFilter = true; SessionStartHour = 9; SessionEndHour = 15;
         UseMomentumFilter = true; MomentumThresholdPips = 7.5;
         FixedSLPips = 22.0; EarlyBEPips = 27.0; UseTrailing = true; TrailStartPips = 45.0; TrailStepPips = 22.0;
         MaxConsecutiveLosses = 6; CooldownMinutes = 52;
         Print("💎 TESTCASE 12 - SPREAD STRICT: Premium conditions only");
         break;
         
      case 13: // Bias hard (M5Bias ON, no contra override)
         PushRangePercent = 0.33; ClosePercent = 0.43; OppWickPercent = 0.57; VolHighMultiplier = 1.18;
         MaxSpreadPips = 15.0; UseSessionFilter = true; SessionStartHour = 7; SessionEndHour = 17;
         UseMomentumFilter = true; MomentumThresholdPips = 6.0;
         FixedSLPips = 25.0; EarlyBEPips = 30.0; UseTrailing = true; TrailStartPips = 50.0; TrailStepPips = 25.0;
         MaxConsecutiveLosses = 8; CooldownMinutes = 45;
         Print("📈 TESTCASE 13 - BIAS HARD: Trend following strict");
         break;
         
      case 14: // Bias soft (M5Bias ON but slope gate 25)
         PushRangePercent = 0.32; ClosePercent = 0.42; OppWickPercent = 0.58; VolHighMultiplier = 1.16;
         MaxSpreadPips = 15.5; UseSessionFilter = true; SessionStartHour = 7; SessionEndHour = 17;
         UseMomentumFilter = true; MomentumThresholdPips = 5.8;
         FixedSLPips = 26.0; EarlyBEPips = 31.0; UseTrailing = true; TrailStartPips = 52.0; TrailStepPips = 26.0;
         MaxConsecutiveLosses = 9; CooldownMinutes = 42;
         Print("📊 TESTCASE 14 - BIAS SOFT: Trend following moderate");
         break;
         
      default:
         Print("❌ Invalid TestCase: ", id, " - Using DEFAULT");
         LoadTestCasePreset(1);
         break;
   }
}

void LoadFromInputs()
{
   PushRangePercent = Manual_PushRange;
   ClosePercent = Manual_ClosePercent;
   OppWickPercent = Manual_OppWick;
   VolHighMultiplier = Manual_VolMultiplier;
   MaxSpreadPips = Manual_MaxSpread;
   UseSessionFilter = true;
   SessionStartHour = Manual_SessionStart;
   SessionEndHour = Manual_SessionEnd;
   UseMomentumFilter = true;
   MomentumThresholdPips = Manual_Momentum;
   FixedSLPips = Manual_SL;
   EarlyBEPips = Manual_BE;
   UseTrailing = true;
   TrailStartPips = Manual_TrailStart;
   TrailStepPips = Manual_TrailStep;
   MaxConsecutiveLosses = Manual_MaxLosses;
   CooldownMinutes = Manual_Cooldown;
}

//=== HELPER FUNCTIONS ===
double Pip() 
{
   if(StringFind(Symbol(), "XAU") >= 0) return 0.01;  
   double pt = Point();
   int d = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   if(d == 5 || d == 3) return 10 * pt;
   return pt;
}

double PriceFromPips(double pips) 
{
   return pips * Pip();
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

double CalculateProfitPips(double entry_price, double current_price, bool is_long)
{
   if(entry_price <= 0 || current_price <= 0) return 0;
   
   double profit_pips = is_long ? 
                       (current_price - entry_price) / Pip() :
                       (entry_price - current_price) / Pip();
   
   return profit_pips;
}

//=== INITIALIZATION ===
int OnInit() 
{
   pip_size = Pip();
   
   // Load selected testcase configuration
   LoadTestCasePreset(TestCase);
   
   Print("🧪 PTG TESTCASE SYSTEM v3.4.0 - SYSTEMATIC TESTING LIKE CHATGPT!");
   Print("📋 TESTCASE ", TestCase, " LOADED");
   Print("📊 Push: Range=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("⏰ Session: ", SessionStartHour, "-", SessionEndHour, " | Spread=", MaxSpreadPips, "p | Momentum=", (UseMomentumFilter ? DoubleToString(MomentumThresholdPips, 1) + "p" : "OFF"));
   Print("🎯 Risk: SL=", FixedSLPips, "p | BE=", EarlyBEPips, "p | Trail=", TrailStartPips, "p");
   Print("🔴 Breaker: ", MaxConsecutiveLosses, " losses → ", CooldownMinutes, "min");
   Print("🧪 TESTCASE SYSTEM: Comprehensive systematic analysis ready!");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   if(!IsMarketOK()) return;
   if(IsInBlackoutPeriod()) return;  
   if(UseSessionFilter && !IsInTradingSession()) return;
   if(IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManagePosition();
      bars_since_entry++;
      return;
   }
   
   CheckPTGSignals();
}

//=== FILTERING SYSTEM ===
bool IsMarketOK() 
{
   double current_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                           SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Pip();
   
   if(current_spread > MaxSpreadPips)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("⚠️ SPREAD HIGH: ", DoubleToString(current_spread, 1), "p > ", MaxSpreadPips, "p");
      return false;
   }
   
   return true;
}

bool IsInTradingSession()
{
   if(!UseSessionFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   bool in_session = (dt.hour >= SessionStartHour && dt.hour < SessionEndHour);
   
   if(!in_session && EnableDebugLogs && signal_count % 1000 == 0)
      Print("💤 OUT OF SESSION: ", IntegerToString(dt.hour), ":00 (", SessionStartHour, "-", SessionEndHour, ")");
   
   return in_session;
}

bool IsInBlackoutPeriod()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   bool in_blackout = ((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0 && dt.min <= 10));
   
   return in_blackout;
}

bool IsInCircuitBreaker()
{
   if(TimeCurrent() < circuit_breaker_until)
   {
      if(EnableDebugLogs && signal_count % 1000 == 0)
         Print("🔴 CIRCUIT BREAKER: Active until ", TimeToString(circuit_breaker_until));
      return true;
   }
   
   return false;
}

void ActivateCircuitBreaker()
{
   if(consecutive_losses >= MaxConsecutiveLosses)
   {
      circuit_breaker_until = TimeCurrent() + CooldownMinutes * 60;
      
      if(EnableDebugLogs)
         Print("🔴 TESTCASE ", TestCase, " BREAKER: ", consecutive_losses, " losses → ", 
               CooldownMinutes, "min until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0;
   }
}

//=== PTG SIGNAL DETECTION ===
void CheckPTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsPushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 200 == 0)
         Print("🧪 TESTCASE ", TestCase, " PUSH #", signal_count);
      
      CheckTestAndGo();
   }
}

bool IsPushDetected() 
{
   if(Bars(Symbol(), PERIOD_CURRENT) < LookbackPeriod + 2) return false;
   
   double high[], low[], close[];
   long volume[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, high) <= 0) return false;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, low) <= 0) return false;
   if(CopyClose(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, close) <= 0) return false;
   if(CopyTickVolume(Symbol(), PERIOD_CURRENT, 1, LookbackPeriod + 1, volume) <= 0) return false;
   
   double current_range = high[0] - low[0];
   
   double avg_range = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_range += (high[i] - low[i]);
   avg_range /= LookbackPeriod;
   
   double avg_volume = 0.0;
   for(int i = 1; i <= LookbackPeriod; i++)
      avg_volume += (double)volume[i];
   avg_volume /= LookbackPeriod;
   
   // TestCase-specific PTG criteria
   bool range_criteria = current_range >= avg_range * PushRangePercent;
   bool volume_criteria = (double)volume[0] >= avg_volume * VolHighMultiplier;
   
   double close_position = (close[0] - low[0]) / current_range;
   bool bullish_push = close_position >= ClosePercent;
   bool bearish_push = close_position <= (1.0 - ClosePercent);
   
   double upper_wick = high[0] - MathMax(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1));
   double lower_wick = MathMin(close[0], iOpen(Symbol(), PERIOD_CURRENT, 1)) - low[0];
   
   bool opp_wick_ok = false;
   if(bullish_push) opp_wick_ok = (upper_wick / current_range) <= OppWickPercent;
   if(bearish_push) opp_wick_ok = (lower_wick / current_range) <= OppWickPercent;
   
   // TestCase-specific momentum filter
   bool momentum_ok = true;
   if(UseMomentumFilter)
   {
      double momentum_pips = MathAbs(close[0] - close[1]) / Pip();
      momentum_ok = momentum_pips >= MomentumThresholdPips;
   }
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok && momentum_ok;
}

void CheckTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== TRADE EXECUTION ===
void ExecuteEntry(bool is_long) 
{
   if(active_position_ticket > 0) return;
   
   double current_price = is_long ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double sl_price = is_long ? 
                     current_price - PriceFromPips(FixedSLPips) :
                     current_price + PriceFromPips(FixedSLPips);
   
   current_price = NormalizePrice(current_price);
   sl_price = NormalizePrice(sl_price);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.volume = FixedLotSize;
   req.type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = current_price;
   req.sl = sl_price;
   req.tp = 0.0;
   req.magic = magic_number;
   req.comment = "PTG TestCase " + IntegerToString(TestCase);
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ TESTCASE ", TestCase, " ENTRY: ", direction, " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG TestCase ", TestCase, " ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ TESTCASE ", TestCase, " ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== POSITION MANAGEMENT ===
void UpdatePositionInfo() 
{
   active_position_ticket = 0;
   
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) 
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number) 
         {
            active_position_ticket = ticket;
            remaining_volume = PositionGetDouble(POSITION_VOLUME);
            break;
         }
      }
   }
}

void ManagePosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // TestCase-specific breakeven
   if(!breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToBreakeven();
      return;
   }
   
   // TestCase-specific trailing
   if(UseTrailing && !trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("🧪 TESTCASE ", TestCase, " TRAILING: +", DoubleToString(profit_pips, 1), "p");
   }
   
   if(UseTrailing && trailing_activated && profit_pips >= TrailStartPips) 
   {
      TrailStopLoss(profit_pips);
   }
}

void MoveToBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(3.0)) :
                     (original_entry_price - spread - PriceFromPips(3.0));
   
   be_price = NormalizePrice(be_price);
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_SLTP;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.sl = be_price;
   req.tp = PositionGetDouble(POSITION_TP);
   
   if(OrderSend(req, res)) 
   {
      breakeven_activated = true;
      if(EnableDebugLogs)
         Print("🛡️ TESTCASE ", TestCase, " BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
   }
}

void TrailStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   double min_improvement = PriceFromPips(6.0);
   if((is_long && new_sl > current_sl + min_improvement) || 
      (!is_long && new_sl < current_sl - min_improvement)) 
   {
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      
      req.action = TRADE_ACTION_SLTP;
      req.symbol = Symbol();
      req.position = active_position_ticket;
      req.sl = new_sl;
      req.tp = PositionGetDouble(POSITION_TP);
      
      if(OrderSend(req, res) && EnableDebugLogs) 
      {
         Print("📈 TESTCASE ", TestCase, " TRAIL: SL @ ", DoubleToString(new_sl, 5), " | +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

//=== UTILITY FUNCTIONS ===
void ResetTradeState() 
{
   active_position_ticket = 0;
   bars_since_entry = 0;
   entry_time = 0;
   original_entry_price = 0.0;
   breakeven_activated = false;
   trailing_activated = false;
   remaining_volume = 0.0;
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result) 
{
   if(trans.symbol != Symbol() || request.magic != magic_number) return;
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) 
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) 
      {
         if((trans.deal_type == DEAL_TYPE_BUY && request.type == ORDER_TYPE_BUY) ||
            (trans.deal_type == DEAL_TYPE_SELL && request.type == ORDER_TYPE_SELL)) 
         {
            // Entry
            active_position_ticket = trans.position;
            original_entry_price = trans.price;
            bars_since_entry = 0;
            entry_time = TimeCurrent();
            breakeven_activated = false;
            trailing_activated = false;
            remaining_volume = trans.volume;
            
            string direction = trans.deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
            
            if(EnableDebugLogs)
               Print("🧪 TESTCASE ", TestCase, " FILLED: ", direction, " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // Loss tracking
               if(profit_pips < -2.0)
               {
                  consecutive_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 5.0)
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 TESTCASE ", TestCase, " EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Losses: ", consecutive_losses);
            
            if(active_position_ticket == trans.position && trans.volume >= remaining_volume) 
            {
               ResetTradeState();
            }
         }
      }
   }
}

void OnDeinit(const int reason) 
{
   string testcase_name;
   switch(TestCase)
   {
      case 0: testcase_name = "MANUAL"; break;
      case 1: testcase_name = "DEFAULT"; break;
      case 2: testcase_name = "SOFTER"; break;
      case 3: testcase_name = "NO SWEEP"; break;
      case 4: testcase_name = "LOWER PUSH"; break;
      case 5: testcase_name = "PENDING STRONG"; break;
      case 6: testcase_name = "VERY STRONG"; break;
      case 7: testcase_name = "CONSERVATIVE"; break;
      case 8: testcase_name = "AGGRESSIVE"; break;
      case 9: testcase_name = "TIGHT SCALPER"; break;
      case 10: testcase_name = "WIDE RR"; break;
      case 11: testcase_name = "RN HARD"; break;
      case 12: testcase_name = "SPREAD STRICT"; break;
      case 13: testcase_name = "BIAS HARD"; break;
      case 14: testcase_name = "BIAS SOFT"; break;
      default: testcase_name = "UNKNOWN"; break;
   }
   
   Print("🧪 PTG TESTCASE SYSTEM v3.4.0 STOPPED - ", testcase_name, " CONFIGURATION COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Final TestCase: ", TestCase);
   Print("🧪 TESTCASE SYSTEM: Systematic analysis complete - ready for next configuration!");
}
