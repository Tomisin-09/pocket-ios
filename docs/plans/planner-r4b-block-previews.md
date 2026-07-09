# Planner R4b — pre-start block previews + straight-into-play live flow

Follow-up to R4 (PR #110, `pocket-116`). From on-device testing 2026-07-09.
**SHIPPED** on branch `pocket-117-planner-r4b-block-previews` (all four parts built; 832 unit tests
green). Loop audio unknown resolved: reused `LoopRunModel` via a new `startAudition(percent:)` +
`LoopAudioPreviewPlayer`; `Loop.ramp` already existed for the staircase. Preview presented as a nav push
(`navigationDestination(item:)` on `RoutineBlockPreviewTarget`).

## The north star
Before a routine starts, the user should fully understand **what** each block is and
**how** they'll play it, straight from the block list. If the up-front previews are clear,
**in-session previews become unnecessary** — so the live session jumps straight into
playing (no per-block "Start training" gate). This supersedes the earlier "item 15 dropped"
call: item 15 is now realised as *up-front block previews + straight-into-play*, not an
in-session preview.

Screens referenced: routine block list = the preview entry point; run-screen stopped state
(fretboard + staircase + **Start training**) = the per-block gate we skip in live sessions.

---

## Scope (one branch, e.g. `pocket-117-planner-r4b-block-previews`)

### 1. Read-only block preview — tap any block in `RoutineDetailView` (read-only mode)
Replaces the current exercise block-tap → `ExerciseDetailSheet` with a purpose-built
**read-only** preview. **Loop blocks become tappable too** (add the chevron in
`blockRow` — `inspectable` should include loops, not just exercises).

The preview is *assembly of existing standalone views*, reading the unit's **stored** values
(no engine, no seeding, no local edit state — simpler than the run screen).

**Presentation:** nav push within `RoutineDetailView`'s `NavigationStack` (own back button;
reads like the run screen). — DECISION to confirm (sheet is the alternative).

**Exercise preview** — content renderer via payload switch, mirroring
`ExerciseRunView.swift:77-82`:
- `strumPattern` → `StrumPatternPreview(pattern:)`
- fretboard (run / scale / arpeggio / custom drill) → `FretboardExercisePreview` — **verify it
  takes the whole `exercise` and covers all fretboard kinds** (`ExerciseTemplatePreview.swift:22`
  / `:102`), i.e. the arpeggio in the test screenshot renders through it, not only custom drills.
- `chordProgression` → `ChordProgressionPreview(progression:)`
- `strumChordSheet` → `StrumChordsPreview(sheet:)`
- Tempo readout: `working → command · reach BPM` (`exercise.workingTempo` / `.command` /
  `.derivedTarget`).
- `RoutineStairs(plateaus: exercise.ramp.plateaus, tint: .practice)` — static (no `currentIndex`).
- **Audio preview button:** metronome command-tempo click, ~6s, **reuse
  `CommandTempoPreviewPlayer`** — `toggle(bpm: exercise.command, signature: <stored meter>)`.
- **Details** link → existing `ExerciseDetailSheet(exercise:)` (keeps R4's command-tempo edit +
  its own audio reachable; no second write path).

**Loop preview:**
- Tempo/speed readout (`loop.speed` %, command).
- `RoutineStairs(plateaus: <loop LoopCommandRamp plateaus>)` — mirror `LoopRunView.swift:99`'s
  `routine.plateaus`.
- **Audio preview button: a few seconds of the loop's ACTUAL audio — no click** (per decision A).
  NEW: a lightweight `LoopAudioPreviewPlayer` (analogous to `CommandTempoPreviewPlayer`) that
  plays the loop region briefly then auto-stops, reusing `LoopRunModel` / `PracticeAudioEngine`.
  **← main technical unknown, verify first (see below).** Loops are DRM-free local/iCloud files,
  so this is allowed (ADR 0001).

**Files:** new `RoutineBlockPreview.swift` (split into `ExerciseBlockPreview` +
`LoopBlockPreview` if it approaches the 400-line cap). Keep under the file/type-body caps.

### 2. Done screen — "Up next"
- `RoutineBlockDoneView` gains an **Up next** section in the empty space between the note field
  and Continue.
- Shows the **next actual unit, skipping past rests** (decision B): name + type icon + tempo line.
- Last block → **Finish**, no up-next.
- Keep `RoutineBlockDoneView` SwiftData-free: build a plain `UpNext` descriptor
  (`title` / `detail` / `symbol`) in `RoutinePlayerView` from the next non-rest stage and pass it in.
- **Pure helper** "next non-rest stage after index" on `RoutineSessionPlayer` (or the cursor) —
  unit-test it.

### 3. Live flow — jump straight into the first exercise
- Today the first unit block always waits for a manual **Start training**
  (`RoutineSessionPlayer.shouldAutoStart`: `AppSettings.routineAutoStart && index != firstUnitIndex`).
  Since blocks are previewed up front, **drop the `firstUnitIndex` exception** so the first block
  also honours `routineAutoStart` (default on): tap **Start** on the routine detail → count-in →
  straight into block 1.
- `routineAutoStart` stays as the setting — **off ⇒ every block waits** (manual-start users keep
  the run-screen gate).
- **Standalone runs are unaffected** — the run-screen stopped state (image 3) stays for the
  exercise/loop libraries; only *routine* blocks auto-start.
- Change is in `RoutineSessionPlayer.shouldAutoStart` (+ `firstUnitIndex` may become unused) —
  unit-test the new behaviour.

### 4. Typo — DONE in R4 (`RoutineBlockDoneView`: "How clean did that feel?").

---

## Open technical unknowns — verify BEFORE building (next session)
1. **Loop audio preview** (biggest): can a few seconds of a loop's region be played cheaply via
   `LoopRunModel` / `PracticeAudioEngine` without the full run setup? Design `LoopAudioPreviewPlayer`
   (own engine/model instance, `preview()` + auto-stop, `stop()` on disappear). If `LoopRunModel`
   is too run-coupled, a thinner region-player over `PracticeAudioEngine` may be needed.
2. **`FretboardExercisePreview`** covers scale/arpeggio/run (not only custom `fretboardDrill`)?
   Confirm against `ExerciseTemplatePreview.swift`.
3. **Presentation**: nav push vs sheet for the preview.

## Constraints
- No grading (ADR 0070) — preview is audition only.
- Loop audio = DRM-free local/iCloud only (ADR 0001) — fine, that's what loops are.
- Pure logic (up-next selection, auto-start) unit-tested (AGENTS.md).
- Docs to touch on build: CHANGELOG, PROJECT, architecture (routine player flow), this plan +
  `planner-review-refinements.md`.

## Optional (not committed)
- A count-in overlay that names the upcoming drill + tempo — a lightweight safety net if a user
  skips the up-front previews and hits Start cold. Not requested; note only.
