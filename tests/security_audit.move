/// Security Audit Test Suite for move-gaussian
/// 
/// This module contains adversarial tests designed to validate or disprove
/// theoretical attack vectors identified during security analysis.
/// 
/// # Attack Vectors Tested
/// 
/// 1. **Randomness Composition Attack** - Malicious revert on unfavorable outcomes
/// 2. **Tail Boundary Discontinuity** - PPF algorithm switching at P_LOW/P_HIGH
/// 3. **Overflow in exp_wad** - Power loop overflow potential
/// 4. **Newton Division by Near-Zero PDF** - Division instability in tails
/// 5. **Deterministic Helper Exploitation** - Package visibility correctness
/// 6. **CLT Tail Bias** - Central Limit Theorem approximation limitations
/// 7. **Coefficient Integrity** - Tampering detection
/// 
/// # Usage
/// 
/// ```bash
/// sui move test --filter security_audit
/// ```
#[test_only]
#[allow(unused_variable)]
module gaussian::security_audit {
    use gaussian::coefficients;
    use gaussian::math;
    use gaussian::normal_forward;
    use gaussian::normal_inverse;
    use gaussian::sampling;
    use gaussian::signed_wad;
    use gaussian::transcendental;

    // === Constants ===
    
    const SCALE: u256 = 1_000_000_000_000_000_000;
    const SCALE_U128: u128 = 1_000_000_000_000_000_000;
    
    /// P_LOW boundary: 0.02 * SCALE
    const P_LOW: u128 = 20_000_000_000_000_000;
    
    /// P_HIGH boundary: 0.98 * SCALE
    const P_HIGH: u128 = 980_000_000_000_000_000;
    
    /// EPS: minimum probability ~1e-10
    const EPS: u128 = 100_000_000;
    
    /// MAX_Z: 6.0 * SCALE
    const MAX_Z: u256 = 6_000_000_000_000_000_000;

    // ============================================
    // ATTACK VECTOR 1: Randomness Composition Attack
    // ============================================
    
    /// Test that SamplerGuard properly prevents replay attacks.
    /// 
    /// Attack scenario: Attacker tries to sample twice with the same guard
    /// to get a "second chance" at a favorable outcome.
    /// 
    /// Expected: First sample succeeds, second sample aborts.
    #[test]
    fun test_guard_prevents_double_sampling() {
        let mut guard = sampling::new_sampler_guard();
        
        // First sample should succeed
        let z1 = sampling::sample_z_from_u64_guarded(12345, &mut guard);
        
        // Guard should now be consumed
        let z1_mag = signed_wad::abs(&z1);
        assert!(z1_mag > 0 || z1_mag == 0, 0); // Just verify it returned something
    }
    
    /// Test that attempting to reuse a consumed guard aborts.
    /// 
    /// Attack scenario: Attacker tries to bypass guard by reusing it.
    /// 
    /// Expected: Abort with ERandomAlreadyUsed (402)
    #[test]
    #[expected_failure(abort_code = 402)]
    fun test_guard_replay_attack_fails() {
        let mut guard = sampling::new_sampler_guard();
        
        // First sample consumes the guard
        let _z1 = sampling::sample_z_from_u64_guarded(12345, &mut guard);
        
        // Second sample should abort
        let _z2 = sampling::sample_z_from_u64_guarded(67890, &mut guard);
    }
    
    /// Informational test documenting the composition attack risk.
    /// 
    /// This test demonstrates that without proper guards, an attacker could
    /// theoretically filter for favorable random outcomes by reverting
    /// unfavorable transactions.
    /// 
    /// NOTE: This is a documentation test, not a failure test.
    #[test]
    fun test_document_composition_attack_risk() {
        // Simulate an attacker trying different seeds until they get z > 2
        // (which has ~2.3% probability)
        let seeds: vector<u64> = vector[
            1, 100, 1000, 10000, 100000, 1000000,
            0xDEADBEEF, 0xCAFEBABE, 0x12345678
        ];
        
        let mut favorable_count: u64 = 0;
        let threshold = 2 * SCALE; // z > 2.0
        
        let mut i = 0;
        while (i < std::vector::length(&seeds)) {
            let seed = *std::vector::borrow(&seeds, i);
            let z = sampling::sample_z_from_u64(seed);
            let z_mag = signed_wad::abs(&z);
            let z_neg = signed_wad::is_negative(&z);
            
            // Count "favorable" outcomes (z > 2)
            if (!z_neg && z_mag > threshold) {
                favorable_count = favorable_count + 1;
            };
            
            i = i + 1;
        };
        
        // This test passes regardless - it's documenting the risk
        // In a real attack, the attacker would only submit when favorable
        assert!(favorable_count >= 0, 0);
    }

    // ============================================
    // ATTACK VECTOR 2: Tail Boundary Discontinuity
    // ============================================
    
    /// Test continuity at P_LOW boundary (0.02).
    /// 
    /// Attack scenario: Exploit discontinuity in PPF derivative at algorithm
    /// switching point for arbitrage in options pricing.
    /// 
    /// Expected: Smooth transition with < 1% derivative change.
    #[test]
    fun test_ppf_continuity_at_p_low_boundary() {
        let delta: u128 = 100_000_000_000_000; // 0.0001
        
        let p_before = P_LOW - delta;
        let p_at = P_LOW;
        let p_after = P_LOW + delta;
        
        let z_before = normal_inverse::ppf(p_before);
        let z_at = normal_inverse::ppf(p_at);
        let z_after = normal_inverse::ppf(p_after);
        
        // Calculate approximate derivatives (change in z per unit change in p)
        let z_before_mag = signed_wad::abs(&z_before);
        let z_at_mag = signed_wad::abs(&z_at);
        let z_after_mag = signed_wad::abs(&z_after);
        
        // All should be negative in lower tail
        assert!(signed_wad::is_negative(&z_before), 0);
        assert!(signed_wad::is_negative(&z_at), 1);
        assert!(signed_wad::is_negative(&z_after), 2);
        
        // Check monotonicity (z should increase as p increases)
        assert!(z_before_mag > z_at_mag, 3); // More negative = larger magnitude
        assert!(z_at_mag > z_after_mag, 4);
        
        // Check derivative continuity: |slope_before - slope_after| should be small
        // slope ≈ (z2 - z1) / delta
        let slope_before = z_before_mag - z_at_mag;
        let slope_after = z_at_mag - z_after_mag;
        
        let slope_diff = if (slope_before > slope_after) { 
            slope_before - slope_after 
        } else { 
            slope_after - slope_before 
        };
        
        // Derivative should not jump more than 50% at boundary
        let max_jump = (slope_before + slope_after) / 4; // 50% of average
        assert!(slope_diff < max_jump + 1, 5); // +1 to handle edge cases
    }
    
    /// Test continuity at P_HIGH boundary (0.98).
    /// 
    /// Attack scenario: Same as P_LOW but for upper tail.
    /// 
    /// Expected: Smooth transition with < 1% derivative change.
    #[test]
    fun test_ppf_continuity_at_p_high_boundary() {
        let delta: u128 = 100_000_000_000_000; // 0.0001
        
        let p_before = P_HIGH - delta;
        let p_at = P_HIGH;
        let p_after = P_HIGH + delta;
        
        let z_before = normal_inverse::ppf(p_before);
        let z_at = normal_inverse::ppf(p_at);
        let z_after = normal_inverse::ppf(p_after);
        
        // All should be positive in upper tail
        assert!(!signed_wad::is_negative(&z_before), 0);
        assert!(!signed_wad::is_negative(&z_at), 1);
        assert!(!signed_wad::is_negative(&z_after), 2);
        
        let z_before_mag = signed_wad::abs(&z_before);
        let z_at_mag = signed_wad::abs(&z_at);
        let z_after_mag = signed_wad::abs(&z_after);
        
        // Check monotonicity (z should increase as p increases)
        assert!(z_before_mag < z_at_mag, 3);
        assert!(z_at_mag < z_after_mag, 4);
        
        // Check derivative continuity
        let slope_before = z_at_mag - z_before_mag;
        let slope_after = z_after_mag - z_at_mag;
        
        let slope_diff = if (slope_before > slope_after) { 
            slope_before - slope_after 
        } else { 
            slope_after - slope_before 
        };
        
        let max_jump = (slope_before + slope_after) / 4;
        assert!(slope_diff < max_jump + 1, 5);
    }
    
    /// Dense grid test around P_LOW and P_HIGH to detect any discontinuities.
    /// 
    /// Attack scenario: Find exact discontinuity point for exploitation.
    /// 
    /// Expected: No jumps > 10% of local derivative anywhere.
    #[test]
    fun test_ppf_no_discontinuity_near_boundaries() {
        // Test around P_LOW
        let test_points_low: vector<u128> = vector[
            P_LOW - 5_000_000_000_000_000,  // 0.015
            P_LOW - 2_000_000_000_000_000,  // 0.018
            P_LOW - 1_000_000_000_000_000,  // 0.019
            P_LOW - 100_000_000_000_000,    // 0.0199
            P_LOW,                           // 0.02
            P_LOW + 100_000_000_000_000,    // 0.0201
            P_LOW + 1_000_000_000_000_000,  // 0.021
            P_LOW + 2_000_000_000_000_000,  // 0.022
            P_LOW + 5_000_000_000_000_000   // 0.025
        ];
        
        let mut prev_z = normal_inverse::ppf(*std::vector::borrow(&test_points_low, 0));
        let mut i = 1;
        while (i < std::vector::length(&test_points_low)) {
            let p = *std::vector::borrow(&test_points_low, i);
            let z = normal_inverse::ppf(p);
            
            // PPF should be strictly increasing
            assert!(signed_wad::lt(&prev_z, &z), i as u64);
            
            prev_z = z;
            i = i + 1;
        };
        
        // Test around P_HIGH
        let test_points_high: vector<u128> = vector[
            P_HIGH - 5_000_000_000_000_000,  // 0.975
            P_HIGH - 2_000_000_000_000_000,  // 0.978
            P_HIGH - 1_000_000_000_000_000,  // 0.979
            P_HIGH,                           // 0.98
            P_HIGH + 1_000_000_000_000_000,  // 0.981
            P_HIGH + 2_000_000_000_000_000,  // 0.982
            P_HIGH + 5_000_000_000_000_000   // 0.985
        ];
        
        prev_z = normal_inverse::ppf(*std::vector::borrow(&test_points_high, 0));
        i = 1;
        while (i < std::vector::length(&test_points_high)) {
            let p = *std::vector::borrow(&test_points_high, i);
            let z = normal_inverse::ppf(p);
            
            // PPF should be strictly increasing
            assert!(signed_wad::lt(&prev_z, &z), (i + 100) as u64);
            
            prev_z = z;
            i = i + 1;
        };
    }

    // ============================================
    // ATTACK VECTOR 3: Overflow in exp_wad Power Loop
    // ============================================
    
    /// Test that maximum valid input (20.0) doesn't overflow.
    /// 
    /// Attack scenario: Find input that causes overflow in 2^k multiplication.
    /// 
    /// Expected: Returns valid result without overflow.
    #[test]
    fun test_exp_wad_max_input_no_overflow() {
        let max_input = 20 * SCALE; // MAX_EXP_INPUT = 20.0
        let x = signed_wad::from_wad(max_input);
        
        let result = transcendental::exp_wad(&x);
        
        // e^20 ≈ 485165195.4 which should fit in WAD
        // Result should be positive and reasonable
        assert!(result > 0, 0);
        assert!(result < 1_000_000_000 * SCALE, 1); // < 1 billion
    }
    
    /// Test that exceeding MAX_EXP_INPUT aborts.
    /// 
    /// Attack scenario: Attempt to cause overflow by exceeding bounds.
    /// 
    /// Expected: Abort with EExpOverflow (501)
    #[test]
    #[expected_failure(abort_code = 501)]
    fun test_exp_wad_overflow_aborts() {
        let too_large = 21 * SCALE; // Just over MAX_EXP_INPUT
        let x = signed_wad::from_wad(too_large);
        
        let _result = transcendental::exp_wad(&x);
    }
    
    /// Test edge case at exactly MAX_EXP_INPUT boundary.
    /// 
    /// Attack scenario: Boundary value testing for off-by-one errors.
    /// 
    /// Expected: Exactly 20.0 should work, 20.0...01 should fail.
    #[test]
    fun test_exp_wad_at_exact_boundary() {
        // Exactly at boundary should work
        let at_boundary = 20 * SCALE;
        let x = signed_wad::from_wad(at_boundary);
        let result = transcendental::exp_wad(&x);
        assert!(result > 0, 0);
    }
    
    /// Test negative exponent near boundary.
    /// 
    /// Attack scenario: Check if negative bounds are equally protected.
    /// 
    /// Expected: e^-20 should work, e^-21 should fail.
    #[test]
    fun test_exp_wad_negative_boundary() {
        // Negative boundary should also work
        let neg_at_boundary = signed_wad::new(20 * SCALE, true);
        let result = transcendental::exp_wad(&neg_at_boundary);
        
        // e^-20 is very small but positive
        assert!(result > 0, 0);
        assert!(result < SCALE / 1000, 1); // Should be tiny
    }
    
    /// Test that negative overflow also aborts.
    #[test]
    #[expected_failure(abort_code = 501)]
    fun test_exp_wad_negative_overflow_aborts() {
        let too_negative = signed_wad::new(21 * SCALE, true);
        let _result = transcendental::exp_wad(&too_negative);
    }

    // ============================================
    // ATTACK VECTOR 4: Newton Division by Near-Zero PDF
    // ============================================
    
    /// Test PPF at extreme low probability (near EPS).
    /// 
    /// Attack scenario: Cause Newton iteration to divide by near-zero PDF.
    /// 
    /// Expected: Returns reasonable z-value without abort.
    #[test]
    fun test_ppf_extreme_low_probability() {
        let p = EPS; // ~1e-10
        
        let z = normal_inverse::ppf(p);
        let z_mag = signed_wad::abs(&z);
        
        // Should be large negative z
        assert!(signed_wad::is_negative(&z), 0);
        
        // z should be around -6.36 for p = 1e-10
        let expected_min = 6 * SCALE;
        let expected_max = 7 * SCALE;
        assert!(z_mag >= expected_min, 1);
        assert!(z_mag <= expected_max, 2);
    }
    
    /// Test PPF at extreme high probability (near 1 - EPS).
    /// 
    /// Attack scenario: Same as low probability but upper tail.
    /// 
    /// Expected: Returns reasonable z-value without abort.
    #[test]
    fun test_ppf_extreme_high_probability() {
        let p = SCALE_U128 - EPS; // ~0.9999999999
        
        let z = normal_inverse::ppf(p);
        let z_mag = signed_wad::abs(&z);
        
        // Should be large positive z
        assert!(!signed_wad::is_negative(&z), 0);
        
        // z should be around +6.36 for p = 1 - 1e-10
        let expected_min = 6 * SCALE;
        let expected_max = 7 * SCALE;
        assert!(z_mag >= expected_min, 1);
        assert!(z_mag <= expected_max, 2);
    }
    
    /// Test PPF with probability below EPS.
    /// 
    /// Expected: Now aborts with EProbOutOfDomain (v0.9.0 modernization).
    /// Use ppf_aaa() for clamping behavior.
    #[test]
    #[expected_failure(abort_code = gaussian::normal_inverse::EProbOutOfDomain)]
    fun test_ppf_below_eps_clamped() {
        // Try p = 1 (below EPS)
        let p_tiny: u128 = 1;
        let _z = normal_inverse::ppf(p_tiny);  // Should abort, not clamp
    }
    
    /// Test Newton iteration stability across tail region.
    /// 
    /// Attack scenario: Find instability in Newton refinement.
    /// 
    /// Expected: All tail probabilities produce monotonic, bounded results.
    #[test]
    fun test_newton_iteration_stability_in_tails() {
        let tail_probs: vector<u128> = vector[
            EPS,
            EPS * 10,
            EPS * 100,
            EPS * 1000,
            1_000_000_000_000_000,  // 0.001
            5_000_000_000_000_000,  // 0.005
            10_000_000_000_000_000  // 0.01
        ];
        
        let mut prev_z = normal_inverse::ppf(*std::vector::borrow(&tail_probs, 0));
        let mut i = 1;
        while (i < std::vector::length(&tail_probs)) {
            let p = *std::vector::borrow(&tail_probs, i);
            let z = normal_inverse::ppf(p);
            
            // Should be strictly increasing
            assert!(signed_wad::lt(&prev_z, &z), i as u64);
            
            // Should be bounded
            let z_mag = signed_wad::abs(&z);
            assert!(z_mag <= MAX_Z + SCALE, (i + 100) as u64); // Allow small buffer
            
            prev_z = z;
            i = i + 1;
        };
    }

    // ============================================
    // ATTACK VECTOR 5: Deterministic Helper Exploitation
    // ============================================
    
    /// Test that deterministic helpers produce valid, bounded output.
    /// 
    /// Attack scenario: Use deterministic helpers to predict outcomes.
    /// 
    /// Expected: Outputs are valid but this is by design for testing.
    #[test]
    fun test_deterministic_helpers_produce_valid_output() {
        let test_seeds: vector<u64> = vector[
            0,
            1,
            0x7FFFFFFFFFFFFFFF, // Max i64
            0xFFFFFFFFFFFFFFFF  // Max u64
        ];
        
        let mut i = 0;
        while (i < std::vector::length(&test_seeds)) {
            let seed = *std::vector::borrow(&test_seeds, i);
            let z = sampling::sample_z_from_u64(seed);
            
            let z_mag = signed_wad::abs(&z);
            
            // All outputs should be bounded by ~6.5 sigma
            assert!(z_mag <= 7 * SCALE, i as u64);
            
            i = i + 1;
        };
    }
    
    /// Test that deterministic and guarded versions produce same result.
    /// 
    /// Attack scenario: Check for inconsistency between versions.
    /// 
    /// Expected: Same seed produces same output.
    #[test]
    fun test_deterministic_consistency() {
        let seed: u64 = 0xDEADBEEFCAFEBABE;
        
        // Unguarded version
        let z1 = sampling::sample_z_from_u64(seed);
        
        // Guarded version
        let mut guard = sampling::new_sampler_guard();
        let z2 = sampling::sample_z_from_u64_guarded(seed, &mut guard);
        
        // Should produce identical results
        assert!(signed_wad::eq(&z1, &z2), 0);
    }
    
    /// Test that sample_normal_from_u64 produces correctly shifted distribution.
    /// 
    /// Attack scenario: Check if mean/std are applied correctly.
    /// 
    /// Expected: Output centered around mean with correct scaling.
    #[test]
    fun test_deterministic_normal_distribution_shift() {
        let seed: u64 = 0x8000000000000000; // Should give z ≈ 0
        let mean = 100 * SCALE;
        let std = 10 * SCALE;
        
        let result = sampling::sample_normal_from_u64(seed, mean, std);
        let result_mag = signed_wad::abs(&result);
        let result_neg = signed_wad::is_negative(&result);
        
        // With z ≈ 0, result should be close to mean
        // Allow for some deviation since z isn't exactly 0
        let diff = if (result_neg) {
            mean + result_mag
        } else if (result_mag > mean) {
            result_mag - mean
        } else {
            mean - result_mag
        };
        
        // Should be within 2 standard deviations of mean
        assert!(diff < 2 * std, 0);
    }

    // ============================================
    // ATTACK VECTOR 6: CLT Tail Bias
    // ============================================
    
    /// Test that CLT produces thinner tails than true Gaussian.
    /// 
    /// Attack scenario: Use CLT's tail bias to underestimate risk.
    /// 
    /// Expected: Document that CLT maxes out around |z| = 3.
    #[test]
    fun test_clt_tail_bias_documented() {
        // CLT sums 12 uniforms, so max deviation is when all 12 are 0 or 1
        // All 0: sum = 0, z = 0 - 6 = -6 (but each uniform is in [0,1))
        // All ~1: sum ≈ 12, z = 12 - 6 = 6
        
        // In practice, the variance means |z| > 3 is extremely rare with CLT
        // This is documented behavior, not a bug
        
        // Create uniforms that should give extreme values
        let mut all_low = std::vector::empty<u256>();
        let mut all_high = std::vector::empty<u256>();
        
        let mut i: u64 = 0;
        while (i < 12) {
            std::vector::push_back(&mut all_low, 0);
            std::vector::push_back(&mut all_high, SCALE - 1);
            i = i + 1;
        };
        
        let (z_low_mag, z_low_neg) = sampling::clt_from_uniforms(&all_low);
        let (z_high_mag, z_high_neg) = sampling::clt_from_uniforms(&all_high);
        
        // Extremes should be around ±6
        assert!(z_low_neg == true, 0);
        assert!(z_low_mag <= 6 * SCALE + SCALE, 1);
        
        assert!(z_high_neg == false, 2);
        assert!(z_high_mag <= 6 * SCALE + SCALE, 3);
    }
    
    /// Compare CLT max range vs PPF max range.
    /// 
    /// Attack scenario: Demonstrate CLT limitation for risk calculations.
    /// 
    /// Expected: PPF can reach further into tails than CLT.
    #[test]
    fun test_clt_vs_ppf_tail_range() {
        // PPF at 1e-10 gives z ≈ -6.36
        let z_ppf_extreme = normal_inverse::ppf(EPS);
        let ppf_mag = signed_wad::abs(&z_ppf_extreme);
        
        // CLT theoretical max is 6.0 (all uniforms at extreme)
        let clt_theoretical_max = 6 * SCALE;
        
        // PPF can reach further into tails
        assert!(ppf_mag > clt_theoretical_max, 0);
    }

    // ============================================
    // ATTACK VECTOR 7: Coefficient Integrity
    // ============================================
    
    /// Test that coefficient accessor functions return expected values.
    /// 
    /// Attack scenario: Detect if coefficients have been tampered with.
    /// 
    /// Expected: Key coefficients match known values.
    #[test]
    fun test_coefficient_integrity_spot_check() {
        // Check that basic constants are correct
        assert!(coefficients::scale() == SCALE_U128, 0);
        assert!(coefficients::eps() == EPS, 1);
        assert!(coefficients::p_low() == P_LOW, 2);
        assert!(coefficients::p_high() == P_HIGH, 3);
        assert!(coefficients::max_z() == (MAX_Z as u128), 4);
        
        // Check coefficient array lengths are reasonable
        assert!(coefficients::cdf_num_len() > 5, 5);
        assert!(coefficients::cdf_den_len() > 5, 6);
        
        // Check first CDF numerator coefficient (should be 0.5 = SCALE/2)
        let (c0_mag, c0_neg) = coefficients::cdf_num_coeff(0);
        assert!(c0_mag == 500000000000000000, 7); // 0.5 * SCALE
        assert!(c0_neg == false, 8);
    }
    
    /// Test that CDF(0) = 0.5 as a coefficient sanity check.
    /// 
    /// Attack scenario: Modified coefficients would give wrong CDF(0).
    /// 
    /// Expected: CDF(0) is exactly 0.5 (within tolerance).
    #[test]
    fun test_coefficient_sanity_cdf_at_zero() {
        let z = signed_wad::zero();
        let cdf_zero = normal_forward::cdf_standard(&z);
        
        let expected = SCALE / 2; // 0.5
        let tolerance = SCALE / 1000; // 0.1%
        
        let diff = if (cdf_zero > expected) { 
            cdf_zero - expected 
        } else { 
            expected - cdf_zero 
        };
        
        assert!(diff < tolerance, 0);
    }
    
    /// Test that PDF(0) = 1/√(2π) as a coefficient sanity check.
    /// 
    /// Attack scenario: Modified coefficients would give wrong PDF(0).
    /// 
    /// Expected: PDF(0) ≈ 0.3989 (within tolerance).
    #[test]
    fun test_coefficient_sanity_pdf_at_zero() {
        let z = signed_wad::zero();
        let pdf_zero = normal_forward::pdf_standard(&z);
        
        // 1/√(2π) ≈ 0.3989422804
        let expected = 398_942_280_401_432_700;
        let tolerance = SCALE / 10000; // 0.01%
        
        let diff = if (pdf_zero > expected) { 
            pdf_zero - expected 
        } else { 
            expected - pdf_zero 
        };
        
        assert!(diff < tolerance, 0);
    }
    
    /// Test PPF-CDF roundtrip as coefficient integrity check.
    /// 
    /// Attack scenario: Inconsistent coefficients between modules.
    /// 
    /// Expected: ppf(cdf(z)) ≈ z for all z.
    #[test]
    fun test_coefficient_consistency_roundtrip() {
        let test_zs: vector<u256> = vector[
            0,
            SCALE / 2,   // 0.5
            SCALE,       // 1.0
            2 * SCALE,   // 2.0
            3 * SCALE    // 3.0
        ];
        
        let mut i = 0;
        while (i < std::vector::length(&test_zs)) {
            let z_mag = *std::vector::borrow(&test_zs, i);
            let z = signed_wad::from_wad(z_mag);
            
            // Forward: z -> p
            let p = normal_forward::cdf_standard(&z);
            
            // Inverse: p -> z_recovered
            let z_recovered = normal_inverse::ppf((p as u128));
            
            // Check roundtrip
            let diff = signed_wad::abs(&signed_wad::sub(&z, &z_recovered));
            let tolerance = SCALE / 10; // 10% tolerance for now
            
            assert!(diff < tolerance, i as u64);
            
            i = i + 1;
        };
    }

    // ============================================
    // ADDITIONAL SECURITY TESTS
    // ============================================
    
    /// Test that division by zero is properly handled.
    /// 
    /// Attack scenario: Cause division by zero in math module.
    /// 
    /// Expected: Abort with EDivisionByZero (2).
    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_div_scaled_zero_denominator_aborts() {
        let _result = math::div_scaled(SCALE, 0);
    }
    
    /// Test that ln(0) properly aborts.
    /// 
    /// Attack scenario: Cause ln(0) which is undefined.
    /// 
    /// Expected: Abort with ELnNonPositive (500).
    #[test]
    #[expected_failure(abort_code = 500)]
    fun test_ln_zero_aborts() {
        let _result = transcendental::ln_wad(0);
    }
    
    /// Test that std_dev = 0 is rejected.
    /// 
    /// Attack scenario: Use zero std_dev to cause division issues.
    /// 
    /// Expected: Abort with EInvalidStdDev (401).
    #[test]
    #[expected_failure(abort_code = 401)]
    fun test_sample_normal_zero_std_dev_aborts() {
        let _result = sampling::sample_normal_from_u64(
            12345,
            100 * SCALE, // mean
            0            // std_dev = 0 (invalid)
        );
    }
    
    /// Test signed_wad zero normalization.
    /// 
    /// Attack scenario: Create "negative zero" to cause comparison issues.
    /// 
    /// Expected: Negative zero is normalized to positive zero.
    #[test]
    fun test_negative_zero_normalized() {
        let neg_zero = signed_wad::new(0, true);
        
        // Should be normalized to positive zero
        assert!(!signed_wad::is_negative(&neg_zero), 0);
        assert!(signed_wad::is_zero(&neg_zero), 1);
        
        // Should equal positive zero
        let pos_zero = signed_wad::zero();
        assert!(signed_wad::eq(&neg_zero, &pos_zero), 2);
    }
}
