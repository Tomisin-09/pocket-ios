# Pocket — Project Reference

The living description of how Pocket is built. Update this whenever a screen, data
model, service, entitlement, build config, or architecture decision changes
(see the doc table in `AGENTS.md`).

## What Pocket is

A native iOS guitar-practice tool that attaches practice data (loops, markers,
notes, session history, routines) to songs in the user's music library. The app
is an intelligence layer over the library — it never replaces it.

- **Platform:** iOS 17+, phone-first, Swift / SwiftUI.
- **Name:** Pocket.

## Audio sources (decided)

| Source | Role | Why |
|---|---|---|
| Local / iCloud files | **Primary** — full engine (waveform, speed, loops) | DRM-free; AVFoundation can read raw PCM |
| Apple Music | Browse / metadata only | DRM blocks raw-audio access; waveform/time-stretch not possible without a special, selectively-granted entitlement |

See `docs/decisions/0001-audio-source-local-first.md`.

## Architecture (V1)

- **App data (solo):** SwiftData, with CloudKit sync planned (Phase 4). Apple's
  iCloud — **not AWS**.
- **AI planner backend:** a thin proxy that holds the Claude API key. The app
  never holds the key. Base URL is chosen by build config:
  - Debug → local / non-AWS dev proxy (accessible, fast to iterate)
  - Release → small AWS prod (Lambda + API Gateway)
  - See `docs/decisions/0002-ai-proxy-backend.md` and `infrastructure/`.
- **AWS collaboration layer** (shared setlists, DynamoDB/S3) is **parked** — not V1.

## Identity model

Practice data attaches to a `SongRef` (`Pocket/Core/Models/SongRef.swift`), a
stable `(id, source)` identity that works for both local files and Apple Music.
Local files carry a security-scoped bookmark for resolution; the bookmark is
**not** part of identity, so a refreshed bookmark doesn't orphan loops/markers.

## Modules

| Path | Responsibility |
|---|---|
| `Pocket/App/` | App entry, root scene |
| `Pocket/Features/Home/` | Home hub — the app root: greeting, resume card, Practice + metronome + songs entry points (ADR 0044) |
| `Pocket/Features/Library/` | Song library, file import, song metadata editing |
| `Pocket/Features/Waveform/` | Timeline, markers, loop creation (the practice screen) |
| `Pocket/Features/Metronome/` | Standalone metronome screen (ADR 0043; automator phase-continuous stepping + explicit run/count-in/infinite, ADRs 0047/0048) |
| `Pocket/Features/Practice/` | Top-level Practice hub → two unit libraries (`ExerciseLibraryView`, `LoopLibraryView`); per-unit training-run screens (`ExerciseRunView` / `LoopRunView` + `LoopRunModel`) + six curated starter exercises seeded once on first launch (`PracticePresets`, ADR 0046) |
| `Pocket/Features/Planner/` | *(reserved for the V2 practice planner — re-homed inside Practice, ADR 0046)* |
| `Pocket/Features/Repertoire/` | Song cards, song info |
| `Pocket/Core/Audio/` | AVFoundation engine, tempo math (pure logic) |
| `Pocket/Core/Models/` | Song, Loop, Marker, JournalEntry, Exercise, Routine, Session, SongRef |
| `Pocket/Core/Services/` | MusicKit, persistence, sync, AI client |
| `Pocket/UI/` | Shared components, design tokens |

## Environments

| Env | App build | Backend |
|---|---|---|
| Local dev | Debug scheme, simulator/device | Local proxy (or none, for Phases 1–3) |
| TestFlight | Release scheme, merge to `main` | AWS dev/prod stage |
| App Store | Tagged release | AWS prod |

## Status

Phase 1 (mostly complete) — the **waveform practice screen**: a fixed practice
cockpit over a scrollable reference area, with named/editable loops & markers
(ADR 0003). Real playback runs through `PracticeAudioEngine` — play/pause/seek,
pitch-preserving speed, and **seamless, click-free region looping** (a crossfaded
`.loops` buffer, ADRs 0006 & 0008) — fed by an imported file's real audio (or a
generated dev sample for the demo). Playback surfaces on the **lock screen /
Control Center** (title, artist, play/pause only) via a `NowPlayingController`
bridge over `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`, driven by a pure
unit-tested `NowPlayingState`; leaving the screen **stops** audio and removes the
global command targets (`onDisappear` → `endPlaybackSession`), while locking the
phone mid-practice keeps it playing (ADR 0025). Interaction: **tap = seek, drag = scrub, hold-drag = select a loop, pinch = zoom**
(a **page-mode** viewport — the window holds still and the playhead sweeps/pages across it,
with a Fit / 1× reset; ADR 0010 — and a deep zoom **re-downsamples the visible window from
the source file** for crisp detail, debounced + cached, ADR 0020);
loops are created through the **A/B span** — the single creation primitive (ADR 0041):
the transport's left column is two **identity dots** (A/B · Mark; **Click** moved to the
speed bar, ADR 0027 / 0030 / 0041). Tap **A/B** to drop A at the playhead, play along, tap
again to close an ephemeral **A↔B span** that loops with no ✓/✗ gate; drag its labelled
**A / B handles** to refine it in place, **Save as loop** to persist it, **✕** to clear.
Dragging a saved loop's **edge knob** lifts it back into A/B for a range edit (**Save
changes** writes back). **Hold-drag** the waveform is the spatial set (A pins at the
playhead, the drag sets B; ADR 0005 round 5). The transport
bar carries a **rewind · pause · forward** playback cluster (restart / prev-loop / next-loop;
cross-song deferred) plus an **active-loop colour strip** with an ✕ deactivator (ADR 0030);
a left-edge **swipe-back guard** stops a scrub from popping back to the library mid-adjust.
On **release**, a dragged A/B edge / tap-seek **snaps to a nearby marker or
saved-loop edge** within an on-screen tolerance (pure `WaveformGesture.snap`, light haptic;
the continuous scrub stays free; ADR 0021). The **minimap** snaps a released seek to a
nearby **marker or saved-loop edge** (but not beats — the full-song strip is too compressed
for the grid to land cleanly), so a tap or drag near a marker dot or loop boundary catches it. When a song has a **BPM and a downbeat anchor**, a
faint **beat grid** is drawn behind the bars (bar-start downbeats brighter, density-aware on
zoom) and its beats join the snap candidates, so edges/seeks catch the pulse too — pure,
unit-tested `BeatGrid`, assumes 4/4 (ADR 0022). The **"Set BPM"** affordance opens a tempo
editor (`BPMSheet`): **tap-tempo** (each tap captures song-time, so in-loop / slowed tapping
still reads the true tempo — pure `TempoMath.bpm(fromTapTimes:)`) or **manual** entry, plus
**the 1** placed by dragging a waveform handle that **snaps to the loudest transient**
(pure `TempoPeaks`) or marked at the playhead. Tempo is stored full-precision in
`Song.preciseBPM` (`Song.bpm: Int?` is the rounded display mirror; `tempoBPM` feeds the grid)
so it doesn't drift across a long song; long-press the BPM readout to re-open the editor.
The editor can also **estimate the tempo and the 1 from the audio** — an on-device pass over
the track's onset envelope (`WaveformExtractor.extractOnsetEnvelope` + pure `TempoEstimator`):
autocorrelation for the BPM (weighted by a ~120 BPM prior to fold half/double errors) and a
comb-filter for the downbeat phase. It **prefills** both, flagged as estimated for the user to
confirm, never auto-committing (rung 2 of ADR 0004). A **Click** toggle on the **speed bar**
(beside the BPM, its own teal — ADR 0027) plays a
**metronome** over the song that **follows the speed control** (50% → half-BPM, locked to the
slowed track): pure unit-tested `MetronomeSchedule` schedules each beat `delay = (beat − now) /
rate` ahead, played by a `ClickVoice` (a second player node on the same engine, straight to the
mixer so ticks aren't time-stretched, accented downbeat / plain beat). Enabled only when the
grid exists (BPM + the 1); it **never** alters the song's saved tempo and is silenced on pause /
screen exit (ADR 0026). Pure gesture/zoom math in unit-tested `WaveformGesture`. The waveform shows the **whole** annotation library on its **borders** (off the
bars): markers as **purple inverted triangles** along the top, **all** saved loops
as **per-loop coloured lines** along the bottom; overlapping/nested loops **stack
into lanes** (pure, unit-tested `LoopLanes`) so overlap reads by position. Colour
now encodes loop **identity** (deterministic palette slot, pure unit-tested
`LoopColors`) with state carried by line weight, the active loop heavier — ADR 0023
(supersedes the colour-is-state rule of ADR 0018). The blue theme (blue bars anchored
on `#2a6796`) sits on the near-black background (ADR 0023). New loops are created **instantly** on confirm — auto-named
("Loop 3", via pure `AutoName`), activated, and **looping immediately** (no separate
play tap), no naming sheet — and **markers now drop the same way**: instantly,
auto-named ("Marker 3", same `AutoName`), no naming step, renamed later from the row
(ADR 0037, amending 0019's marker-naming exception); deleting a loop or marker offers an
**Undo** toast that restores it with its original identity (ADR 0019). Practice
opens on the **full song** — no loop is armed until you pick one — and leaving the
screen **wipes** the transient session knobs (active loop, speed, click, mode) while
persisted song data is left untouched (ADR 0029). Both the **full song and individual loops remember the
speed you last practised them at** (`Song.lastPracticedSpeed` ADR 0044 / `Loop.lastPracticedSpeed`
ADR 0040 — refining 0029): arming a loop restores its speed (a loop slowed to 0.7× reopens at
0.7×), persisted when you leave it via a single `activeLoopID` `didSet` choke point —
`nil`/never-practised falls back to the loop's `speed`. The **song** resumes at its own
last-practiced tempo on reopen via the same choke point, which holds the invariant "no loop
armed ⇒ `speed` is the song's tempo" (bank on arm, restore on disarm) so a loop's speed never
leaks in (ADR 0044). The session still opens clean (no loop armed), only the tempo is remembered.
State + handlers live in an `@Observable` `WaveformPracticeModel`
(ADR 0007), now bound to a **persisted `Song`** — loops/markers are SwiftData
`@Model`s that survive relaunches (ADR 0011). The practice screen is the **one
screen that rotates to landscape** (ADR 0042): the cockpit + loops/markers list are
extracted as `PracticeCockpit` / `PracticeReference`, stacked in portrait; in landscape
the waveform cockpit takes the full width (compact speed/transport bars, flexing waveform)
and the loops/markers list becomes a **slide-in drawer** (☰), gated to this screen by
`OrientationGate`. The old bottom **song-info panel was removed** — its facts live
in the song-details sheet (hold the title). The app opens to a **home hub** (`HomeView`, ADR 0044) — a greeting, a "Jump back in" card
for the most-recently-practised song, a **Practice** card pushing the top-level **Practice
space** (`PracticeView`, ADR 0046 — a **hub** over two unit libraries: `ExerciseLibraryView`
(command drills) and `LoopLibraryView` (any measured song **loop**, `commandTempo != nil`), each a
row pushing its own list. An exercise opens `ExerciseRunView`; a loop opens `LoopRunView` (Phase B)
— both owning their own engine. The
run staircase lights the live plateau as it climbs, tempos are typable as well as nudged, and the
routine takes reach / back-up steps beyond warm-up; the `Exercise` model stores its `CommandRamp`
recipe natively in `ramp*`/dwell/backoff/`rampReachSteps`/`rampBackoffSteps` fields, the
`automator* → ramp*` rename done data-preservingly via `@Attribute(originalName:)`. A loop trains
the **same** warm-up → dwell → reach → back-off `CommandRamp`, but in percent-of-original against
its time-stretched audio: `LoopRunModel` owns a `PracticeAudioEngine`, loops the region, and steps
the playback rate by elapsed seconds; the `×` reach derives from `TempoStretch.targetSpeed` and the
staircase reuses `CommandRamp` via `LoopCommandRamp`'s `×`→percent mapping — no new stored `Loop`
fields), a metronome card, and a preview of your songs with
**See all** pushing the full **song library** (`LibraryView`), now one tap from the front
door rather than the root. Importing a DRM-free local/iCloud **audio file** takes a
security-scoped bookmark and extracts its real waveform (`WaveformExtractor`),
persisting a `Song` to practice, while an empty state offers import or a bundled
demo. **Holding a song card** → **Edit** opens a **song metadata sheet** (`SongEditSheet`)
(a context menu — swipe still offers a quick Delete, a tap opens the song for practice)
for title/artist/album/**genre** (canonicalised on write through `Labels.canonicalSingle`
and converged onto an existing library genre's spelling, ADR 0036)/year/**key** (a closed
`MusicalKey` picker — 12 roots × major/minor + Unknown — parsed from any legacy free text,
ADR 0036)/BPM/**downbeat**, lightweight **collections**,
a free-form **note**, and read-only **practice stats** (loops · markers ·
annotations) — the record we enrich to drive routines (ADR 0012). Collections are
canonicalised on write and **suggested from the ones already in the library** (so they
converge instead of fragmenting), and the library can be **filtered by collection** from a
toolbar **filter menu** (the funnel; intersection/AND) — ADR 0033. The library toolbar also
**names the current sort category** (e.g. "↑ Title") and lets you **flip ascending/descending**
(ADR 0035). The same `[String]` machinery (the shared
`Labels` canonicaliser) now backs loop-level **Tags** (ADR 0034). A song's **Mastery** is no longer stored — it is **derived**
as the rounded average of its **rated** loops' `mastery` (`MasteryRollup`, pure/unit-tested;
unrated loops are skipped, ADR 0039), shown as
stars and as a library group with an **Unrated** bucket for songs with no rated loops; the song also
records `lastPracticed` — **stamped on practice-screen entry** (ADR 0044) — for "recently
practised" ordering (home hub + library) and the planner (ADR 0036). Each loop carries a
per-loop **automator** (the "A" control on its row): a speed-trainer ramp — start % →
target % over N steps, a few loops each — that climbs, descends, or sits level, runs a
**fixed number of passes and then stops** (Set ramp also starts it playing), driven by the
engine counting loop wraps (ADR 0013). A loop row is **glanceable** (ADR 0039): under the name it shows the time range plus —
**only when set** — the loop's **mastery** (dots) and **command tempo** (a percent badge,
the headline achievement), so the loops list reads as a practice dashboard and an untouched
loop never shows a fake rating. Loop rows carry no edit pencil — **press and
hold** a row (with a haptic) to open the edit sheet for rename / range / colour /
delete (ADR 0028); the colour row pins a loop's identity hue — Auto, a preset, or a
custom colour wheel (low-contrast colours get an advisory hint) — or leaves it
automatic (ADR 0031). The edit sheet's **Practice** section carries the loop's
structured fields (ADR 0036), each with an explicit **unset** state (Optional, `nil` =
never set — ADR 0039, so a default never reads as a real rating; migrates pre-0039 loops to
`nil` for free): **Mastery** (0–5 dot rating, the source the song rolls up from; tap the
lowest filled dot down to clear back to *Unrated*), **Focus** (Backburner / Active /
Sharpening intent, stored 1–3, now a menu with a *Not set* option), **Type** (a closed
`LoopType` — Lick / Riff / Chords / Passage, single-select; Passage is the composite for a
loop spanning more than one), and **Command tempo** (the fastest tempo you own the loop at,
as a % of original; a **Set** button until measured — seeded from the loop's practice
speed — and a **Clear** back to unset) — the structured practice signal the planner reads.
Percent display + the `nil → "—"` fallback live in the pure `LoopProgressFormat`. A **Tags** section (ADR 0034)
adds the loop's open descriptive axis (`Loop.tags: [String]`) — the loop analogue of
song collections, canonicalised on write and **suggested from tags already used on any
loop** (cross-loop `@Query`); the cross-song filter-by-tag payoff is deferred to its first
consumer (the planner). Each loop also has a **practice journal** (ADR 0038):
a book icon on the row (left of the "A") opens a dated log of `JournalEntry` `@Model`s
(cascade-owned by the loop). Every entry **snapshots the loop's mastery and command
tempo at creation** — copied, not referenced, so it stays a truthful record as the loop
improves; the snapshot and timestamp are immutable, only `text` and a typed **kind**
(🎯 Goal / ⚡️ Breakthrough / 🧗 Struggle / 📝 Note / 🎬 Session — an `EntryKind`,
primitive-backed like `LoopType`) are editable. Entries group under day headers
(`JournalGrouping`, pure), newest first. This **narrows ADR 0012's three-scope journal**
to loop-only; songs get free-text **notes** rather than a journal, and markers get neither.
Those song notes (`Song.comment`) live in a **Notes** section directly under the
title/artist/album header in the **song details sheet** — **editable inline behind a
pencil affordance**: tap it to edit, an **Update** button (disabled until the draft
changes) commits with a brief "Saved" confirmation; the rest of the sheet stays
read-first. The song-scope half of the notes/journal feature (ADR 0038). Filename suggestions, **collections as real playlists**, and a **metronome**
(the transport "Auto" slot) are next. Navigation/planner follow (Phase 3) — the
planner's **selection** (goals → required skills from a **technique taxonomy**
(`docs/practice-techniques.md`) → candidate items, *prioritised, not balanced*; ADR 0015)
and its **ordering/time-boxing** are grounded in practice science (spaced repetition +
serial-position effect + diminishing returns; ADR 0014); a **clean-before-fast** advance
gate for the speed-trainer is recorded for a later automator slice (ADR 0016).
Verified pure logic: `TempoMath`, `TempoPeaks`, `TempoEstimator`, `SongRef`, `AudioMath`, `WaveformGesture`, `BeatGrid`, `MetronomeBeats`, `MetronomeGrid`, `TempoMarking`, `TempoSliderScale`, `ExerciseProgress`, `TimeSignature`, `MetronomeAutomator`, `TempoStretch`, `CommandRamp`, `LoopLanes`, `AutoName`, `Song`, `AutomatorConfig`, `EntryKind`, `JournalGrouping`, `MasteryRollup`, `LoopProgressFormat`.
See `CHANGELOG.md` for the full history.