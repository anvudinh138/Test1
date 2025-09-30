# AI Analysis Prompt Template for PTG Trading Strategy

## 📋 How to Use This Template

1. **Copy the prompt below** và paste vào AI khác (Claude, ChatGPT, etc.)
2. **Replace [SPECIFIC_ISSUE]** với vấn đề cụ thể bạn muốn analyze
3. **Attach relevant files** (log files, backtest results, etc.)  
4. **Get analysis** từ AI khác
5. **Forward analysis** cho coding AI để implement

---

## 🎯 Universal AI Analysis Prompt

```
# PTG Trading Strategy Analysis Request

## Project Context

I'm developing a **PTG (Push-Test-Go) trading strategy** for **Gold XAUUSD M1** in MetaTrader 5. This is a breakout strategy that identifies high-probability entries through volume and price action analysis.

### Current Status
- **Version**: PTG_REAL_TICK_FINAL v2.2.0  
- **Environment**: MT5 "Every tick based on real ticks"
- **Results**: 622 trades, 20.90% win rate, -5,016 USD net profit
- **Average Win**: 22.15 pips | Average Loss: -16.05 pips
- **Risk Management**: 25 pips fixed SL, 15 pips BE, 22 pips partial TP

### Core Strategy Logic
**PUSH**: Detect momentum candle with:
- Range ≥ 35% above average
- Volume ≥ 120% above average  
- Close position ≥ 45% of range
- Opposite wick ≤ 55% of range

**TEST**: Wait for pullback within 10 bars:
- Pullback ≤ 85% of push range
- Lower volume during test phase

**GO**: Execute market order when price breaks test range:
- Fixed 25 pip stop loss
- Dynamic spread-based entry buffer
- Breakeven at +15 pips, partial TP at +22 pips

### Technical Specifications
- **Symbol**: XAUUSD (Gold pip = 0.01)
- **Spread Filter**: Skip when spread > 12 pips
- **Position Management**: Spread-buffered breakeven to prevent false triggers
- **Order Type**: Market orders (STOP-LIMIT failed due to minimum distance)
- **Risk Control**: Max 35 pips risk per trade

### Key Problem Solved
Successfully adapted strategy from "Every tick" (synthetic) to "Every tick based on real ticks":
- Fixed dynamic spread handling
- Resolved order execution failures  
- Implemented proper position management for real market conditions
- Achieved 622 trades execution vs 0 in broken versions

## Current Issue to Analyze
**[REPLACE WITH SPECIFIC ISSUE]**

Examples:
- Win rate optimization: 20.90% → 35%+ target
- False signal reduction analysis
- Entry timing optimization  
- Risk-reward ratio improvement
- Multi-timeframe confirmation integration
- Volatility-based position sizing

## Analysis Request

Please analyze the provided data and give me:

### 1. Problem Identification
- What specific factors are causing the current issue?
- Are there patterns in losing vs winning trades?
- What market conditions affect performance?

### 2. Technical Analysis
- Statistical analysis of the results
- Performance breakdown by time/market conditions
- Risk-reward optimization opportunities

### 3. Concrete Recommendations  
- Specific parameter adjustments with reasoning
- New logic/filters to implement
- Code modifications needed (high-level)

### 4. Implementation Roadmap
- Priority order of changes
- Expected impact of each change
- Testing methodology

### 5. Alternative Approaches
- If main approach has limits, suggest alternatives
- Different strategy variations to consider

## Output Format Requested

Please structure your analysis as:

```markdown
# PTG Strategy Analysis: [Issue Name]

## 🔍 Problem Analysis
[Detailed analysis of current issue]

## 📊 Data Insights  
[Key findings from data analysis]

## 🎯 Recommendations
### High Priority (Implement First)
1. [Specific change with reasoning]
2. [Parameters to adjust]

### Medium Priority  
1. [Secondary optimizations]
2. [Additional filters/logic]

### Low Priority (Future Enhancements)
1. [Long-term improvements]

## 💻 Implementation Guide
### Code Changes Needed
- [Specific functions/parameters to modify]
- [New logic to add]
- [Testing approach]

### Expected Results
- [Projected win rate improvement]
- [Risk reduction expectations]
- [Performance metrics targets]

## ⚠️ Risks & Considerations
[Potential downsides and mitigation strategies]

## 📈 Success Metrics
[How to measure if changes are successful]
```

## Additional Context

### Files Available for Analysis
- `PTG_REAL_TICK_FINAL.mq5`: Current EA code
- `log.txt`: Backtest results and trade logs
- `PTG_PROJECT_README.md`: Complete project documentation
- Backtest reports: Trade statistics and performance data

### Technical Constraints
- Must maintain real tick compatibility
- Gold-specific optimizations required  
- Risk per trade must stay controlled (≤35 pips)
- Execution speed critical for M1 scalping
- Spread filter essential for cost control

### Success Targets
- **Win Rate**: 35%+ (currently 20.90%)
- **Profit Factor**: 1.2+ (currently 0.36)
- **Drawdown**: <20% (currently manageable)
- **Trade Frequency**: 500+ trades per month maintained
- **Stability**: Consistent performance across different market conditions

Please provide detailed analysis focusing on [SPECIFIC_ISSUE] with concrete, implementable recommendations.
```

---

## 📝 Example Usage Scenarios

### Scenario 1: Win Rate Optimization
Replace `[SPECIFIC_ISSUE]` with:
```
"Win rate optimization: Current 20.90% win rate needs improvement to 35%+. 
Analyze losing trades patterns, signal quality, and entry timing optimization."
```

### Scenario 2: False Signal Reduction  
Replace `[SPECIFIC_ISSUE]` with:
```
"False signal reduction: Strategy generates good R:R (22p avg win vs 16p avg loss) 
but too many losing trades. Need filters to reduce false PUSH signals."
```

### Scenario 3: Risk Management Enhancement
Replace `[SPECIFIC_ISSUE]` with:
```  
"Risk management optimization: Fixed 25p SL works but consider dynamic 
sizing based on volatility. Analyze optimal SL distance vs market conditions."
```

---

## 🔄 Workflow Process

1. **Use AI Analysis** → Get detailed recommendations
2. **Forward to Coding AI** → "Here's professional analysis of my PTG strategy. Please implement these specific recommendations: [paste analysis]"
3. **Implement & Test** → Apply code changes
4. **Measure Results** → Compare performance metrics
5. **Iterate** → Use template again for next optimization

---

## 💡 Tips for Better Analysis

### Provide Comprehensive Data
- Include recent backtest reports
- Share log files with trade details
- Provide market condition context (news events, volatility periods)

### Ask Specific Questions
- Instead of "improve strategy" → "reduce false breakouts during low volatility"  
- Instead of "optimize parameters" → "find optimal BreakevenPips for Gold M1"

### Request Actionable Output
- Ask for specific parameter values, not just general advice
- Request code snippets or logic changes
- Want concrete testing methodology

This template ensures you get maximum value from AI analysis while minimizing costs! 🎯
