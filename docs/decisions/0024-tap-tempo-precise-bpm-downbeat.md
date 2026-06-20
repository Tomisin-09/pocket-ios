# 0024 — Tap-tempo / manual BPM, precise tempo storage, peak-snapped downbeat

- **Status:** Accepted
- **Date:** 2026-06-20

## Context

ADR 0004 made BPM best-effort and user-correctable, with a fallback chain — (1)
file metadata, (2) on-device estimate (flagged), (3) user set/correct — and
shipped the **"Set BPM"** affordance only. Until now the sole way to set a tempo
was typing it into `SongEditSheet`. This ADR builds **rung 3**: the tap-tempo /
manual-entry flow behind "Set BPM", plus a precise way to place the **downbeat**
(the phase anchor the beat grid needs — ADR 0022).

Two problems surfaced while building it:

- **Int tempo drifts the grid.** `Song.bpm` was `Int`. The beat grid steps at
  `60 / bpm` from the downbeat, so rounding the tempo to a whole number shifts
  beats progressively further from the music — up to ~1 beat across a multi-minute
  song (drift ≈ seconds-from-anchor × BPM-rounding-error ÷ 60).
- **Placing the 1 by tapping a button is imprecise.** Capturing a timestamp at
  the instant a button is pressed demands frame-perfect timing. But snare/kick
  hits show as conspicuous peaks in the waveform envelope — so the downbeat can be
  *snapped* to a real transient instead of trusted raw.

## Decision

- **Capture song-time, not wall-clock.** Each tap records the engine's
  `currentTime` (song position). Because that already unwraps loop playback and is
  unaffected by playback rate, tapping inside a loop or at reduced speed reads the
  song's *true* tempo automatically. Inter-tap intervals are averaged; a
  non-positive gap (a tap that wrapped a loop back to an earlier position) is
  discarded; the result is clamped to a musical 30–300 BPM. Pure, in `TempoMath`.

- **Store tempo at full precision; `bpm` is the display mirror.** Add an
  **additive** optional `Song.preciseBPM: Double?`. The beat grid reads
  `Song.tempoBPM` (`preciseBPM ?? Double(bpm)`); `Song.bpm: Int?` stays as the
  rounded value the readout and edit sheet already use. Additive optional fields
  ride SwiftData lightweight migration — a **type change** on `bpm` (Int→Double)
  would not, and risks a store wipe (CoreData 134110, which this project has hit).
  `BeatGrid.beats`/`beatFractions` now take `bpm: Double`.

- **Place the 1 by dragging a handle that snaps to peaks.** "Set the 1 on the
  waveform" dismisses the sheet and shows a draggable downbeat handle; any
  drag/tap on the waveform moves it, and on release it **snaps to the loudest bar
  within a screen-proportional window** (`TempoPeaks`, pure). Snapping against the
  *currently displayed* bars means a deep zoom (crisp re-downsample, ADR 0020)
  gives finer peaks for free. A "Mark the 1 at the playhead" button stays in the
  sheet as the quick path. It reuses the capture-confirm slot (✓/✗) and transport
  lock rather than adding a transport mode/pill.

- **Re-entry via long-press.** Once a tempo is known the speed bar shows the
  readout instead of "Set BPM"; long-pressing the readout reopens the editor so a
  wrong tempo or downbeat can be corrected.

## Consequences

- `Song` gains `preciseBPM: Double?`; `tempoBPM` is the single source the grid
  reads. Tap-tempo commits both (`preciseBPM` + rounded `bpm`).
- New pure, unit-tested helpers: `TempoMath.bpm(fromTapTimes:)` and
  `TempoPeaks.snap(...)`. `BeatGrid` is now `Double`-tempo throughout.
- The downbeat snap is only as fine as the displayed envelope; the user zooms in
  to place precisely. No onset/beat *detection* is done here.

## Alternatives considered

- **Change `Song.bpm` to `Double`** — rejected: an attribute type change breaks
  SwiftData lightweight migration and risks wiping the store; an additive
  `preciseBPM` with `bpm` as a display mirror is migration-safe.
- **Wall-clock tap intervals** — rejected: reduced-speed or in-loop tapping would
  read a stretched/looped tempo; song-time is correct by construction.
- **Infer BPM from the peaks too** — deferred: that is **rung 2** of ADR 0004
  (on-device estimate) — real onset/period detection with half/double-tempo
  pitfalls, and must be presented as a confirmable estimate. Its own ADR/slice.
- **A dedicated "downbeat" transport mode** — rejected: the placement is a
  transient task, so it reuses the existing confirm-toolbar slot instead of adding
  a persistent pill.
