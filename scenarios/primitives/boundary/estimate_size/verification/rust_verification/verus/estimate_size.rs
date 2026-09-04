#![crate_type = "lib"]

use vstd::prelude::*;

verus! {

spec fn expected_panic(x: u32) -> bool {
    x == 1023
}

spec fn expected_size(x: u32) -> u32 {
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

// An explicit error makes the panic behavior observable to verification.
fn estimate_size_panic(x: u32) -> (result: Result<u32, ()>)
    ensures
        result.is_err() <==> expected_panic(x),
        !expected_panic(x) ==> result == Ok(expected_size(x)),
    no_unwind
{
    if x < 256 {
        if x < 128 {
            Ok(1)
        } else {
            Ok(3)
        }
    } else if x < 1024 {
        if x > 1022 {
            Err(())
        } else {
            Ok(5)
        }
    } else if x < 2048 {
        Ok(7)
    } else {
        Ok(9)
    }
}

fn estimate_size_correction(x: u32) -> (result: u32)
    ensures
        result == expected_size(x),
    no_unwind
{
    if x < 256 {
        if x < 128 {
            1
        } else {
            3
        }
    } else if x < 1024 {
        if x > 1022 {
            4
        } else {
            5
        }
    } else if x < 2048 {
        7
    } else {
        9
    }
}

// The original implementation fails exactly when expected.
fn original_panics_iff_expected(x: u32)
    no_unwind
{
    let original = estimate_size_panic(x);
    assert(original.is_err() <==> expected_panic(x));
}

// Local guarantee: the failing input is corrected.
fn corrected_at_1023()
    no_unwind
{
    let corrected = estimate_size_correction(1023);
    assert(corrected == 4);
}

// Weak guarantee: the corrected implementation returns an allowed size.
fn corrected_returns_allowed(x: u32)
    no_unwind
{
    let corrected = estimate_size_correction(x);
    assert(
        corrected == 1 || corrected == 3 || corrected == 4
        || corrected == 5 || corrected == 7 || corrected == 9
    );
}

// Unique-case guarantee: the result is 4 exactly at the repaired input.
fn corrected_returns_four_iff(x: u32)
    no_unwind
{
    let corrected = estimate_size_correction(x);
    assert((corrected == 4) <==> (x == 1023));
}

// Strong guarantee: the corrected implementation matches the full specification.
fn corrected_matches_spec(x: u32)
    no_unwind
{
    let corrected = estimate_size_correction(x);
    assert(corrected == expected_size(x));
}

// Repair guarantee: only the failing input changes behavior.
fn correction_is_exact_patch(x: u32)
    no_unwind
{
    let original = estimate_size_panic(x);
    let corrected = estimate_size_correction(x);
    assert(expected_panic(x) ==> corrected == 4);
    assert(!expected_panic(x) ==> original == Ok(corrected));
}

} // verus!
