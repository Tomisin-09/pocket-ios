# ADR 0269 — A chosen day takes over the figures

- **Status:** Accepted. Built on `pocket-384-month-grid-dates-and-scale`, beside 0268.
- **Date:** 2026-10-21
- **Amends:** ADR 0241 — **D4**, *"a tap narrows the list; it does not open anything"*. Both halves
  stand. What changes is what else a tap does: the section's figures become the chosen day's, the
  chip that gives the period back moves from *What you played* to just above the chart, the month's
  other practised days dim, and the tap ticks.
- **Relates to:** 0268 (D4: the chosen day is filled, which is what lets the others dim without
  losing it) · 0050 (the haptics setting, which this tick obeys) · 0117 and 0070 (the day's figures
  are the section's own figures for one day; nothing new is counted and nothing is graded) ·
  `docs/design-brief.md` §3.5.
- **Schema:** none.

## Context

Tomisin, after trying 0268 on a device, with a screenshot of September and Tuesday 29th chosen:
*"when you tap on a day, there's not a lot that actually tells you that the information is being
displayed except for the change in date in the tab on the bottom right. What could we do to make
this information more prominent?"*

The screenshot showed it. The cell had filled, and the figures above the grid still read 376
minutes, 9 days, 1 new tempo, which were the month's. The only other change was the chip beside *What
you played*, about 110 points below the grid and often below the fold. The tap landed in one place
and its answer appeared in another.

Three changes were proposed and walked through as a working mock (an artifact, accepted the same
day). This records what was built from it.

## Decision

### D1 — The figures become the day's

While a day is chosen, the figures above the chart are that day's: the section's own figures, for
one day. The week shows the day's minutes. The month shows its minutes and any new tempo. Both drop
the days count, because one day is one day. The minutes figure stays where it is and changes its
number, so the eye that just tapped sees it change.

Pure and tested: `PracticeProgress.day(records:containing:calendar:)`, in
`PracticeDayFiguresTests`. It reads the same bucket the chart draws, so the figure and the cell
can't disagree, and it measures a new tempo against the whole log, as the month's figure does.

### D2 — The chip moves to the chart

The chip naming the day, which gives the whole period back, moves from beside *What you played* to
just above the chart. *What you played* still names the day, as plain text.

- **In the month** it takes the place of *Longest day*. Both are always laid out and one is hidden,
  so the row keeps its height and the grid doesn't move under the finger. A month with one practised
  day has no *Longest day*, and the row is held empty for the same reason.
- **In the week** it takes the place of the days count, beside the minutes. It drops under them only
  at text sizes too large for one line.

### D3 — The other days step back

In the month, the other practised days dim to the week chart's 0.32 while a day is chosen
(`WeekMinutesChart.unchosenOpacity`, now shared). Before 0268 this would have hidden the choice: a
ring on a pale cell among dimmed ones. The chosen day is now a solid fill, so it stays the brightest
thing on the grid. Unpractised days and days to come are already quiet and are left as they are.

**Only the fill dims.** The first build dimmed the whole cell, and on a snapshot the dates on the
darker shades all but vanished, because they are drawn in the page's background colour. A dimmed
day's date is now drawn as an unpractised day's is, at full strength, and today's ring stays whole,
so the grid still reads as a calendar while a day is chosen.

### D4 — The tap ticks

Choosing a day, or letting it go, plays the system selection tick (`HapticStyle.selection`), the one
a picker makes. It confirms the tap before anything has been read. It goes through `haptic(_:)`, so
**Haptics** in Settings ▸ *Sound & feel* turns it off. The change animates briefly (`.snappy`, 0.2 s).

## What stays out

- **Scrolling to the list.** It moves the grid away while you tap from day to day.
- **A sheet.** 0241 D4's reason stands: a second surface with two rows in it.
- **A bigger chip in the old place.** It would still be below the grid, away from the tap.

## Consequences

- `WhatYouPlayedList` loses `clearDay`; its header names the day as text.
- The manual's tap-a-day paragraph is rewritten. The `journal/what-you-played` figure is stale (the
  chip has moved and the figures change) and joins the reshoot list. It is not shot on this branch.
- The shoot (`testPracticeLog`) waits for *Whole week* to go when a day is chosen, which it still
  does.
