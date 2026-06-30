# 0048 — Automator: explicit run, count-in, and infinite mode

- **Status:** Accepted
- **Date:** 2026-06-30

## Context

The standalone metronome's tempo automator (ADR 0043) conflated **configuring** a
ramp with **running** it. Selecting a unit on the segmented control (Off / By Bars /
By Time) armed the automator *and*, if the metronome was already playing, started the
climb immediately — `isRampActive` was `trainingRamp != nil || automatorEnabled`, and
`tick()` drove the tempo whenever it was true. User testing surfaced the gap: "you
start the metronome, then go to the automator tab — there's no explicit start button
for the automator; it just climbs." Two further wants came out of the same review:

- A **count-in** before a ramp (and exercises/routines) starts, so you can settle in.
- An **infinite mode** — climb with no chosen target, capped only by a system limit —
  for "just keep speeding me up until I break."
- A cosmetic note: the full-width "Save NNN BPM as exercise" capsule should become a
  compact **bookmark icon**.

## Decision

Split *armed* from *running*, and give the automator its own transport.

- **`automatorEnabled` = armed/configured** (unchanged): the panel is expanded, the
  floor is captured, the staircase previews — but nothing climbs.
- **`automatorRunning` = the climb is live** (new): the only thing `isRampActive` keys
  the free-play ramp on now (`trainingRamp != nil || automatorRunning`). Arming alone no
  longer climbs — the reported bug.
- **Start / Stop** (`startAutomatorRun` / `stopAutomatorRun`): Start plays the metronome
  if stopped, captures the floor, and begins; Stop halts the climb but leaves the
  metronome playing at the tempo reached and the ramp still armed (Start replays from the
  floor). This also retires the old `restartAutomator` — Start *is* the restart.
- **Count-in** (`advanceCountIn` / `automatorCountdown`): Start counts in one bar of the
  current meter, beat-synced to the heard click (counted off `currentBeat`), holding the
  floor until the count-in's final downbeat, where the climb engages. The panel shows the
  count down (4·3·2·1). Purely a free-play-automator concern for now; Practice training
  runs (`run(ramp:)`) are unchanged.
- **Finish holds at the ceiling** (`finishRamp`): a finished *free-play* ramp now stops
  *running* and holds at the ceiling (the click keeps going) instead of stopping the whole
  session. A *training run* still ends the session (ADR 0046) — the two finish paths fork
  on `trainingRamp`.
- **Infinite mode** (`automatorNoLimit` / `setAutomatorNoLimit`): **derived**, not stored
  — "no limit" *is* `ceiling == bpmRange.upperBound`. The toggle sets the ceiling to the
  system max (300) or, off, back to floor + default headroom. The existing finite ramp and
  its auto-stop handle the climb to the cap with no special-casing; the panel hides the
  "Up to" field and shows a "climbing to 300 BPM max" readout.
- **Save-as-exercise** is now a circular bookmark icon in the panel header; the action
  (capture live tempo → Practice's `NewExerciseSheet`) is unchanged.

## Consequences

- Arming is safe again — switching to the automator tab mid-play no longer hijacks the
  tempo. The climb is a deliberate gesture.
- `automatorRunning` is plain `var` (internal), like the rest of the automator config the
  `+Automator` split writes; transport `stop()` and disarming both clear it so the panel's
  Start/Stop can't show a stale state.
- Infinite mode adds **zero** persistent state (derived from the ceiling), so there's
  nothing to migrate or keep in sync.
- The count-in is beat-synced but counts a fixed bar; it does not yet extend to Practice
  exercise/routine starts (the note asked for those too) — that rides on the Practice run
  surface and is left for a later slice. Per-exercise **time-signature** configuration —
  raised in the same review — is likewise tracked for the Practice pass, not here.
