#!/bin/sh
# Install repo git hooks. Run once after cloning:  ./scripts/install-hooks.sh
#
# We can't version-control .git/hooks directly, so this drops a thin shim that
# execs the tracked script in scripts/. Re-run is safe (idempotent overwrite).
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
HOOK="$REPO_ROOT/.git/hooks/pre-push"

cat > "$HOOK" <<'SHIM'
#!/bin/sh
# Managed by scripts/install-hooks.sh — edits go in scripts/pre-push.sh.
exec "$(git rev-parse --show-toplevel)/scripts/pre-push.sh" "$@"
SHIM

chmod +x "$HOOK" "$REPO_ROOT/scripts/pre-push.sh"
echo "Installed pre-push hook → scripts/pre-push.sh"
echo "Tiers: POCKET_PREPUSH=fast (default) | full (runs PocketAll) | skip"
echo "Bypass once: git push --no-verify"
