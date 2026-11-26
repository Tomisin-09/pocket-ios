# ADR 0324 — The play-along counts the time it played

- **Status:** Accepted. Built on `pocket-486-play-along-counts-its-time` (2026-11-26), on top of
  ADR 0323's branch, whose engine pause this relies on. Tomisin asked for it the same day, after
  ADR 0321 named the play-along as one of two timers it left open. The device pass is owed.
- **Date:** 2026-11-26
- **Amends:** ADR 0266 — **D3** logged a looping play-along *"from the moment Play along was
  tapped"* to Done. It now logs the time the song sounded (D1). D3's single completion path, Done and
  the song playing through, stands.
- **Relates to:** 0321 (the loop modes count the time the loop sounded; its Consequences named this
  timer) · 0322 (the song player, the same rule on the same engine) · 0323 (a call pauses the
  transport, which is what stops this count at one) · 0117 (a looping play-along's length) · 0141 (a
  block's planned length, which a song block still ignores)
- **Schema:** none. The rows are the same shape; their length now means time sounded.

## Context

ADR 0321 fixed the 755-minute night on Active listening and Improvise, and its Consequences named two
timers with the same hole: a freeform block, timed from arrival to Done, and a looping play-along, timed
from **Play along** to Done. A routine paused on its song block and left in the background logs the
time away when Done is tapped, and so does a long pause on screen. Neither shows in the phone's 471 rows
yet. The play-along has audio to count, so it has the same answer as the loop modes. The freeform block
has none, and is left for its own decision (*What stays out*).

## Decisions

### D1 — The length is the time the song sounded

A play-along's run starts when the song first sounded and lasts for as long as it sounded: playing on
screen, or with the phone locked. Not counted: paused, on screen or from the lock screen; after a call
or another app's audio (ADR 0323 pauses it); and the gap while a looping song goes back to the top,
which is a fraction of a second.

### D2 — The model counts, the screen writes

`SongPlayAlongModel` keeps the count (`SoundedTime`), fed by its own engine's `onPlayingChange`, for
ADR 0321 D2's reason: a pause from the lock screen reaches the engine in the background, where a view's
`onChange` may not run until the app comes back. `SongPlayAlongView` writes the row on Done or at the
song's end, as before. Skip and exit still log nothing (0266 D4).

## What stays out

- **A freeform block's length.** It has no audio, so there is no sounded time to count. Time with the
  app in front was weighed and not chosen: with the screen held awake (ADR 0050, the default) a phone
  left on the stand still counts, and with it off, the screen locking mid-sight-read would cut the count
  while the player is still playing. Parked in the backlog with the options.
- **A ramp run's length.** A loop trainer or exercise ramp still logs Start to its natural end, a pause
  included.
- **Backfill.** Nothing recorded what sounded, so past rows stay as they are.

## Build notes

- `PlayAlongSoundedTimeTests` drives the real model on the demo sample: a pause left out, the run handed
  back once, and a call pausing it and stopping the count. Bounds are taken against the wall clock, since
  a sleep can overrun but never under-run. Mutants: a count that ignores the transport failed both; the
  model ignoring the call failed the second.
