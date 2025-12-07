# Gaussian Approximation Pipeline

Python pipeline for discovering rational approximations with AAA, scaling them to fixed-point, and exporting Move-ready coefficients plus test vectors (CDF/PPF/sampling).

## Quick Start (recommended)

```bash
cd packages/gaussian/scripts
pip install -r requirements.txt
python run_all.py          # Runs extraction → scaling → PPF → Move export → cross-lang vectors

# Move side (from package root)
cd ..
sui move test              # Uses generated coefficients and vectors
```

If you only want the test harness without regeneration:
```bash
cd packages/gaussian/scripts
python src/05_test_harness.py
pytest src/06_property_tests.py -v
python src/10_cross_language_vectors.py  # refresh Move test modules/vectors
```

## Current Testing Snapshot (Python)
- Forward functions (erf/erfc/phi): max error ~5.7e-11 vs mpmath; bounds/monotonicity/overflow property tests in `06_property_tests.py`.
- PPF (inverse CDF): central and tail fits generated in `02b_extract_ppf_coefficients.py`; Move export carries FNV checksums.
- Cross-language and sampling integration: `10_cross_language_vectors.py` emits Move tests for Φ/φ/Φ⁻¹ and sampler; sampler smoke stats live in `test_sampling_smoke.py`.

## Pipeline Steps (what runs in `run_all.py`)

| Step | Script | Output |
|---|---|---|
| Forward AAA + coeffs | `src/02_extract_coefficients.py` | `outputs/coefficients.json` |
| Scale forward coeffs | `src/03_scale_fixed_point.py` | `outputs/scaled_coefficients.json` |
| PPF AAA + scaling | `src/02b_extract_ppf_coefficients.py` | `outputs/scaled_ppf_coefficients.json` |
| Move export (CDF/PDF/PPF) | `src/07_export_for_move_gaussian.py` | `artifacts/move_generated/coefficients.move` + summary JSON |
| Cross-language & sampling vectors | `src/10_cross_language_vectors.py` | `tests/cross_language_vectors.move`, `tests/sampling_integration.move`, CSV (optional) |

## Directory Structure

```
scripts/
├── run_all.py
├── requirements.txt
├── docs/
│   ├── SPECIFICATION.md
│   └── VERIFICATION_REPORT.md
├── outputs/                  # JSON artifacts
│   ├── coefficients.json
│   ├── scaled_coefficients.json
│   ├── scaled_ppf_coefficients.json
│   ├── test_results.json
│   └── move_generated/       # Auto-generated Move files
├── images/                   # Error plots
└── src/
    ├── 01_aaa_exploration.py
    ├── 01b_aaa_ppf.py
    ├── 02_extract_coefficients.py
    ├── 02b_extract_ppf_coefficients.py
    ├── 03_scale_fixed_point.py
    ├── 04_horner_python.py
    ├── 05_test_harness.py
    ├── 05b_test_precision_limits.py
    ├── 06_property_tests.py
    ├── 07_export_for_move.py
    ├── 07_export_for_move_gaussian.py
    ├── 10_cross_language_vectors.py
    ├── test_coefficients_metadata.py
    ├── test_horner_properties.py
    └── test_sampling_smoke.py
```

## Notes
- FNV checksums in Move artifacts guard against stale or tampered coefficients/vectors.
- `07_export_for_move_gaussian.py` expects `scaled_ppf_coefficients.json`; run the PPF step first or run `python run_all.py` to orchestrate everything.
- Sampler/reference helpers (`uniform_open_interval_from_u64`, signed WAD arithmetic) are mirrored between Python and Move to keep deterministic vectors.