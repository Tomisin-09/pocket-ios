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
  reach/back-off steps, signature), so the exercise snapshot tracks all of them. A **Loop**
  originally stored only `speed` (working) and `commandTempo` (command); its steps/reps were not
  persisted by Start *either*, so the loop snapshot tracked just those two and changing loop
  steps/reps showed no Save button. **Resolved in the follow-up below** — the loop now persists its
  full ramp shape too.

## Follow-up (2026-07-01) — loop ramp shape now persists

Closed the deferred item. `Loop` gains four **dedicated** ramp-shape fields —
`rampWarmupSteps` / `rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep` — with declaration
defaults (additive SwiftData lightweight migration, CoreData 134110 rule; no store wipe). They are
**deliberately decoupled** from the ADR-0013 automator fields (`automatorStepCount`,
`automatorLoopsPerStep`): that's the waveform-screen ramp ("steps to target"), these are the
command-anchored run ramp ("intermediate stops between working and command") — different semantics,
so coupling them to save four fields would be a bug magnet. `LoopSetupState` now carries all six
persisted fields (so `isDirty` fires for the ramp too), `seedIfNeeded` restores them off the loop,
and the shared `persist()` writes them back. `LoopSetupState` was promoted from `private` to
file-internal to unit-test the dirty-detection equality (mirroring `LoopEditSnapshot`).

Visually the button is a subtle filled practice-tinted capsule, distinct from the outlined
**Promote** above it and the filled **Start training** pill below, and it fades in/out on the dirty
transition.

## Alternatives considered

- **Auto-conserve on leave (no button).** Rejected — silently persisting every fiddle defeats the
  cheap-exploration intent; an explicit action is clearer about what sticks.
- **"Discard changes?" prompt when leaving dirty.** Rejected for now — heavier than needed; the
  explicit Save already gives control. Left as a future add if losing edits bites.
- **Persist loop steps/reps too (symmetry with exercises).** Was deferred for this slice; **done in
  the 2026-07-01 follow-up above** via four dedicated `Loop` fields.
- **Reuse the ADR-0013 automator fields for loop ramp shape.** Rejected in the follow-up — the
  automator is the waveform-screen "steps to target" ramp with different semantics than the
  command-anchored run ramp; coupling the two systems to save four fields is a bug magnet.

## Consequences

- Reconfiguring a unit's defaults no longer requires starting a run.
- One shared `persist()` per screen removes the risk of Save and Start writing different things.
- ADR 0046's discard-on-leave is now *scoped to unsaved edits* — documented here so the change from
  "leaving always discards" to "leaving discards the unsaved" isn't re-litigated.
- Loop ramp shape (warm-up/reach/back-off steps + reps per step) now persists via four dedicated
  `Loop` fields, so loop Save covers them too (follow-up above, 2026-07-01).
