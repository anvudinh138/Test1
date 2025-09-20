#!/usr/bin/env python3
"""
Analyze 500 UC Test Results
Compare performance across families and identify best configurations
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

def load_and_analyze_results(results_file):
    """Load backtest results and perform family-wise analysis"""
    
    try:
        df = pd.read_csv(results_file)
        print(f"Loaded {len(df)} test results from {results_file}")
    except FileNotFoundError:
        print(f"Results file {results_file} not found!")
        return None
    
    # Define family ranges
    families = {
        'Family 1 (OB)': (1, 100),
        'Family 2 (FVG)': (101, 200), 
        'Family 3 (Imbalance)': (201, 275),
        'Family 4 (HTF Filter)': (276, 350),
        'Family 5 (Risk/Entry)': (351, 500)
    }
    
    # Add family column
    df['Family'] = df['PresetID'].apply(lambda x: get_family_name(x, families))
    
    return df, families

def get_family_name(preset_id, families):
    """Get family name for a preset ID"""
    for family, (start, end) in families.items():
        if start <= preset_id <= end:
            return family
    return 'Unknown'

def analyze_by_family(df, families):
    """Analyze performance by family"""
    
    print("\n" + "="*60)
    print("FAMILY-WISE PERFORMANCE ANALYSIS")
    print("="*60)
    
    family_stats = []
    
    for family_name in families.keys():
        family_data = df[df['Family'] == family_name]
        
        if len(family_data) == 0:
            continue
            
        stats = {
            'Family': family_name,
            'Count': len(family_data),
            'Avg_ProfitFactor': family_data['ProfitFactor'].mean(),
            'Avg_WinRate': family_data['WinRate'].mean(),
            'Avg_NetProfit': family_data['NetProfit'].mean(),
            'Avg_MaxDD': family_data['MaxDrawdownPercent'].mean(),
            'Avg_SharpeRatio': family_data['SharpeRatio'].mean(),
            'Avg_TotalTrades': family_data['TotalTrades'].mean(),
            'Best_ProfitFactor': family_data['ProfitFactor'].max(),
            'Best_PresetID': family_data.loc[family_data['ProfitFactor'].idxmax(), 'PresetID']
        }
        
        family_stats.append(stats)
        
        print(f"\n{family_name}:")
        print(f"  Count: {stats['Count']}")
        print(f"  Avg Profit Factor: {stats['Avg_ProfitFactor']:.2f}")
        print(f"  Avg Win Rate: {stats['Avg_WinRate']:.1f}%")
        print(f"  Avg Net Profit: ${stats['Avg_NetProfit']:.2f}")
        print(f"  Avg Max DD: {stats['Avg_MaxDD']:.1f}%")
        print(f"  Avg Sharpe: {stats['Avg_SharpeRatio']:.2f}")
        print(f"  Avg Trades: {stats['Avg_TotalTrades']:.0f}")
        print(f"  Best PF: {stats['Best_ProfitFactor']:.2f} (UC #{stats['Best_PresetID']})")
    
    return pd.DataFrame(family_stats)

def find_top_performers(df, top_n=20):
    """Find top performing configurations"""
    
    print(f"\n" + "="*60)
    print(f"TOP {top_n} PERFORMERS (by Profit Factor)")
    print("="*60)
    
    # Filter out configs with too few trades or negative profit
    filtered_df = df[
        (df['TotalTrades'] >= 10) & 
        (df['NetProfit'] > 0) &
        (df['ProfitFactor'] > 1.0)
    ].copy()
    
    top_configs = filtered_df.nlargest(top_n, 'ProfitFactor')
    
    for idx, row in top_configs.iterrows():
        print(f"\n#{row['PresetID']} ({row['Family']}):")
        print(f"  Profit Factor: {row['ProfitFactor']:.2f}")
        print(f"  Win Rate: {row['WinRate']:.1f}%")
        print(f"  Net Profit: ${row['NetProfit']:.2f}")
        print(f"  Max DD: {row['MaxDrawdownPercent']:.1f}%")
        print(f"  Sharpe: {row['SharpeRatio']:.2f}")
        print(f"  Total Trades: {row['TotalTrades']}")
        
        # Show key parameters
        if 'POIType' in row:
            poi_type = "Order Block" if row['POIType'] == 1 else "FVG"
            print(f"  POI Type: {poi_type}")
        if 'K_swing' in row:
            print(f"  K_swing: {row['K_swing']}, N_bos: {row['N_bos']}, TP2_R: {row['TP2_R']}")
        if 'UseHTFFilter' in row:
            htf_status = "ON" if row['UseHTFFilter'] else "OFF"
            print(f"  HTF Filter: {htf_status}")
    
    return top_configs

def compare_poi_types(df):
    """Compare Order Block vs FVG performance"""
    
    print(f"\n" + "="*60)
    print("ORDER BLOCK vs FVG COMPARISON")
    print("="*60)
    
    if 'POIType' not in df.columns:
        print("POIType column not found in results")
        return
    
    ob_data = df[df['POIType'] == 1]  # Order Block
    fvg_data = df[df['POIType'] == 0]  # FVG
    
    if len(ob_data) == 0 or len(fvg_data) == 0:
        print("Insufficient data for POI comparison")
        return
    
    comparison = {
        'Metric': ['Count', 'Avg Profit Factor', 'Avg Win Rate', 'Avg Net Profit', 
                  'Avg Max DD', 'Avg Trades', 'Best Profit Factor'],
        'Order Block': [
            len(ob_data),
            ob_data['ProfitFactor'].mean(),
            ob_data['WinRate'].mean(),
            ob_data['NetProfit'].mean(),
            ob_data['MaxDrawdownPercent'].mean(),
            ob_data['TotalTrades'].mean(),
            ob_data['ProfitFactor'].max()
        ],
        'FVG': [
            len(fvg_data),
            fvg_data['ProfitFactor'].mean(),
            fvg_data['WinRate'].mean(),
            fvg_data['NetProfit'].mean(),
            fvg_data['MaxDrawdownPercent'].mean(),
            fvg_data['TotalTrades'].mean(),
            fvg_data['ProfitFactor'].max()
        ]
    }
    
    comp_df = pd.DataFrame(comparison)
    print(comp_df.to_string(index=False))
    
    # Determine winner
    ob_score = ob_data['ProfitFactor'].mean()
    fvg_score = fvg_data['ProfitFactor'].mean()
    
    winner = "Order Block" if ob_score > fvg_score else "FVG"
    print(f"\n🏆 Winner: {winner} (Avg PF: {max(ob_score, fvg_score):.2f} vs {min(ob_score, fvg_score):.2f})")

def analyze_htf_filter_impact(df):
    """Analyze impact of HTF filter"""
    
    print(f"\n" + "="*60)
    print("HTF FILTER IMPACT ANALYSIS")
    print("="*60)
    
    if 'UseHTFFilter' not in df.columns:
        print("UseHTFFilter column not found in results")
        return
    
    htf_on = df[df['UseHTFFilter'] == True]
    htf_off = df[df['UseHTFFilter'] == False]
    
    if len(htf_on) == 0 or len(htf_off) == 0:
        print("Insufficient data for HTF filter comparison")
        return
    
    print(f"HTF Filter ON  - Count: {len(htf_on)}, Avg PF: {htf_on['ProfitFactor'].mean():.2f}, Avg WR: {htf_on['WinRate'].mean():.1f}%")
    print(f"HTF Filter OFF - Count: {len(htf_off)}, Avg PF: {htf_off['ProfitFactor'].mean():.2f}, Avg WR: {htf_off['WinRate'].mean():.1f}%")
    
    # Trade frequency impact
    print(f"Avg Trades with HTF ON: {htf_on['TotalTrades'].mean():.0f}")
    print(f"Avg Trades with HTF OFF: {htf_off['TotalTrades'].mean():.0f}")
    
    trade_reduction = (1 - htf_on['TotalTrades'].mean() / htf_off['TotalTrades'].mean()) * 100
    print(f"Trade Reduction: {trade_reduction:.1f}%")

def generate_summary_report(df, family_stats, top_configs):
    """Generate final summary report"""
    
    print(f"\n" + "="*60)
    print("FINAL SUMMARY & RECOMMENDATIONS")
    print("="*60)
    
    # Overall statistics
    total_configs = len(df)
    profitable_configs = len(df[df['NetProfit'] > 0])
    profitable_pct = (profitable_configs / total_configs) * 100
    
    print(f"Total Configurations Tested: {total_configs}")
    print(f"Profitable Configurations: {profitable_configs} ({profitable_pct:.1f}%)")
    print(f"Average Profit Factor: {df['ProfitFactor'].mean():.2f}")
    print(f"Average Win Rate: {df['WinRate'].mean():.1f}%")
    
    # Best overall configuration
    best_config = df.loc[df['ProfitFactor'].idxmax()]
    print(f"\n🥇 BEST OVERALL CONFIGURATION:")
    print(f"   PresetID: {best_config['PresetID']} ({best_config['Family']})")
    print(f"   Profit Factor: {best_config['ProfitFactor']:.2f}")
    print(f"   Win Rate: {best_config['WinRate']:.1f}%")
    print(f"   Net Profit: ${best_config['NetProfit']:.2f}")
    print(f"   Max Drawdown: {best_config['MaxDrawdownPercent']:.1f}%")
    
    # Family rankings
    print(f"\n📊 FAMILY RANKINGS (by Avg Profit Factor):")
    family_ranking = family_stats.sort_values('Avg_ProfitFactor', ascending=False)
    for idx, row in family_ranking.iterrows():
        print(f"   {idx+1}. {row['Family']}: {row['Avg_ProfitFactor']:.2f}")
    
    # Recommendations
    print(f"\n💡 RECOMMENDATIONS:")
    
    # Best family
    best_family = family_ranking.iloc[0]['Family']
    print(f"   1. Focus on {best_family} configurations")
    
    # POI type recommendation
    if 'POIType' in df.columns:
        ob_avg = df[df['POIType'] == 1]['ProfitFactor'].mean()
        fvg_avg = df[df['POIType'] == 0]['ProfitFactor'].mean()
        best_poi = "Order Block" if ob_avg > fvg_avg else "FVG"
        print(f"   2. Use {best_poi} as primary POI type")
    
    # Risk level recommendation
    if 'RiskPerTradePct' in df.columns:
        risk_performance = df.groupby('RiskPerTradePct')['ProfitFactor'].mean().sort_values(ascending=False)
        best_risk = risk_performance.index[0]
        print(f"   3. Optimal risk per trade: {best_risk}%")
    
    print(f"\n   4. Consider combining best elements from top 5 configurations")
    print(f"   5. Test top configurations on different timeframes")
    print(f"   6. Implement proper position sizing for live trading")

def main():
    """Main analysis function"""
    
    # File paths - adjust as needed
    results_file = "/Users/anvudinh/Desktop/hoiio/trading/XAU_EA_2/OptimizationResults.csv"
    
    print("🔍 SYSTEMATIC EA TESTING ANALYSIS")
    print("="*60)
    
    # Load results
    result = load_and_analyze_results(results_file)
    if result is None:
        print("❌ Could not load results file. Make sure to run backtests first!")
        print(f"Expected file: {results_file}")
        return
    
    df, families = result
    
    # Perform analyses
    family_stats = analyze_by_family(df, families)
    top_configs = find_top_performers(df, top_n=10)
    compare_poi_types(df)
    analyze_htf_filter_impact(df)
    generate_summary_report(df, family_stats, top_configs)
    
    # Save detailed results
    output_file = "/Users/anvudinh/Desktop/hoiio/trading/XAU_EA_2/analysis_summary.csv"
    top_configs.to_csv(output_file, index=False)
    print(f"\n💾 Detailed results saved to: {output_file}")

if __name__ == "__main__":
    main()
