# ADR 0302 — Train your ear is renamed Active listening

- **Status:** Accepted, built on `pocket-432-active-listening` for 1.4.1, and seen on a phone build on
  2026-11-15 (Consequences).
- **Date:** 2026-11-15
- **Amends:** ADR 0104 — **E1**: the mode on a loop is called *Active listening*, not *Train your ear*.
  **E4**: the 👂 Journal chip reads *Listen*, not *Ear*; the stored kind stays `ear`. **S2.4**: the
  routine picker's bucket is *Active listening*, not *Ear training*. The rest of 0104 stands, including
  the no-grading line and notes going to the Journal.
- **Relates to:** 0070 (never grades) · 0225 and 0227 (Count the notes and Name the notes, which live
  in the mode) · 0127 (the bucket's *All …* row, which follows the bucket's name) · 0241 (*What you
  played* groups runs by kind).
- **Schema:** none. Every name here is computed from a stored kind (`LoopRunMode.ear`, `EntryKind.ear`,
  `SessionRecord.Kind.earLoop`), and none of those raw values changes.

## Context

The loop mode 0104 called **Train your ear** holds hum-it-back, *Count the notes* and *Name the notes*.
Tomisin proposed renaming it **Active listening** on 2026-11-15, because it describes the mode better.

The mode plays the player's own loop and listens to nothing. It never grades (0070). *Train* promises
drills and scores, which the mode deliberately doesn't have. What the player does there is listen on
purpose: count what they hear, say which way it went, then name it. *Active listening* says that.

The words already exist in the app. *Active listening* is a skill under the **Train your ear** goal
(`ear.active-listening` in `SkillTaxonomy`, explained in `SkillExplainer`). The rename gives that skill
a place of the same name to be practised.

Tomisin accepted every recommendation below on 2026-11-15, and asked for the rename to follow the
direction step (0301).

## Decision

**D1 — The mode is *Active listening*, in sentence case.** Everywhere the mode is named:
- the button on a loop (*Active listening*; VoiceOver: *Active listening on this loop*);
- the screen's title;
- the paywall's title for it;
- the hints that send a player there (*Count it in Active listening*);
- the Home card's second line (*Slow Bend · Active listening*);
- the FAQ's list of what the plan covers.

**D2 — Routines and history use the same name.** Otherwise one mode would have two names. The
following all change from *Ear training* to *Active listening*:
- the routine picker's bucket, and its *All active listening* row;
- a routine block's title (*Active listening · Slow Bend*);
- a block's preview line;
- a run's kind in the Practice log, and its group in *What you played*.

**D3 — The compact label is *Listen*.** It replaces *Ear* where the full name doesn't fit:
- under a loop row's mode icon (`LoopRunMode.rowLabel`);
- on the Journal chip (`EntryKind.label`), which matches it on purpose.

The 👂 emoji and the `ear` symbol stay, because an ear is still what the mode uses.

**D4 — What keeps its name.**
- **The Goals template *Train your ear*.** A goal names what you want, and a mode names what you do.
  The goal's skills include *Active listening*, which is now also the place to practise it.
- **The exercise category *Ear Training*** (`ExerciseTemplate`, beside Scales and Chords). Those are
  drills, which is exactly the distinction this rename draws.
- **Marketing and App Store keywords keep *ear training*.** It's the term guitarists search for.
  Outside music, *active listening* usually means a communication skill.
- **Code names** (`EarTrainingSheet`, `.ear`, `.earLoop`, accessibility identifiers). They're never on
  screen, and renaming them would churn every file that touches the mode for no reader's benefit.

## Alternatives not taken

- **Keeping *Ear training* in routines and history** while the button says *Active listening*. That's
  two names for one mode.
- **Renaming the goal too.** A goal says what you want: you want to train your ear. *Active listening*
  is one way you get there.
- **Renaming the stored kinds.** It would mean a migration for a word nobody sees.

## Consequences

- The tests that pin the names (`EntryKindTests`, `AddToRoutineTests`, `SkillExplainerTests` and the
  `PracticeBreakdown…Tests`) now pin the new ones. The UI tests and the shoot harness find the screen
  by its new title.
- `docs/manual/` uses the new names, and `check-manual.py` C9 holds its backticked names to the app's.
  Figures that show the old name are stale until the reshoot.
- **Phone build, 2026-11-15.** Tomisin ran this branch on a phone and asked for it to go up as a pull
  request. On the simulator, the Edit-loop button and the screen title were checked in screenshots.
- The marketing site (`uk-site`) is a separate repo and isn't changed here. It keeps *ear training* as
  the search term (D4). Where it names the mode itself, it should say *Active listening*.
