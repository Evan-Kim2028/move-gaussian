module gaussian::harness {
    use gaussian::sampling;
    use gaussian::signed_wad;

    /// DevInspect-friendly entry: deterministic standard normal from a u64 seed.
    /// Returns (magnitude, is_negative) in WAD.
    public entry fun sample_z_from_seed(seed: u64): (u256, bool) {
        let z = sampling::sample_z_from_u64(seed);
        (signed_wad::abs(&z), signed_wad::is_negative(&z))
    }

    /// DevInspect-friendly entry: deterministic N(mean, std^2) from a u64 seed.
    /// mean/std are WAD-scaled; returns (magnitude, is_negative) in WAD.
    public entry fun sample_normal_from_seed(seed: u64, mean: u256, std_dev: u256): (u256, bool) {
        let n = sampling::sample_normal_from_u64(seed, mean, std_dev);
        (signed_wad::abs(&n), signed_wad::is_negative(&n))
    }
}

