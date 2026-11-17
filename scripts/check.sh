#!/bin/sh
# The site's check. CI runs it on every pull request into `site` and every push to it
# (.github/workflows/site.yml), and scripts/pre-push.sh runs it before a push leaves this machine.
#
#   1. The build: TypeScript, every page rendered, and the manual's own checks (a link to a page that
#      doesn't exist or an #anchor that names no heading fails it — ADR 0217 D3).
#   2. Joined words in the rendered HTML: `</strong>—` where the source had `</strong> —`. JSX eats a
#      space before a line break, and on the same line before an HTML entity, so write the character
#      (—) rather than the entity (&mdash;). The class names what is WRONG after a closing tag.
#   3. Red Moon, never Pocket: `Pocket` is the app's internal target name, never a name it goes by
#      (the same rule the app repo's SwiftLint enforces on Swift).
#
# Both scans read the rendered pages, so each first checks there are pages to read: a scan over
# nothing passes.
set -eu
cd "$(dirname "$0")/.."

# A cold fetch of the Google fonts sometimes fails the build with this one message, and the same tree
# then builds clean (seen locally on 2026-11-16 and 2026-11-17). Retry once for that message only;
# any other failure fails at once. If it ever fails twice, host the fonts in the site (ADR 0306).
FONT_FLAKE='next/font/google queries have exactly one entry'
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
if ! npm run build >"$LOG" 2>&1; then
  cat "$LOG"
  if grep -q "$FONT_FLAKE" "$LOG"; then
    echo "check: the build failed on the cold Google-font fetch; building once more." >&2
    npm run build
  else
    exit 1
  fi
else
  cat "$LOG"
fi

OUT=.next/server/app
RENDERED=$(find "$OUT" -name '*.html' | wc -l | tr -d ' ')
if [ "$RENDERED" -lt 20 ]; then
  echo "check: only $RENDERED rendered pages under $OUT; the scans below would prove nothing." >&2
  exit 1
fi

JOINED=$(grep -rhoE '</(strong|em|code|a)>[A-Za-z0-9—–(]' "$OUT" --include='*.html' || true)
if [ -n "$JOINED" ]; then
  echo "check: words joined to the tag before them (a space lost to a line break or an entity):" >&2
  grep -rnoE '.{0,40}</(strong|em|code|a)>[A-Za-z0-9—–(].{0,20}' "$OUT" --include='*.html' >&2 || true
  exit 1
fi

NAMED=$(grep -rlw 'Pocket' "$OUT" --include='*.html' || true)
if [ -n "$NAMED" ]; then
  echo "check: user-facing copy says Pocket; the app is Red Moon:" >&2
  echo "$NAMED" >&2
  exit 1
fi

echo "check: built; $RENDERED pages scanned, no joined words, no 'Pocket'."
