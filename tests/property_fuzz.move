/// Property-style tests for Gaussian invariants.
#[test_only]
module gaussian::property_fuzz {
    use gaussian::coefficients;
    use gaussian::math;
    use gaussian::normal_forward;
    use gaussian::normal_inverse;
    use gaussian::sampling;
    use gaussian::signed_wad;

    const SCALE: u256 = 1_000_000_000_000_000_000;

    public struct LnCase has copy, drop, store {
        p: u128,
        expected_mag: u256,
        expected_neg: bool,
        tolerance: u256,
    }

    public struct TailCase has copy, drop, store {
        p: u128,
        expected_mag: u256,
        expected_neg: bool,
        tolerance: u256,
    }

    /// Dense tail monotonicity for PPF (lower tail).
    #[test]
    fun test_ppf_tail_monotonic_dense() {
        let probs: vector<u128> = vector[
            100000000,        // 1e-10
            1000000000,       // 1e-9
            10000000000,      // 1e-8
            100000000000,     // 1e-7
            1000000000000,    // 1e-6
            10000000000000,   // 1e-5
            100000000000000,  // 1e-4
            1000000000000000, // 1e-3
            2000000000000000, // 2e-3
            5000000000000000, // 5e-3
            10000000000000000, // 1e-2
            15000000000000000, // 0.015
            20000000000000000  // 0.02
        ];

        let mut i = 1;
        while (i < std::vector::length(&probs)) {
            let p_prev = *std::vector::borrow(&probs, i - 1);
            let p_cur = *std::vector::borrow(&probs, i);
            let z_prev = normal_inverse::ppf(p_prev);
            let z_cur = normal_inverse::ppf(p_cur);
            assert!(signed_wad::lt(&z_prev, &z_cur), i as u64);
            i = i + 1;
        };
    }

    /// Symmetry check: ppf(p) ≈ -ppf(1-p) across a grid.
    #[test]
    fun test_ppf_symmetry_grid() {
        let probs: vector<u128> = vector[
            500000000000000000, // 0.5
            600000000000000000, // 0.6
            700000000000000000, // 0.7
            800000000000000000, // 0.8
            900000000000000000, // 0.9
            950000000000000000, // 0.95
            990000000000000000  // 0.99
        ];
        let tolerance = SCALE / 20; // 0.05 WAD
        let mut i = 0;
        while (i < std::vector::length(&probs)) {
            let p = *std::vector::borrow(&probs, i);
            let p_mirror = SCALE - (p as u256);
            let z = normal_inverse::ppf(p);
            let z_mirror = normal_inverse::ppf((p_mirror as u128));
            let sum = signed_wad::add(&z, &z_mirror);
            let sum_mag = signed_wad::abs(&sum);
            assert!(sum_mag < tolerance, i as u64);
            i = i + 1;
        };
    }

    /// Round-trip check: ppf(cdf(z)) ≈ z on dense grid.
    #[test]
    fun test_roundtrip_dense_grid() {
        let step: u256 = 600000000000000000; // 0.6 step
        let tolerance = SCALE; // 1.0 WAD
        // Negative side
        let mut mag = step;
        while (mag <= 6 * SCALE) {
            let sw = signed_wad::new(mag, true);
            let p = normal_forward::cdf_standard(&sw);
            let z_back = normal_inverse::ppf((p as u128));
            let diff = signed_wad::abs(&signed_wad::sub(&sw, &z_back));
            assert!(diff < tolerance, 0);
            mag = mag + step;
        };
        // Positive side
        mag = 0;
        while (mag <= 6 * SCALE) {
            let sw = signed_wad::new(mag, false);
            let p = normal_forward::cdf_standard(&sw);
            let z_back = normal_inverse::ppf((p as u128));
            let diff = signed_wad::abs(&signed_wad::sub(&sw, &z_back));
            assert!(diff < tolerance, 1);
            mag = mag + step;
        };
    }

    /// Accuracy checks for ln_wad at representative points.
    #[test]
    fun test_ln_wad_accuracy() {
        let cases: vector<LnCase> = vector[
            // p, expected magnitude, expected sign, tolerance
            LnCase { p: (SCALE as u128), expected_mag: 0u256, expected_neg: false, tolerance: 1_000_000_000 }, // ln(1) = 0
            LnCase { p: (SCALE / 2) as u128, expected_mag: 693_147_180_559_945_309u256, expected_neg: true, tolerance: 500_000_000_000_000_000 }, // ln(0.5) = -ln2
            LnCase { p: 100_000_000_000_000_000u128, expected_mag: 2_302_585_092_994_045_000u256, expected_neg: true, tolerance: 2_000_000_000_000_000_000 } // ln(0.1)
        ];
        let mut i = 0;
        while (i < std::vector::length(&cases)) {
            let c = *std::vector::borrow(&cases, i);
            let ln_val = normal_inverse::ln_wad_signed(c.p);
            let mag = signed_wad::abs(&ln_val);
            let neg = signed_wad::is_negative(&ln_val);
            let diff = if (mag > c.expected_mag) { mag - c.expected_mag } else { c.expected_mag - mag };
            assert!(neg == c.expected_neg, i as u64);
            assert!(diff <= c.tolerance, i as u64);
            i = i + 1;
        };
    }

    /// Accuracy checks for sqrt_wad at key values.
    #[test]
    fun test_sqrt_wad_accuracy() {
        let one = normal_inverse::sqrt_wad_public(SCALE);
        let four = normal_inverse::sqrt_wad_public(4 * SCALE);
        let quarter = normal_inverse::sqrt_wad_public(SCALE / 4);

        // sqrt(1) = 1
        assert!(one <= SCALE + 1_000_000_000 && one + 1_000_000_000 >= SCALE, 0);
        // sqrt(4) = 2
        let expected_two = 2 * SCALE;
        let diff_two = if (four > expected_two) { four - expected_two } else { expected_two - four };
        assert!(diff_two <= 1_000_000_000_000, 1);
        // sqrt(0.25) = 0.5
        let expected_half = SCALE / 2;
        let diff_half = if (quarter > expected_half) { quarter - expected_half } else { expected_half - quarter };
        assert!(diff_half <= 1_000_000_000_000, 2);
    }

    /// Tail accuracy checks for PPF against high-precision references.
    #[test]
    fun test_ppf_tail_accuracy_points() {
        let cases: vector<TailCase> = vector[
            TailCase { p: 100000000, expected_mag: 6_361_340_889_697_422_000u256, expected_neg: true, tolerance: 5_000_000_000_000_000 },   // p = 1e-10
            TailCase { p: 1_000_000_000_000, expected_mag: 4_753_424_308_822_899_000u256, expected_neg: true, tolerance: 5_000_000_000_000_000 }, // p = 1e-6
            TailCase { p: 1_000_000_000_000_000, expected_mag: 3_090_232_306_167_813_000u256, expected_neg: true, tolerance: 3_000_000_000_000_000 } // p = 1e-3
        ];
        let mut i = 0;
        while (i < std::vector::length(&cases)) {
            let c = *std::vector::borrow(&cases, i);
            let z = normal_inverse::ppf(c.p);
            let mag = signed_wad::abs(&z);
            let neg = signed_wad::is_negative(&z);
            let diff = if (mag > c.expected_mag) { mag - c.expected_mag } else { c.expected_mag - mag };
            assert!(neg == c.expected_neg, i as u64);
            assert!(diff <= c.tolerance, i as u64);
            i = i + 1;
        };
    }

    /// Sampler invariants: mean ~0 and |z| bounded for deterministic seeds.
    #[test]
    fun test_sampler_invariants() {
        let seeds = vector[
            9334618346840842905u64, 10424100709723369767u64, 9443182695686696458u64,
            17933673198744876582u64, 11342960890024317363u64, 10482980246973705466u64,
            5290281280504745347u64, 10228930864023155047u64, 8624286824275906926u64,
            11253583944051605563u64, 17163634629999896190u64, 4535784743480959579u64
        ];
        let mut sum = signed_wad::zero();
        let mut i = 0;
        while (i < std::vector::length(&seeds)) {
            let raw = *std::vector::borrow(&seeds, i);
            let z = sampling::sample_z_from_u64(raw);
            let mag = signed_wad::abs(&z);
            assert!(mag <= 7 * SCALE, 0);
            sum = signed_wad::add(&sum, &z);
            i = i + 1;
        };
        let mean_mag = signed_wad::abs(&sum) / (std::vector::length(&seeds) as u256);
        assert!(mean_mag < SCALE / 2, 1); // mean within 0.5
    }

    /// Sampler mean shift check for N(mean, std) using deterministic seeds.
    #[test]
    fun test_sampler_normal_mean_shift() {
        let seeds = vector[
            9334618346840842905u64, 10424100709723369767u64, 9443182695686696458u64,
            17933673198744876582u64, 11342960890024317363u64, 10482980246973705466u64,
            5290281280504745347u64, 10228930864023155047u64, 8624286824275906926u64,
            11253583944051605563u64, 17163634629999896190u64, 4535784743480959579u64
        ];
        let mean = 500_000_000_000_000_000u256; // 0.5
        let std = 200_000_000_000_000_000u256;  // 0.2

        let mut sum = signed_wad::zero();
        let mut i = 0;
        while (i < std::vector::length(&seeds)) {
            let raw = *std::vector::borrow(&seeds, i);
            let n = sampling::sample_normal_from_u64(raw, mean, std);
            sum = signed_wad::add(&sum, &n);
            i = i + 1;
        };
        let avg = signed_wad::div_wad(&sum, &signed_wad::from_wad((std::vector::length(&seeds) as u256) * SCALE));
        // Average should stay close to mean (within 0.15)
        let diff = signed_wad::abs(&signed_wad::sub(&avg, &signed_wad::from_wad(mean)));
        assert!(diff < 150_000_000_000_000_000, 0);
    }

    /// Variance sanity check for deterministic seeds (approx unit variance).
    #[test]
    fun test_sampler_variance_bounds() {
        let seeds = vector[
            9334618346840842905u64, 10424100709723369767u64, 9443182695686696458u64,
            17933673198744876582u64, 11342960890024317363u64, 10482980246973705466u64,
            5290281280504745347u64, 10228930864023155047u64, 8624286824275906926u64,
            11253583944051605563u64, 17163634629999896190u64, 4535784743480959579u64
        ];

        let mut sum_sq: u256 = 0;
        let mut i = 0;
        while (i < std::vector::length(&seeds)) {
            let raw = *std::vector::borrow(&seeds, i);
            let z = sampling::sample_z_from_u64(raw);
            let mag = signed_wad::abs(&z);
            let square = math::mul_div(mag, mag); // (mag^2) / SCALE => still WAD-scaled
            sum_sq = sum_sq + square;
            i = i + 1;
        };

        let n = std::vector::length(&seeds) as u256;
        let variance_est = sum_sq / n;
        let lower = 450_000_000_000_000_000; // 0.45
        let upper = 1_550_000_000_000_000_000; // 1.55
        assert!(variance_est >= lower && variance_est <= upper, 0);
    }

    /// Monotonicity check for seeded sampler (raw seed order maps to increasing z).
    #[test]
    fun test_sampler_tail_monotonicity_from_seeds() {
        let seeds = vector[0u64, 1u64, 0x7FFFFFFFFFFFFFFFu64, 0xFFFFFFFFFFFFFFFFu64];
        let mut prev = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, 0));
        let mut i = 1;
        while (i < std::vector::length(&seeds)) {
            let next = sampling::sample_z_from_u64(*std::vector::borrow(&seeds, i));
            assert!(signed_wad::le(&prev, &next), i as u64);
            prev = next;
            i = i + 1;
        };
    }

    /// Monotonicity across the central region probabilities.
    #[test]
    fun test_ppf_central_monotonic_dense() {
        let probs: vector<u128> = vector[
            100000000000000000,  // 0.1
            300000000000000000,  // 0.3
            500000000000000000,  // 0.5
            700000000000000000,  // 0.7
            900000000000000000   // 0.9
        ];
        let mut i = 1;
        while (i < std::vector::length(&probs)) {
            let p_prev = *std::vector::borrow(&probs, i - 1);
            let p_cur = *std::vector::borrow(&probs, i);
            let z_prev = normal_inverse::ppf(p_prev);
            let z_cur = normal_inverse::ppf(p_cur);
            assert!(signed_wad::lt(&z_prev, &z_cur), i as u64);
            i = i + 1;
        };
    }

    /// CDF should be non-decreasing across a sorted grid of z values.
    #[test]
    fun test_cdf_monotonic_grid() {
        let zs: vector<signed_wad::SignedWad> = vector[
            signed_wad::new(6 * SCALE, true),  // -6.0
            signed_wad::new(3 * SCALE, true),  // -3.0
            signed_wad::new(1 * SCALE, true),  // -1.0
            signed_wad::zero(),                // 0.0
            signed_wad::from_wad(SCALE / 2),   // 0.5
            signed_wad::from_wad(1 * SCALE),   // 1.0
            signed_wad::from_wad(3 * SCALE),   // 3.0
            signed_wad::from_wad(6 * SCALE)    // 6.0
        ];

        let mut prev = 0u256;
        let mut i = 0;
        while (i < std::vector::length(&zs)) {
            let z = std::vector::borrow(&zs, i);
            let cdf = normal_forward::cdf_standard(z);
            if (i > 0) {
                assert!(prev <= cdf, i as u64);
            };
            prev = cdf;
            i = i + 1;
        };
    }

    /// ln_wad should be strictly increasing with p; dense grid check.
    #[test]
    fun test_ln_wad_monotonic_grid() {
        let probs: vector<u128> = vector[
            coefficients::eps(),                    // 1e-10
            1000000000000000,                       // 1e-6
            100000000000000000,                     // 0.1
            300000000000000000,                     // 0.3
            500000000000000000,                     // 0.5
            800000000000000000,                     // 0.8
            coefficients::scale() - coefficients::eps() // ~1.0
        ];

        let mut prev_mag = 0u256;
        let mut prev_neg = true;
        let mut i = 0;
        while (i < std::vector::length(&probs)) {
            let p = *std::vector::borrow(&probs, i);
            let ln_val = normal_inverse::ln_wad_signed(p);
            let mag = signed_wad::abs(&ln_val);
            let neg = signed_wad::is_negative(&ln_val);
            if (i > 0) {
                if (neg == prev_neg) {
                    if (!neg) {
                        assert!(mag >= prev_mag, i as u64);
                    } else {
                        assert!(mag <= prev_mag, i as u64);
                    }
                };
            };
            prev_mag = mag;
            prev_neg = neg;
            i = i + 1;
        };
    }

    /// sqrt_wad should be monotone and roughly invert squaring.
    #[test]
    fun test_sqrt_wad_monotonic_grid() {
        let inputs: vector<u256> = vector[
            SCALE / 100,      // 0.01
            SCALE / 4,        // 0.25
            SCALE / 2,        // 0.5
            SCALE,            // 1.0
            4 * SCALE,        // 4.0
            9 * SCALE         // 9.0
        ];

        let mut prev_root = 0u256;
        let mut i = 0;
        while (i < std::vector::length(&inputs)) {
            let x = *std::vector::borrow(&inputs, i);
            let root = normal_inverse::sqrt_wad_public(x);
            if (i > 0) {
                assert!(root > prev_root, i as u64);
            };

            let recomposed = math::mul_div(root, root);
            let diff = if (recomposed > x) { recomposed - x } else { x - recomposed };
            assert!(diff < 5_000_000_000_000_000, i as u64); // ~0.005 tolerance

            prev_root = root;
            i = i + 1;
        };
    }

    /// PPF accuracy at the extreme edges and symmetry check.
    #[test]
    fun test_ppf_edges_and_symmetry() {
        let p_low = coefficients::eps();
        let p_high = coefficients::scale() - p_low;
        let expected_edge = 6_361_340_889_697_422_000u256; // Φ⁻¹(1e-10)
        let tolerance = 10_000_000_000_000_000; // ~0.01

        let z_low = normal_inverse::ppf(p_low);
        let z_high = normal_inverse::ppf(p_high);

        let mag_low = signed_wad::abs(&z_low);
        let mag_high = signed_wad::abs(&z_high);

        let diff_low = if (mag_low > expected_edge) { mag_low - expected_edge } else { expected_edge - mag_low };
        let diff_high = if (mag_high > expected_edge) { mag_high - expected_edge } else { expected_edge - mag_high };

        assert!(signed_wad::is_negative(&z_low), 0);
        assert!(!signed_wad::is_negative(&z_high), 1);
        assert!(diff_low < tolerance, 2);
        assert!(diff_high < tolerance, 3);

        let sum = signed_wad::add(&z_low, &z_high);
        let sum_mag = signed_wad::abs(&sum);
        assert!(sum_mag < tolerance, 4);
    }

    /// Moments check for PPF sampler using deterministic seeds.
    #[test]
    fun test_sampler_ppf_moments() {
        let seeds = vector[
            9334618346840842905u64, 10424100709723369767u64, 9443182695686696458u64,
            17933673198744876582u64, 11342960890024317363u64, 10482980246973705466u64,
            5290281280504745347u64, 10228930864023155047u64, 8624286824275906926u64,
            11253583944051605563u64, 17163634629999896190u64, 4535784743480959579u64
        ];

        let mut sum = signed_wad::zero();
        let mut sum_sq: u256 = 0;
        let mut i = 0;
        while (i < std::vector::length(&seeds)) {
            let raw = *std::vector::borrow(&seeds, i);
            let z = sampling::sample_z_from_u64(raw);
            sum = signed_wad::add(&sum, &z);

            let z_sq = signed_wad::mul(&z, &z);
            let z_sq_wad = signed_wad::to_wad_checked(&z_sq);
            sum_sq = sum_sq + z_sq_wad;

            i = i + 1;
        };

        let n = (std::vector::length(&seeds) as u256);
        let denom = signed_wad::from_wad(n * SCALE);
        let mean = signed_wad::div_wad(&sum, &denom);
        let mean_mag = signed_wad::abs(&mean);
        assert!(mean_mag < SCALE / 3, 0); // |mean| < ~0.33

        let second_moment = sum_sq / n;
        let diff_var = if (second_moment > SCALE) { second_moment - SCALE } else { SCALE - second_moment };
        assert!(diff_var < SCALE / 2, 1); // variance within [0.5, 1.5]
    }
}

