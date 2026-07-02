# 0056 — Sort + search in the Practice unit libraries

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

User-testing "Cluster 2 — Library nav" flagged the two Practice unit libraries
(**Loops**, **Exercises**) as under-served: each rendered a single hardcoded order
(loops by song → name; exercises `@Query(sort: \.name)`) with no way to re-sort or
find a unit. The song library already solved this — a persisted sort menu whose
label spells out the active key + direction, plus `.searchable` (ADR 0035) — so the
gap was a consistency and browsing-friction problem, not a design-open one.

The IA question was **settled and out of scope**: keep loops/exercises inside
Practice, don't restructure (that conflicts with ADR 0046, and cross-unit routines
are V2). This ADR only adds ordering + search to the existing lists.

## Decision

Add a **sort menu + search field** to both libraries, mirroring the song library's
idiom, backed by one pure, unit-tested helper.

- **`PracticeLibrarySort` (pure, SwiftData-free).** Generic over the item type; the
  caller passes a projection closure to a plain field struct (`LoopSortFields`,
  `ExerciseSortFields`), like `SongGroupFields`. So the comparators are unit-tested
  without a model graph (AGENTS.md: pure logic stays pure).
- **Keys.** Loops: **Song · Name · Command tempo · Mastery**; exercises: **Name ·
  Command tempo · Recently added**. `LoopSortKey` / `ExerciseSortKey` are `String`
  enums whose raw values persist via `@AppStorage`, so each library remembers its
  choice across launches, independently.
- **Ascending = the natural order** for the key (A→Z, low→high, needs-work first,
  newest first). `name` is the tiebreaker on every key for determinism. Descending
  **flips the whole list**, ties included (same total reversal as ADR 0035), rather
  than re-comparing — predictable and cheap.
- **Unrated mastery sorts last ascending** (`nil` → `Int.max`): an unrated loop is an
  unknown *need*, so it trails the rated ones, and lands first when flipped.
- **Search + sort are in-memory filters**, layered on the existing `commandTempo != nil`
  loop gate — not SwiftData `#Predicate`s (an optional `#Predicate` starves the main
  thread; see `PracticeRunUITests`). Loops match on name **or** song title; exercises
  on name. Two empty states are distinguished: "none yet" vs. "no matches".
- **Deletion indexes the displayed list.** Exercise `onDelete` now offsets into the
  sorted/filtered `visibleExercises`, not the raw `@Query`, so a swipe deletes the row
  you actually swiped.

## Consequences

- The two libraries now read consistently with the song library; browsing friction
  drops as unit counts grow.
- New pure logic is unit-tested (`PracticeLibrarySortTests`); the views stay thin
  projection + wiring.
- `Loop` has no creation date, so loops get no "Recently added" key — a per-loop
  `dateAdded` would be an additive migration if that's ever wanted.
- No model or schema change; no migration. Closes Cluster 2's actionable scope
  (sort + nav UX); the deferred cross-unit/routine work stays V2.
