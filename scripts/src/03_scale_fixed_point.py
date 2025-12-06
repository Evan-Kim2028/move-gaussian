#!/usr/bin/env python3
"""
Step 3: Scale Coefficients to Fixed-Point Integers

Converts float polynomial coefficients to WAD-scaled integers (1e18)
suitable for on-chain fixed-point arithmetic.

For Move compatibility (u256 is unsigned), we separate magnitude and sign.

Usage:
    python 03_scale_fixed_point.py

Input:
    ../outputs/coefficients.json

Output:
    ../outputs/scaled_coefficients.json
"""

import json
from decimal import Decimal, getcontext
from pathlib import Path

# Set high precision for Decimal operations
getcontext().prec = 50

# WAD = 10^18 (standard DeFi fixed-point scaling)
WAD = 10**18


def scale_coefficient(coeff_float: float) -> int:
    """
    Scale a float coefficient to WAD integer.
    
    Uses Decimal for precise conversion to avoid floating-point errors.
    
    Args:
        coeff_float: Float coefficient
        
    Returns:
        Integer scaled by WAD
    """
    # Use Decimal for precise conversion
    coeff_decimal = Decimal(str(coeff_float))
    wad_decimal = Decimal(str(WAD))
    
    # Scale and round to nearest integer
    scaled = coeff_decimal * wad_decimal
    return int(scaled.to_integral_value())


def scale_and_split(coeffs: list[float]) -> tuple[list[int], list[bool]]:
    """
    Scale coefficients and separate magnitude from sign.
    
    Move uses unsigned integers (u256), so we need to track signs separately.
    
    Args:
        coeffs: List of float coefficients
        
    Returns:
        (magnitudes, signs): Absolute values and sign flags (True = negative)
    """
    magnitudes = []
    signs = []
    
    for c in coeffs:
        scaled = scale_coefficient(c)
        magnitudes.append(abs(scaled))
        signs.append(scaled < 0)
    
    return magnitudes, signs


def analyze_scaled_coefficients(magnitudes: list[int], signs: list[bool], name: str):
    """Analyze scaled coefficients for Move compatibility."""
    
    print(f"\n{name}:")
    print(f"  Count: {len(magnitudes)}")
    
    max_mag = max(magnitudes)
    print(f"  Max magnitude: {max_mag}")
    print(f"  Max magnitude bits: {max_mag.bit_length()}")
    
    # Check if fits in u128 or needs u256
    if max_mag < 2**128:
        print(f"  Fits in: u128 ✓")
    elif max_mag < 2**256:
        print(f"  Fits in: u256 ✓ (too large for u128)")
    else:
        print(f"  WARNING: Exceeds u256!")
    
    # Count negative coefficients
    neg_count = sum(signs)
    print(f"  Negative coefficients: {neg_count}/{len(signs)}")
    
    # Show first few coefficients
    print(f"  First 3 coefficients:")
    for i in range(min(3, len(magnitudes))):
        sign_str = "-" if signs[i] else "+"
        print(f"    c[{i}] = {sign_str}{magnitudes[i]}")


def check_overflow_potential(p_mags: list[int], q_mags: list[int], max_x_wad: int):
    """
    Check if Horner evaluation could overflow.
    
    In Horner's method: result = result * x + c
    The intermediate values can grow large.
    
    Args:
        p_mags: Numerator magnitudes
        q_mags: Denominator magnitudes  
        max_x_wad: Maximum input x (scaled by WAD)
    """
    print("\n" + "="*60)
    print("Overflow Analysis")
    print("="*60)
    
    MAX_U256 = 2**256 - 1
    
    # Worst case for Horner: all coefficients are max, all same sign
    max_p = max(p_mags)
    max_q = max(q_mags)
    n_p = len(p_mags)
    n_q = len(q_mags)
    
    # Rough upper bound: max_coeff * (max_x/WAD)^degree * n_terms
    # This is very conservative
    x_normalized = max_x_wad / WAD  # ~6.0
    
    p_bound = max_p * (x_normalized ** n_p) * n_p
    q_bound = max_q * (x_normalized ** n_q) * n_q
    
    print(f"\nMax input x (WAD): {max_x_wad}")
    print(f"Max x (float): {max_x_wad / WAD}")
    
    print(f"\nP(x) upper bound estimate: {p_bound:.2e}")
    print(f"Q(x) upper bound estimate: {q_bound:.2e}")
    print(f"u256 max: {MAX_U256:.2e}")
    
    # More accurate: simulate Horner with max values
    print(f"\nSimulating Horner with x = {max_x_wad}:")
    
    # P(x) simulation
    result = p_mags[-1]
    max_intermediate_p = result
    for i in range(len(p_mags) - 2, -1, -1):
        result = (result * max_x_wad) // WAD + p_mags[i]
        max_intermediate_p = max(max_intermediate_p, result)
    
    print(f"  P(x) max intermediate: {max_intermediate_p:.2e}")
    print(f"  P(x) fits in u256: {'✓' if max_intermediate_p < MAX_U256 else '✗'}")
    
    # Q(x) simulation
    result = q_mags[-1]
    max_intermediate_q = result
    for i in range(len(q_mags) - 2, -1, -1):
        result = (result * max_x_wad) // WAD + q_mags[i]
        max_intermediate_q = max(max_intermediate_q, result)
    
    print(f"  Q(x) max intermediate: {max_intermediate_q:.2e}")
    print(f"  Q(x) fits in u256: {'✓' if max_intermediate_q < MAX_U256 else '✗'}")
    
    # Final division: (P * WAD) / Q
    # Need to check P * WAD doesn't overflow
    p_times_wad = max_intermediate_p * WAD
    print(f"\n  P(x) * WAD: {p_times_wad:.2e}")
    print(f"  Fits in u256: {'✓' if p_times_wad < MAX_U256 else '✗'}")


def process_function(data: dict, func_name: str) -> dict:
    """Process coefficients for one function."""
    
    print(f"\n{'='*60}")
    print(f"Scaling coefficients for {func_name}")
    print("="*60)
    
    # Use normalized coefficients (Q[0] = 1)
    p_coeffs = data['p_coefficients_normalized']
    q_coeffs = data['q_coefficients_normalized']
    
    print(f"P(x) degree: {len(p_coeffs) - 1}")
    print(f"Q(x) degree: {len(q_coeffs) - 1}")
    
    # Scale to WAD
    p_mags, p_signs = scale_and_split(p_coeffs)
    q_mags, q_signs = scale_and_split(q_coeffs)
    
    # Analyze
    analyze_scaled_coefficients(p_mags, p_signs, "P(x) numerator")
    analyze_scaled_coefficients(q_mags, q_signs, "Q(x) denominator")
    
    # Check overflow potential for x in [0, 6]
    max_x_wad = 6 * WAD
    check_overflow_potential(p_mags, q_mags, max_x_wad)
    
    return {
        'function': func_name,
        'scale': WAD,
        'domain': data['domain'],
        'numerator_degree': len(p_coeffs) - 1,
        'denominator_degree': len(q_coeffs) - 1,
        'p_magnitudes': p_mags,
        'p_signs': p_signs,
        'q_magnitudes': q_mags,
        'q_signs': q_signs,
        'original_max_error': data['max_error_vs_true'],
        'normalization_scale': data['normalization_scale']
    }


def main():
    print("="*60)
    print("Step 3: Scale to Fixed-Point Integers")
    print("="*60)
    print(f"\nWAD scale factor: {WAD} (10^18)")
    
    # Load coefficients from Step 2
    input_dir = Path(__file__).parent.parent / 'outputs'
    input_file = input_dir / 'coefficients.json'
    
    if not input_file.exists():
        print(f"ERROR: {input_file} not found.")
        print("Run 02_extract_coefficients.py first.")
        exit(1)
    
    with open(input_file, 'r') as f:
        coefficients = json.load(f)
    
    # Process each function
    results = {}
    for func_name in ['erf', 'erfc', 'phi']:
        if func_name in coefficients:
            results[func_name] = process_function(coefficients[func_name], func_name)
    
    # Save results
    output_file = input_dir / 'scaled_coefficients.json'
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n{'='*60}")
    print("Summary")
    print("="*60)
    print(f"\nResults saved to: {output_file}")
    
    for name, data in results.items():
        print(f"\n{name}:")
        print(f"  Scale: {data['scale']}")
        print(f"  Degrees: P={data['numerator_degree']}, Q={data['denominator_degree']}")
        print(f"  Original max error: {data['original_max_error']:.2e}")


if __name__ == "__main__":
    main()
