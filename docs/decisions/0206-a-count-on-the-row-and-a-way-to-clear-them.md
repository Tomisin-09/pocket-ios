# ADR 0206 — a count on the row, and a way to clear them

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-308-snags-read-back`)
- **Amends:** ADR 0202 — the snags panel gains multi-select (D2), and a **bulk** delete carries an
  undo toast (D3). D2's no-edit-sheet and D3's no-toast-for-one both stand, and D3 explains why the
  second is not a reversal.
- **Amends:** ADR 0200 — the Loops panel row now shows how many marks sit in a loop (D1), which is
  the last item on that ADR's own "not built" list.
- **Relates to:** ADR 0125 (the multi-select grammar this reuses), ADR 0203 (the position rule all
  three surfaces share), ADR 0039 (absence is the unrated signal), ADR 0019 (deferred delete),
  ADR 0070 (never grading)
- **Schema:** none. No model, no new stored field.

## Context

Three of the four things ADR 0200 and ADR 0202 left explicitly unbuilt are about the same gap: marks
accumulate, and the only place that says so is the panel you have to open. A loop row said nothing;
there was no way to remove more than one mark at a time; and there was no way to clear a passage you
had finished working on without tapping ✕ once per mark.

`WaveformPracticeModel+Snags.swift` had a doc comment describing `snagsInActiveLoop` as *"the count
the Loops panel row shows"*. It did not.

## Decisions

### D1 — the loop row shows how many marks are in its span, and nothing when there are none

The row's second line gains the snag glyph and a number, after the range and the mastery/command
block: `0:31–0:48 · ●●●○○ · 85% · ⌁4`.

**Nothing renders at zero.** That is the row's existing rule for mastery and command tempo (ADR
0039) and it is the same rule for the same reason: an untouched loop must read as a range, not as a
row full of zeroes claiming things about a loop nobody has practised.

**Position decides which marks count**, not `Snag.loopUID` — ADR 0203 D1's rule, now shared by all
three surfaces. The row's count, the Snags panel's rows and the bright ticks on the canvas are then
the same set, which is the only way a player can look from one to another and believe them.

**This is a count, and ADR 0070 permits it.** The line ADR 0200 drew is that counts appear as *where
the marks are*, never as *how many mistakes you made*. A number attached to a span is a property of
that span — "there are four marks in this passage" — and it does exactly the job the feature exists
for: it tells you which loop to open. What stays forbidden is the same number over time, which is a
mistake tally with a chart around it, and nothing here computes one.

It is kept in the **landscape drawer** too, which drops the time range to save width. Two glyphs is a
cheap price for the only thing on that row that says "start here".

### D2 — the panel multi-selects, and "in this loop" seeds the selection rather than firing a delete

The Snags panel joins the loops and markers panels in ADR 0125's grammar: hold the header to enter
selection mode, a pinned bar above the list, circles in place of the row glyph, Done to leave. Its
bar carries **a trash and one other control**, and no more — ADR 0202 D2 declined multi-select
alongside the edit sheet on the grounds that a snag has nothing to set in bulk, which is still true.
Clearing a set of marks is not an edit.

The other control is the request that started this: *clear all in this loop*. It **selects** every
mark inside the armed loop's span. It does not delete them.

That was the decision, and it went the way it did on three counts:

- **You cannot see what it would take.** The marks are in a panel that is folded by default, and the
  span they are judged against is the loop's *current* one, which after a narrowing (ADRs 0199, 0201)
  is not the span they were made in. A single tap that destroys an invisible set, sized by a rule the
  player is not thinking about, is the one action in the app whose reach you cannot check first.
- **It would be a second destructive control.** The panel would then have a ✕ per row, a trash for
  the selection, and a third thing that deletes by a rule of its own. Seeding the selection keeps
  **one** destructive control and makes the shortcut a shortcut to the *choosing*.
- **It costs one tap and buys the whole confirmation.** Tap it and the rows it means are ticked, in
  a mode that already has a Done. Then the trash is the same trash.

It **adds** to the selection rather than replacing it, so using it under two different loops selects
both spans. And it is **absent, not greyed**, when no armed loop has marks in it: "in this loop" with
no loop is not a control waiting to become usable, it is a control with no referent.

### D3 — clearing a set gets an undo; removing one mark still does not

Bulk delete goes through the screen's deferred-delete path (ADR 0019 / 0125): the rows hide, the toast
appears, and the objects are destroyed when the window closes.

ADR 0202 D3 refused a toast for a single ✕, and **that refusal stands**. Its argument was that a snag
carries no authored content — no name, no colour, no rating — so an undo gives back nothing a second
tap could not, and it would cost a row of chrome per tap on the cheapest gesture in the app.

That argument is about **one anonymous timestamp**, and it does not survive multiplication. What a
*set* of marks encodes is where a passage gives trouble, and the only way to remake it is to play the
passage again and trip in the same places. It is also the one snag action that can be aimed at rows
you cannot all see at once — which is the very property D2 built the selection around. A mis-tap on
the trash after "in this loop" is the exact accident an undo exists for.

The toast reads `Deleted 4 snags`, with no name to read back, because a snag has none.

## Consequences

- A loop row now says whether the passage has given trouble, without opening anything. That is the
  glance the count was always for.
- The three snag surfaces — canvas ticks, panel rows, row count — are all filtered by position, so a
  change to that rule now moves all three together or breaks a test.
- `snagsByTime` became the single read for every snag surface, including the waveform's tick band, so
  a mark hidden by an open undo window leaves the canvas and the panel in the same frame. Reading
  `song.snags` directly anywhere on this screen is now a bug.
- `PanelSelection` gains `select(_:)`. It is the first thing in the app that chooses rows for the
  player, and it is deliberately additive rather than replacing.
- Only one panel selects at a time, unchanged — entering any of the three modes ends the other two.
- **Not built, and still refused:** anything that renders a snag count as a trend. A count over time
  is a grade in a costume (ADR 0070), and the third ADR in a row to say so.
