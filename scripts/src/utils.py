"""
Shared utilities for Gaussian library Python scripts.

Constants and helper functions used across coefficient generation,
testing, and validation scripts.
"""

from typing import Tuple

# ============================================================
# Constants (match Move implementation)
# ============================================================

WAD = 10**18  # Scale factor: 10^18 (fixed-point "WAD" standard)
MAX_U256 = 2**256 - 1
MAX_Z = 6  # Maximum |z| supported by approximations
EPS = 1e-10  # Minimum probability for PPF
EPS_WAD = int(EPS * WAD)  # EPS in WAD scaling (10^8)

# Domain boundaries for piecewise approximations
P_LOW = 0.02  # Lower bound for central region
P_HIGH = 0.98  # Upper bound for central region

# FNV-1a hash constants for checksum generation
FNV_OFFSET_BASIS_128 = 0x6C62272E07BB014262B821756295C58D
FNV_PRIME_128 = 0x0000000001000000000000000000013B
MOD_2_128 = 1 << 128


# ============================================================
# WAD Conversion Helpers
# ============================================================

def wad_to_float(x: int) -> float:
    """Convert WAD-scaled integer to float."""
    return x / WAD


def float_to_wad(x: float) -> int:
    """Convert float to WAD-scaled integer."""
    return int(x * WAD)


# ============================================================
# Signed Fixed-Point Arithmetic
# ============================================================

def signed_add(a_mag: int, a_neg: bool, b_mag: int, b_neg: bool) -> Tuple[int, bool]:
    """
    Add two signed magnitudes.
    
    Args:
        a_mag, a_neg: First value (magnitude, is_negative)
        b_mag, b_neg: Second value (magnitude, is_negative)
    
    Returns:
        (result_mag, result_neg): Sum as signed magnitude
    """
    if a_neg == b_neg:
        # Same sign: add magnitudes, keep sign
        return a_mag + b_mag, a_neg
    else:
        # Different signs: subtract magnitudes
        if a_mag >= b_mag:
            return a_mag - b_mag, a_neg
        else:
            return b_mag - a_mag, b_neg


def apply_mean_std(z: Tuple[int, bool], mean_wad: int, std_wad: int) -> Tuple[int, bool]:
    """
    Transform standard normal z to N(mean, std²).
    
    Computes: mean + std * z
    """
    z_mag, z_neg = z
    delta = (std_wad * z_mag) // WAD
    return signed_add(mean_wad, False, delta, z_neg)


# ============================================================
# Uniform Sampling Helpers (match Move sampling.move)
# ============================================================

def uniform_open_interval(u: int) -> int:
    """
    Map u64 → WAD in open interval (EPS_WAD, WAD - EPS_WAD).
    
    Mirrors Move implementation in sampling.move:
        let span = SCALE - 2 * EPS;
        let frac = (u as u128) * span >> 64;
        frac + EPS
    
    Args:
        u: Raw u64 value (0 to 2^64 - 1)
    
    Returns:
        Probability in WAD scaling, guaranteed in (EPS_WAD, WAD - EPS_WAD)
    """
    span = WAD - 2 * EPS_WAD
    # Mask to u64 range and compute fraction
    u_masked = u & ((1 << 64) - 1)
    frac = (u_masked * span) >> 64
    return frac + EPS_WAD


# Alias for backward compatibility
uniform_open_interval_from_u64 = uniform_open_interval


# ============================================================
# Checksum Helpers (FNV-1a)
# ============================================================

def fnv_update(acc: int, value: int) -> int:
    """Update FNV-1a hash accumulator with a value."""
    return (acc ^ value) * FNV_PRIME_128 % MOD_2_128


def fnv_checksum_ints(values) -> int:
    """Compute FNV-1a checksum over a sequence of integers."""
    acc = FNV_OFFSET_BASIS_128
    for v in values:
        acc = fnv_update(acc, int(v) & (MOD_2_128 - 1))
    return acc
