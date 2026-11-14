# ADR 0296 — A bend released on a tap of its own

- **Status:** Accepted — built (2026-11-13, `pocket-426-held-bend-release`), for 1.4.1
- **Date:** 2026-11-13 (`pocket-426-held-bend-release`)
- **Amends:** ADR 0288 — **D7**: *a held bend tied across taps* is lifted. A bend held on one tap can
  come back down on the next, as a join (D1). The rest of D7 stands: a bend released to a pitch other
  than its own fret, and everything else it lists, stays out.
- **Amends:** ADR 0230 — **D1**: *two notes heard, two taps* now covers a bend as it covers a hammer-on.
  A bend let down quickly is one tap (0288's *Release* switch), and a bend held and then let down is two
  (D1 here). **D3**: the four ways in stay on every note, and a fifth, *Release*, appears after a bent
  note (D2). D2 and D4–D7 stand.
- **Amends:** ADR 0227 — **D5**: the joins become hammer-on, pull-off, slide and **release**. A release
  is valid on the same strings and frets as the tap before, where 0227's joins need the frets to move
  (D4 here). **D9**: `into` gains the value `release`, which an older build reads as no join (D8). The
  rest of D5 and D9 stands.
- **Relates to:** 0234 D5 (the glow, which gains no new motion: D7 reuses a pre-bend let down's) · 0235
  D9 (Write a tab, which shares the editor) · 0231 (adding and taking out taps, the workaround this
  replaces) · 0070 (never detected, never suggested)
- **Schema:** none. No `@Model` is touched. `PieceTranscription` stays at version 1. A tap's `into` gains
  one value inside the JSON (D8).

## Context

Tomisin was naming a solo with a half-step bend, held, let down, then a pull-off. The tap pad asks for
*once for every note you hear*, and the bend and its release were heard as two notes, so they were
tapped as two. The first try named them as two bends, `10b11` then `10b11r10`, which plays the bend
twice.

The app had no right answer for the second tap. A hammer-on, pull-off or slide can be one tap or two
(ADR 0230 D1), but a bend could only be one: 0288 gave it a *Release* switch on the bent note and kept
*a held bend tied across taps* out (D7). So the player had to take out a tap they had really heard.
That is the rewrite 0230 refused (*it rewrites what was heard to fit the tab*). Help & FAQs said so
(`pocket-425`), and the backlog recorded the gap the same day.

Two of the questions the backlog left open were already answered by the code. An older build reads a
join it doesn't know as none (`PieceLabel.join(in:)`, unchanged since 0227, 1.4 included), so the piece
still opens. The count already counts taps (*Take note 6 out*), so a release tap is a note like any
other.

## Decisions

**D1. A bend let down on a later tap is a join: *Release*.** When the tap before holds a bend, *Into it*
offers *Release*: the string was let back down without picking again, and what this tap is heard as is
the bend coming down. Two notes heard, two taps, for a bend as for a hammer-on (amends 0230 D1). A bend
let straight back down, heard as one note, stays one tap with *Release* on under *Bend* (0288 D1).

**D2. Offered only after a bend.** The four ways in stay on every note (0230 D3). *Release* appears as a
fifth only when the tap before has a bent note on the neck, held or released. A release with nothing
bent before it can't be played, and a fifth choice dimmed on almost every note would only be noise
beside the four.

**D3. Choosing it places the note.** A release can only land where the bend was fretted, so choosing it
puts this tap there: the same strings and frets as the tap before, unbent, whatever the tap held, an
unnamed tap included. Vibrato already on one of those notes stays. If the bent note had its own
*Release* on, it goes off, since the release has moved to a tap of its own. The cursor stays where it
is, as for any choice under *Into it*, and ↶ takes it back.

**D4. When it fits.** The tap before is on the neck, on the same strings and frets, with at least one
note bent and held (its *Release* off; a pre-bend counts). This tap's notes are unbent, with no
lead-in. When that stops being true, because the bend before is taken off, moved or given its own
release, or this note is bent or moved, the join goes, as any join does (0227 D5), and the tap reads as
picked. In a shape, the bent notes come down and the others are held.

**D5. Named by where it lands, and counted.** The release tap is its fret: `10`, named as fret 10's note
(0288 D2). It is a tap, so it counts in *N notes* and is numbered like any other.

**D6. Written the way the tab writes a join.** An `r` takes the place of the dashes between the two
columns: `10b11r10`, the same as a release inside one tap, as 0230 D5 has it for `11h13`. Tab has never
said how long a note lasts. That is the tab Name the notes shows and *Copy* gives. Where the tab is drawn
with its columns spaced (*The tab so far*, a piece's drawing, an exported tab), the mark goes in front of
the note it leads into, `10b11 r10`, as it writes a hammer-on `5 h7`. The strip in Name the notes puts
`r` between the two chips, and a song's map writes `r10` at the release's own time, where the hold
shows.

**D7. On the neck and in the glow.** On the release tap the neck draws the bend coming down: the dashed
ghost where the bend was, and an arc from it to the note with the arrowhead at the note, the drawing a
pre-bend let down already has (0288 D4), and the join's `r` in a pill under the string, between the
frets, where *h* and *p* sit. The arrowhead lands a little above the note, clear of the number a note
carries once the editor has moved past it, which would otherwise cover it. The glow on the
bent tap glides up and holds (0288 D5). On the release tap it lights at the bent pitch and glides down
to the fret, the motion a pre-bend let down already has. With Reduce Motion it only fades, as before.

**D8. Stored as a join.** `"into": "release"` on the tap, beside a plain fret, under the key every join
uses. An older build reads a join it doesn't know as none, so it reads the tap as fret 10 picked again:
the right pitch with the wrong motion, the trade 0288 D3 accepted for a pre-bend. A lead-in can't be a
release, since a bend let down inside one tap is the *Release* switch, so a `leadIn` whose join is
`release` reads as none.

**D9. In Write a tab too.** The tab writer shares the editor (0235 D9), so it gets *Release* as well.
Both forms are there, as they are for a hammer-on.

**D10. What stays out.** Never detected, never suggested (0070, 0227 D10). Still out: a release to a
pitch other than the fret (a bend to 12 let down to 11), bending again without picking
(`10b11r10b11`), and a release with other taps between it and its bend.

## Alternatives rejected

- **Printed tab's tied note, `10b11 (11)r10`.** It shows the hold, but it's a notation found nowhere else
  in the app, the tab's key in Help & FAQs would need a line for it, and it breaks 0230 D5's rule that
  the tab reads the same however the move was tapped.
- **A Release that is always shown.** It would be dimmed on almost every note. A pull-off is shown
  always because any note can be pulled into; a release needs a bend before it.
- **Asking the player to place the note, then choose Release.** There is one place it can go, so asking
  for it is a step that can only be done one way.
- **Keeping the workaround.** Taking out a tap that was heard is what 0230 rejected, and the FAQ that
  explained it was the only thing between the player and a wrong tab.

## Consequences

- `Join` gains `.release`, and `IntoChoice` gains `.release`, which `IntoChoice.offered(into:of:)` lists
  after a bend. `NeckJoin.releases(into:of:)` is the one rule for when it fits (D4), and
  `NeckJoin.fits(_:into:of:)` gives every reader the same answer for every join: the tab, the strip, the
  staff, a song's map, the glow and the tidy step. `NeckEditing.release(at:of:)` places the note (D3).
- `HaloMotion` glides a release tap down from the bent pitch, and `NeckMarksLayer` draws it (D7).
- The ⓘ beside *Into it* gains a paragraph for each voice. Help & FAQs' two answers about bends now say
  to keep both taps and choose *Release*.
- Unit tests cover when it fits, what choosing it does, the tab, the glow, the tidy step, the round
  trip and what an older build reads. Each was watched failing against a mutant.
- **Device check owed (Tomisin):** name the solo's held bend as two taps with *Release*, play the strip
  and watch the glow come down on the second tap, and read the tab.
