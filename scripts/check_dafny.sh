#!/usr/bin/env bash
#
# Run the Dafny backend across every scenario that has one.
#
#   ./scripts/check_dafny.sh                  # all of them
#   ./scripts/check_dafny.sh binary_search    # only scenarios matching a name
#
# Dafny ships as a self-contained release archive. Grab the one for your
# platform from https://github.com/dafny-lang/dafny/releases, then either put
# it on PATH or point DAFNY at it:
#
#   DAFNY=path/to/dafny/dafny ./scripts/check_dafny.sh
#
# Targets are discovered rather than listed: any *.dfy under a directory named
# dafny_verification is picked up. A new scenario needs no edit here. The other
# runners still hardcode their paths, because a Lake package or a Cargo package
# is not something a glob can find -- when that starts to hurt, a per-scenario
# manifest is the answer, not a longer list.
#
# Unlike Kani and CrossHair, Dafny verifies a program that exists only in Dafny.
# Nothing connects it to the source a scenario ships but a human having written
# the same thing twice -- the same exposure the hand-written Lean and Z3
# backends carry.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAFNY="${DAFNY:-dafny}"
FILTER="${1:-}"

if ! command -v "$DAFNY" >/dev/null 2>&1; then
  echo "dafny not found at '$DAFNY' (set DAFNY=/path/to/dafny)" >&2
  exit 1
fi

targets=()
while IFS= read -r f; do
  [[ -n "$FILTER" && "$f" != *"$FILTER"* ]] && continue
  targets+=("$f")
done < <(find "$REPO_ROOT/scenarios" -type f -name '*.dfy' -path '*/dafny_verification/*' | sort)

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "no Dafny targets found${FILTER:+ matching '$FILTER'}" >&2
  exit 2
fi

failures=0
for target in "${targets[@]}"; do
  rel="${target#"$REPO_ROOT/"}"
  echo "=============================================================="
  echo "[dafny] $rel"
  if "$DAFNY" verify "$target"; then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
done

echo "=============================================================="
if [[ "$failures" -eq 0 ]]; then
  echo "dafny verification: ${#targets[@]} target(s) pass"
  exit 0
fi
echo "dafny verification: $failures of ${#targets[@]} target(s) failed"
exit 1
