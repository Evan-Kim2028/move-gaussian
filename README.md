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
| **erf / erfc** | Error function and complement | `core::erf(x)` |

All functions achieve **<0.05% error** vs scipy reference.

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
    
    // Compute probability P(Z ≤ z)
    let prob: u256 = core::cdf(&z);
    
    // Compute density at z
    let density: u256 = core::pdf(&z);
    
    // Find z-score for 95th percentile
    let z_95: SignedWad = core::ppf(950_000_000_000_000_000); // p = 0.95
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

## WAD Scaling

All values use **WAD scaling** (10¹⁸) for fixed-point precision:

| Real Value | WAD Value |
|------------|-----------|
| 1.0 | `1_000_000_000_000_000_000` |
| 0.5 | `500_000_000_000_000_000` |
| -2.5 | SignedWad { mag: `2_500_000_000_000_000_000`, neg: true } |

## Performance

| Function | Computation | Storage | Total | Accuracy |
|----------|-------------|---------|-------|----------|
| `sample_z` | 1,000,000 | 988,000 | 1,988,000 MIST | - |
| `sample_normal` | 1,000,000 | 988,000 | 1,988,000 MIST | - |
| `cdf` | ~500,000 | ~500,000 | ~1,000,000 MIST | < 0.05% |
| `pdf` | ~500,000 | ~500,000 | ~1,000,000 MIST | < 0.1% |
| `ppf` | ~1,000,000 | ~988,000 | ~1,988,000 MIST | < 0.05% |

### Cost in SUI

| Unit | Value |
|------|-------|
| 1 SUI | 1,000,000,000 MIST (10⁹) |
| 1 sample | ~0.001 - 0.002 SUI |
| Samples per SUI | ~500 - 1,000 |

*Benchmarked on Sui testnet. Actual costs may vary.*

## Documentation

- [API Reference](docs/API_REFERENCE.md) - Complete function documentation
- [Changelog](CHANGELOG.md) - Version history
- [Contributing](CONTRIBUTING.md) - Development guidelines

## Package Info

- **Version**: 1.1.0
- **Testnet Package ID**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`
- **Tests**: 228 Move + 24 Python property tests
- **License**: MIT
