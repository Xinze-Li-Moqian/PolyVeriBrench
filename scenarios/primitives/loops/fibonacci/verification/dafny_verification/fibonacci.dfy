/*
Fibonacci: an iterative implementation proved equal to a recursive specification.

This is a loop scenario like binary_search, but the invariant does a different
job, and that difference is the reason for having both.

In binary_search the invariant narrows a window: it tracks what the loop has
ruled out, so that finishing the loop says something about the whole array.
There is no second program -- the specification is a property (`key !in a`).

Here there are two programs. FibSpec is the definition: recursive, exponential,
and never meant to run. FibIter is the implementation: a linear loop with two
accumulators that looks nothing like the definition. The invariant is the bridge
between them -- it says what the loop variables mean in terms of the spec, at
every step. That shape (a slow obvious definition, a fast unobvious
implementation, an invariant connecting them) is most of what verification of
real code looks like.

It also brings in a distinction estimate_size and binary_search never needed:
`function` versus `method`. FibSpec is a function, so it may appear in
specifications; it is a mathematical object. FibIter is a method, so it has a
body that executes and cannot appear in a spec. The two are related only by the
postcondition.

Run with:

    dafny verify fibonacci.dfy
*/

/* -- The specification ---------------------------------------------------- */

// Exponential to evaluate, which does not matter: it is a definition, not code.
// Its only job is to be obviously right.
function FibSpec(n: nat): nat
{
  if n < 2 then n else FibSpec(n - 1) + FibSpec(n - 2)
}

/* -- The implementation --------------------------------------------------- */

method FibIter(n: nat) returns (r: nat)
  ensures r == FibSpec(n)
{
  if n < 2 {
    return n;
  }

  var a: nat := 0;   // FibSpec(0)
  var b: nat := 1;   // FibSpec(1)
  var i: nat := 1;

  while i < n
    invariant 1 <= i <= n
    // The bridge. Without these two lines the loop is still correct and still
    // terminates; what is lost is any way to say what a and b are.
    invariant a == FibSpec(i - 1)
    invariant b == FibSpec(i)
    decreases n - i
  {
    a, b := b, a + b;
    i := i + 1;
  }

  return b;
}

/*
Why the step goes through, since it is the whole proof:

At the top of an iteration the invariant gives `a == FibSpec(i-1)` and
`b == FibSpec(i)`. After `a, b := b, a + b`:

    new a  ==  old b        ==  FibSpec(i)
    new b  ==  old a + b    ==  FibSpec(i-1) + FibSpec(i)

and then `i` becomes `i+1`, so the two claims to re-establish are
`new a == FibSpec(i)` -- immediate -- and `new b == FibSpec(i+1)`. That last one
is exactly the recursive case of FibSpec, available because `i >= 1` means
`i + 1 >= 2`. The proof is the definition, unfolded once, in the right place.

Only one of the two invariants is the one anybody wanted. `b == FibSpec(i)` is
what makes the postcondition work: the loop ends with `i == n`, so `b` is the
answer. `a == FibSpec(i - 1)` says nothing about the result at all.

Try deleting the one that looks redundant, and read which error appears:

    Error: this invariant could not be proved to be maintained by the loop
      invariant b == FibSpec(i)

The complaint is not about the line that was deleted. It is about the line that
was kept. `b == FibSpec(i)` cannot survive an iteration on its own, because the
new b is `a + b`, and without knowing what `a` is there is nothing to conclude.
The invariant everybody wanted is not inductive by itself.

Deleting the other one is symmetric -- `a == FibSpec(i - 1)` then fails to be
maintained, because the new a is the old b -- with one extra error, since that
is the clause the postcondition was leaning on.

This is the central move in verifying loops, and it is not obvious the first
time. The property you want is rarely the property you can carry: it has to be
strengthened, with extra clauses that are of no interest on their own, until
what remains is closed under one iteration. Then the invariant proves itself and
gives you the postcondition on the way out. Half an inductive invariant does not
get you half the proof -- here it gets you an error on the other half.
*/
