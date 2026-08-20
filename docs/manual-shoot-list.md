# The manual shoot list

What is left to photograph for `docs/manual/`, and how the rest is taken.

**This file used to be a hand-shooting sheet — nine sessions, 68 figures, a table per screen. It is
not that any more.** The shoot is driven: `scripts/shoot-manual.sh` erases a simulator, drives the
app through each documented state with XCUITest, and files each capture under its slug. What remains
by hand is six figures that need a real phone, and one that the simulator cannot honestly produce.

The `<!-- shot: -->` markers in the pages stay the source of truth, `docs/manual/shots.md` stays the
generated index, and **`./scripts/shoot-progress.py` is the live count** — it reads the images on
disk, so it is the one number that cannot go stale. Prefer it to any figure written here.

---

## Shooting it

```sh
./scripts/shoot-manual.sh                                  # every pass, ~40 min
POCKET_SHOOT_PASS=player ./scripts/shoot-manual.sh         # one area, while writing it
POCKET_SHOOT_PASS="routines sessions" ./scripts/shoot-manual.sh
```

**A pass is one erased device**, staged, driven, and filed. The shoot is several of them in order
rather than one long run, because most of the manual's second half *writes to the store*: a finished
run logs practice history, a saved goal changes the planner, a seventh drill changes a library every
other figure shows with six. Both seeds refuse to run twice, so within a single device those writes
are **retroactive** — they land in the store the read-only figures were photographed from, in an
order XCTest chooses and nothing here controls.

| Pass | Classes | What it owns |
|---|---|---|
| `base` | `ManualShotsUITests` · `ManualSettingsShots` · `ManualToolkitShots` · `ManualMetronomeShots` · `ManualReferenceShots` · `ManualPracticeShots` | the read-only set |
| `library` | `ManualLibraryShots` | library, sort, filter, song details/edit |
| `player` | `ManualPlayerShots` · `ManualLoopSheetShots` | the song player and its sheets |
| `exercises` | `ManualExerciseShots` | drills, runs, the freeform block |
| `routines` | `ManualRoutineShots` | the editor and a play-through |
| `sessions` | `ManualSessionShots` | the planner and goal authoring |
| `imports` | `ManualImportShots` | the file picker, the undo toast |
| `broken` | `ManualMissingAudioShots` | a song whose file is gone |
| `bare` | `ManualBareShots` | an unseeded device |

Passes settle cross-area ordering by construction — `exercises/library` is shot on a device where the
freeform drill has never existed. What a pass still owes is ordering *inside* itself: a figure whose
state has to be built belongs in **one test** that shoots the before and the after in sequence, never
across two tests whose relative order is XCTest's to pick.

### Two operational rules, both learned the hard way

**Run every pass in one invocation, not one pass per invocation.** `POCKET_SHOOT_PASS` takes a list.
A shell loop calling the script once per pass used to have each successful pass clear `filed-partial/`
before filing its own images — seven passes ran and two images survived. A partial run now starts in
keep mode and never clears, so both shapes are safe, but one invocation is still faster and files in
one coherent set.

**Read the script's exit code, not a later command's.** `./scripts/shoot-manual.sh > log; echo $?;
tail log` reports *tail's* status. A failing shoot has twice been read as a green one that way.

A failing pass no longer aborts the rest — the names are collected and reported together at the end,
and the shoot still exits non-zero.

---

## What still needs a hand

### `songs/import-progress` — the one simulator figure that cannot be driven

The "Importing N of M…" overlay over the library. Three separate obstacles, each independently
sufficient:

- **The picker cannot see the staged audio.** `Pocket/Resources/Info.plist` carries neither
  `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace`, so the app's `Documents/SeedAudio/`
  is invisible to the document picker.
- **An erased simulator has nothing else to pick.** There is no `File Provider Storage` app-group
  container until the Files app has run, so *On My iPhone* is empty.
- **The overlay barely exists.** `SongImportModel.progress` is non-nil only for the duration of the
  decode loop, which on seed-sized files is well under a second.

Getting past the first two means either adding a file-sharing key the app does not otherwise
exercise — which `AGENTS.md` rules out — or writing into an Apple-owned container whose layout is not
ours. Past that, the shot is still a race. **A launch argument that faked the overlay would fabricate
the very state the figure exists to evidence**, so that is not on the table either.

To take it by hand: put two or three audio files somewhere the Files picker can reach on a device or
a simulator that has used Files, open **Song library ▸ Import a song**, select more than one, and
catch the overlay. Larger files hold it on screen longer.

### On a real phone — 6 figures, marked DEVICE

| Slug | Role | Why hardware |
|---|---|---|
| `song-player/landscape` | band | Landscape, drawer open — the simulator does not render it honestly |
| `toolkit/tuner` | screen | Needs a microphone hearing a real string sounding |
| `reference/tuner` | screen | Same — tuner listening, note disc, cents gauge, string circles |
| `subscription/paywall` | panel | A fresh install without Pro. **Crop above the plan cards** — no price may appear in this manual |
| `subscription/trial-row` | band | An account inside a running trial |
| `subscription/settings-pro` | panel | A subscribed account, Settings ▸ Red Moon Pro |

The subscription three need a real entitlement: no launch argument fakes one, and on a simulator
`AppTransaction.shared` raises a sign-in prompt that leaves the app untappable.

---

## Nothing is parked on a decision

Both figures that once were are now driven. `songs/missing-audio` is the `broken` pass — it was
parked on the belief that a broken song shows up in every library figure, which the source does not
bear out; the pass deletes one staged file after seeding, and its own device means nothing else sees
it. `exercises/freeform-run` is in the `exercises` pass, authored inside the run rather than seeded,
so the six-drill library every other figure shows stays six.

## Do not re-shoot what is already filed

A filed image came off a specific device in a specific state. Re-taking one by hand puts a different
library in it, and the difference will not be visible in the frame.

**`./scripts/shoot-progress.py` counts files** — run it rather than trusting a number written here.
`--verify` additionally checks geometry, duplicates and truncated files.

Two things worth knowing when a count looks wrong:

- **A `capture(…, alsoServing:)` frame owes one file per marker, not one per frame.** Ten figures
  went unfiled for months because the image was attached once under the primary slug with the shared
  names recorded only in an *"also serves:"* line inside the `.context`. C13 counts the `capture()`
  call, which covered all of them, and nothing counted files. `file-shots.py` now copies them.
- **A green pass over a class that has since grown files nothing new.** A log reading
  `Executed 3 tests, with 0 failures` against a five-test class is not a failure and not a skip — the
  run simply predates the tests. Re-run the pass.
