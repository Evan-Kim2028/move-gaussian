# move-gaussian

On-chain Gaussian distribution library for Sui Move (AAA-derived CDF/PPF + sampling with `sui::random`).

## Quick Links
- **API Reference**: [docs/API_REFERENCE.md](docs/API_REFERENCE.md)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Gas benchmarks**: [docs/GAS_BENCHMARKS.md](docs/GAS_BENCHMARKS.md)
- **Test coverage**: [docs/test_coverage_review.md](docs/test_coverage_review.md)
- **Status**: [STATUS.md](STATUS.md)
- **Roadmap**: [ROADMAP.md](ROADMAP.md)

## Snapshot
- **Version**: v1.1.0 (events + facade + profile)
- **Tests passing**: 228 Move + 24 Python property tests
- **Package ID (Testnet)**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`
- **Last updated**: 2025-12-07

## What's New in v1.1

### On-chain Events (#21)
All sampling functions now emit events for indexing and verification:
- `GaussianSampleEvent` for N(0,1) samples
- `NormalSampleEvent` for N(μ,σ²) samples

### Core Facade (#22)
Single import point with shorter function names:
```move
use gaussian::core::{sample_z, cdf, pdf, ppf};
```

### Profile Metadata (#23)
On-chain version tracking via shared `GaussianProfile` object:
```move
use gaussian::profile;
assert!(profile::version(profile) >= 10100, EOutdatedLibrary); // v1.1.0+
```

### Enhanced Testing (#24-27)
- PDF monotonicity: 60 dense test points
- PPF fuzzing: 25 evenly-spaced probabilities  
- Sampler monotonicity: 20 seeds with strict comparison
- Python Hypothesis: 24 property tests with ~100,000+ examples

## Install

Add to your `Move.toml`:
```toml
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "v1.1.0" }
```

Build & test:
```bash
sui move build
sui move test
```

## Quick Start

### Using the Core Facade (Recommended)

```move
use gaussian::core;
use gaussian::signed_wad::{Self, SignedWad};
use sui::random::Random;

public entry fun sample_and_compute(r: &Random, ctx: &mut TxContext) {
    // Sample from N(0,1)
    let z: SignedWad = core::sample_z(r, ctx);
    
    // Compute CDF: P(Z ≤ z)
    let prob = core::cdf(&z);
    
    // Compute PDF: φ(z)
    let density = core::pdf(&z);
    
    // Inverse CDF: find z for p=0.95
    let z_95: SignedWad = core::ppf(950_000_000_000_000_000); // 0.95 WAD
}
```

### Sample from Custom Distribution

```move
use gaussian::core;

// Sample from N(100, 15²) - e.g., IQ distribution
let mean = 100_000_000_000_000_000_000u256;  // 100.0 WAD
let std = 15_000_000_000_000_000_000u256;    // 15.0 WAD
let sample = core::sample_normal(r, mean, std, ctx);
```

### One-Shot Sampling (Replay Protection)

```move
use gaussian::sampling;

let mut guard = sampling::new_sampler_guard();
let z = sampling::sample_z_once(r, &mut guard, ctx);
// guard is consumed - can't be reused
```

## Precision & Performance

| Function | Domain | Max Error | Gas Cost |
|----------|--------|-----------|----------|
| `cdf` | z ∈ [-6, 6] | < 0.05% | ~500K MIST |
| `pdf` | z ∈ [-6, 6] | < 0.1% | ~500K MIST |
| `ppf` | p ∈ (10⁻¹⁰, 1-10⁻¹⁰) | < 0.05% | ~1M MIST |
| `sample_z` | - | - | ~1M MIST |

At ~0.001 SUI per sample, you can perform ~1,000 Gaussian samples per SUI.

## Architecture

```
gaussian/
├── sources/
│   ├── core.move          # v1.1 facade - single import point
│   ├── events.move        # v1.1 on-chain events
│   ├── profile.move       # v1.1 version metadata
│   ├── sampling.move      # Gaussian sampling with sui::random
│   ├── normal_forward.move # CDF, PDF
│   ├── normal_inverse.move # PPF (inverse CDF)
│   ├── erf.move           # Error function
│   ├── signed_wad.move    # Signed fixed-point arithmetic
│   └── coefficients.move  # Auto-generated polynomial coefficients
├── tests/
│   └── property_fuzz.move # Move property tests
├── scripts/
│   └── src/
│       └── 11_v1_1_property_tests.py  # Python Hypothesis tests
└── docs/
    ├── API_REFERENCE.md
    ├── GAS_BENCHMARKS.md
    └── SECURITY_REVIEW.md
```

## Testing

- 228 Move tests covering CDF, PDF, PPF, and sampling functions
- 24 Python property tests with Hypothesis framework
- All division operations protected against zero divisor
- Comprehensive test coverage including edge cases and property-based tests

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for issue naming conventions and development workflow.

## License

MIT
