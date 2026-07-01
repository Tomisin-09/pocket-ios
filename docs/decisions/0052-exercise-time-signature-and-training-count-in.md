# 0052 — Exercise time signature in the run, and count-in on training runs

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

Two user-testing "cheap freebies": exercises already carried `beatsPerBar`/`noteValue`
(ADR 0043, added when the metronome could save an exercise) but nothing let you *choose*
the meter when creating one in Practice, and the meter was never fed to the run engine —
so every drill ran the click in 4/4 regardless. Separately, the **count-in** built for the
free-play automator (ADR 0048, made configurable in Settings V1 / ADR 0050) never fired on
a Practice **training run**: `run(ramp:)` set the floor and started immediately, so the
climb began before you could settle in. Both are wiring existing mechanisms, not new ones.

## Decision

- **Choose the meter at creation.** `NewExerciseSheet` gains a `TimeSignature` `Picker`
  over the existing `TimeSignature.presets`, defaulting to 4/4. `onCreate` carries the
  chosen signature; `Exercise.commandAnchored` gains `beatsPerBar`/`noteValue` params (default
  4/4) so the single creation path (ADR 0046) stores it. The automator's "Save as exercise"
  seam seeds the picker from the metronome's **current** meter (`engine.timeSignature`), so a
  discovered drill inherits the feel you were playing in.
- **Change it on an existing exercise.** `ExerciseRunView` shows a compact meter `Menu` in the
  run-setup nav bar (visible only while stopped). It's held in local edit state and committed on
  **Start** alongside the tempos, so it matches the rest of the setup screen — tweak and leave
  without starting discards it; Start persists `beatsPerBar`/`noteValue`.
- **Feed the meter to the run.** `ExerciseRunView.commitAndStart` calls
  `engine.setTimeSignature(.forStored(…))` before `engine.run(ramp:)`, so the click's accents
  and the count-in length both honor the exercise's meter (a 3/4 drill counts in 3, accents
  the downbeat).
- **Count-in on training runs.** `run(ramp:)` now sets up the same count-in state as the
  free-play `startAutomatorRun` (`countInStartBeat`/`countInTarget`/`automatorCountingIn`),
  honoring the meter and the Settings length (1–2 bars). The tick's generic `advanceCountIn()`
  already holds the floor and engages the climb on the final downbeat — no new tick logic.
  `automatorCountdown` was regated from `automatorRunning` (free-play only) to
  `automatorCountingIn` alone, so it serves both paths; the run screen shows the countdown in
  place of the BPM while the beat dots keep flashing.

## Consequences

- Non-4/4 drills finally run in their meter; existing exercises read 4/4 (the default) and
  are unchanged. No migration — the meter fields already existed on `Exercise`.
- Count-in respects the Settings toggle/length uniformly: off ⇒ the climb drives immediately
  (unchanged feel for anyone who turned it off).
- **Loops** are audio playback, not a click, so count-in doesn't apply there — this covers
  exercise runs only. **Routines** are V2 (ADR 0046); they'll inherit the same `run(ramp:)`
  count-in when built.
- Wiring the meter into subdivision feel (compound-meter inner pulses) is still future work
  (ADR 0043 slice 5); this slice covers accents + count-in.
