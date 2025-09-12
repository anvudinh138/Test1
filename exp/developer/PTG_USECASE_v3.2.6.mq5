//+------------------------------------------------------------------+
//|                    PTG USECASE v3.2.6                           |
//|          Multiple Configuration Testing for Survivability       |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.26"
#property description "PTG v3.2.6 - USECASE: Multiple configurations for optimal survivability balance"

//=== USECASE CONFIGURATIONS ===
input group "=== USECASE SELECTION ==="
input int      UseCase             = 1;                 // 1=Default | 2=Conservative | 3=Aggressive | 4=Balanced | 5=High-Frequency

input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 10;                // Core lookback period

input group "=== USECASE PARAMETERS (Auto-Set) ==="
input double   PushRangePercent_Input    = 0.34;       // Push Range % (auto-set by UseCase)
input double   ClosePercent_Input        = 0.44;       // Close Position % (auto-set by UseCase)
input double   OppWickPercent_Input      = 0.56;       // Opposite Wick % (auto-set by UseCase)
input double   VolHighMultiplier_Input   = 1.18;       // Volume Multiplier (auto-set by UseCase)
input double   MaxSpreadPips_Input       = 15.5;       // Max Spread Pips (auto-set by UseCase)
input int      SessionStartHour_Input    = 7;          // Session Start Hour (auto-set by UseCase)
input int      SessionEndHour_Input      = 17;         // Session End Hour (auto-set by UseCase)
input double   MomentumThresholdPips_Input = 6.0;      // Momentum Threshold Pips (auto-set by UseCase)
input double   FixedSLPips_Input         = 25.0;       // Stop Loss Pips (auto-set by UseCase)
input double   EarlyBEPips_Input         = 30.0;       // Breakeven Pips (auto-set by UseCase)
input double   TrailStartPips_Input      = 50.0;       // Trail Start Pips (auto-set by UseCase)
input double   TrailStepPips_Input       = 25.0;       // Trail Step Pips (auto-set by UseCase)
input int      MaxConsecutiveLosses_Input = 8;         // Max Consecutive Losses (auto-set by UseCase)
input int      CooldownMinutes_Input     = 45;         // Cooldown Minutes (auto-set by UseCase)

//=== DYNAMIC PARAMETERS (will be set based on UseCase) ===
// Push Detection
double   PushRangePercent;
double   ClosePercent;
double   OppWickPercent;
double   VolHighMultiplier;

// Filtering
double   MaxSpreadPips;
bool     UseSessionFilter;
int      SessionStartHour;
int      SessionEndHour;
bool     UseMomentumFilter;
double   MomentumThresholdPips;

// Risk Management
double   FixedSLPips;
double   EarlyBEPips;
double   TrailStartPips;
double   TrailStepPips;

// Circuit Breaker
int      MaxConsecutiveLosses;
int      CooldownMinutes;

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.6-UseCase";

//=== GLOBAL VARIABLES ===
int magic_number = 32600;  // v3.2.6 magic number
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

//=== USECASE CONFIGURATIONS ===
void SetUseCaseParameters()
{
   switch(UseCase)
   {
      case 1: // DEFAULT - Based on successful v3.2.5
         PushRangePercent = PushRangePercent_Input;
         ClosePercent = ClosePercent_Input;
         OppWickPercent = OppWickPercent_Input;
         VolHighMultiplier = VolHighMultiplier_Input;
         MaxSpreadPips = MaxSpreadPips_Input;
         UseSessionFilter = true;
         SessionStartHour = SessionStartHour_Input;
         SessionEndHour = SessionEndHour_Input;
         UseMomentumFilter = true;
         MomentumThresholdPips = MomentumThresholdPips_Input;
         FixedSLPips = FixedSLPips_Input;
         EarlyBEPips = EarlyBEPips_Input;
         TrailStartPips = TrailStartPips_Input;
         TrailStepPips = TrailStepPips_Input;
         MaxConsecutiveLosses = MaxConsecutiveLosses_Input;
         CooldownMinutes = CooldownMinutes_Input;
         Print("📊 USECASE 1 - DEFAULT: Manual input parameters");
         break;
         
      case 2: // CONSERVATIVE - Higher win rate focus
         PushRangePercent = 0.40;  // Stricter
         ClosePercent = 0.50;      // Stricter
         OppWickPercent = 0.50;    // Stricter
         VolHighMultiplier = 1.25; // Stricter
         MaxSpreadPips = 12.0;     // Tighter
         UseSessionFilter = true;
         SessionStartHour = 8;     // Peak hours only
         SessionEndHour = 16;
         UseMomentumFilter = true;
         MomentumThresholdPips = 8.0; // Higher momentum
         FixedSLPips = 20.0;       // Tighter SL
         EarlyBEPips = 25.0;       // Earlier BE
         TrailStartPips = 40.0;    // Earlier trail
         TrailStepPips = 20.0;     // Tighter trail
         MaxConsecutiveLosses = 5; // Faster brake
         CooldownMinutes = 60;     // Longer cooldown
         Print("🛡️ USECASE 2 - CONSERVATIVE: Higher win rate, better survivability");
         break;
         
      case 3: // AGGRESSIVE - Maximum opportunity
         PushRangePercent = 0.30;  // More relaxed
         ClosePercent = 0.40;      // More relaxed
         OppWickPercent = 0.60;    // More relaxed
         VolHighMultiplier = 1.10; // More relaxed
         MaxSpreadPips = 18.0;     // More generous
         UseSessionFilter = true;
         SessionStartHour = 6;     // Extended hours
         SessionEndHour = 18;
         UseMomentumFilter = true;
         MomentumThresholdPips = 4.0; // Lower momentum
         FixedSLPips = 30.0;       // Wider SL
         EarlyBEPips = 35.0;       // Later BE
         TrailStartPips = 60.0;    // Later trail
         TrailStepPips = 30.0;     // Wider trail
         MaxConsecutiveLosses = 10; // More tolerant
         CooldownMinutes = 30;     // Shorter cooldown
         Print("🚀 USECASE 3 - AGGRESSIVE: Maximum signals, bigger winners");
         break;
         
      case 4: // BALANCED - Middle ground approach
         PushRangePercent = 0.37;
         ClosePercent = 0.47;
         OppWickPercent = 0.53;
         VolHighMultiplier = 1.15;
         MaxSpreadPips = 14.0;
         UseSessionFilter = true;
         SessionStartHour = 7;
         SessionEndHour = 17;
         UseMomentumFilter = true;
         MomentumThresholdPips = 5.0;
         FixedSLPips = 22.0;       // Balanced SL
         EarlyBEPips = 27.0;       // Balanced BE
         TrailStartPips = 45.0;    // Balanced trail
         TrailStepPips = 22.0;     // Balanced trail
         MaxConsecutiveLosses = 6; // Balanced brake
         CooldownMinutes = 40;     // Balanced cooldown
         Print("⚖️ USECASE 4 - BALANCED: Optimized balance of all factors");
         break;
         
      case 5: // HIGH-FREQUENCY - More signals, smaller wins
         PushRangePercent = 0.28;  // Very relaxed
         ClosePercent = 0.38;      // Very relaxed
         OppWickPercent = 0.65;    // Very relaxed
         VolHighMultiplier = 1.05; // Very relaxed
         MaxSpreadPips = 20.0;     // Very generous
         UseSessionFilter = true;
         SessionStartHour = 6;
         SessionEndHour = 18;
         UseMomentumFilter = false; // No momentum filter
         MomentumThresholdPips = 0.0;
         FixedSLPips = 18.0;       // Tight SL
         EarlyBEPips = 20.0;       // Quick BE
         TrailStartPips = 30.0;    // Quick trail
         TrailStepPips = 15.0;     // Tight trail
         MaxConsecutiveLosses = 12; // Very tolerant
         CooldownMinutes = 20;     // Quick recovery
         Print("⚡ USECASE 5 - HIGH-FREQUENCY: Maximum signals, quick profits");
         break;
         
      default:
         Print("❌ Invalid UseCase: ", UseCase, " - Using DEFAULT");
         
         SetUseCaseParameters(); // Recursively set to default
         break;
   }
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
   
   // Set parameters based on selected UseCase
   SetUseCaseParameters();
   
   Print("🎯 PTG USECASE v3.2.6 - MULTI-CONFIGURATION TESTING STARTED!");
   Print("📊 Push Criteria: Range=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("⏰ Session: ", SessionStartHour, "-", SessionEndHour, " | Spread=", MaxSpreadPips, "p | Momentum=", (UseMomentumFilter ? DoubleToString(MomentumThresholdPips, 1) + "p" : "OFF"));
   Print("🎯 Risk: SL=", FixedSLPips, "p | BE=", EarlyBEPips, "p | Trail=", TrailStartPips, "p");
   Print("🔴 Breaker: ", MaxConsecutiveLosses, " losses → ", CooldownMinutes, "min");
   Print("🎯 TARGET: Find optimal survivability balance for real trading!");
   
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
   
   // Standard rollover blackout 23:50-00:10
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
         Print("🔴 USECASE ", UseCase, " BREAKER: ", consecutive_losses, " losses → ", 
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
      
      if(EnableDebugLogs && signal_count % 300 == 0)
         Print("🎯 USECASE ", UseCase, " PUSH #", signal_count);
      
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
   
   // UseCase-specific PTG criteria
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
   
   // UseCase-specific momentum filter
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
   req.comment = "PTG UseCase " + IntegerToString(UseCase);
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ USECASE ", UseCase, " ENTRY: ", direction, " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG UseCase ", UseCase, " ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ USECASE ", UseCase, " ENTRY FAILED: ", res.retcode, " - ", res.comment);
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
   
   // UseCase-specific breakeven
   if(!breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToBreakeven();
      return;
   }
   
   // UseCase-specific trailing
   if(!trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("🎯 USECASE ", UseCase, " TRAILING: +", DoubleToString(profit_pips, 1), "p");
   }
   
   if(trailing_activated && profit_pips >= TrailStartPips) 
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
         Print("🛡️ USECASE ", UseCase, " BREAKEVEN: SL @ ", DoubleToString(be_price, 5));
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
         Print("📈 USECASE ", UseCase, " TRAIL: SL @ ", DoubleToString(new_sl, 5), " | +", DoubleToString(profit_pips, 1), "p");
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
               Print("🎯 USECASE ", UseCase, " FILLED: ", direction, " @ ", DoubleToString(trans.price, 5));
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
               Print("💰 USECASE ", UseCase, " EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
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
   string usecase_name;
   switch(UseCase)
   {
      case 1: usecase_name = "DEFAULT"; break;
      case 2: usecase_name = "CONSERVATIVE"; break;
      case 3: usecase_name = "AGGRESSIVE"; break;
      case 4: usecase_name = "BALANCED"; break;
      case 5: usecase_name = "HIGH-FREQUENCY"; break;
      default: usecase_name = "UNKNOWN"; break;
   }
   
   Print("🎯 PTG USECASE v3.2.6 STOPPED - ", usecase_name, " CONFIGURATION COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Final UseCase: ", UseCase);
   Print("🎯 USECASE TESTING: Multi-configuration survivability analysis complete!");
}
