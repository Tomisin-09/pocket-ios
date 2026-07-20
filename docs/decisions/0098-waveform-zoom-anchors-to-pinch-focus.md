# 0098 — Pinch-zoom anchors to the gesture focal point, not the playhead

- **Status:** Accepted
- **Date:** 2026-07-20 (`pocket-160-waveform-zoom-anchor`)

## Context

On-device user testing (2026-07-20, plan-of-attack Note 5) flagged the detail
waveform's pinch-zoom as the biggest "feels weird" moment. You pinch to inspect a
spot, and the window **shifts out from under your fingers** — the thing you were
looking at slides away as you zoom.

The cause is that zoom is anchored to the **playhead**, never to the pinch. The
gesture (`WaveformCanvasGestures.magnifyGesture`) captures only the magnification
and calls `setZoomSpan`, which sets `zoomSpan` and then runs `advancePageIfNeeded`
— the page-mode re-anchor (ADR 0010) that keeps the *playhead* comfortable in the
window. The `MagnifyGesture` focal point (`value.startAnchor`) is discarded. So the
window recomposes around the playhead, not around where the fingers are, and any
point that isn't the playhead drifts. When paused — the common "let me look at this
bit" case — the playhead is off doing nothing useful, so the drift is pure noise.

Every direct-manipulation zoom users have a reference for (Photos, Maps, PDF) keeps
the point **under the pinch centre** fixed while the scale changes. The waveform
should do the same.

## Decision

- **Anchor pinch-zoom to the gesture focal point.** Keep the song fraction under the
  pinch centre pinned to the same on-screen position as the span changes. `MagnifyGesture.Value`
  exposes `startAnchor` (a `UnitPoint` in the canvas's coordinate space); its `.x`
  is the focal *screen* fraction (`0…1`) on the visible waveform. The gesture passes
  that alongside the new span.
- **The anchoring math is pure and unit-tested.** A new
  `WaveformGesture.zoomAnchored(baseStart:baseSpan:focalScreenFraction:newSpan:)`
  returns the new `viewportStart` that holds `focalSong = baseStart +
  focalScreenFraction · baseSpan` at `focalScreenFraction` on screen:
  `start = focalSong − focalScreenFraction · newSpan`, clamped to `0…(1 − newSpan)`.
  This is the slider-style mapping AGENTS.md requires covered; it lands in the same
  pure `WaveformGesture` enum as `clampSpan`/`pagedStart`, next to its tests.
  Recomputing the focal song fraction from the *current* (already-anchored) viewport
  each frame is stable — anchoring preserves it — so the gesture only needs to keep
  capturing `pinchBaseSpan`, no extra base-start state.
- **A new `model.setZoom(span:focalScreenFraction:)` replaces the gesture's
  `setZoomSpan` call.** It sets `zoomSpan` and derives `viewportStart` from the focal
  anchor instead of calling `advancePageIfNeeded`. `setZoomSpan` stays for programmatic
  callers (`resetZoom`, tests) that have no focal point.
- **An optional "Zoom follows playhead" pin, default off.** A persisted setting
  (`AppSettings.zoomFollowsPlayhead`, default **off** = focal anchoring) restores the
  legacy playhead-anchored paging *during the pinch* for anyone who wants the window
  to recenter on the playhead as they zoom. Off is the fix; on is the escape valve.
- **Page-mode (ADR 0010) is untouched.** Focal anchoring governs only the *pinch
  gesture*. During playback the window still auto-pages to keep the playhead visible
  on the next tick — that behaviour is desirable and separate. The bug was only that
  the *zoom* re-anchored to the playhead; paging during playback stays.

## Consequences

- Pinch-zoom holds the spot under your fingers — the reported drift goes away — which
  is most of the perceived-quality lift in Wave 1.
- One closure signature widens: `WaveformView.onSetZoomSpan: (Double) -> Void` becomes
  `onSetZoom: (Double, Double) -> Void` (span, focal screen fraction). Touches the one
  live call site (`WaveformPracticeLayout`) and the component previews.
- A new default-off setting. Default-off means a missing key reads correctly with a
  plain `UserDefaults.bool` (no `resolvedBool` needed), and existing users get the
  improved behaviour without opting in.
- At the song ends the anchor clamps (you can't scroll past `0`/`1`), so the focal
  point drifts there — standard, expected zoom-at-bounds behaviour.

## Out of scope (follow-ups)

- **Note 4 — snap yields near adjacent loops.** The other Wave 1 waveform item
  (loop-edit snap fighting a close neighbour) is a different code path (release-time
  snap on `endABHandle`, not the zoom gesture) and gets its **own ADR + branch**.
- **Rotary / haptic zoom mode** (parked backlog item) — a non-pinch zoom affordance.
  Unrelated to *what pinch anchors to*; still parked.
- **A focal-point indicator** (a transient tick at the pinch centre) — deferred;
  the fixed content under the fingers is its own feedback.

## Alternatives considered

- **Keep playhead anchoring, make it the default (status quo).** Rejected: it *is*
  the reported "feels weird." Playhead-centred zoom only makes sense while chasing a
  moving playhead, which the follow-playhead pin still offers opt-in.
- **Center zoom on the viewport midpoint.** Rejected: better than the playhead, but
  still ignores intent — you pinch *at* the spot you care about, and the focal point
  is right there in the gesture for free.
- **Capture a separate `pinchBaseStart` in the gesture.** Unnecessary: recomputing
  the focal song fraction from the current viewport each frame is stable because
  anchoring preserves it, so the existing `pinchBaseSpan` capture suffices.
