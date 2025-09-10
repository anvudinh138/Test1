//@version=6
strategy("PTG Smart Strategy v1.0.1 – Fix Alerts & Exits", overlay=true, max_bars_back=200, 
         default_qty_type=strategy.fixed, default_qty_value=1,
         commission_type=strategy.commission.percent, commission_value=0,
         calc_on_every_tick=true, initial_capital=10000, close_entries_rule="ANY")

// ===== VERSION 1.0.1 - FIX ALERT SPAM & EXIT VISUALIZATION =====
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

// ===== FIXED ALERT SETTINGS =====
enableAlerts = input.bool(true, "Enable Alerts")
alertMode = input.string("Entry Only", "🔔 Alert Mode", options=["Entry Only", "Entry + Push", "All Signals"])
// Removed enableInstantAlert to reduce complexity

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

// Push detection - NO SPREAD FILTER (same as original)
pushUp = upOK and bigRange and hiVol and closePosHi >= closePct and upWick <= oppWickPct
pushDn = dnOK and bigRange and hiVol and closePosLo >= closePct and lowWick <= oppWickPct

plotshape(pushUp, title="Push Up", style=shape.triangleup, location=location.belowbar, color=color.new(color.yellow, 0), size=size.tiny, text="P↑", textcolor=color.black)
plotshape(pushDn, title="Push Down", style=shape.triangledown, location=location.abovebar, color=color.new(color.orange, 0), size=size.tiny, text="P↓", textcolor=color.white)

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

plotshape(testLong, title="Test Long", style=shape.circle, location=location.belowbar, color=color.new(color.lime, 0), size=size.tiny, text="T", textcolor=color.black)
plotshape(testShort, title="Test Short", style=shape.circle, location=location.abovebar, color=color.new(color.red, 0), size=size.tiny, text="T", textcolor=color.white)

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
goLong = testLong
goShort = testShort

slLong = (na(testLo) ? loPush : testLo) - slBuf
slShort = (na(testHi) ? hiPush : testHi) + slBuf

tp1L = longEntry + pipSize * tpMultiplier
tp1S = shortEntry - pipSize * tpMultiplier

// ===== STRATEGY EXECUTION WITH BETTER EXIT TRACKING =====
getLotSize(entryPrice, stopPrice) =>
    riskAmount = strategy.equity * riskPercent / 100
    pipRisk = math.abs(entryPrice - stopPrice) / pipSize
    if pipRisk > 0
        lotSize = riskAmount / (pipRisk * (isPairEURUSD ? 1.0 : 10.0))
        math.max(0.01, math.min(lotSize, 10.0))
    else
        1.0

// Track exits for visualization
var bool justExitedLong = false
var bool justExitedShort = false
var float exitPrice = na
var string exitReason = ""

// Reset exit flags
justExitedLong := false
justExitedShort := false

// ===== PREVENT HEDGED POSITIONS - USE STRATEGY.ENTRY WITH FROM_ENTRY =====
if goLong
    qty = getLotSize(longEntry, slLong)
    // strategy.entry will automatically close opposite position
    strategy.entry("Long", strategy.long, qty=qty, comment="PTG Long v1.0.1")
    strategy.exit("Long Exit", "Long", limit=tp1L, stop=slLong, comment="Long Exit")

if goShort
    qty = getLotSize(shortEntry, slShort)
    // strategy.entry will automatically close opposite position
    strategy.entry("Short", strategy.short, qty=qty, comment="PTG Short v1.0.1")
    strategy.exit("Short Exit", "Short", limit=tp1S, stop=slShort, comment="Short Exit")

// Detect exits
if strategy.position_size[1] > 0 and strategy.position_size == 0
    justExitedLong := true
    exitPrice := close
    exitReason := close >= tp1L[1] ? "TP" : "SL"

if strategy.position_size[1] < 0 and strategy.position_size == 0
    justExitedShort := true
    exitPrice := close
    exitReason := close <= tp1S[1] ? "TP" : "SL"

// Visual Signals
plotshape(goLong, title="GO Long", style=shape.labelup, location=location.belowbar, color=color.new(color.lime, 0), text="GO", textcolor=color.black, size=size.tiny)
plotshape(goShort, title="GO Short", style=shape.labeldown, location=location.abovebar, color=color.new(color.red, 0), text="GO", textcolor=color.white, size=size.tiny)

// ===== FIXED EXIT VISUALIZATION =====
// Use separate plotshapes for TP and SL exits
plotshape(justExitedLong and exitReason == "TP", title="Long TP Exit", style=shape.labeldown, location=location.abovebar, color=color.new(color.green, 0), text="L-TP", textcolor=color.white, size=size.small)
plotshape(justExitedLong and exitReason == "SL", title="Long SL Exit", style=shape.labeldown, location=location.abovebar, color=color.new(color.red, 0), text="L-SL", textcolor=color.white, size=size.small)
plotshape(justExitedShort and exitReason == "TP", title="Short TP Exit", style=shape.labelup, location=location.belowbar, color=color.new(color.green, 0), text="S-TP", textcolor=color.white, size=size.small)
plotshape(justExitedShort and exitReason == "SL", title="Short SL Exit", style=shape.labelup, location=location.belowbar, color=color.new(color.red, 0), text="S-SL", textcolor=color.white, size=size.small)

plot(goLong ? slLong : na, title="SL Long", style=plot.style_linebr, color=color.red, linewidth=1)
plot(goShort ? slShort : na, title="SL Short", style=plot.style_linebr, color=color.red, linewidth=1)
plot(goLong ? tp1L : na, title="TP Long", style=plot.style_linebr, color=color.green, linewidth=1)
plot(goShort ? tp1S : na, title="TP Short", style=plot.style_linebr, color=color.green, linewidth=1)

// Calculate risk
longRiskPips = math.abs(longEntry - slLong) / pipSize
shortRiskPips = math.abs(shortEntry - slShort) / pipSize

// ===== FIXED ALERT SYSTEM - NO SPAM =====
var int lastAlertBar = 0
var string lastAlertDirection = ""

// Anti-spam: Only alert if different direction or 10+ bars gap
canAlert(direction) =>
    (bar_index - lastAlertBar) >= 10 or lastAlertDirection != direction

// ===== SINGLE ALERT PER SIGNAL =====
if enableAlerts and goLong and canAlert("LONG")
    alert("🚀 PTG LONG - " + pairSelection + " | Entry:" + str.tostring(longEntry, "#.###") + " | SL:" + str.tostring(slLong, "#.###") + " | TP:" + str.tostring(tp1L, "#.###") + " | Risk:" + str.tostring(longRiskPips, "#.#") + "pips", alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "LONG"

if enableAlerts and goShort and canAlert("SHORT")
    alert("🔻 PTG SHORT - " + pairSelection + " | Entry:" + str.tostring(shortEntry, "#.###") + " | SL:" + str.tostring(slShort, "#.###") + " | TP:" + str.tostring(tp1S, "#.###") + " | Risk:" + str.tostring(shortRiskPips, "#.#") + "pips", alert.freq_once_per_bar)
    lastAlertBar := bar_index
    lastAlertDirection := "SHORT"

// Optional Push alerts (only if enabled)
if enableAlerts and alertMode != "Entry Only"
    if pushUp and canAlert("PUSH_UP")
        alert("📈 PTG PUSH UP - " + pairSelection + " - Watch for test", alert.freq_once_per_bar)
        lastAlertBar := bar_index
        lastAlertDirection := "PUSH_UP"
    
    if pushDn and canAlert("PUSH_DOWN")
        alert("📉 PTG PUSH DOWN - " + pairSelection + " - Watch for test", alert.freq_once_per_bar)
        lastAlertBar := bar_index
        lastAlertDirection := "PUSH_DOWN"

// Exit alerts
if enableAlerts and justExitedLong
    alert("✅ PTG LONG EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.###"), alert.freq_once_per_bar)

if enableAlerts and justExitedShort
    alert("✅ PTG SHORT EXIT - " + exitReason + " at " + str.tostring(exitPrice, "#.###"), alert.freq_once_per_bar)

// Reset waitTest
if (goLong or goShort) or (win and (bar_index - iPush) == testBars)
    waitTest := false
    testHi := na
    testLo := na

// ===== RESULTS TABLE =====
var table resultsTable = table.new(position.top_right, 2, 10, bgcolor=color.white, border_width=1)
if barstate.islast
    winRate = strategy.closedtrades > 0 ? strategy.wintrades / strategy.closedtrades * 100 : 0
    profitFactor = strategy.grossprofit > 0 and strategy.grossloss > 0 ? strategy.grossprofit / strategy.grossloss : 0
    
    table.cell(resultsTable, 0, 0, "PTG v1.0.1", text_color=color.white, bgcolor=color.blue, text_size=size.small)
    table.cell(resultsTable, 1, 0, "FIXED", text_color=color.white, bgcolor=color.blue, text_size=size.small)
    
    table.cell(resultsTable, 0, 1, "Total Trades", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 1, str.tostring(strategy.closedtrades), text_color=color.blue, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 2, "Win Rate", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 2, str.tostring(winRate, "#.#") + "%", text_color=winRate > 50 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 3, "Profit Factor", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 3, str.tostring(profitFactor, "#.##"), text_color=profitFactor > 1 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 4, "Net P&L", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 4, "$" + str.tostring(strategy.netprofit, "#.##"), text_color=strategy.netprofit > 0 ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 5, "Risk/Trade", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 5, str.tostring(riskPercent, "#.#") + "%", text_color=color.orange, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 6, "Alert Mode", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 6, alertMode, text_color=color.purple, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 7, "Alerts", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 7, enableAlerts ? "NO SPAM" : "OFF", text_color=enableAlerts ? color.green : color.red, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 8, "Exits", text_color=color.black, text_size=size.tiny)
    table.cell(resultsTable, 1, 8, "VISIBLE", text_color=color.green, text_size=size.tiny)
    
    table.cell(resultsTable, 0, 9, "Last Alert", text_color=color.black, text_size=size.tiny)
    barsAgo = bar_index - lastAlertBar
    table.cell(resultsTable, 1, 9, barsAgo > 100 ? "None" : str.tostring(barsAgo) + "b ago", text_color=color.purple, text_size=size.tiny)

// Note: v1.0.1 fixes alert spam and adds proper exit visualization
