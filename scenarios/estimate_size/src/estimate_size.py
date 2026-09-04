def estimate_size_panic(x: int) -> int:
    if x < 256:
        if x < 128:
            return 1
        else:
            return 3
    elif x < 1024:
        if x > 1022:
            raise RuntimeError("Oh no, a failing corner case!")
        else:
            return 5
    else:
        if x < 2048:
            return 7
        else:
            return 9


def estimate_size_correction(x: int) -> int:
    if x < 256:
        if x < 128:
            return 1
        else:
            return 3
    elif x < 1024:
        if x > 1022:
            return 4
        else:
            return 5
    else:
        if x < 2048:
            return 7
        else:
            return 9
