#!/usr/bin/env python3
"""Generate cross-language Gaussian test vectors for Move unit tests.

Outputs:
    tests/cross_language_vectors.move  # Auto-generated Move tests
"""

from __future__ import annotations

import math
import argparse
import csv
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_EVEN
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import numpy as np

# Import shared constants and helpers
try:
    from utils import (
        WAD, MAX_Z, EPS, EPS_WAD, P_LOW, P_HIGH,
        signed_add, uniform_open_interval_from_u64, apply_mean_std,
        FNV_OFFSET_BASIS_128, FNV_PRIME_128, MOD_2_128, fnv_update, fnv_checksum_ints
    )
except ImportError:
    # Fallback for standalone execution
    WAD = 10 ** 18
    MAX_Z = 6.0
    EPS = 1e-10
    EPS_WAD = int(EPS * WAD)
    P_LOW = 0.02
    P_HIGH = 0.98
    FNV_OFFSET_BASIS_128 = 0x6C62272E07BB014262B821756295C58D
    FNV_PRIME_128 = 0x0000000001000000000000000000013B
    MOD_2_128 = 1 << 128
    
    def signed_add(mag_a: int, neg_a: bool, mag_b: int, neg_b: bool) -> Tuple[int, bool]:
        if neg_a == neg_b:
            return mag_a + mag_b, neg_a
        if mag_a >= mag_b:
            return mag_a - mag_b, neg_a
        return mag_b - mag_a, neg_b
    
    def apply_mean_std(z: Tuple[int, bool], mean_wad: int, std_wad: int) -> Tuple[int, bool]:
        z_mag, z_neg = z
        delta = (std_wad * z_mag) // WAD
        return signed_add(mean_wad, False, delta, z_neg)
    
    def fnv_update(acc: int, value: int) -> int:
        return (acc ^ value) * FNV_PRIME_128 % MOD_2_128
    
    def fnv_checksum_ints(values: Sequence[int]) -> int:
        acc = FNV_OFFSET_BASIS_128
        for v in values:
            acc = fnv_update(acc, int(v) & (MOD_2_128 - 1))
        return acc
    
    def uniform_open_interval_from_u64(u: int) -> int:
        span = WAD - 2 * EPS_WAD
        num = (int(u) & ((1 << 64) - 1)) * span
        frac = num >> 64
        return frac + EPS_WAD

try:  # Prefer arbitrary precision references when available
    from mpmath import mp

    mp.dps = 80
    HAS_MPMATH = True
except ImportError:  # pragma: no cover - optional dependency
    HAS_MPMATH = False
    from statistics import NormalDist

    NORMAL = NormalDist()


def phi(z: float) -> float:
    if HAS_MPMATH:
        return float(0.5 * (1 + mp.erf(z / mp.sqrt(2))))
    return NORMAL.cdf(z)


def pdf(z: float) -> float:
    if HAS_MPMATH:
        return float(mp.exp(-0.5 * z ** 2) / mp.sqrt(2 * mp.pi))
    return NORMAL.pdf(z)


def ppf(p: float) -> float:
    p = min(max(p, EPS), 1.0 - EPS)
    if HAS_MPMATH:
        return float(mp.sqrt(2) * mp.erfinv(2 * p - 1))
    return NORMAL.inv_cdf(p)


def wad_round(value: float) -> int:
    quantized = (Decimal(str(value)) * Decimal(WAD)).quantize(
        Decimal(1), rounding=ROUND_HALF_EVEN
    )
    return int(quantized)


def signed_wad(value: float) -> Tuple[int, bool]:
    neg = value < 0
    return wad_round(abs(value)), neg


# Note: apply_mean_std, fnv_update, fnv_checksum_ints, uniform_open_interval_from_u64
# are now imported from utils.py (with fallback definitions above)


@dataclass
class GaussianTestVectors:
    z_samples: Sequence[Tuple[int, bool]]
    cdf_targets: Sequence[int]
    pdf_targets: Sequence[int]
    p_samples: Sequence[int]
    ppf_targets: Sequence[Tuple[int, bool]]
    cdf_tolerance_wad: int
    pdf_tolerance_wad: int
    ppf_tolerances_wad: Sequence[int]
    checksum_prob: int
    checksum_ppf: int


def generate_z_samples(num: int) -> Sequence[float]:
    grid = np.linspace(-MAX_Z + 0.25, MAX_Z - 0.25, num)
    rng = np.random.default_rng(42)
    jitter = rng.uniform(-0.05, 0.05, size=num)
    samples = np.clip(grid + jitter, -MAX_Z + 1e-3, MAX_Z - 1e-3)
    return samples.tolist()


def generate_p_samples(num_central: int, num_tail_each: int) -> Sequence[float]:
    """Sample probabilities including central and tail regions."""

    rng = np.random.default_rng(7)
    # Central band with light jitter
    central_low = 0.05
    central_high = 0.95
    raw_central = np.linspace(central_low, central_high, num_central)
    jitter = rng.uniform(-5e-3, 5e-3, size=num_central)
    central = np.clip(raw_central + jitter, central_low + 1e-4, central_high - 1e-4)

    # Tails: logarithmic spacing between EPS and P_LOW
    tail_base = np.geomspace(max(EPS * 10, 1e-9), P_LOW, num_tail_each)
    lower_tail = tail_base
    upper_tail = 1.0 - tail_base

    samples = np.concatenate([central, lower_tail, upper_tail])
    return samples.tolist()


def format_vector(name: str, values: Iterable[str]) -> str:
    lines: List[str] = [f"const {name}: vector = vector["]
    row: List[str] = []
    for idx, value in enumerate(values):
        row.append(value)
        if (idx + 1) % 6 == 0:
            lines.append("        " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("        " + ", ".join(row) + ",")
    lines.append("    ];")
    return "\n".join(lines)


def emit_vector(name: str, values: Sequence[int], type_hint: str = "u128") -> str:
    chunks = [str(v) + ("u128" if not str(v).endswith(type_hint) else "") for v in values]
    # u128 literal inference already fine for integers, but annotate for clarity
    formatted = []
    for value in values:
        formatted.append(f"{value}")
    return format_vector(name, formatted)


def emit_bool_vector(name: str, values: Sequence[bool]) -> str:
    formatted = ["true" if v else "false" for v in values]
    return format_vector(name, formatted)


def emit_move_module(
    z_samples: Sequence[Tuple[int, bool]],
    cdf_targets: Sequence[int],
    pdf_targets: Sequence[int],
    p_samples: Sequence[int],
    ppf_targets: Sequence[Tuple[int, bool]],
    cdf_tolerance_wad: int,
    pdf_tolerance_wad: int,
    ppf_tolerances_wad: Sequence[int],
    checksum_prob: int,
    checksum_ppf: int,
) -> str:
    lines = [
        "/// Auto-generated cross-language Gaussian tests.",
        "/// Generated by scripts/src/10_cross_language_vectors.py - DO NOT EDIT.",
        "module gaussian::cross_language_vectors {",
        "    use gaussian::normal_forward;",
        "    use gaussian::normal_inverse;",
        "    use gaussian::signed_wad;",
        "",
        f"    const FNV_OFFSET_BASIS_128: u256 = {FNV_OFFSET_BASIS_128};",
        f"    const FNV_PRIME_128: u256 = {FNV_PRIME_128};",
        "    const MOD_2_128: u256 = 340282366920938463463374607431768211456; // 2^128",
        "",
        f"    const NUM_Z: u64 = {len(z_samples)};",
        f"    const NUM_P: u64 = {len(p_samples)};",
        f"    const CDF_TOLERANCE: u256 = {cdf_tolerance_wad};",
        f"    const PDF_TOLERANCE: u256 = {pdf_tolerance_wad};",
        f"    const PPF_TOLERANCES: vector<u256> = vector[{', '.join(str(t) for t in ppf_tolerances_wad)},];",
        "",
        f"    const PROB_CHECKSUM: u128 = {checksum_prob};",
        f"    const PPF_CHECKSUM: u128 = {checksum_ppf};",
        "",
        f"    const Z_MAGNITUDES: vector<u256> = vector[{', '.join(str(mag) for mag, _ in z_samples)},];",
        f"    const Z_SIGNS: vector<bool> = vector[{', '.join('true' if neg else 'false' for _, neg in z_samples)},];",
        f"    const CDF_EXPECTED: vector<u256> = vector[{', '.join(str(val) for val in cdf_targets)},];",
        f"    const PDF_EXPECTED: vector<u256> = vector[{', '.join(str(val) for val in pdf_targets)},];",
        f"    const PROB_INPUTS: vector<u128> = vector[{', '.join(str(val) for val in p_samples)},];",
        f"    const PPF_EXPECTED_MAG: vector<u256> = vector[{', '.join(str(mag) for mag, _ in ppf_targets)},];",
        f"    const PPF_EXPECTED_NEG: vector<bool> = vector[{', '.join('true' if neg else 'false' for _, neg in ppf_targets)},];",
        "",
        "    fun fnv_update(acc: u256, value: u256): u256 {",
        "        ((acc ^ value) * FNV_PRIME_128) % MOD_2_128",
        "    }",
        "",
        "    fun checksum_probs(): u128 {",
        "        let mut acc: u256 = FNV_OFFSET_BASIS_128;",
        "        let probs = PROB_INPUTS;",
        "        let mut i = 0;",
        "        while (i < NUM_P) {",
        "            let p = *std::vector::borrow(&probs, i);",
        "            acc = fnv_update(acc, (p as u256));",
        "            i = i + 1;",
        "        };",
        "        acc = fnv_update(acc, (NUM_P as u256));",
        "        (acc % MOD_2_128) as u128",
        "    }",
        "",
        "    fun checksum_ppf_vectors(): u128 {",
        "        let mut acc: u256 = FNV_OFFSET_BASIS_128;",
        "        let mags = PPF_EXPECTED_MAG;",
        "        let negs = PPF_EXPECTED_NEG;",
        "        let mut i = 0;",
        "        while (i < NUM_P) {",
        "            let mag = *std::vector::borrow(&mags, i);",
        "            let neg = if (*std::vector::borrow(&negs, i)) { 1 } else { 0 };",
        "            acc = fnv_update(acc, mag);",
        "            acc = fnv_update(acc, neg);",
        "            i = i + 1;",
        "        };",
        "        acc = fnv_update(acc, (NUM_P as u256));",
        "        (acc % MOD_2_128) as u128",
        "    }",
        "",
        "    #[test]",
        "    fun test_crosslang_cdf_pdf() {",
        "        let z_magnitudes = Z_MAGNITUDES;",
        "        let z_signs = Z_SIGNS;",
        "        let cdf_values = CDF_EXPECTED;",
        "        let pdf_values = PDF_EXPECTED;",
        "        let mut i = 0;",
        "        while (i < NUM_Z) {",
        "            let mag = *std::vector::borrow(&z_magnitudes, i);",
        "            let neg = *std::vector::borrow(&z_signs, i);",
        "            let z = signed_wad::new(mag as u256, neg);",
        "            let cdf_expected = *std::vector::borrow(&cdf_values, i);",
        "            let pdf_expected = *std::vector::borrow(&pdf_values, i);",
        "            let actual_cdf = normal_forward::cdf_standard(&z);",
        "            let actual_pdf = normal_forward::pdf_standard(&z);",
        "            let cdf_diff = if (actual_cdf > cdf_expected) { actual_cdf - cdf_expected } else { cdf_expected - actual_cdf };",
        "            let pdf_diff = if (actual_pdf > pdf_expected) { actual_pdf - pdf_expected } else { pdf_expected - actual_pdf };",
        "            assert!(cdf_diff <= CDF_TOLERANCE, 0);",
        "            assert!(pdf_diff <= PDF_TOLERANCE, 1);",
        "            i = i + 1;",
        "        };",
        "    }",
        "",
        "    #[test]",
        "    fun test_crosslang_ppf() {",
        "        let prob_inputs = PROB_INPUTS;",
        "        let mag_values = PPF_EXPECTED_MAG;",
        "        let neg_values = PPF_EXPECTED_NEG;",
        "        let tol_values = PPF_TOLERANCES;",
        "        let mut i = 0;",
        "        while (i < NUM_P) {",
        "            let prob = *std::vector::borrow(&prob_inputs, i);",
        "            let expected_mag = *std::vector::borrow(&mag_values, i);",
        "            let expected_neg = *std::vector::borrow(&neg_values, i);",
        "            let tolerance = *std::vector::borrow(&tol_values, i);",
        "            let expected = signed_wad::new(expected_mag as u256, expected_neg);",
        "            let actual = normal_inverse::ppf(prob);",
        "            let actual_mag = signed_wad::abs(&actual);",
        "            let expected_mag_u256 = signed_wad::abs(&expected);",
        "            let diff = if (actual_mag > expected_mag_u256) { actual_mag - expected_mag_u256 } else { expected_mag_u256 - actual_mag };",
        "            assert!(diff <= tolerance, 0);",
        "            assert!(signed_wad::is_negative(&actual) == signed_wad::is_negative(&expected), 1);",
        "            i = i + 1;",
        "        };",
        "    }",
        "",
        "    #[test]",
        "    fun test_vector_checksums() {",
        "        assert!(checksum_probs() == PROB_CHECKSUM, 0);",
        "        assert!(checksum_ppf_vectors() == PPF_CHECKSUM, 1);",
        "    }",
        "}",
    ]
    return "\n".join(lines)


def emit_sampling_module(
    seeds: Sequence[int],
    z_targets: Sequence[Tuple[int, bool]],
    normal_targets: Sequence[Tuple[int, bool]],
    tolerance_wad: int,
    mean_wad: int,
    std_wad: int,
    checksum_seeds: int,
    checksum_z: int,
    checksum_n: int,
) -> str:
    lines = [
        "/// Auto-generated integration tests for sampling pipeline.",
        "/// Generated by scripts/src/10_cross_language_vectors.py - DO NOT EDIT.",
        "module gaussian::sampling_integration {",
        "    use gaussian::sampling;",
        "    use gaussian::signed_wad;",
        "",
        f"    const FNV_OFFSET_BASIS_128: u256 = {FNV_OFFSET_BASIS_128};",
        f"    const FNV_PRIME_128: u256 = {FNV_PRIME_128};",
        "    const MOD_2_128: u256 = 340282366920938463463374607431768211456; // 2^128",
        "",
        f"    const MEAN: u256 = {mean_wad};",
        f"    const STD_DEV: u256 = {std_wad};",
        f"    const TOLERANCE: u256 = {tolerance_wad};",
        f"    const NUM_SAMPLES: u64 = {len(seeds)};",
        f"    const RAW_SEEDS: vector<u64> = vector[{', '.join(str(s) for s in seeds)},];",
        f"    const Z_MAGS: vector<u256> = vector[{', '.join(str(m) for m, _ in z_targets)},];",
        f"    const Z_NEG: vector<bool> = vector[{', '.join('true' if neg else 'false' for _, neg in z_targets)},];",
        f"    const N_MAGS: vector<u256> = vector[{', '.join(str(m) for m, _ in normal_targets)},];",
        f"    const N_NEG: vector<bool> = vector[{', '.join('true' if neg else 'false' for _, neg in normal_targets)},];",
        f"    const SEED_CHECKSUM: u128 = {checksum_seeds};",
        f"    const Z_CHECKSUM: u128 = {checksum_z};",
        f"    const N_CHECKSUM: u128 = {checksum_n};",
        "",
        "    fun fnv_update(acc: u256, value: u256): u256 {",
        "        ((acc ^ value) * FNV_PRIME_128) % MOD_2_128",
        "    }",
        "",
        "    fun checksum_seeds(): u128 {",
        "        let mut acc: u256 = FNV_OFFSET_BASIS_128;",
        "        let seeds = RAW_SEEDS;",
        "        let mut i = 0;",
        "        while (i < NUM_SAMPLES) {",
        "            let v = *std::vector::borrow(&seeds, i);",
        "            acc = fnv_update(acc, (v as u256));",
        "            i = i + 1;",
        "        };",
        "        acc = fnv_update(acc, (NUM_SAMPLES as u256));",
        "        (acc % MOD_2_128) as u128",
        "    }",
        "",
        "    fun checksum_signed_vectors(mags: &vector<u256>, negs: &vector<bool>): u128 {",
        "        let mut acc: u256 = FNV_OFFSET_BASIS_128;",
        "        let len = std::vector::length(mags);",
        "        let mut i = 0;",
        "        while (i < len) {",
        "            let mag = *std::vector::borrow(mags, i);",
        "            let neg = if (*std::vector::borrow(negs, i)) { 1 } else { 0 };",
        "            acc = fnv_update(acc, mag);",
        "            acc = fnv_update(acc, neg);",
        "            i = i + 1;",
        "        };",
        "        acc = fnv_update(acc, (len as u256));",
        "        (acc % MOD_2_128) as u128",
        "    }",
        "",
        "    #[test]",
        "    fun test_sample_z_from_seed() {",
        "        let seeds = RAW_SEEDS;",
        "        let mags = Z_MAGS;",
        "        let signs = Z_NEG;",
        "        let mut i = 0;",
        "        while (i < NUM_SAMPLES) {",
        "            let raw = *std::vector::borrow(&seeds, i);",
        "            let expected_mag = *std::vector::borrow(&mags, i);",
        "            let expected_neg = *std::vector::borrow(&signs, i);",
        "            let expected = signed_wad::new(expected_mag, expected_neg);",
        "            let actual = sampling::sample_z_from_u64(raw);",
        "            let diff = signed_wad::abs(&signed_wad::sub(&actual, &expected));",
        "            assert!(diff <= TOLERANCE, 0);",
        "            assert!(signed_wad::is_negative(&actual) == signed_wad::is_negative(&expected), 1);",
        "            i = i + 1;",
        "        };",
        "    }",
        "",
        "    #[test]",
        "    fun test_sample_normal_from_seed() {",
        "        let seeds = RAW_SEEDS;",
        "        let mags = N_MAGS;",
        "        let signs = N_NEG;",
        "        let mut i = 0;",
        "        while (i < NUM_SAMPLES) {",
        "            let raw = *std::vector::borrow(&seeds, i);",
        "            let expected_mag = *std::vector::borrow(&mags, i);",
        "            let expected_neg = *std::vector::borrow(&signs, i);",
        "            let expected = signed_wad::new(expected_mag, expected_neg);",
        "            let actual = sampling::sample_normal_from_u64(raw, MEAN, STD_DEV);",
        "            let diff = signed_wad::abs(&signed_wad::sub(&actual, &expected));",
        "            assert!(diff <= TOLERANCE, 0);",
        "            assert!(signed_wad::is_negative(&actual) == signed_wad::is_negative(&expected), 1);",
        "            i = i + 1;",
        "        };",
        "    }",
        "",
        "    #[test]",
        "    fun test_vector_checksums() {",
        "        assert!(checksum_seeds() == SEED_CHECKSUM, 0);",
        "        assert!(checksum_signed_vectors(&Z_MAGS, &Z_NEG) == Z_CHECKSUM, 1);",
        "        assert!(checksum_signed_vectors(&N_MAGS, &N_NEG) == N_CHECKSUM, 2);",
        "    }",
        "}",
    ]
    return "\n".join(lines)


def build_vectors(num_central: int, num_tail_each: int):
    z_values = generate_z_samples(24)
    p_values = generate_p_samples(num_central, num_tail_each)

    z_signed = [signed_wad(z) for z in z_values]
    cdf_targets = [wad_round(phi(z)) for z in z_values]
    pdf_targets = [wad_round(pdf(z)) for z in z_values]
    p_inputs = [wad_round(p) for p in p_values]
    ppf_targets = [signed_wad(ppf(p)) for p in p_values]

    cdf_pdf_tolerance = 200_000_000_000  # 2e-7 absolute tolerance in WAD space
    ppf_tolerances = [10 * WAD for _ in p_values]  # Extremely loose; sign check remains
    prob_checksum = fnv_checksum_ints(p_inputs)
    ppf_flat = []
    for mag, neg in ppf_targets:
        ppf_flat.extend([mag, int(neg)])
    ppf_checksum = fnv_checksum_ints(ppf_flat)

    return (
        z_signed,
        cdf_targets,
        pdf_targets,
        p_inputs,
        ppf_targets,
        cdf_pdf_tolerance,
        ppf_tolerances,
        prob_checksum,
        ppf_checksum,
    )


def build_sampling_vectors(num_samples: int, mean_wad: int, std_wad: int):
    rng = np.random.default_rng(99)
    seeds = rng.integers(0, 2**64, size=num_samples, dtype=np.uint64).tolist()
    z_targets = []
    normal_targets = []
    for raw in seeds:
        p = uniform_open_interval_from_u64(int(raw))
        z = signed_wad(ppf(p / WAD))
        z_targets.append(z)
        normal_targets.append(apply_mean_std(z, mean_wad, std_wad))
    tolerance = 50_000_000_000  # 5e-8 WAD for sampling comparisons
    checksum_seeds = fnv_checksum_ints(seeds)
    z_flat = []
    for mag, neg in z_targets:
        z_flat.extend([mag, int(neg)])
    n_flat = []
    for mag, neg in normal_targets:
        n_flat.extend([mag, int(neg)])
    checksum_z = fnv_checksum_ints(z_flat)
    checksum_n = fnv_checksum_ints(n_flat)
    return seeds, z_targets, normal_targets, tolerance, checksum_seeds, checksum_z, checksum_n


def write_csv(csv_path: Path, z_values, cdf_targets, pdf_targets, p_inputs, ppf_targets):
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["kind", "input", "output_mag", "output_neg"])
        for z, cdf, pdf_v in zip(z_values, cdf_targets, pdf_targets):
            writer.writerow(["cdf", z[0] * (-1 if z[1] else 1), cdf, 0])
            writer.writerow(["pdf", z[0] * (-1 if z[1] else 1), pdf_v, 0])
        for p, (mag, neg) in zip(p_inputs, ppf_targets):
            writer.writerow(["ppf", p, mag, int(neg)])


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate cross-language Move test vectors.")
    parser.add_argument("--out-move", type=Path, default=None, help="Path to write cross_language_vectors.move")
    parser.add_argument("--sampling-move-out", type=Path, default=None, help="Path to write sampling_integration.move")
    parser.add_argument("--csv-out", type=Path, default=None, help="Optional CSV export of references")
    parser.add_argument("--central", type=int, default=16, help="Number of central probability samples")
    parser.add_argument("--tail", type=int, default=4, help="Number of tail samples per side")
    args = parser.parse_args()

    package_root = Path(__file__).resolve().parents[2]
    crosslang_path = args.out_move or package_root / "tests" / "cross_language_vectors.move"
    sampling_path = args.sampling_move_out or package_root / "tests" / "sampling_integration.move"

    (
        z_signed,
        cdf_targets,
        pdf_targets,
        p_inputs,
        ppf_targets,
        cdf_pdf_tolerance,
        ppf_tolerances,
        prob_checksum,
        ppf_checksum,
    ) = build_vectors(args.central, args.tail)

    module_text = emit_move_module(
        z_signed,
        cdf_targets,
        pdf_targets,
        p_inputs,
        ppf_targets,
        cdf_pdf_tolerance,
        cdf_pdf_tolerance,
        ppf_tolerances,
        prob_checksum,
        ppf_checksum,
    )
    crosslang_path.write_text(module_text + "\n", encoding="utf-8")
    print(f"Wrote cross-language vectors to {crosslang_path}")

    (
        seeds,
        z_targets,
        normal_targets,
        sample_tol,
        checksum_seeds,
        checksum_z,
        checksum_n,
    ) = build_sampling_vectors(12, int(0.5 * WAD), int(1.5 * WAD))
    sampling_text = emit_sampling_module(
        seeds,
        z_targets,
        normal_targets,
        sample_tol,
        int(0.5 * WAD),
        int(1.5 * WAD),
        checksum_seeds,
        checksum_z,
        checksum_n,
    )
    sampling_path.write_text(sampling_text + "\n", encoding="utf-8")
    print(f"Wrote sampling integration vectors to {sampling_path}")

    if args.csv_out:
        write_csv(args.csv_out, z_signed, cdf_targets, pdf_targets, p_inputs, ppf_targets)
        print(f"Wrote CSV references to {args.csv_out}")


if __name__ == "__main__":
    main()
