#!/bin/sh
# Boot the simulator CI tests on. One answer, shared by both macOS jobs in ci.yml.
#
#   scripts/ci-simulator.sh "iPhone 16 Pro" 18.5
#
# Finds the named iPhone on the named iOS runtime, boots it and waits until it has
# settled (ADR 0146), then hands its UDID to the later steps as `SIM_UDID` through
# `$GITHUB_ENV`. Outside Actions it prints the UDID instead.
#
# **Pinned by name and iOS version** (ADR 0255). It used to take the first iPhone
# `simctl` listed, so a runner image update could move CI to another OS without a line
# changing here. iOS 18 is deliberate: it is older than the iOS 26 run locally and on
# the phone, and two bugs that passed on both only showed up on it (a `.sheet` on a List
# row losing its write; a toolbar Menu that was never hittable). A miss fails, and lists
# what the runner does have, because a silent fallback is how the OS would drift.

set -eu

NAME="${1:?usage: ci-simulator.sh <device name> <iOS version>}"
OS="${2:?usage: ci-simulator.sh <device name> <iOS version>}"

RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-$(printf '%s' "$OS" | tr . -)"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
print(next((d["udid"] for d in devices if d["name"] == name), ""))
' "$NAME" "$RUNTIME")

if [ -z "$UDID" ]; then
  echo "::error title=CI simulator missing::This runner has no '$NAME' on iOS $OS. Pick one from the list in this step's log and change SIM_NAME / SIM_OS in .github/workflows/ci.yml."
  xcrun simctl list devices available
  exit 1
fi

echo "Using $NAME on iOS $OS: $UDID"
# Boot and settle BEFORE the timed run. A cold UDID handed straight to `xcodebuild test`
# puts boot and SpringBoard settling inside the window the UI tests' waits are budgeted
# against. `boot` may fail harmlessly: an already-booted device exits non-zero.
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "SIM_UDID=$UDID" >> "$GITHUB_ENV"
else
  echo "$UDID"
fi
