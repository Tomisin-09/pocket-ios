# 0137 — Dueness comes from the log (so a loop can finally be due)

- **Status:** Proposed (2026-08-01)
- **Date:** 2026-08-01
- **Closes:** ADR 0135 §B10, which recorded this as a limitation of the backing-track planner slice
  rather than fixing it there — the defect is planner-wide, not specific to backing loops.
- **Builds on:** ADR 0117 (the practice log — one append-only row per completed unit-run, with
  `unitUID` and `startedAt`), ADR 0015 S5 (`DueScore` — the selection formula), ADR 0104 (ear-training
  runs log as `.earLoop`), ADR 0135 (improvise runs will log as `.improvise`), ADR 0070 (mastery is
  self-rated and never auto-decayed; time is the only thing that moves on its own).

## Context

The planner ranks candidates with:

```
dueScore = goalWeight × dueness(lastPracticed, now) × (1 − mastery/5)
```

`dueness(nil)` returns `1.0` — max due — which is the correct cold-start answer for something never
practised. But **`Loop` has no `lastPracticed` field at all**, and `PracticePlanner.library` hard-codes
`lastPracticed: nil` for every loop it projects. So for every loop candidate the time term is
permanently pinned at maximum and the formula collapses to `goalWeight × (1 − mastery/5)`. A loop
practised this morning ranks exactly level with one untouched for a year, and no amount of practice
ever moves it. Exercises and songs carry the field and get the real formula.

This became load-bearing rather than cosmetic once loops started resolving goals: ADR 0135 §B6 makes
backing loops the unit behind "Improvise in a style", and ADR 0104's ear blocks are loops too. A
planner axis that can't tell yesterday from last year is not a ranking.

There is a second, quieter fact worth surfacing before choosing a fix. `Exercise.lastPracticed` means
**"a run started"** — `markPracticed()` is called from `commitAndStart()`, at the moment the player
hits start — whereas `PracticeLogWriter` writes only on *natural completion*, and a hand-stopped run
logs nothing at all. These are two different questions, and any derived answer necessarily picks the
second one.

## Decision

- **D1 — Loop dueness is derived from the practice log, not stored on `Loop`.** No new stored field,
  no migration, and — because ADR 0117's rows are already being written — it is **retroactive**: the
  day this ships, every existing `.loop` and `.earLoop` row starts contributing real dueness.

- **D2 — The derivation is pure and lives in `PracticeLog`.** A `lastPracticedByUnit([SessionRecord])
  -> [UUID: Date]` helper: group by `unitUID` (skipping `nil`), take the maximum `startedAt`.
  `PracticeLog` is already *"the pure aggregation layer over the practice log… UI-free and
  SwiftData-free on purpose"* whose callers *"run their `@Query`, map to `SessionRecord`, and hand the
  array here"*, and `SessionRecord` already carries both fields this needs. Being pure, it is
  unit-tested, which AGENTS.md requires of exactly this kind of logic.

- **D2a — Every run kind counts, and the mode is not distinguished.** A `.earLoop` row makes its loop
  less due as a trainer, and an `.improvise` row will too. The question dueness asks is *when did you
  last work on this material*, not *in which mode* — and per-kind dueness would let a loop you sang
  back yesterday claim to be untouched, which is plainly false and would resurface it against a loop
  you genuinely haven't seen.

- **D3 — The planner boundary takes it as an input.** `PracticePlanner.library(exercises:loops:songs:)`
  gains a `lastPracticed: [UUID: Date]` parameter, **defaulted to empty** so every existing caller and
  test compiles unchanged and behaves exactly as today; `PlannerLoop.lastPracticed` is filled from it
  instead of `nil`. The two live call sites (`PlannerView`, `RoutineLibraryView`) `@Query` the log and
  pass the map down, keeping the planner itself Foundation-only.

- **D4 — Derived means *completed*, and that is the intended definition.** Dueness should measure work
  done, not screens opened. A hand-stopped run logs nothing (`PracticeLogWriter`'s own rule — *"an
  aborted run has no honest length or tempo to claim"*), so it does not reset dueness either, which is
  the right answer: opening a loop and bailing is not practice, and pretending otherwise would let a
  player silently bury a drill they keep avoiding.

- **D5 — Exercises are deliberately *not* switched over here.** They work today. Moving them from
  "started" to "completed" is a live ranking change for every existing install, in the opposite
  direction from this one — loops go from broken to working, exercises would go from working to
  subtly different. Bundling them would hide a behaviour change nobody asked for inside a fix.
  **Accepted consequence:** until that follow-up, exercise dueness and loop dueness answer slightly
  different questions. That is a documented inconsistency, not an invisible one, and it is strictly
  better than today's "loops have no answer at all".

- **D6 — Cost is a dictionary built per plan, and that is fine.** A session is planned on demand — not
  per frame — and the log is append-only with one row per unit-run. Grouping it once per plan is
  cheap at any plausible size. No index, no cache, no incremental maintenance until there is evidence
  one is needed; adding them now would be speculative complexity in the layer that most needs to stay
  pure.

- **D7 — This makes ADR 0117's write path a planner concern, not only a stats one.** If a completion
  seam fails to log, its unit reads as never-practised and therefore **max due** — it surfaces *more*,
  not less, so the failure is in the fail-safe direction. But it is still a wrong ranking driven by a
  missing row, and ADR 0117's write path has not yet been store-verified end-to-end. Verifying it is
  now worth doing for two reasons instead of one.

## Consequences

- **Loops start ranking on time, and every mode contributes for free.** Because everything goes
  through the single `PracticeLogWriter` seam, ear-training and improvise runs count without a line of
  planner code being written for them — including modes not yet built.
- **The fix is retroactive.** Testers who have been practising with ADR 0117's log running get real
  dueness immediately, with no backfill step.
- **A mastery-5 loop stays retired regardless.** Its `(1 − 5/5) = 0` term still zeroes the score; this
  ADR changes only the time half. Nothing here re-surfaces something the player has declared owned.
- **A deleted-and-recreated unit reads as never practised.** The log's references are loose `uid`
  copies that deliberately outlive their units (ADR 0117), so a new unit with a new `uid` will not
  inherit the old one's rows. Correct, and worth stating so it isn't later reported as a bug.
- **One more consumer of the log means it is now load-bearing twice over.** Progress screens
  mis-reporting is visible and self-correcting; ranking mis-reporting is silent. That asymmetry is the
  argument for D7.

## Alternatives considered

- **A stored `Loop.lastPracticed`, stamped at run start (mirroring `Exercise`/`Song`).** Rejected —
  it needs stamping at three seams today (trainer, ear, improvise) and one more every time a mode is
  added, which is exactly the kind of obligation that quietly stops being met. It would also
  denormalise a fact the log already holds, creating a second source of truth that can drift from the
  first with nothing to reconcile them.
- **Have `PracticeLogWriter` stamp the model as a side effect.** Rejected despite being the tidiest
  single-seam option: the writer takes a loose `unitUID` *precisely* so rows outlive the units they
  describe, and handing it live models to mutate couples the append-only log to the object graph it
  was designed to survive.
- **Per-kind dueness (a loop is separately due as trainer / ear / improvise).** Rejected (D2a) —
  over-fine, and it produces claims that are simply untrue about material the player worked on
  yesterday.
- **Switch exercises to the derived value in the same change.** Rejected (D5) — a real ranking change
  smuggled inside a repair. It is the obvious follow-up and should be argued on its own merits.
- **Leave it and rank loops on mastery alone.** Rejected — that is today's behaviour, and it means
  ADR 0135 §B6's improv resolution and ADR 0104's ear blocks both surface material in an order that
  ignores when the player last touched it.

## Slices

- **Slice 1 — the whole thing; it is one change.** `PracticeLog.lastPracticedByUnit` with its unit
  tests (including: multiple kinds for one unit, `nil` `unitUID` skipped, latest-wins), the defaulted
  `lastPracticed:` parameter on `PracticePlanner.library`, and the two call sites querying the log.
  Verifiable by a planner test that ranks two loops of equal mastery and different recency.

## Follow-ups (not in scope)

- **Move exercises onto the derived value too** (D5) — its own decision, its own ADR.
- **Verify ADR 0117's write path end-to-end on device** (D7) — now a prerequisite for trusting
  ranking, not only stats.
- **Song dueness** is untouched here: `Song.lastPracticed` is stored and stamped, and play-alongs log
  as `.song`, so the same derivation would work — but nothing is broken there today.
