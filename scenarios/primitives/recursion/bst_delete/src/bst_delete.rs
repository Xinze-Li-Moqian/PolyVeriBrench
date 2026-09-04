// Clone is here only for delete_error: taking the minimum of the left subtree
// and then deleting it needs that subtree twice, and ownership does not allow
// using a Box twice. The correct version never needs it.
#[derive(Clone)]
enum Tree {
    Leaf,
    Node(Box<Tree>, i64, Box<Tree>),
}

fn tree_min(t: &Tree) -> i64 {
    match t {
        Tree::Leaf => unreachable!(),
        Tree::Node(left, v, _) => match **left {
            Tree::Leaf => *v,
            _ => tree_min(left),
        },
    }
}

fn delete_min(t: Tree) -> Tree {
    match t {
        Tree::Leaf => Tree::Leaf,
        Tree::Node(left, v, right) => match *left {
            Tree::Leaf => *right,
            _ => Tree::Node(Box::new(delete_min(*left)), v, right),
        },
    }
}

fn delete_error(t: Tree, x: i64) -> Tree {
    match t {
        Tree::Leaf => Tree::Leaf,
        Tree::Node(left, v, right) => {
            if x < v {
                Tree::Node(Box::new(delete_error(*left, x)), v, right)
            } else if v < x {
                Tree::Node(left, v, Box::new(delete_error(*right, x)))
            } else if matches!(*left, Tree::Leaf) {
                *right
            } else if matches!(*right, Tree::Leaf) {
                *left
            } else {
                let m = tree_min(&left);
                Tree::Node(left.clone(), m, Box::new(delete_min(*left)))
            }
        }
    }
}

fn delete_correction(t: Tree, x: i64) -> Tree {
    match t {
        Tree::Leaf => Tree::Leaf,
        Tree::Node(left, v, right) => {
            if x < v {
                Tree::Node(Box::new(delete_correction(*left, x)), v, right)
            } else if v < x {
                Tree::Node(left, v, Box::new(delete_correction(*right, x)))
            } else if matches!(*left, Tree::Leaf) {
                *right
            } else if matches!(*right, Tree::Leaf) {
                *left
            } else {
                let m = tree_min(&right);
                Tree::Node(left, m, Box::new(delete_min(*right)))
            }
        }
    }
}
