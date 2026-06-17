# 0012 — Song metadata editing, journaling & collections

- **Status:** Accepted (metadata editing); journaling & playlist-collections **deferred**
- **Date:** 2026-06-17

## Context

ADR 0011 Slice 2 imports a file and defaults the title to the filename; everything
else on the `Song` is empty. The song record is the place where Pocket can capture and
continuously enrich the information that later powers practice routines (proficiency,
what to work on, how a song is organised). This ADR covers the first metadata-editing
slice, and records the larger direction (journaling, real playlist collections, an
automation control) so the model and UI decisions made now don't box those in.

## Decision

### Built now — metadata edit sheet (Accepted)

- **New scalar fields on `Song`:** `album: String = ""`, `year: Int?`, `comment: String = ""`
  (the general note). They join the existing `title`/`artist`/`key`/`bpm`/`proficiency`/
  `progression`/`collections`. Additive → SwiftData lightweight migration handles it,
  **but the default must be on the property declaration, not just `init`**: a
  non-optional attribute with no declaration default is "mandatory" at migration time,
  so migrating a store saved by an earlier build fails (CoreData 134110) and
  `.modelContainer(for:)` recovers by **wiping the store**. Optional attributes
  (`year: Int?`) are exempt. (Pre-release, local store, CloudKit not yet active.)
- **`SongEditSheet` (`Features/Library/`)**, reached by **swiping a library row → Edit**.
  It follows the loop/marker sheet pattern (ADR 0011): edit local `@State` seeded in
  `init`, write back to the `@Model` on **Done**, so **Cancel discards**. `year`/`bpm`
  are numeric text mapped to `Int?` ("" = unknown, like the rest of the codebase treats
  `nil`); proficiency is a 0–5 tappable-star control.
- **Practice stats are read-only and computed**, not stored: `annotationCount` (= loops
  + markers) is a pure, unit-tested accessor on `Song`; loops/markers counts come
  straight from the relationships. No denormalised counters to keep in sync.
- **Collections stay lightweight `[String]` tags** edited in the sheet (add /
  swipe-to-remove). We deliberately do **not** introduce a `Collection` `@Model` yet —
  a real playlist needs a many-to-many relationship and a browse surface, which isn't
  justified until the library/planner needs it. The tag list is forward-compatible: a
  later migration can promote distinct tag strings into `Collection` rows.

### Deferred — recorded so it isn't lost

- **Filename-derived suggestions:** a pure parser that proposes title/artist/album/year
  from the original filename, surfaced as dismissible, user-editable suggestions. Cut
  from this slice to keep it small. When built, capture the original filename at import
  (`SongRef.id` is a UUID, not the name) or fall back to parsing the unedited `title`.
- **Practice journal:** a compact, **dated** journal scoped three ways — **per-loop,
  per-marker, and per-song**. The intent: a journal icon on the loop bar (and markers)
  that **snapshots that item's context** — tempo and automation settings — coupled with
  an **optional** user annotation, plus the ability to browse an item's entries; and a
  song-level general entry. New `@Model` (`JournalEntry`) with a timestamp and a scope
  reference. Its count will join the sheet's stats once it ships.
- **Collections as real playlists:** promote the tag list to a `Collection` `@Model`
  that's browsable/openable from the library.

### Decided (placement) — automation "A" icon

- The automation control lives as a small **"A" icon in the tempo bar** (resolves the
  earlier "undecided" note). It ties into the journal's context snapshot above. Not
  built in this slice — placement is fixed so the journaling/automation work can target it.

## Consequences

- A song's metadata is now fully editable and persists; the data we need for routine
  planning starts accumulating.
- Migration is additive — no destructive reset, and CloudKit remains a later config step.
- Collection tags can't yet be browsed as playlists; that's an intentional, reversible
  simplification (tags → `Collection` rows when the need is real).
- Journaling and filename suggestions are tracked here as the next builds on this record.
