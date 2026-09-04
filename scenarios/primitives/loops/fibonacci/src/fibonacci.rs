fn fib_iter(n: u64) -> u64 {
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
