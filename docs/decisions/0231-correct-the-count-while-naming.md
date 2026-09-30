# ADR 0231 — Correct the count while naming

- **Status:** Accepted. Built on `pocket-338-name-the-notes-on-the-neck`.
- **Date:** 2026-09-28
- **Amends:** ADR 0225 — **D5**: *Name the notes* names a pass's taps, and can now also take a tap out
  or add a note the player missed, tapped in against the recording. The rest of D5 stands, and so does
  D3: every tap is still one the player made, in song seconds.
- **Amended by:** ADR 0234 (Naming from real use, 2026-09-30) — **D3**: each correction is one step of
  the sheet's undo history, and its inline Undo takes that step back while the pass is as the
  correction left it. The rest stands.
- **Relates to:** 0227 (the strip, D2, that the corrections sit under; joins, D5) · 0230 (which left
  adding and removing taps as a separate question) · 0070 (never grades).

## Context

On the device the player asked: *what if, while mapping the notes to a fret and string, you realise
there was a note you didn't count, or one you counted that isn't there?* Naming is where that shows up:
the player is listening closest, one note or a short phrase at a time and often slowed down. The only fix
was to count the loop again and name every note again, which on a pass of 20 to 30 notes throws away
most of the work to change one tap.

## Decision

- **D1 — Take a note out.** Under the strip, *Take note 12 out* removes the selected tap and its name.
  The note after it is selected, or the new last. A pass keeps at least one note.
- **D2 — Add a missed note by tapping it in.** *Missed a note?* plays the stretch around the selected
  note, from the note before it to the note after (at either end of the pass, up to 1.5 s further, never
  past the loop), at the loop's speed, with the strip's ring following. The count's pad appears, and one
  tap on it adds a note **where the player tapped**, read from the stretch's own clock with the output
  latency taken off, as a count would have placed it. It goes in among the others in time order,
  unnamed and selected. *Play it again* replays the stretch; a tap with nothing playing says so.
- **D3 — Undo, until the next change.** Each correction says what it did (*Took note 12 out.*, *Added
  note 12 where you tapped.*) with *Undo*, on a line under the two corrections, so they don't move and a
  second stray tap can go straight after the first. Undo stays only while the pass is exactly as the
  correction left it. A name given or another correction retires it, so Undo never undoes more than the player
  sees. The sheet's own *Cancel* still drops everything done in it.
- **D4 — Joins follow the tap before.** A join is from the tap before (0227 D5), and a correction can
  change which tap that is. The corrected pass is tidied as the correction is made: a join that no
  longer fits goes (an unnamed note added before it), and one that still fits stays (a stray tap taken
  out from between two notes on the same string). A lead-in is inside its own note and is never
  affected.
- **D5 — Where it lands.** Done hands back the taps, not only their names. A pass tapped this visit is
  changed in place, so its row's dots and count change; a saved piece is edited in place and dated to
  the day it changed (0229), as an edit to its names is.

## Alternatives rejected

- **Add a note halfway between two others.** Quicker, but it makes up a time. The tap is where the note
  is in the song: it's what the slice plays, what the ring and the neck follow, and what the song map
  will place. A made-up time would play the wrong moment and put the note in the wrong place, which is
  why a tap is only ever made by the player against the recording (0225 D3).
- **Recount a stretch** (tap notes 10 to 14 again, replacing them). It throws away the names in that
  stretch and needs more UI, while one added and one taken out cover what the player asked for.
- **Drag taps along a waveform.** Count the notes has no waveform on purpose (0225 D1).
- **Split a tap into two** stays rejected (0230): a note heard as one keeps its lead-in. A player who
  hears two notes where they tapped once can now add the second, which is their call, not the app's.

## Consequences

- **Pure and unit-tested** (`PassCorrectionTests`): the stretch (`PassCorrection.stretch`, including a
  region that no longer holds a saved piece, which is ignored), where a tapped-in note lands, a tap
  taken out and the selection after, the joins a correction breaks or keeps (`PassCorrection.tidied`),
  and when Undo is offered. `TapPasses.replaceTaps` replaces `setLabels`, and `CountTheNotesNamingTests`
  checks that Done's taps land on a pass and on a saved piece (re-dated), with the loop's region.
- **The pad is shared.** `TapPad` moves out of `CountTheNotesSection` into its own file with its words
  as a parameter, so a note tapped in is placed with the same touch-down gesture as the count.
- **The sheet owns the taps.** `NameTheNotesSheet` keeps `taps` as its state, and `labels` is read and
  written through it, so the pickers are unchanged. The corrections are in `NameTheNotesSheet+Correct`.
- **The manual** (`reference/practice.md`, the Name the notes paragraph) says how to correct a count,
  and the Name the notes figures owe the reshoot the line under the strip.
- **Owed on a device:** tapping a missed note in time with the stretch, slowed and at speed, and a
  corrected pass saving and reopening.
