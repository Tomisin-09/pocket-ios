# ADR 0206 — a count on the row

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-308-snags-read-back`)
- **Amends:** ADR 0200 — the Loops panel row now shows how many marks sit in a loop (D1), one of the
  items on that ADR's own "not built" list.
- **Relates to:** ADR 0203 (the position rule all three snag surfaces share), ADR 0039 (absence is
  the unrated signal), ADR 0202 (the panel this leaves exactly as it found it), ADR 0125 (the
  multi-select grammar D2 declines to borrow), ADR 0070 (never grading)
- **Schema:** none. No model, no new stored field.

## Context

Marks accumulate, and the only place that said so was a panel you had to open. A loop's row said
nothing about whether the passage had been giving trouble, which is the one thing that would tell you
which loop to open.

`WaveformPracticeModel+Snags.swift` had a doc comment describing `snagsInActiveLoop` as *"the count
the Loops panel row shows"*. It did not.

## Decisions

### D1 — the loop row shows how many marks are in its span, and nothing when there are none

The row's second line gains the snag glyph and a number, after the range and the mastery/command
block: `0:31–0:48 · ●●●○○ · 85% · ⌁4`.

**Nothing renders at zero.** That is the row's existing rule for mastery and command tempo (ADR
0039) and it is the same rule for the same reason: an untouched loop must read as a range, not as a
row full of zeroes claiming things about a loop nobody has practised.

**Position decides which marks count**, not `Snag.loopUID` — ADR 0203 D1's rule, now shared by every
snag surface. The row's count, the Snags panel's rows and the bright ticks on the canvas are then the
same set, which is the only way a player can look from one to another and believe them.

**This is a count, and ADR 0070 permits it.** The line ADR 0200 drew is that counts appear as *where
the marks are*, never as *how many mistakes you made*. A number attached to a span is a property of
that span — "there are four marks in this passage" — and it does exactly the job the feature exists
for: it tells you which loop to open. What stays forbidden is the same number over time, which is a
mistake tally with a chart around it, and nothing here computes one.

It is kept in the **landscape drawer** too, which drops the time range to save width. Two glyphs is a
cheap price for the only thing on that row that says "start here".

### D2 — bulk delete for snags was built, and taken back out

The rest of ADR 0200's and 0202's unbuilt list — multi-select on the Snags panel and a *clear all in
this loop* control — was built on this branch and **removed before merge**, on the device pass. Not
because the mechanism was wrong but because the panel stopped being clean, and for a surface whose
entire argument is cheapness, that outweighs the usefulness.

It is written down rather than quietly dropped, because the idea will be proposed again and the
reason it lost is not obvious from what shipped.

**What was built:** the panel joined ADR 0125's grammar — hold the header, a pinned bar, circles in
place of the row glyph, Done to leave — with a delete-only bar. *Clear all in this loop* **seeded the
selection** rather than deleting, on the grounds that the marks sit in a folded panel judged against
the loop's *current* span, so a one-tap wipe would be the only destructive action in the app whose
reach you cannot check first. A bulk delete carried an undo toast; a single ✕ still did not.

**Why it came out:** it put a fourth mode on a screen that already has three, for the cheapest object
in the app. The panel is *folded by default* precisely because a snag is not something you administer
— you make marks while playing and you read them on the canvas. A selection mode invites you to
manage them, which is the opposite of what the tap is for. And it cost two taps and a hold to reach
an action the ✕ already performs one mark at a time.

**What that leaves standing, unchanged:** ADR 0202 D2's *no multi-select and no edit sheet*, and D3's
*no undo toast* — both back to being simply true rather than true-with-an-exception. This ADR
therefore amends 0202 not at all.

**If it is proposed again**, the thing to solve first is not the delete. It is whether a snag panel
should have a mode at all — and if the answer is that clearing a worked-through passage is a real
need, the cheaper shapes to try are a swipe on a row, or clearing marks as a side effect of an action
the player is already taking, rather than a mode they have to enter and leave.

## Consequences

- A loop row now says whether the passage has given trouble, without opening anything. That is the
  glance the count was always for.
- The three snag surfaces — canvas ticks, panel rows, row count — are all filtered by position, so a
  change to that rule now moves all three together or breaks a test.
- `snagsByTime` has **no pending-delete filter**, unlike `loops` and `markers`. Those defer a delete
  behind an undo window and must hide a row that still exists; removing a snag is immediate and
  unconditional, so there is no such state.
- `PanelSelection` is untouched. The `select(_:)` it briefly grew went out with D2 — nothing else in
  the app chooses rows on the player's behalf, and it should not gain the ability speculatively.
- **Not built, and still refused:** anything that renders a snag count as a trend. A count over time
  is a grade in a costume (ADR 0070), and the third ADR in a row to say so.
