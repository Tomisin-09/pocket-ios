# 0017 — Waveform reduction: RMS energy, percentile-normalised

- **Status:** Accepted
- **Date:** 2026-06-19

## Context

The detail waveform is built from a per-bar envelope stored on `Song.amplitudes`,
reduced from the file's PCM at import by `AudioMath.downsample` (ADR 0011).

On device the envelope read wrong for real songs: peaks and troughs didn't track
the music — a track would render as a near-flat block with no sense of "quiet
verse, loud chorus." Two causes:

1. **Peak per bucket.** `downsample` took the maximum absolute sample in each
   bucket. Modern masters are brick-wall limited, so almost every bucket contains
   *some* sample near full scale — the peak is near-constant and the dynamic
   contrast (which lives in *energy*, not peak) is thrown away.
2. **Normalise to the single max.** Dividing every bucket by the one loudest sample
   in the whole song lets a single transient (a snare crack) flatten everything
   else toward the floor.

Bucket resolution was also low: 240 bars over a 3.5-min song ≈ 0.9 s/bar, so even
a correct envelope smears section boundaries, and a deep zoom just upscales fat
bars.

## Decision

- **Reduce on energy, not peak — and resist transients.** A peak per bucket reads
  flat on brick-walled masters. A straight RMS (`sqrt(mean(sample²))`) reads far
  better, but *squaring* over-weights loud brief events: on-device the bars tracked
  the **snare**, giving a spiky, murky picture that hid the section dynamics. So each
  bar is split into `transientSubFrames` (16) short sub-windows, each reduced by RMS
  (`AudioMath.bucketRMS`), and the bar takes the **median** (`transientReject` = 0.5)
  of those (`AudioMath.sectionEnergy`). A snare lands in only a few sub-windows, so
  the median reads the *sustained* level the rest of the bar sits at and steps over
  the hit. The reduction is sign-agnostic (squares), so the mono mix's phase doesn't
  matter. The percentile is the tuning knob: lower rejects transients harder, 1.0 is
  the bar's peak.
- **Normalise to the 95th percentile of the bar energies, not the max**
  (`AudioMath.percentile`). A robust reference uses the full height for the body
  of the song; the few loudest bars clamp to 1 instead of crushing the rest.
- **Bump the stored bucket count 240 → 512** (`WaveformExtractor.defaultBuckets`),
  ≈0.42 s/bar — finer transitions, better zoom baseline. The count doubles as the
  stored-format version, so it is bumped whenever the reduction changes (it stepped
  240 → 480 → 512 as peak → RMS → transient-resistant) to re-trigger extraction.
- **Keep it pure and tested.** `bucketRMS`, `percentile`, and the composed
  `downsample` stay in `AudioMath` (no AVFoundation), exhaustively unit-tested per
  AGENTS.md. The AVFoundation I/O boundary (`WaveformExtractor`) is unchanged.
- **Self-heal old waveforms via the bucket count.** Songs imported before this ADR
  hold a stale 240-bar peak envelope. Rather than add a schema-version field, the
  bucket count *is* the version: on opening an imported file,
  `WaveformPracticeModel.refreshWaveformIfOutdated` re-extracts and persists when
  `song.amplitudes.count != defaultBuckets`. New imports already match, so they
  never re-extract.

## Consequences

- Every song imported before this ships re-extracts once on next open (a full
  off-main-actor decode), then persists 480 RMS bars and matches thereafter.
- The demo sample keeps its synthetic 120-bar `demoAmplitudes` (`bookmark == nil`
  never hits the import path); it's illustrative, not measured.
- `SampleToneGenerator` shares `downsample`, so the dev arpeggio now shows an RMS
  envelope too — consistent with real files.
- Tuning knobs left open and documented: `transientReject` (0.5), `transientSubFrames`
  (16), the 0.95 normalisation percentile, and a possible perceptual gamma to lift
  quiet passages. Median-RMS (no peak outline) is the V1.

## Alternatives considered

- **Keep peak, just normalise smarter** — rejected: percentile normalisation alone
  doesn't fix brick-walled masters; the flatness is in the peak reduction itself.
- **Store both peak (outline) and RMS (body)**, Logic/SoundCloud style — deferred:
  best readability but doubles stored data and the draw; RMS-only fixes most of the
  gap for now. Revisit if the envelope still reads thin.
- **A `waveformFormatVersion` field for migration** — rejected as redundant: the
  bucket count already changes with the algorithm, so it's a sufficient signal.
- **Re-downsample per zoom viewport for crisp deep zoom** — out of scope here; it
  needs the source buffer retained and pairs with page-mode (ADR 0010).
- **Low-pass before reducing** to attenuate the snare's high-frequency crack and
  emphasise the kick/bass body — deferred as a fallback lever. It's more code (a
  filter in the extraction path) and shifts the envelope's character bass-heavy;
  the median sub-window reduction rejects transients without that, so try it first.
