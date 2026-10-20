# ADR 0262 — Muted notes: a ✕ on the neck, or *Muted* by ear

- **Status:** Accepted. Decided with Tomisin, 2026-10-20: three questions, all answered with the
  recommended choice (a dead note, not a palm mute; on the neck and By ear; a ✕ pinned beside the string
  letters). Built on `pocket-374-muted-notes`.
- **Date:** 2026-10-20
- **Amends:** ADR 0227 — **D3**: the neck gains a ✕ per string, pinned beside the string letters.
  **D4**: with Chords on, a ✕ takes a string the way a note does. **D6**: By ear gains *Muted*.
  **D7**: By ear reads a tap that's only ✕s as *Muted*. **D9**: a new `muted` kind and an optional
  `muted` key. **D10**: dead notes can now be named. Palm muting and rakes stay out. The rest of 0227
  stands.
- **Relates to:** 0225 D6 (an unknown kind reads as unnamed, which is what an older build does with this
  one) · 0234 D3 (placing moves on, and so does a ✕) · 0230 and 0252 (lead-ins, which read only the
  fretted notes) · 0235 D9–D10 (the tab writer shares the neck editor, so a written tab gets the ✕ too,
  with the same limits) · 0232 D3 and D10 (the song map's layers and its Tab view) · 0254 (Watch it on
  the neck, where a heard ✕ lights) · 0095 (My chords, where ✕ means *not played*, see D2) · 0070
  (never grades).
- **Schema:** none. The label gains a kind and an optional key inside the versioned JSON
  (`Loop.transcriptionData`, `WrittenTab`) (D5).

## Context

*Name the notes* names each tap of a pass. A tap can be a note on the neck, a shape, a note name or a
chord. But a lot of real guitar parts are full of **dead notes**: the chuck on 2 and 4 of a strummed
part, the scratches between funk stabs, the muted click before a riff lands. Each one is a tap, since
it's heard in time and counted (0225). There was nothing to name it as, so it stayed a `?`. It counted as
*left to name*, *Next unnamed* kept stopping on it, and a fully transcribed part looked unfinished.

0227 D10 kept "harmonics, tapping, palm muting, rakes" out and said anything past it needs a new ADR. Dead
notes weren't in that list, but they weren't sayable either. This record adds them.

## Decision

### D1 — A muted note is a dead note, and it's an answer

A **muted note** is struck while the fretting hand rests on the string. It's a click with no pitch, and
tab writes it `x`. It is not a **palm mute**, which is damped by the picking hand but still sounds a pitch.
Palm muting stays out (D6).

A muted tap is **named**. It isn't counted as *unnamed*, *Next unnamed* skips it, and the piece's
summary says it.

### D2 — On the neck: a ✕ per string, pinned beside the letters

Each string gets a **✕ spot** in a column pinned between the string letters and the board. It stays in
view at any fret, because the board scrolls and the column doesn't. A ✕ is tapped like any other spot:

- **Chords off:** a ✕ makes the answer that string muted, and **moves on**, silently, as placing a note
  does (0234 D3). Tapping the ✕ already there confirms it and moves on.
- **Chords on:** one entry per string, as for notes. A ✕ on an empty string adds it. A ✕ on a string that
  holds a note replaces the note. A ✕ already there comes out, unless it's all the tap holds. A fret tapped
  on a muted string puts that string back on the neck. A chuck across four strings and a chord strummed
  through a muted string use the same gesture as any chord.
- **No marks on a ✕.** Bend and vibrato go on fretted notes only. A tap that's only ✕s has no *Into it*
  (*A muted note has no way in*), and a ✕ can't be the tap before a join. In a chord, joins and lead-ins
  read the fretted notes and the ✕ strings ride along, so a 9th chord sliding a fret with its muted
  strings still slides.
- **Drawn as the neighbours are** (0234 D4): the ✕ of the tap being named is solid, those of the three
  taps either side are filled or ringed and numbered, and where several taps mute one string, the nearest
  is drawn. While the loop plays, a heard ✕ lights.

**✕ means something different here from My chords.** Above a string in My chords (0095), ✕ means *not
played*. On this neck a string that isn't played just has nothing on it, and ✕ means *struck, muted*,
which is what tab's `x` means. The Chords ⓘ says so.

The scales editor's draw-your-own board shares the neck (0227 D3) and gets no ✕ column. Its dots are
scale notes, and a scale has no dead notes.

### D3 — By ear: *Muted*

A **Muted** button sits under the twelve note names. It's for a click you can hear but can't place,
which in a full mix is most of them. Like a name, it **saves and moves on**. It has no root, so the
selected kind doesn't change, and tapping a kind while the answer is *Muted* does nothing.

By ear reads the neck (0227 D7): a tap that's only ✕s reads as *Muted*, outlined. A chord with ✕
strings reads as its chord, because the ✕s add no pitch. **Only overwriting neck work asks first.**
*Muted* over a placed note or shape asks. Over a tap that's only ✕s, it keeps the neck's answer and
moves on, since that's what the neck already reads.

### D4 — How it reads

- **Names** (the line under *Saved on this loop*, the Journal, By ear's strip): `✕`. *"8 notes. A C ✕ ✕
  D"*. A chord with ✕ strings reads as its chord.
- **Fret & string chips** and the neck's lines say a ✕ by its string, the way they say a note: `B✕`,
  `A✕·D5·G5`.
- **Tab** writes `x` on each muted string in the tap's column (the tab under the neck, the reading view,
  the song's Tab view). A join between two chords is written only on the strings it joins, never on an
  `x`. A *Muted* named by ear has no string, so the reading view and the song's Tab view write `x` above
  the strings, where a name given by ear goes. Fixed-width text gets ASCII `x`, never `✕`, so columns
  stay aligned.
- **Counting chords.** A piece whose every answer is a chord counts chords (0225), and it goes in the
  song map's chords layer (0232 D3). Muted taps **don't count against that**. A strummed part of chords
  and chucks is still *"6 chords"* and still in the chords layer, as long as at least one answer is a
  chord.
- **Watch it on the neck** (0254) lights a heard ✕ in its pinned column and says it: *"B string,
  muted"*, *"Muted, 3 strings"*, *"Muted, named by ear"*.
- **VoiceOver** says *muted*, never "multiplication x".

### D5 — Storage (amends 0227 D9)

Inside the versioned JSON, with no schema change and no version bump:

- **By ear:** a new kind, `{"kind": "muted"}`.
- **On the neck, only ✕s:** the same kind with its strings, `{"kind": "muted", "strings": [4, 5]}`.
- **With fretted notes:** the `fret` or `shape` kind gains an optional `muted` key, `{"kind": "shape",
  "notes": […], "muted": [0, 5]}`. A shape is still two or more fretted notes. One fretted note with ✕s
  beside it is a `fret`.
- **A string is fretted or muted, never both.** On decode, a muted string that also holds a note is
  dropped and the note wins. So is a string number below zero.
- **Older builds.** A `muted` kind is one they've never heard of, so the tap reads as **unnamed** (0225
  D6). A ✕ read as anything else would be a wrong answer. A `muted` key on a `fret` or `shape` is
  dropped and the notes that sound are still right, as a note without its bend is still where it was
  played (0227 D9).

In Swift, the by-ear answer is `PieceLabel.muted` and a muted string on the neck rides in
`.fretted(notes, muted:, into:)`, with an empty `notes` for a tap that's only ✕s. The muted strings are a
separate value, not a kind of `FrettedNote`. Every rule that reads `notes` (pitch, joins, lead-ins,
bends) keeps reading only what sounds, and the compiler points to every match on `.fretted` that has to
carry the strings through.

### D6 — What stays out

- **Palm muting** (`P.M.`). Still out, as 0227 D10 says.
- **Rakes.** A run of muted strings into a note, heard as one, stays out. Each ✕ heard on its own can be
  tapped and named.
- **A fret for a ✕.** Tab doesn't write one, and a dead note sounds no pitch, so where the hand rested
  isn't recorded.
- **A run of ✕s said as a count.** *(12 unnamed)* stays the only run the line shortens.
- **Never detected, never suggested.** Every ✕ is the player's.

## Build order

One branch, in commits that each stand alone:

1. This record.
2. **The label**: the kind, the key, coding, and every pure reader (names, ear reading, tab, the reading
   view, the song's Tab view, joins, the editing rules, the counts), with unit tests.
3. **The neck's ✕ column**, in Name the notes and the tab writer, and in *Watch it on the neck*.
4. **By ear's *Muted***.
5. The manual, the changelog and the project docs.

## Consequences

- **Pure and unit-tested:** encode and decode of every shape of muted answer, the older-build reading
  (the kind unknown, the key dropped), the fretted-or-muted rule, the ✕ placement rules with Chords on
  and off, joins and lead-ins ignoring ✕ strings, a ✕ blocking a join from it, the tab's `x` cells and
  its joins, the names line, the chord count and the map layer.
- **The board gains an optional pinned column** (`FretNeckBoard`). The exercise editor passes none, so its
  board is unchanged. It's rechecked by eye.
- **The manual** (`docs/manual/reference/practice.md`, *Name the notes*) gains the ✕ and *Muted*. The
  Name the notes figures are owed to the reshoot, because the neck has a new column and By ear a new
  button.
- **Owed on a device:** a 30-point ✕ beside the letters on the smallest phone without crowding the
  board; a ✕ tapped while the loop plays.
