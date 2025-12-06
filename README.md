# move-gaussian

Gaussian (normal) distribution sampling library for Move/Sui.

## Status

🚧 **Research & Design Phase** - Not yet implemented

## Overview

This library aims to provide on-chain Gaussian distribution functions for Sui Move:

- **CDF** - Cumulative Distribution Function: Φ(x)
- **PDF** - Probability Density Function: φ(x)  
- **PPF** - Percent-Point Function (inverse CDF): Φ⁻¹(p)
- **Sampling** - Integration with `sui::random` for Gaussian random samples

## Why Move?

Move/Sui offers a key advantage over Solidity for this problem: **native randomness**.

| Challenge | Solidity | Move |
|-----------|----------|------|
| Randomness source | Chainlink VRF (cost, callbacks) | ✅ Native `sui::random` |
| Transcendental functions | Expensive approximations | Same |
| Fixed-point math | No native floats | Same |

See [research notes](https://github.com/Evan-Kim2028/learning_move/tree/main/notes/gaussian) for detailed analysis.

## Core Challenges

Based on analysis of existing Solidity libraries ([SolStat](https://github.com/primitivefinance/solstat), [solgauss](https://github.com/cairoeth/solgauss)):

1. **Transcendental functions** - `exp()`, `log()`, `sqrt()` have no closed-form integer solution
2. **Inverse function errors** - PPF accuracy degrades at probability edges (p → 0 or 1)
3. **Fixed-point precision** - 18 decimal places, overflow risks in intermediate calculations
4. **Randomness** - ✅ Solved by `sui::random`

## Potential Approaches

| Approach | Gas | Precision | Complexity |
|----------|-----|-----------|------------|
| CLT bit-counting | Low | ±0.125σ discrete | Low |
| Lookup table + interpolation | Medium | ~1e-4 | Medium |
| Rational Chebyshev approximation | Medium | <1e-8 | High |

## References

- [Primitive Finance SolStat](https://github.com/primitivefinance/solstat)
- [solgauss](https://github.com/cairoeth/solgauss)
- [Sui Random Module](https://docs.sui.io/references/framework/sui_sui/random)
- Abramowitz & Stegun, "Handbook of Mathematical Functions"
- "Numerical Recipes in C", 2nd Edition

## License

MIT
