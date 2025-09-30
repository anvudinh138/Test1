// Include guard for MQL5
#ifndef __RGD_CLIFECYCLECONTROLLER_MQH__
#define __RGD_CLIFECYCLECONTROLLER_MQH__

#include <RECOVERY-GRID-DIRECTION/core/Types.mqh>
#include <RECOVERY-GRID-DIRECTION/core/Settings.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CGridDirection.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CRescueEngine.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CPortfolioLedger.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CSpacingEngine.mqh>
#include <RECOVERY-GRID-DIRECTION/core/COrderExecutor.mqh>
#include <RECOVERY-GRID-DIRECTION/core/CLogger.mqh>

enum ELifecycleState { LC_IDLE=0, LC_A_ACTIVE, LC_B_ACTIVE, LC_HALTED };

class CLifecycleController {
private:
  string m_symbol;
  SSettings m_cfg;
  CSpacingEngine *m_spacing;
  COrderExecutor *m_exec;
  CRescueEngine *m_rescue;
  CPortfolioLedger *m_ledger;
  CLogger *m_log;
  long m_magic;

  CGridDirection *m_A; // primary
  CGridDirection *m_B; // rescue
  EDirection m_start_dir;
  ELifecycleState m_state;

  string Tag() const { return StringFormat("[LC][%s]", m_symbol); }

  double PipPoints() const {
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    if(digits==3 || digits==5) return 10.0 * _Point;
    return 1.0 * _Point;
  }

  double CurrentPrice(EDirection dir) const {
    return (dir==DIR_BUY)? SymbolInfoDouble(m_symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(m_symbol, SYMBOL_BID);
  }

  EDirection Opposite(EDirection d) const { return (d==DIR_BUY)? DIR_SELL : DIR_BUY; }

  EDirection DecideStartDir(){
    if(!m_cfg.use_ema_for_start) return m_start_dir;
    // EMA bias: price above EMA -> BUY, below -> SELL
    int handle = iMA(m_symbol, m_cfg.ema_timeframe, m_cfg.ema_period, 0, MODE_EMA, PRICE_CLOSE);
    if(handle==INVALID_HANDLE) return m_start_dir;
    double ema[]; if(CopyBuffer(handle,0,0,1,ema)!=1) return m_start_dir;
    double price = iClose(m_symbol, m_cfg.ema_timeframe, 0);
    if(price==0.0) price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    return (price>=ema[0])? DIR_BUY : DIR_SELL;
  }

public:
  CLifecycleController(const string symbol,
                       const EDirection start_dir,
                       const SSettings &cfg,
                       CSpacingEngine *spacing,
                       COrderExecutor *exec,
                       CRescueEngine *rescue,
                       CPortfolioLedger *ledger,
                       CLogger *log,
                       const long magic)
    : m_symbol(symbol), m_cfg(cfg), m_spacing(spacing), m_exec(exec), m_rescue(rescue), m_ledger(ledger), m_log(log), m_magic(magic),
      m_A(NULL), m_B(NULL), m_start_dir(start_dir), m_state(LC_IDLE) {}

  bool Init(){
    // Open initial grid A on start_dir
    double start_price = CurrentPrice(m_start_dir);
    if(!m_ledger.ExposureAllowed(m_symbol, m_cfg.lot_size)){
      m_log.Event(Tag(), "Exposure cap reached. Cannot start lifecycle.");
      m_state = LC_HALTED; return false;
    }
    m_A = new CGridDirection(m_symbol, m_start_dir, m_cfg, m_spacing, m_exec, m_log, m_magic, /*use_stop_pending=*/false);
    m_A.Init(start_price);
    m_state = LC_A_ACTIVE;
    m_log.Event(Tag(), StringFormat("Init A %s", (m_start_dir==DIR_BUY?"BUY":"SELL")));
    return true;
  }

  void Update(){
    if(m_state==LC_HALTED) return;
    if(m_ledger.PortfolioRiskBreached()){
      m_log.Event(Tag(), "Portfolio SL breached. Halt lifecycle.");
      m_state = LC_HALTED; return; // Simplified: not closing positions here in skeleton
    }

    if(m_A!=NULL) m_A.Update();
    if(m_B!=NULL) m_B.Update();

    // Evaluate rescue: if only A active and losing, consider opening B
    // If A is active and B inactive or null, consider opening B as rescue
    if(m_A!=NULL && m_A.IsActive() && (m_B==NULL || !m_B.IsActive())){
      double spacing_pips = m_spacing.SpacingPips();
      double spacing_px = spacing_pips * PipPoints();
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double last_grid = m_A.LastGridPrice();
      double dd_usd = -MathMin(0.0, m_A.BasketPnL()); // if negative, take absolute value
      if(m_rescue.CooldownOk() && m_rescue.CyclesLeft()){
        if(m_rescue.ShouldOpenRescue(m_A.Direction(), last_grid, spacing_px, price, dd_usd)){
          EDirection opp = Opposite(m_A.Direction());
          if(m_ledger.ExposureAllowed(m_symbol, m_cfg.lot_size)){
            double start_price = CurrentPrice(opp);
            m_B = new CGridDirection(m_symbol, opp, m_cfg, m_spacing, m_exec, m_log, m_magic, /*use_stop_pending=*/true);
            m_B.Init(start_price);
            m_rescue.RecordRescue();
            m_state = LC_B_ACTIVE;
            m_log.Event(Tag(), "Opened rescue B");
          } else {
            m_log.Event(Tag(), "Rescue blocked by exposure cap");
          }
        } else {
          // Debug reason
          if(m_log) m_log.Status(Tag(), StringFormat("No rescue: dir=%s price=%.5f last=%.5f dd=%.2f spacing_px=%.5f",
                                   (m_A.Direction()==DIR_BUY?"BUY":"SELL"), price, last_grid, dd_usd, spacing_px));
        }
      }
    }

    // Mirror: if B is active and A inactive or null, consider opening A as rescue
    if(m_B!=NULL && m_B.IsActive() && (m_A==NULL || !m_A.IsActive())){
      double spacing_pips = m_spacing.SpacingPips();
      double spacing_px = spacing_pips * PipPoints();
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double last_grid = m_B.LastGridPrice();
      double dd_usd = -MathMin(0.0, m_B.BasketPnL());
      if(m_rescue.CooldownOk() && m_rescue.CyclesLeft()){
        if(m_rescue.ShouldOpenRescue(m_B.Direction(), last_grid, spacing_px, price, dd_usd)){
          EDirection opp = Opposite(m_B.Direction());
          if(m_ledger.ExposureAllowed(m_symbol, m_cfg.lot_size)){
            double start_price = CurrentPrice(opp);
            m_A = new CGridDirection(m_symbol, opp, m_cfg, m_spacing, m_exec, m_log, m_magic, /*use_stop_pending=*/true);
            m_A.Init(start_price);
            m_rescue.RecordRescue();
            m_state = LC_A_ACTIVE;
            m_log.Event(Tag(), "Opened rescue A");
          } else {
            m_log.Event(Tag(), "Rescue A blocked by exposure cap");
          }
        }
      }
    }

    // Simplified: check halt conditions (exposure) - handled implicitly via PortfolioRiskBreached.

    // Auto-restart when both sides flat
    bool flatA = (m_A==NULL) || (m_A!=NULL && !m_A.IsActive());
    bool flatB = (m_B==NULL) || (m_B!=NULL && !m_B.IsActive());
    if(m_cfg.auto_restart && flatA && flatB){
      // cleanup previous objects
      if(m_A){ delete m_A; m_A=NULL; }
      if(m_B){ delete m_B; m_B=NULL; }
      EDirection dir = DecideStartDir();
      double start_price = CurrentPrice(dir);
      if(m_ledger.ExposureAllowed(m_symbol, m_cfg.lot_size)){
        m_A = new CGridDirection(m_symbol, dir, m_cfg, m_spacing, m_exec, m_log, m_magic, /*use_stop_pending=*/false);
        m_A.Init(start_price);
        m_state = LC_A_ACTIVE;
        m_log.Event(Tag(), StringFormat("Auto-restart A %s", (dir==DIR_BUY?"BUY":"SELL")));
      }
    }
  }

  void Shutdown(){
    // In real implementation: close pending/positions, delete objects
    if(m_A){ delete m_A; m_A=NULL; }
    if(m_B){ delete m_B; m_B=NULL; }
  }
};

#endif // __RGD_CLIFECYCLECONTROLLER_MQH__
