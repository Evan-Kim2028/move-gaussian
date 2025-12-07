/// Standard normal CDF and PDF using AAA-based rational approximations.
/// 
/// # Overview
/// 
/// This module provides:
/// - `cdf_standard(z)` - Standard normal CDF Φ(z)
/// - `pdf_standard(z)` - Standard normal PDF φ(z)
/// 
/// Both functions accept SignedWad inputs and handle the full domain [-6, 6].
/// Values outside this range are clamped (CDF to 0/1, PDF to 0).
/// 
/// # Implementation
/// 
/// Uses Horner's method to evaluate rational polynomials P(z)/Q(z) where
/// coefficients are sourced from `gaussian::coefficients`.
/// 
/// Symmetry properties:
/// - CDF: Φ(-z) = 1 - Φ(z)
/// - PDF: φ(-z) = φ(z)
/// 
/// # Precision
/// 
/// Target error: < 1e-9 (better than solgauss)
/// Domain: z ∈ [-6, 6] (covers 99.9999998% of the distribution)
module gaussian::normal_forward {
    use gaussian::coefficients;
    use gaussian::math;
    use gaussian::signed_wad::{Self, SignedWad};

    // === Constants ===

    /// Scale factor: WAD = 10^18
    const SCALE: u256 = 1_000_000_000_000_000_000;

    /// Maximum |z| value: 6.0 * WAD
    const MAX_Z: u256 = 6_000_000_000_000_000_000;

    /// Precomputed 1/√(2π) in WAD: 0.3989422804014327 * 1e18
    /// Used for PDF normalization check
    const INV_SQRT_2PI_WAD: u256 = 398942280401432700;

    // === Errors ===

    /// Denominator evaluated to zero (should not happen with valid coefficients)
    const EDenominatorZero: u64 = 200;

    // === Internal Horner Evaluation ===

    /// Evaluate CDF numerator polynomial P(z) using Horner's method.
    /// 
    /// P(z) = P0 + z*(P1 + z*(P2 + ... + z*Pn))
    /// 
    /// Returns (magnitude, is_negative) for the result.
    fun horner_eval_cdf_num(z: u256): (u256, bool) {
        let n = coefficients::cdf_num_len();
        
        // Start from highest degree coefficient
        let mut i = n;
        let (mut acc_mag, mut acc_neg) = (0u256, false);
        
        while (i > 0) {
            i = i - 1;
            
            // acc = acc * z / SCALE
            let scaled_acc = math::mul_div(acc_mag, z);
            
            // Get coefficient at index i
            let (coeff_mag, coeff_neg) = coefficients::cdf_num_coeff(i);
            let coeff_mag_256 = (coeff_mag as u256);
            
            // acc = acc + coeff (signed addition)
            (acc_mag, acc_neg) = math::signed_add(scaled_acc, acc_neg, coeff_mag_256, coeff_neg);
        };
        
        (acc_mag, acc_neg)
    }

    /// Evaluate CDF denominator polynomial Q(z) using Horner's method.
    fun horner_eval_cdf_den(z: u256): (u256, bool) {
        let n = coefficients::cdf_den_len();
        
        let mut i = n;
        let (mut acc_mag, mut acc_neg) = (0u256, false);
        
        while (i > 0) {
            i = i - 1;
            
            let scaled_acc = math::mul_div(acc_mag, z);
            let (coeff_mag, coeff_neg) = coefficients::cdf_den_coeff(i);
            let coeff_mag_256 = (coeff_mag as u256);
            
            (acc_mag, acc_neg) = math::signed_add(scaled_acc, acc_neg, coeff_mag_256, coeff_neg);
        };
        
        (acc_mag, acc_neg)
    }

    /// Compute P(z)/Q(z) for the CDF rational approximation.
    /// 
    /// Both P and Q may have signed intermediate values, but the final
    /// ratio for CDF should be in [0, 1].
    fun eval_cdf_rational(z: u256): u256 {
        let (p_mag, p_neg) = horner_eval_cdf_num(z);
        let (q_mag, q_neg) = horner_eval_cdf_den(z);
        
        // Q should never be zero for valid inputs
        assert!(q_mag > 0, EDenominatorZero);
        
        // Compute |P| / |Q| * SCALE
        let ratio = math::div_scaled(p_mag, q_mag);
        
        // Determine sign of result
        let result_neg = p_neg != q_neg;
        
        // CDF should be positive; clamp negative values to 0
        if (result_neg) {
            0
        } else {
            // Clamp to [0, SCALE]
            math::clamp_to_unit(ratio)
        }
    }

    fun horner_eval_pdf_num(z: u256): (u256, bool) {
        let n = coefficients::pdf_num_len();
        let mut i = n;
        let (mut acc_mag, mut acc_neg) = (0u256, false);
        while (i > 0) {
            i = i - 1;
            let scaled_acc = math::mul_div(acc_mag, z);
            let (coeff_mag, coeff_neg) = coefficients::pdf_num_coeff(i);
            let coeff_mag_256 = (coeff_mag as u256);
            (acc_mag, acc_neg) = math::signed_add(scaled_acc, acc_neg, coeff_mag_256, coeff_neg);
        };
        (acc_mag, acc_neg)
    }

    fun horner_eval_pdf_den(z: u256): (u256, bool) {
        let n = coefficients::pdf_den_len();
        let mut i = n;
        let (mut acc_mag, mut acc_neg) = (0u256, false);
        while (i > 0) {
            i = i - 1;
            let scaled_acc = math::mul_div(acc_mag, z);
            let (coeff_mag, coeff_neg) = coefficients::pdf_den_coeff(i);
            let coeff_mag_256 = (coeff_mag as u256);
            (acc_mag, acc_neg) = math::signed_add(scaled_acc, acc_neg, coeff_mag_256, coeff_neg);
        };
        (acc_mag, acc_neg)
    }

    fun eval_pdf_rational(z: u256): u256 {
        let (p_mag, p_neg) = horner_eval_pdf_num(z);
        let (q_mag, q_neg) = horner_eval_pdf_den(z);
        assert!(q_mag > 0, EDenominatorZero);
        let ratio = math::div_scaled(p_mag, q_mag);
        let result_neg = p_neg != q_neg;
        if (result_neg) { 0 } else { ratio }
    }

    // === Public API ===

    /// Standard normal CDF: Φ(z) = P(Z ≤ z) where Z ~ N(0, 1).
    ///
    /// # Arguments
    /// * `z` - z-score as SignedWad (WAD-scaled)
    ///
    /// # Returns
    /// * `u256` - Probability in [0, SCALE] (WAD-scaled)
    ///
    /// # Domain Handling
    /// * z < -6: returns ~0
    /// * z = 0: returns SCALE/2 (0.5)
    /// * z > 6: returns ~SCALE (1.0)
    ///
    /// # Symmetry
    /// Uses Φ(-z) = 1 - Φ(z) for negative inputs.
    ///
    /// # Example
    /// ```move
    /// let z = signed_wad::from_wad(1_000_000_000_000_000_000); // z = 1.0
    /// let prob = cdf_standard(&z);
    /// // prob ≈ 841_344_746_068_543_000 (~0.8413)
    /// ```
    public fun cdf_standard(z: &SignedWad): u256 {
        let z_mag = signed_wad::abs(z);
        let z_neg = signed_wad::is_negative(z);
        
        // Clamp magnitude to MAX_Z
        let z_clamped = if (z_mag > MAX_Z) { MAX_Z } else { z_mag };
        
        // Evaluate rational approximation for |z|
        let phi_abs_z = eval_cdf_rational(z_clamped);
        
        // Apply symmetry: Φ(-z) = 1 - Φ(z)
        if (z_neg) {
            SCALE - phi_abs_z
        } else {
            phi_abs_z
        }
    }

    /// Standard normal PDF: φ(z) = probability density at z for Z ~ N(0, 1).
    ///
    /// # Arguments
    /// * `z` - z-score as SignedWad (WAD-scaled)
    ///
    /// # Returns
    /// * `u256` - Density value (WAD-scaled, non-negative)
    ///
    /// # Properties
    /// * φ(0) ≈ 0.3989 × SCALE (maximum at z=0, equals 1/√(2π))
    /// * φ(-z) = φ(z) (symmetric)
    /// * φ(|z| > 6) ≈ 0 (effectively zero in tails)
    ///
    /// # Example
    /// ```move
    /// let z = signed_wad::zero();
    /// let density = pdf_standard(&z);
    /// // density ≈ 398_942_280_401_432_700 (~0.3989)
    /// ```
    public fun pdf_standard(z: &SignedWad): u256 {
        let z_mag = signed_wad::abs(z);
        if (z_mag > MAX_Z) {
            0
        } else {
            eval_pdf_rational(z_mag)
        }
    }

    /// Get the precomputed 1/√(2π) constant for validation.
    public fun inv_sqrt_2pi(): u256 {
        INV_SQRT_2PI_WAD
    }

    // === Tests ===

    #[test]
    fun test_cdf_at_zero() {
        // Φ(0) = 0.5
        let z = signed_wad::zero();
        let result = cdf_standard(&z);
        
        let expected = SCALE / 2; // 0.5 * WAD
        let tolerance = SCALE / 100; // 1% tolerance
        
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_cdf_positive() {
        // Φ(1) ≈ 0.8413
        let z = signed_wad::from_wad(SCALE); // z = 1.0
        let result = cdf_standard(&z);
        
        // Should be greater than 0.5
        assert!(result > SCALE / 2, 0);
        // Should be less than 1
        assert!(result < SCALE, 1);
        
        // Rough check: 0.8 < Φ(1) < 0.9
        assert!(result > 8 * SCALE / 10, 2);
        assert!(result < 9 * SCALE / 10, 3);
    }

    #[test]
    fun test_cdf_negative() {
        // Φ(-1) ≈ 0.1587 = 1 - Φ(1)
        let z = signed_wad::new(SCALE, true); // z = -1.0
        let result = cdf_standard(&z);
        
        // Should be less than 0.5
        assert!(result < SCALE / 2, 0);
        // Should be greater than 0
        assert!(result > 0, 1);
        
        // Rough check: 0.1 < Φ(-1) < 0.2
        assert!(result > SCALE / 10, 2);
        assert!(result < 2 * SCALE / 10, 3);
    }

    #[test]
    fun test_cdf_symmetry() {
        // Φ(-z) + Φ(z) = 1
        let z_pos = signed_wad::from_wad(SCALE); // z = 1.0
        let z_neg = signed_wad::new(SCALE, true); // z = -1.0
        
        let phi_pos = cdf_standard(&z_pos);
        let phi_neg = cdf_standard(&z_neg);
        
        let sum = phi_pos + phi_neg;
        let tolerance = SCALE / 1000; // 0.1% tolerance
        
        let diff = if (sum > SCALE) { sum - SCALE } else { SCALE - sum };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_cdf_extreme_positive() {
        // Φ(6) ≈ 1.0 (very close to 1)
        let z = signed_wad::from_wad(6 * SCALE); // z = 6.0
        let result = cdf_standard(&z);
        
        // Should be very close to SCALE
        assert!(result > 99 * SCALE / 100, 0); // > 0.99
    }

    #[test]
    fun test_cdf_extreme_negative() {
        // Φ(-6) ≈ 0.0 (very close to 0)
        let z = signed_wad::new(6 * SCALE, true); // z = -6.0
        let result = cdf_standard(&z);
        
        // Should be very close to 0
        assert!(result < SCALE / 100, 0); // < 0.01
    }

    #[test]
    fun test_cdf_clamping_large_positive() {
        // z > 6 should be treated as z = 6
        let z = signed_wad::from_wad(10 * SCALE); // z = 10.0
        let result = cdf_standard(&z);
        
        // Should be essentially 1
        assert!(result > 99 * SCALE / 100, 0);
    }

    #[test]
    fun test_cdf_clamping_large_negative() {
        // z < -6 should be treated as z = -6
        let z = signed_wad::new(10 * SCALE, true); // z = -10.0
        let result = cdf_standard(&z);
        
        // Should be essentially 0
        assert!(result < SCALE / 100, 0);
    }

    #[test]
    fun test_pdf_at_zero() {
        let z = signed_wad::zero();
        let result = pdf_standard(&z);
        let expected = INV_SQRT_2PI_WAD;
        let tolerance = SCALE / 100000; // 1e-5 tolerance
        let diff = if (result > expected) { result - expected } else { expected - result };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_pdf_symmetry() {
        let z_pos = signed_wad::from_wad(SCALE);
        let z_neg = signed_wad::new(SCALE, true);
        let pdf_pos = pdf_standard(&z_pos);
        let pdf_neg = pdf_standard(&z_neg);
        let tolerance = SCALE / 10000; // 0.01%
        let diff = if (pdf_pos > pdf_neg) { pdf_pos - pdf_neg } else { pdf_neg - pdf_pos };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_pdf_decreases_from_zero() {
        // PDF should decrease as |z| increases
        let z0 = signed_wad::zero();
        let z1 = signed_wad::from_wad(SCALE);
        let z2 = signed_wad::from_wad(2 * SCALE);
        
        let pdf0 = pdf_standard(&z0);
        let pdf1 = pdf_standard(&z1);
        let pdf2 = pdf_standard(&z2);
        
        assert!(pdf0 > pdf1, 0);
        assert!(pdf1 > pdf2, 1);
    }

    #[test]
    fun test_pdf_at_extreme() {
        let z = signed_wad::from_wad(6 * SCALE);
        let result = pdf_standard(&z);
        assert!(result < SCALE / 1000000, 0);
    }
}
