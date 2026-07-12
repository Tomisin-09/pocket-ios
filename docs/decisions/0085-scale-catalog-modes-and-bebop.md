# 0085 — Scale catalog: the modes + the bebop scales

- **Status:** Accepted (2026-07-12)
- **Date:** 2026-07-12
- **Builds on:** ADR 0065 (exercise content templates; the `ScaleRun` generative-authoring model —
  a scale is an *interval formula* placed on the shared `CAGEDShape` boxes and filtered) and
  ADR 0083 (the `ScaleLayout` axis: box / extended / 3-notes-per-string).

## Context

The scale library (ADR 0065 build 2, Slice 2) generates every run from a **formula**: a
`GuitarScale` is a list of semitone intervals; generation places one of the five `CAGEDShape`
major boxes in the key and **filters** it to those intervals. Adding a scale is meant to cost one
line. The catalog shipped five scales — minor/major pentatonic, major, natural minor, blues — which
covers the pentatonic-and-major-key ground but leaves out the two families a player reaches for next:

1. **The modes of the major scale.** Dorian, Phrygian, Lydian, Mixolydian, Locrian (Ionian and
   Aeolian already ship as *Major* and *Natural Minor*). Modal vocabulary is core practice material.
2. **The bebop scales.** *Bebop Major* (major + ♯5 passing tone) and *Bebop Dominant* (Mixolydian +
   ♮7 passing tone) — eight-note scales that thread one chromatic passing tone through a mode.

Two other families were on the table and are **deferred**: the **diminished** scales (whole-half /
half-whole) and the **whole-tone** scale. These are *symmetric* — they repeat every minor third / whole
step and are **not** subsets of a single major scale, so the "place a major box, filter it" generator
can't produce them. They need their own placement generator, which is out of scope here.

## Decision

Add the five modes and the two bebop scales to `GuitarScale`, entirely within the existing generator.
No renderer, editor, payload, or store change — the editor already lists `GuitarScale.allCases`, and the
`scaleRaw` field already decodes forward-compatibly (ADR 0036). Four rules.

- **S1 — A mode is its parent-major box, seen from a new tonic.** Every mode shares its seven notes with
  one major scale (its *parent Ionian*), so it borrows that major's CAGED boxes via
  `relativeMajorSemitones` — the offset from the mode's tonic **up to its parent major** (Dorian +10,
  Phrygian +8, Lydian +7, Mixolydian +5, Locrian +1). The degree filter keeps all seven box notes; only
  the highlighted tonic differs. D Dorian is therefore *byte-identical* to the C major box at every
  position — the property the lock test asserts. The modes are 7-tone diatonic, so they also take the
  `.threePerString` layout, exactly like Major / Natural Minor (`supportedLayouts`).

- **S2 — A bebop scale is a mode plus one threaded chromatic passing tone.** No diatonic CAGED box
  contains the passing tone, so it is generalised from the existing **blues ♭5** mechanism: a scale may
  name a `passingToneAnchorDegree`, and generation threads a note one fret above every box note at that
  degree (blues ♭5 over the P4; Bebop Major ♯5 over the P5; Bebop Dominant ♮7 over the ♭7). Each anchor's
  next diatonic tone is a whole step up, so the inserted note lands strictly between the two and the run
  keeps climbing — verified by the shared property tests. Bebop scales are **box-only** (the passing tone
  isn't modelled by the neck-spanning generators, and its semitone steps don't climb the diagonal).

- **S3 — Symmetric scales are deferred, on purpose.** The diminished and whole-tone scales are not
  subsets of any major scale, so they'd need a new placement generator rather than a box filter. Parked in
  `docs/backlog.md` until that generator is warranted; nothing here blocks it.

- **S4 — Additive and forward-compatible.** New enum cases only. An older build decoding a blob that names
  a new scale falls back to the minor pentatonic (`GuitarScale(storage:)`), and every scale authored before
  this ADR generates exactly as before.

## Consequences

- The catalog grows from 5 to 12 scales for one line of formula each, plus one generalised passing-tone
  helper — the generator's whole promise. Modes gain 3-NPS for free; bebop stays box-only.
- The "add a scale = add a formula" boundary is now explicit: it holds for any scale that is a **subset of
  a major scale** (diatonic modes) or a **mode plus fret-adjacent passing tones** (blues, bebop). Symmetric
  scales fall outside it and are the next generator's job.
- No migration, no renderer change, no test-plan change.
