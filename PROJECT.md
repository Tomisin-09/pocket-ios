# Ore — Project Reference

The living description of how Ore is built. Update this whenever a screen, data
model, service, entitlement, build config, or architecture decision changes
(see the doc table in `AGENTS.md`).

## What Ore is

A native iOS guitar-practice tool that attaches practice data (loops, markers,
notes, session history, routines) to songs in the user's music library. The app
is an intelligence layer over the library — it never replaces it.

- **Platform:** iOS 17+, phone-first, Swift / SwiftUI.
- **Name:** "Ore" means *friend* in Yoruba.

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

Practice data attaches to a `SongRef` (`Ore/Core/Models/SongRef.swift`), a
stable `(id, source)` identity that works for both local files and Apple Music.
Local files carry a security-scoped bookmark for resolution; the bookmark is
**not** part of identity, so a refreshed bookmark doesn't orphan loops/markers.

## Modules

| Path | Responsibility |
|---|---|
| `Ore/App/` | App entry, root scene |
| `Ore/Features/Library/` | Music library + file browsing |
| `Ore/Features/Waveform/` | Timeline, markers, loop creation (the practice screen) |
| `Ore/Features/Planner/` | Home screen / practice planner, routines |
| `Ore/Features/Repertoire/` | Song cards, song info |
| `Ore/Core/Audio/` | AVFoundation engine, tempo math (pure logic) |
| `Ore/Core/Models/` | Song, Loop, Marker, Routine, Session, SongRef |
| `Ore/Core/Services/` | MusicKit, persistence, sync, AI client |
| `Ore/UI/` | Shared components, design tokens |

## Environments

| Env | App build | Backend |
|---|---|---|
| Local dev | Debug scheme, simulator/device | Local proxy (or none, for Phases 1–3) |
| TestFlight | Release scheme, merge to `main` | AWS dev/prod stage |
| App Store | Tagged release | AWS prod |

## Status

Phase 0 — scaffold. Verified pure logic: `TempoMath`, `SongRef`. No audio engine
or screens yet. See `CHANGELOG.md` and the build plan in the repo for sequencing.