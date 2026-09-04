#![allow(dead_code)]

include!("../../../src/estimate_size.rs");

fn expected_size(x: u32) -> u32 {
    if x < 128 {
        1
    } else if x < 256 {
        3
    } else if x < 1023 {
        5
    } else if x == 1023 {
        4
    } else if x < 2048 {
        7
    } else {
        9
    }
}

// The original implementation panics at the known failing input.
#[kani::proof]
#[kani::should_panic]
fn original_panics_at_1023() {
    let _ = estimate_size_panic(1023);
}

// The original implementation does not panic at any other input.
#[kani::proof]
fn original_does_not_panic_elsewhere() {
    let x: u32 = kani::any();
    kani::assume(x != 1023);
    let _ = estimate_size_panic(x);
}

// Local guarantee: the failing input is corrected.
#[kani::proof]
fn corrected_at_1023() {
    assert_eq!(estimate_size_correction(1023), 4);
}

// Weak guarantee: the corrected implementation returns an allowed size.
#[kani::proof]
fn corrected_returns_allowed() {
    let x: u32 = kani::any();
    let result = estimate_size_correction(x);
    assert!(matches!(result, 1 | 3 | 4 | 5 | 7 | 9));
}

// Unique-case guarantee: the result is 4 exactly at the repaired input.
#[kani::proof]
fn corrected_returns_four_iff() {
    let x: u32 = kani::any();
    assert_eq!(estimate_size_correction(x) == 4, x == 1023);
}

// Strong guarantee: the corrected implementation matches the full specification.
#[kani::proof]
fn corrected_matches_spec() {
    let x: u32 = kani::any();
    assert_eq!(estimate_size_correction(x), expected_size(x));
}

// Repair guarantee: all non-failing inputs preserve their behavior.
#[kani::proof]
fn correction_preserves_other_inputs() {
    let x: u32 = kani::any();
    kani::assume(x != 1023);
    assert_eq!(estimate_size_panic(x), estimate_size_correction(x));
}
