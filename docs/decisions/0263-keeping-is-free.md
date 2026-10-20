# ADR 0263 — Keeping is free; practising is the plan

- **Status:** Accepted. Decided with Tomisin, 2026-10-20, while designing a References library for the
  Toolkit and a way to share into Red Moon from other apps. That feature has its own ADR, and it too
  lands before 1.4. This one moves the free line before anything is sold. Built on
  `pocket-376-keeping-is-free`.
- **Date:** 2026-10-20
- **Amends:** ADR 0256 — **D2**: the Journal, the Practice log and the Toolkit's My chords, My
  progressions and My tabs move to the free side, and the rule becomes *a feature that plays or keeps
  is free; a feature that practises is the plan* (D1, D2 here). **D3**: Home's Journal tile, the
  Toolkit's rows and the tile beside Toolkit no longer draw a lock, and the wall's sentence changes
  (D4). **D9**: the free-path UI test opens the Journal and My chords instead of meeting the wall
  there (D5). Everything else in 0256 stands, D8's promise above all.
- **Relates to:** 0208 (Home's *This week* strip, the Practice log's only door) · 0142 (a Journal
  caption opens its unit) · 0224 (a take that belongs to no unit) · 0235 D6 (the tile beside Toolkit) ·
  0167 (references, which the next ADR gives a library) · 0070 (never grades, at every tier)
- **Schema:** none. Access is still read live from StoreKit (0256 D9).

## Context

ADR 0256 drew the free line on 2026-10-17: playing and keeping a song is free, and practising and
journaling are the plan. The Toolkit was split down the middle. Its tools that remember nothing (the
Tuner, the Glossary, Help) were free, and the three things you make in it were the plan's.

On 2026-10-20, designing a References library for the Toolkit, Tomisin decided the library would be
free and moved the line with it:

> The journal and everything in the toolkit will be free including the Tuner. We just need to make
> sure that there's a paywall around paid for features e.g. links from the journal to an exercise.

On the Practice log, which 0256 listed with the Practice hub: *"Practice log would be free, we'll
make this an exception."*

**Why now.** 0256 D8: whatever is free at launch stays free for good, and a free door can never close
again. Widening the line after launch is allowed, but nobody has bought Red Moon yet, so moving it
now means the launch line is the one Tomisin intends.

Checking the code before writing this turned up two facts that change how big the move is:

1. **The Practice log's door was already in front of free players.** The Metronome is free, and it
   writes practice runs (`MetronomeRunLog`). Since ADR 0208, Home's *This week* strip is the log's
   only door, and it appears once there is a run. So a free player who used the Metronome got a
   strip with their minutes in it, and tapping it opened the wall.
2. **Every Journal caption already opens a paid screen.** `JournalOwnerDestinationView` sends an
   exercise to its run screen, a loop to Practice now, Train your ear or Improvise, a snag's line to
   Name the notes, and a session to its routine's editor. Each of those screens carries its own gate
   (0256 D3). So "links from the journal to an exercise" are behind the plan already, and stay there
   with no new gate.

## Decisions

### D1 — The new free line

**Free, for good**, added to 0256 D2's list:

- **the Journal:** the tab, its **＋** menu (*Write a note*, and *Record a take*, which records a take
  that belongs to no unit, 0224), a loop's *Journal* (`JournalSheet`) and a snag's line
  (`SnagLineSheet`);
- **the Practice log**, behind Home's *This week* strip;
- **the whole Toolkit:** My chords, My progressions and My tabs join the Tuner, the Glossary and
  Help & FAQs.

**The plan keeps** the rest of 0256 D2's list: the Practice hub, Today's session, a loop's four
launches, drills and routines from anywhere, and receiving a shared routine or drill.

### D2 — The rule

*A feature that plays or keeps is free. A feature that practises is the plan.*

"Keeps" covers the songs, loops and markers 0256 already freed. It also covers what you wrote about
them, what you recorded, what you made in the Toolkit, and (with the next ADR) where you learned it.
"Practises" means a run screen, the planner, or a drill or routine.

**The Practice log is an exception**, Tomisin's word, and it is recorded as one. It counts practising,
so the rule alone would put it with the plan. It is free because it is the player's own record, and
because its door was already in front of free players (Context, fact 1). It is not a precedent for
freeing a practice feature.

### D3 — A link from a free screen into a paid one opens the wall

Journal captions keep their destinations. A free player who taps one reads the wall, titled with the
door they tapped (*Exercise*, *Practice now*, *Train your ear*, *Improvise* or *Routine*), which is
0256 D3 working as designed. A caption stays a link. It draws no lock of its own, because 0256 D3
locks only Home's tiles and the Toolkit's rows, and deeper doors explain themselves on the wall.

An exercise's own Journal sheet is reached only from the drill's run screen, so it stays behind that
screen's gate. The sheet itself carries none.

**Not decided here:** whether a loop's caption should open the song at that loop for a free player,
instead of the wall. The song screen is free and the loop lives there, so it may be the better
destination. It changes 0142's routing, which needs its own call.

### D4 — No lock where nothing is locked

- **Home:** the Journal tile, and the tile beside Toolkit, draw no lock. Practice, the Today's
  session card and Jump back in still do.
- **Toolkit:** no row draws a lock. `ToolkitSection.planDoor` is deleted, since no row has a door.
- **`PlanDoor`** loses `journal`, `practiceLog`, `myChords`, `myProgressions` and `myTabs`, so no
  screen can be gated on one by accident.
- **The wall's sentence** (0256 D3, *"one sentence on what is free and what the plan adds"*):
  - for a first-timer: *"Your songs, loops, Journal and Toolkit are free for good. The plan is for
    practising: drills, routines, Today's session and the loop trainer."*
  - for a returning player: *"Your drills and routines are just as you left them. They open again
    with the plan."*
- **Settings ▸ Your plan** (free) and **Help & FAQs** (*What's free, and what is the plan for?* and
  *What happens if I stop paying?*) say the same.

### D5 — What pins the line

- **`PlanAccessTests` pins the gated side as an exact list**, `PlanDoor.allCases`. Until now it was
  pinned against the Toolkit, the one list that held both sides. The Toolkit no longer does. Adding a
  door is now a deliberate edit to that test, and so is removing one, which D8 makes permanent.
- A second test says **no Toolkit row is titled as a door**, so a Toolkit gate can't come back
  through a new case.
- **`PlanWallUITests`**, the one UI test without the plan, now opens the Journal and My chords and
  finds no wall. Practice still draws its lock and shows the wall.

## Consequences

- **The free app is bigger:** the Song library and player with loops and markers, the Metronome, the
  Journal with its notes and takes, the Practice log, and the whole Toolkit. The plan is the practising.
- **It is permanent** (0256 D8). None of this can move back behind the plan.
- **A lapsed player keeps more open.** 0256 D4 is unchanged, and its free set is now this one, so the
  Journal and the Toolkit stay open after a lapse, not only the songs.
- **The References library is free under D2.** Its ADR follows on its own branch.
- **Owed outside the repo:** the site's plan copy (`uk-site`) and the App Store description, wherever
  they list what is free. The listing copy is release work (0256 Consequences, step 5) and isn't
  written yet.
- **Figures:** the manual states no free line (0256 Consequences) and no shot is taken without the
  plan, so no figure goes stale. The design brief's lock list loses the Toolkit row.

## Alternatives rejected

- **Freeing the Journal and keeping the Practice log paid.** The strip on Home already shows a free
  player their Metronome minutes, and its only door would have stayed a wall.
- **A lock on each Journal caption.** That is a gate at the door, the shape 0256 D3 rejected. The
  screen behind the caption already says what it needs.
