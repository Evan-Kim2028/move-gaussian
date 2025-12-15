#!/usr/bin/env python3
"""
Overflow analysis for Gaussian CDF Horner evaluation.

The CDF computation uses:
1. Horner's method: acc = acc * z / SCALE + coeff
2. Final division: P(z) / Q(z) * SCALE

We need to verify that all intermediate values fit in u256.

Key bounds:
- u128 max: 2^128 - 1 ≈ 3.4 × 10^38
- u256 max: 2^256 - 1 ≈ 1.16 × 10^77
- SCALE = 10^18
- MAX_Z = 6 × 10^18
"""

from fractions import Fraction
from decimal import Decimal, getcontext

getcontext().prec = 100

SCALE = 10**18
MAX_Z = 6 * SCALE
U128_MAX = 2**128 - 1
U256_MAX = 2**256 - 1

# CDF numerator coefficients (magnitude only)
CDF_NUM = [
    500000000000000000,    # p0
    202783200542711800,    # p1
    3858755025623129,      # p2
    11990724892373883,     # p3
    9821445877008875,      # p4
    428553144348960,       # p5
    75031762951910,        # p6
    152292945143770,       # p7
    11488864967923,        # p8
    4621581948805,         # p9
    2225303281381,         # p10
    261982963157,          # p11
    34576100063,           # p12
]

# CDF denominator coefficients (magnitude only)
CDF_DEN = [
    1000000000000000000,   # q0
    392318159714714800,    # q1
    305307092394795530,    # q2
    86637603680925630,     # q3
    36598917127631020,     # q4
    7691680921657243,      # q5
    2291266221525212,      # q6
    371453915370755,       # q7
    92212330692182,        # q8
    13011690648577,        # q9
    2788395097838,         # q10
    284107149822,          # q11
    34964019972,           # q12
]


def simulate_horner(coeffs: list[int], z: int) -> tuple[int, list[int]]:
    """
    Simulate Horner evaluation tracking all intermediate values.
    
    acc = 0
    for i in reverse(range(len(coeffs))):
        scaled_acc = (acc * z) / SCALE
        acc = scaled_acc + coeffs[i]  # or subtract if signs differ
    
    Returns: (final_result, list of max intermediate values at each step)
    """
    intermediates = []
    acc = 0
    
    for i in reversed(range(len(coeffs))):
        # Step 1: Multiply acc * z (before division)
        product = acc * z
        intermediates.append(("mul_before_div", i, product))
        
        # Step 2: Divide by SCALE
        scaled_acc = product // SCALE
        intermediates.append(("after_div", i, scaled_acc))
        
        # Step 3: Add coefficient (worst case: add magnitudes)
        acc = scaled_acc + coeffs[i]
        intermediates.append(("after_add", i, acc))
    
    return acc, intermediates


def analyze_overflow():
    """Analyze overflow risks in CDF computation."""
    
    print("=" * 70)
    print("OVERFLOW ANALYSIS FOR GAUSSIAN CDF")
    print("=" * 70)
    
    print(f"\nConstants:")
    print(f"  SCALE    = {SCALE:.2e}")
    print(f"  MAX_Z    = {MAX_Z:.2e} (6.0 in WAD)")
    print(f"  u128 max = {U128_MAX:.2e}")
    print(f"  u256 max = {U256_MAX:.2e}")
    
    # Worst case: z = MAX_Z
    z = MAX_Z
    
    print(f"\n{'='*70}")
    print(f"NUMERATOR P(z) at z = {z/SCALE:.1f}")
    print(f"{'='*70}")
    
    p_result, p_intermediates = simulate_horner(CDF_NUM, z)
    
    max_product = 0
    max_acc = 0
    
    for name, idx, val in p_intermediates:
        if name == "mul_before_div":
            max_product = max(max_product, val)
        if name == "after_add":
            max_acc = max(max_acc, val)
    
    print(f"\n  Max value BEFORE division (acc * z):")
    print(f"    {max_product:.6e}")
    print(f"    Fits in u256? {max_product <= U256_MAX} (headroom: {U256_MAX/max_product:.1e}x)")
    print(f"    Fits in u128? {max_product <= U128_MAX}")
    
    print(f"\n  Max accumulator value:")
    print(f"    {max_acc:.6e}")
    print(f"    Fits in u256? {max_acc <= U256_MAX}")
    print(f"    Fits in u128? {max_acc <= U128_MAX}")
    
    print(f"\n  Final P({z/SCALE}) = {p_result:.6e}")
    
    print(f"\n{'='*70}")
    print(f"DENOMINATOR Q(z) at z = {z/SCALE:.1f}")
    print(f"{'='*70}")
    
    q_result, q_intermediates = simulate_horner(CDF_DEN, z)
    
    max_product_q = 0
    max_acc_q = 0
    
    for name, idx, val in q_intermediates:
        if name == "mul_before_div":
            max_product_q = max(max_product_q, val)
        if name == "after_add":
            max_acc_q = max(max_acc_q, val)
    
    print(f"\n  Max value BEFORE division (acc * z):")
    print(f"    {max_product_q:.6e}")
    print(f"    Fits in u256? {max_product_q <= U256_MAX} (headroom: {U256_MAX/max_product_q:.1e}x)")
    print(f"    Fits in u128? {max_product_q <= U128_MAX}")
    
    print(f"\n  Max accumulator value:")
    print(f"    {max_acc_q:.6e}")
    print(f"    Fits in u256? {max_acc_q <= U256_MAX}")
    print(f"    Fits in u128? {max_acc_q <= U128_MAX}")
    
    print(f"\n  Final Q({z/SCALE}) = {q_result:.6e}")
    
    print(f"\n{'='*70}")
    print(f"FINAL DIVISION: P(z) * SCALE / Q(z)")
    print(f"{'='*70}")
    
    # div_scaled computes (P * SCALE) / Q
    div_product = p_result * SCALE
    print(f"\n  P(z) * SCALE = {div_product:.6e}")
    print(f"  Fits in u256? {div_product <= U256_MAX} (headroom: {U256_MAX/div_product:.1e}x)")
    
    final_result = div_product // q_result
    print(f"\n  CDF({z/SCALE}) = {final_result:.6e}")
    print(f"  As probability: {final_result/SCALE:.15f}")
    
    print(f"\n{'='*70}")
    print("SUMMARY: OVERFLOW BOUNDS")
    print(f"{'='*70}")
    
    # Find the absolute maximum across all z values
    print("\nScanning all z from 0 to 6...")
    
    global_max_product = 0
    global_max_acc = 0
    worst_z = 0
    
    for z_int in range(0, 6001):  # 0.000 to 6.000 in 0.001 steps
        z = z_int * SCALE // 1000
        
        _, p_ints = simulate_horner(CDF_NUM, z)
        _, q_ints = simulate_horner(CDF_DEN, z)
        
        for name, idx, val in p_ints + q_ints:
            if name == "mul_before_div" and val > global_max_product:
                global_max_product = val
                worst_z = z
            if name == "after_add":
                global_max_acc = max(global_max_acc, val)
    
    print(f"\n  Global max (acc * z) across all z in [0, 6]:")
    print(f"    {global_max_product:.6e}")
    print(f"    At z = {worst_z/SCALE:.3f}")
    print(f"    Fits in u256? {global_max_product <= U256_MAX}")
    print(f"    Fits in u128? {global_max_product <= U128_MAX}")
    if global_max_product <= U256_MAX:
        print(f"    u256 headroom: {U256_MAX/global_max_product:.2e}x")
    
    print(f"\n  Global max accumulator:")
    print(f"    {global_max_acc:.6e}")
    print(f"    Fits in u256? {global_max_acc <= U256_MAX}")
    print(f"    Fits in u128? {global_max_acc <= U128_MAX}")
    
    # Compute tight bounds for specs
    print(f"\n{'='*70}")
    print("BOUNDS FOR FORMAL VERIFICATION")
    print(f"{'='*70}")
    
    print(f"""
For sui-prover specs, we can use these bounds:

1. Horner multiplication bound:
   acc * z < {global_max_product + 1:.0e}
   This fits in u256 with {U256_MAX/global_max_product:.1e}x headroom

2. Accumulator bound:
   acc < {global_max_acc + 1:.0e}
   This fits in u256 with {U256_MAX/global_max_acc:.1e}x headroom

3. Final division bound:
   P(z) * SCALE < {p_result * SCALE:.0e}
   This fits in u256 with {U256_MAX/(p_result*SCALE):.1e}x headroom

Key insight: The implementation uses u256 arithmetic, which provides
~10^40x headroom over the maximum intermediate values. Overflow is
impossible for valid inputs z ∈ [0, 6*SCALE].
""")
    
    return global_max_product, global_max_acc


if __name__ == "__main__":
    max_prod, max_acc = analyze_overflow()
