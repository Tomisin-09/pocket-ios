# ADR 0221 — a run shaped phase by phase

- **Status:** Accepted. Step 1 (exercises, and the pencil on both run screens) built on
  `pocket-330-phase-rows-exercises`; step 2 (loops) on `pocket-331-phase-rows-loops`. See *As built*.
- **Date:** 2026-09-25 (`pocket-329-phase-rows`)
- **Amends:** ADR 0045 — the four-phase profile stands, but only **command** is mandatory: the
  warm-up and the summit become optional, as the back-off already is (D2), and every phase gets a
  hold of its own where 0045 held all but command for one interval (D3). The warm-up is stored as a
  **rung count** and spaced like the reach and back-off, no longer as the `stepBPM` stride the
  `warmupStepBPM` / `intermediateSteps` pair converted to and from (D4). The three tempos, the
  stretch and promotion stand.
- **Amends:** ADR 0078 — the dwell leaves the Steps panel and becomes Command's **Hold**, shown in
  bars or passes instead of as a raw interval count (D1, D3). Its 1…12 range and its storage stand;
  the range is now shared by every phase's hold.
- **Amends:** ADR 0079 — a run played with Reach off offers no raise on the completion screen,
  because there was no reach to play (D6). The rest stands.
- **Amends:** ADR 0134 — the settle half of the offer is unaffected; the raise half is absent when
  the run had no reach (D6).
- **Amends:** ADR 0142 — J1's toolbar pencil is hidden on a **stopped, standalone** run screen,
  where the review bar's Journal already opens a journal that writes (D7). Capture stays reachable
  in every state. J2's two verbs and J3–J5 stand.
- **Relates to:** ADR 0046 (the recipe stored natively, whose warm-up field this changes), ADR 0057
  (edits are local until Start or Save), ADR 0070 (the app never grades), ADR 0075 (a pin is an
  override, not a copy), ADR 0129 (a ramp fits its block by moving the command hold only), ADR 0131
  (the tempo-change warning), ADR 0189 (additive fields carry no destructive-change obligations),
  ADR 0205 / ADR 0209 (the backup and hand-over formats).
- **Schema:** additive only. `Exercise` gains six fields and `Loop` five (see *Model*). Every
  default reproduces today's ramp.

---

## Context

The run screen's **Practice Settings** grew one control at a time, each put where there was room:
three tempos (0045), warm-up steps, then reach and back-off steps (0046's run UI), the dwell (0078),
then back off's switch and floor (user-testing note 6). So the panel is grouped by **kind of
setting**: a list of tempos, then a nested Steps panel. The staircase underneath is grouped by
**phase**, and so is the way a player thinks about a run. Every phase ends up split across two
disclosures.

A device pass on 2026-09-25 (an exercise at 51 → 61, reach 65) named four problems. The code
confirms each one:

1. **Command appears twice, meaning two things.** "Command 61" sits in the tempo list and
   "Command 2" in Steps. The second is the dwell in 4-bar intervals, so "2" means 8 bars.
2. **Only command's length can change.** Every other plateau holds exactly one interval: 4 bars on
   an exercise, `repsPerStep` passes on a loop.
3. **A run can't be shorter than two phases.** Back off has a switch but reach doesn't (a reach is
   clamped above command), so there is no way to run command alone, or a warm-up and then command.
4. **The counts don't match what plays.** "Warm-up steps 0 · straight to command" sits above a
   staircase that draws a warm-up rung at 51, because the count is of stops *between* the floor and
   command. Worse, an exercise stores the warm-up as a stride (`rampStepBPM`) and builds it by
   stepping that stride, and the rounding adds and drops rungs. At 51 → 61, a setting of 2 plays
   four warm-up rungs, and a setting of 6 plays ten (checked against the app's own formula). A loop
   stores a count but converts it to the same stride, so it has the same bug. Reach and back-off
   are spaced by count and don't.

There is also a spelling split: the switch says **Back off**, the tempo row **Back-off**, and the
steps row **Back-up steps**.

The same screenshot shows the journal twice on a stopped run: the toolbar pencil (0142 J1) and the
Journal pill in the review bar under the staircase. The pill opens the full journal, which writes
notes too.

Two layouts were mocked as an interactive page against one live staircase: phase **rows** and phase
**tabs**. The author chose rows.

## Decision

### D1 — Practice Settings is four rows, in the order the run plays

Inside the existing Practice Settings disclosure, which stays collapsed by default, the panel is
four rows: **Warm-up, Command, Reach, Back off**. Each row has a title, a one-line summary of what
that phase will play, and, for the three optional phases, a switch on the row itself. Tapping a row
opens its controls under it, and **only one row is open at a time**. The nested **Steps**
disclosure (`RoutineStepsControls`) goes, and its rows move into the phases they belong to.

While a row is open, **the staircase lights that phase**: its bars at full weight, the rest dimmed,
its caption in the tint. This is what ties a control to the bars it changes. With no row open the
staircase reads as it does today.

### D2 — Command is the only mandatory phase

Warm-up and Reach get a switch, as Back off already has. With all three off, the run is
**command only**: one plateau, held for Command's Hold.

A switch removes a phase from the run but **does not clear its tempo**. The working floor, a pinned
reach and a pinned back-off floor all survive being switched off, and come back when the phase is
switched on. This is 0075's "an override, not a copy", extended to a phase that is off.

Every switch defaults on, which is today's behaviour. Back off keeps its current storage and
default (`includeBackoff`).

### D3 — Every phase has the same three controls: tempo, steps, hold

| Phase | Tempo | Steps | Hold |
|---|---|---|---|
| Warm-up | **Start at**: the floor (`workingTempo`) | rungs from the floor up to command | **Each step** |
| Command | **Tempo** | — (always one plateau) | **Hold**: the dwell |
| Reach | **Tempo**: auto or pinned, with Reset to auto | rungs up to and including the reach | **Each step** |
| Back off | **Settle at**: auto or pinned, with Reset to auto | rungs down to and including the floor | **Each step** |

A hold is shown in the unit the player counts: **bars** on an exercise, stepping by the 4-bar
interval an exercise's ramp has always used (`automatorDefaultBars`), and **passes** on a loop.
Every phase's range is 1…12 intervals, 0078's dwell range, now shared. The warm-up, reach and
back-off holds default to one interval (today's fixed value). The dwell keeps its stored value.

### D4 — Steps count the rungs you hear

A phase's Steps value is **the number of bars that phase draws in the staircase**, from 1 to 7. It
can't exceed the tempo gap it spans: seven rungs across a 3-BPM gap would repeat tempos, so the
upper bound is `min(7, gap)`, and the number shown is always the number drawn. Reach and back-off
already store a count of intermediate stops (value − 1), so their storage doesn't change.

The warm-up changes how it is built. `CommandRamp` places warm-up rungs **by count**, evenly between
the floor and command, the way `intermediateBPMs` already places reach and back-off rungs. This
replaces the stride walk that caused Context §4.

- **Exercises** store the count in a new `rampWarmupSteps: Int?`. When it is `nil`, as on every
  exercise saved before this ADR, the count is derived from the old stride by the existing
  `CommandRamp.intermediateSteps`, the same way the run screen already seeded its stepper. So an
  existing exercise keeps the setting it had, and now plays it. Because Steps now counts the rungs
  drawn, the floor included, the number reads one higher than the old count did (a warm-up that read
  2 reads 3, and plays three). After the first save `rampStepBPM` is no longer read. It stays in the store, because dropping it would
  be a destructive change for no benefit.
- **Loops** already store a count (`rampWarmupSteps`) and only change how it is spaced.

Stated plainly: **an exercise or loop that was hitting the rounding bug will play a different
number of warm-up rungs after this**. It will play the number its screen always showed.

### D5 — One set of words

- **Back off** everywhere: the switch, the row, the captions. "Back-off" and "Back-up steps" go.
- The floor's label becomes **Start at**, inside Warm-up. The model keeps `workingTempo`, and the
  ADRs keep "working tempo". The screen names what the number does.
- The collapsed summary names only the phases that are on: `51 → 61 · reach 65 BPM` as now, and
  `61 BPM, steady · 16 bars` for command only.

### D6 — No reach, no raise

The completion screen offers to raise command because the run just played the reach (0079). A run
with Reach off never went above command, so there is nothing to offer. The offer's raise target
becomes command itself, which `CommandOffer.canRaise` already reads as "nothing to raise". The
settle half (0134) is untouched. A player who wants a higher command after a command-only run edits
it themselves: nothing is measured or graded (0070).

Rows that print **Command → reach** (the exercise and loop library rows) print the command alone
when Reach is off, because that is what a run of it plays.

### D7 — The pencil shows only where the review bar doesn't

On both run screens (exercise and loop), the toolbar's quick-note pencil shows **while running or
inside a routine**, which are exactly the states where the review bar is hidden. On a stopped,
standalone screen the pencil is hidden, because the review bar's **Journal** is there and the
journal it opens writes too. Capture is still reachable in every state, which was the point of J1;
it just isn't offered twice on one screen. While stopped, the meter button sits where the pencil
was, so the toolbar holds two items either way.

### D8 — Loops use the same rows

The loop run setup, and its routine-block preview, get the same four rows in % of original.

**Reps per step** goes, and its value moves into the holds. A loop's interval becomes one pass. On
the first save through the new panel, the stored holds are multiplied out: the warm-up, reach and
back-off holds become `repsPerStep`, the dwell becomes `rampDwellIntervals × repsPerStep`, and
`rampRepsPerStep` is written as 1. Until that save, the new hold fields default to one interval of
`repsPerStep` passes, so a loop plays exactly what it played before. No stored loop changes on
upgrade.

### D9 — What doesn't change

- **Block fitting (0129)** moves only the command hold, and prices everything else by probing a
  one-interval dwell. The new holds are priced with no change. A command-only run in a long block
  still stretches its hold by at most 2.5× the authored value, a limit 0129 already has.
- **The tempo-change warning (0131)** reads plateaus. A command-only run has no change to warn
  about.
- **The practice log** records command, as before.
- **The ⓘ sheet's Tempo section** edits the anchors rather than describing the run, and is
  unchanged.
- **Edits stay local until Start or Save (0057).** The new fields join `ExerciseSetupState` and
  `LoopSetupState`, so changing them shows Save.
- **The staircase draws a single plateau at a fixed height.** Today a run with one tempo would draw
  it at the 30% floor of the height scale.

### D10 — The staircase says how long the run is

Once every phase has a hold, the obvious next question is "how long is this now?", and the
staircase's widths only answer it relatively. So a line under the staircase's captions states the
run's length: **`≈ 1 min 5 s · 16 bars`** on an exercise, **`≈ 2 min 40 s · 12 passes`** on a loop.

- **One source for the number.** The app already estimates run length: `SessionEstimate.seconds`
  prices each plateau's bars at its own tempo and meter, and `LoopEstimate.seconds` prices each
  plateau's passes at its own speed over the loop's region. The line reads those two functions and
  nothing else, so it can't disagree with the planner.
- **It describes the ramp that will actually play.** It reads the same ramp the staircase draws. In
  a generated session that is the ramp fitted to its block (0129), so the line is the precise form of
  0129's effective minutes. Where the fit hits its clamp, it can honestly differ from the planned
  slot, as 0129 already allows.
- **The count-in is not included**, as in the planner's estimates. It is a bar or two before the
  ramp starts, not part of the ramp.
- **Rounding** is done by one pure, unit-tested formatter: to the nearest 5 seconds below ten
  minutes (`≈ 45 s`, `≈ 3 min 10 s`), and to whole minutes from ten minutes up (`≈ 12 min`). It
  never reads `≈ 0 s`. The bar or pass count is exact.
- **It is a total, not a countdown.** While the run plays, the line keeps stating the same total and
  does not tick down. Reading a changing value in the run screen's body re-renders the screen on
  every change, the cost 0153 records for the playhead. A clock counting down is also a different
  feature from a length you read before you start.

It is a length, not a target: nothing compares it with anything, and nothing is measured (0070).

## Model

| Field | `Exercise` | `Loop` | Default | Meaning |
|---|---|---|---|---|
| `includeWarmup` | new | new | `true` | D2 |
| `includeReach` | new | new | `true` | D2 |
| `rampWarmupSteps` | new, `Int?` | exists | `nil` / `0` | D4: `nil` derives from `rampStepBPM` |
| `rampWarmupHold` | new | new | `1` | D3, in intervals |
| `rampReachHold` | new | new | `1` | D3 |
| `rampBackoffHold` | new | new | `1` | D3 |

All six are declaration-defaulted or Optional, so the migration is lightweight (the CoreData 134110
rule). There is no enum attribute. In the backup and hand-over records the new fields are
**Optional**, because a Codable default does not survive a missing key: an older backup, or a file
from an older build, has to decode and read as today's shape. Duplication copies them.

## Alternatives considered

- **Phase tabs**: a four-way control above the staircase, showing one phase's controls at a time.
  It is shorter and ties controls to bars more tightly, but it hides the other phases' switches.
  "Command only" becomes a visit to three tabs, and four segments get tight at the largest text
  sizes. Rows keep every switch in sight and read in play order.
- **A row of shape presets** ("Full ramp / Climb and hold / Command only"): a second way of saying
  what the switches already say, and it turns into "Custom" the moment anything is nudged.
- **One shared hold for warm-up, reach and back-off**: simpler, but the phases want different
  lengths. A warm-up rung is worth staying on, and the reach is meant to be brief (0045: "a brief
  hold").
- **A 1-bar hold unit for exercises**: finer, but every stored dwell is in 4-bar intervals, so it
  would mean rewriting stored values. On the instrument, four bars is the natural phrase anyway.
- **A countdown of time left while the run plays** instead of D10's static total. It would re-render
  the run screen on every tick (the cost 0153 records), and "how long is this?" is a question you ask
  before pressing Start.
- **The run's length in whole minutes**, as the planner shows a block. Most standalone runs are
  under five minutes, so whole minutes would show `1 min` for anything from 30 to 90 seconds and
  hide exactly the changes a hold makes.

## Consequences

- A run can be one phase. The minimum drops from two to one.
- Existing exercises and loops play what they played, except those hitting the warm-up rounding
  bug, which now play the count their screen showed (D4).
- `CommandRamp` loses `stepBPM` and gains a warm-up count, two switches and three holds. Every call
  site changes, and its tests grow a case for each combination of switches.
- `RoutineStepsControls` is deleted once both panels have moved (step 2; done).
- `RoutineStairs` gains an optional length line (D10). All four callers pass it in: both run screens
  and both block previews.
- The manual's Practice Settings section, its pencil line, and the reference strings for these
  controls are rewritten in step 1.

## Build

**Step 1: exercises, and the pencil.**
- `CommandRamp`: optional warm-up and reach, a hold per phase, warm-up by count.
- The `Exercise` fields, plus backup, hand-over and duplication.
- The phase rows on `ExerciseRunView` and the exercise block preview, and the staircase lighting.
- D6, and D7 on both run screens.
- D10 on the exercise screens: the length formatter and the line under the staircase.
- Tests: plateaus for every combination of switches; holds; rung counts across spans, with Context
  §4's cases as regression tests; the stride-to-count seed; a backup decoding without the new keys;
  the length formatter's rounding bands and its lower bound.
- `RowUndoUITests` and the exercise shoot class both tap the pencil on a stopped screen, so both are
  rewired here.

**Step 2: loops.** The `Loop` fields, the reps-per-step fold, `LoopSettingsPanel` moved to the shared
rows, the loop block preview and its length line in passes, and `RoutineStepsControls` deleted.

**As built (step 1).** Choices the decisions above left open, taken from the mockup the rows were
chosen on, and one the build forced:

- Command's row is the one open when Practice Settings expands. A switched-off row is dimmed and
  doesn't open; switching a phase on opens its row, and switching the open one off closes it.
- The collapsed summary names the back off too when it plays: `51 → 61 · reach 65 · back to 57 BPM`.
- The shape travels as one value, `RunShape` (switches, rung counts, holds), and the rows' words come
  from one pure `RampSummary`, so the run screen and the block preview can't word a phase
  differently.
- `CommandRamp` lost `stepBPM` in step 1, so **loops already space their warm-up by count** — they
  pass the count they store instead of converting it to a stride. `warmupStepBPM` survives only as
  the loop panel's "+N % per step" caption until step 2 replaces that panel.
- The exercise block preview's **Start at** shows `rampFloor`, the floor the staircase climbs from.
  It showed `workingTempo`, which on an exercise with no measured command *is* command, so the row
  and the bars disagreed. Moving it pins command first, as the loop preview and the run screen's
  save already do.

**As built (step 2).** Loops moved onto the same `PracticeSettingsPanel`, and `LoopSettingsPanel`,
`RoutineStepsControls` and `CommandRamp.warmupStepBPM` are deleted. What the decisions above left
open:

- **The fold happens on read, and the first save writes it.** `Loop.runShape` multiplies every
  stored hold by `rampRepsPerStep`, so a loop that has never been saved through the rows already
  shows its holds in passes and plays exactly what it played. `Loop.applyRunShape(_:)` writes the
  passes and `rampRepsPerStep = 1`, after which the multiplication is the identity. Start saves too
  (0057), so the fold also lands on the first run. A loop's ramp is built with one pass per interval
  whether or not it has folded, and the tempo at every pass is the same either way (a test checks it
  pass by pass). One thing does move by less than a step: a generated session fits a loop's dwell in
  whole passes rather than in whole reps-per-step intervals.
- **A folded hold may sit above 12.** D3 gives every hold 1…12 intervals, and on a loop an interval is
  now one pass, so the range is 1…12 passes. But the fold multiplies: 4 reps a step with a dwell of 4
  is 16 passes. Clamping it would change what the loop plays, which D8 rules out. So
  `RunShape.setHold` treats a hold that is already above the ceiling as its own ceiling: − walks it
  down one pass at a time, + does nothing, and once it is inside 1…12 the range holds. **Open:** the
  old controls could reach 96 passes at command (12 × 8 reps), and the rows can author at most 12. A
  short loop, a one-bar lick say, may want more than 12 passes at command. If it does, the fix is a
  loop-specific ceiling, not a return to reps per step.
- **A loop whose song hasn't resolved** has no region to price, so D10's line states the passes alone
  (`12 passes`) rather than the formatter's `≈ 5 s` floor.
- **The loop block preview's tempo readout** (`70% → 85%`, `reach 91%`) follows the shape: it drops
  the climb when Warm-up is off or has no room, and the reach when Reach is off (D6).
- **The Loops library row** prints `Command 85%` alone with Reach off (D6), and both loop completion
  offers, standalone and in a routine, raise to `Loop.summitSpeed`, which is command when Reach is off.

**Figures owed.** One shoot, at the end of step 2 and together with ADR 0220's owed reshoot:
`exercises/run-setup`, `exercises/practice-settings`, `exercises/staircase`, and
`journal/quick-note-button`. That glyph was cropped from the stopped run screen, so it has to come
from the running one now: the shoot class serves it from `exercises/run-live` since step 1. Its
existing `crop` still frames the pencil there — the pencil moves into the meter's old slot, which is
where it sat before — checked on a diagnostic shoot with the same `sips` call `build-figures.py`
makes.
