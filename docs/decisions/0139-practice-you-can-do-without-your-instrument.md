# 0139 — Practice you can do without your instrument (the off-guitar session)

- **Status:** Proposed (2026-08-01)
- **Date:** 2026-08-01
- **Closes:** ADR 0138 §G6, both halves — the `ear.*` skills resolving to zero candidates, and
  `SkillMode.offGuitar` having no consumer. 0138 named them and fixed neither by design; this is the
  ADR they were waiting for.
- **Builds on:** ADR 0104 (ear training as a mode on a loop — *"an exercise they can do without an
  instrument in hand"*), ADR 0138 (a precondition belongs to the mode, not the material — the same
  move, applied again), ADR 0135 §B6 (a loop serving a skill directly, without a tag), ADR 0015 S5 /
  0073 (goal-driven candidate derivation), ADR 0129 (sessions sized in blocks), ADR 0116
  (multi-instrument — which is why the user-facing name isn't "off-guitar"), ADR 0136 (freeform
  blocks — the extension point in Slice 2), ADR 0070 / 0094 (nothing grades, nothing listens).

## Context

Two facts sit next to each other in the codebase and have never been introduced.

**First: ear training cannot be planned.** `SkillFamilyMap` maps the three `ear.*` skills to
`ExerciseTemplate.earTraining`, and that template is not in `creatable` — it was pulled on 2026-07-22
precisely because *"ear training shipped as a loop mode, not an exercise template (ADR 0104)"*. So no
player can own a unit that serves those skills, and `ear.relative-pitch`, `ear.transcribe` and
`ear.active-listening` resolve to **zero candidates**, permanently. The mode shipped; the planner was
never told.

**Second: the vocabulary for instrument-free practice already exists, unused.** `SkillMode.offGuitar`
sits on eight skills — all three `ear.*`, the three `know.*` theory skills, and songwriting — and
nothing anywhere branches on it. It has been a column in a table since the taxonomy was written.

Between them is the thing worth building. *"I have fifteen minutes and no guitar"* is a real,
frequent practice situation — a commute, a lunch break, a hotel room, an evening when the flat is
asleep — and it is one that no practice app answers, because every one of them assumes the instrument
is in your hands. Pocket already has the mode that works there and a taxonomy that can express it. It
just has no way to ask for a session made of it.

## Decision

- **O1 — Off-guitar is a property of the *mode*, not the material.** Exactly ADR 0138 §G1's move,
  applied to a second question. A loop is not off-guitar; *running a loop in ear mode* is.
  `LoopRunMode.ear` is off-guitar, `.trainer` and `.improvise` are not (improvise is the mode that
  most obviously needs the instrument). No flag is added to `Loop`, and no player bookkeeping is
  introduced — the same reasoning that rejected an ear flag in ADR 0138.

- **O2 — Audible loops serve the `ear.*` skills directly, with no tag.** The mirror of ADR 0135 §B6:
  a loop whose audio resolves is a candidate for the ear skills by virtue of *what it is*, not because
  the player labelled it. Path A gains this contribution the same way it gains B6's backing loops.
  Loops now serve skills three ways — by **tag** (ADR 0074), by **flag** (0135), by **capability**
  (here) — and the pattern is now deliberate rather than incidental.

- **O2a — Resolved as *ear blocks*, which means the run mode has to survive materialisation.**
  `PlannerCandidate` and `SessionBlock` carry no `LoopRunMode` today, so a loop resolved for an ear
  skill would be built as a trainer block and hand the player a ramp they cannot run away from their
  instrument. This is the **same change ADR 0135 §B6a needs** for backing loops; whichever of the two
  is built first owns it, and the second inherits it.

- **O2b — Deduplication stays keyed on the unit, not on unit-plus-mode.** `deriveCandidates` keeps the
  strongest claim per `PlannerUnitRef`; that must not become per-mode, or one loop could appear twice
  in a session — once to train, once to sing back. A unit appears at most once, and the winning claim
  brings its mode with it.

- **O3 — The off-guitar session is a *constraint on the existing planner*, not a second planner.** A
  `constraint` parameter on the session entry points, defaulted to none so every existing caller is
  unchanged. When it is `.offGuitar`, the candidate pool keeps only units runnable in an off-guitar
  mode, and loop blocks are pinned to `.ear`. Nothing about goal weighting, dueness, prerequisite
  softening or block packing changes — the same machinery, given a smaller pool.

- **O4 — Block sizing already works; ADR 0129 needs no change.**
  `PracticePlanner.estimatedMinutes(for:mode:plannedMinutes:)` already opens with
  `guard mode != .ear else { return estimatedMinutes(for: loop) }` — an ear block is priced by its
  region × repeats rather than by a ramp it doesn't have. The block model was written mode-aware and
  has simply never had a caller that exercised it.

- **O5 — It is called "Away from your instrument", never "off-guitar".** ADR 0116 made this a
  multi-instrument app, and a bassist should not be offered a session named for a guitar. The
  taxonomy's `offGuitar` case keeps its name in code — renaming a stable enum for a copy decision
  would be churn — but nothing user-facing says it.

- **O6 — Slice 2: a freeform block (ADR 0136) may declare itself off-guitar.** This is what makes the
  session more than three ear blocks, and it is the general extension point: transcription, note-name
  drilling, songwriting, a teacher's listening assignment all arrive as freeform blocks the player
  wrote. Crucially it is **player-declared, never inferred** — ADR 0136 §F8 holds exactly as written
  (the app knows nothing about the content), and a player ticking "I can do this without my
  instrument" is a statement, not a guess.

- **O7 — The theory and songwriting skills stay unresolvable, and that is honest.**
  `ExerciseTemplate.theory` is not in `creatable` either, so `know.notes`, `know.intervals`,
  `know.chord-construction` and `create.songwriting` have the same zero-candidate hole as the ear
  skills did. This ADR does **not** fix them, because unlike ear training there is no shipped mode
  behind them — fixing them means building a theory surface, which is ADR 0094 T1 territory and still
  deferred. O6 is the honest interim route: a player who wants note-name drilling writes a freeform
  block for it.

- **O8 — Nothing listens and nothing is graded (ADR 0104 E6 / 0070).** An off-guitar session is a
  sequence of things to attend to, self-judged as ever. No accuracy, no verdict, no tally — and
  specifically no drift toward the interval-quiz well ADR 0094 T2c warns about.

## Consequences

- **Ear training becomes a first-class training option rather than a feature you can find.** It gains
  the one thing it has never had: a reason for the app to hand it to you, at the moment it is the only
  practice available.
- **A session type nothing else offers.** Every competitor assumes the instrument is in your hands.
  This is the clearest product differentiation in the planner, and it costs a constraint parameter
  rather than a subsystem.
- **`SkillMode.offGuitar` gets its first consumer**, and the taxonomy stops carrying a column that
  describes nothing.
- **The session is only as good as the loop library.** A player with three loops gets a thin
  off-guitar session, and a brand-new player gets none at all. That is honest — it is built from the
  player's own material by design (ADR 0104's whole premise) — but it means this lands better for
  established users than for new ones, and the empty state has to say something useful rather than
  offering a session it cannot fill.
- **It shares its one structural change with ADR 0135.** Carrying `LoopRunMode` from candidate through
  `SessionBlock` into the materialised `RoutineItem` is needed by both; sequencing them adjacently
  avoids doing it twice.

## Alternatives considered

- **An `isOffGuitar` flag on units.** Rejected (O1) — the same mistake ADR 0138 unwound. It would make
  the player maintain bookkeeping that the mode already implies, and it would be wrong the moment a
  loop is run in two modes.
- **A separate `planOffGuitarSession` entry point.** Rejected (O3) — it is the same planner with a
  smaller pool. A parallel entry point would duplicate weighting, packing and dueness, and the two
  would drift.
- **Infer which freeform blocks are off-guitar from their text.** Rejected (O6) — ADR 0136 §F8 is
  explicit that the app knows nothing about freeform content, and guessing from prose is exactly the
  kind of quiet inaccuracy that is impossible to debug and mildly insulting when wrong.
- **Build a generic interval / theory trainer to give the `know.*` skills candidates.** Rejected
  (O7) — ADR 0104 rejected the decontextualised-drill framing for good reasons, and ADR 0094 T2c names
  the scored-quiz gravity well it drifts toward. If a theory surface is wanted it gets its own ADR.
- **Let the ear skills resolve to tagged loops only (the ADR 0074 route).** Rejected (O2) — it would
  require the player to tag loops with a skill bucket to make ear training plannable, which is
  bookkeeping in service of a capability every audible loop already has.

## Slices

- **Slice 1 — ear training becomes plannable, and the session type exists.** The `ear.*` Path-A
  contribution from audible loops, the run mode carried candidate → block → `RoutineItem` (shared with
  ADR 0135 §B6a), the `constraint` parameter, and the "Away from your instrument" option where
  sessions are chosen. Pure-side unit tests: an ear skill now resolves; a constrained pool excludes
  trainer-only units; a loop appears once, not twice.
- **Slice 2 — freeform blocks can be off-guitar.** Depends on ADR 0136. One player-set declaration on
  the freeform payload and its contribution to the constrained pool.

## Dependencies

- Slice 1 needs the `LoopRunMode`-on-block change that ADR 0135 slice 3 also needs — build them
  adjacently.
- Slice 2 needs ADR 0136 slice 1.
- Neither slice needs ADR 0137, though an off-guitar session ranks better with it (loops are the
  entire candidate pool here, and until 0137 lands every loop is permanently max-due).
