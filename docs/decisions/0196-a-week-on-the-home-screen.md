# ADR 0196 — a week on the home screen, and the payoff stays where it is

- **Status:** Accepted
- **Date:** 2026-09-07 (`pocket-302-tuner-and-stat-strip`)
- **Relates to:** builds the Home summary tier **ADR 0117** designed and could not place, over the
  aggregation that ADR's Slice 2 made pure. Leaves **ADR 0176**'s placement of the payoff screen
  intact. Retires the card **ADR 0060** introduced and ADR 0117 §113 left in place. Sits inside the
  grouping **ADR 0102** established, without reversing its tile-grid rejection. Bound by **ADR
  0070**. Picked up from `docs/directions-2026-09.md` §2 / §6 Tier 2 item 5.
- **Schema:** none. Two `@Query`s over rows that already exist.

## Context

Home is a launcher. Six navigation rows, static for the life of the app, so scrolling it pays
nothing — you learn their positions in a week and never read them again. `docs/directions-2026-09.md`
§2 argues for spending that height on **content that changed since yesterday**, and its option A
does two things at once: collapse the rows into a tile grid, and add a stat strip.

This ADR does only the second. The tile grid is six call sites, subtitles leaving the screen, manual
copy, `check-manual.py` and a Home reshoot; the strip is additive and touches no existing copy. Doing
the content half first proves it and de-risks the layout half, which is why §6 ranks them in
different tiers.

The material is already there and unused. `PracticeProgress.summarize` and the whole `PracticeLog`
windowing layer have been pure and tested since ADR 0117; `PracticeStatsCard.swift` has had **no call
site** since the 2026-07-09 hub rework, and ADR 0117 §113 deliberately left it in place for a future
that has now arrived in a different shape.

## Decisions

### D1 — Three tiles, one horizon: `This week`

**Minutes · Days · Notes**, all windowed to the same seven days, under a `This week` `HomeSection`
so the horizon is stated rather than inferred.

One horizon because three numbers that quietly mean different spans is a chart that lies. The
directions doc's sketch paired two week figures with an all-time note count; that reads as three
facts about a week and is not. `PracticeLog.count(_:in:)` is added so a journal note windows exactly
the way a run does — start-inclusive, end-exclusive — and a note and a run written in the same minute
always land in the same week.

It lives on `PracticeLog` and not on `PracticeProgress` because a note is not a `SessionRecord` and
never will be: it is a thing you wrote, not a run that was timed.

### D2 — `PracticeStatsCard` is deleted, not adapted

Its fourth tile is **Mastered** — a count of units self-rated 5. That number is the reason the card
cannot become the strip:

- It totals up **self-ratings**, and totalling a self-assessment turns it into a score the app is
  keeping. ADR 0070 is that the app never grades playing; ADR 0176 is *a record, not a verdict*.
- It only ever goes **up**, sitting beside two numbers that can fall. A quiet week then reads as a
  quiet week next to a trophy count, which is a comparison nobody asked for.

The other three tiles (loops, exercises, notes) are **inventory** — they measure library size and go
*down* when a drill is deleted. ADR 0117 already demoted them to supporting texture on the Practice
log for that reason; they are not a headline.

So the card is deleted rather than left as dead code beside a live strip that supersedes it. Its
inventory roll-up, `PracticeStats.summarize`, is untouched — the Practice log's achievement wall
still uses it.

### D3 — It reads back; it does not navigate

The strip is not tappable.

ADR 0176 moved the Practice log into the Journal on an argument about what that screen is, and
`docs/directions-2026-09.md` §5d names its two-taps-deep placement as an open item worth reopening
**on its own**. Making the strip a door would reopen it as a side effect of adding a number, and
settle by accident a decision that deserves to be taken deliberately. The promise ships; the payoff
stays where 0176 put it.

### D4 — Nothing logged, nothing drawn

The strip renders **nothing at all** when no run exists — not three zeroes, not an empty state.

That objection is already recorded in the repo, at `JournalTabView+PracticeLog.swift`: a summary on a
fresh install hands the player a row of nothing to read before they have read anything else. The
test is `runs.isEmpty`, which *is* `PracticeProgress.Summary.hasNoHistory` — lifetime emptiness is
run count — asked without building two horizons and an inventory to ask it through.

### D5 — Its own view, with its own queries

`HomeStatsStrip` holds its `@Query`s rather than taking them from `HomeView`. `HomeView` is near
SwiftLint's 400-line cap and already runs six queries; two more, paid on every Home redraw whether or
not anything has been practised, for a strip it does not otherwise touch. `TrialCountdownRow` is the
precedent — a self-contained child that draws nothing until it has something to say.

Placed **below** the resume card, because what you were doing outranks how much of it there has been,
and **above** the navigation sections, because those are the static thing this is meant to outrank.

### D6 — What is deliberately absent

No goal, no denominator (*4 of 7*), no streak, no week-over-week delta, no target line. All four are
habit-pressure under different names, all four travel with the deferred streak work (ADR 0117), and
a home screen is the worst place to introduce one. Every number here describes what happened.

## Consequences

- Home gains its first content that changes day to day, and `reference/home-and-library.md` gains
  prose for it.
- ⚠ **`reference/home` is knowingly stale and is not reshot here.** `launchForShoot()` passes
  `-seedHistory`, so the seeded figure would now carry real numbers, and the filed one does not show
  the strip at all. It is left that way **deliberately**, batched into the tile-grid work above:
  `docs/directions-2026-09.md` §2 warns that a shoot is ~6 minutes over a harness with five recorded
  traps, and the tile grid changes this same figure again. Shooting it twice buys nothing. **The
  debt is the tile grid's to pay**, and it is written into that Tier 3 entry so it cannot be
  forgotten — the recorded failure mode here is a figure going stale under a prose change with
  nothing noticing, so it is noticed in writing instead.
- ADR 0102's grouping is untouched and its tile-grid rejection stands unreversed. The reversal, if it
  comes, is the Tier 3 work and gets its own ADR.
- A player with notes but no runs sees no strip, because `hasNoHistory` is about runs. Correct: the
  strip is headed `This week` in a practice app, and a week with nothing practised in it is the state
  D4 exists to keep quiet.
- **Not covered:** the tile grid, the year tier, the "wrapped" card, and whether the Practice log
  should be closer than two taps. The last one is now the only part of §2 still to argue.
