# ADR 0140 — Slowing down shouldn't cost the sound: the stretcher, its settings, and the click that leads it

- **Status:** Accepted, **not built**. Slices below.
- **Date:** 2026-08-02
- **Builds on:** ADR 0001 (local files are the audio source — the only reason we own a stretcher at
  all) · ADR 0006 / 0008 (region looping, gapless wrap) · ADR 0013 (the per-loop speed ramp) ·
  ADR 0026 (the in-song click) · ADR 0054 (the display-link playhead) · ADR 0124 (one speed axis,
  ceiling 1.5×).
- **Reopens:** ADR 0124's 1.5× ceiling, which was set *because* the stretch smears transients. Not
  changed here — but this is the work that would earn the right to revisit it.

## Context

Slowing a song down is the app's oldest promise and its most-used feature. Every slowdown surface —
the waveform speed slider, the loop-run percent, the song play-along percent — funnels through one
call, `PracticeAudioEngine.setRate`, onto one node. That node is a bare `AVAudioUnitTimePitch()`
constructed in `init` with one setting applied:

```swift
timePitch.overlap = 3.0
```

The comment justifies it as favouring "transient crispness over smoothness", on the theory that a low
`overlap` sharpens pick attacks at the cost of warble. Three things measured on the iOS 26.5 SDK say
that reasoning no longer holds, and a fourth says the worst problem isn't the stretcher at all.

**What was measured** (probe against `iPhone 17` simulator, iOS 26.5 SDK; probes were temporary and
are not in the tree):

| Question | Measured |
|---|---|
| `'tmpt'` (Apple's *high quality* stretcher) present on iOS? | **Yes** — in the format-converter registry, instantiates as `AVAudioUnitTimeEffect`, `AVAudioEngine` starts with it in the graph |
| `'tmpt'` rate range | `0.25…4.0` — covers our `0.25…1.5` exactly, with 0.25 landing *on* the boundary |
| `'nutp'` latency @ rate 1.0 / 0.5 | **0.0929 s / 0.1393 s** — rate-dependent |
| `'tmpt'` latency @ rate 0.5 | **0.0787 s** — *lower* than `nutp` |
| `nutp` latency @ `overlap` 8.0 vs 3.0 | 0.0929 s both — **smoothness does not affect latency** |
| `EnableTransientPreservation` (param 7) default | **1.0 — already on** |
| `EnableSpectralCoherence` (param 6) default | **1.0 — already on** |

### 1. `overlap` is not what the comment thinks it is

As of iOS 16 the parameter is renamed: `kNewTimePitchParam_Overlap` is deprecated *with replacement*
`kNewTimePitchParam_Smoothness` (same id, 4). AudioToolbox documents it as:

> The generated output can be made to sound smoother by increasing the density of the processing time
> frames. The value is directly proportional to the CPU cost. **When slowing down percussive audio,
> lower values may be better.** Global, generic, 3.0 → 32.0, **8.0**.

AVFoundation's own property doc is blunter: *"A higher value results in fewer artifacts in the output
signal."* So `3.0` is not "crispest" — it is **minimum smoothness, maximum artifacts**, at the extreme
end of a range whose default is 8.0. The carve-out that justifies going low is *percussive* material.
Our material is whole backing tracks: sustained guitar, vocals, cymbals, room. That is the case the
parameter's floor is worst for, and slowing down is exactly when it bites.

### 2. Transient crispness is a *different* parameter, and it is already on

`kNewTimePitchParam_EnableTransientPreservation` — *"uses group delay to identify transients, resets
the phase at points of transients to preserve the original spectral phase relationships, and sets the
stretch factor to 1 at those points"* — defaults to **on**, and we measured it on. So is
`EnableSpectralCoherence` (peak locking, *"a less phasey or reverberant sound"*).

The attack-preservation job the `overlap = 3.0` line was hired to do is already being done, correctly,
by the parameter built for it. We are paying an artifact tax for a second, cruder attempt at the same
goal. (This also corrects a premise: `AUNewTimePitch` is a **phase vocoder** — peak locking, spectral
coherence, group-delay transient detection — not a time-domain overlap-add. Reasoning about it as
"more overlap = more smearing" was wrong.)

### 3. The click leads the song, and the lead grows as you slow down

This is the defect, and it is not a stretch-quality problem — it just presents as one.

`ClickVoice` connects **straight to the main mixer, deliberately bypassing the time-pitch** so clicks
sound at real-time pitch whatever the song's speed. Meanwhile the song goes player → time-pitch →
mixer, and that stretcher reports **93 ms of latency at 1×, rising to 139 ms at 0.5×**.

Nothing compensates. `refreshMetronome` schedules against `currentTime`, and `currentTime` is derived
from `player.playerTime(forNodeTime:)` — the player's render position, **upstream of the stretcher**.
So the playhead reports audio that has been rendered but not yet heard, and the click is scheduled
against that undelayed clock and emitted on an undelayed path.

The click therefore **leads the song by the stretcher's latency**, and the lead is *rate-dependent*:
~93 ms at 1×, ~139 ms at 0.5×. At 120 BPM a 16th note is 125 ms. This is a flam that gets worse the
more you slow down — precisely the conditions under which a player is listening hardest for alignment.
The same offset applies to the **visual** playhead: the waveform cursor sits ~93–139 ms ahead of what
the ear hears.

**Honesty about this claim:** the latency is measured and the uncompensated code path is confirmed by
reading it. It has *not* yet been confirmed by ear or by device instrumentation, and there is a
residual possibility that `AVAudioEngine` compensates node latency internally for a player scheduled
`at: nil`. Slice 2 begins by proving the flam on device before fixing it. If it proves absent, slice 2
is dropped and nothing else in this ADR changes.

### Why one ADR

These are one decision because they share a seam. Any of them — changing smoothness, swapping the AU,
compensating latency — wants the same thing the engine does not currently have: **one owner of the
stretcher that knows its rate and its latency**. Deciding them separately means building that seam
three times, or worse, not building it and scattering `timePitch.` reads across the engine.

## Decision

### 1. A `TimeStretcher` seam owns the AU, its rate, and its latency

Introduce a small type in `Core/Audio` that wraps the time-effect node. It exposes `rate`, `latency`,
and the node for graph wiring, and **hides which AU is inside**. Two reasons this is required rather
than tidy:

- `'tmpt'` is not an `AVAudioUnitTimePitch`. It is an `AVAudioUnitTimeEffect` whose rate is set with
  `AudioUnitSetParameter(unit, kTimePitchParam_Rate, …)` and which has no Swift `rate` property. The
  one existing reader of `timePitch.rate` — `PracticeAudioEngine+Metronome.swift:54` — must read a
  stored value instead, or slice 3 cannot be tried without editing the metronome.
- Latency is rate-dependent, so *something* must re-read it when rate changes. That is the same
  moment rate is written. One owner, one place.

`PracticeAudioEngine` keeps `let stretcher = TimeStretcher()` where it holds `timePitch` today, and
`setRate` goes through it.

### 2. Smoothness follows the rate, and it is pure math

Replace the pinned `overlap = 3.0` with a rate-dependent setting derived by a pure function:

```swift
enum StretchQuality {
    /// AUNewTimePitch "Smoothness" (3…32, default 8) for a playback rate.
    static func smoothness(forRate rate: Double) -> Float
}
```

The shape: at and above ~1× keep it low — nothing is being stretched, and the original rationale costs
nothing there. As rate falls, climb toward and past the 8.0 default, reaching the high teens at 0.25×
where the stretch factor is largest and the artifacts are worst. Exact values are a listening
decision, made in slice 1 against real material and then frozen in the function.

Pure and unit-tested, per AGENTS.md — this is tempo-adjacent math with no UI, and it is exactly the
kind of thing that breaks silently. Tests assert monotonicity (never smoother when faster), that the
output stays inside the AU's 3…32 range, and the endpoints.

**This slice cannot desync anything**: smoothness was measured not to change AU latency. It is
therefore safe to ship ahead of, and independently of, everything below.

Transient preservation and spectral coherence are **left at their defaults (on)** and not exposed. We
verified them on rather than setting them; a future slice that wants them off must say why.

### 3. Compensate the stretcher's latency — for the click *and* the playhead

Once §1 exists, `TimeStretcher.latency` is available at the moment clicks are scheduled. The offset is
applied so that **the click aligns with the song as heard**, not as rendered.

The correction belongs in pure math, not in the scheduling loop: `MetronomeSchedule.upcoming(…)` gains
a latency parameter and the arithmetic is tested. It must be re-read on rate change — the existing
`flushMetronome()` on `setRate` is already the discontinuity hook, so the seam exists.

The **visual** playhead takes the same offset. A cursor 139 ms ahead of the audio is the same defect in
a different sense, and fixing one without the other just moves the disagreement. `currentTime` is the
single place both read from ([ADR 0054](0054-playhead-display-link.md)'s display-link tick), so the
offset lands once.

**Loop wrap is the case to watch.** `updateCurrentTime` maps elapsed frames back into the region and
derives `loopIteration` from it; subtracting a latency offset near the seam can push the reported
position across a wrap boundary. The offset must be applied to the *reported* time without perturbing
the iteration count that drives the ramp (ADR 0013), or a loop could appear to advance its ramp a beat
early on every pass.

### 4. `'tmpt'` is evaluated behind a debug toggle, against a stated decision rule

Apple ships two stretchers and describes them differently: `AVAudioUnitTimePitch` is *"good quality"*;
`kAudioUnitSubType_TimePitch` is *"high quality time stretching and pitch shifting"*, and the header
says `NewTimePitch` *"is computationally less expensive than kAudioUnitSubType_TimePitch"*. Cheaper is
the only advantage claimed for the one we use.

We do **not** swap it on faith. §1's seam makes the AU a one-line choice, so slice 3 puts `'tmpt'`
behind a Debug-only toggle and answers the question by listening on device.

**Adopt `'tmpt'` as the default only if all four hold:**

1. A/B on device, on real material at 0.5× and 0.25×, is preferred — by ear, not by spec sheet.
2. No dropouts or glitching on the oldest supported device under a full graph (song + click + a
   recording take armed).
3. CPU and battery cost are acceptable for a screen that runs for a whole practice session.
4. Rate 0.25 behaves — it is the *exact* bottom of `'tmpt'`'s range, so it must be checked at the
   boundary, not near it.

If any fails, we stay on `'nutp'` with §2's smoothness fix and the toggle is deleted. That is a real
outcome, not a failure — §2 and §3 stand on their own.

Latency is **not** a reason to reject it: `'tmpt'` measured *lower* than `'nutp'` (79 ms vs 139 ms at
0.5×), and §3 compensates whatever it is.

### 5. Headroom: a clipping guard, because clipping is misread as artifacts

The song reaches `mainMixerNode` with no trim, and the click sums into that same mixer. A loud master
plus an accented click can clip, and phase-vocoder resynthesis can push peaks above the source. Clipped
peaks sound like "bad slowdown" and would be wrongly credited to the stretcher — including, if we are
careless, in the §4 A/B.

A small fixed trim on the stretcher's output, sized so song-plus-accent cannot exceed full scale. Cheap
insurance, and it protects the integrity of the listening test above it.

## What this closes off

- **The stretcher is not configurable by the player.** No "quality" setting in Settings. The app picks
  the best sound it can for the rate you chose; a slider that trades sound quality against battery is a
  question no practising guitarist should be asked mid-session.
- **No pitch shifting.** `pitch` stays 0. Slowing down is pitch-preserving, full stop — a varispeed
  ("tape") mode is a different product decision and is not smuggled in here.
- **Not deciding to leave `'nutp'`.** §4 states the rule that settles it, so the decision is made in
  advance and not re-argued when the A/B is inconvenient.

## Deferred

- **Offline pre-render for loops.** `makeLoopBuffer()` already renders a crossfaded PCM buffer;
  stretching it offline and playing at rate 1.0 removes the real-time CPU ceiling entirely. Deferred
  because the per-loop ramp (ADR 0013) changes rate *between iterations*, so it needs the next step's
  buffer pre-rendered during the current one, and the click maths would move from "scale by rate" to
  "the grid itself is stretched". Worth it only if §2–§4 don't get there.
- **A third-party stretcher** (signalsmith-stretch, MIT; Rubber Band; zplane élastique). A genuinely
  higher ceiling than Apple's, at the cost of C++ interop, a licence review and a build change. Not
  before Apple's own high-quality unit has been tried and found wanting.
- **Rate-aware loop crossfade.** The seam fade is 15 ms of *source* frames, so at 0.25× it is heard
  across 60 ms. Equal-power, so likely fine; a knob if slowed wraps sound soft.
- **`preferredSampleRate` on the session.** A 48 kHz file into a 44.1 kHz session is mixer-resampled.
  Minor next to the above.
- **ADR 0124's 1.5× ceiling.** Lowered from 2.0× because of stretch smearing. If §2–§4 land well, the
  premise has changed and it is worth re-testing — but not in this ADR.

## Build slicing

1. **Smoothness + the `TimeStretcher` seam.** §1 and §2. Pure `StretchQuality` with unit tests, the
   seam, the one metronome read moved onto stored rate. No behaviour change beyond the sound itself.
   Independently shippable and cannot desync the click.
2. **Latency compensation.** §3. **Starts by proving the flam on device** — click against song at 1×
   and 0.25×, and the visual cursor against the heard downbeat. If the flam is real, fix click and
   playhead together and re-verify at both rates and across a loop wrap. If it is not real, drop the
   slice and record that here.
3. **The `'tmpt'` A/B.** §4 behind a Debug toggle, judged on device by the four-part rule, plus §5's
   trim first so the test isn't polluted by clipping. Outcome — adopt or delete — is written back into
   this ADR's status.

## Verification

Unit tests cover `StretchQuality.smoothness(forRate:)` (monotonic, in-range, endpoints) and the
latency-offset arithmetic in `MetronomeSchedule`. Neither is device-dependent.

Everything else here is a **listening** claim and must be verified on the iPhone, not the simulator and
not by preview — sound quality, click alignment and CPU headroom are all things the simulator will
happily lie about. The material for the A/B is a real backing track with sustained harmonic content and
clear transients, at 1×, 0.5× and 0.25×, through speakers *and* headphones.
