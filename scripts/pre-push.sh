#!/bin/sh
# Pre-push for the `site` branch.
#
# The repo's hook (.git/hooks/pre-push, installed from main by scripts/install-hooks.sh) is a shim
# that runs `scripts/pre-push.sh` from whatever checkout the push comes from. So a push from a
# checkout of this branch runs THIS file, and a push from the app's checkout runs the app's. Two
# consequences:
#   - this file must exist: without it the shim execs a missing file and every push fails;
#   - push site work from a checkout of `site`. Pushed from the app's checkout, the app's hook would
#     run lint and the iOS build against it.
#
# POCKET_PREPUSH=skip bypasses it, as on main (or `git push --no-verify`).
set -eu

if [ "${POCKET_PREPUSH:-}" = "skip" ]; then
  echo "pre-push (site): POCKET_PREPUSH=skip — skipping the check"
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"
[ -d node_modules ] || npm ci --no-audit --no-fund
exec scripts/check.sh
