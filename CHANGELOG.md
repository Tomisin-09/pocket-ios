# Changelog

All notable changes to Pocket are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project is pre-release.

## [Unreleased]

### Changed
- Renamed the product from "Ore" to **Pocket** (module, targets, bundle id
  `click.decooperations.pocket`, repo `pocket-ios`, all docs). Dropped the
  Yoruba "friend" etymology, which no longer applies to the new name.
- Waveform practice screen restructured into a **fixed practice cockpit**
  (song strip, speed bar, waveform, ruler, minimap, transport) over a
  **scrollable reference area** (loops, markers, song info). Song info is
  demoted to the bottom, collapsed by default. See ADR 0003.
- Temporarily launch the app straight into the waveform practice screen (reverts
  to the home/planner once navigation lands in Phase 3).

### Fixed
- `project.yml` no longer regenerates (overwrites) the hand-maintained
  `Info.plist` — the stray `info:` block was dropping the Apple Music usage
  string, background-audio mode and portrait lock on every `xcodegen generate`.

### Added
- **Waveform practice screen** (Phase 1 skeleton) — SoundCloud-style mirrored
  waveform, speed/BPM bar, time ruler, minimap, transport bar with Scroll/Tap/
  Fine mode pills, all on the design tokens. Driven by mock data; audio engine,
  gestures and the asymmetric speed scale are later iterations.
- Loops & markers panels with **named, editable** entries: tap a row to edit
  (name/speed/repeats/delete) via a native sheet; activate a loop from its
  trailing play button. ADR 0003 records the interaction decisions.
- SwiftUI `#Preview`s for the screen and each component (`WaveformPreviews`).
- Project scaffold (Phase 0): repo structure, XcodeGen `project.yml`, SwiftLint
  config, GitHub Actions (lint + build + test on PR; TestFlight on merge),
  Fastlane stubs.
- `SongRef` — source-agnostic song identity (local files + Apple Music), unit-tested.
- `TempoMath` — pure tempo/speed-slider/automator math, unit-tested.
- Design tokens, app entry point, placeholder home screen.
- Governance docs: `AGENTS.md`, `PROJECT.md`, `docs/architecture.md`, ADRs 0001–0002.
- `docs/design-brief.md` — self-contained design brief + working protocol for
  designing the UI with Claude (design system contract, screen inventory,
  per-screen request template, definition-of-done).
- Infrastructure stub for the Phase 4 Claude proxy.