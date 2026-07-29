# Architecture

## Layers

```
┌─────────────────────────────────────────────────────────┐
│ SwiftUI Features (Home · Library · Waveform · Metronome · Practice · Journal · Toolkit · Repertoire)
│   UI       — shared components + design tokens (PocketColor) · AdaptiveLayout (ADR 0105 iPad groundwork:
│              PocketLayout readable-width cap + readableWidth() modifier — dormant while TARGETED_DEVICE_FAMILY=1)
│              · PocketRowActions — the one row-affordance modifier every list adopts (long-press menu →
│                Favourite → Delete, plus leading/trailing swipes); RowDeletionCoordinator + the
│                \.rowDeletion environment seam back its deferred, undoable delete; UndoToastView is shared
│                with the waveform
├─────────────────────────────────────────────────────────┤
│ Core
│   Audio    — AVAudioEngine + AVAudioUnitTimePitch, audio tap → waveform,
│              TempoMath · TempoPeaks · TempoEstimator · AudioMath · WaveformGesture · WaveformAmplitude · BeatGrid · MetronomeBeats · MetronomeGrid · TempoMarking · TempoSliderScale · LoopLanes (pure)
│   Models   — Song, Loop, Marker, Routine/RoutineItem, Goal (planner input, ADR 0073) · Profile (local account-free artist profile — singleton, drives the home greeting; + ADR-0113 curation fields via pure `ProfileCuration` enums, feeding new-exercise tempo + planner-length defaults (S2) and the planner emphasis mix (S3), ADR 0113; ADR-0113-S4 `ArtistNameGenerator` — pure seed→name over curated Red Moon pools + blocklist, powering the offered name in the naming ceremony) · RoutineBudget · RoutineSessionCursor (pure player stepping, ADR 0071) · Planner: PlannerCandidate/SessionBlock/DueScore/SessionBuilder (back-half) + TechniqueTaxonomy/SkillCatalog/SkillFamilyMap/CandidateDeriver/GoalTemplate/PlannerLibrary/PlannerID/SessionEstimate/GenreSkillMap/PracticeEmphasis (front-half, pure; the last two = ADR-0113-S3 profile emphasis mix) + PracticePlanner (impure projector/materialiser, ADR 0072/0073), Session, SongRef, AutoName · Labels · LibrarySectioning · PracticeLibrarySort · NoteRate (notes-per-beat + its label and `notesPerMinute`; `Exercise.noteRate` resolves the content's own `notesPerBeat` first, then `Exercise.notesPerBeat`, else `nil` = **no rhythm stated**, which is a real answer and never a defaulted "quarters") · RhythmChange (ADR 0121 — the pure rescale behind *keep the same note speed*, clamped to the engine range with the ramp invariants restored; `Exercise.commandNotesPerBeat` binds a measured command to the rhythm it was earned at, `RhythmChangePrompt` asks the player, `ExerciseNoteRateBackfill` retires the never-wired `subdivision` into `notesPerBeat` once at launch) · MasteryRollup · LoopProgressFormat · JournalGrouping (day-bucketing) · JournalTimeline (ADR 0100 — pure merge of notes + takes into one newest-first feed + scope filter + owner-label, feeding the read-only Journal space) · MusicalKey · ExerciseTemplate (closed axis, ADR 0068) · Instrument (per-exercise axis, ADR 0116 — guitar/bass, `instrumentRaw`-backed on `Exercise` defaulting from `Profile.preferredInstrument`; the tuner's lowest-first `Tuning` crosses into the highest-first fretboard engine through the single pure `Tuning.engineOpenMidi` reversal, golden-tested guitar-byte-identical; ADR-0116 S3 renders bass via `expanded(instrument:)` on the run generators + a dedicated `BassNeckLayout` 2-octave 4-string box reusing the shared `ScaleNeckLayout.ascendingTones` ladder, guitar path unchanged) · ExerciseKind (derived renderer) · StrumPattern · FretboardDrill · FretboardRun (movable finger-pattern run, with ADR-0083 position-shifting: per-pass climb + per-string diagonal + retrace/restate come-back + slide seams; a climb wider than the comfortable board (~8 frets) drives the ADR-0083 S5 **following viewport** — the pure `FretboardDrill.displayWindow(activeIndex:)` holds an 8-fret window static and scrolls it only when the active note reaches the edge (hysteresis), landing the note near the trailing edge to prioritise the runway ahead so it reframes only ~twice over a whole climb and never while the note is visible; a gentler climb or short run keeps the static full window; plus ADR-0083 S2b **pass focus** — a transient parallel `FretboardDrill.noteGroups` (filled at generation, not encoded) lets the renderer fade off-pass notes while a multi-pass climb walks)/ScaleRun (with ADR-0083 S4 `ScaleLayout` axis — `.box` default + pure `ScaleNeckLayout` `.extended` pentatonic diagonal with `.slide` seams (two canonical `ExtendedPentatonicShape` fingerings: A-G or D-B slide, whole-step seams) + `.threePerString` diatonic drill, gated by `GuitarScale.supportedLayouts`; plus an orthogonal ADR-0108 sequence axis — `SequencePattern` (straight/thirds/fourths/groups-of-3-4), a pure permutation of the played run leaving `ascendingNotes` untouched; boxes labelled by root anchor with the CAGED letter demoted, opening on the flagship root-position box, ADR 0091; plus a `startsFromLowestRoot` axis (2026-07-28) trimming the box notes below the lowest root so a run opens on the tonic — applied before the octave trim, box-layout-only, and split-defaulted (`true` from `init`, `false` from `decodeIfPresent`) so new runs start on the root while saved ones keep their authored order; `positionNotes` splits the hand's shape off from the played order so the position label doesn't move with it)/ArpeggioRun (same axis)/GuitarScale (ADR 0085 catalog: pentatonics + major + all seven modes borrowing their parent-major box + blues/bebop threading a chromatic passing tone above `passingToneAnchorDegree`; symmetric diminished/whole-tone are drawn on the custom-scale canvas instead of box-generated, ADR 0107)/ArpeggioQuality/CAGEDShape/FretboardContent (generative payload — shared CAGED box engine, ADR 0065) · ChordVoicing/ChordProgression (chord-diagram payload — triads fold in, ADR 0065) · ChordGrip (ADR 0084 movable-shape recipe — pure relative geometry + root string + quality, placed at a root note to generate a `ChordVoicing`; curated Tier 1–2 = E/A-shape triads + 7ths + sus2/sus4/6ths + 9ths (ADR 0101) + power chords (root+5th, ADR 0106), reproducing the `fBarre`/`bMinorBarre` barres byte-for-byte; authored via `MovableChordSheet` (Practice), which mixes slid grips inline with the open-shape library — no slide *animation* since a progression never physically slides between chords, the movable idea is a static shape-family + fret label) · ExerciseAudioEngine (silent-default audio seam)
│   Theory   — ChordNamer (ADR 0093 reverse-lookup: pitch-class set + optional bass → ranked [ChordCandidate] over the ChordQuality.catalog common-practice table; root-position preferred, inversions get slash names, symmetric chords return every root, sharp-spelled/keyless; pure) — the shared harmonic-analysis core the chord identifier + ear-training space (ADR 0094) consume · ScaleReference (ADR 0107 — scale as name + interval formula → pitch classes, reusing GuitarScale + the symmetric whole-tone/diminished scales; drives the custom-scale canvas guide, pure)
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
(ADR 0020). At draw time each bar's normalised height passes through the pure
`WaveformAmplitude` gamma curve — display-only dynamic-range compression for a fuller,
calmer skyline; the snap/marker math still reads the raw peaks (ADR 0049). On a gesture
**release** — a dragged A/B edge or a tap-seek —
the boundary **snaps to a nearby marker or saved-loop edge** if one is within an
on-screen tolerance (pure `WaveformGesture.snap`, candidates sourced and tolerance
scaled by zoom in `WaveformPracticeModel+Snap.swift`, light haptic on a catch);
continuous scrub and the minimap stay un-snapped (ADR 0021). When a song has a **BPM
and a downbeat anchor** (`Song.downbeatSeconds`), pure `BeatGrid` turns tempo + phase
into per-beat song fractions (flagging bar-start downbeats, 4/4); these are drawn as a
faint, density-aware grid behind the bars and **added to the snap candidates**, so a
release also catches the pulse — no grid is drawn or snapped to without both BPM and
the anchor (ADR 0022). A **seek release splits by gesture** (ADR 0080): a **tap** ("take
me to that structure") snaps to the full set including beats, while a free **scrub** ("put
the playhead exactly here") drops the dense beat grid and catches only the sparse landmarks
(markers + loop edges) — the same candidate set the minimap uses, so a deliberate scrub
between beats lands where the finger lifts. Beat snap for *placement* (loop-edge commit,
Fine-handle release, the downbeat) is unaffected; only the seek scrub stops catching beats. Tempo and the downbeat are set behind **"Set BPM"** (`BPMSheet`):
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
(`reportedRate` = speed while playing, 0 when paused); it also attaches a default **Red Moon
crescent artwork** (the `DefaultArtwork` asset), since imported songs carry no embedded cover art.
Because the command center
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
stretched) with three synthesized buffers (accented downbeat / plain beat / a quieter
subdivision tick — ADR 0043 slice 5, selected per click via `ClickLevel`). The three
buffers are voiced by a user-selectable **`ClickTimbre`** (Click / Wood block / Rim / Beep —
pure PCM synthesis, no sample assets, hybrid-ready; ADR 0114): `ClickVoice.loadTimbre` rebuilds
them from `AppSettings.clickTimbre` at each playback start, so both this in-song click and the
standalone tool stay in sync, and a Settings audition (`MetronomeSoundPreviewPlayer`, its own
throwaway engine) never touches a live session. The
engine refreshes the schedule on a 0.03 s **metronome timer**, deduping by a watermark,
and flushes-and-refills on any discontinuity (rate / seek / loop / pause). The **visual
playhead** is on its own clock: a `CADisplayLink` (`DisplayLinkTicker`) samples the audio
render position once per display frame (vsync-aligned, 60/120 Hz) so it glides rather than
stepping at the timer's sub-refresh cadence (ADR 0054). It's
enabled only when the grid exists (BPM + the 1) and **never writes back** to the
song's tempo; it's silenced on pause and screen exit (ADR 0026).

A **standalone metronome** (ADR 0043, `Features/Metronome/`) reuses the same pieces
without a song. `StandaloneMetronomeEngine` (`Core/Audio/`) owns its **own**
`AVAudioEngine` + `ClickVoice` and *generates* its grid with the pure `MetronomeBeats`
(BPM + beats-per-bar → ascending `(time, isDownbeat)` pairs). **Steadiness comes from the
sample clock:** every click is scheduled at an *absolute* sample position
(`phaseOrigin + index · framesPerBeat`) via `ClickVoice.schedule(atSampleTime:)`, so the
tempo is locked to the audio hardware and can't wander with `Timer` jitter — the timer
only tops up the look-ahead. The same scheduler doubles as a **strum-rhythm preview**
(`StandaloneMetronomeEngine+Strum`, ADR 0071 R5): armed with a `StrumSchedule` (built from the pure
`StrumPattern.clickIntensities`), each sub-tick's click level comes from the pattern's slots (rests
silent) instead of the meter — a rhythm reference, no pitch — driven by a thin `StrumPatternPreviewPlayer`. The on-screen **beat-flash indicator** reads the same
`currentBeat`, derived from the render head shifted back by the output latency so the lit
dot lands on the *heard* click rather than leading it. Meter is the pure `TimeSignature`
(named presets — 4/4 pop, 3/4 waltz, 6/8, 12/8 slow blues, … — each carrying its accent
pattern); BPM is the click rate and the accent pattern picks the strong clicks. A
**subdivision** (`Subdivision` — eighths / triplets / sixteenths) fills each beat with
`ticksPerBeat` evenly-spaced ticks: the on-beat one keeps the accent/beat level, the
in-between ones sound the quieter subdivision level (the on-screen flash stays on main
beats only). Transport
is three-state — **stopped → playing → paused** — with a **wall-clock session tracker**
(`elapsed`, accumulated across pause/resume, frozen while paused, zeroed on stop, *not*
persisted) kept separate from the **sample-clock beat phase** (re-anchored on a
tempo/signature change or a resume). Lock-screen / Control Center play-pause is wired
through the shared `NowPlayingController`, and the `audio` background mode (ADR 0025) keeps
the click sounding while locked. An optional **tempo automator** ramps the BPM up over the
sitting. The engine drives whichever pure ramp conforms to `TempoRamp`: the free-play
**`MetronomeAutomator`** (sibling of the in-song `AutomatorConfig`) — step a fixed amount
every N **bars** or N **seconds** and hold at a ceiling — or the command-anchored
**`CommandRamp`** (ADR 0045): warm up from the working floor to **command**, **dwell** at
command for the bulk of the reps, summit at the target reach, then **back off** below
command. The climb to the reach and the descent into the back-off can each carry
`reachSteps` / `backoffSteps` intermediate plateaus (ADR 0046 run-UI; `0` ⇒ the original
single jump), placed by the pure `intermediateBPMs(from:to:steps:)` helper. A `CommandRamp`
reaches the engine two ways: a free-play ramp where an exercise
command is loaded into the automator, or — for a Practice training run (ADR 0046) — handed
straight to `engine.run(ramp:)`, which sets `trainingRamp` and drives it directly instead of
routing through the automator setters (so arming and training are no longer mutually
exclusive). The engine accrues elapsed bars (integrated at the live tempo) and seconds since
the ramp engaged, hands them to `activeRamp` (`trainingRamp` first) each tick, and applies the
resolved BPM **phase-continuously** (ADR 0047): unlike a manual change — which hard re-anchors
to a fresh accented beat 0 — a ramp step keeps the tick counter and re-origins the grid (pure
`MetronomeGrid.reanchoredOrigin`) so the heard click splices seamlessly at the new spacing and
the downbeat stays a downbeat, instead of lurching mid-bar on every step. The two per-tick SwiftUI views (dots, session readout) are
isolated structs so the ~50 Hz updates don't re-render the controls (which would dismiss
the time-signature menu mid-play). Tap-tempo reuses `TempoMath.bpm(fromTapTimes:)`; the
Italian tempo marking is the pure `TempoMarking` lookup. The slider's position↔BPM binding goes
through the pure `TempoSliderScale` (`Core/Audio/`), a **logarithmic** map so the track midpoint
is the *geometric* centre (√(30·300) ≈ 95 BPM) and the common 60–120 band fills the middle
rather than the left fifth a linear scale would give; the steppers and tap-tempo still set
absolute BPM. The metronome is a **pure free-play tool** (ADR 0046): its in-screen exercise UI
(save/load presets, the library sheet, the command-anchored Training Mode) has been removed —
exercises and training runs now live in the top-level **Practice** space (below). What stays is
the free-play **tempo automator** (`MetronomeAutomatorPanel`) for ad-hoc ramps. **Arming is
separated from running** (ADR 0048): the segmented Off / By Bars / By Time control only
*configures* the ramp and previews its staircase (`automatorEnabled`); an explicit **Start**
(`startAutomatorRun`) begins the climb after a one-bar beat-synced **count-in**, and **Stop**
halts it leaving the click at the tempo reached (`automatorRunning` is what `isRampActive` keys
the free-play ramp on). A **No limit** toggle drops the target and ramps to the system ceiling
(infinite mode, *derived* from `ceiling == bpmRange.upperBound`), and a finished free-play ramp
holds at its ceiling rather than stopping the session (`finishRamp`; a Practice training run
still ends the session). Its job is *discovery* — ramp until your hands break down — and an
armed automator offers a one-directional **"Save as exercise"** seam (a compact bookmark) that
captures the current (breakdown) tempo and presents Practice's
`NewExerciseSheet` prefilled with it as the command. Both that seam and Practice's own create flow
funnel through the single `Exercise.commandAnchored(name:command:)` factory, so the two entry
points can't drift. **Command-anchored progress** (ADR
0045) — reach = command + ~6%, clamped — is the pure `TempoStretch`, now exercised from Practice.
The reach can also be **manually pinned** (ADR 0075): optional `Exercise.targetTempoOverride` /
`Loop.targetSpeedOverride` fields, read through the effective `reachTempo` / `targetSpeed`
accessors (`override ?? auto`), with `promoteCommand` auto-clearing a pin once command catches up.
The **back-off** tail is controllable on exercises **and loops** (user-testing note 6):
`Exercise.includeBackoff` / `Loop.includeBackoff` (default on) toggle it, and an optional
`Exercise.backoffTempoOverride` (BPM) / `Loop.backoffSpeedOverride` (×) pins the floor, fed to
`CommandRamp.backoffOverride` (nil ⇒ the `TempoStretch`-derived floor; `LoopCommandRamp` maps × → %).
Reached from the **Metronome card on the home hub** (`Features/Home/`, ADR 0044), full-screen.

**Hear — pitched-tone preview** (`ToneEngine`, `Core/Audio/`, ADR 0097). A shared, sequence-capable
tone service for the Toolkit's reference surfaces, **separate from the file-playback pipeline** (a
pitch reference, not song audio — so it does not touch ADR 0001). It owns its own tiny `AVAudioEngine`
graph over a single `AVAudioUnitSampler`: on iOS an *unloaded* sampler renders a clean built-in tone
(no accessible system GM bank), which is the **zero-asset** pitch reference v1 ships; a redistributable
(CC0) `HearGuitar.sf2` in the bundle would swap in a nylon-guitar program over the same path (deferred,
ADR 0097 D4.3). Its primitive is "sound an ordered set of MIDI notes": `sound(_:)` plays them together
(a **block chord**), `sequence(_:)` spaces them in time (scale run / arpeggio / interval), both reading
MIDI the models already expose (`ChordVoicing.midiNotes`, `ScaleRun.sequence`→`CAGEDShape.midi(_:)`).
A re-tap cancels any in-flight preview and retriggers cleanly (tracked note-on/off work items + a
ringing-note set). The *what-sounds-when* arithmetic — block vs melodic timing, rests keeping their walk
slot, absolute onset deadlines — is a pure, Foundation-only `HearPlan` (unit-tested), so the sequencer
stays a thin dispatcher over it. `start()` never reconfigures the audio session off `.playAndRecord`, so
a Hear tap can't steal the session from an in-flight recording take (ADR 0069). **Every reference surface
now drives it** — block-chord Hear on My Chords / the movable & custom chord sheets, sequenced Hear on the
scale, arpeggio, picking-run and custom-drill editors — through the shared `ChordHearButton` and the
`FretboardDisplayOptionsBar` in `FretboardEditorChrome`.

**Practice-take recording foundations** (`Core/Audio/`, ADR 0069, slice 0) — the substrate
for a mic-only "audio journal," not yet a feature. Recording needs `.playAndRecord`, which
changes routing app-wide, so it is a *separate* session config (`AudioPlumbing.configureRecordSession`)
applied only while a take is armed — never a global flip — with `configurePlaybackSession`
as the restore path, leaving the metronome/playback graph untouched when nothing is armed.
The option set is the copyright/quality guardrail: `.defaultToSpeaker` (not the quiet earpiece)
+ `.allowBluetoothA2DP` and **deliberately not** `.allowBluetooth` — with HFP allowed iOS
collapses a Bluetooth route to phone-call quality to grab the earbud mic, so A2DP-only keeps
output clean and lets input fall to the built-in mic (the guitar is in the room, not the
earbuds). Isolation is a **route question, not a DSP one**: with mic-only capture the loop
couples in only *acoustically* (speaker → air → mic), so the pure **`RecordingRoute`** classifier
maps the current output ports to a *clean* take (private listening — headphones/BT/wired) or a
*bleed* nudge (speaker/AirPlay/car/unknown → "use headphones"), unit-tested and driving an honest
UX cue rather than a voice-tuned AEC that would mangle guitar tone. Mic access is the iOS 17+
`AVAudioApplication` flow (`MicPermission`) behind a specific `NSMicrophoneUsageDescription`.
Capture is **`TakeRecorder`** — mic-only to AAC via `AVAudioRecorder`, deliberately *not* tapping
the playback engine's graph, so both engines are untouched while a take is armed (the recorder
captures the mic, the practice engine keeps playing out, and the two never share a node — the app
therefore never renders its own playback into the file, ADR 0001/0064). Takes are **app-authored**
files (unlike songs, which are bookmarks to files in place): the **`Recording`** `@Model` holds
`uid`/`createdAt`/`duration` + a relative `fileName`, with a **polymorphic, cascade-owned** owner
(`loop`/`exercise`/`song` — inverse `recordings` arrays on those models, mirroring the `journal`
pillar; `ownerKind` is derived, no stored enum). **`RecordingStore`** owns the app-container
`Recordings/` directory and the retention story — delete/size plus a pure orphan sweep that reaps
files whose model row was cascade-deleted (cascade drops the row, not the on-disk audio). On the
**loop trainer**, `RecordingController` orchestrates a take as a **pre-start arm toggle** beside Start
(permission + route sampled up front; the take begins *before* playback so the `.playAndRecord` flip
never happens mid-stream — the fix for an audible glitch), and `RecordingPlayer` plays takes back one
at a time. Takes surface **beside the journal** via the one-row `PracticeReviewBar` (Journal + Takes
count pills → each opens its sheet), keeping the review aids bounded as history builds.

**Ear training — "the loops, re-surfaced"** (ADR 0104): a loop's settings sheet carries a **Train your
ear** button opening `EarTrainingSheet`, an *away-from-the-guitar* mode that plays the loop's own audio
cycling continuously (an `EarTrainingPlayer` wrapping a `LoopRunModel`, with **no** auto-stop — the
difference from the routine-preview `LoopAudioPreviewPlayer`) so the player can **hum or sing it back**,
with a live **−/+ tempo control** (25–150% of original in 5% steps, `LoopRunModel.setAuditionPercent`
pushing the rate to the engine mid-listen) to slow the phrase down. The loop's identity (name + song
prominent, type/tempo/range caption) is shown up top always — no reveal toggle; "what you hear" notes
save through the shared `JournalWriter` path tagged 👂 (`EntryKind.ear`) onto the same Journal timeline
as every other note — no bespoke store. Self-judged, no score (ADR 0094 T2b/T3): the app plays, nothing
listens, the player is the judge (ADR 0070). It replays the *real* loop audio (ADR 0001), deliberately
not the Hear synth (ADR 0097). **Slice 2** makes it a **routine block**: a loop `RoutineItem` carries a
`LoopRunMode` (`.trainer`/`.ear`, String-backed like `kindRaw`), an `.ear` block resolves to
`RoutineStageKind.earLoop` and the player embeds `EarLoopRunView` (the shared `EarTrainingView` core +
routine chrome + a manual **Done**, no completion screen — nothing to grade), authored from a peer **Ear
training** bucket in `AddRoutineUnitSheet`. Same `Loop` unit, no new schema — just a mode.

The **Practice space** (`Features/Practice/`, ADR 0046) is a top-level destination pushed from
the home hub's Practice card — the first-class home for trainable units, decoupling exercises
from the metronome at the product level. `PracticeView` is a **hub**: the live "Build today's
session" planner entry (V2 planner Slice 3 — pushes `PlannerView`) above two **unit libraries** — `ExerciseLibraryView`
(command-anchored click drills) and `LoopLibraryView` (measured song `Loop`s) — each a row that
pushes its own list. The split is for clarity/accessibility; the two models stay separate
(`Exercise` is audio-free, `Loop` is file-bound) but both are "things you train," the multi-source
surface the planner composes from. The two are also **repertoire-linkable** now: a user-authored
**`Exercise.linkedSongs` ↔ `Song.linkedExercises`** edge (ADR 0111) records which songs a drill is
*for*, as a reusable association that — unlike a `RoutineItem`'s positional, disposable reference —
outlives any routine. It is the store's **first many-to-many** (every other relationship is to-one on
its inverse): `@Relationship(inverse:)` sits on the `Exercise` side only, the `Song` side is a plain
inferred-inverse array, and both delete rules are **`.nullify`** (deleting either just drops the
membership, never cascades to the counterpart). Additive optional (empty set on migration), so it's a
safe lightweight migration on two already-registered models. This narrows the old ADR-0043/0046
"`Exercise` has no relationship to `Song`" rule to *audio/tempo*-free — the edge is plain metadata,
never an audio or tempo input. It powers **"Build a routine for this song"**: the pure
`SongRoutineBuilder` reads a song's linked exercises + its loops + itself and emits `[SessionBlock]`
(exercises/loops as `.focus`, the song as a trailing `.play`), reusing the planner's
`RoutineDetailView(generatedSession:)` → `PracticePlanner.materialise` review-then-Save seam so nothing
persists until the player commits — the "planner becomes a producer of these edges" framing, with the
direct edge as the first producer. The **collection-wide** sibling is `CollectionSessionBuilder`
(ADR 0118): a **Collection** is a `[String]` label axis on `Song` (ADR 0033), not an entity, so the
builder fans out across every song carrying the label, pools their linked exercises/loops/play-throughs,
**de-duplicates shared units by `uid`** (a drill linked to three songs warms the set up once), **sizes**
the pool to a `SessionLength` budget (Quick/Focused/Full, ≤ the 60-min ceiling) and **arranges** it by a
player-chosen `OrderMode` dial — `.structured` (drills→passages→play, deterministic), `.mixed` (grouped,
shuffled within), `.shuffled` (all blocks randomised) — with a small seeded `SeededGenerator` (SplitMix64)
keeping the shuffled modes pure/testable, and trailing play-throughs capped per length. Same emit-only
contract: it produces `[SessionBlock]` into the identical review-then-Save seam, no new persistence. Entry
is a **filtered-Library banner** (`CollectionSessionSheet` — a Length + Order configurator) shown only when
the Library is filtered to a single collection with ≥1 linked exercise/loop. That composition has a home:
**`Routine` + `RoutineItem`**
(ADR 0066) is the multi-unit *session* container — an ordered list of typed blocks (`focused` /
`warmup` / `play` / `rest`), each non-rest block referencing exactly one `Exercise`/`Loop`/`Song`
via a typed optional relationship (nullify-on-unit-delete, so a deleted unit orphans the block
rather than deleting the routine). An additive optional `Routine.lastPracticed: Date?` is stamped
when a session starts (safe SwiftData lightweight migration) and drives the home hub's "recent
routines" rail. Its pacing rules (only focused work budgeted; block caps;
proposed rests — ADR 0014) live in a pure, SwiftData-free `RoutineBudget`. Authoring is a
sandboxed editor (`RoutineDetailView`, child `ModelContext` committed only on Save), and the
**player** (ADR 0071) is a *thin* session conductor — `RoutineSessionPlayer` (`@Observable`, owns no
engine) over a pure `RoutineSessionCursor` — that **embeds the real `ExerciseRunView` / `LoopRunView` /
`SongPlayAlongView` per block** (so every training aid — previews, staircase, journal — is
kept, not re-implemented), injecting a `RoutineRunContext` (progress · Skip · exit · natural-completion
hook). Each run screen keeps its own per-unit engine (`StandaloneMetronomeEngine` / `LoopRunModel` /
`SongPlayAlongModel`, the last two on a private `PracticeAudioEngine`) and signals **natural completion**
(one command-ramp pass) through additive `onRampFinished` / `onFinished` / `onReachedEnd` engine
callbacks; the conductor itself plays only the fixed rest countdown. On completion a unit lands on a
**Done screen** (`RoutineBlockDoneView` — completion beat + optional mastery tap + optional inline note +
an optional **Move command to {value}** promote toggle for a summited exercise (opt-in, exercises-only,
target defaults to the reach but is **editable** for a custom command — ADR 0079 §7) + an **Up next**
preview of the next unit, committed together on Continue/Finish; a top-left chevron exits the routine
from here) — **manual advance the default** (ADR 0071 R4); the `routineAutoAdvance` setting (default off)
advances straight through instead (skipping the Done screen and so any promote), Skip bypasses the gate. A block authored to **repeat** (`RoutineItem.reps`, ADR
0076) runs back-to-back that many times before advancing — the pure cursor carries a rep counter
alongside the block index, `advance()` steps the rep (rolling to the next block on the last one) while
a user **Skip** (`skip()`) abandons remaining reps; the Done screen shows only after the last rep, the
progress strip reads "Rep N of M", and the run screen is keyed on the rep so each restarts fresh. Each
block is previewable **before** the routine starts
(ADR 0071 R4b): tapping an exercise/loop block in the detail editor pushes a read-only `RoutineBlockPreview`
(content + tempo + staircase + a short audio audition — a `CommandTempoPreviewPlayer` metronome click for
exercises, a `LoopAudioPreviewPlayer` of the loop's real audio for loops, each on its own engine). Because
previews happen up front, **Start** runs straight into block one (`shouldAutoStart` no longer excepts the
first block; `routineAutoStart` off still waits per-block). A **song
block** is the audio-only `SongPlayAlongView` — a fixed play-along speed (no ramp, ADR 0070), play/pause
and −10s/+10s, local/iCloud files only (ADR 0001); it loops until skipped by default, or plays through
once and advances per the `routineSongLoop` setting. It has **zero evaluation surface** (ADR 0070) —
completion is the material's length, not a graded take. `RoutinePresets` seeds three curated in-house
starter routines once on first launch (after `PracticePresets`, resolving blocks against the seeded
exercises **by name**; exercise-only, since loops/songs need user audio at cold start). The **planner**
(ADR 0072, V2 Slice 1) is now a live producer of this same `Routine`: a pure two-stage pipeline in
`Pocket/Core/Planner/` — `DueScore` ranks candidates (`goalWeight × dueness(lastPracticed) ×
(1 − mastery/5)`, ADR 0015 S5) and `SessionBuilder.buildSession` lays the ranked `PlannerCandidate`s
into `[SessionBlock]` honouring the ADR 0014 pacing (60-min cap, ≤20-min blocks, rests between
focused work, U-shape with the top-due drill last, warm-up LRU-picked / unbudgeted). Both import
Foundation only (no SwiftData/SwiftUI), so they're unit-tested and reusable by a future AI producer
(ADR 0002). The **front-half** (ADR 0073, V2 Slice 2) sits ahead of `buildSession`: a `Goal` (title,
`weight`, `skillIDs` indexing the pure `TechniqueTaxonomy` table, optional `targetSong`) is expanded
by `CandidateDeriver.deriveCandidates` into that ranked `[PlannerCandidate]` — Path A resolves a
technique skill to library exercises via the coarse `SkillFamilyMap` (`ExerciseTemplate → [SkillID]`,
no per-exercise tagging) **plus any loop the user tagged with a matching skill bucket** (ADR 0074,
V2 Slice 4 — `SkillFamilyMap.recognizedTemplate(for:)` reads a `Loop.tag` back to a coarse template,
projected onto `PlannerLoop.templates`; untagged loops stay Path-B only, no schema change), Path B
resolves a `repertoire` skill to the goal's target song (its loops + the song run), with a **soft**
down-weight when a skill's direct prerequisites are unrated (never a hard gate — ADR 0016 ↔ 0071 at
the selection level). The dueScore multiply stays in `SessionBuilder`,
so goal-priority and dueness/mastery compose once. `GoalTemplateLibrary` seeds four curated goals. The
profile's declared taste tilts this pool via a **lift-only `PracticeEmphasis`** (ADR 0113 S3): a
`deriveCandidates(…, emphasis:)` multiplier (default `.neutral`) that raises a candidate's priority
when its skill is in the declared genres' `GenreSkillMap` union or its mode matches the dream's
`emphasisedMode` — capped below a High goal's weight so it re-orders, never gates.
The impure `PracticePlanner` (`@MainActor`) projects `Exercise`/`Loop`/`Song` into candidates
(`planQuickSession`/`planGoalSession(…, profile:)` — the latter builds the emphasis from the profile)
and materialises the blocks into a persisted `Routine`
(exercises by `uid`, loops by `uid`, songs by a deterministic `PlannerID` since `Song` has no stored
`uid`). The **UI** (ADR 0015/0073, V2 Slice 3) is `Features/Practice/PlannerView` — a duration
selector (`SessionLength`), a list of `Goal`s, and **Generate** → a provisional `Routine` reviewed in
`RoutineDetailView` before Start (no active goals ⇒ the Quick-session fallback). That review carries an
**Estimated length** readout + soft over/under-budget hint vs. the chosen length (R3, `RoutineDetailView+Length`):
pure `SessionEstimate` turns each exercise's ramp staircase into minutes (per-plateau tempo × meter, not
a flat default), times each block's additive `RoutineItem.reps`, summed by `PracticePlanner.estimatedMinutes(forRoutine:)`
and classified by `SessionEstimate.fit` — guidance only, never a gate. `GoalEditorView`
(template picker → name → priority → skill-trim → optional target song → met/delete), with the pure
`GoalPriority` mapping Low/Normal/High ↔ the stored `weight`. Its **Add skills** button (R2) opens
`SkillPickerSheet`, a `.searchable` family-grouped picker over the whole catalog backed by the pure
`SkillCatalog` (family-by-prefix grouping + name search) — so a goal isn't limited to its template's
seeded skills, with no free-text (search only narrows the fixed `TechniqueTaxonomy`). `Exercise` gained self-rated
**`mastery: Int?`** + **`lastPracticed: Date?`** (mirroring `Loop`/`Song`; the app never grades
playing — ADR 0070/0072), stamped on run and rated on the detail sheet. `ExerciseLibraryView` owns exercise **create**
(`NewExerciseSheet`, Practice's own path now the metronome's save UI is retired), **duplicate** and **delete**;
tapping one pushes `ExerciseRunView`. `LoopLibraryView` is read-through — loops are made
and removed on the waveform screen, not here — and lists those with a measured command
(`commandTempo != nil`, an **in-memory** filter, never a SwiftData optional `#Predicate`, which
starves the main thread and froze navigation — guarded by `PracticeRunUITests`); tapping one pushes
`LoopRunView` (Phase B, below). Both libraries carry a **sort menu + search** (ADR 0056): the pure
`PracticeLibrarySort` orders each list by the persisted key/direction (loops by Song · Name ·
Command · Mastery; exercises by Name · Command · Recently added) and filters by query, layered
in-memory over the loop `commandTempo` gate — mirroring the song library's `LibrarySectioning`
idiom, with the choice remembered per library via `@AppStorage`. The **exercise** Command key
ranks on `ExerciseSortFields.commandNotesPerMinute` (`command × notesPerBeat`), not on the bare
BPM: 80 BPM means four different things at quarters / eighths / triplets / sixteenths, so raw BPMs
aren't comparable across rhythms (the seeded *Spider Walk* at 80 @ sixteenths is 4.5× the note
speed of *Chord Changes* at 70, a difference bare BPM read as 14%). Bare BPM stays the first
tiebreaker, then name. **A comparison aid, never a difficulty score** — see `NoteRate`.

**Row affordances are one shared modifier, not four implementations.** `.pocketRowActions(…)`
(`UI/PocketRowActions.swift`) packages a row's long-press menu (item actions → Favourite → Delete),
its leading favourite swipe and its trailing delete swipe; the exercise, routine, loop and song
libraries all adopt it, and every parameter is optional so a list declines what it doesn't own
(`LoopLibraryView` passes no delete — a loop belongs to its song). Delete routes through the
`\.rowDeletion` environment seam into a screen-scoped `RowDeletionCoordinator`, installed by
`.pocketRowUndoHost()`: the row is **hidden and the delete deferred** behind a 4-second
`UndoToastView`, committing when the timer expires, a second delete arrives, the screen disappears or
the app backgrounds. That is the opposite of the waveform's delete-then-restore-from-snapshot (ADR
0019) and deliberately so — restoring an `Exercise` or `Song` would have to rebuild routine-block
links, song links, journal entries and takes that the real delete nullifies or cascades away, whereas
deferring destroys nothing. The coordinator is **screen-owned** (`@State`, passed into
`.pocketRowUndoHost(_:)`): a modifier applied inside `body` publishes to that view's descendants
only, so the screen needs a direct handle to project its `present…` lists, which filter pending rows
out of the list, the empty state and the filter menus; the environment seam is the rows' route in.
The trailing swipe's Delete is a plain `danger`-tinted button rather than `role: .destructive` —
that role animates the row away on tap regardless of the data, which under a deferred delete defeats
Undo. `RowUndoUITests` guards both (delete → Undo → row back, no navigation).
Duplication is pure model code (`Core/Models/UnitDuplication.swift`): `CopyNaming` for the
"X copy 2" rule, `Exercise.duplicated(named:)` and `Routine.duplicated(named:)` +
`RoutineItem.copying(_:order:)`, all carrying shape and dropping history/provenance (a fork of a
free-taste preset loses `presetSlug`, so it can't inherit the ADR 0112 run allowance).

`ExerciseRunView` **owns its own `StandaloneMetronomeEngine`**
(independent of the
metronome screen's): it edits working / command (each **typable** via `EditableTempoRow`, not
just the −/+ steppers) plus the warm-up / reach / back-up step counts (in the collapsible
`RoutineStepsControls`) while stopped, shows the
routine staircase (the shared `RoutineStairs`), and on **Start** commits the edits and hands the engine the
`Exercise`-shaped `CommandRamp` via `engine.run(ramp:)`, then shows a live BPM / beat / session
readout. While a run plays, `RoutineStairs` **lights the live plateau** — fed by the engine's
`currentRampPlateau` (the pure `CommandRamp.currentPlateauIndex(…)` over the accrued elapsed) —
instead of the old permanent dwell highlight. When a standalone run **finishes naturally** (the ramp's
own `onRampFinished`, never a manual stop), it presents the **same `RoutineBlockDoneView`** a routine
block finishes on (`upNext: nil` — ADR 0079 §2, reusing the integrated surface rather than a bespoke
one): completion beat + optional mastery + note + an editable **Move command to {value}** promote toggle
(defaults to `min(ceiling, reach)`, ±/typed for a custom command) that, on Finish, moves command to the
chosen value and **persists immediately** (no later Start to carry the write — ADR 0079 §3); no toggle
when the ceiling-aware `PromoteOffer.canPromote` is false. The old pre-run promote button is gone (§4). Its teal `practice` accent (the brand hero, ADR 0081) marks it as a distinct space from the metronome's plum.
The `Exercise` model now stores the `CommandRamp` recipe **natively** (ADR 0046 §5): `rampStepBPM`
/ `rampIntervalCount` / `rampIntervalUnit` plus `dwellIntervals` (the command-plateau hold, **now
user-tunable** via a Dwell row in the Steps panel — ADR 0078, previously hardcoded on save),
`includeBackoff`, and the
`rampReachSteps` / `rampBackoffSteps` counts (additive `Int` fields, declaration-defaulted to `0`),
instead of borrowing the free-play automator fields the ADR 0045 shortcut reused. The `automator* → ramp*`
rename is a **lightweight, data-preserving** migration via `@Attribute(originalName:)` (no
drop+add), and the now-meaningless `automatorEnabled` / `automatorCeiling` columns are dropped;
all new columns carry declaration defaults so the store opens without a 134110 wipe. Six
**curated in-house starter exercises** (`PracticePresets`) are seeded **once** on first launch
(from the app root's `.task`) so Practice is never empty; seeding is gated by a versioned
`UserDefaults` flag rather than an empty-store check, so deleted presets stay deleted, and each is
built through the same `Exercise.commandAnchored` factory as the create flows (no special "preset"
status).

**Loop training runs (Phase B, ADR 0046).** A measured loop trains the **same** warm-up → dwell →
reach → back-off `CommandRamp` as an exercise, but against its time-stretched **audio** rather than
a click — so its tempos are **percent-of-original** (`×`), not absolute BPM. `CommandRamp` and
`TempoStretch` are **reused, not forked**: `LoopCommandRamp` maps a loop's `×` working/command/reach
to integer percent (`0.85×` → `85`) and builds a `CommandRamp` with `unit: .seconds` (a loop has no
metronome bars), and the `×` reach derives from `TempoStretch.targetSpeed(forCommand:)` — the
unit-generic `target(forCommand:…)` with `×`-unit clamps (`+0.02…+0.10×`). `LoopRunView` mirrors
`ExerciseRunView` (working/command as %, derived reach, the same `RoutineStairs` /
`RoutineStepsControls`), and — like the exercise run (ADR 0082, mirroring ADR 0079) — a **standalone
loop run that finishes naturally** now lands on the same `RoutineBlockDoneView` (completion beat +
optional mastery + note + an editable **Move command to {value}** promote toggle, `PromoteOffer` at a
200%-of-original ceiling; since a loop's command is a percent of original, every loop tempo reads with a
**`%`** and never "BPM" — the nudge reads **"90%"** and the shared `RoutineStairs` signpost, once
hardcoded to `"{n} BPM"`, now reads **"90%"** for a loop — via a single value-only `TempoUnit`
(`.bpm`/`.percent`) passed into both `RoutineBlockDoneView` and `RoutineStairs`), committing all three
through the loop's single `persist()`; the old in-setup
loop promote button is gone. A loop's trainer is reachable from Practice → Loops **and** via a
**Practice now** button in the loop edit sheet (shown once a command tempo is set — the same gate that
surfaces a loop into Practice → Loops), which the waveform launches full-screen (`practiceLoop`, staged
through `pendingPracticeLoop` so the run cover presents only after the sheet dismisses) and returns you
to the waveform on exit. It **owns a `LoopRunModel`** which in turn owns a private
`PracticeAudioEngine`: it resolves the song file (the shared `SecurityScopedAccess`, extracted from
`WaveformPracticeModel`), loops the region (`setLoop`), and polls the engine's **`loopIteration`**
each tick → `ramp.bpm(elapsedBars: reps)` → `setRate(percent/100)`, stopping at `ramp.isFinished`.
The ramp advances by **loop repetitions, not seconds** — one pass through the region is one step
(reps-per-step is user-set in the run setup, default 1; the command dwell holds several — the dwell
count is itself user-tunable via the new additive `rampDwellIntervals` field, ADR 0078). The ramp
reuses `CommandRamp`'s `.bars` interval mechanism with "bars" reinterpreted as loop passes, and
`loopIteration` is rate-independent so a plateau holds a fixed number of reps regardless of the
tempo it plays at (and freezes naturally on pause). The tempos ride existing fields —
`speed` (working) and `commandTempo` (command), reach derived — while the **ramp shape** persists in
four dedicated, declaration-defaulted `Int` fields added in the ADR 0057 follow-up
(`rampWarmupSteps` / `rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep`), kept **separate**
from the ADR-0013 automator (`automatorStepCount`/`automatorLoopsPerStep`, the waveform "steps to
target" ramp) since the two ramp systems carry different semantics. All are additive with
declaration defaults, so the loop keeps full ADR 0011/0012 migration discipline. Stage 4's waveform for real files is
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
speed→engine path; grabbing the slider disables the loop's ramp. Arming a loop is
**command-anchored** (`Loop.armingSpeed` = `commandTempo`, else 100%, ADR 0089): it arms at the
tempo you own the loop at, never the previous loop's rate, so a no-command loop resets to full tempo
(the tempo-bleed fix) — superseding ADR 0040's arm-at-last-practised. A single `didSet` on
`activeLoopID` still persists the *outgoing* loop's `speed` into `Loop.lastPracticedSpeed` on any
leave/switch/exit (the leave record, no longer read to arm). The **same `didSet`** carries the song's
own resume tempo
(`Song.lastPracticedSpeed`, ADR 0044): it holds the invariant "no loop armed ⇒ `speed` is the
song's tempo" — banking the song speed when the first loop arms, restoring it when the last
disarms — so the model opens the full song at its last-practiced tempo without a loop's speed
leaking in. This refines ADR 0029: the session opens clean (no loop armed), but the song and
its loops carry speed memory. A later slice adds a
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

## Toolkit hub (Features/Toolkit)

The **Toolkit** (`Features/Toolkit/`, ADR 0096) is a top-level **reference** destination — *explore /
keep* — distinct from the exercise editors' *author* job. It is the fourth home card (a `NavigationLink`
onto the home stack, like Practice/Library) in the new indigo/violet `PocketColor.toolkit` accent (baked
per-appearance `Indigo`/`IndigoCardWash`/`IndigoCircleWash` colour sets, ADR 0062/0081), and the free,
deterministic floor the paid AI layer (ADR 0092) will later sit on. `ToolkitView` is a landing list of
sections; **Slice 1** carries the two zero-dependency tenants and is **audio-free by construction** (ADR
0096 D4/D5 — *Hear* has no pitched-tone source yet, ADR 0001):

- **My Chords** (`MyChordsView`) promotes the `SavedChord` library (ADR 0095) from its in-context Add
  menu to a full grid of saved voicings (newest-first `@Query`). A cell pushes `MyChordDetailView` — a
  large `ChordDiagramView` plus **Rename** (`SavedChord.rename(to:)` keeps the queryable `name` column
  and the encoded voicing's own name in step) and **Delete** (pops back). **+** presents the existing
  `CustomChordSheet` in "Save" mode — a new optional `confirmTitle` (default `"Insert"`) reads `"Save"`
  here so confirming *keeps* the shape rather than *inserting* it into a progression; the dedupe reuses
  the pure `SavedChord.isAlreadySaved`. The chord picker's **My chords** group reuses the same library
  inline inside an exercise (ADR 0103); both surfaces read the same `@Query`, so this screen *manages*
  (rename/delete) while the picker *reuses* (tap-to-insert). The old inline `SavedChordsSheet` manager was
  removed with the picker redesign.
- **Glossary** (`GlossaryView`) is a searchable, area-grouped static terms sheet over the pure
  `GlossaryTerm` catalog (`GlossaryTerm.all`). Filtering is the pure `matches(_:)`/`matching(_:)` (case-
  and diacritic-insensitive over term **and** definition), unit-tested. Definitions state objective
  identity only — a glossary informs, never grades (ADR 0070).

**Tuner** (`TunerView` + `TunerGaugeView`, ADR 0115) is a free, live-mic tuner — the Toolkit's first
audio-*input* tenant (Slice 1's two were audio-free). `TunerEngine` (`Core/Audio`) is the app's **first
live `installTap`** on the mic (the recording path writes to a file and never taps live PCM): it
accumulates a rolling window, runs the pure autocorrelation `PitchDetector` (McLeod NSDF, octave-safe)
off the audio thread, maps the frequency to the nearest note (`TunerReading`, spelled via the shared
`GuitarScale.noteName`) against a curated `Instrument`/`Tuning` catalog (guitar + bass), and publishes a
lightly-smoothed reading (`TunerSmoother` — eases cents, snaps on note change, rides out dropouts). The
view shows the note, an arc-needle cents gauge, the nearest standard-tuning string, and a `ToneEngine`
**Hear** reference tone; it starts on appear (after mic permission) and stops on disappear / when the
scene leaves `.active`, so the mic is never held open. It reports pitch, never grades (ADR 0070).
Instrument / tuning / chromatic-mode / reference-pitch settings land in Slice 4 (Tune Settings sheet).

The four home strips (Song library / Metronome / Practice / Toolkit) share one presentational
`HomeNavCard` component (icon + title + subtitle + chevron on a washed card); each home card just
supplies its copy and its `PocketColor` hue trio, keeping the owning link/button in `HomeView`.

## Persistence

- **SwiftData `@Model` domain** (`Core/Models/`): `Song` is the aggregate root, with
  cascade relationships to its `Loop`s and `Marker`s. The practice screen binds to a
  persisted `Song` via the `ModelContext`; loops/markers persist across launches. ADR 0011.
  **`SavedChord`** (ADR 0095) is a standalone, relationship-free library entry — a user-saved custom
  voicing stored as an encoded `Data` blob (`voicingData`, decoded via `voicing`) plus a primitive
  `name` column for sorting, deliberately not a stored `ChordVoicing`/enum attribute (the payload-as-blob
  pattern that dodges the migration footgun). Adding it is an additive schema change (new table; nothing
  existing migrates). Surfaced as the **My chords** group in the chord picker's Insert grid (ADR 0103,
  tap-to-insert); saved from the placer's **Save to My chords**; and **managed** on the Toolkit hub's
  `MyChordsView` (grid + rename/delete, ADR 0096 — see above).
- **`Profile`** (ADR 0113 Slice 1) is the local, account-free artist profile — a **singleton** `@Model`
  (`uid` + optional `artistName` + `createdAt`), added as an additive new table (nothing existing
  migrates). It is created **lazily**: `Profile.setArtistName` is a fetch-or-create that inserts a row
  only once a non-empty name is set (and clears it back to `nil` when blanked), so an untouched install
  carries no row and the greeting reads name-free. Views read it by `@Query` `.first?.artistName` and
  feed that into the pure `HomeFeed.TimeOfDay.greeting(name:)`; it's edited in Settings → You and offered
  once from Home — a ceremonial full-screen cover (`ArtistNamePromptSheet`) — after the player has
  **completed an exercise or captured a loop** (a Home-appearance check gated by the
  `artistNamePromptSeen` UserDefaults flag). Nothing leaves the device; it is deliberately not treated as PII.
  **Slice 4 (ADR 0113)** adds an **offered name** to that prompt: the signature field starts **blank**
  (providing a name is an explicit act — type, or tap **Spin a name**), and the pure
  `ArtistNameGenerator` (`seed → name` over curated Red Moon word pools + a `blocklist`, safe by
  construction) supplies one. The *first* spin is seeded from the intake answers
  (`ArtistNameGenerator.seed(experience:genres:dream:)`, a stable FNV-1a hash so it feels *fated*;
  skipped intake ⇒ random device seed); each later spin draws a fresh random seed and typing overrides
  — deterministic-then-random, fully unit-tested, no network.
  **Slice 2 (ADR 0113)** adds four **curation** fields as additive optionals — `experienceRaw`,
  `genresRaw: [String]`, `dreamRaw`, `minutesPerDayRaw` — each **backed by a primitive** with a computed
  enum accessor (`experience`/`genres`/`dream`/`minutesPerDay` over the pure `ProfileCuration` enums
  `ArtistExperience`/`MusicGenre`/`MusicalDream`/`PracticeMinutes`), never a stored enum (the
  enum-attribute migration rule). They're written by `Profile.setCuration` (a fetch-or-create that
  *does* legitimately create a still-nameless row — the first-launch intake runs before a name is
  earned). Collected by the **first-launch intake** (`ArtistIntakeView`, a four-card skippable
  full-screen flow gated once by `artistIntakeSeen`; Home shows the intake *or* the naming prompt,
  never both, via `maybeOfferProfileMoment`) and editable any time in **Settings → Your sound**
  (`ProfileCurationSection`). Two consumers exist today, both pure and both *defaults only*:
  `ArtistExperience.defaultCommandTempo` seeds a new exercise's command tempo (`ExerciseLibraryView`
  → `NewExerciseSheet.initialCommand`), and `PracticeMinutes.preferredSessionLength` seeds the
  planner's initial `SessionLength` (`PlannerView`). A third consumer lands with **Slice 3** (ADR 0113,
  the planner emphasis mix): `genres` + `dream` build a pure `PracticeEmphasis` that lifts matching
  candidates' priority in `CandidateDeriver` — genres via the curated `GenreSkillMap`
  (`MusicGenre → [SkillID]`), the dream via a single `MusicalDream.emphasisedMode` tilt. Lift-only and
  capped (`≤ 1.6 < GoalPriority.high.weight`), so taste re-orders but never gates and a stated High
  goal always wins; an absent/skipped profile is `.neutral` (no change).
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
- **Song time signature** (`Song.beatsPerBar`/`noteValue`, ADR 0051): declaration-default
  4/4 additive fields (CoreData 134110 rule). `beatGrid` passes `beatsPerBar` to
  `BeatGrid.beats`, so downbeats are real bar lines; set in the BPM sheet. `Song.showsGridlines`
  (default on) is a per-song view flag gating the grid *draw* only (snap candidates still read
  `beats`).
- `SongRef` is the song's identity (stored on `Song`), so practice data survives the
  underlying file being moved or re-granted.
- **`MetronomeExercise`** (ADR 0043 / 0045): a standalone, **audio-free** `@Model` — a savable
  metronome preset that *is* a practice exercise (name, absolute BPM tempos, time signature,
  `accentBeats`, subdivision, the automator recipe, `tags`, `notes`).
  Deliberately **not** related to `Song`/`Loop` (a `Loop` carries audio assumptions an
  exercise has none of). Joins the same store as an additive migration (registered in the
  app's `modelContainer`), following the 0011/0012/0036 discipline: a `uid: UUID`, declaration
  defaults on every non-optional attribute (CoreData 134110), and the `Subdivision` /
  `MetronomeIntervalUnit` enums stored through `String` backing fields with computed views
  (the enum-attribute migration rule). Three tempos (ADR 0045): the warm-up **working** floor
  (the existing `currentTempo`, aliased `workingTempo`), the measured **`commandTempo: Int?`**
  (`nil` until promoted — an additive optional like `Loop.commandTempo`, falling back to
  working), and the command-derived **`targetTempo`** reach. "Command tempo" now means the
  same thing — fastest clean tempo owned — on both exercises (absolute BPM) and `Loop` (song
  fraction).
- CloudKit-backed sync (Phase 4) is a configuration step on the same `@Model` graph, not
  a re-model.
- **User preferences** (`App/AppSettings.swift`, ADR 0050): `UserDefaults`-backed toggles, not
  SwiftData. `AppSettings` is a thin wrapper so both SwiftUI (`@AppStorage(AppSettings.Key.…)`,
  as in `SettingsView`) and plain engine/helper code (`AppSettings.countInEnabled` in the
  metronome, `AppSettings.hapticsEnabled` in `haptic(_:)`) read the same key without a shared
  object. The pure `resolvedBool(storedValue:default:)` keeps a never-set key at its **default
  (on)** rather than `UserDefaults.bool`'s `false` — unit-tested. UserDefaults is already in the
  privacy manifest (CA92.1), so no new required-reason API and no migration.

## Backend

- Single proxy endpoint for AI session suggestions; key held server-side.
- Base URL by build config (Debug → dev, Release → prod). See `docs/decisions/0002`.

## Testing

- **Unit (PocketTests):** pure logic — tempo math, slider mapping, automator
  stepping, identity, planner weighting + candidate selection (ADR 0015). Must be covered.
- **UI (PocketUITests):** XCUITest for key flows.
- Audio / MusicKit behaviour is validated on device/simulator, not unit-tested.