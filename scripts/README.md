# Gaussian Approximation Pipeline

Python pipeline for designing optimal rational approximations of Gaussian functions using the AAA algorithm.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run the full pipeline
python run_all.py

# Or run individual steps
python src/02_extract_coefficients.py
python src/03_scale_fixed_point.py
python src/04_horner_python.py
python src/05_test_harness.py
python src/07_export_for_move.py
```

## Directory Structure

```
scripts/
├── run_all.py              # Run entire pipeline
├── requirements.txt        # Python dependencies
├── docs/
│   ├── SPECIFICATION.md    # Pipeline specification
│   └── VERIFICATION_REPORT.md  # Test results and confidence assessment
├── images/
│   ├── aaa_erf.png         # Approximation plots
│   ├── aaa_erfc.png
│   └── aaa_phi.png
├── outputs/
│   ├── coefficients.json           # Float P(x)/Q(x) coefficients
│   ├── scaled_coefficients.json    # WAD-scaled integers
│   ├── test_results.json           # Comprehensive test results
│   ├── test_vectors.json           # 100 test cases for Move
│   └── move_generated/
│       ├── erf_coefficients.move   # Move constants module
│       └── erf_tests.move          # Move test module
└── src/
    ├── 01_aaa_exploration.py       # AAA approximation
    ├── 02_extract_coefficients.py  # Barycentric → P(x)/Q(x)
    ├── 03_scale_fixed_point.py     # Float → WAD integers
    ├── 04_horner_python.py         # Fixed-point Horner evaluation
    ├── 05_test_harness.py          # Accuracy & property tests
    ├── 06_property_tests.py        # Hypothesis tests (optional)
    └── 07_export_for_move.py       # Generate Move code
```

## Pipeline Status

| Step | Script | Status | Description |
|------|--------|--------|-------------|
| 1 | `01_aaa_exploration.py` | ✅ Complete | Sample erf, run AAA |
| 2 | `02_extract_coefficients.py` | ✅ Complete | Barycentric → polynomial |
| 3 | `03_scale_fixed_point.py` | ✅ Complete | Float → WAD integers |
| 4 | `04_horner_python.py` | ✅ Complete | Fixed-point Horner |
| 5 | `05_test_harness.py` | ✅ Complete | Comprehensive tests |
| 6 | `06_property_tests.py` | ✅ Complete | Property-based tests |
| 7 | `07_export_for_move.py` | ✅ Complete | Generate Move code |

## Key Results

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Max error (erf) | 5.68e-11 | < 1e-7 | ✅ 1,760x better |
| Polynomial degree | (11, 11) | N/A | Optimal from AAA |
| Bounds [0, 1] | 0 violations | 0 | ✅ |
| Overflow risk | None | None | ✅ Fits in u128 |

## Test Results Summary

```
Accuracy (max < 1e-7):  ✓ PASS  (5.68e-11)
Edge cases:             ✓ PASS  (12/12)
Monotonicity:           ✓ PASS  (minor rounding only)
Bounds [0,1]:           ✓ PASS  (10,000 points)
No overflow:            ✓ PASS  (max ~2.6e22)
```

See `docs/VERIFICATION_REPORT.md` for detailed analysis.

## Next Steps (Move Implementation)

1. Copy `outputs/move_generated/erf_coefficients.move` to `sources/`
2. Implement Horner evaluation in Move (match `04_horner_python.py`)
3. Run `sui move test` with exported test vectors
4. Benchmark gas costs
5. Integrate with `sui::random` for Gaussian sampling
