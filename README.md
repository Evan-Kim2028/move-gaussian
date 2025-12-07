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

## Architecture: 256-bit Native Arithmetic

This library uses **native 256-bit integers** (u256) with fixed-point scaling, not floating-point arithmetic. This design choice provides advantages over EVM libraries like DegeGauss (which uses ABDK 128-bit IEEE-754 floating-point):

| Aspect | Move-Gaussian (u256 fixed-point) | EVM ABDK (128-bit float) |
|--------|-----------------------------------|--------------------------|
| **Precision** | ~77 decimal digits (intermediate) | ~34 decimal digits |
| **Gas cost** | ~1M MIST (benchmarked) | ~53,000 gas (DegeGauss reported) |
| **Complexity** | ~450 lines | 2348 lines (full FP lib) |
| **Conversion overhead** | **Zero** (native u256) | High (int ↔ float boundaries) |
| **Error source** | Approximation only | Rounding + conversion |
| **Best for** | DeFi (bounded domain) | Scientific computing (extreme ranges) |

**Key Insight**: Move's 256-bit arithmetic provides higher intermediate precision than 128-bit floating-point with zero conversion overhead, making it well-suited for financial applications where |z| ≤ 6σ (99.9999% of the Gaussian distribution).

**Implementation Details**:
```move
// All operations stay in u256 - no floating-point conversions!
public fun mul_div(a: u256, x: u256): u256 {
    (a * x) / SCALE  // Native integer ops
}

public fun div_scaled(a: u256, b: u256): u256 {
    (a * SCALE) / b  // Still u256
}
```

For a detailed comparison, see [notes/gaussian/abdk-vs-move-arithmetic-comparison.md](../../notes/gaussian/abdk-vs-move-arithmetic-comparison.md).

## Sui Move vs EVM Advantages

Move-Gaussian leverages Sui-specific features that differentiate it from EVM implementations:

### 1. Native Randomness (`sui::random`)

**Sui**:
```move
// Single-transaction Gaussian sampling
public entry fun sample_and_use(r: &Random, ctx: &mut TxContext) {
    let z = core::sample_z(r, ctx);  // One transaction
    // Use z immediately in same TX
}
```

**EVM**: Requires external oracle like Chainlink VRF (multi-transaction):
```solidity
// Transaction 1: Request randomness
function requestRandom() public {
    requestId = COORDINATOR.requestRandomWords(...);
}

// Transaction 2: Callback (separate TX, user can't use immediately)
function fulfillRandomWords(uint256[] memory randomWords) internal {
    // Process randomness
}
```

**Advantage**: Sui's deterministic randomness enables **atomic sampling** (request + use in one TX), unlocking use cases like:
- On-chain game mechanics (loot drops, damage rolls)
- Generative art with immediate minting
- Randomized DeFi mechanisms (Gaussian lotteries)

### 2. 256-bit Native Operations

**Sui**: Full u256/i256 support with native arithmetic
```move
let product = a * b;  // u256 × u256 = u256 (no overflow if < 2^256)
let quotient = (a * SCALE) / b;  // Native division
```

**EVM**: 256-bit operations exist but libraries often use 64-bit or 128-bit for "optimization"
- Solidity: Native u256 but floating-point requires custom libraries (ABDK)
- Fixed-point precision often limited to 64.64 or 128.128 formats

**Advantage**: Move's native u256 arithmetic eliminates the need for complex floating-point emulation, providing higher intermediate precision (~77 decimal digits vs ABDK's 34).

### 3. Safer Arithmetic (No Silent Overflows)

**Sui**: Move aborts on overflow by default
```move
let x: u256 = U256_MAX;
let y = x + 1;  // ❌ ABORTS (safe!)
```

**EVM**: Solidity 0.8+ has overflow checks, but legacy code and assembly can bypass them
```solidity
uint256 x = type(uint256).max;
uint256 y = x + 1;  // ✅ Reverts in Solidity 0.8+
// But assembly can bypass: unchecked { y = x + 1; }  // Silent overflow!
```

**Advantage**: Move's design makes unsafe operations **impossible**, not just "opt-in safe".

### 4. Cleaner Generics

**Sui**: Type-safe generics with phantom types
```move
public fun create_gaussian_nft<T: key + store>(
    r: &Random,
    ctx: &mut TxContext
): T {
    let rarity = core::sample_z(r, ctx);  // Type-safe!
    // Use rarity to create NFT
}
```

**EVM**: Limited generics, requires inheritance or interfaces
```solidity
// Can't easily parameterize over NFT types
function createGaussianNFT(address nftContract) public {
    // Must use low-level calls or complex inheritance
}
```

**Advantage**: Composability - Gaussian functions work seamlessly with any Move type.

### 5. Gas Predictability

**Sui**: Deterministic gas metering (computation + storage separated)
```
Total Cost = Computation (fixed) + Storage (state size)
sample_z: ~1,000,000 compute + 988,000 storage = 1.988M MIST
```

**EVM**: Gas varies with state (SSTORE costs change based on storage history)
```solidity
// Same operation costs different gas depending on:
// - First write vs update (20k vs 5k gas)
// - Refund mechanics (complex!)
```

**Advantage**: Predictable costs for financial applications (users know exact fees upfront).

### Summary Table

| Feature | Sui Move-Gaussian | EVM (Solidity) |
|---------|-------------------|----------------|
| **Randomness** | Native (`sui::random`) | External oracle (Chainlink VRF) |
| **Sampling** | Single TX | Multi-TX (request → callback) |
| **Arithmetic** | Native u256 (~77 digits intermediate) | ABDK 128-bit float (~34 digits) |
| **Gas cost** | ~1,000,000 MIST (~0.001 SUI) | Varies by implementation |
| **Overflow safety** | Guaranteed (aborts) | Opt-in (Solidity 0.8+) |
| **Code complexity** | ~450 lines | 2348+ lines (ABDK) |
| **Gas predictability** | Deterministic | Variable (storage refunds) |

**Use Sui Move if**: Building DeFi, GameFi, or generative art requiring Gaussian distributions  
**Stick with EVM if**: Already deployed on Ethereum and can't migrate

## Performance

| Function | Computation | Storage | Total | Accuracy |
|----------|-------------|---------|-------|----------|
| `sample_z` | 1,000,000 (0.001 SUI) | 988,000 (0.000988 SUI) | 1,988,000 MIST (0.00199 SUI) | - |
| `sample_normal` | 1,000,000 (0.001 SUI) | 988,000 (0.000988 SUI) | 1,988,000 MIST (0.00199 SUI) | - |
| `cdf` | ~500,000 (0.0005 SUI) | ~500,000 (0.0005 SUI) | ~1,000,000 MIST (0.001 SUI) | < 0.05% |
| `pdf` | ~500,000 (0.0005 SUI) | ~500,000 (0.0005 SUI) | ~1,000,000 MIST (0.001 SUI) | < 0.1% |
| `ppf` | ~1,000,000 (0.001 SUI) | ~988,000 (0.000988 SUI) | ~1,988,000 MIST (0.00199 SUI) | < 0.05% |

*1 SUI = 1,000,000,000 MIST. Benchmarked on Sui testnet.*

## Documentation

- [API Reference](docs/API_REFERENCE.md) - Complete function documentation
- [Changelog](CHANGELOG.md) - Version history
- [Contributing](CONTRIBUTING.md) - Development guidelines

## Package Info

- **Version**: 0.7.0
- **Testnet Package ID**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`
- **Tests**: 228 Move + 24 Python property tests
- **License**: MIT
