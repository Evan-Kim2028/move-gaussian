# Gaussian Approximation Pipeline

Python pipeline for designing optimal rational approximations of Gaussian functions using the AAA algorithm, then exporting them to Move smart contracts.

## The Production Cycle

This pipeline implements a **Python → Move** workflow for on-chain math:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         PRODUCTION CYCLE                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   PYTHON (Design Phase)                     MOVE (Runtime Phase)          │
│   ─────────────────────                     ────────────────────          │
│                                                                           │
│   ┌─────────────────┐                       ┌─────────────────┐          │
│   │ 1. AAA Algorithm│                       │ erf_coefficients│          │
│   │    (baryrat)    │──────────────────────▶│    .move        │          │
│   └─────────────────┘     coefficients      └─────────────────┘          │
│           │                                          │                    │
│           ▼                                          ▼                    │
│   ┌─────────────────┐                       ┌─────────────────┐          │
│   │ 2. Extract P(x)/│                       │   erf.move      │          │
│   │    Q(x) polys   │                       │  (Horner eval)  │          │
│   └─────────────────┘                       └─────────────────┘          │
│           │                                          │                    │
│           ▼                                          ▼                    │
│   ┌─────────────────┐                       ┌─────────────────┐          │
│   │ 3. Scale to WAD │                       │   erf_tests     │          │
│   │    (1e18)       │──────────────────────▶│    .move        │          │
│   └─────────────────┘     test vectors      └─────────────────┘          │
│           │                                                               │
│           ▼                                                               │
│   ┌─────────────────┐                                                     │
│   │ 4-6. Verify in  │                                                     │
│   │    Python       │                                                     │
│   └─────────────────┘                                                     │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run the full pipeline
python run_all.py

# Copy generated files to Move package
cp outputs/move_generated/erf_coefficients.move ../sources/
cp outputs/move_generated/erf_tests.move ../tests/

# Build and test Move package
cd ..
sui move build
sui move test
```

## Pipeline Steps

| Step | Script | What It Does | Output |
|------|--------|--------------|--------|
| 1 | `01_aaa_exploration.py` | Runs AAA on scipy.special.erf samples | Barycentric approximation |
| 2 | `02_extract_coefficients.py` | Converts barycentric → P(x)/Q(x) | `coefficients.json` |
| 3 | `03_scale_fixed_point.py` | Floats → WAD integers (1e18) | `scaled_coefficients.json` |
| 4 | `04_horner_python.py` | Reference Horner implementation | Validation |
| 5 | `05_test_harness.py` | Accuracy & edge case tests | `test_results.json` |
| 6 | `06_property_tests.py` | Hypothesis property tests | Validation |
| 7 | `07_export_for_move.py` | Generate Move code | `move_generated/*.move` |

## Directory Structure

```
scripts/
├── run_all.py              # Run entire pipeline
├── requirements.txt        # Python dependencies
├── docs/
│   ├── SPECIFICATION.md    # Detailed pipeline spec
│   └── VERIFICATION_REPORT.md  # Test results & confidence
├── images/                 # Plots of approximation error
├── outputs/
│   ├── coefficients.json           # Float P(x)/Q(x) coefficients
│   ├── scaled_coefficients.json    # WAD-scaled integers with signs
│   ├── test_results.json           # Comprehensive test results
│   ├── test_vectors.json           # 100 test cases for Move
│   └── move_generated/
│       ├── erf_coefficients.move.bak   # Move constants (backup)
│       └── erf_tests.move.bak          # Move tests (backup)
└── src/
    ├── 01_aaa_exploration.py
    ├── 02_extract_coefficients.py
    ├── 03_scale_fixed_point.py
    ├── 04_horner_python.py
    ├── 05_test_harness.py
    ├── 06_property_tests.py
    └── 07_export_for_move.py
```

## Key Results

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Max error (erf) | 5.68e-11 | < 1e-7 | ✅ 1,760x better |
| Polynomial degree | (11, 11) | N/A | Optimal from AAA |
| Bounds violations | 0 | 0 | ✅ |
| Overflow risk | None | None | ✅ Fits in u128 |

## Why AAA?

The **AAA (Adaptive Antoulas-Anderson) algorithm** automatically finds optimal rational approximations:

1. **Automatic degree selection** - No manual tuning needed
2. **Near-optimal accuracy** - Approaches minimax (best possible) solution  
3. **Pole detection** - Identifies and avoids numerical instabilities
4. **Fast convergence** - Typically reaches machine precision in ~20 iterations

Comparison to hand-tuned approaches:

| Method | Error | Source |
|--------|-------|--------|
| SolStat (Abramowitz-Stegun) | 1.2e-7 | Primitive Finance |
| solgauss (Chebyshev) | <1e-8 | cairoeth |
| **AAA (this project)** | **5.7e-11** | Auto-discovered |

## Extending to Other Functions

To approximate a different function (e.g., PDF, inverse CDF):

1. **Edit `01_aaa_exploration.py`**:
   ```python
   # Change target function
   from scipy.special import erfinv  # or any function
   
   Z = np.linspace(0, 1, 1000)
   F = erfinv(Z)
   
   r = aaa(Z, F, tol=1e-12)
   ```

2. **Run the pipeline**:
   ```bash
   python run_all.py
   ```

3. **Update Move module**:
   - Rename generated files appropriately
   - Update function names in `erf.move`

## Verification Checklist

Before deploying Move code, verify:

- [ ] `test_results.json` shows max_error < target (e.g., 1e-7)
- [ ] No overflow warnings in `scaled_coefficients.json`
- [ ] All 100 test vectors pass in Python (`05_test_harness.py`)
- [ ] `sui move test` passes all 117 tests
- [ ] Edge cases handled: x=0, x=6, x>6

## Dependencies

```
numpy>=1.24.0      # Numerical arrays
scipy>=1.11.0      # Reference erf implementation
baryrat>=2.0.0     # AAA algorithm
mpmath>=1.3.0      # Arbitrary precision validation
hypothesis>=6.0    # Property-based testing (optional)
```

## References

- [AAA Algorithm Paper](https://arxiv.org/abs/1612.00337) - Nakatsukasa, Sète, Trefethen (2018)
- [baryrat Documentation](https://github.com/c-f-h/baryrat)
- [Move Book](https://move-book.com/) - Move language reference
- [Sui Framework](https://docs.sui.io/) - Sui-specific patterns