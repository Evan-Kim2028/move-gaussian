/// Core facade module providing a single import point for the Gaussian library.
/// 
/// # Overview
/// 
/// This module re-exports the most commonly used functions from the Gaussian
/// library with shorter, ergonomic names. Instead of importing from multiple
/// modules, developers can use:
/// 
/// ```move
/// use gaussian::core::{sample_z, cdf, pdf, ppf};
/// ```
/// 
/// # Security Note: `public_random` Lint
/// 
/// Sampling functions suppress the `public_random` lint because this is a
/// composable library. Consumers must ensure safe usage - see `sampling.move`
/// module documentation for details.
/// 
/// # Available Functions
/// 
/// **Sampling:**
/// - `sample_z(r, ctx)` - Sample from N(0,1)
/// - `sample_normal(r, mean, std, ctx)` - Sample from N(μ,σ²)
/// - `sample_standard_normal(r, ctx)` - Sample N(0,1) as StandardNormal
/// 
/// **Distribution Functions:**
/// - `cdf(z)` - Standard normal CDF Φ(z)
/// - `pdf(z)` - Standard normal PDF φ(z)
/// - `ppf(p)` - Inverse CDF / quantile function
/// 
/// **Error Function:**
/// - `erf(x)` - Error function
/// - `erfc(x)` - Complementary error function
/// 
/// **Constants:**
/// - `scale()` - WAD scale factor (10^18)
/// 
/// # Note
/// 
/// For advanced use cases (e.g., SignedWad arithmetic, SamplerGuard),
/// import directly from the specific modules.
module gaussian::core {
    use gaussian::sampling;
    use gaussian::normal_forward;
    use gaussian::normal_inverse;
    use gaussian::erf;
    use gaussian::signed_wad::{Self, SignedWad};
    use sui::random::Random;

    
    // === Constants ===
    

    /// WAD scale factor: 10^18
    /// All values in the library are scaled by this factor.
    public fun scale(): u256 {
        1_000_000_000_000_000_000
    }

    
    // === Sampling Functions ===
    

    /// Sample from the standard normal distribution N(0,1).
    /// 
    /// Returns a SignedWad z-score.
    /// Emits a GaussianSampleEvent.
    /// 
    /// # Example
    /// ```move
    /// let z = gaussian::core::sample_z(r, ctx);
    /// let z_value = signed_wad::abs(&z); // Get magnitude
    /// ```
    #[allow(lint(public_random))]
    public fun sample_z(
        r: &Random,
        ctx: &mut TxContext,
    ): SignedWad {
        sampling::sample_z(r, ctx)
    }

    /// Sample from a custom normal distribution N(μ,σ²).
    /// 
    /// - `mean`: μ in WAD scaling
    /// - `std_dev`: σ in WAD scaling (must be > 0)
    /// 
    /// Returns a StandardNormal containing the sample.
    /// Emits a NormalSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_normal(
        r: &Random,
        mean: u256,
        std_dev: u256,
        ctx: &mut TxContext,
    ): sampling::StandardNormal {
        sampling::sample_normal(r, mean, std_dev, ctx)
    }

    /// Sample from N(0,1) returning a StandardNormal struct.
    /// 
    /// Emits a GaussianSampleEvent.
    #[allow(lint(public_random))]
    public fun sample_standard_normal(
        r: &Random,
        ctx: &mut TxContext,
    ): sampling::StandardNormal {
        sampling::sample_standard_normal(r, ctx)
    }

    
    // === Distribution Functions ===
    

    /// Standard normal CDF: Φ(z) = P(Z ≤ z)
    /// 
    /// Returns probability in [0, SCALE] (WAD-scaled).
    /// 
    /// # Example
    /// ```move
    /// let z = signed_wad::from_wad(1_000_000_000_000_000_000); // z = 1.0
    /// let prob = gaussian::core::cdf(&z);
    /// // prob ≈ 0.8413 * SCALE
    /// ```
    public fun cdf(z: &SignedWad): u256 {
        normal_forward::cdf_standard(z)
    }

    /// Standard normal PDF: φ(z) = probability density at z
    /// 
    /// Returns density value (WAD-scaled, non-negative).
    /// Maximum at z=0: φ(0) ≈ 0.3989 * SCALE
    public fun pdf(z: &SignedWad): u256 {
        normal_forward::pdf_standard(z)
    }

    /// Inverse CDF / quantile function Φ⁻¹(p) with p as WAD-scaled u128.
    /// 
    /// Given probability p ∈ (0,1), returns z such that Φ(z) = p.
    /// 
    /// - `p`: probability in WAD scaling (u128)
    /// 
    /// # Example
    /// ```move
    /// let p: u128 = 975_000_000_000_000_000; // 0.975
    /// let z = gaussian::core::ppf(p);
    /// // z ≈ 1.96 (97.5th percentile)
    /// ```
    public fun ppf(p: u128): SignedWad {
        normal_inverse::ppf(p)
    }

    /// Convenience helper: map a u64 seed into (EPS, 1-EPS) and compute Φ⁻¹(p).
    public fun ppf_from_u64(u: u64): SignedWad {
        let p = sampling::uniform_open_interval_from_u64(u);
        normal_inverse::ppf(p)
    }

    
    // === Error Function ===
    

    /// Error function: erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt
    /// 
    /// - `x`: non-negative WAD-scaled value
    /// - Returns: erf(x) in [0, SCALE]
    /// - Inputs > 6*SCALE are clamped
    public fun erf(x: u256): u256 {
        erf::erf(x)
    }

    /// Complementary error function: erfc(x) = 1 - erf(x)
    /// 
    /// More accurate than computing `SCALE - erf(x)` for large x.
    public fun erfc(x: u256): u256 {
        erf::erfc(x)
    }

    
    // === SignedWad Utilities ===
    

    /// Create a SignedWad with the given magnitude and sign.
    public fun signed_new(magnitude: u256, negative: bool): SignedWad {
        signed_wad::new(magnitude, negative)
    }

    /// Create a zero SignedWad.
    public fun signed_zero(): SignedWad {
        signed_wad::zero()
    }

    /// Create a non-negative SignedWad from an unsigned WAD value.
    public fun signed_from_wad(x: u256): SignedWad {
        signed_wad::from_wad(x)
    }

    /// Get the absolute value of a SignedWad.
    public fun signed_abs(x: &SignedWad): u256 {
        signed_wad::abs(x)
    }

    /// Check if a SignedWad is negative.
    public fun signed_is_negative(x: &SignedWad): bool {
        signed_wad::is_negative(x)
    }

    /// Check if a SignedWad is zero.
    public fun signed_is_zero(x: &SignedWad): bool {
        signed_wad::is_zero(x)
    }

    
    // === Tests ===
    

    #[test]
    fun test_scale_constant() {
        assert!(scale() == 1_000_000_000_000_000_000, 0);
    }

    #[test]
    fun test_cdf_at_zero() {
        let z = signed_zero();
        let prob = cdf(&z);
        // Φ(0) = 0.5, so prob should be ~SCALE/2
        let half_scale = scale() / 2;
        let tolerance = scale() / 100; // 1% tolerance
        let diff = if (prob > half_scale) { prob - half_scale } else { half_scale - prob };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_pdf_at_zero() {
        let z = signed_zero();
        let density = pdf(&z);
        // φ(0) ≈ 0.3989
        let expected = 398_942_280_401_432_700;
        let tolerance = scale() / 1000; // 0.1% tolerance
        let diff = if (density > expected) { density - expected } else { expected - density };
        assert!(diff < tolerance, 0);
    }

    #[test]
    fun test_ppf_at_half() {
        let p: u128 = 500_000_000_000_000_000; // 0.5
        let z = ppf(p);
        // Φ⁻¹(0.5) = 0
        assert!(signed_abs(&z) < scale() / 10, 0); // Should be near 0
    }

    #[test]
    fun test_erf_at_zero() {
        let result = erf(0);
        assert!(result == 0, 0);
    }

    #[test]
    fun test_erfc_at_zero() {
        let result = erfc(0);
        assert!(result == scale(), 0);
    }

    #[test]
    fun test_signed_utilities() {
        let x = signed_new(scale(), true);
        assert!(signed_abs(&x) == scale(), 0);
        assert!(signed_is_negative(&x), 1);
        assert!(!signed_is_zero(&x), 2);

        let zero = signed_zero();
        assert!(signed_is_zero(&zero), 3);
        assert!(!signed_is_negative(&zero), 4);

        let pos = signed_from_wad(scale());
        assert!(!signed_is_negative(&pos), 5);
    }

    // === ppf_from_u64 Tests (v0.9.0 modernization) ===

    #[test]
    fun test_ppf_from_u64_at_midpoint() {
        // u64 midpoint (0x8000000000000000) should map to p ≈ 0.5, z ≈ 0
        let z = ppf_from_u64(0x8000000000000000);
        let z_mag = signed_abs(&z);
        // Should be very close to 0 (within 0.5σ tolerance)
        assert!(z_mag < scale() / 2, 0);
    }

    #[test]
    fun test_ppf_from_u64_at_low_seed() {
        // Very low seed should produce negative z (left tail)
        let z = ppf_from_u64(1000);
        assert!(signed_is_negative(&z), 0);
        let z_mag = signed_abs(&z);
        // Should be large negative (several σ)
        assert!(z_mag > 2 * scale(), 1);
    }

    #[test]
    fun test_ppf_from_u64_at_high_seed() {
        // Very high seed should produce positive z (right tail)
        let z = ppf_from_u64(0xFFFFFFFFFFFFFFFF - 1000);
        assert!(!signed_is_negative(&z), 0);
        let z_mag = signed_abs(&z);
        // Should be large positive (several σ)
        assert!(z_mag > 2 * scale(), 1);
    }

    #[test]
    fun test_ppf_from_u64_never_aborts() {
        // Any u64 seed should produce a valid result (no abort)
        // Test boundary seeds
        let _z0 = ppf_from_u64(0);
        let _z1 = ppf_from_u64(1);
        let _zmax = ppf_from_u64(0xFFFFFFFFFFFFFFFF);
        let _zmaxm1 = ppf_from_u64(0xFFFFFFFFFFFFFFFE);
        let _zmid = ppf_from_u64(0x8000000000000000);
    }

    #[test]
    fun test_ppf_from_u64_monotonic() {
        // Larger seeds should produce larger z values (monotonicity)
        let z_low = ppf_from_u64(0x1000000000000000);
        let z_mid = ppf_from_u64(0x8000000000000000);
        let z_high = ppf_from_u64(0xF000000000000000);
        
        assert!(signed_wad::lt(&z_low, &z_mid), 0);
        assert!(signed_wad::lt(&z_mid, &z_high), 1);
    }
}
