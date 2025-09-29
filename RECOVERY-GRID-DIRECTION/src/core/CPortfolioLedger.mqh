// Include guard for MQL5
#ifndef __RGD_CPORTFOLIOLEDGER_MQH__
#define __RGD_CPORTFOLIOLEDGER_MQH__

class CPortfolioLedger {
private:
  double m_symbol_cap_lots;
  double m_portfolio_cap_lots;
  double m_portfolio_sl_usd;

public:
  CPortfolioLedger(const double symbol_cap_lots,
                   const double portfolio_cap_lots,
                   const double portfolio_sl_usd)
    : m_symbol_cap_lots(symbol_cap_lots),
      m_portfolio_cap_lots(portfolio_cap_lots),
      m_portfolio_sl_usd(portfolio_sl_usd) {}

  double NetExposureLotsAll() const {
    double lots = 0.0;
    int total = (int)PositionsTotal();
    for(int i=0;i<total;i++){
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionSelectByTicket(ticket))
        lots += PositionGetDouble(POSITION_VOLUME);
    }
    return lots;
  }

  double NetExposureLotsSymbol(const string symbol) const {
    double lots = 0.0;
    int total = (int)PositionsTotal();
    for(int i=0;i<total;i++){
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionSelectByTicket(ticket)){
        if(PositionGetString(POSITION_SYMBOL)==symbol)
          lots += PositionGetDouble(POSITION_VOLUME);
      }
    }
    return lots;
  }

  bool ExposureAllowed(const string symbol, const double additional_lots) const {
    if(NetExposureLotsAll() + additional_lots > m_portfolio_cap_lots) return false;
    if(NetExposureLotsSymbol(symbol) + additional_lots > m_symbol_cap_lots) return false;
    return true;
  }

  bool PortfolioRiskBreached() const {
    static double peak_equity = 0.0;
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    if(eq>peak_equity) peak_equity = eq;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    // Stop-loss is an absolute USD threshold from current balance for MVP
    if(m_portfolio_sl_usd>0 && (balance - eq) >= m_portfolio_sl_usd) return true;
    return false;
  }
};

#endif // __RGD_CPORTFOLIOLEDGER_MQH__
