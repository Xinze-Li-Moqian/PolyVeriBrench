fn fib_iter_error_for(n: u64) -> u64 {
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 1..n {
        let next = a + b;
        a = b;
        b = next;
    }
    b
}

// Does not terminate for n >= 2: i is never incremented.
fn fib_iter_error_while(n: u64) -> u64 {
    if n < 2 {
        return n;
    }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    let i: u64 = 1;
    while i < n {
        let next = a + b;
        a = b;
        b = next;
    }
    b
}

fn fib_iter_correction_for(n: u64) -> u64 {
    if n < 2 {
        return n;
    }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 1..n {
        let next = a + b;
        a = b;
        b = next;
    }
    b
}

fn fib_iter_correction_while(n: u64) -> u64 {
    if n < 2 {
        return n;
    }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    let mut i: u64 = 1;
    while i < n {
        let next = a + b;
        a = b;
        b = next;
        i += 1;
    }
    b
}
