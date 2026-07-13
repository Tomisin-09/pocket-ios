# 0084 — Movable chord shapes + custom-chord placer

- **Status:** Accepted (2026-07-12)
- **Date:** 2026-07-12
- **Builds on:** ADR 0065 (exercise content templates; the Chords template, slice 4 — the
  shared `ChordVoicing` + `ChordProgression` + `ChordDiagramView`).
- **Relates to:** ADR 0083 — shares the unsolved **slide/shift teaching cue** (0083 S8 ⇄ M6
  below); solve it once, reuse across both.

## Context

The Chords template (ADR 0065 slice 4) ships a **fixed, in-house `ChordVoicing.library`** —
~18 absolute voicings (open majors/minors, a handful of sevenths, two barre forms, two
triads). Each is a hand-authored `[Int?]` fret array pinned to one place on the neck. Two
signals from the 2026-07-11 notes session push past that:

1. **A movable-barre-shape chart** — the player thinks in *grips*: an "E-root shape" or
   "A-root shape" that is the **same fingering slid to a different fret** to become a
   different chord. The library already contains this idea, frozen: `fBarre` and
   `bMinorBarre` are the E-shape and A-shape barres nailed to one fret. Nothing lets a
   player take that shape and *move it*.
2. **A "custom chord" ask** — compose an arbitrary voicing the curated set can't express
   (jazz shells, extensions, altered dominants, anything bespoke).

The key realisation, same as the runs/scales work (ADR 0065 "generated, not placed", ADR
0083): **the note data is fully derivable** — a barre grip plus a fret offset *is* a
voicing; a chromatic fret→note map names it. So the product decision is **not** "which
voicings do we know" (all tiers are generatable) but **where to draw the curated ceiling**
and **how to teach the slide**. This ADR decides how movable grips are modelled, how far the
curated set reaches, and where bespoke voicings live — **additively** over the shipped
`ChordVoicing`, changing no existing voicing, progression, or renderer.

## Decision

A chord voicing may be **generated from a movable grip** or **hand-placed by the player**;
both resolve to the one `ChordVoicing` the renderer already draws — the ADR 0065/0083
"authoring → generated → one render surface" pattern applied to chords. Eight rules.

- **M1 — Generate grips, never store a voicing table.** A movable shape is emitted
  *programmatically* — a relative grip transposed to a fret — not looked up in a giant
  hand-authored table. The library's fixed voicings stay for the common open shapes (where
  a table *is* the natural form), but the movable/barre and advanced vocabulary is
  generated, so adding a quality is a formula, not N hand-typed fret arrays.

- **M2 — A grip is relative geometry + a root string + a quality; placing it yields a
  `ChordVoicing`.** A new pure `ChordGrip` (SwiftUI-free): the **root string** it anchors on
  (E-root / A-root — the two the chart uses; D-root later if wanted), the **relative fret
  offsets** per string (relative to the grip's root fret; `nil` muted, a barre is offset 0
  across its strings), and the **quality** (maj/min/dom7/…). Placing it at a chosen fret —
  expressed to the player as a **root note** (musically meaningful; "slide the E-shape until
  the root is G"), mapped to the root-string fret — transposes the offsets to absolute frets
  and produces a `ChordVoicing`. The generated voicing's **name derives from its own content**
  (`ChordVoicing.rootPitchClass` + the grip's quality), so a slid shape is auto-named
  ("G", "Bb7") with no naming table.

- **M3 — Tier the curated ceiling (the real product call).** All tiers are generatable; the
  decision is what the *curated exercise* offers vs. what the placer (M4) covers:
  - *Tier 1* — **triads + 7ths** (maj / min / dom7 / min7 / maj7 × E-root & A-root; the
    chart's 10). The curated **default**.
  - *Tier 2* — **+ sus2 / sus4, 6ths, basic 9ths**, in guitar-idiomatic voicings (e.g. sus2
    voiced A-root, not on the awkward E-shape). Also curated.
  - *Tier 3* — **shells (root-3-7), extensions (9/11/13), altered (7♯9/7♭9/7♯5/7alt)** — these
    multiply and get instrument-specific, so they are **not** curated grips; they live in the
    placer. Keeps the curated set small and maintainable, no giant table (M1).
  The curated movable exercise defaults to **Tier 1–2**.

- **M4 — The custom-chord placer is the escape hatch.** A per-string picker — each string
  **fretted at n / open / muted** (and optionally a fretting finger) — composes an arbitrary
  voicing the curated grips can't express, validated by the existing `ChordVoicing.isValid`
  and persisted as a plain `ChordVoicing`. This is where Tier 3 and anything bespoke (jazz,
  altered, custom) live. No new persisted type — a placed chord and a generated grip are the
  same `ChordVoicing` downstream.

- **M5 — One output type; the renderer is untouched; seeded content stays identical.** Grips
  and the placer both emit `ChordVoicing`, so `ChordProgression`, `ChordChangeView`,
  `ChordDiagramView`, and the whole Chords run screen are unchanged (they already speak
  `ChordVoicing`). The two hardcoded barres (`fBarre`, `bMinorBarre`) are **retrofitted as the
  first two grips** placed at their current frets — the generated output must be
  byte-identical to today's arrays, so the seeded library and any saved progression referencing
  them are unaffected.

- **M6 — Slide-to-fret must *teach*, shared with ADR 0083 (S8).** The movable-shape idea is
  "pick a shape, **slide it** to the right fret" — the *movement along the neck* is the whole
  pedagogical point, exactly like the run/scale slide seam in 0083. The authoring and (where
  shown) the exercise surface must convey the slide as **motion**, not a shape that simply
  redraws at the new fret. This is the **same open UX question** as 0083 S8; whichever ships
  first solves it for both, and it is gated by the animate / Reduce-Motion preferences (degrades
  to a static "at fret n / slid from m" cue when motion is off).

- **M7 — Grip transposition and placer validity are pure and unit-tested.** `ChordGrip →
  ChordVoicing` is pure geometry (add the placement fret to each offset), tested with a
  property net over the existing pure `ChordVoicing` accessors: every generated voicing
  `isValid`, its `rootPitchClass` matches the requested root, and its `pitchClasses` /
  `isTriad` / `isMinorQuality` match the requested quality — the same style of correctness net
  ADR 0065 used for scales/arpeggios. The placer leans on `ChordVoicing.isValid` for the
  fretted/open/muted composition.

- **M8 — Grips and shapes are common-practice vocabulary, authored in-house (ADR 0065 T8).**
  Barre grips, CAGED shapes, and standard voicings are generic pedagogy, not anyone's
  protected expression — safe to encode. All names, copy, and the curated tier set stay ours;
  no third-party chord dictionaries, charts, or prose enter the model.

## Build order (slices)

1. **`ChordGrip` + transposition + Tier 1 grips (M1–M3, M7).** The cheapest, pure start —
   the model, the E/A-root triad + 7th grips, the property test, and the retrofit of the two
   library barres into grips (M5, byte-identical). No new UI yet; grips feed the existing
   progression editor's picker as generated voicings.
2. **Movable-shape authoring + the slide-teaching cue (M2 UI, M6) + Tier 2 grips.** "Pick a
   shape, slide it to a root/fret" authoring, with the shared 0083-S8 slide cue. This is the
   slice that answers the open UX question — recommended to coordinate with whichever 0083
   slice touches the same cue.
3. **Custom-chord placer (M4).** The per-string fretted/open/muted picker, the Tier 3 escape
   hatch, persisting a `ChordVoicing`.

Slice 1 is buildable now with no UX unknowns; slice 2 carries the shared teaching-cue
decision; slice 3 is independent and could land any time.

## Consequences

- **No voicing-table sprawl.** Tiers 1–2 are a handful of grips × two root strings, generated;
  Tier 3 is user-composed, not maintained. The curated surface stays small (M1/M3).
- **Fully additive, renderer untouched.** Everything downstream already speaks `ChordVoicing`;
  the retrofit of the two barres keeps seeded content and saved progressions byte-identical
  (M5). No store migration.
- **Two features, one teaching problem.** M6 and 0083 S8 are the same slide cue — a real reason
  to sequence the two ADRs' UI slices together rather than solving it twice.
- **`ChordVoicing`'s pure accessors finally get exercised as validators**, not just for display —
  `rootPitchClass` / `isTriad` / `isMinorQuality` become the property-test oracle for generation
  (M7).
- **The placer is a new authoring surface** (per-string picker) — modest, but it is the first
  chord editor that composes rather than picks; keep it simple (fretted/open/muted + optional
  finger), advanced voicing theory stays the player's, not the app's.

## Alternatives considered

- **Hand-author every movable/advanced voicing into `ChordVoicing.library`.** Rejected (M1):
  a giant table to maintain, and it misses that the data is derivable — the whole reason grips
  generate.
- **A separate persisted `MovableChord` / `Grip` model on disk.** Rejected — a grip is an
  *authoring recipe*; its *output* is a `ChordVoicing`, and only the output needs persisting
  (mirrors ADR 0065's `FretboardRun`→`FretboardDrill` and 0083's run→drill). The grip type is
  pure and in-memory; nothing new hits SwiftData/CloudKit.
- **Curate Tier 3 too (ship altered/extended grips).** Rejected as the *default* (M3): those
  voicings multiply and are instrument/context-specific, so they belong behind the placer, not
  in a curated list that would balloon.
- **Fret-number placement instead of root-note placement.** The player *slides to a fret*, but
  naming a chord by raw fret is unmusical; M2 places by **root note** (auto-naming the result)
  while presenting it as sliding along the neck — the best of both.

## Open questions (to settle at build time)

- **M6 slide-teaching cue** — **RESOLVED (slice 2): no animation for the chord case.** Unlike a run
  (0083 S8), a chord progression is a sequence of *distinct* chords the player forms at their frets —
  nobody physically slides between them, so there is no in-performance motion to teach. The movable
  idea is *conceptual* and carried statically: the authoring sheet shows the **shape family + fret**
  ("E-shape · fret 3 → G7") beside a live diagram. The travelling-highlight arrow stays a runs-only
  treatment; M6's "shared cue" assumption didn't hold once examined.
- **Grip → progression authoring flow** — **RESOLVED (slice 2): a dedicated `MovableChordSheet`,
  inline output.** Reached from a **Movable shape…** item in both the Add-chord and per-chord swap
  menus of `ChordProgressionEditor`; it emits a plain `ChordVoicing` mixed inline with the open-shape
  library (leaning-inline confirmed — a progression freely mixes open shapes, slid grips, and, later,
  placed customs). A sheet, not a nested menu, so the shape/quality/root choice has room to show a live
  preview.
- **D-root grips** — **RESOLVED (slice 3): the placer covers them.** No curated D-root grip family was
  added; a D-root voicing (or any bespoke shape) is composed directly in the custom placer
  (`CustomChordSheet`), which is exactly the escape hatch M4 describes. E/A-shape stay the only *generated*
  grip families.
- **Placer finger hints** — **RESOLVED (slice 3): deferred, no finger control.** The shared
  `ChordDiagramView` deliberately doesn't draw finger numbers (they read as noise at diagram scale), so a
  finger picker in the placer would have no visible effect. The placer composes fretted/open/muted geometry
  only — the same fretted-only output the grips generate. Fingers can return once a surface actually renders
  them; the two library barres still keep their hand-authored `fingers` (not replaced), so no fingering is
  lost.
- **Custom-chord placer (M4)** — **DELIVERED (slice 3): `CustomChordSheet`, a full-screen tappable chord
  box.** Reached from a **Custom chord…** item in both the Add-chord and per-chord swap menus of
  `ChordProgressionEditor` (beside **Movable shape…**), presented `.fullScreenCover`. Rather than a menu
  list, the placer is an *editable twin of `ChordDiagramView`* (device feedback, 2026-07-13): strings are
  columns (low E left → high e right), tapping a fret cell frets that string (tap again to clear), tapping
  the ✕/○ marker above a string cycles muted ↔ open, and a position control slides a 5-fret window up the
  neck (frets 1–16). Each sounded string shows its **scale degree from the lowest note** (R / 3 / 5 / ♭7 …)
  via the pure `ChordVoicing.degreeLabels` / `degreeName` — a plain chromatic reading, *not* a full
  chord-name analysis (that would guess at altered/extended voicings; deferred). The player names the
  bespoke voicing (no derivable name, unlike a slid grip); Insert is gated on `ChordVoicing.isValid` + a
  non-empty name; the output is a plain `ChordVoicing` mixed inline (M4/M5) — no new persisted type,
  renderer and run screen untouched. **All three slices of ADR 0084 are now shipped.**
