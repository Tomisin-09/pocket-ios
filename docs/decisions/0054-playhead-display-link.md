# 0054 — Drive the playhead from a display link, not a Timer

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

The waveform playhead moved in visible hops rather than gliding. It was advanced
by a `Timer.scheduledTimer(withTimeInterval: 0.03)` (~33 Hz) that read the audio
player's sample position and republished `currentTime`. Two things made it jerky:

1. **33 Hz is below the display refresh** (60/120 Hz), so the playhead stepped
   instead of sweeping.
2. **A `Timer` is not vsync-aligned** — it beats against the display, so some frames
   got no update and some got two, adding stutter on top of the low rate.

The same timer also topped up the metronome click schedule, so the two concerns —
a *visual* cadence (wants display rate) and *audio* scheduling (wants a fixed
look-ahead horizon) — were coupled to one 0.03 s tick.

## Decision

- **Playhead on a `CADisplayLink`.** A small `DisplayLinkTicker` (`Core/Audio/`)
  wraps `CADisplayLink`, fires once per display frame, and calls `updateCurrentTime()`.
  Because the underlying `player.playerTime` sample position is continuous, sampling
  it at display rate yields smooth, monotonic motion for free. The link is added to
  the main run loop; the `@objc` callback hops through a plain `NSObject` proxy (the
  link retains its target) and the owner does its main-actor work via
  `MainActor.assumeIsolated` — valid because the callback runs on the main thread.
  The ticker `invalidate()`s on `stop`/`deinit` to break the target retain cycle.
- **Metronome stays on the `Timer`.** Click scheduling keeps its 0.03 s cadence
  (its look-ahead horizon covers that interval); it's now *decoupled* from the
  playhead, so raising the playhead cadence doesn't run click-scheduling 2–4× more
  often. `refreshMetronome` reads `currentTime`, which the display link now keeps
  *fresher* than before, so accuracy is unaffected.
- Lifecycle is unchanged: both start on `play()` and stop on `pause()`/`stop()`
  (`startTimer`/`stopTimer` now manage both clocks).

## Consequences

- The playhead sweeps at the display's native rate; no change to snapping, loop
  math, markers, or the loop-wrap playhead (`AudioMath.loopedPlayhead`).
- Slightly more `updateCurrentTime` calls per second (display rate vs 33 Hz), but
  each is cheap (read sample time + one clamp); the metronome's heavier scheduling
  work did **not** increase.
- Smoothness is a visual property — verified on device (previews/simulator don't
  reflect true refresh cadence), not by unit tests.
