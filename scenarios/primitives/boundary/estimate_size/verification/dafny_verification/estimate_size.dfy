/*
Dafny sits at the far end of the axis this benchmark is built around.

Kani and CrossHair read the program the project ships. Verus annotates Rust that
still compiles to the real binary. Aeneas translates the real Rust mechanically.
Dafny does none of those: the program has to be rewritten in Dafny, so the
transcription is a human step with nothing checking it -- the same position the
hand-written Lean and Z3 backends are in. What it buys in exchange is that the
program, the specification, and the proofs are one artifact in one language,
with the verifier built into the compiler rather than bolted on.

Run with:

    dafny verify estimate_size.dfy

`uint32` is a newtype over the integers rather than a bitvector, which keeps the
domain identical to the Rust and Lean backends (0 .. 2^32 - 1) while leaving the
proof obligations in linear integer arithmetic. The Python backends, by
contrast, range over all of Z.

`Result` mirrors the `Except String UInt32` the hand-written Lean file uses, so
the failure carries its message and claim 7 can pin down not just that the
original fails but what it fails with.
*/

newtype uint32 = x: int | 0 <= x < 0x1_0000_0000 witness 0

datatype Result = Success(value: uint32) | Failure(error: string)

const PanicMessage: string := "Oh no, a failing corner case!"

// The original: the inner guard is only reachable at x = 1023.
function EstimateSizePanic(x: uint32): Result
{
  if x < 256 then
    if x < 128 then Success(1) else Success(3)
  else if x < 1024 then
    if x > 1022 then Failure(PanicMessage) else Success(5)
  else
    if x < 2048 then Success(7) else Success(9)
}

// The corrected function: 4 where the original failed.
function EstimateSizeCorrection(x: uint32): uint32
{
  if x < 256 then
    if x < 128 then 1 else 3
  else if x < 1024 then
    if x > 1022 then 4 else 5
  else
    if x < 2048 then 7 else 9
}

// The bug specification: 1023 is the only input that should fail.
predicate ExpectedPanic(x: uint32) { x == 1023 }

predicate Panics(r: Result) { r.Failure? }

// The complete output specification for the corrected function:
//   0..127       -> 1
//   128..255     -> 3
//   256..1022    -> 5
//   1023         -> 4
//   1024..2047   -> 7
//   2048..2^32-1 -> 9
function ExpectedSize(x: uint32): uint32
{
  if x < 128 then 1
  else if x < 256 then 3
  else if x < 1023 then 5
  else if x == 1023 then 4
  else if x < 2048 then 7
  else 9
}

// The complete result specification for the original function.
function ExpectedOriginalResult(x: uint32): Result
{
  if x == 1023 then Failure(PanicMessage) else Success(ExpectedSize(x))
}

// 1. The original fails exactly when x = 1023.
lemma OriginalPanicsIffExpected(x: uint32)
  ensures Panics(EstimateSizePanic(x)) <==> ExpectedPanic(x)
{ }

// 2. This checks only the known failing input; it says nothing about others.
lemma CorrectedAt1023()
  ensures EstimateSizeCorrection(1023) == 4
{ }

// 3. This restricts the possible outputs without saying which input gives which.
lemma CorrectedReturnsAllowed(x: uint32)
  ensures var r := EstimateSizeCorrection(x);
          r == 1 || r == 3 || r == 4 || r == 5 || r == 7 || r == 9
{ }

// 4. The value 4 occurs only at the repaired input, and does occur there.
lemma CorrectedReturnsFourIff(x: uint32)
  ensures EstimateSizeCorrection(x) == 4 <==> x == 1023
{ }

// 5. For every uint32, the corrected function follows ExpectedSize.
lemma CorrectedMatchesSpec(x: uint32)
  ensures EstimateSizeCorrection(x) == ExpectedSize(x)
{ }

// 6. The correction changes x = 1023 and preserves every other result.
lemma CorrectionIsExactPatch(x: uint32)
  ensures ExpectedPanic(x) ==> EstimateSizeCorrection(x) == 4
  ensures !ExpectedPanic(x) ==>
          EstimateSizePanic(x) == Success(EstimateSizeCorrection(x))
{ }

// 7. The original's complete result: every value it returns, and the one
//    failure together with the message it carries. Claim 1 used `Panics`,
//    which discards the payload, so it recorded only *that* it fails.
lemma OriginalMatchesResultSpec(x: uint32)
  ensures EstimateSizePanic(x) == ExpectedOriginalResult(x)
{ }

// 8. The whole repair relationship, split on what the original actually
//    produced rather than on the ExpectedPanic predicate.
lemma CorrectionIsTotalRefinement(x: uint32)
  ensures match EstimateSizePanic(x) {
            case Success(y) => EstimateSizeCorrection(x) == y
            case Failure(e) => e == PanicMessage
                               && x == 1023
                               && EstimateSizeCorrection(x) == 4
          }
{ }

/*
The claims above mirror the other backends. This last one does not, because no
other backend in this repo can state it.

Dafny lets a partial function carry its domain in its signature. Written this
way the bug is not something a proof discovers after the fact -- it is a
precondition, and every caller has to discharge it. The failing input stops
being reachable rather than being handled, and `EstimateSizePanicPartial` needs
no Result type at all.

Which framing is right depends on what the panic means. If 1023 is a caller
error, this is the honest signature and the Result version is overhead. If it
is a bug in the function, the Result version is honest and this one just moves
the problem up the call stack. Dafny is the only backend here that makes you
choose, and the choice is a design statement rather than a proof detail.
*/
function EstimateSizePanicPartial(x: uint32): uint32
  requires x != 1023
{
  if x < 256 then
    if x < 128 then 1 else 3
  else if x < 1024 then
    5
  else
    if x < 2048 then 7 else 9
}

lemma PartialAgreesWithCorrectionOffTheBug(x: uint32)
  requires x != 1023
  ensures EstimateSizePanicPartial(x) == EstimateSizeCorrection(x)
  ensures EstimateSizePanicPartial(x) == ExpectedSize(x)
{ }
