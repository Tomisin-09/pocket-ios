# The song map — parked design note

**Status:** parked 2026-09-27, for a future update aimed at existing players. Not an ADR, not scheduled.
**Mockup:** https://claude.ai/artifact/B9cjgdgZDxNfy6J2R5uqPU
**Depends on:** ADR 0225 (Count the notes), which already stores everything the map reads.

## The idea

Tomisin's analogy: transcribing a song's loops is a **jigsaw**. Each loop you've worked out is a solved
piece. **Your own chart of the song is the finished picture.** The map is the board you put the pieces on:
the song's length laid out left to right, your loops placed where they sit, and the chart drawn from them.

It's the kind of thing existing players would appreciate, which is why it's parked rather than dropped:
everything a player transcribes from ADR 0225 onward is on the map the day it ships.

## Decided

- **Two views of one layout.** *Pieces* is the jigsaw board; *Chart* is the finished picture. **The chart
  is derived, never authored.** Tap a bar and it takes you to its piece. To change a bar, re-solve its
  piece (ADR 0225 D10: edit pieces, never the picture).
- **Lanes by layer**, because melodies play over chords: a **chords** lane (Indigo) and a **notes** lane
  (Teal). Overlapping note pieces get a **second notes lane**, and in the chart a second staff.
- **Section edges come from a `Starts a section` switch on `Marker`.** Additive, and declared by the
  player. Markers without it stay as pins.
- **Gaps are neutral.** No percentage complete, no "73% transcribed". Tapping a gap offers **Make a piece
  here**, which creates a loop filling the gap between its neighbours exactly (`createLoop`).
- **Put it together** has two shapes:
  - neighbouring pieces become a progressive-part routine (A, B, A+B…);
  - a line plus the chords under it becomes "a line over its chords", with the chord loop as the backing
    (ADR 0135's backing-track idea).
- **Chord pieces are named by chord** (ADR 0225's `.chord` label).
- **Bars come from the song's beat grid.** Loops are drawn where they are, never snapped. One tempo per
  song is the known limit (ADR 0154 anchors). **Anything drawn from the grid is switchable, with a
  seconds-based fallback**, because the grid can be wrong (the same principle as Show beats, 0225 D4).

## Stored vs drawn

| Stored | Where | Since |
|---|---|---|
| Loops (start, end, type) | `Loop` | always |
| Each piece: taps in song seconds, and what each was named | `Loop.transcriptionData` → `PieceTranscription` | ADR 0225 |
| Which loops are solved | The loop's saved piece (`Loop.transcription`), plus notes tagged 🧩 *Transcribed* by hand (the player's declaration) | ADR 0225, 0229 |
| Which markers start a section | **new:** a `Starts a section` Bool on `Marker` | the map's ADR |

**Everything else is drawn**, including the plain-text export of the chart. The only schema addition the
map needs is the marker switch (plus a section-level "same as", if that's taken up). Loops are fractions
of the song and taps are seconds, so the board needs no other data.

## Still open

- **Where it lives.** A secondary view off the song, or the song's new home. Either way, keep the iPad's
  second column in mind (Directions 2026-09, iPad B).
- **The unprepared song**: no tempo, no sections. And whether to *suggest* sections as a starting point.
  Anything suggested is never committed automatically.
- **Repeats at section level**: "Verse 2 — as Verse 1", a section-level "same as".
- **Decoded vs owned on the board**: how a piece named only by count differs from one fully named.
- **Export vs hosting**: sharing a chart meets the ADR 0150 hinge. Export is the player's; hosting
  someone's transcription of a commercial song is not something we do.
- **The name.**

## Don't re-propose

- Editing the chart directly (it's derived; see above).
- A percentage complete, or any completion score (ADR 0070, 0225 D9).
- Detected or suggested notes (ADR 0225 D10, ADR 0092 §A4).
