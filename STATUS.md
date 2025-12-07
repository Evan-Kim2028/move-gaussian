# Gaussian Status

```toml
last_updated = "2025-12-07"
phase = "Phase 4 - devnet validation"
progress_percent = 75
release = "v0.6.0 (sampling beta)"
tests_passing = 184
status_notes = [
  "Phases 1-3 complete (erf/ppf + sampling beta)",
  "Devnet gas + validation in progress; harness redeploy needed to measure CDF/PPF entries",
  "README is generated via scripts/update_readme.py from this status + roadmap + metrics"
]
```

## Snapshot
- Phase: Phase 4 - devnet validation (sampling beta, gas/validation outstanding)
- Progress: ~75% toward v1.0.0 (pending devnet validation + docs polish)
- Tests: 184/184 passing (Move suite)
- Latest release: v0.6.0 (sampling beta)
- Updated: 2025-12-07

## Notes
- Devnet gas benchmarks exist for sampler paths; CDF/PPF entries need redeploy to collect metrics.
- Test coverage review highlights gaps: PDF monotone fuzzing, denser PPF monotonicity, stricter sampler monotonicity/random seeds.
- README is meant to stay concise; detailed guidance lives in notes/gaussian and docs/.

