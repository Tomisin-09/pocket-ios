# ADR 0230 — A note heard as one carries its lead-in

- **Status:** Accepted. Built on `pocket-338-name-the-notes-on-the-neck`.
- **Date:** 2026-09-28
- **Amends:** ADR 0227 — **D5**: *Into it* always shows all four ways in (*Picked · Hammer-on ·
  Pull-off · Slide*) and names the tap it joins from; a hammer-on, pull-off or slide heard as one note
  lives **inside** that tap, as a lead-in, on one note or every note of a shape moving as one. **D9**: a
  placed note gains an optional `leadIn` key.
  **D10**: a slide **into** a note from nowhere (`/7`) is lifted. A slide out to nowhere (`7\`), bend
  releases and pre-bends stay out, and so does everything else D10 lists.
- **Relates to:** 0225 (count what you hear: the tap is the record, and nothing is detected) · 0070
  (never grades).

## Context

On the device, hammer-ons and slides were hard to mark and pull-offs looked missing. Two causes:

- **A quick hammer-on, pull-off or slide sounds like one note**, and a player counting what they hear
  taps once. 0227 D5 put a join on the *second* of two taps, so a join heard as one had nowhere to go,
  and in a lick tapped partly once and partly twice per join the pairs stopped lining up. The player
  found it: *these techniques can sound like one note or two depending on how quick they're played.*
- **The pull-off was hidden.** The middle button read *Hammer-on* and only turned into *Pull-off* on a
  note that went down from the tap before; greyed, it always said *Hammer-on*.

## Decision

- **D1 — Two notes heard, two taps; one heard, one tap.** Heard as two, the join goes between the taps,
  as 0227 D5 has it. Heard as one, the tap carries a **lead-in**: where the note started and how,
  the way a bend is one tap that moves between two pitches. The tap reads as the note it **lands on**,
  everywhere a placed note is read (By ear, the line of names, the Journal).
- **D2 — A slide can come in from nowhere.** *From below* or *From above*, with no start fret: `/13`,
  `\13`. A hammer-on needs a start fret; a hammer-on from nowhere stays out with the rest of 0227 D10.
- **D3 — All four ways in, always.** *Picked · Hammer-on · Pull-off · Slide*. A choice joins from the
  tap before when that tap fits it (same string, the right way), and otherwise asks for the start: *Tap
  the fret it was hammered on from, below it on the G string*, with the frets it can't be dimmed
  (lower for a hammer-on, higher for a pull-off, either side for a slide, and *From below* / *From
  above* beside it). For a shape: *Tap the fret one of its notes slid from; the others move with it*. A
  join from the tap before offers *Heard as one note?* (for a shape, *Moved into place as one?*) to move
  it inside, and a lead-in offers *Change where it started*. An ⓘ beside *Into it* says all this in a
  few lines (added after the fourth device check, 0227 *As built*).
- **D4 — The line names the tap.** *From note 29 (G11), heard as two notes*; or why it can't: *Note 29
  (D13) is on another string*, *is on the same fret*. On the first note of a pair it says the join goes
  on the second, rather than offering a start there.
- **D5 — The tab is the same either way.** A lead-in is written inside its note's column and chip,
  `11h13`, `13p11`, `11/13`, `/13`, a shape's stacked one cell per string (`5/7` over `6/8`); two taps
  joined write `11h13` across two columns. Tab has never said how fast, and the count stays what was
  heard. On the neck a lead-in is the same curve or arrow as a
  join, from a ring where it started, or a short arrow in from the side for a slide from nowhere.
- **D6 — A lead-in moves one note, or a whole shape as one.** A double-stop or chord slid, hammered or
  pulled into place as one hand move carries a lead-in on **every** note: the same join, from the same
  side, the same number of frets. The start is tapped on any of its strings and the other notes follow
  (a start that would push one off the neck is dimmed); *From below* / *From above* applies to all. In
  a shape, a note moved or added takes the shape's move; a lone note keeps the fret it started from.
  Lead-ins that don't move as one go, all of them. A shape whose notes move apart (one slides, one
  holds) stays out, with the partial joins 0227 D10 keeps out. A lead-in also goes when its note moves
  off its string or onto its own start, and a tap with one has no join from the tap before as well.
- **D7 — Storage.** An optional `leadIn` object on the note: `{"from": 11, "join": "legato"}`, or
  `{"from": "below", "join": "slide"}`. The direction, and so hammer-on or pull-off, `/` or `\`, is
  worked out from the frets as 0227 D9 does, never stored. One that can't be played into its fret (its
  own fret, off the neck, a hammer-on from nowhere) reads as none. 0225's build keeps the note it lands
  on. No released build reads `into` or `leadIn`, so none misreads a lead-in as a join from the tap before.

## Alternatives rejected

- **Split the tap into two.** It rewrites what was heard to fit the tab, and the tap is the one record
  0225 promises never to second-guess. Adding and removing taps is a separate question, answered by
  0231: the player can now add or take out a tap, but the app never splits one.
- **Work it out from tap timing.** Two taps close together could be a fast picked run or a hammer-on;
  only the player knows, and nothing is detected (0225).
- **Keep one button that turns into Pull-off.** It hid the mark it was meant to offer.

## Consequences

- **Pure and unit-tested** (`LeadInTests`): the lead-in's tab cell, direction and tidy, its coding and
  0225's read of it, the four ways in (`NeckJoin.route`, `NeckJoin.holds`, `LeadInRequest.choice`),
  where a start can go (`NeckJoin.accepts`, `NeckJoin.starts`), a shape moving as one
  (`NeckJoin.leadInsFit`) and a note moved or added in it taking its move (`NeckJoin.carryingLeadIn`),
  and a lone note keeping its start along its string.
- **The Into it row and its line move to their own file** (`NameTheNotesSheet+Into.swift`), for the
  marks file's length.
- **The manual** (`reference/practice.md`, the Name the notes paragraph) says how to mark a note heard as
  one, and the Name the notes figures owe the reshoot a four-way *Into it*.
- **Owed on a device:** marking a lead-in with a thumb (a choice, then a tap on the dimmed neck); the four
  ways in on one row on the smallest phone; a lead-in drawn on the neck; a double-stop slid in as one.
