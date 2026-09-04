#!/usr/bin/env bash
#
# Run the Rust verification backends.
#
#   ./scripts/check_rust.sh              # both
#   ./scripts/check_rust.sh kani         # just one
#   ./scripts/check_rust.sh verus
#
# Kani needs `cargo install --locked kani-verifier && cargo kani setup`.
#
# Verus ships as a release archive rather than something cargo installs, and it
# pins an exact rustc. Point VERUS at the extracted binary:
#
#   VERUS=/path/to/verus-<version>-<arch>/verus ./scripts/check_rust.sh verus
#
# and install the toolchain its version.json names, or it refuses to start:
#
#   rustup toolchain install "$(python3 -c 'import json,sys;
#     print(json.load(open(sys.argv[1]))["verus"]["toolchain"])' \
#     /path/to/verus-<version>-<arch>/version.json)"
#
# The two split the same way the Python backends do. Kani model-checks the real
# src/estimate_size.rs, reached through the `include!` in its harness file --
# which is why that file's location matters and why Cargo.toml points `[lib]`
# at it in place rather than moving it under src/. Verus verifies annotated
# Rust that compiles to the real binary, with the specs erased, so there is no
# second artifact -- but the program is restated in the Verus dialect rather
# than read from the shipped source.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="$REPO_ROOT/scenarios/estimate_size/verification/rust_verification"
VERUS="${VERUS:-verus}"

selected=("$@")
wanted () {
  [[ ${#selected[@]} -eq 0 ]] && return 0
  for want in "${selected[@]}"; do
    [[ "$want" == "$1" ]] && return 0
  done
  return 1
}

# Guarded: under `set -u`, bash 3.2 (still the macOS default) errors on
# "${arr[@]}" when arr is empty.
if [[ ${#selected[@]} -gt 0 ]]; then
  for want in "${selected[@]}"; do
    case "$want" in
      kani|verus) ;;
      *) echo "unknown backend: $want (known: kani verus)" >&2; exit 2 ;;
    esac
  done
fi

failures=0
ran=0

if wanted kani; then
  ran=$((ran + 1))
  echo "=============================================================="
  echo "[kani] verification/rust_verification/kani"
  echo "  target: the real src/estimate_size.rs, reached via include!"
  if ! command -v cargo-kani >/dev/null 2>&1; then
    echo "  FAIL: cargo-kani not found (cargo install --locked kani-verifier)"
    failures=$((failures + 1))
  elif (cd "$RUST_DIR/kani" && cargo kani); then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
fi

if wanted verus; then
  ran=$((ran + 1))
  echo "=============================================================="
  echo "[verus] verification/rust_verification/verus"
  echo "  target: annotated Rust; specs are erased from the compiled binary"
  if ! command -v "$VERUS" >/dev/null 2>&1; then
    echo "  FAIL: verus not found at '$VERUS' (set VERUS=/path/to/verus)"
    failures=$((failures + 1))
  elif "$VERUS" "$RUST_DIR/verus/estimate_size.rs"; then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
fi

echo "=============================================================="
if [[ "$ran" -eq 0 ]]; then
  echo "rust verification: nothing ran" >&2
  exit 2
fi
if [[ "$failures" -eq 0 ]]; then
  echo "rust verification: $ran backend(s) pass"
  exit 0
fi
echo "rust verification: $failures of $ran backend(s) failed"
exit 1
