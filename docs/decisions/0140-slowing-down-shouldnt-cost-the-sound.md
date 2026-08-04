# ADR 0140 — Slowing down shouldn't cost the sound: the stretcher, its settings, and the click that leads it

- **Status:** Accepted and **complete**. Slices 1 and 2 built and device-confirmed 2026-08-02
  (`pocket-221-time-stretch-quality`); slice 3 built 2026-08-04 (`pocket-226-tmpt-ab-and-headroom`).
  **§4 is settled: `'tmpt'` is ADOPTED** (device A/B 2026-08-04 — *"the sound quality is so much
  better"*), made the default on `pocket-228-adopt-tmpt-and-freeform-click`, and the Debug toggle is
  deleted. Build notes at the end, including what the adoption did and did not verify.
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

## Build notes — slice 1 (2026-08-02, `pocket-221-time-stretch-quality`)

`TimeStretcher` + `StretchQuality` landed as specified; `PracticeAudioEngine` holds
`let stretcher = TimeStretcher()` where `timePitch` was, and the metronome's rate read moved onto
`stretcher.rate`. No other file referenced `timePitch`. Five things worth recording.

**1. `overlap` is not deprecated at the Swift level, so slice 1 keeps using it.** The rename this ADR
rests on is real but lives at the AudioToolbox *constant* level (`kNewTimePitchParam_Overlap` →
`…_Smoothness`). `AVAudioUnitTimePitch.overlap` is still the live, undeprecated property, and the iOS
26.5 SDK header states the semantics this ADR argues from in as many words: *"A higher value results in
fewer artifacts in the output signal. This parameter also impacts the amount of CPU used. Range: 3.0 →
32.0, Default: 8.0."* So the property is right and only the reasoning around it was wrong. No
`AudioUnitSetParameter` call is needed until slice 3 swaps in `'tmpt'`.

**2. The curve, now frozen.** Smoothness climbs linearly in the **stretch factor** (`1/rate`), not in
the rate — artifacts track how far the audio is being stretched, and 0.25× is a 4× stretch where 0.5×
is only 2×. Anchored at **4.0 at and above 1×** (nothing is stretched there, and the parameter costs
CPU for a whole session) rising to **18.0 at 0.25×**, which puts 0.5× at **8.67** — just past Apple's
8.0 default, matching the ADR's "toward and past". Monotonically non-increasing in rate and clamped to
the AU's 3…32, both unit-tested.

**3. The rate clamp moved into the stretcher.** `setRate`'s `min(2.0, max(0.25, …))` now lives in
`TimeStretcher` as `minimumRate`/`maximumRate`, because rate and smoothness must be written together
from the same clamped value. Note these are the *engine's* bounds and are deliberately wider than
ADR 0124's 1.5× product ceiling — that cap belongs to `TempoMath` and the UI, not to the graph.

**4. Slice 2 should be one offset, not two.** §3 proposes both a latency parameter on
`MetronomeSchedule.upcoming` *and* an offset on the visual playhead. They are redundant.
`refreshMetronome` computes its delay from `currentTime`, so if `currentTime` is redefined as **what
you hear now** — offset applied once in `updateCurrentTime`, where it is published — then
`delay = ahead / rate` is already correct and `MetronomeSchedule` needs no change at all. The click and
the cursor both fall out of one line. This is §3's own stated instinct ("`currentTime` is the single
place both read from … the offset lands once"), followed further than §3 followed it. The §3 watch item
stands unchanged: offset the *reported* time without perturbing `loopIteration`, and clamp at 0 so the
playhead can't read negative during the first ~93 ms of playback.

**5. A consequence §3 missed: hand-tapped beat grids already contain the offset.** `WaveformBPMSheet`
captures both tap-tempo and the downbeat from `engine.currentTime`, and the player taps to what they
**hear** — so every hand-tapped grid has `+latency × rate` baked into it. At the 1× they tapped at,
that offset *cancels* the flam; it stops cancelling as they slow down. Two consequences:

- **A sharper test for slice 2 than listening in the absolute.** A song with a **typed** BPM should
  flam even at 1×; a **hand-tapped** one should sound tight at 1× and come apart at 0.25×. If that
  asymmetry is audible, the diagnosis is confirmed by a comparison rather than by an absolute judgment.
- **Fixing `currentTime` makes future captures correct but shifts existing tapped grids by ~93 ms.**
  Only the developer's own library is affected (v1 is approved but held, so there are no users), and
  the honest fix is to re-tap those songs rather than to chase a phantom. Worth stating so it isn't
  mistaken for a regression introduced by the compensation.

Related: prefer proving the flam **by A/B against the fix** rather than by ear beforehand, as §3's
slice ordering implies. Humans judge "which is tighter" far better than "is this 93 ms early", and the
failure case is decisive either way — if `AVAudioEngine` does compensate node latency internally, the
corrected build puts the click 93–139 ms *late*, which is unmistakable. Same code either way, one
device trip.

**Verification (slice 1):** `swiftlint --strict` clean, generic-simulator build clean, **1794 tests
pass** on the `PocketAll` plan including 8 new `StretchQualityTests`. The sound itself is a listening
claim and is device-only. Incidentally, extracting the stretcher took `PracticeAudioEngine.swift` from
397 lines to 395, off the 400-line cap it was about to hit.

## Build notes — slice 2 (2026-08-02, same branch)

Built as **one offset, per build note 4** — `MetronomeSchedule` is untouched. `updateCurrentTime`
publishes `currentTime` in *heard* time via a new pure `AudioMath.heardPlayhead(rendered:latency:rate:)`,
and because `refreshMetronome` measures every beat from `currentTime`, the click and the waveform
cursor are corrected by the same subtraction.

**Slice 1's device pass, first.** The smoothness change is confirmed by ear on the iPhone: *"the
overall quality is much better"*. **0.25× still sounds rough** — which is the case §4 exists for. The
curve is not the ceiling at a 4× stretch; the AU is. That is a point *for* trying `'tmpt'` in slice 3,
and it is now a listening observation rather than a spec-sheet argument.

**The units question the ADR never pinned down.** The correction is `latency × rate`, in *source*
seconds — `latency` is real seconds at the output, but a playhead is a position in the song, and during
those real seconds the player advanced only `rate` as much source material. Getting this backwards
over-corrects by `1/rate`: identical at 1×, four times too far at 0.25×. The measurements corroborate
the reading — 0.0929 s at 1× and 0.1393 s at 0.5× fit `0.0464/rate + 0.0465` almost exactly, i.e. a
fixed ~46 ms *source*-side buffer expressed in real time plus ~46 ms of fixed real output buffering.
Both halves are real seconds at the output, as assumed.

**`loopIteration` is deliberately left on the rendered clock**, per §3's watch item: it drives the
per-loop ramp (ADR 0013), and pulling it back across a wrap would re-fire a pass and step the ramp on
every lap. The consequence is that a ramp's tempo change still lands ~90–140 ms before you hear the
wrap. That is the pre-existing behaviour, it is an order of magnitude below the ramp's own dwell, and
it is not worth risking the loop maths to chase.

Also: the reported time is clamped at zero, so the playhead can't read negative during the first
~93 ms of playback.

**Two files split for the 400-line cap**, both mechanical: `PracticeAudioEngine+LoopBuffer.swift` takes
the region read and seam crossfade (costing `file` / `sampleRate` / `crossfadeSeconds` /
`loopAnchorFrame` / `loopBufferFrames` / `currentLoopSegment` their `private` — the usual
cross-file-private tax), and `DebugAudioSection.swift` takes the new Debug toggle out of
`SettingsView`.

**Device-confirmed 2026-08-02: *"on is definitely tighter"*.** A/B'd on the iPhone at 0.25× via
*Settings → Audio (Debug) → Compensate stretch latency*. So the flam was real, `AVAudioEngine` does
**not** compensate node latency internally for a player scheduled `at: nil`, and §3's honesty caveat is
now discharged — the claim moves from *measured and code-path-confirmed* to *heard*.

The Debug toggle is **kept** rather than deleted. It costs nothing in Release (the whole section is
`#if DEBUG`, and the engine's `compensatesStretcherLatency` is a compile-time `true` there), it is the
rig slice 3's `'tmpt'` A/B will sit beside, and a latency correction is exactly the kind of thing worth
being able to disprove again later.

**Verification (slice 2):** `swiftlint --strict` clean, generic-simulator build clean, **1796 tests
pass** on `PocketAll` including 6 new `heardPlayhead` cases covering the rate scaling, its direction,
the zero clamp and the degenerate inputs.

## Build notes — slice 3 (2026-08-04, `pocket-226-tmpt-ab-and-headroom`)

§5 first, then §4 — the ordering the slice specifies, for the reason it gives: a clipped peak sounds
like a smeared one, so a mix that can clip would let the mixer's fault be credited to the stretcher
in the very test §4 exists to run.

**1. The trim goes on the mixer's *output*, not on the stretcher's.** §5 says "a small fixed trim on
the stretcher's output", and that turns out to be both impossible and wrong.

Impossible: `AVAudioUnit` does not conform to `AVAudioMixing` — in the iOS 26.5 SDK only
`AVAudioPlayerNode`, `AVAudioSourceNode`, `AVAudioUnitGenerator`, `AVAudioUnitMIDIInstrument`, the
mixer and the environment node do. A time-effect node has no `volume` to set.

Wrong, and more interestingly: **it is the *sum* that clips.** Trimming only the song to make the
guarantee needs a factor of `1 − 0.7 = 0.3`, a 10.5 dB cut, and it would leave the click looming over
the track. Trimming the mixer's output scales song and click together, which makes the same guarantee
at `1/(1 + 0.7) ≈ 0.588` (−4.6 dB) and leaves the song-to-click balance exactly as voiced. §5's own
context paragraph already names the click as half the problem ("the click sums into that same
mixer"); putting the trim after the sum is following that further than §5 followed it — the same
move build note 4 of slice 1 made for the latency offset.

The cost is honest and worth stating: **the practice screen is ~4.6 dB quieter**, and the player
makes it up on the device volume. It is a fixed trim, not one that lifts when the metronome is off —
a gain that moves under the player is worse than a quiet one, and a constant level is the only thing
that makes the §4 A/B a fair comparison.

**2. The trim is derived, not pinned.** `AudioMath.headroomTrim(peakClick:)` is pure and unit-tested,
and its input is `ClickTimbre.loudestPeakAmplitude` — computed across all four timbres' three levels
rather than written down as `0.7`. The player can change timbre mid-session and the trim is fixed, so
it has to cover the loudest one; deriving it means retuning a voicing moves the trim instead of
quietly eating the headroom. `synthesize` scales a convex tone/noise blend (magnitude ≤ 1) by an
envelope starting at 1, so a level's `amplitude` *is* its peak — the derivation is exact, not an
estimate. One test asserts the shipping trim stays above 0.5, so meeting the guarantee by gutting the
song would fail rather than pass quietly.

**3. `'tmpt'` is a second `Backend` case inside `TimeStretcher`, and nothing outside the file
changed.** This is the payoff §1 was written for, and it held: `PracticeAudioEngine` still says
`stretcher.node`, `stretcher.rate`, `stretcher.latency`, and the metronome's rate read is untouched.
The differences are confined to two `switch`es — rate (`unit.rate` vs
`AudioUnitSetParameter(…, kTimePitchParam_Rate, …)`) and pitch-zero.

**4. `StretchQuality` does not apply to `'tmpt'`, and that is not a gap.** Smoothness is a
`NewTimePitch` parameter; the high-quality unit has no equivalent knob. So under the toggle the
slice-1 curve is simply unused, and the A/B is genuinely *curve-corrected `nutp`* against *`tmpt` as
Apple ships it* — which is the right comparison, since §2 already shipped and is the baseline.

**5. Two robustness details the ADR didn't anticipate.**

- **The component is looked up before it is instantiated.** `AVAudioUnitTimeEffect` has no failable
  initialiser, so an absent `'tmpt'` would surface as a dead node in the graph — a silent practice
  screen — rather than as a `nil`. `AudioComponentFindNext` first, fall back to `'nutp'` if it isn't
  there. The probe found it present, but a Debug toggle must not be able to silence the app.
- **The rate is re-asserted after `engine.start()`.** `'tmpt'`'s rate is a raw `AudioUnitSetParameter`
  write rather than a property the object retains, and the engine only initialises the AU when it
  starts — which happens *after* `TimeStretcher.init`. One extra parameter write in
  `startEngineIfNeeded` removes the question entirely. Harmless for `'nutp'`.

**6. The toggle takes effect on the next song, not immediately.** The AU is chosen at
`TimeStretcher.init`, so switching it mid-playback would mean rebuilding the graph under a running
player. `PracticeAudioEngine` is already recreated per practice-screen visit, so backing out and
reopening the song is the whole switch procedure — and the Settings footer says so, because a tester
who doesn't know that will A/B one build against itself and conclude there's no difference.

**Verification (slice 3):** `swiftlint --strict` clean, generic-simulator build clean, **1802 tests
pass** on the `PocketAll` plan including 6 new `HeadroomTrimTests`. (`AudioMathTests` hit the 250-line
type-body cap, so the new cases are their own file.)

Everything §4 actually decides is a listening claim and is **not** verified here. What is on the
device is the *rig*: *Settings → Audio (Debug) → High-quality stretcher*.

**The four-part rule, restated as a device checklist** — all four must hold to adopt:

1. **Preferred by ear** on real material at 0.5× and 0.25×, speakers *and* headphones.
2. **No dropouts or glitching** on the oldest supported device with a full graph — song + click + a
   recording take armed.
3. **CPU and battery** acceptable for a screen that runs for a whole practice session.
4. **Rate 0.25 behaves at the boundary** — it is the *exact* bottom of `'tmpt'`'s `0.25…4.0` range,
   not merely near it.

If any fails we stay on `'nutp'` with §2's curve, and the toggle, the `Kind` enum and the
`highQualityStretcher` key are deleted. §5's trim stays either way — it is shipping behaviour and
independent of the outcome.

## §4 outcome — `'tmpt'` adopted (2026-08-04, `pocket-228-adopt-tmpt-and-freeform-click`)

**Verdict: adopt.** The device A/B was decisive — *"the `'tmpt'` definitely makes a massive
difference when I tested it, the sound quality is so much better."* `'tmpt'` is now the default for
every build, and the Debug toggle, its `AppStorage` key and its Settings block are deleted, per §4's
own rule that adoption is written into this ADR rather than left as a switch.

**How the four-part rule was actually satisfied** — stated precisely, because two of the four were
answered by judgment rather than by measurement and that should not be quietly rounded up:

1. **Preferred by ear** — ✅ met, emphatically, and this is the criterion that mattered. It also
   closes the loop on slice 2's finding that *0.25× is still rough with the curve fixed*: the curve
   was not the ceiling at a 4× stretch, the AU was, exactly as §4 predicted.
2. **No dropouts under a full graph** — ⚠️ **not tested with a recording take armed.** Carried as a
   known gap rather than a pass. It is the one remaining way this could be wrong in the field, and it
   is cheap to check.
3. **CPU and battery** — ✅ accepted on the stated basis: *"I can't see any effect on the CPU but I
   don't tend to use it longer than a routine."* That is a real answer for the real usage pattern,
   and it is worth recording that it is a session-length judgment rather than an instrumented one.
4. **Rate 0.25 at the boundary** — ✅ accepted, with the scope deliberately narrowed: 0.25× is the
   product floor and *"unless there's a case to make it even slower, that won't be changing"*. So
   `'tmpt'`'s range having **no headroom below our floor** (0.25…4.0 vs `'nutp'`'s 1/32…32) is an
   accepted limitation rather than an unexamined one. Anything that wants a slower floor reopens this.

**`'nutp'` is kept as a fallback, and the reason is narrow and specific.**
`AVAudioUnitTimeEffect` has **no failable initialiser**, so an absent `'tmpt'` would surface as a dead
node — a **silent practice screen**, on the app's most-used feature. `makeHighQualityUnit` already
looks the component up with `AudioComponentFindNext` and returns `nil`, so retaining the
`.newTimePitch` arm costs a `switch` case and buys a guarantee that the app always makes sound. That
is the *only* justification; it is not kept as a quality option, and there is no way for a player or a
developer to select it.

A consequence worth stating plainly: **`StretchQuality` is now fallback-only code.** Smoothness is a
`NewTimePitch` parameter and `'tmpt'` has no equivalent, so slice 1's curve — and its 8 unit tests —
only ever run if the fallback fires. It stays because the fallback stays; if `'nutp'` is ever deleted,
`StretchQuality` goes with it in the same commit.

**What this reopens.** ADR 0124 capped the speed axis at **1.5× because the stretch smeared
transients**. That premise has now measurably changed. Re-testing the ceiling is worth doing and is
**not** done here — it is a product decision about how far a player should be allowed to push, and it
deserves its own ADR rather than riding in on an audio-quality change.

**Verification:** `swiftlint --strict` clean, generic-simulator build clean, and 5 new
`TimeStretcherKindTests` — including one that resolves a real `TimeStretcher()` through the same
`AudioComponentFindNext` path the app uses and asserts the kind comes back `.highQuality`, so a
future OS that dropped the component would fail a test rather than silently demote every session.
