# ADR 0203 — a snag in the loop you're in

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-307-span-history-and-return`)
- **Amends:** ADR 0200 — snag ticks are no longer drawn at one flat opacity: marks inside the armed
  loop are full strength and the rest recede (D1). The mark, the cluster rule and the tighten offer
  are unchanged.
- **Amends:** ADR 0202 — snag rows gain the name of the loop they were made under (D2). **D2's
  song-order sort stands**; this is a caption, not the grouping that was considered and declined.
- **Relates to:** ADR 0023 (the annotation bands), ADR 0117 (`unitUID`, the loose-id-copy shape
  `Snag.loopUID` follows), ADR 0070 (never grading)
- **Schema:** none. No model, no new stored field — both halves read what ADR 0200 already stores.

## Context

Two requests off a device pass, from one observation: **a snag is loop-born.** That is literally
true — `SnagControl` renders only when `loopActive`, so there is no way to make a snag without a
loop armed, and `Snag.loopUID` is always populated in practice (the `nil` case is defensive).

The proposals were to fade marks belonging to other loops, and to group the Snags panel by loop.
The first is right with one change. The second is right about the problem and wrong about the fix.

## Decisions

### D1 — the fade keys on position, not on `loopUID`

Marks **inside the armed loop's span** draw at full strength; the rest at `snagFadedOpacity` (0.35).

The obvious implementation — fade by the loop the mark was recorded under — would put the drawing at
odds with the feature's own arithmetic. `SnagCluster.proposal` and `snagsInActiveLoop` both filter by
**position**:

```swift
.filter { $0.seconds >= loopStart && $0.seconds <= loopEnd }
```

So a snag marked under loop A, sitting inside loop B's span, would render **dimmed while being
counted** in *"3 snags close together"* and while driving the offer in the status line directly
above it. A faded mark visibly feeding a live suggestion reads as a bug, and it would be one.

Keyed on position, the two agree exactly: **the bright marks are the offer's input.** The fade
becomes a preview of what tightening would use.

It is also the better question. Mid-passage, what a player wants to know is *have I tripped here
before* — not *which loop was armed when I did*.

**With no loop armed, everything draws full.** There is no work area to contrast against, and
dimming the whole canvas would say nothing. This is deliberately the opposite of `drawLoopLines`,
which dims every line when none is active — that dimming exists to make one line pop out of many,
which is a different job.

**The contrast is made upward.** In-loop marks go to 1.0 rather than the out-of-loop ones going far
below the old flat 0.85. A tick is 1.5 pt of the quietest colour on the canvas (ADR 0202 D1 having
just thinned it); taking it further down erases it.

### D2 — the panel gets the loop's name as a caption, and keeps song order

A row reads `2:08 · Post Solo Riff · 0.75×`. The name resolves from `loopUID` through the loops that
still exist, and a snag whose loop was deleted simply shows no name — the mark outlives the loop by
design (ADR 0200), so its caption has to be allowed to not.

**Grouping by loop was considered and declined**, on three counts:

- **It splits clusters.** Two marks a beat apart, made in different sessions under different loops —
  which is exactly what happens when the loop is narrowed between attempts, the thing ADRs 0199 and
  0201 actively encourage — would land in separate groups while describing one problem spot.
  Proximity is the entire signal.
- **It answers a different question.** ADR 0202 D2 sorts by position because the panel is *a map of
  where this song gives trouble*. Grouping makes it a map of which loop you were in.
- **It asserts an ownership nothing else believes in.** With overlapping loops a mark sits inside
  several spans but would group under one, and D1 above deliberately ignores `loopUID` for exactly
  that reason.

What grouping was really reaching for is that **a bare timecode is anonymous**. The caption fixes
that at a fraction of the cost, with no section headers charged against a panel ADR 0202 D2
deliberately made cheap to open.

The speed keeps its width against a long loop name (`layoutPriority(1)`); the name truncates.

## Consequences

- **No new plumbing for D1.** `WaveformView` already holds `loop: Loop?` for the region tint and the
  boundary lines, so `drawSnags` reads the armed span with no signature change and nothing new on
  the playhead's path.
- The fade holds steady through a tighten audition: `tightenToSnags` lifts an A/B span but leaves
  `activeLoopID` set, so the marks stay keyed to the saved loop's span rather than flickering to the
  proposal's bounds.
- `loopNamesByUID` is built once per render rather than searched per row.
- ⚠️ **`WaveformCanvas.swift` now sits at exactly 400 lines**, the SwiftLint cap — the same state
  ADR 0201 left `WaveformPracticeModel.swift` in, and that one was breached within a day. Two
  constants pushed it to 403 and it was brought back by compressing the comments this ADR and 0202
  had just added, on the grounds that both arguments are written out here in full. **The next
  addition to that file splits it** rather than shaving prose again; there is no third pass of that
  available. The natural seam is the remaining drawing helpers, which is where `WaveformDownbeat.swift`
  already came from.
- **Not built:** grouping, a sort control, a per-loop snag count on the Loops panel row, and any
  count rendered as a trend (ADR 0070).
