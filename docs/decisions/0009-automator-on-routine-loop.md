# 0009 — Automator settings live on the routine↔loop, not the Loop

- **Status:** Accepted (direction recorded; build deferred to the planner/persistence layer)
- **Date:** 2026-06-16

## Context

A **loop** is a reusable thing — a region of a song (start/end) with a name. *How
you drill it* — slow it down, ramp the tempo, repeat N times — is a property of the
**practice you're doing**, not of the loop. The same loop is "slow 4×, then up to
tempo" in a warm-up routine and "full tempo ×8" in a run-through.

Today everything is mock: `WaveformMock.Loop` carries `speed` and `repeats`, and the
loops panel row shows them. That bakes "how to practice" into the reusable entity,
which can't vary per routine. The real Loop/Routine/Session models aren't built yet
(only `SongRef` exists; the practice screen runs entirely on `WaveformMock`), so this
ADR records the **model direction** now — before persistence lands — so we don't
model automator onto `Loop`.

## Decision

- **`Loop` is a library entity:** song reference, region (`start`/`end`), name, and a
  **practice log** (see below). Reusable; no tempo/automator state.
- **Automator config lives on the routine↔loop association** — the record that
  represents "this loop, as used in this routine" (a `RoutineItem` / `PracticeStep`).
  It holds the speed ramp / repeat plan (`TempoMath.automatorStepCount` is the math
  groundwork). One loop → many routine items, each with its own automator.
- **Entry point: an "A" icon in the transport** opens an automator setup popup. It
  operates on the *current routine's* use of the active loop — so it only does
  something meaningful inside a routine; in the standalone waveform screen a loop is
  just region + name + log.
- **The loops-panel row drops speed/repeats** (they're routine-scoped now) and gains
  a **timestamped practice log** affordance — append-only dated entries you add as you
  practice the loop ("16 Jun — clean at 0.8×"). This is closer to session logging than
  static notes.
- **Build is deferred.** The "A" popup, the routine↔loop model, and the loop-row log
  UI land with the planner/persistence layer (Phase 3). The transport space freed by
  slimming the bar is reserved for the "A" entry.

## Consequences

- The standalone practice screen shows loops as region + name (and, later, a log) —
  no automator there, because there's no routine to scope it to.
- `WaveformMock.Loop.speed`/`repeats` are **transitional** — when persistence lands,
  automator state moves to the association, not the `Loop`.
- `TempoMath.automatorStepCount` feeds the routine-scoped automator.
- Practice history naturally attaches to the loop's log and/or `Session` records.

## Alternatives considered

- **Automator baked into `Loop`** (today's mock shape) — rejected: couples
  how-you-practice into the reusable entity; the same loop can't be drilled
  differently across routines.
- **Automator per song, or global** — rejected: too coarse; the unit of practice is a
  loop within a routine, not a whole song.
- **Static per-loop notes instead of a log** — considered for the loops row, but a
  **dated, append-only log** better matches tracking progress over time; recorded here
  so the eventual build uses a log, not a single note field.
