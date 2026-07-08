# 0072 — Planner: self-rated exercise mastery + the dueScore selection ranking

- **Status:** Accepted (2026-07-08)
- **Date:** 2026-07-08
- **Supersedes:** ADR 0014 R6's *proficiency* assumption (the planner's proficiency term is a
  self-rating, not a measured score).
- **Relates to:** ADR 0015 (goal → candidate selection), ADR 0039 (`Loop.mastery` self-rating),
  ADR 0066 (routine model — the planner's output substrate), ADR 0070 (no performance feedback),
  ADR 0071 (routine player). Build plan: `docs/plans/planner-build-plan.md` (Slice 1).

## Context

The V2 **practice planner** turns *(what you want to get better at, how many minutes, now)* into a
ready-to-run `Routine` (the shipped substrate, ADR 0066). It is two pure functions that compose —
`deriveCandidates` (front-half, ADR 0015) → `buildSession` (back-half, ADR 0014). This ADR records
the **Slice 1** decisions: the selection *ranking* and the one model change it needs. The
goal/candidate-derivation decisions (Path A/B resolution, soft prereqs) are a later slice and a
separate ADR.

The hard constraint is ADR 0070: **the app never grades playing.** A planner that ranks by "how well
you played" would breach that wall. So the proficiency signal must be the player's own judgement.

## Decision

### 1. Self-rated proficiency, never derived (ADR 0070 wall)

`Exercise` gains a self-rated **`mastery: Int?`** (0–5, `nil` = unrated) and a **`lastPracticed:
Date?`** (`nil` = never run) — additive optional attributes, so SwiftData lightweight migration fills
old rows with `nil` (the CoreData 134110 rule; optionals are exempt). This *extends the shipped
`Loop.mastery` pattern* (ADR 0039), it does **not** reintroduce the deleted song-proficiency
(`Song.mastery` stays derived via `MasteryRollup`). Mastery is set by the player (detail sheet dot
picker) and **never** computed from playing. `lastPracticed` is stamped when a run starts.

### 2. The dueScore formula — the whole selection ranking (ADR 0015 S5)

```
dueScore(item, now) = goalWeight(item)            // from the goal (Slice 2); Slice 1 = 1.0
                    × dueness(lastPracticed, now)  // rises with time since practised
                    × (1 − mastery/5)              // falls as the player rates it settled
```

- **`dueness`** is `1 − e^(−elapsedDays/τ)` (τ = 7 days): strictly rising with elapsed time so equal
  budgets order by recency, asymptoting toward 1.0. **Never-practised (`nil`) is treated as max-due
  (1.0)** — cold-start friendly. (At extreme gaps the float saturates to 1.0, tying with
  never-practised; `SessionBuilder.select` breaks such ties older-first.)
- **Unrated mastery (`nil`) is treated as max-due** (term = 1.0, as if 0).
- **`mastery == 5` retires** the item from rotation (term = 0 zeroes the product) until the player
  themself lowers the rating. **Static rating, time-driven resurfacing:** mastery is never
  auto-decayed — for mastery 1–4 the `dueness` term alone brings the drill back over time. We never
  silently change a number the player set (ADR 0070's spirit).

### 3. Warm-up is structural, never due-scored (ADR 0014 R1)

Warm-up leads, is **unbudgeted** (already enforced by `RoutineBudget`), and is sourced by
**least-recently-used rotation** on `lastPracticed` from `template == .warmup` exercises — *not*
dueScore (a warm-up loosens up, it doesn't target a weakness). The one new `Exercise.lastPracticed`
field feeds **two** rules: *dueness* on the focused axis and *LRU rotation* on the warm-up axis. Absent
any warm-up exercise, the block is simply omitted (no crash).

## Consequences

- **Pure, testable core.** `DueScore` and `SessionBuilder` (and the `PlannerCandidate` / `SessionBlock`
  value projections) import **Foundation only** — no SwiftData/SwiftUI/AVFoundation — so the ranking
  and layout are unit-tested (per AGENTS.md) and reusable by a future AI producer (ADR 0002). The
  impure `PracticePlanner` only projects models → candidates and materialises blocks → a `Routine`.
- **`buildSession` honours ADR 0014:** budgeted focused minutes only, ≤ 60-min session cap (R7),
  ≤ 20-min blocks with splitting (R2), a rest between adjacent focused blocks (R3), U-shape ordering
  with the top-due item **last** (R5), warm-up leads / play trails (R1).
- **First surface:** a "Quick session" generator in the Routines library materialises a real `Routine`
  from the exercise library (dueness-only, no goals yet) and hands it to the shipped player.
- **Deferred:** goal-driven candidate derivation (Slice 2), the planner-home UI (Slice 3), loop
  skill-tags (Slice 4), AI (out of scope). Surfacing mastery in the ADR 0071 end-of-block reflection
  sheet is a follow-up; Slice 1 rates on the exercise detail sheet.
