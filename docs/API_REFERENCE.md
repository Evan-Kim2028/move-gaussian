# Gaussian Package API Reference

**Version**: 0.7.0  
**Package ID (Testnet)**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`  
**License**: MIT

---

## Table of Contents

1. [Overview](#overview)
2. [Constants](#constants)
3. [Types](#types)
4. [Module: core](#module-core) *(NEW in v0.7)*
5. [Module: events](#module-events) *(NEW in v0.7)*
6. [Module: profile](#module-profile) *(NEW in v0.7)*
7. [Module: sampling](#module-sampling)
8. [Module: normal_forward](#module-normal_forward)
9. [Module: normal_inverse](#module-normal_inverse)
10. [Module: erf](#module-erf)
11. [Module: signed_wad](#module-signed_wad)
12. [Module: math](#module-math)
13. [Module: transcendental](#module-transcendental) *(NEW in v0.7)*
14. [Error Codes](#error-codes)

---

## Overview

The Gaussian package provides on-chain Gaussian (normal) distribution functions for Sui Move smart contracts. All arithmetic uses **WAD scaling** (10^18) for fixed-point precision.

### Key Features

- **CDF** (Cumulative Distribution Function): `Φ(z)` - probability that Z ≤ z
- **PDF** (Probability Density Function): `φ(z)` - probability density at z
- **PPF** (Percent Point Function / Inverse CDF): `Φ⁻¹(p)` - z-score for probability p
- **Sampling**: Generate Gaussian random samples using `sui::random`
- **Error Function**: `erf(x)` and `erfc(x)` implementations
- **Events**: On-chain event tracking for all sampling operations *(NEW in v0.7)*
- **Profile**: On-chain version metadata *(NEW in v0.7)*

### What's New in v0.7

- **Core Facade** (`gaussian::core`): Single import point with shorter function names
- **Events** (`gaussian::events`): All sampling functions emit events by default
- **Profile** (`gaussian::profile`): On-chain version tracking and configuration
- **Transcendental** (`gaussian::transcendental`): ln, exp, sqrt for financial math

### Security Note: `public_random` Lint

All sampling functions in this library suppress the `public_random` linter warning:

```move
#[allow(lint(public_random))]
public fun sample_z(r: &random::Random, ctx: &mut TxContext): SignedWad
```

**Why this is suppressed**: This library is designed for **composition** - other Move modules need to call these functions to build DeFi applications. The Sui linter warns about public functions accepting `Random` because they can be vulnerable to composition attacks where a malicious contract reverts if the random outcome is unfavorable.

**Consumer responsibility**: If you're building an application using this library:

1. **For entry points** (user-facing functions): Consider wrapping calls in a private `entry` function:
   ```move
   entry fun my_random_function(r: &Random, ctx: &mut TxContext) {
       let z = gaussian::core::sample_z(r, ctx);
       // Use z - attacker cannot compose with this
   }
   ```

2. **For composable functions**: Ensure the "unhappy path" doesn't consume fewer resources than the "happy path" (see [Sui's randomness docs](https://docs.sui.io/guides/developer/advanced/randomness-onchain)).

3. **Two-step pattern**: For high-value operations, consider splitting into two transactions - one to commit randomness, one to use it.

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
/// Signed WAD value with magnitude and sign flag.
/// 
/// This is the canonical signed type for all Gaussian functions:
/// - PPF returns `SignedWad`
/// - CDF/PDF take `&SignedWad`
/// - Sampler can return `SignedWad` or wrap it
/// 
/// Zero is always stored as non-negative (negative: false).
public struct SignedWad has copy, drop, store {
    /// Absolute value of the number (WAD-scaled, 10^18).
    /// Example: For -2.5, magnitude = 2_500_000_000_000_000_000
    magnitude: u256,
    /// Sign flag: true = negative, false = non-negative.
    /// Note: Zero is always stored with negative = false.
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
/// Standard normal sample stored as a SignedWad value.
/// 
/// Wraps a z-score from N(0,1) for type safety and ergonomic accessors.
/// Use `magnitude()` and `is_negative()` to extract the value, or
/// `to_signed_wad()` for use with other Gaussian functions.
public struct StandardNormal has copy, drop, store {
    /// The underlying z-score from N(0,1), storing magnitude and sign.
    /// Compute the real value as: z = (negative ? -1 : 1) * magnitude / 10^18
    value: SignedWad,
}
```

A sample from the standard normal distribution N(0, 1).

### SamplerGuard

```move
/// Guard to enforce single-use sampling when callers want to prevent
/// reuse of a randomness handle. Protects against replay attacks.
public struct SamplerGuard has store, drop {
    /// Whether this guard has been consumed (true = already used, will abort on reuse)
    used: bool,
}
```

**Usage:**
```move
let mut guard = new_sampler_guard();
let z = sample_z_once(r, &mut guard, ctx); // Consumes guard
// Second call would abort with ERandomAlreadyUsed (402)
```

### GaussianProfile

```move
/// Immutable metadata about the Gaussian library configuration.
/// 
/// Created once at package deployment, shared for public read access.
/// Never modified after creation.
public struct GaussianProfile has key, store {
    /// Sui object identifier (required for shared objects)
    id: UID,
    /// Library version as semantic version integer.
    /// Encoding: major * 10000 + minor * 100 + patch
    /// Example: v0.7.0 = 700, v2.3.1 = 20301
    version: u32,
    /// Precision class indicating the approximation method:
    /// - 0 = standard (AAA polynomial approximation)
    /// - 1 = high (future: more Newton iterations)
    /// - 2 = fast (future: LUT-based)
    precision_class: u8,
    /// Maximum supported |z| value (WAD-scaled).
    /// Current: 6e18 (covers 99.9999998% of distribution)
    max_z_wad: u256,
}
```

---

## Module: core

A facade module providing a single import point for common Gaussian operations. All functions in this module emit events by default.

### Functions

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
use gaussian::core;

public entry fun my_function(r: &Random, ctx: &mut TxContext) {
    let z = core::sample_z(r, ctx);
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
let sample = core::sample_normal(r, mean, std_dev, ctx);
```

---

#### `cdf`

```move
public fun cdf(z: &SignedWad): u256
```

Standard normal CDF: Φ(z) = P(Z ≤ z)

**Parameters:**
- `z`: z-score as SignedWad

**Returns:** Probability in [0, SCALE] (WAD-scaled)

**Example:**
```move
let z = core::signed_from_wad(1_000_000_000_000_000_000); // z = 1.0
let prob = core::cdf(&z);
// prob ≈ 841_344_746_068_543_000 (~0.8413)
```

---

#### `pdf`

```move
public fun pdf(z: &SignedWad): u256
```

Standard normal PDF: φ(z) = probability density at z

**Parameters:**
- `z`: z-score as SignedWad

**Returns:** Density value (WAD-scaled, non-negative)

---

#### `ppf`

```move
public fun ppf(p: u128): SignedWad
```

Inverse CDF / Percent Point Function: Φ⁻¹(p)

**Parameters:**
- `p`: Probability in (0, 1) as u128 WAD-scaled

**Returns:** z-score such that Φ(z) ≈ p

**Example:**
```move
let p: u128 = 975_000_000_000_000_000; // 0.975
let z = core::ppf(p);
// z ≈ 1.96 (97.5th percentile)
```

---

#### `erf`

```move
public fun erf(x: u256): u256
```

Error function: erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt

**Parameters:**
- `x`: Non-negative WAD-scaled value

**Returns:** erf(x) in [0, SCALE]

---

#### `erfc`

```move
public fun erfc(x: u256): u256
```

Complementary error function: erfc(x) = 1 - erf(x)

---

### SignedWad Utilities

The core module also re-exports common SignedWad utilities:

```move
public fun signed_new(magnitude: u256, negative: bool): SignedWad
public fun signed_zero(): SignedWad
public fun signed_from_wad(x: u256): SignedWad
public fun signed_abs(x: &SignedWad): u256
public fun signed_is_negative(x: &SignedWad): bool
public fun signed_is_zero(x: &SignedWad): bool
```

---

### Constants

```move
public fun scale(): u256  // Returns 10^18 (WAD)
```

---

## Module: events

On-chain events emitted by all sampling functions. Events enable off-chain indexing and monitoring.

### Event Structs

#### `GaussianSampleEvent`

```move
public struct GaussianSampleEvent has copy, drop {
    z_magnitude: u256,
    z_negative: bool,
    caller: address,
}
```

Emitted on every standard normal N(0,1) sample.

**Fields:**
- `z_magnitude`: Absolute value of z-score (WAD-scaled, 10^18)
- `z_negative`: Sign of z-score (true = negative)
- `caller`: Address that initiated the sample

**Decoding:**
```
z = (z_negative ? -1 : 1) * z_magnitude / 10^18
```

---

#### `NormalSampleEvent`

```move
public struct NormalSampleEvent has copy, drop {
    z_magnitude: u256,
    z_negative: bool,
    mean: u256,
    std_dev: u256,
    value_magnitude: u256,
    value_negative: bool,
    caller: address,
}
```

Emitted on every custom normal N(μ,σ²) sample.

**Fields:**
- `z_magnitude`: z-score magnitude (WAD-scaled)
- `z_negative`: z-score sign (true = negative)
- `mean`: Mean parameter μ (WAD-scaled)
- `std_dev`: Standard deviation σ (WAD-scaled)
- `value_magnitude`: Final sample value |μ + σ·z| (WAD-scaled)
- `value_negative`: Final sample sign (true = negative)
- `caller`: Address that initiated the sample

### Internal Functions

These functions are `public(package)` and not intended for direct use:

```move
public(package) fun emit_gaussian_sample(z_magnitude: u256, z_negative: bool, caller: address)
public(package) fun emit_normal_sample(z_magnitude: u256, z_negative: bool, mean: u256, std_dev: u256, value_magnitude: u256, value_negative: bool, caller: address)
```

### Usage Example

Events are emitted automatically. Off-chain systems can subscribe:

```typescript
// TypeScript SDK example
const events = await client.subscribeEvent({
    filter: { MoveEventType: `${packageId}::events::GaussianSampleEvent` }
});
```

---

## Module: profile

On-chain metadata object for library version tracking. Created automatically on package deployment.

### Types

#### `GaussianProfile`

```move
public struct GaussianProfile has key, store {
    id: UID,
    version: u32,
    precision_class: u8,
    max_z_wad: u256,
}
```

Immutable metadata about the Gaussian library configuration. Created once at package deployment and shared for public read access.

**Fields:**
- `version`: Library version as semantic version integer (encoding: `major * 10000 + minor * 100 + patch`)
- `precision_class`: Precision class (0 = standard, 1 = high, 2 = fast/LUT)
- `max_z_wad`: Maximum supported |z| value (WAD-scaled, currently 6e18)

### Version Encoding

Version is encoded as: `major * 10000 + minor * 100 + patch`

| Version | Encoded |
|---------|---------|
| v0.7.0 | 700 |
| v1.0.0 | 10000 |
| v2.3.1 | 20301 |

### Constants

```move
const VERSION: u32 = 700;           // v0.7.0
const PRECISION_STANDARD: u8 = 0;     // AAA polynomial approximation
const PRECISION_HIGH: u8 = 1;         // Future: more Newton iterations
const PRECISION_FAST: u8 = 2;         // Future: LUT-based
const MAX_Z_WAD: u256 = 6_000_000_000_000_000_000; // |z| ≤ 6.0
```

### Accessor Functions

#### `version`

```move
public fun version(p: &GaussianProfile): u32
```

Get the library version as semantic version integer.

---

#### `precision_class`

```move
public fun precision_class(p: &GaussianProfile): u8
```

Get the precision class (0 = standard, 1 = high, 2 = fast).

---

#### `max_z_wad`

```move
public fun max_z_wad(p: &GaussianProfile): u256
```

Get the maximum supported |z| value (WAD-scaled).

---

#### `version_major` / `version_minor` / `version_patch`

```move
public fun version_major(p: &GaussianProfile): u32
public fun version_minor(p: &GaussianProfile): u32
public fun version_patch(p: &GaussianProfile): u32
```

Extract individual version components.

---

#### `is_standard_precision` / `is_high_precision` / `is_fast_precision`

```move
public fun is_standard_precision(p: &GaussianProfile): bool
public fun is_high_precision(p: &GaussianProfile): bool
public fun is_fast_precision(p: &GaussianProfile): bool
```

Check precision class.

### Usage Example

```move
use gaussian::profile::{Self, GaussianProfile};

public fun my_function(profile: &GaussianProfile) {
    // Verify version >= 0.7.0
    assert!(profile::version(profile) >= 700, EOutdatedLibrary);
    
    // Check precision class
    assert!(profile::is_standard_precision(profile), EWrongPrecision);
}
```

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

**Note:** `ppf` includes Newton refinement for higher accuracy; `ppf_aaa` is the raw approximation.

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

## Module: transcendental

Transcendental functions for fixed-point arithmetic, essential for financial mathematics like option pricing.

### Overview

This module provides:
- **`ln_wad(x)`** - Natural logarithm for x > 0
- **`exp_wad(x)`** - Exponential function e^x
- **`sqrt_wad(x)`** - Square root

All functions use WAD scaling (10^18) for fixed-point precision.

### Use Cases

- Black-Scholes option pricing: `ln(S/K)`, `e^(-rT)`
- Compound interest calculations
- Geometric Brownian motion simulations
- Risk metrics (VaR, etc.)

### Constants

```move
const LN_2: u256 = 693_147_180_559_945_309;   // ln(2) in WAD
const E: u256 = 2_718_281_828_459_045_235;    // e in WAD
const INV_E: u256 = 367_879_441_171_442_321;  // 1/e in WAD
const MAX_EXP_INPUT: u256 = 20_000_000_000_000_000_000; // |x| ≤ 20
```

### Functions

#### `ln_wad`

```move
public fun ln_wad(x: u256): SignedWad
```

Natural logarithm ln(x) for WAD-scaled x > 0.

**Parameters:**
- `x`: Positive value in WAD scaling (x > 0)

**Returns:** SignedWad representing ln(x), which can be negative for x < 1

**Errors:**
- `ELnNonPositive` (500) - if x ≤ 0

**Example:**
```move
use gaussian::transcendental;

let x = 2_000_000_000_000_000_000; // 2.0
let result = transcendental::ln_wad(x);
// result ≈ 693_147_180_559_945_309 (ln(2) ≈ 0.693)

let y = 500_000_000_000_000_000; // 0.5
let result = transcendental::ln_wad(y);
// result ≈ -693_147_180_559_945_309 (ln(0.5) = -ln(2))
```

**Precision:** < 1% error for x ∈ [0.001, 1000] WAD

---

#### `exp_wad`

```move
public fun exp_wad(x: &SignedWad): u256
```

Exponential function e^x for SignedWad input.

**Parameters:**
- `x`: Exponent as SignedWad (can be negative)

**Returns:** e^x in WAD scaling (always positive)

**Errors:**
- `EExpOverflow` (501) - if |x| > 20 WAD (result would overflow)

**Example:**
```move
use gaussian::{transcendental, signed_wad};

// e^1 = e ≈ 2.718
let x = signed_wad::from_wad(1_000_000_000_000_000_000);
let result = transcendental::exp_wad(&x);
// result ≈ 2_718_281_828_459_045_235

// e^-1 = 1/e ≈ 0.368
let x = signed_wad::new(1_000_000_000_000_000_000, true);
let result = transcendental::exp_wad(&x);
// result ≈ 367_879_441_171_442_321
```

**Precision:** < 1% error for x ∈ [-20, 20] WAD

---

#### `sqrt_wad`

```move
public fun sqrt_wad(x: u256): u256
```

Square root of WAD-scaled value using Newton-Raphson iteration.

**Parameters:**
- `x`: Non-negative value in WAD scaling

**Returns:** sqrt(x) in WAD scaling

**Example:**
```move
use gaussian::transcendental;

let x = 4_000_000_000_000_000_000; // 4.0
let result = transcendental::sqrt_wad(x);
// result = 2_000_000_000_000_000_000 (2.0)

let x = 2_000_000_000_000_000_000; // 2.0
let result = transcendental::sqrt_wad(x);
// result ≈ 1_414_213_562_373_095_048 (√2 ≈ 1.414)
```

**Precision:** Exact to WAD precision (Newton-Raphson converges)

---

#### `exp_neg_wad`

```move
public fun exp_neg_wad(x: u256): u256
```

Convenience function for e^(-x) where x is positive. Common in finance for discount factors.

**Parameters:**
- `x`: Positive exponent in WAD scaling

**Returns:** e^(-x) in WAD scaling

**Example:**
```move
// Discount factor: e^(-0.05 * 1) for 5% rate, 1 year
let rate_time = 50_000_000_000_000_000; // 0.05
let discount = transcendental::exp_neg_wad(rate_time);
// discount ≈ 951_229_424_500_714_000 (~0.9512)
```

---

#### `ln_ratio`

```move
public fun ln_ratio(a: u256, b: u256): SignedWad
```

Natural logarithm of a ratio: ln(a/b). More accurate than computing ln(a) - ln(b) separately.

**Parameters:**
- `a`: Numerator in WAD scaling (a > 0)
- `b`: Denominator in WAD scaling (b > 0)

**Returns:** ln(a/b) as SignedWad

**Example:**
```move
// ln(S/K) for Black-Scholes where S=105, K=100
let spot = 105_000_000_000_000_000_000;   // 105.0
let strike = 100_000_000_000_000_000_000; // 100.0
let ln_moneyness = transcendental::ln_ratio(spot, strike);
// ln_moneyness ≈ 48_790_164_169_432_057 (ln(1.05) ≈ 0.0488)
```

---

#### Constant Accessors

```move
public fun ln_2(): u256   // Returns ln(2) ≈ 0.693 in WAD
public fun e(): u256      // Returns e ≈ 2.718 in WAD
public fun inv_e(): u256  // Returns 1/e ≈ 0.368 in WAD
```

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| 500 | `ELnNonPositive` | Input must be positive for ln |
| 501 | `EExpOverflow` | Exponent too large (|x| > 20) |

### Precision & Accuracy

| Function | Domain | Max Error |
|----------|--------|-----------|
| `ln_wad` | x ∈ [0.001, 1000] WAD | < 1% |
| `exp_wad` | x ∈ [-20, 20] WAD | < 1% |
| `sqrt_wad` | x ≥ 0 | Exact (Newton) |

### Implementation Notes

**ln_wad:**
- Uses range reduction: ln(x) = ln(m × 2^k) = ln(m) + k×ln(2)
- Taylor series for ln(1 + u) where u ∈ [0, 1)
- 12 terms for convergence

**exp_wad:**
- Uses range reduction: e^x = 2^k × e^f where f ∈ [0, ln(2))
- Taylor series for e^f
- 12 terms for convergence

**sqrt_wad:**
- Newton-Raphson iteration: guess = (guess + n/guess) / 2
- Converges to exact WAD precision

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

- [GAS_BENCHMARKS.md](./GAS_BENCHMARKS.md) - Detailed gas measurements
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Deployment instructions
- [test_coverage_review.md](./test_coverage_review.md) - Test coverage details
