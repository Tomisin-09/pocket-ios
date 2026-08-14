# ADR 0166 — the last few taps are the tempo

- **Status:** Accepted
- **Date:** 2026-08-14 (`pocket-265-trailing-window-tap-tempo`)
- **Extends:** ADR 0024 (tap tempo, `preciseBPM`)
- **Relates to:** ADR 0004 (BPM is best-effort and user-correctable), ADR 0154 (a grid you can
  correct as you go), ADR 0043 (the standalone metronome)

## Context

`TempoMath.bpm(fromTapTimes:)` averaged **every** inter-tap gap since tapping began. No window,
no outlier rejection, and neither caller ever trimmed its `taps` array — the song BPM sheet
only on an explicit Reset, the metronome only after a 2-second pause.

Against a steady recording that is the right estimator: more samples, less noise. Against
hand-played, unquantised material — the J Dilla case that produced ADR 0154 — it fails three
ways at once:

1. **It averages across the drift.** Tapping a passage that moves 89 → 93 BPM returns ~91, a
   number correct at neither end of the passage just tapped.
2. **The worst taps are the first taps.** The gaps from finding the pulse stay in the mean for
   as long as tapping continues.
3. **It grows less responsive the longer you tap.** With 40 gaps banked a new tap moves the
   result by ~1/40th, so the natural instinct — keep tapping until it settles — freezes the
   number instead of refining it. On the standalone metronome this is visible live, because
   `MetronomeView.recordTap` commits `engine.setBPM` on *every* tap.

ADR 0154 fixed the **phase** this number produces (a song may carry several downbeat anchors)
and explicitly parked the number itself: anchors bound where phase error accumulates, they do
not make a badly-fitted BPM fit. This is the other half.

## Decision

**Read the last twelve gaps, and drop the ones that disagree with their median.**

```
gaps (non-positive discarded — the ADR 0024 loop-wrap rule)
  → last `tapWindow`
  → drop gaps further than `tapOutlierTolerance` from that window's median
  → mean → 60/mean → clamp to minTapBPM...maxTapBPM
```

Three constants carry the decision, all on `TempoMath` beside the existing tap bounds:

- **`tapWindow = 12`** — measured in *gaps*, so twelve gaps is thirteen taps, roughly three
  bars of 4/4. Long enough to average out a hand's jitter, short enough to follow music whose
  pulse actually moves. (Was 8 — see §Revision.)
- **`tapOutlierTolerance = 0.15`** — a gap counts when `|gap − median| / median <= 0.15`.
  (Was 0.3 — see §Revision.)
- **`minGapsForOutlierRejection = 4`** — below this every gap is kept. With two or three gaps
  there is no majority to be an outlier *from*, and rejecting against a two-sample median
  would simply discard the higher one.

**The window and the rejection are one decision, not two.** Shortening the window to twelve
makes each gap worth ~1/12 of the reading rather than ~1/40th, so a single fumbled tap does
*more* damage after this change than before it. Windowing without rejection would trade a
sluggish reading for a jumpy one. The tolerance is sized around the errors that actually
happen — a double-tap splits a gap to ≈0.5× the median, a missed beat doubles one to ≈2×, and
moderate mistiming sits somewhere between — while leaving genuine movement alone: 89 → 93 BPM
across one window puts the extremes ~2.2% from the median, roughly seven times inside the band.

The median is `AudioMath.percentile(_:0.5)`, already the repo's robust reference for ignoring
outliers. Because the band is centred on a median, at least half the gaps always survive, so
the mean never divides by zero and the function stays total.

**Both tap surfaces get it,** through the shared pure function and with no call-site change:
the song BPM sheet (`WaveformBPMSheet`) and the standalone metronome (`MetronomeView`). Two
behaviours from one function would need a reason, and there isn't one — the freeze in §3 is if
anything more visible on the metronome, which commits on every tap. The metronome's 2-second
`tapResetGap` stays: it marks a *new measurement*, which a rolling window cannot express.

**The unwindowed mean stays reachable** as `window: 0`. It is the better estimator on steady
material and this ADR trades it away deliberately; keeping it expressible is what lets the
tests pin both behaviours, and what a future per-surface split would use.

## Alternatives considered

**A settings toggle.** Rejected: nobody can answer "should tap tempo average 8 taps or all of
them?" before tapping, and the honest default is the one that works on the harder material.
The all-taps mean is only better on songs where the difference barely shows.

**Windowing without rejection** — the shape the backlog entry originally described. Rejected
above: the window is exactly what makes a stray tap expensive.

**A weighted mean** (recent gaps weighted higher, nothing discarded). Smoother in principle,
but it keeps a double-tap in the reading at reduced weight rather than recognising it as an
error, and it needs a decay constant that is harder to justify than a window length.

**Trimming `taps` in the two views instead.** Rejected: it would duplicate the rule in two
`@State` arrays with different clocks — the sheet holds song time, the metronome wall clock —
and leave the pure function still wrong for any third caller.

**A tighter tolerance** (±15%). Rejected: at that width a genuine ritardando starts being
rejected as error, which is precisely backwards for the material this exists to serve.

## Revision — device testing, 2026-08-14

Shipped first as `tapWindow = 8` / `tapOutlierTolerance = 0.3`. On the phone the responsiveness
half was clearly right — the metronome tracks a deliberate tempo change instead of freezing —
but **a fumbled tap still visibly moved the number**. Both constants moved, in opposite
directions, for one reason each.

**A mistimed tap is a *paired* error.** Tapping early by 0.06 s shortens one gap by 0.06 and
lengthens the next by exactly 0.06. Those two cancel in the mean and the reading never moves —
*provided both halves sit inside the window*. At eight gaps a fumble near the edge was split:
one half rolled out, the survivor was left uncancelled, and it showed. Twelve makes the pair far
more likely to be read together, which is the real reason to widen rather than "each gap counts
for less". `testTapTempoAbsorbsAnEarlyTapWhenBothHalvesAreInTheWindow` pins it.

**The tolerance had to *tighten*, not loosen — the intuition here inverts.** A wider band keeps
*more* bad gaps, so raising it makes a fumble matter more, not less. At 0.3, tapping 0.5 s gaps,
anything from 0.35 to 0.65 counted: a tap 30% off the beat was accepted. Since genuine drift
needs ~2.2% and ordinary hand jitter a few percent more, 0.3 was buying nothing and admitting
the moderate mistiming that was leaking through. 0.15 keeps roughly seven times the headroom
drift actually uses.

**Two test fixtures moved with it**, both of which had been sized to sit just inside the old
band so they isolated the window from the rejection (`…WindowDropsTheGapBeyondIt`,
`…WindowArgumentIsHonoured`). Their off-tempo gap went 0.6 → 0.55 to stay inside the new one.
The expectations are now computed from the fixture rather than hard-coded, so a future constant
change moves them automatically instead of silently inverting what they test.

## Consequences

- **Slightly noisier on rock-steady material.** Eight gaps is fewer samples than forty, so a
  perfectly quantised track now reads with marginally more variance than before. This is the
  deliberate trade: the tapped number is user-confirmable at both call sites (ADR 0004), and
  a player tapping a steady track can tap a moment longer or type the value.
- **Every existing `bpm(fromTapTimes:)` test still passes unchanged.** All seven use four or
  fewer gaps, so neither the window nor the rejection floor engages on them. That is a
  property of the chosen constants, not a coincidence — if one of those tests starts failing,
  the constants moved, not the expectation.
- **The tap footer in the BPM sheet says so.** The reading now moves while you tap, which is
  surprising if unexplained — the same honesty rule ADR 0154 applied to its "one BPM per song
  is still not correct" footer.
- **This is the authoring tool the tempo map will need.** A per-section tempo map (the next
  ADR) is authored by tapping through a section and reading *that section's* tempo, which is
  what a trailing window produces and an all-taps mean cannot.
- The view-level accumulation is still untested — `taps` in both screens is `@State`, and the
  metronome's 2-second reset has no coverage. Pre-existing, unchanged by this, and untouched.
