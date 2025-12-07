# CI/CD Quality Tools for Sui Move

**Purpose**: Comprehensive guide to quality assurance tools available for Sui Move projects and CI/CD integration.

**Last Updated**: 2025-12-07

---

## Currently Implemented ✅

### 1. **Sui Move Linter** (Built-in)
```yaml
- name: Move build with linting
  run: sui move build --lint
```

**What it catches**:
- Unused variables and imports
- Deprecated patterns
- Public functions accepting `Random` without `#[allow(lint(public_random))]`
- Sub-optimal use of `sui::coin::Coin`
- Improper equality checks for collections (e.g., `sui::bag::Bag`)
- Style violations

**Reference**: https://blog.sui.io/linter-compile-warnings-update/

---

### 2. **Warnings as Errors** (Strict Mode)
```yaml
- name: Check for warnings-as-errors (strict mode)
  run: sui move build --lint --warnings-are-errors
```

**What it does**:
- Treats all warnings as build failures
- Enforces zero-tolerance for code quality issues
- Prevents technical debt accumulation

**When to use**: In production branches or pre-merge CI

---

### 3. **Python Linting** (ruff + black)
```yaml
- name: Lint Python (ruff)
  run: uv run ruff check src

- name: Format check (black)
  run: uv run black --check src
```

**What it catches**:
- PEP 8 violations
- Unused imports/variables
- Complex functions (McCabe complexity)
- Security issues (bandit rules)
- Type inconsistencies

---

### 4. **Artifact Drift Detection**
```yaml
- name: Check artifact drift
  run: |
    git diff --exit-code sources tests artifacts/move_generated || \
    (echo "Artifacts out of date; commit regenerated files" && exit 1)
```

**What it catches**:
- Coefficients out of sync with Python pipeline
- Test vectors not regenerated after changes
- Manual edits to auto-generated files

---

## Available But Not Implemented ⏳

### 5. **Sui Prover** (Formal Verification) 🔬

**What it is**: Formal verification tool that mathematically proves smart contract properties.

**Integration example**:
```yaml
- name: Formal verification with Sui Prover
  working-directory: packages/gaussian
  run: |
    # Install Sui Prover (from Certora/Asymptotic)
    wget https://github.com/asymptotic-io/sui-prover/releases/latest/download/sui-prover-linux.tar.gz
    tar -xzf sui-prover-linux.tar.gz
    ./sui-prover verify sources/*.move
```

**What it proves**:
- ✅ **Invariants**: "This vault can never be drained"
- ✅ **Correctness**: "Token balance is always preserved exactly"
- ✅ **Safety**: "No overflow/underflow possible"
- ✅ **Termination**: "This function always completes"

**Example specification** (in Move):
```move
module gaussian::erf {
    spec erf {
        // Ensures output is always in [0, SCALE]
        ensures result >= 0 && result <= SCALE;
        
        // Ensures monotonicity: erf is strictly increasing
        ensures x1 < x2 ==> erf(x1) < erf(x2);
        
        // Ensures symmetry: erf(-x) = -erf(x)
        ensures erf(negate(x)) == negate(erf(x));
    }
}
```

**References**:
- https://blog.sui.io/asymptotic-move-prover-formal-verification/
- https://docs.certora.com/en/latest/docs/move/index.html

**Status**: ⏳ Not yet implemented (requires spec annotations)

---

### 6. **Move Analyzer** (IDE + Static Analysis) 🔍

**What it is**: VS Code extension with advanced static analysis.

**Features**:
- Go-to-definition for all symbols
- Hover documentation (shows function signatures)
- Auto-completion for keywords, modules, types
- Real-time error highlighting
- Semantic analysis (not just syntax)

**Installation** (for local development):
```bash
# Install Move Language Server
cargo install --git https://github.com/move-language/move move-analyzer

# In VS Code:
# Search for "Move" extension by Mysten Labs
```

**CI integration**: Not applicable (IDE tool)

**Reference**: https://blog.sui.io/move-analyzer-tutorial/

---

### 7. **Gas Profiling** ⛽

**What it is**: Track gas costs over time to detect regressions.

**Integration example**:
```yaml
- name: Gas cost regression check
  working-directory: packages/gaussian
  run: |
    # Run benchmarks and save results
    python scripts/benchmark.py --output gas-report.json
    
    # Compare to baseline (stored in repo)
    python scripts/check_gas_regression.py \
      --baseline benchmarks/baseline-gas.json \
      --current gas-report.json \
      --max-regression 5%  # Fail if any function >5% worse
```

**What it catches**:
- Accidental performance regressions
- Inefficient new code paths
- Gas cost drift over time

**Status**: ⏳ Baseline file needed

---

### 8. **Coverage Tracking** 📊

**What it is**: Track Move test coverage over time.

**Integration example**:
```yaml
- name: Move test coverage
  working-directory: packages/gaussian
  run: |
    sui move test --coverage
    sui move coverage summary
    
    # Optional: Upload to Codecov
    bash <(curl -s https://codecov.io/bash) -f coverage/lcov.info
```

**What it tracks**:
- Lines covered by tests
- Functions with no test coverage
- Branch coverage (if/else paths)

**Status**: ⏳ Sui CLI coverage support is experimental

---

### 9. **Documentation Generation** 📚

**What it is**: Auto-generate API docs from Move code.

**Integration example**:
```yaml
- name: Generate Move documentation
  working-directory: packages/gaussian
  run: |
    sui move build --doc
    # Check that docs are up to date
    git diff --exit-code docs/move-docs/ || \
    (echo "Move docs out of date; run 'sui move build --doc'" && exit 1)
```

**What it generates**:
- Function signatures with doc comments
- Module dependency graphs
- Struct/type documentation

**Status**: ⏳ Not currently tracked in CI

---

### 10. **Mutation Testing** 🧬

**What it is**: Intentionally break code to verify tests catch bugs.

**Concept**:
```python
# Original code
if (x > 0) { ... }

# Mutated code (CI injects this)
if (x >= 0) { ... }  # Changed > to >=
if (x < 0) { ... }   # Changed > to <
if (true) { ... }    # Removed condition

# If tests still pass, they're not testing this properly!
```

**Status**: ❌ No Move-specific mutation testing tools available yet

---

### 11. **Dependency Scanning** 🔐

**What it is**: Check Move dependencies for known vulnerabilities.

**Integration example**:
```yaml
- name: Audit Move dependencies
  working-directory: packages/gaussian
  run: |
    # Parse Move.toml dependencies
    # Check against Sui package vulnerability database
    # (Tool doesn't exist yet, but pattern shown)
    sui move verify-dependencies
```

**What it would check**:
- Outdated framework versions
- Known vulnerable packages
- Deprecated Move patterns in dependencies

**Status**: ❌ No official Sui dependency scanner yet

---

### 12. **Property-Based Testing** (Hypothesis) 🎲

**What it is**: Already implemented in Python! Generate random test cases.

**Current implementation**:
```yaml
- name: Python unit/property tests
  run: uv run pytest src  # Includes Hypothesis tests
```

**What it tests**:
- CDF monotonicity (100,000+ random inputs)
- PPF inverse relationship (random probabilities)
- PDF symmetry (random z-scores)

**Status**: ✅ Already implemented

---

## Recommended Additions (Priority Order)

### High Priority (Should Add Soon) 🔥

1. **Documentation generation check**
   ```yaml
   - name: Check Move docs are current
     run: |
       sui move build --doc
       git diff --exit-code docs/move-docs/
   ```
   **Benefit**: Ensures API docs stay in sync

2. **Gas regression baseline**
   ```yaml
   - name: Gas cost regression
     run: python scripts/check_gas_regression.py
   ```
   **Benefit**: Catches performance regressions early

### Medium Priority (Nice to Have) 🟡

3. **Sui Prover integration**
   ```yaml
   - name: Formal verification
     run: sui-prover verify sources/*.move
   ```
   **Benefit**: Mathematical proof of critical properties
   **Effort**: Requires writing spec annotations

4. **Coverage tracking**
   ```yaml
   - name: Test coverage report
     run: sui move test --coverage
   ```
   **Benefit**: Identifies untested code paths
   **Effort**: Experimental Sui CLI feature

### Low Priority (Future) 🔵

5. **Dependency scanning** (when tool becomes available)
6. **Mutation testing** (when Move tooling exists)

---

## Tool Comparison Table

| Tool | Type | Status | CI Time | Value |
|------|------|--------|---------|-------|
| **Sui Linter** | Static analysis | ✅ Implemented | ~10s | High |
| **Warnings-as-errors** | Strictness | ✅ Implemented | +5s | High |
| **Artifact drift** | Consistency | ✅ Implemented | ~5s | High |
| **Python linting** | Code quality | ✅ Implemented | ~5s | High |
| **Property tests** | Testing | ✅ Implemented | ~30s | High |
| **Sui Prover** | Formal verification | ⏳ Available | ~2-5min | Very High |
| **Gas profiling** | Performance | ⏳ Needs baseline | ~20s | Medium |
| **Coverage** | Testing | ⏳ Experimental | ~15s | Medium |
| **Docs generation** | Documentation | ⏳ Available | ~10s | Medium |
| **Dependency scan** | Security | ❌ Not available | N/A | High (future) |
| **Mutation testing** | Testing | ❌ Not available | N/A | Medium (future) |

---

## Next Steps

### 1. Add Documentation Check (Low Effort, High Value)

```bash
# Add to gaussian-ci.yml move job:
- name: Generate and check Move docs
  working-directory: packages/gaussian
  run: |
    sui move build --doc
    # Optionally commit docs to repo for GitHub Pages
```

### 2. Create Gas Regression Baseline (Medium Effort, High Value)

```bash
# One-time setup:
cd packages/gaussian
python scripts/benchmark.py --save-baseline benchmarks/baseline-gas.json

# Add to CI:
- name: Check gas regression
  run: |
    python scripts/benchmark.py --output current-gas.json
    python scripts/check_gas_regression.py \
      --baseline benchmarks/baseline-gas.json \
      --current current-gas.json \
      --max-regression 10%
```

### 3. Explore Sui Prover (High Effort, Very High Value)

```bash
# Add spec annotations to critical functions
spec fun erf(x: u256): u256 {
    ensures result >= 0 && result <= SCALE;
    ensures x == 0 ==> result == 0;
}

# Install Sui Prover and integrate into CI
```

---

## References

### Official Sui Documentation
- **Sui CLI**: https://docs.sui.io/references/cli/move
- **Move Conventions**: https://docs.sui.io/concepts/sui-move-concepts/conventions
- **Linter Update**: https://blog.sui.io/linter-compile-warnings-update/

### Formal Verification
- **Sui Prover Announcement**: https://blog.sui.io/asymptotic-move-prover-formal-verification/
- **Certora Docs**: https://docs.certora.com/en/latest/docs/move/index.html
- **MoveBit Tutorial**: https://www.movebit.xyz/blog/post/Move-Prover-Tutorial.html

### Developer Tools
- **Move Analyzer**: https://blog.sui.io/move-analyzer-tutorial/
- **Code Quality Checklist**: https://move-book.com/guides/code-quality-checklist.html
- **awesome-sui**: https://github.com/sui-foundation/awesome-sui

### Security Best Practices
- **OWASP DevSecOps**: https://owasp.org/www-project-devsecops-guideline/

---

## Summary

**Currently implemented** (5 tools):
1. ✅ Sui Move linter
2. ✅ Warnings-as-errors mode
3. ✅ Python linting (ruff + black)
4. ✅ Artifact drift detection
5. ✅ Property-based testing (Hypothesis)

**Recommended next additions** (3 tools):
1. 📚 Documentation generation check (low effort)
2. ⛽ Gas regression baseline (medium effort)
3. 🔬 Sui Prover integration (high effort, high value)

**Future possibilities** (when tooling matures):
- Coverage tracking (experimental in Sui CLI)
- Dependency scanning (no official tool yet)
- Mutation testing (no Move tooling yet)

---

**Last Updated**: 2025-12-07  
**Status**: Living document (update as new tools emerge)
