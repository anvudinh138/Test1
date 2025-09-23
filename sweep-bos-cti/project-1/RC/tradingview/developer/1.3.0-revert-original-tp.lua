//@version=5
strategy("PTG Smart Strategy v1.3.0 – Revert Original TP", overlay=true, max_bars_back=200,
         default_qty_type=strategy.fixed, default_qty_value=1,
         commission_type=strategy.commission.percent, commission_value=0,
         calc_on_every_tick=true, initial_capital=10000, close_entries_rule="ANY")

// ===== CORE PARAMETERS (Original Settings) =====
rangeMin = input.float(0.35, "Min Range (pip)", step=0.05)
rangeMax = input.float(4.0, "Max Range (pip)", step=0.1)
rangeSizeMultiplier = input.float(1.0, "Range Size Multiplier", step=0.1, minval=0.5, maxval=3.0)

wickLongPct = input.float(60.0, "Wick LONG ≤ %", step=5.0) / 100
wickShortPct = input.float(60.0, "Wick SHORT ≤ %", step=5.0) / 100
oppWickPct = input.float(40.0, "Opposite Wick ≤ %", step=5.0) / 100
closePct = input.float(60.0, "Close Position ≥ %", step=5.0) / 100

volHighMult = input.float(1.5, "Vol PUSH ≥ 1.5× SMA Vol", step=0.05)
volLowMult = input.float(1.0, "Vol TEST ≤ 1.0× SMA Vol", step=0.05)

entryBufPip = input.float(0.01, "Đệm Entry (pip)", step=0.01)
slBufPip = input.float(0.01, "Đệm SL (pip)", step=0.01)

// ===== ORIGINAL TP SETTINGS (REVERTED) =====
tp1Multiplier = input.float(1.0, "TP1 Multiplier", step=0.1, minval=0.5, maxval=3.0)
tp2Multiplier = input.float(2.0, "TP2 Multiplier", step=0.1, minval=1.0, maxval=5.0)

// Strategy Settings
riskPercent = input.float(2.0, "Risk per trade (%)", step=0.5, minval=0.5, maxval=10.0)

// ===== SESSION FILTER =====
sessionMode = input.string("Full Time", "📅 Trading Session", options=["Full Time", "London Open", "New York Open", "London/NY Overlap"])

londonOpen = "0700-1600"
newYorkOpen = "1200-2100"
londonNYOverlap = "1200-1600"

// ===== FIXED ALERT SETTINGS (from v1.0.1) =====
enableAlerts = input.bool(true, "Enable Alerts")
alertMode = input.string("Entry Only", "🔔 Alert Mode", options=["Entry Only", "Entry + Push", "All Signals"])

// ===== SESSION LOGIC =====
getSessionFilter() =>
    switch sessionMode
        "Full Time" => true
        "London Open" => bool(time(timeframe.period, londonOpen))
        "New York Open" => bool(time(timeframe.period, newYorkOpen))
        "London/NY Overlap" => bool(time(timeframe.period, londonNYOverlap))
        => true

inTradingSession = getSessionFilter()

// ===== CORE LOGIC =====
ema34 = ta.ema(close, 34)
ema55 = ta.ema(close, 55)
vwap = ta.vwap

trendUp = ema34 > ema55 and close > vwap
trendDn = ema34 < ema55 and close < vwap

volMA = ta.sma(volume, 20)
hiVol = volume >= volMA * volHighMult and volume > volume[1]
loVol = volume <= volMA * volLowMult

pipSize = syminfo.mintick * 10

// Range calculation
bodySize = math.abs(close - open)
totalRange = high - low
bodySizeInPips = bodySize / pipSize
totalRangeInPips = totalRange / pipSize

validRange = totalRangeInPips >= rangeMin and totalRangeInPips <= rangeMax
bigRange = bodySize >= totalRange * 0.4 * rangeSizeMultiplier

// Wick calculations
upperWick = high - math.max(open, close)
lowerWick = math.min(open, close) - low
upperWickPct = upperWick / totalRange
lowerWickPct = lowerWick / totalRange

// Position calculations
closePosHi = (close - low) / totalRange
closePosDn = (high - close) / totalRange

// PUSH detection
upOK = trendUp and close > open
pushUp = inTradingSession and upOK and bigRange and hiVol and closePosHi >= closePct and upperWickPct <= oppWickPct

dnOK = trendDn and close < open
pushDn = inTradingSession and dnOK and bigRange and hiVol and closePosDn >= closePct and lowerWickPct <= oppWickPct

// TEST detection
testUp = close < open and validRange and loVol and lowerWickPct <= wickLongPct
testDn = close > open and validRange and loVol and upperWickPct <= wickShortPct

// GO signals
var bool waitingLong = false
var bool waitingShort = false
var float entryLevelLong = na
var float entryLevelShort = na

if pushUp
    waitingLong := true
    waitingShort := false
    entryLevelLong := high + entryBufPip
    entryLevelShort := na

if pushDn
    waitingShort := true
    waitingLong := false
    entryLevelShort := low - entryBufPip
    entryLevelLong := na

testLong = waitingLong and testUp
testShort = waitingShort and testDn

goLong = testLong and inTradingSession and high >= entryLevelLong
goShort = testShort and inTradingSession and low <= entryLevelShort

// ===== ORIGINAL TP LOGIC (REVERTED) =====
longEntry = entryLevelLong
shortEntry = entryLevelShort

// Stop Loss
slLong = waitingLong ? low[1] - slBufPip : na
slShort = waitingShort ? high[1] + slBufPip : na

// ORIGINAL Take Profit Logic
longRange = longEntry - slLong
shortRange = slShort - shortEntry

tp1L = longEntry + (longRange * tp1Multiplier)
tp2L = longEntry + (longRange * tp2Multiplier)
tp1S = shortEntry - (shortRange * tp1Multiplier)
tp2S = shortEntry - (shortRange * tp2Multiplier)

// Position sizing
getLotSize(entryPrice, slPrice) =>
    riskAmount = strategy.equity * (riskPercent / 100)
    slDistance = math.abs(entryPrice - slPrice)
    slDistanceInPips = slDistance / pipSize
    lotSize = riskAmount / slDistanceInPips
    math.max(lotSize, 0.01)

// ===== ANTI-SPAM ALERT LOGIC =====
var int lastAlertBar = -1
var string lastAlertDirection = ""

canAlert(direction) =>
    (bar_index - lastAlertBar) >= 10 or lastAlertDirection != direction

// ===== EXIT DETECTION =====
var bool justExitedLong = false
var bool justExitedShort = false
var string exitReason = ""

// Detect exits
if strategy.position_size[1] > 0 and strategy.position_size <= 0
    justExitedLong := true
    justExitedShort := false
    exitReason := strategy.closedtrades.exit_price(strategy.closedtrades - 1) >= tp1L ? "TP" : "SL"
else if strategy.position_size[1] < 0 and strategy.position_size >= 0
    justExitedShort := true
    justExitedLong := false
    exitReason := strategy.closedtrades.exit_price(strategy.closedtrades - 1) <= tp1S ? "TP" : "SL"
else
    justExitedLong := false
    justExitedShort := false
    exitReason := ""

// ===== STRATEGY EXECUTION =====
if goLong
    qty = getLotSize(longEntry, slLong)
    strategy.entry("Long", strategy.long, qty=qty, comment="PTG Long v1.3.0")
    strategy.exit("Long Exit", "Long", limit=tp1L, stop=slLong, comment="Long Exit")
    
    if enableAlerts and canAlert("long")
        sessionInfo = sessionMode != "Full Time" ? " | Session: " + sessionMode : ""
        alertMessage = "🚀 PTG LONG ENTRY - " + str.tostring(longEntry, "#.####") + 
                      " | SL: " + str.tostring(slLong, "#.####") + 
                      " | TP: " + str.tostring(tp1L, "#.####") + 
                      " | Risk: " + str.tostring(riskPercent, "#.#") + "%" +
                      sessionInfo
        alert(alertMessage, alert.freq_once_per_bar)
        lastAlertBar := bar_index
        lastAlertDirection := "long"
    
    waitingLong := false

if goShort
    qty = getLotSize(shortEntry, slShort)
    strategy.entry("Short", strategy.short, qty=qty, comment="PTG Short v1.3.0")
    strategy.exit("Short Exit", "Short", limit=tp1S, stop=slShort, comment="Short Exit")
    
    if enableAlerts and canAlert("short")
        sessionInfo = sessionMode != "Full Time" ? " | Session: " + sessionMode : ""
        alertMessage = "🔻 PTG SHORT ENTRY - " + str.tostring(shortEntry, "#.####") + 
                      " | SL: " + str.tostring(slShort, "#.####") + 
                      " | TP: " + str.tostring(tp1S, "#.####") + 
                      " | Risk: " + str.tostring(riskPercent, "#.#") + "%" +
                      sessionInfo
        alert(alertMessage, alert.freq_once_per_bar)
        lastAlertBar := bar_index
        lastAlertDirection := "short"
    
    waitingShort := false

// Exit alerts
if justExitedLong and enableAlerts
    exitPrice = strategy.closedtrades.exit_price(strategy.closedtrades - 1)
    exitAlert = "✅ PTG LONG EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.####")
    alert(exitAlert, alert.freq_once_per_bar)

if justExitedShort and enableAlerts
    exitPrice = strategy.closedtrades.exit_price(strategy.closedtrades - 1)
    exitAlert = "✅ PTG SHORT EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.####")
    alert(exitAlert, alert.freq_once_per_bar)

// ===== VISUALIZATION =====
plotshape(pushUp, title="Push Up", style=shape.triangleup, location=location.belowbar, 
          color=color.blue, size=size.small)
plotshape(pushDn, title="Push Down", style=shape.triangledown, location=location.abovebar, 
          color=color.red, size=size.small)

plotshape(testLong, title="Test Long", style=shape.circle, location=location.belowbar, 
          color=color.yellow, size=size.tiny)
plotshape(testShort, title="Test Short", style=shape.circle, location=location.abovebar, 
          color=color.orange, size=size.tiny)

plotshape(goLong, title="GO Long", style=shape.labelup, location=location.belowbar, 
          color=color.green, text="GO-L", textcolor=color.white, size=size.small)
plotshape(goShort, title="GO Short", style=shape.labeldown, location=location.abovebar, 
          color=color.red, text="GO-S", textcolor=color.white, size=size.small)

// Exit visualization with separate plotshapes
plotshape(justExitedLong and exitReason == "TP", title="Long TP Exit", style=shape.labeldown, 
          location=location.abovebar, color=color.new(color.green, 0), text="L-TP", 
          textcolor=color.white, size=size.small)
plotshape(justExitedLong and exitReason == "SL", title="Long SL Exit", style=shape.labeldown, 
          location=location.abovebar, color=color.new(color.red, 0), text="L-SL", 
          textcolor=color.white, size=size.small)
plotshape(justExitedShort and exitReason == "TP", title="Short TP Exit", style=shape.labelup, 
          location=location.belowbar, color=color.new(color.green, 0), text="S-TP", 
          textcolor=color.white, size=size.small)
plotshape(justExitedShort and exitReason == "SL", title="Short SL Exit", style=shape.labelup, 
          location=location.belowbar, color=color.new(color.red, 0), text="S-SL", 
          textcolor=color.white, size=size.small)

// Session background
sessionBgColor = color.new(color.yellow, 95)
bgcolor(sessionMode != "Full Time" and inTradingSession ? sessionBgColor : na, title="Session Background")

// Stop Loss and Take Profit lines
plot(strategy.position_size > 0 ? slLong : na, title="Long SL", color=color.red, style=plot.style_line, linewidth=1)
plot(strategy.position_size > 0 ? tp1L : na, title="Long TP1", color=color.green, style=plot.style_line, linewidth=1)
plot(strategy.position_size < 0 ? slShort : na, title="Short SL", color=color.red, style=plot.style_line, linewidth=1)
plot(strategy.position_size < 0 ? tp1S : na, title="Short TP1", color=color.green, style=plot.style_line, linewidth=1)

// EMA and VWAP
plot(ema34, title="EMA 34", color=color.blue, linewidth=1)
plot(ema55, title="EMA 55", color=color.red, linewidth=1)
plot(vwap, title="VWAP", color=color.purple, linewidth=1)

// Strategy Performance Table
if barstate.islast
    var table infoTable = table.new(position.top_right, 2, 8, bgcolor=color.white, border_width=1)
    
    totalTrades = strategy.closedtrades
    winTrades = 0
    lossTrades = 0
    totalProfit = 0.0
    
    if totalTrades > 0
        for i = 0 to totalTrades - 1
            profit = strategy.closedtrades.profit(i)
            totalProfit := totalProfit + profit
            if profit > 0
                winTrades := winTrades + 1
            else
                lossTrades := lossTrades + 1
    
    winRate = totalTrades > 0 ? (winTrades / totalTrades) * 100 : 0
    profitFactor = lossTrades > 0 ? (winTrades / lossTrades) : na
    
    table.cell(infoTable, 0, 0, "📊 Strategy Stats", text_color=color.black, text_size=size.normal)
    table.cell(infoTable, 1, 0, "PTG v1.3.0 (Original TP)", text_color=color.black, text_size=size.normal)
    
    table.cell(infoTable, 0, 1, "Total Trades:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 1, str.tostring(totalTrades), text_color=color.blue, text_size=size.small)
    
    table.cell(infoTable, 0, 2, "Win Rate:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 2, str.tostring(winRate, "#.##") + "%", 
               text_color=winRate >= 50 ? color.green : color.red, text_size=size.small)
    
    table.cell(infoTable, 0, 3, "Wins/Losses:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 3, str.tostring(winTrades) + "/" + str.tostring(lossTrades), 
               text_color=color.black, text_size=size.small)
    
    table.cell(infoTable, 0, 4, "Net Profit:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 4, str.tostring(totalProfit, "#.##"), 
               text_color=totalProfit >= 0 ? color.green : color.red, text_size=size.small)
    
    table.cell(infoTable, 0, 5, "Session:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 5, sessionMode, text_color=color.purple, text_size=size.small)
    
    table.cell(infoTable, 0, 6, "In Session:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 6, inTradingSession ? "✅ Active" : "❌ Inactive", 
               text_color=inTradingSession ? color.green : color.red, text_size=size.small)
    
    table.cell(infoTable, 0, 7, "TP Logic:", text_color=color.black, text_size=size.small)
    table.cell(infoTable, 1, 7, "Original (Flexible)", text_color=color.orange, text_size=size.small)
