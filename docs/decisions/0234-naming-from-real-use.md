# ADR 0234 — Naming from real use: save first, move on, undo, and snag where you're stuck

- **Status:** Accepted. Built on `pocket-340-save-then-name`, one commit per item. Still owed: the device
  check under Consequences.
- **Date:** 2026-09-30 (notes 2026-09-29; two design rounds 2026-09-30)
- **Amends:** ADR 0225 — **D5**: *Name the notes* opens on the saved piece only, never on a pass (D1),
  and *Hear it again* goes (D3). The rest of D5 stands: a chip tap plays the real recording, and the
  player judges whether it matches.
- **Amends:** ADR 0227 — **D2**: the strip's bottom row becomes ↶ ↷ · *Next unnamed* (D6), *Next note*
  goes (D3), and the neck's glow moves the way the note was played (D5). **D3**: placing a note moves on,
  silently, the marks follow the note just placed, and the three notes either side are drawn in tiers,
  numbered (D3, D4). **D8**: *Hear it again*, kept there as the thing to play against, goes; a chip tap
  does the same. The rest stands, including a board that never moves under a finger.
- **Amends:** ADR 0229 — **D1**: the row shows one line, the count, and *See the notes* opens the piece
  in place (D8). **D4**: only the loop's caption opens *Train your ear*; the count line opens the notes.
  D2, D3 and D5 stand.
- **Amends:** ADR 0231 — **D3**: a correction is one step of the sheet's history (D6). Its inline Undo
  stays while the pass is as the correction left it, and takes that step back. D1, D2, D4 and D5 stand.
- **Amends:** ADR 0200 — **D6**: a snag can also be made on a note in *Name the notes* (D7), marked
  `markedWhileNaming`. It is still a point on the song with a loose loop id, and D1's tighten offer
  reads it like any other.
- **Amends:** ADR 0204 — **D1**: a snag inside a loop may now be a note the player was stuck naming
  rather than one they fumbled. `Snag.markedWhileNaming` tells the two apart. Nothing reads it yet, and
  the context builder still sends every snag in the span, so a returning Oracle must read the field
  before it treats a snag as a stumble.
- **Amends:** ADR 0205 — **D1**: `SnagRecord` gains an optional `markedWhileNaming`, and
  `JournalEntryRecord` an optional `snagUID`; restore lands both (D3). D4 stands: additive, so
  `schemaVersion` stays at 1.
- **Relates to:** 0228 (a snag's line opens *Name the notes* inside *Train your ear*, the mode it was
  written in) · 0233 (versions: D1 depends on them, or saving over a piece would lose named work) · 0232
  (the map's piece sheet draws the same view) · 0230 (lead-ins, which the glow shows) · 0202 D3 (a snag
  removed with no undo toast) · 0189 (additive schema criteria) · 0070 (never grades) · 0211 (the Home
  tile, which the Write a tab ADR amends, not this one).
- **Schema:** two additive Optional attributes, `Snag.markedWhileNaming: Bool?` and
  `JournalEntry.snagUID: UUID?`. Neither is a custom enum, so both meet 0189's criteria. The archive
  gains the matching optional fields.
- **Amended by:** ADR 0238 (2026-10-02) — **D7**: a snag's line can also be written from the song
  player's *Snags* panel, by holding a row, and it's read from every loop on the song, not only the one
  being named. A new line written there goes to the loop the snag was made under, and is 🧗 Struggle for
  a stumble. The rest of D7 stands.
- **Amended by:** ADR 0252 (One note moves inside a chord, 2026-10-04) — **D6**: ↶ ↷ move from the
  strip's bottom row to the right of the picker's first row, in the same spot on Fret & string and By
  ear. The bottom row keeps *Next unnamed*. The history, the keys and the rest of D6 stand.

## Context

Tomisin used *Count the notes* and *Name the notes* (0225, 0227–0231) on real licks, and came back with
eight notes:

1. Naming should only happen once a pass is saved.
2. A small play button in *Count the notes*, rather than scrolling up to the big one.
3. A way to leave context on a piece where you're stuck, for when you come back.
4. Undo and redo when changing a note ("ctrl-Z / ctrl-Y").
5. Animations that match the technique.
6. Colour the three notes before and after, not only the current one.
7. After placing a note, move on to the next. Playback only when a note in the strip is tapped: with
   *Hear 8 notes* set, every move played eight notes.
8. The saved piece's line of names is a wall of text on a 98-note piece, in *Saved on this loop* and in
   the Journal. Make it presentable.

A ninth, **Write a tab** from the Home tile beside Toolkit, is its own ADR and branch.

Two design rounds ran on a playable mockup before any code. Round two changed four things: the top bar
has no room for ↶ ↷, so they take the space *Hear it again* and *Next note* leave; a snag is a **hold
on the chip**, not a button; neighbours carry their numbers; and the Journal row folds to its count.
The third note became the user's own idea along the way: a snag, until now a stumble while playing,
marks a note while naming too.

## Decisions

### D1 — Save a pass, then name it

- *Count the notes* ends with **Clear · Save**. **Name the notes** sits under *Saved on this loop*, where
  *Edit names* was, and is the only way in.
- A pass is scratch paper: **Clear** throws it away, names and all. Naming it invited losing the work.
- It also fixes a bug. Naming pass A and then saving pass B stamped A's tuning onto B, through a
  model-wide `namingTuning`. The unsaved-pass path (`NamingRequest.Source`, `nameTarget`,
  `TapPasses.replaceTaps`) is gone, and the bug with it.
- *Save* stores the pass's taps unnamed. Saving over a piece keeps the old one as a version (0233), so
  naming after saving loses nothing. This is why versions were built first.

### D2 — A small play button in the count

- A ▶ beside *Show beats* starts and stops the loop (`LoopPlayButton`). It calls the same action as the
  big button, `LoopTransport.toggle`, so an armed take starts before play and finishes before stop from
  either, and the two can't drift apart.

### D3 — Placing a note moves on, silently

- On *Fret & string*, a tap that places a note moves to the next note **without playing anything**.
  With *Chords* on it stays, since a shape is several taps. The tap that says where a lead-in started
  never moves.
- **The marks follow the note just placed.** *Into it*, *Bend* and *Vibrato* apply to it until the next
  placement or a chip tap. The line above them says so: *Marks go on note 5, B8, until you place note
  6*. Its chip is outlined dashed. `NamingCursor.afterPlacing` holds the rule, pure and tested.
- **Only a chip tap plays.** *Next unnamed* moves silently. *Hear it again* goes, since a chip tap does
  the same, and so does *Next note*, since placing moves on by itself.
- *By ear*'s **Replace** now moves on too, as a new name does.
- **Rejected: a "Move on after each note" switch.** It keeps the behaviour the user asked to be rid of,
  helps only those who find it, doubles the tests and the manual, and the sheet is already tight. Add it
  only if the device check finds moving on gets in the way.

### D4 — The three notes either side, numbered

- `NeckNeighbours` ranks each placed spot as the current note, one of the three **before** it, one of
  the three **after** it, or the rest.
  - Before is **filled** and after is **ringed**, each fading with distance, so the two differ in shape,
    not colour alone (*Differentiate Without Color*).
  - Each carries its note number, so a lick reads in order where it comes back to the same fret.
  - Where notes share a spot, the nearer wins, and a tie goes to the note before.
- Once a placement moves on, the note just placed is the first before, so the neck still shows where
  you were.
- VoiceOver reads the neighbours in words.

### D5 — The glow moves the way the note was played

- `HaloMotion` reads the heard note and the one before it, in this order:
  - a lead-in or a join first. A hammer-on or pull-off lights where it started and snaps across; a
    slide travels along the string; a slide in from nowhere enters from below or above.
  - then a **bend**, which glides from the fret to where it lands;
  - then **vibrato**, which shakes;
  - otherwise the note **pops** in.
- `HeardGlows` draws it under the dots, short enough to end before the next note is heard.
- With Reduce Motion each only fades. The board never scrolls to follow (0227 D2).

### D6 — Undo and redo

- `NamingHistory` keeps steps of the taps, the tuning and the current note, up to 100.
- **Every change goes through one commit**, which tidies the joins and then records, so a change and
  the tidy it causes are one step.
- ↶ and ↷ sit in the strip's bottom row beside *Next unnamed*. With a keyboard, ⌘Z, ⇧⌘Z and ⌘Y work.
  The top bar, *Cancel* · title · *Done*, has no room. *(Amended by 0252: they moved up to the right of
  the picker's first row, beside the instrument on Fret & string and *What did you hear?* on By ear.)*
- An undo or redo makes the first note that changed current, and plays nothing.
- The history lasts for the visit. *Cancel* still drops everything.
- Snags are not in it (D7).

### D7 — A snag marks where you're stuck

A snag keeps its job (0200). Marking a stuck note is a second use, not a replacement.

- **Making one: hold a note in the strip.**
  - It makes a `Snag` at that tap's time, on the loop, with `markedWhileNaming: true`.
  - Holding again removes the snag on that note, including one made while playing.
  - A hold makes the note current and never plays it.
  - Tap and hold are two gestures on a plain shape, because a `Button` with a hold fires both.
    VoiceOver gets a named action, *Snag this note* or *Take the snag off*.
  - It's saved at once. It isn't in the history, *Cancel* doesn't drop it, and taking it off has no
    undo toast (0202 D3).
- **Each shows in both places.**
  - A note snagged while naming is a tick on the waveform and a row in the *Snags* panel, and it feeds
    the tighten offer. A note that's hard to hear is the bit to loop tighter.
  - A stumble snagged while playing sits on the nearest note within a second, inside the loop's span
    (`SnagOnPiece`).
- **An optional line.**
  - *Add a line* writes an 👂 Ear note to the loop's Journal at once, tied to the snag by
    `JournalEntry.snagUID`.
  - It is never 🧩: the map reads a 🧩 note as the loop solved by hand, and ignores a line tied to a
    snag even if it's tagged that way.
  - Deleting the snag leaves the line as an ordinary note on the loop.
  - Free text stays in the Journal (0104 E3; a piece has no text of its own, 0229 D4).
- **Where it's read:**
  - a badge on the chip;
  - the line under the strip. It shows the note's snag and its line, else how many snags the piece has
    with *Next snag*, else *Hold a note to snag it*;
  - *Snags on this piece* under *Saved on this loop*, where tapping one opens *Name the notes* on it;
  - the line's Journal caption, *Intro lick · note 23*, which opens *Name the notes* on that note.
- **`markedWhileNaming` is recorded now because it can't be filled in later.** Nothing reads it yet (see
  the 0204 amendment above).

### D8 — A piece drawn for reading, one view in four places

- `PieceStaff` (pure) and `PieceDrawing` replace the line of names and the one line of tab. They are
  used in *Saved on this loop*, **Versions**, the map's piece sheet and the Journal's Pieces row, so
  the four can't drift apart.
- **One line says what it is:** *98 notes · Guitar · Standard · 6 unnamed*. The tuning appears only
  over frets, and a piece with no names says *none named yet*.
- **The tab comes in rows that fit the width**, never scrolling sideways.
  - A column never splits, and each row says which notes it holds.
  - Every row but the last is spread to the width, so the bars line up down the page.
- **What the strings can't say sits above them:**
  - a name given by ear;
  - a chord;
  - the name of a shape of four notes or more;
  - `·` for an unnamed note;
  - a count, `(5)`, for four or more unnamed in a row (0225 D7's count).
- A piece with nothing on the neck is its names, in fours.
- **The Journal row folds to that one line**, whether the piece was named by ear or on the neck. *See
  the notes* opens it in place, and *Hide the notes* folds it again.
- The map's sheet keeps **Copy tab** on a hold, since the tab could be selected as text there.
- `summary()` stays, as the VoiceOver label and the search text.
- **Order only**, as `TabLine`: the dots carry the timing (0225 D10).

## What stays out

- A switch to turn moving on off (D3).
- Snags in the undo history (D7).
- Anything reading `markedWhileNaming`.
- Timing in the tab.
- **Write a tab** and the Home tile beside Toolkit: its own ADR, on its own branch.

## Consequences

- **Manual:** the Count the notes section of `reference/practice.md`, the piece row and a snag line's
  caption in `reference/tools-and-journal.md`, the *Snags* panel in `reference/song-player.md`, the
  map's tab in `songs.md`, and a tenth hold in `gestures.md`.
- **Reshoot owed:**
  - Count the notes' row and *Saved on this loop*;
  - *Name the notes*: the bottom row, the neighbours, the marks line and the snag line;
  - the Journal's Pieces row.

  These are shot once, with the other owed figures.
- **Device check owed:**
  - a tap on a chip never snags, and a hold never plays;
  - the glow's timing for each technique;
  - how moving on feels;
  - whether the neighbours read;
  - the small ▶.
- **A UI test for tap against hold** is owed too. No UI test opens the sheet yet, so it needs a seeded
  route.
- **Schema:** checked as an upgrade on the simulator (the old build, then this one over it) before
  merge.
