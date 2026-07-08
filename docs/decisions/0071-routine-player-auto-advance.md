# 0071 — Routine player: auto-advance on natural completion

- **Status:** Accepted (2026-07-07; player/editor refinements 2026-07-08)
- **Date:** 2026-07-07

## Player & editor refinements (2026-07-08)

A round of device feedback added the following, all consistent with the decisions below:

- **Auto-start (Settings-gated).** Every block *after the first unit block* starts on its own; the
  first always waits for a deliberate Start. Governed by `AppSettings.routineAutoStart` (default on).
- **Count-in.** A brief `3·2·1` visual + haptic overlay (`RoutineCountInOverlay`) precedes **any**
  block start — auto or manual — so a block never begins mid-stride. Uniform across exercises and
  loops (no audio of its own; a drill's own musical count-in, if enabled, still follows).
- **Progress strip.** A slim per-block strip (`RoutineProgressStrip`) below the nav bar with
  **Start/Finish** endcaps and the current block highlighted, replacing the cramped "N of M" that sat
  beside the close button.
- **End-of-block reflection (Settings-gated) + session recap.** On a block's natural finish, an
  optional journal sheet lets the player reflect before advancing (`AppSettings.routineReflection`,
  default on; Skip bypasses it). The routine's in-setup journal is hidden in routine mode — reflection
  moved to the end. The session closes on a **judgement-free recap** (what was practised, no scores —
  ADR 0070).
- **Edit-gated editor.** `RoutineDetailView` opens **read-only**; the name field, Add/Insert, and
  delete/reorder controls appear only after tapping **Edit** (Save commits the sandbox, Cancel
  rebuilds it from the store). A brand-new routine opens directly in edit mode.
- **Loop settings collapse.** `LoopSettingsPanel` gives a loop run the same collapsible **Practice
  Settings** disclosure an exercise has (tempos/reps/steps), so it opens on the summary + staircase.

## Context

ADR 0066 defined the practice **routine** model (an ordered list of exercise /
loop / song / rest blocks) and its authoring UI (slice 2). Slice 3 is the
**player** that runs a routine end-to-end. The question this ADR settles is *how a
block ends and the next begins* — the one genuinely new behaviour, since the
per-unit playback engines already exist (`StandaloneMetronomeEngine` for a click
exercise, `LoopRunModel` / `PracticeAudioEngine` for a loop).

Two forks had to be chosen deliberately:

1. **What ends a block?** A wall-clock time-box per block (the ADR 0014 planning
   model — "12 focused minutes"), or the material's **own natural completion**.
2. **Does completion gate on playing it *right*?** A "clean rep" gate (advance
   only once the take is accurate) is the obvious "smart practice" default.

## Decision

### 1. Auto-advance on the block's own natural completion — not a wall clock

Each block runs its **saved `CommandRamp`** to its end and the player then
**auto-advances**:

- **Exercise / loop block** → one full ramp pass (warm-up → dwell → summit →
  back-off). The engines already know when this finishes; they now expose it:
  `StandaloneMetronomeEngine.onRampFinished` and `LoopRunModel.onFinished`, each
  fired **only** from the natural-completion path (`finishRamp` / the ramp-finished
  branch of the loop tick), **never** from a manual `stop()`. The conductor
  (`RoutineSessionPlayer`) hangs its `advance()` off these callbacks, and detaches
  them before any teardown so a Skip/End/advance can never re-enter.
- **Rest block** → a short fixed countdown (`RoutineSessionPlayer.restSeconds`,
  20 s today), then auto-advance.

**Consequence:** a manual routine needs **no per-block minutes**. Each block runs
its natural length, so the ADR 0014 time-budget becomes a **planning-time** concern
for the future planner, not a runtime clock. The runtime rest is a short breather,
deliberately *not* the ADR 0014 rest *minutes*.

This diverges from ADR 0016's *clean-before-fast* at the **session** level: the aim
here is **controlled discomfort, not clean reps**. The ramp already encodes the
climb to and past the command tempo (the "just outside comfort" reference), so one
pass *is* the block — pushing past command (won't be clean) is the intended
stimulus, not a failure.

### 2. Zero evaluation surface (inherits ADR 0070)

The player never grades a take: no scoring, no pitch/timing detection, no
pass/fail. Completion is the material's length, never "play it right to advance."
The player is the judge (ADR 0070). The player screen shows *what* is playing and
*how far along* the session is, and nothing about *how well*.

### 3. Song blocks — audio-only play-along (built 2026-07-08)

A song block is an **audio-only, branded play-along** — a fixed play-along speed you
set, play/pause, −10 s / +10 s, nothing else ("just play along"). It runs on
`PracticeAudioEngine`, so tempo change is time-stretch and therefore **works only on
DRM-free local / iCloud files** (ADR 0001) — Apple-Music-sourced songs can't be
time-stretched, the same wall as everywhere else. **The DRM-free constraint is
accepted**; Apple-Music song blocks are filtered out of both the picker and the player
(not silent dead ends). Two deliberate calls (user, 2026-07-08):

- **No ramp — one fixed tempo.** Unlike an exercise/loop block, a song is an open jam,
  not a staircase. You set a single play-along speed (percent of original, adjustable
  live); there is no warm-up → reach progression.
- **Loops by default; advances only on Skip.** A song block loops as an open jam and
  moves on only when you skip it — an "open" completion, not a natural end. This is
  **configurable** (`AppSettings.routineSongLoop`, Settings → Routines, default on);
  turn it off and a song plays through **once** and then auto-advances like any other
  block (firing the end-of-block reflection). Whole-song looping is done by **replaying
  on the natural end**, not the engine's crossfaded loop buffer — that buffer holds the
  whole region in memory (fine for a short loop, hundreds of MB for a full song); a
  brief seam at the song boundary is natural for a jam loop.

## Architecture

**The player reuses the real run screens — it does not re-implement them.** An
early cut gave each block a bespoke compact surface (just a BPM/percent readout).
That was rejected on review: it dropped the training **aids** — the fretboard /
strum / chord **preview**, the Practice Settings summary, the **ramp staircase**,
promote, and journal — and would have drifted from the standalone run screen over
time. Instead each exercise/loop block *is* the actual `ExerciseRunView` /
`LoopRunView`, so the aids are kept by construction. The only routine-specific
additions are session chrome.

- **`RoutineSessionCursor`** (pure, Foundation-only) — position / advancement math
  over the count of playable blocks; unit-tested (`RoutineSessionCursorTests`), per
  the "pure logic stays pure / stepping must be tested" rule (AGENTS.md).
- **`RoutineSessionPlayer`** (`@MainActor @Observable`) — a *thin* conductor that
  owns **no playback engine**. It resolves the routine's playable blocks (dropping
  orphaned units, R5, and Apple-Music songs), tracks the cursor, runs the
  between-blocks **rest** countdown (the only playback it does itself), and exposes
  `start / advance / end`. Each unit block's engine is owned by its run screen.
- **`RoutineRunContext`** — the seam injected into a run screen: `progressLabel`,
  `onSkip`, `onFinished` (the natural-completion hook), `onExit`. `ExerciseRunView`
  / `LoopRunView` take it as an optional (`nil` standalone → screen unchanged); when
  present they wire their engine's `onRampFinished` / `onFinished` to it, add a
  `RoutineSkipButton` to their transport, and show a leading close + progress
  (`routineSessionChrome`). A block is **started manually** (the existing "Start
  training"), which preserves the setup/promote/journal moment; "auto-advance" means
  the automatic *transition* to the next block on completion, not auto-start.
- **`RoutinePlayerView`** — a thin `NavigationStack` host that swaps the run screen
  per block (`.id(stage.id)` so each starts fresh), shows the rest countdown and the
  finished summary, and is presented as a `fullScreenCover` from the ▶ on each
  Routines library row.
- **`SongPlayAlongView` / `SongPlayAlongModel`** — the audio-only song-block screen
  (built 2026-07-08). The model owns its own `PracticeAudioEngine` (like `LoopRunModel`)
  and drives a fixed play-along speed, seek, and the loop-or-advance behaviour off
  `PracticeAudioEngine.onReachedEnd` (a new additive callback fired only on a natural
  straight-through end). The view takes the same optional `RoutineRunContext`, so it
  gets the progress strip / Skip / count-in; songs have no journal, so a song block
  never shows the reflection prompt.
- **`Loop.ramp`** — new saved-recipe computed property mirroring `Exercise.ramp`,
  so a loop block runs its stored ramp with no extra setup.

## Alternatives considered

- **Per-block time-box** (ADR 0014 runtime clock) — rejected for the manual player:
  natural completion is on-philosophy and needs no authored minutes. Revisit if the
  planner wants wall-clock sessions.
- **Clean-rep gate** — rejected; it requires evaluation (ADR 0070 forbids it) and
  contradicts the controlled-discomfort aim.
- **A bespoke compact per-block surface** (player drives the engines directly, shows
  only a BPM/percent readout) — **rejected on review.** It dropped the training aids
  (previews, staircase, promote, journal) and would drift from the standalone run
  screen. The player instead **embeds the real run screens** (see Architecture); the
  cost is that it also carries their setup/promote/journal affordances, which is
  acceptable — that per-block moment is useful, and Skip lets you move on.

## Consequences

- Adds three engine callback seams (`onRampFinished` / `onFinished` /
  `onReachedEnd`) — additive, nil for standalone runs, so the run screens are unaffected.
- No model or schema change (the routine model already existed, ADR 0066); no
  migration.
- **`RoutinePresets` seeder (built 2026-07-08).** Three curated in-house starter
  routines (Morning Warm-up, Picking Builder, Rhythm & Changes) seed once on first
  launch, **after** `PracticePresets` so their blocks resolve against the just-seeded
  exercises **by name**. Exercise-only by construction — loops/songs need user audio,
  which doesn't exist at cold start (the exercises-first / shareable-axis direction,
  ADR 0064). A missing exercise is skipped and a rests-only routine isn't seeded;
  one-time `UserDefaults` flag makes deletion stick (mirrors `PracticePresets`). The
  planner (a producer of the same model) is the remaining follow-on.
