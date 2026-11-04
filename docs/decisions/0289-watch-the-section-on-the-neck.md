# ADR 0289 — Watch the section on the neck

- **Status:** Accepted. Planned with Tomisin as item 18 of the last feature push before 1.4 (the approved
  plan of 2026-11-02: *"Watch the section, playing straight through with gaps. When loops overlap, the one
  that starts later shows."*), and built that week.
- **Date:** 2026-11-04 (`pocket-410-watch-the-section`)
- **Amends:** ADR 0254 — **D1**: the sheet also opens on a stretch of a song, a section or the whole
  song, under the same name and icon. **D2**: two more doors on the song map, the section heading's hold
  menu and an eye in the toolbar, each behind the same gate read over the stretch. **D4**: every piece in
  the stretch is drawn, merged, and each loop's name leads its notes under the neck. **D6**: a stretch
  opens at 100%. D3, D5 and D7 stand, and so does the loop's own sheet.
- **Relates to:** 0232 (the song map: its sections, D6, and repeats, D14 and D15) · 0227 D5 (a join that
  no longer fits is dropped) · 0256 D3 (the plan gate, unchanged) · 0090 (sheets presented at the body
  root, by a stable value) · 0001 (Apple Music audio can't be played here)
- **Schema:** none. It reads the pieces the loops already store.

## Context

*Watch it on the neck* (0254) plays one loop with its lick lit on the neck. A song's solo or riff is
usually several loops, counted and named one at a time, and the song map lays them out section by
section. Nothing played them in order, so seeing how one lick leads into the next meant opening each
loop in turn.

## Decisions

**D1. A stretch of the song, played straight through.** The sheet plays the song from the stretch's
start to its end, and round again until it's stopped, as a loop goes round. `LoopRunModel` gains a
region that is a span of a song rather than a loop, and `ContinuousLoopPlayer` an initialiser for it. A
loop's region is still read when its audio loads, as before. Only the recording sounds (0254 D3).

**D2. What lights is every piece in the stretch, merged in song time** (`SectionWatch`):
- Only loops with a piece placed on the neck take part. A part named only by ear lights nothing, and
  it mustn't hide a riff under it.
- **Where two overlap, the one that starts later shows**, for as long as it lasts, and the earlier one
  comes back when it ends. Starting at the same moment, the notes lane shows over the chords lane.
- A loop's repeats (0232 D14, D15) light on every pass, since the riff is heard again.

**D3. Gaps light nothing.** A note is heard until the next note or the end of its loop. Where no piece
covers the song, the neck goes quiet until the next one.

**D4. One tuning per sheet.** The first piece's tuning is used, and pieces named in another are left
out, since their frets would be drawn on the wrong strings. The top of the sheet says how many.

**D5. Joins only where they were named.** A hammer-on, pull-off or slide from the tap before is kept only
when the tap before is the one it was named against. Across two loops, or into a repeat's first note,
it's dropped, as 0227 D5 drops a join that no longer fits. A lead-in inside a note stays.

**D6. Two doors on the song map**, each behind 0254 D2's gate read over the stretch (something in it is
placed on the neck, and the song's audio plays here):
- a section: **Watch it on the neck** in the hold menu of the section's name (*Start* for the stretch
  before the first section);
- the whole song: an eye in the map's toolbar.

The audio half of the gate is one rule, `LoopModeAccess.Facts.audioResolves(_:)`, which a loop's facts
now read too. The plan gate (0256 D3) is the sheet's own, so it's unchanged.

**D7. A stretch opens at 100%**, the record's own tempo. Each loop in it can have a different command
tempo, so no one loop's is the right place to start. − and + work as before.

**D8. The sheet's top says what's playing**: the section's name (or *The whole song*), the song, and the
loops whose pieces it plays. Under the neck, when there's more than one, each loop's name sits where its
notes begin. *Play the section* or *Play the song* replaces *Play the loop*.

### Rejected

- **Playing each loop in turn, as a playlist.** The gaps and overlaps are what the song does, and
  playing the song keeps the time real.
- **Lighting both loops where they overlap.** Two notes lit at once on one neck read as a chord.
- **A section's own tempo.** Nothing stores one, and adding one is a schema change for a viewer.

### What stays out

- A section written *as Verse 1* (0232 D8) has no pieces of its own, so it gets no door. Its music is
  watched from the section it names.
- The Tab view's section headings don't get the door. The board's do.

## Consequences

- New: `SectionWatch` (pure, `SectionWatchTests`), `WatchSpanHeader`, `SongMapView+Watch`. Changed:
  `WatchOnNeckSheet` takes a loop or a span and reads the heard tap from the run; `LoopRunModel` and
  `ContinuousLoopPlayer` play a span; `SongMapSectionHeading` takes a hold menu.
- A loop's own sheet plays the same as before: its piece is a run of one loop, each tap heard until the
  next.
- **Device check owed (Tomisin):** watch a section with two loops, and the whole song, on a real song.
