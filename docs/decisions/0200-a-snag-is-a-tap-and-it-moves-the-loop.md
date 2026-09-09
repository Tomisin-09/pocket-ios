# ADR 0200 — a snag is one tap, and it moves the loop

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-306-snag`)
- **Amends:** ADR 0030 — the armed-state transport's stacked **Loop / Marker** column is removed.
  The idle state's two big identity circles, which that ADR is mostly about, are untouched.
- **Relates to:** ADR 0199 (the half-second floor, which this composes with and depends on),
  ADR 0192 (the transport grammar whose D2 argument this finishes), ADR 0041 (the A/B span the
  accept path lands in), ADR 0070 (never grading — the line this feature runs along),
  ADR 0117 (`PracticeRun.unitUID`, the loose-id-copy shape), ADR 0011 (`Marker`, the neighbour this
  is deliberately not), ADR 0187 (the Oracle, which reads these later but must not be why they exist)
- **Schema:** additive. One new `@Model` (`Snag`) and one new cascade relationship on `Song`. No
  column retyped, renamed or removed — ADR 0189 D1's ordinary work.

## Context

When a player fluffs a passage they have two options today: **stop and think, or carry on and
forget.** Neither is what the moment needs. Stopping breaks the run; carrying on loses the
information, which was only ever going to survive if it cost nothing to keep.

The obvious design is a one-tap mark. The obvious objection is sharper: **if the only thing that
ever reads a snag is the Oracle, this is a data-collection chore wearing a feature's clothes** —
and the Oracle's S2–S5 are Tier 4 "not now", so it would ship as pure cost against benefit that
might never arrive.

That objection is correct, and it sets the bar this ADR has to clear: a snag must pay for itself
**today, with no model anywhere near it.**

## Decisions

### D1 — the payoff is loop placement, and it ships in the same slice

Three marks in the same bar are the app being told where the loop should actually be. The answer is
arithmetic on the marks: take what they span, pad it, offer it. `SnagCluster` is pure, and there is
no model call anywhere in it.

**This composes with ADR 0199, and neither half works alone.** A cluster is typically well under a
second wide. A loop that tight was *impossible* eight hours ago — the floor was 2% of the song,
4.8s on a four-minute track. ADR 0199 made the span reachable; this says where it goes.

**Snag ships with `tightenToSnags` or it does not ship.** That single action is the difference
between a feature and a telemetry pipe with a nice icon.

### D2 — scattered marks propose nothing

Marks spread evenly across the loop are a **true reading**: the trouble is not in one place. The
honest response is to offer nothing.

`SnagCluster.scatterRatio` is `0.6` — once the marks span more than three-fifths of the loop,
tightening buys nothing worth a suggestion. A proposal that fired anyway would be wrong more often
than right, and wrong here means **moving a loop the player deliberately set**.

The same instinct governs three other declines: no marks inside the loop, a degenerate loop, and a
proposal that would not actually be tighter than what is already there.

### D3 — accepting auditions, it does not write

`tightenToSnags` lifts the loop into an **A/B span** (ADR 0041) at the proposed bounds and plays it.
It does not touch `Loop.start` / `Loop.end`.

This is a suggestion assembled from taps made while distracted, so the player hears it before it is
real. Save commits it through the ordinary `saveABSpan` path — which means the narrowing is recorded
by ADR 0199 like any other, with no second write site. ✕ discards it and the loop is untouched.

### D4 — the offer is a transient tenant of the status line

`ModeDescriptionLine` is **not** empty while a loop is armed — it holds *Loop controls*, *Follow*
and *Grid*. So the offer cannot simply live there.

It is gated on `offeringSnagTighten`, set when a tap first makes the marks point somewhere and
cleared when the player takes it, dismisses it, or moves to another loop. That makes it a
**transient mode**, which is exactly what `statusLine`'s ZStack already exists for — the same slot
the A/B and downbeat bars borrow and give back. It sits below both in the chain, so a live span or a
downbeat placement always wins.

Gating on "a proposal exists" instead would have evicted three controls from the screen permanently,
because a proposal exists for as long as the marks do.

### D5 — Snag takes the armed transport's left slot, and two controls go

The armed state carried a stacked **Loop / Marker** column. Both are removed, and **neither is a
trim for space**:

- **Loop disarmed the loop you were working.** `tapAB()` sets `activeLoopID = nil` and calls
  `engine.clearLoop()` — the exact trapdoor ADR 0192 D2 had just closed on the skip buttons,
  surviving on the button next to them.
- **Marker was doing this job quietly**, at 27pt, unlabelled and song-scoped.

One control replaces two, at 38pt rather than 27, because the state where your hands are busiest is
the one that needs a target you can hit without looking. **Idle is untouched** — that is where loops
are *created*, and both controls earn their place there.

### D6 — a snag is a point on the song; the loop is a loose id copy

`Snag` is cascade-owned by `Song`, like `Marker`: 2:01 is 2:01 whether or not the loop that was
armed still exists.

The loop is a plain `loopUID: UUID?`, not a relationship — the `PracticeRun.unitUID` shape (ADR
0117), for the same reason: **deleting a loop must never delete the record of what happened while
you were playing it.** It is also never filtered in a `#Predicate`, so a bare `UUID?` is honest
about how it is read.

What separates a snag from a `Marker` is cost and scope. A marker is a named landmark you stop to
write; a snag is anonymous and costs one tap. That difference is the feature.

### D7 — the glyph is drawn, and it is crimson

Every SF Symbol that fits says the wrong thing. `exclamationmark` is a warning sign pointed at the
player's own playing. `flag` carries a report-this connotation from every other app, and its filled
triangle sits next to the Marker glyph it replaces. `waveform.path.ecg` is visually right and
semantically medical.

So `SnagCatch` is drawn: a line running along that catches on one point. It depicts **what
happened** rather than passing judgement on it — the same distinction that makes *snag* a better
word than *mistake*. A snag is a catch in the fabric, not a failure.

**Crimson**, the Oracle's hue, because a snag's second life is being read back in a reading; the
mark and the thing that reads it look related, which they are. The tone risk was taken knowingly: a
red mark on your own playing can read as a grade. What settles it is that the player put it there —
ADR 0070 forbids *the app* judging, not the player noticing.

### D8 — what is deliberately not built: snags as a trend

A count of marks per run, charted over time, is a score in everything but name. It is technically
self-report, and ADR 0070's letter permits it; its spirit does not, and this ADR declines to argue
the line. Counts appear as *where the marks are*, never as *how many mistakes you made*.

The bar's copy follows: **"3 snags close together"**, not "3 snags this session".

## Consequences

- Marking a stumble now costs one tap and no attention, and the run is not broken to do it.
- The waveform shows density directly — three ticks in a bar look like a cluster. There is no
  collision merging, unlike marker triangles: overlapping ticks stacking into a denser mark **is**
  the correct rendering, because density is the signal.
- The armed transport lost a control that could throw you out of your own loop.
- Snags accrue as Oracle input as a **by-product**, not as a justification. If S2–S5 never ship, the
  feature still paid for itself on the day it landed.
- **Not built:** any reading of snags outside the cockpit — no journal surface, no per-loop history
  screen, no export. The Loops panel does not show a count yet either.
