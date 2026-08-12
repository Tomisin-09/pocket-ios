# 0163 — a chord a bassist would play

- **Status:** Accepted
- **Date:** 2026-08-12 (`pocket-257-bass-chord-shapes`)
- **Builds on:** ADR 0116 (the per-exercise instrument axis, and its Slice 7 fix — until that landed, the create sheet's Guitar/Bass control was inert, which is why this gap went unnoticed). ADR 0065 (`ChordVoicing` as the shared chord geometry). ADR 0084/0095/0103 (the placer, saved chords, the search-first picker). ADR 0127 (authoring-only gating).

## Context

ADR 0116 extended the fretboard family to bass and declared the Chords template **instrument-neutral**
— it drew the same diagram either way, so nothing appeared to need doing. That was wrong on two counts.

`ChordVoicing` resolves every pitch it reports through two *static* constants, `stringCount = 6` and
`openMidi`, and the diagram and board editor draw six columns from the same source. A bass drill
therefore got a **guitar chord box**: six strings, and every note name, root marker and Hear pitch
computed in guitar tuning. It is the same defect ADR 0116 Slice 5 fixed for the fretboard boards
(labels resolved against the wrong tuning), sitting untouched in the chord layer because "chords are
neutral" had closed the question.

The second count is harder. Porting the guitar vocabulary to four strings would be wrong even if it
were free. `ChordGrip` is CAGED — barre forms and triads on string sets, slid by root — and bass is
not CAGED, for the reason ADR 0116 Slice 3 already found with scales. More to the point, **a bassist
does not play triads**: stacked thirds below E2 are mud. The real vocabulary is dyads (root with its
fifth, its octave, or its tenth) and, higher up, three-note shells.

## Decision

**Give bass its own small chord vocabulary, and let a voicing carry the neck it was written for.**

### 1. A voicing's own shape says which neck it is on

`ChordVoicing.openMidi` becomes an instance property derived from `frets.count`: four entries ⇒ bass
standard, anything else ⇒ guitar. Every pitch-derived member (`midiNotes`, `noteLabels`,
`degreeLabels`, root and quality) resolves through it.

**This is why there is no migration and no new stored field.** The string count was already encoded
in every voicing ever written, in the length of an array the app has always persisted. A six-slot
shape resolves exactly as it always did — golden-tested, byte-identical — and nothing written before
bass existed can be misread, because nothing written before bass existed has four strings.
`SavedChord` keeps storing an opaque blob; `ChordProgression` keeps its `version` at 1.

### 2. `isValid` widens to both necks

It gated on `frets.count == 6`. Left alone, every bass voicing this ADR generates would be silently
invalid — offered in the picker, then refused downstream. Listed as its own decision because it is a
single line whose omission disables the feature quietly.

### 3. The bass vocabulary is generated from intervals, not authored as fingerings

`BassChordShape` is an interval recipe — semitones above the root, plus which string each is played
on — slid to any root. Six shapes: root+5th, root+octave, root+major 10th, root+minor 10th, and the
R-5-8 and R-♭7-10 shells.

Two consequences follow, and both are the reason for the shape of it:

- **Correctness is provable rather than eyeballed.** The property test asserts that at *every* root on
  *every* string, a generated voicing spells exactly the intervals its shape declares. A hand-authored
  transposition table can only be checked against itself.
- **A shape that doesn't fit produces nothing.** Off the end of the strings, or past the last fret, and
  `voicing(rootString:rootFret:)` returns `nil`. Clamping would silently change the intervals it
  spells, which is the one thing the type promises not to do — so the picker's root menu omits roots a
  shape can't reach rather than offering a button that does nothing.

### 4. The guitar catalog stands down on bass; the strum-lane templates withdraw

On a bass drill the picker hides Movable shapes, Triads, Open shapes and Tier 2 — six-string geometry
with no honest four-string reading — and offers Bass shapes in their place. **My Chords is filtered by
neck at the point of insertion**: it stays one global library (a saved shape draws correctly there on
its own), but a guitar shape must not enter a bass progression.

**Strumming and Chords & Strum are not offered when creating a bass drill.** Their content is a down/up
arrow lane; a bassist does not strum one. Chords itself stays, because bass chords are real.

This gate is **authoring-only**, exactly as ADR 0127's "no rest next to a rest" is. A drill already
saved under a withdrawn template still lists, opens, edits and runs — including one saved as a bass
strumming exercise while ADR 0116's instrument control was inert. Withdrawing a template from the
picker must never reach backwards into a library.

## Consequences

- Guitar is provably untouched: the golden test pins a six-string voicing's derived tuning and MIDI to
  today's constants, and `ChordGrip`, `ChordVoicing.library` and every existing progression are
  unchanged.
- `ChordDiagramView` and `ChordBoardEditor` now draw the neck their content carries and need no
  instrument passed in — which is what lets an instrument-free surface (My Chords) render a saved bass
  chord correctly. The accessibility label previously indexed `strings[5]` unconditionally and would
  have **crashed** on a four-string voicing; it now reads the outer strings by name.
- Hear needed no work: it sounds `voicing.midiNotes`, which resolves through §1.
- **Ukulele remains closed off**, consistent with ADR 0115/0116: a reentrant tuning is not a shorter
  array, and §1's "count selects the tuning" rule would need a real instrument axis to express it.
- **Alternate bass tunings (drop D, 5-string) are out of scope.** Generation uses standard tuning, as
  ADR 0116 does for scales. A 5-string bass would collide with §1's count rule and needs its own
  decision.
- `ChordNamer` may not name a two-note dyad, since two pitch classes rarely identify a chord. That is
  honest — the shape is named by its recipe ("C5"), and guessing a full chord name from an interval
  would be the kind of confident wrongness ADR 0093 avoids.

## Tests

`BassChordShapeTests` — the guitar golden, the four-string resolution, the `isValid` widening, the
interval property test across every root and string, the refusal-not-clamping cases, naming, and that
every generated voicing is valid. `ExerciseTemplateTests` covers the bass template gate and that it
does not reach backwards into `displayOrder`. `ExerciseInstrumentUITests` drives Bass → Chords → insert
and asserts a four-string box with no six-string box anywhere in the flow.
