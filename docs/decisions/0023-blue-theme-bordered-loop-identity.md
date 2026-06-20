# 0023 — Blue/navy theme, bordered annotations, per-loop colour = identity

- **Status:** Accepted
- **Date:** 2026-06-20
- **Supersedes:** the "colour = state, never identity" decision of
  [ADR 0018](0018-loop-marker-visibility.md) (lane stacking is retained).

## Context

After ADR 0018 shipped (all loops one amber accent, overlap by lane) and its
visual-polish follow-up, the direction changed on review:

- The app's green identity (`active`/playing green, green waveform bars) should
  move to a **blue/navy** palette.
- Loop brackets and marker pins drew **over** the bars, competing with the song
  for the same space.
- Per-loop **identity** is wanted after all — each loop distinguishable at a
  glance — which directly reverses ADR 0018's central rule that colour encodes
  state, not identity.

## Decision

- **Blue identity on a near-black background, anchored on `#2a6796`.** A single
  source of truth in `PocketColor` (`Pocket/UI/DesignTokens.swift`): the
  background stays **near-black `#0F0F0F`** (a mid-navy was tried but the accents
  and per-loop colours contrast better on black); waveform bars → the anchor
  `#2a6796`. Blue is "the song" (bars); **green** (`active`) is the live state —
  playing, the forming loop, the active region — so the two never compete. **Fine**
  precision is a hue-shifted cyan (`#56C6D9`), distinct from both. (An earlier pass
  made `active` a lighter blue tint of the anchor; it read too close to the bars, so
  live state moved to green.) The tokens are grouped by semantic role in
  `PocketColor` as the seam a future swappable theme would slot into.
- **Loop-capture confirm/discard are a green ✓ / red ✗ icon pair.** `confirm`
  (green) and `danger` (red) tint a checkmark/xmark in the edit toolbar (was a
  blue/red `Y`/`N` letter pair). Green returns as "confirm/save" since `active`
  is no longer green.
- **Annotations live on the borders, off the bars.** The fixed 140 pt canvas
  reserves a top band (markers) and a bottom band (loops); the mirrored bars are
  drawn in the region between, so annotations never overlay the song. The mirror
  axis/scale are derived from the region (`BarRegion`) so a full bar plus its
  60% reflection exactly fills it. The beat grid and all region fills are clamped
  to the bar region; the playhead still spans full height so it reads across.
- **Markers are purple inverted triangles** along the top border (apex down at
  the position, a short precision tick into the bars). Colour is unchanged
  (`PocketColor.pin`, purple); only the glyph changed from the stem+dot pin.
- **Loops are per-loop coloured lines along the bottom border, lane-stacked.**
  Colour now encodes **identity** — each loop draws in its own hue from
  `PocketColor.loopPalette` (6 hues: amber, gold, coral, magenta, violet, teal —
  deliberately avoiding the functional hues blue/purple/green so loops never blend
  into bars, markers, or the green active wash).
  Overlap is still shown by **lane** (the `LoopLanes` packing from ADR 0018 is
  unchanged). **State** is now carried by weight/opacity, not colour: the active
  loop is heavier (2.5 pt, full opacity) and its region fill takes its own hue;
  parked loops are lighter (1.5 pt, 0.55). Loops dropped the upward "feet" — they
  are plain horizontal lines.
- **Colour assignment is pure and tested.** `LoopColors.slot(for:among:
  paletteCount:)` (`Pocket/Core/Audio/LoopColors.swift`) maps a loop to a palette
  slot by start-order (ties broken by end, then id — matching `LoopLanes`),
  modulo the palette count, so it's deterministic, order-independent, and wraps
  predictably. No SwiftUI, unit-tested per AGENTS.md; the view maps slot → `Color`.

## Consequences

- `Loop`/`Marker` still gain **no** schema fields — colour is derived at draw
  time from start-order, so editing/reordering can't desync a stored colour.
- Why ADR 0018 rejected per-loop colour, and why it's acceptable now: the old
  objection was that colour collides when brackets *share a vertical position*
  and that the palette is functional (hue = state/type). Moving annotations to
  the border bands plus keeping **lane** as the overlap cue means colour is now a
  redundant-but-helpful *identity* cue, not the overlap resolver — position still
  resolves overlap. The palette is curated to avoid the functional hues
  (blue = bars/fine, purple = markers), and state moved to weight/opacity.
- Once there are more than 6 simultaneous loops the palette wraps, so two distant
  loops can share a hue; lane position still distinguishes overlapping ones.
- `pin` (markers, purple) and `danger` (red) remain distinct; no red was
  introduced for markers.
- The minimap inherits the token changes (cyan fine, blue bars) but is **not**
  yet updated to per-loop colours or the triangle glyph — deferred; revisit if
  the two surfaces reading differently becomes confusing.

## Alternatives considered

- **Keep ADR 0018 (one accent, colour = state)** — rejected by the new
  requirement that each loop be individually distinguishable.
- **Grow the frame / reserved gutter that always shrinks bars** — the bands do
  shrink the bar region slightly, but within the fixed 140 pt frame, so the
  layout never jumps as loops/markers come and go (same stability goal as 0018).
- **Per-loop colour stored on the model** — rejected: derived-at-draw-time keeps
  the schema clean and immune to reorder/edit desync.
- **Markers as red triangles** — considered, rejected: red is `danger`; keeping
  markers purple avoids the functional-colour clash.
