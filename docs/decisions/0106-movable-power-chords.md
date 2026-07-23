# 0106 — Movable power chords in the chord engine

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-171-power-chords`)
- **Builds on:** ADR 0084 (movable chord shapes — the `ChordGrip` primitive and its tiered curated
  ceiling), ADR 0101 (the same tier extended with the movable 9ths), ADR 0093 (the reverse-lookup
  chord namer, whose ≥3-note rule this deliberately leaves alone).

## Context

The movable chord engine (ADR 0084) generates every shape as a `ChordGrip` — relative geometry +
root string + quality — placed at a root note to yield a `ChordVoicing` the renderer already draws.
Its curated ceiling shipped triads + 7ths (Tier 1), then sus/6/9 (Tier 2, ADR 0101). The one shape
conspicuously missing is the **power chord** — root + 5th, no 3rd — which is the single most common
movable shape in rock/punk/metal and the first barre-adjacent shape most players learn. It was never
a knowledge gap (a power chord is trivially generatable); it was simply un-curated.

## Decision

Add the power chord as a first-class movable **quality** and ship it in **Tier 1** (the default
curated set), on both CAGED root strings:

- **`ChordGrip.Quality.fifth`** — `nameSuffix` `"5"`, `displayName` "Power chord". Placed at a root it
  auto-names "E5", "A5", … straight from the root + suffix, exactly like every other grip (M2).
- **`eShapeFifth`** = `[nil, nil, nil, 2, 2, 0]` — root on the low E, 5th on A, octave root on D, the
  top three strings muted (the standard three-string shape).
- **`aShapeFifth`** = `[nil, nil, 2, 2, 0, nil]` — root on the A, 5th on D, octave root on G, low E
  muted like the A-shape kin.
- Both join **`tier1`** (now twelve grips), so they appear in **Build → Movable shape**
  (`MovableChordSheet`, which reads `curated` dynamically) with no view change, and flow through the
  `curated = tier1 + tier2` invariant untouched.

The reverse-lookup namer (ADR 0093) is **not** touched: it deliberately treats a two-pitch-class dyad
as "an interval, not a chord" and needs ≥3 notes. A power chord has two pitch classes (root + 5th, the
octave doubles the root), so the *identifier* panel won't spell a hand-built root-and-5th — but the
movable grip names itself ("E5") on the way out, which is the surface this ADR adds. Pure geometry,
unit-tested against `ChordVoicing`'s accessors (M7): a new `QualitySpec` (`triad: false`,
`required: [7]`, `forbidden: [3, 4]`) folds power chords into the existing every-grip-every-root
property net, plus known-shape oracles for E5/A5.

## Consequences

- The default movable set gains the everyday power chord; a player can slide an "E5 shape" to any root
  the same way they slide a barre. Tier 1's definition becomes "triads + 7ths + power chords".
- `Quality` gains a case; the two `nameSuffix`/`displayName` switches gain it (no other switch over the
  grip quality is exhaustive). `CaseIterable` order shifts by one insertion — nothing reads
  `Quality.allCases` for ordering (the sheet derives its list from `curated`).
- The property test's `qualitySpecs` must carry an entry per curated quality, so `.fifth` gets one; the
  `curated.count == tier1.count + tier2.count` invariant still holds.

## Out of scope (follow-ups)

- **Power chords in the ADR-0103 everyday *Insert* grid.** `ChordPicker.insertMovableGrips` is a
  deliberately small six-shape browse set (maj/min/dom7 × E/A). Power chords are arguably as everyday,
  but adding them reopens that ADR-0103 D4 decision **and** needs a subtitle fix — `movableSubtitle`
  calls every chip a "barre", which a power chord is not. Left to a follow-up that revisits the Insert
  set as a whole.
- **Naming a hand-built root-and-5th dyad** in the chord identifier (ADR 0093) — would require relaxing
  its ≥3-note rule to recognise the "5" interval as a power chord. Deferred; the movable grip already
  names itself.

## Alternatives considered

- **A two-string power chord** (root + 5th only). Simpler, but the three-string root-5-octave form is
  the fuller, more common voicing and reads better as a diagram; the octave adds no new pitch class, so
  the "no 3rd" identity is unchanged.
- **Tier 2 rather than Tier 1.** Power chords are more fundamental than the sus/6/9 shapes already in
  Tier 1's neighbour set, so hiding them a tier down would be backwards; they belong in the default.
