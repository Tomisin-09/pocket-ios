#!/usr/bin/env bash
#
# Build, install, and launch Pocket on the physical iPhone.
#
# xcodebuild does an *incremental* build, so the compile step is skipped when
# no source has changed — the default path is effectively "rebuild only if
# needed", then install + launch.
#
# Usage:
#   scripts/run-device.sh           build (incremental) → install → launch, with the plan unlocked
#   scripts/run-device.sh -n        skip build; just install + launch existing .app
#   scripts/run-device.sh -s        build without the unlock, so the app asks the real sandbox
#                                   for the plan (the ADR 0256 sandbox pass); -s -n reuses that build
#
# The plan (ADR 0256 D9): a build from here has it, so the phone you develop on opens Practice
# without an App Store purchase. It sets `PLAN_UNLOCKED`, which the app reads only inside
# `#if DEBUG`; this builds Debug, and an archive is Release, so a shipped build never has it.
# The -s build gets its own derived data, because switching the condition recompiles every file.
#
# Device/team values can be overridden via env vars (POCKET_TEAM, POCKET_DEST_UDID,
# POCKET_DEVICECTL_ID, POCKET_BUNDLE_ID) if the hardware ever changes — confirm IDs
# with: xcrun devicectl list devices
#
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

SCHEME="Pocket"
BUNDLE_ID="${POCKET_BUNDLE_ID:-click.decooperations.pocket}"
TEAM="${POCKET_TEAM:-2L35PZ86GP}"   # Deco Operations Ltd (paid); NOT the free personal team YX426B7RZR — free-team builds expire in 7 days
DEST_UDID="${POCKET_DEST_UDID:-00008140-0014684A2284801C}"          # xcodebuild -destination id
DEVICECTL_ID="${POCKET_DEVICECTL_ID:-9328B690-0B53-55B3-978F-C6B3603767B7}"  # devicectl --device
SKIP_BUILD=false
UNLOCK_PLAN=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--no-build) SKIP_BUILD=true ;;
    -s|--sandbox) UNLOCK_PLAN=false ;;
    *) echo "✗ Unknown option: $1 (use -n, -s or both)"; exit 1 ;;
  esac
  shift
done

if $UNLOCK_PLAN; then
  DERIVED="build-device"
  CONDITIONS='$(inherited) PLAN_UNLOCKED'
  PLAN_NOTE="plan unlocked"
else
  DERIVED="build-device-sandbox"
  CONDITIONS='$(inherited)'
  PLAN_NOTE="plan from the sandbox"
fi
APP="$DERIVED/Build/Products/Debug-iphoneos/$SCHEME.app"

# --- Precheck: is the iPhone connected? ---
if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICECTL_ID"; then
  echo "✗ iPhone not found (looking for $DEVICECTL_ID)."
  echo "  Plug it in, unlock it, and make sure Developer Mode is on."
  echo "  See what's connected with: xcrun devicectl list devices"
  exit 1
fi

# --- Build (incremental) ---
if ! $SKIP_BUILD; then
  echo "▸ Building $SCHEME, $PLAN_NOTE (incremental — compile is skipped if nothing changed)…"
  xcodebuild -scheme "$SCHEME" -destination "id=$DEST_UDID" \
    -allowProvisioningUpdates -derivedDataPath "$DERIVED" \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS=$CONDITIONS" build
else
  echo "▸ Skipping build (-n); using the existing .app ($PLAN_NOTE)"
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
