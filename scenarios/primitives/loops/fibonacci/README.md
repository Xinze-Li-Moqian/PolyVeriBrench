# fibonacci

An iterative implementation proved equal to a recursive specification.

This is a loop scenario like `binary_search`, but the invariant does a different
job, which is the reason for having both.

In `binary_search` the invariant narrows a window: it records what the loop has
ruled out, so that finishing the loop says something about the whole array.
There is only one program there -- the specification is a property, `key !in a`.

Here there are two programs:

```dafny
function FibSpec(n: nat): nat            // the definition: recursive, exponential,
{ if n < 2 then n                        // never meant to run, obviously right
  else FibSpec(n-1) + FibSpec(n-2) }

method FibIter(n: nat) returns (r: nat)  // the implementation: linear, two
  ensures r == FibSpec(n)                // accumulators, looks nothing like it
```

The invariant is the bridge. It says what the loop variables mean in terms of
the spec, at every step. A slow obvious definition, a fast unobvious
implementation, and an invariant connecting them is most of what verifying real
code looks like.

It also brings in a distinction the earlier scenarios never needed: `function`
versus `method`. `FibSpec` is a function, so it may appear in specifications --
it is a mathematical object. `FibIter` is a method: it has an executing body and
cannot appear in a spec. The postcondition is the only thing relating them.

## The lesson: the invariant you want is not inductive

Two clauses carry the loop:

```dafny
invariant a == FibSpec(i - 1)
invariant b == FibSpec(i)
```

Only the second is of any interest. The loop ends with `i == n`, so `b` is the
answer; `a == FibSpec(i - 1)` says nothing about the result.

Delete the uninteresting one and read which line Dafny complains about:

```
Error: this invariant could not be proved to be maintained by the loop
  invariant b == FibSpec(i)
```

Not the deleted line. The one that was kept. `b == FibSpec(i)` cannot survive an
iteration by itself, because the new `b` is `a + b` and there is nothing known
about `a`. Deleting the other clause is symmetric, plus one extra error, since
that is the one the postcondition leans on.

That is the central move in verifying loops: the property you want is rarely the
property you can carry. It has to be strengthened with clauses that are useless
on their own until what remains is closed under one iteration. Half an inductive
invariant does not get you half a proof.

## Backends

| Path | Tool | Status |
|---|---|---|
| `verification/dafny_verification/` | Dafny | 3 verified, 0 errors |
| `verification/lean_verification/` | Lean 4 + `mvcgen` | 10 theorems, standard axioms only |

```sh
DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh fibonacci
cd scenarios/primitives/loops/fibonacci && lake build
./scripts/check_axioms.sh fibonacci
```

### What Lean needed that Dafny did not

`estimate_size` was proved in Lean by throwing `bv_decide` at it -- 2^32 cases,
bit-blasted to SAT, no thought required. That does not work here: the input is
unbounded and the program is a loop, so there is nothing to enumerate.

The tool for this is `mvcgen`, the verification-condition generator in
`Std.Do`. It works the way Dafny does -- state the goal, supply the loop
invariant, discharge what comes back -- with two steps of setup Dafny does not
need, to turn `Id.run do ...` into a Hoare triple:

```lean
generalize h : fib_iter_correction_for n = res
apply Id.of_wp_run_eq h
mvcgen invariants
  | inv1 => ⇓⟨xs, ab⟩ => ⌜ab.1 = fib_spec xs.prefix.length ∧
                           ab.2 = fib_spec (xs.prefix.length + 1)⌝
```

The `for`/`while` difference shows up as what `mvcgen` asks for. The `for`
version leaves one hole, `inv1`. The `while` version leaves two:

```
case inv1 ⊢ WhileVariant (Nat × Nat × Nat) PostShape.pure
case inv2 ⊢ WhileInvariant (Nat × Nat × Nat) (Nat × Nat × Nat) PostShape.pure
```

`WhileVariant` is the termination measure -- Dafny's `decreases`, under another
name. And `mvcgen?`, which prints a suggested invariant skeleton for the `for`
loop, says only "There were no suggestions for missing invariants" for the
`while` one.

Two smaller notes. `rfl` and `decide` cannot evaluate these functions at all,
even on a literal like `fib_iter_correction_for 10`: the kernel gets stuck on
`forIn`. `native_decide` would work and is the obvious escape hatch -- it also
introduces `Lean.ofReduceBool`, which `scripts/check_axioms.sh` rejects. The
proofs here depend on nothing beyond `propext`, `Classical.choice`, and
`Quot.sound`.
