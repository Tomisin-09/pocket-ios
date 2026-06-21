# Architecture

## Layers

```
┌─────────────────────────────────────────────────────────┐
│ SwiftUI Features (Library · Waveform · Planner · Repertoire)
├─────────────────────────────────────────────────────────┤
│ Core
│   Audio    — AVAudioEngine + AVAudioUnitTimePitch, audio tap → waveform,
│              TempoMath · TempoPeaks · TempoEstimator · AudioMath · WaveformGesture · BeatGrid · LoopLanes (pure)
│   Models   — Song, Loop, Marker, Routine, Session, SongRef, AutoName (pure)
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
in `WaveformGesture`, ADR 0005), which also handles **pinch-to-zoom** — a **page-mode**
viewport (owned `zoomSpan` + `viewportStart`): the window holds still while the
playhead sweeps across it, then pages forward at ~90% (`WaveformGesture.pagedStart`),
with a Fit / 1× reset (ADR 0010). When zoomed in, the visible window is **re-downsampled
from the source file at full detail** (`WaveformExtractor.extractWindow` → the same
`AudioMath.downsample`, off the main actor, debounced on viewport settle and cached by
window) so a deep zoom resolves real transients instead of stretching the stored
whole-song envelope; the stored 512-bar envelope stays the zoomed-out and fallback path
(ADR 0020). On a gesture **release** — a drawn loop edge, a Fine handle, or a tap-seek —
the boundary **snaps to a nearby marker or saved-loop edge** if one is within an
on-screen tolerance (pure `WaveformGesture.snap`, candidates sourced and tolerance
scaled by zoom in `WaveformPracticeModel+Snap.swift`, light haptic on a catch);
continuous scrub and the minimap stay un-snapped (ADR 0021). When a song has a **BPM
and a downbeat anchor** (`Song.downbeatSeconds`), pure `BeatGrid` turns tempo + phase
into per-beat song fractions (flagging bar-start downbeats, 4/4); these are drawn as a
faint, density-aware grid behind the bars and **added to the snap candidates**, so a
release also catches the pulse — no grid is drawn or snapped to without both BPM and
the anchor (ADR 0022). Tempo and the downbeat are set behind **"Set BPM"** (`BPMSheet`):
**tap-tempo** captures the engine's song-time per tap (pure `TempoMath.bpm(fromTapTimes:)`,
so in-loop / slowed tapping reads the true tempo) or **manual** entry, and **the 1** is
placed by a draggable waveform handle that **snaps to the loudest transient** near the drop
(pure `TempoPeaks.snap`, against the displayed bars so a deep zoom sharpens it). Tempo is
persisted full-precision in `Song.preciseBPM` — an **additive** optional so SwiftData
lightweight migration is safe (a type change on `bpm` is not); `Song.bpm: Int?` remains the
rounded display mirror and `Song.tempoBPM` feeds the `Double`-tempo `BeatGrid` so the grid
doesn't drift across a long song (ADR 0024). The sheet can also **estimate the tempo
on-device** (ADR 0004, rung 2): `WaveformExtractor.extractOnsetEnvelope` decodes the
source to a ~100 Hz onset-strength curve (`AudioMath.onsetEnvelope` — frame RMS reduced
to its half-wave-rectified rises) off the main actor, and pure `TempoEstimator.estimateBPM`
takes the autocorrelation peak of that curve, weighting each candidate lag by a log-normal
**tempo prior** (~120 BPM) to fold the common half/double-tempo error; a flat/ambient curve
yields `nil` (no confident read). It also places **the 1**: a comb-filter
(`TempoEstimator.estimateDownbeat`) slides a pulse train at the detected period across the
envelope and keeps the phase whose beats collect the most onset energy — pinning the beat
phase to real hits (the *bar-1* beat isn't disambiguated, so the anchor can sit a beat off).
The estimate only **prefills** the sheet (BPM + downbeat) flagged as estimated — the user
still confirms it, so speed never depends on a guess. An active loop **loops
continuously, gaplessly and click-free** — the
engine pre-renders the loop region into a buffer whose seam is equal-power
**crossfaded** (`AudioMath.crossfadeGains`) and plays it on `.loops`, so the wrap is
both gapless and free of the splice click; the visual playhead wraps via pure
`AudioMath.loopedPlayhead`, decoupled from the audio (region math in
`AudioMath.loopSegment`; ADRs 0006 & 0008). Playback is surfaced to the system
**lock screen / Control Center** (play/pause only) by `NowPlayingController` — a
`@MainActor` bridge that owns the `MPRemoteCommandCenter` targets and pushes
`MPNowPlayingInfoCenter` updates from a pure, unit-tested `NowPlayingState`
(`reportedRate` = speed while playing, 0 when paused). Because the command center
is a process-global singleton, its targets are removed on screen exit:
`WaveformPracticeView.onDisappear` → `model.endPlaybackSession()` clears the info,
removes the targets, and calls `engine.stop()` (halt → deactivate the session), so
audio stops on leaving the screen and nothing keeps the engine alive — while
backgrounding mid-practice keeps playing under the existing `audio`
`UIBackgroundMode` (ADR 0025). A **metronome** can click over the song
(transport **Click** toggle): pure `MetronomeSchedule` takes the `BeatGrid`
(in source seconds), the playhead, and the playback rate and returns the beats
due in the next ~1 s with **how far ahead each sounds** — `delay = (beat − now) /
rate`, so the click *follows playback speed* (50% → half-BPM, locked to the slowed
track). The audio is a `ClickVoice`: a second `AVAudioPlayerNode` on the **same
engine** wired straight to the mixer (bypassing time-pitch, so ticks aren't
stretched) with two synthesized buffers (accented downbeat / plain beat). The
engine refreshes the schedule on its 0.03 s display timer, deduping by a watermark,
and flushes-and-refills on any discontinuity (rate / seek / loop / pause). It's
enabled only when the grid exists (BPM + the 1) and **never writes back** to the
song's tempo; it's silenced on pause and screen exit (ADR 0026). Stage 4's waveform for real files is
extracted up front by `WaveformExtractor` (chunked AVFoundation read →
`AudioMath.mixToMono`/`downsample`, the reduction unit-tested) and stored on the `Song`;
the demo's waveform is still downsampled from its generated buffer (ADR 0011, Slice 2).
The reduction is **transient-resistant energy, percentile-normalised** (512 bars) —
each bar is the median of several short RMS sub-windows, so the envelope tracks the
sustained music and steps over rhythmic spikes (a snare) rather than flat-topping on
loud masters; the bucket count doubles as a stored-format version that re-extracts
pre-ADR-0017 waveforms on open. The detail waveform draws the **whole**
loop/marker library on its **borders** — markers as purple inverted triangles along
the top, loops as **per-loop coloured lines** along the bottom; overlapping/nested
loops **stack into lanes** (pure `LoopLanes` interval packing, unit-tested) so
overlap reads by position. Colour encodes loop **identity** (deterministic palette
slot, pure unit-tested `LoopColors`) with state carried by line weight; the theme is
the blue palette (blue bars anchored on `#2a6796`) on the near-black background. ADR
0023 (supersedes the colour-is-state rule of ADR 0018). New loops are created
**instantly** on confirm — auto-named ("Loop 3", pure `AutoName`), activated, and
**looping immediately** (seek to start + play), no naming sheet (markers keep theirs);
deleting a loop/marker shows an **Undo** toast
that restores it from a snapshot with its original `uid`. ADR 0019.

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

The transport bar (ADR 0030) carries a **rewind · pause · forward** playback cluster
alongside the Loop/Mark/Fine identity dots; skip targets are loops ordered by start
(neighbour lookup is the pure, unit-tested `TransportNav`; cross-song skip is deferred).
An **active-loop colour strip** (the loop's identity hue via the shared `LoopColor`, the
same slot the waveform/minimap use) makes the looping state unmistakable. A scrub starting
near the screen edge is stopped from popping the screen: the model brackets each waveform
touch (`isScrubbing`) and `SwipeBackGuard` disables the nav stack's interactive pop while a
finger is down (ADR 0030).

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