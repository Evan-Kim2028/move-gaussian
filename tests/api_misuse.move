/// API boundary misuse tests (abort paths + checked alternatives).
module gaussian::api_misuse;

use gaussian::math;
use gaussian::normal_inverse;
use gaussian::sampling;

#[test, expected_failure(abort_code = math::EDivisionByZero)]
fun div_scaled_aborts_on_zero_denominator() {
    let _ = math::div_scaled(1, 0);
}

#[test]
fun div_scaled_checked_returns_none_on_zero_denominator() {
    let result = math::div_scaled_checked(1, 0);
    assert!(option::is_none(&result), 0);
}

#[test, expected_failure(abort_code = normal_inverse::EProbOutOfDomain)]
fun ppf_aborts_on_out_of_domain_probability() {
    let _ = normal_inverse::ppf(0);
}

#[test]
fun ppf_checked_returns_none_on_out_of_domain_probability() {
    let result = normal_inverse::ppf_checked(0);
    assert!(option::is_none(&result), 0);
}

#[test, expected_failure(abort_code = sampling::ERandomAlreadyUsed)]
fun sampler_guard_blocks_reuse() {
    let mut guard = sampling::new_sampler_guard();
    let _ = sampling::sample_z_from_u64_guarded(1, &mut guard);
    let _ = sampling::sample_z_from_u64_guarded(2, &mut guard);
}
