# Changelog

All notable changes to the Gaussian package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-12-XX

### Added

- **On-chain Events** (#21): All sampling functions now emit events by default
  - `GaussianSampleEvent` for N(0,1) samples (z-score, sign, caller)
  - `NormalSampleEvent` for N(μ,σ²) samples (z, mean, std_dev, value, caller)
  - Enables off-chain indexing, verification, and audit trails
  - Events emitted from ALL sampling functions (PPF and CLT)

- **Core Facade Module** (#22): Single import point for public API
  - New module: `gaussian::core`
  - Shorter function names: `cdf()`, `pdf()`, `ppf()` 
  - Usage: `use gaussian::core::{sample_z, cdf, ppf};`
  - Thin wrappers - zero overhead

- **Profile Metadata Object** (#23): On-chain version tracking
  - `GaussianProfile` shared object created automatically on deploy
  - Tracks: version (1.1.0 = 10100), precision_class (0 = standard), max_z_wad (6e18)
  - Enables protocols to verify library version on-chain

- **Dense Property Tests**: Significantly improved test coverage
  - PDF monotonicity test: 60 points (was 3) - 20× improvement (#24)
  - PPF fuzzing test: 25 evenly-spaced probabilities (was 18) - ~40% improvement (#25)
  - Sampler monotonicity: 20 evenly-spaced seeds with strict comparison (#26)
  - Python Hypothesis tests: 24 property tests with ~100,000+ generated examples (#27)

### Changed

- CLT sampling functions (`sample_standard_normal_clt`, `sample_normal_clt`) now emit events for consistency
- Monotonicity tests upgraded from `<=` to strict `<` comparison to catch ties
- PDF tail test uses non-strict comparison for z ≥ 5 due to precision limits

### Fixed

- None

### Security

- No security-related changes

---

## [1.0.0] - 2025-12-07

### Added

- Initial release with core Gaussian distribution functions
- **Sampling**: `sample_z()`, `sample_normal()`, `sample_standard_normal()`
- **CDF/PDF**: `cdf_standard()`, `pdf_standard()` via AAA rational approximation
- **PPF**: `ppf()` with Newton refinement for high precision
- **Error Function**: `erf()`, `erfc()` with ~6e-11 accuracy
- **SignedWad**: Signed fixed-point arithmetic type
- **SamplerGuard**: Replay protection for one-shot sampling
- WAD scaling (10^18) throughout
- Testnet deployment: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`

### Technical Details

- Domain: z ∈ [-6, 6] (covers 99.9999998% of distribution)
- PPF accuracy: < 0.05% vs scipy.stats.norm
- Gas cost: ~1,000,000 MIST per sample (~0.001 SUI)
