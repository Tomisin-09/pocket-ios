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
# Installed as .git/hooks/pre-push by scripts/install-hooks.sh.

set -eu

MODE="${POCKET_PREPUSH:-fast}"
if [ "$MODE" = "skip" ]; then
  echo "pre-push: POCKET_PREPUSH=skip — skipping checks"
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# --- Figure out what's actually being pushed -------------------------------
# Pre-push receives "<local ref> <local sha> <remote ref> <remote sha>" lines on
# stdin. Collect the local shas so we can see whether any buildable file changed;
# a docs-only push doesn't need a 2-minute build.
ZERO=0000000000000000000000000000000000000000
RANGE_FILES=""
while read -r _local_ref local_sha _remote_ref remote_sha; do
  [ "$local_sha" = "$ZERO" ] && continue            # branch deletion — nothing to build
  if [ "$remote_sha" = "$ZERO" ]; then
    base=$(git merge-base origin/main "$local_sha" 2>/dev/null || echo "")   # new branch
  else
    base="$remote_sha"
  fi
  if [ -n "$base" ]; then
    RANGE_FILES="$RANGE_FILES
$(git diff --name-only "$base" "$local_sha")"
  else
    RANGE_FILES="$RANGE_FILES
$(git show --name-only --pretty=format: "$local_sha")"
  fi
done

# If stdin gave us a range, use it to decide whether a build is needed.
# When run manually (no stdin range), always build.
NEEDS_BUILD=1
if [ -n "$(printf '%s' "$RANGE_FILES" | tr -d '[:space:]')" ]; then
  if ! printf '%s\n' "$RANGE_FILES" | grep -qE '\.swift$|project\.yml$|\.xcconfig$|\.entitlements$|Info\.plist$|\.swiftlint\.yml$'; then
    NEEDS_BUILD=0
  fi
fi

# --- Regenerate project (source of truth is project.yml) -------------------
echo "pre-push: xcodegen generate…"
xcodegen generate >/dev/null

# --- Lint (fast, catches the most common CI failure) -----------------------
echo "pre-push: swiftlint --strict…"
swiftlint --strict

if [ "$NEEDS_BUILD" -eq 0 ]; then
  echo "pre-push: no buildable files changed — skipping build/test. ✅"
  exit 0
fi

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
  set -o pipefail 2>/dev/null || true
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
  echo "pre-push: xcodebuild build (strict concurrency)…"
  set -o pipefail 2>/dev/null || true
  xcodebuild build \
    -scheme Pocket \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    | $PRETTY
fi

echo "pre-push: all checks passed ✅"
