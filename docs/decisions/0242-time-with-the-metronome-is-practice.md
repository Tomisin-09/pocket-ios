# ADR 0242 — Time with the metronome is practice

- **Status:** Accepted. Built on `pocket-354-metronome-counts-as-practice` (2026-10-02).
- **Date:** 2026-10-02
- **Amends:** ADR 0241 — its *What stays out* left metronome-only time **"not decided here"**, for
  want of an honest length. Decided: it counts (D1), and its length is the time the click sounded
  (D2). *What you played* gains a sixth kind, **Metronome** (D7). 0241's refusal to time parts of the
  app (its D3) stands — this is a run of practice, not a screen being open.
- **Amends:** ADR 0117 — *"a run stopped by hand logs nothing"* holds for every screen that has a
  course to complete. The Metronome screen has none, so stopping it is how a sitting ends, and that
  sitting is logged (D2). 0117's objection to *"however long the screen was open"* as a length is
  kept, and is what D2 answers.
- **Relates to:** 0043 (the session tracker this reads, which stays ephemeral on screen) · 0070
  (never grades — D5 has no cap for that reason) · 0104/0135 (`RampLessRunLog`, the precedent for
  logging on the screen rather than on what plays) · 0181 (the archive — D8) · 0239 (Red Moon counts
  nothing about how the app is used, which this does not change)
- **Schema:** none. `PracticeRun.kindRaw` is a `String`; `metronome` is a new value in it, not a new
  column.

## Context

Tomisin, 2026-10-02, the evening ADR 0241 merged: *"time with the metronome would count as
practice."*

It did not, and nobody had decided it shouldn't. The Metronome screen wrote nothing to the log, so a
player whose practice that day was twenty minutes of scales against the click had a blank day in the
Practice log, nothing on Home's *This week* strip, and no row in *What you played*. ADR 0241 left the
question open on purpose, for the reason ADR 0117 gave for every open-ended surface: the log records
runs with an honest length, and "however long the screen was open" is not one.

The metronome turns out to have one. `StandaloneMetronomeEngine` already keeps a session clock —
`elapsed`, the wall-clock time the click has sounded this sitting, banked across pause and resume and
untouched by a tempo change (ADR 0043's *tracker*). It is not how long the screen was open; it is how
long you played to it.

What was built was agreed in the session before this one, including the 30-second floor; one detail
changed on reading the code (D2: the start is taken from the transport, not the button).

## Decisions

### D1 — Time with the click on the Metronome screen counts

Minutes, days, the month grid, *What you played*, Home's *This week* strip and the all-time totals all
include it, because they all read the same log. It cannot be backfilled — what was never written is
not there to recover — so it counts from this release on.

### D2 — The length is the time the click sounded

**Start** is the moment the click starts: the transport leaving *stopped*. That is not always the
Start button — the automator's own **Start** starts the click when it is stopped — so the screen takes
it from the transport changing, not from a tap.

**The end** is either of the two ways a sitting here ends: **■** (stop and reset), or leaving the
screen. Both read `elapsed` *before* stopping the engine, because `stop()` zeroes it. Pausing is not
an end: a pause and a resume are one sitting, as the engine's own clock already counts them, and
the paused time is left out.

So a row's `startedAt` is when the click started and its `durationSeconds` is the time it sounded.
With a long pause in the middle the two do not add up to when it was stopped — the log's end time is
derived, never stored, and nothing reads it as a wall-clock fact. Like every run, it belongs to the day
it started.

`elapsed` is advanced by the same ~20 ms tick that schedules the clicks, so while the click is
sounding it is never more than a tick behind; while paused it is exact.

### D3 — The screen logs it, never the engine

`StandaloneMetronomeEngine` is shared. It also drives `ExerciseRunView` and `FreeformRunView`, which
already log their runs as `.exercise`, and `CommandTempoPreviewPlayer` and `StrumPatternPreviewPlayer`,
which are previews and not practice. A clock in the engine would log every exercise twice and every
preview once.

So the engine is **unchanged**. `MetronomeView` routes its two ends through one `endSession()`, and the
start/end bookkeeping is `MetronomeRunLog` — a pure value, no SwiftUI or SwiftData — so a start that a
pause would move, and a sitting ended twice (■, then leaving the screen), are unit-tested rather than
trusted. The same reasoning put `RampLessRunLog` on the view that knows what a run *was* rather than on
what plays it.

### D4 — Thirty seconds, for the metronome only

The Metronome screen is also where you go to hear what a tempo sounds like. A five-second listen must
not mark a day practised, and the log's one-second floor would let it. **Under 30 seconds of click
writes nothing.** Thirty is long enough that the click was played *with*, and short enough that no
real minute of practice is lost to it.

The floor is `PracticeLogWriter.minimumSeconds(for:)`, keyed by kind, so it holds for every metronome
row however one comes to be written. Every other kind keeps one second: a ramp or a loop that ran at
all was practice.

### D5 — A forgotten click counts, and there is no cap

The click plays on through the lock screen by design (ADR 0025), so a player can leave it running and
come back an hour later. That hour is logged. A cap would be the app deciding how long practice is
allowed to be, which is a judgement on the player's playing by another route (ADR 0070).

The log has no way to remove a row, so a forgotten click stays in it. That is accepted. If it turns
out to matter, the answer is a way to remove a run, not a ceiling on one.

### D6 — Its own kind, with no unit and no tempo

`PracticeRunKind.metronome`, labelled **Metronome**. Not `.other`, which already means *a row from a
newer build* and claims nothing about what it was.

**No tempo.** The automator moves the tempo under you, so a sitting has no one tempo it was practised
at; and the tempo surfaces (`TempoRecord`, `TempoTrajectory`) are per unit, and the click is not a unit
you own. **No unit, song or name** either — there is nothing to point at. `lastPracticedByUnit`
already skips rows without a unit, so the planner's recency is untouched.

### D7 — One row in *What you played*, with nothing to open

All of a period's metronome time is one group, **Metronome**, ranked by minutes like every other.
Every other group opens onto the exercises, loops or songs inside it; this one would open onto a single
row saying *Metronome* again. So it has no items, and the row is **not a button and has no chevron** —
a control that opens onto nothing is worse than no control. The chevron's width is kept, so its name
lines up with the rows around it.

### D8 — A kind this build doesn't know is read as *other*, in an archive too

The store already did this: `PracticeRun.kind` reads an unknown raw value as `.other`. The archive did
not. `PracticeRunKind`'s synthesised decoder threw on an unknown value, and the restore turns any
decode failure into **corrupt** — so one row of a newer kind would have made the whole backup
unreadable. `PracticeRunKind` now decodes an unknown value as `.other`, and the row's minutes count.
A restore writes that row back as `.other`, so its name is lost on that path; its time is not.

**It protects every build from this one on, and cannot protect a build already released.** An
installed copy of Red Moon from before this change, handed a backup made on this one that holds a
metronome row, will still call it corrupt. The path is narrow — restoring a *newer* backup into an
*older* app — and it is stated rather than fixed.

**Rejected: raising the archive's `schemaVersion`.** An older build would then say *made by a newer
version of Red Moon; update the app* instead of *corrupt*, which is the better sentence. But it would
say it about **every** backup from this build, with or without a metronome row, to improve the wording
on a path almost nobody takes. ADR 0181's rule stands: an additive change does not move the version.

## What stays out

- **A tempo on a metronome row** (D6).
- **Logging on going to the background.** The click plays on, so backgrounding ends nothing.
- **A sitting ended by closing the app from the app switcher.** No seam runs, so it is not logged.
  iOS *may* announce termination to an app playing in the background, and the screen could listen for
  that; it does not promise to, so it is not built here.
- **The tuner and the song library.** Still not practice, and still not timed (0241's D3).
- **Backfill.** Never recorded, so there is nothing to recover.

## Consequences

- **No `@Model` change**, so no migration and no store-upgrade check is owed. A build from before this
  one reading a store that holds a metronome row (a TestFlight build switched back, say) lists it as
  *From a newer version of Red Moon* under *Other practice*, and counts its minutes.
- **The archive** carries the new kind through `SessionRecord`'s synthesised encoder; `schemaVersion`
  does not move (D8). Tested by renaming a kind in a real archive to one no build has heard of: it
  decodes, both rows survive, and the unknown one's minutes count.
- **`MetronomeView.swift` was at 397 of SwiftLint's 400 lines**, so `TypableTempo` moved, unchanged, to
  its own file to make room for the two seams.
- **The manual** (`journal-and-practice-log.md`, `metronome.md`) said metronome time "isn't practice
  the log has recorded"; both now say it is, with the 30-second floor and what is left out.
- **The figures**: the shoot's history seed holds no metronome rows, so the Practice log figures in the
  owed reshoot show no **Metronome** group unless the seed gains one. Not done here.
