# ADR 0254 — Watch it on the neck

- **Status:** Accepted — decided with Tomisin, 2026-10-04, from a mockup with four open choices, all left
  at their defaults (*"I'm happy with the default options"*). Built on `pocket-364-watch-it-on-the-neck`,
  and verified on the Mac: the full test plan on iOS 26, the sheet's UI tests on iOS 18.5 as well, and
  screenshots at 375 and 402 points in light and dark. On Tomisin's iPhone the light keeps time with the
  audio and every door is in reach (2026-10-04).
- **Date:** 2026-10-04
- **Relates to:** 0227 D2 (Name the notes' neck never scrolls under a finger; this one is free to, and
  that rule stands) · 0225, 0227 and 0235 (the app never plays an answer back; it still doesn't) · 0234 D5
  (the glow that moves the way a note was played, drawn here unchanged) · 0138 (the loop modes and their
  gates; this is not one) · 0153 (one leaf per screen reads a clock) · 0090 (sheets presented by a stable
  uid) · 0232 D2 (the map's tab sheet, which gains a way in) · 0229 (the Journal's piece row, which has no
  hold menu)
- **Schema:** none. It reads the piece the loop already stores (`Loop.transcriptionData`).

## Context

A loop's piece is named in *Name the notes*, note by note, on the neck. Once it's named, the app shows it
back as tab: under *Saved on this loop*, on the song map's tab sheet, in the Journal. Tab says which fret,
but not where the hand is going, and nothing showed the lick moving on the neck in time with the record.
Name the notes' strip can play the loop and light each note as it's heard (0234 D5), but that's a sheet
for naming: it opens on a note to name, its neck never moves under a finger (0227 D2), and it shows the
three notes either side of the one being named, not the shape of the whole lick.

Tomisin wanted to watch a lick they'd named play back on the neck with the recording. A mockup put four
questions: what it's called, how big its play controls are, what sits under the neck, and whether a door
shows when the song's audio can't play. They kept every default.

## Decision

| # | Decision |
|---|---|
| **D1** | **A sheet for watching, not a practice mode.** `WatchOnNeckSheet` has no routine block, no practice log row, no takes and no Journal note, and Done closes it. It is not a `LoopRunMode`: `LoopModeAccess.allows` stays exhaustive over its three modes, and it never appears in a routine or the planner. Its name is **Watch it on the neck**, everywhere it's offered, with one icon (`eye`). |
| **D2** | **Five doors, one gate.** It opens from the loop's edit sheet (Practice, after *Train your ear*), the Loops library's hold menu (after the modes, before *Add to routine…*), the song map's tab sheet (after the modes, before *Copy to…*), *Saved on this loop* in Train your ear (a second button under *Name the notes*), and the Journal's piece row (a link under the loop's caption, since that row has no hold menu). Each shows only when `PieceNeck.canWatch` holds: **at least one tap is placed on the neck, and the song's audio plays here** (`LoopModeAccess.Facts.audioResolves`, ear training's own test). A piece named only by ear has nothing to light, and a loop whose audio can't play has nothing to follow, so neither gets a door. The sheet still says *Audio unavailable* if the file goes missing after it opens. |
| **D3** | **Only the recording sounds.** The rule that the app never plays an answer back as a sequence (0225, 0227 and 0235) stands. What lights is what was named; what's heard is the record. |
| **D4** | **The whole lick, and a light.** Every spot the piece uses is drawn in ink, as a map of the lick (`PieceNeck.spots`). The tap being heard turns solid, with its marks over it and its glow under it moving the way it was played (0234 D5's `HeardGlows`, unchanged). Where a bend lands and where a lead-in starts aren't spots; they show on the note being heard, as they do in Name the notes. A tap named by ear or not named lights nothing, and its chip is still ringed. When the loop stops, the map stays. Under the neck, the taps in order as Name the notes' chips read them on the neck, read only, with the one being heard ringed and kept in the middle; over them, where the loop is (*Note 3 of 11*) and the heard tap in words (*G string, fret 5, hammered on from 3*). |
| **D5** | **Following.** The board opens centred on the lick, and moves only when the heard tap's frets (its bend's landing and its lead-in's start included) leave the frets in view (`NeckFollow`). So a lick that fits doesn't swing on every note, and one that doesn't comes into view where it goes. Name the notes' rule against scrolling (0227 D2) protects a finger placing a note; nothing is placed here, so this isn't an exception to it, and Name the notes keeps it. |
| **D6** | **Tempo** comes from the sheet's own `ContinuousLoopPlayer`, starting at the loop's command tempo (`loop.ramp.command`) and moving in 5% steps, as in Train your ear. Each door stops what was playing first: the song player through `onOpenNestedAudio`, Train your ear's loop and take as for naming, the Journal's take. |
| **D7** | **The screen stays awake** while it's open (`keepAwakeDuringPractice`), so it can be played along with hands-free. |

### Rejected

- **Ear training's 108-point play button.** On a 375 × 667 phone it pushes the chips under the neck below
  the fold. The sheet's controls are one row: a 52-point play button, what the audio is doing, and the
  −/+ tempo row drawn smaller (`LoopTempoControl`).
- **The tab under the neck instead of chips.** It would mean a highlighted column in `PieceDrawing`, which
  four places share (0234 D8), for a row that only has to say which tap is heard.
- **Doors that always show**, opening on a map that says the audio can't play. A door to a sheet that
  can't do the one thing it's for is the *Coming soon* tile in another form.
- **Making it a `LoopRunMode`.** A mode is a way to practise a loop that a routine can hold and the log
  counts. Watching isn't, and a fourth case would have put it in every mode list, menu and planner rule.

## Consequences

- New: `PieceNeck` and `NeckFollow` (pure, `PieceNeckTests`), `PieceNeckView`, `WatchOnNeckSheet`. Lifted
  so the viewer draws what Name the notes draws, meant to change nothing on screen: `NeckSpotDot`,
  `HeardTapTracker`, `PieceChip` with `NamingStrip.chipText`, `LoopTempoControl`, and `LoopPlayButton`'s
  `diameter`.
- **Following is judged from where it last moved the board.** A board scrolled by hand while the loop
  plays is moved again only once a heard tap leaves the frets following last put in view. Tracking the
  scroll position would mean changing `FretNeckBoard`, which Name the notes and the exercise editors
  share, for a case that corrects itself within a pass.
- Every door asks `PieceNeck.canWatch`, so none of them can show for a loop another hides. The Journal's
  rows pass the piece they've already decoded (`canWatch(_:on:)`).
- `NamingPieceSeed` gains `-seedWatchPiece`: the same song with its six notes placed on the neck.
  `WatchOnNeckUITests` opens the sheet from Edit loop and checks the neck's value while the loop plays,
  the first UI test to play a loop's audio. It passes on iOS 26 and on iOS 18.5, CI's. A second test
  opens it from *Saved on this loop*, whose button shares a Form row with *Name the notes*: a row holding
  two buttons can fire both on one tap, and the test fails if Name the notes comes too.
- The manual gains the sheet under Practice ▸ *The other run modes*, and a line at each door. Its figure
  goes on the reshoot list; no figure is shot per branch.
- **Device check, done by Tomisin (2026-10-04):** the light keeps time with the audio, and the doors are
  in reach.
