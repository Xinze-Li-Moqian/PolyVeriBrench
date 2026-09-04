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
| `verification/dafny_verification/` | Dafny | 2 verified, 0 errors |

```sh
DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh fibonacci
```
