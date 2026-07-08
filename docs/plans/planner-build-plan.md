# Practice planner — cold-start build plan (ADRs 0014 / 0015 / 0016)

**Purpose.** A pick-up-cold execution plan for the V2 **practice planner** — the
"intelligence" that automatically produces a `Routine` — written while the design
context was rich so a later session can build without re-deriving anything. Pairs
with **ADRs 0014** (session transform), **0015** (goal → candidate selection), and
**0016** (speed staging), the taxonomy at `docs/practice-techniques.md`, and the
shipped routine substrate (ADR 0066, `docs/plans/routines-build-plan.md`).

Branch: **`pocket-109-practice-planner`** (created off `main`).

**Status when written (2026-07-08):** branch created, nothing implemented yet.
Slice 1 is next. The routine model + player + presets are **already shipped**
(PR #102); the planner is a *producer* of that shipped `Routine`.

---

## 1. The concept in one paragraph

The planner turns *(what you want to get better at, how many minutes you have, now)*
into a ready-to-run **`Routine`** — the same object you can already build by hand and
run in the shipped player. It is **two pure functions that compose**:
`deriveCandidates(goals, taxonomy, history, now) → [PlannerCandidate]` (the
"front-half", ADR 0015: turns goals into a ranked list of things to practise) feeding
`buildSession(minutes, candidates, now) → [SessionBlock]` (the "back-half", ADR 0014:
lays that list out into a timed, ordered, rest-punctuated session). The result is
materialised into a `Routine` and handed to the **existing** player. Both functions
are **SwiftData-/SwiftUI-/AVFoundation-free** so they unit-test cleanly and can later
be re-used by the AI suggester (ADR 0002) — which is deferred and NOT part of this
plan. Substrate before intelligence, exactly as the routine model was built.

**Why no AI here:** the deterministic rules ARE the planner; AI is only an optional
future *producer* of the same candidate/session inputs, bounded by these same rules.
The planner ships fully local-first with zero backend. AI adds only free-text goal
decomposition later — a nicety on top, not load-bearing.

---

## 2. Decisions locked this session (2026-07-08)

These close off alternatives — each becomes an ADR (see §8). Build to them.

1. **Self-rated proficiency, not derived/graded.** The dueScore's proficiency term is
   the player's own **self-rating**, never the app measuring how well they played
   (ADR 0070 no-grading wall). This is NOT a reintroduction of the removed
   song-proficiency — it *extends the shipped `Loop.mastery` pattern* (ADR 0039:
   `Int?` 0–5, `nil` = unrated) to `Exercise`, which currently has neither a mastery
   nor a last-practiced field.

2. **The dueScore formula (the whole selection ranking):**
   ```
   dueScore(item, now) = goalWeight(item)              // ADR 0015 S5 — from the goal
                       × dueness(lastPracticed, now)    // rises with time since practised
                       × (1 − mastery/5)                // falls as the player rates it settled
   // unrated ⇒ treat as max-due (good for cold-start); no goal ⇒ item excluded (S4)
   ```
   **Static rating, time-driven resurfacing:** `mastery` is a pure stored
   self-assessment that the app NEVER auto-decays; the `dueness(lastPracticed)` term
   alone brings well-learned items back over time. (We never silently lower a number
   the player set — that would breach 0070's spirit.)

3. **Warm-up is structural, never due-scored.** A `RoutineItem` sits on two
   independent axes: the **structural** axis (`kind`: warmup/focused/play/rest —
   position + budget) and the **selection** axis (dueScore — ranks the *focused* pool
   only). Warm-up/play/rest are *placed by rule*, never scored. Warm-up leads, is
   **unbudgeted** (already implemented in `RoutineBudget`), and is sourced from
   exercises whose **`template == .warmup`** (the marker already exists —
   `ExerciseTemplate.warmup`), chosen by **least-recently-used** rotation on
   `lastPracticed` (NOT dueScore — a warm-up's job is loosening up, not targeting a
   weakness). Cold-start: `RoutinePresets` already seeds warm-up content; if none
   exists, the planner simply omits the warm-up block.
   > Note the elegant reuse: the new `Exercise.lastPracticed` feeds *dueness* on the
   > focused axis and *rotation* on the warm-up axis — same field, two rules.

4. **Broad (template-level) skill resolution — NO new per-exercise tagging.** Taxonomy
   skills are fine-grained (`pick.alternate`, `pick.sweep`, …); the user's exercises
   are classified only by the coarse **`ExerciseTemplate`** (one `.picking` bucket
   covers all picking skills). We bridge with a static, in-house
   **`ExerciseTemplate → [SkillID]` family table** (pure data). A "sweep picking" goal
   therefore surfaces *all* the user's picking exercises, not sweep-specifically —
   accepted V2 tradeoff. Refinable later with optional skill tags; not now.

5. **Two resolution paths, routed by the taxonomy `default mode` column:**
   - **Path A — technique skill → Exercise** via the family table above
     (`speed-ramp` / `loop-drill` / `metronome` / `off-guitar` modes).
   - **Path B — repertoire → Loop/Song** via the goal's **`targetSong`**
     (`repertoire` mode; a target song contributes its loops + the song run directly,
     not via skill matching). Mirrors the technique-vs-repertoire duality already in
     the model (exercises = portable technique; loops = repertoire bound to a
     recording).

6. **Prereqs are a SOFT down-weight, not a hard gate.** A skill whose taxonomy
   `Prereqs` are unrated/low-mastery gets its priority *reduced*, not *excluded*. This
   is the deliberate reconciliation of ADR 0016 (clean-before-fast) with ADR 0071
   (the player's "controlled discomfort") — the advanced thing still appears if the
   goal weights it hard, just later in the U-shape. The app never refuses to schedule
   what the user explicitly asked for. (Capture in the planner-selection ADR.)

7. **Goal skills come from in-house goal templates, not AI.** The goal editor offers
   curated **goal templates** matching ADR 0015 S1's own examples ("Play a specific
   song", "Build speed", "Improvise in a style", "General progress"); each pre-seeds a
   sensible `[SkillID]` set the user trims. Encode the method, author all copy
   in-house. AI later just auto-fills the same skill set from free text.

8. **Loop skill-tagging is a PHASE-2 enrichment, deferred to its own slice (§5.4).**
   Optional, additive: a loop may wear one of the *same ~10 coarse area buckets*
   exercises use (the `ExerciseTemplate` display names — the shared vocabulary,
   deliberately kept short so it never overwhelms), letting a loop feed technique
   goals directly instead of only via its song. Reuses the existing `Loop.tags`
   (`[String]`, ADR 0034 — whose "cross-song filter payoff" was explicitly reserved
   "for its first consumer"; the planner is that consumer). Untagged loops still work
   via Path B, so nobody is forced to tag. **Do NOT build in slice 1.**

---

## 3. Conventions to follow (verified in-repo)

- **Pure logic stays pure** (AGENTS.md): `deriveCandidates`, `buildSession`, the
  taxonomy table, the family map, and dueScore math import **Foundation only** — no
  SwiftUI / SwiftData / AVFoundation. They reason over small value projections
  (`PlannerCandidate`, `SessionBlock`), never the `@Model` types. Precedent:
  `RoutineBudget` (already does exactly this for the pacing half).
- **SwiftData model discipline** (ADR 0011/0036): business `uid: UUID`; declaration
  defaults on every non-optional attribute (CoreData 134110); **String-backed enums
  only** — `SkillID` stays a `String` that *indexes* the taxonomy table, never a
  stored custom-enum attribute (the enum-attr migration crash rule). New scalar fields
  are additive/optional ⇒ lightweight migration (ADR 0012 pattern).
- **Typed optional relationships** for `Goal.targetSong` (ADR 0058/0066 R4) — not a
  generic `ownerKind + ownerID`.
- **SwiftLint:** `--strict` locally before push (CI promotes warnings→errors);
  identifiers ≥ 3 chars; files ≤ 400 lines (`wc -l`, split proactively).
- **Build/test destinations:** sim is **iPhone 17** (not the iPhone 15 Pro in
  AGENTS.md — not installed). UI tests need **`-testPlan PocketAll`** or they're
  skipped locally (CI runs them).
- **`xcodegen generate`** after adding files/targets and after any branch switch,
  BEFORE building.
- **CI is Swift 6 / Xcode 16** — stricter than local; mark UIKit access `@MainActor`
  up front.

---

## 4. What already exists (don't rebuild)

- **`Routine` / `RoutineItem` / `RoutineItemKind` / the player / `RoutinePresets`** —
  shipped (PR #102). The planner *produces* a `Routine`; it does not touch playback.
- **`RoutineBudget`** — pure pacing logic already implements ADR 0014 R1 (only
  `focused` budgeted), R2 (block caps: default 12, max 20 min), R3 (rests: 2/3/5 min).
  `buildSession`'s time-boxing stage **calls into this**, doesn't duplicate it.
- **`ExerciseTemplate`** (closed enum: basic, strumming, scales, chords, picking,
  legato, fingerstyle, rhythm, warm-up, ear-training, theory) — the coarse
  classification Path A + warm-up sourcing ride on. `.warmup` already exists.
- **`Loop.mastery` / `Loop.lastPracticed`** — the self-rating pattern to mirror onto
  `Exercise`. `MasteryRollup` (pure) already averages ratings, skipping `nil`.
- **`Song.lastPracticed`** exists; `Song.mastery` is derived from its loops.
- **`docs/practice-techniques.md`** — the taxonomy (SkillIDs, difficulty, default
  mode, prereqs). The controlled vocabulary; Slice 2 encodes it as a table.

---

## 5. The slices

### Slice 1 — Back-half + mastery parity (pure logic, small model delta)

The first buildable, testable, *shippable-on-its-own* milestone. Produces a working
"generate a session from my library" even before goals exist (feed a trivial
candidate list weighted by dueness only, `goalWeight = 1`).

1. **`Exercise` gains `mastery: Int?` + `lastPracticed: Date?`** (parity with `Loop`,
   ADR 0039 semantics; additive optional ⇒ lightweight migration). Set `lastPracticed`
   when an exercise is run (hook the existing run-completion path); surface the
   `mastery` rating in the player's **end-of-block reflection sheet** (ADR 0071) and
   on the exercise detail — the same affordance loops already have.
2. **`PlannerCandidate`** value type (pure): `unitRef` (id + unit kind), `priority`,
   `mastery: Int?`, `lastPracticed: Date?`, `estimatedMinutes`, optional `skillID` for
   display. Projected from the models — never the `@Model` itself.
3. **`SessionBlock`** enum: `.warmUp(min) | .focus(ref, min, microRestEvery) |
   .rest(min) | .play(min)` (ADR 0014 shape).
4. **`dueScore`** + **`buildSession(minutes:candidates:now:)`**: select by dueScore →
   trim to budget under the R7 60-min cap → order by R5 **U-shape** (top-priority
   LAST, high FIRST, maintenance MIDDLE) → time-box via `RoutineBudget` (R2/R3),
   micro-rest cue (R4), warm-up leads / play trails, R8 presets (Quick 15 / Focused 30
   / Full 60, default short).
5. **Materialiser:** `[SessionBlock]` → a `Routine` of `RoutineItem`s (correct
   `kind`, `order`, unit relationships), handed to the shipped player.
6. **Warm-up sourcing:** LRU pick from `template == .warmup` exercises (Decision 3).
7. **Unit tests** = the ADR 0014 property list (see §6).

**Milestone:** a "Quick session" button that generates + runs a real routine from the
user's exercises, ranked by dueness, with warm-up/rests/U-shape — no goals yet.

### Slice 2 — Front-half: goals + candidate derivation (pure logic + 1 model)

1. **`SkillID` + taxonomy table** (pure): encode `docs/practice-techniques.md` as a
   Foundation-only table (id, difficulty, default mode, prereqs).
2. **`ExerciseTemplate → [SkillID]` family map** (pure data, Decision 4).
3. **`Goal` `@Model`:** `uid`, `title`, `weight: Double = 1.0`, `skillIDsRaw:
   [String]`, `targetSong: Song?`, `isMet: Bool = false`, `dateAdded`.
4. **`deriveCandidates(goals:library:now:)`:** expand active goals → skills (S2) →
   resolve via **Path A** (family map → exercises) + **Path B** (`targetSong` → loops
   + song run), routed by `default mode` (Decision 5) → weight by dueScore (S5) → drop
   unaffiliated skills (S4) → **soft prereq down-weight** (Decision 6). `estimatedMinutes`
   from the exercise ramp staircase / loop length×reps / song duration.
5. **Goal templates** (in-house curated skill sets, Decision 7).
6. **Unit tests** = the ADR 0015 property list (see §6).

**Milestone:** `deriveCandidates → buildSession` composes end-to-end from a real
`Goal`; a goal-driven session runs.

### Slice 3 — Planner UI ("Home is the planner", design brief §4 P3)

The big UI slice. `HomeView` is a Phase-0 placeholder today.

1. **Time selector** (Quick 15 / Focused 30 / Full 60, default short — R8).
2. **Goal editor:** goal-template picker → weight → skill trim (from the coarse
   buckets, not the raw 30-item list) → optional `targetSong`. Mark-met toggle (S6).
3. **Generated-routine card** → "Start" hands the materialised `Routine` to the
   shipped player. Regenerate/edit affordance.
4. Keep it inside the existing navigation; device-test the full loop (Decision:
   device testing is a legitimate verification step — reflection-sheet rating,
   generated session, warm-up-first ordering).

### Slice 4 — Loop skill-tag enrichment (PHASE 2 — Decision 8)

Optional, additive; build only after 1–3 work.

1. Offer the ~10 `ExerciseTemplate` display names as **suggested** `Loop.tags` (so
   users pick canonical names that match).
2. `deriveCandidates` Path A also matches loops whose recognised tag ↔ the skill's
   coarse bucket. Untagged loops unchanged (still Path B).
3. Small ADR of its own when built.

### Slice 5 — AI suggester (OUT OF SCOPE — noted only)

Deferred post-V2, behind the ADR 0002 proxy + a settled pricing model. Would be just
another producer feeding `deriveCandidates`/`buildSession`, bounded by the same rules.
Do not build as part of this plan.

---

## 6. Test spec (pure logic MUST be unit-tested — AGENTS.md)

**`buildSession` (from ADR 0014):** single-item session places it LAST; top-priority
item is always last, never buried mid-session; total *focused* minutes never exceed
budget or the 60-min cap; no focused block > 20 min; a rest sits between every pair of
focused blocks; selection prefers higher dueScore; warm-up + play minutes excluded
from the focused budget.

**`deriveCandidates` (from ADR 0015):** a skill with no active goal produces no
candidate; a higher-weighted goal yields higher-priority candidates; marking a goal
met removes its candidates next derivation; higher `mastery` lowers a skill's
priority; an empty goal list yields an empty (not arbitrary) set; a prereq-unmet skill
is down-weighted **but still present** (Decision 6); `targetSong` contributes its loops
+ song run (Path B).

**dueScore:** unrated (`mastery == nil`) ranks as max-due; `mastery == 5` ranks lowest
for equal recency; `dueness` rises monotonically with time since `lastPracticed`.

**Warm-up:** never enters the focused ranking; LRU picks the least-recently-practised
`template == .warmup` exercise; absent any, no warm-up block (no crash).

UI tests (Slice 3) via `-testPlan PocketAll`.

---

## 7. Gotchas (pick-up-cold)

- **The proficiency signal was DELETED, then re-added differently.** Don't re-store a
  song-level proficiency (MasteryRollup derives it). Only `Exercise` gains a
  *self-rated* `mastery` — mirroring `Loop`, self-set, never computed from playing
  (ADR 0070).
- **`SkillID` is a String, not a stored enum.** Storing a custom enum on a `@Model`
  faults old rows (the enum-attr migration crash). The taxonomy lives in code/data;
  `Goal` stores skill *strings*.
- **Don't duplicate `RoutineBudget`.** `buildSession`'s time-boxing calls it.
- **Warm-up double-meaning:** `ExerciseTemplate.warmup` (content) vs
  `RoutineItemKind.warmup` (block role) — both exist, keep them straight.
- **Materialiser must set `order` explicitly** (ADR 0066 R2 — relationship arrays
  aren't dependably ordered) and handle a nullified unit (skipped, not crash — R5).
- **`xcodegen generate`** before building; **`swiftlint --strict`**, files ≤ 400
  lines, ids ≥ 3 chars; sim **iPhone 17**; UI tests **PocketAll**.
- **Device-test** the reflection-sheet rating + generated session — previews/sim
  aren't sufficient for a new UX flow.

---

## 8. Docs / ADRs to write (AGENTS.md step 4)

- **New ADR — self-rated exercise mastery + dueScore without stored proficiency.**
  Supersedes ADR 0014 R6's proficiency assumption; records Decisions 1–3.
- **New ADR — planner candidate resolution & soft prereq staging.** Records
  Decisions 4–6 (template-level Path A, `targetSong` Path B, soft down-weight — the
  0016↔0071 reconciliation at the *selection* level). Updates/extends ADR 0015.
- **Loop skill-tag ADR** — when Slice 4 is built (Decision 8).
- **Every slice:** `CHANGELOG.md` (`[Unreleased]`). **New model/service:** `PROJECT.md`
  + `docs/architecture.md` (the `Goal` model, the two pure planner modules).
  `docs/backlog.md` — move the planner from "parked" to "in progress", link this plan.
