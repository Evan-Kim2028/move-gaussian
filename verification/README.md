# Formal Verification

This directory contains reproducible formal verification of the Gaussian CDF implementation.

## Quick Start

```bash
# 1. Run sui-prover (45 specs) - requires sui-prover installed
# Note: specs are in verification/specs/, not sources/specs/
# sui-prover uses implicit dependencies, so you may need to modify Move.toml
sui-prover

# 2. Run Sturm certificate (CDF monotonicity)
python3 sturm_certificate.py

# 3. Run overflow analysis
python3 overflow_analysis.py
```

## Directory Structure

```
verification/
├── README.md                 # This file
├── specs/                    # sui-prover spec files (NOT in sources/)
│   ├── math_spec.move
│   ├── overflow_safety_spec.move
│   ├── cdf_monotonicity_spec.move
│   └── ...
├── sturm_certificate.py      # Sturm sequence computation
├── overflow_analysis.py      # Intermediate value bounds
└── results/
    ├── sui-prover-output.txt # Captured prover output
    └── sturm-output.txt      # Captured Sturm result
```

**Important**: The spec files are in `verification/specs/`, NOT `sources/specs/`, because they use sui-prover-specific syntax (`#[spec_only]`, `requires`, `ensures`, `to_real()`) that doesn't compile with the standard Sui Move compiler.

## What's Verified

### [sui-prover](https://github.com/asymptotic-code/sui-prover) (SMT-based)

| Property | Specs | File |
|----------|-------|------|
| Arithmetic primitives | 8 | `sources/specs/math_spec.move` |
| SignedWad comparisons | 6 | `sources/specs/normal_forward_spec.move` |
| Polynomial point evaluations | 10 | `sources/specs/cdf_polynomial_spec.move` |
| CDF bounds | 6 | `sources/specs/cdf_monotonicity_spec.move` |
| Overflow safety | 7 | `sources/specs/overflow_safety_spec.move` |
| Real arithmetic lemmas | 10 | `sources/specs/algebraic_monotonicity_spec.move` |
| **Total** | **45** | |

### Sturm Certificate (Algebraic)

**Theorem**: CDF'(z) > 0 for all z ∈ [0, 6]

**Proof**:
1. N(z) = P'(z)·Q(z) - P(z)·Q'(z) is degree 22
2. Sturm sequence computed with exact rational arithmetic
3. V(0) = V(6) = 11 sign changes
4. Root count = V(0) - V(6) = 0
5. N(0) = 997355701000173/2500000000000000 > 0
6. **Therefore N(z) > 0 on [0, 6], proving monotonicity**

## Trust Model

```
┌─────────────────────────────────────────────────────────────┐
│  TRUSTED                                                     │
│  • Sturm's theorem (1829)                                   │
│  • Python/SymPy polynomial arithmetic                       │
│  • sui-prover/Z3 SMT solver                                 │
├─────────────────────────────────────────────────────────────┤
│  VERIFIED BY sui-prover                                      │
│  • Overflow bounds                                           │
│  • Point evaluations (N(0) > 0, CDF(0) = 0.5)              │
│  • Arithmetic correctness                                    │
├─────────────────────────────────────────────────────────────┤
│  VERIFIED BY Sturm Certificate (external)                   │
│  • CDF monotonicity (0 roots in [0, 6])                    │
└─────────────────────────────────────────────────────────────┘
```

**Note**: The Sturm certificate is computed externally in Python, NOT verified by sui-prover.

## Files

```
verification/
├── README.md                 # This file
├── sturm_certificate.py      # Sturm sequence computation
├── overflow_analysis.py      # Intermediate value bounds
└── results/
    ├── sui-prover-output.txt # Captured prover output
    └── sturm-output.txt      # Captured Sturm result
```

## Requirements

- [sui-prover](https://github.com/asymptotic-code/sui-prover) (Homebrew: `brew install asymptotic-code/sui-prover/sui-prover`)
- Python 3.8+ with SymPy (`pip install sympy`)

## Reproducing Results

All verification can be reproduced from source:

```bash
# From packages/gaussian directory:

# sui-prover verification
sui-prover
# Expected: "Verification successful" (45 specs)

# Sturm certificate
python3 verification/sturm_certificate.py
# Expected: "THEOREM VERIFIED: N(z) > 0 for all z ∈ [0, 6]"
# Key output: "Root count = 0"

# Overflow analysis
python3 verification/overflow_analysis.py
# Expected: "Max intermediate ~10^39, u256 headroom ~10^38x"
```

## Key Results

| Property | Status | Method |
|----------|--------|--------|
| CDF is monotonically increasing | ✓ | Sturm certificate |
| No overflow for z ∈ [0, 6] | ✓ | sui-prover |
| CDF(0) = 0.5 | ✓ | sui-prover |
| N(0) > 0 | ✓ | sui-prover |
| u256 headroom > 10^37x | ✓ | Analysis script |
