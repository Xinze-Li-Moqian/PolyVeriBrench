/*
Binary search: the first scenario in this repo with a loop.

estimate_size is straight-line branching, which is why seven backends proved it
with every lemma body empty. Nothing here is free. A loop has infinitely many
executions, so the verifier cannot enumerate them -- it needs an inductive
invariant, and finding that invariant is the work. This file is where the
proofs stop being `{ }`.

Run with:

    dafny verify binary_search.dfy

There are two defects in play, and they are worth separating:

  1. The famous one. `mid := (lo + hi) / 2` overflows when `lo + hi` exceeds the
     index type. Joshua Bloch's 2006 post "Nearly All Binary Searches and
     Mergesorts are Broken" found it in java.util.Arrays, where it had shipped
     for nine years. It needs an array of over 2^30 elements to fire, so testing
     will not find it -- the same shape as estimate_size's one-input-in-2^32 bug,
     but this one was real.

     Note how Dafny surfaces it. Because indices are `uint32` rather than
     unbounded `int`, the expression `lo + hi` is itself a proof obligation:
     Dafny must show the result is in range, and it cannot, because it is not.
     Swap the safe midpoint below for the naive one and you get, on that line:

         Error: result of operation might violate newtype constraint for 'uint32'

     The bug is not a wrong answer caught downstream. It is an arithmetic
     obligation that fails where it is written. MidpointCanOverflow states why
     it fails; SafeMidpointNeverOverflows states why the standard fix does not.

  2. The one that needs an invariant. Reporting "not found" is only sound if the
     key really is absent from the whole array, not just from the window the
     loop happened to look at. That does not follow from the loop condition; it
     follows from an invariant carried through every iteration. Delete the
     `key in a ==> ...` invariant below and Dafny reports:

         Error: a postcondition could not be proved on this return path
         Related location: this is the postcondition that could not be proved
           ensures !found ==> key !in a

     Read where the complaint lands. Not on the loop -- the loop is fine, and
     the code still returns the right answer on every input you would ever run.
     What breaks is the ability to conclude anything about the array from having
     finished the loop. That gap is what an invariant is for, and it is the
     thing straight-line programs like estimate_size never made you supply.
*/

newtype uint32 = x: int | 0 <= x < 0x1_0000_0000 witness 0

predicate Sorted(a: seq<uint32>)
{
  forall i, j :: 0 <= i < j < |a| ==> a[i] <= a[j]
}

/* ------------------------------------------------------------------------ */
/* Defect 1: the midpoint                                                   */
/* ------------------------------------------------------------------------ */

// Two indices can each be valid while their sum is not. This is the bug, stated
// as something provable rather than as a verification failure.
//
// Written as `ensures exists lo, hi :: ...` this does not verify, and the
// reason is worth knowing: Dafny warns "could not find a trigger for this
// quantifier". The solver has to guess which terms to instantiate an
// existential with, and here it has nothing to guess from -- proving the body
// for concrete values does not tell it to try those values. A lemma with return
// values sidesteps that entirely by handing over the witness instead of
// claiming one exists. It is also the stronger statement.
lemma MidpointCanOverflow() returns (lo: uint32, hi: uint32)
  ensures lo <= hi
  ensures lo as int + hi as int >= 0x1_0000_0000
{
  // 2^31 is a perfectly good index. Two of them are not a good sum. An array
  // this size is where the java.util.Arrays bug fired.
  lo := 0x8000_0000;
  hi := 0x8000_0000;
}

// The standard fix. `lo + (hi - lo) / 2` stays inside the type for every pair of
// valid indices, and computes the same value the naive form was trying to.
lemma SafeMidpointNeverOverflows(lo: uint32, hi: uint32)
  requires lo <= hi
  ensures 0 <= lo as int + (hi as int - lo as int) / 2 < 0x1_0000_0000
  ensures lo as int + (hi as int - lo as int) / 2 == (lo as int + hi as int) / 2
{ }

/* ------------------------------------------------------------------------ */
/* Defect 2: the search itself                                              */
/* ------------------------------------------------------------------------ */

method BinarySearch(a: seq<uint32>, key: uint32) returns (found: bool, index: uint32)
  requires Sorted(a)
  requires |a| < 0x1_0000_0000
  // A positive answer points at the key.
  ensures found ==> index as int < |a| && a[index as int] == key
  // A negative answer is a claim about the whole array, not about a window.
  ensures !found ==> key !in a
{
  var lo: uint32 := 0;
  var hi: uint32 := |a| as uint32;

  while lo < hi
    // The window stays a window.
    invariant 0 <= lo as int <= hi as int <= |a|
    // The one that earns the `!found` postcondition: if the key is anywhere in
    // the array at all, it is still inside the window. Everything outside has
    // been ruled out, not merely skipped.
    invariant key in a ==> key in a[lo as int .. hi as int]
    // Termination: the window shrinks every iteration.
    decreases hi as int - lo as int
  {
    // The safe midpoint. Written `(lo + hi) / 2`, this line does not verify.
    var mid: uint32 := lo + (hi - lo) / 2;

    if a[mid as int] < key {
      lo := mid + 1;
    } else if a[mid as int] > key {
      hi := mid;
    } else {
      return true, mid;
    }
  }
  return false, 0;
}
