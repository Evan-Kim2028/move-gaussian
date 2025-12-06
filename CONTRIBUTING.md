# Contributing to move-gaussian

## Issue Naming Convention

All issues should follow the standardized prefix format:

```
[TYPE] Short descriptive title
```

### Issue Type Prefixes

| Prefix | Use Case | Label |
|--------|----------|-------|
| `[FEAT]` | New feature or capability | `enhancement` |
| `[FIX]` | Bug fix | `bug` |
| `[RESEARCH]` | Investigation, analysis, design decisions | `research` |
| `[IMPL]` | Implementation work (building something already designed) | `implementation` |
| `[BENCH]` | Performance or gas benchmarking | `benchmark` |
| `[DOCS]` | Documentation improvements | `documentation` |
| `[REFACTOR]` | Code improvement without behavior change | `refactor` |

### Examples

```
[FEAT] Gaussian sampling via sui::random
[IMPL] PPF (inverse CDF) for Gaussian sampling
[FIX] Overflow in wad_mul for large inputs
[BENCH] Gas costs and precision metrics
[DOCS] Add API reference for erf module
[RESEARCH] Alternative approximation methods
[REFACTOR] Extract common Horner evaluation logic
```

### Issue Body Template

```markdown
## Overview

Brief description of what this issue addresses.

## Details

- Technical details
- Requirements or constraints
- Links to related issues

## Status

🔴 Not started | 🟡 In progress | ✅ Complete

### Checklist
- [ ] Task 1
- [ ] Task 2

## Dependencies

Blocked by: #X, #Y
Blocks: #Z
```

---

## Pull Request Guidelines

### Branch Naming

```
<type>/<short-description>
```

Examples:
- `feat/ppf-implementation`
- `fix/overflow-handling`
- `docs/api-reference`

### Commit Messages

Follow conventional commits:

```
<type>: <description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `bench`, `chore`

Examples:
```
feat: add PPF (inverse CDF) implementation

Implements the percent-point function using AAA rational approximation.
Achieves ~1e-10 precision for p ∈ [0.001, 0.999].

Closes #2
```

---

## Development Workflow

### Running Tests

```bash
# Move tests
sui move test

# Python pipeline
cd scripts && uv run python run_all.py
```

### Adding New Approximations

1. Create Python exploration script in `scripts/src/`
2. Generate coefficients and test vectors
3. Implement Move module in `sources/`
4. Add tests in `tests/`
5. Update `run_all.py` to include new scripts

### Precision Requirements

| Function | Target | Current |
|----------|--------|---------|
| erf(x) | < 1e-7 | ~6e-11 ✅ |
| erfc(x) | < 1e-7 | ~6e-11 ✅ |
| phi(x) | < 1e-7 | ~6e-11 ✅ |
| ppf(p) | < 1e-7 | TBD |

---

## Labels

| Label | Description | Color |
|-------|-------------|-------|
| `enhancement` | New feature or request | Blue |
| `bug` | Something isn't working | Red |
| `research` | Research and analysis needed | Light blue |
| `implementation` | Implementation work | Green |
| `benchmark` | Performance benchmarking | Yellow |
| `documentation` | Documentation improvements | Blue |
| `refactor` | Code improvement | Yellow |
| `challenge` | Core challenge to solve | Red |
