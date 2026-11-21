# ADR 0310 — The map's doors to picking, and copies that keep their place in the bar

- **Status:** Accepted on 2026-11-21. Tomisin decided all five the same day, after the 11-21 phone round
  (ADR 0309 left them open): *"for 1, I meant both. I'm happy with your recommendations, including the
  shift option"*. Built on `pocket-457-song-map-pick-and-copy`; see *Build notes*. Seen on the phone the
  same day, with a new copy into *Sunday Morning*'s Solo: *"Much better result, the chord changes actually
  match with the song"*.
- **Date:** 2026-11-21 (`pocket-457-song-map-pick-and-copy`)
- **Amends:** ADR 0308 — **D1**: a section's name carries a visible eye, and the map's toolbar a
  **Pick** button (D1, D2 here). Picking, the section's hold menu, and the toolbar eye's removal stand:
  the new eye watches one section, never the song from 0:00. ADR 0232 — **D16**: with bars, a copy keeps
  each tap's place in the bar, starting at the first bar the piece fits in (D3 here); *"Nothing is
  snapped"* still holds for a tap's place in its bar, and without bars nothing changes. **D17**: the map
  can remove a copy it made, while the copy is just as it made it (D5 here), and can shift one by a beat
  (D4). Everything else in D17 stands: Undo, and no delete for a loop made on the waveform.
- **Relates to:** 0309 (the round these came from) · 0254 D2 (Watch's gate) · 0019 (a loop's delete on
  the waveform) · 0233 (a piece's versions) · 0281 (a beat map's bars) · 0139 O6 (declared, never
  inferred) · 0070 (never grades)
- **Schema:** none in SwiftData. A piece gains one optional field in its JSON, `copiedAt` (D5), which
  an older build ignores.

## Context

On the phone on 2026-11-21, Tomisin found two things on the song map.

- **Picking was hard to find.** Since ADR 0308 dropped the toolbar's eye, the only ways in were hold
  menus: **Pick pieces…** at the end of a piece's, and **Watch it on the neck** on a section name's.
  *"After transcribing the notes of a section or even a whole song, the most satisfying thing would be to
  see how it all comes together."*
- **A copy didn't line up, and couldn't be taken off.** In *Sunday Morning guitar cover* the chords
  copied to the Solo landed off their beats. The phone's store showed why. Every section marker sat on
  beat 2 of its bar but *Solo start*, on beat 4, two beats from the rest. It's where the solo's line
  starts, since *Chunk 1* starts at the same moment. A copy put each tap as far from the marker as it
  was from its own loop's start, so the Dm7 that was on beat 2.19 in bar 1 landed on beat 3.96 of bar
  64: half a bar out, every chord. By the time the player saw it, Undo had gone, and the map doesn't
  delete (0232 D17).

## Decisions

### D1 — An eye on a section's name

- A section's heading carries an eye beside its name, when the section has something placed on the neck
  and the song's audio plays here (0254 D2's gate). One tap opens **Watch it on the neck** for that
  section, as its hold menu does.
- It plays that section, never the song from 0:00: the reason the toolbar's eye went (0308).
- It isn't there while picking, when a tap on the name picks the section.

### D2 — Pick in the toolbar

- On the Pieces view, with pieces on the board, the toolbar has **Pick**. It starts picking with nothing
  picked, as **Select** does in Photos, so a run like *Chunk 4 and Chunk 5* is two taps away.
- It plays nothing. The bar's **Cancel** ends picking, and the toolbar's Pick waits until then.
- **Pick pieces…** stays on a piece's hold menu, where it starts with that piece picked.

### D3 — With bars, a copy keeps each tap's place in the bar

- Each tap is read as its place in the bars of the loop it's copied from: so many bars on, so far into
  the bar. A pass is written at a bar line, every tap at its place, so a chord on beat 2 is copied to
  beat 2. Through a beat map's bars too (0281), since each bar is measured as it is.
- The first pass starts at the first bar where the piece fits inside the place: its first tap at or
  after the place's start. A section that starts on the solo's pickup gets its first pass at the next
  bar, and its chords on their beats.
- A first tap a hair before the place's start, up to a sixteenth of a bar, still fits and is written at
  the start: a section whose marker sits just after the 1 doesn't push every chord a bar on.
- Without bars nothing changes: each tap is as far into its pass as it was into the loop.

### D4 — Shift a copy by a beat

- A copy the map made has **Shift a beat earlier** and **Shift a beat later** in its hold menu, while
  it's as the map made it (D5), when the map has bars. Every tap moves one beat, through the bar line
  if it has to, and a tap that would leave the loop is left off.
- An Undo, *Shifted Solo start chords a beat later · Undo*, puts the piece back as it was.
- It's for when the placement guessed wrong. A copy that has been changed is the player's, and Active
  listening is where it's worked on.

### D5 — Remove a copy the map made, while it's as the map made it

- A copy's hold menu has **Remove copy** while the copy is just as the map made it, or shifted. It asks
  first, and removes that loop and nothing else.
- *As the map made it* is declared, never guessed (0139 O6): the map stamps the piece it writes with
  `copiedAt`, and the copy is still the map's while its piece's `changedAt` is that time, it keeps no
  other version (0233), and nothing hangs off the loop: no Journal line, take, snag, reference, routine
  block or changed span, and it's never been practised.
- Not the loop the waveform is playing, when the map was opened from the practice screen.
- Once the player changes it, it's theirs, and deleting it stays on the waveform (0232 D17, 0019).
- A copy made before this build carries no stamp, so it isn't offered: its way out is still the
  waveform.

### Rejected

- **One control for both doors** (the toolbar's Pick putting an eye on each name). Tomisin meant both.
- **Snapping a copy's start to the nearest bar line.** On Tomisin's solo it would have kept the half-bar
  error, since the source loop starts on beat 2. Each tap's place in the bar is what has to carry.
- **Guessing which loops are copies** from their taps. Inferred, and wrong for a copy edited back.
- **An Undo for Remove copy** instead of asking first. A removed loop can't be brought back whole
  without holding the delete off, as the waveform does; asking keeps it simple, and a copy the map made
  can be made again.
- **Shift for any piece.** A piece the player counted is placed where they tapped it.

### Not decided here

- **Moving Pick pieces… up a piece's hold menu**, beside View tab and the modes. Raised with the doors,
  not decided.
- **Repeats that drift.** Tomisin had tried *Repeats to the end of the song* on the same chords the day
  before, and they didn't keep time either. A repeat steps by the loop's length as drawn (`SongTabLayout`
  and `SectionWatch` both use `end - start`), not by whole bars as a copy's pass does: *Chords* is 10.837 s
  where four bars are 10.878 s, so each pass came 41 ms early, about a beat by the Solo and a beat and a half
  by the end. Stepping repeats by whole bars when there are bars would amend 0232 D14 and D18. Tomisin put it
  in the backlog the same day (`docs/backlog.md`, *A loop's repeats keep to the bar*).
- **The song's grid looking a beat early** on Tomisin's song (every marker on beat 2, the chords changing
  on 2 and 4). That's the song's own 1, set on the waveform.

## Consequences

- **Docs.** The manual's map paragraphs in `songs.md` (copies keep their place in the bar; shift and
  remove a copy; the eye and Pick), and `reference/practice.md`'s paragraph on watching what you pick.
- **On the phone, 2026-11-21.** Built on Tomisin's iPhone with these to try: the old copy deleted on the
  waveform, a new copy into the Solo, shift and Undo, Remove copy, the Solo's eye, and Pick with two chunks.
  Tomisin: *"happy with this … the chords changes actually match with the song"*.

## Build notes

**2026-11-21, `pocket-457-song-map-pick-and-copy`.**

- **D1.** The eye is `SongMapSectionHeading.watchButton`, on the same `onWatch` the hold menu already had, so it
  has the same gate. It sits **before** the bars rather than after them: after them, the bars of a section
  with an eye stood out of line with one without. Its tap area is 44pt wide and runs mostly to the left of the
  glyph. Seen in a hosted window, light and dark, with *as Verse 1*, without an eye on *Start*, and while
  picking.
- **D2.** `SongMapView.toolbar` shows **Pick** on the Pieces view with pieces, and not while picking.
  `startPicking()` sets an empty selection, and the bar's existing line (*Tap pieces…*) says what to do.
  `WatchOnNeckUITests.testAPieceWatchedFromThePickingBarLightsItsNotes` now comes in this way.
- **D3.** `SongMapBars` (pure, `SongMapCopyBarTests`) reads a time as a place in the bars: so many bars from
  the first downbeat, and so far into a bar measured from its downbeat to the next. `SongMapCopy.taps` writes
  each tap at its place from the bar the source loop starts in, which counts a start a hair before a downbeat
  as that bar (D18's hair). A first tap up to a sixteenth of a bar early fits and is written at the start
  (`fitSlack`). One test is Tomisin's own solo, with the phone's numbers: the Dm7 lands on beat 2.19 of bar
  65, every chord on its own beat, 91 of them.
- **Why the old tests didn't catch it.** Their source loops start on a downbeat, where a tap's distance from
  the loop's start and its place in the bar are the same thing. A mutant putting the old distance back passed
  every one of them, and failed only the solo's test.
- **D4.** `SongMapCopy.shifted` moves each tap a beat (the bar over `Grid.beatsPerBar`, new, from the song)
  through the bar line, and leaves off a tap that would leave the loop. `SongMapWriter.shift` restamps both
  dates, so the copy stays the map's. The Undo reuses the map's toast, with `Made.restore` holding the piece.
  A shift that would leave no tap, or move none, does nothing.
- **D5.** `PieceTranscription.copiedAt`, stamped by `SongMapCopy.copies`. Every save path already writes
  `changedAt` (naming, a new pass, a version swapped in), so the stamp needs no other code to go stale.
  `SongMapWriter.standing` reads the loop's own relationships for the menu. `removeCopy` also fetches routine
  blocks and practice runs (both can be saved in another context, which a loop's relationships don't hear
  of), every run filtered in memory rather than through an optional in a `#Predicate`. The waveform's
  playing loop reaches the map as `heldLoop`, through `SongDetailsSheet`. The question is
  `SongMapCopyPrompts`, at the map's root.
- **The UI test** (`SongMapCopyUITests`) copies the watch seed's riff, removes the copy from its hold menu, and
  checks every other piece is still there and the riff offers no Remove copy. `NamingPieceSeed` takes out any
  stamped copy on launch, so a failed run leaves nothing. The seed's song has no tempo, so the test sees no
  Shift: what a shift does is in `SongMapCopyWriterTests`.
- **Mutants.** First-fit off, the old distance back, the shift's sign dropped, kept versions ignored, and the
  practice-run fetch skipped: each failed the test aimed at it, and the source was restored byte-identical.
