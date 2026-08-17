# The Red Moon Practice manual

This is the canonical copy of the public user manual. It is written here, reviewed alongside the
code it describes, and rendered by the `.co.uk` site at `/redmoon/manual/<slug>` — **one markdown
file, one route, no exceptions.** The site is a rendering target, not an author.

The decision behind all of it is [ADR 0165 — the manual quotes the app](../decisions/0165-the-manual-quotes-the-app.md).
Read it before writing a page. The short version:

> **The manual owns procedure. The app owns nomenclature and definition. StoreKit owns the numbers.
> The privacy policy owns the commitments.**

`scripts/check-manual.py` enforces the half of that a script can enforce, and it runs on every push
— including docs-only pushes, where the test suite does not.

## The pages

Ordering lives here and nowhere else: filenames carry no numeric prefix, because a prefix *and* an
index is two orderings that drift apart.

### The spine — how to do a thing

| Page | The goal it serves | Status |
|---|---|---|
| `getting-started` | What this is, what you need, and a first session in three moves | Slice A |
| `songs` | Get your own music in, and find it again | Slice A |
| `looping` | The loop workflow, end to end — the largest page | Slice A |
| `exercises` | Run what shipped, then build your own | Slice B |
| `routines` | Put exercises in an order and play them | Slice B |
| `sessions` | Let the app plan a session around a goal | Slice B |
| `journal-and-progress` | Write down what happened, and look back at it | Slice C |
| `metronome` | The click on its own | Slice C |
| `toolkit` | Tuner, saved chords, glossary, help | Slice C |
| `subscription` | What's free, what Pro covers, how to start and stop | Slice C |
| `privacy` | Where your data lives and what leaves the device | Slice C |
| `gestures` | Every hold, drag, pinch and swipe in one place | Slice A |
| `terms` | The app's own words for the things it measures | Slice A |
| `shots` | Screenshot manifest — **generated** from the page markers, never hand-kept | Generated |

### The reference wing — what a screen is

| Page | Covers | Status |
|---|---|---|
| `reference/README` | How to read the wing, and its own conventions | Phase 4 |
| `reference/home-and-library` | Home, first-run, Song library and its sheets | Phase 4 |
| `reference/song-player` | The waveform screen band by band, its sheets, landscape | Phase 4 |
| `reference/practice` | Practice hub, Planner, Routines, Exercises, Loops | Phase 4 |
| `reference/tools-and-journal` | Metronome, Journal, Progress, Toolkit | Phase 4 |
| `reference/settings` | Reaching Settings, and each of its nine destinations | Phase 4 |

Written in slices: Slice A is `getting-started` · `songs` · `looping` · `gestures` · `terms` — the
first hour, and the way most players come in. Slice B is `exercises` · `routines` · `sessions` — the
session half, where the loops from Slice A become blocks in something you press play on. Slice C is
`journal-and-progress` · `metronome` · `toolkit` · `subscription` · `privacy` — the rest of the app.
The reference wing came last on purpose, so the how-tos already knew what they were linking into.

**On the order: A before B is a teaching order, not a ranking.** The app is the intersection of the
audio half and the session half (`docs/positioning.md`), and neither is the thing the other is built
around — earlier drafts of this file and of `getting-started` said the whole product was built around
looping, which is a claim the market does not support. Looping still comes first here because it is
what a new player does on day one and it needs no vocabulary. If you rewrite a page's framing, keep
that distinction: **first** is about sequence, never about which half matters.

**The prose is complete.** What remains is Phase 5: shooting the images the markers describe.

## Standing rules for whoever writes here

1. **Quote, don't restate.** A definition that exists in `PracticeFieldInfo` or `SettingsInfo` is
   reproduced byte-for-byte. Editing the copy in Swift is fine and propagates; paraphrasing it here
   is what fails the check.
2. **Cite an FAQ question; never reproduce its answer.** Write *See Help & FAQs: "…"* and stop.
   An answer is version-locked to the build that shipped it; a page here outlives that build.
3. **Define no theory term.** Name it and point at Toolkit ▸ Glossary, which owns all 53 of them.
4. **Name no price and no period.** Not once, not "about a fortnight", not in an aside. StoreKit
   owns those, and this copy is read long after the build that prompted it.
5. **Nothing coaches, nothing grades** (ADR 0070). Describe what the app does and how to drive it.
6. **Second person, British spelling, product voice.** No first-person "I" — that voice belongs to
   the beta guide, which is a different document for a different audience.
7. **Never refer to an image by position.** No "shown above", no "to the right": floats collapse to
   full-width blocks on a narrow viewport, so position is not a stable fact.
8. **Write the `<!-- shot: -->` marker as you write the sentence**, not at shoot time. The marker
   carries role, crop rect and the state to seed; recording it while the page is fresh is what
   turns the shoot into a batch instead of archaeology.
9. **Vocabulary matches [docs/app-store-listing-copy.md](../app-store-listing-copy.md)**, so a
   reader arriving from the store listing meets the same words for the same things.

## Do not document — the parked list

No script can tell "there is no sync" from "sync" without pretending to be a parser, and a check
that false-fails gets disabled within a month. So this list is a **review** item, checked by a
human, and it is the first thing to reread when a page starts to feel thin.

- **Apple Music / Spotify as a practice source.** DRM audio cannot be tapped for waveform or
  time-stretch (ADR 0001). Apple Music is browse and metadata only.
- **CloudKit sync.** Practice data is local to the device.
- **The AI planner.** Charter only (ADR 0092); nothing ships.
- **Streaks, "this year", weekly goals on Progress.** These do not exist and are checked for by
  name, because there is no legitimate use of those words here.
- **Ear training and theory as *creatable* templates.** Ear training shipped as a loop mode.
- **A free tier or "free taste".** `freeTasteSlugs` is empty (ADR 0144).
- **Instruments beyond guitar and 4-string bass.** Ukulele and the rest are parked (ADR 0116).
- **Take sharing.** Parked pending legal advice (ADR 0150).
- ~~**The bundled demo song.**~~ **Resolved 2026-08-13, and it is not parked.** Walked in the
  build: `LibraryView`'s empty state still offers **Try the demo** beside **Import a song**, and it
  inserts `Song.sample()` — Little Wing, with loops and markers already on it. ADR 0148 §7 does not
  describe what shipped. `songs.md` documents it.

## The shot markers

Every figure is an HTML comment written beside the sentence it belongs to. It renders as nothing on
GitHub, so the repo copy still reads as prose, and the port turns it into an image.

```
<!-- shot: looping/speed-bar | role: band
     | alt: The speed bar showing the speed control, the metronome and the BPM readout
     | state: seeded library, Little Wing, speed reduced below 100% -->
```

- **`slug`** is `group/name` and names the *shot*, not the page. The same crop legitimately appears
  on two pages, so C10 deliberately does **not** require the group to match the filename — requiring
  that would force one of the two pages to invent a second name for one image.
- **`role`** is one of `glyph` · `detail` · `panel` · `band` · `screen` · `strip`.
- **`alt`** is required, and is empty *only* for `glyph`, where the control's name sits in bold text
  beside it and the image is reinforcement.
- **`state`** is what to seed and what must be on screen. Written now, while the page is fresh, so
  the shoot is a batch rather than archaeology.
- **`crop`** is `x,y,w,h` in device pixels against the **1206×2622 master**, and is filled at shoot
  time. That geometry is both the iPhone 17 simulator the walk ran on and the iPhone 16 Pro the
  `device:` shots come from, so driven and hand-shot figures are interchangeable pixel for pixel and
  one set of rects measures both. The App Store material sits at 1320×2868 and is **not** a source
  for this manual (see below); where a frame has to come across, downscale it — resampling 1320 down
  to 1206 lands within two pixels of the master, and going the other way softens the type. C10
  validates the format when a marker carries one.
- **`device:`** marks a shot the simulator cannot produce honestly. Landscape is the known one.

## Capturing the states — what the simulator can and cannot do

Slice A's pages were written with the build running, driven through their flows on an **iPhone 17
simulator (1206×2622)**. What that walk settled, so Phase 5 does not rediscover it:

- **Seed audio must be WAV.** `ScreenshotSeed` reads `Documents/SeedAudio/`, and the simulator's
  decoder silently fails on the `.m4a` masters — the seed then imports nothing, `importReal` returns
  early, and the library shows one song (Little Wing, the built-in) instead of six. `afconvert -f
  WAVE -d LEI16@44100` over the masters fixes it. A one-song library looks like a working seed, so
  check the count before shooting.
- **The import picker is a separate process.** `app.screenshot()` returns a clean picture of Home
  with no picker in it. Capture that state with `XCUIScreen.main.screenshot()`.
- **Landscape needs a real device.** The one state on this list the simulator does not render
  honestly; markers for it carry a `device:` field.
- **Rows below the fold do not exist.** SwiftUI has not built them, so they cannot be found or
  scrolled to by element — scroll first, then query. Under the default **↑ Title** grouping only
  the first four songs are on screen.
- **`-uiTesting` runs the app fully unlocked** (`StoreManager` sets `debugProOverride`), which is
  what makes a driven walk possible at all — but it also means the trial row on Home, the paywall
  and every locked state are *unreachable* on that launch. Those states need a launch without the
  flag, so they are shot by hand or against a StoreKit test configuration.
- **Anything the app only writes at runtime has to be seeded too.** `ScreenshotSeed` builds a
  library; it writes no `PracticeRun`, `JournalEntry`, `Recording` or `SavedChord`, because those are
  only ever written as somebody uses the app. Progress and the Journal therefore open empty on a
  freshly seeded install, and the Toolkit reads *My chords, none saved* — nine figures are of those
  screens. `-seedHistory` (`PracticeHistorySeed`) writes six weeks of runs, four notes, one take and
  four saved voicings, deterministically. It is a **separate flag** from `-seedScreenshots` so the
  App Store shoot keeps its ahistorical library, and both refuse to run twice — so the shoot needs
  `xcrun simctl erase` in front of it, or it photographs the last run.
- **The first-run questions are skipped** under the same flag (`HomeView+ProfileMoment` returns
  early). `getting-started`'s first-run shot has to come from a launch without it, on a fresh
  install.
- **Debug-only UI has to be hidden, not cropped.** The Settings hub carries a tenth destination,
  `Developer`, under `#if DEBUG` — present in every build a shoot can drive, and shipped to nobody.
  The first shoot photographed it into `reference/settings-hub`, whose own alt text lists the nine
  that ship. `ScreenshotSeed.isShooting` now hides it, and `ManualSettingsShots` asserts it is gone;
  a figure is a claim about the shipping app, so the shoot has to be able to say *not this*.
- **Home's cards need slow swipes.** They sit in titled sections below the fold, and the shared
  `scrollIntoView` moves more than a card's height per swipe — a card can be carried past the
  viewport (and then reported missing), or pass `isHittable` and move before the tap is synthesised,
  which taps whatever slid into its place and photographs the wrong screen. `ManualShotCase.tapHomeCard`
  swipes slowly and re-reads hittability on each pass. Both failures were intermittent.

## Filing what comes back

`xcrun xcresulttool export attachments` writes every attachment under a **UUID** and puts the real
name in `manifest.json`, so a raw export cannot be audited — and auditing is the point, because a
missed tap produces a clean screenshot of the previous screen and the run still passes.

```sh
./scripts/file-shots.py shots/export shots/filed     # run for you by shoot-manual.sh
```

It renames each capture to its slug, reports how many of the 96 are still unshot, and warns when a
slug was shot twice (a retried test is not a clean run) or when a capture's slug is not a marker in
any page. **What counts as a figure comes from `shots.md`, not from the filename** — XCTest files
some of its own diagnostics under the same `name_retry_uuid` convention, and filtering on the shape
alone put a screen recording in with the figures.

## The check

```sh
./scripts/check-manual.py          # what CI and pre-push run
./scripts/check-manual.py --list   # each check and its current state
```

A check whose page does not exist yet reports **pending**, not failure — that is what let the
machinery land before the prose. What it cannot check is whether a page is *true*: only somebody
with the build open can say that, which is why every slice ends with a walk through the app.

## The coverage audit — run 2026-08-14, at the end of the reference wing

ADR 0165 calls this the manual's definition of done: every surface ticked against a heading, and
anything unticked either written or added to the parked list above with a reason.

| Surface | Where |
|---|---|
| Home, and the first run | `reference/home-and-library` · `getting-started` |
| Song library, its sort, filter, row menu, details and edit sheets | `reference/home-and-library` · `songs` |
| The waveform screen, band by band | `reference/song-player` · `looping` |
| Its sheets — loop edit, marker edit, bulk edit, automator, tempo, player settings, journal, takes | `reference/song-player` |
| Landscape | `reference/song-player` · `looping` |
| Practice hub | `reference/practice` |
| Today's session, goals, the review screen | `reference/practice` · `sessions` |
| Routines — building, playing, between blocks, the end | `reference/practice` · `routines` |
| Exercises, the ten creatable templates, the shape editors | `reference/practice` · `exercises` |
| Loops library, and the three ways to run a loop | `reference/practice` · `looping` |
| Metronome, its settings sheet, the automator | `reference/tools-and-journal` · `metronome` |
| Journal, Quick note, takes | `reference/tools-and-journal` · `journal-and-progress` |
| Progress | `reference/tools-and-journal` · `journal-and-progress` |
| Toolkit ×4 | `reference/tools-and-journal` · `toolkit` |
| Settings ×9 | `reference/settings` |
| The paywall, the trial, restore and cancel | `subscription` |
| Every hold, swipe and pinch | `gestures` |
| The app's own practice vocabulary | `terms` |
| What leaves the device | `privacy` |

**Three things the audit found, all now written:**

1. **The library groups by every template the app has ever had, not the ten you can create.** A drill
   made under a withdrawn template still lists, opens and runs under its own heading. Noted in
   `reference/practice`.
2. **The player's settings sheet has no button.** It is reachable only by holding `Loop controls`,
   which is one of the nine hintless holds. Named in `reference/song-player`, `reference/settings`
   and `gestures`.
3. **Song details is reached by holding the title** in the player, and by the row menu in the
   library — two doors, one sheet. Both are now stated.

**Nothing is unticked.** The parked list above is unchanged by the audit: everything on it is still
absent from the build, and no page describes any of it.

What the audit cannot do is prove a page is *true* — only somebody with the build open can, which is
why every slice ended with a walk through the app. The last one drove 71 screens.
