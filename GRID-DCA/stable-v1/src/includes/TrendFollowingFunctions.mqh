//+------------------------------------------------------------------+
//|                                      TrendFollowingFunctions.mqh |
//|                                       FlexGridDCA EA v4.0.0      |
//|                                    Plan B: Trend-Following Grid  |
//+------------------------------------------------------------------+
#property copyright "FlexGridDCA EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| PLAN B: Trend-Following Grid Strategy                           |
//+------------------------------------------------------------------+
void PlaceTrendFollowingGrid()
{
    if(!InpEnableGridTrading) return;
    
    // Get trend direction
    GRID_DIRECTION trend_direction = GetTrendDirection();
    
    if(trend_direction == GRID_DIRECTION_BUY)
    {
        Print("📈 TREND-FOLLOWING: Uptrend detected - Placing BUY grid only");
        g_grid_manager.PlaceDirectionOrders(GRID_DIRECTION_BUY);
    }
    else if(trend_direction == GRID_DIRECTION_SELL)
    {
        Print("📉 TREND-FOLLOWING: Downtrend detected - Placing SELL grid only");
        g_grid_manager.PlaceDirectionOrders(GRID_DIRECTION_SELL);
    }
    else
    {
        // No clear trend - don't place any grid
        Print("🔍 TREND-FOLLOWING: No clear trend - Waiting for direction");
    }
}

//+------------------------------------------------------------------+
//| Get Trend Direction for Plan B                                  |
//+------------------------------------------------------------------+
GRID_DIRECTION GetTrendDirection()
{
    // Get ADX and EMA values
    double adx_buffer[1];
    double ema8_buffer[1];
    double ema21_buffer[1];
    
    if(CopyBuffer(g_adx_handle, 0, 0, 1, adx_buffer) <= 0 ||
       CopyBuffer(g_ema8_handle, 0, 0, 1, ema8_buffer) <= 0 ||
       CopyBuffer(g_ema21_handle, 0, 0, 1, ema21_buffer) <= 0)
    {
        return (GRID_DIRECTION)-1; // Invalid direction
    }
    
    double adx = adx_buffer[0];
    double ema8 = ema8_buffer[0];
    double ema21 = ema21_buffer[0];
    
    // Check if trend is strong enough
    if(adx < InpTrendADXThreshold)
    {
        return (GRID_DIRECTION)-1; // No trend
    }
    
    // Determine trend direction
    if(ema8 > ema21)
    {
        Print("📈 TREND ANALYSIS: EMA8(", DoubleToString(ema8, 5), ") > EMA21(", DoubleToString(ema21, 5), ") + ADX(", DoubleToString(adx, 1), ") = UPTREND");
        return GRID_DIRECTION_BUY;
    }
    else if(ema8 < ema21)
    {
        Print("📉 TREND ANALYSIS: EMA8(", DoubleToString(ema8, 5), ") < EMA21(", DoubleToString(ema21, 5), ") + ADX(", DoubleToString(adx, 1), ") = DOWNTREND");
        return GRID_DIRECTION_SELL;
    }
    
    return (GRID_DIRECTION)-1; // No clear direction
}

// NOTE: Dashboard and helper functions moved to main EA file
// to avoid dependency issues with global variables and services

//+------------------------------------------------------------------+