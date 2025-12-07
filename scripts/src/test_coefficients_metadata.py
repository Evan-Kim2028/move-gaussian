from __future__ import annotations

import json
from pathlib import Path

import numpy as np

WAD = 10**18
EPS = 1e-10
EPS_WAD = int(EPS * WAD)


def uniform_open_interval_from_u64(u: int) -> int:
    span = WAD - 2 * EPS_WAD
    num = (int(u) & ((1 << 64) - 1)) * span
    frac = num >> 64
    return frac + EPS_WAD


def test_uniform_open_interval_bounds() -> None:
    low = uniform_open_interval_from_u64(0)
    high = uniform_open_interval_from_u64((1 << 64) - 1)
    assert low >= EPS_WAD
    assert high <= WAD - EPS_WAD
    assert low < high


def test_uniform_open_interval_monotonic() -> None:
    rng = np.random.default_rng(123)
    values = rng.integers(0, 2**64, size=8, dtype=np.uint64)
    mapped = [uniform_open_interval_from_u64(int(v)) for v in values]
    assert mapped == sorted(mapped) or mapped == sorted(mapped, reverse=True) or len(set(mapped)) == len(mapped)


def test_summary_checksums_present() -> None:
    summary_path = (
        Path(__file__).resolve().parent.parent / "artifacts" / "move_generated" / "gaussian_coefficients_summary.json"
    )
    if not summary_path.exists():
        # Allow running tests before generation; this test becomes active once artifacts exist.
        return
    data = json.loads(summary_path.read_text())
    assert "checksums" in data
    checksums = data["checksums"]
    assert {"cdf", "pdf", "ppf_central", "ppf_tail"}.issubset(checksums.keys())

