//+------------------------------------------------------------------+
//|                                       SymbolAdapterService.mqh   |
//|                                       FlexGridDCA EA v3.2.0      |
//|                              Symbol-Specific Configuration       |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <services/SettingsService.mqh>

//+------------------------------------------------------------------+
//| Symbol Configuration Structure                                   |
//+------------------------------------------------------------------+
struct SSymbolConfig
{
    string symbol;
    double lot_size_override;         // Override lot size for this symbol
    int    max_grid_levels_override;  // Override grid levels
    double atr_multiplier_override;   // Override ATR multiplier
    double profit_target_override;    // Override profit target
    double max_loss_override;         // Override max loss
    double max_spread_pips;           // Symbol-specific spread limit
    double risk_per_level_override;   // Override risk per level
    double max_exposure_override;     // Override max exposure
    int    killzone_start;            // Symbol-specific killzone start hour
    int    killzone_end;              // Symbol-specific killzone end hour
    bool   use_trend_filter;          // Symbol-specific trend filter
    bool   use_news_filter;           // Symbol-specific news filter
    string description;               // Symbol description
    bool   is_active;                 // Enable/disable this symbol
};

//+------------------------------------------------------------------+
//| Symbol Adapter Service                                           |
//| Manages symbol-specific configurations for multi-symbol trading |
//+------------------------------------------------------------------+
class CSymbolAdapterService
{
private:
    static CSymbolAdapterService* m_instance;
    SSymbolConfig m_symbol_configs[];
    string m_current_symbol;
    
    CSymbolAdapterService() { InitializeDefaultConfigs(); }
    
public:
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CSymbolAdapterService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CSymbolAdapterService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Default Symbol Configurations                        |
    //+------------------------------------------------------------------+
    void InitializeDefaultConfigs()
    {
        ArrayResize(m_symbol_configs, 8);
        
        // EURUSD - Conservative Forex
        m_symbol_configs[0].symbol = "EURUSD";
        m_symbol_configs[0].lot_size_override = 0.01;
        m_symbol_configs[0].max_grid_levels_override = 10;
        m_symbol_configs[0].atr_multiplier_override = 1.2;
        m_symbol_configs[0].profit_target_override = 3.0;
        m_symbol_configs[0].max_loss_override = 8.0;
        m_symbol_configs[0].max_spread_pips = 2.0;
        m_symbol_configs[0].risk_per_level_override = 4.0;
        m_symbol_configs[0].max_exposure_override = 40.0;
        m_symbol_configs[0].killzone_start = 8;
        m_symbol_configs[0].killzone_end = 20;
        m_symbol_configs[0].use_trend_filter = true;
        m_symbol_configs[0].use_news_filter = true;
        m_symbol_configs[0].description = "Major EUR/USD - Conservative";
        m_symbol_configs[0].is_active = true;
        
        // GBPUSD - Moderate Forex (higher volatility)
        m_symbol_configs[1].symbol = "GBPUSD";
        m_symbol_configs[1].lot_size_override = 0.01;
        m_symbol_configs[1].max_grid_levels_override = 12;
        m_symbol_configs[1].atr_multiplier_override = 1.4;
        m_symbol_configs[1].profit_target_override = 4.0;
        m_symbol_configs[1].max_loss_override = 10.0;
        m_symbol_configs[1].max_spread_pips = 3.0;
        m_symbol_configs[1].risk_per_level_override = 5.0;
        m_symbol_configs[1].max_exposure_override = 50.0;
        m_symbol_configs[1].killzone_start = 8;
        m_symbol_configs[1].killzone_end = 20;
        m_symbol_configs[1].use_trend_filter = true;
        m_symbol_configs[1].use_news_filter = true;
        m_symbol_configs[1].description = "Major GBP/USD - Moderate";
        m_symbol_configs[1].is_active = true;
        
        // XAUUSD - Gold (high volatility, wider spreads)
        m_symbol_configs[2].symbol = "XAUUSD";
        m_symbol_configs[2].lot_size_override = 0.01;
        m_symbol_configs[2].max_grid_levels_override = 8;
        m_symbol_configs[2].atr_multiplier_override = 0.8;
        m_symbol_configs[2].profit_target_override = 8.0;
        m_symbol_configs[2].max_loss_override = 20.0;
        m_symbol_configs[2].max_spread_pips = 50.0;
        m_symbol_configs[2].risk_per_level_override = 10.0;
        m_symbol_configs[2].max_exposure_override = 80.0;
        m_symbol_configs[2].killzone_start = 10;
        m_symbol_configs[2].killzone_end = 22;
        m_symbol_configs[2].use_trend_filter = true;
        m_symbol_configs[2].use_news_filter = true;
        m_symbol_configs[2].description = "Gold Trading - High Volatility";
        m_symbol_configs[2].is_active = true;
        
        // BTCUSD - Crypto (very high volatility)
        m_symbol_configs[3].symbol = "BTCUSD";
        m_symbol_configs[3].lot_size_override = 0.01;
        m_symbol_configs[3].max_grid_levels_override = 6;
        m_symbol_configs[3].atr_multiplier_override = 0.6;
        m_symbol_configs[3].profit_target_override = 15.0;
        m_symbol_configs[3].max_loss_override = 40.0;
        m_symbol_configs[3].max_spread_pips = 100.0;
        m_symbol_configs[3].risk_per_level_override = 20.0;
        m_symbol_configs[3].max_exposure_override = 120.0;
        m_symbol_configs[3].killzone_start = 0;
        m_symbol_configs[3].killzone_end = 24;
        m_symbol_configs[3].use_trend_filter = false;
        m_symbol_configs[3].use_news_filter = false;
        m_symbol_configs[3].description = "Bitcoin Trading - Extreme Volatility";
        m_symbol_configs[3].is_active = true;
        
        // USDJPY - Stable Forex
        m_symbol_configs[4].symbol = "USDJPY";
        m_symbol_configs[4].lot_size_override = 0.01;
        m_symbol_configs[4].max_grid_levels_override = 11;
        m_symbol_configs[4].atr_multiplier_override = 1.3;
        m_symbol_configs[4].profit_target_override = 3.5;
        m_symbol_configs[4].max_loss_override = 9.0;
        m_symbol_configs[4].max_spread_pips = 2.5;
        m_symbol_configs[4].risk_per_level_override = 4.5;
        m_symbol_configs[4].max_exposure_override = 45.0;
        m_symbol_configs[4].killzone_start = 9;
        m_symbol_configs[4].killzone_end = 21;
        m_symbol_configs[4].use_trend_filter = true;
        m_symbol_configs[4].use_news_filter = true;
        m_symbol_configs[4].description = "USD/JPY - Stable Forex";
        m_symbol_configs[4].is_active = true;
        
        // AUDUSD - Commodity Currency
        m_symbol_configs[5].symbol = "AUDUSD";
        m_symbol_configs[5].lot_size_override = 0.01;
        m_symbol_configs[5].max_grid_levels_override = 9;
        m_symbol_configs[5].atr_multiplier_override = 1.1;
        m_symbol_configs[5].profit_target_override = 3.2;
        m_symbol_configs[5].max_loss_override = 8.5;
        m_symbol_configs[5].max_spread_pips = 2.8;
        m_symbol_configs[5].risk_per_level_override = 4.2;
        m_symbol_configs[5].max_exposure_override = 38.0;
        m_symbol_configs[5].killzone_start = 9;
        m_symbol_configs[5].killzone_end = 19;
        m_symbol_configs[5].use_trend_filter = true;
        m_symbol_configs[5].use_news_filter = true;
        m_symbol_configs[5].description = "AUD/USD - Commodity Currency";
        m_symbol_configs[5].is_active = false;
        
        // USDCAD - Oil-correlated
        m_symbol_configs[6].symbol = "USDCAD";
        m_symbol_configs[6].lot_size_override = 0.01;
        m_symbol_configs[6].max_grid_levels_override = 10;
        m_symbol_configs[6].atr_multiplier_override = 1.25;
        m_symbol_configs[6].profit_target_override = 3.3;
        m_symbol_configs[6].max_loss_override = 8.8;
        m_symbol_configs[6].max_spread_pips = 2.2;
        m_symbol_configs[6].risk_per_level_override = 4.3;
        m_symbol_configs[6].max_exposure_override = 43.0;
        m_symbol_configs[6].killzone_start = 9;
        m_symbol_configs[6].killzone_end = 20;
        m_symbol_configs[6].use_trend_filter = true;
        m_symbol_configs[6].use_news_filter = true;
        m_symbol_configs[6].description = "USD/CAD - Oil Correlated";
        m_symbol_configs[6].is_active = false;
        
        // NZDUSD - Risk-on Currency
        m_symbol_configs[7].symbol = "NZDUSD";
        m_symbol_configs[7].lot_size_override = 0.01;
        m_symbol_configs[7].max_grid_levels_override = 9;
        m_symbol_configs[7].atr_multiplier_override = 1.15;
        m_symbol_configs[7].profit_target_override = 3.0;
        m_symbol_configs[7].max_loss_override = 8.0;
        m_symbol_configs[7].max_spread_pips = 3.5;
        m_symbol_configs[7].risk_per_level_override = 4.0;
        m_symbol_configs[7].max_exposure_override = 36.0;
        m_symbol_configs[7].killzone_start = 10;
        m_symbol_configs[7].killzone_end = 18;
        m_symbol_configs[7].use_trend_filter = true;
        m_symbol_configs[7].use_news_filter = true;
        m_symbol_configs[7].description = "NZD/USD - Risk-on Currency";
        m_symbol_configs[7].is_active = false;
        
        Print("✅ Symbol Adapter Service initialized with 8 symbol configurations");
    }
    
    //+------------------------------------------------------------------+
    //| Set Current Active Symbol                                       |
    //+------------------------------------------------------------------+
    void SetCurrentSymbol(string symbol)
    {
        m_current_symbol = symbol;
        Print("📊 Symbol Adapter: Active symbol set to ", symbol);
    }
    
    //+------------------------------------------------------------------+
    //| Get Symbol Configuration                                         |
    //+------------------------------------------------------------------+
    SSymbolConfig GetSymbolConfig(string symbol)
    {
        for(int i = 0; i < ArraySize(m_symbol_configs); i++)
        {
            if(StringFind(symbol, m_symbol_configs[i].symbol) >= 0 && m_symbol_configs[i].is_active)
            {
                Print("✅ Found symbol config for ", symbol, ": ", m_symbol_configs[i].description);
                return m_symbol_configs[i];
            }
        }
        
        // Return default config if not found
        SSymbolConfig default_config;
        default_config.symbol = symbol;
        default_config.lot_size_override = CSettingsService::FixedLotSize;
        default_config.max_grid_levels_override = CSettingsService::MaxGridLevels;
        default_config.atr_multiplier_override = CSettingsService::ATRMultiplier;
        default_config.profit_target_override = CSettingsService::ProfitTargetUSD;
        default_config.max_loss_override = CSettingsService::MaxLossUSD;
        default_config.max_spread_pips = CSettingsService::MaxSpreadPips;
        default_config.risk_per_level_override = CSettingsService::RiskPerLevelUSD;
        default_config.max_exposure_override = CSettingsService::MaxExposurePerDirection;
        default_config.killzone_start = CSettingsService::StartHour;
        default_config.killzone_end = CSettingsService::EndHour;
        default_config.use_trend_filter = true;
        default_config.use_news_filter = CSettingsService::UseNewsFilter;
        default_config.description = "Default Configuration";
        default_config.is_active = true;
        
        Print("⚠️ No specific config for ", symbol, ". Using default configuration.");
        return default_config;
    }
    
    //+------------------------------------------------------------------+
    //| Get Active Symbols List                                         |
    //+------------------------------------------------------------------+
    void GetActiveSymbols(string &active_symbols[])
    {
        ArrayResize(active_symbols, 0);
        
        for(int i = 0; i < ArraySize(m_symbol_configs); i++)
        {
            if(m_symbol_configs[i].is_active)
            {
                ArrayResize(active_symbols, ArraySize(active_symbols) + 1);
                active_symbols[ArraySize(active_symbols) - 1] = m_symbol_configs[i].symbol;
            }
        }
        
        Print("✅ Active symbols count: ", ArraySize(active_symbols));
    }
    
    //+------------------------------------------------------------------+
    //| Enable/Disable Symbol                                           |
    //+------------------------------------------------------------------+
    bool SetSymbolActive(string symbol, bool is_active)
    {
        for(int i = 0; i < ArraySize(m_symbol_configs); i++)
        {
            if(m_symbol_configs[i].symbol == symbol)
            {
                m_symbol_configs[i].is_active = is_active;
                Print("📊 Symbol ", symbol, " set to ", (is_active ? "ACTIVE" : "INACTIVE"));
                return true;
            }
        }
        
        Print("❌ Symbol ", symbol, " not found in configurations");
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Print All Symbol Configurations                                 |
    //+------------------------------------------------------------------+
    void PrintAllConfigurations()
    {
        Print("=== SYMBOL ADAPTER SERVICE - ALL CONFIGURATIONS ===");
        for(int i = 0; i < ArraySize(m_symbol_configs); i++)
        {
            SSymbolConfig config = m_symbol_configs[i];
            Print("Symbol: ", config.symbol, " | Status: ", (config.is_active ? "ACTIVE" : "INACTIVE"));
            Print("  ├─ Lot: ", config.lot_size_override, " | Grid: ", config.max_grid_levels_override, " | ATR: ", config.atr_multiplier_override);
            Print("  ├─ Profit: $", config.profit_target_override, " | Loss: $", config.max_loss_override, " | Spread: ", config.max_spread_pips, "pips");
            Print("  ├─ Risk/Level: $", config.risk_per_level_override, " | Exposure: $", config.max_exposure_override);
            Print("  ├─ Killzone: ", config.killzone_start, ":00-", config.killzone_end, ":00 | Trend: ", config.use_trend_filter, " | News: ", config.use_news_filter);
            Print("  └─ Description: ", config.description);
        }
        Print("==================================================");
    }
    
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
CSymbolAdapterService* CSymbolAdapterService::m_instance = NULL;

//+------------------------------------------------------------------+
