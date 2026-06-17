# 0013 — Automator slice 1: per-loop speed ramp

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

ADR 0009 set the automator's direction (a shared tempo-progression "speed trainer", not
baked into the reusable `Loop`) and reserved a transport "Auto" slot; ADR 0012 settled
that the control is an **"A"** affordance. The math groundwork (`TempoMath`) and the
seamless region-loop engine (ADRs 0006/0008) already exist. This ADR builds the first
concrete, unblocked surface: ramping a **loop's** playback speed as it repeats.

## Decision

- **Per-loop automator, entered from the loop row.** Each loop row gets an **"A"** control
  (tinted when armed), **replacing the row's speed·repeats text** — which ADR 0009 already
  called to drop. The song-level automator (a tempo-bar "A" for whole-song ramping) and a
  metronome are deferred; the transport bar's existing disabled "Auto" slot is reserved
  for the metronome.
- **Ramps in playback speed (×), not BPM.** Start / step / target are speed multipliers, so
  it works for songs with no BPM set; the setup sheet shows BPM equivalents
  (`TempoMath.effectiveBPM`) when `song.bpm != nil`. The ramp holds once it hits the target.
- **Pure stepping math** lives in `AutomatorConfig` (`Core/Audio/Automator.swift`):
  `speed(atLoopIteration:)` steps every `repeatsPerStep` passes by `stepSpeed`, clamped to
  the engine's speed bounds; `stepCount` drives the "N steps to target" readout. Unit-tested.
- **The engine counts loop wraps in source frames.** `PracticeAudioEngine.loopIteration`
  is derived from `(playerTime.sampleTime − loopBaseSampleTime) / loopBufferFrames` — a
  *source*-frame count, so it stays correct even as the ramp changes `timePitch.rate`
  mid-loop. The gapless crossfade buffer is untouched (rate is an independent real-time
  param). The model applies the ramp by setting `speed` (reusing the existing
  speed→engine path); grabbing the slider disables the active loop's ramp (manual wins).
- **Config persists per-loop on `Loop`** as defaulted scalar fields
  (`automatorEnabled`/`automatorStepSpeed`/`automatorCeilingSpeed`/`automatorRepeatsPerStep`;
  the loop's existing `speed` is the ramp **start**), exposed through a computed
  `AutomatorConfig`. **Declaration-level defaults** keep SwiftData lightweight migration
  safe (see ADR 0012's CoreData 134110 note).

## Consequences

- A loop is now a region + name + a speed-trainer ramp; the static "play at X×, ×N" is gone
  from the row.
- **Deviation from ADR 0009 (conscious, revisitable):** ADR 0009 said automator state isn't
  on the reusable `Loop` because a loop used across *routines* needs different settings.
  Pre-routines, storing the config on `Loop` is the pragmatic representation; when routines
  land, the loop's value becomes the **default** a routine↔loop item overrides. ADR 0009's
  open question ("song, routine↔loop item, or both") is resolved *for now* as "the loop,"
  with the song-level layer still to come.
- The `loopIteration` signal is reusable by the future song-level automator and metronome.

## Alternatives considered

- **A in the tempo bar driving the active loop** — rejected: conflates the loop and song
  scopes. The tempo-bar "A" is reserved for the *song* automator.
- **BPM-based ramp** — rejected as the basis: requires a known song BPM; speed-based works
  everywhere and the sheet still surfaces BPM when available.
- **Per-wrap completion callback in the engine** — rejected: the `.loops` buffer plays
  continuously with no per-iteration callback; deriving the count from `sampleTime` needs
  no change to the delicate gapless-loop scheduling.
