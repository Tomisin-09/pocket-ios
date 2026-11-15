# ADR 0301 — Higher, same or lower: say which way a note went, and the neck dims what it can't be

- **Status:** Accepted, built on `pocket-431-higher-same-lower` for 1.4.1, and checked on device on
  2026-11-15 (Consequences).
- **Date:** 2026-11-15
- **Amends:** ADR 0227 — **D3**: a row goes over the neck on Fret & string, *From note 5 · D* with
  *Higher*, *Same* and *Lower*. While one is lit, the neck dims the spots the note can't be. **D10**: one
  step is added past what D10 allowed: the player says which way a note went from the one before. The
  rest of D3 and D10 stands, including *never detected, never suggested* and *no scale shape behind
  the neck*.
- **Relates to:** 0225 (count the notes, then name them; this step sits between) · 0234 D3 (placing moves
  on, silently) · 0288 D2 and 0296 (a note is named by where it lands, bent or released) · 0300 (*Up to
  the note*, proposed in the same review) · 0235 D9 (the neck the tab writer shares) · 0070 (never
  grades).
- **Schema:** none. The arrows stay on the sheet while it's open and are never saved (D6).

## Context

Tomisin names a pass by counting it first, then naming each note (0225). On *Fret & string*, naming
means finding one spot out of 138: six strings, frets 0 to 22. Ear-training dictation teaches a middle
step between counting and naming: the **contour**, whether each note goes up, goes down or stays the
same. It's easier to hear than the note itself, and it's the first thing taught when taking down a
melody (the Parsons code writes it as *u*, *d* and *r*, for repeat).

Contour also narrows the neck. *Higher than D at the G string's 7th fret* leaves about half the spots.
*The same* leaves the four or five places that pitch can be played.

Tomisin proposed the step on 2026-11-15 and reviewed it as a playable mockup (v2). Three things were
decided in that review:

- **A row of its own** over the neck, not squeezed into the count line or the tuning row, *"because it
  has to read as a step of its own"*. The spacing cost was accepted.
- **Three directions to start**, *"simplicity is our friend"*. A step or a leap each way could come
  later.
- **The arrows are kept while the sheet is open and never saved.**

0227 D10 says anything past it needs a new ADR, and this is one. It also refused **a scale shape behind
the neck**, because shown before the answer it's a hint. This step isn't that. A scale shape is the
app's knowledge, drawn before the player has said anything, and it points toward an answer the app
chose. Here the only input is the player's own answer: they heard *higher*, and the neck shows what
follows from that by arithmetic on their own earlier answer. Nothing is detected from the recording,
nothing is compared with it, and a dimmed spot still takes a tap (D4). The app knows no more after the
arrow than before it.

## Decision

**D1 — A row of its own over the neck, on Fret & string.** *From note 5 · D* is on the left and three
buttons are on the right: *↑ Higher*, *= Same* and *↓ Lower*. The row sits above the instrument row.
- **On note 1** the row reads *Note 1 has nothing before it* and the buttons are off. The row stays, so
  the neck doesn't move between note 1 and note 2.
- **Not on By ear.** A name there has no octave, so *higher* can't narrow anything.
- **Not on a chord loop.** A chord's answer is a shape or a name, and neither has one pitch to be
  higher than.
- **Not in the tab writer.** It shares the neck (0235 D9), but it writes what you play, not what you
  heard, so there's no recording to compare by ear. The editor takes the dimming from its owner, and the
  writer passes none.

**D2 — Three directions: Higher, Same, Lower.** Five buttons, a step or a leap each way, is where the
real narrowing is: *a step higher* leaves 6 to 9 spots of 138, where *higher* leaves about half. It's
left for a later ADR, once three have been used.

**D3 — What dims.** While an arrow is lit and the note before is **one note placed on the neck**, every
spot that doesn't fit the arrow is dimmed. *Higher* dims every spot at or below that note's pitch,
*Same* every other pitch, and *Lower* every spot at or above it.
- A spot's pitch is its open string plus its fret, in the piece's tuning.
- It uses the dim the neck already has (`NeckSpotDot.isDimmed`, opacity 0.3, the one *Into it* uses).
- The ✕s dim too, since a muted note has no pitch.
- Two things stay bright: the note being compared with, so the reference stays readable, and the
  note's own answer if it already has one.
- **The note before is compared at its landing pitch**, the pitch it's named by (0288 D2,
  `FrettedNote.sounding`). A held bend counts at its bent pitch, and a released bend at its own fret.
  The spot being considered is compared unbent, because the neck can't know the next note will be bent.
  That's one reason the dim never locks (D4).

**D4 — Dim, never lock. Placing wins.** A dimmed spot takes a tap exactly as a bright one does. Placing
a note takes its arrow off, and nothing says the note doesn't match the arrow. An arrow given wrongly
never hides the right fret. The app never sets two of the player's answers against each other and says
one is wrong (0070).

**D5 — Nothing dims until the note before is placed.** An arrow on a note whose note before is unnamed
stays lit, on the row and on its chip. The neck dims once that note is placed. So a player can say a
pass's contour first, tapping each chip, hearing it and picking an arrow, then place the notes one by
one. Each placement dims the next note's neck straight away, because placing moves on (0234 D3).

Nothing dims either when the note before has no single pitch on the neck: when it's muted, a shape, or
a name given by ear. The line under the neck says why (D7).

**D6 — The arrows aren't saved.** They stay on the sheet while it's open, each kept with its tap, and
they go on *Done* or *Cancel*.
- There's no stored-format change, so an older build has nothing to meet.
- An arrow isn't an answer. A stored arrow would be a second answer for the same note, one that could
  disagree with the first.
- ↶ ↷ step through answers, not arrows. Tapping a lit arrow again takes it off.
- An arrow goes when its tap is answered (D4), on the neck or by ear.
- It also goes when the note before it changes, because a correction put a tap in or took one out just
  before it (0231). The note it was compared with is no longer the note before it.

**D7 — What it says.**
- **The row:** *From note 5 · D*, the note before spelled as the neck spells it, or *From note 5* when it
  has no single pitch. VoiceOver reads the buttons as *Higher than note 5*, *The same as note 5* and
  *Lower than note 5*, with the lit one selected.
- **A line under the neck, while an arrow is lit:**

  | The note before | The line |
  |---|---|
  | one note placed | *Higher than note 5 (D). The spots it can't be are dimmed, and still take a tap.* |
  | not placed yet | *Nothing is dimmed until note 5 is placed.* |
  | muted | *Note 5 is muted, so there's no pitch to compare with.* |
  | a shape | *Note 5 is several notes, so there's no one pitch to compare with.* |
  | named by ear | *Note 5 was named by ear, with no octave to compare with.* |

- **A chip with an arrow** shows the arrow beside its number, on Fret & string only, where the joins
  between chips show too. VoiceOver adds *heard higher*, *heard the same* or *heard lower*.
- **A dimmed spot** says *dimmed* after its name to VoiceOver. The dim was only visual before, for
  *Into it* as well.

`PitchDirection` produces every one of these strings, and they are unit-tested.

**D8 — While *Into it* waits for a start, its dim wins.** *Into it* asks where the note started, which
is a different question. Only the frets the note could have come from matter until it's answered.

## Alternatives not taken

- **The buttons in the count line or the tuning row.** The mockup offered both, and Tomisin chose a row
  of its own (D1).
- **Five directions now.** See D2.
- **Hiding or locking the spots that don't fit.** A wrong arrow would then lock out the right answer.
- **Saving the arrows as a contour on the piece.** It would be a stored change and a second answer to
  disagree with the first (D6). Whether a contour is worth keeping, as a Journal line for instance, is
  not decided here.
- **Working out the direction from the recording.** Never detected (0227 D10).
- **A note when a placement disagrees with its arrow.** That grades (0070).
- **Comparing with where the note before started, before its bend.** The ear compares with the pitch
  it was left with.
- **The row on By ear.** A name has no octave (D1).

## Consequences

- `PitchDirection` (Core/Theory, pure) holds the three directions and what each lets through. It also
  holds what the note before is (`Before`), the dimming it makes (`NeckNarrowing`), which arrows survive
  a change to the pass (`kept`), and the words. `PitchDirectionTests` covers it.
- `NameTheNotesUITests.testAnArrowDimsTheNeckAndPlacingTakesItOff` drives the wiring on the seeded piece.
  It checks four things: *Higher* dims a lower spot, a dimmed spot still places, placing takes the arrow
  off, and an arrow waits on its chip.
- Screenshots of that run showed the row fitting at 402 pt and at 375 pt, the narrowest width. The 375
  run was in dark mode, where the dim still reads.
- `NeckNoteEditor` takes an optional narrowing beside *Into it*'s, and the tab writer passes none.
  `PieceChip` gains an optional arrow by its number.
- `docs/manual/reference/practice.md` describes the row. The `reference/name-the-notes` figure shows
  Fret & string, so it goes stale until the reshoot.
- **Device check, 2026-11-15.** Tomisin used the row on a phone build of this branch and was happy with
  it. The check covered four things: the contour-first way of working (D5), how much room the row takes
  on the sheet, how a dimmed neck reads, and how quickly *Same* finds its four or five places.
