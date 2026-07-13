# 0089 — Loop arming is command-anchored (fixes the loop-switch tempo bleed)

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Supersedes (for arming):** ADR 0040 — which restored a loop's *last-practised* speed on arm.
- **Relates to:** ADR 0044 (the song-level resume-tempo invariant, unchanged); ADR 0036/0046 (`commandTempo`).

## Context

Switching between loops on the waveform could carry the previous loop's tempo into a loop that has **no
command tempo**. Reported: the song sat at 50%; arming a loop whose command tempo was 50% played at 50%
(correct); then switching to a loop with *no* command tempo — saved at 100% — **also** played at 50%,
inheriting the prior loop's rate.

Root cause: both arming paths — `activate(_:)` (tap a loop row) and `jump(to:)` (the ◀◀/▶▶ transport
skip) — set `speed = loop.resumeSpeed`, i.e. `lastPracticedSpeed ?? speed` (ADR 0040). A loop that was
never practised falls back to its stored `speed`, which `createLoop` captured from the *session tempo at
creation* — so a loop born (or last left) during a 50% session re-arms at 50%, regardless of its command
tempo. `commandTempo` and the working `speed` were fully decoupled at the arming choke points.

## Decision

- **A1 — Arm at the loop's command tempo, else 100%.** A new pure accessor `Loop.armingSpeed`
  (`commandTempo ?? 1.0`) is the working speed a loop arms at. `activate(_:)` and `jump(to:)` both set
  `speed = loop.armingSpeed`. Switching to a loop with no command tempo now resets to full tempo instead
  of inheriting the previous loop's rate; a loop *with* a command tempo arms at that tempo (the tempo you
  own it at is the sensible working tempo). Pure and unit-tested (`SongTests`). The arming sites also push
  the new rate to the engine **synchronously** (`engine.setRate(speed)`) rather than relying on the async
  `onChange(of: speed)`, so the switched-to loop starts rendering at its own tempo instead of briefly
  lurching from the old rate (the "buggy audio on switch" symptom).
- **A2 — Retire ADR 0040's last-practised *resume* for arming, keep the leave *record*.**
  `lastPracticedSpeed` is still written on leave (the `activeLoopID` `didSet`) and `Loop.resumeSpeed`
  still computes it, but nothing arms from it anymore — retained as the record of where a loop was left
  (and for the undo/delete restore), a fuller retirement left out of scope.
- **A3 — The song-level invariant (ADR 0044) is untouched.** The `didSet` still banks the song's tempo
  when the first loop arms and restores it when the last disarms; the loop→loop transition stays
  `.none`. Only the per-loop working speed the arming sites *choose* changed.

## Consequences

- Creation is deliberately unchanged: a brand-new A/B-span loop still plays at the current session
  speed at the moment of creation (it isn't an "arm a saved loop" event). Only re-arming an existing
  loop is command-anchored.
- Verify on device: switch between loops with mixed command-tempo states and confirm a no-command loop
  arms at 100% and a command loop arms at its command tempo.
