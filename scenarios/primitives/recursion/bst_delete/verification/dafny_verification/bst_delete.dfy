// Deleting from a binary search tree. README.md covers the bug and what the
// proofs need.

datatype Tree = Leaf | Node(left: Tree, value: int, right: Tree)

function Values(t: Tree): set<int>
{
  match t
  case Leaf => {}
  case Node(l, v, r) => Values(l) + {v} + Values(r)
}

predicate BST(t: Tree)
{
  match t
  case Leaf => true
  case Node(l, v, r) =>
    BST(l) && BST(r) &&
    (forall x :: x in Values(l) ==> x < v) &&
    (forall x :: x in Values(r) ==> v < x)
}

function Min(t: Tree): int
  requires t.Node?
{
  if t.left.Leaf? then t.value else Min(t.left)
}

function DeleteMin(t: Tree): Tree
  requires t.Node?
{
  if t.left.Leaf? then t.right else Node(DeleteMin(t.left), t.value, t.right)
}

lemma MinIsInTree(t: Tree)
  requires t.Node?
  ensures Min(t) in Values(t)
{ }

lemma DeleteMinSubset(t: Tree)
  requires t.Node?
  ensures Values(DeleteMin(t)) <= Values(t)
{ }

lemma DeleteMinValues(t: Tree)
  requires t.Node? && BST(t)
  ensures Values(DeleteMin(t)) == Values(t) - {Min(t)}
  ensures BST(DeleteMin(t))
  ensures forall x :: x in Values(DeleteMin(t)) ==> Min(t) < x
{ }

// Correct: the replacement is the minimum of the RIGHT subtree, the in-order
// successor.
function Delete(t: Tree, x: int): Tree
{
  match t
  case Leaf => Leaf
  case Node(l, v, r) =>
    if x < v then Node(Delete(l, x), v, r)
    else if v < x then Node(l, v, Delete(r, x))
    else if l.Leaf? then r
    else if r.Leaf? then l
    else Node(l, Min(r), DeleteMin(r))
}

// Wrong: the minimum of the LEFT subtree. Successor and predecessor are both
// correct recipes; this mixes them.
function DeleteError(t: Tree, x: int): Tree
{
  match t
  case Leaf => Leaf
  case Node(l, v, r) =>
    if x < v then Node(DeleteError(l, x), v, r)
    else if v < x then Node(l, v, DeleteError(r, x))
    else if l.Leaf? then r
    else if r.Leaf? then l
    else Node(l, Min(l), DeleteMin(l))
}

// Deleting can only shrink the value set. Needed so that a parent's ordering
// constraint still holds after one of its subtrees is rebuilt.
lemma DeleteSubset(t: Tree, x: int)
  ensures Values(Delete(t, x)) <= Values(t)
{
  match t
  case Leaf =>
  case Node(l, v, r) =>
    if x < v {
      DeleteSubset(l, x);
    } else if v < x {
      DeleteSubset(r, x);
    } else if l.Leaf? || r.Leaf? {
    } else {
      MinIsInTree(r);
      DeleteMinSubset(r);
    }
}

lemma DeletePreservesBST(t: Tree, x: int)
  requires BST(t)
  ensures BST(Delete(t, x))
{
  match t
  case Leaf =>
  case Node(l, v, r) =>
    if x < v {
      DeletePreservesBST(l, x);
      DeleteSubset(l, x);
    } else if v < x {
      DeletePreservesBST(r, x);
      DeleteSubset(r, x);
    } else if l.Leaf? || r.Leaf? {
    } else {
      MinIsInTree(r);
      DeleteMinValues(r);
    }
}

lemma DeleteRemovesExactly(t: Tree, x: int)
  requires BST(t)
  ensures Values(Delete(t, x)) == Values(t) - {x}
{
  match t
  case Leaf =>
  case Node(l, v, r) =>
    if x < v {
      DeleteRemovesExactly(l, x);
    } else if v < x {
      DeleteRemovesExactly(r, x);
    } else if l.Leaf? || r.Leaf? {
    } else {
      MinIsInTree(r);
      DeleteMinValues(r);
    }
}

// The error version does not preserve the invariant. One witness is enough.
lemma DeleteErrorBreaksBST() returns (t: Tree, x: int)
  ensures BST(t)
  ensures !BST(DeleteError(t, x))
{
  var l := Node(Leaf, 1, Leaf);
  t := Node(l, 2, Node(Leaf, 3, Leaf));
  x := 2;
  assert DeleteError(t, x) == Node(l, 1, Leaf);
  assert 1 in Values(l);
}
