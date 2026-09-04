"""
Z3 decides the eight claims about `estimate_size`, over the unbounded integers.

Run it: `python3 verification/python_verification/z3/estimate_size.py`

This backend re-encodes the program as SMT formulas rather than reading the
shipped source, which puts it alongside Verus and the hand-written Lean file;
the CrossHair backend next door analyses the real `src/estimate_size.py`
directly, like Kani does for Rust. The re-encoding is a human step and thus a
gap, so `check_encoding_matches_source` at the bottom spot-checks the model
against the real functions at every boundary. That is a test, not a proof, and
is reported separately for exactly that reason.

Two things are different here from the u32 backends:

* `x` is an unbounded `Int`, so these claims quantify over all of Z, negatives
  included, where the Rust and Lean versions cover `0 .. 2**32 - 1`. Bit
  blasting -- what `bv_decide` and Kani ultimately do -- is not available on an
  infinite domain, so Z3 discharges these in linear integer arithmetic instead.
  The claims are correspondingly more general.

* SMT has no notion of an exception type or message, so `panics` is just a
  predicate here. Claim 7 in the Lean and Aeneas developments pins down *which*
  error is raised; the CrossHair backend is what covers that for Python, since
  it runs the real code and can inspect the exception object.
"""

import importlib.util
import pathlib
import sys

from z3 import And, If, Implies, Int, Not, Or, Solver, sat, unsat

SRC = pathlib.Path(__file__).resolve().parents[3] / "src" / "estimate_size.py"
PANIC_MESSAGE = "Oh no, a failing corner case!"


# -- the program, as formulas --------------------------------------------------

def panics(x):
    """When the original function raises: the guard is only reachable at 1023."""
    return And(Not(x < 256), x < 1024, x > 1022)


def original_value(x):
    """What the original returns. Meaningful only where `panics(x)` is false."""
    return If(x < 256,
              If(x < 128, 1, 3),
              If(x < 1024,
                 5,
                 If(x < 2048, 7, 9)))


def correction(x):
    """The corrected function: 4 where the original raised."""
    return If(x < 256,
              If(x < 128, 1, 3),
              If(x < 1024,
                 If(x > 1022, 4, 5),
                 If(x < 2048, 7, 9)))


def expected_size(x):
    """The complete output specification for the corrected function."""
    return If(x < 128, 1,
              If(x < 256, 3,
                 If(x < 1023, 5,
                    If(x == 1023, 4,
                       If(x < 2048, 7, 9)))))


def expected_panic(x):
    return x == 1023


# -- the ladder ----------------------------------------------------------------

x = Int("x")

CLAIMS = [
    ("original_panics_iff_expected",
     "the original fails exactly when x = 1023",
     panics(x) == expected_panic(x)),

    ("corrected_at_1023",
     "the failing input is corrected; says nothing about others",
     correction(1023) == 4),

    ("corrected_returns_allowed",
     "every output is an allowed size",
     Or(*[correction(x) == v for v in (1, 3, 4, 5, 7, 9)])),

    ("corrected_returns_four_iff",
     "4 occurs only at the repaired input, and does occur there",
     (correction(x) == 4) == expected_panic(x)),

    ("corrected_matches_spec",
     "for every int the corrected function follows expected_size",
     correction(x) == expected_size(x)),

    ("correction_is_exact_patch",
     "x = 1023 changes, every other result is preserved",
     And(Implies(expected_panic(x), correction(x) == 4),
         Implies(Not(expected_panic(x)),
                 And(Not(panics(x)), original_value(x) == correction(x))))),

    ("original_matches_result_spec",
     "the original's complete behaviour, its values and its one failure",
     And(panics(x) == expected_panic(x),
         Implies(Not(panics(x)), original_value(x) == expected_size(x)))),

    ("correction_is_total_refinement",
     "both functions compared in every case at once",
     And(Implies(Not(panics(x)), correction(x) == original_value(x)),
         Implies(panics(x), And(expected_panic(x), correction(x) == 4)))),
]


def prove(claim):
    """A claim holds iff its negation is unsatisfiable."""
    solver = Solver()
    solver.add(Not(claim))
    result = solver.check()
    if result == unsat:
        return True, ""
    if result == sat:
        model = solver.model()
        if not model.decls():
            # A claim with no free variables, e.g. the concrete one at 1023.
            return False, "false outright"
        assignment = ", ".join(
            "{} = {}".format(d.name(), model[d]) for d in model.decls())
        return False, "counterexample: " + assignment
    return False, "solver returned {}".format(result)


# -- does the encoding above match the program we actually ship? ---------------

BOUNDARIES = [-(10 ** 9), -1, 0, 1, 127, 128, 129, 255, 256, 257,
              1022, 1023, 1024, 1025, 2047, 2048, 2049, 10 ** 9]


def check_encoding_matches_source():
    """Spot-check the formulas against the real source at every boundary.

    The formulas above were written by hand from `src/estimate_size.py`, and
    nothing so far forces the two to agree. This does not close that gap -- it
    samples it. Kani and CrossHair are the backends that read the real source.
    """
    spec = importlib.util.spec_from_file_location("estimate_size_src", SRC)
    src = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(src)

    mismatches = []
    for v in BOUNDARIES:
        modelled_correction = correction(v)
        actual_correction = src.estimate_size_correction(v)
        if not is_true_int(modelled_correction, actual_correction):
            mismatches.append(
                "correction({}): model {} vs source {}".format(
                    v, modelled_correction, actual_correction))

        try:
            actual = src.estimate_size_panic(v)
            actually_raised = False
        except RuntimeError as exc:
            actual = None
            actually_raised = True
            if exc.args != (PANIC_MESSAGE,):
                mismatches.append("panic({}): unexpected message {!r}".format(v, exc.args))

        modelled_raise = solver_is_true(panics(v))
        if modelled_raise != actually_raised:
            mismatches.append(
                "panics({}): model {} vs source {}".format(
                    v, modelled_raise, actually_raised))
        elif not actually_raised and not is_true_int(original_value(v), actual):
            mismatches.append(
                "original({}): model {} vs source {}".format(
                    v, original_value(v), actual))

    return mismatches


def solver_is_true(formula):
    solver = Solver()
    solver.add(Not(formula))
    return solver.check() == unsat


def is_true_int(formula, value):
    return solver_is_true(formula == value)


def main():
    print("[z3] verification/python_verification/z3")
    print("  domain: unbounded Int (all of Z, negatives included)")

    width = max(len(name) for name, _, _ in CLAIMS)
    failures = 0
    for name, description, claim in CLAIMS:
        ok, detail = prove(claim)
        if not ok:
            failures += 1
        print("  {}  {}  {}{}".format(
            "ok  " if ok else "FAIL",
            name.ljust(width),
            description,
            "" if ok else "  <<{}>>".format(detail)))

    print("  {} claims | {} failing".format(len(CLAIMS), failures))

    mismatches = check_encoding_matches_source()
    if mismatches:
        print("  encoding vs source: {} mismatch(es) at {} boundary values"
              .format(len(mismatches), len(BOUNDARIES)))
        for m in mismatches:
            print("    <<{}>>".format(m))
    else:
        print("  encoding vs source: agrees at all {} boundary values (sampled, not proved)"
              .format(len(BOUNDARIES)))

    if failures or mismatches:
        print("  FAIL")
        return 1
    print("  PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
