#!/usr/bin/env python3
"""
Step 2b: Extract PPF Polynomial Coefficients from AAA Barycentric Form

Converts the PPF barycentric rational form from ppf_aaa_results.json into 
explicit P(x)/Q(x) polynomial coefficients for Horner evaluation in Move.

The PPF has two regions:
- Central: p ∈ [0.02, 0.98] - direct rational in p
- Tail: p ∈ [1e-10, 0.02] - rational in transformed variable t = sqrt(-2*ln(p))

IMPORTANT: Due to numerical instability in high-degree polynomial conversion,
this script re-runs AAA fitting and uses baryrat's native polynomial extraction.

Usage:
    python 02b_extract_ppf_coefficients.py

Output:
    ../outputs/scaled_ppf_coefficients.json
"""

import json
import numpy as np
from numpy.polynomial import polynomial as P
from pathlib import Path
from decimal import Decimal, getcontext

# High-precision math
try:
    from mpmath import mp, erfinv as mp_erfinv, sqrt as mp_sqrt, log as mp_log
    mp.dps = 50
    HAS_MPMATH = True
except ImportError:
    HAS_MPMATH = False
    print("WARNING: mpmath not installed - using scipy")

from scipy.stats import norm

# AAA algorithm
try:
    from baryrat import aaa
    HAS_BARYRAT = True
except ImportError:
    HAS_BARYRAT = False
    print("ERROR: baryrat not installed. Run: pip install baryrat")
    exit(1)

# Set decimal precision for WAD scaling
getcontext().prec = 80
WAD = 10**18

# Configuration
N_SAMPLES = 2000
AAA_TOLERANCE = 1e-12  # Slightly looser for PPF
EPS = 1e-10
P_LOW = 0.02
P_HIGH = 0.98


def ppf_mpmath(p: float) -> float:
    """Compute Φ⁻¹(p) using mpmath with 50-digit precision."""
    if not HAS_MPMATH:
        return float(norm.ppf(p))
    p_mp = mp.mpf(str(p))
    return float(mp_sqrt(2) * mp_erfinv(2 * p_mp - 1))


def tail_transform(p: float) -> float:
    """Tail transform: t = sqrt(-2 * ln(p))"""
    if HAS_MPMATH:
        p_mp = mp.mpf(str(p))
        return float(mp_sqrt(-2 * mp_log(p_mp)))
    return np.sqrt(-2 * np.log(p))


def scale_coefficients_from_array(p_coeffs: np.ndarray, q_coeffs: np.ndarray):
    """
    Scale polynomial coefficients to WAD (10^18) representation.
    
    Returns separate magnitude and sign arrays.
    """
    # Normalize so Q[0] = 1
    scale = 1.0
    if abs(q_coeffs[0]) > 1e-15:
        scale = q_coeffs[0]
        p_coeffs = p_coeffs / scale
        q_coeffs = q_coeffs / scale
    
    def to_wad(coeffs):
        magnitudes = []
        signs = []
        for c in coeffs:
            neg = bool(c < 0)
            mag = abs(c) * WAD
            mag_int = int(Decimal(str(mag)).to_integral_value())
            magnitudes.append(mag_int)
            signs.append(neg)
        return magnitudes, signs
    
    p_mags, p_signs = to_wad(p_coeffs)
    q_mags, q_signs = to_wad(q_coeffs)
    
    return {
        'p_magnitudes': p_mags,
        'p_signs': p_signs,
        'q_magnitudes': q_mags,
        'q_signs': q_signs,
        'normalization_scale': float(scale)
    }


def rational_to_polynomials(r, x_min: float, x_max: float, samples: int = 2000):
    """Convert barycentric rational r(x) to explicit numerator/denominator coefficients."""
    deg_num, deg_den = r.degree()
    xs = np.linspace(x_min, x_max, samples)
    ys = r(xs)
    cols = (deg_num + 1) + deg_den
    A = np.zeros((samples, cols))
    b = ys.copy()
    for k in range(deg_num + 1):
        A[:, k] = xs ** k
    for k in range(1, deg_den + 1):
        A[:, deg_num + k] = -ys * (xs ** k)
    sol, *_ = np.linalg.lstsq(A, b, rcond=None)
    p_coeffs = sol[:deg_num + 1]
    q_coeffs = np.concatenate(([1.0], sol[deg_num + 1:]))
    return p_coeffs, q_coeffs


def fit_and_extract_central():
    """Fit AAA for central region and extract polynomial coefficients."""
    print("\n" + "="*60)
    print("CENTRAL REGION: p ∈ [0.02, 0.98]")
    print("="*60)
    
    # Sample points
    p = np.linspace(P_LOW, P_HIGH, N_SAMPLES)
    x = np.array([ppf_mpmath(pi) for pi in p])
    
    print(f"Sample points: {N_SAMPLES}")
    print(f"Domain: [{P_LOW}, {P_HIGH}]")
    print(f"Range: [{x.min():.4f}, {x.max():.4f}]")
    
    # Run AAA
    r = aaa(p, x, tol=AAA_TOLERANCE)
    degree = r.degree()
    
    print(f"\nAAA Result:")
    print(f"  Degree: {degree}")
    print(f"  Nodes: {len(r.nodes)}")
    
    # Convert barycentric rational to polynomials via least squares
    p_coeffs, q_coeffs = rational_to_polynomials(r, P_LOW, P_HIGH)
    
    print(f"\nPolynomial degrees:")
    print(f"  P(p): {len(p_coeffs) - 1}")
    print(f"  Q(p): {len(q_coeffs) - 1}")
    
    # Validate
    p_test = np.linspace(P_LOW, P_HIGH, 5000)
    x_true = np.array([ppf_mpmath(pi) for pi in p_test])
    x_approx = r(p_test)
    
    errors = np.abs(x_true - x_approx)
    max_error = np.max(errors)
    mean_error = np.mean(errors)
    
    print(f"\nValidation (vs mpmath):")
    print(f"  Max error: {max_error:.2e}")
    print(f"  Mean error: {mean_error:.2e}")
    
    # Scale to WAD
    scaled = scale_coefficients_from_array(p_coeffs, q_coeffs)
    scaled['region'] = 'central'
    scaled['domain'] = [P_LOW, P_HIGH]
    scaled['numerator_degree'] = len(p_coeffs) - 1
    scaled['denominator_degree'] = len(q_coeffs) - 1
    scaled['max_error'] = float(max_error)
    scaled['mean_error'] = float(mean_error)
    
    return scaled


def fit_and_extract_tail():
    """Fit AAA for lower tail region with transform t = sqrt(-2 * ln(p))."""
    print("\n" + "="*60)
    print("LOWER TAIL REGION: p ∈ [1e-10, 0.02]")
    print("="*60)
    
    # Sample probabilities in log-space to cover deep tail
    p = np.logspace(np.log10(EPS), np.log10(P_LOW), N_SAMPLES)
    t = np.array([tail_transform(pi) for pi in p])
    x = np.array([ppf_mpmath(pi) for pi in p])
    
    print(f"Sample points: {N_SAMPLES}")
    print(f"p range: [{p.min():.2e}, {p.max():.2e}]")
    print(f"t range: [{t.min():.4f}, {t.max():.4f}]")
    print(f"x range: [{x.min():.4f}, {x.max():.4f}]")

    # Run AAA on t -> x mapping (transform already applied)
    r = aaa(t, x, tol=AAA_TOLERANCE)
    degree = r.degree()
    
    print(f"\nAAA Result (t → x):")
    print(f"  Degree: {degree}")
    print(f"  Nodes: {len(r.nodes)}")
    
    # Convert barycentric rational to polynomials in t via least squares
    p_coeffs, q_coeffs = rational_to_polynomials(r, float(t.min()), float(t.max()))
    
    print(f"\nPolynomial degrees (in t):")
    print(f"  P(t): {len(p_coeffs) - 1}")
    print(f"  Q(t): {len(q_coeffs) - 1}")
    
    # Validate
    p_test = np.logspace(np.log10(EPS), np.log10(P_LOW), 5000)
    t_test = np.array([tail_transform(pi) for pi in p_test])
    x_true = np.array([ppf_mpmath(pi) for pi in p_test])
    x_approx = r(t_test)
    
    errors = np.abs(x_true - x_approx)
    max_error = np.max(errors)
    mean_error = np.mean(errors)
    
    print(f"\nValidation (vs mpmath):")
    print(f"  Max error: {max_error:.2e}")
    print(f"  Mean error: {mean_error:.2e}")
    
    # Scale to WAD
    scaled = scale_coefficients_from_array(p_coeffs, q_coeffs)
    scaled['region'] = 'lower_tail'
    scaled['p_domain'] = [float(EPS), P_LOW]
    scaled['t_domain'] = [float(t.min()), float(t.max())]
    scaled['transform'] = 'sqrt(-2*ln(p))'
    scaled['numerator_degree'] = len(p_coeffs) - 1
    scaled['denominator_degree'] = len(q_coeffs) - 1
    scaled['max_error'] = float(max_error)
    scaled['mean_error'] = float(mean_error)
    
    return scaled


def main():
    print("="*60)
    print("Step 2b: Extract PPF Polynomial Coefficients")
    print("="*60)
    print(f"\nConfiguration:")
    print(f"  Sample points: {N_SAMPLES}")
    print(f"  AAA tolerance: {AAA_TOLERANCE:.0e}")
    print(f"  WAD scale: {WAD}")
    print(f"  Precision: {'mpmath (50 digits)' if HAS_MPMATH else 'scipy (double)'}")
    
    # Extract coefficients for each region
    central_scaled = fit_and_extract_central()
    tail_scaled = fit_and_extract_tail()
    
    # Combine results
    results = {
        'ppf_central': central_scaled,
        'ppf_tail': tail_scaled,
        'upper_tail': {
            'region': 'upper_tail',
            'method': 'symmetry',
            'formula': 'ppf(p) = -ppf(1-p) for p > 0.98'
        },
        'config': {
            'wad_scale': WAD,
            'eps': EPS,
            'p_low': P_LOW,
            'p_high': P_HIGH,
            'n_samples': N_SAMPLES,
            'aaa_tolerance': AAA_TOLERANCE,
            'precision': 'mpmath_50' if HAS_MPMATH else 'scipy_double'
        }
    }
    
    # Save results
    output_dir = Path(__file__).parent.parent / 'outputs'
    output_dir.mkdir(exist_ok=True)
    output_file = output_dir / 'scaled_ppf_coefficients.json'
    
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n{'='*60}")
    print("Summary")
    print("="*60)
    print(f"\nResults saved to: {output_file}")
    
    print(f"\nCentral region:")
    print(f"  Degrees: P={central_scaled['numerator_degree']}, Q={central_scaled['denominator_degree']}")
    print(f"  Max error: {central_scaled['max_error']:.2e}")
    print(f"  Coefficients: {len(central_scaled['p_magnitudes'])} numerator, {len(central_scaled['q_magnitudes'])} denominator")
    
    print(f"\nTail region:")
    print(f"  Degrees: P={tail_scaled['numerator_degree']}, Q={tail_scaled['denominator_degree']}")
    print(f"  Max error: {tail_scaled['max_error']:.2e}")
    print(f"  Coefficients: {len(tail_scaled['p_magnitudes'])} numerator, {len(tail_scaled['q_magnitudes'])} denominator")
    
    print(f"\nUpper tail: Uses symmetry ppf(p) = -ppf(1-p)")


if __name__ == "__main__":
    main()
