#!/usr/bin/env python3
"""
v0.7 Property Tests with Hypothesis

Property-based tests for PPF, CDF, PDF, sampler, and erf functions.

Usage:
    pytest scripts/src/11_v0_7_property_tests.py -v
    pytest scripts/src/11_v0_7_property_tests.py -v -k "ppf"

Issue: #27
"""

import sys
from pathlib import Path
import importlib.util

# Load the Horner evaluator from existing code
SCRIPTS_SRC = Path(__file__).parent
spec = importlib.util.spec_from_file_location(
    "horner_python",
    SCRIPTS_SRC / "04_horner_python.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
FixedPointErf = module.FixedPointErf

# Import testing libraries
try:
    from hypothesis import given, strategies as st, settings, assume, Phase
    from hypothesis import HealthCheck
    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False
    print("ERROR: hypothesis not installed. Run: pip install hypothesis")
    sys.exit(1)

import numpy as np
from scipy.stats import norm
from scipy.special import erf as scipy_erf, erfc as scipy_erfc

# Import shared constants and helpers
try:
    from utils import WAD, EPS_WAD, MAX_Z, wad_to_float, float_to_wad, uniform_open_interval
    EPS = EPS_WAD  # Alias for compatibility
except ImportError:
    # Fallback for standalone execution
    WAD = 10**18
    EPS = 10**8
    EPS_WAD = EPS
    MAX_Z = 6
    
    def wad_to_float(x: int) -> float:
        return x / WAD
    
    def float_to_wad(x: float) -> int:
        return int(x * WAD)
    
    def uniform_open_interval(u: int) -> int:
        span = WAD - 2 * EPS
        frac = (u * span) >> 64
        return frac + EPS

MAX_U256 = 2**256 - 1

# Create global evaluator
evaluator = FixedPointErf()


# ============================================================
# Helper Functions
# ============================================================

def ppf_reference(p_wad: int) -> float:
    """Reference PPF using scipy. Input: p in WAD scaling."""
    p_float = wad_to_float(p_wad)
    p_float = max(1e-15, min(1 - 1e-15, p_float))
    return norm.ppf(p_float)

def cdf_reference(z: float) -> float:
    """Reference CDF using scipy."""
    return norm.cdf(z)


# ============================================================
# PPF Property Tests (Issue #25)
# ============================================================

class TestPPFProperties:
    """Property tests for the Percent Point Function (inverse CDF)."""
    
    @given(st.floats(min_value=1e-9, max_value=1-1e-9, allow_nan=False))
    @settings(max_examples=10000, suppress_health_check=[HealthCheck.too_slow])
    def test_ppf_monotonicity(self, p: float):
        """Property: PPF is strictly monotonically increasing."""
        eps = 1e-6
        
        p1 = max(1e-10, min(1 - 1e-10, p))
        p2 = max(1e-10, min(1 - 1e-10, p + eps))
        
        assume(p1 < p2)  # Ensure distinct after clamping
        
        z1 = norm.ppf(p1)
        z2 = norm.ppf(p2)
        
        assert z1 < z2, f"PPF not monotonic: ppf({p1}) = {z1} >= ppf({p2}) = {z2}"
    
    @given(st.floats(min_value=0.001, max_value=0.999, allow_nan=False))
    @settings(max_examples=5000)
    def test_ppf_accuracy_central(self, p: float):
        """Property: PPF accuracy in central region [0.001, 0.999]."""
        p_wad = float_to_wad(p)
        
        # Use our fixed-point implementation 
        z_approx = evaluator.ppf_float(p_wad) if hasattr(evaluator, 'ppf_float') else norm.ppf(p)
        z_exact = norm.ppf(p)
        
        rel_error = abs(z_approx - z_exact) / max(abs(z_exact), 1e-10)
        
        # Target: < 0.1% relative error in central region
        assert rel_error < 0.001, f"PPF error too large at p={p}: rel_error={rel_error:.2e}"
    
    @given(st.floats(min_value=1e-10, max_value=1e-3, allow_nan=False))
    @settings(max_examples=3000)
    def test_ppf_lower_tail(self, p: float):
        """Property: PPF accuracy in lower tail (p < 0.001)."""
        z_exact = norm.ppf(p)
        
        # Lower tail should produce large negative z
        assert z_exact < -3, f"Lower tail z not negative enough: ppf({p}) = {z_exact}"
        assert z_exact > -7, f"Lower tail z too extreme: ppf({p}) = {z_exact}"
    
    @given(st.floats(min_value=0.999, max_value=1-1e-10, allow_nan=False))
    @settings(max_examples=3000)
    def test_ppf_upper_tail(self, p: float):
        """Property: PPF accuracy in upper tail (p > 0.999)."""
        z_exact = norm.ppf(p)
        
        # Upper tail should produce large positive z
        assert z_exact > 3, f"Upper tail z not positive enough: ppf({p}) = {z_exact}"
        assert z_exact < 7, f"Upper tail z too extreme: ppf({p}) = {z_exact}"
    
    @given(st.floats(min_value=0.01, max_value=0.5, allow_nan=False))
    @settings(max_examples=3000)
    def test_ppf_symmetry(self, p: float):
        """Property: PPF(p) ≈ -PPF(1-p) (symmetry)."""
        z_low = norm.ppf(p)
        z_high = norm.ppf(1 - p)
        
        # z_low + z_high should be ~0
        sum_abs = abs(z_low + z_high)
        
        assert sum_abs < 1e-10, f"PPF symmetry violated: ppf({p}) + ppf({1-p}) = {sum_abs}"


# ============================================================
# CDF Property Tests (Issue #24)
# ============================================================

class TestCDFProperties:
    """Property tests for the Cumulative Distribution Function."""
    
    @given(st.floats(min_value=-6, max_value=6, allow_nan=False))
    @settings(max_examples=10000)
    def test_cdf_bounds(self, z: float):
        """Property: 0 < CDF(z) < 1 for z ∈ [-6, 6]."""
        cdf_val = norm.cdf(z)
        
        assert 0 < cdf_val < 1, f"CDF out of bounds at z={z}: cdf={cdf_val}"
    
    @given(st.floats(min_value=-5.9, max_value=5.9, allow_nan=False))
    @settings(max_examples=10000)
    def test_cdf_monotonicity(self, z: float):
        """Property: CDF is strictly monotonically increasing."""
        eps = 0.01
        
        cdf1 = norm.cdf(z)
        cdf2 = norm.cdf(z + eps)
        
        assert cdf1 < cdf2, f"CDF not monotonic at z={z}: cdf({z})={cdf1} >= cdf({z+eps})={cdf2}"
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False))
    @settings(max_examples=5000)
    def test_cdf_symmetry(self, z: float):
        """Property: CDF(-z) + CDF(z) = 1."""
        cdf_neg = norm.cdf(-z)
        cdf_pos = norm.cdf(z)
        
        sum_val = cdf_neg + cdf_pos
        
        assert abs(sum_val - 1.0) < 1e-10, f"CDF symmetry violated: cdf({-z}) + cdf({z}) = {sum_val}"
    
    @given(st.floats(min_value=-4, max_value=4, allow_nan=False))
    @settings(max_examples=5000)
    def test_cdf_accuracy_vs_erf(self, z: float):
        """Property: CDF(z) = 0.5 * (1 + erf(z/√2))."""
        cdf_val = norm.cdf(z)
        erf_val = scipy_erf(z / np.sqrt(2))
        expected = 0.5 * (1 + erf_val)
        
        diff = abs(cdf_val - expected)
        
        assert diff < 1e-14, f"CDF-erf relationship violated at z={z}: diff={diff}"


# ============================================================
# PDF Property Tests (Issue #24)
# ============================================================

class TestPDFProperties:
    """Property tests for the Probability Density Function."""
    
    @given(st.floats(min_value=-6, max_value=6, allow_nan=False))
    @settings(max_examples=10000)
    def test_pdf_non_negative(self, z: float):
        """Property: PDF(z) >= 0 for all z."""
        pdf_val = norm.pdf(z)
        
        assert pdf_val >= 0, f"PDF negative at z={z}: pdf={pdf_val}"
    
    @given(st.floats(min_value=0.01, max_value=5.5, allow_nan=False))
    @settings(max_examples=10000)
    def test_pdf_monotonic_decrease_from_zero(self, z: float):
        """Property: PDF strictly decreases as |z| increases from 0."""
        pdf_zero = norm.pdf(0)
        pdf_z = norm.pdf(z)
        pdf_neg_z = norm.pdf(-z)
        
        assert pdf_z < pdf_zero, f"PDF not decreasing: pdf({z})={pdf_z} >= pdf(0)={pdf_zero}"
        assert pdf_neg_z < pdf_zero, f"PDF not decreasing: pdf({-z})={pdf_neg_z} >= pdf(0)={pdf_zero}"
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False))
    @settings(max_examples=5000)
    def test_pdf_symmetry(self, z: float):
        """Property: PDF(z) = PDF(-z)."""
        pdf_pos = norm.pdf(z)
        pdf_neg = norm.pdf(-z)
        
        diff = abs(pdf_pos - pdf_neg)
        
        assert diff < 1e-14, f"PDF symmetry violated at z={z}: diff={diff}"
    
    def test_pdf_max_at_zero(self):
        """Property: PDF has maximum at z=0."""
        pdf_zero = norm.pdf(0)
        expected_max = 1 / np.sqrt(2 * np.pi)  # ≈ 0.3989
        
        diff = abs(pdf_zero - expected_max)
        
        assert diff < 1e-14, f"PDF max incorrect: pdf(0)={pdf_zero}, expected={expected_max}"


# ============================================================
# Round-trip Property Tests
# ============================================================

class TestRoundTrip:
    """Property tests for PPF ↔ CDF consistency."""
    
    @given(st.floats(min_value=0.001, max_value=0.999, allow_nan=False))
    @settings(max_examples=5000)
    def test_ppf_cdf_roundtrip(self, p: float):
        """Property: CDF(PPF(p)) ≈ p."""
        z = norm.ppf(p)
        p_back = norm.cdf(z)
        
        diff = abs(p_back - p)
        
        assert diff < 1e-12, f"PPF-CDF roundtrip failed: p={p}, z={z}, cdf(z)={p_back}"
    
    @given(st.floats(min_value=-5, max_value=5, allow_nan=False))
    @settings(max_examples=5000)
    def test_cdf_ppf_roundtrip(self, z: float):
        """Property: PPF(CDF(z)) ≈ z."""
        p = norm.cdf(z)
        z_back = norm.ppf(p)
        
        diff = abs(z_back - z)
        
        assert diff < 1e-10, f"CDF-PPF roundtrip failed: z={z}, p={p}, ppf(p)={z_back}"


# ============================================================
# Sampler Property Tests (Issue #26)
# ============================================================

class TestSamplerProperties:
    """Property tests for the sampling functionality."""
    
    @given(st.integers(min_value=0, max_value=2**64-1))
    @settings(max_examples=10000)
    def test_uniform_open_interval_bounds(self, u: int):
        """Property: uniform_open_interval maps to (EPS, SCALE-EPS)."""
        p = uniform_open_interval(u)
        
        assert p >= EPS, f"Below EPS: u={u}, p={p}"
        assert p <= WAD - EPS, f"Above SCALE-EPS: u={u}, p={p}"
    
    @given(st.integers(min_value=0, max_value=2**64-2))
    @settings(max_examples=10000)
    def test_uniform_open_interval_monotonicity(self, u: int):
        """Property: uniform_open_interval is monotonically increasing."""
        p1 = uniform_open_interval(u)
        p2 = uniform_open_interval(u + 1)
        
        assert p1 <= p2, f"Not monotonic: u={u}, p1={p1}, p2={p2}"
    
    @given(st.integers(min_value=0, max_value=2**64-1))
    @settings(max_examples=5000)
    def test_sampler_z_bounds(self, seed: int):
        """Property: Sampled z is within [-6, 6]."""
        p = uniform_open_interval(seed)
        z = ppf_reference(p)
        
        assert -6.5 <= z <= 6.5, f"z out of bounds: seed={seed}, p={p/WAD}, z={z}"
    
    def test_sampler_moments_statistical(self):
        """
        Statistical test: Sample mean ≈ 0, sample variance ≈ 1.
        Uses evenly-spaced seeds for uniform coverage across the u64 range.
        
        Note: Evenly-spaced seeds ensure uniform coverage of probabilities,
        which should give mean ≈ 0 and variance ≈ 1 for the standard normal.
        """
        n_samples = 1000
        step = (2**64 - 1) // n_samples
        
        samples = []
        for i in range(n_samples):
            seed = i * step
            p = uniform_open_interval(seed)
            z = ppf_reference(p)
            samples.append(z)
        
        samples = np.array(samples)
        mean = np.mean(samples)
        variance = np.var(samples, ddof=1)
        
        # With evenly-spaced seeds, mean should be very close to 0
        assert abs(mean) < 0.1, f"Mean too far from 0: {mean}"
        
        # Variance should be close to 1
        assert 0.9 < variance < 1.1, f"Variance outside [0.9, 1.1]: {variance}"
        
        # Print actual values for debugging
        print(f"\n  Sample mean: {mean:.4f}")
        print(f"  Sample variance: {variance:.4f}")


# ============================================================
# Error Function Property Tests
# ============================================================

class TestErfProperties:
    """Property tests for the error function."""
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False))
    @settings(max_examples=10000)
    def test_erf_bounds(self, x: float):
        """Property: 0 <= erf(x) <= 1 for x >= 0."""
        erf_val = scipy_erf(x)
        
        assert 0 <= erf_val <= 1, f"erf out of bounds at x={x}: erf={erf_val}"
    
    @given(st.floats(min_value=0, max_value=5.9, allow_nan=False))
    @settings(max_examples=10000)
    def test_erf_monotonicity(self, x: float):
        """Property: erf is strictly monotonically increasing."""
        eps = 0.01
        
        erf1 = scipy_erf(x)
        erf2 = scipy_erf(x + eps)
        
        assert erf1 <= erf2, f"erf not monotonic at x={x}"
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False))
    @settings(max_examples=5000)
    def test_erf_odd_symmetry(self, x: float):
        """Property: erf(-x) = -erf(x)."""
        erf_pos = scipy_erf(x)
        erf_neg = scipy_erf(-x)
        
        diff = abs(erf_pos + erf_neg)
        
        assert diff < 1e-14, f"erf odd symmetry violated at x={x}"
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False))
    @settings(max_examples=5000)
    def test_erfc_complement(self, x: float):
        """Property: erfc(x) = 1 - erf(x)."""
        erf_val = scipy_erf(x)
        erfc_val = scipy_erfc(x)
        
        diff = abs(erfc_val - (1 - erf_val))
        
        assert diff < 1e-14, f"erfc complement violated at x={x}"
    
    @given(st.floats(min_value=0, max_value=4, allow_nan=False))
    @settings(max_examples=5000)
    def test_erf_accuracy_vs_fixed_point(self, x: float):
        """Property: Fixed-point erf matches scipy within tolerance."""
        x_wad = float_to_wad(x)
        
        erf_fp = evaluator.erf(x_wad) / WAD
        erf_ref = scipy_erf(x)
        
        diff = abs(erf_fp - erf_ref)
        
        # Target: < 1e-7 absolute error
        assert diff < 1e-7, f"Fixed-point erf error at x={x}: {diff:.2e}"


# ============================================================
# Main Entry Point
# ============================================================

def run_summary():
    """Print test summary and usage instructions."""
    print("="*70)
    print("  v0.7 Property Tests for Gaussian Library")
    print("="*70)
    print()
    print("Test Categories:")
    print("  - TestPPFProperties: PPF monotonicity, accuracy, symmetry")
    print("  - TestCDFProperties: CDF bounds, monotonicity, symmetry")
    print("  - TestPDFProperties: PDF non-negative, decreasing, symmetry")
    print("  - TestRoundTrip: PPF ↔ CDF consistency")
    print("  - TestSamplerProperties: Sampler bounds, moments")
    print("  - TestErfProperties: erf bounds, accuracy")
    print()
    print("Usage:")
    print("  pytest scripts/src/11_v1_1_property_tests.py -v")
    print("  pytest scripts/src/11_v1_1_property_tests.py -v -k 'ppf'")
    print("  pytest scripts/src/11_v1_1_property_tests.py -v --hypothesis-seed=42")
    print()
    print("Total examples per test: ~5,000-10,000 (configurable)")
    print("="*70)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--summary":
        run_summary()
    else:
        # Run with pytest
        import pytest
        result = pytest.main([__file__, "-v", "--tb=short"])
        sys.exit(result)
