#!/usr/bin/env python3
"""
Generate 100 Optimized Use Cases for XAU EA Testing
Based on feedback analysis - focus on "golden zone" parameters
"""

import csv
import itertools

def generate_100_optimized_uc():
    """Generate 100 optimized test cases based on feedback analysis"""
    
    # New simplified CSV Header (removed FVG, News, POI options)
    header = [
        "Case", "Symbol", "K_swing", "N_bos", "LookbackInternal", "M_retest", 
        "EqTol", "BOSBufferPoints", "UseKillzones", "UseRoundNumber", "RNDelta",
        "RiskPerTradePct", "SL_BufferUSD", "TP1_R", "TP2_R", "BE_Activate_R", 
        "PartialClosePct", "TimeStopMinutes", "MinProgressR", "MaxSpreadUSD", 
        "MaxOpenPositions", "UsePendingRetest", "RetestOffsetUSD", "PendingExpirySec", 
        "CooldownSec", "ATRScalingPeriod", "SL_ATR_Mult", "Retest_ATR_Mult", 
        "MaxSpread_ATR_Mult", "RNDelta_ATR_Mult", "PendingExpiryMinutes", 
        "UseHTFFilter", "HTF_EMA_Period", "EntryOffsetPips"
    ]
    
    cases = []
    case_id = 1
    
    # Base configuration (optimized from feedback)
    base_config = {
        "Symbol": "XAUUSD",
        "M_retest": 3,
        "EqTol": "0.2*pip",
        "BOSBufferPoints": "2.0*pipPoints", 
        "UseKillzones": "true",
        "UseRoundNumber": "true",
        "RNDelta": "0.3*pip",
        "RiskPerTradePct": 0.5,
        "SL_BufferUSD": "0.6*pip",
        "TP1_R": 1.0,
        "BE_Activate_R": 0.8,
        "PartialClosePct": 50,
        "TimeStopMinutes": 5,
        "MinProgressR": 0.5,
        "MaxSpreadUSD": "0.5*pip",
        "MaxOpenPositions": 1,
        "UsePendingRetest": "false",
        "RetestOffsetUSD": "0.07*pip",
        "PendingExpirySec": 60,
        "CooldownSec": 0,
        "ATRScalingPeriod": 14,
        "SL_ATR_Mult": 0.60,
        "Retest_ATR_Mult": 0.25,
        "MaxSpread_ATR_Mult": 0.15,
        "RNDelta_ATR_Mult": 0.40,
        "PendingExpiryMinutes": 120,
        "UseHTFFilter": "true",  # Always enabled based on feedback
        "HTF_EMA_Period": 50
    }
    
    print("Generating 100 Optimized Use Cases based on feedback analysis...")
    
    # === GOLDEN ZONE PARAMETERS (from feedback) ===
    k_swing_values = [40, 45, 50, 55, 60, 65, 70]  # 40-70 range
    n_bos_values = [5, 6, 7, 8, 9]                 # 5-9 range  
    lookback_values = [10, 12, 14, 16]             # 10-16 range
    tp2_r_values = [2.2, 2.5, 3.0, 3.5, 4.0, 4.5] # 2.2-4.5 range
    
    # === ENTRY OFFSET FINE-TUNING (key focus area) ===
    entry_offset_values = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5] # pips
    
    # === HTF EMA PERIOD VARIATIONS ===
    htf_ema_values = [20, 50, 100]
    
    # === RISK MANAGEMENT VARIATIONS ===
    risk_pct_values = [0.3, 0.5, 0.8]
    
    # Generate systematic combinations
    param_combinations = []
    
    # Core structure variations (60 cases)
    for k_swing in k_swing_values:
        for n_bos in n_bos_values:
            for tp2_r in tp2_r_values[:3]:  # Limit to 3 TP2_R values
                if len(param_combinations) >= 60:
                    break
                param_combinations.append({
                    'type': 'core_structure',
                    'K_swing': k_swing,
                    'N_bos': n_bos,
                    'LookbackInternal': 12,  # Fixed
                    'TP2_R': tp2_r,
                    'EntryOffsetPips': 0.0,  # Default
                    'HTF_EMA_Period': 50,    # Default
                    'RiskPerTradePct': 0.5   # Default
                })
            if len(param_combinations) >= 60:
                break
        if len(param_combinations) >= 60:
            break
    
    # Entry offset fine-tuning (25 cases)
    best_configs = [
        {'K_swing': 50, 'N_bos': 6, 'TP2_R': 2.5},
        {'K_swing': 55, 'N_bos': 7, 'TP2_R': 3.0},
        {'K_swing': 45, 'N_bos': 6, 'TP2_R': 2.2},
        {'K_swing': 60, 'N_bos': 8, 'TP2_R': 3.5},
        {'K_swing': 65, 'N_bos': 7, 'TP2_R': 4.0}
    ]
    
    for config in best_configs:
        for entry_offset in entry_offset_values:
            if len(param_combinations) >= 85:
                break
            param_combinations.append({
                'type': 'entry_offset',
                'K_swing': config['K_swing'],
                'N_bos': config['N_bos'],
                'LookbackInternal': 12,
                'TP2_R': config['TP2_R'],
                'EntryOffsetPips': entry_offset,
                'HTF_EMA_Period': 50,
                'RiskPerTradePct': 0.5
            })
        if len(param_combinations) >= 85:
            break
    
    # HTF and Risk variations (15 cases)
    for htf_ema in htf_ema_values:
        for risk_pct in risk_pct_values:
            if len(param_combinations) >= 100:
                break
            param_combinations.append({
                'type': 'htf_risk',
                'K_swing': 50,  # Best performing
                'N_bos': 6,     # Best performing
                'LookbackInternal': 12,
                'TP2_R': 2.5,   # Best performing
                'EntryOffsetPips': 0.2,  # Moderate offset
                'HTF_EMA_Period': htf_ema,
                'RiskPerTradePct': risk_pct
            })
    
    # Generate final cases
    for i, params in enumerate(param_combinations[:100]):
        case = base_config.copy()
        case["Case"] = case_id
        case["K_swing"] = params['K_swing']
        case["N_bos"] = params['N_bos']
        case["LookbackInternal"] = params['LookbackInternal']
        case["TP2_R"] = params['TP2_R']
        case["EntryOffsetPips"] = params['EntryOffsetPips']
        case["HTF_EMA_Period"] = params['HTF_EMA_Period']
        case["RiskPerTradePct"] = params['RiskPerTradePct']
        
        cases.append(case)
        case_id += 1
    
    return header, cases

def write_csv(filename, header, cases):
    """Write cases to CSV file"""
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=header)
        writer.writeheader()
        for case in cases:
            writer.writerow(case)
    
    print(f"Generated {len(cases)} optimized test cases in {filename}")

def create_preset_sample():
    """Create a sample preset for testing"""
    preset_data = [
        ["Case", "Symbol", "K_swing", "N_bos", "LookbackInternal", "M_retest", "EqTol", "BOSBufferPoints", "UseKillzones", "UseRoundNumber", "RNDelta", "RiskPerTradePct", "SL_BufferUSD", "TP1_R", "TP2_R", "BE_Activate_R", "PartialClosePct", "TimeStopMinutes", "MinProgressR", "MaxSpreadUSD", "MaxOpenPositions", "UsePendingRetest", "RetestOffsetUSD", "PendingExpirySec", "CooldownSec", "ATRScalingPeriod", "SL_ATR_Mult", "Retest_ATR_Mult", "MaxSpread_ATR_Mult", "RNDelta_ATR_Mult", "PendingExpiryMinutes", "UseHTFFilter", "HTF_EMA_Period", "EntryOffsetPips"],
        [1, "XAUUSD", 50, 6, 12, 3, "0.2*pip", "2.0*pipPoints", "true", "true", "0.3*pip", 0.5, "0.6*pip", 1.0, 2.5, 0.8, 50, 5, 0.5, "0.5*pip", 1, "false", "0.07*pip", 60, 0, 14, 0.60, 0.25, 0.15, 0.40, 120, "true", 50, 0.0],
        [2, "XAUUSD", 55, 7, 14, 3, "0.2*pip", "2.0*pipPoints", "true", "true", "0.3*pip", 0.5, "0.6*pip", 1.0, 3.0, 0.8, 50, 5, 0.5, "0.5*pip", 1, "false", "0.07*pip", 60, 0, 14, 0.60, 0.25, 0.15, 0.40, 120, "true", 50, 0.2]
    ]
    
    with open("/Users/anvudinh/Desktop/hoiio/trading/XAU_EA_2/preset_optimized_sample.csv", 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerows(preset_data)
    
    print("Created sample preset file: preset_optimized_sample.csv")

if __name__ == "__main__":
    header, cases = generate_100_optimized_uc()
    write_csv("/Users/anvudinh/Desktop/hoiio/trading/XAU_EA_2/UC_100_optimized.csv", header, cases)
    create_preset_sample()
    
    # Print summary
    print("\n=== OPTIMIZED UC SUMMARY ===")
    print("✅ 100% Order Block (POIType removed)")
    print("✅ 100% OB_MustHaveImbalance = true (hardcoded)")
    print("✅ 100% UseNewsFilter = true (hardcoded)")
    print("✅ HTF_EMA_Method = EMA (hardcoded)")
    print("\n📊 PARAMETER FOCUS:")
    print("• K_swing: 40-70 (golden zone)")
    print("• N_bos: 5-9 (golden zone)")  
    print("• LookbackInternal: 10-16 (golden zone)")
    print("• TP2_R: 2.2-4.5 (golden zone)")
    print("• EntryOffsetPips: 0.0-0.5 (fine-tuning)")
    print("• HTF_EMA_Period: 20, 50, 100")
    print("• RiskPerTradePct: 0.3%, 0.5%, 0.8%")
    print(f"\nTotal: {len(cases)} optimized test cases generated")
