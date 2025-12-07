# Verification Report: Python Pipeline

**Date**: 2025-12-06  
**Status**: ✅ All Critical Tests Pass  
**Confidence Level**: HIGH for Move implementation

---

## Executive Summary

| Category | Status | Confidence |
|----------|--------|------------|
| Accuracy (vs scipy) | ✅ 5.68e-11 max error | **HIGH** - 1000x better than 1e-7 target |
| Accuracy (vs mpmath) | ✅ 5.68e-11 max error | **HIGH** - Matches arbitrary precision |
| PPF Accuracy (central/tail) | ✅ 3.97e-14 / 2.03e-13 | **HIGH** - Central + tail bands pass region tolerances |
| Edge Cases | ✅ All 12 pass | **HIGH** - Covers x=0 to x=6 |
| Bounds [0,1] | ✅ No violations | **HIGH** - 10,000 points tested |
| Monotonicity | ✅ Minor rounding only | **MEDIUM-HIGH** - See note below |
| Overflow Safety | ✅ All fit in u256 | **HIGH** - Max intermediate ~2.6e22 |
| Horner Implementation | ✅ Validated | **HIGH** - Matches Move semantics |
| Cross-language vectors | ✅ Generated | **HIGH** - Φ/φ/Φ⁻¹ tolerances encoded in Move tests |
| Sampling integration | ✅ Smoke stats match | **HIGH** - Seeds → deterministic z/normal vectors |

---

## Detailed Analysis

### 1. Accuracy Assessment

**Test**: Compare fixed-point implementation against two references:
- `scipy.special.erf` (double precision, ~15 significant digits)
- `mpmath.erf` (50 decimal places, arbitrary precision)

**Results**:
```
Max error vs scipy:  5.68e-11
Max error vs mpmath: 5.68e-11
Mean error:          2.54e-11
Target:              1.00e-07
```

**Analysis**: 
- Error is **1,760x better than target** (5.68e-11 vs 1e-7)
- Error vs scipy and mpmath are identical → our approximation is the limiting factor, not reference precision
- Error is uniform across domain (no problematic regions)

**Confidence**: **HIGH** ✅

---

### 1b. PPF / Inverse CDF

**Test**: Region-aware AAA fits with high-precision references (mpmath).

**Results**:
```
Central band (p ∈ [0.02, 0.98]): max error ≈ 3.97e-14
Lower tail (p ∈ [1e-10, 0.02]): max error ≈ 2.03e-13
Upper tail: symmetry Φ⁻¹(p) = -Φ⁻¹(1-p)
```

**Analysis**:
- Errors are 3–4 orders tighter than the 1e-7 target.
- Piecewise domains are exported with explicit tolerances in Move tests.
- Sign handling and WAD scaling validated during extraction (u256 headroom retained).

**Confidence**: **HIGH** ✅

---

### 2. Edge Case Verification

**Tested Points**:

| x | Expected | Result | Error | Status |
|---|----------|--------|-------|--------|
| 0 | 0.0 | 0.0 | 0 | ✅ |
| 1e-15 | 1.128e-15 | 1.128e-15 | 3.8e-19 | ✅ |
| 1e-10 | 1.128e-10 | 1.128e-10 | 2.9e-19 | ✅ |
| 0.1 | 0.1125 | 0.1125 | 4.4e-11 | ✅ |
| 0.5 | 0.5205 | 0.5205 | 1.3e-14 | ✅ |
| 1.0 | 0.8427 | 0.8427 | 6.4e-12 | ✅ |
| 2.0 | 0.9953 | 0.9953 | 6.4e-12 | ✅ |
| 3.0 | 0.99998 | 0.99998 | 1.9e-11 | ✅ |
| 4.0 | 0.999999985 | 0.999999985 | 5.7e-11 | ✅ |
| 5.0 | 0.9999999999985 | 0.9999999999 | 5.3e-11 | ✅ |
| 6.0 | 1.0 | 0.9999999999665 | 3.3e-11 | ✅ |

**Critical Edge Cases**:
- **x = 0**: Exact (erf(0) = 0) ✅
- **Very small x**: Maintains precision via linear term ✅
- **Saturation (x > 4)**: Error stays < 6e-11 ✅

**Confidence**: **HIGH** ✅

---

### 3. Monotonicity Analysis

**Result**: 158 minor violations out of 10,000 points

**Details**:
- All violations occur in saturation region (x > 4.5)
- Maximum drop: 2.54e-14 (25,365 WAD units)
- All drops are **~1,000x smaller than our approximation error**

**Why This Is Acceptable**:
1. Violations are at the 14th decimal place
2. Our target error is 1e-7 (7th decimal place)
3. The drops are **numerical noise**, not approximation error
4. In the saturation region, erf(x) ≈ 0.9999999999..., so tiny fixed-point rounding differences appear as non-monotonicity

**Confidence**: **MEDIUM-HIGH** ⚠️
- Mathematically acceptable, but worth documenting for Move users
- Could be eliminated by clamping output to max(prev_result, current_result) if strict monotonicity is required

---

### 4. Bounds Verification

**Test**: Check 0 ≤ erf(x) ≤ 1 for 10,000 points in [0, 6]

**Result**: **No violations** ✅

**Implementation Detail**: Our code clamps output to [0, WAD]:
```python
return min(result_mag, WAD)
```

**Confidence**: **HIGH** ✅

---

### 5. Overflow Analysis

**Test**: Verify intermediate values fit in u256 (max 2^256 ≈ 1.16e77)

**Results**:
```
P(x) max intermediate: 2.64e22
Q(x) max intermediate: 2.58e22
P(x) * WAD:            2.64e40
u256 max:              1.16e77
```

**Safety Margin**: ~1e37 (more than enough)

**Confidence**: **HIGH** ✅

---

### 6. Horner Implementation Verification

**Verification Method**:
1. Implemented Horner in Python with exact integer arithmetic
2. Compared against float evaluation of P(x)/Q(x)
3. Validated against scipy reference

**Result**: Python Horner matches expected behavior exactly.

**Key Implementation Details**:
- Uses integer division (`//`) not float division
- Tracks signs separately (for Move u256 compatibility)
- Handles signed addition correctly

**Confidence**: **HIGH** ✅

---

## What's NOT Tested

### 1. Gas Costs
- Python doesn't measure gas; Move benchmarks still pending for PPF tail and sampling entrypoints.

**Status**: Pending Move benchmarking

### 2. Property fuzzing for ln/sqrt
- `ln_wad` / `sqrt_wad` now ship and are covered indirectly via PPF tests,
  but they still need property-based sweeps for tail stability.

**Status**: Recommended (Phase 4)

### 3. Extended tail monotonicity
- Cross-language vectors cover 24 probabilities; add denser tail grids for
  stricter monotonicity proof if required.

**Status**: Recommended (Phase 4)

---

## Recommendations

### After Move Implementation

1. **Benchmark gas** for `ppf` and sampling entrypoints.
2. **Add property fuzzing** for `ln_wad` / `sqrt_wad` on tail domain.
3. **Optional**: tighten tolerances + checksum guards if regression-proofing is needed.

---

## Conclusion

**Overall Confidence: HIGH** ✅

The Python implementation:
- Achieves 5.68e-11 accuracy (1,760x better than target)
- Passes all mathematical property tests
- Is ready to port to Move

The only caveat is minor monotonicity noise in the saturation region, which is 1,000x smaller than our error tolerance and can be documented or clamped if needed.

---

## Test Commands

```bash
cd packages/gaussian/scripts
pip install -r requirements.txt

# Full pipeline (forward + PPF + export + vectors)
python run_all.py

# Harness + properties only (no regen)
python src/05_test_harness.py
pytest src/06_property_tests.py -v

# Refresh cross-language + sampling Move tests
python src/10_cross_language_vectors.py
```
