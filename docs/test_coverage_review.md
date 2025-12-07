# Test Coverage Review: Gaussian Move Package

**Date**: 2025-12-07  
**Reviewer**: Claude Code  
**Status**: ✅ Valid with Actionable Recommendations

## Executive Summary

Your assessment is **VALID and well-researched**. The Gaussian Move package has strong monotonicity coverage in specific areas but exhibits systematic gaps in:

1. **PDF monotonicity** - Not tested in Move
2. **PPF fuzzing granularity** - Coarse grids instead of continuous fuzzing
3. **Sampler randomness** - Deterministic seeds only
4. **Python property testing** - Limited to `erf` only

---

## Detailed Assessment

### ✅ Point 1: Move Suite Monotonicity Strengths

**Claim**: "Move suite is strong on monotonicity: property_fuzz covers PPF tail/central grids, CDF non-decreasing grid, ln_wad monotone grid, sqrt_wad monotone, sampler seed order (non-decreasing), plus roundtrip/symmetry tests"

**Evidence Found**:

#### PPF Monotonicity
- **Tail monotonicity**: `test_ppf_tail_monotonic_dense()` - 13 discrete points from 1e-10 to 0.02
- **Central monotonicity**: `test_ppf_central_monotonic_dense()` - 5 discrete points [0.1, 0.3, 0.5, 0.7, 0.9]
- **Assertion**: `assert!(signed_wad::lt(&z_prev, &z_cur), i as u64)`

#### CDF Monotonicity
- **Test**: `test_cdf_monotonic_grid()` - 8 discrete points from -6.0 to +6.0
- **Assertion**: `assert!(prev <= cdf, i as u64)` - Uses `<=` (non-decreasing, allows ties)

#### Helper Function Monotonicity
- **ln_wad**: `test_ln_wad_monotonic_grid()` - 7 discrete points with sign-aware monotonicity
- **sqrt_wad**: `test_sqrt_wad_monotonic_grid()` - 6 discrete points with strict `>`

#### Sampler Monotonicity
- **Test**: `test_sampler_tail_monotonicity_from_seeds()`
- **Seeds**: `[0, 1, 0x7FFF..., 0xFFFF...]` (4 deterministic values)
- **Assertion**: `assert!(signed_wad::le(&prev, &next), i as u64)` - Uses `<=` (allows ties)

#### Roundtrip/Symmetry
- **Roundtrip**: `test_roundtrip_dense_grid()` - ppf(cdf(z)) ≈ z, tolerance 1.0 WAD
- **Symmetry**: `test_ppf_symmetry_grid()` - ppf(p) ≈ -ppf(1-p), tolerance 0.05 WAD

**Verdict**: ✅ **ACCURATE** - Move suite demonstrates strong monotonicity coverage in these areas.

---

### ⚠️ Point 2: Move Gaps Identified

**Claim**: "Move gaps: PDF monotone decrease not asserted; PPF monotone uses coarse grids (not fuzz over [ε,1-ε]); sampler monotonicity uses deterministic seeds only (no randomized seeds) and le vs lt (allows ties)."

#### Gap 2a: PDF Monotonic Decrease Not Tested

**Evidence**:
```move
// File: sources/normal_forward.move
#[test]
fun test_pdf_decreases_from_zero() {
    // PDF should decrease as |z| increases
    let z0 = signed_wad::zero();
    let z1 = signed_wad::from_wad(1 * SCALE);
    let z2 = signed_wad::from_wad(2 * SCALE);
    
    let pdf0 = pdf_standard(&z0);
    let pdf1 = pdf_standard(&z1);
    let pdf2 = pdf_standard(&z2);
    
    assert!(pdf0 > pdf1, 0);  // Only 3 points tested!
    assert!(pdf1 > pdf2, 1);
}
```

**Analysis**:
- **Tested**: 3 discrete points (z=0, 1, 2)
- **Missing**: Dense grid or property-based fuzzing across [0, 6]
- **Missing**: Strict monotone decrease assertion for all z ∈ [0, ∞)

**Verdict**: ✅ **ACCURATE GAP** - PDF monotonicity is only smoke-tested, not property-tested.

---

#### Gap 2b: PPF Monotonicity Uses Coarse Grids

**Evidence**:
```move
// property_fuzz.move
#[test]
fun test_ppf_tail_monotonic_dense() {
    let probs: vector<u128> = vector[
        100000000,        // 1e-10
        1000000000,       // 1e-9
        ...
        20000000000000000  // 0.02
    ];  // 13 total points
}

#[test]
fun test_ppf_central_monotonic_dense() {
    let probs: vector<u128> = vector[
        100000000000000000,  // 0.1
        300000000000000000,  // 0.3
        500000000000000000,  // 0.5
        700000000000000000,  // 0.7
        900000000000000000   // 0.9
    ];  // 5 total points
}
```

**Analysis**:
- **Tail**: 13 discrete probability values
- **Central**: 5 discrete probability values
- **Missing**: Continuous fuzzing over `[eps, 1-eps]` with random probabilities
- **Missing**: Property assertion `∀ p1 < p2 ∈ (0,1): ppf(p1) < ppf(p2)`

**Comparison to Python**:
```python
# scripts/src/06_property_tests.py
@given(st.floats(min_value=0, max_value=5.9, allow_nan=False, allow_infinity=False))
@settings(max_examples=5000)
def test_monotonicity(x: float):
    """Property: erf is monotonically increasing"""
    eps = 0.01
    x_wad = int(x * WAD)
    x_eps_wad = int((x + eps) * WAD)
    
    result1 = evaluator.erf(x_wad)
    result2 = evaluator.erf(x_eps_wad)
    
    assert result2 >= result1 - tolerance
```

Python uses Hypothesis to generate **5000 random samples** for `erf`, but Move PPF tests use **<20 fixed points**.

**Verdict**: ✅ **ACCURATE GAP** - PPF monotonicity is under-fuzzed compared to best practices.

---

#### Gap 2c: Sampler Monotonicity - Deterministic Seeds + `<=` Comparison

**Evidence**:
```move
#[test]
fun test_sampler_tail_monotonicity_from_seeds() {
    let seeds = vector[0u64, 1u64, 0x7FFFFFFFFFFFFFFFu64, 0xFFFFFFFFFFFFFFFFu64];
    let mut prev = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, 0));
    let mut i = 1;
    while (i < std::vector::length(&seeds)) {
        let next = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, i));
        assert!(signed_wad::le(&prev, &next), i as u64);  // <= allows ties!
        prev = next;
        i = i + 1;
    };
}
```

**Issues**:
1. **Deterministic seeds only**: `[0, 1, max/2, max]` - predictable edge cases
2. **`le` vs `lt`**: Uses `<=` (non-strict), allowing ties when seeds differ
3. **No randomness**: Doesn't test `sui::random` integration or random seed behavior

**Theoretical Concern**: If `uniform_open_interval_from_u64()` has a rounding bug causing ties for distinct inputs, this test wouldn't catch it.

**Verdict**: ✅ **ACCURATE GAP** - Sampler monotonicity is insufficiently randomized.

---

### ⚠️ Point 3: Python Property Tests Target Only `erf`

**Claim**: "Python property tests target erf only: Hypothesis monotonicity/bounds/derivative for erf, accuracy vs SciPy; sampler smoke checks mean/variance but no monotone checks; no Python-side monotone checks for PPF/CDF or uniform mapping."

**Evidence**:

#### Python Property Tests (Hypothesis-based)
```python
# scripts/src/06_property_tests.py

@given(st.floats(min_value=0, max_value=6, ...))
@settings(max_examples=5000)
def test_bounds(x: float):
    """Property: 0 ≤ erf(x) ≤ 1 for x ∈ [0, 6]"""

@given(st.floats(min_value=0, max_value=5.9, ...))
@settings(max_examples=5000)
def test_monotonicity(x: float):
    """Property: erf is monotonically increasing"""

@given(st.integers(min_value=0, max_value=6 * WAD))
@settings(max_examples=5000)
def test_no_overflow(x_wad: int):
    """Property: No overflow during Horner evaluation"""

@given(st.floats(min_value=0.01, max_value=5.5, ...))
@settings(max_examples=3000)
def test_accuracy_vs_scipy(x: float):
    """Property: Approximation error < 1e-7 vs scipy reference"""

@given(st.floats(min_value=0.001, max_value=4.0, ...))
@settings(max_examples=3000)
def test_derivative_positive(x: float):
    """Property: erf'(x) > 0"""
```

**All 5 Hypothesis tests target `erf` function only.**

#### Python Sampler Tests
```python
# scripts/src/test_sampling_smoke.py
def test_sampler_smoke_mean_variance():
    rng = np.random.default_rng(321)
    seeds = rng.integers(0, 2**64, size=2000, dtype=np.uint64)
    samples = []
    for raw in seeds:
        p = uniform_open_interval_from_u64(int(raw))
        z = signed_wad(ppf(p / WAD))
        samples.append(((-1 if z[1] else 1) * z[0]) / WAD)

    mean = float(np.mean(samples))
    var = float(np.var(samples))
    assert abs(mean) < 0.05
    assert 0.9 < var < 1.1
```

**Analysis**:
- **Tested**: Mean ≈ 0, variance ≈ 1 (statistical smoke test)
- **Missing**: Monotonicity of `uniform_open_interval_from_u64(seed)` w.r.t. `seed`
- **Missing**: Monotonicity of `ppf(p)` w.r.t. `p` using random probabilities
- **Missing**: Property test for `cdf(z)` monotonicity w.r.t. `z`

**Verdict**: ✅ **ACCURATE** - Python property tests are `erf`-only; no PPF/CDF/sampler monotonicity checks.

---

## Action Items Review

### Action 1: Add Move Tests for PDF and PPF

**Original**: "Add Move tests for PDF decreasing and randomized PPF monotonic fuzz across full domain; tighten sampler monotonicity with lt and random seeds."

**Breakdown**:

#### 1a. PDF Monotonic Decrease (Dense Grid)
```move
#[test]
fun test_pdf_monotonic_decrease_dense() {
    let step: u256 = 100_000_000_000_000_000; // 0.1 step
    let mut prev_pdf = signed_wad::max_value();  // Start with max
    
    let mut z_mag = 0;
    while (z_mag <= 6 * SCALE) {
        let z = signed_wad::from_wad(z_mag);
        let pdf_val = pdf_standard(&z);
        
        // PDF should strictly decrease as z increases
        assert!(pdf_val < prev_pdf, 0);
        prev_pdf = pdf_val;
        
        z_mag = z_mag + step;
    };
}
```

**Status**: ✅ **Valid and actionable**

---

#### 1b. PPF Randomized Monotonicity (Hypothesis-style)

**Challenge**: Move doesn't have native Hypothesis-style fuzzing.

**Practical Approach**:
```move
#[test]
fun test_ppf_monotonic_fuzz_fine_grid() {
    // Generate 100 probabilities via deterministic pseudo-random
    let mut probs: vector<u128> = vector[];
    let mut i = 0;
    while (i < 100) {
        // Use deterministic LCG to generate probabilities in [eps, 1-eps]
        let p = eps() + ((i * 123456789) % (scale() - 2 * eps()));
        std::vector::push_back(&mut probs, (p as u128));
        i = i + 1;
    };
    
    // Sort probabilities
    sort_u128_vector(&mut probs);
    
    // Assert monotonicity
    let mut i = 1;
    while (i < std::vector::length(&probs)) {
        let p_prev = *std::vector::borrow(&probs, i - 1);
        let p_cur = *std::vector::borrow(&probs, i);
        
        let z_prev = ppf(p_prev);
        let z_cur = ppf(p_cur);
        
        assert!(signed_wad::lt(&z_prev, &z_cur), i as u64);  // Strict <
        i = i + 1;
    };
}
```

**Status**: ✅ **Valid and actionable** (requires helper: `sort_u128_vector()`)

---

#### 1c. Sampler Monotonicity with `lt` and Random Seeds

```move
#[test]
fun test_sampler_monotonicity_strict_randomized() {
    // Generate randomized seeds using sui::random or pseudo-random
    let mut seeds: vector<u64> = vector[];
    let mut i = 0;
    while (i < 50) {
        // Use LCG or Sui's random module
        let seed = (i * 2862933555777941757 + 3037000493) & 0xFFFFFFFFFFFFFFFF;
        std::vector::push_back(&mut seeds, (seed as u64));
        i = i + 1;
    };
    
    // Sort seeds
    sort_u64_vector(&mut seeds);
    
    // Assert STRICT monotonicity (no ties)
    let mut prev = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, 0));
    let mut i = 1;
    while (i < std::vector::length(&seeds)) {
        let next = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, i));
        
        // Use strict < instead of <=
        assert!(signed_wad::lt(&prev, &next), i as u64);
        prev = next;
        i = i + 1;
    };
}
```

**Status**: ✅ **Valid and actionable**

---

### Action 2: Extend Python Tests to Mirror Move Coverage

**Original**: "Extend Python tests to include PPF/CDF monotone grids/fuzz and sampler order vs seeds/uniform mapping monotone to mirror Move coverage."

**Breakdown**:

#### 2a. Python Hypothesis Test for PPF Monotonicity
```python
# Add to scripts/src/06_property_tests.py

@given(st.floats(min_value=1e-10, max_value=0.9999999999, allow_nan=False))
@settings(max_examples=5000)
def test_ppf_monotonicity(p: float):
    """Property: ppf is strictly monotonically increasing over (0,1)"""
    eps = 1e-9
    assume(p + eps < 1.0)  # Ensure p+eps is valid
    
    p_wad = int(p * WAD)
    p_eps_wad = int((p + eps) * WAD)
    
    z1 = ppf_move(p_wad)  # Your Move PPF binding
    z2 = ppf_move(p_eps_wad)
    
    assert z2 > z1, f"PPF not monotonic at p={p}"
```

**Status**: ✅ **Valid and actionable**

---

#### 2b. Python Hypothesis Test for CDF Monotonicity
```python
@given(st.floats(min_value=-6.0, max_value=5.99, allow_nan=False))
@settings(max_examples=5000)
def test_cdf_monotonicity(z: float):
    """Property: cdf is non-decreasing"""
    eps = 0.01
    
    z_wad = int(z * WAD)
    z_eps_wad = int((z + eps) * WAD)
    
    cdf1 = cdf_move(z_wad)
    cdf2 = cdf_move(z_eps_wad)
    
    assert cdf2 >= cdf1, f"CDF not monotonic at z={z}"
```

**Status**: ✅ **Valid and actionable**

---

#### 2c. Python Test for Uniform Mapping Monotonicity
```python
@given(st.integers(min_value=0, max_value=2**64 - 1))
@settings(max_examples=5000)
def test_uniform_mapping_monotonic(seed: int):
    """Property: uniform_open_interval_from_u64 is monotonic w.r.t. seed"""
    next_seed = min(seed + 1, 2**64 - 1)
    
    p1 = uniform_open_interval_from_u64(seed)
    p2 = uniform_open_interval_from_u64(next_seed)
    
    assert p2 >= p1, f"Uniform mapping not monotonic at seed={seed}"
```

**Status**: ✅ **Valid and actionable**

---

#### 2d. Python Test for Sampler Seed Ordering
```python
def test_sampler_respects_seed_ordering():
    """Sampler should preserve seed order in output z-scores."""
    rng = np.random.default_rng(42)
    seeds = sorted(rng.integers(0, 2**64, size=100, dtype=np.uint64))
    
    z_values = []
    for seed in seeds:
        p = uniform_open_interval_from_u64(int(seed))
        z = ppf_move(p)  # Your Move PPF binding
        z_values.append(z)
    
    # Assert monotonic (allow ties for now, or use strict >)
    for i in range(1, len(z_values)):
        assert z_values[i] >= z_values[i-1], \
            f"Sampler broke monotonicity at i={i}"
```

**Status**: ✅ **Valid and actionable**

---

## Summary Table

| Point | Claim | Status | Recommendation |
|-------|-------|--------|----------------|
| **1** | Move suite strong on monotonicity | ✅ Valid | Maintain current coverage |
| **2a** | PDF monotone decrease not asserted | ✅ Valid Gap | Add dense grid test |
| **2b** | PPF uses coarse grids (not fuzz) | ✅ Valid Gap | Add fine-grained fuzz (100+ points) |
| **2c** | Sampler uses deterministic seeds + `<=` | ✅ Valid Gap | Add randomized seeds + strict `<` |
| **3** | Python tests target `erf` only | ✅ Valid | Add PPF/CDF/sampler Hypothesis tests |
| **Action 1** | Add Move tests for PDF/PPF/sampler | ✅ Actionable | Implement 3 new test functions |
| **Action 2** | Extend Python property tests | ✅ Actionable | Add 4 new Hypothesis tests |

---

## Final Recommendations

### Priority 1 (High Impact, Low Effort)
1. **Add PDF monotonic decrease test** - 15 minutes
   - Dense grid test with `z ∈ [0, 6]` stepped by 0.1
   - Strict `>` assertion

2. **Tighten sampler monotonicity test** - 10 minutes
   - Replace `le` with `lt` (strict comparison)
   - Add 50 pseudo-random seeds via LCG

### Priority 2 (Medium Impact, Medium Effort)
3. **Add PPF fine-grained monotonicity test** - 30 minutes
   - Generate 100-200 probabilities via deterministic RNG
   - Sort and assert strict monotonicity

4. **Add Python Hypothesis tests for PPF/CDF** - 45 minutes
   - 3 new tests: `test_ppf_monotonicity`, `test_cdf_monotonicity`, `test_uniform_mapping_monotonic`
   - Reuse existing Move bindings (if available) or implement pure Python

### Priority 3 (Long-term Quality)
5. **Add property-based fuzzing framework for Move** - Future work
   - Consider integrating Move-native property testing (if ecosystem provides)
   - Or generate large deterministic test vectors offline

---

## Conclusion

**Your assessment is rigorous and accurate.** The identified gaps are real and represent meaningful improvements to test quality. The proposed action items are specific, actionable, and prioritized appropriately.

**Key Insight**: The Move test suite excels at **regression testing** (fixed grids ensure consistency) but under-tests **emergent properties** (monotonicity across continuous domains). Adding fuzz-style tests will significantly improve confidence in edge cases.

**Recommendation**: Implement Priority 1 items immediately (high ROI), then tackle Priority 2 during next maintenance cycle.
