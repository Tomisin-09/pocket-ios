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

- `ChordGrip.RootString` gains **`dRoot`** and **`gRoot`** (the D and G strings) alongside the existing
  low‑E / A. The root-position triad shapes root on the G, D and A strings for the **G‑B‑e**, **D‑G‑B**
  and **A‑D‑G** string sets respectively.
- Six grips — **major + minor** on those three sets, **root position** only (`ChordGrip.triads`). Upper
  string sets put the 5th above the root, so the shapes carry negative offsets; the existing octave-bump
  in `voicing()` (added for the 9ths, ADR 0101) keeps a low root playable by climbing a register instead
  of falling off the nut — no new placement code. Placed at a root they auto-name plainly ("C", "Cm"),
  because a triad *is* a major/minor chord (M2), just a compact voicing.
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
  auto-name, and validity at every root; plus that triads stay out of the movable curated set.

## Out of scope (follow-ups)

- **Triad inversions** (1st / 2nd) and **diminished / augmented** qualities — the fuller triad system.
  Deferred to keep the first cut to the root-position essentials (device-feedback triage 2026-07-23);
  they'd slot in as more `ChordGrip.triads` entries behind the same Insert section + collapse UI.
- **Lower string sets** (D‑A‑E / E‑A‑D). The three upper sets cover the common rhythm/lead register; the
  lowest set is muddier and rarer.
- **Persisting collapse state** across sheet presentations (AppStorage). In-memory is enough for now.

## Alternatives considered

- **A parallel `TriadShape` model.** Cleaner in theory (a triad isn't a barre), but it would duplicate the
  placement, naming, and browse-picture machinery `ChordGrip` already has. A triad is expressible as a
  grip that sounds three strings; reusing the primitive is less code and one test net.
- **Folding triads into the existing Movable section.** Rejected: it would swell one section and blur the
  "slide a barre" story. A distinct, collapsible Triads section keeps each family legible.
