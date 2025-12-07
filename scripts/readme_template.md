# move-gaussian

On-chain Gaussian distribution library for Sui Move (AAA-derived CDF/PPF + sampling with `sui::random`).

## Quick Links
- Status: [STATUS.md](STATUS.md)
- Roadmap: [ROADMAP.md](ROADMAP.md)
- Gas benchmarks: [docs/GAS_BENCHMARKS.md](docs/GAS_BENCHMARKS.md)
- Test coverage review: [docs/test_coverage_review.md](docs/test_coverage_review.md)
- Notes index: [notes/gaussian/README.md](../../notes/gaussian/README.md)
- API reference: [docs/API_REFERENCE.md](docs/API_REFERENCE.md)

## Snapshot (auto-generated)
- Release: $status_release
- Phase: $status_phase
- Progress: $status_progress%
- Tests passing: $status_tests
- Last updated: $status_last_updated
$status_notes_bullets

## Install
Add to your `Move.toml`:
```toml
[dependencies]
gaussian = { git = "https://github.com/Evan-Kim2028/move-gaussian.git", rev = "$dep_rev" }
```

Build & test:
```bash
sui move build --lint
sui move test --lint
```

## Metrics (auto-sourced)
- Gas benchmarks: $gas_date (pkg $gas_package). $gas_summary
- Test coverage: $coverage_date ($coverage_status)

## Roadmap (from ROADMAP.md)
- Next milestone: $roadmap_next
- Target date: $roadmap_target
$roadmap_upcoming_bullets

## Stable APIs (beta sampling)
```move
use gaussian::sampling;
use gaussian::signed_wad;

public fun sample_once(r: &sui::random::Random, ctx: &mut sui::tx_context::TxContext) {
    let mut guard = sampling::new_sampler_guard();
    let z = sampling::sample_z_once(r, &mut guard, ctx);
    let mean = 1_000_000_000_000_000_000; // 1.0 WAD
    let std  = 200_000_000_000_000_000;   // 0.2 WAD
    let n = sampling::sample_normal_once(r, mean, std, &mut guard, ctx);
    if (signed_wad::is_negative(&n)) { /* handle negative */ };
}
```

## Update Routine
1) Run benchmarks/tests: `python scripts/benchmark.py` then `sui move test --lint`
2) Regenerate README: `python scripts/update_readme.py`
3) For CI/pre-commit: `python scripts/update_readme.py --check`
4) Commit README together with updated metrics/status docs

## Notes
- README is generated; edit template at `scripts/readme_template.md` or the source files (STATUS/ROADMAP/metrics), then rerun the generator.
- Detailed context (theory, applications, practices) lives in `notes/gaussian/`.

