# ADR 0308 — Watch what you pick: picking on the map, and notes in their chord's colour

- **Status:** Accepted on 2026-11-19. **Built 2026-11-20** in two slices: picking and the bar (D1–D3, D8),
  then the chords' colour (D4–D7). See *Build notes*. Device checks owed (Consequences). Decided with Tomisin the same day against a canvas
  mockup (`https://claude.ai/artifact/FnmVT9uSJF4o5jwYiQV9Jx`, private), over eight rounds: what 0291's
  *better thought out* meant, then picking, only what's picked lighting, the chords' colour, Roman
  numerals and their palette, and the bar. It is 1.5's item 3 (`docs/backlog.md`). Two more ideas came out
  of the same mockup and are parked as items of their own: Watch drawn as a guitar neck with strings
  that move, and a shape for a chord named by ear.
- **Date:** 2026-11-19 (`pocket-450-watch-what-you-pick`)
- **Amends:** ADR 0289 — **D2**: a riff no longer hides the chords under it. Under notes, a chord colours
  them and is never drawn (D4 here), and only what's picked lights (D3). **D6**: the eye in the map's
  toolbar is dropped, and the section heading's door is joined by picking (D1). **D8**: the top of the
  sheet says what was picked, where it starts, and the chord (D2, D4). D1, D3, D4, D5 and D7 stand.
  ADR 0291 — **D1**'s closed doors reopen as D1 here: the section heading's hold menu comes back, the eye
  doesn't. **D4**'s open question is answered here. ADR 0232 — **D11**: selecting starts from **Pick
  pieces…** (it was *Put it together…*), its bar offers **Watch** beside **Put it together**, and the
  bar's line shows only when the picks can't be put together (D8). The two shapes, and everything Put it
  together makes, stand.
- **Amended by:** ADR 0310 (2026-11-21) — **D1**: a section's name carries a visible eye that watches
  that section, and the map's toolbar a **Pick** button that starts picking with nothing picked. Picking,
  the section's hold menu, and the whole-song eye staying gone all stand.
- **Relates to:** 0254 (watching one loop, which this leaves as it is) · 0225 (the piece, and a chord
  named by ear) · 0227 D7 (what makes a label a chord) · 0123 (key-first spelling) · 0305 (a song's key
  describes the recording) · 0234 D5 (motion that stands for playing) · 0111 (a routine is reviewed before
  it's kept) · 0070 (never grades)
- **Schema:** none. It reads the song's key, the sections and the pieces already stored.

## Context

0289 built *Watch the section*. 0291 held it back from 1.4 after Tomisin's device check, with *"I feel like
it could be better thought out"*, and left what it becomes open.

On 2026-11-19 Tomisin said what that meant. First, it *"seemed to start at the beginning of the song
rather than the section"*. The code started at the section, but the door anyone would see was the eye in
the map's toolbar, which plays the whole song from 0:00. The section's door was in its heading's hold
menu, and a song with no section markers had no section door at all. Second, there was no way to watch a
run of loops inside a section (*"the 4th and the 5th"* of ten), or a run of sections.

The map already lets you pick pieces, for *Put it together* (0232 D11), and the player and the merge
already play any stretch. So the new part is choosing what to watch. Along the way, Tomisin asked for the
notes to show the chord they're played over.

## Decisions

**D1. One way of picking, with two ends.**
- Picking is the mode 0232 D11 built. A piece's hold menu starts it with **Pick pieces…**, with that piece
  picked. The bar's *"2 picked"* and the map's **Pieces** tab say the same word.
- While picking, tapping a section's name picks every piece in it, or lets them all go. The name shows a
  filled check when all are picked, a dash when some are, and an empty circle when none are. Two names in
  a row pick two sections.
- A section name's hold menu keeps **Watch it on the neck**, straight to the sheet for that section, and
  adds **Pick this section**.
- The eye in the map's toolbar is gone. The whole song is every section picked.

**D2. What plays, and how the sheet says so.** The stretch runs from the start of the first piece picked
to the end of the last, its repeats included (0232 D14), and goes round until stopped. The sheet's title
names what was picked: whole sections in a row by their names (*Verse 2 and Solo*; three or more, *Verse 2
to Chorus 3*), otherwise the pieces (*Solo 4 and Solo 5*; four or more, *Solo 3 to Solo 7*). Under it, the
bars and when they start: *Bars 39–42 · starts at 1:54*. The button says **Play from bar 39**, and a bar
counter runs while it plays. It opens at 100%, as 0289 D7 has it.

**D3. Only what's picked lights.** A notes piece in the stretch that isn't picked still plays, but stays
dark. The bar and the sheet both say so: *Solo 5 isn't picked, so it stays dark*. While a dark stretch
plays, the neck says *Not picked: Solo 5*. Among the picks, 0289's merge stands: where two notes pieces
overlap, the one that starts later shows.

**D4. Chords colour the notes; they aren't drawn under them.**
- With a notes piece picked, the neck shows only notes, never a chord's shape.
- Each note takes the colour of the chord the song is on when it's played. That's read from the song's
  chords lane, picked or not: the song is on those chords either way. A chord colours and never lights,
  so D3 holds.
- The heard note is filled with the colour, the other notes played over the same chord are tinted with
  it, and every chip wears its chord's colour, with the chord's name and numeral over the first chip of
  each chord.
- Over the neck sit the chord's name and numeral, and what comes next: *then G · VII*.
- A chord named by ear colours notes just as a placed one does: it only needs its name. A placed shape is
  read as Name the notes reads it (0227 D7).
- Where no chord plays, the notes are drawn as they are now.

**D5. Chords on their own.** With only chords picked, the chords are what plays. Each one's shape lights
in its colour, with its name and numeral. Only a chord placed on the neck has a shape to light (0289 D2).
One named by ear shows its name and colour alone, and giving it a shape is parked as its own item.

**D6. Roman numerals, counted from the song's own key.**
- The key's own 1 is I: in A minor, Am is **i**.
- The case says the kind of chord: upper case is major (**VII**), lower case minor (**iv**), **°**
  diminished, **+** augmented, and a seventh follows (**V7**, **IIImaj7**). So G (VII) is never read as G7
  (VII7), which plain numbers allowed.
- The colour comes from the root's degree alone, so E and Em are both the 5.
- A chord that isn't the key's own, with its root in the key but another kind, keeps its root's colour,
  but its numeral is outlined, not filled. The line beside it says what the key's own would be: D in A minor
  is **IV**, with *A minor's own here: iv*. In a minor key, V and vii° count as the key's own, since minor
  keys take them for the cadence so often.
- A root outside the key is silver, with its ♭ or ♯: **♭VII**.
- The app never says *borrowed*. A secondary dominant isn't borrowed, and the numeral already says what
  the chord is.
- With no key set, chords show their name with no colour and no numeral, and **Set the key** opens Edit
  song. There's no fallback palette, since blue would then mean the 1 in one song and the first chord in
  another.
- Numerals are relative to the key, so a song raised or lowered (0305) keeps its numerals and colours.

**D7. The palette.** Three families, one hue each, with the strongest chord in the strongest shade. They
stay clear of the app's green (live), red (delete), purple (pins), and the terracotta of the practice
accent and of a heard note with no chord under it.

| Family | Degree | Dark | Light |
|---|---|---|---|
| Home, where the song rests | I | `#4C9DFF` | `#0048A7` |
| | VI | `#7FB8FF` | `#265BA1` |
| | III | `#A9D2FF` | `#416698` |
| Moving away, leaving home | IV | `#F5B841` | `#7D4F00` |
| | II | `#F7DC86` | `#786228` |
| Tension, wants to go home | V | `#FF6F91` | `#A60D4B` |
| | VII | `#FFA8BD` | `#A63F73` |
| Outside the key | ♭/♯ | `#C7C7CC` | `#606069` |

- **Dark:** every value reads at 6.1:1 or more as text on the sheet (`#1C1C1E`), and carries the dark ink
  (`#040404`) at 7.4:1 or more when it fills the heard note or a numeral.
- **Light:** every value reads at 4.7:1 or more as text on the cream (`#F0E3D8`), and carries white at
  5.9:1 or more as a fill. Text on cream caps how light a shade can be, so in light mode the shades in a
  family differ by saturation rather than lightness.
- The chord's name over the neck is 20 pt bold, which counts as large text and needs 3:1 on its tint.
- The 4 and the 7 are the pair closest in lightness. For a player who can't tell their hues apart, the
  numeral beside every colour does the work: colour is never the only sign.
- They're named tokens in `DesignTokens.swift`, one asset per entry with both appearances, as
  `loopPalette`'s are, and a row in §3.1 of the design brief.

**D8. The bar while picking.**
- One line says what's picked and where: *Solo 4 and Solo 5 · Bars 39–42*. A second shows only when
  something in the stretch stays dark (D3).
- **Watch** and **Put it together** sit side by side, in the same style. Neither is the default, because
  why you picked is yours to say. Watch carries the eye, and VoiceOver reads it as *Watch it on the neck*.
  The sheet opens under its full name.
- Put it together's line shows only when it can't put the picks together (*Pieces in a row can't
  overlap*). When it can, the routine review that opens next shows what it makes.
- **Cancel** is unchanged. The bar ends up about a third shorter, and the map is what you're picking on.

### Rejected

- **Keeping the toolbar eye.** It was the door that started at 0:00 when a section was wanted, and the
  whole song is every section picked.
- **Lighting everything in the stretch, picked or not.** Tomisin chose only what's picked.
- **Drawing the chord under the notes**, as its notes across the neck or as its shape, with or without a
  switch. Tried in the mockup, then corrected by Tomisin: under notes, only the chord's colour and name.
- **Colouring chords in the order the song first plays them.** A colour would mean something different in
  every song.
- **Plain numbers, 1 to 7.** *G · 7* reads as G7.
- **Seven rainbow hues.** They're hard to tell apart as small dots, and they say nothing about what a
  chord does.
- **Colouring each note by its part in the chord** (root, 3rd, 5th, 7th). Offered beside chord numbers, and
  Tomisin chose the numbers. It would replace the chord's colour on the notes rather than add to it.
- **Name the notes drawn as a guitar neck.** Tomisin: the dot grid is better for naming, the guitar neck
  for watching. Watch's guitar neck is parked as its own item.

### Open, not decided here

- **Whether a loop's own sheet colours its notes too** (0254, from its five doors). Picking one piece and
  pressing Watch would colour them; the loop's own doors wouldn't, unless that's decided.
- **The light values in D7** are worked out from contrast and haven't been seen on the phone. A look in
  light mode settles them.

## Consequences

- **Code, when it's built.** `SectionWatch` merges the picks, not every piece in a stretch, and gains the
  chord context: which chord is under a time, from the whole chords lane. A pure `ChordNumeral` (root
  degree, kind, the key's own or not, the numeral) with its own unit tests. The sheet's header, chord row,
  neck colours and chips. `SongMapView`'s picking: section names while picking (`SongMapSectionHeading`
  is disabled while picking today), the section menu's second item, and the bar's two buttons
  (`SongMapTogetherBar`). The piece menu's label (`SongMapPieceMenu`). The toolbar eye's code goes, and
  `SongMapView.opensSectionWatch` goes with it.
- **The skipped whole-song UI test** (0291 D3) is rewritten to pick two sections, since the eye it opened
  is gone.
- **Docs owed with the build.** The manual: *Pick pieces…* replaces *Put it together…* in `songs.md` and
  `routines.md` (C9 checks `reference/**` against the Swift strings), and the section paragraphs 0291 D3
  removed come back.
  CHANGELOG: the *Held back* entry moves to the release. PROJECT.md, and §3.1 of the design brief for D7.
- **Device checks owed.** The bar's height on the phone while picking, and the palette in both
  appearances.

## Build notes

**Slice 1, 2026-11-20 (`pocket-453-pick-and-watch`): picking and the bar, D1–D3 and D8.**

- `SongMapPicking` (pure, `SongMapPickingTests`) holds what a section's name shows and picks, and reads the
  picks as a `Watch`: the stretch, its bars, the title, what lights and what stays dark. A section holds
  each piece whose middle it holds, as a loop's repeats already count the section it sits in.
- **D4's first point is in slice 1**: with a notes piece picked, the chords don't light, and an unpicked
  chord isn't called dark, since under notes it wouldn't have lit. With only chords picked, an unpicked
  piece of either kind is dark. That rule decides what D3's line says, so it couldn't wait for the colours.
- **A section with no pieces between two picked ones keeps the row** (*Verse to Chorus* over an empty
  Solo), since it plays in the stretch either way. Two sections apart with a picked-out one between are
  named by their pieces.
- **Never *the whole song*.** Every piece of a song with no sections still plays only from the first to the
  last, so its title is the pieces.
- In seconds, the place reads *1:54–2:10*, the sheet *Starts at 1:54*, and the button *Play from 1:54*.
  There's no bar to count.
- **Watch's line, when it can't open**: *Nothing picked is placed on the neck yet*, or that the song's audio
  can't play here. D8 doesn't say; a disabled button with no reason would be worse.
- Put it together's line for picks that *can* be put together is gone (D8): `SongMapTogether.line(for:)`
  returns `nil` for a shape. For one pick it now reads *To put them together, pick the next piece in the
  row…*, since Watch works with one.
- **The UI test picks a piece, not two sections.** The seed's song has no sections, and giving it some
  would move every other test that uses it. `testAPieceWatchedFromThePickingBarLightsItsNotes` drives
  *Pick pieces…* ▸ **Watch** ▸ play; what a section's name picks and what two sections are called are unit
  tests.

**Slice 2, 2026-11-20 (`pocket-454-chord-colours`): chords colour the notes, D4–D7.**

- `ChordNumeral` (pure, `ChordNumeralTests`) reads a chord against the key: the root's degree (the
  colour), the numeral, and whether it's the key's own. It shares `RomanNumeral`'s accidental tables
  (ADR 0065), so a diagram's badge and the sheet never number one root two ways. **Half-diminished reads
  `ø`** (*viiø7*): D6 names only ° and +, and *vii°7* is the diminished seventh. A chord with no third
  (*sus4*, *5*) is never outlined. Sevenths don't change what counts as the key's own: *V7* and *Vmaj7*
  are both a V.
- `SectionWatch.chords` reads the chord the song is on from **every** chords piece in the stretch, picked
  or not, sharing `merge`'s tap placing (the later-starting piece is the chord where two overlap). A tap
  that names no chord leaves the song on no chord until the next. `WatchChords` holds the same chord
  played again in a row as one, names each for the key, and **spells a root outside the key as its
  numeral says** (*B♭ · ♭II*, never *A♯*).
- Numerals and colours are read live from `song.heardKey`, so **Set the key** colours the sheet as soon
  as Edit song saves. The map's pieces are already as you hear them, so a raised song keeps its numerals.
- The heard note takes the chord's colour through the neck's own `neckAccent`, so its glow and marks
  follow. The lick's other spots over the same chord are tinted, and each chip's border wears its chord's
  colour, with *Am · i* over the first chip of each chord.
- **A loop's own sheet isn't coloured**: that's still open (*Open, not decided here*).
- The palette is eight colour assets plus `chordInk` (white in light, `#040404` in dark), and a row in §3.1
  of the design brief. A hosted snapshot in both appearances was looked at. The phone hasn't seen them.

