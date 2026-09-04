def fib_iter_error (n : Nat) : Nat := Id.run do
  let mut a := 0
  let mut b := 1
  for _ in [1:n] do
    let next := a + b
    a := b
    b := next
  return b

def fib_iter_correction (n : Nat) : Nat := Id.run do
  if n < 2 then
    return n
  let mut a := 0
  let mut b := 1
  for _ in [1:n] do
    let next := a + b
    a := b
    b := next
  return b
