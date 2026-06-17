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
  called to drop. There is deliberately **no song-level automator**: the speed bar plus the
  per-loop ramp cover it (user decision), so the tempo-bar "A" is dropped from the roadmap.
  The transport bar's disabled "Auto" slot stays free for a possible future metronome.
- **Ramps in playback speed, shown as %, not BPM.** The user sets **start** and **target**
  (× of tempo, displayed as percentages), a **steps-to-target** count, and **loops-per-step**;
  the per-step size is *derived* and shown signed ("+5% / −5% each"). It works for songs with
  no BPM set; the sheet shows BPM equivalents (`TempoMath.effectiveBPM`) when `song.bpm != nil`.
  The ramp climbs **or descends** (target below start) and holds once it reaches the target.
- **Pure stepping math** lives in `AutomatorConfig` (`Core/Audio/Automator.swift`):
  `speed(atLoopIteration:)` interpolates start→target across `stepCount` steps (advancing one
  step every `loopsPerStep` passes), rounding intermediate speeds to **0.1%** and landing
  exactly on the target; `stepSize` is the derived signed increment. Clamped to engine bounds.
  Unit-tested.
- **The engine counts loop wraps in source frames.** `PracticeAudioEngine.loopIteration`
  is derived from `(playerTime.sampleTime − loopBaseSampleTime) / loopBufferFrames` — a
  *source*-frame count, so it stays correct even as the ramp changes `timePitch.rate`
  mid-loop. The gapless crossfade buffer is untouched (rate is an independent real-time
  param). The model applies the ramp by setting `speed` (reusing the existing
  speed→engine path); grabbing the slider disables the active loop's ramp (manual wins).
- **Config persists per-loop on `Loop`** as defaulted scalar fields
  (`automatorEnabled`/`automatorTargetSpeed`/`automatorStepCount`/`automatorLoopsPerStep`;
  the loop's existing `speed` is the ramp **start**), exposed through a computed
  `AutomatorConfig`. **Declaration-level defaults** keep SwiftData lightweight migration
  safe (see ADR 0012's CoreData 134110 note).
- **The setup sheet** (`WaveformAutomatorSheet`) is a visual "ramp" layout: a hero staircase
  that climbs or descends, four stepper fields (start / target / steps / loops-per-step), and
  the BPM range. No enable toggle — a bottom **Set ramp** arms it (and restarts the ramp if
  the loop is playing); **Turn off** appears for an armed loop; **Cancel** discards.

## Consequences

- A loop is now a region + name + a speed-trainer ramp; the static "play at X×, ×N" is gone
  from the row.
- **Deviation from ADR 0009 (conscious, revisitable):** ADR 0009 said automator state isn't
  on the reusable `Loop` because a loop used across *routines* needs different settings.
  Pre-routines, storing the config on `Loop` is the pragmatic representation; when routines
  land, the loop's value becomes the **default** a routine↔loop item overrides. ADR 0009's
  open question ("song, routine↔loop item, or both") is resolved *for now* as "the loop."
- The `loopIteration` signal is reusable by a future metronome.

## Alternatives considered

- **A song-level automator (tempo-bar "A")** — dropped: the speed bar already gives direct
  manual control, and per-loop ramps cover structured practice, so a whole-song ramp adds
  little. (Earlier ADRs deferred it; this slice removes it from the roadmap.)
- **User-set step size (e.g. "+5% per step")** — rejected for **steps-to-target + loops-per-step**
  with a derived step: setting *how many* steps is more intuitive than dialling an increment,
  and percentages read easier than × decimals. Uneven divisions round to 0.1%.
- **BPM-based ramp** — rejected as the basis: requires a known song BPM; speed-based works
  everywhere and the sheet still surfaces BPM when available.
- **Per-wrap completion callback in the engine** — rejected: the `.loops` buffer plays
  continuously with no per-iteration callback; deriving the count from `sampleTime` needs
  no change to the delicate gapless-loop scheduling.
