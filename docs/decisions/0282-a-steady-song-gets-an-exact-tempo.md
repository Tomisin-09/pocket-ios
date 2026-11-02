# ADR 0282 — A steady song gets an exact tempo

- **Status:** Accepted. Agreed with Tomisin on 2026-11-02 as B3a of the beat map, ahead of B3.
- **Date:** 2026-11-02 (`pocket-400-exact-tempo-steady-song`)
- **Amends:** ADR 0281, its Context: *Binta*'s grid did not drift because the band moved. Its estimate
  read 83.9 BPM, and the song holds 83 from start to end. The beat map still stands for songs that
  move (its D1–D8 are unchanged).
- **Relates to:** 0004 (the estimate is still only proposed, never committed by itself), 0024 (a
  tempo is stored at full precision), 0154 (an extra 1 restarts the bar count; D4 leaves that alone)
- **Schema:** none.

## Context

After B2 (ADR 0281) was installed, Tomisin reported that a fairly steady song's grid still drifted,
and that tapping through a whole song is not tolerable. The song was *Binta*, the starter track.

Measured by fitting one steady grid to the whole song (the app's own onset envelope, tempo in steps
of 0.01 BPM), *Binta* is **83.00 BPM**, and each half on its own is 83.00. The phone had it at 84.
*Estimate from audio* had read 83.9. The Manual field showed that as "84", and Done saved what the
field showed.

The 83.9 is the estimator's fault, not the song's. `TempoEstimator` finds the tempo as the lag at
which the onset envelope best repeats, read one beat apart, in frames of 10 ms. *Binta*'s beat is
72.3 frames. Its peak is lopsided: the lag of 71 frames matches almost as well as 72 (0.263 against
0.266), while 73 matches much worse (0.144). The parabola through the three puts the peak at 71.5
frames, which is 83.9 BPM. That is 8 ms short a beat. Over *Binta*'s 112 beats it is 0.9 s, more
than a beat, by the end. Rounding to 84 added only another 0.1 s.

Tomisin set the priority on 2026-11-02: *"the aim is to ensure that we can match up as well as
possible for steady click songs, this is more important than getting something for songs that speed
up and slow down."* So this slice goes before B3, the beat finder.

## Decisions

**D1. The estimate times many beats, not one.** The one-beat reading still finds the tempo and its
octave (the prior is unchanged). `TempoEstimator.refined` then reads the same autocorrelation at the
lag of 2, 3, 4, 6, 8, 12… beats. A frame's error spread over 48 beats is a fiftieth of a frame a beat.

- **Spans grow by a half or a third**, not by doubling. That keeps the error carried into each search
  small, and puts a bar of three and a bar of four among the spans (*Binta*'s two-beat repeat is weak
  at 0.15, its four-beat one strong at 0.73).
- **Each span is searched within 4 frames** of the last reading times the span.
- **A peak below `minConfidence`** (0.1, the estimator's existing bar for trusting a reading) **is
  skipped.** The result is never less sure than the one-beat reading.
- **A clear peak on the window's edge stops the search.** The reading has drifted too far to follow.
  Searching on would find a neighbouring beat's peak, at 32 beats the 33rd, and confirm the wrong
  tempo.
- **Spans grow while half the envelope still overlaps itself.**

On *Binta* the app's estimate goes from 83.89 to **82.9994 BPM**, 0.6 ms off by the last beat.

**D2. Done keeps the estimate exact.** The Manual field shows a whole BPM. While it still shows the
estimate, Done commits the estimate itself, not the rounded text. Anything typed commits as typed. An
untouched field with no estimate commits nothing (ADR 0281 D4). The rule is pure
(`TempoMath.manualBPM`), and every place the sheet shows a whole BPM reads one helper
(`TempoMath.wholeBPM`), so the comparison and the display cannot drift apart.

**D3. The fill is left to the rest of the song.** *Binta* ends on a few seconds of guitar with no
beat under it. The autocorrelation compares the whole song with itself, so those seconds are
outvoted. The second half alone, fill included, reads 83.00. Nothing marks or skips them.

**D4. Not decided here: a second 1 that fixes the tempo.** Tomisin asked whether the player should
set the points the estimator measures. Two 1s far apart would fix a steady tempo exactly, whatever
lies between them, with the number of bars between inferred from the estimate. Today an extra 1
restarts the bar count (ADR 0154), so giving it this job is its own decision. It is worth taking up
only if a steady song still drifts after D1.

## Alternatives considered

- **Fit a steady grid to the whole song** (tempo and phase swept together, as the measurement in the
  Context did). Just as exact, but a two-dimensional search that still needs the one-beat reading to
  know where to sweep. D1 reuses the autocorrelation already computed and needs no phase.
- **Let the player choose the stretches to measure.** The right stretches are the ones the maths
  reads well, which a player can't see, and *Binta* needed none. D4 keeps the one form of it that a
  player can check by ear.
- **Show a decimal in the Manual field.** It would make an exact estimate look unsure (83.0, then
  82.9 on another song), and nothing the player does needs it. The field stays whole; the value saved
  is exact.
- **Build the beat finder (B3) first.** It answers songs that move, which Tomisin ranked below
  steady ones. Most of a steady song's drift was one number.

## Consequences

- **A song already set from an estimate keeps its old tempo.** Running *Estimate from audio* again
  replaces it. The stored value is never rewritten behind the player's back (ADR 0004).
- **A song that moves** gets the tempo its repeats agree on, or the search stops early and keeps a
  shorter reading. It is still one tempo; the beat map (ADR 0281) is the answer there.
- **Checked on one real song.** *Binta* is the only audio in the repository, and a unit test now
  decodes it (`PocketTests` carries a copy) and holds its estimate to 83 ± 0.02 BPM. Tomisin's own
  steady songs are checked on the device.
