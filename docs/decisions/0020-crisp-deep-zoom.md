# 0020 — Crisp deep-zoom: re-downsample the visible range

- **Status:** Accepted
- **Date:** 2026-06-19 (`pocket-021-crisp-deep-zoom`)

## Context

Page-mode zoom (ADR 0010) gave the detail waveform an owned `viewport`, but the
bars it draws are still the song's **stored 512-bar envelope** (ADR 0017),
stretched to fill the visible window. At a 5% span only ~25 of those bars cover
the whole width, so a deep zoom looks chunky — the very moment you zoom in to
place a loop boundary precisely, the envelope gets *coarser*, not finer. ADR
0010 flagged this as a follow-up ("V1 stretches the fixed bars"). It is also the
substrate the next slice (long-press-drag select) stands on: drawing a precise
region only pays off if the bars under your finger are sample-accurate.

The data to do better already exists — the source file is DRM-free (ADR 0001)
and the model resolves its URL — it just isn't re-read at finer resolution once
the window narrows.

## Decision

- **When zoomed, re-downsample the visible range from the source file** to
  `WaveformExtractor.defaultBuckets` bars, so the bars on screen always describe
  the window at full detail rather than stretching the whole-song envelope.
  `WaveformExtractor.extractWindow(from:startFraction:endFraction:buckets:)`
  seeks to the window's start frame and reads only that range (chunked, like the
  full extract), mixes to mono, and reduces with the same pure
  `AudioMath.downsample`. The frame range is the pure, unit-tested
  `AudioMath.windowFrameRange(startFraction:endFraction:totalFrames:)`.
- **The stored 512-bar envelope stays the zoomed-out and fallback path.** At
  span 1 it already covers the whole song at full detail, so there's nothing to
  refine; it is also what's drawn while a windowed read is in flight or if one
  fails. Deep zoom degrades to "chunky but correct", never to "blank".
- **The re-downsample is owned model state, computed off the main actor and
  debounced.** `WaveformPracticeModel.detailBars` holds `(bars, window)`;
  `scheduleDetailRefresh()` (driven by `onChange(of: viewport)`) cancels any
  in-flight task, waits a short settle delay (so a continuous pinch or a burst
  of page flips coalesces into one read), then runs the extract on a detached
  task. Results are kept only if the viewport hasn't moved on.
- **A small LRU-ish cache keys windowed bars by the quantised window** so paging
  back and forth — or pinching to a span just visited — reuses a prior read
  instead of hitting the file again.
- **Rendering maps each bar through its covered range, then the viewport.**
  `WaveformView.drawBars` takes the bars plus the song range they cover (`[0,1]`
  for the stored envelope, the window for a crisp read) and maps bar *i* to
  `coveredStart + (i + 0.5)/count · coveredSpan`, then through the existing
  `screenFraction(songFraction:viewport:)`. So crisp bars that exactly fill the
  viewport draw 1:1, and bars from a *slightly stale* window (the viewport paged
  while the read finished) still land in the right place and off-screen ones are
  skipped — the fresh read replaces them a moment later.

## Consequences

- A deep zoom now resolves real detail (transients, note onsets) instead of
  fat stretched blocks, so a drawn or dragged boundary lands where the audio
  actually is. This is what makes the upcoming long-press-drag select worth
  having.
- One extra async path (file read per settled viewport), bounded by the debounce
  and the window cache; the engine's playback file is untouched. Memory cost is a
  single window's PCM during the read, not the whole song held resident — chosen
  over keeping the full decoded buffer in RAM (tens of MB per song, worse for
  long or hi-res / not-yet-downloaded iCloud files).
- `WaveformView` gains an optional `detailBars` input and a covered-range arg on
  `drawBars`; the stored-envelope behaviour is the default when it's `nil`.
- The model retains the resolved source URL (`sourceURL`) for both the imported
  file and the demo sample, so crisp zoom works in dev too.

## Out of scope (follow-ups)

- Pre-fetching the next page's window before the playhead reaches the edge.
- Free pan / two-finger scroll (still page-mode, per ADR 0010).

## Alternatives considered

- **Keep the whole decoded PCM in memory and slice it per viewport** — rejected:
  tens of MB per song resident, unbounded for long or hi-res files, and pointless
  while paused. A debounced, cached windowed read is cheap enough.
- **Store a multi-resolution pyramid (mipmap) on the `Song`** — rejected for V1:
  more persistence surface and a new stored-format version for a gain a live
  windowed read already delivers; revisit only if file reads prove too slow on
  device.
- **Refine on every viewport tick** — rejected: page flips and pinch are bursty;
  an un-debounced read would thrash the file. The viewport already only changes
  at page edges (ADR 0010), and the debounce coalesces pinch.
