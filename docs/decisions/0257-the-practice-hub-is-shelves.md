# ADR 0257 — the Practice hub is shelves

- **Status:** Accepted — design signed off with Tomisin on 2026-10-17 (canvas board *Proposed B
  (chosen)*). Built on `pocket-368-practice-hub-shelves`.
- **Date:** 2026-10-17
- **Amends:** ADR 0046 §1 — the hub's two ways in (*Build today's session* and *Your units*) become
  four shelves, and the words *Your units* leave the screen (D1). ADR 0171 D6 — the long-term goals
  move from a row on Practice into the Today's session card, and editing one can start from its chip
  (D2). ADR 0197 — Home loses the Recent routines rail below its map (D4). ADR 0243 D2 and D4 — the
  rail's row leaves D2's table, and the way back to an unsaved session (D4, *any time later*) moves
  from the rail to a line on the Today's session card (D2, D4).
- **Relates to:** 0193 (Jump back in, which becomes Home's only "carry on" card) · 0186 (reminders:
  a routine card names the next one only when it can be delivered) · 0173 and 0178 (the routine
  row's history line and length, which the cards reuse) · 0068 and 0087 (the template order the
  category tiles follow) · 0070 (counts and tempos, never mastery) · 0090 (presentation by stable
  identity) · 0126 (nothing on a navigation bar varies in width) · 0165 (the manual quotes the app)
- **Schema:** none.

## Context

The Practice hub was a launcher of five rows with bare counts, under headings in the app's own
vocabulary: *Your units*, *Click-only command drills*, *Measured song loops*. It showed nothing of
what was in each library. The number of drills told you nothing about which, and the word *units*
is the model's name for an exercise or a loop, not one a player uses.

Routines were the worst served. Saved routines were one row among five, and the routines you
actually played lived on Home, in a rail below the map that Home's own ADR 0197 left below the fold.

Two designs were drawn on the canvas. *Proposed A* showed every section in full and ran to about two
screens. *Proposed B*, chosen, gives every section one shelf of a fixed height.

## Decisions

### D1 — Every section is one shelf

Top to bottom: **Today's session**, **Routines**, **Exercises**, **Loops**. Each shelf has a fixed
height. Anything beyond it is a sideways swipe, and **All N ›** in the shelf's header opens the
whole library. No section header reads *Your units* and no row carries an internal description.

The first screen holds Today's session, Routines and the start of Exercises.

### D2 — Today's session carries its goals and the unsaved session

The card opens the planner, as the row did, now subtitled *Choose how long you have*. Below that:

- **The long-term goals that shape it**, as chips, with *Edit goals*. A chip opens that goal's
  editor, and *Edit goals* opens the ranked list. With none, one dashed chip: *Add your first goal*.
  Met goals don't appear: they no longer shape a session. This amends ADR 0171 D6, which put the
  goals in a row beside the planner and all editing in the list. Editing a goal can now start from
  its chip; ranking stays in the list, which is still the only place that shows the order.
- **The unsaved temporary session** (ADR 0243 allows at most one), while there is one: its name over
  *Not saved yet · ~N min · when*. It opens the session's own screen, where **Save** already is, and
  leaves the card once the session is saved or replaced by the next Start. This is the way back
  ADR 0243 D4 promised ("I'll save that one tomorrow"), which the Home rail used to provide.

### D3 — Routines get their own shelf, straight under Today's session

Routines must not be overshadowed by the units they are built from, so they sit second.

- **Saved routines only** (ADR 0243 D2). Up to three cards, then **New routine**.
- **Order:** favourites, then the most recently practised, then the newest added. "Most recently
  practised" reads the practice log, the same date the card prints, so a card's place and its words
  cannot disagree.
- **▶ starts the player** (the library row's rule); the rest of the card opens the routine (the Home
  rail's rule). Two sibling controls, never a button inside a button.
- **Three lines:** name (+ ★); the block summary and `~N min`, the same estimate as the detail screen
  and the library; then *Next: Tuesday 18:00* when a reminder is on and can be delivered, otherwise
  the library's *Practised N times · when*, otherwise nothing. A reminder line follows ADR 0186's
  future tense: with notifications denied it is not shown at all, because it would be a promise the
  app can't keep.

### D4 — Home's Recent routines rail goes

The Routines shelf takes over its job. Home keeps **Jump back in** (ADR 0193) as its single "carry
on" card, which still shows a temporary session. The reminder handling in `HomeView+Routines.swift`
stays on Home. It needs Home's container and had nothing to do with the rail.

This amends ADR 0197's layout (the rail sat below the map) and drops the rail's row from ADR 0243
D2's table. The rail was the reason D2 gave for showing a temporary session in two places; with it
gone, Jump back in and the Today's session card show it.

### D5 — Exercises are the picker's categories

- Category tiles in the template picker's order (`ExerciseTemplate.displayOrder`), only for the kinds
  you have drills in, two rows swiped sideways, ending in **New exercise**. Each tile shows a count.
- A tile opens the **category screen**: the Exercises library narrowed to one template. Under the
  search bar, a card with the template's one-line description, the count and **New**. New skips the
  template step and opens straight on the configure form. Folders don't show there: a folder cuts
  across kinds.
- New's instrument is the player's preferred one, unless that template can't be made for it (a bass
  player's Strumming or Chords & Strum), in which case it is guitar. A player with both instruments
  who wants a bass scale drill uses **All N ›** and **+**, which keeps the instrument control.
- **All N ›** keeps today's library, but its sections now follow the same picker order instead of
  A→Z, and their icons wear the practice teal.

### D6 — Loops are grouped by song

One shelf of song tiles, each with its loop count, built from the loops the Loops library lists by
default (the measured ones). A tile opens the Loops library narrowed to that song. **All N ›** shows
even with none measured — reading just **All** at zero, as every shelf's link does — because the
library's *Show all loops* is the way to train your ear on an unmeasured one (ADR 0138). *Built:* it
was first hidden until a loop existed; that left a fresh install's Loops library unreachable from
the hub, which `LibrarySearchUITests` caught on iOS 18.5.

### D7 — The New exercise picker loses its noise

The **Editor** badge goes (nine of ten rows carried it) and so does the footer under the list.

### D8 — The old labels stay on the doors

The UI tests and the manual's shoot find the libraries by accessibility label. **All N ›** on each
shelf keeps the label its row had — `Routines, N`, `Exercises, N`, `Loops, N` — and *Edit goals*
keeps `Long-term goals, N`. The label says what opens, which is also what VoiceOver should say.
ADR 0197 did the same.

## What stays out

- **A *Pick up where you left off* rail.** Drawn, then dropped: Jump back in already offers what you
  were last doing, and each routine card says when you last played it. So there is no folding of
  `PracticeRun.routineUID`.
- **The Routines library itself** (*All N*). ADRs 0173, 0177 and 0178 cover it.
- **Mastery** anywhere on the hub (ADR 0070). Counts and tempos only.
- **An instrument control on the category screen's New** (D5).

## Alternatives considered

- **Proposed A, every section in full.** About two screens long, with Routines pushed down by the
  biggest block, Exercises.
- **Keep the rail on Home and add the shelf.** Two routine surfaces that order differently would
  disagree about what you played, the problem ADR 0243 D2 named.

## Consequences

- `PracticeView` is rebuilt as a `ScrollView` of shelves. The pure rules (routine order, category
  tiles, song groups, a card's third line, New's instrument) live in `PracticeHubShelves` and are
  unit-tested.
- `RecentRoutineCard` and `HomeFeed.recentlyPracticed` go with the rail.
- `ExerciseLibraryView` takes an optional template scope; `LoopLibraryView` an optional song scope.
- UI tests that found a library as a list cell tap the shelf's **All** link by its label instead.
- `docs/manual/reference/practice.md` describes the hub again; its figure is owed to the reshoot.
