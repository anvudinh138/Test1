You are an expert MQL5 programmer. Your task is to create a complete Expert Advisor (EA) for MetaTrader 5 named "FVG_Fibonacci_Scaler.mq5". The EA must strictly follow all the rules detailed below.

### Input Parameters:

in_fixed_lot: double (default = 0.02) - Total lot size for the entire setup.

in_magic_number: int (default = 112233)

in_fvg_min_atr_factor: double (default = 0.3) - Minimum FVG size as a factor of ATR(14).

in_swing_bars: int (default = 24) - Bars to detect a swing high/low.

in_trailing_stop_atr_factor: double (default = 1.5) - Trailing stop distance in ATR(14) units.

### Core Logic (executed on every new bar):

1.  Swing & Fibonacci Identification:
* Identify the most recent valid swing high and swing low using the last in_swing_bars. A valid swing must form a clear impulse leg.
* Upon detection, draw a Fibonacci Retracement from the swing start to the swing end.

2.  Fair Value Gap (FVG) Detection:
* An FVG is the gap between the high of candle 1 and the low of candle 3 (for a bullish FVG) and vice-versa.
* Scan for all valid FVGs within the Fibonacci retracement area.
* A valid FVG's size in points must be greater than ATR(14) * in_fvg_min_atr_factor.

3.  Discount/Premium Filter & Entry Zone Selection:
* For Buy setups, only consider FVGs that are within the Discount Zone (below the 50% Fibonacci level).
* For Sell setups, only consider FVGs within the Premium Zone (above the 50% Fibonacci level).
* Automated Range Selection Logic:
* Standard Scenario: If 1-2 FVGs are found in the zone, select Fibonacci Range 3 (0.5-0.618) for the first entry (E1) and Range 4 (0.618-0.786) for the second entry (E2).
* High-Confluence Scenario: If 3+ FVGs are found OR a clear Equal High/Low liquidity pool exists beyond the 100% level, select Range 4 for E1 and Range 5 (0.786-1.0) for E2.

4.  Tiered Entry Execution:
* The total lot size is split 50/50 for two entries (in_fixed_lot / 2).
* Place a Limit Order for E1 at the price level of the FVG within the first selected range.
* Only if E1 is filled, place a new Limit Order for E2 at the price level of the FVG in the second selected range.

5.  Trade Management:
* Stop Loss: Place a single Stop Loss for all open positions of this setup slightly beyond the 100% Fibonacci level.
* Partial Take Profit: The Take Profit level for the partial close (TP1) is the 0% Fibonacci level. When hit, close 50% of the total open volume for this setup.
* Trailing Stop: After TP1 is executed, activate a Trailing Stop on the remaining position. The trail distance should be ATR(14) * in_trailing_stop_atr_factor.

### Additional Requirements:

The EA should not open a new setup if there is already an active trade (pending or open) managed by this EA.

Use clean, well-commented code.

Ensure proper use of the Magic Number for all trade operations.