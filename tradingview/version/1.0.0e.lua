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

// Session Filter
sessionMode = input.string("Full Time", "Trading Session", 
    options=["Full Time", "London Open", "New York Open", "London/NY Overlap"])

londonOpen = "0700-1600:1234567"
newYorkOpen = "1300-2200:1234567"  
londonNYOverlap = "1300-1600:1234567"

getSessionFilter() =>
    switch sessionMode
        "Full Time" => true
        "London Open" => bool(time(timeframe.period, londonOpen))
        "New York Open" => bool(time(timeframe.period, newYorkOpen))
        "London/NY Overlap" => bool(time(timeframe.period, londonNYOverlap))
        => true

sessionOK = getSessionFilter()

// ===== CORE LOGIC =====
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
pushUp = upOK and bigRange and hiVol and closePosHi >= closePct and upWick <= oppWickPct and sessionOK
pushDn = dnOK and bigRange and hiVol and closePosLo >= closePct and lowWick <= oppWickPct and sessionOK

plotshape(pushUp, title="Push Up", style=shape.triangleup, location=location.belowbar, 
          color=color.new(color.yellow, 0), size=size.tiny, text="P", textcolor=color.white)
plotshape(pushDn, title="Push Down", style=shape.triangledown, location=location.abovebar, 
          color=color.new(color.orange, 0), size=size.tiny, text="P", textcolor=color.white)

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

goLong = testLong and sessionOK
goShort = testShort and sessionOK

slLong = (na(testLo) ? loPush : testLo) - slBuf
slShort = (na(testHi) ? hiPush : testHi) + slBuf

tp1L = longEntry + (longEntry - slLong) * tpMultiplier
tp1S = shortEntry - (slShort - shortEntry) * tpMultiplier

plotshape(goLong, title="GO Long", style=shape.labelup, location=location.belowbar, 
          color=color.new(color.lime, 0), text="B", textcolor=color.white, size=size.tiny)
plotshape(goShort, title="GO Short", style=shape.labeldown, location=location.abovebar, 
          color=color.new(color.red, 0), text="S", textcolor=color.white, size=size.tiny)

// ===== RISK MANAGEMENT =====
getLotSize(entryPrice, stopPrice) =>
    riskAmount = strategy.equity * riskPercent / 100
    pipRisk = math.abs(entryPrice - stopPrice) / pipSize
    if pipRisk > 0
        lotSize = riskAmount / (pipRisk * (isPairEURUSD ? 1.0 : 10.0))
        math.max(0.01, math.min(lotSize, 10.0))
    else
        1.0

// Track manual entry prices for P&L calculation
var float lastLongEntry = na
var float lastShortEntry = na

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
var bool justExitedLong = false
var bool justExitedShort = false
var string exitReason = ""
var float profitLoss = na
var float exitPrice = na

justExitedLong := false
justExitedShort := false

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
        profitLoss := (exitPrice - lastLongEntry) / pipSize
        exitReason := profitLoss > 0 ? "TP" : "SL"
    else
        exitReason := "EXIT"
        profitLoss := na

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
        profitLoss := (lastShortEntry - exitPrice) / pipSize
        exitReason := profitLoss > 0 ? "TP" : "SL"
    else
        exitReason := "EXIT"
        profitLoss := na

// Exit dots for TP/SL visualization
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

// Reset waitTest
if (goLong or goShort) or (win and (bar_index - iPush) == testBars)
    waitTest := false
    testHi := na
    testLo := na

// ===== ENHANCED ALERT SYSTEM =====
var int lastAlertBar = 0
var string lastAlertDirection = ""

canAlert(direction) =>
    (bar_index - lastAlertBar) >= 3 or lastAlertDirection != direction

longRiskPips = math.abs(longEntry - slLong) / pipSize
shortRiskPips = math.abs(shortEntry - slShort) / pipSize

if goLong and canAlert("LONG")
    alert("🚀 PTG LONG - " + pairSelection + " | Entry:" + str.tostring(longEntry, "#.###") + 
          " | SL:" + str.tostring(slLong, "#.###") + " | TP:" + str.tostring(tp1L, "#.###") + 
          " | Risk:" + str.tostring(longRiskPips, "#.#") + "p", alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "LONG"

if goShort and canAlert("SHORT")
    alert("🔻 PTG SHORT - " + pairSelection + " | Entry:" + str.tostring(shortEntry, "#.###") + 
          " | SL:" + str.tostring(slShort, "#.###") + " | TP:" + str.tostring(tp1S, "#.###") + 
          " | Risk:" + str.tostring(shortRiskPips, "#.#") + "p", alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "SHORT"

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
    
    table.cell(resultsTable, 0, 3, "Profit Factor", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 3, str.tostring(profitFactor, "#.##"),
               text_color=profitFactor > 1 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 4, "Net P&L", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 4, "$" + str.tostring(strategy.netprofit, "#"),
               text_color=strategy.netprofit > 0 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 5, "Session", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 5, sessionMode == "Full Time" ? "24H" : 
               sessionMode == "London Open" ? "LON" :
               sessionMode == "New York Open" ? "NY" : "L+NY",
               text_color=color.orange, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 6, "Alerts", text_color=color.black, text_size=size.tiny)
    barsAgo = bar_index - lastAlertBar
    table.cell(resultsTable, 1, 6, barsAgo > 100 ? "None" : str.tostring(barsAgo) + "b",
               text_color=color.purple, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 7, "Status", text_color=color.black, text_size=size.tiny)
    posStatus = strategy.position_size > 0 ? "LONG" : strategy.position_size < 0 ? "SHORT" : "FLAT"
    table.cell(resultsTable, 1, 7, posStatus,
               text_color=strategy.position_size > 0 ? color.green : 
                         strategy.position_size < 0 ? color.red : color.gray, text_size=size.tiny)
