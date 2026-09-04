// Indices are u32 rather than usize so the overflow is reachable: it needs
// lo + hi >= 2^32, which a u32-indexed array can reach and a 64-bit usize one
// cannot in practice. This is the width the java.util.Arrays bug lived at.

fn binary_search_error(a: &[i64], key: i64) -> Option<u32> {
    let mut lo: u32 = 0;
    let mut hi: u32 = a.len() as u32;
    while lo < hi {
        let mid = (lo + hi) / 2; // overflows once lo + hi >= 2^32
        let v = a[mid as usize];
        if v < key {
            lo = mid + 1;
        } else if v > key {
            hi = mid;
        } else {
            return Some(mid);
        }
    }
    None
}

fn binary_search_correction(a: &[i64], key: i64) -> Option<u32> {
    let mut lo: u32 = 0;
    let mut hi: u32 = a.len() as u32;
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        let v = a[mid as usize];
        if v < key {
            lo = mid + 1;
        } else if v > key {
            hi = mid;
        } else {
            return Some(mid);
        }
    }
    None
}
