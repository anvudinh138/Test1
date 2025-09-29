// Include guard for MQL5
#ifndef __RGD_CLOGGER_MQH__
#define __RGD_CLOGGER_MQH__

class CLogger {
private:
  datetime m_last_status;
  int m_interval;
  bool m_events;
public:
  CLogger(const int status_interval_sec, const bool event_logs)
    : m_last_status(0), m_interval(status_interval_sec), m_events(event_logs) {}

  void Event(string tag, string msg) {
    if(!m_events) return;
    PrintFormat("%s %s", tag, msg);
  }

  bool ShouldStatus() {
    datetime now = TimeCurrent();
    if(now - m_last_status >= m_interval) {
      m_last_status = now;
      return true;
    }
    return false;
  }

  void Status(string tag, string snapshot) {
    if(ShouldStatus()) PrintFormat("%s %s", tag, snapshot);
  }
};

#endif // __RGD_CLOGGER_MQH__
