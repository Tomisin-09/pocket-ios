# 0066 — Practice routine model (the multi-unit session container)

- **Status:** Accepted (2026-07-05)
- **Date:** 2026-07-05

## Context

"Routine" names two different things in this app, and conflating them is the
first hazard:

1. The **ramp staircase inside one exercise** — the working → command →
   back-off tempo climb a single drill plays. **Already built** (`RoutineStairs`,
   `CommandRamp`, ADR 0045/0046). Not this ADR.
2. A **multi-unit practice session** — an ordered sequence of drills, loops, and
   song run-throughs you work through in one sitting, with rests between. This is
   the "**Song → Loops → Exercises**" pipeline noted at the foot of the exercise
   inventory sheet, and it is what this ADR models.

The planner ADRs already designed the *intelligence* that would fill such a
session: ADR 0014's `buildSession(availableMinutes:, candidates:, now:)` turns a
candidate list into an ordered, time-boxed session; ADR 0015 derives that
candidate list from goals → skills; ADR 0016 stages speed behind control. But
all three take or produce a session **whose data model was left open** — there is
no `Routine`, `RoutineItem`, or `Session` type in the store today. The
intelligence has nothing to write into.

This ADR builds the **container and its player first, the intelligence later** —
the substrate-first sequencing this project uses everywhere (the waveform
roadmap, the A/B primitive). A manually-assembled routine is valuable on its own
(users want to string drills together *now*), it de-risks the planner by proving
the *player* before adding *selection*, and it gives ADR 0014's `buildSession` a
concrete output type. Manual routines and generated routines then share one
player.

## Decision

Model a routine as an ordered list of typed blocks, playable end-to-end. Eight
rules govern it.

- **R1 — `Routine` is a first-class `@Model`.** `uid: UUID`, `name: String`, a
  cascade-owned ordered list of `RoutineItem`, `dateAdded: Date`. Follows the
  established model discipline (ADR 0011/0036): business `uid`, declaration
  defaults on every non-optional attribute (CoreData 134110), String-backed
  enums only.

- **R2 — Order is stored explicitly, not inferred from the relationship.** Each
  `RoutineItem` carries an `order: Int`; the player reads items sorted by it.
  SwiftData `@Relationship` arrays are not a dependable ordering, so we don't
  lean on insertion order (the same discipline as `Song.loopsByStart` sorting on
  a field).

- **R3 — A `RoutineItem` is a typed block: a *practice unit* or a *structural*
  block.** Its `kind` (String-backed) is one of:
  - `focused` — drilling a unit (the budgeted work, ADR 0014 R1)
  - `warmup` — a warm-up unit (surfaced, unbudgeted, R1)
  - `play` — a full run-through / jam (surfaced, unbudgeted, R1)
  - `rest` — a between-blocks break (ADR 0014 R3); references no unit

- **R4 — A unit-bearing item points at an `Exercise`, `Loop`, or `Song`, exactly
  one, via typed optional relationships.** This reuses ADR 0058's polymorphic
  pattern and its explicit rejection of a generic `ownerKind + ownerID`: typed
  optional relationships keep SwiftData's inverse/nullify and referential
  integrity, a generic id loses them. The three unit types mirror ADR 0015 S3's
  candidate slots — a **drill** (`Exercise`), a **loop** on the user's audio
  (`Loop`), a **repertoire run** (`Song`). A `rest` item sets none.

- **R5 — Deleting a referenced unit nullifies the item, and the player skips
  it.** The item references the unit (not a copy), so editing the exercise/loop
  reflects live. On unit deletion the relationship nullifies (never orphan-cascades
  the routine); a unit-bearing item whose unit went missing is **skipped** by the
  player, not a crash. Deleting the `Routine` cascade-deletes its items only.

- **R6 — The player orchestrates existing per-unit engines; the new thing is the
  transition.** Each unit already has a run surface: `ExerciseRunView` /
  `ExerciseRunModel`, `LoopRunView` / `LoopRunModel` (ADR 0046), and a `Song`
  repertoire run is the existing waveform practice screen. The routine player
  runs the current item on its own engine, and on completion **advances to the
  next**, inserting `rest` blocks and showing session progress ("2 of 5"). It
  adds a session-level transport over unit-level engines; it does not
  reimplement them.

- **R7 — Budget/pacing accounting is pure and unit-tested.** The focused-only
  time budget and caps (ADR 0014 R1/R2 — only `focused` counts; 10–20 min
  blocks) and default rest insertion (R3) live in a pure, SwiftData-free module,
  like every planner rule. The model stores what a routine *contains*; the pure
  layer computes budgets and can *propose* rests. Reused later by the AI suggester
  (ADR 0002).

- **R8 — This ADR is the container + manual authoring + player. Generation stays
  deferred.** The planner (goals → candidates → ordered session, ADRs
  0014/0015/0016) is **out of scope here**: once built it becomes simply *another
  producer of a `Routine`*, emitting the same model this ADR defines. Keeping
  generation separate means the manual routine ships and is validated first, and
  the planner has a settled target to write into.

## Build slices

1. **Model** — `Routine` + `RoutineItem` (typed relationships, `order`, `kind`),
   pure ordering/budget helpers with tests. The missing piece ADR 0014 assumed.
2. **Manual authoring** — build a routine: add exercises/loops/songs, reorder,
   insert rests, name it. The user is the planner.
3. **Player** — run end-to-end: per-unit engine + cross-item transitions + rests
   + "N of M" progress.
4. **(V2) Generation** — the pure `buildSession` selection/ordering, in its own
   ADR building on 0014/0015/0016, emitting a `Routine`.

## Consequences

- Unblocks ADR 0014: `buildSession` now has a concrete output type to construct.
- Makes the exercise-inventory "Song → Loops → Exercises" pipeline real, and
  gives the Home screen its eventual **routine cards** (design brief §4, P3).
- Composes with templates (ADR 0065): a routine is a sequence of *typed*
  exercises, each rendering via its content template, so the two features
  multiply.
- Additive schema (new models + new relationships from `Exercise`/`Loop`/`Song`
  as inverses); device-verify the migration before merge (the SwiftData migration
  rule). Loop and Exercise already carry inverse relationships (journal); the new
  routine inverses follow the same additive shape.
- A `Song` repertoire item reuses the waveform screen as its "player," so the
  routine player must be able to **hand off to and return from** a full practice
  screen, not only the compact run screens — a transition to design in slice 3.

## Alternatives considered

- **Skip the container; build the planner (ADR 0014/0015) directly.** Rejected —
  the planner's output has nowhere to live, and auto-selection is unvalidated
  against a player that doesn't exist. Substrate before intelligence.
- **`RoutineItem` copies the unit's settings at add-time (snapshot).** Rejected
  for the unit reference — a routine should reflect the *current* state of a
  drill you keep improving; the journal already owns the "snapshot at a moment"
  job. (Per-item *overrides* — e.g. "run this loop at a fixed 80% here" — are a
  possible additive field later, not core.)
- **Generic `ownerKind + ownerID` for the unit reference.** Rejected per R4, the
  same call ADR 0058 made for journal ownership.
- **Model rest/warm-up as player-only concepts, not stored items.** Rejected —
  a manually-authored routine needs to *store* an explicit rest the user placed;
  making rests first-class items lets manual and generated routines share one
  representation (the player may still *propose* default rests via the pure
  layer, R7).
