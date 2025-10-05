//+------------------------------------------------------------------+
//|                                                   NewsFilter.mqh |
//|           MT5 Calendar-based news filter for backtest + live     |
//|           Works for FX pairs (EURUSD, GBPJPY) and XAUUSD         |
//+------------------------------------------------------------------+
#property strict

struct NewsEvent
{
   datetime time;
   string   currency;
   int      importance;  // CALENDAR_IMPORTANCE_HIGH, MEDIUM, LOW
};

class CNewsFilter
{
private:
   NewsEvent m_events[];
   int       m_count;
   int       m_pre_minutes;
   int       m_post_minutes;
   bool      m_high_only;
   string    m_symbol;
   datetime  m_last_log_event;  // Anti-spam logging

   //+------------------------------------------------------------------+
   //| Load news from MT5 Calendar API for backtest period              |
   //+------------------------------------------------------------------+
   bool LoadNewsForPeriod(datetime from, datetime to)
   {
      string base = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
      string profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);

      // For XAUUSD: base="XAU" (no calendar), profit="USD" → only USD loaded
      // For FX: both currencies loaded (e.g., EUR + USD for EURUSD)

      MqlCalendarValue vals[];
      datetime range_from = from - 86400;  // 1 day before
      datetime range_to = to + 86400;      // 1 day after

      int n = CalendarValueHistory(vals, range_from, range_to);
      if(n <= 0)
      {
         Print("[NewsFilter] No calendar data available for ", m_symbol);
         return false;
      }

      ArrayResize(m_events, n);
      m_count = 0;

      for(int i = 0; i < n; i++)
      {
         MqlCalendarEvent evt;
         if(!CalendarEventById(vals[i].event_id, evt)) continue;

         // Filter by importance
         if(m_high_only && evt.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         if(!m_high_only && evt.importance < CALENDAR_IMPORTANCE_MEDIUM) continue;

         // Filter by currency (base OR profit currency)
         string curr = evt.currency;
         if(curr != base && curr != profit) continue;

         m_events[m_count].time = vals[i].time;
         m_events[m_count].currency = curr;
         m_events[m_count].importance = evt.importance;
         m_count++;
      }

      ArrayResize(m_events, m_count);
      Print("[NewsFilter] Loaded ", m_count, " events for ", m_symbol,
            " (", base, "/", profit, ") | Period: ", TimeToString(from), " → ", TimeToString(to));
      return true;
   }

public:
   CNewsFilter() : m_count(0), m_pre_minutes(30), m_post_minutes(15),
                   m_high_only(true), m_last_log_event(0) {}

   //+------------------------------------------------------------------+
   //| Initialize filter with symbol and time windows                   |
   //+------------------------------------------------------------------+
   void Init(string symbol, int pre_min, int post_min, bool high_only)
   {
      m_symbol = symbol;
      m_pre_minutes = pre_min;
      m_post_minutes = post_min;
      m_high_only = high_only;
   }

   //+------------------------------------------------------------------+
   //| Load news for backtest period (call in OnInit)                   |
   //+------------------------------------------------------------------+
   bool LoadNews(datetime backtest_start, datetime backtest_end)
   {
      return LoadNewsForPeriod(backtest_start, backtest_end);
   }

   //+------------------------------------------------------------------+
   //| Check if current time is within news window                      |
   //+------------------------------------------------------------------+
   bool IsNewsTime(datetime t_now)
   {
      for(int i = 0; i < m_count; i++)
      {
         datetime t_event = m_events[i].time;
         datetime t_start = t_event - m_pre_minutes * 60;
         datetime t_end = t_event + m_post_minutes * 60;

         if(t_now >= t_start && t_now <= t_end)
         {
            // Log once per event (anti-spam)
            if(t_event != m_last_log_event)
            {
               Print("[NewsFilter] 🔴 In news window: ", m_events[i].currency, " ",
                     TimeToString(t_event), " (±", m_pre_minutes, "/", m_post_minutes, "min) | Impact: ",
                     m_events[i].importance == CALENDAR_IMPORTANCE_HIGH ? "HIGH" : "MEDIUM");
               m_last_log_event = t_event;
            }
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Print upcoming news (for debugging)                              |
   //+------------------------------------------------------------------+
   void PrintUpcoming(datetime t_now, int hours = 24)
   {
      datetime t_max = t_now + hours * 3600;
      Print("[NewsFilter] Upcoming events (next ", hours, "h):");
      int found = 0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_events[i].time >= t_now && m_events[i].time <= t_max)
         {
            string impact = (m_events[i].importance == CALENDAR_IMPORTANCE_HIGH) ? "HIGH" : "MED";
            Print("  📅 ", TimeToString(m_events[i].time), " | ", m_events[i].currency, " | ", impact);
            found++;
         }
      }
      if(found == 0) Print("  (No events scheduled)");
   }

   //+------------------------------------------------------------------+
   //| Get total loaded events count                                    |
   //+------------------------------------------------------------------+
   int GetEventCount() { return m_count; }
};
