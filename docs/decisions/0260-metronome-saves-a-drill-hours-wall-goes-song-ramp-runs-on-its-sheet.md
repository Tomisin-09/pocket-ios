# ADR 0260 — The metronome saves a drill, the hours wall goes, and a song ramp runs on its own sheet

- **Status:** Accepted — from Tomisin's device pass, 2026-10-18. Built on
  `pocket-372-metronome-saves-a-drill`.
- **Date:** 2026-10-18
- **Amended by:** ADR 0261 (the metronome carries its tempo into any drill, 2026-10-19) — D1's
  *"opens the create sheet on a Basic drill"* is reversed: the template picker runs, as it does
  for the song player's tempo-carry. The rest of D1 (the bookmark, the tempo pinned at the tap,
  command-only, the plan wall, the fixed label) and D2–D4 stand.
- **Amends:** ADR 0160 — the metronome's journal pencil is gone, so nothing writes a metronome note
  any more. The owner kind, the snapshot and how a stored note renders and filters all stand (D4).
- **Amends:** ADR 0155 — §8's door on the metronome is closed. The metronome is no longer a way into
  the journal. §1–§7 stand.
- **Amends:** ADR 0046 — §4's seam moves from the automator's header to the metronome's toolbar,
  where it is always visible, and the drill it saves is command-only (D1). The seam is still
  one-directional, and still goes through the one insert path.
- **Amends:** ADR 0117 — the hours milestones (10/50/100/500) leave All-time (D2). The lifetime figure
  and the inventory counts stay.
- **Amends:** ADR 0013 — *Set ramp* no longer dismisses the sheet, leaving the sheet disarms the
  ramp, a finished ramp disarms itself, and *Turn off ramp* is replaced by *Stop ramp* (D3). The
  stepping maths, the finite ramp and the per-loop config stand.
- **Builds on:** run shapes (0221: a run can be command-only) · one plan (0256 D3: deeper doors open
  onto the wall with no lock drawn)

## Context

Three things came out of a device pass on 2026-10-18.

1. **The metronome's toolbar pencil wrote a journal note.** Keeping a tempo you'd found was a
   bookmark in the automator's header, and it only showed while the automator was armed. A tempo
   worth keeping is found with the slider or by tapping just as often as with a ramp.
2. **The Practice log's All-time section had an hours wall** under the lifetime figure: four tiles,
   10, 50, 100 and 500 hours, each reached or not yet. It restated the number directly above it.
3. **Set ramp on the song player's automator closed the sheet.** The ramp then ran with nothing on
   screen saying where it was. An exercise run lights its current plateau, and a loop ramp had no
   equivalent.

## Decisions

### D1 — The metronome's toolbar saves a drill

The top-right control on the metronome is **Save as exercise**, a bookmark tinted in the
metronome's colour, in the slot the journal pencil had. It is there whether or not the automator is
armed. The automator panel's header is just *AUTOMATOR* now.

- **The tempo is pinned at the tap**, with the meter, for the reason the metronome note's snapshot
  was (0160 §5): during a ramp the live tempo *is* the discovery, and the click keeps running under
  the sheet.
- **It opens the create sheet on a Basic drill**, with the tempo and meter filled in and the
  instrument from the profile, as the automator's bookmark did. *(Amended by 0261: the template picker runs.)*
- **The drill is command-only.** No warm-up, reach or back-off, so it plays the tempo you found and
  nothing else. The phases can be switched on in the run's Practice Settings. `NewExercisePlan`
  carries `commandOnly`, and `finalise(in:)` (still the one insert path) turns the three phases off
  when it's set. Every other way of making a drill keeps all three on.
- **It is behind the plan with no lock drawn.** `NewExerciseSheet` already wraps itself in the wall
  (0256 D3), so the button needs no badge.
- **Its label is fixed.** "Save as exercise" is the accessibility label and the tempo is its value,
  so VoiceOver's rotor and the UI tests have one name to find.

### D2 — The hours wall goes

All-time is the lifetime figure (time played, sessions, and since when), then the inventory counts.
`PracticeProgress.hourMilestones`, `HoursMilestone`, `AllTime.milestones`, `nextMilestone` and
`milestones(forHours:)` are deleted. Nothing else read them.

The register the wall stood for (something you pass, not a ladder you're timed on) still governs
the goal echo. Its docs now state it directly instead of pointing at the constant.

### D3 — A song ramp runs on its sheet, and leaving the sheet ends it

| State | When | Hero | Fields | Bottom bar |
|---|---|---|---|---|
| **Idle** | nothing started here | the staircase, start → target | editable | **Set ramp** |
| **Running** | started here, armed, playing | the current plateau lit, the live % (and BPM when the song has one), *Step k/N · loop j of L* | locked | **Stop ramp** |
| **Paused** | started here, armed, not playing (a call, headphones out) | as Running, plus *· paused* | locked | **Resume**, **Stop ramp** |
| **Finished** | started here, the ramp played out | the last plateau lit, *Done · target %* | editable; an edit returns to Idle | **Run again** |

- **The sheet keeps no progress state.** The plateau and pass come from `AutomatorConfig.progress(
  atLoopIteration:)`, read off the engine's `loopIteration`, the same count `speed(atLoopIteration:)`
  reads. So the plateau lit and the speed shown can't disagree. `PracticeAudioEngine` is
  `@Observable`, and the ramp already advanced while a sheet covered the player.
- **One bar per plateau** (`steps + 1`), idle and running alike, which is the metronome tracker's
  convention. The hero used to draw `steps` bars for `steps + 1` plateaus. `RampStairs`'s fallback
  for more than 12 plateaus also now maps the last plateau to the last bar: it divided by the
  plateau count rather than the gaps between plateaus, so 13 plateaus lit bar 11 of 12 at the target.
- **A finished ramp disarms itself.** `automatorAdvance` now turns the ramp off when it pauses and
  rewinds at `totalLoops`. The sheet reads "started here, no longer armed" as Finished. It also
  means the next press of play is the player's, not a restart of a ramp that had already finished.
- **Stop ramp disarms and pauses**, which is what the ramp's own finish already does. The speed stays
  where the ramp had got to. Tomisin's call, 2026-10-18.
- **Leaving the sheet always disarms**, whether by Cancel, Close or a swipe. It pauses only if this
  sheet started the run, so opening the sheet while the song plays leaves playback alone. The
  toolbar reads **Cancel** until a run starts, then **Close**.

### D4 — What stays, with no door

The `.metronome` owner kind, `MetronomeJournalContext`, `engine.journalContext`, `JournalWriter`'s
metronome path, the stored owner kind and its columns, and the journal's **Metronome** filter all
stay. Notes already written at the metronome still render, caption and filter as before.
`QuickJournalButton` loses the closure initialiser only the metronome used, and the run screens keep
theirs.

Whether metronome journalling comes back somewhere else is **not decided here**.

## Consequences

- One door to keep a tempo, visible on the metronome all the time, and no door from the metronome
  into the journal. A player who wants to write about a sitting at the click writes from the
  Journal's ＋, which makes a standalone note (0155), not a metronome note.
- A drill saved from the metronome starts as one plateau. Players who want the full ramp turn the
  phases back on in that drill's Practice Settings. The manual says so.
- With the sheet ending every ramp it starts, a loop row's lit **A** (`automatorEnabled`) is now seen
  only for a loop still armed from before this change, or one restored from an archive that had it
  armed. Opening and leaving that loop's sheet clears it. Whether the lit state still earns its place
  is not decided here.
- The manual's metronome, automator and Practice-log figures are stale and are listed for the next
  reshoot, not shot on this branch.

## Alternatives considered

- **Keep the pencil and add the bookmark beside it.** No: two trailing controls pushed the title off
  centre once already (the meter chip moved under the dots for that reason).
- **Stop ramp leaves the song playing at the reached speed.** Tomisin chose pause, to match the
  ramp's own finish.
