/-
This file checks the program in eight steps, from a small claim to a complete one:
1. The original function fails exactly when x = 1023.
2. The corrected function returns 4 when x = 1023.
3. Every corrected result is one of 1, 3, 4, 5, 7, or 9.
4. The corrected result is 4 exactly when x = 1023.
5. The corrected function returns the specified value for every UInt32 input.
6. The correction changes x = 1023 to 4 and preserves every other result.
7. The original function's complete result, its values and its one failure.
8. The original and corrected functions compared in every case at once.

Steps 1-6 describe the corrected function completely but leave the original one
only partially specified: step 1 records *that* it fails, never what it returns
elsewhere or which error it raises. Steps 7 and 8 close that gap, and mirror the
two extra theorems in the Aeneas development so that the two files prove the
same set of claims about the same program.
-/
import Std.Tactic.BVDecide
import src.estimate_size

-- The bug specification: 1023 is the only input that should make the
-- original function fail.
def expectedPanic (x : UInt32) : Prop :=
  x = 1023

-- `Panics result` means that the explicit result is an error rather than a
-- successfully returned value.
def Panics : Except String UInt32 → Prop
  | .error _ => True
  | .ok _ => False

-- The complete output specification for the corrected function:
--   0..127       -> 1
--   128..255     -> 3
--   256..1022    -> 5
--   1023         -> 4
--   1024..2047   -> 7
--   2048..2^32-1 -> 9
def expectedSize (x : UInt32) : UInt32 :=
  if x < 128 then 1
  else if x < 256 then 3
  else if x < 1023 then 5
  else if x = 1023 then 4
  else if x < 2048 then 7
  else 9

-- Running the original function produces an error exactly for x = 1023.
theorem original_panics_iff_expected (x : UInt32) :
    Panics (estimate_size_panic x) ↔ expectedPanic x := by
  cases x
  simp only [estimate_size_panic, expectedPanic]
  simp only [apply_ite Panics]
  simp only [Panics, UInt32.eq_iff_toBitVec_eq]
  simp
  bv_decide

-- This checks only the known failing input; it says nothing about other inputs.
theorem corrected_at_1023 :
    estimate_size_correction 1023 = 4 := by
  rfl

-- This restricts the possible outputs, but does not yet say which input must
-- produce which output.
theorem corrected_returns_allowed (x : UInt32) :
    estimate_size_correction x = 1 ∨
    estimate_size_correction x = 3 ∨
    estimate_size_correction x = 4 ∨
    estimate_size_correction x = 5 ∨
    estimate_size_correction x = 7 ∨
    estimate_size_correction x = 9 := by
  cases x
  simp only [estimate_size_correction, Id.run, Pure.pure]
  simp only [UInt32.eq_iff_toBitVec_eq, apply_ite UInt32.toBitVec]
  bv_decide

-- The new value 4 occurs only at the repaired input, and it does occur there.
-- The outputs for all other inputs are still not fully specified here.
theorem corrected_returns_four_iff (x : UInt32) :
    estimate_size_correction x = 4 ↔ x = 1023 := by
  cases x
  simp only [estimate_size_correction, Id.run, Pure.pure,
    UInt32.eq_iff_toBitVec_eq, apply_ite UInt32.toBitVec]
  bv_decide

-- For every UInt32 input, the corrected function follows the six cases listed
-- in `expectedSize` above.
theorem corrected_matches_spec (x : UInt32) :
    estimate_size_correction x = expectedSize x := by
  cases x
  simp only [estimate_size_correction, expectedSize, Id.run, Pure.pure]
  simp only [UInt32.eq_iff_toBitVec_eq, apply_ite UInt32.toBitVec]
  bv_decide

-- This compares the two functions directly: at x = 1023 the corrected function
-- returns 4; at every other input the original function succeeds with exactly
-- the same value returned by the corrected function.
theorem correction_is_exact_patch (x : UInt32) :
    (expectedPanic x → estimate_size_correction x = 4) ∧
    (¬ expectedPanic x →
      estimate_size_panic x = .ok (estimate_size_correction x)) := by
  constructor
  · intro hx
    unfold expectedPanic at hx
    subst x
    rfl
  · intro hx
    unfold expectedPanic at hx
    unfold estimate_size_correction estimate_size_panic
    simp only [Id.run, Pure.pure]
    by_cases h256 : x < 256
    · by_cases h128 : x < 128 <;> simp [h256, h128]
    · simp only [if_neg h256]
      by_cases h1024 : x < 1024
      · simp only [if_pos h1024]
        by_cases h1022 : x > 1022
        · exfalso
          cases x
          simp only [UInt32.lt_iff_toBitVec_lt,
            UInt32.eq_iff_toBitVec_eq] at *
          bv_decide
        · simp [h1022]
      · by_cases h2048 : x < 2048 <;> simp [h1024, h2048]

-- The complete result specification for the original function:
-- x = 1023 raises the error; every other input successfully returns the value
-- specified by `expectedSize`.
def expectedOriginalResult (x : UInt32) : Except String UInt32 :=
  if x = 1023 then
    .error "Oh no, a failing corner case!"
  else
    .ok (expectedSize x)

-- The original function follows `expectedOriginalResult` for every input,
-- including both its returned values and its one failure. Theorem 1 above used
-- `Panics`, which discards the payload (`.error _`), so it recorded only *that*
-- the function fails; this equation also pins down the message it fails with.
theorem original_matches_result_spec (x : UInt32) :
    estimate_size_panic x = expectedOriginalResult x := by
  unfold estimate_size_panic expectedOriginalResult expectedSize
  repeat (any_goals split)
  all_goals
    first
    | rfl
    | (exfalso; cases x;
       simp only [UInt32.lt_iff_toBitVec_lt, UInt32.eq_iff_toBitVec_eq] at *;
       bv_decide)

-- This states the whole repair relationship in one theorem, splitting on what
-- the original function actually did rather than on the `expectedPanic`
-- predicate as theorem 6 does:
-- - if the original returns y, the corrected function returns the same y;
-- - if the original fails, it is the expected message at x = 1023, and the
--   corrected function returns 4.
-- The Aeneas version of this theorem carries a third case, `.div => False`,
-- stating that the function does not diverge. It has no counterpart here:
-- Lean functions are total by construction, so `estimate_size_panic` cannot
-- fail to terminate and there is nothing to prove. Aeneas translates arbitrary
-- Rust, where non-termination is possible, so it has to carry `.div` as a real
-- case and the claim becomes an explicit proof obligation instead of an
-- assumption made silently when the program was transcribed into Lean.
theorem correction_is_total_refinement (x : UInt32) :
    match estimate_size_panic x with
    | .ok y =>
        estimate_size_correction x = y
    | .error e =>
        e = "Oh no, a failing corner case!" ∧
        x = 1023 ∧
        estimate_size_correction x = 4 := by
  rw [original_matches_result_spec]
  by_cases hx : x = 1023
  · subst x
    simp [expectedOriginalResult, corrected_at_1023]
  · simp [expectedOriginalResult, hx, corrected_matches_spec]
