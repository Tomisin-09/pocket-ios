# 0078 — User-controllable dwell (command-plateau hold)

**Status:** Accepted · 2026-07-11

## Context

A command-anchored training ramp (`CommandRamp`, ADR 0045/0046) is: warm up from the working floor
→ **dwell at command** → summit at the reach → back off. The *dwell* — how many intervals the
command plateau holds — is the consolidation phase, the meat of the practice: time spent playing at
the fastest tempo you own clean.

Every other part of the ramp shape was already tunable in the run setup (warm-up steps, reach steps,
back-off steps, and for loops reps-per-step), but **dwell was fixed at 4** for everything:

- `Exercise` already *stored* a `dwellIntervals` field, but `ExerciseRunView`'s `persist()`
  overwrote it with `StandaloneMetronomeEngine.automatorDefaultDwell` on every Start/Save — so the
  field existed but the user could never change it.
- `Loop` had **no** dwell field at all; `LoopRunView` and `Loop.ramp` hardcoded
  `LoopCommandRamp.defaultDwellIntervals`.

Surfaced during device testing of ADR 0077 Slice 2: reviewing the in-routine tempo/steps surface made
it obvious the user had no control over how long they sit at command. The request was to expose dwell
"across both exercises and loops."

## Decision

Make the command-plateau dwell **user-tunable**, presented as a **raw count** row in the existing
collapsible **Steps** panel (`RoutineStepsControls`), captioned per type so the unit reads right:

- **Exercise:** each dwell interval is `automatorDefaultBars` (4) bars → caption "≈ N×4 bars at command".
- **Loop:** each dwell interval is `repsPerStep` loop passes → caption "≈ N×reps passes at command".

Dwell has its own range (**1…12**; always ≥ 1 — the command plateau must hold at least one interval),
distinct from the 0…6 step counts.

**Scope: everywhere the Steps panel already appears** — the standalone library run screens
(`ExerciseRunView`, `LoopRunView`) *and* the in-routine surfaces (`ExerciseBlockPreview`, and the
in-routine `ExerciseRunView`). Consistent: dwell is tunable wherever the rest of the ramp shape is.

### Model changes
- **Exercise:** no schema change — the `dwellIntervals` field already exists. Stop hardcoding it in
  `persist()`; seed the run-setup state from it and commit the edited value. Added to
  `ExerciseSetupState` so editing it arms Save Changes.
- **Loop:** **new field `rampDwellIntervals: Int = 4`** on the `Loop` `@Model`. Additive,
  declaration-default-backed, so loops saved before this migrate via SwiftData lightweight migration
  with no store wipe (CoreData 134110 rule, per ADR 0012) — matching the old fixed value of 4. Added
  to `LoopSetupState` for Save-dirty tracking; `Loop.ramp` now reads it.

The dwell value flows into the existing `CommandRamp.dwellIntervals` knob — the plateau math, live
cursor and completion are unchanged (the same tested seam), so this is purely *exposing* an existing
parameter plus one additive Loop field.

## Consequences

- The user can now shorten or extend the consolidation hold per exercise/loop, on both the library
  run screen and inside a routine.
- One additive `Loop` schema field — verify on-device (SwiftData migrations have historically only
  failed on device, not in in-memory tests).
- The `ExerciseAudioEngine` / automator seams are untouched; `automatorDefaultDwell` remains the
  seed default for a fresh exercise.

## Alternatives considered
- **Coarse Short/Medium/Long presets** instead of a raw count — friendlier but a different idiom from
  the other step rows, and less precise. Rejected for consistency with the existing count controls.
- **Routine surfaces only** — narrower, but leaves the same Steps panel behaving differently in the
  library vs. a routine. Rejected as inconsistent.
