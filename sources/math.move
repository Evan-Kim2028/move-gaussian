/// Signed fixed-point arithmetic for Gaussian approximation.
///
/// # Overview
///
/// Move uses unsigned integers, but rational polynomial coefficients have
/// mixed signs. This module provides signed arithmetic by tracking magnitudes
/// and sign flags separately.
///
/// # WAD Scaling
///
/// All values use WAD scaling: multiply by 10^18.
/// - 1.0 → 1_000_000_000_000_000_000
/// - 0.5 → 500_000_000_000_000_000
/// - -1.5 → (magnitude: 1_500_000_000_000_000_000, is_negative: true)
///
/// # Key Functions
///
/// - `signed_add` - Add two signed values (handles mixed signs)
/// - `mul_div` - Fixed-point multiply: (a * x) / SCALE
/// - `div_scaled` - Fixed-point divide: (a * SCALE) / b
/// - `clamp_to_unit` - Clamp to [0, SCALE] range
///
/// # Usage in Horner's Method
///
/// This module enables evaluating polynomials with mixed-sign coefficients:
/// ```
/// P(x) = P0 + x*(P1 + x*(P2 + ...))
/// ```
/// Each coefficient Pi may be positive or negative.
module gaussian::math;

use gaussian::rounding::{Self, RoundingMode};

/// Scale factor: WAD = 10^18 as u256
const SCALE: u256 = 1_000_000_000_000_000_000;

/// Maximum value for domain [0, 6]
const MAX_INPUT: u256 = 6_000_000_000_000_000_000;

// === Errors ===

/// Division by zero (denominator is zero).
///
/// This error occurs when attempting to divide by zero in fixed-point
/// division operations. Most commonly seen in `div_scaled()`.
///
/// **Common causes:**
/// 1. Denominator Q(x) = 0 in rational function evaluation
/// 2. Invalid coefficient configuration
/// 3. Numerical underflow in intermediate calculations
///
/// **How to fix:**
/// - Check that the denominator is non-zero before calling `div_scaled()`
/// - Verify input is within valid domain [0, 6*SCALE]
/// - For erf functions, ensure using valid coefficients from `erf_coefficients`
///
/// **Example of the error:**
/// ```move
/// // This will abort with EDivisionByZero:
/// let result = div_scaled(100, 0);
///
/// // Correct: check denominator first
/// assert!(denominator > 0, EDivisionByZero);
/// let result = div_scaled(numerator, denominator);
/// ```
///
/// **Technical details:**
/// - Error code range: 1-99 (math module errors)
/// - Thrown by: `div_scaled()`
/// - Related to: `EDenominatorZero` in erf module (code 100)
///
/// **Overflow safety:**
/// This module uses u256 intermediates to prevent overflow:
/// - Max coefficient: ~1e20
/// - Max input: 6e18
/// - Max product: ~6e38 << u256 max (~1e77)
///
/// Division by zero is the primary failure mode, not overflow.
#[error(code = 2)]
const EDivisionByZero: vector<u8> = b"Denominator must be non-zero.";

// === Public Getters ===

/// Get the scale factor (WAD = 1e18)
public fun scale(): u256 {
    SCALE
}

/// Get the maximum input value (6 * SCALE)
public fun max_input(): u256 {
    MAX_INPUT
}

// === Signed Arithmetic ===

/// Add two signed magnitudes.
///
/// Computes (a_mag, a_neg) + (b_mag, b_neg) where:
/// - a_mag, b_mag are absolute values
/// - a_neg, b_neg are true if the value is negative
///
/// Returns (result_mag, result_neg)
public fun signed_add(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): (u256, bool) {
    if (a_neg == b_neg) {
        // Same sign: add magnitudes, keep sign
        (a_mag + b_mag, a_neg)
    } else {
        // Different signs: subtract magnitudes
        if (a_mag >= b_mag) {
            (a_mag - b_mag, a_neg)
        } else {
            (b_mag - a_mag, b_neg)
        }
    }
}

// === Shared helpers (OZ-style) ===

/// Multiply two unsigned integers, divide by WAD `SCALE`, and return the `u256` quotient.
///
/// Kept as a macro so it can be reused across widths (`u128`, `u256`) without duplicating logic.
public(package) macro fun mul_div_wad_u256<$Int>($a: $Int, $b: $Int): u256 {
    (($a as u256) * ($b as u256)) / SCALE
}

/// Compute `($a * SCALE) / $b` and return the `u256` quotient.
public(package) macro fun div_scaled_wad_u256<$Int>($a: $Int, $b: $Int): u256 {
    (($a as u256) * SCALE) / ($b as u256)
}

fun div_round(numer: u256, denom: u256, mode: RoundingMode): u256 {
    let q = numer / denom;
    let r = numer % denom;
    if (r == 0) {
        return q
    };

    if (mode == rounding::down()) {
        q
    } else if (mode == rounding::up()) {
        q + 1
    } else {
        // Nearest (ties round up).
        // Condition r * 2 >= denom rewritten as r >= denom - r (avoids potential overflow).
        if (r >= denom - r) { q + 1 } else { q }
    }
}

/// Fixed-point multiplication: (a * x) / SCALE
///
/// Used in Horner's method for polynomial evaluation.
/// Assumes both a and x are WAD-scaled.
public fun mul_div(a: u256, x: u256): u256 {
    (a * x) / SCALE
}

/// Fixed-point multiplication: (a * x) / SCALE with explicit rounding.
public fun mul_div_round(a: u256, x: u256, mode: RoundingMode): u256 {
    div_round(a * x, SCALE, mode)
}

/// Fixed-point division with scaling: (a * SCALE) / b
///
/// Used for computing P(x) / Q(x) in rational functions.
/// Aborts if b is zero.
public fun div_scaled(a: u256, b: u256): u256 {
    assert!(b > 0, EDivisionByZero);
    (a * SCALE) / b
}

/// Fixed-point division with scaling: (a * SCALE) / b with explicit rounding.
public fun div_scaled_round(a: u256, b: u256, mode: RoundingMode): u256 {
    assert!(b > 0, EDivisionByZero);
    div_round(a * SCALE, b, mode)
}

/// Checked fixed-point division with scaling.
///
/// Returns `option::none()` when `b == 0` instead of aborting.
public fun div_scaled_checked(a: u256, b: u256): Option<u256> {
    if (b == 0) {
        option::none()
    } else {
        option::some((a * SCALE) / b)
    }
}

/// Checked fixed-point division with scaling and explicit rounding.
public fun div_scaled_round_checked(a: u256, b: u256, mode: RoundingMode): Option<u256> {
    if (b == 0) {
        option::none()
    } else {
        option::some(div_round(a * SCALE, b, mode))
    }
}

/// Clamp a value to the range [0, SCALE] (i.e., [0, 1] in float terms)
public fun clamp_to_unit(value: u256): u256 {
    if (value > SCALE) {
        SCALE
    } else {
        value
    }
}

/// Fixed-point multiplication: (a * b) / SCALE for u128.
/// Uses u256 intermediates to preserve precision before scaling back.
public(package) fun mul_div_128(a: u128, b: u128): u128 {
    (mul_div_wad_u256!(a, b) as u128)
}

/// Fixed-point division: (a * SCALE) / b for u128.
/// Aborts if b is zero; denominator is not truncated before division.
public(package) fun div_scaled_128(a: u128, b: u128): u128 {
    assert!(b > 0, EDivisionByZero);
    (div_scaled_wad_u256!(a, b) as u128)
}

public(package) fun div_scaled_128_checked(a: u128, b: u128): Option<u128> {
    if (b == 0) {
        option::none()
    } else {
        option::some((div_scaled_wad_u256!(a, b) as u128))
    }
}

/// Signed addition for u128 magnitudes with separate sign flags.
/// Returns (magnitude, is_negative).
public(package) fun signed_add_128(
    a_mag: u128,
    a_neg: bool,
    b_mag: u128,
    b_neg: bool,
): (u128, bool) {
    if (a_neg == b_neg) {
        // Same sign: add magnitudes
        (a_mag + b_mag, a_neg)
    } else {
        // Different signs: subtract magnitudes
        if (a_mag >= b_mag) {
            (a_mag - b_mag, a_neg)
        } else {
            (b_mag - a_mag, b_neg)
        }
    }
}

// === Tests ===

#[test]
fun test_signed_add_same_sign_positive() {
    let (mag, neg) = signed_add(100, false, 50, false);
    assert!(mag == 150, 0);
    assert!(neg == false, 1);
}

#[test]
fun test_signed_add_same_sign_negative() {
    let (mag, neg) = signed_add(100, true, 50, true);
    assert!(mag == 150, 0);
    assert!(neg == true, 1);
}

#[test]
fun test_signed_add_different_sign_a_larger() {
    // 100 + (-50) = 50
    let (mag, neg) = signed_add(100, false, 50, true);
    assert!(mag == 50, 0);
    assert!(neg == false, 1);
}

#[test]
fun test_signed_add_different_sign_b_larger() {
    // 50 + (-100) = -50
    let (mag, neg) = signed_add(50, false, 100, true);
    assert!(mag == 50, 0);
    assert!(neg == true, 1);
}

#[test]
fun test_mul_div() {
    // 2 * 3 / SCALE = 6 / SCALE (in WAD terms: 2e18 * 3e18 / 1e18 = 6e18)
    let a = 2 * SCALE;
    let x = 3 * SCALE;
    let result = mul_div(a, x);
    assert!(result == 6 * SCALE, 0);
}

#[test]
fun test_div_scaled() {
    // (2 * SCALE) / 4 = 0.5 * SCALE
    let result = div_scaled(2 * SCALE, 4 * SCALE);
    assert!(result == SCALE / 2, 0);
}

#[test]
fun test_clamp_to_unit() {
    assert!(clamp_to_unit(SCALE / 2) == SCALE / 2, 0);
    assert!(clamp_to_unit(SCALE) == SCALE, 1);
    assert!(clamp_to_unit(SCALE + 1) == SCALE, 2);
    assert!(clamp_to_unit(2 * SCALE) == SCALE, 3);
}

// Error code tests

#[test]
#[expected_failure(abort_code = EDivisionByZero)]
/// Test that div_scaled aborts when denominator is zero
fun test_div_scaled_zero_denominator() {
    div_scaled(100, 0); // Should abort with EDivisionByZero
}

#[test]
#[expected_failure(abort_code = EDivisionByZero)]
/// Test that div_scaled aborts even with large numerator and zero denominator
fun test_div_scaled_large_numerator_zero_denominator() {
    div_scaled(1_000_000_000_000_000_000, 0); // Should abort
}

#[test]
fun test_div_scaled_checked_zero_returns_none() {
    let result = div_scaled_checked(1, 0);
    assert!(option::is_none(&result), 0);
}

#[test]
fun test_div_scaled_round_up_matches_expected() {
    // (1.0 * SCALE) / 3 should round to 0.333... -> up should add 1 wei.
    let a = SCALE;
    let b = 3u256;
    let down = div_scaled_round(a, b, rounding::down());
    let up = div_scaled_round(a, b, rounding::up());
    assert!(up == down + 1, 0);
}

#[test]
/// Test that div_scaled works correctly with non-zero denominator
fun test_div_scaled_normal_operation() {
    // (2 * SCALE) / (4 * SCALE) = 0.5 * SCALE
    let result = div_scaled(2 * SCALE, 4 * SCALE);
    assert!(result == SCALE / 2, 0);

    // Should not abort with positive denominator
    let _ = div_scaled(100, 1);
    let _ = div_scaled(0, 1); // Numerator can be zero
}
