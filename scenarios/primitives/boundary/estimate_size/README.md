# estimate_size

One function with a bug that fires on exactly one input out of 2^32, written
three times, and checked by seven verification backends asked the same eight
questions.

## The function

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

The outer branch already constrains `x < 1024`, so the inner `x > 1022` guard
can only fire at `x = 1023`. That single input is the bug.
`estimate_size_correction` returns `4` there instead of panicking.

`src/` holds all three versions of both functions:

| File                   | Notes                                            |
| ---------------------- | ------------------------------------------------ |
| `estimate_size.py`   | `x: int`, so unbounded -- negatives included   |
| `estimate_size.rs`   | `x: u32`; the panic is a real `panic!`       |
| `estimate_size.lean` | `Except String UInt32` models the panic branch |

## What is verified

Eight claims, ordered from a weak one to a complete one. The point of the order
is that the early ones are easy to mistake for the later ones:

| # | Claim                                                                             | What the previous ones still allow     |
| - | --------------------------------------------------------------------------------- | -------------------------------------- |
| 1 | The original fails exactly when`x = 1023`                                       | nothing yet about what it returns      |
| 2 | The corrected function returns 4 at`x = 1023`                                   | every other input unconstrained        |
| 3 | Every corrected result is one of 1, 3, 4, 5, 7, 9                                 | any input could give any of them       |
| 4 | The corrected result is 4 exactly when`x = 1023`                                | the other five values unassigned       |
| 5 | The corrected function matches the full spec on every input                       | says nothing about the original        |
| 6 | The correction changes`x = 1023` and preserves every other result               | the original's failure is still opaque |
| 7 | The *original's* complete result: its values and which error it raises | --                                     |
| 8 | Original and corrected compared in every case at once                             | --                                     |

Claims 1-6 pin the corrected function down completely but leave the original one
only partially specified: claim 1 records *that* it fails, never what it returns
elsewhere or which error it raises. Claims 7 and 8 close that gap.

The full output specification the later claims refer to:

```
x < 128       -> 1        x = 1023      -> 4   (was the panic)
128 <= x < 256 -> 3       1024 <= x < 2048 -> 7
256 <= x < 1023 -> 5      x >= 2048     -> 9
```

## Coverage

| # | Lean | Aeneas | Kani | Verus | Z3 | CrossHair | Dafny |
| - | :--: | :----: | :--: | :---: | :-: | :-------: | :---: |
| 1 | ✓ | ✓ | ✓ (split) | ✓ | ✓ | ✓ | ✓ |
| 2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 5 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 6 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 7 | ✓ | ✓ | — | ✓ (as `ensures`) | ✓ (no error identity) | ✓ | ✓ |
| 8 | ✓ | ✓ + `.div` | — | — | ✓ | ✓ | ✓ |

Where the table is not full, the reason is usually the tool rather than the
effort:

**Kani cannot state claims 7 or 8 as one harness.** `#[kani::should_panic]` is a
harness attribute, not a proposition, so it cannot appear inside a formula or be
conjoined with anything. That is already why claim 1 is split there into
`original_panics_at_1023` and `original_does_not_panic_elsewhere` -- two
harnesses for what the other backends write as a single `iff`.

**Aeneas states more of claim 8 than anyone else.** It models the whole outcome
-- return, panic, and non-termination -- as one first-class `Result`, so its
claim 8 carries a third case, `.div => False`, asserting the function does not
diverge. The hand-written Lean version has no counterpart, and the reason is
worth stating: Lean functions are total by construction, so the absence of
divergence there is not proved, it is assumed silently when the program is
transcribed into Lean.

**Z3 has no notion of an exception,** so its claim 7 pins the values but not
which error is raised. CrossHair covers that for Python, because it runs the
real code and can inspect the exception object.

**Dafny can make the bug unreachable instead of proving things about it.**
Alongside the eight claims its file carries `EstimateSizePanicPartial`: the same
function with `requires x != 1023` in its signature and no `Result` type at all.
Written that way the failing input is not handled, it is excluded, and every
caller has to discharge the precondition. Which framing is honest depends on
whether 1023 is a caller error or a defect in the function -- and Dafny is the
only backend here that makes you answer that in the signature rather than in a
proof.

## The backends

| Path                                            | Tool                  | What it actually reads                              |
| ----------------------------------------------- | --------------------- | --------------------------------------------------- |
| `verification/lean_verification/`             | Lean 4 +`bv_decide` | a hand-written Lean transcription                   |
| `verification/rust_verification/kani/`        | Kani                  | the real`src/estimate_size.rs`, via `include!`  |
| `verification/rust_verification/verus/`       | Verus                 | Verus-dialect Rust that compiles to the real binary |
| `verification/rust_verification/aeneas/`      | Aeneas + Lean 4       | Lean mechanically translated from the Rust          |
| `verification/python_verification/z3/`        | Z3                    | a hand-written SMT re-encoding                      |
| `verification/python_verification/crosshair/` | CrossHair             | the real`src/estimate_size.py`                    |
| `verification/python_verification/nagini/` | Nagini (Viper) | annotated Python carrying its own contracts |
| `verification/dafny_verification/` | Dafny | a program that exists only in Dafny |

Python and Rust each have one backend that reads the real source and one that
works from a transcription. That is the axis worth watching: a transcription
puts an unverified human step between the program and the theorem. Reading the
real source moves that step into a tool rather than removing it -- Aeneas trades
a human transcriber for Charon plus its own translation, neither of which is
verified either.

Dafny sits at the far end of that axis, alone. Its program exists only in Dafny;
nothing connects it to what the project ships but a human having written the
same branches twice. What it gets in exchange is that the program, the
specification, and the proofs are one artifact in one language, with the
verifier part of the compiler rather than bolted on -- which is why it reaches
8/8 in under a second with every lemma body empty.

Two differences in what is being quantified over:

- The Python backends range over all of **Z**, negatives included, where the
  Rust and Lean ones cover `0 .. 2**32 - 1`. Bit blasting -- what `bv_decide`
  and Kani ultimately do -- is not available on an infinite domain, so Z3 works
  in linear integer arithmetic instead. The Python claims are strictly more
  general.
- CrossHair searches rather than decides, so a clean run normally means only
  "no counterexample within the budget". Here it means more: `--verbose` reports
  `Exhausted calltree search with CONFIRMED` for every claim, six paths each,
  one per branch. No loops, so every path is enumerated and discharged. Add a
  loop and that stops being true.

## Results

Everything passes. The two Lean developments also get an axiom audit, which
reports what the proofs actually rest on:

```
[native] scenarios/estimate_size
  8 theorems | 38 SAT certificate axioms | 0 failing
[aeneas]  .../rust_verification/aeneas
  8 theorems |  0 SAT certificate axioms | 0 failing
```

The hand-written proofs lean on cadical for 7 of their 8 theorems; only
`corrected_at_1023` is axiom-free, and it is a `rfl`. The Aeneas proofs use
`scalar_tac`, which stays inside Lean, and depend on nothing beyond `propext`,
`Classical.choice`, and `Quot.sound`.

So on the trusted-base axis the *translated* side is the cleaner of the two.
That is the opposite of what the extra translation layer suggests, and the two
things are not in tension: Aeneas adds an unverified step in front of the
theorem and removes an external oracle from behind it.

Kani reports 7 harnesses (claim 1 costs two), Verus reports 8 verified items
(6 checks plus the two function contracts), Z3 decides 8 claims and spot-checks
its encoding against the real source at 18 boundary values, CrossHair exhausts
the path tree on all 8, and Dafny reports 22 verified -- the 8 claims, the
partial-function variant and its lemma, and the well-formedness obligations on
every function and on the `uint32` newtype itself.

See the [repository README](../../README.md) for how to run any of this.
