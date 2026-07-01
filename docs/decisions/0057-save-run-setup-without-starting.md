# 0057 — Save run-setup edits without starting a run

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

The exercise and loop **run-setup** screens (`ExerciseRunView`, `LoopRunView`, ADR 0046) let you
tune the command-anchored ramp before a run — the warm-up **working** floor, owned **command**,
derived **reach**, the step granularity, and (exercises) the time signature. Those edits live in
local `@State` and, by ADR 0046's design, are written to the model **only on Start** (`commitAndStart`);
leaving the screen without starting **discards** them.

That discard-on-leave rule keeps exploration cheap, but it left a real gap: there was no way to
**reconfigure** a unit's defaults — bump the working floor, promote command — and come back later
without committing to a training run then and there. The only persist path was to start playing.

## Decision

Add an explicit **Save Changes** control to both run-setup screens. It appears only while the
current setup differs from what's stored, and persists the tuning **without** starting a run.

- **Discard-on-leave still holds by default.** Unsaved edits are still thrown away when you leave —
  ADR 0046's intent is preserved. Save is the *opt-in* that makes edits stick. No "discard changes?"
  prompt on back (kept light; revisit only if losing edits proves painful).
- **Save persists exactly what Start persists.** A shared `persist()` helper is the single write
  path for both **Save Changes** and **Start training**, so the two can't diverge. Start is now
  `persist()` + hand the routine to the engine; Save is `persist()` + haptic.
- **Dirty detection via a baseline snapshot.** A small `Equatable` value type (`ExerciseSetupState`
  / `LoopSetupState`) captures the persistable fields; it's snapshotted at seed and re-captured
  after each Save. `isDirty = baseline != current` gates the button. This mirrors the
  `LoopEditSnapshot` pattern (ADR 0019 undo-on-save).
- **Scope matches the model.** Exercises persist the full ramp shape (working, command, step BPM,
  reach/back-off steps, signature), so the exercise snapshot tracks all of them. A **Loop** stores
  only `speed` (working) and `commandTempo` (command) — its steps/reps are not persisted by Start
  *either* — so the loop snapshot tracks just those two. Changing loop steps/reps therefore shows
  no Save button, because there is nothing to save; persisting loop ramp shape would need new
  `Loop` fields + a migration and is deferred.

Visually the button is a subtle filled practice-tinted capsule, distinct from the outlined
**Promote** above it and the filled **Start training** pill below, and it fades in/out on the dirty
transition.

## Alternatives considered

- **Auto-conserve on leave (no button).** Rejected — silently persisting every fiddle defeats the
  cheap-exploration intent; an explicit action is clearer about what sticks.
- **"Discard changes?" prompt when leaving dirty.** Rejected for now — heavier than needed; the
  explicit Save already gives control. Left as a future add if losing edits bites.
- **Persist loop steps/reps too (symmetry with exercises).** Deferred — needs new `Loop` ramp-shape
  fields and a migration; out of scope for this slice, which persists exactly what Start already does.

## Consequences

- Reconfiguring a unit's defaults no longer requires starting a run.
- One shared `persist()` per screen removes the risk of Save and Start writing different things.
- ADR 0046's discard-on-leave is now *scoped to unsaved edits* — documented here so the change from
  "leaving always discards" to "leaving discards the unsaved" isn't re-litigated.
- A follow-up is recorded: persist loop ramp shape (steps/reps) so loop Save covers them too.
