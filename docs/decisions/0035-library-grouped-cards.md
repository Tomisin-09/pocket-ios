# 0035 — Library redesign: grouped metadata cards with a Group-by control

- **Status:** Accepted (build sliced below; slice 1 — model + pure logic — landed first)
- **Date:** 2026-06-23

## Context

The library (`LibraryView`) is a flat alphabetical list of song rows (title · artist ·
proficiency). The user wants an **Apple-Music-style** library — but explicitly **without
artwork** ("the song title is fine"). So the value to borrow from Apple Music is its
*browse structure*, not its art-forward visuals.

Pocket has something a normal music app doesn't: **rich per-song metadata** — key, BPM,
proficiency, loop/marker counts, collections (ADR 0033). A text-forward library can turn
that into the visual interest artwork would otherwise provide, and into *useful* browse
axes for deciding what to practice next.

We considered several text-suited patterns (sectioned browse hub, sortable column table,
faceted filter, A–Z index, rich cards). Two facts shaped the choice: the artwork
rejection, and that **`Song.artist`/`album` are usually empty on file imports** — so an
Apple-Music "Artists / Albums" hub would have two near-empty sections.

## Decision

A **single adaptive list of rich metadata cards** with a **Group by / Sort by** control —
the "#3 + #5" blend — replacing the flat list. Not a four-section browse hub.

### Card (text-forward, no artwork)

Each row is a card: **title** (prominent) · a metadata line (key · BPM · loop count ·
marker count) · **collection chips** · **proficiency dots** · a slim **colour accent
strip** in place of artwork (derived from proficiency tier or the song's first loop
colour). The absence of art is covered by data + typography + a colour cue, not an image.

### Group by / Sort by — exactly six keys

User-specified: **Proficiency · Recently Added · Title · Artist · Album · Genre**. Picking
a key re-buckets and re-orders the same cards:

- **Proficiency** → tiers, surfaced needs-work first: *Needs work* (0–1★), *Solid* (2–3★),
  *Polished* (4–5★).
- **Recently Added** → *Today / This week / Earlier*, newest first within a bucket.
- **Title / Artist / Album / Genre** → A–Z sections; non-alphabetic starts bucket under
  `#`; empty values bucket under *Unknown Artist/Album/Genre* (sorted last). The grouping
  field then title orders items within a section.

One adaptive list (not four screens) sidesteps the thin Artists/Albums problem — the user
simply doesn't group by them when they're empty — and lets Proficiency / Recently Added /
Collections be the groupings that always have content.

### Two new `Song` fields (additive, migration-safe)

Two keys need data the model didn't store. Both use the established declaration-default /
optional pattern so SwiftData lightweight migration fills existing rows without a store
wipe (the CoreData 134110 note, ADR 0012):

- **`genre: String = ""`** — **manual-entry only** (a field in `SongEditSheet`). We
  deliberately do **not** extract genre from embedded file tags in this pass: it adds
  import-side AVFoundation work for a field the user is happy to type. Empty ⇒ *Unknown
  Genre*. Extraction-at-import stays an open follow-up.
- **`dateAdded: Date?`** — set to `.now` at import; `nil` for the bundled demo and
  pre-0035 songs (they bucket as *Earlier*). Optional with no declaration default, like
  `bpm`/`year`.

### Pure sectioning logic

`LibrarySectioning` (`Core/Models`) is the bucketing/ordering, **generic over the item
type** so it sections `[Song]` without importing SwiftData — the caller passes a
`Song -> SongGroupFields` projection. Bucket boundaries (proficiency tiers, date windows,
A–Z/`#`/Unknown) and section ordering are unit-tested (AGENTS.md: pure logic stays pure
and tested), mirroring `Labels`. `SongGrouping` is a `CaseIterable` raw-value enum so the
user's choice persists and drives the menu.

### Search

A title/artist search field filters the list (built in a later slice, layered over the
grouped view).

## Build (sliced)

1. **Model + pure logic (this slice).** `Song.genre` / `Song.dateAdded` (+ import wiring +
   edit-sheet genre field); `LibrarySectioning` + `SongGrouping` + tests. No new screen yet.
2. **Card row (#5).** The rich metadata card (colour accent, metadata line, chips, dots).
3. **Grouped list + Group-by control (#3).** Wire `LibrarySectioning` into a sectioned
   list with the picker; preserve import (+), swipe Edit/Delete, empty state.
4. **Search.** Title/artist filter over the grouped list.

## Alternatives considered

- **Four-section browse hub (Songs / Collections / Artists / Albums).** Rejected — two
  sections (Artists/Albums) are near-empty on imports, and it spreads one library across
  four screens. The Group-by control gives the same axes in one adaptive view, and the
  user just avoids the empty groupings.
- **Artwork grid / artwork rows.** Rejected by the user — no cover art; titles are enough.
- **Sortable column table.** Rejected as the primary view — columns cramp on a phone; the
  card carries the same metadata more legibly. (Sorting survives as the within-group order.)
- **Genre extracted from file metadata.** Deferred, not rejected — manual entry ships now;
  embedded-tag extraction is a later enhancement if re-typing genre proves tedious.
- **`dateAdded` as a non-optional with a `.now` default.** Rejected — a declaration
  default can't honestly represent "added before we tracked it"; optional + *Earlier*
  bucket is truthful and matches the `bpm`/`year` pattern.

## Consequences

- The library becomes a metadata-rich, regroupable surface that helps choose what to
  practice — text-heavy as a *feature*, not a limitation.
- `LibrarySectioning` is a pure, tested module reusable by any future grouped view; the
  Collections grouping reuses `Labels` data (ADR 0033).
- `Song` gains `genre` (manual) and `dateAdded`; both migrate cleanly. Genre-from-file and
  a search slice are recorded follow-ups.
- When the UI slices land: update `design-brief.md` (screen inventory — the library screen
  changes shape), `PROJECT.md`, `CHANGELOG.md`, and note `LibrarySectioning` in
  `docs/architecture.md`.

## Amendment (pocket-050) — sort direction, label, and filter relocation

Three UX refinements after living with the redesign, all within this ADR's scope:

- **Sort direction.** `LibrarySectioning.sections` gains an `ascending: Bool = true`
  parameter; `false` flips the whole list (section order **and** each section's items
  reversed — a literal flip, not a separate descending comparator, which is what "reverse
  the order" means to a user). Persisted as `@AppStorage("librarySortAscending")`.
- **Explicit sort label.** The toolbar control now spells out the current category as text
  with a direction arrow (e.g. "↑ Title") instead of a generic ⬍ icon — the user couldn't
  tell at a glance what the list was sorted by.
- **Collection filter → toolbar menu.** The horizontal chip bar across the header (ADR 0033)
  is replaced by a **filter menu** (funnel icon, fills when active) so the header is less
  busy; filtering semantics (intersection/AND, `Labels.matches`) are unchanged. The
  `CollectionFilterBar`/`FilterChip` views are removed.

Card interaction also changes (aligning with the loop sheets' hold-to-edit, ADR 0028):
**hold a card** for a context menu (Edit / Delete) rather than swipe→Edit; swipe keeps a
quick Delete and tap still opens the song for practice.
