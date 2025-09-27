//+------------------------------------------------------------------+
//|                                       DashboardUIService.mqh     |
//|                                       FlexGridDCA EA v3.2.0      |
//|                         Professional On-Chart Dashboard UI       |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

#include <../services/SettingsService.mqh>

//+------------------------------------------------------------------+
//| Dashboard Element Structure                                      |
//+------------------------------------------------------------------+
struct SDashboardElement
{
    string   object_name;      // Object name for MT5
    string   display_text;     // Text to display
    int      x_position;       // X coordinate
    int      y_position;       // Y coordinate
    int      font_size;        // Font size
    color    text_color;       // Text color
    string   font_name;        // Font name
    bool     is_visible;       // Visibility flag
    bool     is_clickable;     // Whether element is clickable
};

//+------------------------------------------------------------------+
//| Dashboard Layout Configuration                                   |
//+------------------------------------------------------------------+
struct SDashboardLayout
{
    string layout_name;        // Layout identifier
    int    panel_width;        // Panel width
    int    panel_height;       // Panel height
    int    panel_x;            // Panel X position
    int    panel_y;            // Panel Y position
    color  background_color;   // Background color
    color  border_color;       // Border color
    int    line_height;        // Space between lines
    int    margin_left;        // Left margin
    int    margin_top;         // Top margin
};

//+------------------------------------------------------------------+
//| Dashboard UI Service                                            |
//| Professional on-chart dashboard with multiple layouts          |
//+------------------------------------------------------------------+
class CDashboardUIService
{
private:
    static CDashboardUIService* m_instance;
    
    SDashboardElement m_elements[];    // All dashboard elements
    SDashboardLayout  m_current_layout; // Current layout configuration
    
    bool     m_is_initialized;
    bool     m_is_visible;
    string   m_dashboard_prefix;       // Prefix for all object names
    int      m_update_counter;         // Update frequency control
    int      m_update_interval;        // Updates every N ticks
    datetime m_last_update_time;
    
    // Button states
    bool     m_panic_button_pressed;
    bool     m_minimize_button_pressed;
    
    CDashboardUIService()
    {
        m_is_initialized = false;
        m_is_visible = true;
        m_dashboard_prefix = "FGDCA_";
        m_update_counter = 0;
        m_update_interval = 5; // Update every 5 ticks
        m_last_update_time = 0;
        m_panic_button_pressed = false;
        m_minimize_button_pressed = false;
        
        InitializeDefaultLayout();
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Default Layout                                       |
    //+------------------------------------------------------------------+
    void InitializeDefaultLayout()
    {
        m_current_layout.layout_name = "Professional";
        m_current_layout.panel_width = 320;
        m_current_layout.panel_height = 280; // Increased height for more info
        m_current_layout.panel_x = 10;
        m_current_layout.panel_y = 30;
        m_current_layout.background_color = C'20,20,30';      // Dark blue
        m_current_layout.border_color = C'60,60,80';          // Light blue border
        m_current_layout.line_height = 18;
        m_current_layout.margin_left = 15;
        m_current_layout.margin_top = 10;
    }
    
    //+------------------------------------------------------------------+
    //| Create Dashboard Element                                        |
    //+------------------------------------------------------------------+
    bool CreateElement(string name, string text, int x, int y, int font_size, color text_color, bool clickable = false)
    {
        string full_name = m_dashboard_prefix + name;
        
        if(clickable)
        {
            // Create button (rectangle)
            if(!ObjectCreate(0, full_name + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0))
                return false;
                
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_XDISTANCE, x);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_XSIZE, StringLen(text) * font_size / 2 + 10);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_YSIZE, font_size + 6);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_BGCOLOR, C'180,50,50');  // Red background
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_BORDER_COLOR, C'220,80,80');
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, full_name + "_BG", OBJPROP_BACK, false);
        }
        
        // Create text label
        if(!ObjectCreate(0, full_name, OBJ_LABEL, 0, 0, 0))
            return false;
        
        ObjectSetInteger(0, full_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, full_name, OBJPROP_XDISTANCE, x + (clickable ? 5 : 0));
        ObjectSetInteger(0, full_name, OBJPROP_YDISTANCE, y + (clickable ? 3 : 0));
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, text_color);
        ObjectSetInteger(0, full_name, OBJPROP_FONTSIZE, font_size);
        ObjectSetString(0, full_name, OBJPROP_FONT, "Consolas");
        ObjectSetString(0, full_name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, full_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, full_name, OBJPROP_BACK, false);
        
        // Store element info
        int size = ArraySize(m_elements);
        ArrayResize(m_elements, size + 1);
        
        m_elements[size].object_name = full_name;
        m_elements[size].display_text = text;
        m_elements[size].x_position = x;
        m_elements[size].y_position = y;
        m_elements[size].font_size = font_size;
        m_elements[size].text_color = text_color;
        m_elements[size].font_name = "Consolas";
        m_elements[size].is_visible = true;
        m_elements[size].is_clickable = clickable;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Update Element Text                                             |
    //+------------------------------------------------------------------+
    bool UpdateElementText(string name, string new_text)
    {
        string full_name = m_dashboard_prefix + name;
        
        if(ObjectFind(0, full_name) >= 0)
        {
            ObjectSetString(0, full_name, OBJPROP_TEXT, new_text);
            
            // Update stored info
            for(int i = 0; i < ArraySize(m_elements); i++)
            {
                if(m_elements[i].object_name == full_name)
                {
                    m_elements[i].display_text = new_text;
                    break;
                }
            }
            
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Update Element Color                                            |
    //+------------------------------------------------------------------+
    bool UpdateElementColor(string name, color new_color)
    {
        string full_name = m_dashboard_prefix + name;
        
        if(ObjectFind(0, full_name) >= 0)
        {
            ObjectSetInteger(0, full_name, OBJPROP_COLOR, new_color);
            
            // Update stored info
            for(int i = 0; i < ArraySize(m_elements); i++)
            {
                if(m_elements[i].object_name == full_name)
                {
                    m_elements[i].text_color = new_color;
                    break;
                }
            }
            
            return true;
        }
        
        return false;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Singleton Instance                                               |
    //+------------------------------------------------------------------+
    static CDashboardUIService* GetInstance()
    {
        if(m_instance == NULL)
        {
            m_instance = new CDashboardUIService();
        }
        return m_instance;
    }
    
    //+------------------------------------------------------------------+
    //| Initialize Dashboard                                            |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol)
    {
        if(m_is_initialized) return true;
        
        // Create main background panel
        string panel_name = m_dashboard_prefix + "MainPanel";
        if(!ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
        {
            if(CSettingsService::LogLevel >= 0) // ERROR
                Print("❌ Failed to create dashboard main panel");
            return false;
        }
        
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, m_current_layout.panel_x);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, m_current_layout.panel_y);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, m_current_layout.panel_width);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, m_current_layout.panel_height);
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, m_current_layout.background_color);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, m_current_layout.border_color);
        ObjectSetInteger(0, panel_name, OBJPROP_COLOR, m_current_layout.border_color);
        ObjectSetInteger(0, panel_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
        
        // Create dashboard elements
        int y_offset = m_current_layout.panel_y + m_current_layout.margin_top;
        int x_offset = m_current_layout.panel_x + m_current_layout.margin_left;
        int line_height = m_current_layout.line_height;
        
        // Title
        CreateElement("Title", "FlexGridDCA v3.2.0 - " + symbol, x_offset, y_offset, 10, clrWhite);
        y_offset += line_height + 5;
        
        // Status line
        CreateElement("Status", "Status: Initializing...", x_offset, y_offset, 9, clrYellow);
        y_offset += line_height;
        
        // Profit lines
        CreateElement("BuyProfit", "Buy Profit: $0.00", x_offset, y_offset, 8, clrLimeGreen);
        y_offset += line_height;
        
        CreateElement("SellProfit", "Sell Profit: $0.00", x_offset, y_offset, 8, clrTomato);
        y_offset += line_height;
        
        CreateElement("TotalProfit", "Total: $0.00", x_offset, y_offset, 9, clrWhite);
        y_offset += line_height;
        
        CreateElement("Target", "Target: $" + DoubleToString(CSettingsService::ProfitTargetUSD, 2), x_offset, y_offset, 8, clrGold);
        y_offset += line_height;
        
        // Market info
        CreateElement("Trend", "Trend: Unknown", x_offset, y_offset, 8, clrLightBlue);
        y_offset += line_height;
        
        CreateElement("Spread", "Spread: 0.0 pips", x_offset, y_offset, 8, clrSilver);
        y_offset += line_height;
        
        CreateElement("News", "News: No Filter", x_offset, y_offset, 8, clrWhite);
        y_offset += line_height;
        
        // ENHANCED: Detailed state information
        CreateElement("StateInfo", "State: Initializing...", x_offset, y_offset, 8, clrYellow);
        y_offset += line_height;
        
        CreateElement("ADXInfo", "ADX: 0.0 (Unknown)", x_offset, y_offset, 8, clrLightBlue);
        y_offset += line_height;
        
        CreateElement("SpreadInfo", "Spread: OK", x_offset, y_offset, 8, clrLimeGreen);
        y_offset += line_height;
        
        CreateElement("TimeInfo", "Time: OK", x_offset, y_offset, 8, clrWhite);
        y_offset += line_height;
        
        // Action buttons
        CreateElement("PanicButton", "EMERGENCY CLOSE", x_offset + 170, y_offset, 9, clrWhite, true);
        CreateElement("MinimizeButton", "[-]", x_offset + 280, m_current_layout.panel_y + 5, 8, clrSilver, true);
        
        m_is_initialized = true;
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("✅ Dashboard UI Service initialized for ", symbol);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Update Dashboard Data (Enhanced)                                |
    //+------------------------------------------------------------------+
    void Update(string symbol, string status, double buy_profit, double sell_profit, double target, string trend_status, double spread, string news_status, string state_reason = "", double adx_value = 0.0, bool time_allowed = true)
    {
        if(!m_is_initialized || !m_is_visible) return;
        
        // Control update frequency
        m_update_counter++;
        if(m_update_counter < m_update_interval) return;
        m_update_counter = 0;
        
        // Update status with color coding
        color status_color = clrWhite;
        if(StringFind(status, "TRADING") >= 0) status_color = clrLimeGreen;
        else if(StringFind(status, "WAITING") >= 0) status_color = clrYellow;
        else if(StringFind(status, "CLOSING") >= 0) status_color = clrOrange;
        else if(StringFind(status, "PAUSE") >= 0) status_color = clrTomato;
        
        UpdateElementText("Status", "Status: " + status);
        UpdateElementColor("Status", status_color);
        
        // Update profits
        color buy_color = (buy_profit >= 0) ? clrLimeGreen : clrTomato;
        color sell_color = (sell_profit >= 0) ? clrLimeGreen : clrTomato;
        color total_color = (buy_profit + sell_profit >= 0) ? clrLimeGreen : clrTomato;
        
        UpdateElementText("BuyProfit", "Buy: $" + DoubleToString(buy_profit, 2));
        UpdateElementColor("BuyProfit", buy_color);
        
        UpdateElementText("SellProfit", "Sell: $" + DoubleToString(sell_profit, 2));
        UpdateElementColor("SellProfit", sell_color);
        
        UpdateElementText("TotalProfit", "Total: $" + DoubleToString(buy_profit + sell_profit, 2));
        UpdateElementColor("TotalProfit", total_color);
        
        // Update target
        UpdateElementText("Target", "Target: $" + DoubleToString(target, 2));
        
        // Update trend
        color trend_color = clrWhite;
        if(StringFind(trend_status, "TRENDING") >= 0) trend_color = clrOrange;
        else if(StringFind(trend_status, "SIDEWAYS") >= 0) trend_color = clrLimeGreen;
        
        UpdateElementText("Trend", "Trend: " + trend_status);
        UpdateElementColor("Trend", trend_color);
        
        // Update spread
        color spread_color = (spread <= 3.0) ? clrLimeGreen : (spread <= 5.0) ? clrYellow : clrTomato;
        UpdateElementText("Spread", "Spread: " + DoubleToString(spread, 1) + " pips");
        UpdateElementColor("Spread", spread_color);
        
        // Update news status
        color news_color = (StringFind(news_status, "PAUSE") >= 0) ? clrTomato : clrLightBlue;
        string news_display = news_status;
        if(StringLen(news_display) > 25) news_display = StringSubstr(news_display, 0, 25) + "...";
        
        UpdateElementText("News", "News: " + news_display);
        UpdateElementColor("News", news_color);
        
        // ENHANCED: Update detailed state info
        if(state_reason != "")
        {
            color state_color = clrYellow;
            if(StringFind(state_reason, "WAITING") >= 0) state_color = clrOrange;
            else if(StringFind(state_reason, "READY") >= 0) state_color = clrLimeGreen;
            else if(StringFind(state_reason, "BLOCKED") >= 0) state_color = clrTomato;
            
            UpdateElementText("StateInfo", "State: " + state_reason);
            UpdateElementColor("StateInfo", state_color);
        }
        
        // Update ADX info
        if(adx_value > 0)
        {
            color adx_color = clrWhite;
            string adx_level = "Unknown";
            if(adx_value < 25) { adx_level = "Weak"; adx_color = clrLimeGreen; }
            else if(adx_value < 35) { adx_level = "Moderate"; adx_color = clrYellow; }
            else { adx_level = "Strong"; adx_color = clrTomato; }
            
            UpdateElementText("ADXInfo", "ADX: " + DoubleToString(adx_value, 1) + " (" + adx_level + ")");
            UpdateElementColor("ADXInfo", adx_color);
        }
        
        // Update spread info
        color spread_info_color = (spread <= 3.0) ? clrLimeGreen : (spread <= 5.0) ? clrYellow : clrTomato;
        string spread_status = (spread <= 3.0) ? "Good" : (spread <= 5.0) ? "High" : "Too High";
        UpdateElementText("SpreadInfo", "Spread: " + DoubleToString(spread, 1) + "p (" + spread_status + ")");
        UpdateElementColor("SpreadInfo", spread_info_color);
        
        // Update time info
        color time_color = time_allowed ? clrLimeGreen : clrTomato;
        string time_status = time_allowed ? "Trading Hours" : "Outside Hours";
        UpdateElementText("TimeInfo", "Time: " + time_status);
        UpdateElementColor("TimeInfo", time_color);
        
        m_last_update_time = TimeCurrent();
        
        if(CSettingsService::EnableDebugMode && CSettingsService::LogLevel >= 3) // DEBUG
        {
            Print("🔍 Dashboard updated - Profit: $", DoubleToString(buy_profit + sell_profit, 2), " | Status: ", status);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Handle Chart Events                                             |
    //+------------------------------------------------------------------+
    bool HandleChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
    {
        if(!m_is_initialized) return false;
        
        if(id == CHARTEVENT_OBJECT_CLICK)
        {
            // Panic Button
            if(sparam == m_dashboard_prefix + "PanicButton_BG")
            {
                m_panic_button_pressed = true;
                
                // Reset button state
                ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                
                if(CSettingsService::LogLevel >= 1) // WARNING
                    Print("🚨 PANIC BUTTON PRESSED via Dashboard UI!");
                
                return true; // Event handled
            }
            
            // Minimize Button
            if(sparam == m_dashboard_prefix + "MinimizeButton_BG")
            {
                m_minimize_button_pressed = true;
                ToggleVisibility();
                
                // Reset button state
                ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                
                return true; // Event handled
            }
        }
        
        return false; // Event not handled
    }
    
    //+------------------------------------------------------------------+
    //| Check if Panic Button was Pressed                              |
    //+------------------------------------------------------------------+
    bool IsPanicButtonPressed()
    {
        bool pressed = m_panic_button_pressed;
        m_panic_button_pressed = false; // Reset flag
        return pressed;
    }
    
    //+------------------------------------------------------------------+
    //| Toggle Dashboard Visibility                                     |
    //+------------------------------------------------------------------+
    void ToggleVisibility()
    {
        m_is_visible = !m_is_visible;
        
        // Toggle main panel
        string panel_name = m_dashboard_prefix + "MainPanel";
        ObjectSetInteger(0, panel_name, OBJPROP_TIMEFRAMES, m_is_visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
        
        // Toggle all elements
        for(int i = 0; i < ArraySize(m_elements); i++)
        {
            ObjectSetInteger(0, m_elements[i].object_name, OBJPROP_TIMEFRAMES, m_is_visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
            
            // Also toggle button backgrounds
            if(m_elements[i].is_clickable)
            {
                ObjectSetInteger(0, m_elements[i].object_name + "_BG", OBJPROP_TIMEFRAMES, m_is_visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
            }
        }
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("👁️ Dashboard ", (m_is_visible ? "shown" : "hidden"));
    }
    
    //+------------------------------------------------------------------+
    //| Set Dashboard Position                                          |
    //+------------------------------------------------------------------+
    void SetPosition(int x, int y)
    {
        if(!m_is_initialized) return;
        
        int delta_x = x - m_current_layout.panel_x;
        int delta_y = y - m_current_layout.panel_y;
        
        m_current_layout.panel_x = x;
        m_current_layout.panel_y = y;
        
        // Move main panel
        string panel_name = m_dashboard_prefix + "MainPanel";
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, y);
        
        // Move all elements
        for(int i = 0; i < ArraySize(m_elements); i++)
        {
            m_elements[i].x_position += delta_x;
            m_elements[i].y_position += delta_y;
            
            ObjectSetInteger(0, m_elements[i].object_name, OBJPROP_XDISTANCE, m_elements[i].x_position);
            ObjectSetInteger(0, m_elements[i].object_name, OBJPROP_YDISTANCE, m_elements[i].y_position);
            
            // Also move button backgrounds
            if(m_elements[i].is_clickable)
            {
                ObjectSetInteger(0, m_elements[i].object_name + "_BG", OBJPROP_XDISTANCE, m_elements[i].x_position - 5);
                ObjectSetInteger(0, m_elements[i].object_name + "_BG", OBJPROP_YDISTANCE, m_elements[i].y_position - 3);
            }
        }
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("📍 Dashboard moved to position (", x, ", ", y, ")");
    }
    
    //+------------------------------------------------------------------+
    //| Get Dashboard Status                                            |
    //+------------------------------------------------------------------+
    string GetStatus()
    {
        if(!m_is_initialized) return "Not Initialized";
        if(!m_is_visible) return "Hidden";
        
        return "Active (" + IntegerToString(ArraySize(m_elements)) + " elements)";
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup All Dashboard Objects                                   |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        if(!m_is_initialized) return;
        
        // Remove main panel
        string panel_name = m_dashboard_prefix + "MainPanel";
        ObjectDelete(0, panel_name);
        
        // Remove all elements
        for(int i = 0; i < ArraySize(m_elements); i++)
        {
            ObjectDelete(0, m_elements[i].object_name);
            
            // Also remove button backgrounds
            if(m_elements[i].is_clickable)
            {
                ObjectDelete(0, m_elements[i].object_name + "_BG");
            }
        }
        
        ArrayResize(m_elements, 0);
        m_is_initialized = false;
        
        if(CSettingsService::LogLevel >= 2) // INFO
            Print("🧹 Dashboard UI Service cleaned up");
    }
    
    //+------------------------------------------------------------------+
    //| Static Cleanup                                                  |
    //+------------------------------------------------------------------+
    static void CleanupStatic()
    {
        if(m_instance != NULL)
        {
            m_instance.Cleanup();
            delete m_instance;
            m_instance = NULL;
        }
    }
};

// Static member definition
CDashboardUIService* CDashboardUIService::m_instance = NULL;

//+------------------------------------------------------------------+
