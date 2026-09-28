# ADR 0228 — A Journal caption opens the mode the note was written in

- **Status:** Accepted. Built on `pocket-338-name-the-notes-on-the-neck`.
- **Date:** 2026-09-28
- **Amends:** ADR 0142 — **J5a**: a loop caption on a note written in one mode opens that mode when the
  loop still qualifies for it. J5a's precedence (trainer, then ear, then improvise) stays, as the
  fallback and for every other note, every take and every session pill.
- **Relates to:** 0138 (each loop mode gates on what it needs) · 0104 and 0135 (the notes ear training
  and improvise write) · 0225 (the *Transcribed* kind, saved from Count the notes).

## Context

Found on the device: tapping the loop caption on a 🧩 *Transcribed* entry opened the loop trainer, the
ramp, rather than *Train your ear*, where the piece was counted and named. J5a opens the first mode a
loop qualifies for, trainer first, so a measured loop always opens the ramp, whichever mode the note
came from. That was the right rule for a caption that only knew its loop. A note also knows its kind,
and three kinds are only ever written in one mode.

## Decision

- **D1 — A note written in one mode opens that mode.** 👂 *Ear* and 🧩 *Transcribed* open *Train your
  ear*; 🎸 *Improv* opens *Improvise*. `JournalOwnerRoute.writtenIn(_:)` holds the mapping, exhaustive
  with no `default`, as `LoopModeAccess.allows` is, so a new kind has to say where its caption goes
  before it compiles.
- **D2 — Only while the loop still qualifies.** A mode the loop has lost (the backing-track flag taken
  off, the song's audio gone) falls back to J5a's precedence, never to a screen that can't run.
- **D3 — Everything else keeps J5a.** Every other note kind, takes (a take doesn't record the mode it was
  made in) and session pills (a unit ref carries no mode).

## Alternatives rejected

- **Storing the mode on every note and take.** For notes, the kind already says it for the three kinds
  that matter. For takes it is a schema change for a small gain; if takes need it later, that is its
  own decision.
- **Opening ear training from every loop caption.** A struggle or a breakthrough on a measured loop is
  usually about the ramp, which is where J5a sends it.

## Consequences

- Pure and unit-tested (`JournalOwnerRouteTests`), including the fallback when the loop has lost the
  mode.
- **A shipped behaviour changes:** ear and improvise notes (0104, 0135) on a measured loop used to open
  the ramp, and now open the mode they came from. `CHANGELOG.md` says so under *Changed*.
