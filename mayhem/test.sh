#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# EDIT: RUN the test runner that mayhem/build.sh produced, then map its output to counts.
#   ctest:        (cd build-tests && ctest) ; parse "<P> tests passed, <F> failed out of <T>"
#   gtest binary: ./build-tests/<prog> ; parse "[==========] N ... ran." / "[  PASSED  ] P" / "[ SKIPPED ] S"
#   make/minunit: ./out/<runner> ; parse its pass/fail/total
# Do NOT compile here — if the runner is absent, fail (build.sh should have produced it).

# Run the ENTIRE upstream C++ suite (googletest binaries tests/*.x, built by
# mayhem/build.sh via `make -C tests cxx-tests` — same set upstream's
# `make run-cxx-tests` runs). Counts come from each binary's gtest summary
# ("[  PASSED  ] N tests" / "[  FAILED  ] N tests"), so a neutered binary that
# exits 0 with no output reports 0 tests and is counted as a failure.
# (Upstream's python/pytest suite for the qsimcirq wrapper is NOT run here: it
# needs the pybind build + cirq-core, a heavy pip dependency tree unrelated to
# the fuzzed C++ core.)
passed=0; failed=0; skipped=0
xs=(tests/*.x)
if [ ! -e "${xs[0]}" ]; then
  echo "FATAL: no built test binaries at tests/*.x — mayhem/build.sh must build the suite" >&2
  emit_ctrf "qsim-cxx-tests" 0 1 0
  exit 1
fi
for x in "${xs[@]}"; do
  out="$("./$x" 2>&1)"; rc=$?
  p="$(printf '%s\n' "$out" | sed -n 's/.*\[  PASSED  \] \([0-9][0-9]*\) test.*/\1/p' | tail -1)"
  f="$(printf '%s\n' "$out" | sed -n 's/.*\[  FAILED  \] \([0-9][0-9]*\) test.*/\1/p' | tail -1)"
  s="$(printf '%s\n' "$out" | sed -n 's/.*\[  SKIPPED \] \([0-9][0-9]*\) test.*/\1/p' | tail -1)"
  if [ -z "$p" ] && [ -z "$f" ]; then
    # no parseable gtest summary — the binary crashed or was neutered; that is a failure
    echo "NO-SUMMARY (rc=$rc): $x" >&2
    failed=$((failed + 1))
    continue
  fi
  passed=$((passed + ${p:-0})); failed=$((failed + ${f:-0})); skipped=$((skipped + ${s:-0}))
  if [ $rc -ne 0 ] && [ "${f:-0}" -eq 0 ]; then
    echo "NONZERO-EXIT (rc=$rc) with no reported failures: $x" >&2
    failed=$((failed + 1))
  fi
  echo "$x: passed=${p:-0} failed=${f:-0} skipped=${s:-0}"
done
emit_ctrf "qsim-cxx-tests" "$passed" "$failed" "$skipped"
