# PolyVeriBrench

[![verify](https://github.com/Xinze-Li-Moqian/PolyVeriBrench/actions/workflows/verify.yml/badge.svg)](https://github.com/Xinze-Li-Moqian/PolyVeriBrench/actions/workflows/verify.yml)

A benchmark for comparing verification tools by pointing all of them at the same
program and asking them the same questions, in the same order, from a weak claim
to a complete one.

## The program

`scenarios/estimate_size/src/` holds one function written three times, in Python,
Rust, and Lean. It maps an input to a size:

```rust
fn estimate_size_panic(x: u32) -> u32 {
    if x < 256 {
        if x < 128 { return 1 } else { return 3 }
    } else if x < 1024 {
        if x > 1022 { panic!("Oh no, a failing corner case!") } else { return 5 }
    } else {
        if x < 2048 { return 7 } else { return 9 }
    }
}
```

The outer branch already constrains `x < 1024`, so the inner `x > 1022` guard can
only fire at `x = 1023`. That single input is the bug. `estimate_size_correction`
returns `4` there instead of panicking.

## The claims

Each backend proves the same ladder:

| # | Claim |
|---|---|
| 1 | The original function fails exactly when `x = 1023` |
| 2 | The corrected function returns 4 at `x = 1023` |
| 3 | Every corrected result is one of 1, 3, 4, 5, 7, 9 |
| 4 | The corrected result is 4 exactly when `x = 1023` |
| 5 | The corrected function matches the full specification on every input |
| 6 | The correction changes `x = 1023` and preserves every other result |
| 7 | The *original* function's complete result, its values and its one failure |
| 8 | Original and corrected compared in every case at once |

Claims 1-6 pin down the corrected function but leave the original one only
partially specified -- claim 1 records *that* it fails, never what it returns
elsewhere or which error it raises. Claims 7 and 8 close that gap.

## The backends

| Path | Tool | Verifies | Notes |
|---|---|---|---|
| `verification/lean_verification/` | Lean 4 + `bv_decide` | a hand-written Lean transcription of the program | the transcription step is unverified |
| `verification/rust_verification/kani/` | Kani | the real `src/estimate_size.rs`, via `include!` | reads the shipped source |
| `verification/rust_verification/verus/` | Verus | Verus-dialect Rust that compiles to the real binary | specs are erased, no second artifact |
| `verification/rust_verification/aeneas/` | Aeneas + Lean 4 | Lean mechanically translated from the Rust | trusts Charon/Aeneas instead of a human |
| `verification/python_verification/z3/` | Z3 | a hand-written SMT re-encoding | decides the claims outright |
| `verification/python_verification/crosshair/` | CrossHair | the real `src/estimate_size.py` | reads the shipped source |

Each language has one backend that reads the real source and one that works from
a transcription. That split is the interesting axis: a transcription puts an
unverified human step between the program and the theorem, and reading the real
source moves that step into a tool instead of removing it.

The Python backends also quantify over a larger domain. `int` is unbounded, so
they range over all of Z, negatives included, where the Rust and Lean versions
cover `0 .. 2**32 - 1`. Bit blasting -- what `bv_decide` and Kani ultimately do
-- is not available on an infinite domain, so Z3 discharges these in linear
integer arithmetic instead.

Aeneas models the whole outcome -- return, panic, and non-termination -- as one
first-class `Result` value, so claim 8 there carries a third case, `.div =>
False`, asserting the function does not diverge. The hand-written Lean version
has no counterpart: Lean functions are total by construction, so the absence of
divergence is enforced by the elaborator rather than proved. It is assumed
silently at transcription time.

## Running it

Both Lean projects build with [elan](https://github.com/leanprover/elan):

```sh
cd scenarios/estimate_size && lake build
cd scenarios/estimate_size/verification/rust_verification/aeneas && lake build
```

The Aeneas project depends on Mathlib. Fetch prebuilt oleans rather than
compiling it: `lake exe cache get`.

The Python backends need two pinned tools:

```sh
pip install -r scenarios/estimate_size/verification/python_verification/requirements.txt
./scripts/check_python.sh             # both
./scripts/check_python.sh crosshair   # or just one
```

CrossHair searches rather than decides, so in general a clean run means "no
counterexample found within the budget". On this program it means more: run it
with `--verbose` and it reports `Exhausted calltree search with CONFIRMED` for
every claim, six paths each -- one per branch. There are no loops, so every
execution path is enumerated and its path condition discharged. Add a loop and
that stops holding, which is what separates it from the Z3 backend.

### Axiom audit

```sh
./scripts/check_axioms.sh            # every project
./scripts/check_axioms.sh native     # or just one
```

`grep sorry` cannot see what a proof actually rests on: a theorem can be closed
by a tactic that defers to an external oracle, or by a lemma admitted somewhere
in a dependency. The vendored Aeneas standard library contains several `sorry`s
of its own, so that is a live possibility here rather than a hypothetical.

This walks every theorem in each module via `collectAxioms` and classifies what
it depends on. It fails on `sorryAx`, on `native_decide`'s compiler axioms, and
on any axiom the policy does not recognise. `bv_decide`'s SAT certificates pass
but are counted, because they are a real external dependency worth watching:

```
[native] scenarios/estimate_size
  8 theorems | 38 SAT certificate axioms | 0 failing
[aeneas] scenarios/estimate_size/verification/rust_verification/aeneas
  8 theorems | 0 SAT certificate axioms | 0 failing
```

The hand-written proofs lean on cadical for 7 of their 8 theorems. The Aeneas
proofs use `scalar_tac`, which stays inside Lean, and depend on nothing beyond
`propext`, `Classical.choice`, and `Quot.sound`. On the trusted-base axis the
translated side is the cleaner of the two -- the opposite of what the extra
translation layer suggests, and a distinction worth keeping visible.

### Rust backends

```sh
cargo install --locked kani-verifier && cargo kani setup
./scripts/check_rust.sh kani
```

Verus is a release archive rather than a cargo install, and it pins an exact
rustc that must be present or it refuses to start. Download the archive for
your platform from [verus-lang/verus releases][verus-releases], then:

```sh
rustup toolchain install "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["verus"]["toolchain"])' path/to/verus-dist/version.json)"
VERUS=path/to/verus-dist/verus ./scripts/check_rust.sh verus
```

[verus-releases]: https://github.com/verus-lang/verus/releases

## Status

CI runs all five backends on every push: both Lean projects, both Python
backends, Kani, and Verus.

The ladder is not evenly covered. Claims 7 and 8 exist in the Lean, Aeneas,
Python, and (for 7) Verus backends; Kani has neither as a single harness, and
that is a property of the tool rather than an omission. `#[kani::should_panic]`
is a harness attribute, not a proposition, so it cannot appear inside a formula
or be conjoined with anything -- which is why claim 1 is already split there
into `original_panics_at_1023` and `original_does_not_panic_elsewhere`.
