#!/bin/sh
# Is a range of commits documentation-only?
#
# Single source of truth for the "does this change need lint/build/test?"
# question, shared by CI (.github/workflows/ci.yml) and the local pre-push hook
# (scripts/pre-push.sh) so the two can't drift apart.
#
#   scripts/docs-only.sh <base-ref> <head-ref>
#
# Prints `true` (docs-only — the expensive checks can be skipped) or `false`.
# Always exits 0; every uncertainty resolves to `false`, because the cost of a
# needless build is minutes and the cost of a skipped one is a broken `main`.
#
# Documentation is deliberately a NARROW allowlist rather than "everything that
# isn't Swift". A denylist silently gets it wrong the first time someone adds a
# file type that does affect the build — an .xctestplan, an asset catalog,
# Package.swift — and the failure mode is a green PR that breaks on merge.

set -eu

BASE="${1:-}"
HEAD="${2:-}"

if [ -z "$BASE" ] || [ -z "$HEAD" ]; then
  echo false
  exit 0
fi

# An unresolvable base (shallow clone, force-push, first push of a branch)
# tells us nothing about the diff — run everything.
if ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  echo false
  exit 0
fi

CHANGED=$(git diff --name-only "$BASE" "$HEAD" 2>/dev/null || true)

# No files resolved: either nothing changed or the diff failed. Either way we
# have no evidence this is docs-only.
if [ -z "$(printf '%s' "$CHANGED" | tr -d '[:space:]')" ]; then
  echo false
  exit 0
fi

# Docs = Markdown anywhere (CHANGELOG.md, PROJECT.md, AGENTS.md, README.md,
# docs/decisions/*.md), anything under docs/ (includes the static docs/site
# pages, which are not part of the Xcode build), and LICENSE.
DOCS_RE='^docs/|(^|/)[^/]*\.md$|^LICENSE$'

if printf '%s\n' "$CHANGED" | grep -qvE "$DOCS_RE"; then
  echo false
else
  echo true
fi
