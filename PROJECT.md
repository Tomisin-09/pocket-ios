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
generated dev sample for the demo). Interaction: **tap = seek, drag = scrub, hold-drag = select a loop, pinch = zoom**
(a **page-mode** viewport — the window holds still and the playhead sweeps/pages across it,
with a Fit / 1× reset; ADR 0010 — and a deep zoom **re-downsamples the visible window from
the source file** for crisp detail, debounced + cached, ADR 0020);
playhead capture is via a transport **action bar** (Mark · Loop · Fine · reserved Auto),
while a loop's **range** is drawn directly on the waveform by a **long-press-drag** (ADR 0005
round 5) — a still hold arms a selection that the drag paints, released into a confirmable
draft. On **release**, a drawn edge / Fine handle / tap-seek **snaps to a nearby marker or
saved-loop edge** within an on-screen tolerance (pure `WaveformGesture.snap`, light haptic;
scrub + minimap stay free; ADR 0021). Pure gesture/zoom math in unit-tested `WaveformGesture`. The waveform and minimap show the **whole** annotation library —
markers as pins from the top, **all** saved loops as brackets along the bottom;
overlapping/nested loops **stack into lanes** (pure, unit-tested `LoopLanes`) so
overlap reads by position while colour stays reserved for state, the active loop
brighter (ADR 0018). New loops are created **instantly** on confirm — auto-named
("Loop 3", via pure `AutoName`), activated, and **looping immediately** (no separate
play tap), no naming sheet (markers still ask for a label, since a marker *is* its
label); deleting a loop or marker offers an
**Undo** toast that restores it with its original identity (ADR 0019).
State + handlers live in an `@Observable` `WaveformPracticeModel`
(ADR 0007), now bound to a **persisted `Song`** — loops/markers are SwiftData
`@Model`s that survive relaunches (ADR 0011). The app opens to a **song library**
(`LibraryView`); importing a DRM-free local/iCloud **audio file** takes a
security-scoped bookmark and extracts its real waveform (`WaveformExtractor`),
persisting a `Song` to practice, while an empty state offers import or a bundled
demo. Swiping a library row → **Edit** opens a **song metadata sheet** (`SongEditSheet`)
for title/artist/album/year/key/BPM/proficiency/progression, lightweight **collection
tags**, a free-form **note**, and read-only **practice stats** (loops · markers ·
annotations) — the record we enrich to drive routines (ADR 0012). Each loop carries a
per-loop **automator** (the "A" control on its row): a speed-trainer ramp — start % →
target % over N steps, a few loops each — that climbs, descends, or sits level, runs a
**fixed number of passes and then stops** (Set ramp also starts it playing), driven by the
engine counting loop wraps (ADR 0013). Filename suggestions, a practice
**journal** (per-loop/marker/song), **collections as real playlists**, and a **metronome**
(the transport "Auto" slot) are next. Navigation/planner follow (Phase 3) — the
planner's **selection** (goals → required skills from a **technique taxonomy**
(`docs/practice-techniques.md`) → candidate items, *prioritised, not balanced*; ADR 0015)
and its **ordering/time-boxing** are grounded in practice science (spaced repetition +
serial-position effect + diminishing returns; ADR 0014); a **clean-before-fast** advance
gate for the speed-trainer is recorded for a later automator slice (ADR 0016).
Verified pure logic: `TempoMath`, `SongRef`, `AudioMath`, `WaveformGesture`, `LoopLanes`, `AutoName`, `Song`, `AutomatorConfig`.
See `CHANGELOG.md` for the full history.