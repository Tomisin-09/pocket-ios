# ADR 0227 — Name the notes on the neck: where you played it, or what you heard

- **Status:** Accepted. Built on `pocket-338-name-the-notes-on-the-neck` in the four commits of the build
  order, plus the changes after the device check (*As built*). Still owed: the device checks under
  Consequences.
- **Date:** 2026-09-28
- **Amends:** ADR 0225 — **D5**: the three sheets become two (*Fret & string* and *By ear*), the
  chip grid becomes a strip, picking no longer sounds, and *Hear it, then mine* is withdrawn. **D6**: a
  placed answer gains playing marks and a multi-note *shape* kind, and the tuning is chosen per piece.
  **D10**: three lines are lifted (one note per tap, no technique marks, tuning only from the tuner).
  **D7** (after the device check): a long run of unnamed notes in the line is said as a count.
  D1–D4, D7–D9 and the rest of D10 stand, including *never detected, never suggested*.
- **Amended by:** ADR 0230 — **D5**: all four ways in are always shown, and a hammer-on, pull-off or
  slide heard as one note lives inside that note, or every note of a shape moving as one, as a
  **lead-in**. **D9**: a note gains an optional
  `leadIn` key. **D10**: a slide **into** a note from nowhere (`/7`) is lifted; a slide out to nowhere,
  bend releases and pre-bends stay out. The rest of D5, D9 and D10 stands.
- **Relates to:** 0094 T2b (the call-and-response this takes out of Name the notes) · 0097 (Hear, the
  synth withdrawn here, and D4.3, the route back) · 0093 (the chord namer that names a shape) · 0095
  (My chords, whose one-note-per-string rule the Chords switch follows) · 0065 (exercise templates, whose scales editor
  holds the draw-your-own board the neck is lifted from) · 0115/0116 (the curated tunings; strings
  highest-first) · 0123 (key-first spelling) · 0070 (never grades).
- **Schema:** none. `Loop.transcriptionData` and `PieceTranscription` stay. The label gains optional
  keys and one new kind, inside the versioned JSON (D9).

## Context

0225 shipped *Name the notes* with three sheets: Note name, Fret & string (six string buttons and a
fret stepper) and Chord (a root and a quality). Using it on a device turned up two problems and one
wish:

- **A long pass buries the picker.** A 65-note pass drew 65 chips in a grid of seven a row, and pushed
  the string buttons, the stepper and the hear buttons below the screen. The grid is shared by all three
  sheets.
- **The synth isn't good enough to compare against.** *Hear it, then mine* plays the real recording
  and then the player's answer through the unloaded sampler (0097 D4.2). As a pitch reference that is
  honest, but next to a real guitar it doesn't sound close enough for the player to judge a match, which
  is the whole point of the call-and-response.
- **Placing a note should look like the neck**, the way the draw-your-own scales board does, and
  guitar vocabulary (bends, slides, hammer-ons, double-stops, chords) should be sayable, not pushed into
  the Journal text as 0225 D10 required.

Five rounds of a playable mockup settled the shape with the user
(https://claude.ai/artifact/CpaVS68zxi75dW24MBwBQ5, round five). The Pow Music *fretLIVE* lessons
supplied one idea: a bend drawn as an arrow to a ghost of the note it reaches.

## Decision

### D1 — Two sheets: where you played it, or what you heard

The real divide is not notes against chords. It is **where you played it** against **what you heard**.
0225's Chord and Note name sheets are the same act, naming by ear, at two sizes, so they merge.

- **Fret & string** (first): notes, double-stops, triads and chords, placed on the neck.
- **By ear**: a note name, or a root and a quality, with no position.

Chords are **not** folded into the neck alone, though the user proposed it. Naming a chord by ear keeps
three things the neck can't give:
1. **A chord you can hear but not place.** In a full mix the voicing is often unknowable, and the chord
   may be on keys or horns, where there is no grip. The neck would force a guess, and the tab would then
   claim a voicing nobody heard. This is 0225 D5's reason, and it stands.
2. **The skill itself.** Hearing a chord's quality (minor, major, dominant) is the ear training.
3. **Speed.** A sixteen-chord progression by name is one or two taps a chord.

**Which sheet opens:** a piece already named opens on the sheet of its first answer. A new pass opens on
**Fret & string**, except on a chord loop, which opens on **By ear** with the kind set to major.

### D2 — A strip, not a grid

The chips run in **one row that scrolls sideways** and keeps the current note in the middle, the same on
both sheets and in the same place, so switching sheets never loses the place. Above it: *Note 5 of 65*
and how many are left to name. **Next unnamed** jumps to the next gap. The picker, the hear button and
the running answer below sit in the same place for 7 notes or 65.

**Play the loop from the strip** (added after the device check, see *As built*). A slice is one note, and
a line heard a note at a time loses its shape. A play button at the head of the strip plays the loop
itself, at *Train your ear*'s tempo and round until stopped. The chip being heard is **ringed** and the
strip follows it; the chip being **named** doesn't move, so a tap on the neck can't land on the wrong
note. Tapping a chip stops the loop and plays that note's slice, so a slice still never plays over the
loop (0225's rule). What plays is the recording, never the answers (D8, D10).

**Hear a phrase** (added after the second device check, see *As built*). Between one note and the whole
loop: a tap plays the note **with the notes just before it**, ending on it, so the note is heard
arriving from the line, and it is the sound left in the ear when the finger goes to the neck. How many is
the player's: *Hear 3 notes* in the strip's header, from *Just the note* to eight, remembered across
loops and launches, three by default. Near the start of a pass there are fewer before it to take. The
phrase starts where its first note's slice would and ends where the named note's slice does, and it
plays whatever lies between, a held note or a rest, because the count is what the player asked for and
a cap would sometimes play fewer. Its notes are ringed as they sound, as the loop's are, and the play
button stops it.

**The neck plays along** (added after the fourth device check). While the loop or a phrase plays, on
*Fret & string* the notes of the chip being heard glow where they were placed, popping in as each
sounds and fading as the next takes over (only fading with Reduce Motion), so the lick is seen moving
on the neck. It reads the same chip the strip rings, with no clock of its own. The neck doesn't scroll
to follow: like the chip being named, the board never moves under a finger that's placing a note, so a
note beyond the frets in view glows only on the strip. Eight is the most: past that, the whole loop is the better listen.

### D3 — The neck

- **The board is the draw-your-own board** (`FretboardDrillEditor+Board`, 0065): frets 0–22, a dot per
  string and fret, inlays and fret numbers, string letters pinned on the left, scrolling sideways. It
  moves out of the scales editor into a view of its own that both use. The scales editor is rechecked
  after the move.
- **Every spot carries its note name faintly**, spelled key-first (0123). The note you're naming is bold
  on the practice tint, and the pass's other notes sit in ink, so the lick's shape is on the neck as well
  as in the tab. **A faint name is a map, not a hint:** it reads the same whatever you heard, so it
  can't point at the answer.
- **Tap to place.** With *Chords* off, a tap replaces the note. Tapping the placed note does nothing.
- **Selecting a chip scrolls the neck** to its note.
- **Guitar or bass, per piece.** The *Where did you play it?* row carries the instrument and tuning
  ("Guitar · Standard ›"). Tapping it opens a list sheet (`OptionListSection`, not a menu: twelve
  choices plus an explanation is past what a menu may hold): the instrument, then the tuner's curated
  tunings for it (nine guitar, three bass). It is **for this piece only**: a new piece starts from the
  tuner's setting, and the tuner keeps its own. **A new tuning keeps the frets** and renames their
  notes. **A new instrument clears them**, after asking, since a six-string position has nowhere to go
  on four strings, and moving it would be a guess.

### D4 — Chords on the neck

- A **Chords** switch, off by default. On, a tap on an empty string adds a note, a tap on a string that
  has one moves it, and tapping a note selects it (a ring) and then, tapped again, takes it out. **One
  note per string**, the rule the My chords placer (`CustomChordSheet`) already uses, so a double-stop, a
  triad and a six-string chord are the same gesture.
- **Not from My chords** (withdrawn after the device check, see *As built*). A row of the player's
  saved shapes (0095) that dropped a shape onto the note in one tap was built, then taken out: under the
  neck, with the marks and the Chords hint, it cluttered the sheet. A chord is placed a note at a time.
- **The name comes off the shape**, never off the audio: triads, chords and power chords through
  `ChordNamer.candidates` (0093), root position preferred, inversions as slash names (*Am/C*). Any other
  double-stop shows its **interval** (*a 4th*), from a new twelve-entry table; the app has degree labels
  (♭3, 5) but no interval names in words. It names what was placed, not what was heard.

### D5 — Five playing marks, in three kinds

The kind decides where a mark lives.

| Kind | Marks | Where it lives |
|---|---|---|
| **Changes the note** | Bend (½, whole, 1½ steps) | On the note. The sounding pitch moves, so a bend is part of the answer: without it a bent note has no right fret. |
| **Colours the note** | Vibrato | On the note. |
| **Joins two notes** | Hammer-on, pull-off, slide | On the **second** tap, as *Into it*. |

- **A join is valid only** when the tap before is on the neck, on the same strings, with every note
  moving the same way. The direction decides which it is: up is a hammer-on or `/`, down a pull-off or
  `\`, so the control only offers the one that fits. A join that stops being valid (the note before
  moves) is dropped. *(Amended by 0230: all four ways in are always shown, and a join heard as one note
  lives inside that note, as a lead-in.)*
- **On a shape**, a bend and vibrato go on the ringed note; a join moves the whole shape (sliding 6ths).
- **Drawn on the neck**: a bend as a dashed ghost where it lands, with an arrow from the note (the
  fretLIVE idea); vibrato as a wave over the note; a hammer-on or pull-off as a curve under the string
  marked *h* or *p*; a slide as a straight arrow marked `/` or `\`. Only the current note's marks are
  drawn.
- **Written in the tab** the usual way: `7b9`, `7~`, `5h7`, `7p5`, `8/10`, `10\8`. In the strip a join
  sits between the two chips it joins.

### D6 — By ear

- One **name grid** (the twelve names, key-first) and the **kinds grouped by how many notes they hold**:
  *One note*, *Two notes* (the power chord), *Three notes* (major, minor, sus4, sus2, dim, aug) and *Four
  or more* (sevenths, sixths, add9s, ninths). A note name is the smallest case. Under *Two notes*: *Any
  other double-stop is named on the neck, by its interval.* The kinds come from `ChordQuality.catalog`,
  each suffix once, as before.
- **The kind stays selected; tapping a name saves and moves on.** A solo by ear is one tap a note, as
  fast as Note name was. A progression needs a second tap only when the kind changes. Tapping a kind
  changes the current answer's kind without moving on.

### D7 — One answer per tap, read one way

Each tap has **one** answer. The two sheets give it at two levels of detail, and reading goes one way:

- **By ear reads the neck.** A placed note shows as its sounding pitch (the G7 bent a whole step reads
  *E*), a shape as its chord (*Am/C*), outlined rather than filled, with a line saying it was read from
  the neck. Nothing is entered twice.
- **The neck never draws a by-ear answer.** A chord named by ear has no grip (D1). The neck says *Named
  by ear as Am* and stays empty.
- **Only another sheet overwriting neck work asks first**: *Replace the shape you placed on the neck
  (G5·B5·e5) with Cm?* with **Replace** and **Keep it**. Picking what the neck already reads changes
  nothing. On the neck itself, edits are direct. Every other change is one tap to redo, so it just
  replaces.

### D8 — The synth comes out

- **Hear it, then mine is withdrawn**, and **picking no longer sounds** the answer, since it's the same
  synth. The player compares by playing it on their own instrument against **Hear it again**, which
  stays: that is the real recording.
- **They come back** when the tone engine can sound like a guitar: the parked *Real guitar audio for
  chords and strums* in `docs/backlog.md`, the 0097 D4.3 upgrade path. Not before.

### D9 — Storage (amends 0225 D6)

- A **fretted** label keeps its one note and gains optional keys: `bend` (semitones, 1–3), `vibrato`,
  and `into` (`legato` or `slide`, the join from the tap before; which of hammer-on or pull-off, `/` or
  `\`, is worked out from direction, never stored).
- A new **`shape`** kind holds two to six fretted notes, each with its own `bend` and `vibrato`, and the
  shape's `into`. *(Amended by 0230: a single note gains an optional `leadIn`.)*
- **The pitch of a fretted note includes its bend.** `pitchClass(openMidi:)` and everything that reads
  it (By ear, the Journal line) see the bent note's sounding pitch.
- **The tuning is chosen per piece** (D3) and still recorded as `openMidi` and `tuningLabel`, so nothing
  about how it is saved changes.
- **Older data and older builds.** Pieces saved before this read as they are. An older build that meets
  a newer piece keeps a marked note's fret and drops its marks (a note without its bend is still where
  it was played), and reads a `shape` as an unnamed tap (0225 D6's rule for an unknown kind): a chord
  cut down to one note would be a wrong answer, and no answer is better than that.

### D10 — What stays out

0225 D10 as amended. Anything past this needs a new ADR:
- **Order only, no durations.** The dots carry the timing.
- **No free-text tab document**, and **no playing the tab back as a sequence**.
- **Never detected, never suggested.** Every fret, mark and name is the player's.
- **Marks with no note at one end**: slides from or to nowhere (`/7`, `7\`), bend releases (`7b9r7`)
  and pre-bends. *(Amended by 0230: a slide into a note from nowhere, `/7`, is lifted. The rest stays
  out.)*
- **Joins between a single note and a shape**, or between shapes on different strings.
- **Harmonics, tapping, palm muting, rakes.** The Journal text still carries them.
- **A scale shape behind the neck.** Shown before the answer, it's a hint.

## Build order

One branch, before the manual reshoot, in four commits after this record, each able to stand alone:

1. **The strip, the By ear sheet, and the synth coming out.** Two sheets, with Fret & string still on
   today's string buttons and stepper.
2. **The neck**, with the instrument sheet, and By ear reading placed notes.
3. **The five marks.**
4. **Chords on the neck**, the My chords stamps, and By ear reading shapes.

Reading across sheets lands with whatever it reads, so no commit shows a sheet reading something that
doesn't exist yet.

**As built:** By ear's read of a placed note (and its ask before replacing one) landed in commit 1, not
2: the string buttons and stepper still in commit 1 already placed notes, so there was neck work to
protect from the start.

**After the device check** (2026-09-28):
- **From My chords came out** (D4). The row of saved shapes under the neck cluttered the sheet, and
  placing a chord a note at a time is quick enough.
- **Play the loop from the strip** (D2). Inside the sheet only the slice sounded, so the player heard
  the note they were on and never the line around it.
- **A long run of unnamed notes is said as a count** (0225 D7, amended). A 69-note pass with nine named
  showed nine names and sixty `?` in *Saved on this loop* and the Journal line. Now one to three unnamed
  notes in a row keep a `?` each, and four or more read *(60 unnamed)*. Journal lines already written
  keep their old form.

**After the second device check** (2026-09-28):
- **Hear a phrase** (D2). The whole loop didn't help place one note in a long pass, and one note alone
  gave no context, so a tap now plays a chosen number of notes ending on the one being named.
- **A long pass suggests a shorter loop.** Under the pass rows, once the loop stops, a pass of more than
  24 notes (`TapTally.longPassNotes`) reads *Loops of around 16 notes are easier to transcribe*. It's
  advice about the setup, never a mark on the playing (0070), and well past 16, so a pass of 18 isn't
  told anything.

**After the third device check** (2026-09-28): hammer-ons and slides were hard to mark and pull-offs
looked missing, because a quick one is heard, and tapped, as one note. That lifts part of D10, so it is
its own record: **ADR 0230**.

**After the fourth device check** (2026-09-28):
- **The neck plays along** (D2): the heard chip's notes glow on the neck during playback.
- **An ⓘ beside *Chords* and *Into it*** (D4, D5), the app's shared `InfoPopoverButton`, says what each
  does in a few lines. *Into it* and its ⓘ became a title line over the four ways in, which no longer
  fit one row beside it on the smallest phone.

## Consequences

- **Pure and unit-tested:** the label's new keys and kind (encode, decode, and an older-shaped decode),
  the join rule, the sounding pitch with a bend, the shape reading (namer and interval), the tab writer's
  stacked columns, joins and marks, and the By ear kind grouping.
- **The draw-your-own board is extracted**, so `FretboardDrillEditor` loses the extension and gains a
  child view. No UI test opens the board itself (the shoot class `ManualExerciseShots` stops at the
  screen that offers *Draw your own*), so it is rechecked by eye on the simulator after the move.
- **`NameTheNotesSheet` and `+Pickers` are rebuilt** around the strip and two sheets (239 and 231
  lines today). The neck, the marks and By ear each get a file of their own, to stay under the
  400-line cap.
- **The manual** (`docs/manual/reference/practice.md`, the *Name the notes* paragraph) is rewritten, and
  the Name the notes figures are owed to the reshoot: two sheets to shoot, not three.
- **Owed on a device:** the neck's scroll inside the sheet (no fight with the sheet's own drag); tapping
  a 24pt dot at fret 20 on a phone; the strip's centring on a 65-note pass; the ring keeping time with a
  phrase (`SliceClockReading`, the slice's own clock, read from the player's sample time as the loop's
  is), over Bluetooth and slowed.
