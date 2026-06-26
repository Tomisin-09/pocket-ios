# 0044 — Songs resume at their last-practiced tempo (extends 0040, refines 0029)

- **Status:** Accepted
- **Date:** 2026-06-26

## Context

ADR 0040 gave *loops* a memory of the speed you practise them at, so a loop
slowed to 0.7× reopens at 0.7×. The **full song** got no such memory: ADR 0029
("clean on entry") and ADR 0040 both deliberately reopen the song at 1×, and
0040 explicitly rejected session-level restore on the grounds that a sitting
should start fresh rather than resume a stale **loop**.

In practice the full-song tempo is exactly the kind of working state worth
keeping. If you're drilling a whole song at 0.85×, every reopen snapping back to
1× is the same papercut 0040 fixed for loops — you re-slow it by hand each time.
0040's rejection conflated two things: *which loop is armed on entry* (session
state, rightly wiped) and *what tempo the full song plays at* (practice memory,
worth keeping). This ADR keeps the first and adds the second.

This also unblocks the V1 **home hub**'s "Jump back in" card, whose value is
landing you back where you were. Two gaps surfaced building it:

1. `Song.lastPracticed` (the "recently practised" sort key, ADR 0036) was a
   field that **nothing ever wrote** — so the card and the library's
   recently-practised ordering were dead. It needs a write site.
2. There was no song-level resume tempo to land back at.

## Decision

### New field: `Song.lastPracticedSpeed: Double?`

The song-level analogue of `Loop.lastPracticedSpeed` (ADR 0040): the full-song
playback speed (× of original) you last practised at. `nil` = never practised;
`Song.resumeSpeed` falls back to 1×. Optional with no declaration default, so
pre-0044 songs migrate to `nil` without a store wipe (the CoreData 134110 rule;
optionals are exempt — same pattern as 0040).

### One invariant: "no loop armed ⇒ `speed` is the song's tempo"

`WaveformPracticeModel.speed` is a single value shared between full-song and
in-loop playback (arming a loop overwrites it with the loop's resume speed). To
keep a loop's speed from leaking into the song's memory, the model maintains one
invariant, enforced at the **same `activeLoopID` choke point** 0040 already uses:

- **Bank on arm** — when the first loop arms (`nil → loop`), persist the current
  `speed` into `song.lastPracticedSpeed`. At that moment `speed` is still the
  song's tempo (the loop's speed is applied *after* the assignment).
- **Restore on disarm** — when the last loop disarms (`loop → nil`), set
  `speed = song.resumeSpeed`. So returning to the full song returns to the
  song's own tempo, not the loop's leftover speed.

One choke point means every present and future arm/disarm path is covered by
construction, exactly as in 0040.

### Resume on entry, bank on exit

- **Entry** — the model inits `speed = song.resumeSpeed` (still the full song,
  no loop armed — 0029 preserved); `loadAudio` pushes it to the engine via
  `setRate`.
- **Exit** — `wipeTransientState` banks `song.lastPracticedSpeed = speed` when no
  loop is armed (a loop-armed exit already banked the song's speed at arm time,
  and the disarm restore in the same method handles the rest). It still resets
  the transient `speed` to 1× afterwards.

### Stamp `lastPracticed` on entry

`beginPlaybackSession` sets `song.lastPracticed = .now` — opening a song to
practise marks it most-recently-practised. Entry (not first play) is the right
trigger: "Jump back in" should surface the song you last *opened* to work on.

## Consequences

- A song you practise at 0.85× reopens at 0.85×; the working tempo survives across
  sittings, persisted on the `Song`, the way loop speed already does on the `Loop`.
- Deactivating a loop now returns the full song to **its own** tempo rather than
  leaving the loop's leftover speed in place — a small, more-correct UX shift.
- The home hub's resume card and the library's recently-practised ordering work,
  because `lastPracticed` is finally written.
- Loops are unaffected: they still open disarmed (0029) and carry their own
  last-practiced speed (0040). Only the full-song tempo is newly remembered.

## Alternatives considered

- **Reopen the song on its last armed loop too** — still rejected (0029/0040). The
  session opens clean with no loop armed; only the *full-song tempo* resumes, not
  the loop selection.
- **A second shared "song speed" variable** instead of the invariant — rejected:
  more state to keep in sync. Anchoring "no loop ⇒ `speed` is the song's tempo" to
  the existing choke point reuses the mechanism 0040 already proved.
- **Stamp `lastPracticed` on first play rather than entry** — deferred: entry is
  simpler and matches the "jump back into what you opened" intent; first-play
  precision isn't worth threading through the transport for V1.
- **Persist `lastPracticedSpeed` on every slider tick** — rejected for the same
  reason as 0040: the leave/arm event is the natural commit point, not each tick.
