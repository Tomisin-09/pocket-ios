# ADR 0283 — Hear the tempo and count the bar inside the tempo sheet

- **Status:** Accepted. Agreed with Tomisin on 2026-11-02 as the last of the beat map in 1.4: B4
  (count the bar by choosing), the tempo sheet's layout, and a steady-tempo warning.
- **Date:** 2026-11-03 (`pocket-401-hear-the-tempo-in-the-sheet`)
- **Amends:** ADR 0051, its second decision: the meter is still chosen in the tempo sheet and
  committed with the tempo, but as *Beats in a bar* (3, 4 or More) in the section for the 1, not as
  a picker over every preset in a section of its own (D2). The per-song meter, the gridlines toggle
  and the bar lines stand.
- **Relates to:** 0026 and 0027 (the song's click and its switch on the speed bar, unchanged), 0024
  (the tap pad keeps Reset; its Play moves to the strip), 0154 (a 1 moved by D3 keeps the song's
  corrections), 0281 (on a beat map, D3 steps along the map), 0282 (D4 answers half of its open
  question)
- **Schema:** none.

## Context

On 2026-11-02 Tomisin cut what was left of the beat map for 1.4 down to three things, with the rest
after the release (B3, B5, B6 and B4b): *"Could we soley do b4 + ui interface settings? We'll add a
warning that it only works well with tracks with a steady tempo."* The interface they meant is the
tempo sheet's: *"We also need to find a way to test the tempo from within the sheet, as it is now,
you have to exit out of the tempo sheet before being able to switch it on by tapping the symbol."*

The click's only switch is the metronome on the speed bar (ADR 0027), and the sheet covers it. So
setting a tempo was: set it, Done, tap the metronome, listen, hold the metronome to reopen the
sheet, and again. The sheet had a Play button, but only in Tap mode, under the pad.

B4 is backlog item 11: *how many beats in a bar, then which is the 1*, each answered by ear with the
1 accented. The proposal's screen 3 drew it as two rows of buttons. Without B3 there is no beat
finder, so the beats come from the one tempo (or a tapped map) and the 1 the player or the estimate
placed. What the player can't easily do today is move that 1 by a beat: the estimate can put it a
beat off (ADR 0282's footer says so), and the fix was to find the right beat on the waveform.

Tomisin approved the layout below on 2026-11-02 ("I'm happy to go with your recommended approach"),
including three choices put to them: the click plays values not yet saved and Cancel puts the
song's click back; the warning's words and place; and a row of numbered beats for the 1 rather than
earlier and later buttons.

## Decisions

**D1. Play and the click sit above the sheet's form, and the click plays the sheet's values.** A
strip pinned under the navigation bar, in both modes, holds **Play** (Pause while playing) and a
**Click** switch. It stays in view while the form scrolls, so the player can listen while choosing
the 1 at the bottom. The tap pad's own Play moved there, since one sheet doesn't need two.

- **The click plays what Done would commit**: the tempo in the field or the taps, the 1 as moved by
  D3, and the bar from D2. It follows every change while it plays. The grid it plays is built by
  `commitTempo`'s own rules (`gridIfCommitted`): a tempo given replaces a beat map, a 1 given keeps
  the song's corrections. A test commits each case and compares, so the preview can't promise what
  Done doesn't keep.
- **Only the engine's click changes until Done.** The song's `metronomeOn` is untouched.
- **Done keeps the switch** as the sheet left it, if there's a grid to click.
- **Any other way out puts the song's click back** (Cancel, a swipe down, *Set the 1 on the
  waveform*): on or off as it was, playing the song's grid as it now stands.
- The switch is greyed out until there's a tempo and a 1.

**D2. Beats in a bar: 3, 4 or More.** The first row of the section for the 1. **3** and **4** set
3/4 and 4/4; **More…** shows the full list of time signatures under it, for 2/4, 5/4, 6/8, 7/8 and
12/8. It opens already showing the list for a song in one of those. This answers backlog item 11's
first open question: 5, 6 and 7 sit behind More. The second, whether a 6/8 song counts in 6 or in 2,
is not decided here. The 6/8 preset still clicks six to the bar, as ADR 0051 left it.

**D3. Which beat is the 1: one button a beat.** The second row: **1 2 3 4** for a bar of four, six
for 6/8, twelve in two rows for 12/8. The click plays the 1 higher (ADR 0026's accent), so choosing a
beat moves the accent there, and the player keeps the beat that sounds like the start of the bar.

- **Counted from the 1 as placed.** Choosing 3 moves the 1 two beats later. On one tempo that is two
  steps of the beat. On a beat map it is two of the map's own beats, from the one the 1 marks
  (`BeatGrid.one`).
- **Placing the 1 again counts from it.** Marking it, an estimate, Half or Double, or clearing it
  resets the choice to 1 (`DownbeatChoice`), so a beat chosen against one placing is never applied
  to another.
- **Half and Double keep a chosen 1.** It is a 1 the player has placed, so ADR 0282 D5 applies: it
  stays where they heard it.
- **A choice past the bar counts as 1.** Choosing 4, then 3 beats a bar, leaves the 1 where it was
  placed.
- The row is greyed out until there's a tempo and a 1. Nothing is snapped to the audio: the 1 moves
  by whole beats of the grid.

**D4. A steady-tempo warning, the same for every song.** Under *Estimate from audio*: *"Works best
with songs played to a click. A song that speeds up or slows down will drift."* It is what one tempo
can't do, said where a tempo is set. ADR 0282 left open whether the estimate should say so for the
song in hand. This settles the general warning; a message for one song is still not decided here.
The section for the 1 keeps the remedy, setting the 1 again on the waveform where a song drifts
(ADR 0154).

## Alternatives considered

- **The sheet's switch is the song's switch.** Simpler: no preview, no putting back. But Cancel
  would then leave behind a click the player only turned on to try a tempo they threw away, and
  the click would play the song's saved grid, not the values being tried.
- **Earlier and later buttons for the 1.** One pair works for any bar, but a beat can't be chosen
  directly, and four taps to come back round a bar of four is worse than one.
- **A segmented control of every meter.** Seven segments fit a phone, but most songs are in 3 or 4,
  and the other five crowd them.
- **Snap the moved 1 onto a hit in the audio**, as the waveform's handle does (ADR 0024). The 1 is
  already on the grid, and moving it by whole beats keeps it there. A snap could pull it off by the
  window's width.
- **A warning only when a song is found to move.** Needs a measure of how much a song moves, and
  B3's beat finder is where that comes from. After 1.4.

## Consequences

- The tempo editor figure in the manual is stale (owed since ADR 0282), and now shows the wrong
  sections too. It's noted for the one reshoot.
- `BPMSheet` takes another set of hooks, `TempoClickHooks`, `nil` in previews like `BeatMapHooks`.
- With the click on, each tap in Tap mode changes the tempo the click plays, and the click is
  scheduled again from the playhead, as it is after a seek (`flushMetronome`).
- *Set the 1 on the waveform* still starts its handle from the song's 1, not the beat chosen in the
  sheet, as it always did for a 1 marked there and not yet saved.
