from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from mpmath import mp

WAD = 10**18


def _eval_signed_poly(mags, signs, x):
    acc = 0
    for mag, neg in reversed(list(zip(mags, signs))):
        acc = (acc * x) / WAD
        acc = acc - mag if neg else acc + mag
    return acc


def _eval_rational(entry, x):
    p = _eval_signed_poly(entry["p_magnitudes"], entry["p_signs"], x)
    q = _eval_signed_poly(entry["q_magnitudes"], entry["q_signs"], x)
    return (p * WAD) / q


def test_cdf_pdf_against_mpmath():
    scaled = json.loads((Path(__file__).resolve().parent.parent / "scripts" / "outputs" / "scaled_coefficients.json").read_text())
    phi_entry = scaled["phi"]
    zs = np.linspace(0, 6, 50)
    mp.mp.dps = 60
    for z in zs:
        z_wad = int(z * WAD)
        cdf_move = _eval_rational(phi_entry, z_wad)
        cdf_ref = int(mp.ncdf(z) * WAD)
        assert abs(cdf_move - cdf_ref) <= 1_000_000_000_000  # 1e-6 WAD

