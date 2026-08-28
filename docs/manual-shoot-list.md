# The manual shoot list

What is left to photograph for `docs/manual/`, and how the rest is taken.

**This file used to be a hand-shooting sheet — nine sessions, 68 figures, a table per screen. It is
not that any more.** The shoot is driven: `scripts/shoot-manual.sh` erases a simulator, drives the
app through each documented state with XCUITest, and files each capture under its slug. What remains
by hand is six figures that need a real phone.

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
| `broken` | `ManualMissingAudioShots` | a song whose file is gone |
| `bare` | `ManualBareShots` | an unseeded device |

Passes settle cross-area ordering by construction — the exercises library is shot on a device where
the `sessions` pass has never saved a goal. What a pass still owes is ordering *inside* itself: a figure whose
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

### `songs/import-progress` — cut, not outstanding

The "Importing N of M…" overlay over the library **is no longer a figure**; its marker was removed
from `docs/manual/songs.md`. The prose it sat under already says a progress indicator appears, which
is the whole of what the picture would have added. It is written up here because the three walls it
ran into are properties of the app, not of that one shot, and the next overlay figure will meet them
again:

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

Were it ever wanted back: put two or three audio files somewhere the Files picker can reach on a
device or a simulator that has used Files, open **Song library ▸ Import a song**, select more than
one, and catch the overlay. Larger files hold it on screen longer.

### On a real phone — 5 photographs, 6 markers, marked DEVICE

| Photograph | Serves | Why hardware |
|---|---|---|
| The paywall | `subscription/paywall` | A fresh install without Pro |
| The trial countdown row | `subscription/trial-row` | A running trial is an entitlement |
| Settings ▸ Red Moon Pro | `subscription/settings-pro` | Subscribed is an entitlement |
| The tuner, listening | `toolkit/tuner` + `reference/tuner` | Needs a microphone hearing a real string |
| The player in landscape | `song-player/landscape` | The simulator does not render this layout honestly |

No launch argument fakes an entitlement, and on a simulator `AppTransaction.shared` raises a sign-in
prompt that leaves the app untappable — which is why all three subscription states need hardware.

#### The phone has to be an iPhone 16 Pro

Its screen is **1206×2622**, which is the master geometry every `crop:` rect in the manual is
measured against, and it is why that geometry was chosen: it is also the iPhone 17 simulator's. A
15 Pro or a Plus produces a frame that passes every check except the geometry one, and invalidates
every crop taken against it. `shoot-progress.py --verify` is what catches it — run it before you put
the phone down, not after.

#### It is one sitting in three stages, in this order

The order is not a preference. Stage 1 needs an install that has never had Pro, and stage 2 is what
gives it Pro — so shooting them the other way round means erasing the app and starting again.

Run from Xcode, on the device, with **no launch arguments at all** for stages 1 and 2. The scheme
already points at `Configuration/RedMoonPro.storekit`, so buying is local and costs nothing; both
products carry a free introductory month, which is the trial the countdown row counts down.

**Stage 1 — `subscription/paywall`. No fresh install needed.** The first version of this guide said
to delete the app, which was wrong, and the app has carried the answer all along:
**Settings ▸ Developer ▸ Entitlement** is a three-way picker over `StoreManager.debugProOverride`
(`Default` · `Free` · `Pro`), with a **Show paywall** button beside it, and its own footer says it
exists to *"exercise the paywall gates before StoreKit sandbox exists"*. Set it to `Free` and the
locked states come back on a device with your whole library still on it.

Shoot the wall as it stands. Do not scroll: the marker's `crop: 0,160,1206,1040` cuts above the plan
cards on purpose, because an image carrying a price outlives the sentence that would have carried it
(D6). **That rect is confirmed** — cut against the filed frame it lands on the wordmark, the
one-line promise and the three value lines, and stops before the Annual card.

**Stage 2 — the two that differ from each other.** `subscription/settings-pro` needs no purchase at
all: `ProSettingsView` branches on `isPro` alone, so **Settings ▸ Developer ▸ Entitlement → Pro**
gives you `Manage Subscription`, `Restore Purchases` and the Pro footer. One caution — that footer
also carries `store.betaDiagnostic`, a monospaced `receipt: … · grant: … · pro: yes` line marked
`TODO(beta)` for removal. It must not be in the figure. The marker is `role: panel`, so give it a
`crop:` that stops above the diagnostic, and measure that rect against the frame.

**`subscription/trial-row` is the one thing no toggle fakes.** `TrialCountdownRow` renders only when
`TrialReminder.daysRemaining()` is non-nil, and that reads `trialEndsAt`, which is written from a
real StoreKit expiration and from nowhere else — `debugProOverride` does not touch it. So it needs an
actual purchase, which is still cheap: run from Xcode with `Entitlement` on `Default`, buy from the
paywall, and the local StoreKit environment confirms a free introductory month without money and
without a fresh install. You land on Home with the countdown row at the top.

To go round again: Xcode ▸ Debug ▸ StoreKit ▸ **Manage Transactions**, delete the transaction.

**Stage 3 — the tuner and landscape.** These need the seeded library, so add `-seedScreenshots` to
the scheme's arguments and run again. **Not `-uiTesting`** — it forces `debugProOverride`, and a
habit of passing it is what would spoil stage 1 on the next pass round this list.

`ScreenshotSeed.seedIfNeeded` only fires on an empty library, which the first-run set still is (ADR
0112 ships six exercises and one routine and **no song**). On a phone there is no `Documents/SeedAudio`
for it to import from, so `seedAudioURLs()` returns nothing and you get **Slow Bend** alone — the
tone-generator demo, with its loops. That is exactly what `song-player/landscape` asks for.

- **The tuner.** Toolkit ▸ Tuner, allow the microphone, play a string and let it ring. The frame
  wants the disc naming the note, the cents needle, the flat/sharp end labels, the string circles and
  the reference-pitch caption. Taking a screenshot while holding a guitar is the actual difficulty:
  turn on **Settings ▸ Accessibility ▸ Touch ▸ Back Tap ▸ Double Tap ▸ Screenshot** and knock the
  back of the phone instead of reaching for two buttons.
- **Landscape.** A **seeded** song in the player, rotation lock **off**, turn the phone, open the
  drawer. Not one of your own: the manual names no artist anywhere in its prose and every seeded song
  is by the invented *Jack Trader*, so a figure taken on a personal library would put a real artist's
  name into the documentation, in the largest type on the screen, and nothing in the toolchain checks
  for it. Landscape also carries **no status bar**, so this is the one photograph that needs no
  normalising.
  This is the one figure whose master is **2622×1206**, and `--verify` knows: it reads the marker's
  `state`, so a figure whose state says *landscape* is checked against the transposed master. A
  portrait frame filed under that slug is still a complaint, and so is a turned frame under any
  other.

#### Then normalise, or the seam shows

A phone's status bar carries the time it happened to be, a battery level, a silent-mode bell and —
on the tuner — the orange microphone dot. Every driven figure carries a faked 09:41 with clean
indicators. Side by side in one manual they do not read as one set, and a reader notices the seam
long before they could say what it was.

```sh
./scripts/normalise-shot.swift shots/filed-partial/reference-metronome.png \
    ~/Downloads/IMG_1234.PNG ~/Desktop/manual-shots/toolkit-tuner.png
```

The donor is any driven capture; only its top band is used. Both images are 1206×2622, which is what
makes the band line up — it is the same band. The default height covers the Dynamic Island, where a
live-microphone pill sits.

This is retouching, and it is worth being clear about what it removes: the mic dot on a tuner shot
is *truthful*, the tuner really is listening. What erasing it asserts is that these figures show the
app, not the phone it happened to run on.

#### Filing, and the check that closes it

AirDrop each screenshot to the Mac, normalise it, and save it as `~/Desktop/manual-shots/<slug>.png`
with `/` written as `-` — `toolkit/tuner` becomes `toolkit-tuner.png`. The tuner photograph is filed
**twice**, once as `toolkit-tuner.png` and once as `reference-tuner.png`; the declaration above is
what stops `--verify` reading the second copy as a missed tap.

```sh
./scripts/shoot-progress.py --verify      # geometry, duplicates, truncation, and the count
./scripts/check-manual.py                 # the markers still agree with the app and the harness
```

`--verify` going quiet on all five is the end of Phase 5.

---

## Nothing is parked on a decision

Neither figure that once was is still parked. `songs/missing-audio` is the `broken` pass — it was
parked on the belief that a broken song shows up in every library figure, which the source does not
bear out; the pass deletes one staged file after seeding, and its own device means nothing else sees
it. `exercises/freeform-run` went the other way: its marker was cut, so the `exercises` pass no
longer authors a freeform drill inside the run, and the six-drill library every other figure shows
stays six for a simpler reason than it used to.

## One photograph, two markers

Eight markers are served by a frame taken for another marker. Four are crops of it; four are the
same screen wanted twice, once by the spine and once by the reference wing. Each is listed here
because `shoot-progress.py --verify` reads this list: two figures with identical bytes is the
signature of a missed tap, and the only way to keep that check honest is to name the pairs that are
meant to be identical rather than loosen the check.

- `exercises/staircase` — a band *same frame as `exercises/run-setup`*, `crop: 0,1355,1206,410`
- `journal/quick-note-button` — a glyph *same frame as `exercises/run-setup`*, `crop: 856,188,120,120`
- `journal/record-arm` — a glyph *same frame as `exercises/run-setup`*, `crop: 967,2306,160,160`
- `songs/library-row` — the "Feels" row, *same frame as `reference/library`*, `crop: 0,1140,1206,330`
- `reference/quick-note` — *same frame as `journal/quick-note`*; one sheet, wanted by both halves
- `sessions/planner` — *same frame as `sessions/goals`*; Today's session fits in one screen, so the
  planner figure and the goals figure are the same photograph
- `journal/take-moments` — *same frame as `journal/take-detail`*; the strip, its pins, the note and
  the Moments list all fit above the fold, so scrolling to Moments photographs the screen already taken
- `reference/tuner` — *same frame as `toolkit/tuner`*; one tuner listening to one string. The
  reference marker asks for less than the spine's does — *microphone allowed* against *microphone
  allowed, a string sounding* — and a frame with a string sounding satisfies both

The four crops were measured against the master and **cut and checked by eye before the `crop:` field
was written**. A rect asserted from a coordinate guess is the one kind of error the geometry check
cannot catch — every frame is 1206×2622 whether the numbers point at the right part of it or not.

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
