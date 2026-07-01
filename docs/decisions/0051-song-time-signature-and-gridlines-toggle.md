# 0051 — Per-song time signature + a contextual gridlines toggle

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

Two user-testing notes are really one feature: "let the user set a song's time
signature (default 4/4)" and "a toggle to switch gridlines on/off, and make them a
bit more distinguishable when on." The beat grid already draws from the song's tempo
+ downbeat (ADR 0022/0024), but **hardcoded 4/4** (`beatGrid` passed `BeatGrid.beats`'
default `beatsPerBar`), so a waltz or a 6/8 drew bar lines in the wrong place. And the
grid was always drawn, faintly (downbeat 0.07 / sub-beat 0.04 opacity) — no way to turn
it off, and barely visible when you wanted it.

A global gridlines toggle was considered and rejected in review: it would be dead or
misleading on a song with no tempo/downbeat. The grid is a property of *how you read a
given song*, so the control should be **contextual** — on the practice screen, visible
only once a grid can exist.

## Decision

- **Song time signature.** `Song` gains `beatsPerBar`/`noteValue` (declaration-default
  4/4, additive — the CoreData 134110 mandatory-attribute rule, no migration wipe),
  mirroring the exercise's meter. `beatGrid` passes `song.beatsPerBar` to
  `BeatGrid.beats`, so downbeats become real **bar lines**. The non-4 grouping is
  unit-tested (`BeatGridTests.testTimeSignatureGroupsBarLines`).
- **Set it with the tempo, not in metadata.** The meter is a grid input, so it's chosen
  in the **BPM sheet** ("Set tempo") alongside BPM and the 1 — a `Picker` over the
  existing `TimeSignature.presets` (4/4, 3/4, 6/8, …). `commitTempo` gained optional
  `beatsPerBar`/`noteValue` so a meter-only change commits without touching tempo/phase.
  (`TimeSignature` gained `Hashable` for the picker tag.)
- **Contextual gridlines toggle.** A **per-song** `Song.showsGridlines` (default on).
  The toggle lives on the right of the practice screen's "Loop controls" header
  (`ModeDescriptionLine`), shown **only when a grid exists** — gated on
  `model.gridAvailable` (`!beatGrid.isEmpty`, i.e. tempo + the 1 are set), the exact
  condition the user asked for. Per-song, not global, was the chosen scope: the grid is
  a per-song reading aid, not one app-wide preference.
- **Drawing vs. snapping.** Hiding the grid gates **drawing only** — `WaveformView`'s new
  `showsGrid` early-returns in `drawBeatGrid` — while `beats` still feed the snap
  candidates. Turning the grid off must not stop loop edges snapping to beats.
- **Bar lines only, kept subtle.** On-device review landed on **just the bar lines**
  (1 pt @ 0.11 opacity, behind the bars, clipped to the baseline per ADR 0049); the
  sub-beat gridlines were dropped because they made zooming feel busy and cluttered.
  (Earlier passes tried a dark halo and separate sub-beat weights — both read too heavy.)
  So the grid now marks the *meter* (where each bar starts), not every beat.

## Consequences

- Non-4/4 songs finally draw correct bar lines; 4/4 songs are unchanged (the default).
- No migration: both meter fields and `showsGridlines` are additive declaration defaults;
  existing songs read 4/4, grid-on.
- The meter drives the **waveform bar lines**; wiring it into the practice **click**'s
  accent pattern (so the metronome also feels the meter) is left for later — this slice
  is the visual grid.
- The gridlines toggle only appears in the resting "Loop controls" state (hidden while
  placing the 1 or with an A/B span live) — acceptable, since you set the meter/downbeat
  first, then read the grid.
