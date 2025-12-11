# move-gaussian

On-chain Gaussian (normal) distribution library for Sui Move.

Generate random samples from normal distributions, compute probabilities, and perform statistical calculations directly in your smart contracts. Uses Sui's native randomness (`sui::random`) - no external oracle required.

## Features

| Function | Description | Example |
|----------|-------------|---------|
| **Sampling** | Generate random samples from N(0,1) or N(μ,σ²) | `core::sample_z(r, ctx)` |
| **CDF** | Cumulative distribution function Φ(z) = P(Z ≤ z) | `core::cdf(&z)` |
| **PDF** | Probability density function φ(z) | `core::pdf(&z)` |
| **PPF** | Inverse CDF / quantile function Φ⁻¹(p) | `core::ppf(p)` |
| **PPF (from seed)** | Convenient PPF from u64 seed | `core::ppf_from_u64(u)` |
| **erf / erfc** | Error function and complement | `core::erf(x)` |

All functions achieve **<0.05% error** vs scipy reference.

## ⚠️ Breaking Changes in v0.9.0

If upgrading from v0.8.x:

1. **`ppf(p)` now aborts on invalid input** - Previously clamped out-of-range probabilities. Now aborts with `EProbOutOfDomain` (302) if `p < EPS` or `p > SCALE - EPS`.
   - **Fix**: Use `ppf_from_u64(seed)` for sampling, or `ppf_aaa(p)` for clamping behavior.

2. **`SignedWad` fields renamed** - `magnitude` → `mag`, `negative` → `neg`
   - **Fix**: Use accessor methods (`abs()`, `is_negative()`) instead of direct field access.

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Installation

Add to your `Move.toml`:

```toml
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "main" }
```

Then build:

```bash
sui move build
```

## Quick Start

```move
use gaussian::core;
use gaussian::signed_wad::SignedWad;
use sui::random::Random;

public entry fun example(r: &Random, ctx: &mut TxContext) {
    // Sample from standard normal N(0,1)
    let z: SignedWad = core::sample_z(r, ctx);
    
    // Use method syntax for SignedWad accessors
    let z_magnitude = z.abs();           // Get absolute value
    let is_neg = z.is_negative();        // Check sign
    
    // Compute probability P(Z ≤ z)
    let prob: u256 = core::cdf(&z);
    
    // Compute density at z
    let density: u256 = core::pdf(&z);
    
    // Find z-score for 95th percentile (p must be in valid domain)
    let z_95: SignedWad = core::ppf(950_000_000_000_000_000); // p = 0.95
    
    // For sampling: use ppf_from_u64 which handles domain automatically
    let random_seed: u64 = 12345; // from sui::random or other source
    let z_from_seed: SignedWad = core::ppf_from_u64(random_seed);
}
```

## Sampling from Custom Distributions

```move
use gaussian::core;

public entry fun custom_distribution(r: &Random, ctx: &mut TxContext) {
    // Sample from N(100, 15²) - e.g., IQ-like distribution
    let mean: u256 = 100_000_000_000_000_000_000;  // 100.0
    let std: u256 = 15_000_000_000_000_000_000;    // 15.0
    
    let sample = core::sample_normal(r, mean, std, ctx);
}
```

## PPF Domain & Best Practices

### Domain Validation (v0.9.0+)

The `ppf(p)` function **strictly validates** input probabilities. Input must be in the range `(EPS, 1-EPS)` where `EPS ≈ 1e-10`:

```move
// ✅ Valid: p in (EPS, 1-EPS)
let z = core::ppf(500_000_000_000_000_000);  // p = 0.5, works!
let z = core::ppf(950_000_000_000_000_000);  // p = 0.95, works!

// ❌ Invalid: aborts with EProbOutOfDomain (302)
let z = core::ppf(0);                         // p = 0 is out of domain
let z = core::ppf(1_000_000_000_000_000_000); // p = 1 is out of domain
```

### Recommended: Use `ppf_from_u64` for Sampling

For sampling scenarios, use `ppf_from_u64(u)` which automatically maps any `u64` seed into the valid probability range:

```move
// ✅ Safe: any u64 is valid input (no abort possible)
let z = core::ppf_from_u64(random_seed);  // Maps to valid (EPS, 1-EPS)
```

### Randomness Security

When using `sui::random` for sampling:

1. **Wrap in private entry functions** - Don't expose `Random` directly to prevent composition attacks
2. **Use `SamplerGuard`** for single-use protection - Prevents reusing the same randomness handle
3. **Ensure "unhappy paths" aren't cheaper** - Attackers may revert if random outcome is unfavorable

```move
// Good: Single-use guard prevents replay
let mut guard = sampling::new_sampler_guard();
let z = sampling::sample_z_once(r, &mut guard, ctx);
// Second call would abort with ERandomAlreadyUsed
```

See [Sui Randomness Documentation](https://docs.sui.io/guides/developer/advanced/randomness-onchain) for more details.

## Error Codes

| Code | Name | Module | Description |
|------|------|--------|-------------|
| 2 | `EDivisionByZero` | math | Division by zero |
| 10 | `EDivisionByZero` | signed_wad | Division by zero in `div_wad` |
| 11 | `EUnexpectedNegative` | signed_wad | Negative value in `to_wad_checked` |
| 100 | `EDenominatorZero` | erf | Denominator Q(x) = 0 |
| 101 | `EInputTooLarge` | erf | Input > 6×SCALE in strict functions |
| 200 | `EDenominatorZero` | normal_forward | Denominator zero in rational |
| 301 | `EDenominatorZero` | normal_inverse | Denominator zero in rational |
| **302** | **`EProbOutOfDomain`** | **normal_inverse** | **Probability outside (EPS, 1-EPS)** |
| 401 | `EInvalidStdDev` | sampling | std_dev = 0 |
| 402 | `ERandomAlreadyUsed` | sampling | SamplerGuard reuse |
| 403 | `EInvalidUniformsLength` | sampling | CLT requires exactly 12 uniforms |
| 500 | `ELnNonPositive` | transcendental | ln(x) requires x > 0 |
| 501 | `EExpOverflow` | transcendental | exp(x) overflow (\|x\| > 20) |

## WAD Scaling

All values use **WAD scaling** (10¹⁸) for fixed-point precision:

| Real Value | WAD Value |
|------------|-----------|
| 1.0 | `1_000_000_000_000_000_000` |
| 0.5 | `500_000_000_000_000_000` |
| -2.5 | SignedWad { mag: `2_500_000_000_000_000_000`, neg: true } |

## Architecture

This library uses **native 256-bit integers** (u256) with fixed-point scaling, not floating-point arithmetic.

| Aspect | Move-Gaussian | EVM (ABDK) |
|--------|---------------|------------|
| **Precision** | ~77 decimal digits | ~34 decimal digits |
| **Complexity** | ~450 lines | 2348+ lines |
| **Conversion overhead** | Zero (native u256) | High (int ↔ float) |

**Key advantages over EVM:**
- **Native randomness** - `sui::random` enables single-TX sampling (vs multi-TX Chainlink VRF)
- **Overflow safety** - Move aborts on overflow by default
- **Gas predictability** - Deterministic metering (no SSTORE variance)

For detailed comparison, see [docs/DESIGN.md](docs/DESIGN.md).

## Performance

| Function | Gas Cost | Accuracy |
|----------|----------|----------|
| `sample_z` | ~2M MIST (~0.002 SUI) | - |
| `cdf` | ~1M MIST (~0.001 SUI) | < 0.05% |
| `pdf` | ~1M MIST (~0.001 SUI) | < 0.1% |
| `ppf` | ~2M MIST (~0.002 SUI) | < 0.05% |

*Benchmarked on Sui testnet. 1 SUI = 1,000,000,000 MIST.*

## Documentation

- [API Reference](docs/API_REFERENCE.md) - Complete function documentation
- [Design Doc](docs/DESIGN.md) - Technical deep dive
- [Changelog](CHANGELOG.md) - Version history
- [Contributing](CONTRIBUTING.md) - Development guidelines

## Package Info

- **Version**: 0.9.0
- **Latest Deployed (Testnet)**: v0.7.0 - `0xa3cf304af5b168686db4bff7e28072490bfd154fb1da50af84919ae20df12938`
- **Tests**: 399 Move + 24 Python property tests
- **License**: MIT
