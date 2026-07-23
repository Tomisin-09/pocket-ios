# 0107 — Custom scale canvas with a reference-scale guide

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-172-symmetric-scales`)
- **Builds on:** ADR 0065 (the generative scale engine — `GuitarScale` × `CAGEDShape`, and the
  `FretboardDrillEditor` custom escape hatch), ADR 0084 (the custom-**chord** placer, whose "draw it
  yourself" model this mirrors for scales), ADR 0091 (root-anchor box labels).

## Context

Two scale asks — **symmetric scales** (whole-tone, diminished) and **scale sequencing** (thirds,
pentatonic patterns) — both fight the generative engine. `ScaleRun` generates a scale by placing one of
five `CAGEDShape` boxes in the relative-major key and **filtering** it to the scale's degrees
(ADR 0065). That only works for scales that are **subsets of a major scale**. Symmetric scales aren't:
they repeat on a fixed interval (whole-tone every whole step, diminished every minor third) and belong
to no single major key, so there is no box to filter. Adding them would need a *separate* placement
generator, and they'd still violate the generator's test net — the one-hand-span box invariant
(≤7 frets, ≤12 semitones/octave) and "every scale offers five CAGED positions". Sequencing is a further
orthogonal axis over every layout. Both are real engine surgery with real regression risk.

The custom-**chord** placer (ADR 0084) already resolved the analogous problem for chords: when the
generated grips can't express a voicing, the player *draws* it on a board. The same move applies here.

## Decision

Rather than extend the box generator, **add a custom-scale canvas** — the "draw your own" escape hatch
for any scale the generator can't place (symmetric, sequenced, or invented):

- **Reuse the existing `FretboardDrillEditor`.** It already authors an arbitrary `FretboardDrill` (a
  playable, animatable note sequence up the neck, with position scroll, Watch and Hear). No new canvas.
- **Generate-or-draw split on the Scales template.** `ExerciseShapeSheet`'s scale section gains a
  segmented **Generate / Draw your own** control: Generate keeps today's `ScaleRunEditor` box picker
  (writes `.scale(run)`); Draw shows the `FretboardDrillEditor` (writes `.custom(drill)`). Both are
  `FretboardContent` cases the `.scales` renderer already expands to a drill, so a drawn scale runs and
  animates with **no model or renderer change**. A Scales drill stored as `.custom` reopens in draw
  mode; a freshly-switched draw starts from an **empty bar** (`FretboardDrill.emptyBar`).
- **A scale reference guide overlays the canvas.** An opt-in guide (`referenceEnabled`) adds a scale +
  key picker whose notes are **ghosted** on the placement board (the scale's pitch classes faintly
  tinted, its root stronger) so the player traces and taps them. The guide catalog is a new pure
  **`ScaleReference`** (name + interval formula → pitch classes) — deliberately **not** a `GuitarScale`,
  so it carries the symmetric scales (whole-tone + the two diminished modes) as formulas **without
  touching the CAGED engine or its tests**. It reuses every `GuitarScale` formula by display name so the
  two never drift. Nothing snaps — the guide is a drawing aid, informational only (ADR 0070).

## Consequences

- Symmetric scales **and** any sequenced/exotic/hand-shaped scale are buildable and playable today, with
  zero changes to the generative scale engine, `GuitarScale`, `CAGEDShape`, or their test nets.
- The generator stays the fast path for the common scales (one tap: pick scale + root + box); the canvas
  is the flexible path for everything it can't express — the same generate-vs-author split as chords.
- `ScaleReference` is pure and unit-tested (symmetry properties, formula reuse). `FretboardDrill` gains a
  tested `emptyBar` factory. The guide overlay is off by default, so every other custom drill is
  unchanged.
- The guide only *shows* a scale; it can't yet *name* what you drew (no scale identifier). That's the
  richer custom-chord parallel (`ChordIdentifierPanel`), deferred below.
- **Multi-bar + scrollable neck (pocket-176, device feedback 2026-07-23).** The shared
  `FretboardDrillEditor` is no longer capped at one bar: a **Bars** stepper (1–8) grows the drill via the
  pure `FretboardDrill.withBarCount`, and `resized` now preserves bar count across subdivision changes.
  The placement board became a **horizontally-scrollable full neck** (frets 0–15) with a `ScrollViewReader`
  that follows the selected note, replacing the chevron-paged 5-fret window. Purely editor/UX; the model
  already stored an arbitrary-length `notes` array, so there was no schema change.

## Out of scope (follow-ups)

- **A scale identifier** — "you drew C whole-tone" — the reverse-lookup analog of `ChordNamer`. A real
  theory engine (naming an arbitrary pitch-class set as a scale/mode), deferred; the guide + a
  player-chosen name cover the need for now.
- **First-class generated symmetric scales.** If demand proves it, a dedicated repeating-cell generator
  could still add whole-tone/diminished to `GuitarScale` later — but the canvas removes the urgency, so
  it stays deferred rather than built speculatively.
- ~~**Draw mode at creation.**~~ **DONE (pocket-174, device feedback).** The generate-or-draw toggle now
  also appears in the **New Scales** create sheet (`NewExerciseSheet`), not only Edit-shape, so the canvas
  + guide are discoverable when first making a Scales drill. A Scales drill switched to draw at creation
  starts from an empty neck (`FretboardDrill.emptyBar`).

## Alternatives considered

- **A symmetric-scale placement generator** (a repeating-cell shape rather than a filtered CAGED box).
  The "proper" generative answer, but real engine surgery: a new generator path, new `GuitarScale`
  cases threaded through every switch, and it still breaks the one-hand-span / five-CAGED-positions test
  invariants that assume diatonic boxes. High effort and risk for the two rare scales; the canvas covers
  them and more.
- **A dedicated custom-scale sheet** mirroring `CustomChordSheet` exactly (full-neck board + a scale
  identifier). More polished and more work; the identifier is the hard half. Reusing
  `FretboardDrillEditor` ships the capability now, with the dedicated sheet + identifier left as a
  follow-up.
