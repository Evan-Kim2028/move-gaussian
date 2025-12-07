#!/usr/bin/env python3
"""
Gaussian approximation pipeline runner.

Usage:
    python run_all.py [--skip-aaa] [--include-ppf] [--precision-check]

Options:
    --skip-aaa        Skip AAA exploration (use existing coefficients)
    --include-ppf     Include PPF coefficient generation
    --precision-check Include precision limit validation (slower)
"""

import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent / "src"

# Core pipeline steps
CORE_STEPS = [
    ("01_aaa_exploration.py", "Step 1: AAA Exploration (erf/erfc/phi)"),
    ("02_extract_coefficients.py", "Step 2: Extract Coefficients"),
    ("03_scale_fixed_point.py", "Step 3: Scale to Fixed-Point"),
    ("04_horner_python.py", "Step 4: Horner Evaluation"),
    ("05_test_harness.py", "Step 5: Test Harness"),
    ("07_export_for_move.py", "Step 7: Export for Move"),
]

# Optional steps
PPF_STEP = ("01b_aaa_ppf.py", "Step 1b: AAA Exploration (PPF)")
PRECISION_STEP = ("05b_test_precision_limits.py", "Step 5b: Precision Validation")


def run_step(script: str, description: str) -> bool:
    """Run a pipeline step and return success status."""
    print(f"\n{'='*60}")
    print(f"  {description}")
    print(f"  Script: {script}")
    print('='*60)
    
    script_path = SCRIPTS_DIR / script
    if not script_path.exists():
        print(f"  ERROR: Script not found: {script_path}")
        return False
    
    result = subprocess.run(
        [sys.executable, str(script_path)],
        cwd=str(Path(__file__).parent)
    )
    
    if result.returncode != 0:
        print(f"\n  ✗ FAILED: {script}")
        return False
    
    print(f"\n  ✓ COMPLETED: {script}")
    return True


def main():
    print("="*60)
    print("  GAUSSIAN APPROXIMATION PIPELINE")
    print("="*60)
    
    # Parse options
    skip_aaa = "--skip-aaa" in sys.argv
    include_ppf = "--include-ppf" in sys.argv
    precision_check = "--precision-check" in sys.argv
    
    if "--help" in sys.argv or "-h" in sys.argv:
        print(__doc__)
        sys.exit(0)
    
    print(f"\n  Options: skip_aaa={skip_aaa}, include_ppf={include_ppf}, precision_check={precision_check}")
    
    results = []
    
    # Build step list
    steps = []
    for script, desc in CORE_STEPS:
        if skip_aaa and script.startswith("01_"):
            continue
        steps.append((script, desc))
        
        if script == "01_aaa_exploration.py" and include_ppf:
            steps.append(PPF_STEP)
        
        if script == "05_test_harness.py" and precision_check:
            steps.append(PRECISION_STEP)
    
    # Run steps
    for script, description in steps:
        success = run_step(script, description)
        results.append((script, success))
        
        if not success:
            print(f"\n  Pipeline stopped due to failure in {script}")
            break
    
    # Summary
    print("\n" + "="*60)
    print("  SUMMARY")
    print("="*60)
    
    all_passed = all(success for _, success in results)
    for script, success in results:
        status = "✓" if success else "✗"
        print(f"  {status} {script}")
    
    if all_passed:
        print("\n  ✓ Pipeline complete. Run `sui move test` to verify.")
    else:
        print("\n  ✗ Pipeline failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
