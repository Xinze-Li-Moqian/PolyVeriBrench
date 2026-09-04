inductive Tree where
  | leaf : Tree
  | node : Tree → Int → Tree → Tree

def Tree.min : Tree → Int
  | .leaf => 0
  | .node .leaf v _ => v
  | .node l _ _ => l.min

def Tree.deleteMin : Tree → Tree
  | .leaf => .leaf
  | .node .leaf _ r => r
  | .node l v r => .node l.deleteMin v r

def Tree.deleteError : Tree → Int → Tree
  | .leaf, _ => .leaf
  | .node l v r, x =>
    if x < v then .node (l.deleteError x) v r
    else if v < x then .node l v (r.deleteError x)
    else match l, r with
      | .leaf, _ => r
      | _, .leaf => l
      | _, _ => .node l l.min l.deleteMin

def Tree.deleteCorrection : Tree → Int → Tree
  | .leaf, _ => .leaf
  | .node l v r, x =>
    if x < v then .node (l.deleteCorrection x) v r
    else if v < x then .node l v (r.deleteCorrection x)
    else match l, r with
      | .leaf, _ => r
      | _, .leaf => l
      | _, _ => .node l r.min r.deleteMin
