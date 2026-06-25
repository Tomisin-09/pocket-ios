# Architecture

## Layers

```
┌─────────────────────────────────────────────────────────┐
│ SwiftUI Features (Library · Waveform · Planner · Repertoire)
├─────────────────────────────────────────────────────────┤
│ Core
│   Audio    — AVAudioEngine + AVAudioUnitTimePitch, audio tap → waveform,
│              TempoMath · TempoPeaks · TempoEstimator · AudioMath · WaveformGesture · BeatGrid · MetronomeBeats · TempoMarking · LoopLanes (pure)
│   Models   — Song, Loop, Marker, Routine, Session, SongRef, AutoName · Labels · LibrarySectioning · MasteryRollup · LoopProgressFormat · MusicalKey (pure)
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
A/B-span set, and edge-drag are driven by the waveform **gesture engine** (pure math
in `WaveformGesture` + the pure `ABSpan` state machine, ADR 0005 / 0041). Loop creation
is the **A/B span**: tap the A/B control to set A then B (or hold-drag to paint it), the
ephemeral span loops with no confirm gate, its A / B handles drag in place, "Save as loop"
persists it, and dragging a saved loop's edge lifts it back into A/B to re-edit — the old
Fine mode and capture/confirm flow are retired. The gesture engine also handles
**pinch-to-zoom** — a **page-mode**
viewport (owned `zoomSpan` + `viewportStart`): the window holds still while the
playhead sweeps across it, then pages forward at ~90% (`WaveformGesture.pagedStart`),
with a Fit / 1× reset (ADR 0010). When zoomed in, the visible window is **re-downsampled
from the source file at full detail** (`WaveformExtractor.extractWindow` → the same
`AudioMath.downsample`, off the main actor, debounced on viewport settle and cached by
window) so a deep zoom resolves real transients instead of stretching the stored
whole-song envelope; the stored 512-bar envelope stays the zoomed-out and fallback path
(ADR 0020). On a gesture **release** — a dragged A/B edge or a tap-seek —
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
song's tempo; it's silenced on pause and screen exit (ADR 0026).

A **standalone metronome** (ADR 0043, `Features/Metronome/`) reuses the same pieces
without a song. `StandaloneMetronomeEngine` (`Core/Audio/`) owns its **own**
`AVAudioEngine` + `ClickVoice` and *generates* its grid with the pure `MetronomeBeats`
(BPM + beats-per-bar → ascending `(time, isDownbeat)` pairs). **Steadiness comes from the
sample clock:** every click is scheduled at an *absolute* sample position
(`phaseOrigin + index · framesPerBeat`) via `ClickVoice.schedule(atSampleTime:)`, so the
tempo is locked to the audio hardware and can't wander with `Timer` jitter — the timer
only tops up the look-ahead. The on-screen **beat-flash indicator** reads the same
`currentBeat`, derived from the render head shifted back by the output latency so the lit
dot lands on the *heard* click rather than leading it. Meter is the pure `TimeSignature`
(named presets — 4/4 pop, 3/4 waltz, 6/8, 12/8 slow blues, … — each carrying its accent
pattern); BPM is the click rate and the accent pattern picks the strong clicks. Transport
is three-state — **stopped → playing → paused** — with a **wall-clock session tracker**
(`elapsed`, accumulated across pause/resume, frozen while paused, zeroed on stop, *not*
persisted) kept separate from the **sample-clock beat phase** (re-anchored on a
tempo/signature change or a resume). Lock-screen / Control Center play-pause is wired
through the shared `NowPlayingController`, and the `audio` background mode (ADR 0025) keeps
the click sounding while locked. An optional **tempo automator** (the pure
`MetronomeAutomator`, sibling of the in-song `AutomatorConfig`) ramps the BPM up over the
sitting: it steps a fixed amount every N **bars** or N **seconds** and holds at a ceiling.
The engine accrues elapsed bars (integrated at the live tempo) and seconds since the ramp
engaged, hands them to the pure ramp each tick, and applies the resolved BPM as an
automator-driven tempo change (re-anchoring like a manual one). The two per-tick SwiftUI views (dots, session readout) are
isolated structs so the ~50 Hz updates don't re-render the controls (which would dismiss
the time-signature menu mid-play). Tap-tempo reuses `TempoMath.bpm(fromTapTimes:)`; the
Italian tempo marking is the pure `TempoMarking` lookup. Reached for now via a **temporary**
Library toolbar button (ADR 0043 — moves to a home screen later). Stage 4's waveform for real files is
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
0023 (supersedes the colour-is-state rule of ADR 0018). A loop may also carry a manual
colour override — a palette `Loop.colorIndex` or a free `Loop.customColorHex` (colour
wheel), chosen in its edit sheet. `LoopColor.color` resolves precedence custom →
palette (pure `LoopColors.resolvedSlot`) → derived, so the waveform/minimap/transport
strip all honour it from one place; a low-contrast custom colour gets an advisory
warning via the pure `ColorContrast` (`HexColor` bridges `Color` ⇄ hex). ADR 0031. New loops are created
**instantly** on confirm — auto-named ("Loop 3", pure `AutoName`), activated, and
**looping immediately** (seek to start + play), no naming sheet (markers keep theirs);
deleting a loop/marker shows an **Undo** toast
that restores it from a snapshot with its original `uid`. ADR 0019.

The practice screen's state and handlers live in an `@Observable`
`WaveformPracticeModel` (not the view); `WaveformPracticeView` is the thin body
that observes and binds to it (ADR 0007). Its cockpit and loops/markers reference
list are extracted as `PracticeCockpit` / `PracticeReference`
(`WaveformPracticeLayout.swift`) so the portrait (stacked) and landscape (full-width
cockpit + a slide-in loops/markers drawer) layouts compose the same pieces; the view
branches on `verticalSizeClass`. Landscape
is gated to this screen alone by `OrientationGate.swift` (an `AppDelegate` answering
`supportedInterfaceOrientationsFor` from a mask that a `.landscapeEnabled()` modifier
widens on appear and reverts on disappear) — ADR 0042. Each loop has a per-loop **automator**
(speed trainer, ADR 0013): the engine publishes `loopIteration` (loop wraps counted
in *source* frames, so it's stable across rate changes), the view feeds it to
`WaveformPracticeModel.automatorAdvance`, which sets `speed` from the pure
`AutomatorConfig.speed(atLoopIteration:)` (interpolates start→target over N steps, a few
loops each, up *or* down — or level when start = target). The ramp is **finite**: it runs
`AutomatorConfig.totalLoops` passes — the `stepCount + 1` plateaus (start, the steps, and
the target) × `loopsPerStep` — then `automatorAdvance` **pauses and rewinds** the engine to
the loop start, so it can be replayed. **Set ramp** arms the config and *starts the loop
playing* from the top (`startAutomator`). Setting `speed` reuses the existing
speed→engine path; grabbing the slider disables the loop's ramp. Each loop also remembers
the speed it was last practised at (`Loop.lastPracticedSpeed`, ADR 0040): a single `didSet`
on `activeLoopID` persists the *outgoing* loop's `speed` on any leave/switch/exit, and arming
a loop restores it (`Loop.resumeSpeed` = last-practised, else the loop's `speed`) — so the
three loop tempos (`speed` = ramp start, `lastPracticedSpeed` = resume, `commandTempo` =
fastest owned) stay distinct. This refines ADR 0029: the session opens clean, but loops carry
per-loop speed memory. A later slice adds a
**clean-before-fast** advance gate — an `.onConfirm` mode that holds each plateau until
the user taps step-up, plus a single-step back-off — because Pocket plays the reference
track but can't sense the user's own accuracy (ADR 0016). Opening a song's audio is **async and
off the main actor** — the engine reads the file header on a detached task (it can
block on large or not-yet-downloaded iCloud files), so the UI stays responsive; the
model exposes `isLoadingAudio` and the view shows a dimming **loading overlay**
(`AudioLoadingOverlay`) that also blocks taps on the half-ready controls until ready.

The transport bar (ADR 0030 / 0041) carries a **rewind · pause · forward** playback cluster
alongside the A/B and Marker identity dots; skip targets are loops ordered by start
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
  editable counterpart to the read-only `SongDetailsSheet` (the practice screen's
  `SongInfoPanel` was removed in ADR 0042; song facts now live only in the details sheet).
  Reached by holding a library
  card → Edit (context menu), it edits local `@State` and writes back to the `@Model` on Done (Cancel
  discards), mirroring the loop/marker sheets. `Song` carries the scalar fields
  (`album`, `year`, `comment` joined `title`/`artist`/`key`/`bpm`/`collections`);
  `annotationCount` (= loops + markers) is the pure, unit-tested stat shown in the sheet.
- **Field-model taxonomy & derived mastery** (ADR 0036): every `Song`/`Loop` field is one
  of four buckets — *intrinsic fact*, *scalar/enum* the app reasons about, *descriptive
  tag* (`[String]`), or *named grouping* (`collections`). The song's practice **Mastery**
  is no longer stored: it is **derived** from its loops via `MasteryRollup.rollup`
  (rounded average of the *rated* loops, skipping unrated `nil`s; `nil` ⇒ "Unrated" — ADR
  0039), kept SwiftData-free and unit-tested per the
  pure-logic rule. `Loop.mastery` is the stored source; `Song.lastPracticed` feeds the
  planner (ADR 0014). The song **key** is the scalar/enum bucket: `MusicalKey` (pure, 12
  roots × major/minor + `.unknown`) is the typed vocabulary, with `MusicalKey.parse`
  folding legacy free text and flats onto cases. The SwiftData attribute stays
  `Song.key: String`; `Song.musicalKey` parses on read and writes the canonical raw value
  on save, so the typed model lands without a schema migration. The loop adds the rest of
  the scalar/enum bucket — `Loop.focus` (`Int?` 1–3 intent), `Loop.commandTempo` (`Double?`,
  fastest owned tempo as a fraction), and `Loop.loopType` (the pure `LoopType` enum —
  Lick / Riff / Chords / Passage + `.unset`, where Passage is the composite for a loop that
  spans more than one). `loopType` stores a backing `String` (`loopTypeRaw`)
  with a computed enum over it — like `key`/`MusicalKey` — because a custom enum `@Model`
  attribute does **not** survive lightweight migration (existing rows fault on first read).
  The three **judgment** scalars (`mastery`, `focus`, `commandTempo`) are **Optional with no
  declaration default** (ADR 0039): `nil` = never set, the honest state for a new or migrated
  loop, so a default never reads as a real rating. Optionals are *exempt* from the
  mandatory-attribute rule, so they migrate pre-0039 loops to `nil` for free; `loopType`'s
  backing `String` keeps its `""` default. All fill pre-0036/0039 loops without a store wipe.
  Display percent + the `nil → "—"` fallback live in the pure `LoopProgressFormat`.
- **Two-axis annotation** (`[String]`, shared `Labels` canonicaliser): the descriptive-tag
  bucket is `Song.collections` (song scope, ADR 0033) and `Loop.tags` (loop scope, ADR 0034) —
  one scope-agnostic normaliser (trim → collapse whitespace → case-insensitive de-dup, first-seen
  form), two callers, so neither set fragments into `Blues`/`blues`. Both edit sheets suggest from
  values already used across the library (`Labels.suggestions` over a `flatMap`-aggregated pool —
  all songs' collections / all loops' tags via a top-level `@Query`) so entries converge rather than
  multiply. Both are declaration-default `[String]` arrays (migration-safe, CloudKit-clean — no
  `@Model` promotion). The cross-song *filter by tag* payoff is gated on its first consumer (the
  planner, ADR 0014); collections already filter the library (intersection/AND, ADR 0033).
- `SongRef` is the song's identity (stored on `Song`), so practice data survives the
  underlying file being moved or re-granted.
- **`MetronomeExercise`** (ADR 0043): a standalone, **audio-free** `@Model` — a savable
  metronome preset that *is* a practice exercise (name, absolute `currentTempo`/`targetTempo`
  BPM, time signature, `accentBeats`, subdivision, the automator recipe, `tags`, `notes`).
  Deliberately **not** related to `Song`/`Loop` (a `Loop` carries audio assumptions an
  exercise has none of). Joins the same store as an additive migration (registered in the
  app's `modelContainer`), following the 0011/0012/0036 discipline: a `uid: UUID`, declaration
  defaults on every non-optional attribute (CoreData 134110), and the `Subdivision` /
  `MetronomeIntervalUnit` enums stored through `String` backing fields with computed views
  (the enum-attribute migration rule). The day-to-day value is `currentTempo` and the goal
  `targetTempo` — "command tempo" stays reserved for `Loop`'s measured achievement.
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