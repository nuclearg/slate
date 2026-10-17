#!/bin/bash
#
# Differential test for the Slate script engine.
#
# Runs the same ~/.slate.js probe (script/parity/probe.js) through a reference
# binary and a candidate binary, then diffs the "T|label|value" lines they
# print via slate.log.  The probe covers JS semantics, Slate's ObjC<->JS
# marshalling (BOOL returns, dictionaries, callbacks) and the shell bridge.
#
# Usage:
#   script/verify-parity.sh <reference.app> <candidate.app> [--allow-skip]
#
# --allow-skip: if NEITHER binary produces probe output (no GUI session, e.g. a
# headless CI runner), exit 0 with a SKIP notice instead of failing.  A real
# mismatch, or only one side silent, still fails.
#
# Example:
#   script/verify-parity.sh build/Release/Slate.app build/release-arm64/Slate.app
#
# The reference is normally the original Intel build under Rosetta; the
# candidate is the fresh arm64 build.  Exit status is 0 only when every probe
# line matches.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE="$ROOT/script/parity/probe.js"
TIMEOUT="${SLATE_PARITY_TIMEOUT:-90}"

ALLOW_SKIP=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --allow-skip) ALLOW_SKIP=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done

if [[ ${#ARGS[@]} -ne 2 ]]; then
  echo "usage: $0 <reference.app> <candidate.app> [--allow-skip]" >&2
  exit 2
fi

REF="${ARGS[0]}"
CAND="${ARGS[1]}"

run_app() {
  local app="$1" tag="$2"
  local home="/tmp/slate-parity-$tag-$$"
  local log="/tmp/slate-parity-$tag-$$.log"
  local bin="$app/Contents/MacOS/Slate"

  if [[ ! -x "$bin" ]]; then
    echo "error: $bin is not executable" >&2
    return 1
  fi

  rm -rf "$home"; mkdir -p "$home"
  cp "$PROBE" "$home/.slate.js"

  # CFFIXED_USER_HOME makes Foundation's tilde expansion (and therefore
  # ~/.slate.js) point at the throwaway home instead of the real one.
  CFFIXED_USER_HOME="$home" "$bin" >"$log" 2>&1 &
  local pid=$!

  local waited=0
  while (( waited < TIMEOUT * 10 )); do
    grep -q '^END' "$log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
    ((waited++))
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true

  grep '^T|' "$log" > "/tmp/slate-parity-$tag-$$.txt" || true
  echo "/tmp/slate-parity-$tag-$$.txt"
}

echo "reference: $REF"
echo "candidate: $CAND"
REF_OUT="$(run_app "$REF" ref)"
CAND_OUT="$(run_app "$CAND" cand)"

ref_n=$(wc -l < "$REF_OUT" | tr -d ' ')
cand_n=$(wc -l < "$CAND_OUT" | tr -d ' ')
echo "probe results: reference=$ref_n candidate=$cand_n"

if [[ "$ref_n" -eq 0 && "$cand_n" -eq 0 && "$ALLOW_SKIP" -eq 1 ]]; then
  echo "SKIP: neither binary produced output (no GUI session?); parity not evaluated" >&2
  exit 0
fi

if [[ "$ref_n" -eq 0 || "$cand_n" -eq 0 ]]; then
  echo "FAILED: one of the runs produced no output (modal alert? crash?)" >&2
  echo "--- reference log tail ---" >&2
  tail -20 "/tmp/slate-parity-ref-$$.log" >&2 || true
  echo "--- candidate log tail ---" >&2
  tail -20 "/tmp/slate-parity-cand-$$.log" >&2 || true
  exit 1
fi

if diff -u "$REF_OUT" "$CAND_OUT"; then
  echo "PASS: script engine output is identical ($ref_n probes)"
  exit 0
fi

echo "FAILED: script engine output differs" >&2
exit 1
