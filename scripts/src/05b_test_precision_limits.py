#!/usr/bin/env python3
"""
Step 5b: Precision Limit Validation

Tests how close we are to the theoretical WAD precision limit (~1e-15).
This validates that our AAA approximation + fixed-point arithmetic
approaches the fundamental limits of the number format.

Key metrics:
- Off-chain AAA error (Python rational evaluation)
- On-chain simulation error (integer-only arithmetic)
- Distance from WAD theoretical limit

Usage:
    python 05b_test_precision_limits.py

Requirements:
    pip install numpy mpmath scipy
"""

import numpy as np
from pathlib import Path
import json
import importlib.util
from typing import Tuple, Dict

# High-precision reference
try:
    from mpmath import mp, erf as mp_erf, erfc as mp_erfc
    mp.dps = 50  # 50 decimal places
    HAS_MPMATH = True
except ImportError:
    HAS_MPMATH = False
    print("ERROR: mpmath required for precision limit testing")
    print("Install with: pip install mpmath")
    exit(1)

# Constants
WAD = 10**18
WAD_THEORETICAL_LIMIT = 1e-15  # Theoretical floor of WAD arithmetic
TARGET_HEADROOM = 100  # Target: within 100x of theoretical limit


def load_fixed_point_erf():
    """Load the fixed-point evaluator from 04_horner_python.py."""
    spec = importlib.util.spec_from_file_location(
        "horner_python",
        Path(__file__).parent / "04_horner_python.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.FixedPointErf


def mpmath_erf(x: float) -> float:
    """High-precision erf using mpmath with string conversion."""
    return float(mp_erf(mp.mpf(str(x))))


def mpmath_erfc(x: float) -> float:
    """High-precision erfc using mpmath with string conversion."""
    return float(mp_erfc(mp.mpf(str(x))))


class PrecisionLimitTester:
    """
    Validates approximation precision against theoretical limits.
    """
    
    def __init__(self):
        FixedPointErf = load_fixed_point_erf()
        self.evaluator = FixedPointErf()
        self.results = {}
    
    def test_erf_precision(self, n_points: int = 100000) -> Dict:
        """
        Test erf precision with dense sampling against 50-digit reference.
        
        Args:
            n_points: Number of test points (more = better coverage)
            
        Returns:
            Dictionary with precision metrics
        """
        print(f"\n{'='*70}")
        print(f"ERF PRECISION LIMIT TEST")
        print(f"{'='*70}")
        print(f"Test points: {n_points:,}")
        print(f"Reference: mpmath (50 decimal places)")
        print(f"Domain: [0, 6]")
        
        test_points = np.linspace(0, 6, n_points)
        
        errors = []
        rel_errors = []
        worst_case = {'x': 0, 'error': 0, 'result': 0, 'expected': 0}
        
        for x in test_points:
            # Our fixed-point implementation
            result = self.evaluator.erf_float(x)
            
            # 50-digit reference
            expected = mpmath_erf(x)
            
            # Absolute error
            error = abs(result - expected)
            errors.append(error)
            
            # Relative error (avoid division by zero)
            if abs(expected) > 1e-15:
                rel_error = error / abs(expected)
                rel_errors.append(rel_error)
            
            # Track worst case
            if error > worst_case['error']:
                worst_case = {
                    'x': x,
                    'error': error,
                    'result': result,
                    'expected': expected
                }
        
        max_error = max(errors)
        mean_error = np.mean(errors)
        p99_error = np.percentile(errors, 99)
        max_rel_error = max(rel_errors) if rel_errors else 0
        
        # Calculate headroom from theoretical limit
        headroom = max_error / WAD_THEORETICAL_LIMIT
        
        print(f"\n--- Results ---")
        print(f"Max absolute error:  {max_error:.2e}")
        print(f"Mean absolute error: {mean_error:.2e}")
        print(f"P99 absolute error:  {p99_error:.2e}")
        print(f"Max relative error:  {max_rel_error:.2e}")
        
        print(f"\n--- Distance from WAD Limit ---")
        print(f"WAD theoretical limit: {WAD_THEORETICAL_LIMIT:.0e}")
        print(f"Our max error:         {max_error:.2e}")
        print(f"Headroom factor:       {headroom:.1f}x")
        
        if headroom <= TARGET_HEADROOM:
            print(f"✓ EXCELLENT: Within {TARGET_HEADROOM}x of theoretical limit")
        elif headroom <= 1000:
            print(f"✓ GOOD: Within 1000x of theoretical limit")
        else:
            print(f"→ Room for improvement: {headroom:.0f}x from limit")
        
        print(f"\n--- Worst Case ---")
        print(f"x = {worst_case['x']:.6f}")
        print(f"Our result:   {worst_case['result']:.15e}")
        print(f"Expected:     {worst_case['expected']:.15e}")
        print(f"Error:        {worst_case['error']:.2e}")
        
        self.results['erf'] = {
            'n_points': n_points,
            'max_error': max_error,
            'mean_error': mean_error,
            'p99_error': p99_error,
            'max_rel_error': max_rel_error,
            'headroom': headroom,
            'worst_case': worst_case,
            'within_target': headroom <= TARGET_HEADROOM
        }
        
        return self.results['erf']
    
    def test_error_distribution(self, n_points: int = 10000) -> Dict:
        """
        Analyze error distribution across the domain.
        
        Identifies regions where precision is best/worst.
        """
        print(f"\n{'='*70}")
        print(f"ERROR DISTRIBUTION ANALYSIS")
        print(f"{'='*70}")
        
        test_points = np.linspace(0, 6, n_points)
        
        # Divide domain into regions
        regions = [
            (0.0, 0.5, "Near zero"),
            (0.5, 2.0, "Central"),
            (2.0, 4.0, "Transition"),
            (4.0, 6.0, "Saturation"),
        ]
        
        region_results = {}
        
        for x_min, x_max, name in regions:
            mask = (test_points >= x_min) & (test_points < x_max)
            region_points = test_points[mask]
            
            errors = []
            for x in region_points:
                result = self.evaluator.erf_float(x)
                expected = mpmath_erf(x)
                errors.append(abs(result - expected))
            
            if errors:
                max_err = max(errors)
                mean_err = np.mean(errors)
                headroom = max_err / WAD_THEORETICAL_LIMIT
                
                print(f"\n{name} [{x_min}, {x_max}):")
                print(f"  Max error:  {max_err:.2e}")
                print(f"  Mean error: {mean_err:.2e}")
                print(f"  Headroom:   {headroom:.1f}x")
                
                region_results[name] = {
                    'range': (x_min, x_max),
                    'max_error': max_err,
                    'mean_error': mean_err,
                    'headroom': headroom
                }
        
        self.results['distribution'] = region_results
        return region_results
    
    def test_wad_arithmetic_overhead(self, n_points: int = 1000) -> Dict:
        """
        Measure overhead from WAD integer arithmetic vs ideal float.
        
        Compares:
        1. Direct float rational evaluation
        2. WAD integer arithmetic (simulating Move)
        """
        print(f"\n{'='*70}")
        print(f"WAD ARITHMETIC OVERHEAD ANALYSIS")
        print(f"{'='*70}")
        
        # Load coefficients
        coeff_file = Path(__file__).parent.parent / 'outputs' / 'scaled_coefficients.json'
        if not coeff_file.exists():
            print("Coefficients file not found - skipping overhead analysis")
            return {}
        
        with open(coeff_file, 'r') as f:
            coeffs = json.load(f)
        
        # Get original float coefficients from coefficients.json
        orig_coeff_file = Path(__file__).parent.parent / 'outputs' / 'coefficients.json'
        if not orig_coeff_file.exists():
            print("Original coefficients file not found - skipping")
            return {}
        
        with open(orig_coeff_file, 'r') as f:
            orig_coeffs = json.load(f)
        
        test_points = np.linspace(0.1, 5.9, n_points)
        
        errors_float = []
        errors_wad = []
        
        for x in test_points:
            expected = mpmath_erf(x)
            
            # Float evaluation (ideal, no rounding)
            p_float = orig_coeffs['erf']['p_coefficients_normalized']
            q_float = orig_coeffs['erf']['q_coefficients_normalized']
            result_float = self._eval_rational_float(x, p_float, q_float)
            errors_float.append(abs(result_float - expected))
            
            # WAD evaluation (integer arithmetic)
            result_wad = self.evaluator.erf_float(x)
            errors_wad.append(abs(result_wad - expected))
        
        max_float = max(errors_float)
        max_wad = max(errors_wad)
        overhead = max_wad / max_float if max_float > 0 else float('inf')
        
        print(f"\nFloat evaluation (ideal):")
        print(f"  Max error: {max_float:.2e}")
        
        print(f"\nWAD evaluation (integer arithmetic):")
        print(f"  Max error: {max_wad:.2e}")
        
        print(f"\nOverhead factor: {overhead:.2f}x")
        
        if overhead < 2:
            print("✓ WAD arithmetic adds minimal overhead")
        elif overhead < 10:
            print("→ WAD arithmetic adds moderate overhead")
        else:
            print("⚠ WAD arithmetic adds significant overhead")
        
        self.results['overhead'] = {
            'float_max_error': max_float,
            'wad_max_error': max_wad,
            'overhead_factor': overhead
        }
        
        return self.results['overhead']
    
    def _eval_rational_float(self, x: float, p_coeffs: list, q_coeffs: list) -> float:
        """Evaluate rational function in pure float (Horner's method)."""
        # P(x)
        p = p_coeffs[-1]
        for i in range(len(p_coeffs) - 2, -1, -1):
            p = p * x + p_coeffs[i]
        
        # Q(x)
        q = q_coeffs[-1]
        for i in range(len(q_coeffs) - 2, -1, -1):
            q = q * x + q_coeffs[i]
        
        return p / q
    
    def run_all_tests(self) -> bool:
        """Run all precision limit tests."""
        print("\n" + "="*70)
        print("PRECISION LIMIT VALIDATION SUITE")
        print("="*70)
        print(f"Target: Within {TARGET_HEADROOM}x of WAD theoretical limit ({WAD_THEORETICAL_LIMIT:.0e})")
        
        # Main precision test
        erf_results = self.test_erf_precision(100000)
        
        # Distribution analysis
        self.test_error_distribution(10000)
        
        # Overhead analysis
        self.test_wad_arithmetic_overhead(1000)
        
        # Summary
        print(f"\n{'='*70}")
        print("SUMMARY")
        print(f"{'='*70}")
        
        passed = erf_results['within_target']
        
        print(f"\nMax error:           {erf_results['max_error']:.2e}")
        print(f"WAD theoretical:     {WAD_THEORETICAL_LIMIT:.0e}")
        print(f"Headroom:            {erf_results['headroom']:.1f}x")
        print(f"Target headroom:     {TARGET_HEADROOM}x")
        print(f"\nStatus: {'✓ WITHIN TARGET' if passed else '→ ABOVE TARGET'}")
        
        return passed
    
    def save_results(self, output_file: Path):
        """Save results to JSON."""
        # Convert numpy types for JSON serialization
        def convert(obj):
            if isinstance(obj, np.floating):
                return float(obj)
            elif isinstance(obj, np.integer):
                return int(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            return obj
        
        results_clean = json.loads(
            json.dumps(self.results, default=convert)
        )
        
        with open(output_file, 'w') as f:
            json.dump(results_clean, f, indent=2)
        print(f"\nResults saved to: {output_file}")


def main():
    tester = PrecisionLimitTester()
    success = tester.run_all_tests()
    
    # Save results
    output_dir = Path(__file__).parent.parent / 'outputs'
    tester.save_results(output_dir / 'precision_limit_results.json')
    
    if not success:
        print("\n⚠ Precision target not met - consider regenerating coefficients")
        exit(1)
    else:
        print("\n✓ Precision validation passed")


if __name__ == "__main__":
    main()
