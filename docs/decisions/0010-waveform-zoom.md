# 0010 — Pinch-to-zoom: page-mode viewport

- **Status:** Accepted — page-mode
- **Date:** 2026-06-16 (revised 2026-06-19, shipped on `pocket-020-page-mode-zoom`)

## Context

The detail waveform always showed the whole song, so there was no way to work
precisely on a short section, and the minimap's viewport box had nothing to point at
(hidden in pocket-008). We want pinch-to-zoom. The mechanism question: every gesture
maps screen-x straight to a song fraction (`WaveformGesture.fraction(atX:width:)`) and
everything draws at `width × songFraction` — zoom has to slot a transform into both
paths — and the navigation question: once zoomed, how do you move around?

The first cut (the original form of this ADR) made the viewport **track the
playhead**: it was recomputed every frame as `viewport(center: playheadFraction,
span:)`, pinning the playhead to screen-centre. On device this read poorly — the
playhead never appeared to move (the whole envelope slid underneath it instead), and
re-shifting the envelope on every engine tick stuttered.

## Decision

- **A viewport `(start, end)` (song fractions) is the single zoom state**, formed from
  two pieces of **owned model state**: `zoomSpan` (visible fraction of the song,
  `minZoomSpan…1`) and `viewportStart` (the anchored left edge). `viewport` clamps
  `viewportStart` to `0…(1 − span)`. The viewport is **not** derived from the playhead.
- **Page-mode navigation (GarageBand-style).** The window holds still while the
  **playhead sweeps left→right across it**; when the playhead reaches ~90% of the
  window it **pages forward** so the playhead reappears near the left (a small
  `leadIn` of context behind it). Seeking before the window pages it back. The pure
  `WaveformGesture.pagedStart(currentStart:span:playhead:)` computes the anchor; the
  model calls it from `advancePageIfNeeded()`, driven by the view's
  `onChange(of: playheadFraction)`. Because `viewportStart` only changes at page
  edges, the envelope is redrawn on a flip, not every tick — only the 1px playhead
  line animates between flips. The playhead also moves *faster* the deeper the zoom
  (same screen width spans fewer song-seconds).
- **A Fit / 1× reset affordance** (`ZoomResetButton`, top-trailing of the waveform,
  shown only while zoomed) returns to the whole song. Reset is an explicit control
  because double-tap is reserved for seek.
- **Pinch sets the span** via `MagnifyGesture` (iOS 17+; `MagnificationGesture` is
  deprecated), added as a `.simultaneousGesture`. The span at pinch-start is captured
  so magnification scales it directly; the one-finger drag is gated off while
  pinching. Setting the span re-anchors via `advancePageIfNeeded()` so the playhead
  stays on screen.
- **One transform, two directions, kept pure.** `WaveformGesture.songFraction(screenFraction:viewport:)`
  maps touches → song fractions before they reach the (unchanged) model handlers;
  `screenFraction(songFraction:viewport:)` maps the other way for rendering. Both are
  unit-tested; the handle-grab tolerance is scaled by span so it stays constant on
  screen.
- **The minimap and ruler read the owned viewport.** The minimap shows the live
  viewport box when zoomed (full-song draws nothing); the `TimeRuler` labels the
  visible window's time range — so both decouple from the continuously-moving playhead
  and jump only on page flips. The minimap stays full-song and its drag still seeks →
  playhead → the view follows.

## Consequences

- The playhead visibly travels across a static envelope; rendering is smoother and
  cheaper than the playhead-centred first cut.
- The minimap viewport box is meaningful again (live), closing the loop on hiding it
  in pocket-008. The static `WaveformMock.Song.viewport` field is removed.
- Model handlers are untouched — they still receive plain song fractions; the zoom
  transform lives entirely in the view + pure gesture math.
- `WaveformCanvas.swift` crossed the SwiftLint file-length limit, so the `Minimap`
  moved to `WaveformMinimap.swift`.
- The playhead-centred `WaveformGesture.viewport(center:span:)` is removed (superseded
  by `pagedStart` + owned `viewportStart`).

## Out of scope (follow-ups)

- **Bar fidelity.** ~~V1 stretches the existing fixed downsampled bars, so a deep zoom
  looks chunky.~~ **Resolved in ADR 0020** — the visible window is re-downsampled from
  the source file when the viewport changes.
- Free pan / two-finger scroll.

## Alternatives considered

- **Playhead-centred viewport (the original decision here)** — rejected after
  on-device testing: the playhead is pinned, the envelope slides under it, and
  re-shifting every frame stutters. Replaced by page-mode.
- **Free pan (audio-editor style)** — rejected for V1: needs a two-finger pan gesture
  and arbitration with the drag gestures; page-mode is simpler and fits practice.
- **`MagnificationGesture`** — rejected: deprecated on iOS 17; use `MagnifyGesture`.
