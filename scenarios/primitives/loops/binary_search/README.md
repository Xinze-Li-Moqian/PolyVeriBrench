# binary_search

The first scenario here with a loop, which is the point of it.

`estimate_size` is straight-line branching. Seven backends proved all eight
claims about it with every lemma body empty -- the tools did the work because
there was a finite number of paths to enumerate. A loop removes that. There are
infinitely many executions, the verifier cannot walk them, and it needs an
inductive invariant instead. Finding that invariant is not something a tool does
for you. This scenario is where the proofs stop being `{ }`.

## The program

Binary search over a sorted array, returning whether the key was found and where.

## Two defects, and they fail differently

### 1. The midpoint overflow

```
mid := (lo + hi) / 2        // wrong
mid := lo + (hi - lo) / 2   // right
```

Joshua Bloch found this in `java.util.Arrays` in 2006, where it had shipped for
nine years ([*Nearly All Binary Searches and Mergesorts are
Broken*][bloch]). It needs an array of more than 2^30 elements to fire, so no
test suite was ever going to catch it.

That is the same shape as `estimate_size`'s bug -- one unreachable-looking case
that testing cannot reach -- except this one was real, in a standard library,
for nine years.

Because indices here are a bounded `uint32` rather than Dafny's unbounded `int`,
`lo + hi` is itself a proof obligation. Write the naive form and verification
fails **on that line**:

```
Error: result of operation might violate newtype constraint for 'uint32'
```

Not a wrong answer discovered downstream. An arithmetic obligation that fails
where it is written.

[bloch]: https://research.google/blog/extra-extra-read-all-about-it-nearly-all-binary-searches-and-mergesorts-are-broken/

### 2. The missing invariant

The interesting postcondition is not `found ==> a[index] == key`. That one is
easy: you just looked at that element. It is the negative answer:

```dafny
ensures !found ==> key !in a
```

Finishing the loop tells you the key is not in the *window*. Concluding it is
not in the *array* needs more, and that "more" is the invariant:

```dafny
invariant key in a ==> key in a[lo as int .. hi as int]
```

Delete it and Dafny reports:

```
Error: a postcondition could not be proved on this return path
Related location: this is the postcondition that could not be proved
  ensures !found ==> key !in a
```

Where the complaint lands is the lesson. Not on the loop -- the loop is fine,
and the code still returns the right answer on every input you would ever run.
What breaks is the ability to conclude anything about the array from having
finished the loop.

Termination is a separate obligation again, discharged by `decreases hi - lo`.
In `estimate_size` the Aeneas backend's `.div => False` case was free, because a
branching function cannot fail to terminate. Here it would not be.

## Backends

| Path | Tool | Status |
|---|---|---|
| `verification/dafny_verification/` | Dafny | 7 verified, 0 errors |

Only Dafny so far, on purpose. The comparison across seven tools is worth
building once the invariant is understood, and it is a different comparison than
`estimate_size` produced -- this is where Kani needs an `#[kani::unwind(N)]` and
becomes bounded, and where CrossHair stops being able to exhaust the path tree.

```sh
DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh binary_search
```
