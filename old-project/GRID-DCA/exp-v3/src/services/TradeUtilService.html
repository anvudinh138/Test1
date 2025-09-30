//+------------------------------------------------------------------+
//|                                         TradeUtilService.mqh     |
//|                                       FlexGridDCA EA v3.2.0      |
//|                               Enhanced Trade Execution Wrapper   |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <services/SettingsService.mqh>

//+------------------------------------------------------------------+
//| Trade Result Structure                                           |
//+------------------------------------------------------------------+
struct STradeResult
{
    bool     success;
    ulong    ticket;
    string   error_message;
    int      error_code;
    double   executed_price;
    double   executed_volume;
};

//+------------------------------------------------------------------+
//| Order Type Enumeration                                          |
//+------------------------------------------------------------------+
enum EORDER_TYPE_ENHANCED
{
    ORDER_BUY_MARKET,       // Market Buy
    ORDER_SELL_MARKET,      // Market Sell
    ORDER_BUY_LIMIT_ORDER,  // Buy Limit
    ORDER_SELL_LIMIT_ORDER, // Sell Limit
    ORDER_BUY_STOP_ORDER,   // Buy Stop
    ORDER_SELL_STOP_ORDER   // Sell Stop
};

//+------------------------------------------------------------------+
//| Trade Util Service                                              |
//| Advanced wrapper for CTrade with enhanced error handling        |
//+------------------------------------------------------------------+
class CTradeUtilService
{
private:
    static CTradeUtilService* m_instance;
    CTrade m_trade;
    string m_last_error;
    int    m_retry_attempts;
    int    m_max_retries;
    
    CTradeUtilService()
    {
        m_max_retries = 3;
        m_retry_attempts = 0;
        m_last_error = "";
        
        // Configure CTrade settings
        m_trade.SetAsyncMode(false);
        m_trade.SetMarginMode();
        m_trade.SetTypeFillingBySymbol(_Symbol);
        
        Print("✅ Trade Util Service initialized");
    }
    
    //+------------------------------------------------------------------+
    //| Validate Order Parameters                                       |
    //+------------------------------------------------------------------+
    bool ValidateOrderParameters(string symbol, double volume, double price, EORDER_TYPE_ENHANCED order_type)
    {
        // Check symbol
        if(!SymbolSelect(symbol, true))
        {
            m_last_error = "Symbol " + symbol + " not available";
            return false;
        }
        
        // Check volume
        double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        
        if(volume < min_volume || volume > max_volume)
        {
            m_last_error = StringFormat("Invalid volume %.3f (min: %.3f, max: %.3f)", volume, min_volume, max_volume);
            return false;
        }
        
        // Check volume step
        if(step_volume > 0)
        {
            double remainder = MathMod(volume, step_volume);
            if(remainder > 0.0001)
            {
                m_last_error = StringFormat("Volume %.3f not aligned with step %.3f", volume, step_volume);
                return false;
            }
        }
        
        // Check price for limit/stop orders
        if(order_type != ORDER_BUY_MARKET && order_type != ORDER_SELL_MARKET)
        {
            if(price <= 0)
            {
                m_last_error = "Invalid price for limit/stop order";
                return false;
            }
            
            // Check minimum distance from current price
            double current_price = (order_type == ORDER_BUY_LIMIT_ORDER || order_type == ORDER_BUY_STOP_ORDER) ? 
                                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                                   SymbolInfoDouble(symbol, SYMBOL_BID);
            
            int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double min_distance = stops_level * point;
            
            if(min_distance > 0)
            {
                double distance = MathAbs(price - current_price);
                if(distance < min_distance)
                {
                    m_last_error = StringFormat("Order too close to market (distance: %.5f, minimum: %.5f)", distance, min_distance);
                    return false;
                }
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Execute Order with Retry Logic                                  |
    //+------------------------------------------------------------------+
    STradeResult ExecuteOrderWithRetry(string symbol, double volume, double price, EORDER_TYPE_ENHANCED order_type, string comment, int magic_number)
    {
        STradeResult result;
        result.success = false;
        result.ticket = 0;
        result.error_message = "";
        result.error_code = 0;
        result.executed_price = 0.0;
        result.executed_volume = 0.0;
        
        m_trade.SetExpertMagicNumber(magic_number);
        
        for(m_retry_attempts = 0; m_retry_attempts <= m_max_retries; m_retry_attempts++)
        {
            bool order_result = false;
            
            switch(order_type)
            {
                case ORDER_BUY_MARKET:
                    order_result = m_trade.Buy(volume, symbol, 0, 0, 0, comment);
                    break;
                    
                case ORDER_SELL_MARKET:
                    order_result = m_trade.Sell(volume, symbol, 0, 0, 0, comment);
                    break;
                    
                case ORDER_BUY_LIMIT_ORDER:
                    order_result = m_trade.BuyLimit(volume, price, symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    break;
                    
                case ORDER_SELL_LIMIT_ORDER:
                    order_result = m_trade.SellLimit(volume, price, symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    break;
                    
                case ORDER_BUY_STOP_ORDER:
                    order_result = m_trade.BuyStop(volume, price, symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    break;
                    
                case ORDER_SELL_STOP_ORDER:
                    order_result = m_trade.SellStop(volume, price, symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    break;
            }
            
            if(order_result)
            {
                result.success = true;
                result.ticket = m_trade.ResultOrder();
                result.executed_price = m_trade.ResultPrice();
                result.executed_volume = m_trade.ResultVolume();
                
                string order_type_name = GetOrderTypeName(order_type);
                if(CSettingsService::LogLevel >= 2) // INFO level
                {
                    Print("✅ ", order_type_name, " order executed successfully");
                    Print("  ├─ Symbol: ", symbol, " | Volume: ", volume, " | Price: ", DoubleToString(result.executed_price, _Digits));
                    Print("  └─ Ticket: ", result.ticket, " | Comment: ", comment);
                }
                
                break;
            }
            else
            {
                result.error_code = GetLastError();
                result.error_message = m_trade.ResultRetcodeDescription();
                
                if(CSettingsService::LogLevel >= 1) // WARNING level
                {
                    Print("⚠️ Order attempt ", m_retry_attempts + 1, " failed - ", result.error_message);
                }
                
                // Don't retry for certain critical errors
                if(result.error_code == TRADE_RETCODE_INVALID_VOLUME ||
                   result.error_code == TRADE_RETCODE_INVALID_PRICE ||
                   result.error_code == TRADE_RETCODE_INVALID_STOPS ||
                   result.error_code == TRADE_RETCODE_NOT_ENOUGH_MONEY ||
                   result.error_code == TRADE_RETCODE_TRADE_DISABLED)
                {
                    break;
                }
                
                // Wait before retry
                if(m_retry_attempts < m_max_retries)
                {
                    Sleep(1000); // 1 second wait
                }
            }
        }
        
        if(!result.success && CSettingsService::LogLevel >= 0) // ERROR level
        {
            Print("❌ Failed to execute order after ", m_max_retries + 1, " attempts");
            Print("  └─ Final error: ", result.error_message, " (", result.error_code, ")");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Get Order Type Name                                             |
    //+------------------------------------------------------------------+
    string GetOrderTypeName(EORDER_TYPE_ENHANCED order_type)
    {
        switch(order_type)
        {
            case ORDER_BUY_MARKET:      return "BUY MARKET";
            case ORDER_SELL_MARKET:     return "SELL MARKET";
            case ORDER_BUY_LIMIT_ORDER: return "BUY LIMIT";
            case ORDER_SELL_LIMIT_ORDER:return "SELL LIMIT";
            case ORDER_BUY_STOP_ORDER:  return "BUY STOP";
            case ORDER_SELL_STOP_ORDER: return "SELL STOP";
            default:                    return "UNKNOWN";
        }
    }
    
public:
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CTradeUtilService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CTradeUtilService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Place Market Order                                               |
    //+------------------------------------------------------------------+
    STradeResult PlaceMarketOrder(string symbol, double volume, bool is_buy, string comment = "", int magic_number = 0)
    {
        if(magic_number == 0) magic_number = CSettingsService::MagicNumber;
        
        if(!ValidateOrderParameters(symbol, volume, 0, is_buy ? ORDER_BUY_MARKET : ORDER_SELL_MARKET))
        {
            STradeResult error_result;
            error_result.success = false;
            error_result.error_message = m_last_error;
            return error_result;
        }
        
        EORDER_TYPE_ENHANCED order_type = is_buy ? ORDER_BUY_MARKET : ORDER_SELL_MARKET;
        return ExecuteOrderWithRetry(symbol, volume, 0, order_type, comment, magic_number);
    }
    
    //+------------------------------------------------------------------+
    //| Place Limit Order                                               |
    //+------------------------------------------------------------------+
    STradeResult PlaceLimitOrder(string symbol, double volume, double price, bool is_buy, string comment = "", int magic_number = 0)
    {
        if(magic_number == 0) magic_number = CSettingsService::MagicNumber;
        
        EORDER_TYPE_ENHANCED order_type = is_buy ? ORDER_BUY_LIMIT_ORDER : ORDER_SELL_LIMIT_ORDER;
        
        if(!ValidateOrderParameters(symbol, volume, price, order_type))
        {
            STradeResult error_result;
            error_result.success = false;
            error_result.error_message = m_last_error;
            return error_result;
        }
        
        return ExecuteOrderWithRetry(symbol, volume, price, order_type, comment, magic_number);
    }
    
    //+------------------------------------------------------------------+
    //| Place Stop Order                                                |
    //+------------------------------------------------------------------+
    STradeResult PlaceStopOrder(string symbol, double volume, double price, bool is_buy, string comment = "", int magic_number = 0)
    {
        if(magic_number == 0) magic_number = CSettingsService::MagicNumber;
        
        EORDER_TYPE_ENHANCED order_type = is_buy ? ORDER_BUY_STOP_ORDER : ORDER_SELL_STOP_ORDER;
        
        if(!ValidateOrderParameters(symbol, volume, price, order_type))
        {
            STradeResult error_result;
            error_result.success = false;
            error_result.error_message = m_last_error;
            return error_result;
        }
        
        return ExecuteOrderWithRetry(symbol, volume, price, order_type, comment, magic_number);
    }
    
    //+------------------------------------------------------------------+
    //| Close Position by Ticket                                        |
    //+------------------------------------------------------------------+
    bool ClosePosition(ulong ticket)
    {
        if(!PositionSelectByTicket(ticket))
        {
            if(CSettingsService::LogLevel >= 1) // WARNING
                Print("⚠️ Position with ticket ", ticket, " not found");
            return false;
        }
        
        bool result = m_trade.PositionClose(ticket);
        
        if(result)
        {
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("✅ Position ", ticket, " closed successfully");
        }
        else
        {
            if(CSettingsService::LogLevel >= 0) // ERROR
                Print("❌ Failed to close position ", ticket, ": ", m_trade.ResultRetcodeDescription());
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Cancel Pending Order                                            |
    //+------------------------------------------------------------------+
    bool CancelOrder(ulong ticket)
    {
        bool result = m_trade.OrderDelete(ticket);
        
        if(result)
        {
            if(CSettingsService::LogLevel >= 2) // INFO
                Print("✅ Order ", ticket, " cancelled successfully");
        }
        else
        {
            if(CSettingsService::LogLevel >= 0) // ERROR
                Print("❌ Failed to cancel order ", ticket, ": ", m_trade.ResultRetcodeDescription());
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Close All Positions for Symbol and Magic                        |
    //+------------------------------------------------------------------+
    int CloseAllPositions(string symbol, int magic_number = 0)
    {
        if(magic_number == 0) magic_number = CSettingsService::MagicNumber;
        
        int closed_count = 0;
        
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetSymbol(i) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == magic_number)
            {
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                if(ClosePosition(ticket))
                {
                    closed_count++;
                }
            }
        }
        
        if(CSettingsService::LogLevel >= 1) // WARNING
            Print("🔄 Closed ", closed_count, " positions for ", symbol);
        
        return closed_count;
    }
    
    //+------------------------------------------------------------------+
    //| Cancel All Orders for Symbol and Magic                          |
    //+------------------------------------------------------------------+
    int CancelAllOrders(string symbol, int magic_number = 0)
    {
        if(magic_number == 0) magic_number = CSettingsService::MagicNumber;
        
        int cancelled_count = 0;
        
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            if(OrderGetString(ORDER_SYMBOL) == symbol && 
               OrderGetInteger(ORDER_MAGIC) == magic_number)
            {
                ulong ticket = OrderGetTicket(i);
                if(CancelOrder(ticket))
                {
                    cancelled_count++;
                }
            }
        }
        
        if(CSettingsService::LogLevel >= 1) // WARNING
            Print("🔄 Cancelled ", cancelled_count, " orders for ", symbol);
        
        return cancelled_count;
    }
    
    //+------------------------------------------------------------------+
    //| Get Last Error Message                                          |
    //+------------------------------------------------------------------+
    string GetLastError() { return m_last_error; }
    
    //+------------------------------------------------------------------+
    //| Set Maximum Retry Attempts                                      |
    //+------------------------------------------------------------------+
    void SetMaxRetries(int max_retries) { m_max_retries = max_retries; }
    
    //+------------------------------------------------------------------+
    //| Cleanup                                                          |
    //+------------------------------------------------------------------+
    static void Cleanup()
    {
        if(m_instance != NULL)
        {
            delete m_instance;
            m_instance = NULL;
        }
    }
};

// Static member definition
CTradeUtilService* CTradeUtilService::m_instance = NULL;

//+------------------------------------------------------------------+
