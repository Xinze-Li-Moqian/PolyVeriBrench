def fib_iter_error(n: int) -> int:
    a, b = 0, 1
    for _ in range(1, n):
        a, b = b, a + b
    return b


def fib_iter_correction_for(n: int) -> int:
    if n < 2:
        return n
    a, b = 0, 1
    for _ in range(1, n):
        a, b = b, a + b
    return b


def fib_iter_correction_while(n: int) -> int:
    if n < 2:
        return n
    a, b = 0, 1
    i = 1
    while i < n:
        a, b = b, a + b
        i += 1
    return b
