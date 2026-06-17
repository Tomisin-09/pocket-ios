# 0010 — Pinch-to-zoom: viewport tracks the playhead

- **Status:** Accepted
- **Date:** 2026-06-16

## Context

The detail waveform always showed the whole song, so there was no way to work
precisely on a short section, and the minimap's viewport box had nothing to point at
(hidden in pocket-008). We want pinch-to-zoom. The mechanism question: every gesture
maps screen-x straight to a song fraction (`WaveformGesture.fraction(atX:width:)`) and
everything draws at `width × songFraction` — zoom has to slot a transform into both
paths — and the navigation question: once zoomed, how do you move around?

## Decision

- **A viewport `(start, end)` (song fractions) is the single zoom state**, derived
  from a `zoomSpan` (visible fraction of the song) centred on the playhead and clamped
  to `[0,1]` (`WaveformGesture.viewport(center:span:)`). The model owns `zoomSpan`;
  `viewport` is computed.
- **The viewport tracks the playhead; there is no pan gesture.** You navigate by
  seeking (tap / scrub / minimap), and the view follows. This avoids arbitration with
  the existing one-finger drag gestures (scrub, Fine handles, hold-to-marker), and
  suits a practice tool where you work at the playhead. Free two-finger panning was
  rejected for V1 as unnecessary complexity.
- **Pinch sets the span** via `MagnifyGesture` (iOS 17+; `MagnificationGesture` is
  deprecated), added as a `.simultaneousGesture`. The span at pinch-start is captured
  so magnification scales it directly; the one-finger drag is gated off while pinching.
- **One transform, two directions, kept pure.** `WaveformGesture.songFraction(screenFraction:viewport:)`
  maps touches → song fractions before they reach the (unchanged) model handlers;
  `screenFraction(songFraction:viewport:)` maps the other way for rendering. Both are
  unit-tested; the handle-grab tolerance is scaled by span so it stays constant on
  screen.
- **The minimap shows the live viewport box** when zoomed (full-song draws nothing);
  it stays full-song and its drag still seeks → playhead → the view follows.

## Consequences

- The minimap viewport box is meaningful again (live), closing the loop on hiding it
  in pocket-008. The static `WaveformMock.Song.viewport` field is removed.
- Model handlers are untouched — they still receive plain song fractions; the zoom
  transform lives entirely in the view + pure gesture math.
- `WaveformCanvas.swift` crossed the SwiftLint file-length limit, so the `Minimap`
  moved to `WaveformMinimap.swift`.

## Out of scope (follow-ups)

- **Bar fidelity.** V1 stretches the existing fixed 120 downsampled bars, so a deep
  zoom looks chunky. Crisper zoom = re-downsample the visible range from the source
  buffer when the viewport changes.
- Free pan / two-finger scroll.

## Alternatives considered

- **Free pan (audio-editor style)** — rejected for V1: needs a two-finger pan gesture
  and arbitration with the drag gestures; the playhead-tracking model is simpler and
  fits practice.
- **Zoom centred on the pinch midpoint** — rejected: centring on the playhead ties
  cleanly to the follow-the-playhead model and keeps the bubble/playhead stable.
- **`MagnificationGesture`** — rejected: deprecated on iOS 17; use `MagnifyGesture`.
