# ADR 0295 — What you played, by song

- **Status:** Accepted — built (2026-11-13, `pocket-424-practice-log-by-song`), for 1.4.1
- **Date:** 2026-11-13 (`pocket-424-practice-log-by-song`)
- **Amends:** ADR 0241 — **D3** grouped *What you played* by kind and nothing else, with a song's
  time visible only through its loops. The list gains a second grouping, by song (D1, D2). D3's
  refusal to time parts of the app stands, the grouping by kind is unchanged and is still what the
  list opens on, and D4 (a tap narrows the list) and D7 (no comparison between periods) are untouched.
- **Relates to:** 0171 (long-term goals: its echo on this screen and its ban on a denominator are
  unchanged; D4 here adds a label, not a measure) · 0111 (the exercise → song link D3 reads) · 0070
  (never grades: ranked by minutes, nothing marked) · 0242 (the metronome row has nothing to open)
- **Schema:** none. No `@Model` is touched. One `@AppStorage` key, `practiceLogGrouping`.

## Context

The question, on 2026-11-13, was whether the Practice log could show how much practice went toward
each long-term goal, so the log said more than minutes and a list of exercises.

A run does not record a goal, so a per-goal figure has to be worked back from the goal's skills to
the units that serve them. Before any design, that was run over a copy of a real player's store
(3 goals, 365 runs, 2,177 minutes, 31 July to 12 November):

- The two goals that name a **target song** attributed cleanly, because the answer is the song's own
  loops: 418 and 77 minutes.
- The one **skill** goal attributed 494 minutes, none of it from a unit that states either skill.
  All of it was inferred by type or by what a loop can do, and about 90 of those minutes were ear
  training on a loop counted toward an improvisation skill.
- **59% of the log served no goal at all**, most of it ear training.
- The last four weeks were spent almost entirely on two songs that no goal names. The player's
  explanation: an open mic last month, another this month, and a habit of learning whatever is in
  front of them. The goals described the summer; the practice had moved on to songs.

The same store, grouped by song and month, told that story exactly and with no inference:
October was 513 minutes on one cover and 292 on another; November so far is 375 on the second and
76 on a third being transcribed.

## Decisions

### D1 — *What you played* can be grouped by song

A switch under the list's header, **By kind** and **By song**. By song, each row is a song with the
time spent on it, largest first, and practice on no song keeps the row it has by kind: *Exercises*,
*Metronome*, *Other practice*.

**A switch, not a second list.** Both groupings are the same runs, and two lists under each chart
would double a screen ADR 0241 already made longer. **A segmented control, not a menu**, because
there are two answers and a menu would hide that the list reads another way.

**It opens by kind, and keeps the choice.** By kind is what the list has always shown, and a player
with no songs gets nothing from the other grouping. The week's list and the month's share one
stored choice, so the screen is never grouped two ways at once.

**Rejected: per-goal minutes.** The context above is the reason. For a skill goal the figure is an
inference a player cannot check, and on real data it left most practice outside every goal.

### D2 — A song opens onto kinds of work

Under a song: *Ear training*, *Improvising*, *Loops*, *Play-alongs*, *Exercises*, each with its
minutes. The loops themselves are one switch away, by kind, where they have always been.

This is the reading the grouping by kind cannot give. It says a month on a song was mostly by ear,
or mostly trainer runs, which is a fact about how the song was worked on.

*Exercises* (for no one song) opens onto the exercises by name, as it does by kind. *Metronome* and
*Other practice* have nothing to open.

### D3 — Every run lands in exactly one row

So the rows add up to the period's total, as they do by kind.

- A **play-along** counts under the song it recorded.
- A **loop** run of any mode counts under the song the loop belongs to **now**, then the song the
  run was logged with. The live link first means runs logged before ADR 0241 kept a song still find
  theirs while the loop exists.
- An **exercise** counts under a song only when it is linked to **exactly one** (ADR 0111). Linked to
  several, it has no single song to count under, and counting it under each would make the songs add
  up to more than was played. It stays under *Exercises*.
- A loop or play-along whose song the log never knew shares one row, *Song not recorded*.
- A **deleted song** is named by the title its last play-along was logged under, marked *Deleted*.
  A loop's logged name is the loop's, so a deleted song with only loop runs is *A deleted song*.

### D4 — A song that is a goal's target says so

One line under the song: *Goal · Play a specific song*. The highest-ranked goal when two name the
same song.

This is the linkage that survived the check: it is exact, because the goal names the song. It is a
label and not a measure. There is no figure against the goal, no share, and nothing on a goal whose
song went unplayed, so ADR 0171 D7's ban on a denominator is not touched. The echo at the foot of
the screen is unchanged.

## What stays out

- **Per-goal minutes, and a goal page.** Not built, for the reason in D1. A skill goal would need
  attribution a player can check before it could carry a number.
- **A performance or project** (a set of songs being prepared for a date). The check suggests it,
  from one player. **Not decided here.**
- **Time by routine.** Runs carry `routineUID`; 72% of the checked log was outside any routine.
  Still not built, as ADR 0241 left it.
- **The goal's song in the goal's own title.** The check found two goals both titled *Play a
  specific song*. That is the goal list's to fix, not this screen's.

## Consequences

- `PracticeBreakdown` gains `Grouping`, `Row`, `rows(_:names:grouping:)` and `songRows`; `Names`
  gains `exerciseSongs` and `songGoals`. The list draws `Row`s in either grouping with one piece of
  code. Pure and unit-tested (`PracticeBreakdownSongTests`).
- `PracticeLogView` queries `LongTermGoal` for D4.
- The manual's *What you played* section and reference entry describe the switch. **The Practice
  log figures show the new control and are owed in the reshoot.**
