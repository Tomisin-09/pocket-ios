# Backlog

Deferred work that's intentionally parked — known, but not scheduled. Each item
notes enough context to pick it up cold. Promote to a branch (and an ADR if it
closes off an alternative) when it's time to act.

## Build order — ADRs 0135–0139 (decided 2026-08-01, nothing built)

Five ADRs landed as **decisions only, no Swift**: 0135–0138 on main (squash `0187282`, PR #203) and
0139 on `pocket-217-off-guitar-session`. Each ADR carries its own slices; this is the sequence
*across* them, which lives nowhere else. Two tracks that barely touch — Track A is loops/planner,
Track B is the freeform block.

**A0 — verify ADR 0117's write path on device. ✅ DONE 2026-08-01.** All three seams exercised on the
iPhone and the store read directly (`devicectl … --domain-type appDataContainer`, then SQL over
`ZPRACTICERUN`): `.exercise`, `.loop` and `.earLoop` rows all present, every `unitUID` resolving to a
real named exercise or loop, `routineUID` set for routine blocks, tempo fields populated per kind. No
seam silently fails to log. One thing surfaced that ADR 0138 should decide: **standalone ear training
(`EarTrainingSheet`) writes no row at all** — ADR 0117 rules it open-ended — so only ear blocks *inside
a routine* contribute dueness.

1. **ADR 0137 — dueness from the log. ✅ BUILT 2026-08-01** (`pocket-218-dueness-from-the-log`).
   `PracticeLog.lastPracticedByUnit` + tests, a defaulted `lastPracticed:` param on
   `PracticePlanner.library` and `planGoalSession`, and **one** call site querying the log — not two:
   `RoutineLibraryView` and the goal-less fallback both use `planQuickSession`, which is
   exercises-only and never projects a loop. No UI, no schema, no migration.
2. **ADR 0138 — per-mode gates (ear arm). ✅ BUILT 2026-08-02** (`pocket-219-per-mode-gates`).
   Preconditions extracted to a pure `LoopModeAccess` (trainer + ear arms; **improvise deliberately
   absent** until `isBackingTrack` exists — its `switch` has no `default`, so step 3 won't compile
   until it states the third gate). Ear bucket ungated, all-loops filter added to `LibraryOptionsMenu`
   as an optional *widening* filter, per-mode row affordances, empty state rewritten.
   **Device-verified 2026-08-02** — the flagged noise risk did not materialise: Ear reads 46 against
   Loops' 38 on a real library, 8 rows longer rather than the "several times" the ADR feared.
3. **ADR 0135 slice 1. ✅ BUILT 2026-08-02** (`pocket-220-backing-track-loops`). `Loop.isBackingTrack`
   (+ `LoopEditSnapshot` staging and the settings-sheet toggle with its guidance footer),
   `ImproviseSheet`/`ImproviseView`, `EntryKind.improvise` 🎸, `PracticeRunKind.improvise`, the
   Loops-library **Backing tracks only** filter and per-row **Improv** button, and the improvise arm
   of step 2's gate. `LoopRunMode.improvise` landed **here** rather than in step 4 — `LoopModeAccess`'s
   `switch` has no `default`, so the gate can't be stated without the case. Two boundaries moved,
   both recorded in the ADR's build notes: the **Improvise bucket went to step 4** (a bucket authors a
   routine block, which is all of slice 2 — shipped alone it would author blocks that fall back to the
   trainer), and the shelf filter **replaces** the trainer gate instead of composing with it (composing
   hides the unmeasured flagged loops B9 exists to admit). Not device-verified yet.
4. **ADR 0135 slice 2.** `ImproviseLoopRunView` in the routine player + the **Improvise bucket** in
   `AddRoutineUnitSheet` (carried from step 3), the `RoutineUnitPick` case, the stage dispatch, and the
   Done-screen skip. Mirrors ADR 0104 slice 2. The mode case and its presentation strings
   (`label`/`rowLabel`/`symbolName`) already exist.
5. **ADR 0135 slice 3 + ADR 0139 slice 1 — build adjacently.** Both need the same structural change:
   `PlannerCandidate`/`SessionBlock` carrying a `LoopRunMode` through to the materialised
   `RoutineItem`. Doing them apart means doing it twice. Also here: `improv.vocabulary` resolution,
   `play`-kind placement, the `ear.*` capability contribution, the `constraint` parameter, and the
   "Away from your instrument" option.

**Track B — ADR 0136 (freeform blocks), independent of all of the above.** Touches
`ExerciseTemplate`, `NewExerciseSheet`, a run screen and two planner assertions; near-zero overlap
with Track A, so it can run in parallel or go first if a visible feature is wanted sooner. **ADR 0139
slice 2** (freeform blocks declaring themselves off-guitar) comes after it.

**Watch items to carry into the branches:**
- `AddRoutineUnitSheet.swift` is **324 lines** and step 3 left it untouched, so the Improvise bucket
  now lands in **step 4**. The 400-line cap plus CI `--strict` will bite. The split is planned, not to
  be discovered: extract the `// MARK: - Search` block (~50 lines) into
  `AddRoutineUnitSheet+Search.swift` if the bucket takes it past ~370. It holds no state beyond
  `searchText`.
- **Standalone `ImproviseSheet` logs no `PracticeRun` row**, matching standalone `EarTrainingSheet`.
  The A0 finding above is therefore now **two** open-ended surfaces contributing no dueness, not one.
  Still undecided; decide it before ADR 0139's off-instrument work leans on loop dueness.
- `UnitDuplication`, the preset seeder and bulk import must carry `Exercise.notes` once ADR 0136 makes
  it mean something. A duplicate that drops the instructions drops the exercise.
- Two **silent-break** claims in ADR 0136: `SkillFamilyMap` omitting `.freeform`, and
  `PracticePlanner.library` *not* extending its `.warmup` exclusion to it. Nothing crashes if either is
  wrong; the planner just quietly misbehaves. Unit tests, not manual checks.
- ADR 0139 §O2b: dedup stays keyed on the unit, **not** unit-plus-mode, or one loop lands in a session
  twice — once to train, once to sing back.
- Per branch as usual: `swiftlint --strict`, the generic-simulator build, `-testPlan PocketAll`,
  `CHANGELOG.md` for the user-visible ones, and device verification before calling anything done.

## ADR 0129 device-test findings — ALL FIVE FIXED (2026-07-31, branch `pocket-209-session-block-model`)

Device-tested on the iPhone 16 Pro after ADR 0129 landed (5 commits, `5b1dc10`…`19aca0d`).
**Confirmed working:** the store migrated with the library intact, Quick and Focused both generated as
expected (Quick = warm-up + 3 focus items, no rests, "~15m"; block model correct). Five problems and
one feature request came out of it; the five are **fixed on this branch**, ADR 0129 amended in place.
Kept here as the record of what was found and how it was resolved — **not** outstanding work.

1. **An exercise didn't start after a Skip.** Cause found by inspection and **pre-existing on `main`,
   not an ADR 0129 regression**: `StandaloneMetronomeEngine.stop()` ended with a process-global
   `AVAudioSession.setActive(false)`. SwiftUI starts the incoming block's engine *before* tearing down
   the outgoing one, so the outgoing `stop()` deactivated the session the new run had just activated —
   its player node never rendered, `renderSampleTime()` stayed `nil`, `tick()` bailed before advancing
   the beat, and the count-in froze at 4 with a live UI and a silent click. Fixed by reference-counting
   the session (`AudioSessionLease` / `AudioSessionClaim` in `AudioPlumbing`): last producer out
   deactivates. **Not device-verified yet** — the diagnosis is from the code, so confirm on the phone.
2. **The fit overrode the authored dwell (and the preview disagreed with the run).** Settled as a
   design decision with the user: **bound the fit and let the estimate give way.** `clampedDwell` holds
   the fit to 0.5…2.5× the authored dwell, and `effectiveMinutes` prices the ramp that will actually
   play, so a slot the fit can't reach reads as what it really takes. The block preview now carries
   `plannedMinutes` and draws the fitted staircase. Rejected: block-follows-authored-length (preset
   minutes stop being predictable), opt-in fit (the model's promise off by default).
3. **Loops were left out of the block model.** Both gaps closed — `Loop.rampFloor` mirrors
   `Exercise.rampFloor` in `×` units (the run screen now reads it rather than re-deriving its own), and
   the new `LoopEstimate` fits a loop block by its dwell (passes at command) with the same clamp. Ear
   blocks have no ramp and keep region × repeats.
4. **One goal crowded out the others.** `PlannerCandidate.goalUID` + `SessionBuilder.roundRobin` —
   goals take turns, most-due goal leads and takes the odd slot, an exhausted goal is skipped rather
   than holding a place.
5. **Staircase labels overlapped.** `RoutineStairs` captions are now bounded by their own group's
   width (scaling down, or dropping below `minCaptionWidth`) instead of being free-sized, so they can
   abut but never collide — independent of how lopsided the ramp is.

**Warn before the tempo changes — visual half BUILT, audible half deferred.**
**[ADR 0131](decisions/0131-warn-before-the-tempo-changes.md)**, branch
`pocket-211-tempo-change-warning`. Shipped: a pure `pendingChange(…)` on both ramps, a one-bar window
clamped to half a plateau, `Settings ▸ Tempo changes` (Off/Show), and three visual carriers — the run
caption, the staircase pre-light, and a static edge on the drill surface. Not device-tested yet.

**Device-verified 2026-07-31** on an untemplated exercise: all three carriers fire together and the
caption reads clearly ("Backing off to 75", staircase `reach` lit with `back off` pre-lit).

**Parked — visual redesign.** Functionally right, but the presentation wants another pass. Two things
seen on device, neither critical:

- **The edge around the beat dots is the weak spot — probably the wrong idea there, not just the
  wrong styling.** On an exercise with no template the drill surface *is* `BeatIndicator`, so the
  outline draws as a pill around four small dots and reads as a selected segmented control. Don't
  start from "tune the stroke": ask what would actually indicate an imminent tempo change on a
  *dots-only* screen, where the dots themselves are already the beat. ADR 0131 §3a reasoned the
  static-edge decision about a **board**, and may be right there and wrong here — in which case the
  fix is a per-surface treatment, and the "one modifier on `ExerciseTemplateSurface` covers all five
  configurations" argument (§3a's second bullet) is the thing that has to give.
- **Only 1 of 5 run configurations has been seen.** Fretboard, strumming, chords and strum-chords all
  route through the same modifier but have very different bounds; the edge's geometry (12pt radius,
  2pt stroke) is unverified against any of them.

Revisit as a design task, not a bug. The teal-vs-plum question from ADR 0131 §3a is still open and
should be settled in the same pass.

Still open, in the ADR and deliberately unbuilt:

- **The `sound` mode** (§3) and what it needs — §5's scheduled-beat boundary (new engine state, plus a
  stale-origin path on mid-run signature changes) and §6's `scheduledLevel` precedence change, which
  costs a strum drill its pattern for a bar. All audio-path work needing device verification. Worth
  revisiting after practising with the visual half: it exists for the plain metronome exercise and
  loop practice, where the eyes are on the hands rather than the screen.
  **§5 is now ADR 0132's to build** — the click withdrawal needs the identical captured origin, so
  whichever ships first pays for it and `sound` is left holding only §6.
- **§7's loop warning.** Currently quiet rather than broken (a one-pass plateau's clamped window can't
  be reached by an integer rep count). Needs a fractional rep position on `LoopRunModel`.

## The click withdrawal (ADR 0132, Proposed — unbuilt)

Silent bars: the click thins to the downbeat and then out on a fixed eight-bar cycle, so the player
carries the pulse and hears their own drift when it returns. **Decided but not built** — the ADR is
written, no code exists. Two slices, deliberately:

- **Slice 1 — the feature, no stored model change.** Pure `ClickWithdrawal` cycle math, the
  `drillOriginTick` capture and its re-anchor invalidation (ADR 0131 §5's state), the
  `scheduledLevel` branch, the Settings row, and `BeatIndicator` reading the voiced level so the dots
  go dark with the click. Device-testable without touching persistence — and the §2 bar
  distributions can only be judged by playing against them.
- **Slice 2 — the per-exercise override.** The Optional `clickWithdrawalRaw` field (`nil` = inherit,
  which is what keeps the Settings row from becoming a new-exercises-only preference) and its
  `ConfigureExerciseForm` row. The only part that can break an existing install, so it waits until a
  week of practice says which drills want to differ.

Open question the ADR names rather than settles: on fretboard/chord drills the content advances on
the beat, so the eyes keep a pulse the ear has lost and the withdrawal is partial there by
construction (§7a). Whether that is worth a further answer is a device-testing question.

## Command moves both ways (ADR 0134 — **slice 1 SHIPPED**, slice 2 parked)

The post-run offer can only ever raise `command`, so a run that fell apart still lands on a Done
screen reading "you summited it — bump the drill up". The ramp completes on a timer (the app never
listens), so a bad run reaches that screen exactly as a good one does. - **Slice 1 — the symmetric offer. BUILT 2026-08-01.** `PromoteOffer` → `CommandOffer` with a
  direction chosen by the mastery tap already on that screen (1–2 settle · 3 nothing · 4–5 / unrated
  raise, so the unrated path is unchanged). Settle defaults to the backoff the run just played and
  ranges down to the instrument's floor. The working-floor pull-down and the backoff-pin clear are
  pure `CommandOffer` helpers with two callers each — the model setters *and* the run screens' local
  `@State`, because `persist()` would clobber a direct model write (ADR 0134 §10). Adds a derived
  `Loop.backoffPercent`. No stored field, no migration. **Not yet device-tested.**
- **Slice 2 — mid-run settling, needs its own ADR.** A transport action that drops the live run to
  its backoff plateau and keeps playing, instead of forcing a stop. Touches `CommandRamp` in flight,
  re-anchors the grid, and owes ADR 0131 a warning (a settle *is* a tempo change). Audio-engine work,
  not completion-screen work.

The copy is load-bearing and named as such in §5 — the settle row has to read as technique, not
concession, and the mastery caption is the only place the player learns that rating honestly buys
them anything. Not decoration to trim at build time.

## A loop can be a backing track (ADR 0135, Proposed — unbuilt)

Looping a chord section of a song and playing over it already works; the app just doesn't know it's
happening. The section is indistinguishable from the four-bar lick being ground at 60%, so it can't
be found later, run in a mode that suits it, or reached by the planner. The answer is ADR 0104's
shape again — a mode on a loop the player already owns, playing the real audio (0104 E5), notes into
the Journal — plus one thing ear training didn't need: a **flag**, because any loop can be sung back
but not every loop is jammable.

- **Slice 1 — the flag, the surface, the shelf.** `Loop.isBackingTrack` (a `Bool` with a declaration
  default, `isFavorite`'s pattern exactly) staged through `LoopEditSnapshot`; a toggle whose caption
  is guidance the app does not verify — *whole number of bars, no vocal*, aimed at the **musical**
  seam, since `PracticeAudioEngine` already crossfades the audio one. `ImproviseSheet` off the loop
  edit sheet: continuous playback, live percent (`setAuditionPercent`, no ramp), Journal note under a
  new `EntryKind.improvise`. Backing filter beside Favourites in the loops library — in-memory, not a
  `#Predicate`.
  The run follows `EarLoopRunView`'s shape: clock starts on appearance, an explicit **Done** is a
  genuine completion, no `RoutineBlockDoneView` (nothing to grade), logs a new
  `PracticeRunKind.improvise` with no tempo.
- **Slice 2 — the routine block.** `LoopRunMode.improvise` + `ImproviseLoopRunView`, mirroring ADR
  0104 Slice 2's `.ear` wiring. Access points decided (§B8/B8a): a fifth `bucketRow` in
  `AddRoutineUnitSheet`, and a per-row button in `LoopLibraryView` beside Ear but **only on flagged
  rows** — the Improvise count diverging from Ear's is the flag explaining itself.
- **Blocker on both access points (§B9):** `LoopLibraryView.visibleLoops` and
  `AddRoutineUnitSheet.trainableLoops` both gate on `commandTempo != nil`, and a backing track has
  none by design — so a flagged, unmeasured loop is invisible on the two screens the flag exists to
  populate. Gate becomes `commandTempo != nil || isBackingTrack`; the "no measured loops yet" copy
  has to admit the second route. The same tension already exists for ear-training blocks and stays
  unresolved (§B9a).
- **Slice 3 — the planner.** Closes a hole worth naming on its own: `improv.vocabulary` is
  `.repertoire` mode, `repertoireCandidates` returns `[]` without a target song, and the "Improvise in
  a style" goal template sets `requiresTargetSong: false` — so that goal's improv-specific skill
  produces **zero candidates today** and has since it shipped. It looks fine because its two scale
  skills still resolve. Backing loops become that skill's unit, planned as `play` blocks (unbudgeted,
  ADR 0014 R1). Needs `SessionBlock` to carry a `LoopRunMode`, which it doesn't today — the only
  non-mechanical piece.

**Loop dueness is inert — found while tracing §B6, not caused by it. Now ADR 0137 (below).** `Loop`
has no `lastPracticed` field, and `PracticePlanner.library` hard-codes `lastPracticed: nil` for every
loop, which `DueScore.dueness` reads as *max-due*. So `goalWeight × dueness × (1 − mastery/5)`
collapses to mastery alone for **every** loop candidate.

Rejected on the way (ADR 0135): synthesising a bed from a `ChordProgression` through the Hear engine
(re-loses ADR 0104 E5 — the point is real music, and the sampler tone isn't a bed); overloading
`LoopType.chords` or a free-text tag rather than a typed flag; retyping `improv.vocabulary` to
`.loopDrill` (wider blast radius than the hole). Parked: a scale/box overlay driven by `Song.key`,
bulk-flagging via ADR 0125's multi-select, and exposure surfacing on Progress.

## Practice you can do without your instrument (ADR 0139, Proposed — unbuilt)

Closes ADR 0138 §G6, both halves. Two facts that had never been introduced: the three `ear.*` skills
map to `ExerciseTemplate.earTraining`, which isn't in `creatable`, so they resolve to **zero
candidates** permanently — the mode shipped and the planner was never told. And `SkillMode.offGuitar`
sits on eight skills (`ear.*`, `know.*`, songwriting) with nothing branching on it. Between them is
*"I have fifteen minutes and no guitar"* — a real, frequent situation no practice app answers,
because they all assume the instrument is in your hands.

- **Slice 1 — ear becomes plannable, and the session type exists.** Off-guitar is a property of the
  **mode**, not the material (ADR 0138 §G1 again): `LoopRunMode.ear` is off-guitar, `.trainer` and
  `.improvise` aren't, and no flag lands on `Loop`. Audible loops serve the `ear.*` skills **by
  capability** — no tag — which makes three routes now deliberate: by tag (ADR 0074), by flag (0135),
  by capability (here). The session type is a `constraint` parameter on the existing entry points,
  defaulted to none; same weighting, dueness and packing, smaller pool. Sizing already works —
  `estimatedMinutes(for:mode:plannedMinutes:)` opens with `guard mode != .ear`, written mode-aware and
  never yet exercised.
- **Slice 2 — freeform blocks (ADR 0136) may declare themselves off-guitar.** Player-declared, never
  inferred (§F8 holds). This is what makes the session more than three ear blocks, and it's the
  general route for transcription / note-names / songwriting.

**Shares its one structural change with ADR 0135 §B6a:** `PlannerCandidate` and `SessionBlock` carry
no `LoopRunMode`, so an ear-resolved loop would build as a trainer block and hand the player a ramp
they can't run. Whichever ADR is built first owns it. Dedup must stay keyed on the unit, not
unit-plus-mode, or one loop appears twice in a session (once to train, once to sing back).

Decided too: user-facing name is **"Away from your instrument"**, never "off-guitar" — ADR 0116 made
this multi-instrument and a bassist shouldn't be offered a guitar-named session; the taxonomy case
keeps its name in code. Not fixed (§O7): `know.*` and `create.songwriting` have the same
zero-candidate hole, but unlike ear there's no shipped mode behind them — fixing that means a theory
surface (ADR 0094 T1, still deferred), and the honest interim is a freeform block the player writes.
Honest limitation: the session is only as good as the loop library, so it lands better for
established users than new ones, and the empty state has to say something useful.

## Each mode gates on what it needs (ADR 0138, Proposed — unbuilt)

Closes ADR 0135 §B9a and refines §B9. `LoopLibraryView.visibleLoops` and
`AddRoutineUnitSheet.trainableLoops` both test `commandTempo != nil`, and the add-sheet applies it to
**two** buckets — which is why Loops and Ear training show the same count. The rule is real for the
trainer (the command tempo anchors the ramp) and irrelevant to every other mode.

For ear training it's worse than irrelevant, it's inverted: `commandTempo` is *"the fastest tempo the
player owns this loop at"* — a measurement you can only make by playing the passage. Ear training is
the one mode that needs no instrument in hand, and it's the mode gated behind having already played
the thing. The one practice available when you can't practise is hidden until you have.

**Decided: the gate moves from the loop to the mode.** Trainer keeps `commandTempo != nil`; ear needs
only resolvable audio (the shape `playableSongs` already uses for the Songs bucket — that precedent
exists, loops just never got it); improvise needs `isBackingTrack`. The Ear bucket's count will exceed
the Loops count, and that's the message rather than a defect. `LoopLibraryView`'s default list stays
trainer-gated (admitting every scratch region would drown the practice library) and gains an all-loops
filter in ADR 0126's trailing menu, with per-row affordances gated per mode. Empty-state copy has to
admit all three routes.

Explicitly out of scope (§G5): no new destination, no Home card, no session type — ADR 0094 T1's
dedicated ear space stays deferred where ADR 0104 E1 left it. Named but **not** fixed (§G6), both
planner-side and neither a gate: the three `ear.*` skills map to `ExerciseTemplate.earTraining`, which
isn't in `creatable`, so they resolve to **zero candidates** permanently (mirror of the
`improv.vocabulary` hole); and `SkillMode.offGuitar` sits on eight skills with **nothing branching on
it** — the vocabulary for "practice without your instrument" exists with no consumer.

## Dueness comes from the log (ADR 0137, Proposed — unbuilt)

Closes ADR 0135 §B10. `DueScore` is `goalWeight × dueness(lastPracticed) × (1 − mastery/5)`, but
`Loop` has no `lastPracticed` and `PracticePlanner.library` hard-codes `nil`, which `dueness` reads as
*max-due*. Every loop candidate therefore ranks on mastery alone, forever — a loop practised this
morning sits level with one untouched for a year. Cosmetic until loops started resolving goals; ADR
0135 §B6 and ADR 0104's ear blocks both make it load-bearing.

**Decided: derive it from the practice log, don't store it.** A pure
`PracticeLog.lastPracticedByUnit([SessionRecord]) -> [UUID: Date]` (group by `unitUID`, max
`startedAt`) feeding a defaulted `lastPracticed:` parameter on `PracticePlanner.library`; the two call
sites (`PlannerView`, `RoutineLibraryView`) `@Query` the log and pass the map. `SessionRecord` already
carries both fields, and `PracticeLog` is already the pure SwiftData-free aggregation layer, so it
lands where the unit tests can reach it. No field, no migration, and **retroactive** — existing
`.loop`/`.earLoop` rows give real dueness on day one. Every future mode counts for free, since
everything goes through the one `PracticeLogWriter` seam.

Two things it changes rather than merely fixes. Derived means **completed**, not started — unlike
`Exercise.lastPracticed`, which `markPracticed()` stamps from `commitAndStart()`. A hand-stopped run
logs nothing, so it doesn't reset dueness, which is the intended reading (opening a drill and bailing
isn't practice). And **exercises are deliberately not switched over** (§D5): they work today, and
moving them started→completed is a live ranking change for existing installs that deserves its own
argument. Until then the two axes answer slightly different questions — documented, not invisible.

Watch item (§D7): a completion seam that fails to log now makes its unit read *max due*, so ADR 0117's
write path — still not store-verified end-to-end — is a ranking concern as well as a stats one. The
failure direction is fail-safe (surfaces more, not less), but silent.

## A block for the practice we don't model (ADR 0136, Proposed — unbuilt)

Pocket can't model every exercise a guitarist will ever do, and trying is a content treadmill. The
practice done *outside* the app is still practice, so the log and the mastery picture are both
quietly incomplete — and the more serious the player, the bigger the missing fraction. A freeform
block is the container for it.

Cheap because the progress spine is already content-agnostic: `PracticeRun` never asks what a unit
renders, `mastery` is pure player input, `Exercise.lastPracticed` + `markPracticed()` supply dueness.
And the payload field already exists — `Exercise.notes` (`String = ""`) is on the model and surfaced
**nowhere**: no editor, no reader, dead storage since it was added. So there is no migration.

- **Slice 1 — the template, its payload, its run.** A new `ExerciseTemplate.freeform` case — *not*
  ADR 0104's mode pattern (a mode needs existing material to re-run; a freeform block has none), and
  *not* `.basic` (which is click-first and doubles as the unknown-template fallback). `notes` becomes
  the instructions field with its own `BespokeEditor` branch. No tempo, no ramp. The run copies
  `EarLoopRunView` — clock on appearance, explicit Done as a genuine completion — **plus** the
  `RoutineBlockDoneView` ear blocks skip, because the rating is the whole tracking payoff. Logs
  `PracticeRunKind.exercise` with `tempoBPM: nil`; no new kind.
- **Slice 2 — routine and planner, mostly verification.** Goal-invisible falls out of the existing
  rule (`SkillFamilyMap.skillsByTemplate` omits a template ⇒ it never resolves a technique goal, as
  `.basic`/`.warmup` already do). Due-scored needs only that `.freeform` is **not** added to
  `PracticePlanner.library`'s `.filter { $0.template != .warmup }` exclusion. Both are silent-break
  claims, so they want unit tests.

The line the ADR rings off (§F1b): a **closed case with a free-text payload** is not a reopened
taxonomy. Free prose *inside* one curated case is not the old free-text `category` axis, and pressure
to let players name their own templates is a different ADR this one doesn't license. Also decided:
Pro (authoring, ADR 0112); user-facing name is "freeform", never "empty" — a block labelled empty
reads as broken, and it's about to hold the most personal practice the player has.

Watch items: `UnitDuplication` / presets / bulk import must carry `notes` now that it means
something (a duplicate that drops the instructions drops the exercise); and the library section can
grow unboundedly, since freeform blocks are cheap to make and invisible to goal resolution.

## Device-testing pass — plan of attack (2026-07-28)

Several days of on-device testing produced ~34 notes across four annotated screenshot sheets,
reviewed against the code and triaged 2026-07-28. **v1.0 is already approved and ready for
distribution — none of this chases that submission; all of it is 1.0.1 / v2 fast-follow.**
Sequenced cheapest-and-safest first so each slice is device-testable on its own.

**Decisions taken at triage — settled, don't re-litigate:**

- **Transport when loops are off** — the two sheets contradicted each other (−10/+10 seconds vs.
  jump-between-markers). **Resolved: seconds only.** Marker navigation is dropped; moving freely
  *within* the waveform matters more than one-tap restart, so rewind's single-tap "restart" is
  deliberately sacrificed.
- **"Advanced" means one thing** — a single Advanced disclosure holding **Rhythm** (the renamed
  quarters/eighths/triplets/sixteenths control, now a dropdown), Octaves, Sequence, Up-and-back and
  Start-from-lowest-root. Scale · Root · Layout · Position stay visible above the fold.
- **Enharmonics** — spell by key wherever a tonal centre exists (F major always reads B♭); the user's
  sharp/flat preference is a **tiebreaker only** where there is no key context (custom chords, the
  tuner, rootless drills). Not a global override.
- **"Start from the lowest root note"** — applies to **new runs only**, default on. There are no
  users yet, so no migration is owed, but the flag must not be read at render time or every saved
  run silently changes its note order.
- **Collection generated routines** — an **entry point to the generator** surfaced in Practice, not a
  second list of routines. Generated routines already save as ordinary routines; a parallel list
  would double them.
- **Fret range → 24, not 22.** The models already allow 24 (`ScaleLayout`, `FretboardRun`,
  `BassNeckLayout`); only the editors cap at 15. 24 also lets the octave double-inlay at fret 12 have
  its partner. Confirmed: **this does not create new scale/arpeggio shapes** — positions come from the
  shape catalogue and repeat at the 12th fret; a longer neck just reaches them higher up.

**Scrapped at triage (recorded so they don't come back):**

- **5-song import cap on free.** The slow-downer is the strongest acquisition hook, and there is
  currently no song axis in `AccessPolicy` at all — songs, loops and the slow-downer are entirely
  free. Adding a cap would have amended ADR 0112 to weaken the funnel. Dropped.
- **Two-line numbered dots on the picking board.** Loses to the 24-fret neck (they compete for the
  same pixels). Replaced by the slot-strip linkage in Slice 1.
- **Marker navigation on the transport** — see above.

**Slice 1 — fretboard authoring polish — DONE (branch `pocket-199-fretboard-authoring-polish`,
2026-07-28).** No ADR; all nine items landed. Notes worth carrying forward:

- **Start-from-lowest-root is a *trim*, not a rotation.** The run drops the box notes below the lowest
  root, so it still climbs strictly (the invariant the generator is built and property-tested on) and a
  one-octave run spans a true root-to-root octave. The alternative — rotating the sub-root notes to the
  end — would have kept every note on the board at the cost of a downward leap mid-run. **If the trim
  reads wrong on device, that rotation is the other option; the flag and its plumbing don't change.**
- **The flag is stored on the recipe with split defaults** — `true` from `init` (new runs), `false`
  from `decodeIfPresent` (saved runs) — so nothing already authored reorders itself.
- `ScaleRun.positionNotes` was split out for this: the position label and anchor fret describe the
  shape the **hand** covers, so the run's starting note can move without renaming the box.
- **"Enlarge the Movement/Advanced row labels" was really a *colour* difference** — the fonts were
  already identical (`.futura(.subheadline, .semibold)`); the hand-rolled disclosure titles just
  weren't setting `textPrimary`. Both now use `EditorFieldLabel` via the shared `EditorDisclosure`.
- The chevrons and the Futura position label land in **all four** fretboard editors, as flagged — the
  stepper is shared and the change was accepted everywhere rather than gated.
- `FretboardDrillEditor` was split (`+Board.swift`) to stay under the 400-line ceiling.
- **Renaming the control surfaced a model gap: Rhythm is editable after creation, and the command
  tempo it was earned at isn't recorded anywhere.** Not a Slice 1 regression — it predates the rename —
  but the Rhythm dropdown is now the most reachable way to trigger it. See *A command tempo is
  meaningless without its note rate* under **Near-term**.

**Slice 2 — small player fixes — DONE (branch `pocket-200-slice2-player-fixes`, 2026-07-29).** All
three items landed; no ADR. Notes worth carrying forward:

- **Train your ear pauses the waveform** via a new `onOpenEarTraining` callback on `LoopEditSheet` →
  `model.pauseForNestedAudio()` — the same double-audio guard `launchPendingPractice` already applies
  for "Practice now" (ADR 0082), since `EarTrainingPlayer` wraps its own `LoopRunModel` engine. Pause,
  not stop, is what makes the transport read **Play** on return.
- **The "Follow" toggle** (zoom anchors to the playhead vs. the pinch, ADR 0098) sits on
  `ModeDescriptionLine` between the ⓘ and Grid, reading/writing the *same* `AppStorage` key as the
  Settings toggle — no new setting, no plumbing, since `setZoom` already reads `AppSettings` at gesture
  time. The ⓘ popover gained a line explaining it.
- **Open on create** — a created exercise pushes `ExerciseRunView` from the create sheet's
  `onDismiss` (pushing *into* a dismissing sheet drops the push, hence the two-state stage-then-promote),
  and a **single clean** import pushes the song's waveform from both Home and Library. Both use
  Bool-bound `navigationDestination`, not `item:` — a just-inserted model's `persistentModelID` flips on
  the first autosave and pops an item-based destination (ADR 0090). The predicate lives on
  `SongImportSummary.isSingleCleanImport` (pure, unit-tested); auto-opening also consumes the
  "Imported 1 song." alert, since the screen *is* the confirmation.
- **Device pass found a pre-existing gap: a BPM with no 1 reads as a broken grid.** `commitTempo`
  won't guess the phase (ADR 0022), so a BPM-only commit leaves `beatGrid` empty — no gridlines *and*
  no Grid toggle, unexplained. The toggle's slot now shows **Set the 1** (`model.needsDownbeat` →
  `beginSetDownbeat()`). Related to, but smaller than, Slice 5's "keep a visible affordance while the
  tempo is unknown" — that one is about discovering *Set BPM* on a fresh import; this is about the
  half-set state after it.
- **Deliberately not included:** the metronome automator's "Save as exercise" seam still just saves. It
  fires mid-climb inside a full-screen cover with no stack to push onto, and yanking the user out of a
  running metronome session is the opposite of what that seam is for.
- `HomeView` was split (`HomeView+Actions.swift`) to stay under the 400-line ceiling.

**Slice 3 — list-component uniformity — DONE (branch `pocket-201-slice3-row-actions`, 2026-07-29).**
The `.pocketRowActions(...)` modifier landed as planned (long-press menu → swipes → undo toast),
adopted by exercises, routines, loops and songs, with duplicate folded in. No ADR. Notes worth
carrying forward:

- **Undo is a *deferred delete*, not delete-then-restore.** The waveform's ADR 0019 toast rebuilds a
  loop from a snapshot, which works because a loop is a handful of scalars with one owner. It does
  not generalise: restoring an `Exercise` or `Song` would have to rebuild routine-block links, song
  links, journal entries and takes that the real delete has already nullified or cascaded away. So
  `RowDeletionCoordinator` hides the row and defers `context.delete` until the window closes — on
  timer expiry, a second delete, `onDisappear`, or leaving the foreground. Nothing is ever lost by a
  missed commit; the worst case is a delete that didn't happen.
- **The consequence is that every list must filter its own pending rows** — the modifier can't do it.
  Each screen reads `isPending` itself and projects a `presentExercises` / `presentRoutines` /
  `presentSongs`, which then feeds the **empty state and the filter menus too**, not just the rows.
  Miss that and deleting your last item reads as "nothing matches your search".
- **The screen must therefore *own* the coordinator** (`@State`), passed into
  `.pocketRowUndoHost(_:)`. The first cut had the modifier own it and publish it via the environment,
  which fails silently: **a modifier applied inside a view's `body` publishes to that view's
  descendants only** — the screen's own `@Environment` resolves from its *parent*. The rows saw the
  real coordinator, the screen saw the default no-op seam, and every filter did nothing. The
  environment seam is still how the **rows** reach it; only the screen half needs the direct handle.
- **A destructive swipe button lies about deletion.** `Button(role: .destructive)` inside
  `.swipeActions` plays SwiftUI's own row-removal animation the moment it's tapped, whatever the data
  does. Under a *deferred* delete that made the row look deleted — which is why the broken filter
  above went unnoticed until Undo failed to bring it back (device pass, 2026-07-29). The swipe uses a
  plain `PocketColor.danger`-tinted button so the row's disappearance is driven **only** by the
  pending-row filter. The context-menu Delete keeps the role, where it just colours the label.
- Guarded by `RowUndoUITests` — delete a row, tap Undo, assert it's back **without navigating**. Both
  causes were wiring, not logic, so no unit test could have caught either.
- **That guard then raced its own subject and turned `main` red (2026-07-29, CI run 30441349304 — the
  post-merge build of PR #188, which touched nothing in this path).** The toast lives for
  `RowDeletionCoordinator.window` counted from the Delete tap, and the test spent up to five seconds
  waiting for the row to *vanish* before it went looking for Undo: `waitForExistence` passed, then
  `tap()` reported "No matches found". **The general lesson: when a UI test's subject is on a timer,
  every wait placed in front of it is spent out of that timer.** Fixed twice over — the wait order is
  inverted (grab the timed thing first), and `window` stretches under `-uiTesting`, because the
  four-second figure is a product decision this test was never asserting. It also mimics a regression
  perfectly: the first local sighting was a *different* step of the same test under a concurrent
  device build, which passed in isolation — see [[ui-test-isolation-confound-cold-sim]].
- **The seam is closures in the environment, not the coordinator object** (the `PaywallTrigger`
  pattern), so a row outside a `.pocketRowUndoHost()` — a preview, a test — deletes immediately
  instead of trapping on a missing `@Observable`.
- **Optional parameters are what make adoption honest.** `LoopLibraryView` passes no delete (a loop
  belongs to its song; the library is a read-through) and the song library passes no favourite
  (`Song` has no pin). Declining an affordance is the uniformity working, not a gap in it.
- **A fork drops `presetSlug`**, which is what stops duplicate becoming a paywall bypass: the copy is
  judged by its template alone, so a free player's fork of a Pro-template freebie is locked. Same
  reasoning for routines — a copy of the free demo is a user-authored routine, not a second freebie.
- **`ExerciseLibraryView` went over the type-length budget**; the split extracted `InstrumentFilterBar`
  as a real component rather than an `+Rows` extension. Extensions in a second file can't see the
  screen's `private` state, so a row-half split would have meant loosening five declarations to
  internal — the wrong trade for a length limit.

**Slices 3a & 3b — command tempo × note rate (inserted 2026-07-29).** The full write-up is *A command
tempo is meaningless without its note rate* under **Near-term**; this is only its placement in the
sequence, and the reasoning for it.

- **3a — display + derived notes-per-minute — DONE (branch `pocket-202-slice3a-command-tempo-note-rate`,
  2026-07-29).** No ADR, no migration, as planned. Notes worth carrying forward:
  - **The rate is `nil` when nothing declares one, and that's the whole discipline.** `NoteRate` is
    resolved content-first (`Exercise.noteRate`: the content's `notesPerBeat` → the metronome
    `subdivision` → `nil`), and every surface shows a rhythm **only** when it's non-`nil` — a label
    present means "stated", never "assumed quarters". *Chord Changes* (chords template, `.none`) shows
    no rhythm; *Spider Walk* (metronome-rendered warm-up whose `.sixteenths` click is its only stated
    rhythm) shows one. Comparison still counts an undeclared rate as 1, so nothing drops out of the sort.
  - **"Planner emphasis breaks too" was wrong** — the planner reads mastery and `lastPracticed`
    (`DueScore`), never a tempo, so there was nothing to route through npm. The library's Command key
    was the *only* cross-exercise read. Don't go looking for the planner half again.
  - **The journal was deliberately left alone.** `commandTempoAtEntry` is a snapshot with no rhythm
    stored beside it, so labelling an old entry with today's rhythm would state a fact we don't have.
    That gap is exactly what 3b's `commandNotesPerBeat` closes; until then an unlabelled historical
    BPM is the honest rendering.
  - `RoutineStairs`' BPM signpost was also left alone: every plateau on one staircase is one
    exercise at one rhythm, so nothing is being compared there — it was listed as breaking, but it
    isn't a cross-exercise surface.
  - **Four hand-built `"Command \(command) → \(reachTempo) BPM"` strings collapsed into
    `Exercise.commandProgressLabel`** (library row, `AddRoutineUnitSheet`, `RoutineItemRow`,
    `RoutinePlayerView`'s up-next). Adding the rhythm meant touching all four — the same
    write-it-once pressure Slice 3 applied to the actions, now applied to the row's *content*.
  - `FretboardSubdivisions` now delegates its table and labels to `NoteRate`, so the Rhythm dropdown,
    the rows and the detail sheet can't drift into three vocabularies. Its old "anything unknown reads
    Eighths" fallback is gone — an out-of-table rate describes itself ("6 per beat") rather than
    claiming to be one of the four.
  - The detail sheet's **Feel** section shows **Rhythm** *and* **Subdivision** as two rows on purpose.
    They are separate axes that can legitimately disagree today; collapsing them into one would hide
    the disagreement rather than resolve it (3b's job).
  - `ExerciseRunView` was at 396 lines, so the live readout's caption lives in
    `ExerciseRunView+Actions.swift` — the file-length ceiling decides where a two-line computed
    property goes.
- **3b — `commandNotesPerBeat` + unifying the two note-rate axes — DONE (ADR 0121, branch
  `pocket-203-slice3b-command-note-rate-binding`, 2026-07-29).** Built as one unit as planned, on the
  no-users window. Notes worth carrying forward:
  - **`Exercise.subdivision` was never wired to anything.** `setSubdivision` is called only from the
    standalone metronome screen, so an exercise's subdivision never reached the click — it stated a
    rhythm the drill didn't play, which is *why* the two axes could disagree with nothing noticing.
    That turned "unify the axes" from a merge into a **retirement**: the attribute stays in the
    schema (dropping one isn't additive), nothing writes it, and only the one-time backfill reads it.
    **The strumming exception is real** — the run arms `engine.setStrumPattern`, so those slots do
    sound; don't "tidy" that away.
  - **The user chose retirement over wiring the click up.** Making a sixteenth-note drill actually
    click sixteenths is 480 clicks/min at a command of 120, and would need its own on/off + volume
    control — a metronome feature, not this one. Recorded in the ADR as the rejected alternative.
  - **`nil` means "not stated", and that discipline is what makes every label honest.** The backfill
    deliberately leaves `.none` unstated rather than minting a defaulted "quarters" that every
    surface would then start claiming. Same reason the journal back-stamps nothing.
  - **No new authoring control, deliberately.** Rhythm stays editable exactly where it already was
    (the content editors' dropdown), which is also what keeps the change event to **one interception
    point** — `ExerciseShapeSheet.done()`. Giving Basic/Chords their own Rhythm control is a small
    follow-up if wanted; it would let a drill state a rhythm it renders nothing for.
  - **The Slice 10 collision never happened** — `ConfigureExerciseForm` / `NewExerciseSheet` were not
    touched, because creation states no rhythm and there is nothing to revalue before a command
    exists. Slice 10 is clean.
  - **`keepNoteSpeed` has to move the drill's own rate too, not just the binding** — otherwise a
    content-less drill ends up with a rescaled command bound to a rhythm its `noteRate` doesn't
    report. Caught by a test asserting notes-per-minute held, not by the build.
  - **Both answers rescale the working floor.** A warm-up floor left at the old rhythm is the wrong
    speed to warm up at even when you chose to re-measure the command.
  - `Exercise.swift` crossed 400 lines; the tempo model moved to `Exercise+Tempo.swift`.
  - **Follow-up the same day: the authoring default moved from eighths to quarters** (user call). The
    curated starters (`ScaleRun.aMinorPentatonic`, `ArpeggioRun.aMinorSeventh`, …) **follow** the
    default rather than being pinned — they *are* what a fresh drill opens on, so pinning them would
    have made the change cosmetic. Content that states its rhythm explicitly (`FretboardRun
    .chromaticWarmup`, `FretboardDrill.spiderWalk`, every `PracticePresets` `noteRate`) keeps it:
    **a default becomes quarters, authored content keeps what it declared.** Nothing failed when the
    default was flipped — the old value was asserted nowhere — so a test now pins it.
  - **Two device-pass fixes fell out of the quarters default** (2026-07-29): the slot strip's 12pt
    beat gap missed fitting two bars of quarters on one row **by a single cell**, and the placement
    cursor wrapped to slot 1 at the end of a run, silently overwriting the notes just tapped. The
    strip now draws **bar lines** between bars at a 4pt gap (beat groups stay the wrapping unit — a
    bar of sixteenths is 16 cells and would overflow as one unsplittable item), and filling the last
    slot **appends a bar** (`DrillPlacement`, pure + tested). Growth is the recoverable direction: a
    spare empty bar is visible and one stepper tap away, an overwritten note is gone. Placement and
    growth share one `mutate`, so undo takes back both.
- **No interaction with the rest.** Slices 2, 4, 5, 6, 8 and 9 are clean. In particular Slice 5's speed
  cap (0.25–1.5) is a *song playback multiplier*, not exercise BPM — a different axis, easily confused.
  (Shipped as ADR 0124, and it does reach loop-practice **percent** — still a playback multiplier, still
  not BPM.)

**The no-users window is deliberate, and it applies to every model change in this plan (2026-07-29).**
v1.0 is approved but **distribution is being held on purpose**, so the window closes when the user
decides to release, not on Apple's clock. Two consequences worth acting on:

- **No `@Model` change in the remaining slices owes a migration.** Additive-optional gymnastics, split
  decode defaults and nil-means-legacy states are all unnecessary while this holds — backfill and move
  on. This covers 3b and **Slice 10's "universally applicable" flag**, which is another new `Exercise`
  field riding the same window; batch the schema thinking across both rather than designing each in
  isolation. Contrast Slice 1's `startsFromLowestRoot`, which took the split-defaults route
  (`true` from `init`, `false` from `decodeIfPresent`) — under a held release that ceremony buys
  nothing and should not be copied by reflex.
- **This is the one thing to re-check before distributing.** Once v1.0 ships, every open model change in
  this plan reverts to the additive-optional shape described in the Near-term entry and gets materially
  more expensive. **Confirm the schema is where you want it before hitting release** — and record here
  the date it goes live, so the next reader knows the window shut.

**Slice 4 — chord content — DONE (branch `pocket-203-slice4-chord-content`, 2026-07-29).** All three
items landed, under **two** ADRs rather than the one amendment planned: 0122 for the chord vocabulary,
0123 for note spelling — the spelling half turned out to close off a real alternative (a global
sharp/flat override) and deserved its own record. Notes worth carrying forward:

- **The A-shape's muted high e was argued from two premises, and both were weak.** ADR 0084's reason
  was "barring under the high e is awkward, and it only doubles a tone already sounding". But the
  string sits on the **root fret** — the fret the index finger is already barring, no extra stretch —
  and it sounds the **5th**, the printed top note of every A-shape chart. `ChordVoicing.bMinorBarre`
  had to move with the grips: ADR 0084 M5 makes `aShapeMinor` reproduce it byte-for-byte, so fixing
  one without the other would have broken the invariant that equivalence exists to protect.
- **Deliberately narrow: A-shape sus2/sus4 keep their 4-string form.** Their standard barres would
  take the same treatment on the same argument, but they're Tier 2 (Build-only) and the device note
  named five shapes. `testAShapeSuspensionsAndPowerChordsStayNarrow` pins that, so widening them later
  is an edit to a named test rather than a silent drift. **If they read as inconsistent on device,
  they're the obvious next change.**
- **`insertMovableGrips` is now an *identity* with `ChordGrip.tier1`**, not a copied list — a future
  Tier-1 grip appears in Insert for free. The six-of-twelve curation read on device as a *gap*, not a
  curation: the shapes already existed, so wanting a movable m7 meant leaving Insert for Build.
- **Widening Insert collapsed the Build pane, so Build became an action (device call, same day).**
  Once Insert carried all of Tier 1, `MovableChordSheet` existed only for the ten Tier-2 shapes — which
  the chip grid reaches in **two** taps against the sheet's four. Tier 2 folded into Insert as a last,
  initially-collapsed *Sus, 6ths & 9ths* section; the sheet was **deleted** (161 lines), and the
  segmented **Build a chord** segment is now spring-loaded — its binding always reads `.insert` and its
  setter opens `CustomChordSheet`, so nothing stores a `Mode` and dismissing never lands on an empty
  pane. `testInsertNowOffersTheWholeCuratedMovableVocabulary` pins the lossless claim: Insert's two
  movable sets must together equal `ChordGrip.curated`.
- **The sus2/sus4 question is CLOSED (user, on device, 2026-07-29): they keep the muted high e.**
  Folding Tier 2 into the same grid put it under a microscope — same chip style, a couple of sections
  below the widened five — and it reads fine. Don't reopen it: a suspension's voice *is* its 2nd or
  4th, and the four-string form keeps that on top rather than under a doubled 5th.
  `testAShapeSuspensionsAndPowerChordsStayNarrow` holds the line.
- **"Enharmonic preference" was the smaller half of the spelling job.** The rule ("key first,
  preference as tiebreaker") needed a key-aware speller before the toggle meant anything. `NoteSpelling`
  reads the circle of fifths through the **parent major** each scale/arpeggio already declares
  (`relativeMajorSemitones`, reused from the CAGED boxes). Reading a root as its *own* major is the
  trap: C♯ minor's parent is E (a sharp key) but D♭ major is a flat one, so the root-only shortcut
  gets the whole minor family backwards.
- **`keySpelling` returns `nil`, not sharps, where the key doesn't decide** — C (no accidentals) and
  F♯/G♭ (six of each). That single distinction is what lets a key context and a *keyless* one share
  one fallback, and it's what makes the preference a genuine tiebreaker instead of an override.
- **The board learns its key through a transient `FretboardDrill.keySpelling`**, stamped by
  `expanded()` and excluded from `CodingKeys` — the same contract as `noteGroups`/`openMidi`, so no
  persisted-shape change and no migration. The alternative (resolve inside `FretboardGrid` from
  `drill.rootPitchClass` alone, as if it were a major key) needs no new field and is wrong for every
  minor-family drill.
- **Open tunings stay sharp and sit outside the preference.** Open D's third string is F♯, the raised
  third of D major, for everyone — spelling it G♭ on a preference would be plain wrong. That's the
  key-first rule, not an exception to it.
- Two collateral cleanups the spelling work forced: the app had **two glyph conventions** (`C#` on the
  board, `C♯` in the placer, `♭3` in degrees — now uniformly ♯/♭), and **two hand-rolled "friendly"
  root menus** duplicating an unexplained per-note mix in `ChordPickerSheet` and `MovableChordSheet`.
- `MusicalKey.displayName` now spells by key ("D♭ major" for the case stored as `"C#"`); the
  **`rawValue` is schema and stays sharp**, and `parse` already folded both glyphs, so a label still
  round-trips to its own case (pinned by a test over every case).
- `ChordPickerSheet` and `FretboardDrillEditor` each went one line over the 400 ceiling; both had
  their `#Preview` blocks split into `…Previews.swift`, matching `LibraryView`/`RoutineDetailView`.

**Slice 5 — transport redesign — DONE (branch `pocket-204-slice5-transport-redesign`, 2026-07-29).**
All three items landed under **ADR 0124**. Notes worth carrying forward:

- **The speed cap is now the *only* speed cap (user call at kickoff).** The item said "0.25–2.0 in
  `SpeedBar`", but `SpeedBar` was quoting a **literal** `0.25...2.0` while three other surfaces —
  the automator ramp clamp, the loop-run percent field and song play-along — derived theirs from
  `TempoMath`. So "the cap" was never one number. `TempoMath.maxSpeed` moved 2.0 → 1.5 and the slider
  now reads it, taking loop practice from 25–200% to **25–150%** with it. Deliberate: the slow-downer
  must not be able to outrun the ramp it drives. **If loop speed-training ever wants headroom back,
  that's a second bound and it needs its own argument.**
- **Out-of-range is *named*, not clamped** (`TempoMath.parse(speedEntry:)` returns `.outOfRange`
  rather than a clamped value). Silently substituting 1.5 for a typed 2 is indistinguishable from a
  field that ate the keystrokes. The read-side clamp asked for is separate and does exist —
  `TempoMath.clamped(speed:)` on `Loop.resumeSpeed`/`armingSpeed` and `Song.resumeSpeed`.
- **Tests that spelled `200` were the real risk of the cap change,** not the app code.
  `PromoteOfferTests` pinned a `ceiling: 200` literal that still *passed* while describing a ceiling
  that no longer exists; they now read `LoopRunView.percentRange.upperBound`. Worth a look wherever a
  bound is asserted as a number rather than as the constant.
- **A `Button` with `.onLongPressGesture` bolted on fires both on a hold.** The metronome now carries
  the tempo editor on its hold *and* a tap action, so it uses the loop row's proven idiom instead —
  `.contentShape(Rectangle())` + `.onTapGesture` + `.onLongPressGesture` on a plain shape. **Device
  check this one specifically:** a hold that also toggles the click is the failure mode.
- **The metronome has three states, and none of them is a dead button** — grid exists (tap toggles
  the click), tempo known but no 1 (greyed, tap opens the tempo editor), tempo unknown (accent +
  `plus` badge, tap opens it). The badge is the discoverability the retired "Set BPM" capsule was
  carrying; the greyed middle state is Slice 2's **Set the 1** prompt's problem to announce, and this
  is only the second door.
- **Repeat rides `engine.onReachedEnd`, not a full-song `loopRegion`.** The loop path pre-renders and
  crossfades its whole region into memory — fine for four bars, not for a five-minute song. Cost: one
  schedule gap at the wrap seam. Repeat is **session state** (wiped on exit with the other knobs, ADR
  0029) and **disabled while a loop is armed**, since an armed loop never reaches the file's end.
- **`SpeedBar` moved to `WaveformSpeedBar.swift`** — three more jobs took `WaveformSections.swift`
  past 400 lines. Same split as section 8's `WaveformTransportBar.swift`.
- **The skip increment lives in `@AppStorage` on `TransportBar` itself**, not on the model — it's a
  standing habit, not per-song state, the same reasoning as `transportLoopOnLeft` already there.

**Slice 6 — loops & markers multi-select — DONE (branch `pocket-205-slice6-loop-marker-multiselect`,
2026-07-29).** Landed under **ADR 0125**. The open question is settled and three decisions the note
didn't cover were taken at kickoff. Notes worth carrying forward:

- **Where collapse goes: nowhere.** The chevron's slot is reassigned **only while selecting**, so
  browse mode is byte-for-byte unchanged and the whole slice is additive. The alternatives (chevron
  moves leading; chevron dropped, header-tap collapses) both spend a permanently visible affordance
  on a control used rarely, and change the panel grammar for every user to serve the selecting one.
- **Bulk actions are delete · favourite · categories. Bulk *colour* was considered and rejected** —
  the identity colour is identity (ADR 0023 derives it from start-order), so it's the one bulk edit
  that makes rows *less* distinguishable, and it collides with the row-colour change below.
- **The identity colour is on the row all the time (user call), not just while selecting.** Green
  already meant "armed", so the rule is **hue = identity, saturation = state**: the glyph is muted
  (55%) unless armed. Consequence: the **leading bar stays green** as the sole armed marker — tint it
  to the loop's hue as well and nothing says which loop is live. **Verified on device in both
  appearances (2026-07-29)** — 55% reads clearly in light too, and the armed loop is unambiguous.
- **The way *in* is the header hold, not a row hold** — a row's hold already opens the edit sheet
  (ADR 0028), which is how people rename a loop. So the mode opens with nothing selected, and
  select-all is the row circle one level up, in the header (its filled/empty state says which way a
  tap goes, so there's no "Select All"/"Deselect All" text button). Only one panel selects at a time.
- **Bulk delete forced the ADR 0019 undo to change shape, and that's the most consequential part of
  the slice.** The toast rebuilt a deleted loop from a snapshot of its scalars — which silently lost
  its cascade-owned journal (ADR 0038) and takes (ADR 0069) and its nullified routine links (ADR
  0066). Bulk would have multiplied that by the selection size. Deletes here are now **deferred**
  (hide the row, `context.delete` on window close), the same trade Slice 3 took for the practice
  libraries. Slice 3's "every list must filter its own pending rows" applies with one simplification:
  this screen has **one** reader, `WaveformPracticeModel.loops`/`.markers`, so the filter there
  clears the list, the lanes and the minimap at once.
- **The partial editor needed a three-state field.** `focus` is already `Int?` where `nil` means
  "never triaged" (ADR 0039) — a real value — so "leave unchanged" is a *third* state, hence
  `LoopBulkEdit.FieldEdit`. Tags add and remove, never replace; removal only offers tags **every**
  selected loop has, so Remove can't look like it did nothing.
- **Two device findings, both fixed on the branch (2026-07-29):**
  - **The selection bar is pinned above the scroll view**, not inside the panel header. In the header
    it scrolled away, so selecting a row far down the list meant scrolling back up to reach Delete.
    The selecting panel therefore shows no header of its own — the pinned bar names the list.
  - **A `Button` fires its action on the release of a long press too**, so holding an *already open*
    panel entered selection mode **and collapsed it**. This is Slice 5's metronome trap again, and
    `.simultaneousGesture` did **not** avoid it — the fix is not to use a `Button` at all: a plain
    shape with separate `.onTapGesture` / `.onLongPressGesture`, the loop row's idiom. **Treat "a
    `Button` that also needs a hold" as a smell anywhere in this codebase.**
- **Also added on request:** a **Favourite** toggle on the loop edit sheet. Bulk could star a
  selection while the single loop you had open couldn't be starred at all; `LoopEditSnapshot` carries
  `isFavorite` so save-undo covers it.
- `WaveformPanels.swift` split — `WaveformPanels+Markers.swift` — to stay under the 400-line ceiling.

**Slice 7 — routine building — DONE, device-verified (branch `pocket-206-slice7-routine-building`,
2026-07-29).**
Landed under **ADR 0127**. All three items in, plus two kickoff decisions the note didn't cover.
Notes worth carrying forward:

- **"Multi-select" became "the picker doesn't close".** A tap adds the unit immediately and leaves
  the sheet open (checked row · running tally · second tap un-adds); **Done** closes. The two
  alternatives were weighed and rejected: **hold-to-select** (the ADR 0125 grammar) hides the whole
  feature behind a gesture nobody will find in a *transient* sheet — 0125's hold works because a
  panel header is a fixture you return to daily — and **checkboxes committed by "Add 3"** puts a
  confirm step in front of an action that is already provisional (every edit here is sandboxed and
  reversible by Cancel, ADR 0071; it would be the only place in the app you confirm a change twice).
  The accepted cost: a **single** add now needs a Done tap where it used to dismiss itself.
- **Every grouped level gained an "All …" row** (device feedback, 2026-07-29). Grouping assumes you
  remember which template/song a unit landed under, and you often don't. It sits in its own section
  *above* the groups — not a ninth group, the way *past* them — so the groups stay the default path;
  hidden at one group; and the flat exercise rows carry the **template** as context, since the
  section header no longer does. Songs was already flat.
- **The picker holds no state.** The editor keeps `pickID → RoutineItem.uid` for the open session and
  hands the id set back each render, so a checkmark is drawn *because a block exists*. The toggle is
  **session-scoped** — it removes only the block this sheet created, never one added earlier, so a
  routine can still hold the same drill twice (warm-up pass + focused pass is a real shape).
- **The rest guard is one rule and it is authoring-only:** a rest may not sit next to a rest
  (`RoutineBudget.allowsRest(at:in:)`, unit-tested). Head and tail rests stay legal — the append path
  has always produced the trailing one. Nothing in the model changed, so no migration is owed and an
  existing routine holding adjacent rests still loads and runs; we refuse to *create* the shape, not
  to display one.
- **A refused gap still takes the tap** and answers with an anchored popover. Inert and silent would
  leave the user tapping a row that does nothing with no reason given.
- **Rest-insert mode borrows the whole list:** drag and swipe are suspended (`editMode` goes inactive
  *without* leaving edit mode) and block rows go inert in both directions, since every tap on that
  screen is a placement. Leaving edit mode via Save/Cancel leaves rest mode with it — otherwise its
  only exit is an affordance the add section has just hidden.
- **A rest is spliced into the *displayed* order before the insert, not read back after it.** A new
  item sharing an `order` with the block it displaces gets ordered against it by the `uid` tiebreak
  in `RoutineItem.ordered` — a coin flip over which side of the tapped block it lands on.
- **The `Button`-plus-hold trap, third time.** *Insert rest* is a plain shape with separate
  `.onTapGesture`/`.onLongPressGesture`; as a `Button` the hold would enter the mode **and** append a
  stray rest on release (ADRs 0124, 0125). It carries a visible **"Hold to place"** hint — a gesture
  with no affordance is a feature nobody uses.
- Splits to stay under the 400-line cap: `RoutineDetailView+Units.swift` / `+Rests.swift`, and
  `AddRoutineUnitLists.swift` off the picker. `editContext` / `insert` / `nextOrder` went internal —
  a cross-file extension on a `View` can't see `private` members.

**Slice 8 — analytics & privacy — DONE (branch `pocket-207-slice8-analytics`, 2026-07-29).**
ADR 0120 written and accepted; Aptabase Cloud (EU), opt-in and off by default. Notes worth carrying
forward:

- **The legal driver is ePrivacy Art 5(3) / PECR, not GDPR.** Aptabase's irreversible anonymisation
  genuinely does take the data outside GDPR — but Art 5(3) governs *accessing information on a
  device* regardless of whether it's personal, analytics never qualifies as "strictly necessary",
  and the ICO says so. Hence opt-in. The exemption *does* cover the app's existing UserDefaults
  preferences and the consent flag itself. There are no cookies in a native app.
- **"Off-the-grid mode" was dropped, deliberately** — see ADR 0120 §7. It was conceived while the
  plan was still opt-out, where a master switch would have been needed; opt-in makes off-the-grid
  the default state, and with no other network calls in the app the "mode" would govern exactly one
  flag while implying far more. The withdrawal **toggle** stays (Settings ▸ Privacy). Don't rebuild
  it as a mode.
- **The ask sits after a first practice, not in the intake** — putting it in the activation flow
  would tax the metric it exists to measure. The cost, accepted: the intake and the first session
  are permanently unmeasurable, recovered only as the `since_install` bucket on later runs.
- **Aptabase cannot do cross-session user metrics** (no identifier ⇒ no retention curve, no
  funnel/path tooling — the dashboard is counts with breakdowns). Every question must therefore be a
  **ratio between two event counts**. ASC App Analytics + StoreKit own retention and revenue.
- **Its queue is in-memory only** — events are lost if the app is killed while offline, so offline
  sessions are under-counted. Real bias for an app built to work with no network.
- **No kill switch** (no backend), which is why the vocabulary is 13 events and why every event
  whose host can re-appear carries a fire-once latch.
- **Aptabase EU app created and `APTABASE_APP_KEY` set** (2026-07-29), so the pipeline is live for
  anyone who opts in. Debug builds flush every 2s and land in the dashboard's separate debug bucket,
  which is the quickest way to watch the pipeline end-to-end without touching release numbers.
- **Still outstanding:** answer the ASC App Privacy nutrition label (Product Interaction → Analytics
  → not linked, not tracking); paste the revised Red Moon section into `decooperations.co.uk/privacy`;
  and **Tier 2** (AdAttributionKit / Apple Search Ads) plus the **marketing-site cookie policy**,
  both separate slices with no code overlap here.

**Slices 9 and 10 — PARKED (user, 2026-07-30). This closes the device-testing plan at eight shipped
slices.** Both are self-contained tails: nothing in Slices 1–8 depends on either, and neither depends
on the other. Their full entries moved to the standing sections that own the subject matter, so
they're found by someone working on that area rather than by re-reading a finished plan:

- **Slice 9 — artist name generator + onboarding copy** → *Onboarding — "the art of creating loops" +
  musician voice*.
- **Slice 10 — song links on creation sheets + the "universally applicable" flag** → the **ADR 0111
  exercise↔song** entry under *Near-term*, as a fourth sub-bullet beside Model / Authoring UI /
  Generator. It **split in two on 2026-07-30**: the creation-sheet link **shipped** (branch
  `pocket-208-song-links-on-create`), and the **flag stays parked**, unanswered — the groundwork
  recorded there explains why it's a bigger decision than "small follow-up" suggested.

**One consequence of parking Slice 10: the no-users schema window (above) no longer has an open
model change riding it.** The batch-the-schema-thinking-across-3b-and-10 advice is spent — 3b shipped,
10 is parked. If Slice 10 is picked up *after* distribution, its flag pays the full additive-optional
cost, and that cost should be weighed against the flag's value at that point rather than assumed.

**Found during the Slice 3 device pass (2026-07-29) — DONE 2026-07-29 (ADR 0126):**

- **The inline nav title sat off-centre in the practice libraries — FIXED.** Confirmed at triage: not
  one screen's bug. Exercises carried two `.topBarLeading` items (a sort menu rendering as a
  variable-width `↑ Recently Added` pill, plus the favourites star) against a lone trailing `+`;
  Routines had the same shape with a wand in place of the sort; Loops carried the same pill on the
  trailing side. Fixed by the second of the two options recorded here — **collapse sort + favourites
  into one icon-only menu** (`LibraryOptionsMenu`), and put it **trailing**, leaving the back button
  alone on the leading side. Moving the pill to trailing was rejected: it rebalances the groups but
  the width still varies, so the title would still drift, just the other way. On Routines the wand
  moved into the menu as a labelled row. See ADR 0126 for the grammar and the costs (the active sort
  key is no longer legible from the bar; favourites is one tap deeper).

**Fixed on the Slice 1 branch (was: needs a device repro):**

- **Dots grey out when a sequence is picked — FIXED 2026-07-28.** The device repro (A minor pentatonic,
  Box, Straight vs Groups of 4) found it: not pass focus, and not *greying* either — **alpha stacking**.
  `SequencePattern.byGroup` emits each note up to four times, and `FretboardGrid.notes()` drew one
  translucent dot per *played slot*, so a position the rolling window hit four times reached ~0.79
  opacity (near-white) while one it hit twice stayed at 0.32 (grey). The bright dots were the anomaly,
  not the dim ones. Fixed by plotting distinct **positions** via the pure `FretboardDrill.plottedPositions`;
  slide cues were stacking identically and are deduped with it.

**Parked pending a clearer product story:**

- **Image attachments on exercises** (reference photos). Parked until we can articulate what the user
  gains. When picked up, the open design questions are: how the user uploads (photo picker? camera?
  files?) and how they view them mid-practice — plus `@Attribute(.externalStorage)`, downscale on
  import, a per-exercise cap, and an alt-text field for VoiceOver. Read
  `docs/swiftdata-gotchas.md` first: binary blobs on a `@Model` are exactly the class of thing that
  behaves in the simulator and bites on device.

**Branding — SVG logo swap — DONE 2026-07-29.**

`RedMoonLogo`, `RedMoonMark` and `RedMoonWordmark` are now SVG with
`preserves-vector-representation`, from the **v5** Pixelmator set. The light/dark appearance pair
stayed, as flagged (the mark is two-tone, so it can't be one template asset tinted in code), and the
**App Icon stayed PNG** — but it was re-cut from the same v5 art (the dark-background mark, no
wordmark) rather than left on the old textured raster. ADR 0061's icon decision is unchanged: same
crescent + stars, same near-black, no text. Notes worth carrying forward:

- **The three assets are generated, not hand-cropped** — `scripts/derive-brand-svgs.py` keeps the
  chosen `<path>` layers from the one supplied lockup and rewrites the viewBox to their exact
  bounding box (true cubic-bezier extrema). A new logo revision is one command, not three crops per
  appearance. The generated files carry a do-not-hand-edit banner.
- **The App Icon is generated too** (`--app-icon`): the mark composited on opaque `#0F0F0F` and
  rasterised through **QuickLook** (`qlmanage`), so there's no librsvg/ImageMagick to install. Both
  the background hex and the 66.8%-of-canvas mark height were **measured off the icon it replaced**,
  so the swap is like-for-like on the home screen. QuickLook hands back RGBA, so the script asserts
  every pixel is opaque and then re-encodes without the alpha channel — a partly-transparent icon is
  an App Store rejection, and the renderer is the one part of the pipeline we don't control.
- **The blood-moon variant is deliberately not in the catalog** — the Blood Moon theme has no
  consumer yet, so it would be a dead asset. `--variants blood` produces it when Slice 2 / ADR 0081
  lands; that's the whole cost.
- **The simplified v5 art changes the aspect ratios**, which the sizing had baked in: the mark went
  from wider-than-tall (raster) to roughly 2:3 (vector), so `ArtistNamePromptSheet` had to cap its
  **height** rather than its width or the crescent would have grown ~80% taller. The lockup likewise
  went from 0.87 to 1.14 — Settings' `maxWidth: 160` now yields a shorter block. Check every consumer
  when the art changes shape, not just that it still renders.

**Colour tokens: no work needed.** The palette already sits on the logo — `TealCTA` light is
`18698B` against the logo's `17698A`, and `Terracotta` light is `C24A2C`, an *exact* match for the
blood-moon outer colour. Decision: **logos stay their own thing**; the per-space accent families
(Teal / Terracotta / Plum / Gold / Indigo) are what tell you which space you're in and must not be
flattened to brand blue. Optional insurance: add `BrandBlue` / `BrandBlueLight` colorsets used only by
logo-adjacent chrome, so retuning a space accent later can't desync the mark. The blood-moon pair
(`C24A2C` / `E3694A`) is the natural accent for the parked *Blood Moon theme* section below.

## StoreKit purchase path — sandbox validation (ADR 0112, parked 2026-07-28)

**Full checklist: [`docs/plans/storekit-sandbox-validation.md`](plans/storekit-sandbox-validation.md).**
To be folded into a larger work item rather than run as its own branch.

ADR 0112 merged (PR #178, `47fbd83`) with the paywall, the gates and the entitlement layer all built
— but **the purchase itself has never run**, in any environment. Every test used the local
`.storekit` config or the DEBUG `isPro` toggle; neither contacts Apple. The untested chain is
Apple confirms → `Transaction.currentEntitlements` → `isPro` → gates open.

Blocking facts to carry in cold:

- ASC subscriptions are still **drafts**; sandbox won't vend them until "Ready to Submit"
  (Apple's *approval* isn't needed — completed metadata is).
- Two switches fail **silently** and make fake results look real: the run scheme's local StoreKit
  config (`project.yml`), and the DEBUG override — which *replaces* the real entitlement rather than
  influencing it.
- **Trial lapse re-locking is the likeliest breakage** — least-travelled path, never exercised, and it
  has to re-lock all five routine surfaces as well as the exercise gates.
- **Don't ship a paywall build before the ASC products are live**, or `isPro` is permanently false and
  everything Pro-locks with no way to buy.
- Same submission, separate task: the ASC **Content Rights** answer must change from "no third-party
  content" now that *Binta* ships bundled.

## Collection session builder — follow-ups (ADR 0118, parked 2026-07-25)

The `CollectionSessionBuilder` + `CollectionSessionSheet` shipped (branch
`pocket-197-collection-session`, device-verified). Two enhancements raised on device
review, deferred to a later session:

- ~~**Show estimated times on the Length tabs.**~~ **DONE (2026-07-25, branch
  `pocket-198-collection-session-length-caps`).** The Quick / Focused / Full tabs now read
  "Quick · ~10m" etc. — the **truer** estimate (focus + rests + capped play-throughs), not the raw
  focused budget. New pure `CollectionSessionBuilder.estimatedMinutes(for:in:length:)` sums the
  generated blocks' minutes, pinned to the deterministic `.structured` arrangement (the worst case
  for rests) so the figure is a **stable upper bound regardless of the Order dial**. Rendered in
  `CollectionSessionSheet.lengthLabel` with `.monospacedDigit()`, plus a Length-section footer.
  **Paired with a real cap on the whole session (same session):** the generator now budgets the
  *entire* sitting — focus + rests + play-throughs — against a per-preset ceiling
  (`totalCap`: Quick 10 · Focused 30 · Full 60 min), so a Quick session genuinely stays ≤10 min
  rather than the ~22 the focus-only budget produced. Play-throughs are budgeted first, bounded to
  half the cap (`playMinutesCap`) so focus keeps the majority, then `budgetFilled` fills the
  remainder charging a rest before each subsequent focus block so focus **and its rests** fit — the
  cap holds for every order mode (structured is the worst case). Unit-tested
  (`CollectionSessionBuilderTests`: whole-session-within-cap across all length×order, estimate
  within-cap + grows-with-length, sums-the-blocks). Distinct from `SessionLength.minutes`, which the
  V2 planner still reads as its *focused* budget (ADR 0014 R1) — left unchanged.

- ~~**A selectable pool view below the Order tab (Instagram-style ordered multi-select).**~~
  **SCRAPPED (2026-07-25)** in favour of a simpler "template producer" model: the generated
  session is now **editable before Save** — on the review screen a provisional generated
  session (`!existsInStore`) offers "Add exercise, loop or song" (library-wide, so it adds
  drills from **outside** the collection) + "Insert rest", alongside the existing swipe-delete
  and inline rename. So the builder generates a *starting template* the player customises,
  rather than pre-curating a selection. Done this session (`RoutineDetailView.canAddBlocks`);
  applies to **every** generated-session flow that shares the review screen — the collection
  session, the ADR-0111 per-song routine, and the V2 planner's "Generate today's session". A **tally** (exercises ·
  loops · songs) + a "richer collection → fuller session" note now sit on the Build a session
  page (`CollectionSessionSheet`, `CollectionSessionBuilder.pool`). *Not done:* drag-reorder on
  a provisional session still needs Save→Edit (swipe-delete + add work provisionally); enable
  `.onMove` in the provisional state if that gap bites.

## User-testing pass — plan of attack (2026-07-20)

A round of on-device user testing produced ~13 notes (embedded in annotated
screenshots), reviewed and triaged 2026-07-20. **v1 is mid-flight in App Store
review — none of this chases the current submission; treat all as fast-follow /
v2.** Sequenced by impact-per-effort into waves. Details for items that already
have a home live in their own sections (cross-referenced); this is the index.

**Wave 0 — contained cleanups (no ADR, decisions already made):**

- ~~**Note 9 — song card row 3.**~~ **DONE (pocket-159, 2026-07-20).** `SongCard.metadata`
  now emits only `N loops · M markers`; key + BPM dropped from the card (still in the
  song details sheet). Artist row + collection chips unchanged.
- ~~**Note 10 — chord-template de-crowd.**~~ **DONE (pocket-159, 2026-07-20).** Removed the
  `ChordIdentityCaption` ("Looks like …") from each `changeRow` in `ChordProgressionEditor`
  — the row now shows name + length only. The reverse-lookup reading still surfaces while
  *building* a shape (custom-chord board + `MovableChordSheet`), so no capability was lost.
- ~~**Note 3 — default Red Moon artwork.**~~ **DONE (pocket-159, 2026-07-20).** `NowPlayingController`
  now attaches a default `DefaultArtwork` asset (the dark crescent, a copy of the app icon) to the
  now-playing info, so every song shows the Red Moon mark on the lock screen / Control Center instead
  of a blank tile. Pure `NowPlayingState` stays UIKit-free.
- ~~**Note 6 — back-off step toggle + editable tempo.**~~ **DONE for exercises (pocket-159,
  2026-07-20).** A **Back off** switch (`Exercise.includeBackoff`, default on) in Practice Settings,
  and when on an editable **Back-off** floor (`Exercise.backoffTempoOverride: Int?`, additive optional
  mirroring ADR 0075's reach pin; `CommandRamp.backoffOverride`; reset-to-auto) with the back-up step
  row gated off when disabled. Ramp math unit-tested (4 new `CommandRampTests`). **Loop parity DONE
  (pocket-159, 2026-07-20):** the loop path now mirrors it — new `Loop.includeBackoff` (default on) +
  `Loop.backoffSpeedOverride: Double?` (× of original), threaded through `LoopCommandRamp.make`
  (× → % conversion) and surfaced in `LoopSettingsPanel`; loop ramp tests added. **Merged** in
  PR #154 (commit `161a203`, "back-off toggle + editable tempo for loops — note 6 parity") — the
  earlier "loop fields want a device launch before merge" gate is resolved.

**Wave 1 — core loop feel (small ADRs, highest quality lift):**

- ~~**Note 5 — zoom anchor.**~~ **DONE — MERGED (pocket-160, ADR 0098, PR #155).** Pinch-zoom now
  anchors to the **gesture focal point** (`MagnifyGesture.startAnchor`)
  via the pure `WaveformGesture.zoomAnchored` (unit-tested), so the spot under your fingers holds
  still instead of jumping to the playhead. New default-off **Zoom follows playhead** setting
  (Settings → Transport) restores the legacy playhead-anchored paging. Page-mode during playback
  (ADR 0010) untouched. Relates to the parked *rotary haptic zoom mode*.
- ~~**Note 4 — snap free-control near neighbours.**~~ **DONE — MERGED (pocket-161, ADR 0099,
  PR #156).** Both halves shipped: **(1)** a neighbouring loop's edge gets a gap-scaled reduced
  catch radius (`WaveformGesture.yieldedTolerance` = `max(0, min(base, gap/2))`, per-candidate
  tolerance via `loopEdgeSnapCandidates`), so a facing neighbour in a tight gap stops hijacking
  the release while roomy edits still line up (markers/beats keep full radius); and **(2)** the
  **free-control escape** — a ~400 ms long-press mid-drag (`snapSuspended`, `freeDragHoldDuration`)
  suspends snap for the rest of that gesture, confirmed with a medium haptic. Reuses
  `WaveformPracticeModel+Snap` geometry. Deferred follow-ups (ADR 0099 "out of scope"): a visible
  "snap off" indicator; neighbour-yield for a brand-new span's drag; live-drag (not release-only)
  snap.

**Wave 2 — new surfaces (ADR each, design-first):**

- **Note 8 — journal entries tab. DONE (pocket-162, ADR 0100).** A read-only, cross-cutting
  **Journal space** — the 4th Home card (warm-gold) — merging journal notes **and** takes across
  loops + exercises on one day-grouped timeline (pure `JournalTimeline`), All/Notes/Takes filter,
  gold owner captions; takes play in place, authoring stays on the owner. Scope grew from the
  original "entries only" to entries + takes in design. **Folded in the same PR:** the post-run
  completion screen (`RoutineBlockDoneView`) now tags its note with the 🎯/⚡️/🧗/📝/🎬 kinds
  (was a plain note), threaded through all three run hosts — feeds richer, filterable entries into
  the space. See *Journal authoring* / *Notes & journal*.
- ~~**Note 12 — chord picker redesign.**~~ **DONE (pocket-165, ADR 0103).** Search-first
  `ChordPickerSheet`, Insert/Build split, diagram grid, movable barre shapes browsable in Insert
  (tap → root menu). Replaced the flat insert `Menu`; `SavedChordsSheet` removed (management → Toolkit).
- **Note 7 — ear training as "loops, re-surfaced." DONE (pocket-166, ADR 0104).** **Slice 1:** a
  **Train your ear** mode on a loop's edit sheet — ears-only continuous playback of the loop's
  own audio (loop + song shown up top; hum/sing framing; a live −/+ **tempo control** to slow it
  down), with "what you hear" notes saved to the loop's Journal tagged 👂 `.ear`. Self-judged, no
  score (ADR 0094 T2b/T3); reuses the Journal write path (ADR 0100/0058) and loop audio (ADR 0001),
  not the Hear synth (ADR 0097) — the point is to hear the *real* music. **Slice 2:** ear training
  as a **routine block** — a loop `RoutineItem` carries a `LoopRunMode` (`.trainer`/`.ear`), an
  `.ear` block resolves to `RoutineStageKind.earLoop` → `EarLoopRunView` (shared core + routine
  chrome + manual Done, no completion screen), authored from a peer **Ear training** bucket in
  `AddRoutineUnitSheet` (the loop-settings entry stays too). Folded in: the "Coming Soon" **Ear
  Training/Theory** rows removed from the New Exercise picker (ear training is a loop mode, not an
  exercise template). Follow-ups parked: waveform-on-reveal, a dedicated Home Ear destination
  (ADR 0094 T1, deferred).

**Wave 3 — strategy tracks (decide before building — user flagged these need more
thought 2026-07-20):**

- **Note 11 — bandmate sharing (not a forum).** The real need is **sharing prepared
  material with specific people** (bandmates), à la the user's Google-Sheets set-list
  workflow — *not* discovery/community. Start with the **zero-backend** path: export
  an exercise / set-list as a shareable bundle (AirDrop/Messages/Files), import on the
  other end — aligns exactly with **ADR 0064** (exercises shareable, audio never).
  **Profiles + a forum are explicitly out of scope** for the first cut (that's a
  different, moderation-heavy product); layer identity (SIWA)/discovery only later if
  the need proves real. Own ADR. See *Social layer boundaries (ADR 0064)*.
- **Note 1 — local-file → library friction + Bandcamp/legal.** Two tracks: (a) reduce
  *import* friction (clearer drag-in / file-picker / recently-added) — safe within
  **ADR 0001** (local-first); (b) any Bandcamp/mp3-provider "collaboration" is a
  **business-development / API-licensing** conversation, not a design change. Keep the
  app **bring-your-own-DRM-free-file** and agnostic; do **not** reintroduce
  streaming-as-source (the ADR 0001 wall). Legal note (non-authoritative): importing a
  user's *own purchased* DRM-free file for private practice is analogous to importing
  into Apple Music; risk lives in fetching-on-their-behalf or *sharing* audio (already
  closed by ADR 0064). Needs real thought before acting.
- **Note 2 — pricing: lifetime + "own it after 2 years."** A **lifetime / one-time
  tier alongside a subscription** is clean and recommended. The **subscribe-2-years →
  own-it** mechanic is parked: no native StoreKit primitive for it, "own it" is
  ambiguous (perpetual license to which version?), and rev-rec gets messy. Fold into
  *Monetization* — decide once the feature set is settled (user's standing call).
- **Note 13 — onboarding: tutorials / walkthroughs / FAQs.** Good pre-growth, not
  pre-submission. Cheapest high-value start: (1) first-run coach-marks on the 3–4 core
  flows (create a loop, run an exercise, save a chord); (2) an in-app **FAQ/help**
  screen backed by static markdown (updatable without a release); (3) empty-state
  hints (already used). **Not** a heavy tutorial engine. Own ADR; connects to the
  *Onboarding — "the art of creating loops"* vision + musician-voice principle.

## Release sequencing (decided 2026-06-24)

The order below reflects a deliberate scoping call, not just priority:

- **V1 (first release):** practice screen + library + a richer **creation
  experience** + **notes/journal**. **No planner.**
- **Planner → V2, SHIPPED (2026-07-10).** Routine generation and goal-driven selection
  (ADRs 0014 / 0015 / 0016) shipped across Slices 1–4 plus the review-refinements pass, player
  polish, and the reps follow-up (ADR 0076). The planner is functionally complete and live. What
  remains is the deferred tail — **AI decomposition** (gated on the AI phase) and the
  **learned-target reach default** — neither scheduled. See **Practice planner** under "V2 vision".
- **AI layer → late phase.** Every AI feature (note summaries, suggested
  automator settings, etc.) is built only once the rest of the app is solid
  and the foundations are in place: the Claude proxy backend (ADR 0002, still
  paper-only) and a settled pricing/cadence model. Cleanly separable from the
  user-editable foundations below — build those first, gate AI behind them.

## V2 vision (logged 2026-07-05)

The V2 direction was set in a scoping session; the thinking lives in dedicated
docs so this stays a pointer list:

- **Practice planner — ADRs 0014 / 0015 / 0016 (Accepted; IN PROGRESS).** The
  goal-driven session generator: two pure functions — `deriveCandidates` (front-half,
  0015) → `buildSession` (back-half, 0014) — that produce a `Routine` (ADR 0066) run by
  the shipped player. Fully designed 2026-07-08; **cold-start build plan:
  `docs/plans/planner-build-plan.md`**. Decisions locked: self-rated `Exercise.mastery`
  / `lastPracticed` feeding a `dueScore` (no grading — ADR 0070); broad
  `ExerciseTemplate → [SkillID]` skill resolution (no new per-exercise tagging); two
  candidate paths (technique → exercise, repertoire → loop/song via `Goal.targetSong`);
  soft prereq staging (reconciles ADR 0016 with 0071); in-house goal templates; loop
  skill-tagging as a phase-2 slice; **AI suggester deferred** — the planner ships fully
  local-first, no backend. The substrate (routine model + player + presets, PR #102)
  has shipped.
  - **Slice 1 — back-half + mastery parity: DONE (branch `pocket-112-practice-planner`,
    ADR 0072).** `Exercise` gained self-rated `mastery` + `lastPracticed`; pure
    `DueScore` + `SessionBuilder.buildSession` + warm-up LRU (Foundation-only,
    unit-tested); impure `PracticePlanner` projects/materialises a `Routine`; "Quick
    session" ✨ button in the Routines library is the first surface (dueness-only).
  - **Slice 2 — front-half: goals + candidate derivation: DONE (branch
    `pocket-112-practice-planner`, ADR 0073).** `TechniqueTaxonomy` + `SkillFamilyMap`
    (pure tables), `Goal` `@Model`, pure `CandidateDeriver.deriveCandidates` (Path A
    technique→exercise via the family map, Path B repertoire→target-song loops+run,
    soft direct-prereq down-weight), `GoalTemplateLibrary` (4 curated templates), and
    `PracticePlanner.planGoalSession`/library projector + loop/song materialisation
    (songs keyed by a deterministic `PlannerID`). Front-half composes with the back-half
    end-to-end; unit-tested (ADR 0015 property list). No UI yet.
  - **Slice 3 — planner UI: DONE (branch `pocket-112-practice-planner`, ADR 0015/0073).**
    `PlannerView` (the live "Build today's session" entry in Practice): duration selector
    (`SessionLength`), goals list, **Generate** → provisional `Routine` review → shipped
    player, with a no-goals Quick-session fallback. `GoalEditorView`: template picker →
    name → priority (`GoalPriority` Low/Normal/High ↔ `weight`, pure + unit-tested) →
    skill-trim → optional target song → met toggle / delete. `RoutineDetailView`'s
    provisional init broadened to resolve loop/song blocks.
  - **Slice 4 — loop skill-tags: DONE (branch `pocket-112-practice-planner`, ADR 0074).**
    A `Loop.tag` matching a coarse `ExerciseTemplate` bucket (recognised by
    `SkillFamilyMap.recognizedTemplate(for:)`, offered as ✨ suggestions in the loop tag
    editor) lets a technique goal's Path A surface that loop alongside exercises;
    projected onto `PlannerLoop.templates`. Opt-in — untagged loops stay Path-B only;
    reuses ADR 0034 tags (no schema change); pure + unit-tested.
  - **Slices 1–4 complete the V2 planner (all shipped).** Plus the full review-refinements pass
    (R0–R5), player polish (P1–P3), and the reps authoring follow-up (ADR 0076, PR #117). The
    planner is functionally complete and live.
  - **Deferred (user, 2026-07-10), not now:** **Slice 5 (AI decomposition)** — still OUT OF SCOPE,
    gated on the AI phase; and the **learned-target reach default** fast-follow (its own future ADR;
    ADR 0075's manual pins are its data substrate).

- **Exercise content templates — ADR 0065 (Accepted).** A per-exercise "what to
  play" layer (`Exercise.kind` + a versioned `Codable` `templatePayload`, renderer
  switched in `ExerciseRunView`) *over* today's metronome/ramp engine — strumming
  arrow-lane, animated fretboard, chord/progression stepper — mapped from the
  taxonomy's `Default mode` column. Build order strumming → fretboard (shared with
  tab→fretboard Phase R + preset guides) → chords; vibrato/bends/palm-muting
  deliberately get no template. **COMPLETE & merged (PRs #95–#101):** strumming
  (incl. accents/mutes); fretboard renderer + runs + polish; scales & arpeggios on
  a shared CAGED box engine; **chords** (progression drill on a shared
  `ChordVoicing`, absorbed triads); **Strum & Chords** composition; exercise-audio
  seam; global animate toggle. `ExerciseKind`/`ExerciseTemplate` carry all six
  kinds. No template work outstanding.
- **CAGED + triads as a category — RESOLVED (folded into Chords, shipped).** Was
  floated as its own fretboard category, then parked in favour of folding triads into
  the **Chords** template — which has now shipped (PR #97) on a shared `ChordVoicing`.
  A triad is a 3-note chord voicing and the CAGED box engine generates arbitrary note
  sets, so the shape/inversion lives with chords as planned. No separate category.
- **Movable chord shapes + custom-chord placer — ADR 0084 (Accepted, 2026-07-12).**
  From a notes session 2026-07-11 (a movable-barre-shape chart + a "custom chord"
  ask). Written up as ADR 0084 (branch pocket-133, with 0083). Rules M1–M8: generate grips
  don't store a table (M1); a `ChordGrip` = relative geometry + root string + quality,
  placed by root note → auto-named `ChordVoicing` (M2); tiered ceiling (M3, below); custom
  placer is the Tier-3 escape hatch (M4); one output type so the renderer is untouched + the
  two library barres retrofit into grips byte-identically (M5); slide-to-fret must TEACH —
  shared cue with **ADR 0083 S8** (M6); pure + property-tested via `ChordVoicing`'s accessors
  (M7). **3 slices:** (1) `ChordGrip` + transposition + Tier-1 grips + barre retrofit (pure,
  no UI); (2) movable-shape authoring + the shared slide cue + Tier-2 grips; (3) custom placer.
  Two parts over the shipped fretboard renderer (`FretboardContent`, pocket-102) and
  the shared `ChordVoicing`:
  1. **Curated movable shapes.** Add variety to the chord exercise as *movable grips* —
     a relative shape (E-root / A-root grip) + a fret offset (transposition), taught as
     "pick a shape, slide it to the right fret." The note data itself is fully derivable
     (chromatic fret→note on the E/A strings, standard barre grips) — **do not store a
     voicing table**; emit grips programmatically and transpose. **Tier the ceiling**, the
     real product decision (not a knowledge gap — all tiers are generatable):
     - *Tier 1* — triads + 7ths (maj/min/dom7/min7/maj7 × E-root & A-root; the chart's 10).
     - *Tier 2* — + sus2/sus4, 6ths, basic 9ths (guitar-idiomatic voicings; e.g. sus2 is
       voiced A-root, not on the awkward E-shape).
     - *Tier 3* — shells (root-3-7), extensions (9/11/13), altered (7♯9/7♭9/7♯5/7alt).
     Default the curated exercise to **Tier 1–2**; let the placer (below) cover Tier 3 so
     there's no giant voicing table to maintain.
  2. **Custom-chord fretboard placer** — a per-string picker (fretted note / open / muted)
     that composes an arbitrary voicing the curated set can't express. The escape hatch for
     Tier 3 and anything bespoke; persists as a `ChordVoicing`. This is where advanced/jazz
     voicing choices live, since they multiply and get instrument-specific.
  Open design question (now ADR 0084 M6 ⇄ 0083 S8): **how to present** the movable-shape idea
  (slide-to-fret) so it teaches, not just displays — the SAME slide-teaching cue as the
  position-shifting runs; whichever ships first solves it for both. Natural fretboard slice
  after scales.
- **Position-shifting runs + extended pentatonics — ADR 0083 (Accepted, 2026-07-12).** From a
  design session 2026-07-12 (flexible picking runs + two player-supplied extended-pentatonic
  diagrams). One insight: a neck-climbing picking run, a diagonal warm-up, and a diagonal
  extended pentatonic are **the same primitive** — a run whose anchor fret *shifts
  mid-sequence*, with a slide at each same-string seam. Build the shift once, it produces all
  three. Additive over the shipped `FretboardRun` / `ScaleRun` (ADR 0065), timing engine
  untouched. **Three slices:** (1) player-authored shift controls on `FretboardRun`
  (`fretShiftPerPass`/`passCount` horizontal climb + `fretShiftPerString` diagonal) + the
  slide-seam **teaching** cue — cheapest, no scale theory, de-risks the "teach the slide"
  question shared with movable chords (S8); (2) **following viewport** — the board tracks the
  hand for climbing runs (the one non-free piece: today's window is static, `displayLowestFret`
  /`displayFretSpan`); (3) `ScaleRun` **`layout` axis** generating `.extended` (the two reference
  diagrams) **and** a plain `.threePerString` (3-NPS folded IN — same generator/viewport/test-net
  substrate) over that substrate, ADR 0065 property test as the correctness net. Slides reuse the
  existing `FretTechnique.slide` (its first producer). Slice 1 also carries a **come-back
  fingering** choice (S9): `returnStyle` = `.retrace` (today's strict palindrome, 4-3-2-1 down —
  default, keeps the seeded warm-up byte-identical) vs `.restate` (keep 1-2-3-4 per string,
  strings walked back high→low) — small and independent, could ship even ahead of the shift work.
  Resolved at accept: a "pass" = one full `sequence()` at the anchor (up-and-back included); shifts
  clamp to a real neck + editor caps `passCount` (S10); `.extended`/`.threePerString` read
  `position` as start anchor and ignore `octaves`; the run editor tucks the shift controls under a
  "Movement" disclosure. ~~**Sequencing (3s/4s/6s) is a SEPARATE orthogonal future axis over ALL
  layouts — deliberately NOT a 3-NPS feature, its own later ADR.**~~ **DONE (pocket-173, ADR 0108):**
  the `SequencePattern` axis on `ScaleRun` (straight/thirds/fourths/groups-of-3-4) — a pure permutation
  of the played run, orthogonal to every layout, applied in `sequenceWithGroups` so the box stays
  untouched. **Order: slice 1 first** (see ADR). Shares the slide-teaching UX with the movable-chord
  item above.
- ~~**Symmetric scales: diminished + whole-tone (deferred from ADR 0085).**~~ **ADDRESSED via the custom
  scale canvas (pocket-172, ADR 0107), not a generator.** Rather than build the "own placement generator"
  a filtered CAGED box can't provide, symmetric scales (and any sequenced/exotic/hand-shaped run) are now
  **drawn** on the Scales exercise's **Draw your own** canvas, with a **scale guide** that ghosts a chosen
  scale + key's notes to trace — the three symmetric scales ship as pure `ScaleReference` formulas
  (whole-tone + both diminished modes), never touching the CAGED engine or its tests. **Still deferred (if
  ever warranted):** *first-class generated* symmetric scales in `GuitarScale` (a repeating-cell
  generator) — the canvas removes the urgency, so it stays unbuilt rather than speculative. A **scale
  identifier** (name what you drew, the `ChordNamer` analog) is the other ADR-0107 follow-up.
- **Practice routine model — ADR 0066 (Accepted).** The multi-unit *session*
  container (distinct from the intra-exercise ramp staircase): `Routine` +
  `RoutineItem` (typed relationship to Exercise/Loop/Song or a rest block, explicit
  `order`), a player orchestrating the existing per-unit engines, pure budget/rest
  logic. Container + manual authoring + player first; the planner (ADRs
  0014/0015/0016) becomes just another producer of a `Routine`, deferred to its own
  ADR. Unblocks ADR 0014's open output type. **In progress:** branch
  `pocket-107-routine-model` (slice 1 = model + pure ordering/budget helpers + tests).
  **Cold-start build plan: `docs/plans/routines-build-plan.md`** (pick-up-cold; all
  slices, conventions, gotchas). Two decisions locked 2026-07-07: (i) routines live in
  the **Practice space** next to Exercises (Home cards later); (ii) the player
  **auto-advances** — aim is *controlled discomfort, not clean reps* (command tempo is
  a "just outside comfort" reference; pushing past it, where it won't be clean, is the
  point). This diverges from ADR 0016's clean-before-fast at the *session* level →
  capture as its own ADR when the player (slice 3) is built.
  - **Exercises-first direction (decided 2026-07-07).** Lean into exercises as
    first-class routine units, incl. **exercise-only routines** — the model already
    allows it (R4 makes Exercise/Loop/Song equal citizens; zero model change). The
    reasoning, to build with:
    - Exercises and loops are different practice *modes* — **technique** (audio-free,
      click/template-driven, portable) vs **repertoire** (a loop bound to one
      recording). Exercises are exactly the skill-building axis the planner's
      front-half already assumes (ADR 0015: goals → **skills** → exercises).
    - **Exercise routines are the shareable ones** (ADR 0064 §2: exercise is the
      shareable unit, loop never) — the teacher-persona win lives here.
    - **Cold-start unlock:** exercise routines work day one with an *empty library*
      (no imported song/loops needed) — the onboarding wedge loops can't provide.
    - **Presets = content:** now the ADR 0065 template axis is complete, an exercise
      carries *what to play*. Ship a `RoutinePresets` seeder mirroring
      `PracticePresets` (curated in-house ordered exercise sequences — "10-Min
      Warm-Up", "Alt-Picking Builder", "Chord-Change Bootcamp"; same one-time-flag,
      deletion-sticks pattern; encode the method, author all copy in-house).
    - **Build-order consequence (all SHIPPED now):** exercise + loop routines shipped
      first, then **Song items too** — a song block runs the audio-only `SongPlayAlongView`
      (own `SongPlayAlongModel` / `PracticeAudioEngine`; fixed play-along speed, no waveform
      handoff needed after all), authored via `AddRoutineUnitSheet`'s flat **Songs** bucket
      (`onPickSong`) and played by `RoutineSessionPlayer`. The model stayed **freeform** (any
      mix) — no rigid "routine type" enum; exercise-heavy routines curated via presets, not
      schema. No new model ADR needed — lives inside 0066 R4;
      `RoutinePresets` is its own slice after the player works.
  - **`RoutinePresets` — SHIPPED (2026-07-08), folded into the routines PR #102.** Three
    curated in-house starter routines (Morning Warm-up, Picking Builder, Rhythm & Changes)
    seeded once on first launch. The earlier "parked — reintroduces a run-screen freeze" read
    was a **misdiagnosis, twice over**: after a machine reboot the flake reproduced at a
    *different* assertion than claimed — the 5 s wait for a seeded **exercise** cell, never the
    20 s run-screen freeze guard (which fired 0/12 runs). Isolated to seeding latency: `HomeView`
    ran `PracticePresets` then `RoutinePresets` seeding back-to-back on the main actor before
    first paint, so the routine seeder's fetch+insert+save delayed the exercise library
    rendering past the test's tight 5 s window. Fixed by yielding between the two seeders (order
    preserved for by-name resolution) + widening the test timeout 5 s→20 s. Now 5/5 green,
    matching the no-presets control. Lesson: check *which* assertion a UI test fails before
    trusting a stored freeze diagnosis.
- **Social layer boundaries — ADR 0064 (Accepted).** Local-first forever;
  exercises (never loops/audio) are the shareable unit; derived-stats-only
  leaderboards; Sign in with Apple; CloudKit personal sync vs AWS social rails
  kept separate; loop compensation explicitly closed until a rights framework
  reopens it. Backend sizing + data-classification strategy:
  `docs/research/v2-backend-and-data-strategy.md` (S0 recap slice is buildable
  now, with no backend).
- **Song splitting / stems:** `docs/research/feasibility-song-splitting-and-stems.md`
  — loop-region audio export is a cheap V2 win; on-device stem separation is a
  gated spike (server-side rejected on privacy/rights); pitch-shift is nearly
  free when wanted.
- **Practice-take recording — ADR 0069 (Proposed).** Mic-only "audio journal":
  record your playing, relisten, review; sits beside notes/journal. Feasibility in
  `docs/research/feasibility-practice-recording.md`. Deliberately mic-only (no
  mix-in of app playback — that bakes copyrighted audio into a user file, the ADR
  0001/0064 wall). Isolation over a loop is **free on headphones** (coupling is
  acoustic, not digital) and **messaged, not fought, on speakers** via output-route
  detection — no AEC/DSP. Costs: a specific `NSMicrophoneUsageDescription` +
  privacy-manifest review, a `.playAndRecord` session config kept separate from the
  shared `.playback` plumbing, and a new app-owned `Recording` model (AAC files in
  the container). Buildable now; small-to-medium.
- **Tab → fretboard animation:** `docs/research/feasibility-tab-to-fretboard.md`
  — build the animated-fretboard *renderer* over an internal notation model
  first (it powers preset guides and shares its clock/substrate with the
  strumming-pattern animation), ASCII-tab import second, Guitar Pro/MusicXML
  later (licensing-gated), OCR never-planned.
- **Tab → song metadata (FUTURE, gated on the AI/parse phase).** From the notes session
  2026-07-11, flagged "for the future" by the user. Translate imported song tablature into
  structured **song metadata** — key, chord progression, time signature, and played
  **techniques** (slides, vibrato, bends) — so the app can drive fretboard/chord surfaces
  and planner skill-tagging from real song content instead of manual entry. Sits on top of
  the tab-import substrate above (shares the notation model); the technique/key/progression
  inference is the AI-phase piece (ADR 0002 proxy, still paper-only). Not scheduled; a big
  parse+inference feature deliberately deferred behind the tab-import renderer and the AI
  foundations.
- ~~**Strumming-pattern animation + preset expansion (near-term, buildable now):**~~
  **Animation SHIPPED (ADR 0065): `StrummingLaneView` + `StrumPatternPreviewPlayer` render an
  animated D/DU lane driven by `StrumPattern.activeSlotIndex(atBeat:)`, wired to the metronome via
  `clickIntensities`.** **Preset expansion DONE (pocket-170, 2026-07-23):** three more curated
  `StrumPattern` grooves — **Down-Up Eighths**, **Reggae Offbeat** (the up-stroke "skank"), **Boom-Chick**
  (down + muted chuck) — added and seeded as a v10 `PracticePresets` batch. The broader
  *exercise-inventory* preset expansion (warm-ups/spider, hammer-on/pull-off/slide ladders, scale +
  arpeggio runs, open/barre/triad progression changes) is largely covered by the shipped ADR 0065
  template batches (fretboard/scales/arpeggios/chords/strum); remaining curation is incremental. Per the
  content strategy: encode the *methods*, all copy and exercises authored in-house.
- **Backing tracks:** **narrowed by ADR 0135, not resolved.** The first build takes the free route —
  the player's own song sections, flagged as backing tracks and jammed over in place (see "A loop can
  be a backing track", above). *First-party recorded* beds remain the answer for a player whose own
  library has no suitable section (a beginner with three loops, all licks), and remain a
  content-production decision before a code one — outsource vs self-record (start tiny: 3–5
  first-party tracks, common keys / I–IV–V / 12-bar, recorded as owned work product). Technically
  trivial: bundled or downloadable DRM-free files ride the existing engine unchanged; needs only a
  "first-party content" bucket distinct from user imports.
- **Desktop bulk metadata/artwork editing:** door held open by ADR 0064 §7
  (keep metadata logic pure/portable); otherwise deliberately unplanned.

## Launch readiness (pre-submission gate)

From a full pre-launch audit (2026-06-25). The code itself audited clean —
SwiftLint `--strict` 0 violations, build 0 warnings, 313 tests green, no
force-unwraps / `as!` / `fatalError` / debt markers, accurate privacy manifest,
minimal justified permissions. The gating work is **submission assets/config**,
not code. Re-run the audit any time with the `/ready-to-ship` skill.

**Hard blocker — RESOLVED (ADR 0061, 2026-07-02):**

- ~~**App icon + asset catalog.**~~ **DONE.** `Pocket/Resources/Assets.xcassets`
  now exists with an `AppIcon` set — a single 1024×1024 universal iOS icon
  (`icon-1024.png`, no alpha, the crescent + Southern-Cross mark), wired via
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`. The catalog also
  holds the `RedMoonLogo`/`RedMoonWordmark` in-app marks and the semantic colour
  sets. The stale audit note (2026-06-25, "no `.xcassets` anywhere") predates the
  icon integration. No open code blocker remains for submission.

**Should-fix before submission (no code dependency):**

- ~~**`ITSAppUsesNonExemptEncryption = false`** in `Info.plist`~~ — **DONE**
  (branch `pocket-073`): added, skips the export-compliance prompt on every upload.
- ~~**Bump `MARKETING_VERSION` 0.0.1 → 1.0.0**~~ — **DONE** (branch `pocket-073`):
  bumped in `project.yml` for a public release.
- ~~**Delete `Features/Planner/HomeView.swift`**~~ — **N/A (already gone).** Stale audit
  note: there is no `Features/Planner/` directory, and the app entry now renders the real
  `HomeView()` home hub (ADR 0044), not `LibraryView()`. Nothing to delete.

**Robustness (optional):**

- ~~**Audio-session errors are swallowed**~~ — **DONE** (branch `pocket-097`, pre-V2
  audit): session/engine-start plumbing deduplicated into `AudioPlumbing`, which logs
  failures via `os.Logger`; bookmark-resolution / file-read failures now surface a
  "Couldn't load this song's audio" notice on both practice surfaces (and disable the
  loop run's Start), and a resolved-but-stale bookmark is re-minted and persisted on
  the spot. Remaining (deliberately not built): a user-visible state for a failed
  *audio session* itself — rare, and needs a design pass to avoid a scare banner.

**Standing dev guide — keep new features launch-ready as you build:**

- **Privacy manifest is a living file.** Any new required-reason API
  (file timestamps, system boot time / `mach_absolute_time`, disk space) or any
  off-device data send (e.g. the AI phase's Claude proxy) must add the matching
  `NSPrivacyAccessedAPITypes` / `NSPrivacyCollectedDataTypes` entry in
  `PrivacyInfo.xcprivacy` *in the same PR*. Today's manifest declares
  UserDefaults (CA92.1) and System Boot Time (35F9.1 — the metronome's
  `CACurrentMediaTime()` session/tick timing, added pocket-089); don't let it
  drift further.
- **Permissions stay minimal & specific.** Add an `Info.plist` usage string only
  when a shipping feature exercises it (the parked pedal modeller's mic string is
  correctly absent). Vague strings cause rejection.
- **No live host in Release until the proxy exists.** The Release `POCKET_API_HOST`
  is a placeholder and nothing calls it (zero `URLSession` in V1). Before any
  networked feature ships, replace it and guard against the placeholder leaking
  into a release build.
- **The audit gate is the bar.** A feature isn't "done" if it adds a force-unwrap,
  a silent `try?` over real user data, a TODO marker, or a new entitlement/permission
  without justification. Run `/ready-to-ship` before calling V1 shippable.

## Branding & naming — "Red Moon" (workshopping, 2026-06-25)

Candidate rename of the product from "Pocket" to **Red Moon**, after *Red Moon*
by Tom Misch — the track that turned the idea into a working prototype, and the
song the build keeps getting tested against. The origin story is the moat; the
name carries it.

- **Brand = "Red Moon"** (spoken/marketing). Resist baking a descriptor into the
  brand itself; let an App Store **subtitle** do the functional work (e.g. "Loop,
  slow down, and learn any song"). Keeps the name ownable as the product grows
  past any one feature (it's practice + library + creation + notes, not just loops).
- **Logo:** simple red-moon disc. Colour **#C73818** (burnt vermilion) — not a
  compromise on "red", it's the *actual* colour of a blood/harvest moon, so lean
  into it. Keep one ownable detail that survives at icon size (soft blood-moon
  glow, or a faint crescent shadow so it reads as a moon, not a dot). Feeds the
  hard-blocker **App icon** item above.
- **Name-clearance findings (web search 2026-06-25):** the iOS music/practice
  lane is clear — no "Red Moon" practice/looper app exists. Flags, none fatal:
  1. **"Red Moon Fitness" already on the App Store** — different category (no TM
     issue), but Apple requires unique app *names*, so the bare string "Red Moon"
     may be partly encumbered; expect to need a qualifier to register.
  2. **"Red Moon Label" is an active record label** (+ a RedMoon DJ on
     SoundCloud) — music-services overlap (TM Class 41); not a software blocker,
     but "red moon music" SEO won't be ownable. Glance at this if filing a TM.
  3. **"Red Moon" (Android blue-light filter)** — dormant, Android-only,
     unrelated function; only muddies Google results.
  4. **The song itself** dominates search — a discoverability headwind, not legal;
     arguably on-brand.
- **Next action (do early — resolves flag #1 definitively):** log into App Store
  Connect and try to **reserve "Red Moon"** as the app name. If taken, that
  decides the qualifier (e.g. "Red Moon: Practice"). Reservation is free and
  immediate.

## Blood Moon theme — Slice 2 (parked 2026-07-11)

The default brand re-theme shipped in **ADR 0081 / Slice 1** (Practice = brand
teal, Metronome = plum, Song library = terracotta `#C24A2C`; mastery tracks the
teal hero). We're **sitting with the default theme for a while** before building the
second, selectable theme. When picked back up:

- **Blood Moon** = a selectable theme that swaps **Practice ↔ Library** so Practice
  (the dominant feature + the "Start today's session" CTA) goes **terracotta** and
  the library goes teal — making terracotta the main colour of the home. Metronome
  stays plum. Mastery tracks the hero (→ terracotta), never plum.
- It's a **role → hue mapping in code**, not a second baked palette — the three hues
  keep their single light+dark asset pairs (the terracotta sets already exist). Add a
  theme abstraction + a **Settings picker** beside Appearance (orthogonal to
  light/dark).
- **Also re-tint the wordmark + Settings logo terracotta** in Blood Moon. Open
  question: the textured **moon logo** is raster art — flat-tinting flattens the
  crater detail, so it needs a terracotta art variant (the wordmark tints cleanly as
  a template). Decide art-vs-tint when we start.
- See ADR 0081 for the full mapping and consequences.

## Multi-instrument support — bass first (logged 2026-07-24, action after tuner)

Extend the fretboard-family features (scales, chords, arpeggios, custom drills) to other
stringed instruments — **bass first** (nearly free), ukulele later and reduced-scope. Do **not**
start until the guitar tuner (ADR 0115, branch pocket-193) is complete; that work already lays the
data foundation (`Instrument` enum + `Tuning` value in `Core/Theory/InstrumentTuning.swift`).

- **Integration model = Option C: instrument as a per-exercise axis with a profile default.**
  Instrument is a property fixed at creation (sibling to the immutable `ExerciseTemplate` axis),
  defaulted from the ADR 0113 profile ("what do you play"), overridable per exercise. **Not** a
  global "mode" and **not** a launch-time path pick — both fight the Library (wrong-instrument
  rendering) and the multi-instrumentalist. Surfaces: profile intake sets default → segmented
  Guitar/Bass on the create/configure step (guitar-only templates like CAGED scale boxes
  hide/disable off-guitar) → Library instrument filter that appears only once >1 instrument's
  content exists (progressive disclosure) → renderer needs no new UI (`FretboardGrid` already draws
  N strings) → tuner/chord-library already per-instrument.

- **String-order mismatch — decided approach: adapt at the boundary, don't unify.** The engine is
  canonically **highest-first** (`FretNote` "0 = high e … 5 = low E", `CAGEDShape.openMidi =
  [64,59,55,50,45,40]`, `ScaleLayout`, `ChordGrip.RootString` enum, renderer row-stacking) and it's
  **persisted** in every stored drill's `FretNote.string` — do not flip it. The tuner's `Tuning` is
  lowest-first (ADR 0115) and isolated. Cross the two in exactly one place — a pure reversal:
  ```swift
  extension Tuning { var engineOpenMidi: [Int] { Array(midiNotes.reversed()) } }  // index 0 = highest
  ```
  Rules: (1) raw `tuning.midiNotes` never reaches engine code — only `engineOpenMidi`; (2) golden
  test `Instrument.guitar.standardTuning.engineOpenMidi == [64,59,55,50,45,40]` proves guitar renders
  byte-for-byte identical post-refactor; (3) de-hardcode string count at the same boundary (replace
  `ChordVoicing.stringCount = 6` / `openMidi.count` assumptions with the tuning length). Reversal is
  valid only for **monotonic** tunings — reentrant ukulele (gCEA) is not a simple reversal, which is
  the same non-monotonicity that breaks CAGED box generation → **uke deferred**, and when it lands
  it's chords + custom drills only, no generated scale boxes.

- **Scope ladder:** guitar (today) → **bass** (interval math identical, mostly the tuning-as-value +
  string-count de-hardcode) → ukulele (chords/drills only, own follow-up). Write an ADR when actioned
  (canonical convention + boundary adapter + de-hardcoding plan close off the "unify the conventions"
  alternative). Bass presets grow a small set over time; existing presets tagged guitar.

## Near-term (active, not parked)

These are scheduled to be picked up shortly — listed here so they're not lost.

- **A command tempo is meaningless without its note rate (logged 2026-07-29).** 80 BPM means four
  different things at quarters / eighths / triplets / sixteenths, and nothing in the model records
  which one a command tempo was earned at. Two independent note-rate axes exist today and **nothing
  syncs them**: `Exercise.subdivision` (the *click* — `Subdivision`, set only at creation, read-only on
  `ExerciseDetailSheet`; both interactive creation paths take the `.none` default and only
  `PracticePresets` passes a real value) and the content's own `notesPerBeat` (`ScaleRun`,
  `ArpeggioRun`, `FretboardDrill`), which **is** editable after creation via the Advanced → **Rhythm**
  dropdown. So a hand-authored sixteenth-note scale run carries `subdivision == .none` alongside
  `notesPerBeat == 4`, and moving Rhythm eighths → sixteenths quadruples the demand while the stored
  command tempo sits at 80 — a *measured* achievement (ADR 0045, not an aspiration) silently revalued
  with no event marking it.
  - **What it does and doesn't break.** The ramp math is **fine and needs no change**: working, reach
    and back-off all derive from command proportionally (`TempoStretch`), so they are note-rate-invariant.
    What breaks is **comparison and edit safety** — the library's command-tempo sort
    (`PracticeLibrarySort`) and the journal's `commandTempoAtEntry` snapshots. (Corrected while
    building 3a: **planner emphasis and the `RoutineStairs` BPM labels are not affected** — the
    planner ranks on mastery + `lastPracticed`, never a tempo, and a staircase is one exercise at one
    rhythm, so neither compares across rhythms.) The seeded presets show the scale of it: *Spider Walk* (80 @
    sixteenths = 320 notes/min) and *Chord Changes* (70 @ none = 70) sort as near-neighbours — a 4.5×
    difference reading as 14%.
  - **Scope decision — notes-per-minute is a *comparison aid*, never a difficulty score.**
    `npm = BPM × notesPerBeat` normalises **one** variable so two exercises can be ranked honestly. It
    is not a measure of how hard something is: triplets at 80 and sixteenths at 60 are both 240 npm and
    are not equally demanding for a picking hand, and a strumming pattern's difficulty has nothing to do
    with its click density. **Do not grow this into a derived difficulty index, a "level", or a
    cross-exercise ranking presented as ability** — that is grading the player, which ADR 0070 rules
    out. It describes, sorts and labels; it never judges. Where npm is shown at all it is secondary to
    the BPM the musician actually sets.
  - ~~**Slice 1 — display + derived npm (no migration, do first).**~~ **DONE 2026-07-29** (branch
    `pocket-202-slice3a-command-tempo-note-rate`; see *Slices 3a & 3b* above for the carry-forward
    notes). Shipped as `NoteRate` + `Exercise.noteRate` / `commandProgressLabel`, the rhythm on the
    exercise rows, routine blocks, the run screen's live readout and the detail sheet's Feel section,
    and the library's Command key ranking on `commandNotesPerMinute`. The **planner** half of this
    bullet was a false alarm — it reads mastery and `lastPracticed`, never a tempo.
  - ~~**Slice 2 — bind the achievement to its rhythm (own ADR).**~~ **DONE 2026-07-29 as ADR 0121**
    (see *Slices 3a & 3b* above). Shipped `commandNotesPerBeat` + the keep-note-speed / re-measure
    prompt, the journal's `commandNotesPerBeatAtEntry`, and the axes unified by **retiring**
    `subdivision` — it was never wired to the click at all, so there was no second axis to follow.
    `nil` means "nothing bound", never "legacy": the one-time backfill stamps every existing
    measured command.
  - **Rejected:** a *stored* `notesPerMinute` field (derivable — a denormalisation that can go stale);
    silently rescaling command on a Rhythm change without telling the user (an unannounced rewrite of a
    measured achievement); and any global difficulty ordering (see the scope decision).

- ~~**Extend "draw your own" to the technique templates (parked 2026-07-23).**~~ **DONE (pocket-180,
  2026-07-23).** The generate-or-draw toggle + hand-drawn `FretboardDrillEditor` canvas with the scale
  **Guide** now extends to all four `.run` bespoke editors — **Warm-up, Picking, Legato, Fingerstyle** —
  at both create (`ConfigureExerciseForm`, extracted from `NewExerciseSheet.swift`) and Edit shape
  (`ExerciseShapeSheet`). A `runMode` (generate/draw) mirrors `scaleMode`; draw mode emits `.custom(drill)`
  from an empty-bar seed, generate mode the declared `FretboardRun`. No model change — rendering keys off
  `FretboardContent.drill`, not the template. Recorded as an ADR 0107 follow-up (no new ADR needed).

- **Link exercises ↔ songs → curated routine generator (logged 2026-07-23).** Decided direction:
  a **direct, user-authored Exercise↔Song edge** (many-to-many) that feeds a **"Build a practice
  routine for this song"** action — pulls the song's linked exercises + its own loops into a fresh
  `Routine`. This is the smallest change with the biggest unlock: curated routines *without* pulling
  forward the deferred V2 planner. Rejected alternatives: routine-only (no reusable link, dies with
  the routine) and reviving the planner `Goal.targetSong`/`skillIDs` machinery (heavier, indirect via
  the skill taxonomy). The planner, when it lands, becomes just a smarter producer of the same edges.
  - **Model — ✅ DONE (pocket-182, ADR 0111, 2026-07-23).** Shipped the edge: `Exercise.linkedSongs`
    + inverse `Song.linkedExercises`, the store's first many-to-many (`@Relationship(inverse:)` on the
    `Exercise` side only, `.nullify` both ways, additive optional → empty set on migration). The
    "Exercise is Song-free" boundary is reversed for repertoire association only (audio/tempo firewall
    stands) and recorded in **ADR 0111** (0109 was taken by the triad-shapes work). In-memory
    `ModelContainer` round-trip + both nullify-not-cascade directions covered in
    `ExerciseSongLinkTests`. **Migration device-verified 2026-07-23** — installed over a populated
    store, launched clean, existing library intact (no wipe).
  - **Authoring UI — ✅ DONE (pocket-182, 2026-07-23).** Both-sides link authoring: a **Songs** section
    on `ExerciseDetailSheet` and an **Exercises for this song** section on `SongDetailsSheet`, over a
    shared presentation-only `LinkPickerSheet` (searchable multi-select, swipe-to-unlink, persists
    immediately). `SongDetailsSheet` is reached from the Library long-press **Details** action (added
    alongside Edit) as well as the waveform title-hold — Edit stays the staged metadata form
    (Cancel-discards), which is why the immediate-persist link UI lives on Details, not Edit. No schema
    change — reads/writes the 0111 edge.
  - **Generator — ✅ DONE (pocket-182, 2026-07-23).** Pure, unit-tested `SongRoutineBuilder`
    (Core/Planner) emits `[SessionBlock]` from a song's linked exercises (`.focus`) + its loops
    (`.focus`) + a trailing `.play` play-through, reusing `RoutineDetailView(generatedSession:)` →
    `PracticePlanner.materialise` so nothing persists until Save (Cancel/back = no orphan). Entry
    point: **Build a routine for this song** in the *Exercises for this song* section on
    `SongDetailsSheet`, disabled unless there's ≥1 linked exercise or loop. No schema change — reads
    the 0111 edge. **This completes the exercise↔song feature** (schema + authoring UI + generator).
  - **Links at creation + a "universally applicable" flag — PARKED 2026-07-30 (was the device-testing
    pass's Slice 10).** Two items that arrived as one small follow-up and are really one small piece
    and one open design question:
    1. **Offer the link on the *new exercise* sheet, every template — ✅ DONE (branch
       `pocket-208-song-links-on-create`, 2026-07-30).** A **Songs** section on
       `ConfigureExerciseForm` over the existing `LinkPickerSheet` (presentation-only, so it took no
       changes), picks staged in local `@State` → `NewExercisePlan.songs` → attached by each host
       **after** `context.insert`, because a relationship assigned to a not-yet-inserted model doesn't
       stick (the constraint `UnitDuplication` documents). Notes:
       - **There are two insert paths, not one.** `ExerciseLibraryView.create` *and* the metronome
         automator's "Save as exercise" seam in `MetronomeAutomatorPanel`, which builds and inserts
         its own `Exercise` inline. Both had to attach the links or a link made on the automator's
         sheet would vanish with no error — the same second-path trap ADR 0120 hit with
         `exerciseCreated` analytics.
       - **The existing link tests all linked two *uninserted* models**, which works; the creation
         path links an already-stored song onto a fresh drill, which is the ordering that actually
         constrains it. Pinned by `testAttachingStoredSongsAfterInsertingTheExerciseLinksBothWays`.
       - **The section hides itself on an empty song library** rather than offering a row that opens
         an empty picker on an already-long form. It reappears once a song is imported.
       - **Adding a `@Query` to a form breaks its previews.** `ConfigureExerciseForm` and both
         `NewExerciseSheet` previews needed a `.modelContainer`; without one a `@Query` traps. Cheap
         to fix, easy to miss, and it only shows up in the canvas — not in a build.
    2. **The flag is not small, and this is why it was parked rather than built.** The original note
       read *"a flag meaning the exercise is tied to no song"* — but **nothing in the app filters by
       song links today**, so the flag has no existing behaviour to label. It would *create* one.
       `CandidateDeriver.techniqueCandidates` (Path A) resolves a goal skill to **every** library
       exercise whose template serves it, song-tied or not; `CollectionSessionBuilder` is purely
       link-driven in the other direction (`pool`/`canBuild` count only `song.linkedExercises` +
       `song.loops`). Three questions have to be answered before any code, and each changes the work:
       - **Stored or derived?** Derived (`linkedSongs.isEmpty`) is free but can't express "linked to
         Binta *and* generally useful", and linking a song would silently drop the drill from the
         universal pool. A stored `Bool` independent of the links can express it, at the cost of a
         field the user has to understand.
       - **Hard filter or soft down-weight in Path A?** A hard filter gives "always eligible" a real
         complement (song-tied drills reach a session only via Path B, a repertoire goal for their
         song) but **can empty the pool** — a player whose drills are all song-linked would derive
         nothing for a technique goal. A soft multiplier on `priority` matches the house precedent
         (`prereqPenalty`/`prereqFloor`, the ADR 0016↔0071 "never refuse what the player asked for"
         shape) and can't empty anything.
       - **Do universal drills top up a thin collection session?** If yes, `pool` and `canBuild` stop
         describing the collection and a Binta session can contain drills unrelated to Binta; if no,
         ADR 0118's deliberate "a thinly-linked collection yields a thinner session" stands.
       Item 1 shipped on its own without answering any of this (user call, 2026-07-30 — *"we'll
       revisit the universal applicable flag another time"*), which is what the original note should
       have said. **The flag remains parked and unanswered.**

- ~~**Futura navigation titles app-wide (spotted in the v1 screenshot shoot, 2026-07-23).**~~ **DONE
  (pocket-181, ADR 0110, 2026-07-23).** Shipped exactly as the decision below: one global
  `UINavigationBarAppearance` in `Pocket/UI/NavigationBarStyle.swift`, applied once from
  `AppDelegate.application(_:didFinishLaunchingWithOptions:)`. Futura-Bold title + large-title
  attributes (`UIFontMetrics`-scaled) in `Ink`; default material on standard/compact, transparent on
  scroll edge; the two `.principal` screens untouched. **Correction to the verify note:** the proxy is
  installed by the app delegate, so it is **not** visible in a SwiftUI `#Preview` — verified on a real
  run (device/sim), not the canvas. Original write-up kept below for record.

  Every SwiftUI `.navigationTitle` renders in **San Francisco**, not Futura — there's no SwiftUI-native
  hook to swap the face. Spotted on the exercise run screen ("A Minor Pentatonic"), but it's
  systemic: **~45 titles across the app**, nearly all `.inline`. Only two screens already dodge it
  by hand-rolling a `.principal` toolbar item in Futura — Home's wordmark and `MetronomeView`'s
  header (`Text(.font(.futura(.headline)))`).
  - **Decision (2026-07-23): one global override, including large titles.** A single
    `UINavigationBarAppearance` set once at launch — new `Pocket/UI/NavigationBarStyle.swift`,
    called from `AppDelegate.application(_:didFinishLaunchingWithOptions:)` in
    `OrientationGate.swift`. Overrides `titleTextAttributes` **and** `largeTitleTextAttributes` to
    **Futura-Bold** (`.headline`/`.largeTitle` sizes, `UIFontMetrics`-scaled so Dynamic Type still
    grows them) in `UIColor(named: "Ink")` (= `PocketColor.textPrimary`). Fonts resolve as
    `"Futura-Bold"` (see `Font.futura`, `DesignTokens.swift`). The two `.principal` screens override
    their own centre, so they're untouched.
  - **Why global, not per-screen:** the app has **zero** per-screen toolbar-background
    customisation (grep: only `WaveformPracticeView` hides its bar; nothing sets
    `.toolbarBackground`), so there's nothing for the proxy to clash with. Editing ~45 call sites
    would churn and drift; the proxy also catches every *future* screen for free.
  - **Preserve the current look:** keep default material for `standardAppearance`/`compactAppearance`
    (shown when content scrolls under the bar) and a **transparent** `scrollEdgeAppearance` (the flat
    black bar at rest, as shown in the screenshot) — only the title text changes.
  - **Reversibility (required):** keep it isolated to that **one file + one call site** so it's
    trivially removable, and gate large titles as a **one-line removal** (drop
    `largeTitleTextAttributes`) if they read wrong at 34pt. Fallback if the proxy misbehaves: a
    per-screen SwiftUI `.principal` Futura modifier mirroring `MetronomeView` (safe, zero background
    risk, but ~40 edit sites) — the proxy is the first choice precisely because it's the easiest to
    undo wholesale.
  - **Verify (Xcode preview, per the usual flow — not sim screenshots):** the run screen's title in
    Futura, the **scrolled-under** bar material on a long screen, and the one large-title screen
    (`LibraryView` has no explicit `.inline`). Small.

- ~~**Add-routine picker: audio previews on loop rows.**~~ **SHIPPED (pocket-166, ADR 0104 Slice 2
  follow-up, 2026-07-22).** A per-row **audition** speaker (reusable `AddRoutineUnitRow` +
  `LoopAudioPreviewPlayer`, one loop at a time per screen) on the **Loops** and **Ear training**
  buckets — and every loop row in search — so indistinctly-named loops ("Loop 5/8") can be told apart
  by ear.
- ~~**Add-routine picker: make the whole picker searchable.**~~ **SHIPPED (pocket-166, ADR 0104
  Slice 2 follow-up, 2026-07-22).** `.searchable` on `AddRoutineUnitSheet` flattens the buckets into
  typed result sections across **all** elements — Exercises · Loops · **Ear training** (same loops) ·
  Songs — matching on unit name + song title.

- ~~**Bulk song import from local/iCloud files.**~~ **SHIPPED (PR #114, pocket-120, 2026-07-10).**
  Multi-select `fileImporter` on both entry points (home hub + library `+`); each file decoded off
  the main thread behind an "Importing N of M…" overlay, partial-failure tolerant (unreadable/DRM
  files skipped, good ones still import) with a summary alert. Home import navigates into the library
  afterwards; library stays put. Pure `SongImportSummary` unit-tested.
- ~~**Loop edit "blocked while playing".**~~ **FIXED (pocket-121, 2026-07-10.)** The real cause
  wasn't playback at all: in a loop's waveform edit sheet the **Focus** and **Type** rows were
  interactive `.menu` `Picker`s in a `LabeledContent` value slot, which need several taps to register and
  never commit their selection at the sheet's partial detent — so those two fields appeared frozen. Both
  are now a plain `Button` opening a `confirmationDialog` that writes the choice directly (a `Menu` of
  `Button`s was tried first but still needed multiple taps). Mastery/Command tempo always worked — not Pickers.

- ~~**Manual target override (loops, and likely exercises).**~~ **SHIPPED (PR #116, pocket-122,
  2026-07-10) — ADR 0075.** Applied to **both** loops (`Loop.targetSpeedOverride: Double?`, ×) and
  exercises (`Exercise.targetTempoOverride: Int?`, BPM) — additive optionals read through effective
  `targetSpeed`/`reachTempo` (`override ?? auto`). The reach is editable in place (run-setup Practice
  Settings + the exercise Tempo section) with **reset-to-auto**; a pin must stay above command, so
  `promoteCommand` **auto-clears** it once command catches up. `Exercise.targetTempo` went vestigial
  (retained, unwritten). Also dropped the redundant idle transport timecode. **Fast-follow deferred:**
  a per-user on-device *learned* reach default over the accumulated pins (own future ADR) — the pins
  are its data substrate; not built (no data to train on yet).

- ~~**Routine block repeats (reps authoring follow-up).**~~ **SHIPPED (PR #117, pocket-123,
  2026-07-10) — ADR 0076.** The R3 `RoutineItem.reps`/`effectiveReps` + reps-aware length estimate
  were infra-only; this added authoring (tap a unit block in edit mode → a `BlockRepsEditor` sheet
  with a stepper, 1–9; a tappable `×N` chip is the affordance) and player looping (a multi-rep block
  runs back-to-back with a "Rep N of M" counter, Done screen only after the last rep; Skip abandons
  remaining reps). Rep stepping lives in the pure `RoutineSessionCursor`.

- **Practice — exercise creation entry point (design experiment).** The create sheet now asks
  for **command tempo** explicitly (working floor + reach derive from it), which fixes the
  earlier mismatch where the entered "working" number resurfaced as "command" on the run screen
  (ADR 0046, branch `pocket-067`). Open question worth A/B-ing: is command the best single number
  to anchor an exercise on, or would starting from the **working** tempo (where you actually
  practise today) or the **target/reach** (the goal) read more naturally to a musician? Try the
  variants and pick the one that needs the least explanation.
- **Loop tags — show existing as well.** DONE (branch `pocket-055`): the tags
  already on a loop now render as removable chips matching the suggestion-chip
  language, in the loop edit sheet. Tags stay edit-sheet-only — no loop-row display
  (ADR 0034 gating holds).
- **Landscape — practice screen only.** DONE (ADR 0042, branch `pocket-056`):
  the practice screen rotates to landscape (waveform claims the width, loops/markers
  to a ~30% side rail); every other screen stays portrait. The bottom song-info
  panel was removed in the same pass.

## Chords & theory (logged 2026-07-17)

Direction sense-checked 2026-07-17: music **theory & ear training are fair game** and do **not**
conflict with "Pocket never grades the player" (ADR 0070) — that rule is about the *subjective* act
of playing; interval/chord/scale identity is *objective* and needs no performance to assess. The
ADR-0086 removal of key/Roman-numerals was scoped to the **chord-template surface only**, so a
dedicated theory/ear-training context isn't bound by it. Worth its own ADR before building.

- ~~**Scrollable custom-chord board + Display toggle.**~~ **DONE (pocket-149, 2026-07-17).** The
  placer scrolls the neck (frets 1–15), mute/open + string names pinned, inlay dots at 3·5·7·9·12·15;
  new **Display** menu (Note / Interval / Off) reusing the scale boards' control and global pref.
  Added `ChordVoicing.noteLabels`.
- **Chord suggestions / chord identifier (ADR 0093).** In the space below the custom-chord board,
  surface likely names for the shape being built (reverse lookup: sounded pitch classes → chord
  name(s), inversions/enharmonics handled). **Slice 1 DONE (pocket-150):** the pure naming engine
  `Core/Theory/ChordNamer` (common-practice vocabulary, ranked candidates, slash inversions, sharp
  spelling, 18 unit tests) — the shared theory core, with a `ChordVoicing` adapter as its first
  consumer. **Slice 2 DONE (pocket-150):** live `ChordIdentifierPanel` under the custom-chord board in
  `CustomChordSheet` — "Looks like Cmaj7" + alternate/inversion chips, tap-to-fill-name, "No common
  name" fallback; hidden until ≥3 distinct notes. Additive & factual (never grades). *Follow-on if
  wanted:* surface the same panel on the movable sheet / progression editor rows.
- **Ear-training & theory space (direction — ADR 0094).** Stay on the clearly-safe side of the
  no-grading line: **reference/exploration** tools (interval player, chord voicer that sounds the
  shape, scale/mode explorer with audio over the existing 12-scale catalog) and **call-and-response,
  self-judged** drills (app plays → you echo on guitar → *you* decide; nothing listens or scores).
  **App-scored right/wrong quizzes are forbidden** (ADR 0094 T2c) — that's the bright line. No
  streaks/scores/XP. Direction ratified in ADR 0094; **no build scheduled yet.** A "coach that
  explains the theory" is an **AI** feature → ADR 0092, deferred/paid.
- **Saved custom chords — "My chords" (ADR 0095). DONE (pocket-151):** the placer gains an explicit
  **Save to My chords** button; saved voicings persist as a standalone `SavedChord` `@Model` (voicing as
  an encoded blob, migration-safe) and reappear as a **My chords** section in the Add/swap menus + a
  `SavedChordsSheet` list (tap-to-insert, swipe-to-delete). Interim home; graduates to the hub below.
- **Chords / theory / resources HUB (direction — ADR 0096, PARKED).** A dedicated top-level *reference*
  destination (separate from the exercise editors) carrying **My Chords** (the ADR-0095 library promoted
  to its own screen) + **theory & ear-training** (ADR 0094 tools) + a **glossary/vocabulary** sheet, all
  objective/additive (no grading, no quiz — ADR 0070/0094). Built on the shared `Core/Theory` +
  scale-catalog + `SavedChord` substrates. **IA/design pass DONE (2026-07-17):**
  [`docs/plans/chords-theory-hub-ia.md`](plans/chords-theory-hub-ia.md) resolves the attach point (a
  **fourth home card → own NavigationStack**, matching the teal·plum·terracotta triad), the five-section
  screen inventory (My Chords · chord identifier · scales & modes · intervals & ear · glossary), the
  build/hear/explore/keep flows, and phasing (**Slice 1 = shell + My Chords + Glossary**, the only
  zero-dependency tenants). **D1–D5 ratified 2026-07-17 → ADR 0096 ACCEPTED:** attach = **fourth home card**
  ("**Toolkit**", **indigo/violet**), *Hear*/audio **deferred to Slice 2 + own ADR**, **Slice 1 = shell +
  My Chords + Glossary** (audio-free). **Slice 1 BUILT (pocket-155, 2026-07-17).**
- **Hear / audio-preview across the app (ADR 0097 — resolves 0096 D4). NEXT PRIORITY (player-flagged,
  2026-07-17): build before v1 submission.** On-device spike confirmed a **synthesized** tone (built-in
  `AVAudioUnitSampler`, zero assets) is good enough as a pitch reference; **block chords, no strum** for
  v1. One shared **sequence-capable `ToneEngine`** (`Core/Audio`) with `sound(notes:)` + `sequence(notes:…)`
  feeds every surface, reading MIDI the models already expose (`ChordVoicing.midiNotes`,
  `ScaleRun.sequence`→`CAGEDShape.midi`, `FretboardDrill.notes`). Provisional slice order:
  1. ~~**`ToneEngine` + block-chord Hear in My Chords** (promote the spike; delete `ChordTonePlayer`/`HearSpikeView`).~~ **DONE (pocket-156, 2026-07-17):** shared sequence-capable `ToneEngine` (`Core/Audio/`, built-in tone) shipped; **Hear** button on `MyChordDetailView` sounds the voicing (block); spike files + temporary Toolkit row removed.
  2. ~~**Hear on the chord identifier / custom placer** (sound the shape being built).~~ **DONE (pocket-156, 2026-07-17):** a **Hear** control sounds the live voicing on the **custom placer** (`CustomChordSheet`, beside Display — enabled as soon as any string sounds, before naming) and the **movable-shape sheet** (`MovableChordSheet`, in the live preview). Same block-chord `ToneEngine.sound` path as Slice 1.
  3. ~~**Scale/CAGED-box preview** (sequence asc/desc) + **arpeggios** (a chord's notes, sequenced).~~ **DONE (pocket-156, 2026-07-18):** shared `FretboardHearButton` (audio sibling of `FretboardPlayOnceButton` — Watch walks it, Hear sounds it) added to the **Scales** (`ScaleRunEditor`) and **Arpeggios** (`ArpeggioRunEditor`) editors, beside Watch. Sequences `run.sequence.map(CAGEDShape.midi)` through `ToneEngine.sequence` (asc, then descent when round-trip is on). Same button/table is reusable for Slice 4's fretboard/picking-run editors.
  4. **Fretboard/picking-run preview** — **DONE (pocket-157, 2026-07-18):** `FretboardHearButton` added to `FretboardRunEditor` (picking runs) and `FretboardDrillEditor` (custom grid) — the melodic path is now **rest-aware** (`ToneEngine.sequence` takes `[Int?]`; a `nil` slot keeps its time so empty grid cells stay aligned to the walk). **Glossary "Hear" affordance** on interval/chord terms — **PULLED for now (2026-07-18):** built (pure `GlossaryTerm.demo`/`AudioDemo` + per-row speaker for intervals + Power chord/Triad/Arpeggio) but backed out before the PR — the player judged it more trouble than it's worth for the value; revisit if ear-training (ADR 0094) wants it. Note: the whole Hear surface has known **sync + display rough edges** flagged 2026-07-18 to fine-tune later (audio/highlight drift on some shapes; extended-shape display).
  5. **Intervals / ear-training** playback (ADR 0094, still needs its own build ADR; objective, no quiz).
  *Optional later — CC0 guitar SoundFont (ADR 0097 D4.3):* **built-in tone judged good enough on device
  (2026-07-17), staying as-is for v1** — the clean synth tone is arguably *clearer* for a reference tool
  (dense voicings read as distinct pitches without a guitar's overtones muddying them). Loading a nylon
  guitar `.sf2` is a drop-in over the *same wired code path* (`ToneEngine.loadSoundFontIfPresent`, expects
  `HearGuitar.sf2`) — no rewrite. It's a **trade, not a strict upgrade** and quality is entirely the
  font's, so it's a separate later slice: (1) find a **genuinely CC0/public-domain** font licensed for
  redistribution *as a playable instrument in a shipped app* (same rights posture as the Kontakt/GarageBand
  rejections), (2) **audition candidates on device**, (3) keep or revert. A few MB of bundle weight.
  Deferred, not blocking v1.

- ~~**Chord picker redesign — search-first, Insert/Build split (user-testing Note 12, logged 2026-07-20).**~~
  **DONE (pocket-165, ADR 0103).** Shipped as `ChordPickerSheet`: search field over an Insert grid
  (My chords → Movable shapes → Open shapes) + a Build segment (Movable/Custom cards); movable chips tap →
  root menu → placed grip; `SavedChordsSheet` removed, management lives in Toolkit → My chords (ADR 0103 D5).
  Original write-up kept below for record.
  From a user-testing pass: the chord-**insert** surface felt **dense** and made saved chords **hard to
  find**. Root cause is structural — `voicingMenu`/`addMenu` in
  [`ChordProgressionEditor.swift`](../Pocket/Features/Practice/ChordProgressionEditor.swift) are a single
  flat SwiftUI `Menu` that stacks *Movable shape… → Custom chord… → My chords (unbounded) → Manage… →
  curated `ChordVoicing.library`* in one growing text column with no filter. As the ADR-0095 **My chords**
  library grows, density and findability both degrade and there's no search to escape it. **Proposed shape**
  (mockup: <https://claude.ai/code/artifact/e9681690-b22e-4f76-8ad8-f8f722025105> — interactive, dark-committed
  to match the app):
  1. **Replace the flat `Menu` with a picker sheet** carrying a live **search field** at the top — type
     "maj9"/"lenny" and filter, the fix a growing list can't get from ordering alone (findability).
  2. **Split *Insert* from *Build*** (segmented): *Insert* = pick an existing voicing; *Build* = the two
     authoring actions (Movable shape / Custom chord) as cards. Empties the everyday path of its two
     least-used rows (de-density).
  3. **Diagram grid, not a word list**: mini chord-diagram chips read shape at a glance and pack tighter
     than text, in three browsable groups — **My chords** (surfaced first, badged as yours), **Movable
     shapes**, then **Open shapes**.
  4. **Movable shapes are first-class in Insert (ADR 0084).** The **Movable shapes** group shows common
     generated barre grips (E-/A-shape maj/min/dom7 as `ChordGrip`s, badged "slide to any root") as
     tap-to-insert diagram chips — so the everyday "I want an F barre" no longer requires diving into the
     Build authoring flow. **Build → Movable shape** stays for full grip-to-arbitrary-root placement; the
     two are the browse-vs-author split of the same ADR-0084 substrate (grips generated, never a stored
     table). Chips read `ChordGrip` geometry, so no new data.
  Additive over the shipped surfaces — no model change (reads `ChordVoicing`/`SavedChord` (ADR 0095) +
  `ChordGrip` (ADR 0084); grips generated on the fly); the renderer is untouched. Touches both call sites
  (`addMenu` + `voicingMenu`) plus likely
  [`SavedChordsSheet.swift`](../Pocket/Features/Practice/SavedChordsSheet.swift) /
  [`MyChordsView.swift`](../Pocket/Features/Toolkit/MyChordsView.swift) for consistency. **Needs its own
  ADR** (closes off the native-`Menu` approach for chord insert) before building; small-to-medium. Not yet
  scheduled — sits in Wave 2 of the 2026-07-20 user-testing plan of attack.

- ~~**maj9 / min9 movable A-shapes (ADR 0084 follow-up, requested 2026-07-20).**~~ **DONE — MERGED
  (ADR 0101, PR #158).** Shipped all three — `dom9`/`maj9`/`min9` are in `ChordGrip.Quality` with the
  A-shape grips, `tier2` extension, and the octave-bump guard for the A/B♭ edge; the reopened
  Tier-2/3 "9ths → placer" call was settled by ADR 0101. Original write-up kept below for record. Add ninth
  extensions to the curated movable set (`ChordGrip`), at least the **A-shape** family the request
  named. The ADR-0084 comment parked "basic 9ths" to the custom placer, but the common A-shape ninths
  are clean movable grips — the note under-sold them. Concrete voicings (root on the A string, high-e
  muted like the other A-shapes), offsets high-e-first `[e, B, G, D, A, lowE]`:
  - **maj9** — C maj9 = `x3243x` → `[nil, 0, 1, -1, 0, nil]` (D-string = 3rd, G = maj7, B = 9).
  - **min9** — Cm9 = `x3133x` → `[nil, 0, 0, -2, 0, nil]` (D = ♭3, G = ♭7, B = 9).
  - *(optional)* **dom9** — C9 = `x3233x` → `[nil, 0, 0, -1, 0, nil]`; the most-used of the three and
    the same shape family, so worth folding in unless we deliberately keep it placer-only.
  - **The one wrinkle:** every 9th voicing puts the D string **below** the root fret (offset −1/−2),
    so a root fret of 0 (A) — and fret 1 (B♭) for min9 — would emit a negative fret. Fix is a one-line
    **octave-bump** in `ChordGrip.voicing(rootPitchClass:)`: if any resulting fret < 0, add 12 to the
    root fret (A9 lands at fret 12, a legit playable voicing — the "jumps an octave" the ADR comment
    predicted). Every other root places cleanly with no bump.
  - **Work:** add `maj9`/`min9`(/`dom9`) to `ChordGrip.Quality` (+ `nameSuffix`/`displayName`), the
    A-shape grips, extend `tier2`, add the octave-guard, and **unit-test the A/B♭ edge** (the exact
    slider-style math AGENTS.md requires covered). No renderer or sheet changes — `MovableChordSheet`
    reads the curated list dynamically. **Reopens the ADR-0084 Tier-2/3 "9ths → placer" call**, so it
    wants a short ADR note (or an 0084 amendment) before building. Small.

- **Toolkit hub is thinner than the card promises — only My Chords + Glossary surface
  (found during the v1 screenshot shoot, 2026-07-22).** **Subtitle realigned (pocket-170,
  2026-07-23):** the Home **Toolkit** card now reads "*Your chords & a music glossary*"
  instead of "*Chords, scales & theory reference*", so the copy no longer over-promises the
  not-yet-built sections. **Still open (the deferred build):** the hub carries only **My
  Chords** and **Glossary** — the scales & modes, chord-identifier, and intervals/ear
  sections from the hub IA
  ([`docs/plans/chords-theory-hub-ia.md`](plans/chords-theory-hub-ia.md) sections 2–5)
  were deferred past Slice 1 (see the ADR-0096 entry above). Consequence still to fix:
  there's **no *Hear* / audio-preview reachable from Toolkit** — Hear shipped only as
  inline buttons inside the Practice-side exercise editors (scales/arpeggios/chords/runs,
  ADR 0097), so a user browsing Toolkit as a *reference* destination never meets it.
  Fix path = build the deferred hub slices (scales & modes explorer + intervals/ear per
  ADR 0094 Slice 5) so the reference Hear surfaces there. Relates to the Wave-2
  "split Toolkit into a Learn section" step.

## Notes & journal — DONE (ADR 0038)

Shipped in PR #50: a per-loop **practice journal** (dated entries snapshotting
mastery + command tempo at write time, immutable; typed entry kinds) opened from
a book icon on the loop row, plus **song notes** (free-text `Song.comment`)
editable inline in the song details sheet. Narrowed ADR 0012's three-scope
forecast to loop-only; markers get neither. AI summaries over the journal remain
in the AI phase (below).

## Journal authoring → Practice screen — SHIPPED (ADR 0058)

**SHIPPED.** Journal authoring lives on the Practice run screens (`ExerciseRunView` /
`LoopRunView` — `JournalSheet(owner:)` + `JournalPreviewSection`), the waveform journal
is read-only, and exercises have their own journal (polymorphic `JournalEntry`, owner =
loop XOR exercise, with the honest `commandBpmAtEntry` snapshot). The migration was
device-verified and merged. The original plan is kept below for record.

**Ownership decided (ADR 0058, 2026-07-01):** one polymorphic `JournalEntry`
(owner = loop **XOR** exercise), reusing the existing list/undo/kind/sheet
machinery; exercises get a new honest `commandBpmAtEntry: Int?` snapshot (no
mastery, absolute BPM) rather than overloading the loop's song-fraction `Double`.
Additive schema (new optional `exercise` relationship + `commandBpmAtEntry`) —
device-verify the migration before merge. **Loops-first is an acceptable partial
ship** if the exercise side slips.

**Built (2026-07-02), device-verified & MERGED.** Model layer + full UI:
`JournalOwner`/`JournalWriter` shared write path, `JournalSheet(owner:readOnly:)`
generalised from the loop-only sheet, book button on both run screens, waveform journal
made read-only, old waveform write helpers retired.


Relocate journal **authoring** to the Practice run screens; make the waveform
journal **read-only** (history view only). Rationale: ADR 0046 makes Practice
*the* run surface — the moment right after a run, where you just felt the
difficulty, is the truthful place to write a note; the waveform screen is
edit/create. A "+" / add-note affordance lives in the run screen's top-right
(where the empty nav slot is today).

- **No data migration / no erasing entries.** This is a UI relocation, not a
  schema change — existing `JournalEntry` rows stay. (Corrects the 2026-07-01
  sense-check premise: the journal never captured automator settings — only
  `masteryAtEntry` + `commandTempoAtEntry`, snapshot unchanged.)
- **Snapshot stays** mastery + command tempo at write time, now read off the
  loop from the run screen instead of the waveform model.
- **Extend to exercises (net-new).** Exercises have *no* journal today —
  `JournalEntry` only relates to `Loop`. Add an `Exercise` journal from scratch:
  new model relationship (`JournalEntry.exercise` or a shared owner), authored
  from `ExerciseRunView`, with its own snapshot (command BPM / mastery-equivalent
  at write time). New ADR — decide the ownership shape (one polymorphic entry vs
  two) before building. Loops-first is acceptable if exercises slip.

## Loop experience (sense-check decided 2026-06-24)

Outcome of a UX review of loop properties + the loop-making flow. Numbering
matches the discussion thread.

**#2 + #4 — DONE (ADR 0039).** The loop row now surfaces **mastery** (dots) and
**command tempo** (a percent badge, the achievement) under the name, shown only when
set — last-practiced speed is *not* shown. The three judgment fields (**mastery,
command tempo, focus**) became Optional with an explicit "unset" state, so a default
never masquerades as a rating (the `1.0` command-tempo "100%" lie is gone). Existing
loops migrated to `nil` for free; `MasteryRollup` skips unrated loops; the edit sheet
gained set/clear affordances (dot walk-down, command-tempo Set/Clear, focus menu).

**#3 — DONE (ADR 0040).** Each loop now remembers the speed you last practised it at
(new `Loop.lastPracticedSpeed`, kept separate from `loop.speed` = automator ramp start to
avoid clobbering it). Persisted on leave via a single `activeLoopID` `didSet` choke point
(not per slider tick); arming a loop — tap or transport skip — restores its speed, falling
back to `loop.speed` when never practised. Session still opens clean (full song, 1×),
refining ADR 0029. The user-defined toggle (loop speed always = command tempo *vs* last
playback) stays V2.

**#6 A/B as the creation primitive — DONE (ADR 0041, branch pocket-054).** The
ephemeral A↔B span is now the single creation primitive: tap A/B to set A then B (or
hold-drag), the span loops with no ✓/✗ gate, its labelled A / B handles drag in place,
**Save as loop** persists it. Dragging a saved loop's edge lifts it back into A/B for a
range edit (**Save changes** writes back), dissolving the three-hop range edit. **Fine
mode and the capture/confirm system were retired** — the transport left column is now
A/B · Marker. Built in 5 slices (pure `ABSpan` state machine → play-along set → handle
adjust → range-edit lift → Fine retirement + hold-drag wiring).

**V2 / planner-era:**

- **#4 test-data seeding** to exercise the planner before real fill-rate exists.
  Validates planner *logic*, not fill-rate — only real usage shows whether users
  actually fill the fields.

**Parked — deliberate, leave as-is:**

- **#5 Multi-select loops:** parked until the friction is real. Useful for bulk
  delete / cleanup and batch re-tag / type / focus, but it's a *scale* feature —
  it only pays off with many loops, or once the planner makes bulk-focus a real
  workflow. At a handful of loops, one-at-a-time editing doesn't hurt, so building
  the selection-mode UI now is speculative. *Inheritance and duplicate were
  considered and rejected* — multi-select is the only bulk move we'd want.
  **Revisit when** one-at-a-time editing starts to hurt, or when the planner lands.
- **#1 Marker→loop bridge:** not needed as an explicit action. Markers already
  snap loop edges during creation (ADR 0021), and a marker is approximate, so an
  "exact marker→loop" would mislead. The passive snap is the right amount.
- **#7 Resume-to-last-loop:** leave as-is (ADR 0029 wipes the active loop on
  exit); revisit via A/B test. Could ride on the `lastPracticed` field cheaply if
  reconsidered.
- **#8 "Loop 1/2/3" naming:** deferred naming (ADR 0019) stays — if a loop's
  unclear you play it to remember, and the glanceable row (#2) lowers the cost
  further.

**Found during the v1 screenshot shoot (2026-07-22) — two loop-practice-library gaps:**

- **Loops practice library shows empty despite songs having loops.** Songs in the
  library carry saved loops (visible in each song's loop trainer), but the centralised
  loops practice library lists none of them — the aggregation isn't surfacing
  song-owned loops. *Verify it's not a seed artefact first:* the shoot's loops were
  inserted programmatically by `ScreenshotSeed`; confirm the gap also reproduces with a
  loop saved by hand via **Save as loop** before treating it as a pure query bug.
- ~~**From the loops practice library, ramp is the only practice mode — ear training
  doesn't surface.**~~ **DONE (pocket-170, 2026-07-23).** `LoopLibraryView` rows now carry a
  per-row **Ear** button beside the ramp tap: tapping the row opens the command-ramp `LoopRunView`
  (unchanged), the Ear button pushes `EarTrainingView` (ADR 0104). Two sibling buttons + programmatic
  `navigationDestination(item:)` so the List routes each tap to its own mode.

## Practice run-setup — persist loop ramp shape — DONE (2026-07-01, ADR 0057 follow-up)

Shipped on `pocket-083`: four dedicated `Loop` fields (`rampWarmupSteps` /
`rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep`, declaration defaults,
additive migration), decoupled from the ADR-0013 automator. `LoopSetupState` now
tracks all six persisted fields (ramp edits arm Save Changes), `seedIfNeeded`
restores them, shared `persist()` writes them. Original spec below, for record.

Follow-up recorded in **ADR 0057**. The loop run-setup screen exposes four
ramp-shape controls — warm-up intermediate steps, reach steps, back-off steps,
reps per step — that **don't persist**: only `speed` (working) and `commandTempo`
(command) round-trip today, so **Save Changes** never appears for the four, and
they reseed to defaults each visit. Exercises already persist the full shape
(`rampStepBPM` / `rampIntervalCount` / `rampReachSteps` / `rampBackoffSteps`).

**Plan — add four *dedicated* `Loop` fields, decoupled from the legacy automator.**
Do **not** reuse the ADR-0013 automator fields (`automatorStepCount`,
`automatorLoopsPerStep`): they're the waveform-screen ramp with different
semantics ("steps to target" vs "intermediate stops between working and command"),
and coupling the two ramp systems to save four fields is a bug magnet. Add
`rampWarmupSteps` / `rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep` with
**declaration defaults** (CoreData 134110 rule → additive lightweight migration,
no store wipe). Then: `LoopSetupState` gains the four (so `isDirty` fires for
them), `seedIfNeeded` reads them off the loop, and the shared `persist()` writes
them back. Tests: persist round-trips all four; `isDirty` triggers per field.
**Gate:** it's a live schema change — must be device-verified against a store that
predates the fields (the SwiftData migration-crash lesson), not just in-memory
tests. Scheduled **after** the remaining Cluster 4 items land.

## Loop & marker creation

- **A/B ephemeral span ("not saved").** A transient A↔B selection the musician
  sets on the fly to rehearse **several consecutive saved loops together as
  one**, without persisting a new loop. Distinct from saved region loops
  (ADR 0006); think scratch/rehearsal span. Net-new. *Note:* the A/B span is now
  also the basis for **#6 (A/B as creation primitive)** above — build the span
  once, serve both the rehearsal and the save-as-loop use.
- ~~**Loops accessible outside their song?**~~ **RESOLVED (2026-07-17).** A `Loop`
  still belongs to one `Song`, but cross-song *access* is now delivered in practice:
  **routine** loop blocks reference loops from any song, and the **planner** (V2,
  built) session-builds by pulling loops across songs. The need surfaced and was met
  through loop practice/routines — no separate cross-song loop surface is required.
  Cross-song *filter-by-tag* stays deferred (ADR 0034) as a distinct, lower-priority
  concern.

## Onboarding — "the art of creating loops" + musician voice

A coherent vision, captured for V1's creation experience:

- **Guided creation flow, onboarding-only and skippable.** An opinionated,
  3-step path layered over the free-form practice screen, shown during
  onboarding; the user can skip it. Implementation approach TBD (the point now
  is to capture intent, not design the mechanism):
  1. **Listen whole** — original tempo, no speed changes. Think about parts you
     liked / want to recreate. Add a **first journal entry** (goals, aims).
  2. **Mark sections** — replay (author suggests ~0.8–0.9× tempo, musician's
     discretion) and drop **markers** on sections of interest. Markers set
     automatically with a standardised name (see marker auto-naming above),
     renameable anytime.
  3. **Create loops** — with the song signposted by markers, build loops from
     those positions (author suggests 50% tempo, playback starting at 50%,
     zoomed in to a set level).
- **Artist name generator + naming copy (parked 2026-07-30 — was the device pass's Slice 9).** New
  copy for the naming step: *"Every artist earns their name. / You've put in the work. Sign your
  stage name — or spin one up."* Expand `ArtistNameGenerator` and curate it from the ADR 0113 profile
  signals (genre, sound, goals) as generation variables, so a spun name reads like it came from the
  musician's own scene rather than a generic word bag. Small and self-contained: copy plus generator
  logic, no model change, no dependency on the rest of the device-testing plan. Sits naturally with
  the **musician voice** principle below — the naming moment is one of the rituals that bullet
  describes.
- **Musician voice / ritual (cross-cutting design principle).** Address users
  as *musicians* throughout; use language that helps them internalise the
  identity. Frame **completing the first loop** as a small ritual — the moment
  you "become" a musician — felt via tutorial guides and docs/copy. When acted
  on, this belongs in `docs/design-brief.md` as a voice/tone principle and
  should then govern copy app-wide.
- **Rotary haptic zoom mode (net-new interaction).** A zoom mode where finger
  rotation acts like a physical dial/knob — direction-sensed, reflected in
  haptics (rotate one way to zoom in, the other to zoom out). Alternative/
  complement to pinch-to-zoom (ADR 0010). Self-contained; could ship
  independently of the guided flow.
- **Method provenance guardrail:** this flow encodes a practice author's method
  ("the author recommends…"). Per the content strategy, encode the **method**,
  never ship his words — all copy must be ours.
- **User-guide note — mastery vs command tempo are different axes.** When we
  write user guides/help copy, make explicit that **command tempo measures
  speed** (the fastest fraction you own a loop at) while **mastery measures
  cleanliness** (how well you own it). They're deliberately separate fields
  because *for a lot of material the bottleneck isn't speed* — tone, feel,
  expression, a single hard change can be unmastered at full tempo, and a slow
  passage can be perfectly owned. Considered collapsing mastery into a
  derivative of command tempo (2026-06-25) and rejected it for this reason.

## Analytics — SUPERSEDED by ADR 0120 (kept for the reasoning)

> **Resolved 2026-07-29.** The "designated later path" below was taken: Aptabase, opt-in, EU region.
> The "v1 ships no SDK" position was overtaken by the decision to instrument *before* distribution —
> launch week is the only cohort that can show whether a cold install reaches a first practice, and
> it is unrepeatable. See `docs/decisions/0120-anonymous-product-analytics-opt-in.md`.

## Analytics — decision made 2026-07-16 (v1 = Apple-only)

**v1 ships with no in-app analytics SDK, deliberately.** Rely on the free,
Apple-side surfaces that cost zero code and zero privacy: App Store Connect →
**App Analytics** (impressions, downloads, active devices, sessions, retention,
deletions) and Xcode Organizer → **Crashes**. These aggregate from OS-level
opt-in users, so they don't touch the privacy manifest or the "collects nothing"
policy/questionnaire posture we submit at launch.

**Designated later path (when usage funnels are actually wanted):** a
privacy-first Swift SDK — **TelemetryDeck** or **Aptabase** (anonymized,
non-personal events, no third-party ad trackers). Not Firebase/Amplitude/Mixpanel
— those contradict the app's ethos. Adopting one is a clean additive 1.1 change:
add the SDK, flip App Privacy to "Data Collected → not linked to identity",
update the privacy section (the "if a future version processes data differently,
opt-in and disclosed" clause is already pre-written), aligned with ADR 0092.

## AI phase (late — gated on backend + pricing)

Parked until the foundations above are solid (see Release sequencing). Captured
so the intent isn't lost:

- **AI note summaries** over the song/loop timestamped logs — user-editable
  stays; the AI proposes a summary on top.
- **AI-suggested automator settings** derived from a loop's notes/journal (the
  speed-trainer ramp). Loop notes reachable from the automator make this the
  natural surface.
- **Cadence & monetization question (open):** how often should an AI summary
  refresh? Candidate: ~24h (or weekly) on a free tier, daily/hourly behind
  pay — find the sustainable balance without burning backend cost. Decide
  alongside the backend build (ADR 0002).

## Monetization — first paid lever (parked 2026-07-17, decide once features are set)

Deferred deliberately: settle the full feature set first, *then* design monetization
(user's call, 2026-07-17). Captured so the reasoning isn't lost.

- **Recording (ADR 0069) as a candidate first paid tier — before the AI layer.**
  Rationale: recordings are local (zero marginal cost, high perceived value), so
  they're pure margin if they convert; and shipping a paid feature *before* AI lets
  us build + validate the paywall plumbing (StoreKit 2, entitlements, restore,
  pricing, trust UX — the ADR 0092 "foundations bar") on a simple, no-eval-risk
  feature instead of betting the first paid tier on AI.
- **Caution — don't gate *all* recording.** It's the audio twin of the free-core
  journal and a strong retention hook. Preferred shape: **basic recording free**
  (the hook), **premium = the richer layer** (unlimited/long takes, take
  organization, and later **AI review of takes** — which folds recording into the
  AI story rather than competing with it).
- **Needs its own ADR when picked up** — it closes off "recording is free core" and
  sets monetization architecture; reconcile with **ADR 0092** (AI as *the* paid
  lever) and the V1 free-core scope. Gating is a wrapper added later, so it does
  **not** block finishing the recording feature (slices).

## Haptics — configurable section (parked, build at finishing-touches)

Decided 2026-07-01. Two motion-tracking haptics are worth adding, but only as an
opt-in that stays out of the way by default. **Build these when putting the
finishing touches on the app**, not now — an empty Settings section with dead
toggles is exactly the scaffolding the launch-readiness gate warns against, so
the Settings UI and the mechanism ship together.

**Settings — dedicated "Haptics" section.** Today there's a single `Haptics`
toggle in the *Feel* section of `SettingsView`, governing gesture-confirmation
taps (`AppSettings.hapticsEnabled`, default **on**) — leave that as the master
switch. Promote it into its own **Haptics section** that gains the two toggles
below, each a new `AppSettings.Key` following the existing `resolvedBool`
default-resolution idiom. Both **default off** (opt-in), and both are gated by
the master `hapticsEnabled` switch.

1. **Playback-tracking haptic** — pulses on **bar-line (downbeat) crossings** as
   the song plays. Follows the real playhead, so it scales automatically with
   playback speed (slowing to 50% doubles the interval — a feature). **Gate it
   exactly like the gridlines toggle (ADR 0051): needs tempo + the "1" set** — a
   bar is meaningless without a downbeat anchor. Single medium-impact per bar for
   V1; no strength gradations. Silent during count-in (position-while-playing
   only) unless device testing says otherwise. *Not* a granularity picker
   (bars/beats/off) — bars-only is the opinionated default.
   - **Open sub-decision, revisit at build time:** a distinct heavier tap on the
     **loop wrap** ("I've heard this N times" by feel). Real value for looped
     practice; ship bars-only first and add as a fast follow if it feels missing.
2. **Scrubbing/drag haptic** — detents felt while **dragging the playhead** as it
   crosses bars/beats/markers (the tactile "notch" of scrubbing past a
   structural point). Distinct from the playback pulse; this one fires only
   during an active scrub gesture. Snap points already exist
   (`WaveformPracticeModel+Snap`), so reuse that geometry.

`Haptics.swift` (`Pocket/Features/Waveform/`) is the existing helper both would
route through.

## UI / polish

- **Metronome sound picker — UI polish (logged 2026-07-24, ADR 0114).** The four-voice picker shipped
  functional (row + inline ▶ audition + selected check, `MetronomeSoundSection`) and the *sounds* are
  approved, but the presentation feels plain — a flat list of Form rows. Ideas when picked up: a richer
  selection affordance (cards / a segmented feel), a small waveform or motion cue while a voice
  auditions, tighter play-button styling, maybe a per-voice glyph. Content and behaviour are settled;
  this is purely a visual pass.
- **iPad layout pass (logged 2026-07-20; IN PROGRESS 2026-07-22, ADR 0105, pocket-167).** Pocket is
  phone-first (iOS 17+, portrait-primary); it *runs* on iPad but the UI doesn't use the extra width —
  a first-pass adaptation, not a feature. **Approach (ADR 0105): write the adaptivity now but keep
  `TARGETED_DEVICE_FAMILY: "1"` for v1** — layouts land dormant (no submission risk), and the eventual
  universal flip becomes a one-line flag change + iPad screenshots. Verification is preview-driven
  (forced `.regular` size class) while the flag stays `1`.
  - **DONE so far:** shared `readableWidth()` cap primitive (`PocketLayout`, verified via
    `AdaptiveLayoutTests`) applied to **Home** and **Library**.
  - **DEFERRED to the universal-flip PR** (only observable on a real iPad, so unverifiable now):
    **(a) sheet iPad sizing** — the OS already form-sheet-caps sheets on iPad; the real win is
    `presentationSizing(.page)` (iOS 18+) for content-heavy sheets so they aren't crammed; and
    **(b) a root master-detail / sidebar `NavigationSplitView`** (its own ADR — `LibraryView` is a
    pushed destination, so the split belongs at the app root, not inside Library).
  Concrete offenders to tackle when this is picked up:
  - **Sheets read sparse.** The many `.medium`/`.large` detent sheets (movable/custom chord,
    song details, loop edit, settings) stretch a single narrow column across the iPad. Consider
    width-capped content, `.form`/two-column grouping, or `.presentationSizing` on iPad.
  - **Single-column layouts leave the width empty.** Home, Library, and the Toolkit hub stack
    vertically; a `NavigationSplitView` (sidebar + detail) or an adaptive grid would earn the space.
  - **The practice/waveform screen** already has a landscape path (ADR 0042) — check how it holds
    up at iPad width and whether the side rail proportions still read.
  - **Regular vs. compact size classes** aren't branched on anywhere; that's the lever (not a
    device check). Prerequisite discipline is already in place: every view draws from semantic
    tokens (brief §3) and layouts are geometry-driven, so this is layout tuning, not a rework.
  Not scheduled; captured so the phone-first assumption is a deliberate, revisitable choice. Own
  design pass (likely its own ADR if it changes navigation structure, e.g. adopting split view).

- **Swappable themes (design-system extension, roadmap).** `DesignTokens.swift`
  was built for this from day one — every colour is a semantic role, and the file
  calls out the seam explicitly ("each role becomes a `Theme` property; the current
  values become the 'teal' theme"). Light/dark already ship (ADR 0062/0063); a
  user-selectable **`Theme`** (beyond appearance) is the natural next step. Shape
  when built: a `Theme` protocol/struct whose properties are the current
  `PocketColor` roles, `PocketColor` reading from the active theme, and a Settings
  picker persisted like `AppearancePreference`. Prerequisite already enforced: every
  view (and every ADR-0065 exercise template, rule **T10**) must draw from semantic
  tokens, never literal hex, so themes reskin the whole app — templates included —
  for free. The template-gallery preview demonstrates the payoff (Red Moon / Light /
  Blood Moon, one control reskins all five templates live). Candidate themes to
  explore: the shipped Red Moon dark/light, and a **Blood Moon** register built on
  the brand vermilion `#C73818` (branding note above). Not scheduled; captured so the
  token discipline that keeps the door open is treated as load-bearing, not optional.

- **Fine-tune the song details sheet.** `SongDetailsSheet` (opened by holding the
  song title on the practice screen) currently stands up the read-first overview on
  a plain SwiftUI `Form`. It works, but the presentation is a first pass. Candidate
  refinements:
  - Richer header treatment (artwork? larger title, tighter artist/album/year line).
  - A more bespoke descriptive layout than a stock grouped `Form` — spacing,
    grouping, and typography tuned to the app's design tokens (brief §3).
  - ~~Decide the relationship with the scroll-area `SongInfoPanel`~~ — RESOLVED
    (ADR 0042): `SongInfoPanel` was removed; `SongDetailsSheet` is now the single
    home for the song's key / mastery / collections.
  - Consider inline editing vs. the current Edit → `SongEditSheet` hop.
  - Surface tempo precision / downbeat state if useful (currently shows rounded BPM).

- **Numeric font — explore alternatives to system monospace (parked 2026-07-16).**
  Today Futura carries all prose/UI while numerals (tempo `1.00×`, BPM, timecodes,
  loop bubble) use system monospace (`Font.pocketMono` = SF Mono) — chosen for
  tabular alignment, since Futura ships no monospaced face (`DesignTokens.swift`
  §Typography, ADR 0061). Question raised: could numerals better fit the Futura
  aesthetic? Framing for whoever picks this up:
  - **Reframe:** alignment needs *tabular figures*, not a monospaced font.
    SwiftUI `.monospacedDigit()` turns on tabular digits for any face that ships
    them (letters stay proportional). So monospace is a *stylistic*, not
    *functional*, requirement — one-family alignment is achievable.
  - **Three strategies:** (1) *Unify* — Futura-flavored digits that still align:
    **Jost** (free OFL Futura revival, has tabular figures), or Futura +
    `.monospacedDigit()` (only works if the cut ships tabular metrics — test, may
    be a no-op). (2) *Deliberate companion* — **DIN Alternate** (on iOS, canonical
    Futura pairing, instrument-readout connotation suits BPM/tempo) or **Avenir
    Next** (on iOS, Futura descendant, strong tabular set). (3) *Keep the contrast
    but make it designed* — the display-face-for-voice / mono-for-data register
    split is a legitimate pattern (reads as studio gear, on-brand); if kept, upgrade
    the default SF Mono to an intentional geometric mono like **Space Mono** (free
    OFL).
  - **Cheap to settle:** DIN Alternate and Avenir Next are both on-device (no
    bundling). Prototype = a font toggle on the rate/timecode/BPM readouts, run on
    device, compare the four against real Futura headings. See the four options
    before arguing.

## Transport bar — deferred pieces of V1 feedback #1 (parked 2026-07-04)

Branch `pocket-093` enlarged the Loop/Marker controls into big circular buttons flanking the
transport while **idle** — **Marker far-left, Loop far-right** — and, on device review, **reverts to
the original compact bar once a loop is active** (small stacked Loop/Marker column + ✕ strip), since
the running loop already reads on the existing Loops panel below. So the mock's "dedicated
active-loop Loops panel" is **resolved by reuse** — no new panel needed. One follow-up remains:

- ~~**Home-settings toggle to swap Loop/Marker sides.**~~ **SHIPPED.** Settings has a
  **"Loop control on left"** toggle (`AppSettings.transportLoopOnLeft`, default off = Marker-left /
  Loop-right) which `WaveformTransportBar` reads to swap the two idle flanking controls. Applies to
  the idle buttons only — while a loop is active the compact column + colour strip keep their sides.
