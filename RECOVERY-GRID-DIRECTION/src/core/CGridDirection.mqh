// Include guard for MQL5
#ifndef __RGD_CGRIDDIRECTION_MQH__
#define __RGD_CGRIDDIRECTION_MQH__

#include <RECOVERY-GRID-DIRECTION/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION/core/Settings.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CSpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION/core/COrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CLogger.mqh>
#include <Trade/Trade.mqh>

class CGridDirection {
private:
  string m_symbol;
  EDirection m_dir;
  SSettings m_cfg;
  CSpacingEngine *m_spacing;
  COrderExecutor *m_exec;
  CLogger *m_log;
  long m_magic;
  bool m_use_stop_pending; // false=limit grid, true=stop grid

  SGridLevel m_levels[];
  bool m_active;
  double m_last_grid_price; // furthest price in direction grid
  double m_basket_pnl_usd;
  double m_peak_pnl_usd;
  bool   m_trailing_active;
  bool   m_be_armed;

  string Tag() const {
    string d = (m_dir==DIR_BUY?"BUY":"SELL");
    return StringFormat("[GRID][%s][%s]", m_symbol, d);
  }

  double PipPoints() const {
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    if(digits==3 || digits==5) return 10.0 * _Point;
    return 1.0 * _Point;
  }

  void ClearLevels() {
    ArrayResize(m_levels, 0);
  }

  void AppendLevel(double price, double lot) {
    int n = ArraySize(m_levels);
    ArrayResize(m_levels, n+1);
    m_levels[n].price = price;
    m_levels[n].lot = lot;
    m_levels[n].ticket = 0;
    m_levels[n].is_filled = false;
  }

  void BuildLevels(double start_price, double spacing_price) {
    ClearLevels();
    // Level 0: market entry (record price)
    AppendLevel(start_price, m_cfg.lot_size);
    // Levels 1..N-1: pending limits
    for(int i=1;i<m_cfg.grid_levels_per_side;i++){
      double price = start_price;
      if(!m_use_stop_pending){
        // LIMIT grid
        if(m_dir==DIR_SELL) price += spacing_price * i; else price -= spacing_price * i;
      } else {
        // STOP grid (momentum continuation)
        if(m_dir==DIR_BUY) price += spacing_price * i; else price -= spacing_price * i;
      }
      AppendLevel(price, m_cfg.lot_size);
    }
    // last grid price stored
    int last = ArraySize(m_levels)-1;
    m_last_grid_price = m_levels[last].price;
  }

  void PlaceOrders() {
    // Market order for level 0
    if(ArraySize(m_levels)<=0) return;
    m_exec.SetMagic(m_magic);
    // bypass cooldown for this batch (market + remaining limits)
    m_exec.BypassCooldownCount(ArraySize(m_levels));
    ulong tk = m_exec.PlaceMarket(m_dir, m_levels[0].lot, "RGD_Market");
    if(tk>0) m_levels[0].ticket = tk;

    // Pending orders for remaining levels
    for(int i=1;i<ArraySize(m_levels);++i){
      ulong tkl = 0;
      if(!m_use_stop_pending)
        tkl = m_exec.PlaceLimit(m_dir, m_levels[i].price, m_levels[i].lot, "RGD_Grid");
      else
        tkl = m_exec.PlaceStop(m_dir, m_levels[i].price, m_levels[i].lot, "RGD_Grid");
      if(tkl>0){
        m_levels[i].ticket = tkl;
      } else {
        if(m_log) m_log.Event(Tag(), StringFormat("%s level %d rejected at %.5f",
                                  (!m_use_stop_pending?"Limit":"Stop"), i, m_levels[i].price));
      }
    }
  }

  void UpdateBasketPnL() {
    m_basket_pnl_usd = 0.0;
    int total = (int)PositionsTotal();
    for(int i=0;i<total;i++){
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionSelectByTicket(ticket)){
        if(PositionGetString(POSITION_SYMBOL)!=m_symbol) continue;
        long magic = (long)PositionGetInteger(POSITION_MAGIC);
        if(magic!=m_magic) continue;
        long type = (long)PositionGetInteger(POSITION_TYPE);
        if((m_dir==DIR_BUY && type==POSITION_TYPE_BUY) || (m_dir==DIR_SELL && type==POSITION_TYPE_SELL)){
          m_basket_pnl_usd += PositionGetDouble(POSITION_PROFIT);
        }
      }
    }
  }

  void TryCloseByBasketTP() {
    if(!m_cfg.use_basket_tp) return;
    if(m_basket_pnl_usd >= m_cfg.basket_tp_usd){
      // Close all positions for this direction
      CloseAllPositionsAndCancelPending("BasketTP");
    }
  }

public:
  CGridDirection(const string symbol,
                 const EDirection dir,
                 const SSettings &cfg,
                 CSpacingEngine *spacing,
                 COrderExecutor *exec,
                 CLogger *log,
                 const long magic,
                 const bool use_stop_pending)
    : m_symbol(symbol), m_dir(dir), m_cfg(cfg), m_spacing(spacing), m_exec(exec), m_log(log), m_magic(magic),
      m_active(false), m_last_grid_price(0.0), m_basket_pnl_usd(0.0), m_peak_pnl_usd(0.0), m_trailing_active(false), m_be_armed(false),
      m_use_stop_pending(use_stop_pending) {}

  bool Init(const double start_price){
    double spacing_pips = m_spacing.SpacingPips();
    double spacing_price = spacing_pips * PipPoints();
    BuildLevels(start_price, spacing_price);
    PlaceOrders();
    m_active = true;
    m_log.Event(Tag(), StringFormat("Init grid N=%d spacing=%.1f pips (%s)", m_cfg.grid_levels_per_side, spacing_pips,
                                    (!m_use_stop_pending?"LIMIT":"STOP")));
    return true;
  }

  void Update(){
    if(!m_active) return;
    UpdateBasketPnL();
    // Arm breakeven
    if(m_cfg.use_breakeven){
      if(!m_be_armed && m_basket_pnl_usd>=m_cfg.basket_breakeven_after_usd) m_be_armed=true;
    }
    // Activate trailing
    if(m_cfg.use_trailing && !m_trailing_active && m_basket_pnl_usd>=m_cfg.basket_trailing_start_usd){
      m_trailing_active=true; m_peak_pnl_usd=m_basket_pnl_usd;
    }
    if(m_cfg.use_trailing && m_trailing_active){
      if(m_basket_pnl_usd>m_peak_pnl_usd) m_peak_pnl_usd=m_basket_pnl_usd;
      if(m_peak_pnl_usd - m_basket_pnl_usd >= m_cfg.basket_trailing_lock_usd){
        CloseAllPositionsAndCancelPending("TrailingLock");
      }
    }
    // Breakeven: hiện tại không tự đóng để tránh xóa pending ngoài ý muốn
    TryCloseByBasketTP();
    if(m_log && m_log.ShouldStatus()){
      m_log.Status(Tag(), StringFormat("basket_pnl=%.2f last_grid=%.5f", m_basket_pnl_usd, m_last_grid_price));
    }
    // update active flag
    if(!HasOpenPositions() && !HasPendingOrders()) m_active=false;
  }

  bool IsActive() const { return m_active; }
  double BasketPnL() const { return m_basket_pnl_usd; }
  double LastGridPrice() const { return m_last_grid_price; }
  EDirection Direction() const { return m_dir; }
  string Symbol() const { return m_symbol; }

  bool HasOpenPositions() const {
    int total=(int)PositionsTotal();
    for(int i=0;i<total;i++){
      ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=m_symbol) continue;
      long magic=(long)PositionGetInteger(POSITION_MAGIC); if(magic!=m_magic) continue;
      long type=(long)PositionGetInteger(POSITION_TYPE);
      if((m_dir==DIR_BUY && type==POSITION_TYPE_BUY) || (m_dir==DIR_SELL && type==POSITION_TYPE_SELL)) return true;
    }
    return false;
  }
  bool HasPendingOrders() const {
    int total=(int)OrdersTotal();
    for(int i=0;i<total;i++){
      ulong ticket=OrderGetTicket(i); if(ticket==0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=m_symbol) continue;
      long magic=(long)OrderGetInteger(ORDER_MAGIC); if(magic!=m_magic) continue;
      long type=(long)OrderGetInteger(ORDER_TYPE);
      if(!m_use_stop_pending){
        if((m_dir==DIR_BUY && type==ORDER_TYPE_BUY_LIMIT) || (m_dir==DIR_SELL && type==ORDER_TYPE_SELL_LIMIT)) return true;
      } else {
        if((m_dir==DIR_BUY && type==ORDER_TYPE_BUY_STOP) || (m_dir==DIR_SELL && type==ORDER_TYPE_SELL_STOP)) return true;
      }
    }
    return false;
  }
  void CancelPending() {
    int total=(int)OrdersTotal();
    CTrade t; t.SetExpertMagicNumber(m_magic);
    for(int i=0;i<total;i++){
      ulong ticket=OrderGetTicket(i); if(ticket==0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=m_symbol) continue;
      long magic=(long)OrderGetInteger(ORDER_MAGIC); if(magic!=m_magic) continue;
      long type=(long)OrderGetInteger(ORDER_TYPE);
      bool match=false;
      if(!m_use_stop_pending){
        match = ((m_dir==DIR_BUY && type==ORDER_TYPE_BUY_LIMIT) || (m_dir==DIR_SELL && type==ORDER_TYPE_SELL_LIMIT));
      } else {
        match = ((m_dir==DIR_BUY && type==ORDER_TYPE_BUY_STOP) || (m_dir==DIR_SELL && type==ORDER_TYPE_SELL_STOP));
      }
      if(match){
        t.OrderDelete(ticket);
      }
    }
  }

  void CloseAllPositionsAndCancelPending(const string reason){
    // Close positions
    int total=(int)PositionsTotal();
    CTrade trade; trade.SetExpertMagicNumber(m_magic);
    for(int i=0;i<total;i++){
      ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=m_symbol) continue;
      long magic=(long)PositionGetInteger(POSITION_MAGIC); if(magic!=m_magic) continue;
      long type=(long)PositionGetInteger(POSITION_TYPE);
      if((m_dir==DIR_BUY && type==POSITION_TYPE_BUY) || (m_dir==DIR_SELL && type==POSITION_TYPE_SELL)){
        trade.PositionClose(ticket);
      }
    }
    // Cancel pending
    CancelPending();
    if(m_log) m_log.Event(Tag(), StringFormat("Closed basket & pending [%s]", reason));
  }
};

#endif // __RGD_CGRIDDIRECTION_MQH__
