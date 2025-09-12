//+------------------------------------------------------------------+
//|                    PTG EXPLOSIVE v3.2.4                         |
//|          Maximum Signals + Proven Big Winner Strategy           |
//|                     Gold XAUUSD M1 Specialized                 |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2024, PTG Trading Strategy"  
#property link      "https://github.com/ptg-trading"
#property version   "3.24"
#property description "PTG v3.2.4 - EXPLOSIVE: Maximum signal frequency + proven big winner exits"

//=== EXPLOSIVE INPUTS (Maximum Signals + Big Winners) ===
input group "=== PTG CORE SETTINGS ==="
input int      LookbackPeriod     = 9;                 // EXPLOSIVE: 9 (vs 10) for faster signals

input group "=== EXPLOSIVE PUSH PARAMETERS ==="
input double   PushRangePercent   = 0.33;              // EXPLOSIVE: 33% (vs 35%) for more signals
input double   ClosePercent       = 0.43;              // EXPLOSIVE: 43% (vs 45%) for more signals
input double   OppWickPercent     = 0.57;              // EXPLOSIVE: 57% (vs 55%) for more flexibility
input double   VolHighMultiplier  = 1.15;              // EXPLOSIVE: 1.15× (vs 1.2×) for more signals

input group "=== EXPLOSIVE TIMING ==="
input double   MaxSpreadPips      = 16.0;              // EXPLOSIVE: 16p (vs 15p) more generous
input bool     UseSessionFilter   = true;              // PROVEN: Strategic session
input int      SessionStartHour   = 6;                 // EXPLOSIVE: 6:00-18:00 (vs 7-17)
input int      SessionEndHour     = 18;                // Wider window for more signals
input bool     UseBlackoutTimes   = true;              // Keep rollover protection
input int      BlackoutStartHour  = 23;                
input int      BlackoutStartMin   = 50;                
input int      BlackoutEndHour    = 0;                 
input int      BlackoutEndMin     = 10;
input bool     UseMomentumFilter  = true;              // NEW: Momentum filter for quality
input double   MomentumThresholdPips = 5.0;            // Minimum momentum for entry

input group "=== PROVEN BIG WINNER EXITS ==="
input double   FixedSLPips        = 25.0;              // PROVEN: 25p SL (exact v3.2.3)
input bool     UseEarlyBreakeven  = true;              // PROVEN: Early protection
input double   EarlyBEPips        = 28.0;              // EXPLOSIVE: 28p BE (vs 30p) earlier protection
input bool     UsePartialTP       = false;             // PROVEN: No partial TP
input bool     UseTrailing        = true;              // PROVEN: Let winners run
input double   TrailStartPips     = 45.0;              // EXPLOSIVE: 45p (vs 50p) earlier trail
input double   TrailStepPips      = 22.0;              // EXPLOSIVE: 22p (vs 25p) tighter trail

input group "=== EXPLOSIVE TIME MANAGEMENT ==="
input bool     UseTimeBasedExit   = true;              // PROVEN: Time management
input int      MaxHoldingHours    = 10;                // EXPLOSIVE: 10h (vs 12h) more active
input int      MinProfitForHold   = 8;                 // EXPLOSIVE: 8p (vs 10p) lower threshold
input bool     UseEndOfSessionExit = true;             // NEW: Exit before session end
input int      EOSExitHour        = 17;                // Exit 1h before session end

input group "=== EXPLOSIVE CIRCUIT BREAKER ==="
input bool     UseCircuitBreaker  = true;              // PROVEN: Protection
input int      MaxConsecutiveLosses = 6;               // EXPLOSIVE: 6 (vs 8) faster brake
input int      CooldownMinutes    = 30;                // EXPLOSIVE: 30min (vs 45min) faster recovery
input bool     UseHourlyReset     = true;              // NEW: Reset consecutive count hourly
input int      HourlyResetInterval = 2;                // Reset every 2 hours

input group "=== SYSTEM ==="
input bool     UseFixedLotSize    = true;
input double   FixedLotSize       = 0.10;
input bool     EnableDebugLogs    = true;
input bool     EnableAlerts       = true;
input string   BotVersion         = "v3.2.4-Explosive";

//=== GLOBAL VARIABLES ===
int magic_number = 32400;  // v3.2.4 magic number
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

// Explosive circuit breaker
int consecutive_losses = 0;
datetime circuit_breaker_until = 0;
datetime last_hourly_reset = 0;

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
   last_hourly_reset = TimeCurrent();
   
   Print("💥 PTG EXPLOSIVE v3.2.4 - MAXIMUM SIGNALS + PROVEN BIG WINNERS!");
   Print("🚀 EXPLOSIVE Push: Range=", PushRangePercent*100, "% | Close=", ClosePercent*100, "% | Vol=", VolHighMultiplier, "×");
   Print("⏰ EXPLOSIVE Timing: Session=", SessionStartHour, "-", SessionEndHour, " | Spread=", MaxSpreadPips, "p | Momentum=", (UseMomentumFilter ? DoubleToString(MomentumThresholdPips, 1) + "p" : "OFF"));
   Print("🌟 PROVEN Exits: SL=", FixedSLPips, "p | BE=", EarlyBEPips, "p | Trail=", TrailStartPips, "p");
   Print("⚡ EXPLOSIVE Management: Max=", MaxHoldingHours, "h | EOSession=", (UseEndOfSessionExit ? IntegerToString(EOSExitHour) + ":00" : "OFF"));
   Print("🔴 EXPLOSIVE Breaker: ", MaxConsecutiveLosses, " losses → ", CooldownMinutes, "min | Reset=", (UseHourlyReset ? IntegerToString(HourlyResetInterval) + "h" : "OFF"));
   Print("💥 EXPLOSIVE PHILOSOPHY: Maximum quality signals + proven big winner management!");
   
   return INIT_SUCCEEDED;
}

//=== MAIN LOGIC ===
void OnTick() 
{
   // Explosive hourly reset
   if(UseHourlyReset && TimeCurrent() >= last_hourly_reset + HourlyResetInterval * 3600)
   {
      consecutive_losses = 0;
      last_hourly_reset = TimeCurrent();
      if(EnableDebugLogs)
         Print("🔄 HOURLY RESET: Consecutive losses reset to 0");
   }
   
   // Explosive filtering
   if(!IsExplosiveMarketOK()) return;
   if(UseBlackoutTimes && IsInBlackoutPeriod()) return;  
   if(UseSessionFilter && !IsInTradingSession()) return;
   if(UseCircuitBreaker && IsInCircuitBreaker()) return;
   
   UpdatePositionInfo();
   
   if(active_position_ticket > 0) 
   {
      ManageExplosivePosition();
      bars_since_entry++;
      return;
   }
   
   CheckExplosivePTGSignals();
}

//=== EXPLOSIVE FILTERING ===
bool IsExplosiveMarketOK() 
{
   // Explosive spread check (more generous)
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
   
   // EXPLOSIVE: Extended session for maximum opportunities
   bool in_session = (dt.hour >= SessionStartHour && dt.hour < SessionEndHour);
   
   if(!in_session && EnableDebugLogs && signal_count % 1000 == 0)
      Print("💤 OUT OF SESSION: ", IntegerToString(dt.hour), ":00 (", SessionStartHour, "-", SessionEndHour, ")");
   
   return in_session;
}

bool IsInBlackoutPeriod()
{
   if(!UseBlackoutTimes) return false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   bool in_blackout = false;
   
   if(BlackoutStartHour == 23 && BlackoutEndHour == 0)
   {
      if((dt.hour == BlackoutStartHour && dt.min >= BlackoutStartMin) ||
         (dt.hour == BlackoutEndHour && dt.min <= BlackoutEndMin))
      {
         in_blackout = true;
      }
   }
   
   return in_blackout;
}

//=== EXPLOSIVE CIRCUIT BREAKER ===
bool IsInCircuitBreaker()
{
   if(!UseCircuitBreaker) return false;
   
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
   if(UseCircuitBreaker && consecutive_losses >= MaxConsecutiveLosses)
   {
      circuit_breaker_until = TimeCurrent() + CooldownMinutes * 60;
      
      if(EnableDebugLogs)
         Print("🔴 EXPLOSIVE BREAKER ACTIVATED: ", consecutive_losses, " losses | Cooldown ", 
               CooldownMinutes, "min until ", TimeToString(circuit_breaker_until));
      
      consecutive_losses = 0;
   }
}

//=== EXPLOSIVE PTG SIGNALS ===
void CheckExplosivePTGSignals() 
{
   int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
   if(current_bar <= last_signal_bar) return;
   
   if(IsExplosivePushDetected()) 
   {
      signal_count++;
      last_signal_bar = current_bar;
      
      if(EnableDebugLogs && signal_count % 200 == 0)
         Print("💥 EXPLOSIVE PUSH #", signal_count, " detected");
      
      CheckExplosiveTestAndGo();
   }
}

bool IsExplosivePushDetected() 
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
   
   // EXPLOSIVE PTG criteria (more relaxed for more signals)
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
   
   // NEW: Momentum filter for quality
   bool momentum_ok = true;
   if(UseMomentumFilter)
   {
      double momentum_pips = MathAbs(close[0] - close[1]) / Pip();
      momentum_ok = momentum_pips >= MomentumThresholdPips;
   }
   
   return range_criteria && volume_criteria && (bullish_push || bearish_push) && opp_wick_ok && momentum_ok;
}

void CheckExplosiveTestAndGo() 
{
   bool is_bullish = IsBullishContext();
   ExecuteExplosiveEntry(is_bullish);
}

bool IsBullishContext() 
{
   double close_current = iClose(Symbol(), PERIOD_CURRENT, 1);
   double close_prev = iClose(Symbol(), PERIOD_CURRENT, 2);
   return close_current > close_prev;
}

//=== EXPLOSIVE TRADE EXECUTION ===
void ExecuteExplosiveEntry(bool is_long) 
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
   req.comment = "PTG Explosive v3.2.4";
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      last_trade_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
      trade_count++;
      entry_time = TimeCurrent();
      
      string direction = is_long ? "LONG" : "SHORT";
      
      if(EnableDebugLogs)
         Print("✅ EXPLOSIVE ENTRY: ", direction, " ", DoubleToString(FixedLotSize, 2), 
               " @ ", DoubleToString(current_price, 5));
      
      if(EnableAlerts)
         Alert("PTG Explosive ", direction, " @", DoubleToString(current_price, 5));
   } 
   else if(EnableDebugLogs)
   {
      Print("❌ EXPLOSIVE ENTRY FAILED: ", res.retcode, " - ", res.comment);
   }
}

//=== EXPLOSIVE POSITION MANAGEMENT ===
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

void ManageExplosivePosition() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double profit_pips = CalculateProfitPips(original_entry_price, current_price, is_long);
   
   // NEW: End of session exit
   if(UseEndOfSessionExit)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= EOSExitHour)
      {
         CloseExplosivePosition("Explosive EOS exit - " + IntegerToString(dt.hour) + ":00");
         return;
      }
   }
   
   // Explosive time management
   if(UseTimeBasedExit)
   {
      int holding_hours = (int)((TimeCurrent() - entry_time) / 3600);
      if(holding_hours >= MaxHoldingHours)
      {
         if(profit_pips >= MinProfitForHold)
         {
            CloseExplosivePosition("Explosive time exit - " + IntegerToString(holding_hours) + "h");
            return;
         }
      }
   }
   
   // Explosive breakeven (earlier)
   if(UseEarlyBreakeven && !breakeven_activated && profit_pips >= EarlyBEPips) 
   {
      MoveToExplosiveBreakeven();
      return;
   }
   
   // Explosive trailing (earlier + tighter)
   if(UseTrailing && !trailing_activated && profit_pips >= TrailStartPips) 
   {
      trailing_activated = true;
      if(EnableDebugLogs)
         Print("💥 EXPLOSIVE TRAILING ACTIVATED: Profit ", DoubleToString(profit_pips, 1), "p >= ", TrailStartPips, "p");
   }
   
   if(UseTrailing && trailing_activated && profit_pips >= TrailStartPips) 
   {
      TrailExplosiveStopLoss(profit_pips);
   }
}

void MoveToExplosiveBreakeven() 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   double spread = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double be_price = is_long ? 
                     (original_entry_price + spread + PriceFromPips(4.0)) :
                     (original_entry_price - spread - PriceFromPips(4.0));
   
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
         Print("🛡️ EXPLOSIVE BREAKEVEN: SL @ ", DoubleToString(be_price, 5), " (+", 
               DoubleToString(EarlyBEPips, 1), "p trigger)");
   }
}

void TrailExplosiveStopLoss(double profit_pips) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   bool is_long = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double current_sl = PositionGetDouble(POSITION_SL);
   
   // Explosive trailing (tighter steps)
   double trail_distance = profit_pips - TrailStepPips;  
   double new_sl = is_long ? 
                   original_entry_price + PriceFromPips(trail_distance) :
                   original_entry_price - PriceFromPips(trail_distance);
   
   new_sl = NormalizePrice(new_sl);
   
   // More aggressive improvement threshold
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
         Print("📈 EXPLOSIVE TRAIL: SL @ ", DoubleToString(new_sl, 5), " | Step: ", 
               DoubleToString(TrailStepPips, 1), "p | Profit: +", DoubleToString(profit_pips, 1), "p");
      }
   }
}

void CloseExplosivePosition(string reason) 
{
   if(!PositionSelectByTicket(active_position_ticket)) return;
   
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = Symbol();
   req.position = active_position_ticket;
   req.volume = PositionGetDouble(POSITION_VOLUME);
   req.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.magic = magic_number;
   req.comment = reason;
   req.deviation = 30;
   
   if(OrderSend(req, res)) 
   {
      ResetTradeState();
      if(EnableDebugLogs)
         Print("🔚 EXPLOSIVE CLOSE: ", reason);
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
               Print("💥 EXPLOSIVE FILLED: ", direction, " ", DoubleToString(trans.volume, 2), 
                     " @ ", DoubleToString(trans.price, 5));
         } 
         else 
         {
            // Exit - explosive loss tracking
            double profit_pips = 0.0;
            if(original_entry_price > 0) 
            {
               bool was_long = trans.deal_type == DEAL_TYPE_SELL;
               profit_pips = CalculateProfitPips(original_entry_price, trans.price, was_long);
               
               // Explosive loss tracking (more aggressive reset)
               if(profit_pips < -3.0)
               {
                  consecutive_losses++;
                  ActivateCircuitBreaker();
               }
               else if(profit_pips > 6.0)
               {
                  consecutive_losses = 0;
               }
            }
            
            if(EnableDebugLogs)
               Print("💰 EXPLOSIVE EXIT: ", (profit_pips >= 0 ? "+" : ""), DoubleToString(profit_pips, 1), 
                     "p | Consecutive losses: ", consecutive_losses);
            
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
   Print("💥 PTG EXPLOSIVE v3.2.4 STOPPED - MAXIMUM SIGNALS + PROVEN BIG WINNERS COMPLETE");
   Print("📊 Signals: ", signal_count, " | Trades: ", trade_count);
   Print("🔴 Consecutive Losses: ", consecutive_losses, " | Circuit Breaker: ", (UseCircuitBreaker ? "ON" : "OFF"));
   Print("💥 EXPLOSIVE PHILOSOPHY: Maximum opportunity capture + proven big winner strategy!");
}
