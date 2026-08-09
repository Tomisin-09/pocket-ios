# ADR 0154 — a grid you can correct as you go

- **Status:** Accepted
- **Date:** 2026-08-09 (`pocket-249-beat-grid-anchors`)
- **Extends:** ADR 0022 (the grid is tempo + one phase anchor), ADR 0024 (tap tempo, `preciseBPM`)
- **Relates to:** ADR 0004 (BPM is best-effort and user-correctable), ADR 0026 (the in-song click)

## Context

The metronome phases in and out of alignment on a J Dilla production. It locks for a while,
slides away, then slides back. Setting the BPM more carefully doesn't help.

**The click engine is not at fault.** `MetronomeSchedule` re-derives every beat from the heard
playhead every 30 ms and re-anchors on each transport discontinuity (ADR 0026). It is faithfully
rendering a grid that is wrong.

The grid is wrong because a song's entire rhythmic model was two numbers. `Song.preciseBPM` and
`Song.downbeatSeconds`, drawn as a straight line by `BeatGrid`:

```swift
let time = downbeat + Double(beatIndex) * interval   // interval = 60.0 / bpm
```

Phase error therefore accumulates as ∫(played tempo − stored tempo)·dt away from the anchor.
Against drums played by hand, without quantisation, the *mean* tempo fits and the *local* tempo
does not — which is exactly the reported symptom. Nothing else in the system could rescue it:
`Loop` carries no tempo or phase fields at all, so a loop start never becomes "the 1", and every
acquisition path collapses to the same two scalars (`TempoMath.bpm(fromTapTimes:)` takes the
arithmetic mean of *all* inter-tap gaps; `TempoEstimator` takes one autocorrelation peak plus one
comb-filter offset).

ADR 0004 §15 already named rubato as a failure mode **of the estimator**. That is a different
claim, and it let this one hide: nothing recorded that a grid could be right on average and wrong
locally, which is the case where the numbers all look fine and the click still sounds broken.

## Decision

**Keep one tempo per song. Let a song carry more than one 1.**

`Song.extraDownbeatSeconds: [TimeInterval] = []` sits beside the existing `downbeatSeconds`,
which stays the primary anchor — so no stored data changes and no existing call site moves. The
grid reads `Song.downbeatAnchors`, the primary plus corrections in time order, empty when no
primary is set (a correction without a 1 is meaningless and must never grid a song on its own).

`BeatGrid.beats(bpm:duration:anchors:beatsPerBar:)` cuts the line into segments. Beats run
forward from each anchor until the next; before the first anchor the grid extrapolates backwards
as it always has. The single-anchor entry point is now a delegation to `anchors: [downbeat]`, and
`BeatGridTests` pins that the two forms agree across a spread of shapes.

Two rules do the real work:

1. **The bar count restarts at every anchor.** An anchor *is* a 1. A correction that kept the
   running count would fix the click and leave the bar lines wrong, which is the worse of the two
   failures — the click can be turned off, the bar lines are how the waveform is read.
2. **No two beats may be *closer* than half an interval.** This is the one invariant that makes
   the function total, and it applies wherever two beats can collide: a segment's last generated
   beat approaching the next anchor is dropped (the anchor's own beat wins, or a correction
   audibly double-clicks at the seam), and two anchors placed almost on top of each other collapse
   to the earlier. *Closer*, strictly — a beat landing exactly half an interval before an anchor
   survives, because that's an eighth-note gap, a legitimate offbeat rather than a stumble.

The same half-interval rule decides what a drop *means* in the UI: within half a beat of an
existing anchor it nudges that anchor, beyond it becomes a new correction. Storing a
near-duplicate would leave a correction in the song that `BeatGrid` provably discards.

**✓ corrects, and moving is explicit.** With no 1 yet, ✓ sets it. With one already placed, ✓
means *correct from here* and leaves the original alone — that is what a return to this bar
almost always means. Replacing the original is the rarer intent and gets its own plain-text
"Move the 1" control, which deliberately leaves corrections untouched: they are anchored to their
own sections and are still right.

**Corrections are visible and removable.** They draw on the waveform as dashed ticks while a new
one is being placed, and the downbeat bar carries a count and a Clear. Clear removes all of them
and is **undoable** through the existing toast, which is what makes one clear-all an honest
removal path rather than a way to lose work.

## Alternatives considered

**A full tempo map** — a list of (time, BPM) with interpolation, replacing the scalar. Genuinely
correct for material whose tempo moves continuously, and rejected for now on cost: it touches
`BeatGrid`, `TempoEstimator`, the schema and needs an authoring UI, for material most players
don't bring. Anchors get most of the benefit for a fraction of the surface, and they compose with
a tempo map later rather than blocking one.

**Per-loop tempo and downbeat overrides on `Loop`.** Fits the workflow — practice happens in
loops — but leaves the whole-song waveform grid wrong whenever no loop is armed, which is where
the drift is noticed in the first place.

**Detect the drift automatically and re-anchor.** Rejected under ADR 0004: estimates aren't
truth, and silently moving a grid the player set is worse than leaving it where they put it.

**A distance heuristic instead of an explicit Move control** — infer "nudge the 1" vs "correct
from here" purely from how far the drop lands. Kept as the *near-anchor* rule, where the two
intents genuinely coincide, but not as the whole decision: at a distance the two intents are
different things and the app shouldn't guess between them.

## Consequences

- **This does not make one BPM per song correct.** It stops error accumulating past the section
  being worked on; a track that genuinely accelerates still needs marking every so often. Said
  plainly in the BPM sheet footer and in a new Help entry rather than left for the player to
  discover — the honesty rule ADR 0004 set.
- `WaveformPracticeModel.GridKey` gains `anchors` in place of a single `downbeat`, so adding or
  removing a correction misses the memoised grid's cache (ADR 0153). Without that the grid would
  silently keep the phase you just corrected.
- Additive `[Double]` with a declaration default, the same shape as `Song.collections` and
  `Loop.tags` — primitives, no stored enum, no `@Model` promotion — so lightweight migration
  fills pre-0154 songs with an empty array (CoreData 134110). **Verified on device over an
  existing install**, per `docs/swiftdata-gotchas.md`; the in-memory test store starts empty and
  cannot catch a migration failure.
- Tap tempo still averages every inter-tap gap with no window (`TempoMath.bpm(fromTapTimes:)`),
  so on drifting material it yields a number that fits nowhere in particular. Independent of this
  work and parked in `docs/backlog.md`.
