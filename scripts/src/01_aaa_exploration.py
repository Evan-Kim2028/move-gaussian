#!/usr/bin/env python3
"""
AAA Algorithm Exploration for Gaussian/erf Approximation

This script uses the AAA (Adaptive Antoulas-Anderson) algorithm to find
optimal rational approximations for erf and the Gaussian CDF (Φ).

The goal is to discover coefficients offline that can be hardcoded into
a Move smart contract for on-chain evaluation.

Usage:
    pip install numpy scipy baryrat matplotlib
    python aaa_exploration.py

References:
    - AAA Paper: https://arxiv.org/abs/1612.00337
    - baryrat library: https://github.com/c-f-h/baryrat
"""

import numpy as np
from scipy.special import erf, erfc
from scipy.stats import norm
import matplotlib.pyplot as plt

# Try to import baryrat, provide instructions if not available
try:
    from baryrat import aaa
    HAS_BARYRAT = True
except ImportError:
    HAS_BARYRAT = False
    print("baryrat not installed. Install with: pip install baryrat")
    print("Continuing with analysis only...\n")


def sample_function(func, x_min, x_max, n_points=1000):
    """Sample a function on a uniform grid."""
    x = np.linspace(x_min, x_max, n_points)
    f = func(x)
    return x, f


def analyze_aaa_approximation(x, f, func_name, tol=1e-10):
    """
    Run AAA and analyze the resulting rational approximation.
    
    Returns the AAA approximant and analysis results.
    """
    if not HAS_BARYRAT:
        print(f"Skipping AAA for {func_name} (baryrat not installed)")
        return None, None
    
    print(f"\n{'='*60}")
    print(f"AAA Approximation for {func_name}")
    print(f"{'='*60}")
    print(f"Domain: [{x.min():.2f}, {x.max():.2f}]")
    print(f"Sample points: {len(x)}")
    print(f"Tolerance: {tol}")
    
    # Run AAA
    r = aaa(x, f, tol=tol)
    
    # Analyze the result
    degree = r.degree()
    print(f"\nResult:")
    print(f"  Degree (num/denom): {degree}")
    print(f"  Number of nodes: {len(r.nodes)}")
    
    # Compute errors
    r_vals = r(x)
    errors = np.abs(f - r_vals)
    max_error = np.max(errors)
    mean_error = np.mean(errors)
    
    print(f"\nError Analysis:")
    print(f"  Max absolute error: {max_error:.2e}")
    print(f"  Mean absolute error: {mean_error:.2e}")
    
    # Check for poles on real axis
    poles = r.poles()
    real_poles = poles[np.abs(poles.imag) < 1e-10]
    poles_in_domain = real_poles[(real_poles.real >= x.min()) & (real_poles.real <= x.max())]
    
    print(f"\nPole Analysis:")
    print(f"  Total poles: {len(poles)}")
    print(f"  Real poles: {len(real_poles)}")
    print(f"  Poles in domain: {len(poles_in_domain)}")
    
    if len(poles_in_domain) > 0:
        print(f"  WARNING: Poles found in domain at: {poles_in_domain}")
    else:
        print(f"  ✓ No poles in domain (safe for evaluation)")
    
    # Show pole locations
    print(f"\n  Pole locations (complex):")
    for i, p in enumerate(poles):
        print(f"    {i+1}: {p.real:.4f} + {p.imag:.4f}i")
    
    # Check output bounds (for CDF-like functions)
    r_min, r_max = np.min(r_vals), np.max(r_vals)
    print(f"\nOutput Range:")
    print(f"  Approximation range: [{r_min:.6f}, {r_max:.6f}]")
    print(f"  True function range: [{np.min(f):.6f}, {np.max(f):.6f}]")
    
    return r, {
        'degree': degree,
        'max_error': max_error,
        'mean_error': mean_error,
        'n_poles': len(poles),
        'poles_in_domain': len(poles_in_domain),
        'nodes': r.nodes,
        'weights': r.weights,
        'values': r.values,
    }


def extract_rational_coefficients(r):
    """
    Extract P(x)/Q(x) polynomial coefficients from AAA approximant.
    
    This is what we'd hardcode into the Move contract.
    """
    if r is None:
        return None, None
    
    # Get poles, residues, and zeros
    poles = r.poles()
    zeros = r.zeros()
    
    print(f"\nCoefficient Extraction:")
    print(f"  Number of poles: {len(poles)}")
    print(f"  Number of zeros: {len(zeros)}")
    
    # Get numerator and denominator as polynomial objects
    # These can be evaluated directly
    num_poly = r.numerator()
    denom_poly = r.denominator()
    
    print(f"\n  Numerator polynomial coefficients (lowest degree first):")
    print(f"  {num_poly}")
    print(f"\n  Denominator polynomial coefficients (lowest degree first):")
    print(f"  {denom_poly}")
    
    # Barycentric form (alternative representation)
    print(f"\n  Barycentric form:")
    print(f"  Nodes: {r.nodes}")
    print(f"  Weights: {r.weights}")
    print(f"  Values at nodes: {r.values}")
    
    return r.nodes, r.weights


def compare_with_solgauss():
    """
    Compare AAA result with solgauss's (11,4) rational approximation.
    
    solgauss uses a degree (11,4) rational polynomial for erfc.
    Let's see what degree AAA chooses for similar accuracy.
    """
    print(f"\n{'='*60}")
    print(f"Comparison with solgauss")
    print(f"{'='*60}")
    print(f"solgauss uses: (11,4) rational polynomial for erfc")
    print(f"solgauss error: < 1e-8")
    print(f"solgauss gas (CDF): 519-833")
    print(f"\nLet's see what AAA finds for similar accuracy...")


def plot_results(x, f, r, func_name):
    """Plot the function, approximation, and error."""
    if r is None:
        return
    
    fig, axes = plt.subplots(2, 1, figsize=(10, 8))
    
    # Plot function and approximation
    axes[0].plot(x, f, 'b-', label=f'True {func_name}', linewidth=2)
    axes[0].plot(x, r(x), 'r--', label='AAA approximation', linewidth=1.5)
    axes[0].set_xlabel('x')
    axes[0].set_ylabel('y')
    axes[0].set_title(f'{func_name} and AAA Rational Approximation')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    # Plot error
    errors = np.abs(f - r(x))
    axes[1].semilogy(x, errors, 'g-', linewidth=1.5)
    axes[1].set_xlabel('x')
    axes[1].set_ylabel('|error|')
    axes[1].set_title('Absolute Error (log scale)')
    axes[1].grid(True, alpha=0.3)
    axes[1].axhline(y=1e-8, color='r', linestyle='--', label='solgauss target (1e-8)')
    axes[1].legend()
    
    plt.tight_layout()
    plt.savefig(f'aaa_{func_name.lower().replace(" ", "_")}.png', dpi=150)
    print(f"\nPlot saved to: aaa_{func_name.lower().replace(' ', '_')}.png")


def main():
    print("AAA Algorithm Exploration for Gaussian/erf Approximation")
    print("="*60)
    
    # 1. Approximate erf(x) on [0, 6]
    # We use [0, 6] because erf(6) ≈ 1 - 2e-17 (essentially 1)
    x_erf, f_erf = sample_function(erf, 0, 6, n_points=1000)
    r_erf, results_erf = analyze_aaa_approximation(x_erf, f_erf, "erf(x)", tol=1e-10)
    
    # 2. Approximate erfc(x) on [0, 6]
    # erfc is what solgauss approximates directly
    x_erfc, f_erfc = sample_function(erfc, 0, 6, n_points=1000)
    r_erfc, results_erfc = analyze_aaa_approximation(x_erfc, f_erfc, "erfc(x)", tol=1e-10)
    
    # 3. Approximate standard normal CDF Φ(x) on [0, 6]
    # Φ(x) = 0.5 * erfc(-x/√2) = 0.5 * (1 + erf(x/√2))
    phi = lambda x: norm.cdf(x)
    x_phi, f_phi = sample_function(phi, 0, 6, n_points=1000)
    r_phi, results_phi = analyze_aaa_approximation(x_phi, f_phi, "Φ(x) (normal CDF)", tol=1e-10)
    
    # 4. Compare with solgauss
    compare_with_solgauss()
    
    # 5. Extract coefficients (for Move implementation)
    if r_erf is not None:
        print(f"\n{'='*60}")
        print("Coefficient Extraction for Move Implementation")
        print(f"{'='*60}")
        extract_rational_coefficients(r_erf)
    
    # 6. Plot results
    if HAS_BARYRAT:
        plot_results(x_erf, f_erf, r_erf, "erf")
        plot_results(x_erfc, f_erfc, r_erfc, "erfc")
        plot_results(x_phi, f_phi, r_phi, "Phi")
    
    # Summary
    print(f"\n{'='*60}")
    print("Summary")
    print(f"{'='*60}")
    if results_erf:
        print(f"erf:  degree={results_erf['degree']}, max_error={results_erf['max_error']:.2e}")
    if results_erfc:
        print(f"erfc: degree={results_erfc['degree']}, max_error={results_erfc['max_error']:.2e}")
    if results_phi:
        print(f"Φ:    degree={results_phi['degree']}, max_error={results_phi['max_error']:.2e}")
    
    print(f"\nNext steps:")
    print(f"1. Convert barycentric form to P(x)/Q(x) polynomial form")
    print(f"2. Scale coefficients for fixed-point (1e18 WAD)")
    print(f"3. Implement Horner evaluation in Move")
    print(f"4. Verify monotonicity and bounds")


if __name__ == "__main__":
    main()
