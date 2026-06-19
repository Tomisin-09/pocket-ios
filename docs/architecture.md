# Architecture

## Layers

```
┌─────────────────────────────────────────────────────────┐
│ SwiftUI Features (Library · Waveform · Planner · Repertoire)
├─────────────────────────────────────────────────────────┤
│ Core
│   Audio    — AVAudioEngine + AVAudioUnitTimePitch, audio tap → waveform,
│              TempoMath · AudioMath · WaveformGesture · LoopLanes (pure)
│   Models   — Song, Loop, Marker, Routine, Session, SongRef
│   Services — MusicKit (browse), Persistence (SwiftData), Sync (CloudKit),
│              AIClient (→ proxy)
├─────────────────────────────────────────────────────────┤
│ Apple: MusicKit · AVFoundation · SwiftData · CloudKit · Sign in with Apple
├─────────────────────────────────────────────────────────┤
│ Backend (Phase 4): Claude proxy — local dev / tiny AWS prod
└─────────────────────────────────────────────────────────┘
```

## Audio pipeline (local/iCloud files)

1. User imports a file via the Files picker → store a **security-scoped
   bookmark** + a `SongRef(.localFile)`.
2. Resolve the bookmark to a URL; load with AVFoundation.
3. Playback through `AVAudioEngine` with `AVAudioUnitTimePitch` for
   pitch-preserving speed control (0.25×–2.0×).
4. Generate the waveform from an offline read / audio tap (mirrored bars).
5. Playhead, loops, and markers are all positions in seconds, independent of
   speed.

**Current status:** stages 3–5 exist as `PracticeAudioEngine` (player →
time-pitch → mixer; play/pause/seek/rate + a published `currentTime`) with pure
helpers in `AudioMath` (unit-tested). Stages 1–2 (file import) now exist:
`SongImporter` (the `LibraryView` file picker) stores a security-scoped bookmark, and
the practice model resolves it to feed the engine the real file; the generated arpeggio
(`SampleToneGenerator`) remains only as the bundled demo song. Tap-to-seek, scrub,
and loop/marker capture are driven by the waveform **gesture engine** (pure math
in `WaveformGesture`, ADR 0005), which also handles **pinch-to-zoom** — the detail
waveform shows a viewport that tracks the playhead (ADR 0010). An active loop **loops continuously, gaplessly and click-free** — the
engine pre-renders the loop region into a buffer whose seam is equal-power
**crossfaded** (`AudioMath.crossfadeGains`) and plays it on `.loops`, so the wrap is
both gapless and free of the splice click; the visual playhead wraps via pure
`AudioMath.loopedPlayhead`, decoupled from the audio (region math in
`AudioMath.loopSegment`; ADRs 0006 & 0008). Stage 4's waveform for real files is
extracted up front by `WaveformExtractor` (chunked AVFoundation read →
`AudioMath.mixToMono`/`downsample`, the reduction unit-tested) and stored on the `Song`;
the demo's waveform is still downsampled from its generated buffer (ADR 0011, Slice 2).
The reduction is **transient-resistant energy, percentile-normalised** (512 bars) —
each bar is the median of several short RMS sub-windows, so the envelope tracks the
sustained music and steps over rhythmic spikes (a snare) rather than flat-topping on
loud masters; the bucket count doubles as a stored-format version that re-extracts
pre-ADR-0017 waveforms on open. The detail waveform and minimap draw the **whole**
loop/marker library — markers as pins from the top, loops as brackets along the
bottom; overlapping/nested loops **stack into lanes** (pure `LoopLanes` interval
packing, unit-tested) so overlap reads by position while colour stays reserved for
state (the active loop is drawn brighter). ADR 0018.

The practice screen's state and handlers live in an `@Observable`
`WaveformPracticeModel` (not the view); `WaveformPracticeView` is the thin body
that observes and binds to it (ADR 0007). Each loop has a per-loop **automator**
(speed trainer, ADR 0013): the engine publishes `loopIteration` (loop wraps counted
in *source* frames, so it's stable across rate changes), the view feeds it to
`WaveformPracticeModel.automatorAdvance`, which sets `speed` from the pure
`AutomatorConfig.speed(atLoopIteration:)` (interpolates start→target over N steps, a few
loops each, up *or* down — or level when start = target). The ramp is **finite**: it runs
`AutomatorConfig.totalLoops` passes — the `stepCount + 1` plateaus (start, the steps, and
the target) × `loopsPerStep` — then `automatorAdvance` **pauses and rewinds** the engine to
the loop start, so it can be replayed. **Set ramp** arms the config and *starts the loop
playing* from the top (`startAutomator`). Setting `speed` reuses the existing
speed→engine path; grabbing the slider disables the loop's ramp. A later slice adds a
**clean-before-fast** advance gate — an `.onConfirm` mode that holds each plateau until
the user taps step-up, plus a single-step back-off — because Pocket plays the reference
track but can't sense the user's own accuracy (ADR 0016). Opening a song's audio is **async and
off the main actor** — the engine reads the file header on a detached task (it can
block on large or not-yet-downloaded iCloud files), so the UI stays responsive; the
model exposes `isLoadingAudio` and the view shows a dimming **loading overlay**
(`AudioLoadingOverlay`) that also blocks taps on the half-ready controls until ready.

Apple Music tracks skip stages 2–4 (no raw audio) — they are browse/metadata
only. See `docs/decisions/0001`.

## Persistence

- **SwiftData `@Model` domain** (`Core/Models/`): `Song` is the aggregate root, with
  cascade relationships to its `Loop`s and `Marker`s. The practice screen binds to a
  persisted `Song` via the `ModelContext`; loops/markers persist across launches. ADR 0011.
- **Song metadata editing** (`Features/Library/SongEditSheet.swift`, ADR 0012): the
  editable counterpart to the read-only `SongInfoPanel`. Reached by swiping a library
  row → Edit, it edits local `@State` and writes back to the `@Model` on Done (Cancel
  discards), mirroring the loop/marker sheets. `Song` carries the scalar fields
  (`album`, `year`, `comment` joined `title`/`artist`/`key`/`bpm`/`proficiency`/
  `progression`/`collections`); `annotationCount` (= loops + markers) is the
  pure, unit-tested stat shown in the sheet.
- `SongRef` is the song's identity (stored on `Song`), so practice data survives the
  underlying file being moved or re-granted.
- CloudKit-backed sync (Phase 4) is a configuration step on the same `@Model` graph, not
  a re-model.

## Backend

- Single proxy endpoint for AI session suggestions; key held server-side.
- Base URL by build config (Debug → dev, Release → prod). See `docs/decisions/0002`.

## Testing

- **Unit (PocketTests):** pure logic — tempo math, slider mapping, automator
  stepping, identity, planner weighting + candidate selection (ADR 0015). Must be covered.
- **UI (PocketUITests):** XCUITest for key flows.
- Audio / MusicKit behaviour is validated on device/simulator, not unit-tested.