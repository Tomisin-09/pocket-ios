# 0073 — Planner candidate resolution & soft prerequisite staging

- **Status:** Accepted
- **Date:** 2026-07-08
- **Extends:** ADR 0015 (goal → candidate selection). Pairs with ADR 0072 (self-rated mastery +
  dueScore), ADR 0014 (session transform), ADR 0016 (speed staging), ADR 0070 (no grading).
- **Supersedes:** nothing.

## Context

ADR 0072 built the planner's **back-half** (`buildSession`: a ranked candidate list → a timed,
U-shaped, rest-punctuated session) and gave `Exercise` a self-rated `mastery`. This ADR records the
**front-half** decisions (V2 planner Slice 2): how a user's **goals** become that ranked candidate
list — `deriveCandidates(goals, library) → [PlannerCandidate]`. Both halves are pure /
Foundation-only so they unit-test and can later back an AI producer (ADR 0002, deferred).

The design questions this closes (locked in the 2026-07-08 planner build plan, Decisions 4–7):

1. How do a user's coarsely-typed exercises satisfy a fine-grained skill goal?
2. How does a repertoire ("learn a song") goal resolve, versus a technique goal?
3. What happens when a goal targets an advanced skill whose prerequisites are unpractised?
4. Where do a goal's skills come from, given there is no AI in V2?

## Decision

### 1. Broad, template-level skill resolution — no per-exercise tagging (Decision 4)

The taxonomy (`docs/practice-techniques.md`, encoded as the pure `TechniqueTaxonomy` table) is
fine-grained (`pick.alternate`, `pick.sweep`, …). The user's exercises are classified only by the
coarse **`ExerciseTemplate`** (one `.picking` bucket). We bridge with a static
**`SkillFamilyMap` (`ExerciseTemplate → [SkillID]`)**: a Picking exercise serves *every* picking
skill. So a "sweep picking" goal surfaces **all** the user's Picking drills, not sweep-specifically.
This is an accepted V2 tradeoff — the alternative (per-exercise skill tags) is more authoring burden
than a V2 warrants, and is refinable later (loop tags are already the Slice-4 path). `.basic` and
`.warmup` carry no skills: Basic is a catch-all click drill, Warm-up is structural (Decision 3,
ADR 0072 — LRU-placed, never due-scored).

### 2. Two resolution paths, routed by the taxonomy `default mode` (Decision 5)

- **Path A — technique → Exercise.** For the four technique modes (`speedRamp` / `loopDrill` /
  `metronome` / `offGuitar`), a skill resolves to library exercises via the family map.
- **Path B — repertoire → Loop/Song.** For `repertoire` mode, the skill resolves to the goal's
  **`targetSong`**: its loops **plus** the song run itself, contributed directly (not skill-matched).
  This mirrors the technique-vs-repertoire duality already in the model (exercises = portable
  technique; loops/songs = repertoire bound to a recording).

A skill with no active goal yields no candidate (S4). A unit surfaced by several goals keeps its
**strongest** claim (max priority), never a double-count.

### 3. Prerequisites are a SOFT down-weight, never a hard gate (Decision 6)

A skill whose **direct** prerequisites are unrated or low-mastery has its goal weight *reduced*
(`prereqPenalty = 0.6` per unmet prereq, compounded, clamped to `prereqFloor = 0.3`), **not**
excluded. A prereq counts as met once the user's exercises for it average `mastery ≥ 2`. This is the
deliberate reconciliation of ADR 0016 (clean-before-fast) with ADR 0071 (the player's "controlled
discomfort") at the **selection** level: the advanced thing still appears if the goal weights it
hard — just later in the U-shape. The app never refuses to schedule what the user explicitly asked
for. At cold-start (everything unrated) this simply ranks no-prereq beginner skills first, which is
the desired staging. Only direct (one-level) prereqs are considered — a bounded, testable V2 scope.

Crucially, the **dueScore multiply** (recency × need, ADR 0072) is *not* applied in the deriver — it
stays in `SessionBuilder.select`, so `priority` (goal-derived) and dueness/mastery (unit-derived)
compose exactly once. Higher mastery therefore ranks a unit lower via dueScore, not via priority.

### 4. Goal skills come from in-house goal templates, not AI (Decision 7)

The goal editor (Slice 3) offers curated **`GoalTemplate`s** matching ADR 0015 S1's own examples
("Play a specific song", "Build speed", "Improvise in a style", "General progress"). Each pre-seeds a
sensible `[SkillID]` set the user trims; a repertoire template additionally asks for a target song.
All copy is authored in-house — encode the method, ship none of anyone's content. AI would later just
auto-fill the same skill set from free text, bounded by these same rules.

## New model

`Goal` (`@Model`): `uid`, `title`, `weight: Double = 1.0`, `skillIDs: [String]` (indexes the
taxonomy — a scalar array, **never a stored enum**, per the SwiftData enum-attribute migration rule),
`targetSong: Song?` (typed optional relationship, nullify delete — ADR 0058/0066 R4), `isMet: Bool`,
`dateAdded`. Additive/optional throughout ⇒ lightweight migration.

`Song` has **no stored `uid`** (its identity is the file `SongRef.sourceID`). Rather than a
migration-risky new column, the planner keys song candidates by a **deterministic** UUID derived
from `sourceID` (`PlannerID.uid(from:)`, an FNV-1a spread) so the pure projector and the impure
materialiser agree on a song's id without sharing state.

## Consequences

- **Positive:** front-half composes with the back-half end-to-end; a real goal produces a runnable
  session. Pure and fully unit-tested. No schema change to `Song`. Coarse matching keeps authoring
  cost near zero.
- **Negative / accepted:** template-level matching can't distinguish sweep from alternate picking
  within the Picking bucket; direct-only prereq staging ignores transitive chains; song-candidate
  ids rely on a deterministic hash rather than a stored key (negligible collision risk for a personal
  library). All are refinable post-V2.
- **Deferred:** the goal-editor UI (Slice 3), loop skill-tag enrichment (Slice 4, its own ADR), and
  the AI suggester (Slice 5, out of scope).
