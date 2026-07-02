# 0047 — Phase-continuous automator tempo stepping

- **Status:** Accepted
- **Date:** 2026-06-30

## Context

The standalone metronome's tempo automator (ADR 0043) climbs the BPM over a
sitting — step a fixed amount every N bars/seconds (free-play `MetronomeAutomator`)
or warm up → dwell → summit → back off (`CommandRamp`, ADR 0045). User testing
surfaced an audible defect: **the transition into the first step of a ramp lurches,
while later steps feel smoother** — and, separately, "the tempo change is smooth
between some steps and not others." The two reports are the same bug.

Root cause: every tempo change — manual *and* ramp — went through `applyTempo`,
which calls `reanchorPhase()`: it flushes the queued clicks (`clickVoice.stopAll`),
restarts the voice, and drops `phaseOrigin`/`scheduledThrough`/`currentBeat` so the
grid re-anchors to a **fresh accented beat 0**, scheduled `leadSeconds` (~60 ms)
ahead of the render head. For a *manual* change that's correct — you want an
immediate, clean downbeat. For a *ramp step* it's wrong:

- The step fires off the **wall-clock** bar accrual (`automatorBarsElapsed`,
  integrated from tick deltas), which is a different clock from the **sample-clock**
  beat grid. When the accrual crosses an integer bar, the audio grid is somewhere
  mid-bar — so reanchoring to beat 0 *there* yanks the downbeat to an arbitrary
  point in the bar.
- "First step worst" follows: at engage time the wall-clock accrual leads the
  sample grid by the scheduling lead (~60 ms) plus the initial output latency, so
  the first crossing lands furthest from a real downbeat. How near later crossings
  happen to fall to a downbeat is what makes some steps smooth and others not — the
  "factors at play."

## Decision

Split the tempo-change paths. Manual changes keep the hard re-anchor
(`applyTempo` → `reanchorPhase`). Ramp steps go through a new
`applyAutomatorTempo`, which re-anchors **phase-continuously**:

- Do **not** flush the queued clicks or reset the tick counter / `currentBeat`.
- Re-origin the grid so the last *already-scheduled* tick keeps its exact sample
  and the next unscheduled tick continues one **new** interval after it. The tick
  counter carries on unbroken, so the accent pattern — hence the downbeats — stays
  put; the new spacing simply takes over at the splice.

The splice math is the pure, Foundation-only `MetronomeGrid.reanchoredOrigin`
(frame positions as `Int64`, no AVFoundation), unit-tested in `MetronomeGridTests`
(AGENTS.md: timing math that breaks silently must be covered). The engine reads the
old spacing, moves `bpm`, then asks `MetronomeGrid` for the new origin.

## Consequences

- Ramp steps no longer lurch — first or later — because no step resets to beat 0
  mid-bar. The first-step asymmetry disappears.
- The new tempo takes effect at the next *unscheduled* tick, so already-queued
  clicks (up to the ~0.3 s look-ahead horizon) play out at the old spacing before
  the new one begins. For the small per-step deltas a ramp uses this is musically
  smooth — and is the point: the change splices instead of snapping.
- A side effect of keeping this under the 400-line file cap: the engine's
  `AVAudioEngine`/timer/now-playing **plumbing** moved to a new
  `StandaloneMetronomeEngine+Driver.swift` split (mirroring `+Automator`), and a few
  plumbing handles relaxed `private → internal`. No behaviour change.
- The deeper option — defer each step to the next real downbeat *and* preserve
  phase — is left for later; the value-change is already bar-quantized, and
  phase-continuous re-anchoring removes the lurch without the extra look-ahead
  bookkeeping a deferred-apply would need.
