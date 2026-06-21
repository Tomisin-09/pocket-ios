# 0033 — Collections: normalize, suggest, and filter (still `[String]`)

- **Status:** Accepted (build sliced below)
- **Date:** 2026-06-22

## Context

ADR 0012 added song **collections** as lightweight `[String]` tags edited in
`SongEditSheet` (add / swipe-to-remove), surfaced read-only in `SongDetailsSheet` and the
practice-screen `SongInfoPanel`. It deliberately deferred promoting them to a `Collection`
`@Model` ("a real playlist needs a many-to-many relationship and a browse surface, which
isn't justified until the library/planner needs it") and recorded the field as
forward-compatible: distinct strings can later become rows.

In practice the current implementation is the rough first cut, and it violates the basic
tag-system principles:

- **No reuse.** You retype a collection name every time — nothing offers the ones you
  already use, so the set fragments (`Blues`, `blues`, `blues ` become three).
- **No normalization beyond a per-song, case-*sensitive* dedup** (`addCollection`).
- **No payoff.** Collections are write-only decoration — nothing in `LibraryView` filters
  or browses by them. A grouping you can't filter by is just a note.

Separately, this app is heading toward a **second, scope-distinct annotation axis**:
loop-level **Tags** (descriptive facets on a loop — "solo", "needs-work"), unblocked by
ADR 0032 (loops are now addressable cross-song by `uid`). To keep the two axes
unambiguous, the **name follows the scope**: song-level stays **Collections**, loop-level
will be **Tags**. The word is fixed by *what you annotate*, so "is this a tag or a
collection?" is never a judgment call.

## Decision

Keep collections as user-facing **"Collections"** and keep the underlying storage as
`[String]` on `Song` — but give them the three behaviours a usable grouping system needs.

### Stay `[String]`; do not promote to a `@Model` yet

Adding a **library filter does not trip ADR 0012's "promote to `@Model`" trigger.**
Filtering over `[String]` is trivial at this scale (single-user library, hundreds of
songs) — the same volume reasoning as ADR 0032. Promotion is justified only by the needs
0012 actually named — collections as **openable, browsable playlists**, or **per-collection
metadata** (rename-across-library, colour, pinned order) — none of which this slice needs.
The forward-compatible promotion path is unchanged. (When promoted, name the model
`SongCollection`, **not** `Collection` — the latter shadows the Swift standard-library
protocol.)

### Normalize on write (pure, unit-tested)

A pure, SwiftData/SwiftUI-free canonicaliser (AGENTS.md "pure logic stays pure / must be
unit-tested"):

- trim leading/trailing whitespace; collapse internal whitespace runs to one space;
- reject empty;
- **case-insensitive de-duplication, first-seen display form preserved** — adding "blues"
  when "Blues" exists is a no-op, and the stored form stays "Blues".

This is what actually prevents fragmentation; suggestion alone doesn't.

### Suggest from existing (reuse over re-entry)

`SongEditSheet` offers the collections already used **across the library** (distinct,
normalised, excluding ones already on this song) as tappable suggestions; tapping adds the
**canonical** form. This is the convergence mechanism — the whole point of collections is
many songs sharing the *same* one.

### Filter the library by collection

`LibraryView` gains a collection filter. Selecting collections narrows the song list by
**intersection (AND)** — a song matches if it contains **all** selected collections; the
common single-select case is AND-of-one (tap a collection → its songs, playlist-like).
The filter predicate is **pure and unit-tested**. Empty filter ⇒ all songs; an empty
result shows a clear "no songs in this collection" state.

### Naming hygiene

- Reserve **"Tags"** for the future loop axis; do not use "tag" for collection code. Rename
  the stray local in `SongEditSheet` (`ForEach(collections) { tag in … }`) to `collection`
  so the two vocabularies don't blur once loop-tags land.

## Build (sliced)

1. **Normalisation + naming hygiene.** New pure canonicaliser in `Core` (+ tests:
   trim/collapse/empty/case-dedup). Route `addCollection` through it. Rename the `tag`
   local → `collection`. No new UI.
2. **Suggestions in `SongEditSheet`.** Aggregate distinct normalised collections across
   songs; render as tappable chips that add the canonical form and hide already-added
   ones. (+ tests for the aggregation: distinct, sorted, excludes current.)
3. **Library filter in `LibraryView`.** Filter affordance (collection chips/menu),
   intersection semantics, all/empty states. Pure filter predicate (+ tests:
   single/multi-select intersection, empty filter, empty result).

Deferred (unchanged from 0012): promote to a browsable `SongCollection` `@Model` /
openable playlists — gated on a real browse-or-per-collection-metadata need.

## Alternatives considered

- **Rename collections → "Tags" (one shared name across scopes).** Rejected — it
  reintroduces the song/loop axis ambiguity that scope-based naming removes, and churns
  model/UI/docs for no gain. "Collections" also fits the curatorial song-level use
  ("gig setlist") better than "tags".
- **Promote to a `Collection` `@Model` now (to power filtering).** Rejected — filtering
  over `[String]` is trivial at this volume; a relationship + browse surface isn't earned
  yet and adds CloudKit/migration surface (consistent with ADR 0012's reasoning and the
  ADR 0032 volume analysis).
- **Suggestion without normalisation.** Rejected — suggestions reduce but don't prevent
  fragmentation; the canonicaliser is the actual guard. Keep both.
- **Union (OR) filter semantics.** Rejected as the default — intersection narrows, which
  is the useful query for curatorial groupings; single-select (the common case) behaves
  identically under AND.

## Consequences

- Collections become a real, low-friction grouping: reused via suggestions, kept clean by
  normalisation, and — finally — **actionable** via library filtering.
- The normalisation and filter predicates are pure modules, unit-tested independently of
  SwiftData and the UI.
- Naming now encodes the axis: **Collections = song-level**, **Tags = loop-level** (ADR
  0032 enables the latter), so the two never blur.
- No migration: the field stays `[String]`; the `SongCollection` `@Model` promotion path
  from ADR 0012 remains open and is explicitly out of scope here.
- When built, update `CHANGELOG.md` (collection suggestions + library filter are
  user-visible) and `PROJECT.md` (library filtering behaviour); note the new pure module in
  `docs/architecture.md`.
