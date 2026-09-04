# `(lo + hi) // 2` is correct here: Python ints are unbounded, so the midpoint
# cannot overflow. The same line is a bug in binary_search.rs.
def binary_search(a, key):
    lo, hi = 0, len(a)
    while lo < hi:
        mid = (lo + hi) // 2
        if a[mid] < key:
            lo = mid + 1
        elif a[mid] > key:
            hi = mid
        else:
            return mid
    return None
