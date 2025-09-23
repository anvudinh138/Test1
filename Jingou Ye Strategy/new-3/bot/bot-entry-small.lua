InpFastEMA_Period: start 9 step 1 stop 10
InpSlowEMA_Period: start 28 step 1 stop 30     // chậm hơn → lọc bớt nhiễu
InpSlow2EMA_Period: start 50 step 2 stop 56

InpStopLossPoints: start 200 step 25 stop 300
InpTakeProfit1_Points: start 250 step 25 stop 350
InpTakeProfit2_Points: start 600 step 50 stop 800 // RR lớn hơn chút

InpUseTrailingSL: start false step true stop true  // mặc định tắt (giảm đá quét), có thể bật khi tối ưu
InpTrailingStartPoints: start 300 step 50 stop 400
InpTrailingStopPoints: start 150 step 50 stop 200

InpRiskPercent: start 0.1 step 0.1 stop 0.3      // risk thấp

InpUseDailyFilter: start true step false stop true
InpDailyEmaPeriod: start 200 step 10 stop 240

InpUseAdxFilter: start true step false stop true
InpUseDiCrossover: start true step false stop true
InpAdxPeriod: start 22 step 1 stop 30
InpAdxThreshold: start 28 step 1 stop 30         // ngưỡng cao → ít lệnh, winrate cao

InpUseSessionFilter: start true step false stop true
InpTradingStartHour: start 9 step 1 stop 11      // phiên hẹp
InpTradingEndHour: start 19 step 1 stop 21

InpBreakoutLookbackBars: start 12 step 1 stop 15 // lookback cao hơn
InpBreakoutOffsetPoints: start 30 step 10 stop 40// offset cao → ít lệnh nhưng “chắc tay”

InpUseLossLimit: start true step false stop true
