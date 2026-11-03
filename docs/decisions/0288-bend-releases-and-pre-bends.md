# ADR 0288 — Bend releases and pre-bends

- **Status:** Accepted. Planned with Tomisin as item 17 of the last feature push before 1.4 (backlog,
  2026-11-03), and built that week.
- **Date:** 2026-11-04 (`pocket-409-pre-bends`)
- **Amends:** ADR 0227 — **D5**: a bend gains two switches, *Pre-bend* and *Release*, so it has four
  shapes, each drawn on the neck and written in the tab (`7b9`, `7b9r7`, `7pb9`, `7pb9r7`). **D9**: a
  released bend keeps its size under a `release` key instead of `bend`, a pre-bend adds `preBend`, and a
  note's pitch is where the bend lands. **D10**: bend releases and pre-bends are lifted. A slide out to
  nowhere (`7\`) still stays out, with the rest of D10.
- **Amends:** ADR 0234 — **D5**: the glow gains two motions. A released bend glides up and back, and a
  pre-bend let down glides down from the bent pitch. A pre-bend held lights where it's heard. The rest
  of D5 stands.
- **Relates to:** 0230 (the lead-in, whose rule this follows: a note that moves inside one tap is named
  by where it lands), 0235 (Write a tab, which takes the same marks from the same editor), 0225 D6 (the
  versioned piece JSON), 0070 (never detected, never suggested)
- **Schema:** none. `Loop.transcriptionData` and `PieceTranscription` stay at version 1. A note gains
  two optional keys inside the JSON (D3).

## Context

ADR 0227 put three bend sizes on a note and left bend releases and pre-bends out (D10), and ADR 0230
kept them out when it lifted the slide in from nowhere. Both are everyday lead-guitar moves: a bend
and release is how a blues lick turns round, and a pre-bend is how a phrase drops into a note from
above. A player naming such a lick could only call the note a plain bend or a plain fret, and either
one was wrong about what they played.

## Decisions

**D1. Four shapes, made from two switches.** Under *Bend*, once a size is chosen, two switches appear:
*Pre-bend* (the string is pushed before it's picked) and *Release* (the bend comes back down to the
fret before the next note). Together they give the four shapes: a bend, a bend and release, a
pre-bend, and a pre-bend and release. Two switches rather than one picker of four, because a bend can
be both, and four labels that long don't fit beside the neck on a phone. Choosing *None* clears both,
so a note with no bend never carries either. Vibrato combines with any of them, as it does with a
bend today.

**D2. A note is named by where it lands.** A bend and a pre-bend land on the bent pitch, so `7b9` and
`7pb9` are both named as fret 9's note. A release lands back on the fret, so `7b9r7` and `7pb9r7` are
both named as fret 7's. This is the rule ADR 0230 set for a lead-in (*one tap that moves between two
pitches, read as the note it lands on*), and By ear, the Journal line, a shape's chord name and
everything else that reads `pitchClass(openMidi:)` follows it. By ear's *Read from the neck* line still
explains a bent name (*", G7 pre-bent a whole step"*). A released bend is named by its own fret, so
there's nothing to explain.

**D3. Stored so an older build names the note right.** A bend stays `{"bend": 2}`. A released bend
keeps its size under **`release`** instead (`{"release": 2}`), and a pre-bend adds `"preBend": true`.
An older build drops keys it doesn't know (0227 D9), so it reads:

| Shape | Stored | An older build reads |
|---|---|---|
| Bend | `bend` | the same bend |
| Bend and release | `release` | fret 7, the note it lands on |
| Pre-bend | `bend`, `preBend` | a bend to 9: the right pitch, the wrong motion |
| Pre-bend and release | `release`, `preBend` | fret 7, the note it lands on |

Storing a release under `bend` with a flag beside it would have made an older build name `7b9r7` as
fret 9's note, a wrong answer, and 0227 D9's rule is that no answer is better than a wrong one. A note
with both keys, which nothing writes, reads `bend` first, the key every build reads, so this build and
an older one agree on it. A `preBend` with no bend reads as a plain note. In memory the two marks are
plain `Bool`s, decoded with `decodeIfPresent` and written only when set, so a missing key is never a
failed decode, and an unmarked note is written byte for byte as before.

**D4. On the neck, the arrow points the way the pitch is heard to move.** The dashed ghost where the
bend lands stays (0227 D5). The arc from the note to it carries:

- a bend: an arrowhead at the ghost (as now);
- a bend and release: arrowheads at both ends;
- a pre-bend: an arrowhead at the ghost, with the arc **dashed**, since the string was pushed before
  anything sounded;
- a pre-bend and release: an arrowhead at the note only.

Vibrato's wave sits over where the note ends up: the ghost for a bend or pre-bend held, the note for
a release.

**D5. The glow moves the same way** (amends 0234 D5). A bend glides from the fret to where it lands (as
now). A bend and release glides up and back, ending on the fret. A pre-bend lights where it's heard,
the bent pitch, and shakes there when it has vibrato. A pre-bend and release lights at the bent pitch
and glides down to the fret. With Reduce Motion every one only fades in, as before. *Watch it on the
neck* draws the same glows, from the same `HaloMotion`.

**D6. In words and in the tab.** The line over the strip says *bent a whole step*, *bent a whole step
and released*, *pre-bent a whole step*, *pre-bent a whole step and released*. The tab writes `7b9`,
`7b9r7`, `7pb9`, `7pb9r7`, the usual way (0227 D5), with `~` after any of them. One reader,
`FrettedNote.bendShape`, gives the shape to the tab, the words, the glow and the drawing, so they can't
disagree.

**D7. What stays out.** Never detected, never suggested (0227 D10, 0070): every shape is the player's
own. Still out: a slide out to nowhere (`7\`), a bend that reaches a pitch other than its own (a bend to
9 released to 8), a held bend tied across taps, harmonics, tapping, palm muting and rakes.

## Consequences

- One reader, `FrettedNote+Bend.swift`, holds the shape, the tab text and the words. `HaloMotion`
  gains `.bendAndRelease`. `NeckMarksLayer` draws the four arcs. `NeckShape.tap` keeps the shape when a
  note moves, as it keeps the size.
- Name the notes and Write a tab both get the switches, since they share the editor (0235 D9).
- Unit tests in `BendShapeTests` cover the pitch of each shape, the tab, the round trip, what a build
  from before this ADR reads, the glow, the words and a moved note. Each was watched failing against a
  mutant.
- **Device check owed (Tomisin):** name a bend and release and a pre-bend on the neck, play the strip
  and watch the glow, and read the tab.
