#!/usr/bin/env bash
#
# Audit what every Lean theorem in this repo actually depends on.
#
#   ./scripts/check_axioms.sh              # every project
#   ./scripts/check_axioms.sh native       # just one (CI runs them as separate jobs,
#   ./scripts/check_axioms.sh aeneas       #  because the Aeneas project needs Mathlib)
#
# Builds each Lean project, then reports the axioms behind each of its theorems
# (see scripts/AxiomCheck.lean.tmpl for the classification policy). Exits
# non-zero if any theorem rests on `sorryAx`, on `native_decide`'s compiler
# axioms, or on an axiom the policy does not recognise.
#
# This catches what `grep sorry` cannot: a proof admitted in a dependency rather
# than in the file under review. The vendored Aeneas standard library contains
# several `sorry`s, so that is a live possibility here, not a hypothetical.
#
# The two projects use different toolchains (v4.33.1 and v4.31.0); `lake env`
# picks the right one from each project's lean-toolchain.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPL="$REPO_ROOT/scripts/AxiomCheck.lean.tmpl"

# "<short name>|<project dir relative to repo root>|<module to audit>"
PROJECTS=(
  "native|scenarios/estimate_size|verification.lean_verification.estimate_size"
  "aeneas|scenarios/estimate_size/verification/rust_verification/aeneas|EstimateSizeAeneas.Proofs"
)

if [[ ! -f "$TMPL" ]]; then
  echo "missing template: $TMPL" >&2
  exit 2
fi

# With no arguments every project runs; otherwise only the ones named.
selected=("$@")
if [[ ${#selected[@]} -gt 0 ]]; then
  for want in "${selected[@]}"; do
    found=0
    for entry in "${PROJECTS[@]}"; do
      [[ "${entry%%|*}" == "$want" ]] && found=1
    done
    if [[ "$found" -eq 0 ]]; then
      echo "unknown project: $want" >&2
      echo "known: $(printf '%s ' "${PROJECTS[@]%%|*}")" >&2
      exit 2
    fi
  done
fi

wanted () {
  [[ ${#selected[@]} -eq 0 ]] && return 0
  for want in "${selected[@]}"; do
    [[ "$want" == "$1" ]] && return 0
  done
  return 1
}

TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

failures=0

ran=0

for entry in "${PROJECTS[@]}"; do
  name="${entry%%|*}"
  rest="${entry#*|}"
  dir="${rest%%|*}"
  module="${rest##*|}"
  abs="$REPO_ROOT/$dir"

  wanted "$name" || continue
  ran=$((ran + 1))

  echo "=============================================================="
  echo "[$name] $dir"
  echo "  module: $module"

  if [[ ! -d "$abs" ]]; then
    echo "  SKIP: directory not found"
    failures=$((failures + 1))
    continue
  fi

  build_log="$TMPDIR_RUN/build.log"
  if ! (cd "$abs" && lake build) >"$build_log" 2>&1; then
    echo "  FAIL: lake build failed"
    sed 's/^/    /' "$build_log" | tail -30
    failures=$((failures + 1))
    continue
  fi

  # Surface `sorry` warnings from dependencies; they are why this check exists.
  dep_sorries="$(grep -c "declaration uses 'sorry'\|declaration uses \`sorry\`" "$build_log" 2>/dev/null || true)"
  if [[ "${dep_sorries:-0}" -gt 0 ]]; then
    echo "  note: $dep_sorries 'declaration uses sorry' warning(s) while building dependencies"
  fi

  probe="$TMPDIR_RUN/AxiomCheck_$(echo "$module" | tr './' '__').lean"
  sed "s|__MODULE__|$module|g" "$TMPL" >"$probe"

  if (cd "$abs" && lake env lean "$probe"); then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
done

echo "=============================================================="
if [[ "$ran" -eq 0 ]]; then
  echo "axiom audit: nothing ran" >&2
  exit 2
fi
if [[ "$failures" -eq 0 ]]; then
  echo "axiom audit: $ran project(s) pass"
  exit 0
fi
echo "axiom audit: $failures of $ran project(s) failed"
exit 1
