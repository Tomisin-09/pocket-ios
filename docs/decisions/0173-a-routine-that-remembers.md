# ADR 0173 — a routine that remembers

- **Status:** Accepted
- **Date:** 2026-08-19 (`pocket-277-a-routine-that-remembers`)
- **Relates to:** ADR 0070 (never grades the player), ADR 0117 (the practice log and the
  Progress screen — this reads the log that ADR created), ADR 0129 (the session block model,
  and `RoutineBudget`'s estimate), ADR 0137 (dueness comes from the log), ADR 0167 (the
  references section this sits beside on the same screen)
- **Not** a schema change. `PracticeRun.routineUID` and `SessionRecord.routineUID` already
  exist and are already written; this ADR is a **read** of data the store has been holding
  since ADR 0117 shipped.

## Context

**`PracticeRun.routineUID` is written on every run and read back nowhere.**
`RoutinePlayerView` threads the routine's `uid` into `RoutineRunContext`, and all six run
surfaces pass it to `PracticeLogWriter`. Then nothing ever asks for it. A routine has no run
count, no last-run summary, no "you've run this eleven times" — the one object in the app
that should have a history is the only one without one, while an *exercise* carries a
trajectory, a run count and a last-practised date on its detail sheet.

`docs/backlog.md` (Routines, item 1) names this the highest-value gap in the routine surface
and the cheapest to close, precisely because the data is already on disk.

**Compounding it, a saved routine could not say how long it was.** `lengthSection` gated on
`!existsInStore` — the estimate showed on a provisional generated session and vanished the
moment the routine was kept. So the single most useful fact for choosing between routines was
hidden on exactly the routines you would be choosing between (backlog Routines, item 3).

## Decision

**The routine detail screen carries one section holding three facts: how long it is, when it
was last practised, and how many times — and the library row carries the same history on a
second line under its block count.**

Not the Home card.

> Originally decided as detail-screen only, with the library row listed below as a rejected
> alternative. Reversed on device the same day: with the section in place, the library was
> the screen you actually stand on when choosing, and a tally the list refuses to show is a
> fact you have to open four routines to compare. See D6.

### D1 — sittings, not rows. The load-bearing one.

The log holds **one row per completed unit-run**, not per practice sit (`docs/architecture.md`
states this outright, and it is the schema decision ADR 0117 made deliberately so a per-drill
tempo trajectory stays derivable). A six-block routine run once on a Tuesday morning writes
six rows.

So the obvious implementation — mirror `TempoTrajectory.runCount(for unitUID:)` onto
`routineUID` — reports that Tuesday as **"Practised 6 times"**. That is not a smaller number
than the truth; it is a different fact, and it is the one a reader would most confidently
misread.

`PracticeLog.routineHistory` groups the routine's rows through `PracticeLog.sittings`, the
same recovery every other session-level statistic already performs. The routine screen and the
Progress screen therefore cannot disagree about what one sit is.

Two consequences are inherited from `sittingGap`, both accepted rather than worked around: a
routine run twice inside half an hour counts **once**, and one abandoned and picked up after a
long break counts **twice**. Neither is worth a second definition of a session living beside
the first.

### D2 — the log, not `Routine.lastPracticed`.

`Routine.lastPracticed` already exists and is already stamped — but by
`RoutinePlayerView.markPracticed()`, wired to **`.onAppear`**. It records the player *opening*
the session. The log records runs that *finish* (a hand-stopped run writes no row at all).

Reading the stamp beside a count derived from the log would let a routine say *"last practised
today · practised 3 times"* after a session that was opened and abandoned — two numbers on one
row, sourced from two different definitions of practising, disagreeing in public. Both facts
come from the log.

`Routine.lastPracticed` stays exactly where it is and keeps its meaning. Home's recent-routines
rail keeps reading it, and "what you last opened" is the right thing for a resume rail.

### D3 — one section, four states.

The old length gate (`!existsInStore`) and a history gate (`existsInStore`) are near-
complements. Two sections would have meant the screen showed one or the other and never both.
One section:

| state | shows |
|---|---|
| provisional, something playable | estimated length + the soft budget hint (unchanged) |
| provisional, nothing playable | nothing |
| saved, something playable | estimated length · last practised · how many times |
| saved, nothing playable | last practised · how many times |

**A provisional routine shows no history on purpose.** It has a `uid`, so the read would
succeed and return zero — but zero reports on something the player has not yet decided to
keep, and "Not yet" against a routine that does not exist reads as a reproach for not having
done a thing that was never offered.

**A saved routine with nothing playable shows no length**, because an all-rest or
all-orphaned routine estimates at 0 min and "~0 min" is a worse answer than no row.

### D4 — facts, never verdicts.

design-brief §3.5 names *"a tempo, a run count and a date"* as facts and *"on track",
"behind", "your best week"* as verdicts, so this feature is pre-blessed with its framing
fixed. What was refused, explicitly:

- **No streak**, and no consistency score.
- **No denominator.** "4 of 7" states a target, and a target is habit-pressure under another
  name (`PracticeLog` already says this about `daysActive`).
- **No week-over-week delta.** ADR 0117 held it back as the first element that can read as a
  verdict on a bad week.
- **No second-person past tense about a gap.** Never *"you haven't practised since Tuesday"*.
  A never-run routine says **"Not yet"** and stops there — it does not add a second sentence
  about the thing not done.

### D5 — the seed had to grow a routine history.

`PracticeHistorySeed` wrote eighty-odd rows and set `routineUID` on none of them, while
separately stamping `routine.lastPracticed`. Left alone, the new section would have rendered
empty in **every** figure of the routine detail screen in the user manual — a store the app
itself could not have produced, photographed as though it could.

Four days of the seeded history are now runs of the seeded Morning Routine. The offsets are
chosen rather than derived, against two constraints worth recording because a different four
would break them silently: each must be a day the seed does **not** split in two (or it reads
as two sittings and the count is wrong), and each must land on an `.exercise`-kind row (Morning
Routine is exercise-only by construction, so a loop or song row inside it would be a shape the
app would never write).

### D6 — the list carries the history on a second line, and stays silent about routines never run.

`RoutineLibraryView`'s row becomes two captions: **`4 blocks · 2 rests`** for what is in the
routine, and **`Practised 11 times · 3 days ago`** underneath for what it has come to. Two
lines rather than four facts on one, because they answer different questions and because a long
routine name at a large text size wraps a single four-part caption to three lines anyway.

Read through `PracticeLog.routineSessionCounts` and `routineLastPractised`, both one-pass maps
built **once per redraw** in `body` and handed down. Calling `routineHistory` from a row body
would rescan the whole log for every routine on screen — a library of thirty routines doing
thirty full scans per frame.

**Blocks, not units.** The row was the only surface calling them units while the detail screen's
own section header says `Blocks` and the model calls them blocks. *"Exercise blocks"* was tried
and rejected the same day: `kind.carriesUnit` is true for a loop and a song block too
(ADR 0129/0134), so a routine of two loops and a song would have read "3 exercise blocks".

**A routine with no runs shows nothing, where the detail screen says "Not yet".** The asymmetry
is deliberate. The detail screen has one routine's worth of room and a date to say it beside; a
list does not, and thirty rows each announcing a thing not done reads as a nag however neutral
each word is. Routines with no runs are therefore *absent* from both maps rather than present
with a zero and a placeholder date, so the omission is structural rather than a `> 0` check a
later caller could forget.

## Alternatives rejected

- **A stored `runCount` on `Routine`.** A denormalised counter that the six run surfaces would
  each have to remember to bump, drifting the first time one didn't — and a schema change, for
  a number the log can already answer.
- **Counting rows.** See D1. It is one line shorter and reports a different fact.
- **Showing an average session length, or minutes per routine.** Both are true and both invite
  comparison between routines, which is the doorway to a verdict.
- **A "not yet" on unrun rows in the library.** See D6 — the detail screen says it, the list
  does not.

## Consequences

- The routine is no longer the only object in the app without a history.
- A saved routine states its estimated length for the first time. `docs/backlog.md` Routines
  item 3 loses its compounding half; the search-and-sort half stays open, now with a length
  available to sort by.
- `PracticeLog` gains the first aggregate that legitimately keys off `routineUID`.
  `testRoutineAttributionDoesNotChangeAnyAggregate` still holds for every *shared* aggregate,
  and a companion test pins that this landed as an addition rather than a change of meaning.
- `RoutineDetailView` gains its first `@Query` — indirectly, in a child view that takes a
  `UUID` rather than the `Routine`, because the routine itself is faulted into a private child
  context and a cross-context reference would be corruption rather than a preference.
