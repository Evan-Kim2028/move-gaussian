# Gaussian Package Gas Benchmarks

**Date**: 2025-12-07  
**Network**: Sui Testnet  
**Package**: `0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b`

---

## Summary

| Metric | Value |
|--------|-------|
| Functions Tested | 5 |
| Successful | 5 |
| Avg Computation Cost | 1,000,000 MIST |
| Max Computation Cost | 1,000,000 MIST |
| Min Computation Cost | 1,000,000 MIST |

---

## Detailed Results

### sample_z_from_seed (Standard Normal Sampling)

This is the primary function for sampling from N(0,1). Uses PPF (inverse CDF) method.

| Seed | Region | Computation | Storage | Total | Status |
|------|--------|-------------|---------|-------|--------|
| 12345 | small seed (tail region) | 1,000,000 | 988,000 | 1,988,000 | ✅ |
| 9223372036854775808 | midpoint (central region) | 1,000,000 | 988,000 | 1,988,000 | ✅ |
| 1000000000000000000 | lower quartile | 1,000,000 | 988,000 | 1,988,000 | ✅ |
| 14000000000000000000 | upper quartile | 1,000,000 | 988,000 | 1,988,000 | ✅ |

### sample_normal_from_seed (Custom Normal Distribution)

Samples from N(μ, σ²) by computing μ + σ·z where z ~ N(0,1).

| Parameters | Computation | Storage | Total | Status |
|------------|-------------|---------|-------|--------|
| N(1.0, 0.1²) | 1,000,000 | 988,000 | 1,988,000 | ✅ |

---

## Comparison with Solidity

| Function | Gaussian (Sui) | solgauss (EVM) | solstat (EVM) |
|----------|----------------|----------------|---------------|
| PPF/sample_z | ~1,000,000 MIST | ~2,001 gas | N/A |
| CDF | TBD | 519-833 gas | 916-5,137 gas |
| erfc | TBD | 687-693 gas | 4,436-4,543 gas |

**Note**: Direct comparison is difficult due to different gas models (Sui MIST vs EVM gas).
Sui's computation cost of ~1M MIST ≈ 0.001 SUI is very affordable.

---

## Cost Analysis

At current testnet rates:
- **1 SUI** = 1,000,000,000 MIST (10^9)
- **Average sample_z cost**: ~1,000,000 MIST = ~0.001000 SUI

**Per 1 SUI, you can perform approximately 1,000 Gaussian samples.**

---

## Methodology

Benchmarks run via `sui client call --dev-inspect --json`:
- dev-inspect simulates execution without spending gas
- Captures computation and storage costs
- Run on Sui testnet against deployed package

To reproduce:
```bash
cd packages/gaussian
python3 scripts/benchmark.py
```
