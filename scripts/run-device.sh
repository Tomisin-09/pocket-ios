#!/usr/bin/env bash
#
# Build, install, and launch Pocket on the physical iPhone.
#
# xcodebuild does an *incremental* build, so the compile step is skipped when
# no source has changed — the default path is effectively "rebuild only if
# needed", then install + launch.
#
# Usage:
#   scripts/run-device.sh           build (incremental) → install → launch
#   scripts/run-device.sh -n        skip build; just install + launch existing .app
#
# Device/team values can be overridden via env vars (POCKET_TEAM, POCKET_DEST_UDID,
# POCKET_DEVICECTL_ID, POCKET_BUNDLE_ID) if the hardware ever changes — confirm IDs
# with: xcrun devicectl list devices
#
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

SCHEME="Pocket"
BUNDLE_ID="${POCKET_BUNDLE_ID:-click.decooperations.pocket}"
TEAM="${POCKET_TEAM:-YX426B7RZR}"
DEST_UDID="${POCKET_DEST_UDID:-00008140-0014684A2284801C}"          # xcodebuild -destination id
DEVICECTL_ID="${POCKET_DEVICECTL_ID:-9328B690-0B53-55B3-978F-C6B3603767B7}"  # devicectl --device
DERIVED="build-device"
APP="$DERIVED/Build/Products/Debug-iphoneos/$SCHEME.app"

SKIP_BUILD=false
if [[ "${1:-}" == "-n" || "${1:-}" == "--no-build" ]]; then
  SKIP_BUILD=true
fi

# --- Precheck: is the iPhone connected? ---
if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICECTL_ID"; then
  echo "✗ iPhone not found (looking for $DEVICECTL_ID)."
  echo "  Plug it in, unlock it, and make sure Developer Mode is on."
  echo "  See what's connected with: xcrun devicectl list devices"
  exit 1
fi

# --- Build (incremental) ---
if ! $SKIP_BUILD; then
  echo "▸ Building $SCHEME (incremental — compile is skipped if nothing changed)…"
  xcodebuild -scheme "$SCHEME" -destination "id=$DEST_UDID" \
    -allowProvisioningUpdates -derivedDataPath "$DERIVED" \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build
else
  echo "▸ Skipping build (-n); using existing .app"
fi

# --- Verify the .app is there ---
if [[ ! -d "$APP" ]]; then
  echo "✗ No built app at $APP — run without -n to build it first."
  exit 1
fi

# --- Install + launch ---
echo "▸ Installing onto device…"
xcrun devicectl device install app --device "$DEVICECTL_ID" "$APP"

echo "▸ Launching ${BUNDLE_ID}…"
xcrun devicectl device process launch --device "$DEVICECTL_ID" "$BUNDLE_ID"

echo "✓ Pocket is running on your iPhone."
