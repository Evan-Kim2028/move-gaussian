#!/usr/bin/env python3
"""
Compute Sturm sequence for the CDF derivative numerator polynomial
to formally prove no roots exist in [0, 6].

Sturm's Theorem: The number of distinct real roots of polynomial p(x)
in the interval (a, b] equals V(a) - V(b), where V(x) is the number of
sign changes in the Sturm sequence evaluated at x.

If V(0) - V(6) = 0 and N(0) > 0, then N(z) > 0 on [0, 6].
"""

from fractions import Fraction
from typing import List, Tuple
import sympy as sp
from sympy import Rational, symbols, Poly, sign as sym_sign


# WAD scale
SCALE = 10**18

# P coefficients from coefficients.move (with signs)
P_COEFFS = [
    (500000000000000000, False),    # p0
    (202783200542711800, False),    # p1
    (3858755025623129, True),       # p2
    (11990724892373883, False),     # p3
    (9821445877008875, False),      # p4
    (428553144348960, False),       # p5
    (75031762951910, True),         # p6
    (152292945143770, False),       # p7
    (11488864967923, False),        # p8
    (4621581948805, True),          # p9
    (2225303281381, False),         # p10
    (261982963157, True),           # p11
    (34576100063, False),           # p12
]

# Q coefficients
Q_COEFFS = [
    (1000000000000000000, False),   # q0
    (392318159714714800, True),     # q1
    (305307092394795530, False),    # q2
    (86637603680925630, True),      # q3
    (36598917127631020, False),     # q4
    (7691680921657243, True),       # q5
    (2291266221525212, False),      # q6
    (371453915370755, True),        # q7
    (92212330692182, False),        # q8
    (13011690648577, True),         # q9
    (2788395097838, False),         # q10
    (284107149822, True),           # q11
    (34964019972, False),           # q12
]


def to_rational(mag: int, is_neg: bool) -> Rational:
    """Convert coefficient to SymPy Rational."""
    r = Rational(mag, SCALE)
    return -r if is_neg else r


def build_polynomials():
    """Build P(z) and Q(z) as SymPy polynomials."""
    z = symbols('z')
    
    p_coeffs = [to_rational(mag, neg) for mag, neg in P_COEFFS]
    q_coeffs = [to_rational(mag, neg) for mag, neg in Q_COEFFS]
    
    P = sum(c * z**i for i, c in enumerate(p_coeffs))
    Q = sum(c * z**i for i, c in enumerate(q_coeffs))
    
    return z, P, Q


def compute_derivative_numerator():
    """Compute N(z) = P'(z)*Q(z) - P(z)*Q'(z)."""
    z, P, Q = build_polynomials()
    
    P_prime = sp.diff(P, z)
    Q_prime = sp.diff(Q, z)
    
    N = sp.expand(P_prime * Q - P * Q_prime)
    
    return z, N


def sturm_sequence(poly, var):
    """
    Compute the Sturm sequence for a polynomial.
    
    Returns list of polynomials [p0, p1, p2, ...] where:
    - p0 = poly
    - p1 = poly'
    - p_{i+1} = -rem(p_{i-1}, p_i)
    """
    p0 = Poly(poly, var)
    p1 = Poly(sp.diff(poly, var), var)
    
    sequence = [p0, p1]
    
    while not sequence[-1].is_zero:
        p_prev = sequence[-2]
        p_curr = sequence[-1]
        
        # Polynomial remainder
        _, remainder = sp.div(p_prev.as_expr(), p_curr.as_expr(), var)
        
        if remainder == 0:
            break
            
        # Negate the remainder
        p_next = Poly(-remainder, var)
        sequence.append(p_next)
    
    return sequence


def count_sign_changes(values: List) -> int:
    """Count sign changes in a sequence, ignoring zeros."""
    # Filter out zeros
    nonzero = [v for v in values if v != 0]
    
    if len(nonzero) < 2:
        return 0
    
    changes = 0
    for i in range(len(nonzero) - 1):
        if (nonzero[i] > 0) != (nonzero[i+1] > 0):
            changes += 1
    
    return changes


def evaluate_sturm_at(sequence, var, point) -> List:
    """Evaluate each polynomial in Sturm sequence at a point."""
    return [poly.eval(point) for poly in sequence]


def sturm_root_count(sequence, var, a, b) -> int:
    """
    Count roots in interval (a, b] using Sturm's theorem.
    """
    values_a = evaluate_sturm_at(sequence, var, a)
    values_b = evaluate_sturm_at(sequence, var, b)
    
    V_a = count_sign_changes(values_a)
    V_b = count_sign_changes(values_b)
    
    return V_a - V_b


def main():
    print("=" * 70)
    print("Sturm Sequence Analysis for CDF Monotonicity Certificate")
    print("=" * 70)
    
    # Compute N(z)
    print("\nComputing N(z) = P'(z)*Q(z) - P(z)*Q'(z)...")
    z, N = compute_derivative_numerator()
    
    N_poly = Poly(N, z)
    print(f"N(z) degree: {N_poly.degree()}")
    
    # Evaluate at endpoints
    N_at_0 = N.subs(z, 0)
    N_at_6 = N.subs(z, 6)
    print(f"\nN(0) = {float(N_at_0):.15e}")
    print(f"N(6) = {float(N_at_6):.15e}")
    
    # Compute Sturm sequence
    print("\nComputing Sturm sequence...")
    sturm_seq = sturm_sequence(N, z)
    print(f"Sturm sequence length: {len(sturm_seq)} polynomials")
    
    # Print degrees
    print("\nSturm sequence degrees:")
    for i, p in enumerate(sturm_seq):
        if not p.is_zero:
            print(f"  p_{i}: degree {p.degree()}")
        else:
            print(f"  p_{i}: zero polynomial")
    
    # Evaluate at 0 and 6
    print("\n" + "=" * 70)
    print("Evaluating Sturm sequence at endpoints:")
    print("=" * 70)
    
    values_0 = evaluate_sturm_at(sturm_seq, z, Rational(0))
    values_6 = evaluate_sturm_at(sturm_seq, z, Rational(6))
    
    print("\nAt z = 0:")
    for i, v in enumerate(values_0):
        sign = "+" if v > 0 else ("-" if v < 0 else "0")
        print(f"  p_{i}(0) = {sign} ({float(v):.6e})")
    
    print("\nAt z = 6:")
    for i, v in enumerate(values_6):
        sign = "+" if v > 0 else ("-" if v < 0 else "0")
        print(f"  p_{i}(6) = {sign} ({float(v):.6e})")
    
    # Count sign changes
    V_0 = count_sign_changes(values_0)
    V_6 = count_sign_changes(values_6)
    
    print(f"\nSign changes at z=0: V(0) = {V_0}")
    print(f"Sign changes at z=6: V(6) = {V_6}")
    
    # Root count
    root_count = V_0 - V_6
    print(f"\nNumber of roots in (0, 6]: V(0) - V(6) = {root_count}")
    
    # Final verdict
    print("\n" + "=" * 70)
    print("CERTIFICATE RESULT:")
    print("=" * 70)
    
    if root_count == 0 and N_at_0 > 0:
        print("""
✓ THEOREM VERIFIED: N(z) > 0 for all z ∈ [0, 6]

Proof:
1. N(0) > 0 (numerically: {:.15e})
2. Sturm's theorem: V(0) - V(6) = {} roots in (0, 6]
3. Since N(0) > 0 and there are no roots, N(z) > 0 on [0, 6]
4. Therefore CDF'(z) = N(z)/Q(z)² > 0, proving monotonicity
""".format(float(N_at_0), root_count))
    else:
        print(f"✗ Could not verify: found {root_count} root(s)")
    
    # Check also on [0, 0] (at exactly 0)
    root_count_full = sturm_root_count(sturm_seq, z, Rational(-1, 1000), Rational(6))
    print(f"\nRoots in [-0.001, 6]: {root_count_full}")
    
    # Generate certificate data
    print("\n" + "=" * 70)
    print("Certificate Data for Formal Verification:")
    print("=" * 70)
    print(f"""
The following facts constitute a formal certificate:

1. Polynomial N(z) has exact rational coefficients (derivable from P, Q)
2. Sturm sequence computed with exact arithmetic
3. V(0) = {V_0} (sign changes at z=0)
4. V(6) = {V_6} (sign changes at z=6)  
5. Root count = {root_count}
6. N(0) = {N_at_0} > 0

This certificate can be checked in any proof assistant that supports:
- Exact rational arithmetic
- Polynomial GCD computation
- Sign evaluation
""")


if __name__ == "__main__":
    main()
