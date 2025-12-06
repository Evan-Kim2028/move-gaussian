#!/usr/bin/env python3
"""
AAA Algorithm for Inverse CDF (PPF / Quantile Function)

Finds optimal rational approximations for Φ⁻¹(p), the inverse of the 
standard normal CDF. This is essential for Gaussian sampling:

    sample = Φ⁻¹(uniform_random)

CHALLENGE: PPF has different numerical properties than erf:
- Domain: p ∈ (0, 1) with singularities at 0 and 1
- Range: x ∈ (-∞, +∞)
- Steep gradient at tails (p near 0 or 1)

STRATEGY: Piecewise approximation
- Central region (0.02 ≤ p ≤ 0.98): Direct AAA
- Lower tail (ε ≤ p < 0.02): Transform-based AAA  
- Upper tail (p > 0.98): Symmetry Φ⁻¹(p) = -Φ⁻¹(1-p)

Usage:
    python 01b_aaa_ppf.py

Output:
    Plots and coefficient extraction for PPF approximation
"""

import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import json

# High-precision math
try:
    from mpmath import mp, erfinv as mp_erfinv, sqrt as mp_sqrt, log as mp_log
    mp.dps = 50
    HAS_MPMATH = True
except ImportError:
    HAS_MPMATH = False
    print("WARNING: mpmath not installed - using scipy (double precision)")

from scipy.stats import norm
from scipy.special import erfinv as scipy_erfinv

# AAA algorithm
try:
    from baryrat import aaa
    HAS_BARYRAT = True
except ImportError:
    HAS_BARYRAT = False
    print("ERROR: baryrat not installed. Run: pip install baryrat")
    exit(1)


# =============================================================================
# Configuration
# =============================================================================

N_SAMPLES = 2000
AAA_TOLERANCE = 1e-13

# Domain boundaries for piecewise approximation
CENTRAL_LOW = 0.02      # Below this, use tail approximation
CENTRAL_HIGH = 0.98     # Above this, use symmetry
TAIL_EPSILON = 1e-10    # Minimum probability (avoid singularity at 0)


# =============================================================================
# High-Precision PPF
# =============================================================================

def ppf_mpmath(p: float) -> float:
    """
    Compute Φ⁻¹(p) using mpmath with 50-digit precision.
    
    Uses the relationship: Φ⁻¹(p) = √2 × erfinv(2p - 1)
    """
    if not HAS_MPMATH:
        return float(norm.ppf(p))
    
    p_mp = mp.mpf(str(p))
    result = mp_sqrt(2) * mp_erfinv(2 * p_mp - 1)
    return float(result)


def ppf_mpmath_array(p_arr: np.ndarray) -> np.ndarray:
    """High-precision PPF for array input."""
    return np.array([ppf_mpmath(p) for p in p_arr])


# =============================================================================
# Tail Transform
# =============================================================================

def tail_transform(p: np.ndarray) -> np.ndarray:
    """
    Transform for lower tail: t = √(-2 ln(p))
    
    This maps p ∈ (0, 0.5) to t ∈ (√(2 ln 2), ∞)
    The PPF can be approximated more easily as a function of t.
    """
    return np.sqrt(-2 * np.log(p))


def tail_transform_mpmath(p: float) -> float:
    """High-precision tail transform."""
    if HAS_MPMATH:
        p_mp = mp.mpf(str(p))
        return float(mp_sqrt(-2 * mp_log(p_mp)))
    return np.sqrt(-2 * np.log(p))


# =============================================================================
# AAA Analysis for Different Regions
# =============================================================================

def analyze_central_region():
    """
    AAA approximation for central region: 0.02 ≤ p ≤ 0.98
    
    In this region, PPF is well-behaved (no singularities).
    """
    print(f"\n{'='*70}")
    print("CENTRAL REGION: AAA for Φ⁻¹(p), p ∈ [0.02, 0.98]")
    print("="*70)
    
    # Sample points
    p = np.linspace(CENTRAL_LOW, CENTRAL_HIGH, N_SAMPLES)
    x = ppf_mpmath_array(p)
    
    print(f"Sample points: {N_SAMPLES}")
    print(f"Domain: [{CENTRAL_LOW}, {CENTRAL_HIGH}]")
    print(f"Range: [{x.min():.4f}, {x.max():.4f}]")
    print(f"Precision: {'mpmath (50 digits)' if HAS_MPMATH else 'scipy (double)'}")
    
    # Run AAA
    r = aaa(p, x, tol=AAA_TOLERANCE)
    degree = r.degree()
    
    print(f"\nAAA Result:")
    print(f"  Degree: {degree}")
    print(f"  Nodes: {len(r.nodes)}")
    
    # Compute error
    x_approx = r(p)
    errors = np.abs(x - x_approx)
    max_error = np.max(errors)
    mean_error = np.mean(errors)
    
    print(f"\nError (vs mpmath):")
    print(f"  Max: {max_error:.2e}")
    print(f"  Mean: {mean_error:.2e}")
    
    # Check poles
    poles = r.poles()
    real_poles = poles[np.abs(poles.imag) < 1e-10]
    poles_in_domain = real_poles[(real_poles.real >= CENTRAL_LOW) & (real_poles.real <= CENTRAL_HIGH)]
    
    print(f"\nPole Analysis:")
    print(f"  Total poles: {len(poles)}")
    print(f"  Poles in domain: {len(poles_in_domain)}")
    print(f"  {'✓ Safe' if len(poles_in_domain) == 0 else '⚠ POLES IN DOMAIN!'}")
    
    # Verify on denser grid
    p_verify = np.linspace(CENTRAL_LOW, CENTRAL_HIGH, 10000)
    x_true = ppf_mpmath_array(p_verify)
    x_verify = r(p_verify)
    verify_error = np.max(np.abs(x_true - x_verify))
    
    print(f"\nVerification (10k points):")
    print(f"  Max error: {verify_error:.2e}")
    
    return r, {
        'region': 'central',
        'domain': [CENTRAL_LOW, CENTRAL_HIGH],
        'degree': degree,
        'max_error': max_error,
        'verify_error': verify_error,
        'nodes': r.nodes.tolist(),
        'weights': r.weights.tolist(),
        'values': r.values.tolist()
    }


def analyze_lower_tail():
    """
    AAA approximation for lower tail using transform.
    
    For p < 0.02, we use the transform t = √(-2 ln(p))
    and approximate Φ⁻¹(p) as a function of t.
    
    This avoids the singularity at p = 0.
    """
    print(f"\n{'='*70}")
    print("LOWER TAIL: AAA for Φ⁻¹(p), p ∈ [1e-10, 0.02]")
    print("="*70)
    
    # Sample in log-space to get good coverage near zero
    p = np.logspace(np.log10(TAIL_EPSILON), np.log10(CENTRAL_LOW), N_SAMPLES)
    t = tail_transform(p)
    x = ppf_mpmath_array(p)
    
    print(f"Sample points: {N_SAMPLES}")
    print(f"p range: [{p.min():.2e}, {p.max():.2e}]")
    print(f"t range: [{t.min():.4f}, {t.max():.4f}]")
    print(f"x range: [{x.min():.4f}, {x.max():.4f}]")
    
    # Note: In the lower tail, x is negative
    # The Acklam algorithm approximates x = -t + (c0 + c1*t + c2*t²) / (d0 + d1*t + d2*t² + d3*t³)
    # Let's see what AAA finds
    
    # Run AAA on t -> x mapping
    r = aaa(t, x, tol=AAA_TOLERANCE)
    degree = r.degree()
    
    print(f"\nAAA Result (t → x):")
    print(f"  Degree: {degree}")
    print(f"  Nodes: {len(r.nodes)}")
    
    # Compute error
    x_approx = r(t)
    errors = np.abs(x - x_approx)
    max_error = np.max(errors)
    mean_error = np.mean(errors)
    
    print(f"\nError (vs mpmath):")
    print(f"  Max: {max_error:.2e}")
    print(f"  Mean: {mean_error:.2e}")
    
    # Check poles
    poles = r.poles()
    real_poles = poles[np.abs(poles.imag) < 1e-10]
    t_min, t_max = t.min(), t.max()
    poles_in_domain = real_poles[(real_poles.real >= t_min) & (real_poles.real <= t_max)]
    
    print(f"\nPole Analysis:")
    print(f"  Total poles: {len(poles)}")
    print(f"  Poles in t-domain [{t_min:.2f}, {t_max:.2f}]: {len(poles_in_domain)}")
    print(f"  {'✓ Safe' if len(poles_in_domain) == 0 else '⚠ POLES IN DOMAIN!'}")
    
    return r, {
        'region': 'lower_tail',
        'p_domain': [float(TAIL_EPSILON), CENTRAL_LOW],
        't_domain': [float(t.min()), float(t.max())],
        'degree': degree,
        'max_error': max_error,
        'transform': 'sqrt(-2*ln(p))',
        'nodes': r.nodes.tolist(),
        'weights': r.weights.tolist(),
        'values': r.values.tolist()
    }


def test_full_domain():
    """
    Test combined approximation over full domain.
    
    Uses:
    - Lower tail transform for p < 0.02
    - Central region direct for 0.02 ≤ p ≤ 0.98
    - Symmetry for p > 0.98: Φ⁻¹(p) = -Φ⁻¹(1-p)
    """
    print(f"\n{'='*70}")
    print("FULL DOMAIN TEST: Combined Approximation")
    print("="*70)
    
    # Get approximants
    r_central, _ = analyze_central_region()
    r_tail, _ = analyze_lower_tail()
    
    # Test on full domain
    p_test = np.logspace(np.log10(TAIL_EPSILON), np.log10(1 - TAIL_EPSILON), 10000)
    
    x_true = ppf_mpmath_array(p_test)
    x_approx = np.zeros_like(x_true)
    
    for i, p in enumerate(p_test):
        if p < CENTRAL_LOW:
            # Lower tail: use transform
            t = tail_transform(np.array([p]))[0]
            x_approx[i] = r_tail(t)
        elif p > CENTRAL_HIGH:
            # Upper tail: symmetry Φ⁻¹(p) = -Φ⁻¹(1-p)
            p_sym = 1 - p
            if p_sym < CENTRAL_LOW:
                # p_sym is in lower tail region
                t = tail_transform(np.array([p_sym]))[0]
                x_approx[i] = -r_tail(t)
            else:
                # p_sym is in central region
                x_approx[i] = -r_central(p_sym)
        else:
            # Central region
            x_approx[i] = r_central(p)
    
    errors = np.abs(x_true - x_approx)
    
    print(f"\nFull domain error analysis:")
    print(f"  Max error: {np.max(errors):.2e}")
    print(f"  Mean error: {np.mean(errors):.2e}")
    print(f"  P99 error: {np.percentile(errors, 99):.2e}")
    
    # Error by region
    lower_mask = p_test < CENTRAL_LOW
    central_mask = (p_test >= CENTRAL_LOW) & (p_test <= CENTRAL_HIGH)
    upper_mask = p_test > CENTRAL_HIGH
    
    if np.any(lower_mask):
        print(f"\n  Lower tail (p < {CENTRAL_LOW}):")
        print(f"    Max error: {np.max(errors[lower_mask]):.2e}")
    
    if np.any(central_mask):
        print(f"\n  Central ({CENTRAL_LOW} ≤ p ≤ {CENTRAL_HIGH}):")
        print(f"    Max error: {np.max(errors[central_mask]):.2e}")
    
    if np.any(upper_mask):
        print(f"\n  Upper tail (p > {CENTRAL_HIGH}):")
        print(f"    Max error: {np.max(errors[upper_mask]):.2e}")
        # Debug: find worst case
        worst_idx = np.argmax(errors[upper_mask])
        worst_p = p_test[upper_mask][worst_idx]
        print(f"    Worst p: {worst_p:.6f}")
        print(f"    True x: {x_true[upper_mask][worst_idx]:.6f}")
        print(f"    Approx x: {x_approx[upper_mask][worst_idx]:.6f}")
    
    return r_central, r_tail


def plot_results(r_central, r_tail):
    """Generate plots for PPF approximation."""
    
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # 1. PPF function and approximation
    ax = axes[0, 0]
    p_plot = np.linspace(0.001, 0.999, 1000)
    x_true = ppf_mpmath_array(p_plot)
    
    # Compute approximation
    x_approx = np.zeros_like(x_true)
    for i, p in enumerate(p_plot):
        if p < CENTRAL_LOW:
            t = tail_transform(np.array([p]))[0]
            x_approx[i] = r_tail(t)
        elif p > CENTRAL_HIGH:
            p_sym = 1 - p
            if p_sym < CENTRAL_LOW:
                t = tail_transform(np.array([p_sym]))[0]
                x_approx[i] = -r_tail(t)
            else:
                x_approx[i] = -r_central(p_sym)
        else:
            x_approx[i] = r_central(p)
    
    ax.plot(p_plot, x_true, 'b-', label='True Φ⁻¹(p)', linewidth=2)
    ax.plot(p_plot, x_approx, 'r--', label='AAA approx', linewidth=1.5)
    ax.axvline(CENTRAL_LOW, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(CENTRAL_HIGH, color='gray', linestyle=':', alpha=0.5)
    ax.set_xlabel('p')
    ax.set_ylabel('x = Φ⁻¹(p)')
    ax.set_title('Inverse CDF (PPF)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 2. Error plot (log scale)
    ax = axes[0, 1]
    errors = np.abs(x_true - x_approx)
    ax.semilogy(p_plot, errors, 'g-', linewidth=1.5)
    ax.axhline(1e-10, color='orange', linestyle='--', label='Target (1e-10)')
    ax.axhline(1e-15, color='red', linestyle='--', label='WAD limit (1e-15)')
    ax.axvline(CENTRAL_LOW, color='gray', linestyle=':', alpha=0.5)
    ax.axvline(CENTRAL_HIGH, color='gray', linestyle=':', alpha=0.5)
    ax.set_xlabel('p')
    ax.set_ylabel('|error|')
    ax.set_title('Absolute Error')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 3. Central region detail
    ax = axes[1, 0]
    p_central = np.linspace(CENTRAL_LOW, CENTRAL_HIGH, 500)
    x_central = ppf_mpmath_array(p_central)
    x_central_approx = np.array([r_central(p) for p in p_central])
    errors_central = np.abs(x_central - x_central_approx)
    
    ax.semilogy(p_central, errors_central, 'b-', linewidth=1.5)
    ax.axhline(1e-13, color='orange', linestyle='--', label='1e-13')
    ax.set_xlabel('p')
    ax.set_ylabel('|error|')
    ax.set_title(f'Central Region Error [{CENTRAL_LOW}, {CENTRAL_HIGH}]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 4. Tail region detail
    ax = axes[1, 1]
    p_tail = np.logspace(np.log10(TAIL_EPSILON), np.log10(CENTRAL_LOW), 500)
    t_tail = tail_transform(p_tail)
    x_tail = ppf_mpmath_array(p_tail)
    x_tail_approx = np.array([r_tail(t) for t in t_tail])
    errors_tail = np.abs(x_tail - x_tail_approx)
    
    ax.loglog(p_tail, errors_tail, 'r-', linewidth=1.5)
    ax.axhline(1e-10, color='orange', linestyle='--', label='1e-10')
    ax.set_xlabel('p')
    ax.set_ylabel('|error|')
    ax.set_title(f'Lower Tail Error [1e-10, {CENTRAL_LOW}]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('aaa_ppf.png', dpi=150)
    print(f"\nPlot saved to: aaa_ppf.png")


def main():
    print("="*70)
    print("AAA Algorithm for Inverse CDF (PPF / Quantile Function)")
    print("="*70)
    print(f"\nConfiguration:")
    print(f"  Sample points: {N_SAMPLES}")
    print(f"  AAA tolerance: {AAA_TOLERANCE:.0e}")
    print(f"  Central region: [{CENTRAL_LOW}, {CENTRAL_HIGH}]")
    print(f"  Tail epsilon: {TAIL_EPSILON:.0e}")
    print(f"  Precision: {'mpmath (50 digits)' if HAS_MPMATH else 'scipy (double)'}")
    
    # Analyze each region
    r_central, results_central = analyze_central_region()
    r_tail, results_tail = analyze_lower_tail()
    
    # Test combined approximation
    test_full_domain()
    
    # Generate plots
    plot_results(r_central, r_tail)
    
    # Summary
    print(f"\n{'='*70}")
    print("SUMMARY")
    print("="*70)
    print(f"\nCentral region ({CENTRAL_LOW} ≤ p ≤ {CENTRAL_HIGH}):")
    print(f"  Degree: {results_central['degree']}")
    print(f"  Max error: {results_central['max_error']:.2e}")
    
    print(f"\nLower tail (p < {CENTRAL_LOW}):")
    print(f"  Degree: {results_tail['degree']}")
    print(f"  Max error: {results_tail['max_error']:.2e}")
    print(f"  Transform: t = {results_tail['transform']}")
    
    print(f"\nUpper tail (p > {CENTRAL_HIGH}):")
    print(f"  Uses symmetry: Φ⁻¹(p) = -Φ⁻¹(1-p)")
    
    # Save results
    output_dir = Path(__file__).parent.parent / 'outputs'
    output_dir.mkdir(exist_ok=True)
    
    results = {
        'central': results_central,
        'lower_tail': results_tail,
        'upper_tail': {
            'region': 'upper_tail',
            'method': 'symmetry',
            'formula': 'ppf(p) = -ppf(1-p)'
        },
        'config': {
            'n_samples': N_SAMPLES,
            'aaa_tolerance': AAA_TOLERANCE,
            'central_bounds': [CENTRAL_LOW, CENTRAL_HIGH],
            'tail_epsilon': TAIL_EPSILON,
            'precision': 'mpmath_50' if HAS_MPMATH else 'scipy_double'
        }
    }
    
    with open(output_dir / 'ppf_aaa_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to: {output_dir / 'ppf_aaa_results.json'}")


if __name__ == "__main__":
    main()
