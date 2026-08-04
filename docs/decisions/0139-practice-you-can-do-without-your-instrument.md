# 0139 — Practice you can do without your instrument (the off-guitar session)

- **Status:** Accepted — **Slice 1 built** 2026-08-02 on
  `pocket-224-improvise-planner-and-off-guitar`, alongside ADR 0135 Slice 3, which shares its one
  structural change. **Slice 2 built** 2026-08-04 on `pocket-227-freeform-blocks`, immediately after
  the ADR 0136 slice it waited on. See §Build notes.
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

- **Slice 1 — ear training becomes plannable, and the session type exists. ✅ BUILT.** The `ear.*`
  Path-A contribution from audible loops, the run mode carried candidate → block → `RoutineItem`
  (shared with ADR 0135 §B6a), the `constraint` parameter, and the "Away from your instrument" option
  where sessions are chosen. Pure-side unit tests: an ear skill now resolves; a constrained pool
  excludes trainer-only units; a loop appears once, not twice.
- **Slice 2 — freeform blocks can be off-guitar. ✅ BUILT.** Depends on ADR 0136. One player-set
  declaration on the freeform payload and its contribution to the constrained pool.

## Build notes — Slice 1 (2026-08-02)

- **The constraint *pins* surviving loops rather than filtering them, and that is what makes the
  session reachable.** O3 says the pool "keeps only units runnable in an off-guitar mode" and that
  loop blocks "are pinned to `.ear`", which reads as two steps but is really one: a repertoire goal's
  loops arrive as **trainer** candidates, so a filter-first reading would have dropped them and left
  the constrained pool empty for every player whose goals are about songs and technique — i.e. almost
  everyone, since the taxonomy has three ear skills and twenty-eight others. Pinning first, then
  qualifying against `LoopModeAccess`, is what lets "learn Little Wing" contribute its sections as
  ear work. A pinned loop still has to qualify: a loop with no playable audio survives nothing.

- **The goal-less Quick path takes the constraint too.** O3 says "the session entry points", plural,
  but the Quick path projects only exercises, so under a constraint it would have produced nothing —
  and *"I have fifteen minutes and no guitar"*, the ADR's own headline case, is not a situation that
  waits for the player to have written a goal. `planQuickSession` gains defaulted `loops:` and
  `constraint:` parameters and, when constrained, builds its pool from the library's loops through
  the same `CandidateDeriver.constrained` used by the goal path. Unconstrained, it ignores loops
  entirely and is byte-for-byte the session it was.

- **No warm-up in a constrained session.** Not stated in the ADR, and it follows from O3 rather than
  extending it: the warm-up pool is `template == .warmup` **exercises**, every one of which wants the
  instrument in your hands. The structure is unchanged; the pool it draws from is empty.

- **The consequence about the empty state was taken literally.** A constrained session that resolves
  nothing gets its own notice, pointing at loops. The unconstrained copy tells the player to add an
  exercise or give a goal a target song — advice that would send an off-guitar player to build
  something this session cannot use.

- **It names itself.** A generated off-guitar session defaults to "*d MMM* Listening Session" rather
  than "Quick Session". It lands in the routine library beside the others and will be re-run from
  there, so a player deciding what to open on a train has to be able to tell them apart. Never
  "off-guitar" (O5).

- **`SkillMode.offGuitar` still has no direct consumer, and the ADR is satisfied anyway.** The
  taxonomy column that prompted this decision is *not* what the constraint branches on — the
  constraint asks `LoopRunMode`, per O1's "off-guitar is a property of the mode, not the material".
  The column's real payoff is O7's honesty: it is how you can see at a glance that the four `know.*`
  and `create.*` skills sharing it are still unresolvable, and that Slice 2 is where they get an
  answer.

## Dependencies

- Slice 1 needs the `LoopRunMode`-on-block change that ADR 0135 slice 3 also needs — build them
  adjacently.
- Slice 2 needs ADR 0136 slice 1.
- Neither slice needs ADR 0137, though an off-guitar session ranks better with it (loops are the
  entire candidate pool here, and until 0137 lands every loop is permanently max-due).

## Build notes — Slice 2 (2026-08-04, `pocket-227-freeform-blocks`)

Built on the same branch as the ADR 0136 slice it depends on, and it is genuinely small — one stored
`Bool`, one projection field, one branch in `constrained`, and a toggle in two places. What took the
thinking was where it *couldn't* work.

- **`constrained` was the wrong shape by one word, and the fix is an exception rather than a rule.**
  Its guard read `candidate.unit.kind == .loop`, i.e. *drop every exercise* — which O3 states as
  "drop anything that needs the instrument". Those are the same sentence only while every exercise
  does need it. A declared freeform block now survives with **no mode and no pinning**, because it has
  neither: pinning exists to turn a trainer loop into ear work, and a freeform block has no mode to
  turn. So it is a genuinely separate branch, not a widened predicate.

- **The declaration is read through a gate, never raw.** `Exercise.awayFromInstrument` is the stored
  flag; `Exercise.declaresAwayFromInstrument` is `template == .freeform && awayFromInstrument`, and
  that is what the projection calls. A flag left behind on a modelled drill therefore means nothing —
  which matters because the toggle only appears on a freeform surface, so any other value could only
  ever be a leftover or a bug. A test pins both directions.

- **The goal path can't reach this, and that is correct rather than a gap.** ADR 0136 F5 makes a
  freeform block **goal-invisible**, so `deriveCandidates` never produces one and no amount of work in
  `constrained` would surface it from a goal. The route is the **goal-less Quick path**, which slice 1
  had already taught to take the constraint. That path was passing `exercises: []` — deliberately, per
  slice 1's "no warm-up in a constrained session" note — so slice 2's real change is that it now
  projects the exercise library and lets `constrained` do the qualifying. The warm-up reasoning is
  unaffected: warm-ups are `template == .warmup`, `PracticePlanner.library` filters them out of the
  pool entirely, and none of them could be freeform anyway.

  The consequence worth stating: a declared freeform block reaches an off-guitar session **only**
  through Quick. A player whose goals are all technique still gets their loops as ear work and their
  freeform blocks alongside, because Quick is what "I have fifteen minutes and no guitar" actually
  taps. If that ever feels wrong, the fix is in ADR 0136 F5's goal-invisibility, not here.

- **O7 gets its interim answer.** `know.notes`, `know.intervals`, `know.chord-construction` and
  `create.songwriting` still resolve to zero candidates, exactly as O7 says they honestly should. What
  changed is that a player who wants note-name drilling can now write a freeform block for it, tick
  the box, and have it turn up when they're on a train — without the app claiming the block serves
  those skills. That is the whole of O7's "honest interim route", and it is now real.

- **Copy: the toggle explains why it is being asked.** *"I can do this without my instrument"*, with a
  footer that says the app **can't tell from what you wrote, so it's your call**. That sentence is
  doing O6's work — it is the difference between a preference and a guess, and it pre-empts the
  reasonable question of why the app is asking something it could seemingly infer.

**Verification (slice 2):** `swiftlint --strict` clean, generic-simulator build clean, **1818 tests
pass** including 6 new `FreeformOffInstrumentTests` covering the declared/undeclared split, the
template gate, the projection seam, and the unconstrained fast path.
