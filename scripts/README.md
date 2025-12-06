# Gaussian Approximation Pipeline

Python pipeline for designing optimal rational approximations of Gaussian functions using the AAA algorithm.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run the exploration (Step 1-2)
python src/01_aaa_exploration.py
```

## Directory Structure

```
scripts/
├── docs/               # Documentation and specifications
│   └── SPECIFICATION.md   # Complete pipeline specification
├── images/             # Generated plots and visualizations
├── outputs/            # Exported coefficients and test vectors
├── src/                # Python source files (numbered by step)
│   ├── 01_aaa_exploration.py    # Sample + AAA approximation
│   ├── 02_convert_to_poly.py    # Barycentric → P(x)/Q(x)
│   ├── 03_scale_fixed_point.py  # Scale for on-chain arithmetic
│   ├── 04_horner_python.py      # Horner evaluation in Python
│   ├── 05_test_harness.py       # Comprehensive testing
│   ├── 06_verify_properties.py  # Mathematical property verification
│   └── 07_export_for_move.py    # Generate Move constants
└── requirements.txt
```

## Pipeline Overview

```
Sample erf → AAA → Convert → Scale → Horner (Python) → Verify → Export → Move
```

See `docs/SPECIFICATION.md` for full details.

## Current Status

- [x] Step 1-2: AAA exploration complete
- [ ] Step 3-8: Python pipeline in progress
- [ ] Step 9-11: Move implementation pending

## Key Results

| Function | Degree | Max Error | Poles in [0,6] |
|----------|--------|-----------|----------------|
| erf(x) | (11, 11) | 4.4e-11 | 0 ✓ |
| erfc(x) | (11, 11) | 4.4e-11 | 0 ✓ |
| Φ(x) | (11, 11) | 6.98e-13 | 0 ✓ |
