def fib_spec(n: int) -> int:
    if n < 2:
        return n
    return fib_spec(n - 1) + fib_spec(n - 2)


def fib_iter(n: int) -> int:
    if n < 2:
        return n
    a, b = 0, 1
    for _ in range(1, n):
        a, b = b, a + b
    return b
