# 0071 — Routine player: auto-advance on natural completion

- **Status:** Accepted (2026-07-07)
- **Date:** 2026-07-07

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

### 3. Song blocks deferred to a following slice

A song block is an **audio-only, branded play-along** — pick tempo, play/pause,
−10 s / +10 s, nothing else ("just play along"). It runs on `PracticeAudioEngine`,
so tempo change is time-stretch and therefore **works only on DRM-free local /
iCloud files** (ADR 0001) — Apple-Music-sourced songs can't be time-stretched, the
same wall as everywhere else. **The DRM-free constraint is accepted.** Because every
block now runs in a compact screen, the earlier "full-waveform handoff" problem
dissolves; song blocks are gated only on building this small player and are
**filtered out of the player until then** (they are not authorable yet either).

## Architecture

- **`RoutineSessionCursor`** (pure, Foundation-only) — position / advancement math
  over the count of playable blocks; unit-tested (`RoutineSessionCursorTests`), per
  the "pure logic stays pure / stepping must be tested" rule (AGENTS.md).
- **`RoutineSessionPlayer`** (`@MainActor @Observable`) — the conductor: resolves
  the routine's playable blocks (dropping orphaned units, R5, and song blocks for
  now), reuses one metronome engine across exercise blocks, rebuilds a
  `LoopRunModel` per loop block, and drives `start → advance → finish` plus
  pause/skip/end.
- **`RoutinePlayerView`** — the full-screen face (progress header, live block
  surface, minimal transport), presented as a `fullScreenCover` from the ▶ on each
  Routines library row.
- **`Loop.ramp`** — new saved-recipe computed property mirroring `Exercise.ramp`,
  so the player can run a loop block's stored ramp with no setup UI.

## Alternatives considered

- **Per-block time-box** (ADR 0014 runtime clock) — rejected for the manual player:
  natural completion is on-philosophy and needs no authored minutes. Revisit if the
  planner wants wall-clock sessions.
- **Clean-rep gate** — rejected; it requires evaluation (ADR 0070 forbids it) and
  contradicts the controlled-discomfort aim.
- **Embedding the full `ExerciseRunView` / `LoopRunView`** per block — rejected; the
  player is a transport, not an editor. It drives the engines directly and shows a
  compact readout, so mid-session tempo tweaking isn't offered (the routine plays
  the saved ramps).

## Consequences

- Adds two engine callback seams (`onRampFinished` / `onFinished`) — additive, nil
  for standalone runs, so `ExerciseRunView` / `LoopRunView` are unaffected.
- No model or schema change (the routine model already existed, ADR 0066); no
  migration.
- Song-block play-along and `RoutinePresets` seeding remain follow-on slices.
