# 0055 — Minimap draws the song envelope, not a flat track

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

The minimap is the full-song overview strip: loops, markers, the viewport box, and
the playhead drawn over a base "track." That base was a **flat rounded pill**
(`PocketColor.barPlayed`), so every song's map looked identical — a featureless bar
with no sense of the song's shape. User testing wanted the minimap to read as a
*friendly overview* you can orient by (quiet intro vs. loud chorus), not just a
percentage scrubber.

## Decision

Replace the flat base track with a **compressed whole-song silhouette**: the stored
0…1 envelope (`WaveformPracticeModel.amplitudes`, the same ~512-bar whole-song
envelope the zoomed-out detail waveform uses) drawn as a mirrored filled path
centred in the 28 pt strip.

- **Shaped through the existing display gamma.** Each sample passes through
  `WaveformAmplitude.display` (ADR 0049), so the minimap gets the same fuller/calmer
  dynamic-range compression as the detail waveform — they read as one instrument, not
  two different renderings.
- **Same muted colour** (`barPlayed`), so it stays a background: loops, markers, the
  viewport box, and the playhead still draw on top and stay the salient elements.
- **Falls back to the flat pill** while `amplitudes` is empty (still extracting), so
  the strip never renders blank.
- **Draw-only.** No new data, no model change beyond passing the envelope the model
  already holds into `Minimap`. Snapping, seeking, loop math, and the un-snapped
  minimap scrub are untouched.

## Consequences

- The minimap now maps the song's shape; orientation at a glance improves.
- Reuses tested pieces (`WaveformAmplitude`), so no new pure logic to unit-test; the
  change is Canvas rendering, verified visually on device.
- The per-loop-colour / triangle-glyph minimap upgrade deferred by ADR 0023 is still
  open and independent of this.
