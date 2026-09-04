-- Original implementation; `.error` represents the panic branch.
def estimate_size_panic (x : UInt32) : Except String UInt32 :=
  if x < 256 then
    if x < 128 then
      .ok 1
    else
      .ok 3
  else if x < 1024 then
    if x > 1022 then
      .error "Oh no, a failing corner case!"
    else
      .ok 5
  else
    if x < 2048 then
      .ok 7
    else
      .ok 9

-- Corrected implementation for every UInt32 input.
def estimate_size_correction (x : UInt32) : UInt32 := Id.run do
  if x < 256 then
    if x < 128 then
      return 1
    else
      return 3
  else if x < 1024 then
    if x > 1022 then
      return 4
    else
      return 5
  else
    if x < 2048 then
      return 7
    else
      return 9
