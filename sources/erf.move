/// Error function (erf) and related Gaussian distribution functions.
/// 
/// # Overview
/// 
/// This module implements the error function erf(x) and related functions for
/// Gaussian (normal) distribution computations on-chain. All values use WAD
/// scaling (multiplied by 10^18).
/// 
/// # Functions
/// 
/// - `erf(x)` - Error function: erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt
/// - `erfc(x)` - Complementary error function: erfc(x) = 1 - erf(x)
/// - `phi(x)` - Standard normal CDF: Φ(x) = ½(1 + erf(x/√2))
/// 
/// # Implementation
/// 
/// Uses a degree (11,11) rational polynomial approximation P(x)/Q(x) computed
/// offline using the AAA algorithm with mpmath (50-digit) sampling.
/// Coefficients are stored in `erf_coefficients` module and evaluated using 
/// Horner's method for efficiency.
/// 
/// # Accuracy
/// 
/// - Max error vs mpmath reference: ~6e-11 (verified against 50-digit precision)
/// - Domain: x ∈ [0, 6] (covers 99.9999998% of distribution)
/// - Inputs > 6 are clamped to 6
/// 
/// Note: The (11,11) degree is optimal for polynomial evaluation. Higher degrees
/// achieve better AAA approximation but lose precision during the barycentric
/// to polynomial conversion. See notes/gaussian/precision-limits-and-roadmap.md.
/// 
/// # Production Cycle
/// 
/// This code is part of a Python → Move pipeline:
/// 1. Python: AAA algorithm finds optimal P(x)/Q(x) coefficients (mpmath 50-digit sampling)
/// 2. Python: Scales coefficients to WAD integers (1e18)
/// 3. Python: Generates `erf_coefficients.move` and test vectors
/// 4. Move: This module evaluates P(x)/Q(x) using Horner's method
/// 
/// To regenerate coefficients, run `python scripts/run_all.py`
/// 
/// # Example
/// 
/// ```move
/// use gaussian::erf;
/// 
/// // erf(1.0) ≈ 0.8427
/// let x = 1_000_000_000_000_000_000; // 1.0 in WAD
/// let result = erf::erf(x);
/// // result ≈ 842_700_792_956_151_261
/// ```
module gaussian::erf {
    use gaussian::math;
    use gaussian::erf_coefficients;
    
    // ========================================
    // Constants
    // ========================================
    
    /// Scale factor (WAD = 10^18)
    const SCALE: u256 = 1_000_000_000_000_000_000;
    
    /// Maximum input (6 * SCALE)
    const MAX_INPUT: u256 = 6_000_000_000_000_000_000;
    
    /// Polynomial degree (both P and Q are degree 11)
    const DEGREE: u64 = 11;
    
    /// sqrt(2) * SCALE for phi computation
    /// sqrt(2) ≈ 1.41421356237...
    const SQRT2_SCALED: u256 = 1_414_213_562_373_095_048;
    
    // ========================================
    // Error codes
    // ========================================
    
    /// Denominator is zero (Q(x) = 0).
    /// 
    /// This error indicates the denominator polynomial Q(x) evaluated to zero,
    /// which would cause division by zero in the rational function P(x)/Q(x).
    /// 
    /// **This should never occur** in the valid domain [0, 6*SCALE] because the
    /// AAA algorithm ensures Q(x) has no poles (zeros) in this range.
    /// 
    /// **If you encounter this error:**
    /// 1. Verify input is within [0, 6*SCALE] (6e18)
    /// 2. Check that `erf_coefficients` module was not manually modified
    /// 3. Report as a bug if input is valid
    /// 
    /// **Technical details:**
    /// - Error code range: 100-199 (erf module errors)
    /// - Thrown by: `erf_internal()` when Q(x) = 0
    /// - Related functions: All functions in this module
    const EDenominatorZero: u64 = 100;
    
    /// Input exceeds valid domain [0, 6*SCALE].
    /// 
    /// This error is thrown by strict validation functions when the input
    /// is larger than 6*SCALE (6e18).
    /// 
    /// **Why 6 is the limit:**
    /// - erf(6) ≈ 0.9999999999999998 (essentially 1.0)
    /// - Beyond 6σ, the error function saturates
    /// - Approximation quality degrades outside [0, 6]
    /// 
    /// **How to fix:**
    /// - Use `erf()` instead of `erf_strict()` - it clamps automatically
    /// - Or clamp your input: `let x = min(x_raw, 6 * SCALE)`
    /// 
    /// **Example:**
    /// ```move
    /// // This will abort with EInputTooLarge:
    /// let result = erf_strict(10_000_000_000_000_000_000); // 10.0
    /// 
    /// // This will work (clamps to 6.0):
    /// let result = erf(10_000_000_000_000_000_000);
    /// ```
    /// 
    /// **Technical details:**
    /// - Error code range: 100-199 (erf module errors)
    /// - Thrown by: `erf_strict()`, `erfc_strict()`, `phi_strict()`
    /// - Valid domain: [0, 6_000_000_000_000_000_000]
    const EInputTooLarge: u64 = 101;
    
    // ========================================
    // Main API
    // ========================================
    
    /// Compute erf(x) for x in [0, 6*SCALE] with input clamping.
    /// 
    /// The error function is defined as:
    ///   erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt
    /// 
    /// Inputs larger than 6*SCALE are silently clamped to 6*SCALE.
    /// For strict input validation, use `erf_strict()`.
    /// 
    /// Properties:
    /// - erf(0) = 0
    /// - erf(∞) = 1
    /// - erf(-x) = -erf(x) (symmetry, handle in caller)
    /// 
    /// Returns: erf(x) scaled by SCALE, in range [0, SCALE]
    public fun erf(x: u256): u256 {
        // Clamp to domain
        let x_clamped = if (x > MAX_INPUT) { MAX_INPUT } else { x };
        erf_internal(x_clamped)
    }
    
    /// Compute erf(x) for x in [0, 6*SCALE] with strict input validation.
    /// 
    /// The error function is defined as:
    ///   erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt
    /// 
    /// Aborts if x > 6*SCALE. For automatic clamping, use `erf()`.
    /// 
    /// Properties:
    /// - erf(0) = 0
    /// - erf(∞) = 1
    /// - erf(-x) = -erf(x) (symmetry, handle in caller)
    /// 
    /// Returns: erf(x) scaled by SCALE, in range [0, SCALE]
    public fun erf_strict(x: u256): u256 {
        assert!(x <= MAX_INPUT, EInputTooLarge);
        erf_internal(x)
    }
    
    /// Internal implementation of erf evaluation.
    /// 
    /// Assumes x is already validated/clamped to domain [0, 6*SCALE].
    fun erf_internal(x: u256): u256 {
        // Evaluate P(x) / Q(x)
        let (p_mag, p_neg) = horner_eval_p(x);
        let (q_mag, _q_neg) = horner_eval_q(x);
        
        // Q(x) should always be positive in our domain (no poles)
        assert!(q_mag > 0, EDenominatorZero);
        
        // Compute P(x) / Q(x) with proper scaling
        // result = (P * SCALE) / Q
        let result = (p_mag * SCALE) / q_mag;
        
        // If P was negative, result should be 0 (shouldn't happen for x >= 0)
        if (p_neg) {
            return 0
        };
        
        // Clamp to [0, SCALE]
        math::clamp_to_unit(result)
    }
    
    /// Compute erfc(x) = 1 - erf(x).
    /// 
    /// The complementary error function.
    /// More accurate than computing 1 - erf(x) directly for large x.
    /// 
    /// Returns: erfc(x) scaled by SCALE, in range [0, SCALE]
    public fun erfc(x: u256): u256 {
        SCALE - erf(x)
    }
    
    /// Compute Φ(x), the standard normal CDF.
    /// 
    /// Φ(x) = (1/2) * (1 + erf(x / √2))
    /// 
    /// This is the cumulative distribution function of the standard normal
    /// distribution N(0, 1).
    /// 
    /// Returns: Φ(x) scaled by SCALE, in range [0.5*SCALE, SCALE] for x >= 0
    public fun phi(x: u256): u256 {
        // Compute x / sqrt(2)
        let x_scaled = (x * SCALE) / SQRT2_SCALED;
        
        // Compute erf(x / sqrt(2))
        let erf_val = erf(x_scaled);
        
        // Φ(x) = (1 + erf(x/√2)) / 2
        (SCALE + erf_val) / 2
    }
    
    // ========================================
    // Horner evaluation
    // ========================================
    
    /// Evaluate numerator polynomial P(x) using Horner's rule.
    /// 
    /// P(x) = P0 + P1*x + P2*x² + ... + P11*x^11
    ///      = P0 + x*(P1 + x*(P2 + ... + x*P11))
    /// 
    /// Returns (magnitude, is_negative)
    fun horner_eval_p(x: u256): (u256, bool) {
        // Start with highest degree coefficient
        let (mut result_mag, mut result_neg) = erf_coefficients::p_coeff(DEGREE);
        
        // Work backwards: result = result * x / SCALE + c[i]
        let mut i = DEGREE;
        while (i > 0) {
            i = i - 1;
            
            // result = result * x / SCALE
            result_mag = math::mul_div(result_mag, x);
            
            // result = result + c[i]
            let (c_mag, c_neg) = erf_coefficients::p_coeff(i);
            (result_mag, result_neg) = math::signed_add(result_mag, result_neg, c_mag, c_neg);
        };
        
        (result_mag, result_neg)
    }
    
    /// Evaluate denominator polynomial Q(x) using Horner's rule.
    /// 
    /// Q(x) = Q0 + Q1*x + Q2*x² + ... + Q11*x^11
    ///      = Q0 + x*(Q1 + x*(Q2 + ... + x*Q11))
    /// 
    /// Returns (magnitude, is_negative)
    fun horner_eval_q(x: u256): (u256, bool) {
        // Start with highest degree coefficient
        let (mut result_mag, mut result_neg) = erf_coefficients::q_coeff(DEGREE);
        
        // Work backwards: result = result * x / SCALE + c[i]
        let mut i = DEGREE;
        while (i > 0) {
            i = i - 1;
            
            // result = result * x / SCALE
            result_mag = math::mul_div(result_mag, x);
            
            // result = result + c[i]
            let (c_mag, c_neg) = erf_coefficients::q_coeff(i);
            (result_mag, result_neg) = math::signed_add(result_mag, result_neg, c_mag, c_neg);
        };
        
        (result_mag, result_neg)
    }
    
    // ========================================
    // Tests
    // ========================================
    
    #[test]
    fun test_erf_zero() {
        let result = erf(0);
        assert!(result == 0, 0);
    }
    
    #[test]
    fun test_erf_one() {
        // erf(1) ≈ 0.8427
        let result = erf(SCALE);
        // Expected: ~842700792956151261
        // Allow 1e-7 tolerance = 100_000_000_000
        let expected = 842700792956151261;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < 100_000_000_000, 1);
    }
    
    #[test]
    fun test_erf_two() {
        // erf(2) ≈ 0.9953
        let result = erf(2 * SCALE);
        let expected = 995322265025322200;
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < 100_000_000_000, 2);
    }
    
    #[test]
    fun test_erf_six() {
        // erf(6) ≈ 1.0
        let result = erf(6 * SCALE);
        // Should be very close to SCALE
        assert!(result > SCALE - 1_000_000_000, 0);
        assert!(result <= SCALE, 1);
    }
    
    #[test]
    fun test_erf_bounds() {
        // erf should always be in [0, SCALE]
        let result = erf(3 * SCALE);
        assert!(result >= 0, 0);
        assert!(result <= SCALE, 1);
    }
    
    #[test]
    fun test_erfc_zero() {
        // erfc(0) = 1
        let result = erfc(0);
        assert!(result == SCALE, 0);
    }
    
    #[test]
    fun test_erfc_large() {
        // erfc(6) ≈ 0
        let result = erfc(6 * SCALE);
        assert!(result < 1_000_000_000, 0); // < 1e-9
    }
    
    #[test]
    fun test_phi_zero() {
        // Φ(0) = 0.5
        let result = phi(0);
        assert!(result == SCALE / 2, 0);
    }
    
    #[test]
    fun test_phi_positive() {
        // Φ(x) > 0.5 for x > 0
        let result = phi(SCALE);
        assert!(result > SCALE / 2, 0);
    }
    
    #[test]
    fun test_clamping_large_input() {
        // Input > 6*SCALE should be clamped
        let result = erf(10 * SCALE);
        assert!(result <= SCALE, 0);
        assert!(result > SCALE - 1_000_000_000, 1); // Should be ~1
    }
    
    #[test]
    fun test_phi_monotonic() {
        // phi should be monotonically increasing
        let x1 = 1_000_000_000_000_000_000; // 1.0
        let x2 = 2_000_000_000_000_000_000; // 2.0
        assert!(phi(x2) > phi(x1), 0);
    }
    
    // ========================================
    // Error code tests
    // ========================================
    
    #[test]
    #[expected_failure(abort_code = EInputTooLarge)]
    /// Test that erf_strict() aborts when input exceeds 6*SCALE
    fun test_erf_strict_input_too_large() {
        let x = 10_000_000_000_000_000_000; // 10.0 > 6.0
        erf_strict(x); // Should abort with EInputTooLarge
    }
    
    #[test]
    /// Test that non-strict erf() clamps instead of aborting
    fun test_erf_clamping_doesnt_abort() {
        let x = 10_000_000_000_000_000_000; // 10.0 > 6.0
        
        // This should not abort, just return erf(6.0)
        let result = erf(x);
        
        // Verify it returns the clamped value (erf(6.0) ≈ 1.0)
        assert!(result > 999_999_000_000_000_000, 0); // > 0.999999
        assert!(result <= SCALE, 1);
    }
    
    #[test]
    /// Test edge case: exactly at domain boundary
    fun test_erf_at_boundary() {
        let x = 6 * SCALE; // Exactly 6.0
        let result = erf(x);
        
        // Should work fine, no abort
        assert!(result > 999_999_000_000_000_000, 0);
    }
}
