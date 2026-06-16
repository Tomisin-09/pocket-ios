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
| `Pocket/Features/Library/` | Music library + file browsing |
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

Phase 1 (in progress) — the **waveform practice screen**: a fixed practice
cockpit over a scrollable reference area, with named/editable loops & markers
(ADR 0003). Real playback runs through `PracticeAudioEngine` (play/pause/seek/
pitch-preserving speed) fed by a generated dev sample until file import lands.
The three transport modes are live as a **gesture engine** (Scroll seek + hold-
to-marker, Tap scrub + two-tap loop capture, Fine draggable handles; ADR 0005),
with the pure gesture math in unit-tested `WaveformGesture`. The screen's state
and handlers live in an `@Observable` `WaveformPracticeModel`, with the view as a
thin observing body (ADR 0007). The app temporarily launches straight into this
screen; it reverts to the planner once navigation lands in Phase 3. Verified pure logic: `TempoMath`, `SongRef`, `AudioMath`,
`WaveformGesture`. See `CHANGELOG.md` and the build plan for sequencing.