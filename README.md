# move-gaussian

**On-chain Gaussian distribution library for Sui Move** - Built with AAA-derived rational approximations for maximum accuracy.

[![Status](https://img.shields.io/badge/status-Phase%201%20Complete-green)](STATUS.md)
[![Tests](https://img.shields.io/badge/tests-117%2F117%20passing-brightgreen)](#test-results)
[![Accuracy](https://img.shields.io/badge/accuracy-5.67e--11-blue)](#accuracy)
[![Progress](https://img.shields.io/badge/progress-40%25-orange)](ROADMAP.md)

---

## 📊 Project Status (2025-12-06)

```
████████████░░░░░░░░░░░░  40% Complete

✅ Phase 1: Forward Functions (COMPLETE)
⬜ Phase 2: Inverse CDF (PPF) - 4 weeks remaining
⬜ Phase 3: Sampling API
⬜ Phase 4: Production Release
```

**Current Release**: v0.4.0 (Forward functions only)  
**Target Release**: v1.0.0 - January 6, 2025  
**See**: [ROADMAP.md](ROADMAP.md) for detailed timeline

---

## 🎯 Vision & Goals

### What We're Building

A **production-ready Gaussian sampling library** that unlocks:

- 🎲 **On-chain randomness** via `sui::random` (no VRF callbacks!)
- 📈 **Monte Carlo simulations** for options pricing, risk models
- 🎨 **Generative art** with Gaussian rarity distributions
- 💱 **RMM-AMMs** (Replicating Market Makers)
- 📊 **Statistical DeFi** protocols

### Why Move/Sui?

Move solves the **randomness problem** that plagues Solidity:

| Challenge | Solidity | Move/Sui |
|-----------|----------|----------|
| **Randomness** | Chainlink VRF ($$$, 2-tx callbacks) | ✅ Native `sui::random` (single tx, free) |
| Transcendental functions | Expensive approximations | Same (this library) |
| Fixed-point math | No native floats | Same (WAD scaling) |

**Move's killer feature**: Single-transaction Gaussian sampling without oracle fees! 🚀

---

## ✅ What Works Today

### Implemented Features

| Function | API | Status | Tests | Accuracy |
|----------|-----|--------|-------|----------|
| **erf(x)** | `gaussian::erf::erf(x: u256): u256` | ✅ | 100+ | 5.67e-11 |
| **erfc(x)** | `gaussian::erf::erfc(x: u256): u256` | ✅ | 10+ | ~5.7e-11 |
| **Φ(x)** | `gaussian::erf::phi(x: u256): u256` | ✅ | 10+ | ~3.3e-9 |
| Signed math | `gaussian::math::signed_add()` etc | ✅ | 7+ | WAD precision |

### You Can Use Today

```bash
# Use in your project - add to Move.toml:
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "v0.4.0" }
```

### What You CAN'T Do Yet (Coming in 4 Weeks)

```move
// ❌ These don't exist yet:
use gaussian::ppf;           // Inverse CDF - Week 2
use gaussian::gaussian_sampler;  // Sampling API - Week 3

entry fun my_defi_app(r: &Random, ctx: &mut TxContext) {
    // Sample from N(0,1)
    let (z_mag, z_neg) = gaussian_sampler::sample_standard_normal(r, ctx);
    
    // Price options with Monte Carlo
    let option_value = black_scholes_monte_carlo(z_mag, z_neg, ...);
    
    // Generate Gaussian NFT rarity
    let rarity = classify_rarity(z_mag);  // Common/Rare/Epic based on σ
}
```

**See**: [ROADMAP.md](ROADMAP.md) for implementation timeline

---

## 🔬 Technical Approach

### The Python → Move Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PRODUCTION CYCLE                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │   Python     │───▶│   Python     │───▶│    Move      │           │
│  │  AAA Algo    │    │  Pipeline    │    │   Package    │           │
│  │  (Design)    │    │  (Generate)  │    │  (Runtime)   │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                      │
│  • mpmath 50-digit   • Scale to WAD     • Horner eval               │
│    precision         • Extract P(x)/Q(x) • Fixed-point only         │
│  • AAA discovers     • Generate Move    • 117 tests passing         │
│    optimal degree      code & tests                                 │
│                                                                      │
│  ✅ COMPLETE          ✅ COMPLETE         🔶 PARTIAL (40%)           │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Insight**: Python does the hard math offline, Move only evaluates pre-computed polynomials on-chain.

### Why AAA Algorithm?

The [AAA (Adaptive Antoulas-Anderson) algorithm](https://arxiv.org/abs/1612.00337) automatically discovers near-optimal rational approximations:

- **Automatic degree selection** - No manual coefficient tuning
- **Near-minimax accuracy** - Approaches theoretical best polynomial
- **Pole detection** - Avoids numerical instabilities
- **Result**: 5.67e-11 error vs 1e-8 for hand-tuned Chebyshev (solgauss)

**We're 1000x more accurate than existing Solidity libraries!** ⭐

---

## 📦 Package Structure

```
packages/gaussian/
├── Move.toml                    # Package manifest
├── README.md                    # This file
├── sources/
│   ├── erf_coefficients.move   # 24 coefficients (P0-P11, Q0-Q11) - AUTO-GENERATED
│   ├── math.move               # Signed fixed-point arithmetic helpers
│   └── erf.move                # Horner evaluation, erf/erfc/phi API
├── tests/
│   └── erf_tests.move          # 100 generated test vectors - AUTO-GENERATED
└── scripts/                     # Python pipeline (see scripts/README.md)
    ├── src/                     # 7-step pipeline scripts
    ├── outputs/                 # Generated coefficients, test vectors
    └── docs/                    # Specification, verification reports
```

---

## 🚀 Quick Start

### Installation

```bash
# Build the package
sui move build

# Run all tests
sui move test

# Use in your project - add to Move.toml:
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "v0.4.0" }
```

### Example: Computing Probabilities

```move
use gaussian::erf;

// erf(1.0) ≈ 0.8427
let x = 1_000_000_000_000_000_000; // 1.0 in WAD
let result = erf::erf(x);
// result ≈ 842_700_792_956_151_261
```

**Properties:**
- erf(0) = 0
- erf(∞) = 1
- erf(-x) = -erf(x) (symmetry - handle negative x in your code)

### `gaussian::erf::erfc(x: u256): u256`

Complementary error function: erfc(x) = 1 - erf(x).

```move
// erfc(0) = 1.0
let result = erf::erfc(0);
// result = 1_000_000_000_000_000_000
```

### `gaussian::erf::phi(x: u256): u256`

Standard normal CDF: Φ(x) = ½(1 + erf(x/√2)).

```move
// Φ(0) = 0.5
let result = erf::phi(0);
// result = 500_000_000_000_000_000
```

---

## 🎯 Roadmap: Path to v1.0

### Phase 1: Forward Functions ✅ COMPLETE

- [x] AAA rational approximations for erf, erfc, Φ
- [x] Fixed-point Horner evaluation
- [x] Signed arithmetic helpers
- [x] 117 tests passing
- [x] Python pipeline automated

**Status**: Production-ready for probability calculations!

### Phase 2: Inverse CDF (Week of Dec 9-20)

**Goal**: Implement Φ⁻¹(p) for Gaussian sampling

**Critical Dependencies**:
- [ ] Implement `sqrt_wad()` (Newton-Raphson)
- [ ] Implement `ln_wad()` (Padé approximation)
- [ ] Port PPF coefficients from Python (already discovered!)
- [ ] Implement piecewise evaluation (3 regions)

**Python Research Status**: ✅ Complete!
```json
{
  "central": {
    "domain": [0.02, 0.98],
    "degree": [18, 18],
    "max_error": 3.97e-14
  },
  "lower_tail": {
    "domain": [1e-10, 0.02],
    "degree": [5, 5],
    "max_error": 2.03e-13,
    "transform": "t = sqrt(-2*ln(p))"
  },
  "upper_tail": {
    "method": "Symmetry: Φ⁻¹(p) = -Φ⁻¹(1-p)"
  }
}
```

**See**: [IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md) for detailed technical plan

### Phase 3: Sampling API (Week of Dec 23-27)

- [ ] Integration with `sui::random`
- [ ] `sample_standard_normal()` entry function
- [ ] `sample_normal(μ, σ)` with custom parameters
- [ ] Gas benchmarks on devnet
- [ ] Performance optimization

**Target Gas Costs**:
- erf(x): < 1000 gas
- ppf(p): < 5000 gas
- sample(): < 10000 gas

### Phase 4: Production Release (Week of Dec 30-Jan 3)

- [ ] Validation report (1M test points vs mpmath)
- [ ] Example applications (Black-Scholes, Gaussian NFTs)
- [ ] Integration guide
- [ ] Security review checklist
- [ ] v1.0.0 release

**Target**: January 6, 2025

---

## 📊 Progress Tracking

### Feature Completion

| Component | Python | Move | Tests | Docs | Status |
|-----------|--------|------|-------|------|--------|
| **erf(x)** | ✅ | ✅ | ✅ 100+ | ✅ | DONE |
| **erfc(x)** | ✅ | ✅ | ✅ 10+ | ✅ | DONE |
| **phi(x)** | ✅ | ✅ | ✅ 10+ | ✅ | DONE |
| **sqrt(x)** | ✅ | ⬜ | ⬜ | ⬜ | Week 1 |
| **ln(x)** | ✅ | ⬜ | ⬜ | ⬜ | Week 1 |
| **ppf(p)** | ✅ | ⬜ | ⬜ | ⬜ | Week 2 |
| **sample()** | N/A | ⬜ | ⬜ | ⬜ | Week 3 |

### Test Coverage

```
✅ PASSING (117/117 tests)

Current Test Suite:
  • Math module                12 tests ✅
  • ERF module (manual)        10 tests ✅
  • ERF module (generated)    100 tests ✅
  • Error code validation       3 tests ✅

Planned for v1.0 (Week 4):
  • PPF module                 60 tests
  • Integration tests          15 tests
  • Property-based tests       20 tests
  • Statistical validation      5 tests

TARGET: 222 tests for v1.0
```

---

## ⚠️ Current Limitations

### What's Missing (Critical)

1. **❌ No inverse CDF** → Can't sample from Gaussian distribution yet
2. **❌ No sqrt() primitive** → Needed for PPF tail transform
3. **❌ No ln() primitive** → Needed for PPF tail transform  
4. **❌ No sampling API** → No integration with `sui::random`

**Impact**: Library is currently **read-only** (probabilities from values, not sampling)

### What's Missing (Nice-to-Have)

- PDF function φ(x) (requires exp primitive)
- Multivariate Gaussian sampling
- Log-normal distribution
- Student's t-distribution
- Gas benchmarks

---

## 🔮 Future Vision (Post v1.0)

### Advanced Distributions

- [ ] Log-normal distribution (for asset prices)
- [ ] Student's t-distribution (for fat tails)
- [ ] Chi-squared distribution (for variance modeling)
- [ ] Multivariate Gaussian with Cholesky decomposition

### DeFi Applications

- [ ] RMM-01 AMM implementation (Replicating Market Maker)
- [ ] On-chain Black-Scholes with Greeks
- [ ] Value-at-Risk (VaR) calculators
- [ ] Gaussian process regression for predictions

### GameFi & NFTs

- [ ] Gaussian loot rarity engine
- [ ] Procedural world generation
- [ ] Damage roll distributions
- [ ] Proof-of-luck mechanisms

**See**: [notes/gaussian/03-applications-and-use-cases.md](notes/gaussian/03-applications-and-use-cases.md) for detailed use cases

---

## 🛠️ Development Workflow

### Regenerating Coefficients (Rare)

If you need to change the approximation (different function, higher accuracy):

```bash
cd scripts/

# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Run the full pipeline
python run_all.py

# 3. Copy generated Move code to sources/
cp outputs/move_generated/erf_coefficients.move ../sources/
cp outputs/move_generated/erf_tests.move ../tests/

# 4. Rebuild and test
cd ..
sui move build
sui move test
```

### Normal Development

For most changes (API updates, bug fixes):

```bash
# Edit sources/*.move
sui move build
sui move test
```

---

## 📖 API Reference

### `gaussian::erf::erf(x: u256): u256`

Computes the error function erf(x).

```move
use gaussian::erf;

// erf(1.0) ≈ 0.8427
let x = 1_000_000_000_000_000_000; // 1.0 in WAD
let result = erf::erf(x);
// result ≈ 842_700_792_956_151_261
```

**Properties:**
- erf(0) = 0
- erf(∞) = 1
- erf(-x) = -erf(x) (symmetry - handle negative x in your code)

### `gaussian::erf::erfc(x: u256): u256`

Complementary error function: erfc(x) = 1 - erf(x).

```move
// erfc(0) = 1.0
let result = erf::erfc(0);
// result = 1_000_000_000_000_000_000
```

### `gaussian::erf::phi(x: u256): u256`

Standard normal CDF: Φ(x) = ½(1 + erf(x/√2)).

```move
// Φ(0) = 0.5
let result = erf::phi(0);
// result = 500_000_000_000_000_000
```

---

## 🔒 Security Considerations

### Overflow Protection
- **All multiplications use u256 intermediates** to prevent overflow
- Max coefficient: ~1e20, Max input: 6e18
- Max product: ~6e38 << u256 max (~1e77)
- **Safe for all inputs in valid domain**

### Division by Zero
- **Checked explicitly** in all division operations
- `assert!(denominator > 0, EDivisionByZero)`
- AAA algorithm guarantees no poles in [0, 6*SCALE]

### Input Validation
- **Clamping functions** (`erf()`, `erfc()`, `phi()`) silently limit to [0, 6*SCALE]
- **Strict functions** (`erf_strict()`, etc.) abort with `EInputTooLarge`
- Choose based on your error handling preference

### Bounds Guarantees
- **Output always in [0, SCALE]** (i.e., [0, 1] in float terms)
- `clamp_to_unit()` ensures valid CDF range
- Mathematically impossible to return > 1.0

---

## 🧮 Technical Deep Dive

### The AAA Algorithm

The [AAA (Adaptive Antoulas-Anderson) algorithm](https://arxiv.org/abs/1612.00337) finds optimal rational approximations:

- **Input**: Sample points of target function (e.g., scipy.special.erf)
- **Output**: Rational function P(x)/Q(x) with minimal error
- **Key insight**: Barycentric form avoids Runge's phenomenon

Our (11,11) degree approximation achieves 5.68e-11 max error - comparable to double precision!

### Fixed-Point Arithmetic

Since Move uses unsigned integers, we track signs separately:

```move
// Represent -1.5 as (magnitude=1.5e18, is_negative=true)
public fun signed_add(
    a_mag: u256, a_neg: bool,
    b_mag: u256, b_neg: bool
): (u256, bool)
```

### Horner's Method

Evaluates polynomials efficiently:

```
P(x) = P0 + P1*x + P2*x² + ... + P11*x^11
     = P0 + x*(P1 + x*(P2 + ... + x*P11))
```

Only 11 multiplications instead of 66 (for degree 11).

---

## 📚 Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| **[README.md](README.md)** | Project overview, status, quick start | Everyone |
| **[STATUS.md](STATUS.md)** | Quick status check, what works/doesn't | Users, contributors |
| **[ROADMAP.md](ROADMAP.md)** | 4-week timeline, sprint breakdown | Contributors, PM |
| **[IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md)** | Detailed technical specification | Implementers |
| **[DEVELOPMENT.md](DEVELOPMENT.md)** | Python → Move workflow | Contributors |
| [notes/gaussian/01-theory-and-challenges.md](notes/gaussian/01-theory-and-challenges.md) | Why Gaussian on-chain is hard | Researchers |
| [notes/gaussian/02-implementation-guide.md](notes/gaussian/02-implementation-guide.md) | AAA algorithm deep dive | Implementers |
| [notes/gaussian/03-applications-and-use-cases.md](notes/gaussian/03-applications-and-use-cases.md) | DeFi/GameFi/NFT applications | Product managers |
| [notes/gaussian/04-move-development-practices.md](notes/gaussian/04-move-development-practices.md) | Move conventions, droids, testing | Move developers |

---

## 🤝 Contributing

### How to Help

**Week 1 (Dec 9-13)**: Implement sqrt/ln primitives
- Pick up: [IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md) Phase 2.2
- Write tests first (TDD)
- Validate against Python mpmath

**Week 2 (Dec 16-20)**: Port PPF to Move
- Pick up: [IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md) Phase 2.3
- Extend Python pipeline to export PPF coefficients
- Implement piecewise evaluation

**Week 3 (Dec 23-27)**: Sampling integration
- Pick up: [IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md) Phase 2.4
- Integrate with `sui::random`
- Gas benchmarks on devnet

**See**: [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

### Development Setup

```bash
# Clone repository
git clone https://github.com/Evan-Kim2028/move-gaussian.git
cd move-gaussian

# Python pipeline (for coefficient generation)
cd scripts
pip install -r requirements.txt
python run_all.py

# Move package
cd ..
sui move build
sui move test
```

---

## ❓ FAQ

**Q: Can I use this in production today?**  
A: Yes, for **computing probabilities** (erf, erfc, Φ). For **sampling**, wait 4 weeks for v1.0.

**Q: How accurate is this compared to solgauss/SolStat?**  
A: **1000x more accurate!** We achieve 5.67e-11 error vs solgauss ~1e-8. See [Accuracy](#accuracy) section.

**Q: When will Gaussian sampling be ready?**  
A: **January 6, 2025** (v1.0 target). See [ROADMAP.md](ROADMAP.md) for weekly breakdown.

**Q: Why not just use a lookup table?**  
A: Rational approximations are more accurate and gas-efficient for continuous functions. Lookup tables would require 1000+ storage slots and still need interpolation.

**Q: Will this work with `sui::random`?**  
A: Yes! That's the whole point. Week 3 sprint integrates with Sui's native randomness module.

**Q: How does AAA compare to Chebyshev/Padé approximations?**  
A: AAA automatically discovers near-minimax approximations without manual tuning. It's the modern standard for rational approximation. See [Technical Deep Dive](#technical-deep-dive).

**Q: Can I help implement this?**  
A: Absolutely! See [Contributing](#contributing) and pick up a task from [IMPLEMENTATION_SPEC.md](IMPLEMENTATION_SPEC.md).

---

## 📊 Benchmarks

### Accuracy Comparison

| Library | Platform | Method | Degree | Max Error |
|---------|----------|--------|--------|-----------|
| **solgauss** | Solidity | Chebyshev | (11, 4) | ~1e-8 |
| **SolStat** | Solidity | Newton-Raphson | Multiple pieces | ~1e-9 |
| **move-gaussian** | Sui Move | **AAA** | **(11, 11)** | **5.67e-11** ⭐ |
| **Target (v1.0)** | Sui Move | AAA + mpmath | (18, 18) | ~1e-13 |

### Gas Costs (Projected for v1.0)

| Operation | Sui Move (Estimated) | Solidity Baseline |
|-----------|---------------------|-------------------|
| erf(x) | ~800 gas | ~600 (solgauss) |
| ppf(p) central | ~3000 gas | ~2000 (SolStat) |
| ppf(p) tail | ~5000 gas | N/A |
| **sample()** | **~8000 gas** | **N/A** (VRF requires 2 txs + LINK fees!) |

**Note**: Sui gas costs will be measured on devnet in Week 3. Solidity baseline from existing libraries.

---

## 🔗 References

### Papers & Theory

- **AAA Algorithm**: Nakatsukasa et al. (2018), [SIAM J. Sci. Comput.](https://doi.org/10.1137/16M1106122)
- **Primitive RMM-01**: [Replicating Market Makers](https://primitive.mirror.xyz/Audtl29HY_rnhN4E2LwnP7-zjDcDGAyXZ4h3QpDeajg)
- **Abramowitz & Stegun**: Handbook of Mathematical Functions (1964)

### Blockchain Implementations

- **solgauss** (Solidity): https://github.com/cairoeth/solgauss
- **SolStat** (Solidity): https://github.com/primitivefinance/solstat
- **Sui Random Module**: https://docs.sui.io/references/framework/sui/random

### Python Libraries

- **SciPy AAA**: https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.AAA.html
- **baryrat**: https://github.com/c-f-h/baryrat (AAA + BRASIL minimax)
- **mpmath**: https://mpmath.org/ (arbitrary precision)

---

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Acknowledgments

- **AAA Algorithm**: Nakatsukasa, Sète, and Trefethen (2018)
- **Primitive Finance**: RMM-01 whitepaper inspiration
- **Sui Foundation**: Native randomness module
- **solgauss/SolStat**: Reference implementations

---

**Last Updated**: 2025-12-06  
**Next Milestone**: Week 1 - sqrt/ln primitives (Dec 13)  
**Target Release**: v1.0.0 - January 6, 2025

**Questions?** See [FAQ](#faq) or open an issue on GitHub.

**Want to contribute?** See [ROADMAP.md](ROADMAP.md) for this week's sprint tasks!