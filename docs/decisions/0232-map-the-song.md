# ADR 0232 — Map the song: a song's loops laid out as pieces, and the tab drawn from them

- **Status:** Accepted. Building on `pocket-339-map-the-song`, in the slices of the build order.
- **Date:** 2026-09-28
- **Relates to:** 0225 D8 (the piece is stored structured because this is its reader) · 0227 D7 (one
  answer per tap, read one way: what makes a label a chord) · 0229 (the Journal's Pieces scope, and
  which loops count as solved) · 0011 (markers) · 0022/0154 (the beat grid, one tempo per song) · 0051
  (the per-song gridlines switch) · 0135 (a loop as a backing track) · 0150 and 0161 (export, not
  hosting; the practice file carries no song titles) · 0070 and 0225 D9 (no completion score) · 0092 §A4
  and 0225 D10 (never detected, never suggested).
- **Schema:** two additive fields on `Marker`: `startsSection` (D6, slice 1) and `sameAsUID` (D8,
  slice 3). Both are Optional or defaulted, and both are optional in the archive's `MarkerRecord`.
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

### D8 — "Same as", at section level

- **`Marker.sameAsUID`**, an optional UUID naming an earlier section's marker: *Verse 2, as Verse 1*. The
  player's declaration, set on the marker sheet when the marker starts a section.
- **Drawn as a label across the section, not as copied pieces.** That's how a chart writes a repeat, and
  it doesn't need the two sections to be the same length. Pieces worked out inside the section still show:
  a variation beats "same as".
- **Only an earlier section can be picked**, so there are no cycles. A chain (Verse 3 as Verse 2 as Verse
  1) reads as the first. If the named marker is deleted or stops starting a section, the section reads
  plain.

### D9 — Make a piece here

- **Tapping a gap in a lane offers *Make a piece here*.** It makes a loop that fills the gap exactly,
  from the neighbour before to the neighbour after, bounded by the section.
- The loop is named after its section and lane (*Chorus chords*, *Chorus notes*), typed *Chords* in the
  chords lane, and renamed like any loop.

### D10 — The Tab view is drawn, never authored

- **Pieces | Tab are two views of one layout.** Tab has no edit control. To change a bar,
  re-solve its piece (0225 D10: edit pieces, never the picture).
- Per section, rows of 4 bars (8 seconds without a grid). Chord symbols sit at their taps. Notes read as
  names, or as tab when fretted, from the tuning the piece recorded. Unnamed taps are slashes. A "same as"
  section reads *as Verse 1*.
- **Tapping a row goes to the pieces that drew it**, on the board.

### D11 — Put it together

Select pieces on the board and **Put it together** makes a routine, in one of two shapes:

- **In a row**: neighbouring pieces become a progressive-part routine (A, B, A+B, …).
- **A line over its chords**: a notes piece with the chords piece under it becomes the line played over
  the chord loop as its backing (ADR 0135).

The routine builder's own rules (0127) apply, and the routine is whatever a routine is at the time: this
ADR doesn't change what's free.

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

## Build order

1. **The board.** `Marker.startsSection` with its switch and archive field; `SongMapLayout` (pure:
   sections, rows, lanes, gaps, what each piece holds); the Pieces view; *Map the song* in Song details;
   bars or seconds. Tapping a heading or pin opens the marker.
   **1b. A loop's tab** (D2): tapping a piece opens its tab sheet; holding it offers *View tab* and the
   modes it can open in.
2. **The Tab view** (D10), including the no-grid line (D7).
3. **The unprepared song and repeats**: *Use your markers as sections?* (D7), *Make a piece here* (D9),
   and `Marker.sameAsUID` (D8).
4. **Put it together** (D11).
5. **The Journal's Pieces scope, grouped by song** (D1).

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

- **A second schema addition** is taken up (D8) beyond the one the design note planned. Both are
  additive under ADR 0189's criteria, and both must be **optional in the archive** (`decodeIfPresent`): a
  Codable default does not survive a missing key, and an archive made before this would fail to restore
  as a whole.
- **The gridlines switch now governs two surfaces** (D5). Its help text and the manual say so.
- **The map is the reader 0225 D8 named**, so the structured piece now has one.
- **Manual:** Song details gains a row, the marker sheet gains a switch, and there's a new screen
  (`docs/manual/songs.md`, `looping.md`).
