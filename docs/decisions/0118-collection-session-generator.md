# 0118 — Build a practice session from a Collection: budget-sized, order-dialled, reusing the planner back-half

- **Status:** Proposed
- **Date:** 2026-07-25 (`pocket-197-collection-session`)
- **Builds on:** ADR 0111 (the `Exercise`↔`Song` repertoire edge and `SongRoutineBuilder`, the pure per-song producer of planner `SessionBlock`s that flows into the Save-only review screen). ADR 0066 (`Routine`/`RoutineItem`; nullify unit references). ADR 0014 (the practice-science planner rules — focused-block caps, between-block rests, the 60-minute session ceiling, and the **Quick / Focused / Full** `SessionLength` presets). ADR 0033/0035 (song **Collections** are a `[String]` label axis normalised through `Labels`, and the Library filter over them). ADR 0064 (the V2 planner as "a smarter producer of the same `SessionBlock`s"). ADR 0070 (never grade the player).
- **Supersedes:** nothing. Generalises the ADR 0111 per-song generator to a whole collection.

## Context

A **Collection** is not an entity — it is a `[String]` label axis on `Song` (ADR 0033), the Library's
soft grouping (a setlist, an album, "songs to learn"). ADR 0111 shipped `SongRoutineBuilder`: for **one**
song it emits planner `SessionBlock`s — its linked exercises as focused drills, its loops as focused
passages, a trailing play-through — reviewed and persisted only on Save via
`RoutineDetailView(generatedSession:)`.

Players want the same for a **whole collection**: "set up a practice session for this set." Done naively
that is a trap — a 10-song collection has dozens of exercises and loops, and enumerating them all yields a
multi-hour "routine" nobody sits through. Two forces shape the real decision:

**1. It must be a *session*, not an inventory.** The output should be a right-sized sitting — the app
already speaks this language: `SessionLength` (`.quick = 15`, `.focused = 30`, `.full = 60` focused
minutes) and `SessionBuilder`, which lays a candidate pool into a budgeted, capped, U-shaped,
rest-punctuated `[SessionBlock]` under a 60-minute ceiling (ADR 0014). A collection session should draw
*from* the collection but be *sized to* a chosen length, not enumerate it.

**2. Order is a taste axis the player should control.** `SongRoutineBuilder` has one fixed arc
(drills → passages → play). For a collection, some players want that structured arc; others want the set
mixed up so it doesn't feel rote. The request was explicit: let the player vary **the magnitude of order
vs. randomness**, and let the player decide. So generation gains a **dial**, not a second hard-coded rule.

## Decision

Add a pure **`CollectionSessionBuilder`** (Core/Planner) that materialises a **session** from a
collection's songs — **sized to a `SessionLength`** and **arranged by a player-chosen `OrderMode`** —
emitting `[SessionBlock]` into the *existing* review-then-Save flow. No new persistence, no new `@Model`,
no migration; collections stay a label axis (ADR 0033).

### The pool — deduped across the collection's songs

For every song carrying the collection label (`Labels.matches(song.collections, allOf: [collection])`):

- its **linked exercises** (ADR 0111) as `.focus` candidates,
- its **loops** as `.focus` candidates,
- the **song itself** as a `.play` candidate.

Exercises and loops are **de-duplicated by `uid`** — a drill linked to three songs in the set warms the
whole set up **once**, not three times. This dedup is the core value over "run `SongRoutineBuilder` per
song and concatenate."

### Sized to a `SessionLength`

The player picks Quick / Focused / Full. Focused blocks (exercises + loops) fill up to that focused-minute
budget, honouring `RoutineBudget`'s block caps / splits and between-block rests and `SessionBuilder`'s
60-minute hard ceiling (ADR 0014). Play-throughs are unbudgeted book-ends (R1); with many songs the number
of trailing `.play` blocks is **capped** so a "Full" session isn't swallowed by play-throughs.

### `OrderMode` — the dial (new pure enum)

- **`.structured`** — the ADR 0111 arc scaled up: deduped drills → passages → play-throughs. Deterministic.
- **`.mixed`** — grouped, but shuffled *within* each group.
- **`.shuffled`** — fully randomised order across all blocks.

Randomness takes a **seed** so the pure function is deterministic and unit-testable (AGENTS.md — "pure
logic stays pure"); the UI passes a fresh seed per generation so "regenerate" reshuffles.

### Reuse the whole back-half

`CollectionSessionBuilder` emits `[SessionBlock]` and nothing more. The entry point hands those to
`RoutineDetailView(generatedSession:)` → `PracticePlanner.materialise`, so the session is reviewed in the
normal editor and **persists only on Save** (Cancel/back leaves no orphan) — exactly the ADR 0111 seam.
This is the ADR 0064 framing realised again: the direct edge and now the collection are just *producers* of
the same session blocks the V2 planner will one day produce more cleverly.

### Entry point — a filtered-Library action

Collections have no home screen; they live in the Library filter (ADR 0035). So the action appears **when
the Library is filtered to a single collection**: a "Build a session from these songs" affordance opens a
small sheet (a `SessionLength` picker + an `OrderMode` picker) and pushes the review screen. It is hidden
when no single-collection filter is active. A `canBuild` guard mirrors ADR 0111 — enabled only when the
collection has **at least one linked exercise or loop** across its songs (otherwise the session would be
lone play-throughs).

## Consequences

- Collections gain a "practice this set today" action **without** becoming first-class entities or touching
  the schema — the label axis (ADR 0033) is enough; this is a read-only producer.
- The **order dial** turns generation into a taste the player controls, not a fixed rule — the same
  substrate yields a disciplined arc or a shuffled set on demand.
- **Dedup** means shared technique warms up the whole collection once; the session reads as curated, not
  repetitive.
- **Sizing to `SessionLength`** keeps the output a real sitting (≤ 60 focused minutes), and the review
  screen still lets the player trim/reorder/rename before Save.
- Pure builder + **seeded** randomness → fully unit-testable (dedup, budget fill, order determinism per
  mode) per AGENTS.md.
- Never grades (ADR 0070): it *schedules effort* drawn from what the player linked, and computes no quality
  judgement.
- Depends on the ADR 0111 edges being populated to be rich; a collection whose songs have no linked
  exercises/loops disables the action rather than generating an empty-feeling session.

## Alternatives considered

- **Promote `Collection` to a first-class `@Model` entity.** Rejected — ADR 0033 deliberately chose a label
  axis; a read-only session generator needs no entity, and adding one is a migration + a whole new
  management UX for no payoff here.
- **Enumerate everything in the collection (no budget).** Rejected — a large collection yields a multi-hour
  "routine" nobody uses; it violates ADR 0014's session-length discipline. Sizing to a `SessionLength` is
  the point.
- **Keep the single fixed order (just reuse `SongRoutineBuilder`'s arc, concatenated per song).** Rejected —
  the explicit ask was to vary order vs. randomness, and per-song concatenation also loses the cross-song
  dedup. The dial *is* the feature.
- **A new bespoke session pipeline.** Rejected — `SessionBuilder` / `RoutineBudget` / `SessionLength` /
  `RoutineDetailView` already do budgeted, capped, reviewed, Save-only sessions; reuse them wholesale as
  ADR 0111 did.
- **Per-song grouping as the *only* shape.** Rejected as the sole mode — it is offered as one point on the
  `OrderMode` dial rather than imposed on everyone.
- **A dedicated Collections browse screen to host the action.** Deferred — the filtered-Library action
  reaches the same set with no new screen; a Collections surface can come later if collections earn more
  first-class treatment.
