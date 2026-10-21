# ADR 0268 — A month grid with dates, today, and a scale one long day can't wash out

- **Status:** Accepted. Built on `pocket-384-month-grid-dates-and-scale`.
- **Date:** 2026-10-21
- **Amends:** ADR 0241 — **D7**, *"the scale stays the month's own"*. It still does, but the darkest
  shade now starts at the month's **typical** practised day (its upper quartile), not its longest, so
  the *Longest day* line above the grid is no longer the scale. D7's refusal to compare one period
  with another stands, and so does its refusal of a fixed number.
- **Relates to:** 0117 (no target, no goal, no streak, all unchanged; and its rule that "nothing"
  never reads as "a little", which the old palest shade was quietly breaking, D6) · 0190 D9 and
  0207 D5 (the Journal's month grid, whose rings mark *presence*; this grid's one ring marks *today*)
  · 0070 (nothing here grades) · `docs/design-brief.md` §3.5 (numbers shown, never judged).
- **Schema:** none.

## Context

Tomisin, on the Practice log's month grid, with a screenshot of October:

1. *"We should add the date numbers."*
2. *"A white border around the current date."*
3. *"It's always relative to the most practiced day. Let's say you aim to practice 20 mins a day …
   and you succeed with this 29 out of 30 days. But if there's a day in which you practice for 2
   hours, the heatmap shades those other 29 days much lesser in comparison. It should be anchored to
   something user defined, like a daily practice target."*
4. Any small wins while we're here.

The screenshot showed it. October's longest day was Friday 16th at 165 minutes. Every other practised
day was 30 minutes or less, so all ten of them drew the palest shade: 30 / 165 is under a quarter.
The grid said "you barely practised" about a month of steady practice.

**The target was weighed and not taken.** A user-set number is a daily goal, and 0117 holds goals
with the deferred streaks, behind an opt-in and a rest-day freeze. 0241 D7 and the manual both say a
fixed number *"would be a daily target by the back door"*. The fault in item 3 is real, and it doesn't
need a target to fix it: one outlier sets the scale. Three choices were put to Tomisin: the month's
typical day, worked out by the app (keeps the rule); a number you set, opt-in (reverses 0117 for this
grid); or both. **Tomisin chose the typical day.**

## Decision

### D1 — The darkest shade starts at the month's typical practised day

The scale is the **upper quartile** of the month's practised days, by nearest rank, in seconds. A
day's shade is which quarter of that it falls in. Anything at or past it is the darkest, and any
practice at all reaches the palest. With three practised days or fewer, nearest rank lands on the
longest, which is right: three days have no "typical" to find. Pure and tested:
`PracticeProgress.Month.shadeScaleSeconds` and `shade(of:)`, in `MonthShadingTests`, including the
29 × 20 min + 1 × 2 h case that asked for it.

**The quartile, not the median.** On the median, half of every month's practised days would draw the
darkest shade, leaving gradation only below the middle. The quartile shrugs off a quarter of the days
being unusually long and keeps three shades for everything under it.

**This month, not a trailing window.** A scale over the last 90 days would carry across pages, but
the grid pages month by month, and D7 gave each page its own terms. That stays.

**It is still relative, and that is the point.** A month of five-minute days reads mostly full. The
grid answers *how often* (0117); *how much* is the minutes figure above it.

### D2 — No number on the scale

The key stays as words. *Longest day* was the scale's number. Now it is only a fact about the month,
and it stays as one. The new scale gets no number of its own: *"20 min"* beside the darkest swatch
would read as minutes to reach, which is the target D1 doesn't set.

### D3 — Each cell carries its date, and the columns have weekdays

The day number sits in the cell's top-leading corner at `caption2`. It goes in the corner, not the
centre, because the shade is what the cell is for and the date labels it. At the accessibility
sizes it scales down to half rather than spill. Its colour depends on the fill under it. Over the
neutral it is secondary text. Over the paler shades it is ink. Over the darker shades it is the page
background. The practice teal is light in the dark appearance and dark in the light one, so that
switch happens at shade 2 in dark and shade 3 in light. Measured against the asset values, every
pairing is at least 4.1 : 1.

Weekday initials head the columns, from `JournalMonthLayout.weekdayInitials`, the same tested
rotation the Journal's grid uses. Like the key, they are drawn once above the pager, not once per
page.

### D4 — Today is ringed; the chosen day is filled

Today gets a 2 pt ink ring, inside the cell for the reason the selection ring was: a ring outside the
frame is clipped at the pager's edges. That ring used to mean *the chosen day* (0241). The chosen day
now **fills with ink**, its date in the page background, which is how Calendar marks the date you
picked. Only a practised day can be chosen, and its minutes are in the list it narrows, just below.
So while it is chosen, hiding its shade loses nothing the screen doesn't show anyway.

The week chart already marks today its own way (a bold weekday label) and keeps it.

### D5 — Days still to come are outlines

Days after today drew the unpractised neutral. On 21 October that put ten absences on the screen
that were nothing of the kind. They are now a 1 pt border with no fill. VoiceOver reads them as the
date alone, where it said *"no practice"*. Each cell's spoken label also gained its weekday and
*"today"*.

### D6 — The palest shade moves off the neutral

The ramp was `0.25 / 0.45 / 0.7 / 1.0`. At 0.25 the palest practised shade was 1.21 : 1 against the
unpractised neutral in dark and 1.17 : 1 in light, the smallest step anywhere on the scale. A short
day looked like a day off, which is the confusion 0117 built the neutral to prevent. It is now
`0.4 / 0.6 / 0.8 / 1.0`, and every neighbouring pair, neutral included, differs by 1.37–1.71 : 1.

## What stays out

- **A daily target, a goal, a streak.** 0117's deferrals stand. Whether an opt-in number ever joins
  this grid is **not decided here**. If it does, it reverses 0117 and gets its own ADR.
- **The line *Complete the grid*.** It came up in the same conversation as a marketing line. It is
  **not decided here**, and nothing in the app says it.

## Consequences

- `docs/manual/journal-and-practice-log.md` *This month* is rewritten: dates, today's ring,
  outlines, the typical-day scale, and a chosen cell filling in. The `journal/month-heatmap` figure is
  stale and joins the reshoot list. It is not shot on this branch.
- ADR 0241 carries an *Amended by* note. `PROJECT.md` and `docs/architecture.md` no longer say the
  ramp is scaled to the busiest day.
- The two month grids now both show dates. They stay distinct in the way 0207 D5 needs: this one is
  filled squares on a four-step ramp with a key; the Journal's is rings on numbers with no ramp and
  no key.
- `PracticeProgress.Month.peakMinutes` is gone. Its one reader was this grid. The week chart keeps its
  own.
