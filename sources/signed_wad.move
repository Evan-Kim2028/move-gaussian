/// Signed fixed-point WAD type for Gaussian library.
/// 
/// # Overview
/// 
/// This module provides a single canonical signed type (`SignedWad`) for all
/// Gaussian functions. It wraps magnitude and sign flag, delegating arithmetic
/// to `gaussian::math` for consistency.
/// 
/// # WAD Scaling
/// 
/// All values use WAD scaling: multiply by 10^18.
/// - 1.0 → SignedWad { magnitude: 1_000_000_000_000_000_000, negative: false }
/// - -2.5 → SignedWad { magnitude: 2_500_000_000_000_000_000, negative: true }
/// 
/// # Usage
/// 
/// ```move
/// let a = signed_wad::from_wad(1_000_000_000_000_000_000); // 1.0
/// let b = signed_wad::new(500_000_000_000_000_000, true);  // -0.5
/// let c = signed_wad::add(&a, &b);                         // 0.5
/// ```
module gaussian::signed_wad {
    use gaussian::math;

    // === Constants ===

    /// Maximum representable u256 value.
    #[allow(unused_const)]
    const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    #[allow(unused_const)]
    const SCALE: u256 = 1_000_000_000_000_000_000;

    // === Errors ===

    /// Division by zero.
    const EDivisionByZero: u64 = 10;
    
    /// Unexpected negative value where only non-negative is allowed.
    const EUnexpectedNegative: u64 = 11;

    // === Structs ===

    /// Signed WAD value with magnitude and sign flag.
    /// 
    /// This is the canonical signed type for all Gaussian functions:
    /// - PPF returns `SignedWad`
    /// - CDF/PDF take `&SignedWad`
    /// - Sampler can return `SignedWad` or wrap it
    /// 
    /// # Normalization
    /// Zero is always stored as non-negative (negative: false).
    public struct SignedWad has copy, drop, store {
        /// Absolute value of the number (WAD-scaled, 10^18).
        /// Example: For -2.5, magnitude = 2_500_000_000_000_000_000
        magnitude: u256,
        /// Sign flag: true = negative, false = non-negative.
        /// Note: Zero is always stored with negative = false.
        negative: bool,
    }

    // === Constructors ===

    /// Create a new SignedWad from magnitude and sign flag.
    public fun new(magnitude: u256, negative: bool): SignedWad {
        // Normalize: zero is never negative
        if (magnitude == 0) {
            SignedWad { magnitude: 0, negative: false }
        } else {
            SignedWad { magnitude, negative }
        }
    }

    /// Create a zero SignedWad.
    public fun zero(): SignedWad {
        SignedWad { magnitude: 0, negative: false }
    }

    /// Create a non-negative SignedWad from an unsigned WAD value.
    public fun from_wad(x: u256): SignedWad {
        SignedWad { magnitude: x, negative: false }
    }

    /// Create a SignedWad from the difference of two unsigned WADs.
    /// 
    /// `from_difference(a, b)` returns a - b as a SignedWad.
    /// Useful for Newton iteration: `err = cdf(z) - p`.
    public fun from_difference(a: u256, b: u256): SignedWad {
        if (a >= b) {
            SignedWad { magnitude: a - b, negative: false }
        } else {
            SignedWad { magnitude: b - a, negative: true }
        }
    }

    // === Accessors ===

    /// Get the absolute value (magnitude) of a SignedWad.
    public fun abs(x: &SignedWad): u256 {
        x.magnitude
    }

    /// Check if a SignedWad is negative.
    public fun is_negative(x: &SignedWad): bool {
        x.negative
    }

    /// Check if a SignedWad is zero.
    public fun is_zero(x: &SignedWad): bool {
        x.magnitude == 0
    }

    /// Get the magnitude (for internal use or struct access).
    public fun magnitude(x: &SignedWad): u256 {
        x.magnitude
    }

    // === Unary operations ===

    /// Negate a SignedWad: -x.
    public fun negate(x: &SignedWad): SignedWad {
        if (x.magnitude == 0) {
            zero()
        } else {
            SignedWad { magnitude: x.magnitude, negative: !x.negative }
        }
    }

    // === Binary arithmetic operations ===

    /// Add two SignedWad values.
    /// 
    /// Delegates to `math::signed_add` for sign handling.
    public fun add(a: &SignedWad, b: &SignedWad): SignedWad {
        let (mag, neg) = math::signed_add(
            a.magnitude,
            a.negative,
            b.magnitude,
            b.negative
        );
        new(mag, neg)
    }

    /// Subtract two SignedWad values: a - b.
    /// 
    /// Equivalent to a + (-b).
    public fun sub(a: &SignedWad, b: &SignedWad): SignedWad {
        let neg_b = negate(b);
        add(a, &neg_b)
    }

    /// Multiply a SignedWad by an unsigned WAD factor.
    /// 
    /// `mul_wad(a, k)` returns a * k / SCALE.
    /// The result has the same sign as `a`.
    public fun mul_wad(a: &SignedWad, k: u256): SignedWad {
        let result_mag = math::mul_div(a.magnitude, k);
        new(result_mag, a.negative)
    }

    /// Multiply two SignedWad values.
    /// 
    /// `mul(a, b)` returns (a * b) / SCALE.
    /// Sign is XOR of input signs.
    public fun mul(a: &SignedWad, b: &SignedWad): SignedWad {
        let result_mag = math::mul_div(a.magnitude, b.magnitude);
        let result_neg = a.negative != b.negative; // XOR for sign
        new(result_mag, result_neg)
    }

    /// Divide two SignedWad values.
    /// 
    /// `div_wad(a, b)` returns (a * SCALE) / b.
    /// Aborts if b is zero.
    public fun div_wad(a: &SignedWad, b: &SignedWad): SignedWad {
        assert!(b.magnitude > 0, EDivisionByZero);
        let result_mag = math::div_scaled(a.magnitude, b.magnitude);
        let result_neg = a.negative != b.negative; // XOR for sign
        new(result_mag, result_neg)
    }

    // === Conversion functions ===

    /// Convert to unsigned WAD with clamping: negative values become 0.
    /// 
    /// Useful for functions that must return non-negative values (e.g., PDF).
    public fun to_wad_clamped(x: &SignedWad): u256 {
        if (x.negative) {
            0
        } else {
            x.magnitude
        }
    }

    /// Convert to unsigned WAD, aborting if negative.
    /// 
    /// Use when negative values indicate an error condition.
    public fun to_wad_checked(x: &SignedWad): u256 {
        assert!(!x.negative, EUnexpectedNegative);
        x.magnitude
    }

    // === Comparison functions ===

    /// Compare two SignedWad values.
    /// Returns: -1 if a < b, 0 if a == b, 1 if a > b.
    public fun cmp(a: &SignedWad, b: &SignedWad): u8 {
        // Handle sign differences
        if (!a.negative && b.negative) {
            // a >= 0, b < 0 => a > b (unless both zero)
            if (a.magnitude == 0 && b.magnitude == 0) { return 0 };
            return 1
        };
        if (a.negative && !b.negative) {
            // a < 0, b >= 0 => a < b (unless both zero)
            if (a.magnitude == 0 && b.magnitude == 0) { return 0 };
            return 2 // represents -1 (we use 2 to avoid signed return)
        };

        // Same sign
        if (!a.negative) {
            // Both non-negative
            if (a.magnitude > b.magnitude) { 1 }
            else if (a.magnitude < b.magnitude) { 2 }
            else { 0 }
        } else {
            // Both negative: larger magnitude means smaller value
            if (a.magnitude > b.magnitude) { 2 }
            else if (a.magnitude < b.magnitude) { 1 }
            else { 0 }
        }
    }

    /// Check if a < b.
    public fun lt(a: &SignedWad, b: &SignedWad): bool {
        cmp(a, b) == 2
    }

    /// Check if a <= b.
    public fun le(a: &SignedWad, b: &SignedWad): bool {
        let c = cmp(a, b);
        c == 2 || c == 0
    }

    /// Check if a > b.
    public fun gt(a: &SignedWad, b: &SignedWad): bool {
        cmp(a, b) == 1
    }

    /// Check if a >= b.
    public fun ge(a: &SignedWad, b: &SignedWad): bool {
        let c = cmp(a, b);
        c == 1 || c == 0
    }

    /// Check if a == b.
    public fun eq(a: &SignedWad, b: &SignedWad): bool {
        cmp(a, b) == 0
    }

    // === Tests ===

    #[test]
    fun test_new_normalizes_zero() {
        let z = new(0, true); // Negative zero
        assert!(z.magnitude == 0, 0);
        assert!(z.negative == false, 1); // Should be normalized to positive
    }

    #[test]
    fun test_from_wad() {
        let x = from_wad(SCALE);
        assert!(x.magnitude == SCALE, 0);
        assert!(x.negative == false, 1);
    }

    #[test]
    fun test_from_difference_positive() {
        let x = from_difference(3 * SCALE, 1 * SCALE);
        assert!(x.magnitude == 2 * SCALE, 0);
        assert!(x.negative == false, 1);
    }

    #[test]
    fun test_from_difference_negative() {
        let x = from_difference(1 * SCALE, 3 * SCALE);
        assert!(x.magnitude == 2 * SCALE, 0);
        assert!(x.negative == true, 1);
    }

    #[test]
    fun test_negate() {
        let pos = from_wad(SCALE);
        let neg = negate(&pos);
        assert!(neg.magnitude == SCALE, 0);
        assert!(neg.negative == true, 1);

        let back = negate(&neg);
        assert!(back.magnitude == SCALE, 2);
        assert!(back.negative == false, 3);
    }

    #[test]
    fun test_negate_zero() {
        let z = zero();
        let neg_z = negate(&z);
        assert!(neg_z.magnitude == 0, 0);
        assert!(neg_z.negative == false, 1); // -0 = 0
    }

    #[test]
    fun test_add_same_sign() {
        let a = from_wad(2 * SCALE);
        let b = from_wad(3 * SCALE);
        let c = add(&a, &b);
        assert!(c.magnitude == 5 * SCALE, 0);
        assert!(c.negative == false, 1);
    }

    #[test]
    fun test_add_different_sign() {
        let a = from_wad(5 * SCALE);
        let b = new(3 * SCALE, true); // -3
        let c = add(&a, &b);          // 5 + (-3) = 2
        assert!(c.magnitude == 2 * SCALE, 0);
        assert!(c.negative == false, 1);
    }

    #[test]
    fun test_add_near_cancellation() {
        let a = from_wad(SCALE);
        let b = new(SCALE, true); // -1
        let c = add(&a, &b);      // 1 + (-1) = 0
        assert!(c.magnitude == 0, 0);
        assert!(c.negative == false, 1);
    }

    #[test]
    fun test_sub() {
        let a = from_wad(5 * SCALE);
        let b = from_wad(3 * SCALE);
        let c = sub(&a, &b); // 5 - 3 = 2
        assert!(c.magnitude == 2 * SCALE, 0);
        assert!(c.negative == false, 1);

        let d = sub(&b, &a); // 3 - 5 = -2
        assert!(d.magnitude == 2 * SCALE, 2);
        assert!(d.negative == true, 3);
    }

    #[test]
    fun test_mul_wad() {
        let a = from_wad(2 * SCALE); // 2.0
        let result = mul_wad(&a, 3 * SCALE); // 2.0 * 3.0 = 6.0
        assert!(result.magnitude == 6 * SCALE, 0);
        assert!(result.negative == false, 1);
    }

    #[test]
    fun test_mul_wad_negative() {
        let a = new(2 * SCALE, true); // -2.0
        let result = mul_wad(&a, 3 * SCALE); // -2.0 * 3.0 = -6.0
        assert!(result.magnitude == 6 * SCALE, 0);
        assert!(result.negative == true, 1);
    }

    #[test]
    fun test_mul() {
        let a = from_wad(2 * SCALE); // 2.0
        let b = from_wad(3 * SCALE); // 3.0
        let c = mul(&a, &b);         // 6.0
        assert!(c.magnitude == 6 * SCALE, 0);
        assert!(c.negative == false, 1);
    }

    #[test]
    fun test_mul_mixed_signs() {
        let a = from_wad(2 * SCALE);   // 2.0
        let b = new(3 * SCALE, true);  // -3.0
        let c = mul(&a, &b);           // -6.0
        assert!(c.magnitude == 6 * SCALE, 0);
        assert!(c.negative == true, 1);

        // Negative * negative = positive
        let d = new(2 * SCALE, true);  // -2.0
        let e = mul(&d, &b);           // -2.0 * -3.0 = 6.0
        assert!(e.magnitude == 6 * SCALE, 2);
        assert!(e.negative == false, 3);
    }

    #[test]
    fun test_div_wad() {
        let a = from_wad(6 * SCALE); // 6.0
        let b = from_wad(2 * SCALE); // 2.0
        let c = div_wad(&a, &b);     // 3.0
        assert!(c.magnitude == 3 * SCALE, 0);
        assert!(c.negative == false, 1);
    }

    #[test]
    fun test_div_wad_mixed_signs() {
        let a = from_wad(6 * SCALE);  // 6.0
        let b = new(2 * SCALE, true); // -2.0
        let c = div_wad(&a, &b);      // -3.0
        assert!(c.magnitude == 3 * SCALE, 0);
        assert!(c.negative == true, 1);
    }

    #[test]
    #[expected_failure(abort_code = EDivisionByZero)]
    fun test_div_wad_by_zero() {
        let a = from_wad(SCALE);
        let b = zero();
        div_wad(&a, &b);
    }

    #[test]
    fun test_to_wad_clamped() {
        let pos = from_wad(SCALE);
        assert!(to_wad_clamped(&pos) == SCALE, 0);

        let neg = new(SCALE, true);
        assert!(to_wad_clamped(&neg) == 0, 1);
    }

    #[test]
    fun test_comparison_same_sign() {
        let a = from_wad(2 * SCALE);
        let b = from_wad(3 * SCALE);
        assert!(lt(&a, &b), 0);
        assert!(le(&a, &b), 1);
        assert!(gt(&b, &a), 2);
        assert!(ge(&b, &a), 3);
        assert!(!eq(&a, &b), 4);
    }

    #[test]
    fun test_comparison_different_sign() {
        let pos = from_wad(SCALE);
        let neg = new(SCALE, true);
        assert!(gt(&pos, &neg), 0);
        assert!(lt(&neg, &pos), 1);
    }

    #[test]
    fun test_comparison_equal() {
        let a = from_wad(SCALE);
        let b = from_wad(SCALE);
        assert!(eq(&a, &b), 0);
        assert!(le(&a, &b), 1);
        assert!(ge(&a, &b), 2);
    }

    #[test]
    fun test_comparison_negative_values() {
        let a = new(3 * SCALE, true); // -3
        let b = new(2 * SCALE, true); // -2
        // -3 < -2
        assert!(lt(&a, &b), 0);
        assert!(gt(&b, &a), 1);
    }
}
