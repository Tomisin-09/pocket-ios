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
| `Pocket/Features/Home/` | Home hub — the app root: greeting, a primary **Start today's session** CTA (→ planner, goal-adaptive), the resume card, a blue **Song library** nav strip, metronome + Practice strips, a fourth **Toolkit** strip (→ the chords/theory reference hub, indigo/violet accent, ADR 0096), and a **Recent routines** rail (last 3 routines *practised*, tap → opens that routine's `RoutineDetailView` (blocks + Edit + Start), not a straight replay — supersedes ADR 0066's one-tap-replay-from-home; the routine library ▶ still replays directly; reads `Routine.lastPracticed`); Settings top-left, add-song **+** top-right (`HomeView` + `HomeCards`, ADR 0044 / planner review R1) |
| `Pocket/Features/Library/` | Song library, file import, song metadata editing. Import is **multi-select** (`SongImportModel` — decodes each file off-main via `Task.detached`, `SongImporter.prepare`/`persist` split, progress overlay + partial-failure summary; good files import even when others fail) |
| `Pocket/Features/Waveform/` | Timeline, markers, loop creation (the practice screen) |
| `Pocket/Features/Metronome/` | Standalone metronome screen (ADR 0043; automator phase-continuous stepping + explicit run/count-in/infinite, ADRs 0047/0048) |
| `Pocket/Features/Practice/` | Top-level Practice hub → two unit libraries (`ExerciseLibraryView`, `LoopLibraryView`) plus a **Routines** library (`RoutineLibraryView` — ▶ plays, row-tap edits, three curated in-house starter routines seeded once via `RoutinePresets` (after the exercise presets, blocks resolved by name; exercise-only at cold start) — → `RoutineDetailView` editor: name, add exercise/loop/song blocks via `AddRoutineUnitSheet` (two-level picker: Exercises→template, Loops→song, plus a flat **Songs** bucket), insert rests, drag-reorder, and **tap a unit block → a `BlockRepsEditor` sheet** to set its **Repeat ×N** (1–9, ADR 0076; a `×N` badge shows in both modes); and the **player** `RoutinePlayerView` (thin `NavigationStack` host over the `RoutineSessionPlayer` conductor + pure `RoutineSessionCursor`) that **embeds the real `ExerciseRunView`/`LoopRunView`/`SongPlayAlongView` per block** — injected with a `RoutineRunContext` (progress · Skip · natural-completion hook · exit) so every training aid is kept, not re-implemented — though an **exercise** block in a routine no longer mirrors the library editor (ADR 0077, Slice 2): `ExerciseRunView` gates on `routineContext != nil` to drop Save, journal and the meter picker (the pre-run promote button is gone everywhere — promotion is now a post-run offer, ADR 0079), keeping only the collapsible **Practice Settings** panel (tempos + step granularity, incl. the ADR-0078 dwell), the ramp, count-in, live BPM and staircase — edits committed on Start — with a fixed rest countdown between blocks, judgement-free; a finished unit lands on a **Done screen** (`RoutineBlockDoneView` — completion beat + optional mastery tap + optional inline note + an optional **Move command to {value}** promote toggle for a summited exercise (opt-in, exercises-only, absent under auto-advance; the target defaults to the reach but is **editable** via a ±/typed stepper for a custom command — ADR 0079 §7) + an **Up next** card previewing the next unit (rests skipped), committed together on Continue/Finish; a top-left chevron exits the routine from here; collapses the old reflection sheet) with **manual advance the default** (the `routineAutoAdvance` setting, default off, restores auto-advance; a Skip always bypasses the gate — ADR 0071 R4); a **multi-rep block** (ADR 0076) runs back-to-back with a **Rep N of M** counter on the progress strip, the Done screen only after the last rep, while **Skip** jumps past remaining reps to the next block; tapping **Start** runs **straight into block one** (previews happen up front, so the first block no longer waits — ADR 0071 R4b); each block is inspectable before starting via a read-only **block preview** (`RoutineBlockPreview` — pushed on tap: `ExerciseBlockPreview` shows content + an editable collapsible `PracticeSettingsPanel` (tempos + steps + dwell, written straight to the model via bindings — ADR 0077 Slice 2 / 0078) + staircase + a `CommandTempoPreviewPlayer` metronome audition — or, for a strumming / Chords & Strum drill, a `StrumPatternPreviewPlayer` **Hear the strum** rhythm audition (the metronome engine's pattern mode, `StandaloneMetronomeEngine+Strum`, plays the pattern's down/up/accent/mute slots as clicks; rhythm not tone — ADR 0071 R5), `LoopBlockPreview` shows source + speed + staircase + a `LoopAudioPreviewPlayer` audition of the loop's real audio); a **song block** runs the audio-only `SongPlayAlongView` (+ `SongPlayAlongModel`, own `PracticeAudioEngine`): fixed play-along speed (no ramp) · play/pause · −10s/+10s, looping-until-skip by default or play-through-once-and-advance per the `routineSongLoop` setting; ADR 0066 slices 2–3 / ADR 0071); template-first exercise **creation** (`ExerciseTemplatePicker` → `NewExerciseSheet` configure step, ADR 0068 — picker order + retired Fingerstyle/Rhythm + Coming-Soon Ear Training/Theory + Chords & Strum rename, ADR 0087); per-unit training-run screens (`ExerciseRunView` / `LoopRunView` + `LoopRunModel`) — a standalone exercise **or loop** run that **finishes naturally** presents the **same `RoutineBlockDoneView`** a routine block finishes on (`upNext: nil`, ADR 0079 §2 revised; loops brought to parity by ADR 0082, at a 200%-of-original ceiling) — completion beat + optional mastery + note + an editable **Move command to {value}** promote toggle (defaults to the reach, ±/typed for a custom command) that persists immediately on Finish (or no toggle when there's nothing above command); pure `PromoteOffer` math (ceiling-aware `canPromote`); the old pre-run promote button is gone for both, an exercise **detail/reference sheet** (`ExerciseDetailSheet` — a **purely read-only reference** sheet (ADR 0077, reordered description-first, **tempo editing removed** — command/reach are tuned on the run screen / in-routine block surface instead — and, Slice 3, **content/shape editing removed** too): editable **description** + self-rated **mastery** + read-only meter (**Feel**) + a compact read-only **template** chip at the bottom (ADR 0068), committing only notes + mastery — the redundant routine-staircase preview was dropped (device feedback, it lives on the run screen); ⓘ from the run screen); the exercise **shape editor** (`ExerciseShapeSheet` — ADR 0077 Slice 3: the per-template content editor relocated off ⓘ onto a compact **Edit shape** control in the board preview's header on the library run screen (`routineContext == nil` only — in a routine an exercise is tempo-only), hosting `StrumPatternEditor` for strumming, `FretboardRunEditor` (declare a movable finger-pattern run + live preview) for the warm-up families, `ScaleRunEditor` (pick scale + root + position + octaves; generated run + live preview) for Scales, `ArpeggioRunEditor` (pick quality + root + position + octaves) for Arpeggios, `ChordProgressionEditor` (build a progression of chord voicings + per-chord beat holds) for Chords, `StrumPatternEditor` + `ChordProgressionEditor` stacked for Chords & Strum (a `StrumChordSheet` pairing the two, no reset coupling between them), and `FretboardDrillEditor` (tap-to-place notes) as the custom escape hatch — ADR 0065; the one-shot **Watch** preview (`FretboardPlayOnceButton`) now hides when "Animate exercises" is on and shows when animation is off / Reduce Motion (ADR 0077, reversing 0065), and the dead "Sound soon" scaffold button was dropped while its `ExerciseAudioEngine` seam is kept); the content-template renderers (`StrumLane` + live `StrummingLaneView`; `FretboardGrid` + live `FretboardView` + self-driving `FretboardDrillPreview`, ADR 0065 build 2 — with the ADR-0083 S5 **following viewport**: a climb wider than the comfortable board (~8 frets) shows, while walking, a hand-width window (pure `FretboardDrill.displayWindow(activeIndex:)`) that follows the sounding note by only scrolling when it reaches the edge (hysteresis; the note lands near the trailing edge to prioritise the runway ahead, so it reframes only ~twice over a whole climb) and hides off-window notes, never reframing while the note is visible; a gentler climb or short run keeps the static full-neck reference diagram; plus ADR-0083 S2b **pass focus** — while a multi-pass climb walks, off-pass notes fade to a ghost so the active position reads clearly (driven by a transient parallel `FretboardDrill.noteGroups` filled at generation, excluded from `Codable`; single-pass runs and the static board are unaffected); `ChordDiagramView` + live `ChordChangeView`, ADR 0065; `StrumChordsView`, the chord surface stacked over the strum lane on one shared beat origin); the library grouped into **template sections** (`PracticeLibrarySort.exerciseSections`, ADR 0068); a collapsible **Practice Settings** panel (`PracticeSettingsPanel`) grouping the run-setup tempos + Steps + curated starter exercises seeded once on first launch in eight one-time batches — six v1 technique drills + a v2 strumming preset + a v3 fretboard warm-up + a v4 scale run + a v5 arpeggio + a v6 chord progression + a v7 accent/mute strumming preset + a v8 strum & chords groove (`PracticePresets`, ADR 0046/0065); and the **V2 planner UI** (Slice 3, ADR 0015/0072/0073): `PlannerView` (the "Today's session" entry — duration selector, goals list, **Generate** → provisional `Routine` review with an inline editable **Name** field + an **Estimated length** readout and soft over/under-budget hint vs. the chosen length (R3, `RoutineDetailView+Length`) → shipped player; no-goals falls back to a Quick session) and `GoalEditorView` (template picker → name → priority → skill-trim + an **Add skills** full-catalog search (`SkillPickerSheet` — a `.searchable`, family-grouped picker over the whole `TechniqueTaxonomy`, R2) → optional target song → met/delete, writing `Goal`s) |
| `Pocket/Core/Planner/` | **V2 practice planner** (ADR 0072/0073/0074, Slices 1–4) — pure ranking + layout, Foundation-only. **Back-half (S1):** `PlannerCandidate`/`SessionBlock` (value projections), `DueScore` (the `goalWeight × dueness × (1−mastery/5)` selection ranking), `SessionBuilder.buildSession` (ranked candidates → timed U-shape session honouring ADR 0014 pacing) + warm-up LRU pick. **Front-half (S2):** `TechniqueTaxonomy` (pure skill table — id/difficulty/mode/prereqs) + `SkillFamilyMap` (`ExerciseTemplate → [SkillID]`, coarse) + `CandidateDeriver.deriveCandidates` (active `Goal`s → ranked candidates: Path A technique→exercise via the family map, Path B repertoire→target-song loops+run, soft direct-prereq down-weight) + `GoalTemplateLibrary` (4 curated goal templates) + `PlannerLibrary`/`PlannerGoal` projections + `PlannerID` (deterministic song id). **Session length (R3):** `SessionEstimate` — pure ramp-staircase → minutes (per-plateau tempo × meter), a `reps` multiplier, and a soft-budget `fit` (under/onTarget/over vs. the chosen length); `PracticePlanner.estimatedMinutes(forRoutine:)` sums it across a routine's blocks. `RoutineItem`'s additive `reps: Int = 1` is now **authored** (editor stepper) and **looped** by the player (ADR 0076): the pure `RoutineSessionCursor` steps reps within a block before advancing, `RoutineStage` carries `reps`. **UI (S3):** `GoalPriority` (pure Low/Normal/High ↔ `weight` bridge). **Skill catalog (R2):** `SkillCatalog` + `SkillFamily` — pure display grouping (family by `SkillID` prefix) + case/diacritic-insensitive name search over `TechniqueTaxonomy`, backing the goal editor's full-catalog skill picker. **Loop skill-tags (S4, ADR 0074):** `SkillFamilyMap.recognizedTemplate(for:)`/`taggableTemplates`/`suggestedLoopTags` recognise a `Loop.tag` as a coarse `ExerciseTemplate` bucket, projected onto `PlannerLoop.templates` so Path A also surfaces tagged loops (untagged = Path B only; reuses ADR 0034 tags, no schema change). Plus the impure `PracticePlanner` (`@MainActor`) that projects models into candidates, composes `planQuickSession`/`planGoalSession`, and materialises `[SessionBlock]` into a persisted `Routine` (exercises/loops/songs). The planner UI lives in `Features/Practice/` (`PlannerView`, `GoalEditorView`) |
| `Pocket/Features/Toolkit/` | **Toolkit** — the chords/theory/resources reference hub (ADR 0096, fourth home card, indigo/violet `PocketColor.toolkit`). Relies on an ambient `NavigationStack` (pushed from Home). `ToolkitView` is a landing list of sections; **Slice 1** carries two: **`MyChordsView`** — the `SavedChord` library promoted to a full grid (newest-first), each cell → `MyChordDetailView` (large `ChordDiagramView` + a **Hear** button sounding the voicing as a block chord through the shared `ToneEngine` (ADR 0097 Slice 1) + **Rename** (keeps `SavedChord.name` and the encoded voicing name in step) + **Delete**), **+** opens the existing `CustomChordSheet` in "Save" mode (`confirmTitle: "Save"` — building here *keeps* rather than *inserts*; the in-context `SavedChordsSheet` menu stays for inline reuse, same `@Query`) — and **`GlossaryView`** — a searchable, area-grouped static terms sheet over `GlossaryTerm.all` (pure `matches(_:)`/`matching(_:)` search). *Hear* on chords lands in Slice 1 (ADR 0097); identifier / scales / ear-training are later slices |
| `Pocket/Features/Settings/` | Settings screen (pushed from the Home gear) — Appearance override (System/Light/Dark, ADR 0063) + Haptics + Count-in + **Routines** (auto-start blocks, reflect-after-each-block; ADR 0071) + a **Transport** section (loop-control side + **Show minimap**, default on, hiding the practice screen's full-song strip — planner review P1c + **Show marker labels**, default on, floating a marker's name over the timeline as the playhead nears it — P2) toggles (`SettingsView`, ADR 0050); About footer shows the Red Moon brand mark (ADR 0061), background now transparent (ADR 0063) |
| `Pocket/Resources/Assets.xcassets/` | Asset catalog (ADR 0061): `AppIcon` (crescent + stars on dark), `RedMoonLogo` (moon + wordmark, light/dark, transparent background since ADR 0063), `RedMoonWordmark` (compact nav-bar crop) |
| `Pocket/Features/Repertoire/` | Song cards, song info |
| `Pocket/Core/Audio/` | AVFoundation engine, tempo math (pure logic). **Hear — pitched-tone preview** (`ToneEngine`, ADR 0097): a shared, sequence-capable tone service (its own tiny `AVAudioEngine` + single `AVAudioUnitSampler`, separate from the file-playback pipeline, so ADR 0001 is untouched) — `sound(_:)` plays MIDI notes together (block chord), `sequence(_:)` spaces them in time (scale/arpeggio/interval), reading MIDI the models already expose (`ChordVoicing.midiNotes`, `ScaleRun.sequence`→`CAGEDShape.midi`); v1 renders iOS's zero-asset **built-in sampler tone** (no accessible GM bank — a redistributable CC0 `HearGuitar.sf2` would swap in a nylon program over the same path, deferred D4.3); a re-tap cancels any in-flight preview. **Slice 1 wires block-chord Hear on the My Chords detail**; scale/arpeggio/interval preview are follow-up slices. **Practice-take recording** (ADR 0069, mic-only audio journal): `AudioPlumbing.configureRecordSession` — a `.playAndRecord` config applied only while a take is armed (`.defaultToSpeaker` + `.allowBluetoothA2DP` and deliberately **not** `.allowBluetooth`, so output stays A2DP-clean and input falls to the built-in mic — avoids the Bluetooth HFP-collapse); pure **`RecordingRoute`** classifier (private-listening → clean take vs speaker/unknown → bleed nudge, ADR 0069 §2, unit-tested); **`MicPermission`** (iOS 17+ `AVAudioApplication` flow); **`TakeRecorder`** (mic-only → AAC via `AVAudioRecorder`, not tapping the playback engine — engines unchanged, §3); **`RecordingController`** (pre-start arm orchestration: permission → record session → capture → persist → restore; begins the take *before* playback to avoid a mid-play glitch); **`RecordingPlayer`** (one-at-a-time take relisten via `AVAudioPlayer`); **`RecordingStore`** (app-container `Recordings/` dir + delete/size + pure orphan-sweep retention). New `NSMicrophoneUsageDescription` in Info.plist (mic records the user's own playing only; never the app's loop/song output — ADR 0001/0064). Slices 0–3 done on the **loop trainer**: record is a pre-start arm toggle beside Start (loops also gained the count-in); relisten via a **Takes** sheet reached from the one-row `PracticeReviewBar` (Journal + Takes count pills). Exercise/song surfaces reuse the owner-agnostic `RecordingOwner` |
| `Pocket/Core/Models/` | Song, Loop, Marker, JournalEntry, Exercise (+ closed `ExerciseTemplate` axis chosen at creation & immutable, deriving the `ExerciseKind` renderer + `StrumPattern` / `FretboardContent` (`FretboardRun` finger-pattern — movable, with ADR-0083 **position-shifting**: a per-pass neck climb (`fretShiftPerPass`/`passCount`), a per-string diagonal (`fretShiftPerString`), a `.retrace`/`.restate` come-back (`returnStyle`), and same-string pass seams articulated as `.slide` (drawn by `SlideCue`); all additive, defaults reproduce today's run | `ScaleRun`/`ArpeggioRun` generated from `GuitarScale`/`ArpeggioQuality` interval formulas via the five shared `CAGEDShape` boxes (positions + octaves) — the `GuitarScale` catalog (ADR 0085) spans pentatonics, the major scale and all seven **modes** (Dorian/Phrygian/Lydian/Mixolydian/Locrian borrow their *parent major* box via `relativeMajorSemitones`, filtered to their degrees), plus the **blues** and two **bebop** scales, whose chromatic passing tone no diatonic box holds and so is threaded one fret above its `passingToneAnchorDegree` (♭5/♯5/♮7); the *symmetric* diminished + whole-tone scales are deferred to the backlog (they aren't subsets of a major scale, so they'd need their own generator) — with a ADR-0083 **`layout` axis** (`ScaleLayout`, additive/decode-time-defaulted): `.box` (default) plus two neck-spanning rules in the pure `ScaleNeckLayout` namespace — `.extended` (the minor/major-pentatonic diagonal linking three boxes with same-string `.slide` seams + per-note box groups for focus; offered as the **two** canonical `ExtendedPentatonicShape` fingerings — slide on A&G or on D&B, each a clean whole-step) and `.threePerString` (the diatonic three-tones-per-string drill, offered by every 7-tone diatonic scale incl. the modes), gated per scale via `GuitarScale.supportedLayouts`; the editor labels each box by its **root anchor** ("root on low E · fret 5", `CAGEDShape.rootAnchor`, ADR 0091) with the CAGED letter demoted to a caption, and a new drill opens on the **flagship** root-position 6th-string box (badged "Most common" — `CAGEDShape.flagshipPosition`, the box whose run begins on the tonic on the low E; position 5 for the minor pentatonic, not 1), in scales and arpeggios alike | `ChordProgression` of `ChordVoicing`s rendered as chord diagrams — triads fold in as three-note voicings; a pure **`ChordGrip`** (ADR 0084) is a *movable-shape recipe* — relative fret offsets + a root string (E/A) + a quality — that generates a `ChordVoicing` when slid to a root note (auto-named from its own content), never a stored table (M1); the curated Tier 1–2 grips cover E/A-shape triads + 7ths + sus2/sus4/6ths and reproduce the two library barres byte-for-byte (M5); authored via **`MovableChordSheet`** (family + quality + root → live diagram, mixed inline with the open-shape library) — no slide animation, since a progression never physically slides between chords (M6 resolves to a static shape-family + fret label for the chord case); and the **`CustomChordSheet`** custom placer (M4, slice 3) — the Tier-3 escape hatch for anything the curated grips can't voice (jazz shells, extensions, altered dominants, D-root shapes): a **full-screen, tappable chord box** (an editable twin of `ChordDiagramView`) — tap a fret to place it, tap it again to clear, tap the ✕/○ marker above a string to cycle muted↔open, with a position control to slide the window up the neck; each sounded string shows its **scale degree** from the lowest note (pure `ChordVoicing.degreeLabels`/`degreeName`), a live **`ChordIdentifierPanel`** under the board suggests what the shape is called (ADR 0093 — `ChordNamer` reverse lookup, "Looks like Cmaj7" + alternate/inversion chips, tap-to-fill-name, "No common name" fallback, hidden below 3 notes; informational, never a gate or grade), the player names it, and it lands as a plain `ChordVoicing` (same output type, renderer untouched; fingers deferred while the shared diagram doesn't draw them) | custom `FretboardDrill` | `StrumChordSheet` pairing a `StrumPattern` with a `ChordProgression` for the Chords & Strum template) payloads, ADR 0068/0065; plus self-rated **`mastery: Int?`** + **`lastPracticed: Date?`** mirroring `Loop`/`Song` — the planner's *need* + *dueness* signals, self-set never graded, ADR 0072/0070), **Routine + RoutineItem** (the multi-unit *session* container — ordered typed blocks referencing an Exercise/Loop/Song or a rest, nullify-on-unit-delete, plus **`lastPracticed: Date?`** (stamped when a session starts, drives the home "recent routines" rail), with a pure `RoutineBudget` pacing layer + pure `RoutineSessionCursor` stepping; ADR 0066/0071, authored by hand and run by the auto-advancing `RoutineSessionPlayer` in the Practice space — exercise/loop/song blocks all playable), **Goal** (the V2-planner input, ADR 0073 — `title`, `weight`, `skillIDs: [String]` indexing the taxonomy, optional `targetSong` relationship, `isMet`; produces `PlannerGoal` for the pure deriver), **Recording** (a mic-only practice take, ADR 0069 — `uid`/`createdAt`/`duration` + a relative AAC `fileName`; polymorphic **cascade-owned** owner via inverse `recordings` arrays on `Loop`/`Exercise`/`Song`, `ownerKind` derived not stored; files reaped by `RecordingStore`'s orphan sweep), **SavedChord** (a user-saved custom chord, ADR 0095 — standalone/relationship-free library entry: `uid`/`name`/`createdAt` + the `ChordVoicing` as an encoded `voicingData: Data` blob decoded via `voicing`, never a stored voicing/enum attribute; additive new table; saved from the placer's **Save to My chords**, reused via a **My chords** menu section + `SavedChordsSheet` tap-to-insert/swipe-to-delete list, and **managed** on the Toolkit hub's `MyChordsView` full screen (ADR 0096) with an in-place `rename(to:)`), SongRef (`Marker` now lives in its own `Marker.swift`) |
| `Pocket/Core/Theory/` | Objective harmonic analysis, SwiftUI-free (ADR 0093). **`ChordNamer`** — reverse-lookup chord naming: a pitch-class set (+ optional bass) → ranked `[ChordCandidate]` matched against the `ChordQuality.catalog` common-practice table (triads, 6/6-9, the seven common 7ths, add9); root-position preferred over inversions (slash names like `C/E`), symmetric chords (dim7/aug) return all true roots, sharp-spelled with no key assumed (agrees with the board). Keyless (ADR 0086) and deterministic; a thin `candidates(for: ChordVoicing)` adapter is its first consumer (the chord identifier, slice 2). The shared theory core the ear-training space (ADR 0094) will also consume |
| `Pocket/Core/Services/` | MusicKit, persistence, sync, AI client |
| `Pocket/UI/` | Shared components, design tokens (`PocketColor` — light + dark appearance, ADR 0062; appearance override + vibrancy retune, ADR 0063; blue **`library`** identity + `libraryCardWash`/`libraryCircleWash` for the home Song-library strip, baked per-appearance not opacity-blended) |

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
loops are created through the **A/B span** — the single creation primitive (ADR 0041):
the transport is flanked by two big **circular identity buttons** — **Marker** on the far left,
**Loop (A/B)** on the far right (V1 feedback #1; **Click** moved to the speed bar, ADR 0027 / 0030 /
0041). The Loop button lights while a span forms and cross-fades to the active-loop colour strip. Tap **A/B** to drop A at the playhead, play along, tap
again to close an ephemeral **A↔B span** that loops with no ✓/✗ gate; drag its labelled
**A / B handles** to refine it in place, **Save as loop** to persist it, **✕** to clear.
Dragging a saved loop's **edge knob** lifts it back into A/B for a range edit (**Save
changes** writes back). **Hold-drag** the waveform is the spatial set (A pins at the
playhead, the drag sets B; ADR 0005 round 5). The transport
bar carries a **rewind · pause · forward** playback cluster (restart / prev-loop / next-loop;
cross-song deferred) plus an **active-loop colour strip** with an ✕ deactivator (ADR 0030);
a left-edge **swipe-back guard** stops a scrub from popping back to the library mid-adjust.
On **release**, a dragged A/B edge / tap-seek **snaps to a nearby marker or
saved-loop edge** within an on-screen tolerance (pure `WaveformGesture.snap`, light haptic;
the continuous scrub stays free; ADR 0021). The **minimap** snaps a released seek to a
nearby **marker or saved-loop edge** (but not beats — the full-song strip is too compressed
for the grid to land cleanly), so a tap or drag near a marker dot or loop boundary catches it. When a song has a **BPM and a downbeat anchor**, a
a **beat grid** is drawn behind the bars (bar-start downbeats brighter, density-aware on
zoom) and its beats join the snap candidates, so edges and **tap**-seeks catch the pulse too — pure,
unit-tested `BeatGrid`, grouped by the song's **time signature** (`beatsPerBar`, ADR 0051;
default 4/4). A **scrub** seek deliberately drops the beat grid and catches only the sparse
landmarks (markers + loop edges), the same set the minimap uses, so a free scrub between beats
lands where the finger lifts instead of magnetizing to the pulse (ADR 0080). A per-song **Grid** toggle on the "Loop controls" row shows/hides it, appearing
only once a grid exists. The **"Set BPM"** affordance opens a tempo
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
persisted song data is left untouched (ADR 0029). Arming a loop is now **command-anchored** (ADR 0089):
a loop arms at its measured `commandTempo`, else 100% (`Loop.armingSpeed`) — **never** the tempo of the
loop you were just on — so switching to a loop with no command tempo resets to full tempo instead of
inheriting the previous loop's reduced rate (the tempo-bleed fix). This supersedes ADR 0040's arm-at-last-
practised for both arming sites (`activate`, the ◀◀/▶▶ `jump`); `Loop.lastPracticedSpeed` is still
recorded on leave (via the `activeLoopID` `didSet`) as the leave record, just no longer read to arm. The
**song** still resumes at its own last-practiced tempo on reopen (`Song.lastPracticedSpeed`, ADR 0044) via
the same choke point, which holds the invariant "no loop armed ⇒ `speed` is the song's tempo" (bank on
arm, restore on disarm) so a loop's speed never leaks in. The session still opens clean (no loop armed),
only the tempo is remembered.
State + handlers live in an `@Observable` `WaveformPracticeModel`
(ADR 0007), now bound to a **persisted `Song`** — loops/markers are SwiftData
`@Model`s that survive relaunches (ADR 0011). The practice screen is the **one
screen that rotates to landscape** (ADR 0042): the cockpit + loops/markers list are
extracted as `PracticeCockpit` / `PracticeReference`, stacked in portrait; in landscape
the waveform cockpit takes the full width (compact speed/transport bars, flexing waveform)
and the loops/markers list becomes a **slide-in drawer** (☰), gated to this screen by
`OrientationGate`. The old bottom **song-info panel was removed** — its facts live
in the song-details sheet (hold the title). The app opens to a **home hub** (`HomeView`, ADR 0044; planner review R1) — a greeting, a primary
**Start today's session** CTA (→ `PlannerView`, goal-adaptive), a "Jump back in" card
for the most-recently-practised song, a blue **Song library** nav strip, and — below the metronome —
a **Practice** card pushing the top-level **Practice
space** (`PracticeView`, ADR 0046 — a **hub** over two unit libraries: `ExerciseLibraryView`
(command drills) and `LoopLibraryView` (any measured song **loop**, `commandTempo != nil`), each a
row pushing its own list — each with a **sort menu + search** (`PracticeLibrarySort`, ADR 0056:
loops by Song · Name · Command · Mastery, exercises by Name · Command · Recently added; choice
persisted per library). An exercise opens `ExerciseRunView`; a loop opens `LoopRunView` (Phase B)
— both owning their own engine. On the
exercise run setup the tempos (working/command/reach) and the Steps granularity sit inside a
collapsible **Practice Settings** panel (`PracticeSettingsPanel`) below the title — collapsed by
default to a one-line tempo summary, mirroring the nested Steps disclosure. The
run staircase lights the live plateau as it climbs, tempos are typable as well as nudged, and the
routine takes reach / back-up steps beyond warm-up. The **reach is editable** (ADR 0075): it
defaults to the auto-derived goal above command but can be pinned to a custom target (nudged/typed in
Practice Settings, or in `ExerciseTempoSection`), with a **Reset to auto** affordance; a pin is stored
per unit (`Exercise.targetTempoOverride: Int?` / `Loop.targetSpeedOverride: Double?`, additive
optionals) and read through the effective `Exercise.reachTempo` / `Loop.targetSpeed`. A pin must stay
above command, so `promoteCommand` auto-clears it once command catches up (the vestigial
`Exercise.targetTempo` is retained un-removed for migration but no longer written). A new exercise picks a **time signature**
(`NewExerciseSheet`, default 4/4) — also editable on an existing exercise from the run-setup nav
bar — that drives the run click's accents + **count-in** length; a training run **counts you in**
before the climb (honoring the Settings toggle/length, ADR 0052). The running readout is just the
live BPM + beat dots — or, for an exercise with a **content template** (ADR 0065), the template's
own surface in place of the dots: `kind` selects the renderer (`.metronome` default → beat dots;
`.strumming` → `StrummingLaneView`, a down/up/mute/rest arrow lane (each slot independently
**accentable**) driven by the pure `StrumPattern` timing math; `.fretboard` → `FretboardView`,
notes walking a string × fret grid driven by the pure
`FretboardDrill` timing math — the shared surface for Scales/Picking/Legato/Fingerstyle/Warm-up,
ADR 0065 build 2; `.chords` → `ChordChangeView`, the current chord's diagram large with the next
previewed, swapping on the beat, driven by the pure `ChordProgression` timing over a shared
`ChordVoicing`/`ChordDiagramView` — triads are just three-note voicings, so they fold in here;
`.strumChords` → `StrumChordsView`, the chord surface stacked over the strum lane, both reading one
shared beat origin but each wrapping on its own independent cycle length — driven by a
`StrumChordSheet` pairing a `StrumPattern` and a `ChordProgression`, no reset coupling between them),
with an absent/undecodable payload falling back to the dots. The `Exercise` model stores its `CommandRamp`
recipe natively in `ramp*`/dwell/backoff/`rampReachSteps`/`rampBackoffSteps` fields, the
`automator* → ramp*` rename done data-preservingly via `@Attribute(originalName:)`. A loop trains
the **same** warm-up → dwell → reach → back-off `CommandRamp`, but in percent-of-original against
its time-stretched audio: `LoopRunModel` owns a `PracticeAudioEngine`, loops the region, and steps
the playback rate by elapsed seconds; the `×` reach derives from `TempoStretch.targetSpeed` (or a
pinned `targetSpeedOverride`, ADR 0075) and the staircase reuses `CommandRamp` via `LoopCommandRamp`'s
`×`→percent mapping), a metronome card, and a preview of your songs with
**See all** pushing the full **song library** (`LibraryView`), now one tap from the front
door rather than the root. Importing a DRM-free local/iCloud **audio file** takes a
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
as the rounded average of its **rated** loops' `mastery` (`MasteryRollup`, pure/unit-tested;
unrated loops are skipped, ADR 0039), shown as
stars and as a library group with an **Unrated** bucket for songs with no rated loops; the song also
records `lastPracticed` — **stamped on practice-screen entry** (ADR 0044) — for "recently
practised" ordering (home hub + library) and the planner (ADR 0036). Each loop carries a
per-loop **automator** (the "A" control on its row): a speed-trainer ramp — start % →
target % over N steps, a few loops each — that climbs, descends, or sits level, runs a
**fixed number of passes and then stops** (Set ramp also starts it playing), driven by the
engine counting loop wraps (ADR 0013). A loop row is **glanceable** (ADR 0039): under the name it shows the time range plus —
**only when set** — the loop's **mastery** (dots) and **command tempo** (a percent badge,
the headline achievement), so the loops list reads as a practice dashboard and an untouched
loop never shows a fake rating. Loop rows carry no edit pencil — **press and
hold** a row (with a haptic) to open the edit sheet for rename / range / colour /
delete (ADR 0028); the colour row pins a loop's identity hue — Auto, a preset, or a
custom colour wheel (low-contrast colours get an advisory hint) — or leaves it
automatic (ADR 0031). The edit sheet's **Practice** section carries the loop's
structured fields (ADR 0036), each with an explicit **unset** state (Optional, `nil` =
never set — ADR 0039, so a default never reads as a real rating; migrates pre-0039 loops to
`nil` for free): **Mastery** (0–5 dot rating, the source the song rolls up from; tap the
lowest filled dot down to clear back to *Unrated*), **Focus** (Backburner / Active /
Sharpening intent, stored 1–3, now a menu with a *Not set* option), **Type** (a closed
`LoopType` — Lick / Riff / Chords / Passage, single-select; Passage is the composite for a
loop spanning more than one), and **Command tempo** (the fastest tempo you own the loop at,
as a % of original; a **Set** button until measured — seeded from the loop's practice
speed — and a **Clear** back to unset) — the structured practice signal the planner reads.
Once a command tempo is set the Practice section also shows a **Practice now** button (ADR 0082) that
commits the sheet's edits and launches the loop's `LoopRunView` full-screen over the waveform,
returning here on exit — the same command-tempo gate that surfaces a loop into Practice → Loops.
Percent display + the `nil → "—"` fallback live in the pure `LoopProgressFormat`. A **Tags** section (ADR 0034)
adds the loop's open descriptive axis (`Loop.tags: [String]`) — the loop analogue of
song collections, canonicalised on write and **suggested from tags already used on any
loop** (cross-loop `@Query`); the cross-song filter-by-tag payoff is deferred to its first
consumer (the planner). Each loop also has a **practice journal** (ADR 0038): a dated log of
`JournalEntry` `@Model`s. **Authoring lives on the Practice run screens** (ADR 0058) — an inline
**Journal** section in `LoopRunView` / `ExerciseRunView` (a `JournalPreviewSection`: New-entry CTA
+ the latest 3 entries + See-all) opens the shared `JournalSheet` to add / edit / delete entries,
snapshotting the unit's context at that moment (the truthful place to write is right after a run).
The inline preview replaced an earlier nav-bar book button, which crowded the exercise
time-signature control. Every entry **snapshots the owner's achievement at creation** —
copied, not referenced, so it stays truthful as the unit improves; the snapshot and timestamp are
immutable, only `text` and a typed **kind** (🎯 Goal / ⚡️ Breakthrough / 🧗 Struggle / 📝 Note /
🎬 Session — an `EntryKind`, primitive-backed like `LoopType`) are editable. Entries group under
day headers (`JournalGrouping`, pure), newest first. The loop-journal also lives in the loop's
**settings sheet** (a **Journal** row, ADR 0067), not on the loop row — the row's second control
became a one-tap **fine-adjust** button instead — and it is now **authorable** there too (ADR 0088,
reversing 0058's waveform read-only): the same `JournalSheet` + `JournalWriter` path, so a song loop
can be journalled without launching a run. The entry's owner is **polymorphic**
(ADR 0058): `JournalEntry` relates to a `Loop` **or** an `Exercise` (exactly one) via
`JournalOwner`, so exercises get a journal too — an exercise entry snapshots its command in
**absolute BPM** (`commandBpmAtEntry`) and has no mastery, kept a distinct field from the loop's
song-fraction `commandTempoAtEntry` so a BPM is never stored as a fraction; the shared
`JournalWriter` builds each via the `forLoop`/`forExercise` factories. Songs get free-text
**notes** rather than a journal, and markers get neither.
Those song notes (`Song.comment`) live in a **Notes** section directly under the
title/artist/album header in the **song details sheet** — **editable inline behind a
pencil affordance**: tap it to edit, an **Update** button (disabled until the draft
changes) commits with a brief "Saved" confirmation; the rest of the sheet stays
read-first. The song-scope half of the notes/journal feature (ADR 0038). Filename suggestions, **collections as real playlists**, and a **metronome**
(the transport "Auto" slot) are next. Navigation/planner follow (Phase 3) — the
planner's **selection** (goals → required skills from a **technique taxonomy**
(`docs/practice-techniques.md`) → candidate items, *prioritised, not balanced*; ADR 0015)
and its **ordering/time-boxing** are grounded in practice science (spaced repetition +
serial-position effect + diminishing returns; ADR 0014); a **clean-before-fast** advance
gate for the speed-trainer is recorded for a later automator slice (ADR 0016).
Verified pure logic: `TempoMath`, `TempoPeaks`, `TempoEstimator`, `SongRef`, `AudioMath`, `WaveformGesture`, `BeatGrid`, `MetronomeBeats`, `MetronomeGrid`, `TempoMarking`, `TempoSliderScale`, `TimeSignature`, `MetronomeAutomator`, `TempoStretch`, `CommandRamp`, `LoopLanes`, `AutoName`, `Song`, `AutomatorConfig`, `EntryKind`, `JournalGrouping`, `MasteryRollup`, `LoopProgressFormat`, `PracticeStats`, `GlossaryTerm`.
See `CHANGELOG.md` for the full history.