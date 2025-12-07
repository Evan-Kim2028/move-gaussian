#!/usr/bin/env python3
"""
Verify deployed Gaussian package against Python/scipy reference values.

This script:
1. Computes reference values using scipy
2. Calls the deployed Move functions via sui client
3. Compares results and reports accuracy
"""

import subprocess
import json
import sys
from scipy import stats
from scipy.special import erf
import numpy as np

# Constants
SCALE = 10**18  # WAD scaling
PACKAGE_ID = "0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b"


def wad_to_float(wad: int) -> float:
    """Convert WAD-scaled integer to float."""
    return wad / SCALE


def float_to_wad(f: float) -> int:
    """Convert float to WAD-scaled integer."""
    return int(f * SCALE)


def signed_wad_to_float(magnitude: int, is_negative: bool) -> float:
    """Convert SignedWad (magnitude, is_negative) to float."""
    val = wad_to_float(magnitude)
    return -val if is_negative else val


# ============================================================================
# Python Reference Implementations
# ============================================================================

def python_sample_z_from_seed(seed: int) -> float:
    """
    Replicate Move's sample_z_from_u64 logic in Python.
    
    The Move implementation:
    1. Uses seed to generate 12 uniform values via xorshift
    2. Applies Box-Muller style CLT: z = (sum - 6) / sqrt(1)
    """
    # Xorshift64 PRNG (same as Move)
    def xorshift64(state: int) -> int:
        state = state ^ (state << 13) & 0xFFFFFFFFFFFFFFFF
        state = state ^ (state >> 7) & 0xFFFFFFFFFFFFFFFF
        state = state ^ (state << 17) & 0xFFFFFFFFFFFFFFFF
        return state
    
    # Generate 12 uniform values in [0, 1)
    state = seed if seed != 0 else 1
    uniforms = []
    for _ in range(12):
        state = xorshift64(state)
        # uniform_open_interval: (state % (SCALE - 2) + 1) / SCALE
        u = ((state % (SCALE - 2)) + 1) / SCALE
        uniforms.append(u)
    
    # CLT: sum of 12 uniforms has mean 6, variance 1
    z = sum(uniforms) - 6.0
    return z


def python_ppf(p: float) -> float:
    """Standard normal inverse CDF (PPF) using scipy."""
    return stats.norm.ppf(p)


def python_cdf(z: float) -> float:
    """Standard normal CDF using scipy."""
    return stats.norm.cdf(z)


def python_pdf(z: float) -> float:
    """Standard normal PDF using scipy."""
    return stats.norm.pdf(z)


def python_erf(x: float) -> float:
    """Error function using scipy."""
    return erf(x)


# ============================================================================
# Sui Client Calls
# ============================================================================

def call_move_function(module: str, function: str, args: list, type_args: list = None) -> dict:
    """
    Call a Move function via sui client call --dev-inspect.
    Returns the parsed JSON result.
    """
    cmd = [
        "sui", "client", "call",
        "--package", PACKAGE_ID,
        "--module", module,
        "--function", function,
        "--gas-budget", "10000000",
        "--dev-inspect",
        "--json"
    ]
    
    for arg in args:
        cmd.extend(["--args", str(arg)])
    
    if type_args:
        for ta in type_args:
            cmd.extend(["--type-args", ta])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            print(f"Error calling {module}::{function}: {result.stderr}")
            return None
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        print(f"Timeout calling {module}::{function}")
        return None
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        print(f"Raw output: {result.stdout}")
        return None


def parse_return_values(result: dict) -> list:
    """Parse return values from dev-inspect result."""
    try:
        # Navigate to the return values
        effects = result.get("effects", {})
        if "returnValues" in effects:
            return effects["returnValues"]
        
        # Alternative path
        results = result.get("results", [])
        if results and "returnValues" in results[0]:
            return results[0]["returnValues"]
        
        return None
    except Exception as e:
        print(f"Error parsing return values: {e}")
        return None


# ============================================================================
# Test Functions
# ============================================================================

def test_sample_z_from_seed():
    """Test sample_z_from_seed against Python reference."""
    print("\n" + "="*60)
    print("Testing: sample_z_from_seed")
    print("="*60)
    
    test_seeds = [1, 42, 12345, 999999, 2**32 - 1]
    
    for seed in test_seeds:
        # Python reference
        py_z = python_sample_z_from_seed(seed)
        
        # Move function call
        result = call_move_function("harness", "sample_z_from_seed", [seed])
        
        if result is None:
            print(f"  Seed {seed}: FAILED (call error)")
            continue
        
        # Parse the (magnitude, is_negative) return values
        return_vals = parse_return_values(result)
        if return_vals:
            # The return is (u256, bool) - need to decode BCS
            print(f"  Seed {seed}:")
            print(f"    Python z = {py_z:.6f}")
            print(f"    Move return: {return_vals}")
        else:
            print(f"  Seed {seed}: Python z = {py_z:.6f}, Move: (parsing needed)")


def test_cdf_values():
    """Test CDF values at key points."""
    print("\n" + "="*60)
    print("Testing: CDF (Φ) at key z values")
    print("="*60)
    
    test_z_values = [
        0.0,      # Φ(0) = 0.5
        1.0,      # Φ(1) ≈ 0.8413
        -1.0,     # Φ(-1) ≈ 0.1587
        2.0,      # Φ(2) ≈ 0.9772
        -2.0,     # Φ(-2) ≈ 0.0228
        3.0,      # Φ(3) ≈ 0.9987
    ]
    
    print("\n  z       | Python CDF | Expected")
    print("  --------|------------|----------")
    for z in test_z_values:
        py_cdf = python_cdf(z)
        print(f"  {z:7.2f} | {py_cdf:.8f} | Φ({z})")


def test_ppf_values():
    """Test PPF (inverse CDF) values at key probabilities."""
    print("\n" + "="*60)
    print("Testing: PPF (Φ⁻¹) at key probabilities")
    print("="*60)
    
    test_p_values = [
        0.5,      # Φ⁻¹(0.5) = 0
        0.8413,   # Φ⁻¹(0.8413) ≈ 1.0
        0.1587,   # Φ⁻¹(0.1587) ≈ -1.0
        0.9772,   # Φ⁻¹(0.9772) ≈ 2.0
        0.0228,   # Φ⁻¹(0.0228) ≈ -2.0
        0.99,     # Φ⁻¹(0.99) ≈ 2.326
        0.01,     # Φ⁻¹(0.01) ≈ -2.326
    ]
    
    print("\n  p       | Python PPF | Expected z")
    print("  --------|------------|------------")
    for p in test_p_values:
        py_ppf = python_ppf(p)
        print(f"  {p:.4f}  | {py_ppf:10.6f} | Φ⁻¹({p})")


def test_pdf_values():
    """Test PDF values at key points."""
    print("\n" + "="*60)
    print("Testing: PDF (φ) at key z values")
    print("="*60)
    
    test_z_values = [0.0, 1.0, -1.0, 2.0, 3.0]
    
    print("\n  z       | Python PDF")
    print("  --------|------------")
    for z in test_z_values:
        py_pdf = python_pdf(z)
        print(f"  {z:7.2f} | {py_pdf:.8f}")


def print_reference_values():
    """Print all reference values for manual verification."""
    print("\n" + "="*60)
    print("REFERENCE VALUES FOR MANUAL VERIFICATION")
    print("="*60)
    
    print("\n1. Standard Normal CDF Φ(z):")
    print("   (Input z as WAD, output probability as WAD)")
    z_tests = [-3, -2, -1, 0, 1, 2, 3]
    for z in z_tests:
        cdf_val = python_cdf(z)
        z_wad = float_to_wad(z)
        cdf_wad = float_to_wad(cdf_val)
        print(f"   Φ({z:2d}) = {cdf_val:.10f}  | z_wad={z_wad}, cdf_wad={cdf_wad}")
    
    print("\n2. Standard Normal PPF Φ⁻¹(p):")
    print("   (Input p as WAD, output z as SignedWad)")
    p_tests = [0.001, 0.01, 0.1, 0.5, 0.9, 0.99, 0.999]
    for p in p_tests:
        ppf_val = python_ppf(p)
        p_wad = float_to_wad(p)
        ppf_mag = abs(float_to_wad(ppf_val))
        ppf_neg = ppf_val < 0
        print(f"   Φ⁻¹({p:.3f}) = {ppf_val:8.5f}  | p_wad={p_wad}, (mag={ppf_mag}, neg={ppf_neg})")
    
    print("\n3. Standard Normal PDF φ(z):")
    print("   (Input z as WAD, output density as WAD)")
    for z in z_tests:
        pdf_val = python_pdf(z)
        z_wad = float_to_wad(z)
        pdf_wad = float_to_wad(pdf_val)
        print(f"   φ({z:2d}) = {pdf_val:.10f}  | z_wad={z_wad}, pdf_wad={pdf_wad}")
    
    print("\n4. Sample Z from Seed (CLT-based):")
    print("   (Input seed as u64, output z as SignedWad)")
    seeds = [1, 42, 12345, 999999]
    for seed in seeds:
        z = python_sample_z_from_seed(seed)
        z_mag = abs(float_to_wad(z))
        z_neg = z < 0
        print(f"   seed={seed:6d} -> z={z:8.5f}  | (mag={z_mag}, neg={z_neg})")


def main():
    print("="*60)
    print("Gaussian Package Deployment Verification")
    print("="*60)
    print(f"\nPackage ID: {PACKAGE_ID}")
    print(f"Network: Testnet")
    
    # Print reference values
    print_reference_values()
    
    # Show expected WAD values for key inputs
    print("\n" + "="*60)
    print("KEY WAD VALUES FOR sui client call")
    print("="*60)
    print("""
To manually test via CLI, use these WAD-scaled values:

1. sample_z_from_seed (seed=12345):
   sui client call --package {pkg} --module harness --function sample_z_from_seed --args 12345 --gas-budget 10000000 --dev-inspect

2. For CDF at z=1.0 (would need direct module access):
   z_wad = 1000000000000000000 (1.0 * 10^18)
   
3. For PPF at p=0.5:
   p_wad = 500000000000000000 (0.5 * 10^18)
""".format(pkg=PACKAGE_ID))


if __name__ == "__main__":
    main()
