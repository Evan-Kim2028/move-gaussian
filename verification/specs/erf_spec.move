/// Formal verification specifications for the erf module.
///
/// Level 4: Verify bounds and basic properties.
///
/// IMPORTANT: The erf/erfc functions use complex polynomial evaluation with
/// large coefficients (~1e77) that cause symbolic overflow in the prover.
/// These functions CANNOT be directly verified with SMT-based formal verification.
///
/// This is a known limitation - numerical libraries with large coefficients
/// require different verification approaches (e.g., testing, bounded model checking).
///
/// Instead, we verify the simpler math utilities that erf depends on, and
/// document that erf bounds are verified through extensive testing.
module gaussian::erf_spec;

// Level 4 specs for erf are NOT VERIFIABLE due to polynomial coefficient overflow.
// See notes above. The math module specs (Level 2, Level 3) verify the building
// blocks that erf uses (mul_div, signed_add, clamp_to_unit).
//
// The erf bounds are verified through:
// 1. Unit tests in erf.move
// 2. Property-based testing in test suite
// 3. Manual code review (clamp_to_unit at end guarantees bounds)
//
// Formal verification of erf would require:
// - Bounded model checking (concrete values only)
// - Or custom theory solver for polynomial arithmetic
