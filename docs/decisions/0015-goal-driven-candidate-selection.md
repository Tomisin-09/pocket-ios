# 0015 — Goal-driven candidate selection (the planner's front-half)

- **Status:** Accepted (principles recorded; build deferred to the Phase 3 planner)
- **Date:** 2026-06-18

## Context

ADR 0014 defines the planner's **transform**: `buildSession(availableMinutes:,
candidates:[PlannerCandidate], now:)` turns a *given* list of candidate practice
items into an ordered, time-boxed session (U-shaped ordering, spaced-repetition
selection, caps). It deliberately takes `candidates` as an **input** and says
nothing about where that list comes from. This ADR records the **front-half**: how a
user's intentions become that `[PlannerCandidate]` list.

Without this, "the planner" silently assumes a candidate set exists. In practice the
quality of a session is decided here — schedule the wrong items well and the session
is still wrong.

Source: guitargearfinder.com, *"How To Plan a Guitar Practice Routine"* (the
goal → required-skills → exercises → time-box method, and the argument that routines
should be **prioritised, not balanced**). As with ADR 0014, the takeaways below are
our **encodable distillation**; the article is rationale, not a dependency, and none
of its content (its worked example routines, its exercises) is used here — see
`docs/research/guitargearfinder-catalog.md` for the licence boundary.

This ADR keeps the rules in a **pure, SwiftData-free** module so they are
unit-testable and reusable by the AI suggester (ADR 0002), exactly like ADR 0014.

## Decision

Selection is a pipeline: **goals → required skills → candidate items → priorities**,
feeding ADR 0014. Seven rules govern it.

- **S1 — Goals are the root input, and they are ranked.** The user declares one or
  more **goals** (play a specific song, write songs, improvise in a style, master a
  technique, general progress) and the goals are **not equal** — the user weights/orders
  them. Everything downstream is derived from the active, weighted goals.

- **S2 — Goals decompose into required skills, drawn from a defined taxonomy.** Each
  goal maps to a set of **skills/techniques** taken from the project's technique
  taxonomy (`docs/practice-techniques.md`). E.g. a fast metal solo → alternate picking,
  sweeps, legato; blues improv → pentatonic/blues vocabulary, bends, ear. The taxonomy
  is the controlled vocabulary that makes this mapping consistent across manual and AI
  planning.

- **S3 — Skills resolve to candidate *slots*, which the user fills with their own
  material.** Each required skill yields candidate items the planner can schedule — a
  **loop** in one of the user's songs, a **speed-trainer ramp** (ADR 0013), a technique
  **drill**, a **repertoire** run-through. Pocket provides the *slot per skill*; the user
  attaches their own audio/loops to it. **We never ship third-party exercises to fill a
  slot** (that would be licence-gated, per the catalog); a built-in content library is a
  separate, future, opt-in decision (see Alternatives).

- **S4 — Prioritised, not balanced (the core principle).** The candidate set is shaped
  by the **current goals**, not by an even split across all skill areas. A skill that
  serves no active goal is **excluded or down-weighted** — we do not pad a session to
  "cover everything." This is the explicit rejection of the balanced-routine default and
  is what makes the session feel purposeful rather than diffuse.

- **S5 — Priority = goal weight × due-ness.** ADR 0014's R6 ranks candidates by a
  **due score** (rises with time since last practised, falls with proficiency). S5 fixes
  what feeds R6's `priority`: it is the **goal weight** the skill inherits (S1/S4). So the
  item actually selected is the one that is both **goal-relevant and due**. This is the
  precise coupling between this ADR and ADR 0014.

- **S6 — The set is re-derived as goals and proficiency change.** Goals are editable.
  As a song's **proficiency** rises (ADR 0012) or a goal is met, its skills decay in
  priority and other skills surface. Selection is a function of current state, recomputed,
  not a frozen list.

- **S7 — Modest by default; start with one near-term goal.** Mirroring ADR 0014's R8
  (build up, don't default to elite volume): the default is a **single, concrete,
  near-term goal** and a small candidate set — not a full skill matrix. Beginners get a
  focused start, not an overwhelming curriculum.

### Shape of the pure logic (doubles as the test spec)

A pure function, no SwiftData / SwiftUI imports, producing the input ADR 0014 consumes:

```
deriveCandidates(goals:[Goal], taxonomy:, history:, now:) -> [PlannerCandidate]
```

- `Goal` carries `id`, `weight`, `requiredSkills:[SkillID]`, optional `targetSong`.
- `SkillID` indexes the technique taxonomy (`docs/practice-techniques.md`).
- Output is ADR 0014's `PlannerCandidate` (`id`, `priority`, `proficiency`,
  `lastPracticed?`, `estimatedMinutes`) — so `deriveCandidates` then `buildSession`
  compose into the full planner.
- Pipeline: **expand** active goals → required skills (S2) → **resolve** each skill to
  candidate slots bound to the user's material (S3) → **weight** by goal × due-ness
  (S4/S5) → drop unaffiliated skills (S4) → hand to `buildSession`.

Properties to assert (the unit tests): a skill with no active goal produces no
candidate; a higher-weighted goal yields higher-priority candidates; marking a goal met
removes its candidates on the next derivation; proficiency rising lowers a skill's
priority; an empty goal list yields an empty (not arbitrary) candidate set.

## Where it attaches

- **A new lightweight `Goal`** (Phase-3 model) holds weight + required skills + optional
  target song; required skills reference the taxonomy.
- **`PracticeStep`/`RoutineItem` priority** (the field ADR 0014 added) is *computed* from
  goal weight here, not hand-set in isolation.
- **The AI suggester (ADR 0002)** may propose goal→skill mappings and goal weights, but
  the same S-rules bound it — AI proposes *content*, these rules enforce *selection*,
  exactly as ADR 0014 bounds *structure*.

## Consequences

- "Where do candidates come from?" — left open by ADR 0014 — now has a concrete, testable
  answer (S1–S5) that composes cleanly: `deriveCandidates` → `buildSession`.
- The **technique taxonomy becomes a first-class artifact** (`docs/practice-techniques.md`),
  shared by selection (S2), the speed-trainer staging (ADR 0016), and the AI suggester.
- Pocket stays an **engine, not a content product**: it supplies skill slots; the user
  supplies material. This is the architectural reason the roadmap needs **no content
  licence** (see the catalog's "key triage finding").
- A `Goal` model is needed in Phase 3; recorded here so it is designed in from the start.

## Alternatives considered

- **Balanced / even-split routines** — rejected: the source's central argument, and it
  conflicts with ADR 0014's R5/R6 (a balanced set buries goal-relevant work). S4 is the
  whole point.
- **A fixed, one-size curriculum** — rejected: goals differ per user; a shared syllabus
  ignores S1.
- **Letting the AI freely choose candidates** — rejected: selection lives in shared pure
  logic so manual and AI sessions obey the same guardrails (parallels ADR 0014).
- **Shipping a built-in exercise library to auto-fill skill slots** — **deferred, not
  adopted.** Doing it with a third party's exercises is licence-gated (catalog). The
  intended direction is to **build first-party content in-house** so slots can ship
  pre-filled without a licence; that is a future strategy, recorded in the catalog, not a
  dependency of this ADR. Today, slots are user-filled.
