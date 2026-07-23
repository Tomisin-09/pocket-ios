# 0109 — Triad shapes as an Insert category + collapsible picker sections

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-178-triads`)
- **Builds on:** ADR 0084 (movable `ChordGrip` — relative geometry placed at a root), ADR 0103 (the
  search-first chord picker and its Insert grid grouped My chords → Movable → Open), ADR 0106 (power
  chords, the last grip family added to Insert).

## Context

The Insert grid (ADR 0103) browses full chord shapes: saved chords, the movable barres, and open
shapes. It has no **triads** — the small three-note root/3rd/5th shapes on a single string set (a "major
triad on the top three strings", G‑B‑e), which are core rhythm/lead vocabulary and the natural next step
after barres. They're trivially generatable (a triad is just a `ChordGrip` that sounds three adjacent
strings), they were simply un-curated. Adding them, though, widens an already-tall Insert pane — four
categories of diagram grids is a lot to scroll past.

## Decision

**1. Triads are a new curated `ChordGrip` set on their own Insert category.** Reuse the movable-grip
primitive (ADR 0084) rather than a parallel model:

- `ChordGrip.RootString` gains **`dRoot`**, **`gRoot`**, **`bRoot`** and **`eHighRoot`** alongside the
  existing low‑E / A — an inversion moves the root off the lowest string of the set, so a triad grip can
  root on any string. A grip's `rootString` is whichever string carries the root *in that inversion*.
- Eighteen grips — **major + minor** on the three sets (**G‑B‑e**, **D‑G‑B**, **A‑D‑G**), in **all three
  inversions** (root · 1st · 2nd), a new `inversion` field tagging each (`ChordGrip.triads`). Upper
  string sets put chord tones above the root, so the shapes carry negative offsets; the existing
  octave-bump in `voicing()` (added for the 9ths, ADR 0101) keeps a low root playable by climbing a
  register instead of falling off the nut — no new placement code. Placed at a root they auto-name plainly
  ("C", "Cm"), because a triad *is* a major/minor chord (M2) — an inversion is the same chord symbol, a
  different voicing; the chip subtitle carries the set + inversion ("G‑B‑e · 1st inv").
- A new **Triads** Insert section (`ChordPicker.insertTriadGrips`) browses them exactly like movable
  shapes — a root menu on tap — with the **string set** as the chip subtitle. Scope is deliberately the
  root-position essentials; inversions and diminished/augmented are out of scope below.

**2. Insert sections are collapsible.** Each Insert group (My chords · Movable · **Triads** · Open) gets
a tappable header with a chevron that collapses/expands its grid, so the player can fold away categories
they aren't using. A live search **force-expands** every section (`collapsedSections … && query.isEmpty`)
so a match can never hide inside a collapsed group. Collapse state is in-memory (per sheet presentation).

## Consequences

- The picker gains the everyday triad vocabulary with **no new model or renderer** — six grips × a root,
  generated not tabled (M1). `RootString` is now four cases; nothing switches exhaustively over it.
- The taller four-category grid is manageable because any section folds away. Search still surfaces
  everything regardless of collapse state.
- Triads name themselves "C"/"Cm" like the barres, so a progression built from a triad reads identically
  to one built from a barre — the voicing differs, the chord symbol doesn't.
- Pure geometry is unit-tested (`ChordGripTriadTests`): each triad's pitch-class set, three-string count,
  the **bass tone per inversion** (root / 3rd / 5th), auto-name, and validity at every root; plus that
  triads stay out of the movable curated set.

## Out of scope (follow-ups)

- ~~**Triad inversions** (1st / 2nd).~~ **DONE (pocket-178, device feedback 2026-07-23).** The set now
  carries all three inversions (18 shapes); with the sections collapsible the wider grid stays manageable.
- **Diminished / augmented** triad qualities — the remaining triad colours, deferred to keep the set to the
  everyday major/minor; they'd slot in as more `ChordGrip.triads` entries behind the same UI.
- **Lower string sets** (D‑A‑E / E‑A‑D). The three upper sets cover the common rhythm/lead register; the
  lowest set is muddier and rarer.
- **Persisting collapse state** across sheet presentations (AppStorage). In-memory is enough for now.

## Alternatives considered

- **A parallel `TriadShape` model.** Cleaner in theory (a triad isn't a barre), but it would duplicate the
  placement, naming, and browse-picture machinery `ChordGrip` already has. A triad is expressible as a
  grip that sounds three strings; reusing the primitive is less code and one test net.
- **Folding triads into the existing Movable section.** Rejected: it would swell one section and blur the
  "slide a barre" story. A distinct, collapsible Triads section keeps each family legible.
