-- `(lo + hi) / 2` is correct here: Nat is unbounded, so the midpoint cannot
-- overflow. The same line is a bug in binary_search.rs.
partial def binarySearch (a : Array Int) (key : Int) : Option Nat := Id.run do
  let mut lo := 0
  let mut hi := a.size
  while lo < hi do
    let mid := (lo + hi) / 2
    if a[mid]! < key then
      lo := mid + 1
    else if a[mid]! > key then
      hi := mid
    else
      return some mid
  return none
