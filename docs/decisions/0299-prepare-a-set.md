# ADR 0299 — Prepare a set

- **Status:** Accepted — built (2026-11-15, `pocket-429-prepare-a-set`), for 1.4.1. Proposed and
  accepted the same day. The owner took the recommendation on all three questions that were open
  (D3, D6), and they are recorded below as decided.
- **Date:** 2026-11-15
- **Amends:** ADR 0171 — **D2**'s fields gain `setSongIDs`, and **D5**'s shared templates gain one the
  short-term tier doesn't offer (D2 here). The rest of 0171 stands: no date, ranking, the echo.
- **Amends:** ADR 0298 — **D2**'s target-song rule is applied to each song in a set, and **D5**'s *a goal
  opens onto kinds of work* has an exception: a set opens onto its songs (D5 here). The rest of 0298
  stands.
- **Relates to:** 0295 and 0298 (the store check, and By goal), 0015 (the deriver's repertoire path),
  0070 (never grades), 0189 (what a schema change must carry)

## Context

The 2026-11-13 store check found October and November spent on open-mic covers no goal named. ADR 0298's
By goal now shows that every week, as Free play. The player wants to say *I'm preparing a set* as a
goal. The objection was that it feels neither long-term nor short-term.

That is a problem with the label, not with how the tiers are defined. ADR 0171 split the tiers by
**scope**, not length. Short-term means *this session*. Long-term means *a standing outcome until I say
it's done*. A set fits the second, but the word "Long-term" says duration. In periodisation terms, the
app has microcycles (sessions) and a macrocycle (the long list), and a set is a mesocycle: a block aimed
at an event. In GTD terms, it is a project made of song projects.

Four shapes were weighed on 2026-11-15:

- **A. A long-term goal that holds several songs** (chosen).
- **B. A bundle of song goals.** It adds two concepts, the ten-goal cap fills fast, and after the gig
  you mark several goals met.
- **C. A routine as the set.** A routine is *how* you practise, not what you're working toward. It
  doesn't steer Generate or rank against goals.
- **D. A third tier between session and long-term.** It is the most faithful to the mesocycle idea, but
  it makes a third thing called "goal" (0171 D9 already worked to keep two distinct), and the evidence
  is one player.

The owner's answers settled the rest. **Not time-bound**: that removes the one objection to making it
a goal (0171 D1: no dates). **Running order doesn't matter** while preparing. **Done or reused depends
on the gig.**

## Decisions

### D1 — A set is a long-term goal with several songs, started from *Prepare a set*

A new starting point, **Prepare a set** (*Get a handful of songs ready to play for people.*), with the
song skills `rep.learn-song` and `rep.master-song`. Its editor asks for **songs**, more than one, where
*Play a specific song* asks for one. Everything else is any long-term goal's: rank, skills, *Mark as
met*, delete.

**The name is the player's.** The placeholder stays *Prepare a set* until they type one, such as
*Symposium set*. A date can go in the name as words. The app reads nothing from it, so 0171 D1 holds.
The goal-name rule doesn't apply, since there is no one song to name a set for. The list row's second
line reads *N songs*.

### D2 — Long-term only

The short-term tier doesn't offer *Prepare a set*. Templates are shared by both tiers (0171 D5), but a
set is a standing outcome by definition. "Work on my set today" is already *Build from ▸ Long-term*.
This also keeps the short-term `Goal` model unchanged.

### D3 — The songs are stored as a list of song ids, unordered

`LongTermGoal` gains `setSongIDs: [String] = []` (`Song.sourceID`s), an additive attribute with a
declaration default, the same shape as `skillIDs`.

- **Not a to-many relationship.** A relationship would need an inverse on `Song`, so it would change
  two models, and to-many relationships are where this store's device-only traps live
  (`docs/swiftdata-gotchas.md`). A deleted song's id simply resolves to nothing and drops out when read.
- **Unordered.** There is no running order (owner, 2026-11-15). It reads in title order.
- **Archive:** `LongTermGoalRecord` gains `setSongIDs: [String]?`. It is optional, so an archive made
  before this decodes (a synthesised default does not survive a missing key). An older build ignores
  the key.
- **The gate (0189):** it is the first schema change after 1.4. Before merging, a store upgrade check on
  the simulator: install the current release, create goals and practice, upgrade in place, and prove the
  same rows survive by their identity, not by counts.

**Decided: a goal is known to be a set by its songs.** A goal with a non-empty `setSongIDs` is a set,
and *Prepare a set* is only a starting point that opens the editor in that mode. So Save waits for at
least one song: a set saved with none would not be one. **Rejected:** a new skill, `rep.prepare-set`,
that requires a set the way the song skills require a target song. That would be more consistent with
how 0171 gates the target song, but it adds a taxonomy entry whose only job is to be a flag.

### D4 — The planner rotates through the set

Each song in the set resolves the way a target song does (0015 Path B): its loops, then a play-through.
Because all of them come from one goal, `roundRobin` deals one item from the set per pass, and dueness
chooses which song. A song you haven't touched comes forward, and the set never takes over a session.

### D5 — By goal counts each song whole and opens onto the songs

0298 D2's target-song rule, applied to each song in the set: every run that By song counts under one of
its songs counts toward the set. The set's row opens onto its **songs**, not kinds of work, because that
is the question it answers: *which songs have I left?* A song in the set with no time is listed at 0 min,
by the reasoning of 0298 D4.

### D6 — Done or reused needs no new control

A one-off gig: *Mark as met*. A set kept for the next one: leave it open and change its songs. A met set
reopens by turning *Mark as met* off. These all exist already.

**Decided: a song goal that is also in a set keeps both.** By goal already gives a shared run to the
higher-ranked goal (0298 D3), and the ranking is the player's statement of which matters more.
**Rejected:** offering to fold the song goal into the set, which is more tidiness than this is worth.

**Decided: the first-run intake leaves *Prepare a set* out.** It leaves *Play a specific song* out
because it needs a song (ADR 0246), and a set needs several. The intake offers from the shared ten,
which don't include it.

## What stays out

- **Running order and a run-through.** No order (D3). Playing the set top to bottom would be a routine,
  and "make a routine from this set" can come later if it's asked for.
- **A date, a countdown, "days until".** 0171 D1 and 0070.
- **Sharing a set with bandmates.** Backlog Note 11, its own ADR.
- **Renaming "Long-term goals".** The label is what makes a set feel wrong there (Context), but 0171 D9
  chose it deliberately, and renaming it would touch the manual and every figure of the tier. Not
  proposed.

## Consequences

- `LongTermGoal.setSongIDs`, `LongTermGoalRecord.setSongIDs`, and the builder and restore writer carry
  it. The store upgrade check (D3) runs before merging.
- `GoalTemplateLibrary` gains `prepareSet`, offered by the long-term editor only. The editor gains a
  multi-song picker section.
- `PlannerGoal` carries the set's song ids (`setSongUIDs`, read through `repertoireSongUIDs`), and
  `CandidateDeriver.repertoireCandidates` resolves each one. `GoalReach` counts a set's songs in the
  reach line (*4 songs*). `GoalAttribution` passes them to `GoalClaim` (`songSourceIDs`, `isSet`), and
  `PracticeBreakdown.goalRows` opens a set onto its songs, the ones at nothing included. In *By song*,
  a set's songs carry the set's name, as a target song carries its goal's.
- `SearchableMultiPickerList` (pushed, searchable, a tap toggles and the list stays) and
  `GoalSetSongsSection`. `longTermGoalLine` replaces the two copies of the goal row's second line, which
  for a set counts the songs still in the library.
- Unit-tested in `PrepareSetTests`. The store upgrade check is recorded in the PR.
- Manual: *Long-term goals* in `sessions.md`, the reference entry, and *What you played*.
