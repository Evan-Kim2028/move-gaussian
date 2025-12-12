module gaussian::rounding;

/// Enumerates rounding strategies used by arithmetic helpers.
/// - Down: round toward zero (truncate).
/// - Up: round away from zero (ceiling).
/// - Nearest: round to closest integer, ties round up.
public enum RoundingMode has copy, drop {
    Down,
    Up,
    Nearest,
}

/// Helper returning the enum value for downward rounding.
public fun down(): RoundingMode { RoundingMode::Down }

/// Helper returning the enum value for upward rounding.
public fun up(): RoundingMode { RoundingMode::Up }

/// Helper returning the enum value for nearest rounding (ties round up).
public fun nearest(): RoundingMode { RoundingMode::Nearest }
