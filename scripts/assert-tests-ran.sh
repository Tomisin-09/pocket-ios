#!/bin/sh
# Did the run actually run any tests?
#
#   scripts/assert-tests-ran.sh <raw-xcodebuild-log>
#
# xcodebuild can print `** TEST SUCCEEDED **` and exit 0 having run nothing: ADR 0053
# measured `-only-testing:` on a skipped class doing exactly that. Since ADR 0255 CI runs
# two plans in two jobs, and an edit to either `.xctestplan` could empty it, so each
# job's green has to mean its tests ran. Fails when not one test case passed.
#
# Reads the same raw lines as `report-test-retries.sh` — the log teed out *before*
# xcbeautify, which rewrites them:
#   Test Case '-[PocketTests.TempoMathTests testHalfSpeed]' passed (0.001 seconds).

set -eu

LOG="${1:?usage: assert-tests-ran.sh <raw-xcodebuild-log>}"

PASSED=$(grep -cE "Test Case '[^']+' passed" "$LOG" 2>/dev/null || true)

if [ "${PASSED:-0}" -eq 0 ]; then
  echo "::error title=No tests ran::xcodebuild finished without one passing test case in $LOG. A plan that runs nothing exits 0, so this is a red run, not a clean one."
  exit 1
fi

echo "$PASSED test case(s) passed."
