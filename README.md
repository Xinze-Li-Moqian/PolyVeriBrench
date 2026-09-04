# PolyVeriBrench

[![verify](https://github.com/Xinze-Li-Moqian/PolyVeriBrench/actions/workflows/verify.yml/badge.svg)](https://github.com/Xinze-Li-Moqian/PolyVeriBrench/actions/workflows/verify.yml)

A benchmark for comparing verification tools by pointing all of them at the same
program and asking them the same questions, in the same order, from a weak claim
to a complete one.

## Scenarios

| Scenario | Program | Backends |
|---|---|---|
| [`primitives/boundary/estimate_size`](scenarios/primitives/boundary/estimate_size/) | a size lookup that panics on exactly one input out of 2^32 | Lean, Aeneas, Kani, Verus, Z3, CrossHair, Nagini, Dafny |
| [`primitives/loops/binary_search`](scenarios/primitives/loops/binary_search/) | binary search: the midpoint overflow that shipped in the JDK for nine years | Dafny, Verus |
| [`primitives/loops/fibonacci`](scenarios/primitives/loops/fibonacci/) | an iterative loop proved equal to a recursive specification | Dafny, Lean |
| [`primitives/recursion/bst_delete`](scenarios/primitives/recursion/bst_delete/) | BST delete: the two-children case, where the value goes but the invariant breaks | Dafny |

Scenarios are grouped by what makes verification hard, not by what the program
does: `boundary/` is about the input space, `loops/` about unbounded control
flow, `recursion/` about unbounded data. Each scenario's README states the program, the claims, and which backend
proves which. This file is only about running them.

## Running the backends

### Lean

Both Lean projects build with [elan](https://github.com/leanprover/elan):

```sh
cd scenarios/primitives/boundary/estimate_size && lake build
cd scenarios/primitives/boundary/estimate_size/verification/rust_verification/aeneas && lake build
```

The Aeneas project depends on Mathlib. Fetch prebuilt oleans rather than
compiling it: `lake exe cache get`.

### Python

```sh
pip install -r scenarios/primitives/boundary/estimate_size/verification/python_verification/requirements.txt
./scripts/check_python.sh             # both backends
./scripts/check_python.sh crosshair   # or just one
```

### Rust

```sh
cargo install --locked kani-verifier && cargo kani setup
./scripts/check_rust.sh kani
```

Verus ships as a release archive rather than a cargo install, and it refuses to
start unless the exact rustc named in its `version.json` is installed. Download
the archive for your platform from [verus-lang/verus releases][verus-releases],
then:

```sh
rustup toolchain install "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["verus"]["toolchain"])' path/to/verus-dist/version.json)"
VERUS=path/to/verus-dist/verus ./scripts/check_rust.sh verus
```

[verus-releases]: https://github.com/verus-lang/verus/releases

### Nagini

Needs Java 11+ (Viper's backends are Scala) and Python 3.12-3.14:

```sh
pip install -r scenarios/primitives/boundary/estimate_size/verification/python_verification/nagini/requirements.txt
./scripts/check_python.sh nagini
```

### Dafny

Dafny ships as a self-contained release archive. Grab the one for your platform
from [dafny-lang/dafny releases][dafny-releases], then:

```sh
DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh
```

[dafny-releases]: https://github.com/dafny-lang/dafny/releases

## Axiom audit

```sh
./scripts/check_axioms.sh            # every Lean project
./scripts/check_axioms.sh native     # or just one
```

`grep sorry` cannot see what a proof actually rests on: a theorem can be closed
by a tactic that defers to an external oracle, or by a lemma admitted somewhere
in a dependency. The vendored Aeneas standard library contains several `sorry`s
of its own, so that is a live possibility here rather than a hypothetical.

The audit walks every theorem in each module via `collectAxioms` and classifies
what it depends on. It fails on `sorryAx`, on `native_decide`'s compiler axioms,
and on any axiom the policy does not recognise. `bv_decide`'s SAT certificates
pass but are counted, because they are a real external dependency worth keeping
visible.

## CI

[`.github/workflows/verify.yml`](.github/workflows/verify.yml) runs every
backend on each push. The Aeneas job is the slow one -- it pulls Mathlib -- and
is kept in its own job so a broken hand-written proof reports in seconds rather
than minutes.
