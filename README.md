# move-gaussian

On-chain Gaussian (normal) distribution library for Sui Move.

> **Warning**: This library has **not been audited** by a professional security firm. Use at your own risk.

Generate random samples from normal distributions, compute probabilities, and perform statistical calculations directly in your smart contracts.

## Features

| Function | Description |
|----------|-------------|
| `core::sample_z(r, ctx)` | Sample from standard normal N(0,1) |
| `core::sample_normal(r, μ, σ, ctx)` | Sample from N(μ, σ²) |
| `core::cdf(&z)` | Cumulative distribution Φ(z) = P(Z ≤ z) |
| `core::pdf(&z)` | Probability density φ(z) |
| `core::ppf(p)` | Inverse CDF / quantile function Φ⁻¹(p) |
| `core::erf(x)` | Error function |

**Precision**: < 0.05% error vs scipy reference across all functions.

## Installation

```toml
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "main" }
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
    
    // Find z-score for 95th percentile
    let z_95: SignedWad = core::ppf(950_000_000_000_000_000);
}
```

## Custom Distributions

```move
// Sample from N(100, 15²) - e.g., IQ distribution
let mean: u256 = 100_000_000_000_000_000_000;  // 100.0 in WAD
let std: u256 = 15_000_000_000_000_000_000;    // 15.0 in WAD

let sample = core::sample_normal(r, mean, std, ctx);
```

## WAD Scaling

All values use **WAD scaling** (10¹⁸) for fixed-point precision:

| Real Value | WAD Representation |
|------------|-------------------|
| 1.0 | `1_000_000_000_000_000_000` |
| 0.5 | `500_000_000_000_000_000` |
| -2.5 | `SignedWad { mag: 2_500_000_000_000_000_000, neg: true }` |

## Formal Verification

> **Note**: The verification below was performed by the library author, not by an independent auditor. The proofs are reproducible but have not been externally reviewed.

This library includes formal verification using two complementary approaches:

### [sui-prover](https://github.com/asymptotic-code/sui-prover) (45 specs)

- Overflow safety (u256 headroom ~10³⁸x)
- Arithmetic primitive correctness
- CDF bounds and point evaluations

### Sturm Certificate (Algebraic proof)

- **CDF monotonicity**: Proven via Sturm's theorem that N(z) = P'Q - PQ' has zero roots in [0, 6]
- **Result**: CDF is strictly increasing on the entire domain

See [`verification/`](verification/) for reproducible proofs and scripts.

```bash
# Run Sturm certificate
python3 verification/sturm_certificate.py

# Run overflow analysis  
python3 verification/overflow_analysis.py
```

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](docs/API_REFERENCE.md) | Complete function documentation |
| [Design Doc](docs/DESIGN.md) | Technical architecture |
| [Verification](verification/README.md) | Formal verification details |
| [Changelog](CHANGELOG.md) | Version history |

## Example: Black-Scholes

See [move-black-scholes](https://github.com/Evan-Kim2028/move-black-scholes) for real-world usage in European option pricing.

## Package Info

| Field | Value |
|-------|-------|
| **Version** | 0.9.0 |
| **Testnet Package** | [`0x66f9087...`](https://suiscan.xyz/testnet/object/0x66f9087a3d9ae3fe07a5f3c1475d503f1b0ea508d3b83b73b0b8637b57629f7f) |
| **Tests** | 406 Move tests |
| **License** | MIT |
