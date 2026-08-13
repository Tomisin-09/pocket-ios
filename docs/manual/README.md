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
| `getting-started` | What this is, what you need, and a first session in three moves | — |
| `songs` | Get your own music in, and find it again | — |
| `looping` | The loop workflow, end to end — the largest page | — |
| `exercises` | Run what shipped, then build your own | — |
| `routines` | Put exercises in an order and play them | — |
| `sessions` | Let the app plan a session around a goal | — |
| `journal-and-progress` | Write down what happened, and look back at it | — |
| `metronome` | The click on its own | — |
| `toolkit` | Tuner, saved chords, glossary, help | — |
| `subscription` | What's free, what Pro covers, how to start and stop | — |
| `privacy` | Where your data lives and what leaves the device | — |
| `gestures` | Every hold, drag, pinch and swipe in one place | — |
| `terms` | The app's own words for the things it measures | — |
| `shots` | Screenshot manifest — **generated** from the page markers, never hand-kept | — |

### The reference wing — what a screen is

| Page | Covers | Status |
|---|---|---|
| `reference/home-and-library` | Home, first-run, Song library and its sheets | — |
| `reference/song-player` | The waveform screen band by band, its eight sheets, landscape | — |
| `reference/practice` | Practice hub, Planner, Routines, Exercises, Loops | — |
| `reference/tools-and-journal` | Metronome, Journal, Progress, Toolkit | — |
| `reference/settings` | Reaching Settings, and each of its nine destinations | — |

Written in slices: Slice A is `getting-started` · `songs` · `looping` · `gestures` · `terms` — the
first hour, and the path the whole product is built around. The reference wing comes last on
purpose, so the how-tos already know what they are linking into.

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
- **The bundled demo song.** Dropped by ADR 0148 §7 — check the Library empty state before
  describing "Try the demo" as a thing a reader can tap.

## The check

```sh
./scripts/check-manual.py          # what CI and pre-push run
./scripts/check-manual.py --list   # each check and its current state
```

A check whose page does not exist yet reports **pending**, not failure — that is what let the
machinery land before the prose. What it cannot check is whether a page is *true*: only somebody
with the build open can say that, which is why every slice ends with a walk through the app.

**The coverage audit, at the end of the reference wing, is this manual's definition of done:** tick
every surface — Home, Practice hub, Planner, Routines, Exercises and their templates, the shape
editors, Loops and its three modes, Song library, the waveform screen and its eight sheets,
Metronome, Journal, Progress, the four Toolkit sections, the nine Settings destinations, the
paywall — against a heading here. Anything unticked is either written or added to the parked list
above with a reason.
