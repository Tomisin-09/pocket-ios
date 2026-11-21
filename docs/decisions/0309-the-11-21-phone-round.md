# ADR 0309 — The 11-21 phone round: moves as arrows, closer editor rows, a song's exercises behind a row, Works on when a drill is made

- **Status:** Accepted on 2026-11-21. Tomisin decided all four against screenshots from the phone, the
  day after 1.5's last item merged: D1 *"let's go with the recommended approach of the small arrow head at
  the middle of a jump … do you reckon we could toggle this on/off?"*; D2 *"let's implement the tighter
  row padding for the rows"*; D3 *"I'm happy with this"*; D4 *"you can link songs in the create your own
  setup template, you should be able to link skills as well … I'm with you on goals and would like to
  include the updated text"*. Built the same day on `pocket-456-phone-round-polish`, one commit per
  decision; see *Build notes*. Device check owed (Consequences).
- **Date:** 2026-11-21 (`pocket-456-phone-round-polish`)
- **Amends:** ADR 0293 — **D1**: on iOS 26 the editor's control rows take 5pt above and below (D2
  here). The rows, and what each holds, stand. ADR 0258 — **D4**, Song details: the linked drills and
  *Link exercises* move behind an **Exercises** row (D3 here). Map the song and Build a routine stay on
  the sheet; the other sheets are unchanged. ADR 0216 — **D6**: Works on can be set while a drill is
  made, not only from its ⓘ, on a type with no skills of its own (D4 here). **D4**'s read-only Works on
  for a goal skill's fix becomes that section, and can be changed before Create.
- **Relates to:** 0083 S8 (a slide's arrow, which stays) · 0251 (hammer-on and pull-off marks, which
  stay) · 0157 (the walking board, on by default) · 0111 (drills linked to songs) · 0136 (Your own
  practice) · 0139 O6 (declared, never inferred) · 0070 (never grades)
- **Schema:** none. One new preference, `fretboardShowsMoves`, on to start.

## Context

On 2026-11-21, with every 1.5 item merged and main's UI gate green, Tomisin played with the build on the
phone and sent five screenshots. Two of the asks are about the song map and aren't decided here (see
the end). Three are:

- **Moves.** *"The lines that indicate movement from one note to the other seem a bit weird … could we
  replace them with smaller arrows perhaps?"* The line was the connector trail of 2026-07-28
  (`FretboardGrid.walkTrail`): a faint segment from the note just played to the one lit now, there so a
  sequenced run's jumps would read. It said the two notes were joined, not which way, so a run coming
  back down looked the same as one going up.
- **Spacing.** *"The spacing between the options are a bit too much."* Measured in a hosted window on
  the iPhone 17 simulator (iOS 26.5): 64pt from one setting's row to the next in the Scales editor, and
  50 in the same editor before item 2d made it rows (restored from git and rendered beside it).
- **Song details.** The linked drills are listed on the sheet: *"This could add up over time."*
- **Your own practice.** *"Is there a way we could link it to skills or goals?"*, and a mention of
  setting up pedals or using a looper. A drill can already work on skills, but only from its ⓘ once it's
  saved (0216 D6), and the create form showed Works on only for a goal skill's fix.

## Decisions

### D1 — A move is a small arrowhead in the gap

- While the board walks, the move from the note just played to the one lit now is drawn as an
  arrowhead, 6pt deep and 9pt wide with no stem, pointing the way the hand went.
- It sits in the middle of the gap between the two dots' edges, not between their centres, since the
  lit dot is drawn larger than the one left behind.
- Where the gap can't hold it with 2pt clear of each dot (a string apart with captions on), it isn't
  drawn. There the lit dot already says where the hand is.
- A slide keeps its arrow along the string (0083 S8), and a hammer-on or pull-off its curve and letter
  (0251). Those say what to do; this says which way the hand went.
- **Display** has **Arrows between notes**, on to start. It's global, like the captions, so the
  editors' boards and the run screen read the same, and it turns off only the arrow.

### D2 — The editor's rows sit closer

- On iOS 26 the control rows of the Scales, Arpeggios and Warm-up/Picking/Legato editors take 5pt
  above and below, and keep the list's own side margins so they line up with the form.
- A one-line row comes to about 52pt, the minimum iOS 26 gives a row; it was 64. A two-line row
  (Position) loses its full 20pt. The board's own row keeps its padding.
- The modifier that sets only some edges is in the iOS 26 SDK alone, so it sits under
  `#if compiler(>=6.2)`, as `KeyboardButtonSurface` does. Before iOS 26 nothing changes.

### D3 — A song's exercises sit behind a row

- Song details' **Practise** reads: Map the song, an **Exercises** row, Build a routine for this song.
- The row says how many are linked (*4 linked*), or *None*. The exercise's own **Songs** row names
  titles; this one counts, as the rows beside it on the sheet do (*10 loops*, *1 link*), because the
  list this replaces is the one that grows.
- It opens **Exercises**: the drills by name, each opening its run screen, swipe to unlink, **Link
  exercises**, and the footer that explains them.
- **Build a routine for this song** stays on the sheet. It's something you do with the song, and it
  reads the linked drills either way.

### D4 — Works on, while a drill is made

- The create form for a type with no skills of its own, **Your own practice** and **Basic**, has a
  **Works on** section under Songs. **Add skills** opens the picker the ⓘ uses, the player's own skills
  included. It's optional.
- Its footer says what a skill does for the drill, and names the goals it serves now: *Serves your goal
  Play at the open mic*. A goal reaches a drill through its skills, and the planner already reads them
  (0216 D3), so no link from a drill to a goal is added.
- A typed drill takes its type's skills, changed from its ⓘ as before. A goal skill's fix still arrives
  with its skill in Works on (0216 D4), and on these two types it can be changed before Create.
- Your own practice's footer names two more kinds of practice it's for: dialling in your pedals, and
  building loops on a looper. They're things you practise; the app doesn't talk to pedals.

### Rejected

- **An arrow from the lit note to the next one.** It would show a move before it's played, where a
  slide's and a hammer-on's marks show on the note they lead into.
- **No mark, the last note fading out instead.** Offered beside the arrowhead; Tomisin chose the
  arrowhead.
- **Lowering the whole form's minimum row height**, which would reach about 44pt. Set on a row it does
  nothing, and set on the form it reshapes every row there, the Name field and the songs included.
- **The first few drills on the sheet, then *All 7*.** Two patterns in one section.
- **A link from a drill to a goal.** A second route the planner doesn't read, beside the skills that
  already connect them.

### Not decided here

- **Picking's doors on the map** (an eye on each section heading, a Pick button in the toolbar) and
  **a copied piece that doesn't line up**, which can't be adjusted, and can't be removed from the map
  once its Undo has gone (0232 D17). Discussed with Tomisin on 2026-11-21.
- **Watch drawn as a guitar neck** stays parked in `docs/backlog.md`. Tomisin, 2026-11-21: for another
  release, *"maybe when it's a bit more thought out"*.

## Consequences

- **Docs.** The manual's Song details lines (`reference/home-and-library.md`) and the songs page follow
  D3, and the Your own practice paragraph (`exercises.md`) follows D4. The reshoot list gains Song
  details and the create form.
- **Device check owed.** The arrows on the phone, light and dark, with captions on and off; the editors'
  rows; Song details' Exercises row; the create form's Works on.

## Build notes

**D1 and D2, 2026-11-21.**

- `MoveArrow` (a `Shape`) with a pure `head(from:fromRadius:to:toRadius:)`, tested in `MoveArrowTests`:
  direction both ways along a string, a diagonal's tip on the line with even barbs, the middle of the
  gap rather than the centres, too small a gap, and no move.
- `FretboardGrid.walkTrail` draws it for a plain jump, behind `fretboardShowsMoves`
  (`AppSettings.fretboardShowsMovesDefault`, named because two `@AppStorage` sites hold it). The
  Display menu's switch sits under the caption picker, behind a divider.
- Seen in a hosted window, light and dark, captions on and off: a thirds run's diagonal jumps, a jump
  back down one string, and a one-string move up, which fits with captions off and is left off with
  them on.
- `editorRowInsets()` in `FretboardEditorChrome.swift`, on every control row of the three editors. A
  per-row `defaultMinListRowHeight` was tried and does nothing; a form-wide one took the rows to 44.7pt.
