# 0032 — Routine→loop reference: address loops by `uid`, not a SwiftData relationship

- **Status:** Accepted (decision recorded; build deferred to the Phase 3 planner)
- **Date:** 2026-06-22

## Context

The Phase-3 planner (ADR 0014) turns *(available minutes, candidate practice items,
history, now)* into an ordered list of timed blocks. A focused block —
`.focus(id, min, microRestEvery)` — points at a practice item **by opaque id**, and
those items are loops drawn from **across the whole library**, not one song. ADR 0014
deliberately keeps the pure logic SwiftData-free: candidates are value projections
(`PlannerCandidate`), ids are opaque. It leaves one thing open — the **persistence /
navigation bridge**: how does a routine item reference a real `Loop`, and how is that
reference resolved back to a *playable* loop (and its parent song) when the session runs?

Today a loop is only reachable **through its song**. The only `@Query` in the app is
`LibraryView` fetching `Song`; loops load via `song.loops` into `WaveformPracticeModel`
when you open a song. There is no top-level loop fetch, no loop browser, and no
"navigate to / play this one loop" entry point — `WaveformPracticeView` takes only
`(song, context)`, with no "open at loop" parameter. So a deep link from a session block
to a specific loop **does not exist yet**; this ADR decides the mechanism that enables it.

Relevant model facts:

- `Loop` is a cascade-delete child of `Song` (`Song.swift`,
  `@Relationship(deleteRule: .cascade, inverse: \Loop.song)`).
- `Loop` carries a **stable `uid: UUID`** as its business id, precisely because the
  SwiftData `persistentModelID` is unstable before insert (see the comment on `Loop.uid`).
- The store is **CloudKit-syncable in Phase 4** (see the `Song` class doc). That makes a
  cross-entity relationship a *sync* concern, not just a modeling choice: CloudKit
  relationships must be optional, sync as references, and can arrive out of order or
  reference a record that is deleted/not-yet-synced on another device.

The choice is between a direct SwiftData relationship and a scalar id reference. We
weighed it on Pocket's actual interaction model and scale, not in the abstract.

## Decision

A routine item references a loop by its **stable `Loop.uid`, stored as a scalar** on the
routine item — **not** via a SwiftData `RoutineItem → Loop` relationship.

- **Resolution is an explicit fetch-by-uid helper** (e.g. `loop(for: uid) -> Loop?`)
  backed by a `FetchDescriptor<Loop>` predicate. Callers handle `nil`.
- **Deep-link to practice** resolves uid → `Loop`, then uses the existing `Loop.song`
  inverse to open the waveform at that loop — one fetch; the song comes free.
- **Dangling references are a designed-for state, not an error.** A reference whose loop
  no longer resolves (the loop or its song was deleted, or it has not yet synced under
  CloudKit) is normal: the block is skipped / shown as "loop removed", never a crash.
  There is no schema-level delete rule to maintain.
- **Store the reference as the uid's string form** and predicate-match on a string, to
  keep `#Predicate` matching reliable — `#Predicate` on `UUID` has been unreliable across
  SwiftData versions. Per AGENTS.md ("verify, don't assume" for Apple frameworks),
  confirm the predicate behaviour against the current SDK at build time; `Loop.uid` stays
  the canonical `UUID`.

This only fixes the **persistence/navigation** layer. The planner's pure logic (ADR 0014)
is unchanged — it already uses opaque ids and value projections.

## Alternatives considered

- **Direct SwiftData relationship `RoutineItem → Loop`** (with inverse
  `Loop.routineItems`). Rejected. It forces a delete-rule policy and dangling-state
  handling when a song/loop cascade-deletes, adds an inverse array to every `Loop`, and
  adds a genuine relationship for the Phase-4 CloudKit engine to reconcile (optional,
  out-of-order arrival, transient cross-device dangling refs). The ergonomics it buys —
  free reverse-traversal (`loop.routineItems`) and reactive linking through the edge — are
  marginal for Pocket's **generate-then-consume** flow (build a session, then run a short,
  largely read-only list of ~6 blocks) and are not warranted by volume (a single-user
  library of hundreds to low-thousands of loops; a session is ~6 blocks, so no N+1
  concern). It is a forward migration, not a one-way door: add the relationship and
  backfill it from the stored uids later **if** a live routine-management dashboard ever
  makes those ergonomics decisive.
- **`persistentModelID` as the reference.** Rejected — unstable before insert (the very
  reason `Loop` carries its own `uid`), and not a clean identity across store resets / sync.
- **Positional reference (song + loop index).** Rejected — not stable; reordering,
  inserting, or deleting loops silently repoints the reference to the wrong region.
- **Denormalized snapshot (copy the loop's bounds/speed into the routine item).**
  Rejected — the routine would drift from the loop: editing the loop wouldn't update the
  routine, and there'd be two sources of truth. The routine must point at the *live* loop.

## Consequences

- Loops become **addressable from outside their song without a schema relationship**: a
  `loop(for: uid)` helper plus the existing `Loop.song` inverse is enough to deep-link
  into focused playback. This is the missing surface both the planner and any future
  cross-song loop view need.
- The planner's pure layer (ADR 0014) is untouched; this defines how its opaque ids
  resolve in the persistence/UI layer.
- The Phase-3 `RoutineItem`/`PracticeStep` model (not yet built) carries `loopUID`
  alongside its `priority` (ADR 0014) and automator config (ADR 0009/0013).
- `WaveformPracticeView` will need an "open at loop" entry point (an initial active loop)
  — today it takes only `(song, context)`. Recorded here so the planner build includes it.
- Dangling references are handled at read time; no cascade bookkeeping and a calmer
  CloudKit sync (the reference is a plain scalar, which always syncs intact).
- A future **loop-tag** feature (cross-song "build a session from my `needs-work` loops")
  reuses the same path — query loops by tag to assemble candidates, resolve by uid to play
  — so it needs no relationship either. Same generate-then-consume shape.
