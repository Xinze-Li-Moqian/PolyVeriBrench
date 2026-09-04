def fib_iter_error_for (n : Nat) : Nat := Id.run do
  let mut a := 0
  let mut b := 1
  for _ in [1:n] do
    let next := a + b
    a := b
    b := next
  return b

-- Does not terminate for n >= 2: i is never incremented.
def fib_iter_error_while (n : Nat) : Nat := Id.run do
  if n < 2 then
    return n
  let mut a := 0
  let mut b := 1
  let i := 1
  while i < n do
    let next := a + b
    a := b
    b := next
  return b

def fib_iter_correction_for (n : Nat) : Nat := Id.run do
  if n < 2 then
    return n
  let mut a := 0
  let mut b := 1
  for _ in [1:n] do
    let next := a + b
    a := b
    b := next
  return b

def fib_iter_correction_while (n : Nat) : Nat := Id.run do
  if n < 2 then
    return n
  let mut a := 0
  let mut b := 1
  let mut i := 1
  while i < n do
    let next := a + b
    a := b
    b := next
    i := i + 1
  return b
