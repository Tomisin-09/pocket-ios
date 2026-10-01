# ADR 0232 — Map the song: a song's loops laid out as pieces, and the tab drawn from them

- **Status:** Accepted. Built on `pocket-339-map-the-song`, in the five slices of the build order.
- **Date:** 2026-09-28
- **Relates to:** 0225 D8 (the piece is stored structured because this is its reader) · 0227 D7 (one
  answer per tap, read one way: what makes a label a chord) · 0229 (the Journal's Pieces scope, and
  which loops count as solved) · 0011 (markers) · 0022/0154 (the beat grid, one tempo per song) · 0051
  (the per-song gridlines switch) · 0135 (a loop as a backing track) · 0150 and 0161 (export, not
  hosting; the practice file carries no song titles) · 0070 and 0225 D9 (no completion score) · 0092 §A4
  and 0225 D10 (never detected, never suggested) · 0233 (the map reads a piece's version in use, and its tab sheet
  opens **Versions**) · 0111 (a routine made for you is reviewed before it's kept) · 0138 (a Practice block
  needs a command tempo).
- **Amended by:** ADR 0236 — **D12**: the Export tab is no longer waiting on a legal review. A
  song's tab, and a tab written in My tabs, export as plain text or PDF (0236 D9). No hosting, no
  importing and never inside a routine file all stand; the last now because a song sent inside a
  routine carries no pieces (0236 D4). D12's "carries no song titles on purpose" cited the support-message
  ADR by mistake, and no longer holds for a routine sent with its songs.
- **Amends:** ADR 0229 D2 — under the **Pieces** scope a piece sits under its song, not on the day it
  last changed (D20). *All* keeps the day, and D1's one row per loop stands.
- **Schema:** four additive fields: `Marker.startsSection` (D6, slice 1), `Marker.sameAsUID` (D8,
  slice 3), `Loop.repeatsToSectionEnd` (D14, slice 3) and `Loop.repeatsTo` (D15, slice 3b, a String).
  Each is Optional or defaulted, and each is optional in the archive's `MarkerRecord` or `LoopRecord`.
- **Design history:** `docs/plans/song-map.md` (parked 2026-09-27, promoted to this ADR) and the
  mockup at https://claude.ai/artifact/B9cjgdgZDxNfy6J2R5uqPU.

## Context

Tomisin's analogy: transcribing a song's loops is a **jigsaw**. Each loop you've worked out is a solved
piece, and your own chart of the song is the finished picture. Since ADR 0225 every saved piece has held
its taps in song seconds and what each one was named, so the pieces already know where they sit and what
they say. What's missing is the board to put them on.

The idea was parked on 2026-09-27 with six questions open. They were settled in one design round on
2026-09-28, and the answers are D1, D7, D8, D4, D12 and D13 below.

## Decision

### D1 — Where it lives

- **Song details gains a row, *Map the song*.** The map is per song, so the song is its home.
- **It opens full screen** (a cover over the details sheet, not a push inside it). The board is wide,
  and on iPad a sheet is a narrow card.
- **The cross-song way in is the Journal's Pieces scope, grouped by song** (ADR 0229 said so), not a
  second list in the Toolkit.
- The iPad second column (Directions 2026-09, iPad B) is the natural later home for it beside the song.

### D2 — The board

- **The song, left to right, in rows.** A row is 8 bars when the song has a grid (D5), or 16 seconds
  when it doesn't. Rows restart at each section (D6), so a section always begins a row.
- **Lanes by layer**, because melodies play over chords: **Chords** (Indigo) above **Notes** (Teal).
  Pieces that overlap in one layer take a second lane in that layer, assigned once per song so a piece
  keeps its lane across rows.
- **Every loop of the song is on the board**, drawn where it is and never snapped. A loop crossing a row
  or section edge is drawn in both, with the cut edge marked.
- **Markers that don't start a section are pins** on the row's ruler.
- **Tapping a piece opens its tab**: a sheet with what it holds (the piece's line; its tab, drawn by
  `TabLine` as *Saved on this loop* and the Journal draw it, with the tuning; or a line saying what's
  missing) and buttons for the modes it can open in. **Holding it** gives a menu: *View tab*, then those
  modes (*Train your ear*, *Practice*, *Improvise*, as `LoopModeAccess` allows). Reading is the light
  action, so it's the tap; working on it is one more. The hold is a context menu, the system's long
  press, so it never fires the tap too. *(Changed during the build, 2026-09-28: the tap first went
  straight to Train your ear. Holding still does, in one step.)*

### D3 — Which layer a piece is on

- **Its names decide.** If every named tap reads as a chord (0227 D7: a chord named by ear, or a shape
  on the neck that spells one), it's in the chords layer.
- **With no names, the loop's type decides.** A *Chords* loop is in the chords layer. *Lick*, *Riff*,
  *Passage* and no type are in the notes layer.

### D4 — Draw what's there, not a status

| What the loop holds | On the board | In the Tab view |
|---|---|---|
| No piece | an empty, dashed frame | nothing (it reads as a gap) |
| Counted only | frame, dots at the taps | slash noteheads: rhythm with no pitch |
| Partly named | the piece's line, as the Journal says it | names, and slashes where unnamed |
| Named | the piece's line | chord symbols, note names, or tab |
| Tagged 🧩 by hand, no piece saved | frame with 🧩 | nothing |

- **No badge, no tier, no "done" colour, no percentage.** Indigo and Teal are lane colours only. The
  difference between counted and named is visible because the names are there or they aren't.
- **The piece's line is `PieceTranscription.summary`**, so a long unnamed run reads *(12 unnamed)* on
  the board exactly as it does in the Journal (0227 D7's count rule).

### D5 — Bars, or seconds

- **Bars come from the song's beat grid** when it has one (a tempo and a 1) **and** its gridlines are
  on. Bars are numbered from the first downbeat in the song.
- **The switch is the song's existing gridlines switch** (`showsGridlines`, ADR 0051), shown beside
  the song's facts as a **Bars** chip: the waveform's **Grid** chip, under the map's word for it. A
  player who hid the grid on the waveform because it's wrong doesn't want bars drawn from it anywhere
  else, and one switch can't disagree with itself.
- **Without a grid, the map draws seconds.** Nothing is guessed.

### D6 — Sections are declared, on the marker

- **`Marker.startsSection`**, a Bool defaulting to `false`. Only the player sets it. Markers without it
  stay as pins.
- **The switch is on the marker sheet**, reached as it always was from the waveform's Markers panel, and
  from the map by tapping a section heading or a pin.
- The stretch before the first section, when there is one, is headed *Start*.

### D7 — The unprepared song

- **The map works with nothing prepared.** No grid: seconds (D5). No sections: one continuous strip. The
  first loop is enough for something to appear.
- **Without a grid, the Tab view says so once**: *Set the tempo and the 1 to see bars*, opening the song on
  the waveform where **Set the 1** already lives. The map has no tempo flow of its own.
- **Sections are suggested only from the player's own words, never from the audio.** A song with markers
  and no sections offers, once, *Use your markers as sections?*: every marker in a list, those whose labels
  read as a section (Intro, Verse, Pre-chorus, Chorus, Bridge, Solo, Break, Outro) ticked. Nothing changes
  until the player confirms. Detecting sections from the audio would break the same line as detecting
  notes (0225 D10): next to the player's own map, an estimate becomes a quiz.

Settled in the build (slice 3, 2026-09-29):

- **The offer is a card at the top of the map**, on a song that has markers and no section. *Choose
  sections* opens the list, and *Use* switches on **Starts a section** for the ticked markers. *Cancel*
  changes nothing and leaves the card. *Not now* puts it away.
- **"Once" means answered once, either way.** Using the markers or *Not now* records the song (by its
  `sourceID`) on the device, and the card doesn't come back, even if every section is later switched
  off. It's kept in `AppSettings`, not on the song: it's where the screen has got to, not the player's
  music, so a backup doesn't carry it and a restored song may be offered again, once.
- **A label reads as a section when any whole word of it is a section word** (`SectionWords`):
  *Verse 2*, *Chorus x2* and *Guitar solo* are ticked; *Breakdown* and *Tricky bend* are not.
  *Pre-chorus* is folded to one word first.

### D8 — "Same as", at section level

- **`Marker.sameAsUID`**, an optional UUID naming an earlier section's marker: *Verse 2, as Verse 1*. The
  player's declaration, set on the marker sheet when the marker starts a section.
- **Drawn as a label across the section, not as copied pieces.** That's how a chart writes a repeat, and
  it doesn't need the two sections to be the same length. Pieces worked out inside the section still show:
  a variation beats "same as".
- **Only an earlier section can be picked**, so there are no cycles. A chain (Verse 3 as Verse 2 as Verse
  1) reads as the first. If the named marker is deleted or stops starting a section, the section reads
  plain.

Settled in the build (slice 3, 2026-09-29):

- **The marker sheet's *Same as*** is a picker under **Starts a section**, shown only while the switch is
  on and there's an earlier section to pick. A marker saved with the switch off lets go of its *same as*.
  A section it names that has since moved later, or stopped starting one, shows as *None*.
- **On the board, the heading reads *↻ as Verse 1***, and tapping it goes to Verse 1. The section's own
  rows are drawn as usual, so *Make a piece here* still works inside it.
- ~~**In the Tab view, a "same as" section with nothing of its own is its heading alone**: no empty rows
  under *as Verse 1*, as a chart writes it. One with a piece of its own draws its rows.~~ *Replaced by
  D19 (slice 3b): the tab writes the earlier section's bars out under the heading. With nothing to
  write, it's still the heading alone.*
- A chain broken part way reads as its last good link: Verse 3 as Verse 2, when Verse 2 names a marker
  that's gone.

### D9 — Make a piece here

- **Tapping a gap in a lane offers *Make a piece here*.** It makes a loop that fills the gap exactly,
  from the neighbour before to the neighbour after, bounded by the section.
- The loop is named after its section and lane (*Chorus chords*, *Chorus notes*), typed *Chords* in the
  chords lane, and renamed like any loop.

Settled in the build (slice 3, 2026-09-29):

- **A gap is a stretch of the layer with no piece and no repeat (D14) on it**, whichever lane they're
  in. It's offered on the layer's first lane, with a faint **+** where it starts, and a stretch shorter
  than a second isn't offered: that's the sliver between two loops whose edges nearly meet.
- **Without sections, a gap is bounded by the row tapped**, not the whole song. A song with no sections
  would otherwise offer one loop the length of the song. (Found on Tomisin's own song, which had none.)
- **Outside a named section, the loop is named by where it is**: *Chords, bars 9–12*, or its times in
  seconds scale. That covers *Start* and an unnamed section too. A name the song already has gets a
  number (*Verse chords 2*).
- **The offer is a confirmation**, saying where the loop will go. The new loop plays at full speed and is
  drawn heavier for a moment so you can see where it landed. It's an empty piece until it's counted.

### D10 — The Tab view is drawn, never authored

- **Pieces | Tab are two views of one layout.** Tab has no edit control. To change a bar,
  re-solve its piece (0225 D10: edit pieces, never the picture).
- Per section, rows of 4 bars (8 seconds without a grid). Chord symbols sit at their taps. Notes read as
  names, or as tab when fretted, from the tuning the piece recorded. Unnamed taps are slashes. A "same as"
  section reads *as Verse 1*.
- **Tapping a row goes to the pieces that drew it**, on the board.

Settled in the build (slice 2, 2026-09-28):

- **A line per lane, not one merged line.** The Tab view keeps the board's lanes, so two overlapping licks
  are two lines of tab rather than one line claiming both. A lane with no taps in a row has no line there.
- **In the chords layer every tap is a symbol**, a shape on the neck included: a chord chart doesn't write
  grips. In the notes layer a tap placed on the neck is tab (`TabLine.cell`, with the join written in front,
  `h7`), and a name given by ear sits above the strings.
- **Nothing overprints, and nothing is snapped.** A column sits just after its tap. One that would print
  over the one before is pushed just clear of it. A row whose taps can't all fit draws wider and scrolls
  sideways, rather than being squeezed until the numbers overlap. Spacing is worked out in characters,
  because tab is set in a fixed-width font.
- **The way back is the board row the tab row starts in**, with its pieces drawn heavier for two seconds.
  Pieces | Tab is pinned under the title, so the other view is one tap away from anywhere.
- **The no-grid line goes to the waveform from either door** (D7). From the practice screen, closing
  Song details is the whole trip. From the library, the song's waveform opens once Song details has closed.

### D11 — Put it together

Select pieces on the board and **Put it together** makes a routine, in one of two shapes:

- **In a row**: neighbouring pieces become a progressive-part routine (A, B, A+B, …).
- **A line over its chords**: a notes piece with the chords piece under it becomes the line played over
  the chord loop as its backing (ADR 0135).

The routine builder's own rules (0127) apply, and the routine is whatever a routine is at the time: this
ADR doesn't change what's free.

Settled before the build (slice 4, 2026-09-30). Tomisin agreed the three open questions as suggested:
ask for a missing command tempo, make the joined stretches as loops, and switch on the backing.

- **Selecting starts from a piece.** Its hold menu has **Put it together…**, which starts a selection
  with that piece in it. While selecting, tapping a piece or its repeats adds or removes that loop, and
  nothing else on the board responds. A bar along the bottom says what the selection makes, or why it
  can't be put together, with **Put it together** and **Cancel**. The board has no header to hold (0125's
  way in), and a nav bar button would change width between *Select* and *Cancel* (0126).
- **The shape follows from what's selected**, so there's nothing to choose:
  - **In a row**: two or more pieces on one layer, each starting and ending later than the one before,
    overlapping it by a second at most, so a loop drawn a hair long still counts. A gap between them is
    allowed, and the joined stretches play it.
  - **A line over its chords**: one piece on each layer, with the chords piece, or its repeats, playing
    under the whole line, give or take a second at either end.
  - Anything else says why: pieces in a row can't overlap; the chords have to play under the whole line;
    pick pieces on one layer, or a line and its chords.
- **In a row runs A, B, A to B, C, A to C…**: each piece, then the stretch from the first piece to it, each
  a Practice block with the speed ramp. The stretches are loops Put it together makes, from the first
  piece's start to the last one's end, named *Verse notes to Verse notes 2* and typed as the pieces are.
  **A joined loop holds no piece of its own.** Its parts hold the notes, and a copy would write them twice
  in the tab (D10). It sits on the map on a lane of its own, under the pieces it joins.
- **A line over its chords runs the line, then the chords as a backing**: the line as a Practice block,
  then the chord loop as an Improvise block (ADR 0135). **The chord loop's Backing track switch is turned
  on**, because choosing this shape says that's what it's for. The backing is the record at those bars,
  the original line included: it's playing along in context, not a clean track. A short vamp going round
  under a longer line brings the line's opening round with it, a limit of backing with the record.
- **A Practice block needs a command tempo (ADR 0138), so Put it together asks once** for any piece that
  has none: *How fast can you play these now?*, one row per piece in 5% steps, each starting where the loop
  edit sheet's **Set** would. The answer is saved on the loop, as if set there. A joined loop starts at
  the slowest of its parts' command tempos, and the slowest of their speeds.
- **A backing with no command tempo is asked for too**: *How fast should the backing play?*, starting at
  the line's command tempo, or moving with the line's row until it's set on its own. The Improvise block
  opens at the backing's command tempo, else the record's speed (ADR 0135), and the answer is saved on
  the chord loop as its command tempo, as the line's is.
- **The routine opens for review**, as *Build a routine for this song* does (ADR 0111), and nothing lands
  in Routines until **Save**. It's named after the song and the pieces (*Slow Bend: Intro lick over
  Intro chords*), and each block runs at its loop's own length, as a block added by hand does.
- **Undo (D17) takes back the joined loops**, which are made when Put it together is tapped. Back on the
  map, *Made Verse notes to Verse notes 2 · Undo* offers it while no saved routine uses them. Once a
  saved routine does, they're its blocks, and there's no Undo. The command tempos and the backing
  switch stay either way: they're what the player said about their loops.
- **Behind Routines' own gate** (ADR 0144), the one *Build a routine for this song* uses.

Settled in the build (slice 4, 2026-09-30):

- **Of two loops that start together, the shorter now takes the first lane.** Slice 1 gave it to the
  longer, for no reason beyond laying the same loops out the same way each time. A joined loop starts
  with its first part and is longer, so under that rule it pushed the pieces it joins down a lane (found
  in a render). A board with two loops starting together has them the other way round from now on.
- **The joined loops are made in the map's own context, when Put it together is tapped.** The review
  builds its routine in a context of its own, and a loop saved there doesn't reach the map's copy of
  the song until the map is opened again. Made on the map, they're drawn straight away, and Undo can take
  them back.
- **Cancelling the tempo question goes back to the picked pieces**, still picked.
- **The chords have to play under the whole line, and the backing is asked for** (after the build,
  2026-09-30). Tomisin agreed both on going over the backing. The first rule asked only that the chords
  play under *some* of the line, which let through chords stopping partway, with the rest of the line
  landing on the wrong ones as the backing went round. And only the line was asked for, so a line
  practised up to 80% was followed by a backing opening at the record's speed.

### D12 — Export, not hosting, and not yet

- **No share action on the map.** The pieces already travel in the whole-archive export (ADR 0181), so
  nothing is locked in, and the map doesn't wait on legal advice.
- **The song's tab is a narrower case than a take.** It holds no audio, so ADR 0150's speaker-bleed question (a
  commercial master in the file) doesn't arise. What remains is the composition, the ground tab sites
  have contested with publishers. So an **Export tab** (text or PDF, one song, the share sheet) joins
  0150's questions for the same legal review. It doesn't open a new one.
- **Never:** hosting tabs, a shared tab library, or **importing** a tab. Importing is ruled out by
  design as well as rights: a tab you didn't draw from your own pieces breaks D10.
- **Never inside a `.redmoonpractice` file.** That file carries no song titles on purpose (ADR 0161), and
  a tab without its song's title is useless.

### D13 — The name

- **Map the song** is the row in Song details, following the app's verb-phrase names (*Count the notes*,
  *Name the notes*, *Train your ear*).
- The screen is titled with the song's title, with **Pieces | Tab** under it. *Chart* was the working
  name. A guitarist looks for *tab*, and a song whose pieces are all chords still reads as its tab.
- *Piece it together* was the runner-up. It sits too close to *Put it together*, the map's own action.

### D14 — A loop that repeats to the end of its section

*Added 2026-09-28, while agreeing slice 3.* Tomisin asked: what if the song is one progression looped
over and over? D8 repeats a whole section. This repeats one loop within a section.

- **`Loop.repeatsToSectionEnd`**, a Bool defaulting to `false`: one progression, worked out once, that
  its section plays over and over. The player's declaration, set from the piece's hold menu as **Repeats to
  the end of the section** (*…of the song* when the song has no sections). **Never detected, and never
  copies**: copies would draw as pieces worked out that weren't, and a change to the first wouldn't carry
  to them (D10: edit pieces, never the picture).
- **Its section is the one holding the loop's middle**, so a loop dragged to start a beat early still
  belongs to the section it plays in. Without sections, it repeats to the song's end.
- **On the board, a lighter band runs from the loop's end to its section's end**, marked **↻ ×N**. N counts
  the passes including the one worked out, to the nearest whole pass. The band still runs to the section's
  end, because that's what the player said. Tapping it opens the loop's tab, and holding it gives the
  loop's menu.
- **Offered only with room for half a pass more**, so there's something to draw. Once on, it stays in the
  menu, as a checked item, so it can be switched off wherever the section's edge has moved to.
- **The repeats hold their lane.** A piece worked out later in the section (a turnaround, a variation)
  takes the next lane down rather than being drawn over them, and the stretch they cover isn't a gap (D9).
- ~~**In the Tab view the taps are written once**, and the stretch the loop repeats over reads **↻ Verse
  changes ×8**, with the count said once, where the repeats begin. It's a chart's repeat sign, in words.~~
  *Replaced by D18 (slice 3b): the tab writes every pass out, with **↻ ×8** where the repeats begin.*

*Slice 3b (2026-09-29):* repeats can now run past their section (D15). "Never copies" still holds for
repeats; copying is a separate act the player asks for (D16).

### D15 — How far a repeat runs

*Added 2026-09-29, from Tomisin's device test.* On their song, the intro's chords repeat to the end of the
song, and D14 could only take them to the end of the intro.

- **`Loop.repeatsTo`**, an optional String read only while `repeatsToSectionEnd` is on: `nil` for the
  loop's own section (D14's reach, so every loop saved before this reads as it did), `"song"`, or the uid
  of the marker starting a later section it repeats on through. A String, never the enum
  (`SongMap.RepeatsTo`), per ADR 0189. `repeatsToSectionEnd` stays the switch: removing or renaming it
  would be the unsafe kind of migration.
- **The hold menu offers each reach that has room for half a pass more**, nearest first: *To the end of
  the section*, *Through* each later section but the last, and *To the end of the song*. There's one
  item, as in D14, when there's only one way, and a *Repeats* menu with *Doesn't repeat* when there are
  several. Two sections with one name are told apart by where they start (*Through Chorus, bar 21*). A
  loop that fills its section can still repeat on through the next.
- **A reach reads as what it reaches now.** A section that's gone, or that no longer ends after the
  loop's own, reads as its own section. Through the last section is the end of the song.
- **The band runs across section headings**, holding its lane all the way, and the stretch it covers
  isn't a gap (D9). The Tab view writes it out in each row it crosses (D18). The tab sheet says how far:
  *Repeats through Chorus, 6 times in all*.

### D16 — Copy a piece

*Added 2026-09-29, from the same test.* Tomisin asked to use a counted piece, chords or notes, for another
section or run of bars, rather than counting the same changes again.

- **Copying is the player's act, never suggested.** *Copy to…* is on a counted piece's hold menu and its
  tab sheet. It lists the song's sections, or the board's rows when it has none, and **Choose bars** when
  the map has bars. Tap **+** in a gap and, beside *Make a piece here*, each piece counted on that lane
  offers *Copy X here*.
- **Each place gets a loop of its own**, the length of the place, named as *Make a piece here* names one
  (*Chorus chords*), typed as its source, at full speed. Its piece is the source's taps written across it
  pass after pass from where it starts, each tap as far into a pass as it was into the loop. With bars, a
  pass is the loop's length to the nearest whole bar, so passes keep to the bar though the loop was drawn a
  hair long or short. Only one pass's taps are written each time, so a tap is never written twice. Nothing
  is snapped. The tuning comes with it.
- **A copy is not a link.** Change the first and the copies stay as they were. That's D14's reason for
  never copying repeats, and it stands for repeats. Copying is for when the notes should be written out
  where they play: to practise that section on its own, or to change a bar of it. The sheet says so.
- **A place with a piece already on that lane says so** (*Already has Verse chords*), and the copy takes
  a lane of its own beside it. Nothing is written over.
- **A copy is a piece in the Journal** like any other (ADR 0229), because it is one.

### D17 — The map adds; it never deletes

*Added 2026-09-29.* Tomisin first asked to delete a loop from the map, then chose Undo instead, so the
loops made on the waveform are protected.

- **What the map makes, Undo takes back**: *Made Chorus chords · Undo* after *Make a piece here*, and
  *Made 3 copies of Verse changes · Undo* after a copy, which takes back all of them. Undo removes those
  loops and nothing else.
- **The Undo lasts until the player does something else**: opens a piece, a marker or a gap, or sets a
  repeat. Otherwise it goes after six seconds. A loop opened and counted is no longer new, and isn't
  removed from here.
- **No delete on the map.** Deleting a loop stays on the waveform, where the loop is drawn and its
  delete has an Undo of its own (ADR 0019). No practice-screen seam is needed, since the map never
  removes a loop the waveform might be holding.

### D18 — The tab writes a repeat out

*Added 2026-09-29, from the second device test.* Replaces D14's last bullet. With the intro's chords
repeating to the end of the song, every row of Verse 1 read *↻ Chords* and nothing else. Tomisin: "a user
doesn't gain anything by just seeing the name". The tab is for reading what plays in each bar, and a
label sends the reader back to the intro to find out.

- **Every pass is written out**, each tap as far into its pass as it is into the loop, for as long as
  the repeats run. A last pass cut short by the section's end is written as far as it gets.
- **Drawn, never copied** (D10). Each pass is drawn from the one piece, every time, so a change to it
  changes every pass. Nothing is stored, and D14's reason for never copying repeats still stands.
- **↻ ×8 where the repeats begin**, in front of the tap it shares a time with. It's the count, said once,
  and the sign that these bars are the same loop. Tapping any of them goes to that loop on the board.
- **The board keeps its band.** The board shows pieces and where they sit; the tab shows the song.
- **A tap on a loop's start is written though the start reads back a hair after it.** A copy's first
  tap sits exactly on its start (D16), and a start stored as a fraction of the song can read back a
  hair late, so the tab reads the start within `SongMapLayout.tolerance`. Found while building this.

### D19 — The tab writes a "same as" section out

*Added 2026-09-30.* Replaces D8's Tab view bullet, for the reason D18 gives. Verse 2 *as Verse 1* was
written as a chart writes it, the heading alone, which sent the reader back up to Verse 1 for its chords.
Tomisin chose the other way when shown both.

- **The earlier section's bars are written out under *as Verse 1***, bar for bar: its pieces, their
  repeats and ↻ signs included, each on a line of its own. With bars, they're moved on from the 1 nearest
  the earlier section's start to the 1 nearest this one's, so a marker set a hair off the 1 doesn't move
  every chord. Without bars, they move marker to marker.
- **As far as either section runs.** A shorter section gets as much as fits. A longer one has empty bars
  after the earlier one runs out, and only the earlier section's own stretch is written: a loop that plays
  on from it into the next section brings nothing from there.
- **Drawn, never copied** (D10). It's drawn from the earlier section's pieces every time, so changing
  Verse 1 changes Verse 2. *Copy to…* (D16) is still how to get a copy that can be changed on its own.
- **A variation still shows** (D8). The section's own pieces draw on their own lines, under the written
  lines of their layer. A repeat that plays on through both sections draws in this one as itself, and
  isn't written a second time.
- **Tapping a written row goes to the earlier section on the board**, where its pieces are. A row with a
  piece of its own goes to its own stretch.
- **The board is unchanged.** It still heads the section *↻ as Verse 1* over its own rows, where a
  variation is made.

### D20 — The Journal's Pieces, by song

*Added 2026-09-30, slice 5.* D1 made the Journal's Pieces scope the map's way in from outside the song,
in place of a list in the Toolkit. This is how the scope carries it.

- **Under *Pieces*, the feed is grouped by song, not by day.** A section per song, headed by its title
  and artist with **Map the song** beside them, which opens the map full screen as Song details does. The
  heading stays pinned while its pieces scroll, as a day's does, so the way in stays in reach.
- **Songs run by when their newest piece changed**, so the song being worked on is at the top. *⋯ ▸ Sort*
  turns that round, as it does the days.
- **Within a song, pieces run in song order**, by where each loop starts, the shorter first when two
  start together (as the lanes break that tie). It's the order the map lays them out in and the song
  plays in, and it doesn't change with the sort.
- **Each row says the day it last changed**, where under a day's heading it says the time. Its caption is
  the loop alone, because the song is the heading. Tapping either still opens the loop in *Train your
  ear* (0229 D4).
- ***All* keeps each piece on its day** (0229 D2). Only the Pieces scope changes.
- **No months and no *Jump to…* under *Pieces*:** there are no day sections to land on. The *Show* chip
  stays, because it states the filter in force (0190 D8), and search still narrows the list.
- **A piece whose loop has no song** comes last, under *No song*, with no map to open.
- **The map is opened by its first piece's loop.** `Song` has no `uid`, and a `persistentModelID` can
  change under a save (0090), so the song is reached through a loop that has one.
- **No way to the waveform from here.** Without a tempo, the Tab view says what's missing rather than
  offering *Set the tempo and the 1* (D7), as it does wherever `onShowWaveform` is `nil`.

## Build order

1. **The board.** `Marker.startsSection` with its switch and archive field; `SongMapLayout` (pure:
   sections, rows, lanes, gaps, what each piece holds); the Pieces view; *Map the song* in Song details;
   bars or seconds. Tapping a heading or pin opens the marker.
   **1b. A loop's tab** (D2): tapping a piece opens its tab sheet; holding it offers *View tab* and the
   modes it can open in.
2. **The Tab view** (D10), including the no-grid line (D7).
3. **The unprepared song and repeats**: *Use your markers as sections?* (D7), *Make a piece here* (D9),
   `Marker.sameAsUID` (D8), and `Loop.repeatsToSectionEnd` (D14).
   **3b. Reach, copies and Undo**, from the first device test: how far a repeat runs (D15), *Copy to…*
   and *Copy X here* (D16), and Undo for what the map makes (D17). From the second, the tab writes a
   repeat out (D18), and a "same as" section too (D19).
4. **Put it together** (D11): selecting on the board, the two shapes, the command tempo it asks for,
   the joined loops and their Undo, and the routine opened for review.
5. **The Journal's Pieces scope, grouped by song** (D1, D20).

Each slice ships on its own: slice 1 is useful without the Tab view, since a song's loops laid out by
section, with what each holds, is already more than any screen shows today.

## What stays out

Anything past this needs a new ADR:

- **Editing the tab**, or any tab text stored apart from the pieces.
- **A percentage, a score, or anything counted over time** (ADR 0070, 0225 D9).
- **Detected or suggested notes, chords, sections or tempo** (0225 D10, 0092 §A4).
- **Snapping pieces or taps** to the grid.
- **Sharing the song's tab**, until 0150's questions are answered (D12).

## Consequences

- **Three schema additions beyond the one the design note planned** are taken up: D8's, D14's and D15's.
  All four are additive under ADR 0189's criteria, and all four must be **optional in the archive**
  (`decodeIfPresent`): a Codable default does not survive a missing key, and an archive made before this
  would fail to restore as a whole.
- **One thing is kept on the device, not in the backup**: which songs have been offered *Use your
  markers as sections?* (D7).
- **The gridlines switch now governs two surfaces** (D5). Its help text and the manual say so.
- **The map is the reader 0225 D8 named**, so the structured piece now has one.
- **The map now writes pieces as well as reading them** (D16). A copy is written once, from a piece the
  player counted, and is theirs to change from then on; nothing keeps it in step with its source.
- **A loop's edges, stored as fractions of the song, read back a hair off** a section's start. The board and the Tab view
  now decide what a row holds within `SongMapLayout.tolerance`, so a copy ending where the next section
  starts doesn't draw a sliver there. Found in a slice 3b render.
- **Manual:** Song details gains a row, the marker sheet gains a switch and a *Same as* picker, and
  there's a new screen (`docs/manual/songs.md`, `looping.md`). Slice 3b adds *Repeats*, *Copy to…* and
  Undo to the map's section of `songs.md`.
