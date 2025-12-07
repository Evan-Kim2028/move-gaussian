# Gaussian Approximation Pipeline Specification

**Version**: 2.0  
**Date**: 2025-12-06  
**Status**: In Progress  
**Master Plan**: See `/Users/evandekim/Documents/learning_move/plans/gaussian-pipeline-plan-v2.md`

---

## Quick Reference

This is the working specification for the `scripts/` folder. The master plan with full details and rationale is in the `plans/` directory at the repository root.

### Key Changes in v2 (Based on Python Tools Inventory)

| Aspect | v1 | v2 (Current) | Reason |
|--------|-----|--------------|--------|
| AAA Library | `baryrat` only | `scipy.interpolate.AAA` + `baryrat` | SciPy is official (1.15+) |
| Validation | Custom tests | `hypothesis` property-based | Better edge case discovery |
| Reference | `scipy.special` | + `mpmath` arbitrary precision | Ground truth validation |
| Coverage | Forward only | Forward + PPF + sampler vectors | End-to-end Move parity |
| Guardrails | None | FNV-128 checksums in Move export | Detect stale/tampered coeffs |

---

## Overview

This document specifies the complete pipeline for creating an on-chain Gaussian distribution library using the AAA algorithm for optimal rational approximation design.

### Core Principle

**AAA is a design-time tool, not a runtime component.**

```
┌─────────────────────────────────────────────────────────────────┐
│                    OFFLINE PIPELINE (Python)                     │
│                                                                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│  │  Step 1  │ → │  Step 2  │ → │  Step 3  │ → │  Step 4  │     │
│  │  Sample  │   │  AAA     │   │  Convert │   │  Scale   │     │
│  │  erf/Φ   │   │  Approx  │   │  to P/Q  │   │  Fixed   │     │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘     │
│                                                    │            │
│                                                    ▼            │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│  │  Step 8  │ ← │  Step 7  │ ← │  Step 6  │ ← │  Step 5  │     │
│  │  Export  │   │  Verify  │   │  Test    │   │  Horner  │     │
│  │  Coeffs  │   │  Props   │   │  Harness │   │  Python  │     │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘     │
│       │                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ON-CHAIN (Move)                               │
│                                                                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                     │
│  │  Step 9  │ → │  Step 10 │ → │  Step 11 │                     │
│  │  Horner  │   │  Move    │   │  Publish │                     │
│  │  Move    │   │  Tests   │   │          │                     │
│  └──────────┘   └──────────┘   └──────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
scripts/
├── docs/
│   ├── SPECIFICATION.md
│   └── VERIFICATION_REPORT.md
├── images/                  # Approximation plots
├── outputs/
│   ├── coefficients.json              # Forward P/Q (float)
│   ├── scaled_coefficients.json       # Forward, WAD + signs
│   ├── scaled_ppf_coefficients.json   # PPF central/tail, WAD + signs
│   ├── test_results.json              # Harness summary
│   └── move_generated/                # Move artifacts
├── src/
│   ├── 01_aaa_exploration.py            # AAA for erf/erfc/phi
│   ├── 01b_aaa_ppf.py                   # AAA for inverse CDF
│   ├── 02_extract_coefficients.py       # Forward barycentric → P/Q
│   ├── 02b_extract_ppf_coefficients.py  # PPF extraction + scaling
│   ├── 03_scale_fixed_point.py          # Forward scaling (WAD)
│   ├── 04_horner_python.py              # Fixed-point Horner reference
│   ├── 05_test_harness.py               # Accuracy/edge/bounds/overflow
│   ├── 05b_test_precision_limits.py     # Optional precision sweeps
│   ├── 06_property_tests.py             # Hypothesis properties
│   ├── 07_export_for_move.py            # Legacy forward export
│   ├── 07_export_for_move_gaussian.py   # Unified CDF/PDF/PPF export + checksums
│   ├── 10_cross_language_vectors.py     # Cross-language + sampling Move tests
│   ├── test_coefficients_metadata.py
│   ├── test_horner_properties.py
│   └── test_sampling_smoke.py
└── requirements.txt
```

---

## Pipeline Steps

### Phase 1: AAA Approximation

- **Forward (erf/erfc/phi)**: `src/01_aaa_exploration.py`  
  Domain z ∈ [0, 6]; 2000 samples; tol = 1e-13; reference = mpmath 50 dps (fallback: scipy). Typical degree (11,11) with max error ≈ 5.7e-11.

- **Inverse CDF (PPF)**: `src/01b_aaa_ppf.py`  
  Central band p ∈ [0.02, 0.98] rational in p; lower tail p ∈ [1e-10, 0.02] rational in t = sqrt(-2·ln(p)); upper tail via symmetry Φ⁻¹(p) = -Φ⁻¹(1-p).

---

### Phase 2: Coefficient Extraction & Scaling

- **Forward extraction**: `src/02_extract_coefficients.py`  
  Converts barycentric → P/Q; validates poly vs barycentric (<1e-12 diff). Output: `outputs/coefficients.json`.

- **Forward scaling**: `src/03_scale_fixed_point.py`  
  WAD scaling (1e18), sign split for Move u256, overflow simulation for z ≤ 6. Output: `outputs/scaled_coefficients.json`.

- **PPF extraction + scaling**: `src/02b_extract_ppf_coefficients.py`  
  AAA per region, least-squares poly reconstruction, WAD scaling/sign split. Output: `outputs/scaled_ppf_coefficients.json`.

---

### Phase 3: Python Verification

- **Fixed-point Horner reference**: `src/04_horner_python.py` (mirrors Move semantics with sign-split integers).
- **Harness**: `src/05_test_harness.py`  
  Accuracy vs scipy + mpmath (10k points), edge cases, bounds, monotonicity tolerance, overflow simulation, symmetry docs. Writes `outputs/test_results.json`.
- **Property-based tests**: `src/06_property_tests.py`  
  Hypothesis coverage: bounds, monotonicity, overflow, accuracy slice, derivative sign, erfc complement.
- **Optional precision sweep**: `src/05b_test_precision_limits.py` (slow, opt-in).

---

### Phase 4: Export for Move

- **Unified export**: `src/07_export_for_move_gaussian.py`  
  Inputs: `scaled_coefficients.json`, `scaled_ppf_coefficients.json`, `pdf_aaa_results.json`.  
  Outputs: `artifacts/move_generated/coefficients.move` + `gaussian_coefficients_summary.json`.  
  Embeds FNV-128 checksums and Move tests to assert checksum matches.

- **Cross-language + sampling vectors**: `src/10_cross_language_vectors.py`  
  Outputs: `tests/cross_language_vectors.move`, `tests/sampling_integration.move`; optional CSV for offline inspection.

---

### Phase 5: Move Implementation (Steps 9-11)

#### Step 9: Horner Evaluation in Move
**Location**: `sources/gaussian.move`

```move
public fun horner_eval(x: u256, coeffs: &vector<u256>, signs: &vector<bool>): (u256, bool) {
    // Fixed-point Horner evaluation with sign tracking
}

public fun erf(x: u256): (u256, bool) {
    let (p, p_neg) = horner_eval(x, &P_COEFFS, &P_SIGNS);
    let (q, q_neg) = horner_eval(x, &Q_COEFFS, &Q_SIGNS);
    // Return p/q with proper sign
}
```

#### Step 10: Move Tests
- Port test vectors from Python
- Differential testing against known values

#### Step 11: Publish
- Deploy to testnet
- Benchmark gas costs
- Compare with Solidity implementations

---

## Success Criteria

### Accuracy
- [ ] Max error < 1e-7 vs reference (current forward: ~5.7e-11)
- [ ] Proper handling of edge cases (0, saturation, tails)

### Safety
- [ ] No poles in evaluation domain
- [ ] No overflow in Horner evaluation (simulated)
- [ ] Bounded output [0, 1] (clamp)

### Performance
- [ ] Python verification: < 1ms per evaluation
- [ ] Move: competitive with solgauss gas costs (bench pending)

### Correctness
- [ ] Monotonicity verified (tolerance in saturation)
- [ ] Symmetry: erf(-x) = -erf(x) (documented)
- [ ] Asymptotes correct

---

## Current Status

| Step | Status | Script |
|------|--------|--------|
| Forward AAA + extraction | ✅ | `01_aaa_exploration.py`, `02_extract_coefficients.py` |
| Forward scaling | ✅ | `03_scale_fixed_point.py` |
| PPF AAA + scaling | ✅ | `01b_aaa_ppf.py`, `02b_extract_ppf_coefficients.py` |
| PDF fit for export | ✅ | Consumed via `07_export_for_move_gaussian.py` |
| Python Horner + harness | ✅ | `04_horner_python.py`, `05_test_harness.py` |
| Property tests | ✅ | `06_property_tests.py` |
| Move export + checksums | ✅ | `07_export_for_move_gaussian.py` |
| Cross-language + sampling vectors | ✅ | `10_cross_language_vectors.py` |
| Move integration tests | ✅ | `tests/` |
| Publish / gas benchmarks | 🔲 | Devnet benchmarking pending |

---

## References

- [AAA Algorithm Paper](https://arxiv.org/abs/1612.00337)
- [baryrat Python library](https://github.com/c-f-h/baryrat)
- [solgauss Solidity implementation](https://github.com/cairoeth/solgauss)
- [SolStat Solidity implementation](https://github.com/primitivefinance/solstat)
