# 0014 — Practice-routine generation grounded in practice science

- **Status:** Accepted (principles recorded; build deferred to the Phase 3 planner)
- **Date:** 2026-06-18

## Context

The home screen **is** the practice planner (design brief §4, P3): a time selector,
routine cards, and session blocks. It is not built yet — `HomeView` is a Phase-0
placeholder — so the data model (`Routine`, `RoutineItem`/`PracticeStep`, `Session`)
and the **planner-weighting** logic (called out in `docs/architecture.md` as pure
logic that *must* be unit-tested) are still open. Before we build, we want the way a
session is **selected, ordered, and time-boxed** to be grounded in evidence rather
than invented, so the logic — and the AI session suggestions behind the proxy
(ADR 0002) — pull in the same direction.

Source: guitargearfinder.com, *"How Long to Practice Guitar: Science-Based Effective
Practice"* (Ebbinghaus forgetting curve; serial-position effect; diminishing returns;
micro-rest study). The takeaways below are the encodable distillation; the article is
the rationale, not a dependency.

This ADR records **what the planner optimises for**. It does not design the planner
UI, and it keeps the rules in a **pure, SwiftData-free** module (the "pure logic stays
pure" rule in `AGENTS.md`) so they are unit-testable and reusable by the AI suggester.

## Decision

The planner turns *(available minutes, candidate practice items, practice history,
now)* into an **ordered list of timed blocks**. Eight rules, derived from the research,
govern that transform:

- **R1 — Practice ≠ play; only deliberate work is budgeted.** A block is either
  *focused* practice (drilling a loop, the speed-trainer ramp, a technique) or *play*
  (full run-through, jamming) or *warm-up*. **Only focused blocks count against the
  time budget and the daily cap.** Warm-up and play are surfaced but unbudgeted — the
  user can play as long as they like; we never tell them to stop *playing*.

- **R2 — Short focused blocks, never one long grind.** Default focused block length
  **10–15 min**; **hard ceiling 20 min** per unbroken focused block. If the selected
  focused time exceeds one block, split it into several blocks. (A 20-min block is
  short enough to be effective end-to-end; unbroken hours are mostly wasted middle.)

- **R3 — A break between blocks.** Insert a short **2–5 min rest** between focused
  blocks so attention resets. Breaks are explicit blocks in the output, not gaps.

- **R4 — Micro-rests inside a block.** A focused block carries a micro-rest cue:
  **~10 s every 1–2 min**. This rides the existing per-loop automator (ADR 0013): the
  ramp already **pauses between passes** — that pause *is* the micro-rest, and the
  loops-per-step pacing is where a brief stop lands. The planner emits the cue; the
  engine already provides the stop point.

- **R5 — Serial-position ordering (this is the core of "planner weighting").**
  Sequence is **not** "most important first." We exploit primacy + recency:
  - the **single highest-priority item goes LAST** (recency — finish on the thing you
    most want to improve);
  - a **high-priority item goes FIRST** (primacy);
  - **lower-value / maintenance items fill the MIDDLE** (the least-retained stretch).
  So ordering is a **U-shape by priority**, not a descending sort. With one item it is
  last; with two, both bookends; with three+, bookends + middle.

- **R6 — Spaced repetition drives *selection*.** Which items make today's session is
  weighted by the forgetting curve: an item's **due score rises with time since last
  practised and falls with proficiency** (well-learned items can wait longer before
  decaying). Rank candidates by due score, fill the budget from the top. This is what
  turns the practice log / `Session` history (ADR 0009) into a schedule instead of a
  static list.

- **R7 — Diminishing returns → a daily cap and no repeats.** Past ~**60 min** of
  focused practice the planner stops adding blocks and shows a soft "diminishing
  returns" note rather than building a marathon. No single item is scheduled more than
  once per session (spacing beats cramming).

- **R8 — Build up; don't default to elite volume.** Presets are modest —
  **Quick 15 / Focused 30 / Full 60** min of *focused* time — and the default is the
  short one. We never default to multi-hour sessions; elite volume is built over years
  and copying it burns out beginners.

### Shape of the pure logic (doubles as the test spec)

A pure function, no SwiftData / SwiftUI imports, fed lightweight value inputs:

```
buildSession(availableMinutes:, candidates:[PlannerCandidate], now:) -> [SessionBlock]
```

- `PlannerCandidate` carries `id`, `priority`, `proficiency`, `lastPracticed?`,
  `estimatedMinutes` — projected from `RoutineItem`/`Loop`/`Session`, *not* the
  SwiftData types themselves.
- `SessionBlock` = `.warmUp(min) | .focus(id, min, microRestEvery) | .rest(min) |
  .play(min)`.
- Pipeline: **select** by R6 due score → **trim** to budget under the R7 cap →
  **order** by R5 U-shape → **time-box** with R2 block size, R3 rests, R4 micro-rest,
  R8 preset; warm-up leads, optional play trails.

Properties to assert (the unit tests): single-item session places it last; the
top-priority item is always last and never buried mid-session; total *focused* minutes
never exceed the budget or the R7 cap; no focused block exceeds 20 min; a rest sits
between every pair of focused blocks; selection prefers higher due scores; warm-up and
play minutes are excluded from the focused budget.

### Where it attaches

- **`RoutineItem`/`PracticeStep` gains a `priority`** (drives R5) on top of its
  automator config (ADR 0009/0013); proficiency + last-practiced come from `Song`
  (ADR 0012) and `Session` history.
- **The AI suggester (ADR 0002) is constrained by these rules** — same caps, same
  U-shaped ordering — so manual and AI-built sessions behave consistently.

## Consequences

- "Planner weighting" now has a concrete, testable definition (R5 + R6) before any UI
  exists; the pure module can be built and unit-tested independently of persistence and
  of the planner screen.
- The per-loop automator's "pause between passes" (ADR 0013) gains a second meaning: it
  is the R4 micro-rest. No new engine work for micro-rests.
- A new `priority` field is needed on the routine↔loop item; recorded here so the Phase-3
  model includes it from the start.
- The planner is opinionated about **stopping** (R7/R8): it will cap and nudge rather
  than maximise minutes — a deliberate fit with the "quality over speed" ethos.

## Alternatives considered

- **"Most-important-first" descending order** — rejected: it buries the priority item
  in the low-retention middle/tail. R5's U-shape is the whole point of the research.
- **Flat fixed-length sessions (e.g. always 30 min, no breaks)** — rejected: ignores
  R2/R3; long unbroken blocks are mostly wasted.
- **Pure recency scheduling (always drill the newest/weakest)** — rejected as the sole
  signal: R6 needs proficiency too, or well-learned items never resurface and decay.
- **Letting the AI suggester own all sequencing free-form** — rejected: the rules live
  in shared pure logic so AI and manual sessions obey the same guardrails; the AI
  proposes *content*, the rules enforce *structure*.
- **Encoding micro-rests as their own engine feature** — rejected: the automator's
  inter-pass pause already provides the stop; the planner only needs to surface the cue.
