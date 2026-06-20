# 0018 — Loop & marker visibility: lane-stacked brackets, colour = state

- **Status:** Accepted; **colour = state superseded by [ADR 0023](0023-blue-theme-bordered-loop-identity.md)**
  (lane stacking retained, colour now encodes loop identity).
- **Date:** 2026-06-19

## Context

The waveform drew only the **active** loop (a translucent amber region) and the
in-progress capture selection. Saved loops and markers existed in the data model
(`Song.loops`, `Song.markers`) but were invisible on the detail waveform — you
couldn't see your loop library against the timeline, only whichever loop was
currently active. The minimap already drew all markers (purple dots) and the
active loop, but no other loops.

Showing *all* loops raises an immediate question: loops overlap. In a practice
app overlap is the normal case, not an edge case — a wide "whole solo" loop with
a tight "hard lick" loop **nested** inside it, plus a transition loop that
straddles two sections. Whatever we draw has to handle full containment and
several simultaneous overlaps, not just partial overlap.

## Decision

- **Overlap is shown by vertical position (lanes), not colour.** Saved loops are
  drawn as thin brackets along the bottom of the waveform. When loops overlap in
  time, the later one drops to the next lane down — the classic greedy
  interval-graph packing (minimum lanes = maximum overlap depth). This is the
  proven pattern from calendars and DAWs and scales to any number of loops.
- **Colour is reserved for state, never identity.** All loops use the one loop
  accent (`PocketColor.marker`, amber). The **active** loop keeps its translucent
  fill and gets a full-opacity, slightly thicker bracket; inactive loops get a
  dimmed (0.5) bracket. Per-loop colours were rejected (see Alternatives): they
  don't actually resolve overlap, run out, and collide with the functional colour
  system where hue already means something (`active`=green, `fine`=blue,
  `pin`=purple).
- **Markers are pins from the top; loops are brackets from the bottom.** The two
  annotation types read as distinct shapes pointing from opposite edges, so they
  never compete for the same space. Markers: purple stem + dot head dropping from
  the top. Loops: amber bracket with feet pointing up along the bottom.
- **Overlay, don't grow the frame (capped lanes).** Brackets live in the dead
  space below the reflected bars in the fixed 140 pt waveform — at ~7 pt/lane the
  common 0–2 overlaps cost nothing and the layout never jumps as loops are
  added/removed. Lanes are capped (`maxLanes` = 3 on the detail waveform, 2 on the
  minimap); deeper nesting clamps into the last lane rather than marching up into
  the bars. A reserved gutter (always shrink the bars) and a dynamic height
  (frame grows with lane count) were both rejected for paying a steady-state cost
  / causing layout instability.
- **The packing is pure and tested.** Lane assignment lives in `LoopLanes` (a
  value-type `Interval` in, an id→lane `Packing` out) with no SwiftUI — the logic
  that silently mis-stacks without coverage is unit-tested per AGENTS.md. The
  drawing layer (`WaveformView`, `Minimap`) decides how many lanes it can afford;
  `LoopLanes` always returns true lanes. Touching loops (one ends exactly where
  the next begins) share a lane.

## Consequences

- The whole loop/marker library is visible against the timeline at a glance, on
  both the detail waveform and (compressed) the minimap.
- The active loop still stands out via its fill + brighter bracket, so the
  active-vs-saved distinction survives drawing every loop.
- `Loop`/`Marker` gain no schema fields — no per-loop colour, no lane storage.
  Lanes are derived at draw time, so reordering/editing loops can't desync a
  stored lane.
- Lane depth > 3 (detail) / > 2 (minimap) clamps into the last lane. If deep
  nesting turns out common in practice, revisit the cap or add a "+n" affordance.

## Alternatives considered

- **Different-coloured brackets per loop** — rejected: colours collide when
  brackets share a vertical position (overlap is unresolved), the palette is
  already functional (hue = state/type), and it doesn't scale past a handful of
  loops with no semantic hook to remember them by.
- **Lanes + a per-lane colour tint** — rejected: reintroduces palette pressure
  and complexity for a redundant cue; position already encodes overlap.
- **Reserved bottom gutter** (always carve out space for brackets) — rejected:
  pays a real-estate cost even with zero loops.
- **Dynamic waveform height** (grow with lane count) — rejected: the waveform
  visibly jumps and shoves the minimap/transport around as loops come and go.
- **Tappable brackets to activate a loop** — deferred: this slice is visibility
  only; selecting a loop by its bracket is a later interaction slice.
