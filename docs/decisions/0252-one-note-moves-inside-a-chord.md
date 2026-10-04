# ADR 0252 — One note moves inside a chord, and ↶ ↷ move up

- **Status:** Accepted — decided with Tomisin, 2026-10-04, after two rounds of mockups. Built on
  `pocket-362-chord-flourishes` in two commits: ↶ ↷ first, then one note in a chord. Still owed: the
  device check and the reshoot (Consequences).
- **Date:** 2026-10-04
- **Amends:** ADR 0230 — **D6**: a lead-in no longer moves one note or else the whole shape. In a chord,
  a hammer-on or pull-off moves the note on the string tapped, and the rest are held (D1).
  *The whole chord moved?* gives the shape the move as one (D2). A slide still moves the whole shape, and
  so does *Moved into place as one?*. In a shape moving as one, a note moved or added still takes the
  shape's move. D1–D5 and D7 stand.
- **Amends:** ADR 0227 — **D3**: the *Where did you play it?* title over the neck goes. Its row is the
  instrument and tuning on the left and ↶ ↷ on the right (D3). The rest of D3 stands, the instrument
  sheet included.
- **Amends:** ADR 0234 — **D6**: ↶ ↷ leave the strip's bottom row for the right of the picker's first
  row, in the same spot on both sheets (D3). The bottom row keeps *Next unnamed*. The history, the keys
  and the rest of D6 stand.
- **Amends:** ADR 0235 — **D3**: the writer's neck loses its *Where do you play it?* title too, since the
  neck is shared. The writer's ↶ ↷ stay where they were, above the neck. The rest of D3 stands.
- **Relates to:** 0227 D10 (joins between a single note and a shape stay out) · 0251 (the Legato drill
  works its joins out from the same rule, which this leaves alone) · 0225 (the tap is what was heard;
  nothing is detected) · 0070 (never grades)
- **Schema:** none. Each note of a shape has carried an optional `leadIn` since 0230 D7. A shape where
  one note has one and the rest don't is new data in the same keys (Consequences).

## Context

In *Name the notes* (Fret & string, Chords on), Tomisin hammered the B string 5→7 inside a Dmaj7 from
the A string (A5 D7 G6 B7 e5), and every note moved: *Started 2 frets lower, moving as one*. That was
0230 D6 by design. A lead-in was one note, or a whole shape moving as one, the way a hand slides a
double-stop. A finger hammering one string while the chord rings had no way in.

The first mockup answered with a lot: several notes each with its own start (tap them, then Done),
links to switch between modes, and a Trill. Tomisin found it complicated, and said its examples didn't
match how chords are played: an e string hammered from below the barre, a B pulled off from 9 onto 7,
a B trilling 7↔9. They asked to go *"back to basics, cheapest but most effective"*.

The second round's first rule worked the start out from the barre, the chord's lowest fret. Tomisin
corrected it: **a start is not always the barre.** In an m7 from the A string (Dm7: A5 D7 G5 B6 e5) the
B string sits under the middle finger at 6, and it's hammered from it to 8 or pulled off from 8 onto it.
The minor-to-major hammer (a D shape barred at 5, its B going 6→7) is a second case. The barre would be
right for the Dmaj7 and wrong for both of the others. So the start is tapped, never worked out.

The same review kept a smaller change from the first mockup: ↶ ↷ in the header row.

## Decision

### D1 — In a chord, a hammer-on or pull-off moves one note

- **The gesture is the one a single note already has:** pick *Hammer-on* or *Pull-off*, then tap where
  it started. The string tapped picks the note, and the rest of the chord is held. One tap, and it's
  done.
- **The start is always tapped.** Any fret on that string can be it: below the note for a hammer-on,
  above it for a pull-off. Only that note has to be playable from it, so a start isn't dimmed because
  another note of the chord would have left the neck.
- **A slide still moves the whole chord.** A hand slides the shape; a finger hammers. *From below* and
  *From above* are unchanged. *Moved into place as one?*, which moves a join from the tap before inside
  the shape, still moves the whole shape too.
- **The rule** (`NeckJoin.leadInsFit`): at least one note has a start. The notes that move share one
  join and one direction, and each can be played into its fret. The rest are held. When every note
  moves, they still move the same number of frets, so a shape whose notes move apart still goes.
- **The line says which note moved:** *B string hammered on from fret 5; the others held.* The *h* or
  *p* pill sits on the moving string, and the tab writes the moving note's column alone:
  `B|-5h7--|` with `e|-5----|` held.
- **Moved or added:** in a shape moving as one, a note moved or added takes the shape's move, as before.
  In a chord where one note moves, each keeps what it had, as a lone note does: the moving note keeps
  the fret it started from, a held note stays held, and a note added is held. A lone note with a start
  still passes it on when it grows into a double-stop (0230 D6).

### D2 — *The whole chord moved?*

Under a one-note hammer-on or pull-off, beside *Change where it started*. It gives every note the moving
note's move, the same number of frets from its own, so a double-stop hammered as one is still a tap and
a link away. It appears only when every note would stay on the neck. *Change where it started* starts
again the way the note moved: one note picks its note again, a shape moving as one moves as one.

### D3 — ↶ ↷ move up

- The *Where did you play it?* title over the neck goes. Its row is *Guitar · Standard ›* on the left
  and ↶ ↷ on the right, drawn smaller and still touched at 44 pt.
- On By ear they sit at the right of *What did you hear?*, the same spot.
- The bottom row keeps only *Next unnamed*, on the right.
- ⌘Z, ⇧⌘Z and ⌘Y are unchanged, and so are the history and its ids.
- The tab writer shares the neck, so its title goes too. Its ↶ ↷ sit in their own row above the neck
  already, and stay there.

### Parked, not decided against

In `docs/backlog.md`, each with its reason:

- **Several notes, each with its own start** (keep tapping, then Done). It's the most complicated piece
  of the first mockup, and one note covers the cases Tomisin plays.
- **Trill.** Most of its cost is a new stored key, a tab mark, a drawing, a glow and a gesture, and the
  first mockup's frets were wrong. A chord trill can be written today as a hammer-on, then pull-offs and
  hammer-ons on single notes.
- **One note sliding inside a held chord.** A slide moves the whole chord (D1). The rule would keep one
  that was stored; nothing makes one.
- **Working out the start from the barre.** It gets the minor-to-major hammer and the m7's middle
  finger wrong.
- **Joins from a chord to a single note** were already out (0227 D10) and stay out.

## Consequences

- **A pull-off inside a chord now works both ways it's heard.** Heard as two (the usual): tap 1 is the
  chord, tap 2 is the B alone, then *Pull-off*, which joins from the tap before. That already worked.
  Heard as one: the shape with the B where it lands, then *Pull-off*, then tap where it started.
- **Older data reads as it did.** A shape whose notes all move as one is unchanged. Before this, a shape
  with one note's start and the rest without was tidied away, every start with it, so none was stored.
- **An older build meeting the new data** keeps the notes and the frets. On its next change to that
  pass, its tidy drops the one start, since it requires every note to move. The note stays where it was
  placed; only the hammer-on is lost. No crash, no wrong fret.
- **The Legato drill (0251) is untouched.** It works its joins out between steps with `NeckJoin.direction`,
  which this doesn't change.
- **Device check (Tomisin):** the Dmaj7 with B 5h7; the minor-to-major hammer; the Dm7's B 6h8 and 8p6;
  a pull-off heard as one and as two; a chord slid in; reaching ↶ ↷ with a thumb.
- **Reshoot:** the Name the notes figures on Fret & string and By ear, and the tab writer's, show the
  header row. They go on the reshoot list, not shot on this branch.
