# ADR 0298 — What you played, by goal

- **Status:** Accepted — built (2026-11-15, `pocket-428-practice-by-goal`), for 1.4.1
- **Date:** 2026-11-15 (`pocket-428-practice-by-goal`)
- **Amends:** ADR 0295 — **D1** rejected per-goal minutes, and *What stays out* left a goal's song
  out of its name as the goal list's to fix. Both are taken up here: *What you played* gains a third
  grouping, by goal (D2–D5), and a goal made from the song template is named for its song (D1). The
  rest of 0295 stands. By kind is still what the list opens on, by song is unchanged, and its D4
  caption now carries the goal's shown name.
- **Amended by:** ADR 0299 (2026-11-15) — a **set** counts each of its songs the way D2 counts a target
  song, and opens onto its songs rather than kinds of work (an exception to D5). D3, D4 and D6 stand.
- **Relates to:** 0171 (long-term goals: the echo is untouched, D7's ban on a denominator holds, and
  D1's "no date" holds, since `dateAdded` is read in D4 and never shown) · 0241 (the list this
  regroups) · 0070 (never grades: ranked by minutes, nothing marked) · 0139 (O2a, the mode a loop is
  claimed in, which D2 counts by) · 0015 (the deriver D2 reads)
- **Schema:** none. No `@Model` is touched. The `practiceLogGrouping` key gains a value, `goal`.

## Context

ADR 0295 checked per-goal minutes against a real player's store and turned them down, because a
skill goal's figure was an inference the player could not check. Two days later the player asked
for them back, for a different reason: *"If I'm not dedicating time towards my initially set goals,
then I should be able to review that, then adjust accordingly."*

That purpose changes what the figure is for. It is not credit toward a goal. It is the gap between
what was set out and what was played. The 0295 check had already found that gap: **most of the log
served no goal**. It treated that as a reason not to build, when it is the reading a review exists
to give.

The objection still has to be met, because an over-count is the worst error a review can make: it
makes drift look smaller than it is. The over-count 0295 found was specific. About 90 minutes of ear
training were counted toward an improvising skill, because the loop *could* be soloed over.

Built, and run over a fresh copy of the same store (3 goals, 2,351 minutes, August to November):

- The improvising goal fell from 494 minutes to **340**, 302 of them improvising over backing loops.
  The ear training is no longer counted toward it.
- **Free play** came to **1,514** minutes, 64% of the log. Most of it was three covers no goal
  names: 635, 331 and 160 minutes.
- The two song goals, both titled *Play a specific song*, read as *Play Self Control* and *Play Canon
  in D Major*. Neither got any time in November.
- One of those covers is a **different song in the library** from the one a goal names. The goal
  points at the original, and the October practice went on a cover. By goal shows this. By song
  could not, because it doesn't know what the goals name.

## Decisions

### D1 — A goal made from the song template is named for its song

A goal still called *Play a specific song* with *Sunday Morning* as its target reads **Play Sunday
Morning**, everywhere a goal is named: the list, the planner, the chips on Today's session, the
echo on Progress, and this list. A name the player typed is shown as typed.

**Worked out when it is shown, not written into the store.** Goals saved before this read correctly
with no migration, and a goal whose song changes can't be left naming the old one. The editor's
name field follows the song too. Picking a song names the goal for it, and changing the song
renames it, until the player types a name of their own (`GoalTitle.following`).

Both tiers. They share the templates (ADR 0171 D5), so they share the placeholder.

### D2 — What counts toward a goal is what the planner would schedule for it, in the mode it would run it

A run records its unit and no goal, so the answer is worked back from the goal, and the walk is the
planner's own. `CandidateDeriver.resolve` gives what each of a goal's skills resolves to, and
`deriveCandidates` now deals from that same function. The log can't drift from what *Generate*
hands you.

Two rules keep the count conservative:

- **A loop counts in the mode the goal would run it in.** For each loop it claims, the planner says
  whether it is there to train, to hear or to solo over (ADR 0139 O2a). Only runs of that kind
  count. This is the rule that removes the over-count 0295 found.
- **A target song counts whole.** Everything *By song* counts under the song counts toward a goal
  that names it, whatever kind of work it was. Learning a song by ear is learning the song. The goal's
  row and the song's agree, which is pinned by a test.

`resolve` is read **without** the planner's one-claim-per-unit rule. A loop that states an ear
skill is claimed twice by that one skill, once to train and once by ear. The planner keeps only
one of the two claims, and the log needs both.

**A met goal still claims.** It derives nothing for the planner, but time spent on it before it was
met was time toward it.

### D3 — Every run lands in exactly one row

The rows add up to the period's total, as they do by kind and by song. A run two goals claim counts
under the **higher-ranked** one, and unmet goals outrank met ones. This is the ranking's meaning
already, *what matters more*, and it settles a shared run with no double count.

What no goal claims is **Free play**, captioned *Practice no goal names*. The player chose the name
over *No goal*. *No goal* names an absence, and the row is mostly deliberate work, such as learning
covers for an open mic. It just isn't work the goals describe.

### D4 — A goal with no time is listed, once there was practice it could have had

An unmet goal with nothing against it gets a row at **0 min**, after the timed rows, in rank order.
A goal that got nothing while you practised is the reading this grouping exists for. Leaving it out
would make the gap something to notice by its absence.

It is left out in two cases. **A met goal** with no time is finished, not waiting. **A goal set after
all the practice listed** had nothing to get. The second is the only use of `dateAdded`, and it is a
filter. Nothing on screen shows a date, so ADR 0171 D1 is untouched.

A row at nothing has nothing to open and is set like any other. It carries no colour, no mark and no
"behind" (ADR 0070).

### D5 — A goal opens onto kinds of work; Free play opens onto songs

Under a goal: *Ear training*, *Improvising*, *Loops*, *Play-alongs*, *Exercises*, as under a song
(ADR 0295 D2). That shows how the goal's time was spent, and makes the inference visible. A
skill goal that is mostly *Exercises* is counting drills by type, which the player can see.

Under **Free play**: the **songs** the time went on, and *Exercises*, *Metronome* and *Other
practice* for the rest. What Free play answers is *what did the time go on instead*. A song there
with an hour against it and no goal naming it is the obvious next goal.

### D6 — By goal is offered once a long-term goal exists

Before that, every minute would sit in one row. This is the rule ADR 0171 D10 applies to *Build
from*. A stored *By goal* with the last goal deleted draws as *By kind* until a goal exists again.

## Adjusting stays where it was

The review is read-only, like the rest of Progress (ADR 0171 D6, ADR 0117). Acting on it happens
where goals are edited: re-rank one so it pulls harder when a session is built, build from
*Long-term* only, retarget a song goal, mark one met, or add one for a song Free play shows.

"Making time for a goal" was asked about and needs nothing new. The ranking already controls how hard
a goal pulls, and a **time target per goal was not built**. A target is something to fall behind,
which ADR 0171 D7 and ADR 0070 rule out.

## What stays out

- **A share or percentage.** Minutes only. The rows add up to the total, so the proportion is
  visible without being stated.
- **Time by routine.** Still not built, as ADR 0241 and 0295 left it.
- **A performance or set list** (songs prepared for a date). Still **not decided here**. By goal is
  how the evidence will arrive: if Free play keeps filling with songs being prepared for a date,
  that is the case for one.

## Consequences

- `GoalTitle` (pure) and `displayTitle` on `Goal` and `LongTermGoal`. Every surface that names a goal
  reads it. `GoalTemplateLibrary.playSong` is the template's own constant.
- `CandidateDeriver.resolve(_:of:library:emphasis:)` is extracted from `deriveCandidates`, with no
  change in what the planner deals.
- `GoalAttribution` (pure) builds `PracticeBreakdown.GoalClaim`s. `PracticeBreakdown` gains
  `Grouping.goal`, `Names.goals`, `goalRows` and `songSourceID(of:names:)`, in
  `PracticeBreakdown+Goal.swift`. Pure and unit-tested (`GoalTitleTests`, `GoalAttributionTests`,
  `PracticeBreakdownGoalTests`).
- The manual's *What you played* section and reference entry describe the third segment, and the
  goal pages say how a song goal is named. **The Practice log figures are owed in the reshoot**,
  as 0295 already left them.
