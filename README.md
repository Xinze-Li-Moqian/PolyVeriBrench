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
| `verification/rust_verification/kani/` | Kani | the real `src/estimate_size.rs`, via `include!` | the only backend reading the shipped source |
| `verification/rust_verification/verus/` | Verus | Verus-dialect Rust that compiles to the real binary | specs are erased, no second artifact |
| `verification/rust_verification/aeneas/` | Aeneas + Lean 4 | Lean mechanically translated from the Rust | trusts Charon/Aeneas instead of a human |

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

## Status

CI covers the two Lean projects. Not yet wired up:

- `verification/python_verification/` is empty.
- The Kani and Verus files have no `Cargo.toml` and no runner, so they are not
  built or checked automatically.
