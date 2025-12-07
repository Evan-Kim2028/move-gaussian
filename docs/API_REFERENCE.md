# Gaussian Package API Reference

**Version**: 1.0.0  
**Package ID (Testnet)**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`  
**License**: MIT

---

## Table of Contents

1. [Overview](#overview)
2. [Constants](#constants)
3. [Types](#types)
4. [Module: sampling](#module-sampling)
5. [Module: normal_forward](#module-normal_forward)
6. [Module: normal_inverse](#module-normal_inverse)
7. [Module: erf](#module-erf)
8. [Module: signed_wad](#module-signed_wad)
9. [Module: math](#module-math)
10. [Error Codes](#error-codes)

---

## Overview

The Gaussian package provides on-chain Gaussian (normal) distribution functions for Sui Move smart contracts. All arithmetic uses **WAD scaling** (10^18) for fixed-point precision.

### Key Features

- **CDF** (Cumulative Distribution Function): `Φ(z)` - probability that Z ≤ z
- **PDF** (Probability Density Function): `φ(z)` - probability density at z
- **PPF** (Percent Point Function / Inverse CDF): `Φ⁻¹(p)` - z-score for probability p
- **Sampling**: Generate Gaussian random samples using `sui::random`
- **Error Function**: `erf(x)` and `erfc(x)` implementations

### WAD Scaling Convention

All values are scaled by 10^18:

| Real Value | WAD Value |
|------------|-----------|
| 1.0 | `1_000_000_000_000_000_000` |
| 0.5 | `500_000_000_000_000_000` |
| -2.5 | SignedWad { magnitude: `2_500_000_000_000_000_000`, negative: true } |

---

## Constants

### Scale Factor

```move
const SCALE: u256 = 1_000_000_000_000_000_000; // 10^18 (WAD)
```

### Domain Limits

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_Z` | 6 × SCALE | Maximum \|z\| value (~6σ covers 99.9999998%) |
| `EPS` | 100_000_000 | Minimum probability (~10^-10 WAD) |
| `P_LOW` | 0.02 × SCALE | Central region lower bound |
| `P_HIGH` | 0.98 × SCALE | Central region upper bound |

---

## Types

### SignedWad

```move
public struct SignedWad has copy, drop, store {
    magnitude: u256,
    negative: bool,
}
```

Signed fixed-point value for representing real numbers (including negatives).

**Usage:**
```move
use gaussian::signed_wad::{Self, SignedWad};

let positive = signed_wad::from_wad(1_000_000_000_000_000_000); // 1.0
let negative = signed_wad::new(2_500_000_000_000_000_000, true); // -2.5
let zero = signed_wad::zero();
```

### StandardNormal

```move
public struct StandardNormal has copy, drop, store {
    value: SignedWad,
}
```

A sample from the standard normal distribution N(0, 1).

---

## Module: sampling

Primary module for generating Gaussian random samples.

### Primary Functions

#### `sample_z`

```move
#[allow(lint(public_random))]
public fun sample_z(
    r: &random::Random,
    ctx: &mut TxContext,
): SignedWad
```

Sample from standard normal distribution N(0, 1).

**Parameters:**
- `r`: Reference to Sui's Random object
- `ctx`: Transaction context

**Returns:** SignedWad z-score

**Example:**
```move
use gaussian::sampling;

public entry fun my_function(r: &Random, ctx: &mut TxContext) {
    let z = sampling::sample_z(r, ctx);
    // z is a SignedWad sample from N(0,1)
}
```

---

#### `sample_standard_normal`

```move
#[allow(lint(public_random))]
public fun sample_standard_normal(
    r: &random::Random,
    ctx: &mut TxContext,
): StandardNormal
```

Sample from N(0, 1), returning a `StandardNormal` wrapper.

**Parameters:**
- `r`: Reference to Sui's Random object
- `ctx`: Transaction context

**Returns:** StandardNormal struct containing the sample

---

#### `sample_normal`

```move
#[allow(lint(public_random))]
public fun sample_normal(
    r: &random::Random,
    mean: u256,
    std_dev: u256,
    ctx: &mut TxContext,
): StandardNormal
```

Sample from custom normal distribution N(μ, σ²).

**Parameters:**
- `r`: Reference to Sui's Random object
- `mean`: μ in WAD scaling (e.g., 1.5 × 10^18 for μ=1.5)
- `std_dev`: σ in WAD scaling (must be > 0)
- `ctx`: Transaction context

**Returns:** StandardNormal struct

**Aborts:** `EInvalidStdDev` (401) if `std_dev == 0`

**Example:**
```move
// Sample from N(100, 15²) - like an IQ distribution
let mean = 100_000_000_000_000_000_000; // 100.0
let std_dev = 15_000_000_000_000_000_000; // 15.0
let sample = sampling::sample_normal(r, mean, std_dev, ctx);
```

---

### StandardNormal Accessors

#### `magnitude`

```move
public fun magnitude(sn: &StandardNormal): u256
```

Get the absolute value of the sample.

---

#### `is_negative`

```move
public fun is_negative(sn: &StandardNormal): bool
```

Check if the sample is negative.

---

#### `to_signed_wad`

```move
public fun to_signed_wad(sn: &StandardNormal): SignedWad
```

Convert to SignedWad for use with other Gaussian functions.

---

#### `from_signed_wad`

```move
public fun from_signed_wad(sw: &SignedWad): StandardNormal
```

Create StandardNormal from a SignedWad.

---

### CLT-Based Functions (Alternative Implementation)

#### `clt_from_uniforms`

```move
public fun clt_from_uniforms(uniforms: &vector<u256>): (u256, bool)
```

Core CLT-based sampler from pre-generated uniforms.

**Parameters:**
- `uniforms`: Vector of 12 WAD-scaled uniform values in [0, SCALE]

**Returns:** (magnitude, is_negative)

---

#### `sample_standard_normal_clt`

```move
#[allow(lint(public_random))]
public fun sample_standard_normal_clt(
    r: &random::Random,
    ctx: &mut TxContext,
): (u256, bool)
```

Sample N(0,1) using Central Limit Theorem (sum of 12 uniforms).

**Returns:** (magnitude, is_negative)

**Note:** PPF-based sampling (`sample_z`) is more accurate, especially in tails.

---

#### `sample_normal_clt`

```move
#[allow(lint(public_random))]
public fun sample_normal_clt(
    r: &random::Random,
    mean: u256,
    std_dev: u256,
    ctx: &mut TxContext,
): (u256, bool)
```

Sample N(μ, σ²) using CLT method.

**Aborts:** `EInvalidStdDev` (401) if `std_dev == 0`

---

## Module: normal_forward

Standard normal CDF and PDF functions.

### `cdf_standard`

```move
public fun cdf_standard(z: &SignedWad): u256
```

Standard normal CDF Φ(z) = P(Z ≤ z).

**Parameters:**
- `z`: z-score as SignedWad

**Returns:** Probability in [0, SCALE] (WAD-scaled)

**Behavior:**
- z < -6: returns ~0
- z = 0: returns SCALE/2 (0.5)
- z > 6: returns ~SCALE (1.0)

**Example:**
```move
use gaussian::normal_forward;
use gaussian::signed_wad;

let z = signed_wad::from_wad(1_000_000_000_000_000_000); // z = 1.0
let prob = normal_forward::cdf_standard(&z);
// prob ≈ 841_344_746_068_543_000 (~0.8413)
```

---

### `pdf_standard`

```move
public fun pdf_standard(z: &SignedWad): u256
```

Standard normal PDF φ(z) = probability density at z.

**Parameters:**
- `z`: z-score as SignedWad

**Returns:** Density value (WAD-scaled, non-negative)

**Properties:**
- φ(0) ≈ 0.3989 × SCALE (maximum at z=0)
- φ(-z) = φ(z) (symmetric)
- φ(|z| > 6) ≈ 0

**Example:**
```move
let z = signed_wad::zero();
let density = normal_forward::pdf_standard(&z);
// density ≈ 398_942_280_401_432_700 (~0.3989, which is 1/√(2π))
```

---

### `inv_sqrt_2pi`

```move
public fun inv_sqrt_2pi(): u256
```

Get the precomputed 1/√(2π) constant.

**Returns:** `398_942_280_401_432_700` (WAD-scaled)

---

## Module: normal_inverse

Inverse CDF (PPF / Quantile Function).

### `ppf`

```move
public fun ppf(p: u128): SignedWad
```

High-precision inverse CDF with Newton refinement.

**Parameters:**
- `p`: Probability in (0, 1) as u128 WAD-scaled

**Returns:** z-score such that Φ(z) ≈ p

**Behavior:**
- p is clamped to [EPS, SCALE - EPS] internally
- Uses piecewise rational approximation + Newton refinement
- Achieves < 0.05% error vs scipy.stats.norm

**Example:**
```move
use gaussian::normal_inverse;

// Find z such that P(Z ≤ z) = 0.975 (97.5th percentile)
let p: u128 = 975_000_000_000_000_000; // 0.975
let z = normal_inverse::ppf(p);
// z ≈ 1.96 (WAD-scaled)
```

---

### `ppf_aaa`

```move
public fun ppf_aaa(p: u128): SignedWad
```

Raw AAA-based inverse CDF (no Newton refinement).

**Parameters:**
- `p`: Probability in (0, 1) as u128 WAD-scaled

**Returns:** z-score (less accurate than `ppf`)

**Note:** Use `ppf` for production; `ppf_aaa` is the raw approximation.

---

## Module: erf

Error function and related computations.

### `erf`

```move
public fun erf(x: u256): u256
```

Error function: erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt

**Parameters:**
- `x`: Non-negative WAD-scaled value

**Returns:** erf(x) in [0, SCALE]

**Behavior:**
- x > 6 × SCALE is clamped to 6 × SCALE
- erf(0) = 0
- erf(6) ≈ SCALE (essentially 1.0)

**Accuracy:** ~6e-11 max error vs mpmath reference

---

### `erf_strict`

```move
public fun erf_strict(x: u256): u256
```

Error function with strict input validation.

**Aborts:** `EInputTooLarge` (101) if x > 6 × SCALE

---

### `erfc`

```move
public fun erfc(x: u256): u256
```

Complementary error function: erfc(x) = 1 - erf(x)

**Parameters:**
- `x`: Non-negative WAD-scaled value

**Returns:** erfc(x) in [0, SCALE]

---

### `phi`

```move
public fun phi(x: u256): u256
```

Standard normal CDF using error function: Φ(x) = ½(1 + erf(x/√2))

**Parameters:**
- `x`: Non-negative WAD-scaled value

**Returns:** CDF value in [0.5 × SCALE, SCALE] for x ≥ 0

**Note:** For full signed domain support, use `normal_forward::cdf_standard`.

---

## Module: signed_wad

Signed fixed-point arithmetic type.

### Constructors

#### `new`

```move
public fun new(magnitude: u256, negative: bool): SignedWad
```

Create a SignedWad from magnitude and sign.

**Note:** Zero is always normalized to non-negative.

---

#### `zero`

```move
public fun zero(): SignedWad
```

Create a zero SignedWad.

---

#### `from_wad`

```move
public fun from_wad(x: u256): SignedWad
```

Create a non-negative SignedWad from unsigned WAD.

---

#### `from_difference`

```move
public fun from_difference(a: u256, b: u256): SignedWad
```

Create SignedWad representing a - b.

---

### Accessors

| Function | Signature | Description |
|----------|-----------|-------------|
| `abs` | `fun abs(x: &SignedWad): u256` | Absolute value |
| `is_negative` | `fun is_negative(x: &SignedWad): bool` | Check sign |
| `is_zero` | `fun is_zero(x: &SignedWad): bool` | Check if zero |
| `magnitude` | `fun magnitude(x: &SignedWad): u256` | Get magnitude |

### Arithmetic Operations

| Function | Signature | Description |
|----------|-----------|-------------|
| `negate` | `fun negate(x: &SignedWad): SignedWad` | -x |
| `add` | `fun add(a: &SignedWad, b: &SignedWad): SignedWad` | a + b |
| `sub` | `fun sub(a: &SignedWad, b: &SignedWad): SignedWad` | a - b |
| `mul` | `fun mul(a: &SignedWad, b: &SignedWad): SignedWad` | a × b / SCALE |
| `mul_wad` | `fun mul_wad(a: &SignedWad, k: u256): SignedWad` | a × k / SCALE |
| `div_wad` | `fun div_wad(a: &SignedWad, b: &SignedWad): SignedWad` | a × SCALE / b |

### Conversions

| Function | Signature | Description |
|----------|-----------|-------------|
| `to_wad_clamped` | `fun to_wad_clamped(x: &SignedWad): u256` | Negative → 0 |
| `to_wad_checked` | `fun to_wad_checked(x: &SignedWad): u256` | Aborts if negative |

### Comparisons

| Function | Signature | Description |
|----------|-----------|-------------|
| `cmp` | `fun cmp(a: &SignedWad, b: &SignedWad): u8` | 0: equal, 1: a>b, 2: a<b |
| `lt` | `fun lt(a: &SignedWad, b: &SignedWad): bool` | a < b |
| `le` | `fun le(a: &SignedWad, b: &SignedWad): bool` | a ≤ b |
| `gt` | `fun gt(a: &SignedWad, b: &SignedWad): bool` | a > b |
| `ge` | `fun ge(a: &SignedWad, b: &SignedWad): bool` | a ≥ b |
| `eq` | `fun eq(a: &SignedWad, b: &SignedWad): bool` | a = b |

---

## Module: math

Low-level fixed-point arithmetic utilities.

### Constants

```move
public fun scale(): u256      // Returns SCALE (10^18)
public fun max_input(): u256  // Returns MAX_INPUT (6 × SCALE)
```

### Arithmetic

#### `signed_add`

```move
public fun signed_add(
    a_mag: u256, a_neg: bool,
    b_mag: u256, b_neg: bool
): (u256, bool)
```

Add two signed values represented as (magnitude, is_negative).

---

#### `mul_div`

```move
public fun mul_div(a: u256, x: u256): u256
```

Fixed-point multiply: (a × x) / SCALE

---

#### `div_scaled`

```move
public fun div_scaled(a: u256, b: u256): u256
```

Fixed-point divide: (a × SCALE) / b

**Aborts:** `EDivisionByZero` (2) if b = 0

---

#### `clamp_to_unit`

```move
public fun clamp_to_unit(value: u256): u256
```

Clamp value to [0, SCALE].

---

## Error Codes

### Module: math (1-99)

| Code | Name | Description |
|------|------|-------------|
| 2 | `EDivisionByZero` | Division by zero in `div_scaled` |

### Module: erf (100-199)

| Code | Name | Description |
|------|------|-------------|
| 100 | `EDenominatorZero` | Q(x) = 0 (should never happen) |
| 101 | `EInputTooLarge` | x > 6 × SCALE in strict functions |

### Module: normal_forward (200-299)

| Code | Name | Description |
|------|------|-------------|
| 200 | `EDenominatorZero` | Denominator evaluated to zero |

### Module: normal_inverse (300-399)

| Code | Name | Description |
|------|------|-------------|
| 301 | `EDenominatorZero` | Denominator zero in rational |

### Module: sampling (400-499)

| Code | Name | Description |
|------|------|-------------|
| 401 | `EInvalidStdDev` | std_dev = 0 in `sample_normal*` |

### Module: signed_wad

| Code | Name | Description |
|------|------|-------------|
| 10 | `EDivisionByZero` | Division by zero in `div_wad` |
| 11 | (unnamed) | Negative value in `to_wad_checked` |

---

## Quick Reference

### Common Patterns

**Sample and use z-score:**
```move
use gaussian::{sampling, normal_forward, signed_wad};

public entry fun compute_probability(r: &Random, ctx: &mut TxContext) {
    let z = sampling::sample_z(r, ctx);
    let prob = normal_forward::cdf_standard(&z);
    // prob is in [0, SCALE], representing P(Z ≤ z)
}
```

**Convert probability to z-score:**
```move
use gaussian::normal_inverse;

let p: u128 = 950_000_000_000_000_000; // 0.95
let z = normal_inverse::ppf(p);
// z ≈ 1.645 (95th percentile)
```

**Custom distribution sampling:**
```move
use gaussian::sampling;

// Sample from N(100, 10²)
let mean = 100_000_000_000_000_000_000u256;  // 100.0
let std = 10_000_000_000_000_000_000u256;    // 10.0
let sample = sampling::sample_normal(r, mean, std, ctx);
```

---

## Precision & Accuracy

| Function | Domain | Max Error |
|----------|--------|-----------|
| `cdf_standard` | z ∈ [-6, 6] | < 0.05% |
| `pdf_standard` | z ∈ [-6, 6] | < 0.1% |
| `ppf` | p ∈ (10^-10, 1-10^-10) | < 0.05% |
| `erf` | x ∈ [0, 6] | ~6e-11 |

---

## Gas Costs

| Function | Computation Cost | Notes |
|----------|------------------|-------|
| `sample_z` | ~1,000,000 MIST | Primary sampling function |
| `sample_normal` | ~1,000,000 MIST | Custom distribution |
| `cdf_standard` | ~500,000 MIST | Included in PPF |
| `pdf_standard` | ~500,000 MIST | Included in PPF |

At ~0.001 SUI per sample, you can perform ~1,000 Gaussian samples per SUI.

---

## See Also

- [SECURITY_REVIEW.md](./SECURITY_REVIEW.md) - Security audit results
- [GAS_BENCHMARKS.md](./GAS_BENCHMARKS.md) - Detailed gas measurements
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Deployment instructions
