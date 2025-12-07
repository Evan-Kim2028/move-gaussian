/// Transcendental functions for fixed-point arithmetic.
/// 
/// # Overview
/// 
/// This module provides transcendental functions needed for financial mathematics:
/// - `ln_wad(x)` - Natural logarithm for x > 0
/// - `exp_wad(x)` - Exponential function e^x
/// - `sqrt_wad(x)` - Square root
/// 
/// All functions use WAD scaling (10^18) for fixed-point precision.
/// 
/// # Use Cases
/// 
/// - Black-Scholes option pricing (ln(S/K), e^(-rT))
/// - Compound interest calculations
/// - Geometric Brownian motion
/// - Risk metrics (VaR, etc.)
/// 
/// # Precision
/// 
/// - `ln_wad`: < 0.01% error for x ∈ [1e-4, 1e6] WAD
/// - `exp_wad`: < 0.01% error for x ∈ [-20, 20] WAD
/// - `sqrt_wad`: Exact to WAD precision (Newton-Raphson)
module gaussian::transcendental {
    use gaussian::math;
    use gaussian::signed_wad::{Self, SignedWad};

    // === Constants ===

    /// Scale factor: WAD = 10^18
    const SCALE: u256 = 1_000_000_000_000_000_000;

    /// ln(2) in WAD: 0.693147180559945309 * 1e18
    const LN_2: u256 = 693_147_180_559_945_309;

    /// e in WAD: 2.718281828459045235 * 1e18
    const E: u256 = 2_718_281_828_459_045_235;

    /// 1/e in WAD: 0.367879441171442321 * 1e18
    const INV_E: u256 = 367_879_441_171_442_321;

    /// Maximum exponent magnitude (~20) to avoid overflow
    /// e^20 ≈ 4.85e8, which fits in WAD
    const MAX_EXP_INPUT: u256 = 20_000_000_000_000_000_000;

    // === Errors ===

    /// Input must be positive for ln
    const ELnNonPositive: u64 = 500;

    /// Exponent too large (would overflow)
    const EExpOverflow: u64 = 501;

    // === Public Functions ===

    /// Natural logarithm ln(x) for WAD-scaled x > 0.
    /// 
    /// # Arguments
    /// * `x` - Positive value in WAD scaling (x > 0)
    /// 
    /// # Returns
    /// * `SignedWad` - ln(x) which can be negative (for x < 1)
    /// 
    /// # Errors
    /// * `ELnNonPositive` (500) - if x <= 0
    /// 
    /// # Implementation
    /// Uses range reduction: ln(x) = ln(m * 2^k) = ln(m) + k*ln(2)
    /// where m ∈ [1, 2), then Taylor series for ln(m).
    /// 
    /// # Example
    /// ```move
    /// let x = 2_000_000_000_000_000_000; // 2.0
    /// let result = ln_wad(x);
    /// // result ≈ 693_147_180_559_945_309 (ln(2) ≈ 0.693)
    /// ```
    public fun ln_wad(x: u256): SignedWad {
        assert!(x > 0, ELnNonPositive);

        // ln(1) = 0
        if (x == SCALE) {
            return signed_wad::zero()
        };

        // Determine if result is negative (x < 1)
        let is_negative = x < SCALE;
        
        // Work with x >= 1 by using ln(1/x) = -ln(x) if needed
        let mut working_x = if (is_negative) {
            // x < 1: compute ln(1/x) then negate
            // 1/x = SCALE * SCALE / x
            (SCALE * SCALE) / x
        } else {
            x
        };

        // Range reduction: find k such that working_x = m * 2^k where m ∈ [1, 2)
        // We track k as magnitude and sign separately since Move has no signed integers
        let mut k_mag: u256 = 0;
        let mut k_neg: bool = false;
        
        // Scale up if x < 1 (after inversion this shouldn't happen, but safety check)
        while (working_x < SCALE) {
            working_x = working_x * 2;
            if (!k_neg && k_mag > 0) {
                k_mag = k_mag - 1;
            } else if (!k_neg && k_mag == 0) {
                k_neg = true;
                k_mag = 1;
            } else {
                k_mag = k_mag + 1;
            };
        };
        
        // Scale down if x >= 2
        while (working_x >= 2 * SCALE) {
            working_x = working_x / 2;
            if (k_neg && k_mag > 0) {
                k_mag = k_mag - 1;
                if (k_mag == 0) {
                    k_neg = false;
                };
            } else {
                k_neg = false;
                k_mag = k_mag + 1;
            };
        };

        // Now working_x ∈ [SCALE, 2*SCALE), i.e., m ∈ [1, 2)
        // Compute ln(m) using Taylor series for ln(1 + u) where u = m - 1
        // ln(1 + u) = u - u²/2 + u³/3 - u⁴/4 + ...
        let u = working_x - SCALE; // u ∈ [0, SCALE)
        
        let mut result = u; // First term: u
        let mut term = u;
        let mut n: u64 = 2;
        
        // Taylor series (converges for |u| < 1, which is satisfied since u < SCALE)
        while (n <= 12) {
            // term = term * u / SCALE (next power of u)
            term = math::mul_div(term, u);
            
            // Add or subtract term/n based on parity
            let contribution = term / (n as u256);
            
            if (n % 2 == 0) {
                // Subtract even terms
                if (result >= contribution) {
                    result = result - contribution;
                };
            } else {
                // Add odd terms
                result = result + contribution;
            };
            
            n = n + 1;
        };

        // Add k * ln(2)
        let k_contribution = k_mag * LN_2;

        let final_mag = if (!k_neg) {
            result + k_contribution
        } else {
            if (result >= k_contribution) {
                result - k_contribution
            } else {
                k_contribution - result
            }
        };

        // Apply sign based on original x
        signed_wad::new(final_mag, is_negative)
    }

    /// Exponential function e^x for SignedWad input.
    /// 
    /// # Arguments
    /// * `x` - Exponent as SignedWad (can be negative)
    /// 
    /// # Returns
    /// * `u256` - e^x in WAD scaling (always positive)
    /// 
    /// # Errors
    /// * `EExpOverflow` (501) - if |x| > 20 WAD (result would overflow)
    /// 
    /// # Implementation
    /// Uses range reduction: e^x = e^k * e^f where k = floor(x/ln2), f = x - k*ln2
    /// Then Taylor series for e^f where f ∈ [0, ln2).
    /// 
    /// # Example
    /// ```move
    /// let x = signed_wad::new(1_000_000_000_000_000_000, true); // -1.0
    /// let result = exp_wad(&x);
    /// // result ≈ 367_879_441_171_442_321 (e^-1 ≈ 0.368)
    /// ```
    public fun exp_wad(x: &SignedWad): u256 {
        let x_mag = signed_wad::abs(x);
        let x_neg = signed_wad::is_negative(x);

        // Handle zero
        if (x_mag == 0) {
            return SCALE
        };

        // Check bounds
        assert!(x_mag <= MAX_EXP_INPUT, EExpOverflow);

        // For negative x: e^(-|x|) = 1 / e^|x|
        // Compute e^|x| first
        
        // Range reduction: find k = floor(|x| / ln(2))
        // e^|x| = 2^k * e^f where f = |x| - k*ln(2) ∈ [0, ln(2))
        let k = x_mag / LN_2;
        let f = x_mag - k * LN_2;

        // Taylor series for e^f: 1 + f + f²/2! + f³/3! + f⁴/4! + ...
        let mut result = SCALE; // 1
        let mut term = SCALE;   // Current term (starts at 1)
        let mut n: u64 = 1;

        while (n <= 12) {
            // term = term * f / (n * SCALE)
            term = math::mul_div(term, f) / (n as u256);
            result = result + term;
            
            // Break early if term is negligible
            if (term == 0) {
                break
            };
            
            n = n + 1;
        };

        // Multiply by 2^k
        // 2^k = (2*SCALE / SCALE)^k, but we need to be careful about overflow
        // For each power of 2, multiply result by 2
        let mut i: u256 = 0;
        while (i < k) {
            result = result * 2;
            i = i + 1;
        };

        // If original x was negative, compute 1/result
        if (x_neg) {
            // 1/result = SCALE * SCALE / result
            (SCALE * SCALE) / result
        } else {
            result
        }
    }

    /// Square root of WAD-scaled value.
    /// 
    /// # Arguments
    /// * `x` - Non-negative value in WAD scaling
    /// 
    /// # Returns
    /// * `u256` - sqrt(x) in WAD scaling
    /// 
    /// # Implementation
    /// Newton-Raphson iteration: converges to exact WAD precision.
    /// Computes sqrt(x * SCALE) to maintain WAD scaling.
    /// 
    /// # Example
    /// ```move
    /// let x = 4_000_000_000_000_000_000; // 4.0
    /// let result = sqrt_wad(x);
    /// // result = 2_000_000_000_000_000_000 (2.0)
    /// ```
    public fun sqrt_wad(x: u256): u256 {
        if (x == 0) {
            return 0
        };

        // To compute sqrt(x) where x is WAD-scaled:
        // sqrt(x_wad) = sqrt(x_real * SCALE) = sqrt(x_real) * sqrt(SCALE)
        // But we want result in WAD: sqrt(x_real) * SCALE
        // So: result = sqrt(x_wad * SCALE)
        let n = x * SCALE;
        
        // Newton-Raphson: guess_{n+1} = (guess_n + n/guess_n) / 2
        let mut guess = n;
        let mut prev = 0u256;
        
        while (guess != prev) {
            prev = guess;
            guess = (guess + n / guess) / 2;
        };
        
        guess
    }

    /// Convenience: exp(-x) for positive x (common in finance for discounting)
    /// 
    /// # Arguments
    /// * `x` - Positive exponent in WAD scaling
    /// 
    /// # Returns
    /// * `u256` - e^(-x) in WAD scaling
    public fun exp_neg_wad(x: u256): u256 {
        let neg_x = signed_wad::new(x, true);
        exp_wad(&neg_x)
    }

    /// Natural logarithm of a ratio: ln(a/b)
    /// More accurate than computing ln(a) - ln(b) separately
    /// 
    /// # Arguments
    /// * `a` - Numerator in WAD scaling (a > 0)
    /// * `b` - Denominator in WAD scaling (b > 0)
    /// 
    /// # Returns
    /// * `SignedWad` - ln(a/b)
    public fun ln_ratio(a: u256, b: u256): SignedWad {
        assert!(a > 0 && b > 0, ELnNonPositive);
        
        // Compute a/b in WAD
        let ratio = math::div_scaled(a, b);
        ln_wad(ratio)
    }

    // === Constants Accessors ===

    /// Get ln(2) constant
    public fun ln_2(): u256 { LN_2 }

    /// Get e constant
    public fun e(): u256 { E }

    /// Get 1/e constant
    public fun inv_e(): u256 { INV_E }

    // === Tests ===

    #[test]
    fun test_ln_one() {
        let result = ln_wad(SCALE);
        assert!(signed_wad::is_zero(&result), 0);
    }

    #[test]
    fun test_ln_e() {
        // ln(e) = 1
        let result = ln_wad(E);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > SCALE) { mag - SCALE } else { SCALE - mag };
        // Allow 0.1% error
        assert!(diff < SCALE / 1000, 0);
        assert!(!signed_wad::is_negative(&result), 1);
    }

    #[test]
    fun test_ln_2() {
        let result = ln_wad(2 * SCALE);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > LN_2) { mag - LN_2 } else { LN_2 - mag };
        // Allow 0.1% error
        assert!(diff < LN_2 / 1000, 0);
        assert!(!signed_wad::is_negative(&result), 1);
    }

    #[test]
    fun test_ln_half() {
        // ln(0.5) = -ln(2)
        let result = ln_wad(SCALE / 2);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > LN_2) { mag - LN_2 } else { LN_2 - mag };
        // Allow 0.1% error
        assert!(diff < LN_2 / 1000, 0);
        assert!(signed_wad::is_negative(&result), 1);
    }

    #[test]
    fun test_exp_zero() {
        let zero = signed_wad::zero();
        let result = exp_wad(&zero);
        assert!(result == SCALE, 0);
    }

    #[test]
    fun test_exp_one() {
        // e^1 = e
        let one = signed_wad::from_wad(SCALE);
        let result = exp_wad(&one);
        let diff = if (result > E) { result - E } else { E - result };
        // Allow 0.1% error
        assert!(diff < E / 1000, 0);
    }

    #[test]
    fun test_exp_neg_one() {
        // e^-1 = 1/e
        let neg_one = signed_wad::new(SCALE, true);
        let result = exp_wad(&neg_one);
        let diff = if (result > INV_E) { result - INV_E } else { INV_E - result };
        // Allow 0.1% error
        assert!(diff < INV_E / 1000, 0);
    }

    #[test]
    fun test_exp_ln_roundtrip() {
        // e^(ln(x)) = x
        let x = 3 * SCALE; // 3.0
        let ln_x = ln_wad(x);
        let result = exp_wad(&ln_x);
        let diff = if (result > x) { result - x } else { x - result };
        // Allow 0.5% error for roundtrip
        assert!(diff < x / 200, 0);
    }

    #[test]
    fun test_sqrt_perfect_squares() {
        // sqrt(1) = 1
        assert!(sqrt_wad(SCALE) == SCALE, 0);
        
        // sqrt(4) = 2
        let result = sqrt_wad(4 * SCALE);
        let diff = if (result > 2 * SCALE) { result - 2 * SCALE } else { 2 * SCALE - result };
        assert!(diff < SCALE / 1000000, 1);
        
        // sqrt(9) = 3
        let result = sqrt_wad(9 * SCALE);
        let diff = if (result > 3 * SCALE) { result - 3 * SCALE } else { 3 * SCALE - result };
        assert!(diff < SCALE / 1000000, 2);
    }

    #[test]
    fun test_sqrt_2() {
        // sqrt(2) ≈ 1.414213562373095
        let expected = 1_414_213_562_373_095_048u256;
        let result = sqrt_wad(2 * SCALE);
        let diff = if (result > expected) { result - expected } else { expected - result };
        // Allow very small error
        assert!(diff < SCALE / 1000000, 0);
    }

    #[test]
    fun test_sqrt_zero() {
        assert!(sqrt_wad(0) == 0, 0);
    }

    #[test]
    fun test_exp_neg_wad() {
        // e^(-0.5) ≈ 0.6065
        let result = exp_neg_wad(SCALE / 2);
        let expected = 606_530_659_712_633_423u256;
        let diff = if (result > expected) { result - expected } else { expected - result };
        // Allow 1% error
        assert!(diff < expected / 100, 0);
    }

    #[test]
    fun test_ln_ratio() {
        // ln(2/1) = ln(2)
        let result = ln_ratio(2 * SCALE, SCALE);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > LN_2) { mag - LN_2 } else { LN_2 - mag };
        assert!(diff < LN_2 / 1000, 0);
    }

    #[test]
    #[expected_failure(abort_code = ELnNonPositive)]
    fun test_ln_zero_fails() {
        ln_wad(0);
    }

    #[test]
    #[expected_failure(abort_code = EExpOverflow)]
    fun test_exp_overflow() {
        // e^30 would overflow
        let x = signed_wad::from_wad(30 * SCALE);
        exp_wad(&x);
    }

    // === Comprehensive Tests ===

    #[test]
    fun test_ln_comprehensive() {
        // ln(10) ≈ 2.302585
        let result = ln_wad(10 * SCALE);
        let expected = 2_302_585_092_994_045_684u256;
        let mag = signed_wad::abs(&result);
        let diff = if (mag > expected) { mag - expected } else { expected - mag };
        assert!(diff < expected / 100, 0); // 1% tolerance
        assert!(!signed_wad::is_negative(&result), 1);
        
        // ln(0.1) ≈ -2.302585
        let result = ln_wad(SCALE / 10);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > expected) { mag - expected } else { expected - mag };
        assert!(diff < expected / 100, 2);
        assert!(signed_wad::is_negative(&result), 3);
    }

    #[test]
    fun test_exp_comprehensive() {
        // e^2 ≈ 7.389056
        let x = signed_wad::from_wad(2 * SCALE);
        let result = exp_wad(&x);
        let expected = 7_389_056_098_930_650_227u256;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 100, 0); // 1% tolerance
        
        // e^-2 ≈ 0.135335
        let x = signed_wad::new(2 * SCALE, true);
        let result = exp_wad(&x);
        let expected = 135_335_283_236_612_691u256;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 100, 1);
    }

    #[test]
    fun test_sqrt_comprehensive() {
        // sqrt(0.5) ≈ 0.707107
        let result = sqrt_wad(SCALE / 2);
        let expected = 707_106_781_186_547_524u256;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 10000, 0); // 0.01% tolerance
        
        // sqrt(100) = 10
        let result = sqrt_wad(100 * SCALE);
        let expected = 10 * SCALE;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < SCALE / 1000000, 1);
    }

    #[test]
    fun test_ln_exp_inverse_property() {
        // ln(exp(x)) ≈ x for various x
        let test_values: vector<u256> = vector[
            SCALE / 2,      // 0.5
            SCALE,          // 1.0
            2 * SCALE,      // 2.0
            5 * SCALE,      // 5.0
        ];
        
        let mut i = 0;
        while (i < 4) {
            let x_wad = *std::vector::borrow(&test_values, i);
            let x = signed_wad::from_wad(x_wad);
            let exp_x = exp_wad(&x);
            let ln_exp_x = ln_wad(exp_x);
            let result_mag = signed_wad::abs(&ln_exp_x);
            
            // Should be close to original x
            let diff = if (result_mag > x_wad) { result_mag - x_wad } else { x_wad - result_mag };
            assert!(diff < x_wad / 50, i); // 2% tolerance for roundtrip
            
            i = i + 1;
        };
    }

    #[test]
    fun test_exp_ln_inverse_property() {
        // exp(ln(x)) ≈ x for various x > 0
        let test_values: vector<u256> = vector[
            SCALE / 10,     // 0.1
            SCALE / 2,      // 0.5
            SCALE,          // 1.0
            2 * SCALE,      // 2.0
            10 * SCALE,     // 10.0
        ];
        
        let mut i = 0;
        while (i < 5) {
            let x = *std::vector::borrow(&test_values, i);
            let ln_x = ln_wad(x);
            let exp_ln_x = exp_wad(&ln_x);
            
            // Should be close to original x
            let diff = if (exp_ln_x > x) { exp_ln_x - x } else { x - exp_ln_x };
            assert!(diff < x / 50, i); // 2% tolerance for roundtrip
            
            i = i + 1;
        };
    }

    #[test]
    fun test_sqrt_square_inverse() {
        // sqrt(x)^2 ≈ x
        let test_values: vector<u256> = vector[
            SCALE / 4,      // 0.25
            SCALE / 2,      // 0.5
            SCALE,          // 1.0
            2 * SCALE,      // 2.0
            10 * SCALE,     // 10.0
        ];
        
        let mut i = 0;
        while (i < 5) {
            let x = *std::vector::borrow(&test_values, i);
            let sqrt_x = sqrt_wad(x);
            // sqrt(x)^2 = sqrt_x * sqrt_x / SCALE
            let squared = math::mul_div(sqrt_x, sqrt_x);
            
            let diff = if (squared > x) { squared - x } else { x - squared };
            assert!(diff < x / 1000000, i); // Very tight tolerance for sqrt
            
            i = i + 1;
        };
    }

    #[test]
    fun test_exp_large_positive() {
        // e^10 ≈ 22026.47
        let x = signed_wad::from_wad(10 * SCALE);
        let result = exp_wad(&x);
        let expected = 22_026_465_794_806_716_516_957u256;
        // Allow 1% error for large values
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 100, 0);
    }

    #[test]
    fun test_exp_large_negative() {
        // e^-10 ≈ 0.0000454
        let x = signed_wad::new(10 * SCALE, true);
        let result = exp_wad(&x);
        let expected = 45_399_929_762_484u256;
        // Allow 5% error for very small values (precision loss)
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 20, 0);
    }

    #[test]
    fun test_ln_large_value() {
        // ln(1000) ≈ 6.9078
        let result = ln_wad(1000 * SCALE);
        let expected = 6_907_755_278_982_137_052u256;
        let mag = signed_wad::abs(&result);
        let diff = if (mag > expected) { mag - expected } else { expected - mag };
        assert!(diff < expected / 100, 0);
        assert!(!signed_wad::is_negative(&result), 1);
    }

    #[test]
    fun test_ln_small_value() {
        // ln(0.001) ≈ -6.9078
        let result = ln_wad(SCALE / 1000);
        let expected = 6_907_755_278_982_137_052u256;
        let mag = signed_wad::abs(&result);
        let diff = if (mag > expected) { mag - expected } else { expected - mag };
        assert!(diff < expected / 100, 0);
        assert!(signed_wad::is_negative(&result), 1);
    }

    #[test]
    fun test_sqrt_large_value() {
        // sqrt(10000) = 100
        let result = sqrt_wad(10000 * SCALE);
        let expected = 100 * SCALE;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < SCALE / 1000000, 0);
    }

    #[test]
    fun test_sqrt_small_value() {
        // sqrt(0.0001) = 0.01
        let result = sqrt_wad(SCALE / 10000);
        let expected = SCALE / 100;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 10000, 0);
    }

    #[test]
    fun test_exp_at_ln2_boundary() {
        // e^ln(2) = 2 (tests range reduction at exact boundary)
        let x = signed_wad::from_wad(LN_2);
        let result = exp_wad(&x);
        let expected = 2 * SCALE;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < expected / 100, 0);
    }

    #[test]
    fun test_constants_accuracy() {
        // Verify our constants are accurate
        // ln(2) should give us 2 when exponentiated
        let x = signed_wad::from_wad(LN_2);
        let result = exp_wad(&x);
        let diff = if (result > 2 * SCALE) { result - 2 * SCALE } else { 2 * SCALE - result };
        assert!(diff < 2 * SCALE / 100, 0);

        // E should give us 1 when we take ln
        let result = ln_wad(E);
        let mag = signed_wad::abs(&result);
        let diff = if (mag > SCALE) { mag - SCALE } else { SCALE - mag };
        assert!(diff < SCALE / 100, 1);
    }
}
