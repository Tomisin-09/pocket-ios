# ADR 0313 — Triads on three strings: a mode of the Arpeggios exercise, and a progression kept inside a range of frets

- **Status:** Accepted on 2026-11-23. **All four slices built** the same day (`pocket-464-dim-aug-vii`,
  `pocket-465-triad-finder`, `pocket-466-triads-together`, `pocket-467-practice-as-triads`): see *What
  building slice 1 settled*, *What building slice 2 settled*, *What the phone showed*, which brings part
  of D8 into slice 2, *What building slice 3 settled* and *What building slice 4 settled*. Which release
  any of it goes in is not decided here. Its shape was settled with Tomisin the same day over a mockup
  (`https://claude.ai/artifact/NFrDaPL1oE5XAT3hyk8PkB`, private), and the calls they made are marked
  *Decided by Tomisin*. The calls this ADR added while turning the mockup into code are marked
  *proposed here*. Tomisin took all ten as written the same day (*Decided*, below).
- **Date:** 2026-11-23 (`pocket-463-triads-adr`)
- **Amends:** ADR 0109 — *Out of scope*: diminished and augmented triads come in (D1). They join
  `ChordGrip.triads` and the picker's Triads section. Its other out-of-scope items stand, and so does
  its test that triads stay out of the curated movable set. ADR 0218 — **D5**: the builder's in-key row
  gains vii°. The rule D5 states still holds, because diminished and augmented get curated grips in the
  same slice (D1), so *Alternatives considered*'s "No grip plays it" stops being true. **D2**: a step's
  quality gains two values, and a build from before this reads either as major, by D2's own tolerant
  decode. **D10**: a saved progression gets a second use, *Practice as triads* (D9). D1, D3, D4 and D6
  to D11 stand. ADR 0083 — **S5**, from slice 2 (*What the phone showed*): a board with a shaded range never
  follows the hand; it shows the whole range and a fret either side. An open string is drawn only while
  the window starts at the nut, on every board. And a run that names its chords follows the chord, not
  the note, so its window moves only when the chord changes. The rest of S5, and how any other wider run
  follows, stand.
- **Relates to:** 0065 (the fretboard payload, and Arpeggios as a template) · 0083 S5 (the board holds
  still inside eight frets and follows a wider run) · 0084 (the movable grip) · 0107 (generate or
  draw) · 0123 (key-first spelling) · 0164 (the bass shapes that stand in for guitar grips) · 0188 (an
  archive or a shared routine can carry an exercise to an older build) · 0256 D3 (locked, not hidden) ·
  0263 D1 (My progressions is free)
- **Schema:** none. The recipe is a new case inside `Exercise.templatePayload`, and the two new
  qualities ride inside `SavedProgression.stepsData`. Both are blobs, so no `@Model` attribute changes
  and the store needs no migration.

## Context

In their guitar lesson on 2026-11-23, Tomisin's teacher drilled triads on three adjacent strings in
three steps:

1. One chord's shapes: its three inversions, up one string set.
2. The key's seven chords, up the same strings.
3. The same seven chords kept inside a range of frets (G‑B‑e, frets 3 to 7), so each chord is played
   in whichever inversion lands there.

Tomisin asked how Red Moon could support it, then asked for a fourth step in the same build: **a
progression voiced as triads inside a range**, each change taking the nearest shape.

What the app has today gets part of the way:

- **Triad shapes in the chord picker** (0109): major and minor, on G‑B‑e, D‑G‑B and A‑D‑G, in all
  three inversions. There is no diminished, so the seventh chord of every major key has no shape.
- **The Arpeggios exercise** (0065): picked, not placed. Choose a quality, a root and one of five CAGED
  positions, and it lays the chord tones out and walks them on the fretboard over the click.
- **Progressions written as numerals** (0218), which move to any key exactly. The builder leaves vii°
  out because no grip plays it (0218 D5).

A Chords exercise can half-build step 3 from the picker's triads. But it draws one diagram per chord,
each at its own place, so frets 3 to 7 never appears as one place on the neck. The player would also
need to know already which inversion fits the range, and that is what the exercise teaches. The range
is the lesson, so it has to be drawn.

**The 5-fret catch.** Not every 5-fret range holds a whole key. Across the twelve major keys, the three
string sets and start frets 1 to 12, five frets hold all seven chords in 168 of 432 cases (the mockup's
count). The narrowest range that holds them:

| Strings | Works somewhere, in every key | Works anywhere, in every key |
|---|---|---|
| G‑B‑e | 5 frets | 6 frets |
| D‑G‑B | 5 frets | 6 frets |
| A‑D‑G | 6 frets | 7 frets |

The B string's tuning is why the top two sets pack tighter. A progression uses fewer chords, so it fits
more ranges than the key's seven. So the editor can't refuse a narrow range, and it can't promise that
one works either (D6).

## Decisions

### D1 — Diminished and augmented come first, and are useful on their own

*Decided by Tomisin: this slice comes first.*

- `ChordGrip.Quality` gains `diminished` and `augmented`, named "dim" and "aug" as `ChordNamer` already
  names them, and written vii° and III+ as `ChordNumeral` already writes them. A diminished step is
  minor-family, so its numeral is lower case.
- `ChordGrip.triads` gains them on the three string sets. Diminished gets all three inversions, nine
  shapes. An augmented triad is the same shape in every inversion, because its notes are each a major
  third apart, so it gets one shape per set, three in all, and its chip names no inversion *(proposed
  here)*. The picker's Triads section lists them after minor.
- **0218 D5's rule holds because they get curated grips too.** Every quality the builder offers must
  fret at every root on both necks. 0109's triads stay out of the curated set, and its test pins that,
  so diminished and augmented each gain a movable four-string grip in `ChordGrip.curated`, rooted on the
  A and the low E strings. The build picks the fingerings, and `ProgressionResolverTests` covers them
  because it runs over every quality *(proposed here)*.
- **On bass, the third states them** *(proposed here)*. The guitar shapes stand down on bass (0164). A
  diminished chord plays the minor tenth and an augmented one the major tenth, still named Bdim and
  Caug. 0218 D4's fit rule already lets the fifth go unplayed, and the tenth is what the bass plays for
  every other chord with a third.
- **The builder's in-key row gains vii°**: I ii iii IV V vi vii°, seven chips over three rows of its
  three-column grid. *Any chord* gains both qualities, since it lists every one.
- **A build from before this reads either as major.** `ProgressionStep`'s decode reads an unknown
  quality as major and keeps the step's place and length (0218's own rule), so on an older build vii°
  reads as VII: B, not Bdim. That needs an archive restored into an older build, since the app doesn't
  sync, and Red Moon isn't publicly released yet. Accepted, as 0218 accepted it.

This slice stands on its own. Bdim in the chord picker and vii° in a progression are worth having before
Triads exists.

### D2 — Triads is a mode of the Arpeggios exercise, not a new template

*Decided by Tomisin.*

Under *Generate*, the Arpeggios editor's first row becomes a choice of shape: **Box**, the CAGED
arpeggio it plays today, or **Triads**. *Draw your own* (0107) is unchanged.

It goes in Arpeggios because the board already does what the lesson needs. It holds still when a drill
fits in eight frets and follows the hand when it's wider (0083 S5), so frets 3 to 7 stays put and a climb
up the neck scrolls, with no new windowing code. The editor already works by picking and generating, and
the template's own line says it: *"Run chord tones across the neck, in position."*

Switching from Box to Triads seeds the key from the box's root, and major or minor from its quality
*(proposed here)*. **Triads is guitar only** *(proposed here)*: on a bass exercise the Shape row doesn't
show. Bass triads on E‑A‑D and A‑D‑G are real, but the string sets, the shapes and the 5-fret finding
are all worked out for guitar (Deferred).

### D3 — One pure function finds the shapes

`TriadShapes`, pure and in `Core` with no SwiftUI or AVFoundation, takes any three-note chord (a root and
three intervals), a string set and a range of frets. It gives back every close voicing that fits, each
with its inversion and the chord tone on each string. When several fit and there's a chord before, it
picks the one that moves the fingers least, measured as the sum of the three strings' fret distances,
and a tie goes to the lower shape. The first chord of a run takes the lowest shape in the range.

It works from intervals rather than placing `ChordGrip.triads`, because sus2 and sus4 play as written
(D5) and have no triad grips. A test holds the two together: for every triad grip at every root, the
function finds that exact shape, so the picker and the exercise can't disagree about what a shape is.
Further tests run every key, string set and range, the nearest-move choice, and the table in *Context*.

### D4 — The recipe: `TriadRun`, a new `FretboardContent` case

`FretboardContent.triads(TriadRun)`, versioned like its siblings. It holds the key (tonic, and major or
minor), the strings, where the chords come from (D5), where they're played (*Up the neck*, or *Stay in
frets* with its two frets), the inversion a key's climb uses, *Play as* (D7), the rhythm, and *Up and
back*. A progression is held as a copy of its steps, with their bars, and the name it was chosen under.
**The notes are generated on each expansion, never stored**, as every other generated run's are.

A chord holds for its bars, and a bar is the exercise's (0218 D7), so this is the one fretboard recipe
whose length depends on the meter. Its expansion takes the exercise's beats per bar.

**An older build plays it as a click, and must not overwrite it** *(proposed here)*. It can't decode the
new case or read the blob as a bare drill, so `fretboardContent` is nil and the run falls back to the
metronome renderer, as 0065 intends. But the shape sheet seeds A minor 7 when there's no content
(`ExerciseShapeSheet.init`), and Done then writes that over the payload it couldn't read. So **slice 1
adds a guard**: the editors don't write fretboard content over a payload that is there but can't be
decoded, and they say the exercise was made in a newer version of Red Moon. The ways an older build
meets one are an archive restored into it and a shared routine opened on it (0188). Red Moon isn't
publicly released yet, so today the only older builds are Tomisin's and testers', and the risk is small.
The guard is a few lines, and putting it in slice 1 means every build in use has it by the time Triads
ships.

### D5 — Where the chords come from

*Decided by Tomisin, from the mockup.*

- **One chord**: the key's own chord, major or minor, named on its button ("Just C").
- **The key's seven**: the key's triads in order, vii° (or ii° in minor) included.
- **A progression**: a menu listing the built-ins and *My progressions*. Choosing one copies its steps
  in, as *Use a progression* does, so editing or deleting the progression later leaves the exercise as
  it was. The Key row moves it exactly, because it's numerals. Major or minor follows the progression,
  so that segment shows the progression's reading and doesn't take a tap, as the builder reads it
  (0218 D3).
- **Bigger chords play as their triad.** A 7th, maj7, 6th or 9th plays its major or minor triad, and its
  chip says so ("Dm7", then *plays Dm*). Sus2 and sus4 have three notes, so they play as written.
  Diminished and augmented play as themselves (D1).
- **A power chord has no third, so it has no triad.** Its chip says so and the run plays nothing for it.
  *Proposed here*: nothing for its whole length, so the form keeps time with the click and a progression
  doesn't get shorter.

### D6 — Where they're played, and a range that's too narrow

*Decided by Tomisin, from the mockup.*

- **Stay in frets** keeps every chord between two frets the player sets, shaded on the board. Each
  chord takes the shape in the range nearest the one before (D3).
- **Up the neck**: one chord plays every shape from the nut up. The key's seven climbs in one inversion
  (*Climb in*, under Advanced). A progression plays three passes, each starting from the next shape of
  its first chord and kept to the narrowest range around it (five to eight frets) that holds every
  chord, so the three passes are three positions up the neck.
- **A range that can't hold a chord isn't refused.** The chord's chip says *no shape*, the run plays
  nothing for its length, and the editor names the chord and offers the nearest ranges that hold them
  all: the same width lower, the same width higher, or one fret wider. Save stays on. The table in
  *Context* is why: a narrow range is a fair thing to practise, and the help is to say which chord falls
  out.

### D7 — Broken and Together

*Decided by Tomisin: both, as* Play as *under Advanced.*

- **Broken** plays each triad one note at a time, low string to high. It runs on today's board as it is.
- **Together** lights all three notes at once and holds them, the way you'd strum the changes. Today the
  board lights one note per slot, so this is the new board work (D8).

*Proposed here, the lengths.* In a progression each chord lasts its bars, and Broken repeats its three
notes upward to fill them (triplets fill a beat exactly). With one chord or the key's seven nothing has
bars, so Broken plays each chord's three notes once, as the mockup does. **Together always takes the
time Broken would**, so switching *Play as* never changes how long the run is. *Up and back* is offered
for one chord and the key's seven, not for a progression, whose order is the music.

### D8 — The board learns to show a chord

*Decided by Tomisin: Together needs it. How, proposed here.*

- **A slot can sound more than one note.** `FretboardDrill` gains a transient field, never encoded, like
  `noteGroups`, `openMidi` and `keySpelling`: the notes that sound with each slot. `activeNoteIndex` is
  unchanged, and the renderer lights the slot's companions with it. A stored `.custom` drill and every
  saved payload keep their shape.
- **Interval labels read each chord's own root**: R, 3 or ♭3, 5, ♭5 or ♯5, 2 or 4. The lesson is which
  tone is on top, and a label read against the key's tonic would hide it. The drill gains a second
  transient field, each slot's root. Note labels are spelled from each chord's degree, as 0218 D3 spells
  a progression.
- **Where your fingers just were**: when the chord changes, the notes of the shape before that moved
  show as dashed rings (the mockup's), so the nearest move can be seen.
- **A strip of chips under the editor's board**: each chord's name, its numeral and inversion, its
  frets, and *plays Dm* or *no shape* where those apply. The run screen names the chord being played.

*Brought into slice 2 (What the phone showed):* naming the chord being played, on the run screen and over
the editor's board, and interval labels read against its root. The second transient field is a list of
chords with their slots rather than each slot's root. The companions, the dashed rings and the strip stay
in slice 3.

### D9 — Practice as triads

*Decided by Tomisin:* a **Practice as triads** button on a progression in *My progressions*, spelled like
the loop sheet's *Practice now* (whose accessibility label is "Practice this loop now").

*Proposed here:*

- **It sits on the progression's own screen**, above *Delete progression*, the way *Practice now* sits
  on a loop's sheet, and in the row's context menu. Not as a button inside the row: a button in a List
  row leaves the row's middle dead, and a sheet presented from a row loses its write on iOS 18 (0218,
  *What building it settled*).
- **It opens the New exercise form**, on Arpeggios, *Generate*, Triads, with this progression chosen in
  the key it was written in, and the rest of D10's defaults. Its title is the progression's name with
  "as triads" after it. Nothing is saved until the player saves it.
- **It wears Practice's colour**, since it leads into Practice, as *Practice now* does on a song's loop.
- **My progressions is free** (0263 D1); making an exercise isn't. A free player who taps it meets the
  *New exercise* wall (`PlanDoor.newDrill`). The button shows to everyone: locked, not hidden (0256 D3).

### D10 — What a new Triads run opens on

*Proposed here.* The teacher's step 3: C major, G‑B‑e, the key's seven, *Stay in frets* 3 to 7, Broken,
eighths. It shows the range and the nearest move before anything is tapped, the way 0218's sheet opens
on a progression rather than empty.

## Alternatives considered

- **A Triads template of its own.** A new tile in the template list, a new manual section and a new
  skill association, for something the Arpeggios line already describes. A mode keeps it beside the box
  it grows out of.
- **The Chords exercise, or *Use a progression*.** One diagram per chord, each at its own place, so the
  range never appears as one place on the neck. *Use a progression* fills a Chords exercise, so it has
  the same problem.
- **Placing `ChordGrip.triads` instead of working from intervals.** It leaves sus2 and sus4 with no
  shape. D3's test keeps the two in step instead.
- **Diminished as a triad grip only.** The resolver would need it in the curated set, which breaks
  0109's test, or vii° would have no shape, which breaks 0218 D5.
- **Refusing a range that can't hold every chord.** Most 5-fret ranges would be refused (264 of 432 for
  the key's seven). Naming the chord that falls out and offering the nearest range teaches more.
- **Dropping a power chord, or a chord with no shape, from the run.** The run would come out shorter than
  the form, and the click would drift from the bars (D5, D6).

## Decided

The ten calls marked *proposed here*, taken as written by Tomisin on 2026-11-23. On the fifth they noted
that the app isn't publicly released yet, so an older build is less of a risk; D4 says why the guard
still goes in.

1. Augmented gets one shape per string set, with no inversion named (D1).
2. Diminished and augmented gain four-string curated grips, so 0218 D5's rule holds (D1).
3. On bass, diminished and augmented play their tenths (D1).
4. Triads is guitar only for now, and Box to Triads carries the root and major or minor (D2).
5. Slice 1 adds the guard that stops an older editor overwriting a payload it can't read (D4).
6. A power chord, or a chord with no shape in the range, rests for its whole length (D5, D6).
7. Broken fills a progression chord's bars; Together takes Broken's time (D7).
8. How the board shows it: companion notes, per-chord labels, the dashed rings, the chip strip, and the
   chord's name on the run screen (D8).
9. Where *Practice as triads* sits, what it opens, its colour, and the wall for a free player (D9).
10. What a new Triads run opens on (D10).

## Deferred

- **Triads on bass** (D2).
- **The lower string sets**, D‑A‑E and E‑A‑D, still out of scope as in 0109.
- **One chord of any quality**, such as Bdim on its own. *One chord* is the key's own chord.
- **Diminished and augmented in Box mode** (`ArpeggioQuality`).
- **Spread voicings**, a triad across strings that aren't adjacent.
- **Four-note shapes on four strings**, the seventh chords. It's the natural next lesson; the finder's
  method carries over, the string sets don't.

## Slices

1. **Diminished, augmented and vii° (D1), and the overwrite guard (D4).** No schema. Tests: the new
   triad grips' pitch sets and the bass tone of each inversion (`ChordGripTriadTests`); every quality at
   every root on both necks (`ProgressionResolverTests`); vii° and III+ numerals and their spelling; an
   older build's decode of a diminished step; and the guard leaving an unreadable payload as it was.
   Ships alone.
2. **The finder and the recipe, played Broken (D3 to D6, D10).** `TriadShapes`, `TriadRun`, the new
   case and its decode, and the Triads rows in the editor, which stays rows (0293). Tests per D3, plus a
   `TriadRun` round trip and a blob that decodes as nothing on a build without the case.
3. **The board shows a chord (Together, D7 and D8).** The two transient fields, Together, per-chord
   labels, the dashed rings and the chips. A screenshot of each state, since a green build can't see a
   dot in the wrong place.
4. **Practice as triads (D9).** The button and its context-menu twin, the form opened with the
   progression chosen, and the wall for a free player. A UI test that it opens the form filled in.

## What building slice 1 settled

- **The four curated grips** (D1), as the chart prints them at C, low string first: E-shape dim
  *8-9-10-8-x-x*, A-shape dim *x-3-4-5-4-x*, E-shape aug *8-x-10-9-9-x* (the E-shape major with its 5th
  raised on the B string and the A muted, as the E-shape maj7 mutes it) and A-shape aug *x-3-2-1-1-x*.
  The A-shape aug reaches below its root fret, so at A and B♭ it climbs an octave, as the 9ths do; the
  resolver takes the E-shape there, which sits lower.
- **They sit in Tier 2**, so the picker's last section is now *Sus, 6ths, 9ths, dim & aug*. The picker
  already holds that every curated grip has a chip (`ChordPickerTests`), and Tier 1's two-rows-per-family
  grid had no room. Their chips say *E-shape* or *A-shape* without *barre*, as the power chord's do: no
  finger lies across.
- **The root-position diminished triad on A-D-G spans five frets** (*x-7-5-3* for E dim): it climbs two
  frets a string because A-D-G are all fourths apart. It is the shape the triad books print, so it
  stays, and its chip's diagram stretches to five frets as a bass tenth's does (1.5). Every other guitar
  diagram keeps four, and `ChordDiagramWindowTests` now holds both, and that every dot is drawn.
- **A fit for diminished or augmented is strict** (`ProgressionResolver.fits`). The altered fifth must
  sound, the perfect fifth must not, and no 6th or 9th may colour it: a 6th over a diminished triad is a
  dim7, another chord. So a saved Bdim7 doesn't stand in for vii°.
- **The guard covers every payload, not only fretboard content** (D4). `Exercise.hasUnreadableContent`
  is true when a payload is there and this build's decoder for the template's renderer reads nothing;
  the four setters return without writing then. The strum pattern, chord progression and strum-chord
  sheet had the same overwrite (the sheet seeds a default for each), and guarding at the setters covers
  every editor that writes through them. The shape sheet shows *Made in a newer version of Red Moon* in
  place of the editor, and Done only closes it.
- **A progression that opens on i° reads as minor**, since diminished is minor-family (D1) and that is
  what `readsAsMinor` asks. No built-in does, and it only changes how the key is labelled and spelled.

## What building slice 2 settled

- **The finder reproduces the 5-fret table exactly** (`TriadShapesTests`): 168 of 432, and 5 and 6 frets
  on G‑B‑e and D‑G‑B, 6 and 7 on A‑D‑G. Those numbers came from the mockup's own script, so the Swift
  finder and the mockup agree on what fits. Frets run 0 to 22, the mockup's neck.
- **The key's seven ends back on the key's chord**, eight chords, as the mockup plays them: up the neck it
  is the octave a climb closes on, and in frets it is the tonic again, nearest from vii°.
- **D2's carry is for a box the player has.** Switching to Triads takes the box's key when the box was
  saved with the exercise or has been changed in the editor. A new exercise's untouched A minor 7 isn't
  one, so its first switch opens on D10's C major between frets 3 and 7, the teacher's step 3. Neither is
  the A minor 7 seeded beside a saved Triads run.
- **A range is 3 to 10 frets**, set one end at a time. *The nearest ranges* are the same width lower and
  higher, the nearest of each way; only when neither exists, the narrowest range up to four frets wider
  that keeps the low fret where it can. A power chord has no shape anywhere, so it never counts against a
  range and the help never names it.
- **Up the neck's limits**: one chord's shapes, and the shapes a progression's passes start from, reach
  fret 15; a pass's later chords may reach 17. A progression that opens on a power chord starts its
  passes from its first chord with a triad. The key's seven climbs until the neck runs out.
- **Up and back drops the shared turn**, as the box arpeggio does, so a looping run never plays a chord
  twice in a row. The mockup repeated the first chord at the seam.
- **The range reaches the board as a transient field**, `FretboardDrill.shadedFrets`, like `noteGroups`:
  never encoded. The board keeps it in view with a fret either side, so frets 3 to 7 draws 2 to 8. As
  first built, a 10-fret range followed the hand like any run wider than the board's eight (0083 S5);
  *What the phone showed* changed that.
- **Labels read the key, as first built**: interval labels and root rings were against the key's tonic.
  *What the phone showed* changed that too. A progression up the neck fades the passes not being played,
  through 0083 S2b's pass focus.
- **A payload from a newer build still plays.** An unknown string set, source or placement reads as D10's,
  and a progression source with no steps plays the key's seven. A Triads run on a bass exercise, which
  no editor can make, draws on the six-string board.
- **Two files moved for the 400-line cap**: `FretboardContent` out of `FretboardRun.swift` into its own
  file, and *Edit shape*'s sections into `ExerciseShapeSheet+Sections.swift`.

## What the phone showed

*Decided by Tomisin on 2026-11-23, after playing slice 2 on the phone: "it's hard to identify what triad
you're playing ... it's just a bunch of notes lighting up in a seemingly random order if you're not
familiar with the triad shapes." How, proposed here and agreed the same day.*

- **The chord being played is named over the board**: its name in its colour, its numeral, and what comes
  next, *Am · vi, then F · IV*. This is Watch it on the neck's chord row (0308 D4), with the same badge.
  In the editor it sits at the head of the board's row, beside Display, where Watch otherwise goes. On
  the run screen it sits over the board. While nothing is lit (the count-in, or a board that doesn't walk)
  it names the chord the run starts on: *Starts on C · I*.
- **A run of one chord names the inversion instead**, since the chord never changes: *C · I · 1st
  inversion, then 2nd inversion*. A chord with no shape says it *rests*.
- **The chord's three notes wear its colour**, 0308 D7's colour for its degree, so V is the same colour
  here as in Watch it on the neck. The note being played is filled with it and the other two are tinted.
  Every other note stays grey. Only the chord being played is coloured, because neighbouring triads share
  notes: the C at the G string's 5th fret is in C, Am and F, so no note can keep one colour.
- **Only its own root is ringed, and interval labels count from it** (D8's rule, brought forward). The
  ring used to stay on the key's tonic, so every C was ringed while Am played. Where the root sits in each
  inversion is most of what the drill teaches. While nothing plays, the board reads the key, as before.
- **The board names what it plays**: a G7 in a progression plays its G triad (D5), so the line says G and
  V, not G7 and V7. The progression row still says what's written.
- **A range you stay in is shown whole and never follows the hand.** The range is where the hand stays,
  so the board shows all of it and a fret either side, up to twelve columns for a 10-fret range. On the
  phone, frets 0 to 9 scrolled to 3 to 10 and drew the open strings on the window's left edge.
- **An open string is drawn only while the window starts at the nut**, on every board. A window that has
  followed the hand up the neck has no nut in view, and an open note on its left edge read as a note at
  that fret. The following rule keeps the nut in view near an open note, so a lit one stays visible.
- **Up the neck, the board follows the chord, not the note.** A triad's notes can step back down the neck
  inside one chord: the F on G‑B‑e plays frets 10, 10 and 8, so the window scrolled to 9 to 16 for its F
  and straight back to 3 to 10 for its C, twice for one chord. It now takes 0083 S5's rule over all of
  the chord's frets at once, so it moves only when the chord changes, and the chord being played is
  always whole on the board. C major's seven up G‑B‑e now moves twice per climb (at F, then Am), and once
  more to go back to the start.
- **How it reaches the board**: `FretboardDrill.chords`, a transient list of `DrillChord`s (root, the
  triad's suffix, its numeral, a detail, its slots), never encoded, like `shadedFrets`. Nothing saved
  changes. `DrillChordTests` pins it.
- **Chords and Strum & chords get the same numeral and colour on a branch of their own.** Their diagrams
  already name the chord; what's open there is a progression whose key isn't set, which Watch it on the
  neck answers by colouring nothing. Not decided here.

## What building slice 3 settled

- **Together keeps the bass in the slot.** Each slot of a chord played Together sounds the shape's lowest
  note, with its other two as the slot's companions (`FretboardDrill.companions`, transient like the
  drill's other render fields). So `activeNoteIndex` and the slot count are Broken's, and switching *Play
  as* moves nothing in time (D7). A companion counts as sounding in its slot wherever the board asks: it
  is plotted, lit, coloured and pass-focused with the slot, and the window keeps it in view.
  `TriadRun.playAs` is stored by its raw value. A run saved before it, or a value from a newer build,
  plays Broken.
- **Together draws no move arrow.** Three fingers land at once, so an arrow from bass to bass would single
  one out; the dashed rings show where they came from. Broken keeps its arrow.
- **The dashed rings are the mockup's.** While a chord plays, the notes of the last shape that played and
  aren't in this one are ringed dashed, in grey, since the colour belongs to the chord under the hand. A
  note the two shapes share is a finger that stayed, so C to G on G‑B‑e rings two notes, not three. A
  chord that rests rings nothing and is passed over, so the chord after it rings the shape before the
  rest. The run's first chord rings nothing, even when the run loops back to it: on the first pass there
  is nowhere the fingers were, and a ring would point at a shape not yet played. So the seam of a looping
  progression goes unringed; if the phone shows that missed, wrapping is the follow-up.
- **A chip says the chord as written**, as the progression row does: *Dm7*, *ii7 · root*, *7 6 5*, *plays
  Dm*. The line over the board names the triad (*Dm · ii*), so the two read together. Frets go low string
  first, as a chord chart prints them. An augmented chip names no inversion (D1). A power chord's says *no
  triad*, a chord with no shape in the range says *no shape*, and both are drawn dashed and dimmed. There
  is a chip per chord played, so the key's seven has eight and a progression up the neck twelve, with a
  dashed rule before each later pass. The chip being played fills with its chord's colour, and the strip
  scrolls to keep it in view. A chip doesn't take a tap: the preview walks on its own clock.
- **The board's spoken summary reads chord by chord** on a board that names its chords: *C, I, together:
  G fret 5, root, B fret 5, e fret 3*. Read slot by slot, a chord held for two bars said its notes sixteen
  times.
- **The phone showed the sheet lagging**, with a progression up the neck played Together. The board worked
  out its window (0083 S5) on every read, about 110 times a frame, and each time walked all 96 slots and
  their companions: 106 ms a frame in a Debug build, against 8 at 120 Hz. `FretboardGrid` now works it out
  once a frame, the window takes one pass with no arrays built (0.2 ms), and the editor's board row owns
  the chord being played, so a chord change no longer re-runs the shape finder. Every board gains from it;
  the key's seven in frets went from 6.9 ms a frame to under 0.1.
- **Two moves for the 400-line cap**: pass focus from `FretboardGrid` into `FretboardGrid+Focus.swift`,
  beside the dashed ring, and Advanced with the bindings from `TriadRunEditor` into
  `TriadRunEditor+Advanced.swift`. The chip is its own `TriadChip`, since lint allows one level of nesting.

## What building slice 4 settled

*Proposed here, the same day, while building it.* The first four are small calls D9 left open. Tomisin
tried both doors on the phone the same day and was happy with it.

- **Both doors make the form's seed in one place.** `NewExerciseSeed.practiceAsTriads` (pure, in `Core`)
  takes a name, the steps and the key they were written in, and gives the template, the instrument, the
  name and the Triads run. The button and the menu item both call it, and `newExerciseFlow` carries it
  to `NewExerciseSheet`, which skips the template picker for it, and on to `ConfigureExerciseForm`,
  which opens on Triads with that run. So the form, the gate (`PlanGated(.newDrill)`) and the push to the
  new exercise after **Create** are the ones every other door uses. On the Toolkit's stack, as *Start an
  exercise from this* does (0264 D5), so Back from the new exercise returns to the progression.
- **It opens on guitar, whatever the profile's instrument.** Triads is guitar only (D2), and on a bass
  exercise the Shape row doesn't show, so a bass player's form would open on a box arpeggio with no
  progression in it. The form fixes the instrument as every create does (0116), so the exercise is a
  guitar one.
- **The button practises what's on the screen.** An edit not yet saved goes into the exercise as it
  stands, and stays on the builder to save or leave, as every edit there does. The menu item reads the
  progression as saved, since a row has no edits. A name cleared while editing falls back to the saved
  name.
- **A progression with nothing a triad plays opens nothing.** With no chords, or only power chords (D5:
  no third, no triad), the run would rest for its whole length on a board that never lights. The
  button stays, disabled, and with only power chords its footer says *Power chords have no third, so
  there's no triad to play.* The menu item doesn't show. One power chord among others is fine: it rests
  for its length, as D5 has it.
- **The key follows the progression's reading.** The run's own major or minor is set from the
  progression (`readsAsMinor`), so switching **Chords** to the key's seven stays in the progression's key:
  A minor's, for Am · F · C · G written in A.
- **The menu item's lock replaces its glyph.** A context menu draws one glyph, so without the plan the
  lock stands in for the play glyph, as Home's rows swap their chevron for it. The button on the screen
  draws `PlanLockBadge` beside its label, as *Start an exercise from this* does.
- **The button's footer says what it makes**: *Makes an Arpeggios exercise that plays these chords as
  triads on three strings.* It opens a form, not a run, and *Practice now* on a loop plays at once, so
  the line is what tells the two apart.
- **Tests**: `PracticeAsTriadsTests` (the seed: template, guitar, name, the copy with its bars, the key
  and its reading, D10's defaults, no seed for no triad, and that the seeded run lights notes inside
  frets 3 to 7) and `PracticeAsTriadsUITests`, which opens the form from both doors and reads its name,
  Triads, Generate and the progression chosen, then deletes the progression it wrote. The progression
  menu gained the identifier `triads.progression`, since the Chords row has a *Progression* segment too.

## Consequences

- Diminished and augmented reach the chord picker and the progression builder in slice 1, before any of
  the triads work.
- `docs/manual/` will owe: the Arpeggios rows (the Shape row, the Triads rows, *Play as*), *My
  progressions* (the button), the picker's Triads section (diminished and augmented) and the builder's
  in-key row (vii°). Their figures go in the reshoot notes and are shot once every slice is in.
- `FretboardDrill` gains transient fields: the shaded range and the chords in slice 2, D8's companions
  in slice 3. Nothing that's encoded changes.
- The 5-fret table is pinned by a test, so if the finder's rules change, the numbers here get checked
  again.
- An older build that meets a Triads exercise plays a click (D4).
