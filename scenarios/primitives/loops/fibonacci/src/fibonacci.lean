def fib_spec : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib_spec n + fib_spec (n + 1)

def fib_iter (n : Nat) : Nat := Id.run do
  if n < 2 then
    return n
  let mut a := 0
  let mut b := 1
  for _ in [1:n] do
    let next := a + b
    a := b
    b := next
  return b
