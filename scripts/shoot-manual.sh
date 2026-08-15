#!/usr/bin/env bash
#
# Shoot the user manual (ADR 0165, Phase 5).
#
# Drives `PocketUITests/ManualShotsUITests` against a freshly erased simulator and exports the
# captures. Exists as a script rather than a paragraph in a README because the *order* is the whole
# problem: the seed audio has to be on the device before the app's first launch, and the app has to
# be installed before there is a container to put it in. Get that order wrong and every seed guard
# has already fired by the time the audio lands — `ScreenshotSeed` skips a library that has songs
# in it, so the run is silently a one-song shoot and looks exactly like a working one.
#
#   ./scripts/shoot-manual.sh                       # iPhone 17, ~/Documents/…/seed-audio
#   POCKET_SIM="iPhone 17 Pro" ./scripts/shoot-manual.sh
#   POCKET_SEED_AUDIO=/path/to/masters ./scripts/shoot-manual.sh
#   POCKET_SHOOT_ONLY=ManualToolkitShots ./scripts/shoot-manual.sh    # one class while writing it
#
# `-enableCodeCoverage NO`: the plan turns coverage on, which instruments the app under test and buys
# a shoot nothing. It is timing cost on exactly the code path the captures race against. Passed to
# **both** xcodebuild calls on purpose — instrumentation is decided when the binary is built, so the
# flag on `test-without-building` alone would skip gathering the data while still paying for it.
#
# Masters may be any format `afconvert` reads; they are transcoded to WAV on the way in, because the
# simulator's decoder fails *silently* on the `.m4a` originals and `importReal` returns early.
#
set -euo pipefail

SIM_NAME="${POCKET_SIM:-iPhone 17}"
# The shoot's test classes, listed rather than inferred. They are split by area of the manual so one
# broken tap doesn't take an unrelated page's figures down with it, which means adding an area means
# adding a line here — a visible cost, and the alternative (running the whole target and skipping the
# four ordinary UI-test classes) inverts it onto every future non-shoot test instead.
SHOOT_CLASSES=(
    ManualShotsUITests
    ManualSettingsShots
    ManualToolkitShots
    ManualMetronomeShots
)

# `POCKET_SHOOT_ONLY` narrows the run to one class (or a space-separated few) while a new area is
# being written. The full set is ~6 minutes and a single class is well under one, and the difference
# is not convenience: a six-minute turn on a missed tap encourages guessing at the next selector
# instead of reading the step log. Always finish with a full run — the filed set is only coherent
# when every figure came from the same seed on the same erased device.
if [ -n "${POCKET_SHOOT_ONLY:-}" ]; then
    # shellcheck disable=SC2206  # deliberate word-splitting: this takes a list of class names
    SHOOT_CLASSES=($POCKET_SHOOT_ONLY)
    echo "▸ Narrowed to: ${SHOOT_CLASSES[*]} (partial run — not a complete set)"
fi
BUNDLE_ID="click.decooperations.pocket"
SEED_AUDIO_SRC="${POCKET_SEED_AUDIO:-$HOME/Documents/Red Moon Screenshots 2/seed-audio}"
DERIVED="${POCKET_DERIVED:-build-sim}"
OUT_DIR="${POCKET_SHOT_OUT:-shots}"
RESULT_BUNDLE="$OUT_DIR/shoot.xcresult"

say() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# --- 1. a device with nothing on it -------------------------------------------------------------
# Both seeds are idempotent by design, which is the right behaviour in the app and the wrong one
# here: a re-run against a dirty device photographs the *previous* run's data.
say "Erasing $SIM_NAME"
xcrun simctl shutdown "$SIM_NAME" 2>/dev/null || true
xcrun simctl erase "$SIM_NAME"
xcrun simctl boot "$SIM_NAME"

# **Wait for the boot to actually finish.** `simctl boot` returns as soon as the device starts coming
# up, not when it is usable, and an erased device's first boot is heavy — asset extraction, Metal
# shader compilation, PosterBoard, mobileassetd — enough to put this Mac's load average over 130.
#
# Without this wait the shoot's flakiness depended on something absurd: whether the *build* was warm.
# A cold run does `build-for-testing` for minutes and the simulator settles behind it; a warm re-run
# goes straight to `test-without-building` and starts tapping into a saturated machine. Three
# consecutive warm runs each failed a different test — metronome, then glossary, then privacy — which
# reads as random and is not. `bootstatus -b` blocks until the device reports booted, so both paths
# start from the same place.
say "Waiting for $SIM_NAME to finish booting"
xcrun simctl bootstatus "$SIM_NAME" -b

# A fresh simulator boots **light**, and every other image in the manual — the beta guide's, the
# creative brief's — is dark. One light figure in the middle of a page is the thing a reader
# notices. This is not a preference; it is the set staying one set.
#
# Home's greeting is computed from the *real* clock, which the status-bar override does not touch.
# What matters is the **bucket, not the clock**: `HomeFeed.TimeOfDay.at(hour:)` reads 5–11 as
# morning, so anything in that range produces the same "Good morning" a 09:41 status bar implies —
# an earlier guard here said 09:00 and sent the shoot away for no reason at 08:30. What actually
# breaks the figure is crossing into another bucket: shoot at 02:00 and the frame says "Late
# session" under a morning clock, a contradiction inside one image that no assertion catches,
# because both halves are individually correct.
HOUR="$(date +%-H)"
if [ "$HOUR" -lt 5 ] || [ "$HOUR" -gt 11 ]; then
    echo "⚠️  It is $(date +%H:%M) locally, but the status bar is faked to 09:41." >&2
    echo "   Home's greeting reads the real clock and is only 'Good morning' from 05:00 to 11:59," >&2
    echo "   so the shot will disagree with its own status bar." >&2
    # A hard stop, not a warning. This began as a warning, and a warning is the wrong shape for it:
    # it scrolls past inside a ten-minute run, every test still passes, and the contradiction lives
    # in the pixels of `reference/home` where no assertion can reach it. The whole harness is built
    # on the principle that a green run proves nothing about the picture — a check that only prints
    # is a check that participates in exactly the failure it was written to prevent.
    if [ -z "${POCKET_SHOOT_ANY_HOUR:-}" ]; then
        echo "" >&2
        echo "   Refusing to shoot. Run between 05:00 and 11:59, or set POCKET_SHOOT_ANY_HOUR=1 to" >&2
        echo "   validate the harness — in which case reference/home is NOT shippable." >&2
        exit 1
    fi
    echo "   POCKET_SHOOT_ANY_HOUR is set — continuing. reference/home will be wrong." >&2
fi

say "Forcing dark appearance and a clean status bar"
xcrun simctl ui "$SIM_NAME" appearance dark
# 09:41, full bars, no carrier noise — the same status bar the App Store shots carry, so a hand-shot
# device figure and a driven one differ only in the clock.
xcrun simctl status_bar "$SIM_NAME" override \
    --time "09:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

# --- 2. build, then install without launching ---------------------------------------------------
# `build-for-testing` rather than `test`, so nothing launches until the audio is staged.
say "Building for testing"
xcodebuild build-for-testing \
    -scheme Pocket \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -testPlan PocketAll \
    -derivedDataPath "$DERIVED" \
    -enableCodeCoverage NO \
    -quiet

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Pocket.app"
[ -d "$APP_PATH" ] || { echo "no app at $APP_PATH" >&2; exit 1; }

say "Installing"
xcrun simctl install "$SIM_NAME" "$APP_PATH"

# --- 3. stage the seed audio --------------------------------------------------------------------
if [ -d "$SEED_AUDIO_SRC" ]; then
    CONTAINER="$(xcrun simctl get_app_container "$SIM_NAME" "$BUNDLE_ID" data)"
    DEST="$CONTAINER/Documents/SeedAudio"
    mkdir -p "$DEST"

    say "Staging seed audio → $DEST"
    count=0
    for master in "$SEED_AUDIO_SRC"/*; do
        [ -f "$master" ] || continue
        base="$(basename "${master%.*}")"
        # Mono 16-bit 44.1k: small, and what the extractor and the simulator both read reliably.
        afconvert -f WAVE -d LEI16@44100 -c 1 "$master" "$DEST/$base.wav"
        count=$((count + 1))
    done
    echo "  $count file(s) staged"
    [ "$count" -ge 5 ] || echo "  ⚠️  fewer than 5 — the library shots expect six songs including Little Wing"
else
    echo "⚠️  no seed audio at '$SEED_AUDIO_SRC' — the shoot will run with Little Wing only." >&2
    echo "   Set POCKET_SEED_AUDIO to the masters directory." >&2
fi

# --- 4. shoot -----------------------------------------------------------------------------------
say "Shooting"
mkdir -p "$OUT_DIR"
rm -rf "$RESULT_BUNDLE"
ONLY_TESTING=()
for class in "${SHOOT_CLASSES[@]}"; do
    ONLY_TESTING+=("-only-testing:PocketUITests/$class")
done
xcodebuild test-without-building \
    -scheme Pocket \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -testPlan PocketAll \
    "${ONLY_TESTING[@]}" \
    -derivedDataPath "$DERIVED" \
    -enableCodeCoverage NO \
    -resultBundlePath "$RESULT_BUNDLE" 2>&1 \
    | tee "$OUT_DIR/shoot.log" \
    | grep -E "Test Case .* (passed|failed)|TEST (EXECUTE )?(SUCCEEDED|FAILED)" || true

# `2>&1` **before** the pipe, and it is load-bearing: xcodebuild prints the failing verdict on
# **stderr** and the succeeding one on stdout. Without it a failed shoot tees a log with no verdict
# in it at all, and the check below reports "no verdict line" — the right exit code for the wrong
# reason, and a misleading thing to hand someone at the end of a six-minute run.
#
# `tee` means `$?` is grep's, so read the verdict out of the log rather than trusting the pipeline.
# Two spellings, because `test-without-building` says **TEST EXECUTE FAILED** where `test` says
# **TEST FAILED** — matching only the latter reads a failed shoot as a missing verdict.
#
# The display filter above needs both spellings for the same reason, and for a while did not: a
# fully green shoot printed sixteen passing test cases and **no verdict line at all**, because
# `TEST (SUCCEEDED|FAILED)` cannot match `TEST EXECUTE SUCCEEDED`. The check below read the log and
# was right; the console was silent about the one line a reader is told to look for. A filter that
# hides the verdict is worse than no filter, because it teaches you to accept its absence.

# A narrowed run files somewhere else. `file-shots.py` empties its target first — it has to, or a
# renamed slug leaves its old image behind to be shipped — and pointing a four-figure run at the
# directory holding the full set would delete the other ninety-two. `filed/` therefore only ever
# means "everything, from one erased device"; a partial run is visibly partial.
FILED="$OUT_DIR/filed"
[ -n "${POCKET_SHOOT_ONLY:-}" ] && FILED="$OUT_DIR/filed-partial"

if grep -qE "TEST FAILED|TEST EXECUTE FAILED" "$OUT_DIR/shoot.log"; then
    # A failed shoot never reaches the filing step, so whatever is sitting in $FILED is from an
    # earlier run against an earlier build — sixteen slug-named PNGs that look exactly like a
    # finished set, because last time they were one. Say so *in the directory*: that is where
    # someone reaching for the images looks, and the terminal telling them not to has by then
    # scrolled past. The marker is a plain file, so the next successful filing deletes it along
    # with everything else it clears out.
    if [ -d "$FILED" ]; then
        cat > "$FILED/STALE-DO-NOT-SHIP.txt" <<STALE
The shoot that ran at $(date "+%Y-%m-%d %H:%M") FAILED, and these images are from before it.

They were not re-filed, so they are of an earlier build of the app. Do not copy them into the
site repo. Read $OUT_DIR/shoot.log and the step log attached to the failing test, fix the
shoot, and run it again — this file disappears when a run files a fresh set.
STALE
        echo "⚠️  $FILED still holds the previous run's images — marked STALE-DO-NOT-SHIP.txt" >&2
    fi
    echo "❌ the shoot failed — read $OUT_DIR/shoot.log, and the step log attached to each test" >&2
    exit 1
fi
grep -qE "TEST SUCCEEDED|TEST EXECUTE SUCCEEDED" "$OUT_DIR/shoot.log" || {
    echo "❌ no verdict line in $OUT_DIR/shoot.log — treat as a failure, not a pass" >&2
    exit 1
}

# --- 5. export ----------------------------------------------------------------------------------
say "Exporting attachments → $OUT_DIR/export"
rm -rf "$OUT_DIR/export"
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$OUT_DIR/export" >/dev/null

# The export is UUID-named and unusable as-is; this renames each capture to its slug. Separate
# script so an old result bundle can be re-filed without re-shooting it. $FILED is chosen above the
# verdict check, because a failed run needs to name that directory too.
say "Filing by slug → $FILED"
./scripts/file-shots.py "$OUT_DIR/export" "$FILED"

cat <<EOF

✅ Shot. Slug-named images and their .context files are in $FILED.

   Next: open every image. A missed tap produces a clean photograph of the previous
   screen and the run still reports success — the .context file beside each image is
   what makes that auditable, and two identical images is its signature.
EOF
