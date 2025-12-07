module gaussian::sampling {
    use gaussian::math;
    use gaussian::signed_wad::{Self, SignedWad};
    use gaussian::normal_inverse;
    use gaussian::events;
    use sui::random;

    /// Standard normal sample stored as a SignedWad value.
    /// magnitude / SCALE is |z|, negative indicates sign.
    public struct StandardNormal has copy, drop, store {
        value: SignedWad,
    }

    // ========================================
    // Constants
    // ========================================

    /// Invalid std_dev input
    const EInvalidStdDev: u64 = 401;

    /// Guard has already been used for sampling (replay attempt).
    const ERandomAlreadyUsed: u64 = 402;

    /// Number of independent uniform samples used in CLT approximation.
    /// For n = 12, the sum of n U(0,1) variables has variance n/12 = 1,
    /// so Z = (Σ U_i) - 6 is approximately N(0, 1).
    const NUM_UNIFORMS: u64 = 12;

    /// 2^64 as u256, used to map a u64 into a WAD-scaled uniform in [0, 1).
    const TWO_POW_64: u256 = 18_446_744_073_709_551_616;

    /// Scale factor: WAD = 10^18
    const SCALE: u128 = 1_000_000_000_000_000_000;

    /// Minimum probability for PPF (avoids singularity): ~1e-10 * WAD
    const EPS: u128 = 100_000_000;

    // ========================================
    // Replay guard (one-shot sampler)
    // ========================================

    /// Guard to enforce single-use sampling when callers want to prevent reuse of a randomness handle.
    public struct SamplerGuard has store, drop {
        used: bool,
    }

    /// Create a fresh sampler guard.
    public fun new_sampler_guard(): SamplerGuard {
        SamplerGuard { used: false }
    }

    fun mark_guard_consumed(guard: &mut SamplerGuard) {
        assert!(!guard.used, ERandomAlreadyUsed);
        guard.used = true;
    }

    // ========================================
    // Uniform generation helpers
    // ========================================

    /// Convert a raw u64 into a WAD-scaled uniform in [0, 1).
    public(package) fun uniform_from_u64(u: u64): u256 {
        let scale = math::scale();
        ((u as u256) * scale) / TWO_POW_64
    }

    /// Map u64 → WAD in open interval (EPS, SCALE-EPS).
    /// Critical for PPF: avoids singularities at 0 and 1.
    /// Uses multiply-before-divide to preserve precision.
    public(package) fun uniform_open_interval_from_u64(u: u64): u128 {
        let scale = SCALE;
        let span = scale - 2 * EPS;
        
        // (u / 2^64) * span + EPS
        // Multiply first to preserve bits
        let num = (u as u128) * span;
        let frac = num >> 64; // equivalent to / 2^64
        frac + EPS
    }

    // ========================================
    // CLT-based sampling (original implementation)
    // ========================================

    /// Core CLT-based standard normal sampler given pre-generated uniforms.
    ///
    /// Each entry in `uniforms` must be WAD-scaled and lie in [0, SCALE].
    /// The result is (magnitude, negative) for
    ///   Z ≈ Σ U_i - 6 ,  U_i ~ Uniform(0,1), i=1..12
    /// which is approximately N(0, 1).
    public fun clt_from_uniforms(uniforms: &vector<u256>): (u256, bool) {
        let n = std::vector::length(uniforms);
        assert!(n == NUM_UNIFORMS, 0);

        let mut sum: u256 = 0;
        let mut i: u64 = 0;
        while (i < NUM_UNIFORMS) {
            sum = sum + *std::vector::borrow(uniforms, i);
            i = i + 1;
        };

        // Mean of 12 uniforms is 6.0
        let mean_scaled = 6 * math::scale();

        if (sum >= mean_scaled) {
            (sum - mean_scaled, false)
        } else {
            (mean_scaled - sum, true)
        }
    }

    fun sample_standard_normal_clt_with_gen(
        gen: &mut random::RandomGenerator
    ): (u256, bool) {
        let mut uniforms = std::vector::empty<u256>();

        let mut i: u64 = 0;
        while (i < NUM_UNIFORMS) {
            let raw = random::generate_u64(gen);
            let u_wad = uniform_from_u64(raw);
            std::vector::push_back(&mut uniforms, u_wad);
            i = i + 1;
        };

        clt_from_uniforms(&uniforms)
    }

    /// Sample an approximately standard normal variable using CLT:
    ///   Z ≈ Σ U_i - 6 ,  U_i ~ Uniform(0,1), i=1..12
    ///
    /// Returns (magnitude, negative) in WAD scaling.
    /// Emits a GaussianSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_standard_normal_clt(
        r: &random::Random,
        ctx: &mut sui::tx_context::TxContext,
    ): (u256, bool) {
        let mut gen = random::new_generator(r, ctx);
        let (z_mag, z_neg) = sample_standard_normal_clt_with_gen(&mut gen);
        
        // Emit event
        events::emit_gaussian_sample(z_mag, z_neg, sui::tx_context::sender(ctx));
        
        (z_mag, z_neg)
    }

    /// Sample from N(mean, std_dev^2) using CLT-based standard normal sampler.
    ///
    /// - `mean` and `std_dev` are WAD-scaled.
    /// - Returns (magnitude, negative) representing the sampled value in WAD.
    /// - Emits a NormalSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_normal_clt(
        r: &random::Random,
        mean: u256,
        std_dev: u256,
        ctx: &mut sui::tx_context::TxContext,
    ): (u256, bool) {
        assert!(std_dev > 0, EInvalidStdDev);
        let mut gen = random::new_generator(r, ctx);
        let (z_mag, z_neg) = sample_standard_normal_clt_with_gen(&mut gen);

        // delta = std_dev * z / SCALE
        let delta = math::mul_div(std_dev, z_mag);

        let (value_mag, value_neg) = if (!z_neg) {
            (mean + delta, false)
        } else {
            if (mean >= delta) {
                (mean - delta, false)
            } else {
                // Magnitude exceeds mean; result is negative
                (delta - mean, true)
            }
        };

        // Emit event
        events::emit_normal_sample(
            z_mag, z_neg,
            mean, std_dev,
            value_mag, value_neg,
            sui::tx_context::sender(ctx)
        );

        (value_mag, value_neg)
    }

    // ========================================
    // PPF-based sampling (new implementation)
    // ========================================

    /// Sample standard normal using PPF (inverse CDF) method.
    /// 
    /// This is more accurate than CLT for the tails of the distribution.
    /// Uses the relationship: if U ~ Uniform(0,1), then Φ⁻¹(U) ~ N(0,1).
    /// 
    /// Returns a SignedWad sample.
    fun sample_standard_normal_ppf_internal(
        r: &random::Random,
        ctx: &mut sui::tx_context::TxContext,
    ): SignedWad {
        let mut gen = random::new_generator(r, ctx);
        let raw = random::generate_u64(&mut gen);
        
        // Map to open interval (EPS, SCALE-EPS)
        let p = uniform_open_interval_from_u64(raw);
        
        // Apply inverse CDF (PPF)
        let z = normal_inverse::ppf(p);

        // Fallback to CLT if an unexpected zero emerges in tail-heavy draws.
        let z_mag = signed_wad::abs(&z);
        let is_tail = p < (SCALE / 4) || p > (3 * SCALE / 4);
        if (is_tail && z_mag == 0) {
            let (mag, neg) = sample_standard_normal_clt_with_gen(&mut gen);
            return signed_wad::new(mag, neg)
        };

        z
    }

    /// Deterministic helper for tests/integration: map a raw u64 to SignedWad z via PPF.
    /// Mirrors `sample_standard_normal_ppf_internal` without requiring Random/TxContext.
    public(package) fun sample_z_from_u64(raw: u64): SignedWad {
        let p = uniform_open_interval_from_u64(raw);
        normal_inverse::ppf(p)
    }

    /// Deterministic helper with guard: map a raw u64 to SignedWad z via PPF.
    /// Used to test replay protection without needing `Random`.
    public(package) fun sample_z_from_u64_guarded(raw: u64, guard: &mut SamplerGuard): SignedWad {
        mark_guard_consumed(guard);
        sample_z_from_u64(raw)
    }

    /// Deterministic helper: sample N(mean, std_dev^2) from a raw u64 without Random.
    public(package) fun sample_normal_from_u64(
        raw: u64,
        mean: u256,
        std_dev: u256,
    ): SignedWad {
        assert!(std_dev > 0, EInvalidStdDev);
        let z = sample_z_from_u64(raw);
        let delta = signed_wad::mul_wad(&z, std_dev);
        let mean_signed = signed_wad::from_wad(mean);
        signed_wad::add(&mean_signed, &delta)
    }

    /// Deterministic helper with guard: sample N(mean, std_dev^2) from a raw u64 with replay protection.
    public(package) fun sample_normal_from_u64_guarded(
        raw: u64,
        mean: u256,
        std_dev: u256,
        guard: &mut SamplerGuard,
    ): SignedWad {
        assert!(std_dev > 0, EInvalidStdDev);
        mark_guard_consumed(guard);
        sample_normal_from_u64(raw, mean, std_dev)
    }

    /// Sample from N(mean, std_dev^2) using PPF-based standard normal sampler.
    ///
    /// - `mean` and `std_dev` are WAD-scaled.
    /// - Returns (z, value) where z is the standard normal and value = mean + std_dev * z.
    fun sample_normal_ppf_internal_with_z(
        r: &random::Random,
        mean: u256,
        std_dev: u256,
        ctx: &mut sui::tx_context::TxContext,
    ): (SignedWad, SignedWad) {
        assert!(std_dev > 0, EInvalidStdDev);
        let z = sample_standard_normal_ppf_internal(r, ctx);
        let delta = signed_wad::mul_wad(&z, std_dev);
        let mean_signed = signed_wad::from_wad(mean);
        let value = signed_wad::add(&mean_signed, &delta);
        (z, value)
    }

    // ========================================
    // Public API
    // ========================================

    /// Direct SignedWad standard normal sample ("sample_z" helper).
    /// Emits a GaussianSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_z(
        r: &random::Random,
        ctx: &mut sui::tx_context::TxContext,
    ): SignedWad {
        let z = sample_standard_normal_ppf_internal(r, ctx);
        
        // Emit event
        events::emit_gaussian_sample(
            signed_wad::abs(&z),
            signed_wad::is_negative(&z),
            sui::tx_context::sender(ctx)
        );
        
        z
    }

    /// One-shot standard normal sample that consumes the provided guard to block reuse.
    /// Emits a GaussianSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_z_once(
        r: &random::Random,
        guard: &mut SamplerGuard,
        ctx: &mut sui::tx_context::TxContext,
    ): SignedWad {
        mark_guard_consumed(guard);
        let z = sample_standard_normal_ppf_internal(r, ctx);
        
        // Emit event
        events::emit_gaussian_sample(
            signed_wad::abs(&z),
            signed_wad::is_negative(&z),
            sui::tx_context::sender(ctx)
        );
        
        z
    }

    /// Ergonomic wrapper returning a StandardNormal sample.
    /// Emits a GaussianSampleEvent.
    ///
    /// **Implementation**: Currently uses PPF-based sampling for better
    /// accuracy, especially in the tails. Falls back to CLT if needed.
    ///
    /// Internal implementation may change in future versions without
    /// affecting the public API.
    #[allow(lint(public_random))]
    public fun sample_standard_normal(
        r: &random::Random,
        ctx: &mut sui::tx_context::TxContext,
    ): StandardNormal {
        // Use PPF-based sampling (more accurate)
        let value = sample_standard_normal_ppf_internal(r, ctx);
        
        // Emit event
        events::emit_gaussian_sample(
            signed_wad::abs(&value),
            signed_wad::is_negative(&value),
            sui::tx_context::sender(ctx)
        );
        
        StandardNormal { value }
    }

    /// Ergonomic wrapper for N(mean, std_dev^2) returning a StandardNormal.
    /// Emits a NormalSampleEvent.
    ///
    /// **Implementation**: Uses PPF-based sampling internally.
    #[allow(lint(public_random))]
    public fun sample_normal(
        r: &random::Random,
        mean: u256,
        std_dev: u256,
        ctx: &mut sui::tx_context::TxContext,
    ): StandardNormal {
        let (z, value) = sample_normal_ppf_internal_with_z(r, mean, std_dev, ctx);
        
        // Emit event
        events::emit_normal_sample(
            signed_wad::abs(&z),
            signed_wad::is_negative(&z),
            mean, std_dev,
            signed_wad::abs(&value),
            signed_wad::is_negative(&value),
            sui::tx_context::sender(ctx)
        );
        
        StandardNormal { value }
    }

    /// One-shot N(mean, std_dev^2) sample that consumes the provided guard to block reuse.
    /// Emits a NormalSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_normal_once(
        r: &random::Random,
        mean: u256,
        std_dev: u256,
        guard: &mut SamplerGuard,
        ctx: &mut sui::tx_context::TxContext,
    ): StandardNormal {
        assert!(std_dev > 0, EInvalidStdDev);
        mark_guard_consumed(guard);
        let (z, value) = sample_normal_ppf_internal_with_z(r, mean, std_dev, ctx);
        
        // Emit event
        events::emit_normal_sample(
            signed_wad::abs(&z),
            signed_wad::is_negative(&z),
            mean, std_dev,
            signed_wad::abs(&value),
            signed_wad::is_negative(&value),
            sui::tx_context::sender(ctx)
        );
        
        StandardNormal { value }
    }

    // ========================================
    // StandardNormal accessors
    // ========================================

    /// Get the magnitude (absolute value) of a StandardNormal sample.
    public fun magnitude(sn: &StandardNormal): u256 {
        signed_wad::abs(&sn.value)
    }

    /// Check if a StandardNormal sample is negative.
    public fun is_negative(sn: &StandardNormal): bool {
        signed_wad::is_negative(&sn.value)
    }

    /// Convert StandardNormal to SignedWad for use with other Gaussian functions.
    public fun to_signed_wad(sn: &StandardNormal): SignedWad {
        sn.value
    }

    /// Create StandardNormal from SignedWad.
    public fun from_signed_wad(sw: &SignedWad): StandardNormal {
        StandardNormal { value: *sw }
    }

    // ========================================
    // Tests
    // ========================================

    #[test]
    fun test_clt_zero_when_all_half() {
        let mut uniforms = std::vector::empty<u256>();
        let half = math::scale() / 2;

        let mut i: u64 = 0;
        while (i < NUM_UNIFORMS) {
            std::vector::push_back(&mut uniforms, half);
            i = i + 1;
        };

        let (z_mag, z_neg) = clt_from_uniforms(&uniforms);
        assert!(z_mag == 0, 0);
        assert!(z_neg == false, 1);
    }

    #[test]
    fun test_clt_positive_when_uniforms_high() {
        let mut uniforms = std::vector::empty<u256>();
        let three_quarters = (math::scale() * 3) / 4;

        let mut i: u64 = 0;
        while (i < NUM_UNIFORMS) {
            std::vector::push_back(&mut uniforms, three_quarters);
            i = i + 1;
        };

        let (z_mag, z_neg) = clt_from_uniforms(&uniforms);
        assert!(z_mag > 0, 0);
        assert!(!z_neg, 1);
    }

    #[test]
    fun test_clt_negative_when_uniforms_low() {
        let mut uniforms = std::vector::empty<u256>();
        let quarter = math::scale() / 4;

        let mut i: u64 = 0;
        while (i < NUM_UNIFORMS) {
            std::vector::push_back(&mut uniforms, quarter);
            i = i + 1;
        };

        let (z_mag, z_neg) = clt_from_uniforms(&uniforms);
        assert!(z_mag > 0, 0);
        assert!(z_neg, 1);
    }

    #[test]
    fun test_uniform_open_interval() {
        // Test boundary values
        let low = uniform_open_interval_from_u64(0);
        let high = uniform_open_interval_from_u64(0xFFFFFFFFFFFFFFFF);
        
        // Should be within (EPS, SCALE-EPS)
        assert!(low >= EPS, 0);
        assert!(high <= SCALE - EPS, 1);
        assert!(low < high, 2);
    }

    #[test]
    fun test_uniform_open_interval_midpoint() {
        // Midpoint of u64 range should map to approximately SCALE/2
        let mid = uniform_open_interval_from_u64(0x8000000000000000);
        
        // Should be roughly SCALE/2
        let half_scale = SCALE / 2;
        let tolerance = SCALE / 100; // 1% tolerance
        
        let diff = if (mid > half_scale) { mid - half_scale } else { half_scale - mid };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_standard_normal_to_signed_wad() {
        let sn = StandardNormal { value: signed_wad::new(1_000_000_000_000_000_000, true) };
        let sw = to_signed_wad(&sn);
        
        assert!(signed_wad::abs(&sw) == 1_000_000_000_000_000_000, 0);
        assert!(signed_wad::is_negative(&sw) == true, 1);
    }

    #[test]
    fun test_signed_wad_to_standard_normal() {
        let sw = signed_wad::new(2_000_000_000_000_000_000, false);
        let sn = from_signed_wad(&sw);
        
        assert!(magnitude(&sn) == 2_000_000_000_000_000_000, 0);
        assert!(!is_negative(&sn), 1);
    }

    #[test]
    fun test_sampler_guard_allows_single_use() {
        let mut guard = new_sampler_guard();
        let z = sample_z_from_u64_guarded(0x8000000000000000, &mut guard);
        assert!(signed_wad::abs(&z) > 0, 0);
    }

    #[test]
    #[expected_failure(abort_code = ERandomAlreadyUsed)]
    fun test_sampler_guard_blocks_reuse() {
        let mut guard = new_sampler_guard();
        let _ = sample_z_from_u64_guarded(1, &mut guard);
        let _ = sample_z_from_u64_guarded(2, &mut guard);
    }
}
