# ADR 0266 — A song block you can finish

- **Status:** Accepted. Built on `pocket-382-take-opens-its-mode`.
- **Date:** 2026-10-21
- **Amends:** ADR 0071 — **§3**, *"Loops by default; advances only on Skip"*. A looping song block now
  has a **Done** (or **Finish** on the last block) that logs the play-along and moves on. Skip still
  moves on without logging. The rest of §3 stands: one fixed speed, no ramp, *Loop song blocks*
  default on, and play-through-once-and-advance when it is off.
- **Amends:** ADR 0117 — the paragraph keeping a **looping** play-along unlogged as open-ended. Done is
  its end, so it now writes a `.song` row. The paragraph's reason, that "however long the screen was
  open" is not an honest length, is kept: the length runs from **Play along** to **Done**, not from
  arrival.
- **Relates to:** 0135 B3b (the improvise block's Done, whose reasoning this copies) · 0104 (the ear
  block's Done) · 0070 (no grading: Done is the player saying they're finished, not a verdict).

## Context

Found on the device: a song block in a routine has no way to finish. With *Loop song blocks* on, which
is the default, the song repeats until the player leaves it, and the only way on is **›**, Skip. Skip
logs nothing, by design, for every block. So a play-along that went on for twenty minutes counted for
no minutes, no day on the calendar and no row in the Practice log, while an improvise block over a
loop of the same song, run for the same time, counted.

0071 §3 made Skip the way out of a looping song when no block logged its runs. 0117 then gave the ear
block (0104) and later the improvise block (0135 B3b) a **Done** that counts, on the argument that a
block with no natural end ends when the player says it does. The looping song block is the same kind
of block and was left out.

## Decision

- **D1 — A Done in the toolbar, as the improvise and ear blocks have.** The label is **Done**, or
  **Finish** on the last block. It is a nav-bar button, not a bottom pill, because the transport owns
  the bottom and a big call to action reads like something has gone wrong.
- **D2 — Only once the play-along has started.** Before **Play along** there is nothing to finish, and a
  Done that only moved on would be a second Skip.
- **D3 — One completion path.** Done and the song playing through (with looping off) both go through
  `finish()`: log a `.song` run from the moment **Play along** was tapped, then advance. The run
  carries no tempo, as 0117 set for play-alongs.
- **D4 — Skip is unchanged.** Skip and exit still log nothing. Done means "I played this", Skip means
  "not this one today".
- **D5 — The copy says it.** The stopped screen reads *"Plays as a loop — tap Done when you've
  finished"*. The *Loop song blocks* info reads *"A song block loops as an open jam until you tap
  Done."*

## Alternatives rejected

- **Making Skip log a looping song.** Skip means the same on every block. A Skip that sometimes counts
  is a rule the player has to remember per block type.
- **Turning *Loop song blocks* off by default.** That gives every song a natural end, but it changes
  what an open jam is for. 0071 chose looping deliberately.
- **Honouring a planned block length (0141) on song blocks.** A generated session can allot minutes to
  a song block, and the song screen ignores them today, as it did before this. Not decided here.

## Consequences

- A looping play-along that ends with Done appears in the Practice log, on the Progress screen and on
  the calendar. It shows no completion screen, because a song has no journal or mastery to rate (the
  routine player advances past it as before).
- `SettingsInfo.routineSongLoop` changed, and `docs/manual/reference/settings.md` quotes it, so the two
  changed together. `docs/manual/routines.md` says what a song block does.
