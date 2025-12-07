/// On-chain events for Gaussian sampling operations.
/// 
/// # Overview
/// 
/// This module defines events emitted by all sampling functions in the Gaussian
/// library. Events enable off-chain indexing and monitoring.
/// 
/// # Events
/// 
/// - `GaussianSampleEvent` - Emitted for N(0,1) samples
/// - `NormalSampleEvent` - Emitted for N(μ,σ²) samples
/// 
/// # Usage
/// 
/// Events are emitted automatically by sampling functions. Off-chain systems
/// can subscribe to these events for:
/// - Analytics and usage tracking
/// - Monitoring of sampling behavior
/// - Event tracking for DeFi protocols
/// - Debugging complex transactions
module gaussian::events {
    use sui::event;

    
    // === Event Structs ===
    

    /// Emitted on every standard normal N(0,1) sample.
    /// 
    /// Contains the z-score (magnitude + sign) and caller address.
    /// The actual floating-point z-value can be computed as:
    ///   z = (z_negative ? -1 : 1) * z_magnitude / 10^18
    public struct GaussianSampleEvent has copy, drop {
        /// Absolute value of z-score (WAD-scaled, 10^18)
        z_magnitude: u256,
        /// Sign of z-score (true = negative)
        z_negative: bool,
        /// Address that initiated the sample
        caller: address,
    }

    /// Emitted on every custom normal N(μ,σ²) sample.
    /// 
    /// Contains the underlying z-score, distribution parameters,
    /// and the final sample value.
    public struct NormalSampleEvent has copy, drop {
        /// z-score magnitude (WAD-scaled)
        z_magnitude: u256,
        /// z-score sign (true = negative)
        z_negative: bool,
        /// Mean parameter μ (WAD-scaled)
        mean: u256,
        /// Standard deviation σ (WAD-scaled)
        std_dev: u256,
        /// Final sample value magnitude = |μ + σ·z| (WAD-scaled)
        value_magnitude: u256,
        /// Final sample value sign (true = negative)
        value_negative: bool,
        /// Address that initiated the sample
        caller: address,
    }

    
    // === Internal Emit Functions ===
    

    /// Emit a GaussianSampleEvent for N(0,1) samples.
    /// 
    /// Called internally by sampling functions. Not intended for direct use.
    public(package) fun emit_gaussian_sample(
        z_magnitude: u256,
        z_negative: bool,
        caller: address,
    ) {
        event::emit(GaussianSampleEvent {
            z_magnitude,
            z_negative,
            caller,
        });
    }

    /// Emit a NormalSampleEvent for N(μ,σ²) samples.
    /// 
    /// Called internally by sampling functions. Not intended for direct use.
    public(package) fun emit_normal_sample(
        z_magnitude: u256,
        z_negative: bool,
        mean: u256,
        std_dev: u256,
        value_magnitude: u256,
        value_negative: bool,
        caller: address,
    ) {
        event::emit(NormalSampleEvent {
            z_magnitude,
            z_negative,
            mean,
            std_dev,
            value_magnitude,
            value_negative,
            caller,
        });
    }

    
    // === Tests ===
    

    #[test]
    fun test_gaussian_event_can_be_constructed() {
        let _event = GaussianSampleEvent {
            z_magnitude: 1_000_000_000_000_000_000,
            z_negative: false,
            caller: @0x1,
        };
    }

    #[test]
    fun test_normal_event_can_be_constructed() {
        let _event = NormalSampleEvent {
            z_magnitude: 1_000_000_000_000_000_000,
            z_negative: true,
            mean: 100_000_000_000_000_000_000,
            std_dev: 10_000_000_000_000_000_000,
            value_magnitude: 90_000_000_000_000_000_000,
            value_negative: false,
            caller: @0x1,
        };
    }
}
