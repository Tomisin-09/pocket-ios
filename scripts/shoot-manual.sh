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
#   POCKET_SHOOT_KEEP_RUNS=20 ./scripts/shoot-manual.sh               # keep more logs than the last 5
#   POCKET_SHOOT_PREPARE=1 ./scripts/shoot-manual.sh                  # stage the device, then stop
#
# Every attempt lands in `$OUT_DIR/runs/<timestamp>.{log,xcresult}`, with `shoot.log` and
# `shoot.xcresult` symlinked to the latest. A failed run's evidence therefore survives the re-run
# that fixes it — see the note at RUN_ID for the shoot this was learned on.
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

# The shoot has its own plan. `PocketAll` — what CI runs — *skips* these classes, because they
# photograph an erased device this script has staged and are seven minutes of flake on an ordinary
# simulator. The two lists are the same names in two files, so the guard after the run checks
# that every class it asked for actually reported: adding a class here and forgetting the plan makes
# xcodebuild run **zero tests and exit 0**, which is the quietest possible way for a shoot to stop
# shooting. That is not hypothetical — it is what `-only-testing:` against `PocketAll`'s skip list
# does, measured, and it is why the selection lives in a plan instead of in flags.
TEST_PLAN="${POCKET_SHOOT_PLAN:-PocketShoot}"
# The shoot's test classes, listed rather than inferred, and grouped into **passes**. They are split
# by area of the manual so one broken tap doesn't take an unrelated page's figures down with it,
# which means adding an area means adding a line here — a visible cost, and the alternative (running
# the whole target and skipping the ordinary UI-test classes) inverts it onto every future non-shoot
# test instead.
#
# **A pass is one erased device**, staged, driven, and filed. The shoot is several of them in order
# rather than one long run, and the reason is the half of the manual that was left after the first
# 33 figures: almost all of it *writes to the store*. A finished exercise run logs practice history,
# a saved goal changes the planner, a seventh drill changes a library every other figure shows with
# six. Both seeds refuse to run twice, so within one device those writes are **retroactive** — they
# land in the store the read-only figures are photographed from, in an order XCTest chooses and
# nothing here controls. The first version of this script had one erase at the top and could not
# have expressed the rest of the shoot at all.
#
# Passes make cross-area ordering a non-question: `exercises/library` is shot on a device where the
# freeform drill has never existed, and `reference/planner` on one where no goal has ever been saved,
# because those are different devices. What a pass still owes is ordering *inside* itself — a figure
# whose state has to be built belongs in one test that shoots the before and the after in sequence,
# not spread across two tests whose relative order is XCTest's to pick.
#
# The cost is one erase and boot per pass, which on this machine is the expensive part (~2 minutes)
# and buys the guarantee outright. Named passes, so a single area can be re-driven while it is being
# written: `POCKET_SHOOT_PASS=player ./scripts/shoot-manual.sh`.
PASSES=(base library player exercises routines sessions imports broken bare)

# The classes each pass drives. `base` is the read-only set the first shoot filed; the rest are the
# areas that had to build their own state.
pass_classes() {
    case "$1" in
        base)      echo "ManualShotsUITests ManualSettingsShots ManualToolkitShots \
                         ManualMetronomeShots ManualReferenceShots ManualPracticeShots" ;;
        library)   echo "ManualLibraryShots" ;;
        player)    echo "ManualPlayerShots ManualLoopSheetShots" ;;
        exercises) echo "ManualExerciseShots" ;;
        routines)  echo "ManualRoutineShots" ;;
        sessions)  echo "ManualSessionShots" ;;
        imports)   echo "ManualImportShots" ;;
        broken)    echo "ManualMissingAudioShots" ;;
        bare)      echo "ManualBareShots" ;;
        # `POCKET_SHOOT_ONLY`'s ad-hoc pass — whatever was asked for, on its own erased device.
        adhoc)     echo "${POCKET_SHOOT_ONLY:-}" ;;
        *)         return 1 ;;
    esac
}

# `POCKET_SHOOT_ONLY` narrows the run to one class (or a space-separated few) while a new area is
# being written. The full set is ~6 minutes and a single class is well under one, and the difference
# is not convenience: a six-minute turn on a missed tap encourages guessing at the next selector
# instead of reading the step log. Always finish with a full run — the filed set is only coherent
# when every figure came from the same seed on the same erased device.
if [ -n "${POCKET_SHOOT_ONLY:-}" ]; then
    PASSES=(adhoc)
    echo "▸ Narrowed to: $POCKET_SHOOT_ONLY (partial run — not a complete set)"
elif [ -n "${POCKET_SHOOT_PASS:-}" ]; then
    # One named pass, for re-driving an area while it is being written. Still a partial set — it
    # files beside the full one rather than into it, for the same reason `POCKET_SHOOT_ONLY` does.
    # shellcheck disable=SC2206  # deliberate word-splitting: this takes a list of pass names
    PASSES=($POCKET_SHOOT_PASS)
    for pass in "${PASSES[@]}"; do
        pass_classes "$pass" >/dev/null || { echo "no such pass: $pass" >&2; exit 1; }
    done
    echo "▸ Narrowed to pass(es): ${PASSES[*]} (partial run — not a complete set)"
fi

# A run is **partial** unless it drove every pass. Only a complete run may write `filed/`, because
# that directory is what gets uploaded and a partial run filing into it would look exactly like a
# finished set with most of the manual missing.
PARTIAL=""
[ -n "${POCKET_SHOOT_ONLY:-}${POCKET_SHOOT_PASS:-}" ] && PARTIAL="1"
BUNDLE_ID="click.decooperations.pocket"
SEED_AUDIO_SRC="${POCKET_SEED_AUDIO:-$HOME/Documents/Red Moon Screenshots 2/seed-audio}"
DERIVED="${POCKET_DERIVED:-build-sim}"
OUT_DIR="${POCKET_SHOT_OUT:-shots}"

# **Every attempt keeps its own log and its own result bundle.** This used to be one `shoot.log` and
# one `shoot.xcresult`, both truncated at the top of the run, and that made a failed shoot erase
# itself: on 2026-08-16 `testMetronome` and `testMetronomeAutomator` failed, the shoot was re-run,
# and the second log — 16/16, TEST EXECUTE SUCCEEDED — replaced the evidence. Afterwards nothing on
# disk showed the failure had ever happened. Worse, the failure message tells you to read "the step
# log attached to each test", which lives in the result bundle the re-run had already deleted.
#
# So a run is identified by when it started, and `shoot.log` / `shoot.xcresult` become pointers to
# the latest — the convenient names still work, and history survives them. Kept to the last few
# runs, because a result bundle is tens of megabytes and `$OUT_DIR` is gitignored scratch.
#
# A shoot is now several passes, so the id is `<shoot timestamp>-<pass>`: one timestamp groups the
# runs that belong together, and the suffix says which area failed without opening anything.
SHOOT_STARTED="$(date +%Y%m%d-%H%M%S)"
RUNS_DIR="$OUT_DIR/runs"
KEEP_RUNS="${POCKET_SHOOT_KEEP_RUNS:-5}"
RUN_ID=""; RUN_LOG=""; RESULT_BUNDLE=""   # set per pass, by shoot_pass

# Where the images land. `file-shots.py` empties its target unless told to keep it — it has to, or a
# renamed slug leaves its old image behind to be shipped — so `filed/` is cleared by the **first**
# pass of a complete shoot and added to by the rest. A partial run files beside it instead: pointing
# a one-area run at the directory holding the full set would delete the other ninety. `filed/`
# therefore means "every pass, each from its own erased device"; a partial run is visibly partial.
FILED="$OUT_DIR/filed"
[ -n "$PARTIAL" ] && FILED="$OUT_DIR/filed-partial"

say() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# --- 1. build once ------------------------------------------------------------------------------
# `build-for-testing` rather than `test`, so nothing launches until the audio is staged.
#
# Built **once for the whole shoot**, ahead of the passes rather than inside them. The passes differ
# in which device they run against, not in what they run, so a rebuild between them would add minutes
# apiece for nothing. This used to sit after the erase, so that the simulator settled behind a cold
# build — that is now `simctl bootstatus -b`'s job in `stage_device`, which blocks whether the build
# was warm or not, and was always the honest fix for it.
say "Building for testing"
xcodebuild build-for-testing \
    -scheme Pocket \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -testPlan "$TEST_PLAN" \
    -derivedDataPath "$DERIVED" \
    -enableCodeCoverage NO \
    -quiet

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Pocket.app"
[ -d "$APP_PATH" ] || { echo "no app at $APP_PATH" >&2; exit 1; }

# --- 2. a device with nothing on it -------------------------------------------------------------
# Both seeds are idempotent by design, which is the right behaviour in the app and the wrong one
# here: a re-run against a dirty device photographs the *previous* run's data. Every pass therefore
# starts here, not just the first one.
stage_device() {
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
# **There is no longer an hour gate here.** There used to be: Home's greeting was computed from the
# real clock, the status bar is faked to 09:41, and the two disagreed the moment a run crossed a
# bucket boundary — "Late session" under a morning clock, a contradiction living entirely in the
# pixels where no assertion reaches it. This script defended that by refusing to run outside
# 05:00–11:59.
#
# That was the wrong shape for the problem twice. It made a deterministic artefact depend on when
# someone happened to start the run, and it could not express a figure that needs a *different*
# hour — `getting-started/home` asks for an evening greeting and was unshootable at any time of day.
# The app now takes the hour as a launch argument (`UITestHooks.shotHourArgument`), each test names
# the one its figure needs, and the clock in the frame agrees with the status bar by construction.
say "Forcing dark appearance and a clean status bar"
xcrun simctl ui "$SIM_NAME" appearance dark
# 09:41, full bars, no carrier noise — the same status bar the App Store shots carry, so a hand-shot
# device figure and a driven one differ only in the clock.
xcrun simctl status_bar "$SIM_NAME" override \
    --time "09:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

say "Installing"
xcrun simctl install "$SIM_NAME" "$APP_PATH"

# Grant the microphone **before the app has ever launched**, because the alternative is a system
# alert landing on top of a figure. `routines/block-record` turns `Record this block` on, and the
# first flip is what raises the prompt (ADR 0179 D3) — on an erased device that is every run. A
# permission alert is the worst shape of shoot failure: the tap lands, the assertion on the screen
# behind it still passes, and what gets filed is a photograph of an alert. Nothing in the manual
# photographs an ungranted mic — `routines.md` describes the prompt in prose and the tuner figures
# are already `device:` — so there is no state being faked away here, only a modal removed from a
# frame that never wanted it.
xcrun simctl privacy "$SIM_NAME" grant microphone "$BUNDLE_ID"

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
    [ "$count" -ge 5 ] || echo "  ⚠️  fewer than 5 — the library shots expect six songs including Slow Bend"
else
    echo "⚠️  no seed audio at '$SEED_AUDIO_SRC' — the shoot will run with Slow Bend only." >&2
    echo "   Set POCKET_SEED_AUDIO to the masters directory." >&2
fi
}

# --- 3c. per-pass preparation --------------------------------------------------------------------
# Most passes need nothing between staging the device and driving it. One does.
#
# **`songs/missing-audio` is a figure of a song whose file cannot be found**, and the state cannot be
# reached from inside the app or from a launch argument: `ScreenshotSeed.importReal` gives each
# seeded song a bookmark into `Documents/SeedAudio/` and **no** `audioFileName` — the pre-0148 shape
# — so the song resolves through that bookmark alone until something opens it and
# `SongAudioResolver.adoptIfNeeded` copies the file into `Application Support/Songs/`. Take the
# bookmark's target away and `resolve` returns nil for that song and nothing else.
#
# The order is the whole problem, and it is the same order problem this script exists for. The file
# has to be present when the seed runs — remove it first and the song is never imported at all, so
# instead of a song with missing audio there is simply one song fewer, which photographs as a
# perfectly ordinary library. So: seed, **wait for the seed to have actually landed**, then remove.
#
# Waiting is done against the store rather than a sleep. SwiftData writes `default.store`, an
# ordinary SQLite file, and `ZSONG` is queryable from here — which is also how the `1 block` bug in
# `Blues, week three` was finally settled after two wrong guesses. A fixed sleep would be a guess
# about a cold device's decode speed, and getting it wrong produces a green run and a wrong figure.
BROKEN_SONG="I'd Rather Go Blind (Cover)"

pass_prepare() {
    [ "$1" = "broken" ] || return 0

    local container store seeded=0
    container="$(xcrun simctl get_app_container "$SIM_NAME" "$BUNDLE_ID" data)"
    store="$container/Library/Application Support/default.store"

    say "Seeding, then breaking '$BROKEN_SONG'"
    xcrun simctl launch "$SIM_NAME" "$BUNDLE_ID" \
        -uiTesting -seedScreenshots -seedHistory -shotHour 9 >/dev/null

    # Six songs is what a complete seed writes — five staged masters plus the demo song. Anything
    # less means the seed is still running or the audio was not staged, and both produce the wrong
    # figure rather than a failure, so this waits for the number rather than for the table.
    for _ in $(seq 1 60); do
        if [ -f "$store" ]; then
            seeded="$(sqlite3 "$store" "select count(*) from ZSONG;" 2>/dev/null || echo 0)"
            [ "$seeded" -ge 6 ] && break
        fi
        sleep 2
    done
    [ "$seeded" -ge 6 ] || {
        echo "❌ the seed never wrote six songs (saw ${seeded:-0}) — not breaking anything, because" >&2
        echo "   a shoot from here would photograph a library that is short a song rather than a" >&2
        echo "   song that is short its audio." >&2
        exit 1
    }
    echo "  seeded: $seeded songs"
    sqlite3 "$store" "select ZTITLE from ZSONG where ZTITLE = \"$BROKEN_SONG\";" | grep -q . || {
        echo "❌ '$BROKEN_SONG' is not in the seeded library — check the name against ScreenshotSeed." >&2
        exit 1
    }

    xcrun simctl terminate "$SIM_NAME" "$BUNDLE_ID" >/dev/null 2>&1 || true

    # The bookmark's target, and the owned copy if anything opened the song during seeding. Leaf
    # names under `Songs/` are sourceID-keyed rather than titled, so that directory is cleared
    # wholesale — this pass shoots one figure and adopts nothing else.
    local removed=0
    for stale in "$container/Documents/SeedAudio/$BROKEN_SONG."*; do
        [ -f "$stale" ] || continue
        rm -f "$stale"
        removed=$((removed + 1))
    done
    rm -rf "$container/Library/Application Support/Songs"
    [ "$removed" -ge 1 ] || {
        echo "❌ found no '$BROKEN_SONG.*' in Documents/SeedAudio to remove — the song would still" >&2
        echo "   resolve, and the figure would be an ordinary player." >&2
        exit 1
    }
    echo "  removed $removed file(s) — '$BROKEN_SONG' can no longer resolve"
}

# --- 3b. hand-shoot: stop here with the device ready ---------------------------------------------
# `POCKET_SHOOT_PREPARE=1` does stages 1–3 and stops, leaving the app installed, seeded and running
# on an erased device with the dark appearance and the 09:41 status bar already forced.
#
# **This exists so a hand-shot figure and a driven one are the same photograph.** Shooting by hand
# off a real phone means the photographer's own library, their own practice history, and a live
# status bar — three differences visible in every frame, in a set whose whole claim is that it is one
# set. None of them can be overridden on hardware. Driving this simulator by hand costs nothing
# against that and keeps the 33 already-filed figures valid.
if [ -n "${POCKET_SHOOT_PREPARE:-}" ]; then
    stage_device
    # **`-uiTesting` is not optional here**, and it is not about tests. It is the argument every one
    # of the driven figures was shot under, and it does three things a hand-shoot needs: it unlocks
    # Pro (without it, Practice, Routines and the song library all meet a paywall — most of the
    # manual), it disables animations so a capture cannot land mid-transition, and it holds the
    # undo toast open for 120s instead of 4, which is the difference between `gestures/undo-toast`
    # being shootable by hand and not.
    #
    # It also suppresses the first-run intake — which is why `getting-started/first-run` gets its own
    # launch below rather than being unshootable on a seeded device, as this script once assumed.
    say "Launching the app, seeded and unlocked"
    xcrun simctl launch "$SIM_NAME" "$BUNDLE_ID" \
        -uiTesting -seedScreenshots -seedHistory -shotHour 9 >/dev/null
    cat <<PREPARED

✅ Ready to shoot by hand. $SIM_NAME is erased, seeded, dark, and showing 09:41.

   Screenshot:  xcrun simctl io "$SIM_NAME" screenshot ~/Desktop/manual-shots/<slug>.png
                (⌘S in Simulator saves to the Desktop and is the same pixels)

   Every image must be 1206×2622 — do not resize the window, and do not crop by hand.
   Re-launch without losing the seed:
                xcrun simctl launch "$SIM_NAME" $BUNDLE_ID -uiTesting -seedScreenshots \
                    -seedHistory -shotHour 9

   For getting-started/first-run ONLY, drop -uiTesting so the intake appears:
                xcrun simctl terminate "$SIM_NAME" $BUNDLE_ID
                xcrun simctl launch "$SIM_NAME" $BUNDLE_ID -seedScreenshots -seedHistory -shotHour 9

   Filing: one file per slug, '/' becomes '-'  →  routines/library = routines-library.png
PREPARED
    exit 0
fi

# --- 4. shoot -----------------------------------------------------------------------------------
# Prune by *run id*, not by file: one run is two entries and deleting the newest `.xcresult` while
# keeping its `.log` would leave a run that says where to look and no longer has it.
#
# Grouped by **shoot**, not by pass, and done once before any of them rather than inside each. A
# shoot is now eight runs sharing a start timestamp, so pruning per pass to the last five entries
# would delete the first three passes' evidence partway through the shoot that produced it — the
# same self-erasing failure this history exists to prevent, arriving through the fix for it.
prune_runs() {
    mkdir -p "$RUNS_DIR"
    local stale
    # `<ts>-<pass>` ids: cut back to the timestamp to group, keep the newest `$KEEP_RUNS` shoots.
    stale="$(find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -name '20*' -exec basename {} \; \
             | sed 's/\.[^.]*$//' | cut -d- -f1-2 | sort -ru | tail -n "+$(( KEEP_RUNS + 1 ))")"
    [ -n "$stale" ] || return 0
    while IFS= read -r ts; do
        [ -n "$ts" ] || continue
        rm -rf "${RUNS_DIR:?}/$ts"-*.log "${RUNS_DIR:?}/$ts"-*.xcresult
    done <<<"$stale"
}

# One pass: the device has already been staged by `stage_device`, so this drives the pass's classes,
# reads the verdict out of the log, and files what came back.
#
# - `$1` the pass name, which selects the classes and names the run.
# - `$2` `keep` once an earlier pass has already filed into `$FILED` during this shoot, so filing
#   adds to the set rather than clearing it. See `file-shots.py --keep`.
shoot_pass() {
    local pass="$1" keep_filed="$2"
    # shellcheck disable=SC2206  # deliberate word-splitting: pass_classes returns a list of names
    local classes=($(pass_classes "$pass"))
    [ ${#classes[@]} -gt 0 ] || { echo "pass '$pass' selects no classes" >&2; exit 1; }

    RUN_ID="$SHOOT_STARTED-$pass"
    RUN_LOG="$RUNS_DIR/$RUN_ID.log"
    RESULT_BUNDLE="$RUNS_DIR/$RUN_ID.xcresult"

say "Shooting pass '$pass' — ${classes[*]}"

# The stable names stay, as pointers to this run. Removed rather than overwritten: `ln -sf` onto an
# existing *directory* links inside it, so a legacy real `shoot.xcresult` would quietly become
# `shoot.xcresult/<id>.xcresult` and every path in the messages below would be wrong.
rm -rf "$OUT_DIR/shoot.log" "$OUT_DIR/shoot.xcresult"
ln -s "runs/$RUN_ID.log" "$OUT_DIR/shoot.log"
ln -s "runs/$RUN_ID.xcresult" "$OUT_DIR/shoot.xcresult"
echo "  run $RUN_ID → $RUN_LOG"

ONLY_TESTING=()
for class in "${classes[@]}"; do
    ONLY_TESTING+=("-only-testing:PocketUITests/$class")
done
xcodebuild test-without-building \
    -scheme Pocket \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -testPlan "$TEST_PLAN" \
    "${ONLY_TESTING[@]}" \
    -derivedDataPath "$DERIVED" \
    -enableCodeCoverage NO \
    -resultBundlePath "$RESULT_BUNDLE" 2>&1 \
    | tee "$RUN_LOG" \
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

if grep -qE "TEST FAILED|TEST EXECUTE FAILED" "$RUN_LOG"; then
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
site repo. Read $RUN_LOG and the step log inside $RESULT_BUNDLE, fix the shoot, and run it
again — this file disappears when a run files a fresh set.

Both of those are named for run $RUN_ID and survive the next attempt, so a fix can be checked
against what actually failed rather than against whatever ran last.
STALE
        echo "⚠️  $FILED still holds the previous run's images — marked STALE-DO-NOT-SHIP.txt" >&2
    fi
    echo "❌ pass '$pass' failed — read $RUN_LOG, and the step log inside $RESULT_BUNDLE" >&2
    return 1
fi
grep -qE "TEST SUCCEEDED|TEST EXECUTE SUCCEEDED" "$RUN_LOG" || {
    echo "❌ no verdict line in $RUN_LOG — treat as a failure, not a pass" >&2
    return 1
}

# **A green verdict over zero tests.** `xcodebuild` reports success for running nothing, so a shoot
# that selects no tests at all is indistinguishable at the exit code from a shoot that took every
# figure. The way in is mundane: a class added to `SHOOT_CLASSES` but not to `PocketShoot.xctestplan`
# is silently skipped, and so is every class if the plan name is wrong. Measured, not feared —
# `-only-testing:` against a plan that skips the class runs `Executed 0 tests` and exits 0.
#
# So each class is required to have reported at least one test case by name. This is the same
# principle as C13's refusal to pass when it finds no `capture()` calls: a check that can be
# satisfied by reading nothing is not a check.
missing=()
for class in "${classes[@]}"; do
    grep -qE "Test Case '-\[PocketUITests\.$class " "$RUN_LOG" || missing+=("$class")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "❌ pass '$pass' passed, but these classes never executed a single test: ${missing[*]}" >&2
    echo "   A plan that selects nothing still exits 0. Check that each class is listed in" >&2
    echo "   $TEST_PLAN.xctestplan as well as in pass_classes() here." >&2
    return 1
fi

# --- 5. export ----------------------------------------------------------------------------------
say "Exporting attachments → $OUT_DIR/export"
rm -rf "$OUT_DIR/export"
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$OUT_DIR/export" >/dev/null

# The export is UUID-named and unusable as-is; this renames each capture to its slug. Separate
# script so an old result bundle can be re-filed without re-shooting it. $FILED is chosen above the
# verdict check, because a failed run needs to name that directory too.
say "Filing pass '$pass' by slug → $FILED"
if [ "$keep_filed" = "keep" ]; then
    ./scripts/file-shots.py --keep "$OUT_DIR/export" "$FILED"
else
    ./scripts/file-shots.py "$OUT_DIR/export" "$FILED"
fi
}

# --- 6. drive every pass -------------------------------------------------------------------------
# Each pass gets its own erased device, in the order `PASSES` names. The order is not arbitrary and
# it is not load-bearing either: passes cannot see each other's writes, so it is simply the order
# the manual's own shoot list is written in, which is the order that is easiest to audit against.
prune_runs
keep_filed=""
if [ -n "$PARTIAL" ]; then
    # **A partial run does not own `filed-partial/`, and must never clear it.**
    #
    # A complete shoot does own `filed/`: it takes every figure, so clearing on the first pass and
    # adding on the rest leaves exactly one shoot's images behind. A partial run is the opposite —
    # it exists precisely because other partial runs are filing into the same directory, whether
    # earlier in this shoot or in a separate invocation yesterday.
    #
    # This was a one-line data-loss bug and it destroyed real work. `keep_filed` is reset per
    # *invocation*, and only set to `keep` after the first pass *within* one. So the documented
    # resume path — one invocation per pass, in a shell loop, so that a failing pass doesn't stop
    # the others — had every successful pass wipe the previous pass's images before filing its own.
    # Seven passes ran; two images survived. Nothing warned, because clearing a directory you were
    # told to file into is not an error.
    #
    # A partial run therefore starts in `keep` mode. To start `filed-partial/` empty, delete it.
    keep_filed="keep"
else
    # That has to happen here rather than inside `file-shots.py`, which cannot know whether it is
    # being called for the first pass of eight or the only pass of one.
    echo "  filing a complete shoot into $FILED (cleared by the first pass)"
fi
# **A failing pass no longer takes the rest of the shoot with it.**
#
# `shoot_pass` used to `exit 1`, which under `set -e` ended the whole invocation on the first
# failure. With one pass per invocation that was harmless; now that a multi-pass invocation is the
# *only* way to file safely (see `keep_filed` above), it meant a single failure in the first pass
# left the other eight undriven — an hour of device time spent on one test, and eight areas' worth of
# failures still unknown. A shoot is diagnostic work: the point is to come back with every failure,
# not the first one.
#
# Each pass still gets its own erased device, and a failed pass still files nothing. The names are
# collected and reported together at the end, and the script still exits non-zero — a shoot with any
# failing pass is a failed shoot.
failed_passes=()
for pass in "${PASSES[@]}"; do
    stage_device
    pass_prepare "$pass"
    if ! shoot_pass "$pass" "$keep_filed"; then
        failed_passes+=("$pass")
        echo "⚠️  pass '$pass' failed — continuing with the remaining passes" >&2
    fi
    keep_filed="keep"
done

if [ ${#failed_passes[@]} -gt 0 ]; then
    cat >&2 <<EOF

❌ ${#failed_passes[@]} of ${#PASSES[@]} pass(es) failed: ${failed_passes[*]}

   Each failed pass filed nothing, so $FILED holds only the passes that succeeded.
   Read the per-pass logs — they are named for the pass and they survive the re-run:
       $OUT_DIR/runs/$RUN_ID-<pass>.log
EOF
    exit 1
fi

cat <<EOF

✅ Shot ${#PASSES[@]} pass(es). Slug-named images and their .context files are in $FILED.

   Next: open every image. A missed tap produces a clean photograph of the previous
   screen and the run still reports success — the .context file beside each image is
   what makes that auditable, and two identical images is its signature.

   ./scripts/shoot-progress.py --verify   # geometry, duplicates, truncated files
EOF
