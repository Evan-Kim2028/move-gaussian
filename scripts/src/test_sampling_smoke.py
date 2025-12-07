from __future__ import annotations

import numpy as np
from mpmath import mp

from .10_cross_language_vectors import apply_mean_std, signed_wad, uniform_open_interval_from_u64, ppf, WAD  # type: ignore


def test_sampler_smoke_mean_variance():
    rng = np.random.default_rng(321)
    seeds = rng.integers(0, 2**64, size=2000, dtype=np.uint64)
    samples = []
    for raw in seeds:
        p = uniform_open_interval_from_u64(int(raw))
        z = signed_wad(ppf(p / WAD))
        samples.append(((-1 if z[1] else 1) * z[0]) / WAD)

    mean = float(np.mean(samples))
    var = float(np.var(samples))
    assert abs(mean) < 0.05
    assert 0.9 < var < 1.1

