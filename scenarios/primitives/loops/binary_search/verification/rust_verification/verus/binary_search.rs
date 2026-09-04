// Binary search in Verus. README.md covers what fails and why.
#![crate_type = "lib"]

use vstd::prelude::*;

verus! {

spec fn sorted(s: Seq<i64>) -> bool {
    forall|i: int, j: int| 0 <= i < j < s.len() ==> s[i] <= s[j]
}

// The safe midpoint, and the reason it is the right one: it computes the
// mathematical average. Spec arithmetic is unbounded, so `(lo + hi) / 2` is
// meaningful here even though the executable form of it is not.
//
// Writing `(lo + hi) / 2` in the body instead gives, on that expression:
//   error: possible arithmetic underflow/overflow
fn safe_mid(lo: u32, hi: u32) -> (r: u32)
    requires
        lo <= hi,
    ensures
        r == (lo + hi) / 2,
{
    lo + (hi - lo) / 2
}

fn binary_search(a: &[i64], key: i64) -> (result: Option<u32>)
    requires
        sorted(a@),
        a@.len() < 0x1_0000_0000,
    ensures
        match result {
            Some(i) => (i as int) < a@.len() && a@[i as int] == key,
            None => !a@.contains(key),
        },
{
    let mut lo: u32 = 0;
    let mut hi: u32 = a.len() as u32;
    while lo < hi
        invariant
            // Not inherited from the precondition: a loop sees only what its
            // invariant carries in.
            sorted(a@),
            lo <= hi,
            hi as int <= a@.len(),
            // Everything ruled out stays ruled out. This is what earns the
            // None case of the postcondition.
            forall|k: int| 0 <= k < lo as int ==> a@[k] != key,
            forall|k: int| hi as int <= k < a@.len() ==> a@[k] != key,
        decreases hi - lo,
    {
        let mid = safe_mid(lo, hi);
        let v = a[mid as usize];
        if v < key {
            lo = mid + 1;
        } else if v > key {
            hi = mid;
        } else {
            return Some(mid);
        }
    }
    None
}

}
