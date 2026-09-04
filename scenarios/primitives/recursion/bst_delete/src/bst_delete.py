# A tree is None (leaf) or a (left, value, right) triple.


def tree_min(t):
    while t[0] is not None:
        t = t[0]
    return t[1]


def delete_min(t):
    if t[0] is None:
        return t[2]
    return (delete_min(t[0]), t[1], t[2])


def delete_error(t, x):
    if t is None:
        return None
    left, v, right = t
    if x < v:
        return (delete_error(left, x), v, right)
    if v < x:
        return (left, v, delete_error(right, x))
    if left is None:
        return right
    if right is None:
        return left
    return (left, tree_min(left), delete_min(left))


def delete_correction(t, x):
    if t is None:
        return None
    left, v, right = t
    if x < v:
        return (delete_correction(left, x), v, right)
    if v < x:
        return (left, v, delete_correction(right, x))
    if left is None:
        return right
    if right is None:
        return left
    return (left, tree_min(right), delete_min(right))
