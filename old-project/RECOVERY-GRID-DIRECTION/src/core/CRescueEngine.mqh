// Include guard for MQL5
#ifndef __RGD_CRESCUEENGINE_MQH__
#define __RGD_CRESCUEENGINE_MQH__

class CRescueEngine {
private:
  double m_offset_ratio;
  double m_dd_open_usd;
  double m_dd_reenter_usd;
  int m_cooldown_sec;
  int m_max_cycles;
  datetime m_last_rescue_time;
  int m_cycles;

public:
  CRescueEngine(const double offset_ratio,
                const double dd_open_usd,
                const double dd_reenter_usd,
                const int cooldown_sec,
                const int max_cycles)
    : m_offset_ratio(offset_ratio), m_dd_open_usd(dd_open_usd), m_dd_reenter_usd(dd_reenter_usd),
      m_cooldown_sec(cooldown_sec), m_max_cycles(max_cycles), m_last_rescue_time(0), m_cycles(0) {}

  bool CooldownOk() const {
    return (TimeCurrent() - m_last_rescue_time) >= m_cooldown_sec;
  }

  bool CyclesLeft() const { return m_cycles < m_max_cycles; }

  void RecordRescue() { m_last_rescue_time = TimeCurrent(); m_cycles++; }

  bool ShouldOpenRescue(EDirection loser_dir,
                        double last_grid_price,
                        double spacing_price,
                        double current_price,
                        double loser_dd_usd) const {
    bool break_ok = false;
    if(spacing_price>0){
      double offset = spacing_price * m_offset_ratio;
      if(loser_dir==DIR_SELL){
        // SELL side thua khi giá vượt qua last SELL grid lên phía trên
        if(current_price > last_grid_price + offset) break_ok = true;
      } else {
        // BUY side thua khi giá vượt qua last BUY grid xuống phía dưới
        if(current_price < last_grid_price - offset) break_ok = true;
      }
    }
    bool dd_ok = (loser_dd_usd >= m_dd_open_usd);
    return (break_ok || dd_ok);
  }

  bool ShouldReopenWinner(double loser_dd_usd) const {
    return loser_dd_usd >= m_dd_reenter_usd;
  }
};

#endif // __RGD_CRESCUEENGINE_MQH__
