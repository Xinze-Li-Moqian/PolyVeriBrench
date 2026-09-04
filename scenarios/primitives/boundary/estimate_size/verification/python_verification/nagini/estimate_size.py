"""
Nagini: deductive verification of annotated Python, via Viper.

This is the Verus-shaped backend for Python. Kani and CrossHair read the source
the project ships; Z3 re-encodes the program as formulas; Nagini sits where
Verus does -- the program is real Python carrying its own contracts, and the
verifier discharges them for every input rather than searching for a
counterexample.

Run with:

    nagini estimate_size.py

`x` is an unbounded `int`, so these claims cover all of Z, negatives included,
like the Z3 and CrossHair backends and unlike the u32 ones.

One deviation from the shipped source, and it is a tool limit rather than a
choice: the program raises `Exception` here, not `RuntimeError`. Nagini models
only the base class -- `Exsures(RuntimeError, ...)` crashes its translator, and
even constructing one is rejected as an unsupported builtin. So this backend can
say that the original fails and exactly where, but not what it fails with.
CrossHair is the Python backend that pins the exception type down, because it
runs the real code and can look at the object.
"""

from nagini_contracts.contracts import *


@Pure
def expected_panic(x: int) -> bool:
    return x == 1023


@Pure
def expected_size(x: int) -> int:
    if x < 128:
        return 1
    elif x < 256:
        return 3
    elif x < 1023:
        return 5
    elif x == 1023:
        return 4
    elif x < 2048:
        return 7
    else:
        return 9


# Claims 1 and 7 both live in this contract. Ensures covers the normal exits:
# returning at all means the input was not the failing one, and the value is the
# specified one. Exsures covers the other exit: raising means it was.
def estimate_size_panic(x: int) -> int:
    Ensures(not expected_panic(x) and Result() == expected_size(x))
    Exsures(Exception, expected_panic(x))
    if x < 256:
        if x < 128:
            return 1
        else:
            return 3
    elif x < 1024:
        if x > 1022:
            raise Exception("Oh no, a failing corner case!")
        else:
            return 5
    else:
        if x < 2048:
            return 7
        else:
            return 9


# Claim 5: the corrected function matches the full specification everywhere.
def estimate_size_correction(x: int) -> int:
    Ensures(Result() == expected_size(x))
    if x < 256:
        if x < 128:
            return 1
        else:
            return 3
    elif x < 1024:
        if x > 1022:
            return 4
        else:
            return 5
    else:
        if x < 2048:
            return 7
        else:
            return 9


# 1. The original fails exactly at x = 1023: both directions, read off the two
#    halves of its contract.
def original_panics_iff_expected(x: int) -> None:
    try:
        estimate_size_panic(x)
        assert not expected_panic(x)
    except Exception:
        assert expected_panic(x)


# 2. The failing input is corrected. Says nothing about any other input.
def corrected_at_1023() -> None:
    result = estimate_size_correction(1023)
    assert result == 4


# 3. Every output is an allowed size. True, and satisfied by a function that
#    returns 9 always.
def corrected_returns_allowed(x: int) -> None:
    result = estimate_size_correction(x)
    assert result == 1 or result == 3 or result == 4 or result == 5 \
        or result == 7 or result == 9


# 4. The value 4 occurs only at the repaired input, and does occur there.
def corrected_returns_four_iff(x: int) -> None:
    result = estimate_size_correction(x)
    assert (result == 4) == (x == 1023)


# 6. The correction changes x = 1023 and preserves every other result.
def correction_is_exact_patch(x: int) -> None:
    corrected = estimate_size_correction(x)
    if expected_panic(x):
        assert corrected == 4
    else:
        original = estimate_size_panic(x)
        assert original == corrected
