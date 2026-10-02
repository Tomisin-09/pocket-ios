# ADR 0243 — The planner's sessions are temporary until you save them

- **Status:** Accepted — decided with Tomisin, 2026-10-02. Not yet built
  (`pocket-355-a-session-you-keep`).
- **Date:** 2026-10-02
- **Amends:** ADR 0072 — its *First surface* has the Quick session materialise "a real `Routine`" and
  hand it to the player. It still does, but that routine is now **temporary** (D2) and reaches
  Routines only if it is saved (D4). The same now holds for Today's session, which came after 0072
  and never had an ADR of its own. 0072's mastery rating and due-score ranking are untouched.
- **Relates to:** 0111, 0118 and 0232 (the three song-side generators, which go on keeping what they
  make — D1) · 0117 and 0143 (the practice log and the session note name a routine by a loose id,
  which is what makes D3 and D6 safe) · 0173 (a routine's practised count, which a session saved
  afterwards keeps) · 0193 (Jump back in, which shows a temporary session — D2) · 0178, 0119 and 0210
  (the Routines library's search and sort, favourites and folders, which leave it out — D2) · 0186
  and 0167 (reminders and references, which wait until it is saved — D5) · 0181 (the archive — D8) ·
  0189 (an additive column, so none of its criteria for a destructive change apply — D7) · 0126
  (nothing on a navigation bar varies in width — D4) · 0198 (the question Session complete already
  asks — D4)
- **Schema:** one additive column, `Routine.isTemporary: Bool = false` (D7).

## Context

Tomisin, 2026-10-02, before the reshoot: *"if a user uses the 'Start Today's Session' everyday, the
routines would build up in the routines sheet... what if we made these sessions temporary, only made
permanent if the user decides before or after the session?"*

A generated session opens on a review screen, and nothing is written until you act on it. **Save**
puts it in Routines without playing it. So does **Start**: `RoutineDetailView.startPlaying()` commits
it first, on the stated ground that *"running must write real practice history"*, and the manual says
the same — Start "keeps it, because a session you actually practise is real practice history." So a
player who does what Home asks of them, and taps **Start today's session** every day, gets a routine
called *2 Oct Quick Session* every day, and the Routines library turns into a diary.

That ground was true when the planner shipped in July. It has not been true since ADR 0117, which
gave every run a row in the practice log naming its routine by a **loose copy** of its `uid` rather
than a relationship, so that *"deleting a routine must not erase the practice done in it."* ADR 0143
did the same for the session note, and snapshots the routine's name beside it. Everything a sitting
leaves behind — its minutes and days, *What you played*, Home's *This week* strip, its note, its takes
(which belong to loops and exercises) — outlives the routine. The routine kept on Start records
nothing they don't. It is a second copy of the plan, not the history.

And the planner's plan is a function of **today**: dueness read from the log, the goals set for this
session, what was practised yesterday. Tomorrow's is meant to differ. Yesterday's is stale the moment
tomorrow's is generated.

A song's routine is not like that. The per-song routine (0111), a Collection's session (0118) and the
song map's *Put it together* (0232) are built from songs, and the same songs give the same routine
tomorrow. They are recipes, and keeping them is right.

**One thing the record has wrong.** 0111 and 0118 call the review screen "Save-only" — *"persists only
on Save."* It never was: Start has committed every generated session, song-side included, since the
planner's first slice. D1 states the song side's behaviour as it actually is, and keeps it.

## Decisions

### D1 — Today's session and Quick session are temporary; a song's are kept

| Path | Built by | Start |
|---|---|---|
| **Today's session** (Home, Practice) | `PracticePlanner` | runs it as a **temporary** session |
| **Quick session** (the Routines library's options) | `PracticePlanner` | runs it as a **temporary** session |
| A song's routine (song details) | `SongRoutineBuilder` | runs it and keeps it — unchanged |
| A Collection's session | `CollectionSessionBuilder` | runs it and keeps it — unchanged |
| *Put it together* (song map) | `SongMapWriter` | runs it and keeps it — unchanged |

The line falls between builders: the planner's two are temporary, the three built from songs are kept.
An away-from-your-instrument *Listening Session* is a Today's session, so it is temporary too.

On all five, backing out of the review screen still writes nothing, and **Save** on the review screen
still keeps.

### D2 — Temporary means in the store, marked, and out of the library

A temporary session has to be in the store while it runs: the player resolves it from the main
context, and the run screens stamp `lastPracticed` and write runs and takes against the real store.
So Start inserts it, as now, with `isTemporary = true`.

Where it shows comes down to one question — is this surface about **what you practised**, or about
**what you keep**:

| Shows a temporary session | Leaves it out |
|---|---|
| Home's **Jump back in** (Tomisin's call) | The Routines library: list, search, sort, favourites, folders |
| Home's **Recent routines** rail | The routine count on the Practice screen |
| A session note's link in the Journal | **Add to routine** |
| | The archive (D8) |
| | Name de-duplication (D4) |

The rail follows Jump back in because two routine surfaces on one screen must not disagree about
whether you practised something — the same reason the card and `RecentRoutineCard` already count a
routine's blocks one way.

Leaving it out is done in memory on the fetched routines, the way the library's favourites filter
already works, not in a `#Predicate`.

### D3 — At most one temporary session

**Starting a planner session deletes every other temporary session**, in the same save that inserts
the new one. So there is never more than one, by construction: no timer, no sweep at launch, no rule
the player can't see. "Every other" rather than "the previous one", so that a stray left behind by a
crash between the two writes is cleared by the next Start.

Until then the last one stays — on Jump back in, in the rail, and runnable again from either. Running
it again is another run of the same session, so it deletes nothing. A session generated and then
backed out of was never written, so it replaces nothing either.

Deleting a temporary session cascades to its blocks and nothing else. Its runs stay in the log. Its
session note keeps its words and the routine name it snapshotted, and loses only its link — the path
ADR 0143 already takes for any deleted routine (`JournalOwnerRoute` resolves to nothing). Its takes
belong to their loops and exercises.

### D4 — Save, before or after

- **Before:** the review screen's **Save**, unchanged.
- **Straight after:** the Session complete screen gains **Save as a routine**, for a temporary session
  only, between the session note and **Done**. One tap saves it under its current name, and the
  button gives way to a line saying it is in Routines. A button, never a prompt: the screen already
  asks one question (0198), and a "Keep this session?" dialog at the end of every sitting is the kind
  of interruption 0186 refused.
- **Any time later:** a temporary session's own screen, reached from Jump back in or the rail, carries
  **Save** in the toolbar where a saved routine carries **Edit**. The same width (0126).

The word is **Save** everywhere, because the review screen already taught it for exactly this act:
putting a generated session in Routines. *Keep* was considered, being the exact opposite of
*temporary*, and rejected — it would rename a button on five paths, three of which are not changing,
to describe the two that are.

**Names are unique among saved routines.** A temporary session is left out of the de-duplication, so
a second session generated on the same day is not numbered against the one it is about to replace.
Saving a temporary session de-duplicates its name at that moment.

### D5 — A temporary session is read-only until it is saved

Its screen shows its blocks, its length, its history and **Start**. It takes no edit, no reminder
(0186), no reference (0167), no folder (0210) and no share (0236) until it is saved. Each of those is
something a player would put into it, and the next Start would delete it along with the session.
**Save** and then **Edit** is one tap more than editing in place, and it never loses work.

Its history **is** shown, unlike a provisional session's: it has been run, so "practised once, today"
is true, and it is what the saved routine will carry (D6).

### D6 — Saving afterwards loses nothing

Saving flips `isTemporary` and changes nothing else. The `uid` is the one every run and the session
note were written with, so the saved routine arrives with ADR 0173's practised count and last-practised
date already right, and the note's link already pointing at it.

### D7 — `Routine.isTemporary: Bool = false`

An additive `Bool` with a declaration default — the shape `isFavorite` (0119) already has on `Routine`.
Lightweight migration fills every existing routine with `false`, meaning saved, which is what D9 needs.
No date: nothing reads when a session became temporary, and D3 needs no clock.

Additive, so ADR 0189's criteria for a destructive change do not apply. The store-upgrade check on a
device holding existing routines is still owed (`docs/swiftdata-gotchas.md`).

### D8 — The archive leaves a temporary session out

A backup holds what you saved. The session's runs and note are in it regardless, carrying their loose
ids, so all that is missing is the plan. Writing the session in would mean adding the flag to the
archive format, or else it would restore as a saved routine. Leaving it out needs no format change, and
`schemaVersion` does not move (0181).

### D9 — The routines already there stay

Every dated session in Routines today was kept under the old rule, and nothing tells one the player
wanted from one they didn't. Deleting them on upgrade would delete routines the player chose to have.
They stay as they are, deletable one at a time as now.

## What stays out

- **Resuming where you stopped.** Running a temporary session again starts at its first block, as every
  routine does.
- **Reopening today's session from Start today's session.** Generating always builds a fresh one.
  Whether that card should offer the session already made today is not decided here.
- **Clearing the existing pile in one go** (D9).
- **Naming at the finish.** *Save as a routine* keeps the dated name; **Edit** renames it afterwards.
- **The song side** (D1).

## Alternatives considered

- **Delete it at Done.** The smallest build. But the session is gone the moment the finish screen
  closes — after an interrupted sitting, or an "I'll save that one tomorrow" — and Jump back in could
  never show it, which Tomisin asked for.
- **Keep everything and tidy what's old**, as a collapsed *Past sessions* section or an age limit. The
  pile still grows, and an age limit deletes routines the player kept, under a rule they can't see.
- **"It lasts for the day."** The same objection, smaller: a clock decides, out of sight. D3's rule is
  visible — the next session replaces this one.
- **Run it without inserting it.** The run screens write to the real store and stamp the routine. A
  routine that isn't there can't be stamped, can't be resolved by the player, and can't be on Jump back
  in.
- **Temporary on all five paths.** Rejected by Tomisin: a song's routine is the same tomorrow, so it is
  worth keeping (D1).
- **A prompt at the finish.** See D4.

## Consequences

- **`existsInStore` stops answering one question.** It means *in the store*, and the 11
  `RoutineDetailView` files that read it treat it as *saved*. There are now three states — provisional
  (not in the store), temporary (in it, not saved), saved — and each reader has to say which it means
  (D5). This is most of the build, and where a gap goes unnoticed: a reader left on `existsInStore`
  lets a temporary session take a reminder, and nothing fails.
- **The screen under the player goes stale.** `RoutineDetailView` holds its own sandbox copy, and
  *Save as a routine* writes the main context. The detail screen has to re-read the flag when the
  player closes, or it goes on offering **Save**.
- **The provisional initialiser learns which kind it is making.** The two planner callers (`PlannerView`,
  `RoutineLibraryView`'s Quick session) ask for a temporary session; the three song-side callers keep
  today's behaviour. The doc comments that say "nothing persists until the user Saves or Starts" are
  rewritten.
- **Surfaces that leave it out** (D2): `RoutineLibraryView` and its folder scope, `PracticeView`'s
  count, `AddToRoutineSheet`, `ArchiveSource+Store`, and the name de-duplication in `PlannerView`,
  `RoutineLibraryView` and `commitProvisional`. **Unchanged**, because they already read every routine:
  `HomeView+Resume`, the rail, and `JournalTabView`. `PracticeReminderSection` needs nothing, since a
  temporary session can't have a reminder.
- **Tests.** Pure: which routines a surface shows; de-duplication ignoring temporaries; "every other"
  temporary on insert. UI: start a Quick session and finish it, and the library doesn't list it; *Save
  as a routine*, and it does; a second session replaces the first on Jump back in. Run the shoot class
  after touching the finish screen's body — a green `PocketAll` has missed a crash in a routine screen
  before.
- **The manual.** `sessions.md` ("Start plays it — and keeps it") changes for Today's and Quick
  sessions; `routines.md` gains *Save as a routine*; `reference/home-and-library.md` says Jump back in
  and the rail can carry an unsaved session.
- **Figures.** `routines/session-complete` shows the new button only if the shoot finishes a planner
  session rather than a seeded routine — decide which when shooting. `sessions/review` keeps its
  toolbar, but its caption's claim about Start changes. Both join the owed reshoot.
- **CHANGELOG, PROJECT.md and `docs/architecture.md`** gain the rule and the field when it is built.
