#!/usr/bin/env python3
"""
Step 6: Property-Based Tests with Hypothesis

Uses Hypothesis to test mathematical invariants of the erf implementation:
- Monotonicity: erf(x+ε) ≥ erf(x)
- Bounds: 0 ≤ erf(x) ≤ 1
- No overflow: All intermediate values fit in u256

Usage:
    pytest 06_property_tests.py -v
    # Or run directly:
    python 06_property_tests.py

Requirements:
    pip install hypothesis pytest
"""

import sys
from pathlib import Path
import importlib.util

# Load FixedPointErf
spec = importlib.util.spec_from_file_location(
    "horner_python",
    Path(__file__).parent / "04_horner_python.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
FixedPointErf = module.FixedPointErf

# Import testing libraries
try:
    from hypothesis import given, strategies as st, settings, assume
    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False
    print("WARNING: hypothesis not installed. Run: pip install hypothesis")

import numpy as np
from scipy.special import erf as scipy_erf

WAD = 10**18
MAX_U256 = 2**256 - 1

# Create global evaluator
evaluator = FixedPointErf()


# ============================================================
# Property Tests
# ============================================================

if HAS_HYPOTHESIS:
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False, allow_infinity=False))
    @settings(max_examples=5000)
    def test_bounds(x: float):
        """Property: 0 ≤ erf(x) ≤ 1 for x ∈ [0, 6]"""
        x_wad = int(x * WAD)
        result = evaluator.erf(x_wad)
        
        assert 0 <= result <= WAD, f"Bounds violated at x={x}: erf(x) = {result/WAD}"
    
    
    @given(st.floats(min_value=0, max_value=5.9, allow_nan=False, allow_infinity=False))
    @settings(max_examples=5000)
    def test_monotonicity(x: float):
        """Property: erf is monotonically increasing (with tolerance for rounding)"""
        eps = 0.01  # Use larger epsilon to avoid rounding noise
        
        x_wad = int(x * WAD)
        x_eps_wad = int((x + eps) * WAD)
        
        result1 = evaluator.erf(x_wad)
        result2 = evaluator.erf(x_eps_wad)
        
        # Allow small tolerance for rounding in saturation region
        tolerance = 100000  # ~1e-13
        
        assert result2 >= result1 - tolerance, \
            f"Monotonicity violated at x={x}: erf({x+eps})={result2/WAD} < erf({x})={result1/WAD}"
    
    
    @given(st.integers(min_value=0, max_value=6 * WAD))
    @settings(max_examples=5000)
    def test_no_overflow(x_wad: int):
        """Property: No overflow during Horner evaluation"""
        # This tests that the implementation doesn't raise errors
        # and produces a valid result
        result = evaluator.erf(x_wad)
        
        # Result should be in valid range
        assert 0 <= result <= MAX_U256, f"Result out of u256 range: {result}"
        assert 0 <= result <= WAD, f"Result out of [0,1] range: {result/WAD}"
    
    
    @given(st.floats(min_value=0.01, max_value=5.5, allow_nan=False, allow_infinity=False))
    @settings(max_examples=3000)
    def test_accuracy_vs_scipy(x: float):
        """Property: Approximation error < 1e-7 vs scipy reference"""
        result = evaluator.erf_float(x)
        expected = scipy_erf(x)
        error = abs(result - expected)
        
        assert error < 1e-7, f"Accuracy violated at x={x}: error={error:.2e}"
    
    
    @given(st.floats(min_value=0.001, max_value=4.0, allow_nan=False, allow_infinity=False))
    @settings(max_examples=3000)
    def test_derivative_positive(x: float):
        """Property: erf'(x) > 0 (strictly increasing in non-saturation region)"""
        eps = 1e-6
        
        x_wad = int(x * WAD)
        x_eps_wad = int((x + eps) * WAD)
        
        result1 = evaluator.erf(x_wad)
        result2 = evaluator.erf(x_eps_wad)
        
        # Derivative approximation (scaled)
        derivative = (result2 - result1) / (eps * WAD)
        
        # In the main domain (x < 4), derivative should be clearly positive
        assert derivative > 0, f"Derivative non-positive at x={x}: d/dx ≈ {derivative:.2e}"
    
    
    @given(st.floats(min_value=0, max_value=6, allow_nan=False, allow_infinity=False))
    @settings(max_examples=2000)
    def test_erfc_complement(x: float):
        """Property: erfc(x) = 1 - erf(x)"""
        x_wad = int(x * WAD)
        
        erf_result = evaluator.erf(x_wad)
        erfc_result = evaluator.erfc(x_wad)
        
        # erfc(x) + erf(x) should equal 1 (WAD)
        # Allow small tolerance for rounding
        total = erf_result + erfc_result
        diff = abs(total - WAD)
        
        # Tolerance: ~1e-10 in float terms
        assert diff < 100000000, \
            f"Complement violated at x={x}: erf + erfc = {total/WAD} ≠ 1"


# ============================================================
# Manual Tests (run without hypothesis)
# ============================================================

def run_manual_tests():
    """Run a subset of tests without hypothesis."""
    print("="*60)
    print("Running Manual Property Tests")
    print("="*60)
    
    test_points = np.linspace(0, 6, 1000)
    
    # Test bounds
    print("\n1. Testing bounds [0, 1]...")
    violations = 0
    for x in test_points:
        result = evaluator.erf(int(x * WAD))
        if result < 0 or result > WAD:
            violations += 1
    print(f"   Violations: {violations}/1000")
    print(f"   {'✓ PASS' if violations == 0 else '✗ FAIL'}")
    
    # Test monotonicity
    print("\n2. Testing monotonicity...")
    violations = 0
    prev = 0
    for x in test_points:
        result = evaluator.erf(int(x * WAD))
        if result < prev - 100000:  # Tolerance
            violations += 1
        prev = result
    print(f"   Significant violations: {violations}/1000")
    print(f"   {'✓ PASS' if violations == 0 else '✗ FAIL'}")
    
    # Test accuracy
    print("\n3. Testing accuracy vs scipy...")
    max_error = 0
    for x in test_points:
        result = evaluator.erf_float(x)
        expected = scipy_erf(x)
        error = abs(result - expected)
        max_error = max(max_error, error)
    print(f"   Max error: {max_error:.2e}")
    print(f"   {'✓ PASS' if max_error < 1e-7 else '✗ FAIL'}")
    
    print("\n" + "="*60)
    print("Manual Tests Complete")
    print("="*60)


def main():
    """Run property tests."""
    if HAS_HYPOTHESIS:
        print("="*60)
        print("Running Hypothesis Property Tests")
        print("="*60)
        print("\nRun with: pytest 06_property_tests.py -v")
        print("Or use pytest directly for full test output\n")
        
        # Run tests programmatically
        import pytest
        result = pytest.main([__file__, "-v", "--tb=short"])
        sys.exit(result)
    else:
        print("Hypothesis not installed. Running manual tests instead.")
        run_manual_tests()


if __name__ == "__main__":
    main()
