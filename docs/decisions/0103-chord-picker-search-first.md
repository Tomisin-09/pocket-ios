# 0103 — Chord picker: search-first, Insert / Build split, diagram grid

- **Status:** Accepted (2026-07-21)
- **Date:** 2026-07-21
- **Builds on:** ADR 0065 (`ChordVoicing` + the chord-progression template), ADR 0084 (movable
  `ChordGrip`s + the `MovableChordSheet` / `CustomChordSheet` authoring sheets), ADR 0095
  (`SavedChord` "My chords" library), ADR 0096 (the Toolkit hub as the management home for
  saved chords).
- **Closes off:** the flat native-`Menu` approach to inserting a chord in
  `ChordProgressionEditor`.

## Context

Building a chord progression inserts and swaps chords through a single SwiftUI `Menu`
(`addMenu` / `voicingMenu` in `ChordProgressionEditor`). That menu stacks, in one growing text
column with no filter:

    Movable shape…  →  Custom chord…  →  My chords (unbounded) …  →  Manage…  →  ChordVoicing.library

A user-testing pass (Note 12, 2026-07-20) flagged two problems that compound as the ADR-0095
**My chords** library grows: the surface is **dense** (the two least-used authoring rows sit at
the top of the everyday path), and the player's **own chords get hard to find** (buried
mid-list, text-only, no search, ordering the only lever). A `Menu` also can't host a search
field or read a shape at a glance.

## Decision

**Replace the flat insert/swap `Menu` with a dedicated picker sheet — search-first, with an
*Insert* / *Build* split and a diagram grid.** Additive over the shipped substrates: it reads
`ChordVoicing.library`, the `SavedChord` `@Query`, and generated `ChordGrip`s; it introduces no
new persisted type and leaves `ChordDiagramView` untouched.

- **D1 — One picker sheet, search at the top.** Both entry points (the "Add chord" button and a
  row's chord-name button) present `ChordPickerSheet`. A live search field sits above everything;
  typing filters the Insert grid by chord name (and, for movable shapes, by quality + shape
  family — "minor", "e-shape", "barre"). Case- and diacritic-insensitive.

- **D2 — Insert vs Build (segmented).** *Insert* browses existing voicings to drop one in;
  *Build* is the two authoring actions (**Movable shape** / **Custom chord**) as description
  cards that open the existing `MovableChordSheet` / `CustomChordSheet`. Splitting them empties
  the everyday path of its two least-used rows. Search shows only in Insert (it has no target in
  Build).

- **D3 — Diagram grid, three groups.** Insert is a 3-column grid of mini `ChordDiagramView`
  chips, in fixed order: **My chords** first (badged as the player's, teal), then **Movable
  shapes** (badged "slide to any root"), then **Open shapes** (`ChordVoicing.library`). Diagrams
  read shape at a glance and pack tighter than text. An empty state ("No chords match — try
  Build to make one") shows when a search excludes everything.

- **D4 — Movable shapes are first-class in Insert (ADR 0084), tap → quick root pick.** The
  Movable group shows six common barre grips (E-/A-shape major / minor / dom7) as chips drawn at
  a representative fret-5 barre — root-agnostic pictures of the *shape*. A grip is not a chord
  until it has a root, so tapping a movable chip opens a **compact root menu** (C … B); choosing
  a root places the grip there (`ChordGrip.voicing(rootPitchClass:)`) and inserts it. This is the
  everyday "I want an F barre" without diving into Build. **Build → Movable shape** remains for
  full family-and-root authoring; the two are the browse-vs-author split of the same ADR-0084
  substrate (grips generated on the fly, never a stored table).

- **D5 — Saved-chord *management* lives in the Toolkit hub, not the picker.** The picker's My
  chords group is **insert-only** (tap a chip to drop it in). Renaming and deleting saved chords
  is the Toolkit → **My Chords** screen's job (ADR 0096, `MyChordsView`, with rename + delete).
  The old menu's inline **Manage…** row and the `SavedChordsSheet` it opened are **removed** —
  the swipe-to-delete list existed only because a `Menu` couldn't host management, a constraint
  the sheet redesign and the dedicated hub both dissolve. One management home, less density.

## Consequences

- `ChordProgressionEditor` drops `voicingMenu` / `addMenu` / `savedChordsSection` and its three
  target sheets, keeping a single `pickerTarget`; the picker owns the Movable/Custom sub-sheets.
- `SavedChordsSheet.swift` is deleted (its only caller was the editor). `MyChordsView`'s doc
  comment is corrected — the inline manager no longer "stays".
- The movable browse picture needs a representative root; `ChordGrip.browseVoicing` places the
  grip at fret 5 (a clean mid-neck barre). The chip suppresses the generated name and labels the
  quality + family instead, keeping it honestly root-agnostic.
- Pure, UI-free bits (`ChordGrip.browseVoicing`, the search match, the Insert movable list) are
  unit-tested (`ChordPickerTests`), per the repo's pure-logic rule.
- No model or renderer change; every voicing the picker inserts is the same `ChordVoicing` the
  progression already stores.

## Alternatives considered

- **Keep the `Menu`, just add sections / reorder.** Rejected: a `Menu` can host neither search
  nor diagrams, and reordering can't fix findability in an unbounded list — the root cause is
  structural (Note 12).
- **Tap a movable chip inserts at a fixed default root** (e.g. E-shape → F), transpose later.
  Rejected: there is no in-row transpose, so a wrong default means re-picking; the one extra tap
  of a root menu is cheaper than guessing and serves the exact-chord case ("F barre") directly.
- **Tap a movable chip opens the full `MovableChordSheet`.** Rejected as heavier than needed and
  near-identical to the Build path; the inline root menu keeps browse and author distinct.
- **Keep an inline Manage… / `SavedChordsSheet` in the picker.** Rejected: duplicates the Toolkit
  hub's management and re-adds the density the redesign removes; management has a canonical home.
