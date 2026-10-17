#!/bin/sh
# Is main's UI test job green? The release rule from ADR 0255, as a check.
#
#   scripts/main-ui-green.sh
#
# Since ADR 0255 the UI tests run in their own CI job, `UI tests`, which is not a
# required check: a PR can merge while it is red. So nothing stops a red one reaching
# `main`, and the rule is **no release build until main's UI job is green**. This is
# the check `/ready-to-ship` runs before an archive. Exits 0 only when it passes.
#
# It walks back from main's head to the newest commit whose `UI tests` job actually
# ran, because a docs-only commit skips the job, and the code at the head is the code
# that commit tested. That run must have passed. A cancelled, failed, timed-out or
# still-running result is not green; push again or re-run it.

set -eu

git fetch -q origin main
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

for SHA in $(git rev-list --max-count=30 origin/main); do
  RESULT=$(gh api "repos/$REPO/commits/$SHA/check-runs?check_name=UI%20tests" \
    --jq '[.check_runs[] | .conclusion // .status] | first // "none"')
  SUBJECT=$(git log -1 --format='%h %s' "$SHA")
  case "$RESULT" in
    skipped) continue ;;   # docs-only: the commit below it tested the same code
    none) continue ;;      # no UI job: a commit from before ADR 0255, or CI never ran
    success)
      echo "✅ main's UI tests are green, on $SUBJECT"
      exit 0 ;;
    *)
      echo "❌ main's UI tests are '$RESULT', on $SUBJECT"
      echo "   No release build until they pass (ADR 0255)."
      exit 1 ;;
  esac
done

echo "❌ No UI test result in main's last 30 commits. No release build until one passes (ADR 0255)."
exit 1
