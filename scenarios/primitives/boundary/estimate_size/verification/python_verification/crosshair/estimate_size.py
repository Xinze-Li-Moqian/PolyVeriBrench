"""
CrossHair checks the real `src/estimate_size.py` -- the same file the project
ships, loaded here rather than transcribed. That makes this the Python
counterpart of the Kani backend, which `include!`s the real `.rs`; the Z3
backend next door re-encodes the program instead, like the Verus and
hand-written Lean ones do.

Run with:

    crosshair check --analysis_kind=PEP316 <this file>

Each claim below is a function whose docstring carries a `post:` condition.
CrossHair executes the body on symbolic integers and reports any input that
violates the postcondition or raises an undeclared exception.

What that buys depends on the program. CrossHair searches rather than decides,
so in general a clean run means "no counterexample found within the budget".
Here it means more: this program is straight-line branching with no loops, and
`--verbose` reports `Exhausted calltree search with CONFIRMED` for every claim,
six paths each -- one per branch. Every execution path was enumerated and its
path condition discharged, so on this program the result is conclusive rather
than merely inconclusive-and-clean. Put a loop in the source and that stops
being true, which is the difference between this backend and the Z3 one.

The ladder is the same one the other backends prove, with a difference worth
stating: Python's `int` is unbounded, so `x` here ranges over all of Z,
negatives included, where the Rust and Lean versions range over
`0 .. 2**32 - 1`. These claims are therefore strictly more general -- and
exhaustive enumeration, which is what `bv_decide` and Kani ultimately do, is
not even available as a strategy.
"""

import importlib.util
import pathlib

_SRC = pathlib.Path(__file__).resolve().parents[3] / "src" / "estimate_size.py"
_spec = importlib.util.spec_from_file_location("estimate_size_src", _SRC)
_src = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_src)

estimate_size_panic = _src.estimate_size_panic
estimate_size_correction = _src.estimate_size_correction

PANIC_MESSAGE = "Oh no, a failing corner case!"


def expected_size(x: int) -> int:
    """The complete output specification for the corrected function.

    x < 128 -> 1, x < 256 -> 3, x < 1023 -> 5, x == 1023 -> 4,
    x < 2048 -> 7, otherwise 9. Unlike the u32 backends this covers negative
    x too, which land in the first case.
    """
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


def original_panics_iff_expected(x: int) -> bool:
    """Claim 1: the original function fails exactly when x = 1023.

    post: __return__ == (x == 1023)
    """
    try:
        estimate_size_panic(x)
        return False
    except RuntimeError:
        return True


def corrected_at_1023() -> int:
    """Claim 2: the failing input is corrected. Says nothing about others.

    post: __return__ == 4
    """
    return estimate_size_correction(1023)


def corrected_returns_allowed(x: int) -> int:
    """Claim 3: the output is always an allowed size.

    This restricts the possible outputs without saying which input gives which.

    post: __return__ in (1, 3, 4, 5, 7, 9)
    """
    return estimate_size_correction(x)


def corrected_returns_four_iff(x: int) -> int:
    """Claim 4: the value 4 occurs only at the repaired input, and does occur there.

    post: (__return__ == 4) == (x == 1023)
    """
    return estimate_size_correction(x)


def corrected_matches_spec(x: int) -> int:
    """Claim 5: for every int, the corrected function follows `expected_size`.

    post: __return__ == expected_size(x)
    """
    return estimate_size_correction(x)


def correction_is_exact_patch(x: int) -> bool:
    """Claim 6: the correction changes x = 1023 and preserves every other result.

    At any other input the original must not raise, and must agree with the
    corrected function -- an escaping RuntimeError fails this too.

    post: __return__
    """
    corrected = estimate_size_correction(x)
    if x == 1023:
        return corrected == 4
    return estimate_size_panic(x) == corrected


def original_matches_result_spec(x: int) -> bool:
    """Claim 7: the original function's complete behaviour.

    Which value it returns everywhere and -- unlike claim 1, which records only
    *that* it fails -- the exact exception type and message it fails with.

    post: __return__
    """
    try:
        returned = estimate_size_panic(x)
    except RuntimeError as exc:
        return (
            x == 1023
            and type(exc) is RuntimeError
            and exc.args == (PANIC_MESSAGE,)
        )
    return x != 1023 and returned == expected_size(x)


def correction_is_total_refinement(x: int) -> bool:
    """Claim 8: the whole repair relationship in one statement.

    Split on what the original actually did rather than on the `x == 1023`
    predicate, so it reads as a refinement: whatever the original produced,
    here is what the corrected function produces.

    post: __return__
    """
    corrected = estimate_size_correction(x)
    try:
        returned = estimate_size_panic(x)
    except RuntimeError as exc:
        return exc.args == (PANIC_MESSAGE,) and x == 1023 and corrected == 4
    return corrected == returned
