// Iterative Fibonacci proved equal to its recursive specification.
// README.md covers what the invariants do and which one breaks when you drop one.

function FibSpec(n: nat): nat
{
  if n < 2 then n else FibSpec(n - 1) + FibSpec(n - 2)
}

method FibIter(n: nat) returns (r: nat)
  ensures r == FibSpec(n)
{
  if n < 2 {
    return n;
  }

  var a: nat := 0;
  var b: nat := 1;

  for i := 1 to n
    invariant a == FibSpec(i - 1)
    invariant b == FibSpec(i)
  {
    a, b := b, a + b;
  }

  return b;
}
