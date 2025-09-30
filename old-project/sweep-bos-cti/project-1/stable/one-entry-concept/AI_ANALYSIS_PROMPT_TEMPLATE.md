# AI ANALYSIS PROMPT TEMPLATE FOR PTG TRADING SYSTEM

## 🎯 MASTER PROMPT FOR AI ANALYSIS

Use this comprehensive prompt template when working with AI assistants (ChatGPT, Claude, etc.) for PTG trading system analysis and development.

---

## 📋 CONTEXT SETTING PROMPT

```
You are an expert algorithmic trading analyst specializing in MetaTrader 5 (MT5) Expert Advisors (EAs) for Gold (XAUUSD) trading on M1 timeframe. I need your analysis of a Push-Test-Go (PTG) trading strategy that has been systematically developed and tested.

CRITICAL CONTEXT:
- Symbol: XAUUSD (Gold)
- Timeframe: M1 (1-minute charts)
- Platform: MetaTrader 5 with "Every tick based on real ticks" backtesting
- Strategy: PTG (Push-Test-Go) - detect momentum, validate, execute
- Current Status: PTG FINAL ULTIMATE v3.5.0 achieved 67.87% ROI with only 3 trades
- Key Insight: Quality over quantity - fewer, higher-quality trades outperform high-frequency approaches

PROVEN FACTS FROM SYSTEMATIC TESTING:
1. TestCase 6 (Very Strong): 2 trades, 50% win rate, +3,396 USD, max 1 consecutive loss = CHAMPION
2. ChatGPT 3.6.0 approach: 3,061 trades, 1.92% win rate, -2,432 USD = DISASTER
3. High-frequency approaches consistently fail (1-13% win rates)
4. Ultra-selective criteria ensure survivability and profitability
5. Big winner strategy: Allow occasional small losses for massive wins

CURRENT CHAMPION PARAMETERS (TestCase 6):
- PushRangePercent: 0.36 (ultra-strict)
- ClosePercent: 0.46 (very strict) 
- VolHighMultiplier: 1.22 (high volume requirement)
- MaxSpreadPips: 13.0 (tight filter)
- SessionFilter: 8-16 GMT (peak hours only)
- MomentumThresholdPips: 8.0 (high momentum)
- FixedSLPips: 21.0 (tight stop loss)
- Circuit Breaker: 6 losses → 55min cooldown

YOUR ANALYSIS SHOULD:
- Respect the proven "quality over quantity" principle
- Acknowledge that complexity destroys performance
- Focus on survivability (max consecutive losses) as key metric
- Consider Gold-specific characteristics (pip = 0.01, high volatility)
- Understand that fewer trades with higher win rates are superior
```

---

## 🔍 SPECIFIC ANALYSIS PROMPTS

### 1. PERFORMANCE ANALYSIS PROMPT
```
Analyze the following backtest results for PTG FINAL ULTIMATE v3.5.0:

[PASTE BACKTEST RESULTS HERE]

Please provide analysis on:
1. Trade quality assessment (frequency vs profitability)
2. Risk-adjusted returns (Sharpe ratio, profit factor)
3. Survivability metrics (consecutive losses, drawdown)
4. Comparison with industry standards
5. Strengths and potential weaknesses
6. Recommendations for live trading deployment

Focus on the "quality over quantity" principle and explain why 3 trades with 67.87% ROI is superior to 3,061 trades with -48.64% loss.
```

### 2. PARAMETER OPTIMIZATION PROMPT
```
Given the champion TestCase 6 parameters that achieved 2 trades, 50% win rate, +3,396 USD:

Current Parameters:
- PushRangePercent: 0.36
- ClosePercent: 0.46  
- VolHighMultiplier: 1.22
- MaxSpreadPips: 13.0
- MomentumThresholdPips: 8.0

Historical Context:
- 14 different configurations tested systematically
- High-frequency approaches (72-3,061 trades) consistently failed
- Ultra-selective approaches (2-3 trades) succeeded

Question: Should any parameters be adjusted for live trading, or should we maintain the exact champion configuration?

Consider:
1. Market condition changes
2. Broker-specific factors (spreads, execution)
3. Capital scaling requirements
4. Risk tolerance adjustments

Remember: Over-optimization destroyed previous versions. Simplicity and proven results should be prioritized.
```

### 3. RISK MANAGEMENT ANALYSIS PROMPT
```
Evaluate the risk management system of PTG FINAL ULTIMATE v3.5.0:

Current Risk Management:
- Stop Loss: 21 pips (tight protection)
- Breakeven: 26 pips (early protection) 
- Trailing: Start 43 pips, step 21 pips
- Circuit Breaker: 6 losses → 55min cooldown
- Position Size: 0.10 lots fixed
- Max Consecutive Losses: 0 (actual), 1 (historical max)

Results Context:
- 3 trades: 2 small losses (-21p each), 1 massive win (+35,879p)
- Perfect survivability with 0 consecutive losses at completion
- 67.87% ROI with 0.09% maximum drawdown

Analyze:
1. Risk-reward ratio effectiveness
2. Position sizing appropriateness 
3. Circuit breaker necessity and calibration
4. Trailing stop strategy optimization
5. Capital preservation vs profit maximization balance

Provide recommendations while respecting the proven "big winner" approach.
```

### 4. MARKET CONDITION ADAPTATION PROMPT
```
The PTG system was developed and tested during Aug 21 - Sep 10, 2025 period. 

Market Characteristics During Testing:
- Gold volatility: Variable (ATR-based filtering used)
- Spread conditions: 11.2p average (13p max filter)
- Session focus: 8-16 GMT (London/NY overlap)
- Economic events: [SPECIFY IF KNOWN]

Questions for Analysis:
1. How might different market conditions affect performance?
2. Should parameters adapt to changing volatility regimes?
3. Are there seasonal or economic calendar considerations?
4. How to maintain the "ultra-selective" approach across market cycles?
5. What monitoring indicators suggest parameter adjustment needs?

Remember: The system succeeded by being highly selective (3 trades total). Any adaptations should maintain this core principle.
```

### 5. COMPARATIVE ANALYSIS PROMPT
```
Compare and contrast these approaches that were systematically tested:

1. PTG FINAL ULTIMATE v3.5.0: 3 trades, 33.33% win rate, +67.87% ROI
2. ChatGPT 3.6.0 Complex: 3,061 trades, 1.92% win rate, -48.64% ROI  
3. TestCase 1 (Default): 72 trades, 1.39% win rate, +55.54% ROI
4. TestCase 2 (Softer): 204 trades, 0.49% win rate, +44.38% ROI

Analysis Required:
1. Why does trade frequency inversely correlate with performance?
2. What causes the dramatic win rate differences?
3. How does complexity impact trading results?
4. What lessons apply to algorithmic trading in general?
5. Are there any scenarios where high-frequency might be better?

Provide insights that could guide future algorithmic trading development across different strategies and markets.
```

---

## 🛠️ DEVELOPMENT ASSISTANCE PROMPTS

### 6. CODE REVIEW PROMPT
```
Review this MQL5 Expert Advisor code for PTG FINAL ULTIMATE v3.5.0:

[PASTE CODE HERE]

Focus on:
1. Code efficiency and optimization opportunities
2. Risk management implementation correctness
3. Error handling and robustness
4. MT5 best practices compliance
5. Potential bugs or edge cases
6. Documentation and maintainability

The EA achieved 67.87% ROI with 3 trades, so the logic is proven effective. Suggest improvements that maintain this performance while enhancing reliability.

Key Functions to Review:
- IsPushDetected(): Core signal detection
- ExecuteEntry(): Trade execution
- ManagePosition(): Position management
- Circuit breaker implementation
- Risk management functions
```

### 7. ENHANCEMENT SUGGESTION PROMPT
```
Given the success of PTG FINAL ULTIMATE v3.5.0 (67.87% ROI, 3 trades), suggest potential enhancements:

Current Strengths:
- Ultra-selective entry criteria
- Perfect survivability (0 consecutive losses)
- Big winner approach (1 massive win covers losses)
- Simple, focused implementation
- Proven through systematic testing

Constraints:
- Must maintain "quality over quantity" principle
- Cannot increase trade frequency significantly
- Should not add complexity that could destroy performance
- Must preserve the core PTG logic
- Survivability is more important than profit maximization

Potential Enhancement Areas:
1. Dynamic position sizing based on account growth
2. Multi-timeframe confirmation
3. Economic calendar integration
4. Volatility regime detection
5. Broker-specific optimizations

Provide specific, implementable suggestions that align with the proven approach.
```

### 8. TROUBLESHOOTING PROMPT
```
Help diagnose issues with PTG FINAL ULTIMATE v3.5.0 deployment:

Issue Description: [DESCRIBE SPECIFIC PROBLEM]

System Context:
- Expected: 1-2 trades per month maximum
- Expected Win Rate: 30-50%
- Expected: 2 small losses for every 1 big winner
- Normal: Extended periods without trades due to ultra-selective criteria

Common Issues:
1. No trades executing (spread filter, session filter, circuit breaker)
2. Frequent small losses (normal pattern, big winner compensates)
3. Extended periods without signals (expected with ultra-selective approach)

Provide systematic troubleshooting steps while considering that the system is designed for very low frequency, high-quality trades.
```

---

## 🎯 SPECIALIZED ANALYSIS PROMPTS

### 9. GOLD MARKET SPECIFIC ANALYSIS
```
Analyze PTG FINAL ULTIMATE v3.5.0 specifically for Gold (XAUUSD) trading:

Gold-Specific Characteristics:
- Pip value: 0.01 (not 0.0001 like forex)
- High volatility during London/NY sessions
- Sensitive to USD strength, inflation, geopolitical events
- Typical spreads: 10-15 pips during active hours
- Strong trending behavior during news events

PTG System Gold Adaptations:
- 13 pip spread filter (appropriate for Gold)
- 8-16 GMT session filter (captures peak volatility)
- 21 pip stop loss (reasonable for Gold volatility)
- Momentum filter 8 pips (significant for Gold)

Questions:
1. Are the parameters optimally calibrated for Gold characteristics?
2. How does Gold's volatility profile align with the PTG approach?
3. Should economic calendar events be considered?
4. Are there Gold-specific risk factors to address?
5. How does the "big winner" approach suit Gold's trending nature?
```

### 10. LIVE TRADING DEPLOYMENT PROMPT
```
Provide a comprehensive live trading deployment guide for PTG FINAL ULTIMATE v3.5.0:

Proven Backtest Performance:
- 3 trades over ~20 days (Aug 21 - Sep 10)
- 67.87% ROI with 0.09% max drawdown
- Perfect survivability (0 consecutive losses)
- Ultra-selective approach validated

Deployment Considerations:
1. Broker selection criteria (spreads, execution, regulation)
2. VPS requirements and setup
3. Capital requirements and position sizing
4. Monitoring and maintenance procedures
5. Performance expectations and benchmarks
6. Risk management protocols
7. When to stop/restart the system

Create a step-by-step deployment checklist that ensures live performance matches backtest results while managing real-world trading risks.

Include specific recommendations for:
- Minimum account size
- Broker requirements (spread, execution speed)
- Monitoring frequency
- Performance deviation thresholds
- Emergency stop procedures
```

---

## 💡 USAGE INSTRUCTIONS

### How to Use These Prompts:

1. **Start with Context Setting**: Always begin with the master context prompt
2. **Choose Specific Analysis**: Select the most relevant specific prompt for your needs
3. **Customize with Data**: Replace placeholders with actual results/code/issues
4. **Iterate and Refine**: Use follow-up questions to dive deeper
5. **Document Insights**: Save valuable analysis for future reference

### Best Practices:

- **Always emphasize** the proven "quality over quantity" principle
- **Reference the systematic testing** that led to current conclusions
- **Maintain focus** on survivability as the primary metric
- **Avoid complexity** that could destroy proven performance
- **Respect the data** from 14 TestCase configurations

### Expected AI Response Quality:

Good AI responses should:
- ✅ Acknowledge the proven results and methodology
- ✅ Provide specific, actionable insights
- ✅ Maintain focus on survivability and quality
- ✅ Consider Gold-specific trading characteristics
- ✅ Avoid suggesting high-frequency approaches

Poor AI responses might:
- ❌ Ignore the systematic testing results
- ❌ Suggest increasing trade frequency
- ❌ Recommend complex additions
- ❌ Focus only on profit without considering risk
- ❌ Generic advice not specific to PTG/Gold/M1

---

*Template Version: 1.0*  
*Last Updated: September 12, 2025*  
*Compatible with: ChatGPT, Claude, Gemini, and other AI assistants*
