#!/usr/bin/env python3
"""
Step 2: Extract Polynomial Coefficients from AAA Approximation

Converts the barycentric rational form from AAA into explicit P(x)/Q(x)
polynomial coefficients that can be used for Horner evaluation.

Barycentric form:
    R(x) = Σ (w_j * f_j) / (x - z_j)  /  Σ w_j / (x - z_j)

Polynomial form:
    R(x) = P(x) / Q(x)

where:
    P(x) = Σ w_j * f_j * Π_{k≠j}(x - z_k)
    Q(x) = Σ w_j * Π_{k≠j}(x - z_k)

Usage:
    python 02_extract_coefficients.py

Output:
    ../outputs/coefficients.json
"""

import json
import numpy as np
from numpy.polynomial import polynomial as P
from scipy.special import erf
from pathlib import Path

# Try to import baryrat
try:
    from baryrat import aaa
    HAS_BARYRAT = True
except ImportError:
    HAS_BARYRAT = False
    print("ERROR: baryrat not installed. Run: pip install baryrat")
    exit(1)


def barycentric_to_poly(nodes: np.ndarray, weights: np.ndarray, values: np.ndarray):
    """
    Convert barycentric rational to P(x)/Q(x) polynomials.
    
    The barycentric form is:
        R(x) = Σ (w_j * f_j) / (x - z_j)  /  Σ w_j / (x - z_j)
    
    Multiplying numerator and denominator by Π(x - z_k):
        P(x) = Σ w_j * f_j * Π_{k≠j}(x - z_k)
        Q(x) = Σ w_j * Π_{k≠j}(x - z_k)
    
    Args:
        nodes: Support points z_j
        weights: Barycentric weights w_j
        values: Function values f_j = f(z_j)
    
    Returns:
        (p_coeffs, q_coeffs): Polynomial coefficients, lowest degree first
    """
    n = len(nodes)
    
    # Initialize polynomials as zero
    p_poly = np.array([0.0])
    q_poly = np.array([0.0])
    
    for j in range(n):
        # Compute Π_{k≠j}(x - z_k) = product of (x - z_k) for k ≠ j
        # Start with polynomial "1"
        partial = np.array([1.0])
        
        for k in range(n):
            if k != j:
                # Multiply by (x - z_k) = [-z_k, 1] in coefficient form
                partial = P.polymul(partial, np.array([-nodes[k], 1.0]))
        
        # Add w_j * f_j * partial to P(x)
        p_term = weights[j] * values[j] * partial
        p_poly = P.polyadd(p_poly, p_term)
        
        # Add w_j * partial to Q(x)
        q_term = weights[j] * partial
        q_poly = P.polyadd(q_poly, q_term)
    
    return p_poly, q_poly


def validate_conversion(r, p_coeffs, q_coeffs, x_test, tol=1e-12):
    """
    Validate that P(x)/Q(x) matches the original barycentric evaluation.
    
    Args:
        r: Original baryrat AAA approximant
        p_coeffs: Numerator polynomial coefficients
        q_coeffs: Denominator polynomial coefficients
        x_test: Test points
        tol: Maximum allowed difference
    
    Returns:
        (is_valid, max_diff)
    """
    # Evaluate original barycentric form
    r_bary = r(x_test)
    
    # Evaluate P(x)/Q(x)
    p_vals = P.polyval(x_test, p_coeffs)
    q_vals = P.polyval(x_test, q_coeffs)
    r_poly = p_vals / q_vals
    
    # Compare
    diff = np.abs(r_bary - r_poly)
    max_diff = np.max(diff)
    
    is_valid = max_diff < tol
    
    return is_valid, max_diff


def analyze_coefficients(p_coeffs, q_coeffs):
    """Analyze coefficient properties for Move implementation."""
    
    print("\n" + "="*60)
    print("Coefficient Analysis")
    print("="*60)
    
    print(f"\nNumerator P(x): degree {len(p_coeffs) - 1}")
    print(f"  Min coefficient: {np.min(p_coeffs):.6e}")
    print(f"  Max coefficient: {np.max(p_coeffs):.6e}")
    print(f"  Max absolute: {np.max(np.abs(p_coeffs)):.6e}")
    
    print(f"\nDenominator Q(x): degree {len(q_coeffs) - 1}")
    print(f"  Min coefficient: {np.min(q_coeffs):.6e}")
    print(f"  Max coefficient: {np.max(q_coeffs):.6e}")
    print(f"  Max absolute: {np.max(np.abs(q_coeffs)):.6e}")
    
    # Check if Q(0) = 1 (normalized form)
    print(f"\n  Q(0) = {q_coeffs[0]:.6e} (ideally 1.0 for normalized form)")
    
    # Count signs
    p_neg = np.sum(p_coeffs < 0)
    q_neg = np.sum(q_coeffs < 0)
    print(f"\n  Negative coefficients: P has {p_neg}, Q has {q_neg}")


def run_extraction(func_name, func, x_min, x_max, n_points=1000, tol=1e-10):
    """
    Run the full extraction pipeline for a function.
    
    Args:
        func_name: Name for output files
        func: Target function
        x_min, x_max: Domain bounds
        n_points: Number of sample points
        tol: AAA tolerance
    
    Returns:
        Dictionary with coefficients and metadata
    """
    print(f"\n{'='*60}")
    print(f"Extracting coefficients for {func_name}")
    print(f"{'='*60}")
    
    # Sample function
    x = np.linspace(x_min, x_max, n_points)
    f = func(x)
    
    print(f"Domain: [{x_min}, {x_max}]")
    print(f"Sample points: {n_points}")
    
    # Run AAA
    r = aaa(x, f, tol=tol)
    degree = r.degree()
    print(f"AAA degree: {degree}")
    
    # Extract barycentric components
    nodes = r.nodes
    weights = r.weights
    values = r.values
    
    print(f"Barycentric nodes: {len(nodes)}")
    
    # Convert to polynomial form
    print("\nConverting to polynomial form...")
    p_coeffs, q_coeffs = barycentric_to_poly(nodes, weights, values)
    
    print(f"P(x) degree: {len(p_coeffs) - 1}")
    print(f"Q(x) degree: {len(q_coeffs) - 1}")
    
    # Validate conversion
    x_test = np.linspace(x_min, x_max, 10000)
    is_valid, max_diff = validate_conversion(r, p_coeffs, q_coeffs, x_test)
    
    print(f"\nConversion validation:")
    print(f"  Max diff (bary vs poly): {max_diff:.2e}")
    print(f"  Valid (< 1e-12): {'✓ YES' if is_valid else '✗ NO'}")
    
    if not is_valid:
        print("  WARNING: Conversion error too large!")
    
    # Compute error vs true function
    r_poly = P.polyval(x_test, p_coeffs) / P.polyval(x_test, q_coeffs)
    f_true = func(x_test)
    approx_error = np.max(np.abs(r_poly - f_true))
    mean_error = np.mean(np.abs(r_poly - f_true))
    
    print(f"\nApproximation error (vs true function):")
    print(f"  Max error: {approx_error:.2e}")
    print(f"  Mean error: {mean_error:.2e}")
    
    # Analyze coefficients
    analyze_coefficients(p_coeffs, q_coeffs)
    
    # Normalize Q so Q[0] = 1 (optional, for numerical stability)
    # This makes the constant term of denominator = 1
    if abs(q_coeffs[0]) > 1e-15:
        scale = q_coeffs[0]
        p_coeffs_norm = p_coeffs / scale
        q_coeffs_norm = q_coeffs / scale
        print(f"\nNormalized by Q[0] = {scale:.6e}")
        print(f"  New Q[0] = {q_coeffs_norm[0]:.6f}")
    else:
        p_coeffs_norm = p_coeffs
        q_coeffs_norm = q_coeffs
        print("\nQ[0] near zero, skipping normalization")
    
    return {
        'function': func_name,
        'domain': [x_min, x_max],
        'aaa_degree': degree,
        'numerator_degree': len(p_coeffs) - 1,
        'denominator_degree': len(q_coeffs) - 1,
        'p_coefficients': p_coeffs.tolist(),
        'q_coefficients': q_coeffs.tolist(),
        'p_coefficients_normalized': p_coeffs_norm.tolist(),
        'q_coefficients_normalized': q_coeffs_norm.tolist(),
        'normalization_scale': float(q_coeffs[0]),
        'max_error_vs_true': float(approx_error),
        'mean_error_vs_true': float(mean_error),
        'conversion_max_diff': float(max_diff),
        'barycentric': {
            'nodes': nodes.tolist(),
            'weights': weights.tolist(),
            'values': values.tolist()
        }
    }


def main():
    print("="*60)
    print("Step 2: Extract Polynomial Coefficients")
    print("="*60)
    
    # Create outputs directory
    output_dir = Path(__file__).parent.parent / 'outputs'
    output_dir.mkdir(exist_ok=True)
    
    results = {}
    
    # 1. Extract coefficients for erf(x) on [0, 6]
    results['erf'] = run_extraction(
        func_name='erf',
        func=erf,
        x_min=0,
        x_max=6,
        n_points=1000,
        tol=1e-10
    )
    
    # 2. Extract coefficients for erfc(x) on [0, 6]
    from scipy.special import erfc
    results['erfc'] = run_extraction(
        func_name='erfc',
        func=erfc,
        x_min=0,
        x_max=6,
        n_points=1000,
        tol=1e-10
    )
    
    # 3. Extract coefficients for Φ(x) (normal CDF) on [0, 6]
    from scipy.stats import norm
    results['phi'] = run_extraction(
        func_name='phi',
        func=norm.cdf,
        x_min=0,
        x_max=6,
        n_points=1000,
        tol=1e-10
    )
    
    # Save results
    output_file = output_dir / 'coefficients.json'
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n{'='*60}")
    print("Summary")
    print("="*60)
    print(f"\nResults saved to: {output_file}")
    
    for name, data in results.items():
        print(f"\n{name}:")
        print(f"  Degree: P={data['numerator_degree']}, Q={data['denominator_degree']}")
        print(f"  Max error: {data['max_error_vs_true']:.2e}")
        print(f"  Conversion diff: {data['conversion_max_diff']:.2e}")


if __name__ == "__main__":
    main()
