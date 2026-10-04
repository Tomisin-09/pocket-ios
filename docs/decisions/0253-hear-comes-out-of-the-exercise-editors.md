# ADR 0253 — *Hear* comes out of the exercise editors

- **Status:** Accepted — decided with Tomisin, 2026-10-04. Built on `pocket-363-hear-out-of-exercises`.
- **Date:** 2026-10-04
- **Amends:** ADR 0097 — **D4.6**: the table's rows for scale patterns, arpeggios and fretboard /
  picking runs no longer have a surface, so the slices that wired them into the exercise editors
  (3 and 4) are undone. D4.1–D4.5 stand, as do the chord row and the tuner's reference tone, which
  were never in the table.
- **Relates to:** 0227 D8 (the same tone, withdrawn from *Name the notes*) · 0065 (the editors' *Watch*
  preview, which stays)
- **Schema:** none. Hear never stored anything.

## Context

Every fretboard-family exercise editor (Scales, Arpeggios, the warm-up and picking runs, and *Draw
your own*) carries one header row, `FretboardDisplayOptionsBar`. Until now it held **Hear**, **Watch**
and **Display**. *Hear* sounded the run one note at a time through `ToneEngine`, while the preview's
highlight walked in step. *Watch* shows only when the board isn't already walking: with *Animate
exercises* off, or Reduce Motion on (ADR 0077).

That tone is ADR 0097 D4.2's built-in sampler voice: a clean pitch reference, not a guitar. ADR 0227
D8 already took it out of *Name the notes*, because next to a real recording it did not sound close
enough to judge a match. Real guitar audio is designed and parked in `docs/backlog.md` (*Real guitar
audio for chords and strums*). Tomisin, 2026-10-04: *"while we're still planning on getting real
guitar sounds, let's get rid of Hear for exercises."*

The scope was Tomisin's choice: the exercise editors only.

## Decision

| # | Decision |
|---|---|
| **D1** | **The exercise editors lose Hear.** The header row of all four editors holds **Display**, and **Watch** when the board isn't already walking. `FretboardHearButton` is deleted, along with `heardMidi(for:)` on `ScaleRun`, `ArpeggioRun` and `FretboardRun` and `Instrument.midi(of:)`. Those four had no other callers and no tests. The editors no longer start a tone, so they no longer stop one on disappear either. |
| **D2** | **The chord Hear and the tuner stay.** `ChordHearButton` on the My chords detail and the custom chord sheet, and the tuner's reference tone, are unchanged. So are `ToneEngine`, `HearPlan`, `HearPlanTests` and `hearStopsOnDisappear()`, which the chord surfaces still use. |
| **D3** | **It comes back with real guitar audio, not before.** The backlog's design puts a recorded sample bank behind the same `ToneEngine` path, still fed MIDI, so returning is a revert of this change's code, which git keeps. The decision to bring it back belongs to that work. |

### Rejected

- **Taking Hear out everywhere at once**, chords and tuner included. A chord's *Hear* is checking
  which notes a voicing holds, which is the pitch-reference job D4.2 chose the tone for, and the
  tuner needs a reference pitch. Not this change's call.
- **Keeping `heardMidi(for:)` for the day Hear returns.** Unused code with no tests drifts from the
  models it reads. Git keeps it, and it is three lines per model.

## Consequences

- An exercise editor makes no sound. The board walks the shape as before, and *Watch* still walks it
  once where it shows.
- The header row has one item fewer. Nothing takes Hear's place. With the default settings the row is
  *Display* alone, at the trailing edge; with animation off, *Watch* sits at the leading edge.
- The manual's *New exercise* page loses its line that **Hear** plays the shape back. Figures of the
  four editors show the old row and go on the reshoot list.
