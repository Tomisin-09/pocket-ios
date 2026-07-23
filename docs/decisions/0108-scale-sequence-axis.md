# 0108 — Scale sequence axis (thirds, fourths, groups)

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-173-scale-sequencing`)
- **Builds on:** ADR 0065 (the generative scale engine — `ScaleRun` × `GuitarScale` × `CAGEDShape`),
  ADR 0083 (the `ScaleLayout` axis, which explicitly parked sequencing as "a SEPARATE orthogonal future
  axis over ALL layouts, its own later ADR").

## Context

Practising a scale "in thirds" (1 3 2 4 3 5 …), in fourths, or in rolling groups of three/four is a
core technique drill. ADR 0083 anticipated it as a distinct axis but deferred it. It's the natural
counterpart to the custom-scale canvas (ADR 0107): the canvas lets you *draw* an arbitrary pattern, but
hand-placing a 14-note "major scale in thirds" is tedious — a mechanical, well-defined pattern is
exactly what a generator should produce for you.

Crucially, sequencing does **not** need the box-generator surgery symmetric scales did. It doesn't
change *which* notes a scale produces — only the **order** they're played. So it's a pure permutation of
the already-generated note list, orthogonal to scale/root/position/layout, and it can't fight the CAGED
boxes or the one-hand-span test net (those lock `ascendingNotes`, which sequencing leaves untouched).

## Decision

Add a **sequence axis** to `ScaleRun` — a pure `SequencePattern` applied to the generated run:

- **`SequencePattern`** (`.straight` · `.thirds` · `.fourths` · `.groupsOfThree` · `.groupsOfFour`): a
  pure enum whose `indices(count:)` returns the reordering for a run of N ascending notes. `.straight` is
  the identity (today's behaviour); the intervals pair each note with the one two/three steps above
  (dropping the pair off the top of the scale); the groups roll a window of three/four. Every original
  index is always emitted, so **no note is dropped** and the whole scale is still practised. An `apply`
  helper reorders the notes **and** the index-aligned box-focus `groups` (ADR 0083 S2b) in step.
- **`ScaleRun.sequenceRaw`** — String-backed (ADR 0036), decode-defaulting to `.straight`, so every
  scale authored before this axis plays byte-identically (no store migration). Threaded through the
  init, `CodingKeys`, and `init(from:)` exactly like `layoutRaw`.
- **Applied in `sequenceWithGroups`** — the *played* run — not in `ascendingLayout`. So `ascendingNotes`
  (and everything that reads it — `rootAnchor`, `anchorFret`, `positionLabel`, `isMostCommon`, and the
  box regression tests) is unchanged; only the played/expanded order differs. Round-trip then mirrors the
  sequenced run as before.
- **A Sequence picker** in `ScaleRunEditor`, offered for every layout (it's orthogonal). A curated
  `ScaleRun.gMajorInThirds` seeds a "G Major — in 3rds" preset (v11 batch) so the axis ships with content.

## Consequences

- "In thirds / fourths / groups" is one menu tap on any generated scale, and it plays and animates like
  any other scale run — no hand-placement. The custom canvas (ADR 0107) remains the path for patterns
  the five presets don't cover.
- Zero risk to the box generator: `ScaleRun` gains one additive, decode-defaulted field; the permutation
  is pure and unit-tested (index math, coverage, `ascendingNotes` invariance, Codable back-compat).
- The sequence composes with the layout axis (box / extended / 3-NPS) since it reorders whatever ascending
  notes the layout produced — no per-layout gating needed.

## Out of scope (follow-ups)

- **Sixes / broken patterns / custom groupings** beyond the five shipped — more `SequencePattern` cases
  are additive if wanted.
- **Sequencing arpeggios.** `ArpeggioRun` shares the generator shape and could take the same axis; left
  until there's a need.
- **Descending-first / pattern-direction options.** Today round-trip mirrors the ascending sequence;
  a "start descending" variant is a later toggle if asked for.

## Alternatives considered

- **Only the custom canvas (ADR 0107).** Draw the pattern by hand. Fine for one-offs but tedious for the
  long mechanical patterns sequencing is *for* — a generator is the right tool, and it's cheap and
  low-risk here.
- **Applying the permutation in `ascendingLayout`.** Would have changed `ascendingNotes` and forced the
  box labels/anchors and their locked regression tests to reckon with a non-ascending list. Keeping
  sequencing in the played layer keeps the box's identity intact.
