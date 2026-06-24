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
| `Pocket/Features/Library/` | Song library, file import, song metadata editing |
| `Pocket/Features/Waveform/` | Timeline, markers, loop creation (the practice screen) |
| `Pocket/Features/Planner/` | Home screen / practice planner, routines |
| `Pocket/Features/Repertoire/` | Song cards, song info |
| `Pocket/Core/Audio/` | AVFoundation engine, tempo math (pure logic) |
| `Pocket/Core/Models/` | Song, Loop, Marker, Routine, Session, SongRef |
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
playhead capture is via three transport **identity dots** (Loop · Mark · Fine — coloured
dots, no captions; **Click** moved to the speed bar, ADR 0027 / 0030), and the transport
bar carries a **rewind · pause · forward** playback cluster (restart / prev-loop / next-loop;
cross-song deferred) plus an **active-loop colour strip** with an ✕ deactivator (ADR 0030);
a left-edge **swipe-back guard** stops a scrub from popping back to the library mid-adjust,
while a loop's **range** is drawn directly on the waveform by a **long-press-drag** (ADR 0005
round 5) — a still hold arms a selection that the drag paints, released into a confirmable
draft. On **release**, a drawn edge / Fine handle / tap-seek **snaps to a nearby marker or
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
persisted song data is left untouched (ADR 0029).
State + handlers live in an `@Observable` `WaveformPracticeModel`
(ADR 0007), now bound to a **persisted `Song`** — loops/markers are SwiftData
`@Model`s that survive relaunches (ADR 0011). The app opens to a **song library**
(`LibraryView`); importing a DRM-free local/iCloud **audio file** takes a
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
as the rounded average of its loops' `mastery` (`MasteryRollup`, pure/unit-tested), shown as
stars and as a library group with an **Unrated** bucket for songs with no loops; the song also
records `lastPracticed` for "recently practised" ordering and the planner (ADR 0036). Each loop carries a
per-loop **automator** (the "A" control on its row): a speed-trainer ramp — start % →
target % over N steps, a few loops each — that climbs, descends, or sits level, runs a
**fixed number of passes and then stops** (Set ramp also starts it playing), driven by the
engine counting loop wraps (ADR 0013). Loop rows carry no edit pencil — **press and
hold** a row (with a haptic) to open the edit sheet for rename / range / colour /
delete (ADR 0028); the colour row pins a loop's identity hue — Auto, a preset, or a
custom colour wheel (low-contrast colours get an advisory hint) — or leaves it
automatic (ADR 0031). The edit sheet's **Practice** section carries the loop's
structured fields (ADR 0036): **Mastery** (0–5 dot rating, the source the song
rolls up from), **Focus** (Backburner / Active / Sharpening intent, stored 1–3),
**Type** (a closed `LoopType` — Lick / Riff / Chords / Passage, single-select; Passage is the
composite for a loop spanning more than one), and
**Command tempo** (the fastest tempo you own the loop at, as a % of original) —
the structured practice signal the planner reads. A **Tags** section (ADR 0034)
adds the loop's open descriptive axis (`Loop.tags: [String]`) — the loop analogue of
song collections, canonicalised on write and **suggested from tags already used on any
loop** (cross-loop `@Query`); the cross-song filter-by-tag payoff is deferred to its first
consumer (the planner). Filename suggestions, a practice
**journal** (per-loop/marker/song), **collections as real playlists**, and a **metronome**
(the transport "Auto" slot) are next. Navigation/planner follow (Phase 3) — the
planner's **selection** (goals → required skills from a **technique taxonomy**
(`docs/practice-techniques.md`) → candidate items, *prioritised, not balanced*; ADR 0015)
and its **ordering/time-boxing** are grounded in practice science (spaced repetition +
serial-position effect + diminishing returns; ADR 0014); a **clean-before-fast** advance
gate for the speed-trainer is recorded for a later automator slice (ADR 0016).
Verified pure logic: `TempoMath`, `TempoPeaks`, `TempoEstimator`, `SongRef`, `AudioMath`, `WaveformGesture`, `BeatGrid`, `LoopLanes`, `AutoName`, `Song`, `AutomatorConfig`.
See `CHANGELOG.md` for the full history.