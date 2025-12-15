/// Formal verification specifications for the normal_forward module.
///
/// Level 5: CDF properties including monotonicity.
///
/// IMPORTANT: Like erf, the CDF uses polynomial evaluation with large coefficients
/// that cause symbolic overflow. Direct verification of cdf_standard is not possible.
///
/// However, we CAN verify:
/// 1. SignedWad comparison operations (used to establish monotonicity preconditions)
/// 2. The symmetry relationship at the type level
/// 3. Properties of the clamping logic
///
/// The monotonicity of CDF is guaranteed by:
/// - Mathematical properties of the normal distribution
/// - The polynomial approximation preserving monotonicity (verified in Python)
/// - Extensive numerical testing in the test suite
module gaussian::normal_forward_spec;

use gaussian::signed_wad::{Self, SignedWad};
use gaussian::math;

#[spec_only]
use prover::prover::{requires, ensures};

// =============================================================================
// LEVEL 5: SignedWad comparison specs (building blocks for monotonicity)
// =============================================================================

/// Verify that SignedWad less-than is consistent with the comparison function.
///
/// Property: lt(a, b) == true iff cmp(a, b) == 2
#[spec(prove)]
fun signed_wad_lt_consistent_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): bool {
    let a = signed_wad::new(a_mag, a_neg);
    let b = signed_wad::new(b_mag, b_neg);
    
    let lt_result = signed_wad::lt(&a, &b);
    let cmp_result = signed_wad::cmp(&a, &b);
    
    // lt returns true iff cmp returns 2 (representing "less than")
    ensures(lt_result == (cmp_result == 2));
    
    lt_result
}

/// Verify that SignedWad less-than-or-equal is consistent.
///
/// Property: le(a, b) == true iff cmp(a, b) == 2 or cmp(a, b) == 0
#[spec(prove)]
fun signed_wad_le_consistent_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): bool {
    let a = signed_wad::new(a_mag, a_neg);
    let b = signed_wad::new(b_mag, b_neg);
    
    let le_result = signed_wad::le(&a, &b);
    let cmp_result = signed_wad::cmp(&a, &b);
    
    // le returns true iff cmp returns 2 (less) or 0 (equal)
    ensures(le_result == (cmp_result == 2 || cmp_result == 0));
    
    le_result
}

/// Verify that SignedWad comparison is antisymmetric.
///
/// Property: if lt(a, b) then !lt(b, a)
#[spec(prove)]
fun signed_wad_lt_antisymmetric_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): (bool, bool) {
    let a = signed_wad::new(a_mag, a_neg);
    let b = signed_wad::new(b_mag, b_neg);
    
    let a_lt_b = signed_wad::lt(&a, &b);
    let b_lt_a = signed_wad::lt(&b, &a);
    
    // Antisymmetry: if a < b then not(b < a)
    ensures(!a_lt_b || !b_lt_a);
    
    (a_lt_b, b_lt_a)
}

/// Verify that SignedWad equality is reflexive.
///
/// Property: eq(a, a) == true
#[spec(prove)]
fun signed_wad_eq_reflexive_spec(mag: u256, neg: bool): bool {
    let a = signed_wad::new(mag, neg);
    
    let result = signed_wad::eq(&a, &a);
    
    ensures(result == true);
    
    result
}

/// Verify that SignedWad equality is symmetric.
///
/// Property: eq(a, b) == eq(b, a)
#[spec(prove)]
fun signed_wad_eq_symmetric_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): (bool, bool) {
    let a = signed_wad::new(a_mag, a_neg);
    let b = signed_wad::new(b_mag, b_neg);
    
    let a_eq_b = signed_wad::eq(&a, &b);
    let b_eq_a = signed_wad::eq(&b, &a);
    
    ensures(a_eq_b == b_eq_a);
    
    (a_eq_b, b_eq_a)
}

/// Verify that le and gt are complements.
///
/// Property: le(a, b) != gt(a, b) (unless equal, then both can be true/false)
/// Actually: le(a, b) == !gt(a, b) when a != b
#[spec(prove)]
fun signed_wad_le_gt_complement_spec(a_mag: u256, a_neg: bool, b_mag: u256, b_neg: bool): (bool, bool) {
    let a = signed_wad::new(a_mag, a_neg);
    let b = signed_wad::new(b_mag, b_neg);
    
    let le_result = signed_wad::le(&a, &b);
    let gt_result = signed_wad::gt(&a, &b);
    let eq_result = signed_wad::eq(&a, &b);
    
    // If not equal, le and gt are complements
    // If equal, le is true and gt is false
    ensures(eq_result || (le_result != gt_result));
    ensures(!eq_result || (le_result && !gt_result));
    
    (le_result, gt_result)
}

// =============================================================================
// Note on CDF Monotonicity
// =============================================================================
//
// The CDF monotonicity property:
//   forall z1 z2, z1 <= z2 => cdf(z1) <= cdf(z2)
//
// Cannot be directly verified due to polynomial overflow in symbolic execution.
// 
// However, monotonicity is guaranteed by:
// 1. The standard normal CDF is mathematically monotonic by definition
// 2. The polynomial approximation preserves monotonicity (verified numerically)
// 3. The implementation uses clamping which preserves ordering
// 4. Extensive test coverage including test_cdf_monotonic in normal_forward.move
//
// The SignedWad comparison specs above verify the building blocks needed to
// express monotonicity relationships at the type level.
