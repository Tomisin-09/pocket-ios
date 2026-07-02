# 0060 — Practice stats are derived read-through, not stored

- **Status:** Accepted
- **Date:** 2026-07-02

## Context

The user-testing "polish" cluster asked for **stats / measures** — a glanceable sense of progress —
with the explicit steer to do **derivable counts first**. Pocket already stores everything a first
slice needs (loops with `mastery`, exercises, journal entries); it deliberately does **not** store a
practice-session history (the old `SessionTracker` was removed in ADR 0052). So the question is
whether stats warrant a new stored model now, or should be computed from what's already there.

## Decision

Ship a first slice of stats as a **pure, derived read-through** — no new persistence.

- A UI-free `PracticeStats.summarize(...)` rolls plain inputs into a `Summary` of four counts:
  **loops**, **exercises**, **mastered** (loops at the top of the 0–5 scale), and **notes** (journal
  entries across loops and exercises). Pure, so the counting and the "mastered" threshold are
  unit-tested (AGENTS.md).
- The home hub shows a **"Your progress"** card (`PracticeStatsCard`) built from that summary,
  gathered from the existing `@Query`s. It **hides on an empty library** so first launch isn't a
  wall of zeros.
- **No stored stats, no sessions model, no counters mutated on write.** The numbers are recomputed
  from the source of truth each render — cheap at V1 library sizes and impossible to drift.

## Alternatives considered

- **A stored `PracticeSession` / streak model.** Rejected for this slice — it's the V2 planner's
  territory (time-series, streaks, goals) and a schema commitment we don't need to show counts.
  Derived-first keeps the door open without paying for it now.
- **Incrementing stored counters on write.** Rejected — denormalised counters drift the moment any
  write path forgets to bump them; deriving can't.
- **Richer measures now (tempo gains over time, per-week activity).** Rejected for the first slice —
  those need timestamps we don't keep (see the sessions model above). Counts land the value cheaply;
  richer measures can follow if wanted.

## Consequences

- Progress is visible on the home hub with zero new stored state; the card is honest by construction.
- If later measures need history (streaks, tempo-over-time), that's a deliberate new model + ADR —
  this decision scopes the first slice to derivable counts and records why.
- `PracticeStats` is the single place the measure definitions live (e.g. "mastered = 5"), so the
  home card and any future surface agree.
