/// Formal verification specifications for the math module.
///
/// This file contains specs that sui-prover will verify.
/// Start with simple properties and build up to more complex ones.
module gaussian::math_spec;

use gaussian::math;

#[spec_only]
use prover::prover::{requires, ensures};

// =============================================================================
// LEVEL 1: clamp_to_unit bounds (Hello World) - VERIFIED
// =============================================================================

/// Verify that clamp_to_unit always returns a value <= SCALE.
///
/// This is the simplest possible spec - it verifies a basic bound.
/// Property: forall x, clamp_to_unit(x) <= SCALE
#[spec(prove)]
fun clamp_to_unit_bounded_spec(value: u256): u256 {
    let result = math::clamp_to_unit(value);
    
    // Postcondition: result is always bounded by SCALE
    ensures(result <= math::scale());
    
    result
}

/// Verify that clamp_to_unit preserves values already in range.
///
/// Property: forall x <= SCALE, clamp_to_unit(x) == x
#[spec(prove)]
fun clamp_to_unit_preserves_small_spec(value: u256): u256 {
    // Precondition: value is already within bounds
    requires(value <= math::scale());
    
    let result = math::clamp_to_unit(value);
    
    // Postcondition: value is unchanged
    ensures(result == value);
    
    result
}

// =============================================================================
// LEVEL 2: mul_div correctness
// =============================================================================

/// Verify that mul_div computes (a * x) / SCALE correctly.
///
/// Uses unbounded integers in the spec to verify without overflow concerns.
/// Property: mul_div(a, x) == (a * x) / SCALE
#[spec(prove)]
fun mul_div_correctness_spec(a: u256, x: u256): u256 {
    // Precondition: prevent overflow (a * x must fit in u256)
    requires(a <= 10_000_000_000_000_000_000_000); // ~1e22
    requires(x <= 10_000_000_000_000_000_000_000);
    
    let result = math::mul_div(a, x);
    
    // Postcondition: result equals (a * x) / SCALE using unbounded integers
    let a_int = a.to_int();
    let x_int = x.to_int();
    let scale_int = math::scale().to_int();
    ensures(result.to_int() == a_int.mul(x_int).div(scale_int));
    
    result
}

/// Verify that mul_div returns 0 when either input is 0.
///
/// Property: mul_div(0, x) == 0 AND mul_div(a, 0) == 0
#[spec(prove)]
fun mul_div_zero_spec(a: u256, x: u256): u256 {
    requires(a == 0 || x == 0);
    
    let result = math::mul_div(a, x);
    
    ensures(result == 0);
    
    result
}

// =============================================================================
// LEVEL 3: signed_add correctness
// =============================================================================

/// Verify that signed_add with same signs adds magnitudes.
///
/// Property: signed_add(a, sign, b, sign) == (a + b, sign)
#[spec(prove)]
fun signed_add_same_sign_spec(a_mag: u256, b_mag: u256, sign: bool): (u256, bool) {
    // Prevent overflow when adding magnitudes
    requires(a_mag <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    requires(b_mag <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    
    let (result_mag, result_neg) = math::signed_add(a_mag, sign, b_mag, sign);
    
    // Magnitudes add
    ensures(result_mag == a_mag + b_mag);
    // Sign is preserved (or result is zero which normalizes to positive)
    ensures(result_neg == sign || result_mag == 0);
    
    (result_mag, result_neg)
}

/// Verify that signed_add is commutative (for magnitude).
///
/// Note: Sign may differ for zero due to implementation not normalizing zero.
/// Property: signed_add(a, a_neg, b, b_neg).magnitude == signed_add(b, b_neg, a, a_neg).magnitude
#[spec(prove)]
fun signed_add_commutative_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): (u256, bool) {
    // Prevent overflow - bound inputs to half of u256 max
    requires(a_mag <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    requires(b_mag <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    
    let (r1_mag, r1_neg) = math::signed_add(a_mag, a_neg, b_mag, b_neg);
    let (r2_mag, r2_neg) = math::signed_add(b_mag, b_neg, a_mag, a_neg);
    
    // Magnitudes are always equal (commutativity holds for magnitude)
    ensures(r1_mag == r2_mag);
    // Signs are equal when magnitude is non-zero
    // (zero can have inconsistent sign due to impl not normalizing)
    ensures(r1_mag == 0 || r1_neg == r2_neg);
    
    (r1_mag, r1_neg)
}

/// Verify that adding zero preserves the original value.
///
/// Property: signed_add(a, a_neg, 0, false) == (a, a_neg)
#[spec(prove)]
fun signed_add_zero_identity_spec(a_mag: u256, a_neg: bool): (u256, bool) {
    let (result_mag, result_neg) = math::signed_add(a_mag, a_neg, 0, false);
    
    ensures(result_mag == a_mag);
    // Sign preserved unless magnitude is zero
    ensures(result_neg == a_neg || a_mag == 0);
    
    (result_mag, result_neg)
}

/// Verify that subtracting a value from itself yields zero.
///
/// Property: signed_add(a, false, a, true) == (0, false)
#[spec(prove)]
fun signed_add_self_cancellation_spec(a_mag: u256): (u256, bool) {
    let (result_mag, result_neg) = math::signed_add(a_mag, false, a_mag, true);
    
    ensures(result_mag == 0);
    ensures(result_neg == false); // Zero is always non-negative
    
    (result_mag, result_neg)
}
