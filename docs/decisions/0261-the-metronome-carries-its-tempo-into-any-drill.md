# ADR 0261 — The metronome carries its tempo into any drill

- **Status:** Accepted — Tomisin's call, 2026-10-19, confirmed on device the same day. Built on
  `pocket-373-metronome-carries-its-tempo`.
- **Date:** 2026-10-19
- **Amends:** ADR 0260 — D1's *"It opens the create sheet on a Basic drill"* is reversed: the
  template picker runs. The rest of D1 stands: the toolbar bookmark, the tempo and meter pinned at
  the tap, the drill command-only, the plan wall, the fixed label.
- **Amends:** ADR 0170 — D6 set the song player's route apart from the metronome's on the grounds
  that *"a metronome breakdown is always a plain tempo drill"*. That no longer holds, and the two
  routes now both run the picker. The song link (D6) and everything else in 0170 stand.
- **Amends:** ADR 0068 — the Consequences' note that the metronome's save passes
  `fixedTemplate: .basic` is out of date. Template-first creation (T3) stands.
- **Amends:** ADR 0116 — the note that the save skips the picker and takes the profile default
  directly. It now gets the picker's Guitar/Bass control, seeded from the profile.
- **Amends:** ADR 0128 — *"The automator's sheet still has no instrument control"* no longer
  holds. The one insert path stands, and its rhythm bind now meets real payloads.

## Context

Two places carry a tempo into a new drill. Holding the song player's BPM callout (0170) opens
*Carry this tempo*, and its *Into a new exercise* runs the template picker. The tempo can become a
chord change, a strumming pattern, a scale or a freeform block. The metronome's **Save as exercise**
(0260 D1) skipped the picker and always made a Basic drill.

The reason for Basic is in 0170 D6: *"a metronome breakdown is always a plain tempo drill."* That was
true when the save lived in the automator's header and only showed during a ramp. What it saved
then was the tempo your hands broke down at, on a bare click. 0260 moved the save to the toolbar
and kept it visible all the time, because a tempo worth keeping is found with the slider or by
tapping as often as by a ramp. A tempo found while running a scale or changing chords against the
click is a tempo for that drill, not for a plain click drill.

Tomisin noticed the two routes behaved differently on 2026-10-19.

## Decisions

### D1 — Save as exercise runs the template picker

The create sheet opens on its first step: Guitar or bass, then the template. The tempo and meter
the bookmark pinned are already filled in on the configure step. That's the song player's
*Into a new exercise*, without the song link, because the metronome has no song to link.

`MetronomeView` stops passing `fixedTemplate: .basic` to `NewExerciseSheet`. The sheet itself,
`NewExercisePlan` and `finalise(in:)` don't change. `fixedTemplate` stays, for the library's
category **+** and a goal skill's fix.

### D2 — The drill stays command-only

Nothing in 0260 D1's command-only rule changes. `commandOnly` is three flags set in `finalise(in:)`
before the payload goes on, so it applies to whatever template is picked. A test now covers it
under an authored payload.

The two routes **differ here on purpose**. A drill from the metronome plays its tempo and nothing
else, while one from the song player keeps warm-up, reach and back off. Tomisin's call after the
device pass, 2026-10-19: the metronome's drill stays command-only. 0260 D1's reason still holds:
what you find at the metronome is one tempo, and a ramp around it is for the player to add in the
run's Practice Settings, not for saving to decide.

## Consequences

- A tempo can seed any kind of drill from both routes.
- Saving a Basic drill from the metronome takes one more tap than before: *Basic* on the picker.
- The save gains the picker's **Guitar or bass** control, seeded from the profile. It had none,
  because Basic skipped the step that hosts it.
- The rhythm bind the shared insert added for this seam (0128) now has payloads to bind to. It
  was written for exactly this, and the new test runs it with command-only set.
- The manual's metronome page and the tools reference say the picker runs. The create sheet's
  figures in *Exercises* already show the picker. No metronome figure showed the save sheet, so
  none goes stale here.

## Alternatives considered

- **Keep Basic and add a "Change type" link on the configure step.** No: creation is template-first
  and the configure step is built from the template (0068 T3), so the link would just be the picker
  behind an extra tap.
- **Open the song player's *Carry this tempo* chooser from the metronome.** No: from the metronome
  its only other destination is the metronome you are already on.
- **Drop command-only, so the two routes make the same drill.** Not taken: Tomisin's call (D2).
