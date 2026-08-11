# 0119 — Favourites: a manual per-item star across exercises, routines & loops, surfaced by a per-list filter in each library

- **Status:** Accepted
- **Date:** 2026-07-25 (`pocket-196-favourites`)
- **Builds on:** ADR 0011/0012/0036 (SwiftData `@Model` discipline — a business `uid`, **declaration defaults** on every non-optional attribute so lightweight migration stays additive per the CoreData 134110 mandatory-attribute rule, and the enum-attr rule that keeps custom enums out of stored attributes). ADR 0043/0046 (`Exercise` is a standalone click-only unit) and ADR 0066 (`Routine`/`RoutineItem`) and the `Loop` model — the three units gaining a star. ADR 0070 (Pocket never grades the player) — a favourite is a bookmark the player sets, not a rating the app computes.
- **Supersedes:** nothing. First appearance of a favourite/pin concept in the store.

## Context

A player who has built a real library — a dozen exercises, several routines, loops scattered across many
songs — has **no way to mark the handful they return to daily**, and no way to pull those together across
the three unit types. Exercises and routines are top-level Practice units; loops are nested one level down
inside their songs, so "the three passages I'm drilling this week" are physically spread across the
library with no single door to them.

Two distinctions sharpen what a favourite *is* and *isn't*:

**1. A favourite is not a grade, and not mastery.** Pocket already has `mastery` (ADR 0036) — a *derived*
practice-proficiency roll-up — and `dueScore` (ADR 0015) — a computed "wants scheduling" signal. A
favourite is neither: it is an **explicit, manual, opinion-free pin** ("I care about this / keep it close"),
set by the player and read by no algorithm. It never feeds mastery, due-scoring, or the planner. This keeps
it clean of ADR 0070 — the app isn't judging anything; the player is bookmarking.

**2. The unit grain matters.** Loops are the interesting cross-cutting case: a player's "my key passages"
live *inside different songs*, so a loop-level star gives a view the song-browse (collections / genre /
recently-added) structurally cannot. Songs themselves are **already** the library's first-class browse unit
with their own grouping axes, so a song-level favourite would duplicate existing affordances while the
loop-level one adds something new. That asymmetry is a deliberate scoping decision, not an oversight.

## Decision

Add a **manual per-item favourite flag** to `Exercise`, `Routine`, and `Loop`; a **star toggle** on each;
and a **"Favourites" filter** within each of the three lists.

> **Scope note (superseding the original draft).** An earlier version of this ADR also added **one
> aggregating "Favourites" rail on Home**. That surface was **cut before shipping** — favourites are
> surfaced *only* by the per-list filter, keeping the feature to "narrow the list you're already in."
> The cut removed the pure `Favorites` aggregator + its test with it (there is no longer a place that
> merges the three starred types into one ordered list). A Home rail — or any cross-type aggregation —
> can return in a later ADR if the per-list filter proves too indirect; see Alternatives.

### The flag — a plain `Bool`, additive on all three

```swift
var isFavorite: Bool = false   // on Exercise, Routine, Loop
```

- **Declaration default `false`** so SwiftData lightweight migration fills every pre-existing row
  additively — no store wipe (the CoreData 134110 mandatory-attribute rule, ADR 0012). No new type is
  registered in the container; no relationship is added.
- **A `Bool`, deliberately not an enum.** The ask is pinned / not-pinned. A stored enum would reintroduce
  the enum-attr migration crash (ADR 0036) for zero benefit. If a future need for "pin levels" appears, it
  earns its own ADR.
- **Deletion-safe by construction.** The flag lives *on* the unit; deleting the unit removes its star with
  it. There are no cross-references to dangle, so no cleanup path is needed.
- **Songs are intentionally excluded** (see Context #2). The useful cross-cutting grain is the loop; the
  song already has collections/genre/recently-added.

### The toggle

A star (`star` / `star.fill`) on each unit's row (inline and/or swipe action) and on its detail surface.
The toggle is local, idempotent, and instant — a single attribute write, no sheet, no confirmation.

### The surface — a per-list "Favourites" filter

**A "Favourites" filter within each existing list** — the Practice exercises list, the routines list,
and the loops library — a "show only starred" toggle in the list's toolbar (a star that fills when
active), with a leading-swipe Favourite/Unfavourite on each row and a small star on favourited rows. The
player narrows *where they already are*; there is no separate favourites destination to navigate to. An
empty filtered list reads as a prompt to pin something, not a false "no matches".

Because there is no cross-type aggregation, **no pure `Favorites` helper is needed** — each list just
filters its own `@Query` on `isFavorite`. The flag is a trivial boolean and needs no test beyond the
additive migration.

### Amendment, 2026-08-11 — the pin can also be set where you finish

*From a device-testing note: "should be a way to favourite an exercise from its Done screen."*

The star gains one more home: `RoutineBlockDoneView`, the post-block completion beat. Nothing about
the model, the filter, or the three libraries changes — this is a second place to set an existing
flag, added because the moment a drill has just gone well is the moment a player knows they want it
close, and making them find it in the library later is how the intention gets lost.

Three constraints the build has to respect:

- **Exercise and loop blocks only.** `Song` has no `isFavorite` and does not gain one here — the
  original scoping decision above (songs are already the library's first-class browse unit with their
  own grouping axes) still holds. All three loop modes qualify: `.loop`, `.earLoop`, `.improviseLoop`.
- **Resolve the unit by switching on `stage.payload`, never `stage.loop`.** That accessor returns the
  loop for ear and improvise blocks too, which is right here but wrong elsewhere — the rule
  `revisionOffer(for:)` documents in `RoutinePlayerView+Done.swift` exists so the distinction survives
  a gate moving, and the same discipline applies to any new payload read.
- **It stays a bookmark, not a rating.** The Done screen also carries the mastery self-rating, and the
  two sit inches apart. They must not read as one gesture: mastery is a self-assessment the player
  scores, the star is a pin they set, and ADR 0070 depends on the app never conflating them. The star
  belongs on the toolbar's trailing edge (free today — the host claims only `.topBarLeading`), not
  in the rating band.

## Consequences

- Players can pin the handful of exercises, routines, and loops they return to, and filter each list to
  them **in place**.
- Three additive `Bool`s → migration-safe, no schema type registration, no relationship, no new `@Model`.
- Home is untouched — no new rail, no aggregation surface, nothing to hide-when-empty (ADR 0102 stays a
  non-issue for this feature).
- Not a grade (ADR 0070): a favourite is a manual bookmark that feeds no algorithm — not mastery, not
  due-scoring, not the planner — unless a later ADR deliberately opts one of those in.
- Within the loops library, the favourites filter gives a "my key passages" view across every song's
  loops — the one place the per-song browse can't express — without leaving Practice.
- The boolean write is trivial; there is no aggregation logic to test, only the additive migration.
- One-per-device, no-sync (no backend/account), like the rest of the local store — a favourite set doesn't
  follow the player to another device until/unless sync ships.

## Alternatives considered

- **A dedicated `Favorite` `@Model` / join table.** Rejected — a per-unit `Bool` is simpler, additively
  migratable, and deletion-safe for free. A pin is one-to-one with its unit; there is no many-to-many to
  model, so a join table is pure overhead (and the store's only many-to-many, ADR 0111, was added for a
  genuine graph, which this is not).
- **Reuse `mastery` or a tag to mean "favourite."** Rejected — `mastery` is *derived* proficiency
  (ADR 0036) and tags are a loop-only label axis (ADR 0034); a favourite is an explicit, manual, cross-type
  pin with different semantics. Overloading either muddies both and risks a favourite silently affecting a
  computed signal.
- **A stored enum "pin level / priority."** Rejected — YAGNI; the ask is boolean, and a stored enum
  reintroduces the enum-attr migration footgun (ADR 0036).
- **Favourite songs too.** Deferred — songs already have collections/genre/recently-added browse; the
  loop grain is the useful cross-cutting pin. Revisit if a real need appears.
- **An aggregating "Favourites" rail on Home** (in the original draft, built then cut). Deferred — it
  merges the three starred types into one place, but it also adds a cross-type aggregator + a Home surface
  for a feature whose core value ("pin what I return to, then filter this list to it") the per-list filter
  already delivers. Keeping favourites entirely inside the lists keeps Home lean (ADR 0102) and the feature
  self-contained; the rail (or a dedicated screen) can return in its own ADR if the per-list filter proves
  too indirect.
- **A dedicated full-screen Favourites list as the primary surface.** Rejected as *primary* — heavier UI
  that sends the player somewhere new, when the per-list filters reach the same items where the player
  already is. A standalone screen (or the Home rail above) can follow later if a cross-type view is wanted.
