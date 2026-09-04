/-
Lean 4 with `mvcgen`, the verification-condition generator in Std.Do.

It works the way Dafny does: state the goal, supply the loop invariant, and
discharge what comes back. The difference between the `for` and `while`
versions is visible in what it asks for. See README.md.
-/
import Std.Tactic.Do
import src.fibonacci

open Std.Do

-- The specification: the definition, not the program.
def fib_spec : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib_spec n + fib_spec (n + 1)

theorem fib_spec_step {i : Nat} (h : 1 ≤ i) :
    fib_spec (i - 1) + fib_spec i = fib_spec (i + 1) := by
  obtain ⟨k, rfl⟩ : ∃ k, i = k + 1 := ⟨i - 1, by omega⟩
  simp [fib_spec]

theorem fib_spec_small {n : Nat} (h : n < 2) : n = fib_spec n := by
  have : n = 0 ∨ n = 1 := by omega
  rcases this with rfl | rfl <;> rfl

-- 1. The corrected for-loop computes the specification, for every input.
--    One invariant: what a and b mean after k iterations.
set_option mvcgen.warning false in
theorem correction_for_matches_spec (n : Nat) :
    fib_iter_correction_for n = fib_spec n := by
  generalize h : fib_iter_correction_for n = res
  apply Id.of_wp_run_eq h
  mvcgen invariants
    | inv1 => ⇓⟨xs, ab⟩ => ⌜ab.1 = fib_spec xs.prefix.length ∧
                             ab.2 = fib_spec (xs.prefix.length + 1)⌝
  all_goals try simp_all [fib_spec]
  · exact fib_spec_small ‹_›
  · omega
  · congr 1
    omega

-- 2. The corrected while-loop computes the same thing. Same invariant plus the
--    index bounds, and a termination measure the for-loop never needed.
set_option mvcgen.warning false in
theorem correction_while_matches_spec (n : Nat) :
    fib_iter_correction_while n = fib_spec n := by
  generalize h : fib_iter_correction_while n = res
  apply Id.of_wp_run_eq h
  mvcgen invariants
    | inv1 => fun s => ⟨n - s.2.2⟩
    | inv2 => ⇓ x => ⌜match x with
        | .inl (a, b, i) => 1 ≤ i ∧ i ≤ n ∧ a = fib_spec (i - 1) ∧ b = fib_spec i
        | .inr (a, b, _) => b = fib_spec n⌝
  all_goals try simp_all [fib_spec]
  all_goals try grind [fib_spec, fib_spec_step]

-- 3. Both corrections agree, which follows from 1 and 2 rather than from
--    anything about loops.
theorem corrections_agree (n : Nat) :
    fib_iter_correction_for n = fib_iter_correction_while n := by
  rw [correction_for_matches_spec, correction_while_matches_spec]

-- 4. The error version, completely: dropping the n < 2 guard leaves the range
--    empty at n = 0, so the loop never runs and the initial b is returned.
set_option mvcgen.warning false in
theorem error_for_result (n : Nat) :
    fib_iter_error_for n = if n = 0 then 1 else fib_spec n := by
  generalize h : fib_iter_error_for n = res
  apply Id.of_wp_run_eq h
  mvcgen invariants
    | inv1 => ⇓⟨xs, ab⟩ => ⌜ab.1 = fib_spec xs.prefix.length ∧
                             ab.2 = fib_spec (xs.prefix.length + 1)⌝
  all_goals try simp_all [fib_spec]
  · omega
  · split
    · next hn => subst hn; rfl
    · congr 1
      omega

-- 5. It is wrong at exactly one input.
theorem error_for_wrong_iff (n : Nat) :
    fib_iter_error_for n ≠ fib_spec n ↔ n = 0 := by
  rw [error_for_result]
  cases n with
  | zero => simp [fib_spec]
  | succ k => simp

-- 6. The correction changes n = 0 and preserves every other result.
theorem correction_is_exact_patch (n : Nat) :
    (n = 0 → fib_iter_correction_for n = 0) ∧
    (n ≠ 0 → fib_iter_error_for n = fib_iter_correction_for n) := by
  constructor
  · rintro rfl
    rw [correction_for_matches_spec]
    rfl
  · intro hn
    rw [error_for_result, correction_for_matches_spec, if_neg hn]
