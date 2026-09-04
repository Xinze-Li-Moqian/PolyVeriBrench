#!/usr/bin/env bash
#
# Run the Python verification backends.
#
#   ./scripts/check_python.sh              # both
#   ./scripts/check_python.sh z3           # just one
#   ./scripts/check_python.sh crosshair
#   ./scripts/check_python.sh nagini
#
# Needs the pinned tools:
#   pip install -r scenarios/primitives/boundary/estimate_size/verification/python_verification/requirements.txt
#
# The two backends sit on opposite sides of the same trade the Rust ones make.
# Z3 re-encodes the program and decides the claims outright. CrossHair reads the
# real src/estimate_size.py and searches -- on this loop-free program it
# exhausts the path tree, so the result is conclusive, but that is a property of
# this program rather than a guarantee of the tool.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYVER_DIR="$REPO_ROOT/scenarios/primitives/boundary/estimate_size/verification/python_verification"
PYTHON="${PYTHON:-python3}"
CROSSHAIR="${CROSSHAIR:-crosshair}"
NAGINI="${NAGINI:-nagini}"

# CrossHair's search is bounded by wall clock, so a slow machine could report a
# clean run for the wrong reason. 30s per claim is ~150x what it needs locally.
PER_CONDITION_TIMEOUT="${PER_CONDITION_TIMEOUT:-30}"

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
      z3|crosshair|nagini) ;;
      *) echo "unknown backend: $want (known: z3 crosshair nagini)" >&2; exit 2 ;;
    esac
  done
fi

failures=0
ran=0

if wanted z3; then
  ran=$((ran + 1))
  echo "=============================================================="
  "$PYTHON" "$PYVER_DIR/z3/estimate_size.py" || failures=$((failures + 1))
fi

if wanted crosshair; then
  ran=$((ran + 1))
  echo "=============================================================="
  echo "[crosshair] verification/python_verification/crosshair"
  echo "  target: the real src/estimate_size.py, symbolically executed"

  # CrossHair prints nothing at all on success, which is indistinguishable from
  # not having run. Report the exit status explicitly instead.
  if "$CROSSHAIR" check \
      --analysis_kind=PEP316 \
      --per_condition_timeout="$PER_CONDITION_TIMEOUT" \
      "$PYVER_DIR/crosshair/estimate_size.py"; then
    echo "  no counterexample found for any claim"
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
fi

if wanted nagini; then
  ran=$((ran + 1))
  echo "=============================================================="
  echo "[nagini] verification/python_verification/nagini"
  echo "  target: annotated Python; Viper discharges the contracts for every input"

  if ! command -v "$NAGINI" >/dev/null 2>&1; then
    echo "  FAIL: nagini not found at '$NAGINI' (needs Java 11+ and Python 3.12-3.14)"
    failures=$((failures + 1))
  elif "$NAGINI" "$PYVER_DIR/nagini/estimate_size.py"; then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
fi

echo "=============================================================="
if [[ "$ran" -eq 0 ]]; then
  echo "python verification: nothing ran" >&2
  exit 2
fi
if [[ "$failures" -eq 0 ]]; then
  echo "python verification: $ran backend(s) pass"
  exit 0
fi
echo "python verification: $failures of $ran backend(s) failed"
exit 1
