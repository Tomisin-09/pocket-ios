#!/bin/sh
# Which tests only passed because CI retried them?
#
#   scripts/report-test-retries.sh <raw-xcodebuild-log>
#
# CI runs the suite with `-retry-tests-on-failure -test-iterations 3` (ADR 0146).
# That keeps a one-off timing loss on a cold simulator from reddening `main`, but
# it also means a green tick no longer proves every test passed first time. This
# script closes that gap: it names every test that failed at least one attempt, as
# a GitHub warning annotation and in the job summary.
#
# **A green run with retries in it is not a clean run.** A test that needs a retry
# is either racing the app or racing the runner, and the next person to see it red
# will have no idea it was already flaking.
#
# Always exits 0. This reports; it never decides the build. Failing here would
# re-create the exact problem retries were added to solve, and the retry itself is
# already recorded in the result bundle for anyone who wants the detail.

set -eu

LOG="${1:-}"

if [ -z "$LOG" ] || [ ! -f "$LOG" ]; then
  echo "No xcodebuild log at '${LOG:-<unset>}' — nothing to report."
  exit 0
fi

# xcodebuild prints one line per attempt:
#   Test Case '-[PocketUITests.PracticeRunUITests testRunsARamp]' failed (21.004 seconds).
# Matching the raw stream rather than the result bundle keeps this working across
# Xcode versions — `xcresulttool`'s JSON schema has changed shape more than once,
# and CI's Xcode (16, macOS-15) is older than local (26.5).
# "No failures" and "no test results at all" look identical if you only grep for
# failures, and the second one reported as the first is exactly the false
# reassurance this script exists to prevent — a build that died before running a
# test would otherwise be announced as a clean suite. Establish that tests ran
# before drawing any conclusion from the absence of failures.
TOTAL=$(grep -cE "Test Case '[^']+' (passed|failed)" "$LOG" 2>/dev/null || true)

if [ "${TOTAL:-0}" -eq 0 ]; then
  echo "::warning title=No test results in the log::No 'Test Case' lines found in '$LOG' — the run probably died before the tests started. This is NOT a clean suite; check the build step."
  echo "No test results found in '$LOG' — nothing ran, so nothing can be said about flakes."
  exit 0
fi

RETRIED=$(grep -oE "Test Case '[^']+' failed" "$LOG" 2>/dev/null \
  | sed -E "s/^Test Case '(.*)' failed$/\1/" \
  | sort -u || true)

if [ -z "$RETRIED" ]; then
  echo "$TOTAL test result(s) recorded, no failures — every test passed on its first attempt."
  exit 0
fi

COUNT=$(printf '%s\n' "$RETRIED" | wc -l | tr -d ' ')

echo "$COUNT test(s) failed at least one attempt:"
printf '%s\n' "$RETRIED" | sed 's/^/  /'

# GitHub annotations surface on the PR itself, not just in the log.
printf '%s\n' "$RETRIED" | while IFS= read -r TEST; do
  [ -n "$TEST" ] || continue
  echo "::warning title=Test needed a retry::$TEST failed at least one attempt. If the job is green it only passed on retry — treat this as a flake to fix, not a pass."
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### ⚠️ $COUNT test(s) needed a retry"
    echo
    echo "A green run with retries in it is **not** a clean run (ADR 0146)."
    echo
    printf '%s\n' "$RETRIED" | sed 's/^/- `/; s/$/`/'
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit 0
