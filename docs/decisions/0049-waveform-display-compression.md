# 0049 — Waveform display-amplitude compression

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

User testing flagged the practice waveform as "aggressive" — spiky and off-putting
next to a reference like SoundCloud's. The instinct in the raw note was "make it
smoother, trade accuracy for appealing design." Taken literally that's impractical:
SoundCloud's waveform is **display-only** (you don't set loops, drop markers, or drag
edges against it), whereas ours is the **editing substrate** — loop bounds and markers
snap to its peaks (ADR 0017/0020/0021). Smoothing the underlying data would drift the
very positions the musician edits against.

Diagnosing the gap against the actual renderer: the stored envelope is already
peak-normalised to 0…1 (`AudioMath.downsample`, 95th-percentile reference, ADR 0017),
but `drawBars` painted it **linearly** (`topHeight = amp · scale`). Because the
normalisation reference is the 95th percentile, most bars sit well below the ceiling,
so a linear draw is a jagged, low skyline. That — not missing normalisation — is what
reads as aggressive. SoundCloud's friendlier look is two tricks: normalisation (which
we already do) and **dynamic-range compression** (which we didn't).

## Decision

Add compression as a **display-only** transform, decoupling render from data:

- A pure `WaveformAmplitude.display(_:)` applies a gamma curve (γ = 0.6) to the
  normalised amplitude before it becomes a bar height. γ < 1 lifts the quiet/mid bars
  toward the top for a fuller, calmer skyline; the endpoints are pinned (silence stays
  flat, a full bar stays full) and the curve is monotonic (louder never draws shorter).
- It shapes **only the drawn height**. Snapping, markers and loop edges keep reading the
  raw peaks, so editing precision is untouched — the accuracy-vs-appeal trade resolved by
  decoupling, not by smoothing the samples we position against.
- The curve is pure, Foundation-only, and unit-tested (`WaveformAmplitudeTests`):
  endpoints pinned, monotonic, genuinely lifts the mid-range, clamps out-of-range input,
  and γ = 1 is the linear identity (a clean opt-out).

The rendering pass landed in three display-only moves on the same branch:

1. **Compression** — the gamma curve above (`WaveformAmplitude`).
2. **Widen + smooth** — thin ~1px bars read as a jittery comb even once lifted, so
   `WaveformBars` groups source bars toward a target on-screen width (~4px) and draws each
   as the **mean** of its group: wider *and* smoother (the averaging low-passes the comb).
   It self-tunes with zoom — group size is 1 once bars are already wide enough, so a deep
   zoom / crisp re-downsample (ADR 0020) keeps full transient detail. Pure, unit-tested
   (`WaveformBarsTests`).
3. **Calmer geometry** — bars gained rounded tops (square at the axis so the baseline stays
   crisp) and the mirror reflection dropped to 0.3 opacity — a quieter mirror.

Giving the **minimap** its own compressed envelope — it currently draws a flat progress
track, not a waveform — is left as a later slice.

## Consequences

- The waveform reads fuller and less spiky with zero change to editing accuracy, model,
  or persistence — a pure draw-time transform over data already in hand.
- The compression is uniform, not per-window, so a passage keeps the same shape as you
  zoom (the crisp re-downsample of ADR 0020 feeds the same curve); no disorienting
  re-scaling between zoom levels.
- γ is a single tunable constant. If 0.6 reads too flat or too tame on device, it moves
  in one place without touching the draw or the data path.
- The deeper "structure over amplitude" ideas from the same review (frequency colour,
  section cues) are **not** taken here — this stays a monochrome amplitude shape; those
  remain open if the rendering pass proves insufficient.
