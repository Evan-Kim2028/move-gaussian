# Changelog

All notable changes to the Gaussian package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Technical Documentation** (`docs/DESIGN.md`): Comprehensive technical deep dive
  - Full story on AAA rational approximation algorithm (2018)
  - Comparison to Solidity implementations (solstat, solgauss, Morpheus PM-AMM)
  - Mathematical trade-offs and precision analysis
  - Implementation pipeline: Python → Move workflow
  - Historical context and "why Move" narrative

- **CI Quality Tools Guide** (`docs/CI_QUALITY_TOOLS.md`): Quality assurance reference
  - Currently implemented: Sui Move linter, warnings-as-errors, Python linting, artifact drift detection, property-based testing
  - Available tools: Sui Prover (formal verification), Move Analyzer, gas profiling, coverage tracking
  - Priority recommendations with implementation examples

- **Enhanced CI/CD Pipeline**: Move linter integration in GitHub Actions
  - `sui move build --lint` - catch unused variables, deprecated patterns, style violations
  - `sui move test --lint` - enforce code quality during testing
  - `sui move build --lint --warnings-as-errors` - strict zero-tolerance mode
  - CI now runs on feature branches for faster feedback

### Changed

- **README.md**: Simplified for practitioners, added link to technical deep dive
  - Removed AAA technical breadcrumbs from opening line
  - Added explicit signpost to `docs/DESIGN.md` for technical background
  - Clearer separation: README = "how to use", DESIGN = "why this way"

- **Documentation Claims**: Removed production-ready and security assertions
  - Replaced "Security" sections with "Testing" sections
  - Changed "audit trails" → "event tracking/monitoring" (3 occurrences)
  - Removed "SAFE FOR MAINNET DEPLOYMENT" and security audit references
  - More neutral language about API stability

### Fixed

- **Linter Warnings**: Resolved all 14 Move linter warnings → 0 warnings
  - Added `#[allow(unused_const)]` to checksum constants (used only in tests)
  - Added `#[allow(unused_function)]` to checksum validation functions
  - Replaced magic error numbers with named constants:
    - `EUnexpectedNegative` in `signed_wad.move` (was `11`)
    - `EInvalidUniformsLength` in `sampling.move` (was `0`)
  - All linter checks now pass: build, test, and strict warnings-as-errors mode

---

## [0.7.0] - 2025-12-XX

### Added

- **On-chain Events** (#21): All sampling functions now emit events by default
  - `GaussianSampleEvent` for N(0,1) samples (z-score, sign, caller)
  - `NormalSampleEvent` for N(μ,σ²) samples (z, mean, std_dev, value, caller)
  - Enables off-chain indexing and monitoring
  - Events emitted from ALL sampling functions (PPF and CLT)

- **Core Facade Module** (#22): Single import point for public API
  - New module: `gaussian::core`
  - Shorter function names: `cdf()`, `pdf()`, `ppf()` 
  - Usage: `use gaussian::core::{sample_z, cdf, ppf};`
  - Thin wrappers - zero overhead

- **Profile Metadata Object** (#23): On-chain version tracking
  - `GaussianProfile` shared object created automatically on deploy
  - Tracks: version (0.7.0 = 700), precision_class (0 = standard), max_z_wad (6e18)
  - Enables protocols to verify library version on-chain

- **Transcendental Functions**: ln, exp, sqrt for financial mathematics
  - `ln_wad(x)` - Natural logarithm for x > 0
  - `exp_wad(x)` - Exponential function e^x
  - `sqrt_wad(x)` - Square root via Newton-Raphson
  - Enables Black-Scholes option pricing (see issue #30)

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

### Testing

- All existing tests continue to pass with new features

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
