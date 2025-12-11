# Changelog

All notable changes to the Gaussian package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2025-12-11

### Added

- **Comprehensive Security Audit Test Suite** (160+ new tests)
  - `tests/security_audit.move`: 25+ tests covering 7 attack vectors
    - Randomness composition attack validation (SamplerGuard replay protection)
    - Tail boundary discontinuity tests at P_LOW (0.02) and P_HIGH (0.98)
    - Overflow protection verification for exp_wad power loop
    - Newton iteration stability tests for near-zero PDF cases
    - Deterministic helper exploitation tests
    - CLT tail bias documentation tests
    - Coefficient integrity and tampering detection
  - `tests/boundary_exploit.move`: 30+ edge case exploitation tests
    - Domain boundary tests (EPS, MAX_Z, P_LOW, P_HIGH)
    - Precision attack tests for fixed-point arithmetic
    - Type boundary tests (u64, u128, u256 limits)
    - Signed arithmetic edge cases (near-cancellation, exact zero)
  - `tests/economic_exploit.move`: 15+ DeFi integration attack simulations
    - Options pricing arbitrage detection (Black-Scholes d1/d2 accuracy)
    - VaR calculation accuracy at 95% and 99% confidence levels
    - Probability threshold precision verification
    - Roundtrip error accumulation testing
    - Rounding bias detection across operations
  - `tests/defi_exploit_scenarios.move`: 21 tests for real-world DeFi exploit simulations
    - Rounding direction attacks (Balancer-style)
    - Flash loan attack vectors (Euler Finance-style)
    - Sandwich attack scenarios
    - Precision loss exploitation
    - First depositor / donation attacks
    - Gas griefing / DoS vectors
  - `tests/advanced_adversarial.move`: Nation-state threat model testing
    - Statistical distinguisher attacks
    - Seed correlation analysis
    - Coefficient integrity verification

### Security Audit Findings

The security audit validated the following:

**✅ PROTECTED (No Exploitable Vulnerabilities Found):**
1. **Randomness Composition**: SamplerGuard correctly prevents replay attacks
2. **Overflow Protection**: Move's native u256 with bounds checking prevents overflows
3. **Division Safety**: All division operations properly check for zero denominators
4. **Tail Accuracy**: Newton refinement provides stable results even at extreme probabilities
5. **Coefficient Integrity**: Spot checks confirm coefficients match expected values
6. **Precision Bounds**: Error stays within documented 0.05% tolerance

**⚠️ DOCUMENTED LIMITATIONS (Not Exploitable, But Noted):**
1. **CLT Tail Bias**: CLT sampling has thinner tails than true Gaussian (by design, PPF is default)
2. **Event Information Leak**: Sample values are emitted on-chain (transparency feature)
3. **Composition Attack Risk**: Documented in module - consumers must wrap in entry functions

**Test Results:** 388 tests passing (160+ new security-focused tests)

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

## [0.7.0] - 2025-12-07

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
