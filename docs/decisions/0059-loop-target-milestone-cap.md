# 0059 — A loop's auto-target is a milestone capped at song tempo, then overspeed

- **Status:** Accepted
- **Date:** 2026-07-02

## Context

A measured loop trains a command-anchored ramp toward an **auto-derived reach** (ADR 0046):
`TempoStretch.targetSpeed` returns `command + a proportional stretch` (≈+6%, clamped +0.02…+0.10×).
Loop tempos are a **fraction of original**, so **100% = the song's real tempo**.

The old derivation had no notion of that ceiling: at command 96% the reach was 102%, at 100% it was
106% — i.e. it routinely pointed *past the record* before the player had even reached full tempo.
That contradicts how a learner reads the number: full tempo is the goal you climb toward, and the
auto-target should feel like the **next milestone on the way there**, not "now play faster than the
song" while you're still at 96%.

## Decision

`targetSpeed` treats **100% (song tempo) as the ultimate target**, in two regimes:

- **Below full tempo (`command < 100%`):** the proportional reach is **capped at 100%**. It climbs
  toward the song's real tempo as a milestone and never overshoots it before it's owned. As command
  rises, the reach marches up to 100% (`96% → 100%`, `90% → 95%`, `80% → 85%`).
- **At/above full tempo (`command ≥ 100%`):** the ceiling **lifts** — overspeed unlocks and the
  reach climbs past 100% by the usual proportional stretch (`100% → 106%`, `120% → 127%`). Owning
  the song at full tempo is the trigger, matching "the auto-target goes above 100% once command is
  100%".

The cap lives **only in `targetSpeed`** (the loop convenience), not the unit-generic
`target(forCommand:…)`: it's a loop concept. Exercises are absolute BPM with no song ceiling and are
untouched. One derivation feeds both the run-screen reach and the loop-row `→` badge
(`Loop.derivedTargetSpeed`), so both change together.

## Alternatives considered

- **100% as a hard finish line (no overspeed).** Reach caps at 100% always; at command 100% the
  target is 100% (done). Rejected — many players do overspeed drills once they own full tempo, and
  the engine already supports up to 200×; a hard stop would remove a legitimate training tool.
- **Leave as-is (always +6%).** Rejected — the reach overshooting the song before it's owned is the
  exact confusion this fixes.
- **Discontinuity at the boundary.** Just under 100% the reach is 100%; at 100% it jumps to 106%.
  Accepted as intentional — crossing full tempo is a real milestone ("barrier broken"), and the
  jump reads as the overspeed unlock rather than a glitch.

## Consequences

- A loop's auto-target now reads as a milestone toward the song's real tempo, then opens into
  overspeed once full tempo is owned. Sub-100% commands that used to show >100% now cap at 100%.
- Loops already at command 100% are unchanged (still `→ 106%`), so existing measured-at-full loops
  look the same.
- No stored data changes — the reach is derived, not persisted.
- **Manual target override** (letting a player set their own target instead of the derived one) is a
  natural follow-up but explicitly **not** in scope here — parked in `docs/backlog.md`.
