/// Profile metadata object for the Gaussian library.
/// 
/// # Overview
/// 
/// This module provides an on-chain metadata object (`GaussianProfile`) that
/// documents the library version and configuration. The profile is created
/// automatically when the package is deployed and shared for public access.
/// 
/// # Usage
/// 
/// Downstream protocols can reference the profile to verify they're using
/// a specific version of the library:
/// 
/// ```move
/// use gaussian::profile::GaussianProfile;
/// 
/// public fun my_function(profile: &GaussianProfile, ...) {
///     // Verify version >= 0.7.0
///     assert!(gaussian::profile::version(profile) >= 700, EOutdatedLibrary);
/// }
/// ```
/// 
/// # Version Encoding
/// 
/// Version is encoded as: `major * 10000 + minor * 100 + patch`
/// - v0.7.0 = 700
/// - v1.0.0 = 10000
/// - v2.3.1 = 20301
module gaussian::profile {

    // === Constants ===

    /// Current library version: v0.7.0
    /// Encoding: major * 10000 + minor * 100 + patch
    const VERSION: u32 = 700;

    /// Standard precision class (AAA polynomial approximation)
    const PRECISION_STANDARD: u8 = 0;

    /// High precision class (future: more Newton iterations)
    const PRECISION_HIGH: u8 = 1;

    /// Fast/LUT precision class (future: lookup table)
    const PRECISION_FAST: u8 = 2;

    /// Maximum |z| = 6.0 in WAD scaling
    const MAX_Z_WAD: u256 = 6_000_000_000_000_000_000;

    // === Structs ===

    /// Immutable metadata about the Gaussian library configuration.
    /// 
    /// Created once at package deployment, shared for public read access.
    /// Never modified after creation.
    public struct GaussianProfile has key, store {
        /// Sui object identifier (required for shared objects)
        id: UID,
        /// Library version as semantic version integer.
        /// Encoding: major * 10000 + minor * 100 + patch
        /// Example: v0.7.0 = 700, v2.3.1 = 20301
        version: u32,
        /// Precision class indicating the approximation method:
        /// - 0 = standard (AAA polynomial approximation)
        /// - 1 = high (future: more Newton iterations)
        /// - 2 = fast (future: LUT-based)
        precision_class: u8,
        /// Maximum supported |z| value (WAD-scaled).
        /// Current: 6e18 (covers 99.9999998% of distribution)
        max_z_wad: u256,
    }

    // === Initialization ===

    /// Package initializer - creates and shares the GaussianProfile.
    /// 
    /// Called automatically by Sui when the package is first deployed.
    /// Creates a single shared GaussianProfile object.
    fun init(ctx: &mut TxContext) {
        let profile = GaussianProfile {
            id: object::new(ctx),
            version: VERSION,
            precision_class: PRECISION_STANDARD,
            max_z_wad: MAX_Z_WAD,
        };
        
        // Share the profile so anyone can read it
        transfer::public_share_object(profile);
    }

    // === Accessors ===

    /// Get the library version as semantic version integer.
    /// 
    /// Decode with: major = v / 10000, minor = (v / 100) % 100, patch = v % 100
    public fun version(p: &GaussianProfile): u32 {
        p.version
    }

    /// Get the precision class.
    /// 
    /// - 0 = standard (AAA approximation)
    /// - 1 = high (future)
    /// - 2 = fast/LUT (future)
    public fun precision_class(p: &GaussianProfile): u8 {
        p.precision_class
    }

    /// Get the maximum supported |z| value (WAD-scaled).
    public fun max_z_wad(p: &GaussianProfile): u256 {
        p.max_z_wad
    }

    // === Version Helpers ===

    /// Extract major version number from profile.
    /// 
    /// Example: v1.2.3 → 1
    public fun version_major(p: &GaussianProfile): u32 {
        p.version / 10000
    }

    /// Extract minor version number from profile.
    /// 
    /// Example: v1.2.3 → 2
    public fun version_minor(p: &GaussianProfile): u32 {
        (p.version / 100) % 100
    }

    /// Extract patch version number from profile.
    /// 
    /// Example: v1.2.3 → 3
    public fun version_patch(p: &GaussianProfile): u32 {
        p.version % 100
    }

    // === Precision Class Helpers ===

    /// Check if this is the standard precision profile.
    public fun is_standard_precision(p: &GaussianProfile): bool {
        p.precision_class == PRECISION_STANDARD
    }

    /// Check if this is a high precision profile.
    public fun is_high_precision(p: &GaussianProfile): bool {
        p.precision_class == PRECISION_HIGH
    }

    /// Check if this is a fast/LUT precision profile.
    public fun is_fast_precision(p: &GaussianProfile): bool {
        p.precision_class == PRECISION_FAST
    }

    // === Constants Accessors ===

    /// Get the current library version constant.
    public fun current_version(): u32 {
        VERSION
    }

    /// Get the standard precision class constant.
    public fun standard_precision(): u8 {
        PRECISION_STANDARD
    }

    // === Tests ===

    #[test]
    fun test_version_encoding() {
        // v0.7.0 = 700
        assert!(VERSION == 700, 0);
        
        // Decode test
        let major = VERSION / 10000;
        let minor = (VERSION / 100) % 100;
        let patch = VERSION % 100;
        
        assert!(major == 0, 1);
        assert!(minor == 7, 2);
        assert!(patch == 0, 3);
    }

    #[test]
    fun test_version_encoding_examples() {
        // v2.3.1 = 20301
        let v231: u32 = 20301;
        assert!(v231 / 10000 == 2, 0);
        assert!((v231 / 100) % 100 == 3, 1);
        assert!(v231 % 100 == 1, 2);
        
        // v1.0.0 = 10000
        let v100: u32 = 10000;
        assert!(v100 / 10000 == 1, 3);
        assert!((v100 / 100) % 100 == 0, 4);
        assert!(v100 % 100 == 0, 5);
    }

    #[test]
    fun test_max_z_constant() {
        // 6.0 in WAD
        assert!(MAX_Z_WAD == 6_000_000_000_000_000_000, 0);
    }

    #[test]
    fun test_precision_constants() {
        assert!(PRECISION_STANDARD == 0, 0);
        assert!(PRECISION_HIGH == 1, 1);
        assert!(PRECISION_FAST == 2, 2);
    }

    #[test]
    fun test_current_version() {
        assert!(current_version() == 700, 0);
    }

    #[test]
    fun test_standard_precision() {
        assert!(standard_precision() == 0, 0);
    }

    // === Test-only helpers for creating profiles ===

    #[test_only]
    public fun create_test_profile(ctx: &mut TxContext): GaussianProfile {
        GaussianProfile {
            id: object::new(ctx),
            version: VERSION,
            precision_class: PRECISION_STANDARD,
            max_z_wad: MAX_Z_WAD,
        }
    }

    #[test_only]
    public fun destroy_test_profile(profile: GaussianProfile) {
        let GaussianProfile { id, version: _, precision_class: _, max_z_wad: _ } = profile;
        object::delete(id);
    }

    #[test]
    fun test_profile_accessors() {
        let mut ctx = sui::tx_context::dummy();
        let profile = create_test_profile(&mut ctx);
        
        assert!(version(&profile) == 700, 0);
        assert!(precision_class(&profile) == 0, 1);
        assert!(max_z_wad(&profile) == 6_000_000_000_000_000_000, 2);
        assert!(version_major(&profile) == 0, 3);
        assert!(version_minor(&profile) == 7, 4);
        assert!(version_patch(&profile) == 0, 5);
        assert!(is_standard_precision(&profile), 6);
        assert!(!is_high_precision(&profile), 7);
        assert!(!is_fast_precision(&profile), 8);
        
        destroy_test_profile(profile);
    }
}
