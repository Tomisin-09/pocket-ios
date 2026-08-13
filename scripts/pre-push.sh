#!/bin/sh
# Pre-push guard — mirror CI locally so failures surface BEFORE the merge,
# not as a follow-up "Fix CI" commit.
#
# CI (.github/workflows/ci.yml) runs, in order:
#   xcodegen generate → swiftlint --strict → xcodebuild test -testPlan PocketAll
# on an OLDER toolchain (macOS-15 / Xcode 16, Swift 6 strict) than this Mac
# (Xcode 26.5), which is why lint/build/test can pass locally and fail on CI.
# We can't downgrade the compiler, but we can run the same --strict lint, the
# same PocketAll plan, and force complete concurrency checking to surface most
# main-actor-isolation drift early.
#
# Tiers (set POCKET_PREPUSH):
#   fast  (default) — xcodegen + swiftlint --strict + build (strict concurrency)
#   full            — also runs the PocketAll test plan (matches CI exactly)
#   skip            — bypass entirely (same as `git push --no-verify`)
#
# The manual check (ADR 0165) sits OUTSIDE the tiers and runs on every push,
# including `skip` and docs-only ones — see the note at the top of the script.
#
# Installed as .git/hooks/pre-push by scripts/install-hooks.sh.

set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# --- The manual (ADR 0165) -------------------------------------------------
# Deliberately ABOVE the tier logic and above `skip`: this is the one check whose
# whole subject is documentation, so the two states that turn everything else off
# — a docs-only push, and POCKET_PREPUSH=skip — are exactly the states in which it
# most needs to run. It is stdlib Python over markdown; it costs a fraction of a
# second, so there is no tier worth giving it.
if [ -x scripts/check-manual.py ]; then
  scripts/check-manual.py >/dev/null || {
    echo "pre-push: the manual is out of step with the app —"
    scripts/check-manual.py || true
    exit 1
  }
fi

MODE="${POCKET_PREPUSH:-fast}"
if [ "$MODE" = "skip" ]; then
  echo "pre-push: POCKET_PREPUSH=skip — skipping checks"
  exit 0
fi

# --- Figure out what's actually being pushed -------------------------------
# Pre-push receives "<local ref> <local sha> <remote ref> <remote sha>" lines on
# stdin. A docs-only push doesn't need a 2-minute build — and CI now skips it
# too, via the SAME rule: scripts/docs-only.sh is the single source of truth for
# both, so local and CI can't disagree about what counts as documentation.
ZERO=0000000000000000000000000000000000000000
SAW_REF=0
DOCS_ONLY=1
while read -r _local_ref local_sha _remote_ref remote_sha; do
  [ "$local_sha" = "$ZERO" ] && continue            # branch deletion — nothing to build
  SAW_REF=1
  if [ "$remote_sha" = "$ZERO" ]; then
    base=$(git merge-base origin/main "$local_sha" 2>/dev/null || echo "")   # new branch
  else
    base="$remote_sha"
  fi
  # An unknown base yields `false`, i.e. run everything — the safe direction.
  if [ "$(scripts/docs-only.sh "$base" "$local_sha")" != "true" ]; then
    DOCS_ONLY=0
  fi
done

# When run manually (no stdin range) there's nothing to scope against, so run
# the full set of checks.
[ "$SAW_REF" -eq 1 ] || DOCS_ONLY=0

if [ "$DOCS_ONLY" -eq 1 ]; then
  echo "pre-push: documentation-only push — skipping lint/build/test. ✅"
  exit 0
fi

# --- Regenerate project (source of truth is project.yml) -------------------
echo "pre-push: xcodegen generate…"
xcodegen generate >/dev/null

# --- Lint (fast, catches the most common CI failure) -----------------------
echo "pre-push: swiftlint --strict…"
swiftlint --strict

# Optional prettifier; fall back to a plain pipe if xcbeautify isn't installed.
if command -v xcbeautify >/dev/null 2>&1; then
  PRETTY="xcbeautify"
else
  PRETTY="cat"
fi

if [ "$MODE" = "full" ]; then
  # Exact CI parity: run the PocketAll plan (this is the ONLY way PocketUITests
  # actually compile+run — a plain local test run silently skips them).
  echo "pre-push: xcodebuild test -testPlan PocketAll (full)…"
  UDID=$(xcrun simctl list devices available \
    | grep -E 'iPhone' \
    | grep -oE '[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}' \
    | head -n 1)
  if [ -z "$UDID" ]; then
    echo "pre-push: no available iPhone simulator found."; exit 1
  fi
  # Boot and settle first, as CI does (ADR 0146) — otherwise device boot is spent
  # inside the window the UI tests' own waits are budgeted against.
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
  set -o pipefail 2>/dev/null || true
  # Deliberately WITHOUT CI's `-retry-tests-on-failure`. The parity that matters is
  # the plan and the destination; retries exist to stop a cold-runner timing loss
  # reddening `main`, and locally you want to see the flake, not have it papered over.
  xcodebuild test \
    -scheme Pocket \
    -testPlan PocketAll \
    -destination "id=$UDID" \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_STRICT_CONCURRENCY=complete \
    | $PRETTY
else
  # Fast tier: build only, but with complete concurrency checking so main-actor
  # isolation errors that CI's older compiler flags surface here too.
  # Warnings-as-errors is NOT passed here: a command-line build setting applies to every
  # target in the graph, and SPM dependencies are compiled with `-suppress-warnings`, which
  # conflicts with it. It lives on the Pocket target in project.yml (Debug) instead, so our
  # code is still held to it while package sources are left alone.
  echo "pre-push: xcodebuild build (strict concurrency)…"
  set -o pipefail 2>/dev/null || true
  xcodebuild build \
    -scheme Pocket \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_STRICT_CONCURRENCY=complete \
    | $PRETTY
fi

echo "pre-push: all checks passed ✅"
