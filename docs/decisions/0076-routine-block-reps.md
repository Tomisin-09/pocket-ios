# 0076 — Routine block repeats (reps)

- **Status:** Accepted
- **Date:** 2026-07-10
- **Extends:** ADR 0066 (routine model + player), ADR 0071 (player auto-advance / per-block Done
  screen). Pairs with the R3 session-length estimate (`SessionEstimate`, already reps-aware).
- **Supersedes:** nothing. Completes the reps follow-up parked in the R3 slice (the `RoutineItem.reps`
  field + estimate shipped infra-only; nothing set it > 1 and the player didn't loop).

## Context

`RoutineItem.reps: Int = 1` and `effectiveReps` were added in the planner R3 slice, and
`PracticePlanner.estimatedMinutes(forRoutine:)` already multiplies each block's estimate by its reps.
But it was **infra-only**: there was no way to *set* reps above 1, and the player ran each block
exactly once. This closes that gap — authoring + player looping — so a routine can say "run this drill
three times before moving on," which is how a warm-up or a hard passage is actually practised.

## Decision

### 1. Reps loop a block **back-to-back**, reflection is **per-block**

A block with `reps > 1` runs its full drill (a complete ramp pass, or the block's natural completion)
`reps` times in a row before the session advances to the next block. Between reps there is **no Done
screen and no rest** — reps are consecutive runs of the same material. The manual-advance **Done
screen** (ADR 0071: optional mastery tap + inline note) and any authored rest appear only **after the
last rep**, because reflection belongs to finishing the *block*, not each rep. A fresh rep restarts
the drill from scratch (the player keys the run screen on the current rep, so SwiftUI rebuilds it),
honouring the same auto-start setting a new block does.

### 2. Skip abandons remaining reps; Back leaves the block

The session's **Skip** (progress-strip ›) jumps to the **next block**, dropping any remaining reps —
distinct from a natural completion, which only steps to the next rep. **Back** (‹) returns to the
**previous block** and resets its rep counter. This keeps "advance one rep" (the material finished)
and "skip the block" (the user is done with it) as separate, legible actions.

### 3. Rep stepping lives in the pure cursor

`RoutineSessionCursor` (SwiftData-/SwiftUI-free, unit-tested — the "pure logic stays pure" rule) owns
the rep counter alongside the block index. It is constructed with a **per-block reps array**; a
convenience `init(total:)` (all-single-run) keeps existing callers/tests valid. `advance()` is
rep-aware (step the rep, or roll to the next block on the last rep); a new `skip()` jumps blocks; both
`skip()` and `retreat()` reset the rep. The **block** progress label ("N of M") counts blocks, not
reps, so a repeated block never inflates the session length; the rep counter reads separately as
"Rep 2 of 3".

### 4. Authoring: tap a block → a reps editor sheet

In the routine editor's **edit mode**, tapping a **unit** block (exercise/loop/song — not a rest)
opens a compact **reps editor** sheet with one roomy stepper (1…9) — so the block *list* stays a clean
single line rather than cramming a stepper next to the drag/delete affordances (a first inline-stepper
pass was too bunched on a narrow screen). The tap target is a real `Button`, not a row tap gesture, so
it fires reliably alongside edit-mode's drag/delete (the same "real Button beats a menu/gesture in a
fussy slot" lesson as the loop picker). The button's trailing affordance is a tappable **`×N` chip**
(always shown in edit mode, even at `×1`, so it's discoverable) — the count doubling as the control,
clearer than a bare chevron. Edits write to the editing sandbox like every other edit (provisional
until Save, re-flowing the live length estimate). In **read-only** mode a block set above `×1` shows a
flatter `×N` **badge**, so the count stays visible without entering edit mode. Rests can't repeat.

## Consequences

- Warm-ups and trouble spots can be authored to repeat without duplicating blocks; the length estimate
  already reflected reps, so it stays accurate.
- No schema change — `reps` / `effectiveReps` already existed (additive, CoreData 134110-safe).
- The player stays a thin conductor over the *real* run screens (ADR 0066): a rep is just another run
  of the same screen, so every training aid is kept.

## Alternatives considered

- **A Done screen after every rep.** Rejected — reps are back-to-back repetition; a reflection gate
  between them breaks the flow and duplicates the per-block Done.
- **Counting reps in the block progress label** ("3 of 9" for a 3-rep block). Rejected — it conflates
  session length with repetition; blocks and reps are shown as separate counters.
- **Reps in the conductor, not the cursor.** Rejected — the off-by-one stepping is exactly what the
  pure cursor exists to make unit-testable.
