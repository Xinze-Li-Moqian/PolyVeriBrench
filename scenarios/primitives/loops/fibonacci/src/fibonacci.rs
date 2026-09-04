fn fib_spec(n: u32) -> u64 {
    if n < 2 {
        return n as u64;
    }
    fib_spec(n - 1) + fib_spec(n - 2)
}

fn fib_iter(n: u32) -> u64 {
    if n < 2 {
        return n as u64;
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
