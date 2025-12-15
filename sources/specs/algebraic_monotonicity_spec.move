/// Algebraic approach to proving CDF monotonicity.
///
/// This module uses real arithmetic (to_real()) to verify mathematical properties
/// without the overflow issues of fixed-point integer arithmetic.
///
/// Key insight: We prove monotonicity by showing the derivative is non-negative,
/// which is a purely algebraic property that Z3 can handle.
module gaussian::algebraic_monotonicity_spec;

#[spec_only]
use prover::prover::{requires, ensures};

// =============================================================================
// Constants as reals (avoiding integer overflow)
// =============================================================================

const SCALE: u128 = 1_000_000_000_000_000_000;

// CDF numerator coefficients (degree 12 polynomial)
// P(z) = sum(p_i * z^i) for i = 0..12
const P0: u128 = 500000000000000000;   // 0.5
const P1: u128 = 202783200542711800;   // ~0.203
const P2: u128 = 3858755025623129;     // ~0.00386 (negative)
const P3: u128 = 11990724892373883;    // ~0.012
const P4: u128 = 9821445877008875;     // ~0.00982
const P5: u128 = 428553144348960;      // ~0.000429
const P6: u128 = 75031762951910;       // ~7.5e-5 (negative)
const P7: u128 = 152292945143770;      // ~1.5e-4
const P8: u128 = 11488864967923;       // ~1.1e-5
const P9: u128 = 4621581948805;        // ~4.6e-6 (negative)
const P10: u128 = 2225303281381;       // ~2.2e-6
const P11: u128 = 261982963157;        // ~2.6e-7 (negative)
const P12: u128 = 34576100063;         // ~3.5e-8

// Sign flags for numerator
const P2_NEG: bool = true;
const P6_NEG: bool = true;
const P9_NEG: bool = true;
const P11_NEG: bool = true;

// =============================================================================
// Test: Can we use to_real() in specs?
// =============================================================================

/// Simple test: verify real arithmetic works in specs.
#[spec(prove)]
fun real_arithmetic_test_spec(): bool {
    let a = 2u64.to_real();
    let b = 3u64.to_real();
    let c = a.mul(b);  // 2 * 3 = 6
    
    ensures(c == 6u64.to_real());
    
    true
}

/// Test: verify real division works.
#[spec(prove)]
fun real_division_test_spec(): bool {
    let a = 6u64.to_real();
    let b = 2u64.to_real();
    let c = a.div(b);  // 6 / 2 = 3
    
    ensures(c == 3u64.to_real());
    
    true
}

/// Test: verify real comparison works.
#[spec(prove)]
fun real_comparison_test_spec(): bool {
    let a = 2u64.to_real();
    let b = 3u64.to_real();
    
    ensures(a.lt(b));
    ensures(b.gt(a));
    
    true
}

// =============================================================================
// Polynomial evaluation in real arithmetic
// =============================================================================

/// Evaluate a simple quadratic: a + b*x + c*x^2
/// This tests polynomial evaluation without overflow.
#[spec(prove)]
fun quadratic_eval_spec(x_wad: u64): bool {
    // Bound x to reasonable range
    requires(x_wad <= 6_000_000_000_000_000_000);
    
    // Convert to real and scale
    let scale_real = SCALE.to_real();
    let x = x_wad.to_real().div(scale_real);  // x in [0, 6]
    
    // Quadratic: 1 + 2x + 3x^2
    let a = 1u64.to_real();
    let b = 2u64.to_real();
    let c = 3u64.to_real();
    
    let x2 = x.mul(x);
    let result = a.add(b.mul(x)).add(c.mul(x2));
    
    // For x >= 0, this quadratic is always >= 1
    ensures(result.gte(1u64.to_real()));
    
    true
}

// =============================================================================
// Derivative sign analysis (the key to monotonicity)
// =============================================================================

/// For a rational function R(x) = P(x)/Q(x), the derivative is:
/// R'(x) = (P'(x)*Q(x) - P(x)*Q'(x)) / Q(x)^2
///
/// Since Q(x)^2 > 0 when Q(x) != 0, R'(x) >= 0 iff:
/// P'(x)*Q(x) - P(x)*Q'(x) >= 0
///
/// This is what we need to prove for monotonicity.

/// Simplified test: prove derivative of a simple increasing function is positive.
/// f(x) = x^2 has f'(x) = 2x >= 0 for x >= 0
#[spec(prove)]
fun simple_derivative_positive_spec(x_wad: u64): bool {
    requires(x_wad <= 6_000_000_000_000_000_000);
    
    let scale_real = SCALE.to_real();
    let x = x_wad.to_real().div(scale_real);
    
    // f(x) = x^2
    // f'(x) = 2x
    let two = 2u64.to_real();
    let derivative = two.mul(x);
    
    // For x >= 0, derivative >= 0
    ensures(derivative.gte(0u64.to_real()));
    
    true
}

/// Test: derivative of linear function is constant.
/// f(x) = 0.5 + 0.2*x has f'(x) = 0.2 > 0
#[spec(prove)]
fun linear_derivative_positive_spec(): bool {
    // f(x) = 0.5 + 0.2*x
    // f'(x) = 0.2
    let derivative = P1.to_real().div(SCALE.to_real());  // ~0.203
    
    ensures(derivative.gt(0u64.to_real()));
    
    true
}

// =============================================================================
// CDF monotonicity building blocks
// =============================================================================

/// Key property: The CDF polynomial P(x) has positive leading terms.
/// This is necessary (but not sufficient) for monotonicity.
#[spec(prove)]
fun cdf_leading_coefficient_positive_spec(): bool {
    let p0_real = P0.to_real().div(SCALE.to_real());  // 0.5
    let p1_real = P1.to_real().div(SCALE.to_real());  // ~0.203
    
    // Both are positive
    ensures(p0_real.gt(0u64.to_real()));
    ensures(p1_real.gt(0u64.to_real()));
    
    true
}

/// Key property: At x=0, P(0) = 0.5 (CDF at z=0 is 0.5)
#[spec(prove)]
fun cdf_at_zero_spec(): bool {
    let p0_real = P0.to_real().div(SCALE.to_real());
    let half = 1u64.to_real().div(2u64.to_real());
    
    ensures(p0_real == half);
    
    true
}

// =============================================================================
// Composition lemmas for monotonicity
// =============================================================================

/// Lemma: If f is monotonically increasing and g is a positive linear transform,
/// then g(f(x)) is monotonically increasing.
///
/// CDF uses: cdf(z) = 0.5 * (1 + erf(z/sqrt(2))) for z >= 0
/// This is a positive linear transform of erf.
#[spec(prove)]
fun positive_linear_preserves_monotonicity_spec(
    f1: u64, f2: u64,  // f(x1) and f(x2) where x1 <= x2
    a: u64, b: u64     // Transform: g(y) = a + b*y where b > 0
): bool {
    requires(f1 <= f2);  // f is increasing: f(x1) <= f(x2)
    requires(b > 0);     // Positive scaling
    
    let f1_real = f1.to_real();
    let f2_real = f2.to_real();
    let a_real = a.to_real();
    let b_real = b.to_real();
    
    // g(f(x1)) = a + b*f(x1)
    let g1 = a_real.add(b_real.mul(f1_real));
    // g(f(x2)) = a + b*f(x2)
    let g2 = a_real.add(b_real.mul(f2_real));
    
    // Since f1 <= f2 and b > 0, we have g1 <= g2
    ensures(g1.lte(g2));
    
    true
}

/// Lemma: The symmetry transform preserves monotonicity.
/// For z < 0: cdf(z) = 1 - cdf(-z)
/// If cdf is increasing for z >= 0, then cdf is increasing for all z.
#[spec(prove)]
fun symmetry_preserves_monotonicity_spec(
    cdf_neg_z1: u64, cdf_neg_z2: u64  // cdf(-z1) and cdf(-z2) where z1 < z2 < 0
): bool {
    // For negative z: if z1 < z2 < 0, then -z1 > -z2 > 0
    // Since cdf is increasing for positive args: cdf(-z1) > cdf(-z2)
    requires(cdf_neg_z1 > cdf_neg_z2);
    
    let one = SCALE.to_real();
    let cdf_z1 = one.sub(cdf_neg_z1.to_real());  // 1 - cdf(-z1)
    let cdf_z2 = one.sub(cdf_neg_z2.to_real());  // 1 - cdf(-z2)
    
    // cdf(z1) = 1 - cdf(-z1) < 1 - cdf(-z2) = cdf(z2)
    ensures(cdf_z1.lt(cdf_z2));
    
    true
}
