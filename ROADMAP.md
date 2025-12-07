# Gaussian Roadmap

```toml
last_updated = "2025-12-07"
next_milestone = "Phase 4: devnet validation"
target_date = "TBD"
upcoming = [
  "Redeploy harness with CDF/PPF entries; rerun scripts/benchmark.py and refresh docs/GAS_BENCHMARKS.md",
  "Tighten Move tests: PDF monotone grid, denser PPF monotonicity, sampler strict/randomized seeds",
  "Refresh integration docs/examples; regenerate README via scripts/update_readme.py"
]
```

## Milestones
- Phase 1: Forward functions (erf/erfc/phi) – Complete
- Phase 2: Inverse CDF (PPF + Newton refinement) – Complete
- Phase 3: Sampling API (PPF-first with CLT fallback) – Complete (beta)
- Phase 4: Devnet validation, gas benchmarks, documentation polish – In progress

## Near-Term Tasks
- Capture gas for CDF/PPF/sampler after redeploying harness entries.
- Add fuzzier property tests (PPF monotonicity, PDF decrease, sampler seed strict ordering).
- Publish integration examples and ensure README regeneration before releases.

