# ADR 0315 — A loop's repeats keep to the bar

- **Status:** Accepted on 2026-11-24, for 1.6, and built on `pocket-470-repeats-keep-the-bar`. Tomisin
  asked to revisit the drift on *Sunday Morning* (logged in the backlog on 2026-11-21, while building ADR
  0310) and chose to build it in 1.6, before release.
- **Date:** 2026-11-24
- **Amends:** ADR 0232 — **D14**: with bars, a repeat's **↻ ×N** counts passes of the loop's length to
  the nearest whole bar, not of its length as drawn (D1 here). **D18**: with bars, each pass is written
  that many whole bars on, each tap at its place in the bar, not as far into its pass as it is into the
  loop (D1, D2 here). Without bars, both stand as written. ADR 0308 — **D2**: the stretch Watch plays and
  lights runs over passes that keep to the bar (D3 here). What plays, and how the sheet says so, stand.
- **Relates to:** 0310 D3 (a copy's pass is already whole bars, and this reads taps through the same
  `SongMapBars`) · 0281 (a beat map's bars, read as they're played) · 0154 (the beat grid) · 0232 D10
  (drawn, never copied) · 0070 (nothing here grades playing)
- **Schema:** none. Nothing stored changes; every pass is still drawn from the one piece.

## Context

On *Sunday Morning guitar cover*, Tomisin set the intro's *Chords* to repeat to the end of the song, and
the chord changes slid off the record as the song went on. A repeat stepped by the loop's length as drawn:
`SongTabLayout.sounds`, `SectionWatch.entries` and `SongMapLayout.repeats` all used `end - start`.
*Chords* is 10.837 s where four bars at 88.25 BPM are 10.878 s, so each pass came 41 ms early: about a
beat out by the Solo, and a beat and a half by the end. It wasn't the song's tempo. A copy into the Solo
(0310 D3) kept time to the last bar, because a copy's pass is whole bars.

A loop is drawn by hand on the waveform, so it's almost never exactly a whole number of bars. The error
is small on one pass and adds up on every pass after it.

## Decision

**D1. With bars, a repeat steps by whole bars.** A pass is the loop's length to the nearest whole bar, at
least one, exactly as a copy's pass is (`SongMapCopy.period`). **↻ ×N** counts those passes, to the
nearest whole pass, from the loop's start to where the repeats stop.

**D2. Each tap keeps its place in the bar.** A tap is read as so many bars into the loop and so far into
its bar (`SongMapBars`), and written at the same place that many whole bars on. On a beat map (0281),
whose bars are measured as they're played, a pass follows the bars as played, not a fixed length.

**D3. Everywhere a repeat is drawn.** The map's band and its **↻ ×N** (D14), the Tab view's written-out
passes (D18), and what Watch lights for a repeat (0308 D2). The band still runs to where the player said
the repeats stop.

**D4. Without bars, nothing changes.** A song with no grid repeats by the loop's length as drawn, as
before: there's no bar to keep to.

**D5. The loop's own audio is unchanged.** Playing the loop still plays the region drawn on the waveform.
This changes where the map, the tab and Watch say the repeats fall in the song, not what the loop plays.

## Consequences

- A loop drawn a hair long or short now repeats in time with the song's bars to the end, which is what
  the player meant by *repeats*. A loop drawn to exactly a whole number of bars reads as before.
- A loop drawn as, say, three and a half bars repeats every four (or every three), as a copy of it would.
  That's the same rounding 0310 D3 chose for copies, so a copy and a repeat of one loop agree.
- `SongTabLayout.sounds`, `SectionWatch` and `SongMapLayout.repeats` take the grid, and all three step
  their passes through one pure helper, `SongMapRepeats`, so the map, the tab and Watch can't disagree.
  `SongMapRepeatsTests` holds it with *Sunday Morning*'s own numbers, and through the Tab view's and
  Watch's own builds.
- **A loop drawn a hair over its whole bars** has a tap or two in that hair: usually the next pass's 1,
  counted early. Only one pass's worth of taps repeats, and a pass after the first starts no earlier than
  the loop's end, so that 1 isn't written twice. The loop's own taps are always written as counted.
- The backlog entry *A loop's repeats keep to the bar* is done.
- **Seen on the phone, 2026-11-24:** Tomisin checked *Sunday Morning* on a build of this branch: *"All good
on the phone."*

## Alternatives

- **Snap the loop's edges to the bar when repeats are set.** Rejected: it changes what the loop plays,
  and a loop is the player's region on the waveform. The map should read the loop, not rewrite it.
- **Keep the length as drawn and correct the drift at each section's start.** Rejected: it hides the
  error in jumps, and a repeat to the end of a one-section song would still drift.
