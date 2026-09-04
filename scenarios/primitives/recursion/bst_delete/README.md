# bst_delete

Deleting from a binary search tree: the first scenario here with a recursive
data structure.

`binary_search` and `fibonacci` are loops over numbers, and their invariants are
carried by a counter. Here there is no counter. The proofs recurse over the
tree, the specification is itself recursive (`BST`, `Values`), and termination
comes from the structure shrinking rather than from a measure you write down.

## The bug

Deleting a node with two children means promoting something to take its place.
There are two correct recipes:

- the **in-order successor** -- the minimum of the right subtree
- the **in-order predecessor** -- the maximum of the left subtree

Either works. The bug is mixing them:

```dafny
else Node(l, Min(r), DeleteMin(r))   // correct: successor
else Node(l, Min(l), DeleteMin(l))   // wrong: minimum of the LEFT subtree
```

This is the case BST delete is famously gotten wrong in, and the reason is worth
stating: **the deleted value really is gone.** A test that deletes 2 and then
asks "is 2 still there?" passes. What breaks is the ordering invariant, and that
does not surface until some later search walks the wrong way and reports a value
missing that is still in the tree.

So the specification that catches it is not about the return value. It is:

```dafny
lemma DeletePreservesBST(t: Tree, x: int)
  requires BST(t)
  ensures BST(Delete(t, x))
```

A global property of the structure, before and after. That is a shape testing is
bad at and verification is good at.

The error version is refuted by exhibiting one tree:

```dafny
lemma DeleteErrorBreaksBST() returns (t: Tree, x: int)
  ensures BST(t)
  ensures !BST(DeleteError(t, x))
```

Deleting 2 from `Node(Node(Leaf,1,Leaf), 2, Node(Leaf,3,Leaf))` gives
`Node(Node(Leaf,1,Leaf), 1, Leaf)` -- the left subtree now contains a value equal
to the root, so the ordering constraint `x < v` fails.

## What the proofs need

Two claims, both by structural induction:

| Lemma | Claim |
|---|---|
| `DeletePreservesBST` | the result is still a BST |
| `DeleteRemovesExactly` | `Values(Delete(t,x)) == Values(t) - {x}` |

Neither goes through on its own. The load-bearing helper is `DeleteMinValues`,
which says three things about pulling the minimum out of a subtree at once: what
it does to the value set, that the remainder is still a BST, and that everything
left is greater than what was removed. That third clause is what lets the
promoted value sit above the right subtree without breaking the ordering.

The other helper, `DeleteSubset` (`Values(Delete(t,x)) <= Values(t)`), is what
keeps a *parent's* constraint intact when one of its subtrees is rebuilt. The
parent said "everything on the left is less than me"; after deleting inside the
left subtree, that has to still hold, and it does only because deletion cannot
add values.

## A note on which lines are doing the work

The proof carries four helper lemmas. Removing any single call site still
verifies; removing three of them together does not. The solver finds more than
one route to the same fact, so no individual line looks necessary while the set
of them is.

This is worth knowing about SMT-backed proofs in general, and it cuts against
reading a Dafny proof as a record of the argument. Lean's proof terms say
exactly what was used. Here, the honest description is that these four lemmas
together are enough, and the file does not tell you which subset would do.

## Backends

| Path | Tool | Status |
|---|---|---|
| `verification/dafny_verification/` | Dafny | 16 verified, 0 errors |

```sh
DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh bst_delete
```

Worth adding next, and for a specific reason: this is the first scenario where
Rust puts the structure on the heap (`Box<Node>`). Everything so far has been
scalar functions, so Aeneas's central claim -- that Rust's ownership discipline
lets it translate the heap away and hand Lean a pure functional program -- has
never actually been tested here. A tree would test it. Kani, meanwhile, hits an
unbounded recursive structure and needs a bound.
