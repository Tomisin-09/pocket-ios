# 0074 — Loop skill-tag enrichment

- **Status:** Accepted
- **Date:** 2026-07-08
- **Extends:** ADR 0073 (planner candidate resolution — Path A / the coarse `SkillFamilyMap`), ADR 0034
  (loop tags). Pairs with ADR 0015 (goal → candidate selection), ADR 0070 (no grading).
- **Supersedes:** nothing.

## Context

ADR 0073 gave the planner two resolution paths: **Path A** routes a technique goal to the user's
**exercises** (via the coarse `ExerciseTemplate → [SkillID]` family map), and **Path B** routes a
repertoire goal to a target song's **loops + song run**. A loop could therefore only reach a session
by being part of a "learn this song" goal — a *picking* goal never surfaced a picking-heavy loop the
user had isolated, even though a measured loop is often the best drill for a technique. This is the
last planner enrichment slice (Decision 8 of the 2026-07-08 build plan); AI decomposition (Slice 5)
stays out of scope.

## Decision

### 1. Loops opt into Path A by carrying a recognised skill-bucket tag

We reuse the existing free-form `Loop.tags` (ADR 0034) rather than adding a new field or a
per-loop skill relationship. A tag is recognised as a **skill bucket** when it case-insensitively
matches one of the `ExerciseTemplate` display names that carry skills — the *same* ~10 coarse buckets
as the exercise family map (`SkillFamilyMap.taggableTemplates`; `.basic` and `.warmup` are excluded,
exactly as in the map). `SkillFamilyMap.recognizedTemplate(for:)` does the match; unrecognised tags
("chorus", "needs-work") route nothing, so the descriptive-tag vocabulary is unharmed.

The loop tag editor (`LoopEditSheet`) surfaces these as a distinct, always-present ✨ suggestion row
(separate from the library-wide descriptive suggestions), so the user picks canonical names the
planner will actually recognise rather than guessing.

### 2. Path A also matches tagged loops, weighted identically to exercises

`CandidateDeriver` Path A now, in addition to exercises, includes any loop whose recognised template
serves the skill (`loop.templates.contains { SkillFamilyMap.template($0, serves: skillID) }`). A
Path-A loop candidate carries the *same* goal-weight-times-prereq-readiness priority as an exercise
candidate for that skill, plus the loop's own mastery/recency (so the back-half's dueScore composes
as before). A loop surfaced by both a technique goal (Path A) and a repertoire goal (Path B) keeps
its **strongest** claim through the existing max-priority dedup — no double-count.

The recognised templates are projected onto the pure `PlannerLoop.templates` by the impure
`PracticePlanner` (the tag→template parse lives with the projector, keeping the deriver reasoning over
values), deduped and order-stable.

### 3. Untagged loops are unchanged; loops don't establish prerequisite mastery

An untagged loop carries no templates and stays **Path-B only** — no behaviour change for anyone who
never tags. And `prereqMet` (Decision 6) still averages **exercise** mastery only: a loop's mastery
is repertoire mastery of a passage, not a portable technique rating, so a tagged loop does not lift a
skill's prerequisite readiness. A bounded, defensible V2 choice — revisit if loops become a primary
drill source.

## Consequences

- **Positive:** a measured loop can now be a first-class technique drill, not just a song fragment;
  zero new schema (reuses `Loop.tags`), zero migration; opt-in and coarse, so it never overwhelms;
  fully pure and unit-tested (recognition round-trip + Path A matching). The suggestion row makes the
  canonical vocabulary discoverable.
- **Negative / accepted:** matching stays template-coarse (a "Picking"-tagged loop answers *any*
  picking skill, like exercises do); recognition is name-based, so a typo'd tag simply isn't
  recognised (no fuzzy match); loops don't count toward prereq readiness.
- **Deferred:** the AI suggester (Slice 5, out of scope) would only auto-suggest these same tags.
