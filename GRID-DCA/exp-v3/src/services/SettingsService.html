//+------------------------------------------------------------------+
//|                                           SettingsService.mqh    |
//|                                       FlexGridDCA EA v3.2.0      |
//|                              Centralized Settings Management     |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Settings Service - Singleton Pattern                            |
//| Manages all EA inputs and provides global access               |
//+------------------------------------------------------------------+
class CSettingsService
{
private:
    static CSettingsService* m_instance;
    
    // Constructor is private for Singleton
    CSettingsService() {}
    
public:
    // ==================== RISK MANAGEMENT ====================
    static double    MaxAccountRisk;
    static double    ProfitTargetPercent;
    static double    ProfitTargetUSD;
    static bool      UseTotalProfitTarget;
    static double    MaxLossUSD;
    static double    MaxEquityDrawdownPercent;
    static double    MinMarginLevel;
    
    // ==================== ENHANCED RISK ====================
    static bool      UseATRDollarSizing;
    static double    RiskPerLevelUSD;
    static double    MaxExposurePerDirection;
    static int       MaxPositionsPerDirection;
    
    // ==================== GRID SETTINGS ====================
    static double    FixedLotSize;
    static int       MaxGridLevels;
    static double    ATRMultiplier;
    static double    MaxSpreadPips;
    static double    MaxSpreadPipsWait;
    static bool      UseVolatilityFilter;
    
    // ==================== NEWS FILTER ====================
    static bool      UseNewsFilter;
    static int       NewsAvoidMinutes;
    static string    NewsEvents;
    static bool      AvoidFridayClose;
    
    // ==================== PRESET & LOGGING ====================
    static bool      UsePresetConfig;
    static string    PresetSymbols;
    static bool      EnableCSVExport;
    static bool      EnableDebugMode;
    static int       LogLevel;
    
    // ==================== TIME FILTERS ====================
    static int       StartHour;
    static int       EndHour;
    
    // ==================== ADVANCED ====================
    static double    TrailingStopATR;
    static int       MagicNumber;
    static string    EAComment;
    
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CSettingsService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CSettingsService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize from EA Inputs                                       |
    //+------------------------------------------------------------------+
    static void InitializeFromInputs(
        double inp_max_account_risk,
        double inp_profit_target_percent,
        double inp_profit_target_usd,
        bool   inp_use_total_profit_target,
        double inp_max_loss_usd,
        double inp_max_equity_drawdown_percent,
        double inp_min_margin_level,
        bool   inp_use_atr_dollar_sizing,
        double inp_risk_per_level_usd,
        double inp_max_exposure_per_direction,
        int    inp_max_positions_per_direction,
        double inp_fixed_lot_size,
        int    inp_max_grid_levels,
        double inp_atr_multiplier,
        double inp_max_spread_pips,
        double inp_max_spread_pips_wait,
        bool   inp_use_volatility_filter,
        bool   inp_use_news_filter,
        int    inp_news_avoid_minutes,
        string inp_news_events,
        bool   inp_avoid_friday_close,
        bool   inp_use_preset_config,
        string inp_preset_symbols,
        bool   inp_enable_csv_export,
        bool   inp_enable_debug_mode,
        int    inp_log_level,
        int    inp_start_hour,
        int    inp_end_hour,
        double inp_trailing_stop_atr,
        int    inp_magic_number,
        string inp_ea_comment)
    {
        MaxAccountRisk = inp_max_account_risk;
        ProfitTargetPercent = inp_profit_target_percent;
        ProfitTargetUSD = inp_profit_target_usd;
        UseTotalProfitTarget = inp_use_total_profit_target;
        MaxLossUSD = inp_max_loss_usd;
        MaxEquityDrawdownPercent = inp_max_equity_drawdown_percent;
        MinMarginLevel = inp_min_margin_level;
        
        UseATRDollarSizing = inp_use_atr_dollar_sizing;
        RiskPerLevelUSD = inp_risk_per_level_usd;
        MaxExposurePerDirection = inp_max_exposure_per_direction;
        MaxPositionsPerDirection = inp_max_positions_per_direction;
        
        FixedLotSize = inp_fixed_lot_size;
        MaxGridLevels = inp_max_grid_levels;
        ATRMultiplier = inp_atr_multiplier;
        MaxSpreadPips = inp_max_spread_pips;
        MaxSpreadPipsWait = inp_max_spread_pips_wait;
        UseVolatilityFilter = inp_use_volatility_filter;
        
        UseNewsFilter = inp_use_news_filter;
        NewsAvoidMinutes = inp_news_avoid_minutes;
        NewsEvents = inp_news_events;
        AvoidFridayClose = inp_avoid_friday_close;
        
        UsePresetConfig = inp_use_preset_config;
        PresetSymbols = inp_preset_symbols;
        EnableCSVExport = inp_enable_csv_export;
        EnableDebugMode = inp_enable_debug_mode;
        LogLevel = inp_log_level;
        
        StartHour = inp_start_hour;
        EndHour = inp_end_hour;
        
        TrailingStopATR = inp_trailing_stop_atr;
        MagicNumber = inp_magic_number;
        EAComment = inp_ea_comment;
        
        Print("✅ Settings Service initialized with all EA inputs");
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
    
    //+------------------------------------------------------------------+
    //| Debug Print All Settings                                        |
    //+------------------------------------------------------------------+
    static void PrintAllSettings()
    {
        Print("=== SETTINGS SERVICE - ALL PARAMETERS ===");
        Print("Risk: MaxAccountRisk=", MaxAccountRisk, "%, ProfitTarget=$", ProfitTargetUSD);
        Print("Grid: FixedLot=", FixedLotSize, ", MaxLevels=", MaxGridLevels, ", ATRMult=", ATRMultiplier);
        Print("Enhanced Risk: ATRDollar=", UseATRDollarSizing, ", Risk/Level=$", RiskPerLevelUSD);
        Print("News Filter: Enabled=", UseNewsFilter, ", Events=", NewsEvents);
        Print("Logging: CSV=", EnableCSVExport, ", Debug=", EnableDebugMode, ", Level=", LogLevel);
        Print("==========================================");
    }
};

// Static member definitions
CSettingsService* CSettingsService::m_instance = NULL;
double    CSettingsService::MaxAccountRisk = 10.0;
double    CSettingsService::ProfitTargetPercent = 1.0;
double    CSettingsService::ProfitTargetUSD = 4.0;
bool      CSettingsService::UseTotalProfitTarget = true;
double    CSettingsService::MaxLossUSD = 10.0;
double    CSettingsService::MaxEquityDrawdownPercent = 15.0;
double    CSettingsService::MinMarginLevel = 200.0;
bool      CSettingsService::UseATRDollarSizing = false;
double    CSettingsService::RiskPerLevelUSD = 5.0;
double    CSettingsService::MaxExposurePerDirection = 50.0;
int       CSettingsService::MaxPositionsPerDirection = 10;
double    CSettingsService::FixedLotSize = 0.01;
int       CSettingsService::MaxGridLevels = 13;
double    CSettingsService::ATRMultiplier = 1.2;
double    CSettingsService::MaxSpreadPips = 0.0;
double    CSettingsService::MaxSpreadPipsWait = 0.0;
bool      CSettingsService::UseVolatilityFilter = false;
bool      CSettingsService::UseNewsFilter = false;
int       CSettingsService::NewsAvoidMinutes = 30;
string    CSettingsService::NewsEvents = "NFP,FOMC,GDP,CPI,PMI";
bool      CSettingsService::AvoidFridayClose = true;
bool      CSettingsService::UsePresetConfig = false;
string    CSettingsService::PresetSymbols = "EURUSD,GBPUSD,XAUUSD,BTCUSD,USDJPY";
bool      CSettingsService::EnableCSVExport = true;
bool      CSettingsService::EnableDebugMode = false;
int       CSettingsService::LogLevel = 2;
int       CSettingsService::StartHour = 10;
int       CSettingsService::EndHour = 20;
double    CSettingsService::TrailingStopATR = 2.4;
int       CSettingsService::MagicNumber = 12345;
string    CSettingsService::EAComment = "FlexGridDCA";

//+------------------------------------------------------------------+
