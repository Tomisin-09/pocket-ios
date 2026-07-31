# ADR 0129 — Practice sessions are sized in blocks, not minutes; a preset means one thing; the ramp fits its block

- **Status:** Accepted
- **Date:** 2026-07-31 (`pocket-209-session-block-model`)
- **Amends:** **ADR 0014** — R2's default focused-block length was specified but never enforced by
  `SessionBuilder` (only its ceiling was), and R8's presets stop being minute *budgets*. R3's rests are now
  charged against the budget rather than added after it. R4's micro-rest cue finally gets populated.
  **ADR 0118** — its deliberate "the preset is a *total* cap here, a *focused* budget there" divergence is
  withdrawn; there is one meaning now. **ADR 0045/0046** — the `CommandRamp` gains a *fitted* form; the
  stored recipe is unchanged and stays authoritative for standalone runs.
- **Builds on:** ADR 0070 (never grade the player — everything here schedules effort, nothing measures it).
  ADR 0121 (a command tempo is bound to the rhythm it was measured in). ADR 0117 (rescoped — the practice
  log lands alongside this work). ADR 0071/0076/0079 (the routine player's block seams this rides on).

## Context

The planner's session sizing is measurably broken, and the defect compounds as a player invests in the
app. Traced end to end on 2026-07-31:

| Step | Value | Where |
|---|---|---|
| A fresh exercise has `currentTempo = 80`, `commandTempo = nil` | — | `Exercise.swift` |
| `workingTempo` is an alias over `currentTempo`, so **working == command** | — | `Exercise+Tempo.swift` |
| ⇒ `command > working` is false → **no warm-up plateaus**; backoff derives to command → **no backoff** | — | `CommandRamp.plateaus` |
| The whole ramp is dwell (16 bars) + summit (4 bars) | **20 bars ≈ 59 s** | — |
| `SessionEstimate.minutes(forRamp:)` rounds and floors at 1 | **1** | `SessionEstimate.swift` |
| The goal-less Quick path gives every library exercise `priority = 1.0` | — | `PracticePlanner.candidate(for:)` |
| `select` greedily fills the budget with `max(1, estimatedMinutes)` — no floor, no item cap | **15 items at a 15-min budget** | `SessionBuilder.select` |
| `interleaveRests` inserts a 3-min rest between **every** adjacent pair, *after* budgeting and uncharged | **14 rests = 42 min** | `SessionBuilder.interleaveRests` |
| Plus unbudgeted warm-up (5) and play (10) | — | `SessionBuilder` |

So a **"Quick 15"** renders as **31 blocks and ~72 minutes** on a grown library, and **13 blocks and
~36 minutes** on the seeded first-run library of six exercises. Three of the four documented ramp phases
never appear until an exercise has been promoted at least once.

Two root causes, both narrow:

1. **`SessionBuilder` enforces R2's ceiling but not its floor.** It calls `splitFocused`
   (`maxFocusedMinutes = 20`) and never reads `defaultFocusedMinutes = 12`. `CollectionSessionBuilder`
   does read it, *and* enforces a `minFocusMinutes = 4`, *and* charges rests against its budget. The
   planner does none of the three — the two builders have drifted apart on three separate axes.
2. **A minute budget is the wrong currency.** The number a player picks is a promise about how long they
   will be sitting there; the code spends it on deliberate work only, and then adds rests and book-ends on
   top. The two builders resolved this contradiction in opposite directions, both defensibly, which is why
   "Quick" has meant two different things since ADR 0118.

A third force is new: this project is about to run its first external cohort, and interleaving/variable
practice (from the motor-learning literature) argues for rotating several items rather than grinding one —
which pulls directly against R2's 10–15 minute blocks. That conflict has to be resolved deliberately rather
than by accident of implementation.

## Decision

### 1. A preset is a count of blocks, not a budget of minutes

`SessionLength` stops denominating minutes and denominates **focused blocks**. A block is R2-sized (12–15
minutes) and holds **three items**, practised one pass each in sequence.

| Preset | Blocks | Items | Focused min | Rests | Book-ends |
|---|---|---|---|---|---|
| Quick | 1 | 3 | 12–15 | 0 | warm-up only |
| Focused | 2 | 6 | 24–30 | 1 | warm-up + play |
| Full | 4 | 12 | 48–60 | 3 | warm-up + play |

This keeps every ADR 0014 rule intact rather than trading them off: R2's block length is preserved
exactly, R3's rests fall between *blocks* (0/1/3 instead of 14), R5's U-shape still orders the items, R7's
60-minute focused ceiling is exactly the largest preset, and R8's "presets are modest, default is short"
holds with Quick still the default.

**It also resolves the interleaving conflict.** Rotation happens *inside* a block, where R2's length is
the container rather than the competitor. The player meets three things per block instead of grinding one,
without any block violating the research-derived length.

### 2. Minutes become one derived estimate, always total

Because the count is now the budget, minutes stop being a budget at all and become a **readout**: an
estimate of total elapsed time, including rests and book-ends, everywhere it appears. One meaning, both
builders.

`CollectionSessionSheet` already speaks this grammar — it builds `"Quick · ~22m"` from a real per-collection
estimate. `PlannerView`'s `"Quick · 15m"` is the odd one out, stating a budget as fact. **PlannerView adopts
the collection sheet's grammar**, not the reverse.

R1 is untouched: play is still never *capped*. It is merely *included in the estimate*, and not
*scheduled* in a Quick sitting (sub-decision 2 below).

### 3. `SessionBuilder` enforces the floor and budgets its rests

- Fill to the **item count**, not to a minute budget.
- Every focused block is R2-sized; no more one-minute stubs.
- Rests are **charged against the session** as `CollectionSessionBuilder` already does, not appended
  afterwards.
- `microRestEvery` — plumbed on `SessionBlock.focus` since ADR 0014 R4 and passed `nil` at all four
  construction sites ever since — is finally populated, carrying the in-block rotation cue.

### 4. The ramp fits its block, dwell-dominant — **within reach of the authored recipe**

> **Amended 2026-07-31 after device testing.** The fit as first shipped was unbounded, which made it an
> *override* rather than an adjustment: an exercise authored 64→75 / reach 80 with a **4-interval dwell**,
> given a 5-minute block, was fitted to **~19 intervals (~76 bars at command)** — five times what its
> author asked for, and wide enough that `RoutineStairs` printed "reach" and "back off" on top of each
> other. Sub-decision 3 below protected the stored recipe from being *written* and treated that as
> sufficient. It wasn't, because the run ignored the recipe anyway.
>
> **The fit is now clamped to 0.5…2.5× the authored dwell** (`SessionEstimate.clampedDwell`), and —
> this is the half that matters — **where the clamp bites, the block's estimate gives way, not the
> recipe.** `SessionEstimate.effectiveMinutes` prices the ramp that will actually play, and
> `PracticePlanner.estimatedMinutes(forRoutine:)` sums *that* rather than reading each block's
> allotment back as fact. So a 5-minute slot holding a short staircase reads as the ~3 minutes it
> takes. The allotment is the block's **ask**; the fitted ramp is the **answer**; the readout reports
> the answer. Rejected alternatives: letting the block's share follow the authored length (a preset's
> minutes stop being predictable at all), and making the fit opt-in (the block model's central promise
> would then be off by default).
>
> The device pass also found the fit applied to **exercises only** — `LoopRunView` never read
> `plannedMinutes`, so a loop block was allotted a slot and ignored it. Loops now fit the same way,
> through a separate `LoopEstimate`: a loop ramp reuses `CommandRamp` with intervals meaning *passes*
> and plateau values meaning *percent of original*, so one interval costs `regionSeconds ÷ (percent/100)`
> and the exercise estimator's bars-against-a-meter arithmetic would have produced a number in the
> wrong units. Same dwell quantum, same clamp, same "report what plays" rule.

`CommandRamp` gains a **fit-to-minutes** construction: warm-up, summit and backoff hold roughly fixed, and
the remainder goes into the **dwell**. Consolidation happens at the tempo you own, so the dwell is the only
phase that absorbs added time. For a ~4–5 minute slot that is roughly 45 s warm-up, 3 min at command,
30 s summit, 20 s backoff.

The dwell share is **emergent, not enforced** — an exercise with a long staircase keeps more of its slot in
the climb, one with a short staircase spends nearly all of it at command. It lands around **65–75%**.
Enforcing a fixed share would mean padding the other plateaus, which just makes the climb languid.

Pure arithmetic on a pure type; no schema change; unit-tested per AGENTS.md.

### 5. The five sub-decisions

0. **Selection deals across goals; it does not skim the top N.** *(Added 2026-07-31 after device
   testing.)* `SessionBuilder.select` ranked purely by `DueScore` and there was no per-goal quota
   anywhere, so with two equally-weighted goals a generated **Quick** session drew all three items
   from the first and the second goal never appeared. This is a consequence of this ADR that the ADR
   did not anticipate: at ~15 items both goals were represented by brute force; at **three**, top-N
   takes everything. `PlannerCandidate` gains a `goalUID` (the strongest claim's goal, set by
   `CandidateDeriver`) and `select` deals one item per goal per pass, goals visited in the order their
   best candidate ranks. The most-due goal still leads and still takes the odd slot — a share, not an
   equal split — and a goal that runs out is skipped rather than holding a place, so a thin second goal
   never costs the session an item. With one goal, or none (the goal-less Quick path), it is exactly
   the old top-N.
1. **A never-promoted exercise gets a derived warm-up floor.** `workingTempo` is a straight alias over
   `currentTempo`, so working cannot sit below command without a promote — fitting alone will not conjure a
   staircase. When `commandTempo == nil`, `Exercise.ramp` derives its floor from
   **`TempoStretch.warmupFloorBPM(forCommand:)`** — a 15% drop clamped to 5…20 BPM.

   **The precise defect is a disagreement, not an absence.** `ExerciseRunView.seedIfNeeded` *already*
   calls that helper for an un-measured exercise, explicitly "so the two start apart, not equal (ADR
   0045)" — so a **run** has always warmed up correctly. But `Exercise.ramp`, the model-level staircase
   the *planner* estimates from, took `workingTempo` raw and therefore collapsed to dwell-plus-summit.
   Two ramps for one exercise, disagreeing: the screen played 68 → 80 → 85 → 75 while the model
   described a flat hold at 80. `Exercise.ramp` now derives the same floor the run screen does, so the
   model describes what actually plays. `derivedBackoff` takes it too, for the same reason.

   Worked example, `currentTempo = 80`: floor 68 ⇒ warm-up 68 · 73 · 78, dwell at 80, summit 85, backoff
   75 — 36 bars ≈ 1 min 52 s, where the *model* previously said 20 bars ≈ 59 s. That 59 s is what
   `SessionEstimate` floored to one minute, and one minute is what let `SessionBuilder` pack fifteen
   items into a Quick session. The user-visible bug was the flooded session; the ramp disagreement was
   its cause.

   **Extended to loops 2026-07-31 after device testing.** `Loop` has the identical collapse in `×`
   units — `Loop.command` falls back to `speed` when nothing is promoted, so an un-measured loop had
   working == command and its staircase showed only *command* and *reach*, no warm-up and no back off.
   `LoopRunView.seedIfNeeded` had always seeded a floor below command, so a *run* climbed correctly;
   `Loop.ramp` — what the planner estimates from and what the routine's block preview draws — did not.
   That seeding rule now lives on the model as **`Loop.rampFloor`** and the run screen reads it, so the
   two cannot drift. Derived, never stored; no migration.
2. **Book-ends scale with the preset.** Quick gets a warm-up and **no play block**; Focused and Full get
   both. Precedent: `CollectionSessionBuilder.playCap(for:)` already scales play-throughs 1/2/3 by preset.
   Under a total-minutes readout, a 5-min warm-up and 10-min play would otherwise make "Quick" read ~28
   minutes — true, and absurd.
3. **The stored recipe stays authoritative; the fit is a run-time override.** The fitted length is passed
   through a new `RoutineRunContext` field, **not** by writing `exercise.dwellIntervals`. Generating a
   session must never silently rewrite an exercise the player authored. `RoutineStepsControls`' dwell
   stepper keeps its meaning everywhere it exists today; its caption reads the *effective* dwell when a
   routine context is present.

   **Amended during implementation — the share has to be persisted, so this needs one schema field.**
   `PracticePlanner.item(for:)` read a block's `unit` and `kind` and dropped its `minutes`, so a
   generated session's allotted times died at materialisation and the run had no idea what slot it was
   filling. `RoutineItem` gains **`plannedMinutes: Int?`** — Optional with no declaration default, the
   migration-exempt shape `Exercise.targetTempoOverride` already uses, so hand-authored items migrate to
   `nil` and keep their natural length. Note this does **not** weaken the sub-decision: the minutes are a
   property of *this block in this routine*, which is precisely why they belong on `RoutineItem` and not
   on `Exercise`. Only **focused** blocks carry it — pinning a warm-up or play-through to a nominal
   figure would contradict R1, which says those run as long as the player likes.
   **Amended 2026-07-31 — the preview has to show the fitted ramp, not the authored one.** Keeping the
   recipe unwritten is necessary but not sufficient: the routine sheet's block preview drew the
   *authored* staircase while the run played the *fitted* one, so the two surfaces contradicted each
   other on device. `RoutineBlockPreviewTarget` now carries the block's `plannedMinutes` and both
   previews draw the effective ramp — the same expression the run screen hands the engine. Making the
   surfaces agree only makes the override *visible*, which is why it is paired with bounding the fit
   (sub-decision 4 above); on its own it would have been a prettier lie.
4. **`ExerciseTempoSection` shows the derived floor** on an unmeasured exercise, so the sheet cannot say
   "Working 80" while the ramp runs from 72. The section's own footer already calls working "the warm-up
   floor"; it should show the floor the warm-up uses.
5. **Interleaving is one pass each (A·B·C), not full rotation (A·B·C·A·B·C).** Full rotation requires a
   ramp to resume mid-staircase — restart the warm-up, or resume at the plateau? — which is a real design
   question with no obvious answer. Ship the cheap form; let the cohort say whether the complexity earns
   its keep.

## Consequences

- **`estimatedMinutes` roughly 5×'s for every exercise**, app-wide and deliberately. It ripples into
  `CollectionSessionBuilder`'s sizing, `RoutineDetailView+Length`'s "~N min" readout and
  `SessionEstimate.fit`. Accepted explicitly: the old number was wrong, and everything downstream of it was
  wrong in the same direction.
- **A generated Quick session goes from 13 blocks (~36 min) to 4 blocks (~15 min)** on the seeded library.
  The routine editor's layout does not change; there is simply far less of it.
- **"Full" now estimates ~75 minutes, not 60.** R7 caps *focused* work at 60 and that is unchanged; the
  extra is rests and book-ends, which the old model hid. This is the honest total and should not later be
  "fixed" back down.
- `SessionEstimate.fit` becomes an **edit-time** signal only. A freshly generated session is on-target by
  construction, so the hint fires only after the player adds or removes blocks — and its copy moves from
  "your 15 min" to the preset.
- **UI cost is small**: three copy edits (`PlannerView`'s picker label, `budgetHint`, the dwell caption),
  one new `RoutineRunContext` field, two display decisions (3 and 4 above). No new screens, no navigation
  change, no toolbar work (ADR 0126 untouched), no authoring flow affected.
- `RoutineStairs` redraws itself from the new plateaus with no code change — a fresh exercise's stub
  becomes a real staircase with a wide command bar, which is what ADR 0045 always intended to show.
- **Still never grades the player** (ADR 0070). Everything here schedules and sizes effort; nothing measures
  how well anything was played.
- The two builders converge on three axes (floor, budgeted rests, preset meaning) without merging — they
  remain separate producers of `[SessionBlock]`, as ADR 0064 intends.

## Alternatives considered

- **Keep minutes as the budget and just add a floor and an item cap.** Rejected — it fixes the symptom and
  leaves the two meanings of "Quick" in place, which is the thing that let the drift happen. It also leaves
  rests uncharged, so a "15-minute" session still overruns.
- **~5 minutes per item, giving Quick 3 / Focused 6 / Full 10 directly.** Rejected — the figure was
  reverse-engineered by dividing preferred counts into preset minutes, and it silently reverses R2's
  research-derived 10–15 minute block. The block model reaches nearly the same counts *from* R2 rather than
  against it.
- **Honour R2 literally: one 12-minute block per 15 minutes, so Quick is one item.** Rejected — a
  single-item Quick session is thin, and it forgoes interleaving entirely. Three items inside one R2-sized
  block satisfies both.
- **Make the preset a total-minutes cap (the ADR 0118 reading) and keep minutes as the budget.** Rejected —
  it caps *play*, contradicting R1's "we never tell them to stop playing." Counts as the budget and minutes
  as a readout preserve R1 exactly.
- **Fit the ramp by writing `dwellIntervals` on the exercise.** Rejected — generating a session would
  rewrite the player's authored recipe invisibly, and a saved exercise would drift every time it appeared
  in a generated sitting. See sub-decision 3.
- **Full rotation (A·B·C·A·B·C) in the first cut.** Deferred, not rejected — it needs a ramp-resumption
  rule, and the cohort will say whether it is worth one.
- **Unify the two builders into one.** Rejected — out of scope here and against ADR 0064's shape. They now
  agree on the rules that matter while staying separate producers.
