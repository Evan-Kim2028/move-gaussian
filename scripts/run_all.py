#!/usr/bin/env python3
"""
Run All Pipeline Steps

Executes the complete Gaussian approximation pipeline:
1. Extract coefficients from AAA approximation
2. Scale to fixed-point integers
3. Validate Horner evaluation
4. Run comprehensive test harness
5. Export for Move

Usage:
    python run_all.py [--skip-aaa]

Options:
    --skip-aaa    Skip Step 1 (AAA exploration) if coefficients already exist
"""

import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent / "src"

STEPS = [
    ("01_aaa_exploration.py", "Step 1: AAA Exploration"),
    ("02_extract_coefficients.py", "Step 2: Extract Coefficients"),
    ("03_scale_fixed_point.py", "Step 3: Scale to Fixed-Point"),
    ("04_horner_python.py", "Step 4: Horner Evaluation"),
    ("05_test_harness.py", "Step 5: Test Harness"),
    ("07_export_for_move.py", "Step 7: Export for Move"),
]


def run_step(script: str, description: str) -> bool:
    """Run a pipeline step and return success status."""
    print(f"\n{'='*70}")
    print(f"  {description}")
    print(f"  Script: {script}")
    print('='*70)
    
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
    print("="*70)
    print("  GAUSSIAN APPROXIMATION PIPELINE")
    print("  Running all steps...")
    print("="*70)
    
    skip_aaa = "--skip-aaa" in sys.argv
    
    results = []
    
    for script, description in STEPS:
        if skip_aaa and script == "01_aaa_exploration.py":
            print(f"\n  Skipping {script} (--skip-aaa)")
            continue
        
        success = run_step(script, description)
        results.append((script, success))
        
        if not success:
            print(f"\n  Pipeline stopped due to failure in {script}")
            break
    
    # Summary
    print("\n" + "="*70)
    print("  PIPELINE SUMMARY")
    print("="*70)
    
    all_passed = True
    for script, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"  {status}: {script}")
        if not success:
            all_passed = False
    
    if all_passed:
        print("\n  ✓ ALL STEPS COMPLETED SUCCESSFULLY")
        print("\n  Next steps:")
        print("    1. Review outputs/ directory")
        print("    2. Copy Move files to sources/")
        print("    3. Implement Horner in Move")
        print("    4. Run: sui move test")
    else:
        print("\n  ✗ PIPELINE FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
