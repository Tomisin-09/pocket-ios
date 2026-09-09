# ADR 0202 — what a snag costs to unmake, and a rung back down

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-307-span-history-and-return`)
- **Amends:** ADR 0200 — snag ticks are resized and the time bubble moves off them (D1); snags gain
  a panel, so a mark can be reached and removed (D2, D3). The tap, the cluster rule and the tighten
  offer are unchanged.
- **Amends:** ADR 0201 — the tempo-return rule is **re-anchored to a gesture** and now offers the
  rung above rather than the top of the ladder (D4); the span history collapses to three rows (D5).
  D1's "no cockpit surface" and D3's "widening auditions, it never writes" stand.
- **Relates to:** ADR 0206 — its D2 records that multi-select and a bulk clear were **built on the
  snags panel and taken back out before merge**. D2's *no multi-select, no edit sheet* and D3's *no
  undo toast* therefore stand exactly as written, with no exception.
- **Relates to:** ADR 0199 (the spans this reads), ADR 0023 (the annotation bands the tick geometry
  lives in), ADR 0125 (the panel grammar this borrows and trims), ADR 0070 (never grading)
- **Schema:** none. No model, no new stored field.
- **Amended by:** ADR 0203 — snag rows carry the name of the loop they were made under (0203 D2).
  **D2's song-order sort stands**, and 0203 declines the grouping-by-loop that would replace it, for
  the reason D2 gives: proximity is the signal, and grouping splits a cluster.

## Context

ADRs 0200 and 0201 went to a device together. Six things came back off one screenshot, and all six
are the same kind of finding: not "this is wrong" but "this was drawn without looking at what was
already there".

The screenshot is the argument. The playhead's time bubble sat squarely across the snag ticks — two
crimson marks half-hidden behind a `2:08` capsule — because `drawSnags` measured 11 pt up from the
loop band and the bubble measured 12 pt up from the same edge, in a different file, with neither
number knowing about the other.

## Decisions

### D1 — the tick band is a shared constant, and the bubble sits above it

`WaveformCanvas.snagBand` (9 pt) is now the one number, read by both `drawSnags` (which grows the
ticks up from the loop band) and the time bubble (which sits down against them). The bubble clears
the band by its own half-height plus a hair.

The ticks are also **thinner and shorter** — 9 × 1.5 pt, from 11 × 2. At the old weight they read as
annotations in their own right, competing with the marker triangles they were explicitly designed
not to compete with (ADR 0200). A snag is the quietest mark on the canvas; it should read as texture
until you look for it.

The collision is worth naming as a class, not just fixing: **two elements measured from the same
edge, in two files, by two literals.** Neither number was wrong on its own.

### D2 — snags get a panel, folded, after Markers

A `SnagsPanel` in the reference list: tap a row to go there, ✕ to remove it.

ADR 0200 shipped a mark that could be made and never unmade. There was no row, no list and no delete
anywhere in the app — the only trace was a tick on the canvas, and the only thing you could do about
it was leave it. **A mark you cannot remove is not a cheap mark, it is a permanent one**, and
cheapness is the entire argument for the one-tap gesture.

It borrows the loops/markers grammar (`CollapsiblePanel`, tap-the-row-to-seek) and **trims what a
snag has no use for**: no multi-select, no edit sheet, no hold. A snag has nothing to rename,
recolour or rate, so what is left of a row's affordances is *go here* or *forget it*.

Rows are ordered **by position in the song, not by when they were tapped** — the panel is a map of
where this song gives trouble, and sorting by recency would scatter three marks in one bar across
it. It starts **folded**: it is somewhere you reach for a mark, not a list anyone opens the screen
to read, and an open one would push Loops and Markers down.

### D3 — deleting a snag has no undo toast

Unlike a loop or a marker (ADR 0125), which vanish behind a pending-delete set and a toast.

Those carry authored content — a name, a colour, a mastery, a range someone tuned — and a mis-tap
costs work. A snag is an anonymous timestamp. The toast would guard nothing, and it would cost a row
of chrome across the bottom of the screen every time someone tidied up a handful of marks.

Deleting the last snag folds the panel to *None*, which is the only state it has anything to say
about.

### D4 — the return pill goes back one rung, and now appears at all

Two changes to one rule, and the second is a bug the first exposes.

**It offers the rung above, not the top.** A player who drops 1.0 → 0.75, works, then drops
0.75 → 0.60 is offered **0.75**, not 1.00. ADR 0201 D2 already decided this shape for spans —
*"isolating is a ladder, and coming back down it a rung at a time is the point"* — and then the
tempo half of the same ADR did the opposite. Nothing justified the difference; it was two rules
written an hour apart.

**And the rule is anchored to a gesture, not to consecutive writes.** `TempoReturn.remembered` used
to compare each write of `speed` against the previous one and call it a drop when the gap exceeded
`minimumDrop` (0.05). But the speed slider is continuous: one drag writes `speed` on every frame, in
steps far smaller than 0.05, so **no frame ever counted as a drop and the pill never appeared from a
drag at all.** It could only ever be raised by a preset pill, a typed value or the automator. The
feature was half-dead on arrival and the unit tests could not see it, because they called the rule
with the big discrete jumps a slider never makes.

The fix is to anchor to the **settled speed the gesture started from**, captured in
`userAdjustedSpeed` — which every hand on the tempo already calls, on the slider's *grab* and before
a preset or typed value commits. Every frame of one drag then agrees on the same answer, and "the
rung above" falls out of it for free: a new gesture from a settled speed is a new rung.

`TempoReturnTests` now walks an actual drag, one hundredth at a time, and asserts inside the loop
that a per-write rule would have found nothing — so the regression cannot come back unnoticed.

### D5 — the span history shows three, and grows only when asked

*How it got here* caps at the three most recent changes, with **Show all N changes** when there are
more.

The history has no end. A loop worked on for a month gets a row per edit, and an unbounded list
pushes *Delete* — and everything else in the sheet — a scroll away, in service of a log almost
nobody reads past the top of.

**The Widen back action stays outside the fold.** It is the only thing in the section anyone acts
on, and an action buried under *Show all* is an action nobody finds.

## Consequences

- **`WaveformPracticeModel.swift` was split**, which ADR 0201 predicted in as many words: it stood
  at exactly 400 lines and this needed two more stored properties. The Now Playing / playback
  lifecycle block (ADR 0025) moved wholesale to `WaveformPracticeModel+NowPlaying.swift` — the
  cleanest seam in the model, five members that only talk to the lock screen and the screen's own
  entry and exit. `nowPlayingState` and `wipeTransientState` lost their `private` in the move; Swift
  has no cross-file-private for a single type, the same reason `gridCache` is `internal`.
- The model is back to ~340 lines, so the next stored property does not force another split.
- **`TempoReturn.remembered` changed signature** (`movingFrom:to:` → `gestureStart:now:`). There is
  one call site and one test file; it is not a shared rule.
- **Not built:** no bulk delete for snags, no "clear all in this loop", no snag count on a loop row,
  and nothing that turns a snag count into a trend. The last of those is the one to keep refusing —
  a count rendered as a chart is a grade wearing a costume (ADR 0070).
