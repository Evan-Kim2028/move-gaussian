#!/usr/bin/env python3
"""
Step 4: Horner Evaluation in Fixed-Point Arithmetic

Implements polynomial and rational function evaluation using integer-only
arithmetic. This must match the Move implementation exactly.

Key principle: Use ONLY integer division, track signs explicitly.

Usage:
    python 04_horner_python.py

Input:
    ../outputs/scaled_coefficients.json

Output:
    Validation results (printed)
"""

import json
from pathlib import Path
from typing import Tuple, List
from scipy.special import erf as scipy_erf
import numpy as np

# WAD = 10^18 (must match scaling)
WAD = 10**18


def signed_add(a_mag: int, a_neg: bool, b_mag: int, b_neg: bool) -> Tuple[int, bool]:
    """
    Add two signed magnitudes.
    
    Args:
        a_mag, a_neg: First value (magnitude, is_negative)
        b_mag, b_neg: Second value (magnitude, is_negative)
    
    Returns:
        (result_mag, result_neg): Sum as signed magnitude
    """
    if a_neg == b_neg:
        # Same sign: add magnitudes, keep sign
        return a_mag + b_mag, a_neg
    else:
        # Different signs: subtract magnitudes
        if a_mag >= b_mag:
            return a_mag - b_mag, a_neg
        else:
            return b_mag - a_mag, b_neg


def horner_eval_signed(
    x: int,
    magnitudes: List[int],
    signs: List[bool]
) -> Tuple[int, bool]:
    """
    Evaluate polynomial using Horner's rule with signed fixed-point arithmetic.
    
    P(x) = c[0] + c[1]*x + c[2]*x² + ... + c[n]*x^n
         = c[0] + x*(c[1] + x*(c[2] + ... + x*c[n]))
    
    Horner's method evaluates from highest to lowest degree:
        result = c[n]
        result = result * x + c[n-1]
        result = result * x + c[n-2]
        ...
        result = result * x + c[0]
    
    Args:
        x: Input value (WAD-scaled, must be non-negative)
        magnitudes: Absolute values of coefficients (WAD-scaled)
        signs: Sign flags (True = negative)
    
    Returns:
        (result_mag, result_neg): Polynomial value as signed magnitude
    """
    assert x >= 0, "x must be non-negative for this implementation"
    
    # Start from highest degree coefficient
    result_mag = magnitudes[-1]
    result_neg = signs[-1]
    
    # Work backwards through coefficients (from second-highest to lowest)
    for i in range(len(magnitudes) - 2, -1, -1):
        # result = result * x / WAD (fixed-point multiplication)
        # Since x >= 0, sign of result doesn't change
        result_mag = (result_mag * x) // WAD
        
        # result = result + c[i]
        c_mag = magnitudes[i]
        c_neg = signs[i]
        
        result_mag, result_neg = signed_add(result_mag, result_neg, c_mag, c_neg)
    
    return result_mag, result_neg


def rational_eval_signed(
    x: int,
    p_mags: List[int],
    p_signs: List[bool],
    q_mags: List[int],
    q_signs: List[bool]
) -> Tuple[int, bool]:
    """
    Evaluate rational function P(x)/Q(x) in fixed-point arithmetic.
    
    Args:
        x: Input value (WAD-scaled, non-negative)
        p_mags, p_signs: Numerator polynomial coefficients
        q_mags, q_signs: Denominator polynomial coefficients
    
    Returns:
        (result_mag, result_neg): P(x)/Q(x) as signed magnitude
    """
    # Evaluate P(x) and Q(x)
    p_mag, p_neg = horner_eval_signed(x, p_mags, p_signs)
    q_mag, q_neg = horner_eval_signed(x, q_mags, q_signs)
    
    # Check for division by zero (pole in domain)
    if q_mag == 0:
        raise ValueError(f"Division by zero at x = {x/WAD}")
    
    # Compute P(x) / Q(x)
    # In fixed-point: (P * WAD) / Q to maintain precision
    result_mag = (p_mag * WAD) // q_mag
    result_neg = p_neg != q_neg  # XOR for division sign
    
    return result_mag, result_neg


class FixedPointErf:
    """
    Fixed-point erf(x) evaluator.
    
    Loads coefficients from scaled_coefficients.json and provides
    an erf() function using integer-only arithmetic.
    """
    
    def __init__(self, coefficients_file: Path = None):
        """Load coefficients from JSON file."""
        if coefficients_file is None:
            coefficients_file = Path(__file__).parent.parent / 'outputs' / 'scaled_coefficients.json'
        
        if not coefficients_file.exists():
            raise FileNotFoundError(
                f"Coefficients file not found: {coefficients_file}\n"
                "Run 03_scale_fixed_point.py first."
            )
        
        with open(coefficients_file, 'r') as f:
            data = json.load(f)
        
        # Load erf coefficients
        erf_data = data['erf']
        self.p_mags = erf_data['p_magnitudes']
        self.p_signs = erf_data['p_signs']
        self.q_mags = erf_data['q_magnitudes']
        self.q_signs = erf_data['q_signs']
        self.scale = erf_data['scale']
        self.domain = erf_data['domain']
        
        # Also load erfc and phi
        self.erfc_data = data.get('erfc')
        self.phi_data = data.get('phi')
    
    def erf(self, x_wad: int) -> int:
        """
        Compute erf(x) using fixed-point arithmetic.
        
        Args:
            x_wad: Input scaled by WAD (e.g., 1.5 → 1.5e18)
            
        Returns:
            erf(x) scaled by WAD
            
        Note:
            - Only valid for x >= 0 (use symmetry erf(-x) = -erf(x))
            - Domain: [0, 6*WAD]
        """
        assert x_wad >= 0, "Use symmetry for negative x"
        
        # Clamp to domain
        max_x = int(self.domain[1] * WAD)
        if x_wad > max_x:
            # erf(x) ≈ 1 for large x
            return WAD
        
        result_mag, result_neg = rational_eval_signed(
            x_wad,
            self.p_mags, self.p_signs,
            self.q_mags, self.q_signs
        )
        
        # erf(x) should always be positive for x >= 0
        # (negative result would indicate approximation error)
        if result_neg:
            # Shouldn't happen for valid input, return 0
            return 0
        
        # Clamp to [0, WAD]
        return min(result_mag, WAD)
    
    def erf_float(self, x: float) -> float:
        """Convenience: compute erf(x) taking/returning floats."""
        x_wad = int(x * WAD)
        result_wad = self.erf(x_wad)
        return result_wad / WAD
    
    def erfc(self, x_wad: int) -> int:
        """Compute erfc(x) = 1 - erf(x) using fixed-point."""
        if self.erfc_data is None:
            # Fall back to 1 - erf
            return WAD - self.erf(x_wad)
        
        # Use direct erfc coefficients
        result_mag, result_neg = rational_eval_signed(
            x_wad,
            self.erfc_data['p_magnitudes'],
            self.erfc_data['p_signs'],
            self.erfc_data['q_magnitudes'],
            self.erfc_data['q_signs']
        )
        
        if result_neg:
            return 0
        return min(result_mag, WAD)
    
    def phi(self, x_wad: int) -> int:
        """Compute Φ(x) (normal CDF) using fixed-point."""
        if self.phi_data is None:
            # Fall back to 0.5 * (1 + erf(x / sqrt(2)))
            # sqrt(2) ≈ 1.4142... → scaled = 1414213562373095048
            SQRT2_WAD = 1414213562373095048
            x_scaled = (x_wad * WAD) // SQRT2_WAD
            erf_val = self.erf(x_scaled)
            return (WAD + erf_val) // 2
        
        # Use direct phi coefficients
        result_mag, result_neg = rational_eval_signed(
            x_wad,
            self.phi_data['p_magnitudes'],
            self.phi_data['p_signs'],
            self.phi_data['q_magnitudes'],
            self.phi_data['q_signs']
        )
        
        if result_neg:
            return 0
        return min(result_mag, WAD)


def validate_implementation():
    """Validate the fixed-point implementation against scipy."""
    
    print("="*60)
    print("Step 4: Horner Evaluation Validation")
    print("="*60)
    
    # Load evaluator
    evaluator = FixedPointErf()
    print(f"\nLoaded erf coefficients:")
    print(f"  P(x) degree: {len(evaluator.p_mags) - 1}")
    print(f"  Q(x) degree: {len(evaluator.q_mags) - 1}")
    print(f"  Domain: {evaluator.domain}")
    
    # Test points
    test_points = np.linspace(0, 6, 1000)
    
    errors = []
    max_error = 0
    max_error_x = 0
    
    print(f"\nTesting {len(test_points)} points in [0, 6]...")
    
    for x in test_points:
        # Our implementation
        result = evaluator.erf_float(x)
        
        # Reference
        expected = scipy_erf(x)
        
        error = abs(result - expected)
        errors.append(error)
        
        if error > max_error:
            max_error = error
            max_error_x = x
    
    mean_error = np.mean(errors)
    
    print(f"\nResults:")
    print(f"  Max error: {max_error:.2e} at x = {max_error_x:.4f}")
    print(f"  Mean error: {mean_error:.2e}")
    print(f"  Target: < 1e-7")
    print(f"  Status: {'✓ PASS' if max_error < 1e-7 else '✗ FAIL'}")
    
    # Test specific points
    print(f"\nEdge case tests:")
    edge_cases = [
        (0, 0.0),
        (0.5, 0.5204998778130465),
        (1.0, 0.8427007929497149),
        (2.0, 0.9953222650189527),
        (3.0, 0.9999779095030014),
        (6.0, 0.9999999999999999),
    ]
    
    for x, expected in edge_cases:
        result = evaluator.erf_float(x)
        error = abs(result - expected)
        status = "✓" if error < 1e-7 else "✗"
        print(f"  erf({x}) = {result:.10f}, expected {expected:.10f}, error = {error:.2e} {status}")
    
    # Test erfc
    print(f"\nerfc validation:")
    for x in [0, 1, 2, 3]:
        erfc_result = evaluator.erfc(int(x * WAD)) / WAD
        from scipy.special import erfc as scipy_erfc
        expected = scipy_erfc(x)
        error = abs(erfc_result - expected)
        print(f"  erfc({x}) = {erfc_result:.10f}, expected {expected:.10f}, error = {error:.2e}")
    
    # Test phi
    print(f"\nphi (normal CDF) validation:")
    from scipy.stats import norm
    for x in [0, 1, 2, 3]:
        phi_result = evaluator.phi(int(x * WAD)) / WAD
        expected = norm.cdf(x)
        error = abs(phi_result - expected)
        print(f"  Φ({x}) = {phi_result:.10f}, expected {expected:.10f}, error = {error:.2e}")
    
    return max_error < 1e-7


def main():
    success = validate_implementation()
    
    print(f"\n{'='*60}")
    print("Summary")
    print("="*60)
    
    if success:
        print("\n✓ Fixed-point Horner evaluation validated successfully!")
        print("  Ready for property testing (Step 5-6)")
    else:
        print("\n✗ Validation failed - check implementation")
        exit(1)


if __name__ == "__main__":
    main()
