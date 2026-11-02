# ADR 0281 — A song can store its beats

- **Status:** Accepted. Planned with Tomisin on 2026-11-02 as B2 of the beat map, part of the last
  feature push before 1.4 (`docs/backlog.md`). The screen in D5 is a proposal to try on the device,
  as the plan asked: "build it, then try it".
- **Date:** 2026-11-02 (`pocket-399-song-stores-its-beats`)
- **Amends:** ADR 0022: the grid was a tempo plus a phase. A song with a beat map is gridded from
  its beats, and its 1 marks which of them starts a bar (D1, D2). The single-tempo grid it describes
  is unchanged for every song without a map. ADR 0154: its first two rejected alternatives, a full
  tempo map and re-anchoring by detection, are answered in D6. A correction keeps its meaning on a
  map, *the bar count restarts here* (D2). Its single-tempo grid and its ✓ and Move rules stand.
- **Relates to:** 0004 (an estimate never commits itself), 0024 (the peak snap D5 narrows), 0153
  (the memoised grid, D8), 0166 (the windowed tap reading the new screen shows), 0170 (the tempo
  carried out of a song, which reads D3's median), 0212 (the archive rule D7 follows), 0225 and 0232
  (Count the notes and the song map, both now gridded by D8)
- **Replaces:** the backlog entry *A song whose tempo changes at a section*. A song that slows for
  its bridge is a beat map whose gaps widen there.
- **Schema:** one additive field, `Song.beatTimes: [Double] = []`. Lightweight migration fills
  existing songs with an empty array, and nothing is lost. The archive's `SongRecord` gains an
  optional `beatTimes`, and `schemaVersion` does not move (ADR 0212 D4's reasoning).

## Context

1.4 was taken off review on 2026-11-02 because setting the tempo isn't good enough to ask people to
pay for. The main complaint is drift. One tempo and a 1 draw the grid as a straight line, and a band
that played without a click speeds up and settles, so the line slides off the music. 0154 let the
player correct the line further in, which stops the error building past a correction, but every
stretch between two corrections is still straight. A song that keeps moving needs a correction
every few bars.

The beat-map proposal (artifact, 2 November) replaces the line with the beats themselves. It is
built in six slices. B1 (#391) taught the estimate to hear new notes as well as drums. On the device
afterwards, *Binta*'s single-tempo grid still drifted, which is the thing this slice fixes.

**B2 is the foundation:** the model, the grid, and the one way to make a map that needs no detection,
which is tapping through the song. Detection (B3), counting the bar (B4), fixing a stretch (B5) and
the tempo lane (B6) all build on it.

The backlog had already found what makes this cheap: nothing after `BeatGrid` reads a tempo. The
click (`MetronomeSchedule`), snapping, the grid lines and the bars all take beat times. A map
therefore lands inside the grid and the screens that author it, and nowhere else.

## Decisions

### D1 — the song stores its beats

`Song.beatTimes: [TimeInterval] = []` holds every beat in song seconds, ascending. It has the same
shape as 0154's `extraDownbeatSeconds`: primitives, a declaration default, no stored enum, and a
migration already proven on a device. A four-minute song is a few hundred numbers.

A map is **at least four beats** (`BeatMap.minBeats`), the fewest that have a median worth taking.
Anything shorter grids the song from its one tempo, as before. `Song.hasBeatMap` asks the question,
so no reader counts beats for itself.

### D2 — the 1 marks a beat

`downbeatSeconds` stays the primary anchor. On a map it marks **the beat nearest it** as a 1, and
bars count `beatsPerBar` beats from there in both directions. An 0154 correction marks the beat
nearest it and restarts the count. On a one-tempo grid a correction fixes drift. On a map it fixes
a short bar or a count that went wrong. Two anchors on the same beat are one.

**No 1, no grid**, unchanged from 0022. The map knows where the beats are, not which of them starts
a bar. Finding that is B4.

**Before the map's first beat and after its last**, the grid carries on to the ends of the song at
the tempo at that end: the median of the first or last four gaps. A tap-through that started after
the intro or stopped before the outro still grids the whole song. This is the same thing 0022's
pre-roll does for one tempo.

### D3 — the tempo is the map's median

When a map is stored, `preciseBPM` becomes the median of its gaps as a tempo, and `bpm` becomes that
rounded. Every reader of one tempo keeps working with no change of its own: the readout, the tempo
carried out of a song (0170), count-ins, and 0154's half-a-beat rule for a dropped correction.
`tempoBPM` falls back to the map's median only when both stored fields are empty, which only a damaged
restore would leave.

### D4 — a tempo given as a number replaces the map

A tempo typed, tapped on the pad or accepted from an estimate in the tempo sheet means **one steady
tempo**. So `commitTempo` clears the map, with an undo, because the map may be a whole song's worth of
tapping. The sheet says so before it happens: a song with a map shows **The beats** at the top of the
sheet, with the count, the tempo range and **`Use one tempo`**.

An untouched Manual field no longer commits. It only showed the song's tempo rounded, so committing
it rounded the tempo, and with a map it would have dropped the map. `SongEditSheet` is not changed. Its
BPM field writes only `bpm`, which a stored `preciseBPM` already outranks, so it never reached the
grid of a tapped song and can't reach a map either.

### D5 — Tap through the song

A new screen, pushed from the tempo sheet's Tap mode: **`Tap through the song`**. It plays the song
from the top, and every tap is a beat. `From the start` lets go of an armed loop or an A/B span
first, since either would keep playback inside one stretch. The speed is kept, because taps read the
playhead in song time.

It is **kept apart from the tap pad.** The pad's taps measure a tempo for a grid that passes through
the 1 the player placed. Turning those eight or twelve taps into a map would anchor the grid to the
taps' jitter instead, and carry it to the ends of the song from there.

The taps are cleaned into a map (`BeatMap.fromTaps`):

1. They are **sorted**, because a loop that wrapped puts later taps earlier.
2. **Near-duplicates are dropped.** Two taps closer than half a beat are a fumble, or one beat tapped
   on two passes of a loop. The first is kept.
3. **Missed beats are filled.** A gap of one and a half beats or more gets evenly spaced beats. The
   beat it is measured against is the median of up to four gaps either side, so a song that slows
   for its bridge isn't mistaken for one that skipped a beat there.

Before cleaning, **a tap moves onto a hit only when the hit is clear.** The hit must be the strongest
onset peak within 50 ms of the tap, at least twice the median onset over the half second either side.
This narrows 0024's rule. The 1 snaps to the loudest bar near where it is dropped, because the player
dropped it looking at the waveform. A tap was aimed by ear, so on a quiet stretch with no clear hit
the tap is the better guess.

**The 1** stays where the player put it and moves onto the nearest beat. A song with no 1 takes the
first tap as its 1, and the screen's instruction tells the player to start on one. The whole commit
is undoable.

### D6 — what 0154 turned down

0154 rejected **a full tempo map** on cost, "for material most players don't bring". Tomisin's verdict
on the device reverses that: this is where the app is weakest. The cost also turned out smaller than
0154 priced it, because the readers after the grid already take beat times. The shape is different
from the one 0154 described. It stores **the beats, not (time, BPM) pairs with interpolation**, so
there is nothing to integrate, and a stated tempo change is just wider gaps.

0154 rejected **re-anchoring by detection** because it silently moved a grid the player had set.
Nothing here moves a grid on its own. A map is stored only when the player commits a tap-through, and
B3's detection will only propose one, under 0004.

**Per-loop tempo overrides** stay rejected, for 0154's reason.

### D7 — the archive carries the map as an optional

`SongRecord.beatTimes: [TimeInterval]?` is written `nil` for a song without a map, so such a song
exports exactly as before, and read through `?? []`. This follows 0212 D3's scalar rule rather than a
named container overload, because `[Double]` is not a type the format owns. An overload on it would
default every missing `[Double]` in every `Codable` type. Restore and a shared song (0236) both read
the same record, so a song sent as a file carries its map.

### D8 — one entry point builds every grid

`BeatGrid.beats(bpm:map:duration:anchors:beatsPerBar:)`, and `Song.gridBeats(duration:)` over it,
build every grid. The map wins when there is one. Its three readers all call it: the waveform
(memoised), the song map (0232) and Count the notes (0225).

- The waveform's `GridKey` **gains the map**. Without it the cached grid would keep the straight
  line over the beats just tapped, the 0153 trap that 0154 has already paid for once.
- Count the notes divides taps into slots one beat wide. On a map that is **the beat here**, the
  median gap across the region, and not the song's median.

## Alternatives considered

**The backlog's preferred shape, a tempo per anchor** (a `TempoAnchor` entity with an optional BPM,
piecewise-constant). It covers a song that changes tempo at a section and does nothing for a band that
drifts, which is the complaint. A beat map covers both. It was also a new entity, where this is one
field.

**Every tap on the tap pad becomes a beat.** Rejected in D5: the pad's few taps would replace the 1 as
the grid's anchor.

**Leave missed beats as gaps.** Rejected because one missed tap would shift every bar line after it by
a beat.

**Snap every tap, as 0024 snaps the 1.** Rejected in D5. A tap with no clear hit near it would move to
the strongest of several weak peaks, which on a busy mix is often the hi-hat between beats.

**An optional `[Double]?` on the model.** Rejected because it gives two kinds of empty, `nil` and `[]`.
The declaration-default array is the shape 0154 already took through a migration on a device.

## Consequences

- The upgrade over an existing store was checked on the simulator in this branch. **The device check
  is owed**, per `docs/swiftdata-gotchas.md`. The in-memory test store starts empty and can't catch a
  failed migration.
- **A long gap is filled evenly**, and on a drifting song the count over it can be a beat out. A
  correction after the gap restarts the count, and B5 will fix the stretch itself.
- **Corrections are drawn where they were placed**, which on a map can be a few milliseconds off the
  beat they mark. The primary 1 is moved onto its beat when a map is stored.
- The tempo editor gains **`Tap through the song`** and, on a song with a map, **The beats**. The
  manual's tempo-editor section names both, and its figure is now stale.
- Owed on the device: Tomisin's own drifting songs, tapped through. Does the click stay with the band?
