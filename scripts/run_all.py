#!/usr/bin/env python3
"""
One-shot pipeline runner for move-gaussian coefficient generation and test vectors.

Steps:
1) Extract forward coefficients (erf/erfc/phi)
2) Scale to fixed-point
3) Extract PPF coefficients (central + tail)
4) Export Move modules
5) Regenerate cross-language and sampling vectors
6) Copy generated Move coefficients into sources

Usage:
    python3 run_all.py
"""

import subprocess
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUTPUT = ROOT / "outputs"
ARTIFACTS = ROOT.parents[0] / "artifacts" / "move_generated"


def run(cmd: list[str], cwd: Path):
    print(f"\n=== Running: {' '.join(cmd)} ===")
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        sys.exit(result.returncode)


def main():
    run(["python3", str(SRC / "02_extract_coefficients.py")], cwd=ROOT)
    run(["python3", str(SRC / "03_scale_fixed_point.py")], cwd=ROOT)
    run(["python3", str(SRC / "02b_extract_ppf_coefficients.py")], cwd=ROOT)
    run(["python3", str(SRC / "07_export_for_move_gaussian.py")], cwd=ROOT)
    run(["python3", str(SRC / "10_cross_language_vectors.py")], cwd=ROOT)

    # Copy generated coefficients into package sources
    coeff_src = ARTIFACTS / "coefficients.move"
    coeff_dest = ROOT.parents[0] / "sources" / "coefficients.move"
    if coeff_src.exists():
        shutil.copy(coeff_src, coeff_dest)
        print(f"Copied {coeff_src} -> {coeff_dest}")
    else:
        print("WARNING: coefficients.move not found; export step may have failed")

    print("\nPipeline complete. Consider running `sui move test` from package root.")


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Run All Pipeline Steps

Executes the complete Gaussian approximation pipeline:
1. AAA exploration for erf/erfc/phi (high-precision mpmath sampling)
1b. AAA exploration for inverse CDF (PPF)
2. Extract polynomial coefficients
3. Scale to fixed-point integers  
4. Validate Horner evaluation
5. Run comprehensive test harness
5b. Run precision limit validation
6. (Reserved for property tests)
7. Export for Move

Usage:
    python run_all.py [--skip-aaa] [--include-ppf] [--precision-check]

Options:
    --skip-aaa        Skip AAA exploration steps if coefficients already exist
    --include-ppf     Include PPF (inverse CDF) coefficient generation
    --precision-check Include precision limit validation (slower, thorough)
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

# Optional PPF step
PPF_STEP = ("01b_aaa_ppf.py", "Step 1b: AAA Exploration (PPF/inverse CDF)")

# Optional precision validation
PRECISION_STEP = ("05b_test_precision_limits.py", "Step 5b: Precision Limit Validation")


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
    print("  High-Precision Edition (mpmath 50 digits)")
    print("="*70)
    
    # Parse options
    skip_aaa = "--skip-aaa" in sys.argv
    include_ppf = "--include-ppf" in sys.argv
    precision_check = "--precision-check" in sys.argv
    
    print(f"\n  Options:")
    print(f"    Skip AAA: {skip_aaa}")
    print(f"    Include PPF: {include_ppf}")
    print(f"    Precision check: {precision_check}")
    
    results = []
    
    # Build step list
    steps = []
    for script, desc in CORE_STEPS:
        if skip_aaa and script.startswith("01_"):
            continue
        steps.append((script, desc))
        
        # Insert PPF step after 01_aaa_exploration.py
        if script == "01_aaa_exploration.py" and include_ppf:
            steps.append(PPF_STEP)
        
        # Insert precision check after 05_test_harness.py
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
        print("\n  Generated files:")
        print("    - outputs/coefficients.json")
        print("    - outputs/scaled_coefficients.json")
        print("    - outputs/test_vectors.json")
        print("    - outputs/test_results.json")
        if include_ppf:
            print("    - outputs/ppf_aaa_results.json")
        if precision_check:
            print("    - outputs/precision_limit_results.json")
        print("\n  Next steps:")
        print("    1. Review outputs/ directory")
        print("    2. Copy generated Move files to sources/")
        print("    3. Run: sui move test")
    else:
        print("\n  ✗ PIPELINE FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
