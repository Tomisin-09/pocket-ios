# Changelog

All notable changes to Pocket are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project is pre-release.

## [Unreleased]

### Added
- **Region looping** — an active loop now actually loops: playback wraps from the
  loop's end back to its start continuously (`PracticeAudioEngine` loop region,
  with the boundary math in unit-tested `AudioMath.loopSegment`). A loop just
  loops (no on/off toggle — the per-loop `repeats` count is reserved for the
  future automator); a small **✕ exit chip** by the loop name returns to
  full-song playback. Decisions in ADR 0006.

### Changed
- **Practice screen refactored to a view model** (no behaviour change): state and
  the gesture/loop handlers moved out of `WaveformPracticeView` into an
  `@Observable` `WaveformPracticeModel` (+ `…+Actions` extension). The view drops
  from the SwiftLint file-length limit (400 → ~130 lines), making room for the
  next features. Decisions in ADR 0007.
- **Transport bar simplified**: the **"+" quick-capture** and the per-loop
  **repeat/clear controls** are gone — loop creation is owned by the Tap/Fine
  gestures, and an active loop simply loops (the explicit toggle was redundant;
  real region looping lands on a later branch). When a loop is active the
  transport now shows its **name** over its time range.
- **Confirm pill** is smaller and now lives on the **mode-instructions row
  (trailing)** in every mode, instead of floating over the waveform. On a Tap
  second-punch the captured loop **stays highlighted green** while you confirm.
- **Cockpit chrome slimmed**: the speed/tempo bar is more compact (smaller `×`
  readout, tighter spacing) and the minimap is shorter. The **minimap is now
  seekable** — tap or drag anywhere on it to move the playhead (also VoiceOver-
  adjustable), reclaiming vertical space in the pinned cockpit.
- **Loop capture flow refined** (2nd round of on-device feedback): the keyboard-
  free confirm step is now an **icon-only ✓/✗ pill floating over the waveform**
  (the old bar read as if the name were editable there). **Tap mode is now punch
  in/out** — taps mark the loop at the *current playhead* and never move it; only
  dragging scrubs. Discarding the name from a **Fine** selection now **keeps the
  selection** (handles + pill return) so it can be re-adjusted. ADR 0005 updated.
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
- **Waveform gesture engine — UX polish** (from on-device feedback): Scroll mode
  now **drags to scrub** the playhead (tap still jumps, hold still drops a
  marker); Tap mode **plays a preview** from the first tap, filling the loop
  region green, and stops on the second; a live **time bubble** rides the
  playhead in every mode. Loop capture is now a keyboard-free **confirm bar
  (✓/✗)** that opens a native **naming sheet** (no more keyboard hiding the
  field). Loop & marker lists are **unified** — tap a row to use it (activate
  loop / seek to marker), edit via a trailing pencil. An existing loop's range
  can be **adjusted in Fine mode** via "Adjust range" (the reference area dims to
  focus the waveform). Name fields gained a **clear (✕)** button. ADR 0005 updated.
- **Waveform gesture engine** — the three transport modes are now live on the
  waveform: **Scroll** taps to seek and holds 650 ms (amber ring) to drop a
  marker; **Tap** drags to scrub and two taps capture a loop; **Fine** drags two
  blue handles to set loop bounds. Loop capture is named inline as before. The
  pure gesture math (point→fraction, bound ordering + min width, handle
  hit-testing) lives in unit-tested `WaveformGesture`. The transport **+** button
  remains as an accessible quick-capture. Decisions in ADR 0005.
- **Waveform practice screen** (Phase 1 skeleton) — SoundCloud-style mirrored
  waveform, speed/BPM bar, time ruler, minimap, transport bar with Scroll/Tap/
  Fine mode pills, all on the design tokens. Driven by mock data; audio engine,
  gestures and the asymmetric speed scale are later iterations.
- Loops & markers panels with **named, editable** entries: tap a row to edit
  (name/speed/repeats/delete) via a native sheet; activate a loop from its
  trailing play button. ADR 0003 records the interaction decisions.
- **Naming-on-capture** — capturing a loop slides in an inline creation panel
  below the transport (name field + range + Save/Discard, with a Reduce Motion
  fallback). Capture is triggered by a transport **+** button standing in for
  the Tap/Fine waveform gesture until the gesture engine lands.
- **Empty states** for the Loops and Markers panels (with hints that teach the
  real interaction), and an **unknown-tempo** state: `Song.bpm` is now optional
  and the speed bar shows a "Set BPM" affordance when it's absent — the speed
  multiplier works regardless. BPM derivation strategy recorded in ADR 0004.
- **Audio playback engine** (`PracticeAudioEngine`): real play/pause, seek, and
  pitch-preserving speed via `AVAudioUnitTimePitch`, with a live playhead. The
  practice screen's transport, speed bar and playhead are now driven by actual
  audio. A generated arpeggio (`SampleToneGenerator`) is the dev source (real
  file import is a later piece), and the waveform is downsampled from it.
  Pure helpers in `AudioMath` are unit-tested.
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