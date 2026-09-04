#!/usr/bin/env bash
#
# Run the Dafny backend.
#
#   ./scripts/check_dafny.sh
#
# Dafny ships as a self-contained release archive. Grab the one for your
# platform from https://github.com/dafny-lang/dafny/releases, then either put
# it on PATH or point DAFNY at it:
#
#   DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh
#
# Unlike every other backend here, Dafny verifies a program that exists only in
# Dafny. Nothing connects it to src/estimate_size.{py,rs,lean} but a human
# having written the same branches twice -- the same exposure the hand-written
# Lean and Z3 backends carry, and the reason Kani, CrossHair, Verus, and Aeneas
# are worth having alongside it.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$REPO_ROOT/scenarios/estimate_size/verification/dafny_verification/estimate_size.dfy"
DAFNY="${DAFNY:-dafny}"

echo "=============================================================="
echo "[dafny] verification/dafny_verification"
echo "  target: a program written in Dafny; specs and proofs in the same file"

if ! command -v "$DAFNY" >/dev/null 2>&1; then
  echo "  FAIL: dafny not found at '$DAFNY' (set DAFNY=/path/to/dafny)"
  echo "=============================================================="
  echo "dafny verification: 1 backend failed"
  exit 1
fi

if "$DAFNY" verify "$TARGET"; then
  echo "  PASS"
  echo "=============================================================="
  echo "dafny verification: 1 backend passes"
  exit 0
fi

echo "  FAIL"
echo "=============================================================="
echo "dafny verification: 1 backend failed"
exit 1
