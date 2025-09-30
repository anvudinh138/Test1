//@version=5
strategy("PTG Smart Strategy v1.3.2 – Clean UI", overlay=true, max_bars_back=200,
         default_qty_type=strategy.fixed, default_qty_value=1,
         commission_type=strategy.commission.percent, commission_value=0,
         calc_on_every_tick=true, initial_capital=10000, close_entries_rule="ANY")

// ===== CORE PARAMETERS (SAME AS v1.0.1) =====
pairSelection = input.string("XAU/USD", "Trading Pair", options=["EUR/USD", "XAU/USD"])
isPairEURUSD = pairSelection == "EUR/USD"
isPairXAUUSD = pairSelection == "XAU/USD"

pipSize = isPairEURUSD ? 0.0001 : 0.01
useEMA = input.bool(false, "Lọc trend EMA34/55")
useVWAP = input.bool(false, "Lọc trend VWAP")
lookback = input.int(20, "So sánh trong N nến", minval=10)

// PTG Parameters
pushRangePct = input.float(0.60, "Range ≥ 60% range lớn nhất N nến", step=0.05)
closePct = input.float(0.60, "Close nằm ở 60–100% cực trị", step=0.05)
oppWickPct = input.float(0.40, "Bóng ngược ≤ 40% range", step=0.05)
volHighMult = input.float(1.2, "Vol ≥ 1.2× SMA Vol", step=0.1)

testBars = input.int(5, "Cho phép TEST trong 1–5 nến", minval=1, maxval=10)
pullbackMax = input.float(0.50, "Pullback ≤ 50% range PUSH", step=0.02)
volLowMult = input.float(1.0, "Vol TEST ≤ 1.0× SMA Vol", step=0.05)

entryBufPip = input.float(0.01, "Đệm Entry (pip)", step=0.01)
slBufPip = input.float(0.01, "Đệm SL (pip)", step=0.01)
tpMultiplier = input.float(2.0, "TP multiplier", step=0.5, minval=1.0, maxval=5.0)

// Strategy Settings
riskPercent = input.float(2.0, "Risk per trade (%)", step=0.5, minval=0.5, maxval=10.0)

// ===== SESSION FILTER =====
sessionMode = input.string("Full Time", "📅 Trading Session", options=["Full Time", "London Open", "New York Open", "London/NY Overlap"])

londonOpen = "0700-1600"
newYorkOpen = "1200-2100"
londonNYOverlap = "1200-1600"

// ===== ALERT SETTINGS =====
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

// ===== CORE LOGIC (SAME AS v1.0.1) =====
ema34 = ta.ema(close, 34)
ema55 = ta.ema(close, 55)
vwap = ta.vwap

upOK = (not useEMA or ema34 > ema55) and (not useVWAP or close > vwap)
dnOK = (not useEMA or ema34 < ema55) and (not useVWAP or close < vwap)

rng = high - low
rngHi = ta.highest(rng, lookback)
volMA = ta.sma(volume, lookback)
rngMA = ta.sma(rng, lookback)

closePosHi = (close - low) / math.max(rng, 1e-6)
closePosLo = (high - close) / math.max(rng, 1e-6)
lowWick = (math.min(open, close) - low) / math.max(rng, 1e-6)
upWick = (high - math.max(open, close)) / math.max(rng, 1e-6)

bigRange = rng >= rngHi * pushRangePct
hiVol = volume >= volMA * volHighMult and volume > volume[1]

// Push detection
pushUp = upOK and bigRange and hiVol and closePosHi >= closePct and upWick <= oppWickPct
pushDn = dnOK and bigRange and hiVol and closePosLo >= closePct and lowWick <= oppWickPct

// CLEAN Push visualization
plotshape(pushUp, title="Push Up", style=shape.triangleup, location=location.belowbar, 
          color=color.new(color.yellow, 0), size=size.tiny, text="P↑", textcolor=color.white)
plotshape(pushDn, title="Push Down", style=shape.triangledown, location=location.abovebar, 
          color=color.new(color.orange, 0), size=size.tiny, text="P↓", textcolor=color.white)

// PTG Logic
var bool waitTest = false
var bool longDir = false
var int iPush = na
var float hiPush = na
var float loPush = na
var float rngPush = na

if (pushUp or pushDn)
    waitTest := true
    longDir := pushUp
    iPush := bar_index
    hiPush := high
    loPush := low
    rngPush := rng

win = waitTest and (bar_index - iPush) >= 1 and (bar_index - iPush) <= testBars

pullOKLong = win and longDir and (hiPush - low) <= pullbackMax * rngPush
pullOKShort = win and (not longDir) and (high - loPush) <= pullbackMax * rngPush
lowVol = volume <= volMA * volLowMult
smallRng = rng <= rngMA * 1.2

testLong = pullOKLong and lowVol and smallRng
testShort = pullOKShort and lowVol and smallRng

// CLEAN Test visualization
plotshape(testLong, title="Test Long", style=shape.circle, location=location.belowbar, 
          color=color.new(color.lime, 0), size=size.tiny, text="T", textcolor=color.white)
plotshape(testShort, title="Test Short", style=shape.circle, location=location.abovebar, 
          color=color.new(color.red, 0), size=size.tiny, text="T", textcolor=color.white)

var float testHi = na
var float testLo = na
if testLong
    testHi := high
    testLo := low
if testShort
    testHi := high
    testLo := low

useHi = na(testHi) ? hiPush : testHi
useLo = na(testLo) ? loPush : testLo

buf = entryBufPip * pipSize
slBuf = slBufPip * pipSize

longEntry = useHi + buf
shortEntry = useLo - buf

// ENTRY SIGNALS
goLong = testLong and inTradingSession
goShort = testShort and inTradingSession

slLong = (na(testLo) ? loPush : testLo) - slBuf
slShort = (na(testHi) ? hiPush : testHi) + slBuf

tp1L = longEntry + pipSize * tpMultiplier
tp1S = shortEntry - pipSize * tpMultiplier

// Position sizing
getLotSize(entryPrice, stopPrice) =>
    riskAmount = strategy.equity * riskPercent / 100
    pipRisk = math.abs(entryPrice - stopPrice) / pipSize
    if pipRisk > 0
        lotSize = riskAmount / (pipRisk * (isPairEURUSD ? 1.0 : 10.0))
        math.max(0.01, math.min(lotSize, 10.0))
    else
        1.0

// Track entry prices and exits
var float lastLongEntry = na
var float lastShortEntry = na
var bool justExitedLong = false
var bool justExitedShort = false
var float exitPrice = na
var string exitReason = ""
var float entryPriceForExit = na
var float profitLoss = na

// Reset exit flags
justExitedLong := false
justExitedShort := false

// Store entry prices
if goLong
    lastLongEntry := longEntry
if goShort
    lastShortEntry := shortEntry

// STRATEGY EXECUTION - Prevent multiple same-direction entries
if goLong and strategy.position_size <= 0  // Only enter Long if not already Long
    qty = getLotSize(longEntry, slLong)
    strategy.entry("Long", strategy.long, qty=qty, comment="PTG Long v1.3.2")
    strategy.exit("Long Exit", "Long", limit=tp1L, stop=slLong, comment="Long Exit")

if goShort and strategy.position_size >= 0  // Only enter Short if not already Short
    qty = getLotSize(shortEntry, slShort)
    strategy.entry("Short", strategy.short, qty=qty, comment="PTG Short v1.3.2")
    strategy.exit("Short Exit", "Short", limit=tp1S, stop=slShort, comment="Short Exit")

// Detect exits with guaranteed P&L calculation
if strategy.position_size[1] > 0 and strategy.position_size == 0
    justExitedLong := true
    exitPrice := close
    if strategy.closedtrades > 0
        lastProfit = strategy.closedtrades.profit(strategy.closedtrades - 1)
        exitReason := lastProfit > 0 ? "TP" : "SL"
        entryPriceForExit := strategy.closedtrades.entry_price(strategy.closedtrades - 1)
        profitLoss := (exitPrice - entryPriceForExit) / pipSize
    else if not na(lastLongEntry)
        // Fallback to manual tracking
        entryPriceForExit := lastLongEntry
        profitLoss := (exitPrice - entryPriceForExit) / pipSize
        exitReason := "EXIT"
    else
        // Always show something
        profitLoss := 0
        exitReason := "EXIT"

if strategy.position_size[1] < 0 and strategy.position_size == 0
    justExitedShort := true
    exitPrice := close
    if strategy.closedtrades > 0
        lastProfit = strategy.closedtrades.profit(strategy.closedtrades - 1)
        exitReason := lastProfit > 0 ? "TP" : "SL"
        entryPriceForExit := strategy.closedtrades.entry_price(strategy.closedtrades - 1)
        profitLoss := (entryPriceForExit - exitPrice) / pipSize
    else if not na(lastShortEntry)
        // Fallback to manual tracking
        entryPriceForExit := lastShortEntry
        profitLoss := (entryPriceForExit - exitPrice) / pipSize
        exitReason := "EXIT"
    else
        // Always show something
        profitLoss := 0
        exitReason := "EXIT"

// ===== CLEAN VISUALIZATION =====
// Entry signals
plotshape(goLong, title="BUY Signal", style=shape.labelup, location=location.belowbar, 
          color=color.new(color.lime, 0), text="B", textcolor=color.white, size=size.small)
plotshape(goShort, title="SELL Signal", style=shape.labeldown, location=location.abovebar, 
          color=color.new(color.red, 0), text="S", textcolor=color.white, size=size.small)

// Exit dots at exact price
plot(justExitedLong and exitReason == "TP" ? exitPrice : na, title="Long TP Dot", 
     style=plot.style_circles, color=color.green, linewidth=4)
plot(justExitedLong and exitReason == "SL" ? exitPrice : na, title="Long SL Dot", 
     style=plot.style_circles, color=color.red, linewidth=4)
plot(justExitedShort and exitReason == "TP" ? exitPrice : na, title="Short TP Dot", 
     style=plot.style_circles, color=color.green, linewidth=4)
plot(justExitedShort and exitReason == "SL" ? exitPrice : na, title="Short SL Dot", 
     style=plot.style_circles, color=color.red, linewidth=4)

// Always show P&L labels when position exits
if justExitedLong
    var string exitText = ""
    var color labelColor = color.orange
    
    if not na(profitLoss) and profitLoss != 0
        profitSign = profitLoss >= 0 ? "+" : ""
        exitText := "LONG " + exitReason + " " + profitSign + str.tostring(profitLoss, "#.#") + "p"
        labelColor := profitLoss >= 0 ? color.green : color.red
    else
        exitText := "LONG " + exitReason
        labelColor := color.orange
    
    label.new(bar_index, high + (high * 0.001), exitText, 
              style=label.style_label_down, 
              color=labelColor, 
              textcolor=color.white, size=size.small)

if justExitedShort
    var string exitText = ""
    var color labelColor = color.orange
    
    if not na(profitLoss) and profitLoss != 0
        profitSign = profitLoss >= 0 ? "+" : ""
        exitText := "SHORT " + exitReason + " " + profitSign + str.tostring(profitLoss, "#.#") + "p"
        labelColor := profitLoss >= 0 ? color.green : color.red
    else
        exitText := "SHORT " + exitReason
        labelColor := color.orange
    
    label.new(bar_index, low - (low * 0.001), exitText, 
              style=label.style_label_up, 
              color=labelColor, 
              textcolor=color.white, size=size.small)

// Clean SL/TP lines - DISAPPEAR immediately when position closes
hasPosition = strategy.position_size != 0
plot(hasPosition and strategy.position_size > 0 and not justExitedLong ? slLong : na, title="SL Long", 
     style=plot.style_linebr, color=color.red, linewidth=1)
plot(hasPosition and strategy.position_size < 0 and not justExitedShort ? slShort : na, title="SL Short", 
     style=plot.style_linebr, color=color.red, linewidth=1)
plot(hasPosition and strategy.position_size > 0 and not justExitedLong ? tp1L : na, title="TP Long", 
     style=plot.style_linebr, color=color.green, linewidth=1)
plot(hasPosition and strategy.position_size < 0 and not justExitedShort ? tp1S : na, title="TP Short", 
     style=plot.style_linebr, color=color.green, linewidth=1)

// EMA and VWAP with clear identification
plot(ema34, title="EMA 34 (Fast Trend)", color=color.blue, linewidth=1)
plot(ema55, title="EMA 55 (Slow Trend)", color=color.red, linewidth=1)
plot(vwap, title="VWAP", color=color.purple, linewidth=1)

// ===== ALERTS =====
longRiskPips = math.abs(longEntry - slLong) / pipSize
shortRiskPips = math.abs(shortEntry - slShort) / pipSize

var int lastAlertBar = 0
var string lastAlertDirection = ""

canAlert(direction) =>
    (bar_index - lastAlertBar) >= 10 or lastAlertDirection != direction

if enableAlerts and goLong and canAlert("LONG")
    sessionInfo = sessionMode != "Full Time" ? " | Session: " + sessionMode : ""
    alert("🚀 PTG LONG - " + pairSelection + " | Entry:" + str.tostring(longEntry, "#.###") + 
          " | SL:" + str.tostring(slLong, "#.###") + " | TP:" + str.tostring(tp1L, "#.###") + 
          " | Risk:" + str.tostring(longRiskPips, "#.#") + "pips" + sessionInfo, alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "LONG"

if enableAlerts and goShort and canAlert("SHORT")
    sessionInfo = sessionMode != "Full Time" ? " | Session: " + sessionMode : ""
    alert("🔻 PTG SHORT - " + pairSelection + " | Entry:" + str.tostring(shortEntry, "#.###") + 
          " | SL:" + str.tostring(slShort, "#.###") + " | TP:" + str.tostring(tp1S, "#.###") + 
          " | Risk:" + str.tostring(shortRiskPips, "#.#") + "pips" + sessionInfo, alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "SHORT"

if enableAlerts and justExitedLong
    exitAlert = "✅ PTG LONG EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.###")
    alert(exitAlert, alert.freq_once_per_bar)

if enableAlerts and justExitedShort
    exitAlert = "✅ PTG SHORT EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.###")
    alert(exitAlert, alert.freq_once_per_bar)

// Reset waitTest
if (goLong or goShort) or (win and (bar_index - iPush) == testBars)
    waitTest := false
    testHi := na
    testLo := na

// ===== REALTIME SIMULATION TABLE =====
// FORCE RESET - Change this number to reset all variables
resetVersion = 2

var float simBalance = na
var int simTrades = na
var int simWins = na
var float simProfit = na
var float simCurrentRisk = 0.0
var string simLastTrade = ""
var int lastResetVersion = na

// Force reset when version changes OR on first bar
needsReset = na(lastResetVersion) or lastResetVersion != resetVersion or barstate.isfirst
if needsReset
    simBalance := 500.0
    simTrades := 0
    simWins := 0
    simProfit := 0.0
    simLastTrade := ""
    lastResetVersion := resetVersion

// Update simulation ONLY for REALTIME trades (not backtest history)
if (justExitedLong or justExitedShort) and barstate.isconfirmed and not barstate.ishistory
    simTrades := simTrades + 1
    if not na(profitLoss)
        pipProfit = profitLoss
        dollarProfit = pipProfit * (isPairEURUSD ? 1.0 : 10.0) * 0.1  // Rough conversion
        simProfit := simProfit + dollarProfit
        simBalance := simBalance + dollarProfit
        if dollarProfit > 0
            simWins := simWins + 1
        simLastTrade := (justExitedLong ? "L" : "S") + (dollarProfit >= 0 ? "+" : "") + str.tostring(dollarProfit, "#.#")

// Calculate current trade risk
if strategy.position_size != 0
    currentRiskPips = strategy.position_size > 0 ? math.abs(strategy.position_avg_price - slLong) / pipSize : math.abs(slShort - strategy.position_avg_price) / pipSize
    simCurrentRisk := currentRiskPips * (isPairEURUSD ? 1.0 : 10.0) * 0.1

var table simTable = table.new(position.bottom_right, 2, 8, bgcolor=color.black, border_width=1)
if barstate.islast
    // Handle na values for display
    displayBalance = na(simBalance) ? 500.0 : simBalance
    displayTrades = na(simTrades) ? 0 : simTrades
    displayWins = na(simWins) ? 0 : simWins
    displayProfit = na(simProfit) ? 0.0 : simProfit
    simWinRate = displayTrades > 0 ? displayWins / displayTrades * 100 : 0
    
    table.cell(simTable, 0, 0, "💰 LIVE ONLY", text_color=color.white, bgcolor=color.green, text_size=size.small)
    table.cell(simTable, 1, 0, "SIM v" + str.tostring(resetVersion), text_color=color.white, bgcolor=color.green, text_size=size.small)
    
    table.cell(simTable, 0, 1, "Balance", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 1, "$" + str.tostring(displayBalance, "#.##"), 
               text_color=displayBalance >= 500 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(simTable, 0, 2, "P&L", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 2, (displayProfit >= 0 ? "+" : "") + "$" + str.tostring(displayProfit, "#.##"),
               text_color=displayProfit >= 0 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(simTable, 0, 3, "Trades", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 3, str.tostring(displayTrades), text_color=color.aqua, text_size=size.tiny)
    
    table.cell(simTable, 0, 4, "Win Rate", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 4, str.tostring(simWinRate, "#.#") + "%",
               text_color=simWinRate >= 50 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(simTable, 0, 5, "Risk Now", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 5, strategy.position_size != 0 ? "$" + str.tostring(simCurrentRisk, "#.#") : "FLAT",
               text_color=strategy.position_size != 0 ? color.orange : color.gray, text_size=size.tiny)
    
    table.cell(simTable, 0, 6, "Long P&L", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 6, strategy.position_size > 0 ? (strategy.openprofit / pipSize >= 0 ? "+" : "") + str.tostring(strategy.openprofit / pipSize, "#.#") + "p" : "FLAT",
               text_color=strategy.position_size > 0 ? (strategy.openprofit >= 0 ? color.green : color.red) : color.gray, text_size=size.tiny)
    
    table.cell(simTable, 0, 7, "Short P&L", text_color=color.white, text_size=size.tiny)
    table.cell(simTable, 1, 7, strategy.position_size < 0 ? (strategy.openprofit / pipSize >= 0 ? "+" : "") + str.tostring(strategy.openprofit / pipSize, "#.#") + "p" : "FLAT",
               text_color=strategy.position_size < 0 ? (strategy.openprofit >= 0 ? color.green : color.red) : color.gray, text_size=size.tiny)

// ===== CLEAN RESULTS TABLE =====
var table resultsTable = table.new(position.top_right, 2, 8, bgcolor=color.white, border_width=1)
if barstate.islast
    winRate = strategy.closedtrades > 0 ? strategy.wintrades / strategy.closedtrades * 100 : 0
    profitFactor = strategy.grossprofit > 0 and strategy.grossloss > 0 ? strategy.grossprofit / strategy.grossloss : 0
    
    table.cell(resultsTable, 0, 0, "PTG v1.3.2", text_color=color.white, bgcolor=color.blue, text_size=size.small)
    table.cell(resultsTable, 1, 0, "CLEAN UI", text_color=color.white, bgcolor=color.blue, text_size=size.small)
    
    table.cell(resultsTable, 0, 1, "Total Trades", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 1, str.tostring(strategy.closedtrades), text_color=color.blue, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 2, "Win Rate", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 2, str.tostring(winRate, "#.#") + "%", 
               text_color=winRate > 50 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 3, "Net P&L", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 3, "$" + str.tostring(strategy.netprofit, "#.##"), 
               text_color=strategy.netprofit > 0 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 4, "Session", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 4, sessionMode, text_color=color.purple, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 5, "In Session", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 5, inTradingSession ? "✅ Active" : "❌ Inactive", 
               text_color=inTradingSession ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 6, "Alerts", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 6, enableAlerts ? "ON" : "OFF", 
               text_color=enableAlerts ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 7, "Version", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 7, "CLEAN", text_color=color.green, text_size=size.tiny)

// Session background
sessionBgColor = color.new(color.yellow, 95)
bgcolor(sessionMode != "Full Time" and inTradingSession ? sessionBgColor : na, title="Session Background")
