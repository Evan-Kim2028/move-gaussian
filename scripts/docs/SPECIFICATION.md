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
| New Step | None | `06_property_tests.py` | Verify monotonicity, bounds |

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
│   ├── SPECIFICATION.md      # This file
│   └── VERIFICATION.md       # Test results and validation
├── images/
│   ├── aaa_erf.png          # Approximation plots
│   ├── aaa_erfc.png
│   └── aaa_phi.png
├── outputs/
│   ├── coefficients.json    # Extracted P/Q coefficients
│   ├── scaled_coeffs.json   # Fixed-point scaled coefficients
│   └── test_vectors.json    # Test cases for Move
├── src/
│   ├── 01_aaa_exploration.py    # Step 1-2: Sample + AAA
│   ├── 02_convert_to_poly.py    # Step 3: Barycentric → P/Q
│   ├── 03_scale_fixed_point.py  # Step 4: Scale to WAD
│   ├── 04_horner_python.py      # Step 5: Horner implementation
│   ├── 05_test_harness.py       # Step 6: Comprehensive tests
│   ├── 06_verify_properties.py  # Step 7: Monotonicity, bounds
│   └── 07_export_for_move.py    # Step 8: Generate Move constants
└── requirements.txt
```

---

## Pipeline Steps

### Phase 1: AAA Approximation (Steps 1-2)

#### Step 1: Sample the Target Function
**Script**: `src/01_aaa_exploration.py` (existing)

**Input**: None (uses scipy.special.erf)  
**Output**: Sample points and function values

**Specification**:
- Domain: [0, 6] for erf (use symmetry for negative)
- Sample density: 1000 points (uniform grid)
- High-precision reference values from scipy

#### Step 2: Run AAA Algorithm
**Script**: `src/01_aaa_exploration.py` (existing)

**Input**: Sample points and values  
**Output**: Barycentric rational approximation

**Specification**:
- Tolerance: 1e-10
- Expected degree: ~(11, 11) for erf
- Verify: No poles in [0, 6]

**Current Results**:
| Function | Degree | Max Error |
|----------|--------|-----------|
| erf | (11, 11) | 4.4e-11 |
| erfc | (11, 11) | 4.4e-11 |
| Φ | (11, 11) | 6.98e-13 |

---

### Phase 2: Coefficient Extraction (Steps 3-4)

#### Step 3: Convert Barycentric to P(x)/Q(x)
**Script**: `src/02_convert_to_poly.py` (TO CREATE)

**Input**: Barycentric rational (nodes, weights, values)  
**Output**: Polynomial coefficients P[0..m], Q[0..n]

**Algorithm**:
```python
# Barycentric form:
# r(x) = Σ (w_j * f_j) / (x - z_j)  /  Σ w_j / (x - z_j)

# Convert to explicit polynomials:
# 1. Compute common denominator: Π(x - z_j)
# 2. Expand numerator and denominator
# 3. Extract coefficient vectors
```

**Validation**:
- Evaluate P(x)/Q(x) at test points
- Compare with original barycentric evaluation
- Max difference should be < 1e-14 (floating-point precision)

#### Step 4: Scale to Fixed-Point
**Script**: `src/03_scale_fixed_point.py` (TO CREATE)

**Input**: Float coefficients P[], Q[]  
**Output**: Integer coefficients scaled by WAD = 1e18

**Specification**:
- Scale: WAD = 10^18
- All coefficients stored as signed 256-bit integers
- Track sign separately for Move compatibility

**Considerations**:
- Check coefficient magnitudes fit in u256/i256
- Document precision loss from rounding
- Normalize Q[0] = 1 (or scale appropriately)

---

### Phase 3: Python Verification (Steps 5-7)

#### Step 5: Implement Horner Evaluation in Python
**Script**: `src/04_horner_python.py` (TO CREATE)

**Input**: Scaled coefficients, input x (as integer)  
**Output**: erf(x) as scaled integer

**Horner's Method**:
```python
def horner_eval(x: int, coeffs: list[int], scale: int) -> int:
    """
    Evaluate polynomial using Horner's rule with fixed-point arithmetic.
    
    P(x) = c[0] + c[1]*x + c[2]*x² + ... + c[n]*x^n
         = c[0] + x*(c[1] + x*(c[2] + ... + x*c[n]))
    """
    result = 0
    for c in reversed(coeffs):
        result = (result * x) // scale + c
    return result

def rational_eval(x: int, p_coeffs: list[int], q_coeffs: list[int], scale: int) -> int:
    """Evaluate P(x)/Q(x) in fixed-point."""
    p = horner_eval(x, p_coeffs, scale)
    q = horner_eval(x, q_coeffs, scale)
    return (p * scale) // q
```

**Validation**:
- Compare fixed-point result with high-precision float
- Track maximum error introduced by fixed-point

#### Step 6: Test Harness
**Script**: `src/05_test_harness.py` (TO CREATE)

**Test Categories**:

1. **Accuracy Tests**
   - Compare with scipy.special.erf at 10,000 points
   - Max error < 1e-7 (after fixed-point conversion)
   - Mean error tracking

2. **Edge Cases**
   - x = 0: erf(0) = 0
   - x = 6: erf(6) ≈ 1
   - x very small: erf(1e-10) ≈ 1.128e-10
   - x very large: erf(100) = 1 (clamped)

3. **Overflow Tests**
   - Verify no intermediate overflow in Horner evaluation
   - Test with maximum input values

4. **Symmetry Tests**
   - Verify erf(-x) = -erf(x)
   - Or document how to handle negative inputs

**Output**: `outputs/test_vectors.json` with test cases for Move

#### Step 7: Verify Mathematical Properties
**Script**: `src/06_verify_properties.py` (TO CREATE)

**Properties to Verify**:

1. **Monotonicity**: erf'(x) ≥ 0 for all x ≥ 0
   - Compute derivative of rational approximation
   - Check sign at dense grid points

2. **Bounds**: 0 ≤ erf(x) ≤ 1 for x ≥ 0
   - Evaluate at dense grid
   - Check no overshoots

3. **Asymptotic Behavior**:
   - lim(x→∞) erf(x) = 1
   - lim(x→0) erf(x)/x = 2/√π

4. **No Division by Zero**:
   - Q(x) > 0 for all x in [0, 6]
   - Check denominator at dense grid

---

### Phase 4: Export for Move (Step 8)

#### Step 8: Generate Move Constants
**Script**: `src/07_export_for_move.py` (TO CREATE)

**Output**: Move-compatible constant declarations

```move
// Auto-generated from AAA approximation pipeline
// DO NOT EDIT MANUALLY

module gaussian::coefficients {
    // Scale factor (WAD)
    const SCALE: u256 = 1_000_000_000_000_000_000;
    
    // Numerator coefficients P(x) = P0 + P1*x + P2*x² + ...
    const P0: u256 = ...;
    const P1: u256 = ...;
    // ... etc
    
    // Denominator coefficients Q(x) = Q0 + Q1*x + Q2*x² + ...
    const Q0: u256 = ...;
    const Q1: u256 = ...;
    // ... etc
    
    // Sign flags for signed arithmetic
    const P0_NEG: bool = false;
    // ... etc
}
```

Also export:
- Test vectors as Move test cases
- Expected results for verification

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
- [ ] Max error < 1e-7 vs scipy reference
- [ ] Proper handling of edge cases (0, large x)

### Safety
- [ ] No poles in evaluation domain
- [ ] No overflow in Horner evaluation
- [ ] Bounded output [0, 1]

### Performance
- [ ] Python verification: < 1ms per evaluation
- [ ] Move: competitive with solgauss gas costs

### Correctness
- [ ] Monotonicity verified
- [ ] Symmetry: erf(-x) = -erf(x)
- [ ] Asymptotes correct

---

## Current Status

| Step | Status | Script |
|------|--------|--------|
| 1. Sample | ✅ Complete | `01_aaa_exploration.py` |
| 2. AAA | ✅ Complete | `01_aaa_exploration.py` |
| 3. Convert to P/Q | 🔲 TODO | `02_convert_to_poly.py` |
| 4. Scale fixed-point | 🔲 TODO | `03_scale_fixed_point.py` |
| 5. Horner Python | 🔲 TODO | `04_horner_python.py` |
| 6. Test harness | 🔲 TODO | `05_test_harness.py` |
| 7. Verify properties | 🔲 TODO | `06_verify_properties.py` |
| 8. Export for Move | 🔲 TODO | `07_export_for_move.py` |
| 9. Horner Move | 🔲 TODO | `sources/gaussian.move` |
| 10. Move tests | 🔲 TODO | `sources/tests/` |
| 11. Publish | 🔲 TODO | - |

---

## References

- [AAA Algorithm Paper](https://arxiv.org/abs/1612.00337)
- [baryrat Python library](https://github.com/c-f-h/baryrat)
- [solgauss Solidity implementation](https://github.com/cairoeth/solgauss)
- [SolStat Solidity implementation](https://github.com/primitivefinance/solstat)
