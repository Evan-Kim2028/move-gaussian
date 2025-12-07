#!/usr/bin/env python3
"""
AAA Algorithm for Direct Standard Normal PDF Approximation

Goal: Fit a high-precision rational approximation for φ(z) directly, instead
of deriving it numerically from the CDF / PPF results. The resulting rational
can be exported to Move for fast PDF evaluation without differentiating the
CDF polynomial.

Workflow:
1. Sample φ(z) over z ∈ [-MAX_Z, MAX_Z] with extra density near z = 0.
2. Run the AAA algorithm (via baryrat) to obtain a rational approximation.
3. Validate accuracy on a dense grid.
4. Persist barycentric data for later conversion to Horner-ready polynomials.
5. Generate diagnostic plots.

Usage:
    python 01c_aaa_pdf.py

Output:
    - plots/aaa_pdf.png
    - outputs/pdf_aaa_results.json
"""

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

# High-precision math helpers
try:
    from mpmath import mp
    mp.dps = 50
    HAS_MPMATH = True
except ImportError:
    HAS_MPMATH = False
    print("WARNING: mpmath not installed - falling back to scipy (double precision)")

from scipy.stats import norm

# AAA implementation
try:
    from baryrat import aaa
    HAS_BARYRAT = True
except ImportError:
    HAS_BARYRAT = False
    print("ERROR: baryrat not installed. Run: pip install baryrat")
    raise SystemExit(1)


# =============================================================================
# Configuration
# =============================================================================

N_SAMPLES = 2000
AAA_TOLERANCE = 1e-13
MAX_Z = 6.0


# =============================================================================
# Helpers
# =============================================================================

def pdf_mpmath(z: float) -> float:
    """High-precision standard normal PDF φ(z)."""
    if not HAS_MPMATH:
        return float(norm.pdf(z))
    z_mp = mp.mpf(str(z))
    const = 1 / mp.sqrt(2 * mp.pi)
    return float(const * mp.e**(-0.5 * z_mp * z_mp))


def pdf_mpmath_array(z_values: np.ndarray) -> np.ndarray:
    """Vectorized helper for φ(z)."""
    return np.array([pdf_mpmath(z) for z in z_values])


def build_sampling_grid() -> np.ndarray:
    """Create sampling grid with extra density around zero and the tails."""
    coarse = np.linspace(-MAX_Z, MAX_Z, N_SAMPLES, endpoint=True)
    center = np.linspace(-0.25, 0.25, 400, endpoint=True)
    mid = np.linspace(-3.0, 3.0, 800, endpoint=True)
    grid = np.unique(np.concatenate([coarse, center, mid]))
    grid.sort()
    return grid


def run_aaa_pdf():
    """Run AAA fitting for φ(z) across the entire domain."""
    print("\n" + "=" * 70)
    print("AAA Approximation for Standard Normal PDF")
    print("=" * 70)
    print(f"Domain: [-{MAX_Z}, {MAX_Z}]")
    print(f"Samples: ~{N_SAMPLES}")
    print(f"Precision: {'mpmath (50 digits)' if HAS_MPMATH else 'scipy (double)'}")
    print(f"AAA tolerance: {AAA_TOLERANCE:.0e}")

    z = build_sampling_grid()
    phi = pdf_mpmath_array(z)

    r = aaa(z, phi, tol=AAA_TOLERANCE)
    degree = r.degree()

    print(f"\nAAA Result:")
    print(f"  Degree: {degree}")
    print(f"  Nodes: {len(r.nodes)}")

    phi_approx = r(z)
    abs_err = np.abs(phi - phi_approx)

    print(f"\nError (sample grid):")
    print(f"  Max error: {abs_err.max():.2e}")
    print(f"  Mean error: {abs_err.mean():.2e}")

    z_dense = np.linspace(-MAX_Z, MAX_Z, 20000)
    phi_dense = pdf_mpmath_array(z_dense)
    phi_dense_approx = r(z_dense)
    dense_err = np.abs(phi_dense - phi_dense_approx)

    print(f"\nValidation (dense grid, 20k points):")
    print(f"  Max error: {dense_err.max():.2e}")
    print(f"  Mean error: {dense_err.mean():.2e}")
    print(f"  P99 error: {np.percentile(dense_err, 99):.2e}")

    poles = r.poles()
    real_poles = poles[np.abs(poles.imag) < 1e-10]
    poles_in_domain = real_poles[(real_poles.real >= -MAX_Z) & (real_poles.real <= MAX_Z)]
    print(f"\nPole analysis:")
    print(f"  Total poles: {len(poles)}")
    print(f"  Poles in domain: {len(poles_in_domain)}")

    return r, {
        'region': 'full',
        'domain': [-MAX_Z, MAX_Z],
        'degree': degree,
        'max_error': float(dense_err.max()),
        'mean_error': float(dense_err.mean()),
        'p99_error': float(np.percentile(dense_err, 99)),
        'nodes': r.nodes.tolist(),
        'weights': r.weights.tolist(),
        'values': r.values.tolist(),
    }, (z_dense, phi_dense, phi_dense_approx)


def plot_pdf_results(z_dense, phi_true, phi_approx):
    """Generate diagnostic plots for the PDF approximation."""
    abs_err = np.abs(phi_true - phi_approx)

    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    axes[0].plot(z_dense, phi_true, label='True φ(z)', linewidth=2)
    axes[0].plot(z_dense, phi_approx, '--', label='AAA approx', linewidth=1.5)
    axes[0].set_xlabel('z')
    axes[0].set_ylabel('φ(z)')
    axes[0].set_title('Standard Normal PDF')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)

    axes[1].semilogy(z_dense, abs_err, color='purple', linewidth=1.5)
    axes[1].axhline(1e-12, color='orange', linestyle='--', label='1e-12')
    axes[1].set_xlabel('z')
    axes[1].set_ylabel('|error|')
    axes[1].set_title('Absolute Error')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('aaa_pdf.png', dpi=150)
    print("Plot saved to: aaa_pdf.png")


def main():
    print("=" * 70)
    print("AAA Rational Fitting for Standard Normal PDF")
    print("=" * 70)

    r_pdf, pdf_results, dense_data = run_aaa_pdf()
    plot_pdf_results(*dense_data)

    output_dir = Path(__file__).parent.parent / 'outputs'
    output_dir.mkdir(exist_ok=True)

    results = {
        'pdf': pdf_results,
        'config': {
            'n_samples': N_SAMPLES,
            'aaa_tolerance': AAA_TOLERANCE,
            'max_z': MAX_Z,
            'precision': 'mpmath_50' if HAS_MPMATH else 'scipy_double'
        }
    }

    with open(output_dir / 'pdf_aaa_results.json', 'w') as f:
        json.dump(results, f, indent=2)

    print(f"Results saved to: {output_dir / 'pdf_aaa_results.json'}")


if __name__ == "__main__":
    main()
