/-
This file checks the Rust functions after Aeneas has translated them into Lean.

The first six theorems ask the same questions, in the same order, as the native
Lean verification:
1. The original function fails exactly when x = 1023.
2. The corrected function returns 4 when x = 1023.
3. Every corrected result is one of 1, 3, 4, 5, 7, or 9.
4. The corrected result is 4 exactly when x = 1023.
5. The corrected function returns the specified value for every u32 input.
6. The correction changes x = 1023 to 4 and preserves every other result.

Aeneas records each Rust execution as a `Result`:
- `.ok y` means that the function returned y.
- `.fail e` means that the function stopped with error e.
- `.div` means that the function did not return.

The final two theorems describe the complete `Result` of the original Rust
function and then compare the original and corrected Rust functions in all
three cases. These statements are not beyond native Lean's proving ability;
their value is that they refer to functions translated from the Rust source.
-/
import EstimateSizeAeneas

open Aeneas Aeneas.Std Result Error

namespace EstimateSizeAeneas

-- The bug specification: 1023 is the only input that should make the
-- original Rust function fail.
def expectedPanic (x : U32) : Prop :=
  x = 1023#u32

-- For this scenario, `Panics result` means that Aeneas recorded a `.fail`
-- rather than a returned value or divergence.
def Panics : Result U32 → Prop
  | .fail _ => True
  | _ => False

-- The complete output specification for the corrected function:
--   0..127       -> 1
--   128..255     -> 3
--   256..1022    -> 5
--   1023         -> 4
--   1024..2047   -> 7
--   2048..2^32-1 -> 9
def expectedSize (x : U32) : U32 :=
  if x < 128#u32 then 1#u32
  else if x < 256#u32 then 3#u32
  else if x < 1023#u32 then 5#u32
  else if x = 1023#u32 then 4#u32
  else if x < 2048#u32 then 7#u32
  else 9#u32

-- Running the translated original Rust function produces `.fail` exactly for
-- x = 1023.
theorem original_panics_iff_expected (x : U32) :
    Panics (estimate_size_panic x) ↔ expectedPanic x := by
  by_cases hx : expectedPanic x
  · unfold expectedPanic at hx
    subst x
    simp [estimate_size_panic, Panics, expectedPanic, massert]
  · have hguard :
        x.val < 256 ∨ 1024 ≤ x.val ∨ x.val ≤ 1022 := by
      unfold expectedPanic at hx
      scalar_tac
    simp [estimate_size_panic, massert, hguard]
    simp only [apply_ite Panics]
    simp [Panics, hx]

-- This checks only the known failing input; it says nothing about other inputs.
theorem corrected_at_1023 :
    estimate_size_correction 1023#u32 = .ok 4#u32 := by
  rfl

-- This restricts the possible successful outputs, but does not yet say which
-- input must produce which output.
theorem corrected_returns_allowed (x : U32) :
    estimate_size_correction x = .ok 1#u32 ∨
    estimate_size_correction x = .ok 3#u32 ∨
    estimate_size_correction x = .ok 4#u32 ∨
    estimate_size_correction x = .ok 5#u32 ∨
    estimate_size_correction x = .ok 7#u32 ∨
    estimate_size_correction x = .ok 9#u32 := by
  simp [estimate_size_correction]
  scalar_tac +split

-- The corrected Rust function returns 4 only at x = 1023, and it does return
-- 4 there. The outputs for other inputs are still not fully specified here.
theorem corrected_returns_four_iff (x : U32) :
    estimate_size_correction x = .ok 4#u32 ↔
    x = 1023#u32 := by
  simp only [estimate_size_correction,
    apply_ite (fun result : Result U32 => result = .ok 4#u32)]
  simp
  scalar_tac +split

-- For every u32 input, the corrected Rust function succeeds and follows the
-- six cases listed in `expectedSize` above.
theorem corrected_matches_spec (x : U32) :
    estimate_size_correction x = .ok (expectedSize x) := by
  simp [estimate_size_correction, expectedSize]
  scalar_tac +split

-- This compares the two translated Rust functions directly: at x = 1023 the
-- corrected function returns 4; at every other input both functions return
-- exactly the same `Result`.
theorem correction_is_exact_patch (x : U32) :
    (expectedPanic x → estimate_size_correction x = .ok 4#u32) ∧
    (¬ expectedPanic x →
      estimate_size_panic x = estimate_size_correction x) := by
  constructor
  · intro hx
    unfold expectedPanic at hx
    subst x
    rfl
  · intro hx
    unfold expectedPanic at hx
    unfold estimate_size_panic estimate_size_correction
    simp only [massert]
    split
    · simp
      scalar_tac +split
    · exfalso
      scalar_tac

-- The complete result specification for the original Rust function:
-- x = 1023 produces an assertion failure; every other input successfully
-- returns the value specified by `expectedSize`.
def expectedOriginalResult (x : U32) : Result U32 :=
  if x = 1023#u32 then
    .fail .assertionFailure
  else
    .ok (expectedSize x)

-- The translated original Rust function follows `expectedOriginalResult` for
-- every input, including both its returned values and its one failure.
theorem original_matches_result_spec (x : U32) :
    estimate_size_panic x = expectedOriginalResult x := by
  unfold estimate_size_panic
  simp only [massert]
  split
  · simp [expectedOriginalResult, expectedSize]
    scalar_tac +split
  · simp [expectedOriginalResult]
    scalar_tac

-- This states the whole repair relationship in one theorem:
-- - if the original returns y, the corrected function returns the same y;
-- - if the original fails, it is the assertion failure at x = 1023, and the
--   corrected function returns 4;
-- - the original function never reaches `.div`.
theorem correction_is_total_refinement (x : U32) :
    match estimate_size_panic x with
    | .ok y =>
        estimate_size_correction x = .ok y
    | .fail e =>
        e = .assertionFailure ∧
        x = 1023#u32 ∧
        estimate_size_correction x = .ok 4#u32
    | .div =>
        False := by
  rw [original_matches_result_spec]
  by_cases hx : x = 1023#u32
  · subst x
    simp [expectedOriginalResult, corrected_matches_spec, expectedSize]
  · simp [expectedOriginalResult, hx, corrected_matches_spec]

end EstimateSizeAeneas
