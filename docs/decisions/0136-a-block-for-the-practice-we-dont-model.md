# 0136 — A block for the practice we don't model (freeform exercises)

- **Status:** Accepted. **Slices 1 and 2 built 2026-08-04** (`pocket-227-freeform-blocks`). Build
  notes at the end — including one correction to the Context below.
- **Date:** 2026-08-01
- **Builds on:** ADR 0068 (revised) / 0065 (`ExerciseTemplate` as the single user-facing axis, closed
  and immutable at creation), ADR 0104 (ear training as a *mode* — the pattern this ADR deliberately
  does **not** follow, and why), ADR 0117 (the practice log — one row per unit-run), ADR 0134 (the
  self-rating means something), ADR 0015 S5 / 0073 (`DueScore`, goal resolution via `SkillFamilyMap`),
  ADR 0128 (one insert path for created exercises), ADR 0112 (freemium — free runs, Pro authors),
  ADR 0070 (Pocket never grades the player), ADR 0036 / 0012 (the SwiftData field-discipline rules).
- **Reopens, deliberately:** the "no free-text / custom template yet (deferred)" note in
  `ExerciseTemplate`'s own doc comment, which anticipates exactly this ADR: *"a new template is a
  deliberate, ADR-worthy addition with code behind it, never an open extension point."*

## Context

Pocket cannot model every exercise a guitarist will ever do, and trying is a Sisyphean content
treadmill — each new drill type costs a template, a renderer, an editor, and a planner mapping. But
the practice a player does *outside* the app is still practice: sight-reading, transcribing, working
a piece by hand, a teacher's assignment, singing while playing, a technique this app has no surface
for. Today none of it exists as far as Pocket is concerned, which means a player's log and their
mastery picture are both quietly incomplete — the app reports on the fraction of practice it happens
to model, and the fraction shrinks the more serious the player is.

The cost of covering it is much lower than it looks, because **the progress spine is already
content-agnostic**. `PracticeRun` (ADR 0117) records `unitUID` + duration + optional tempo and never
asks what the unit renders. `Exercise.mastery` is pure player input, and ADR 0134 just made that
rating drive the command offer as well as `DueScore`. `Exercise.lastPracticed` + `markPracticed()`
supply the time half of dueness. None of that needs to understand a drill to work on it.

There is even a payload field already in place: `Exercise.notes` (`String = ""`, *"Optional free-text
notes about the exercise"*) exists on the model and is **surfaced nowhere in the app** — no editor,
no reader. It has been dead storage since it was added.

## Decision

- **F1 — A freeform block is a new `ExerciseTemplate` case (`.freeform`), not a new model and not a
  run mode.** It is the deliberate, ADR-worthy addition the enum's doc comment anticipates. A
  separate `@Model` would cost a parallel library surface, a fourth unit reference on `RoutineItem`,
  a parallel `PracticeRunKind`, and its own favourites/journal/recording wiring — all to express
  "an exercise whose content we don't model," which is an exercise.

- **F1a — And specifically *not* the ADR 0104 pattern, though that was the obvious analogy.** Ear
  training is a **mode** because it re-runs material the player already owns: its unit is the `Loop`.
  A freeform block has no underlying material — it *is* the new thing — so there is nothing to re-run
  differently and no unit to hang a mode on. The evidence that this distinction is load-bearing is in
  the enum already: `ExerciseTemplate.earTraining` exists but was removed from `creatable` on
  2026-07-22 because *"ear training shipped as a loop mode, not an exercise template (ADR 0104)"*.
  The template route was tried for ear training and correctly abandoned; the same reasoning points
  the opposite way here.

- **F1b — A closed case with a free-text *payload* is not a reopened taxonomy.** The thing
  `ExerciseTemplate`'s doc warns against is a *free-text template axis* — the old `category` field,
  where every user coined their own kind and nothing downstream could reason about any of it.
  `.freeform` is one more closed, curated case that the library, the picker and the planner all
  recognise exactly. The openness is confined to the player's prose inside it, which no code branches
  on. That boundary is the whole decision, and any future pressure to let players *name new
  templates* is a different ADR that this one does not license.

- **F1c — Not `.basic`.** `basic` is click-first by definition (*"A plain tempo drill on the
  click"*), and it is the fallback an unrecognised stored template decodes to — overloading it would
  make "the drill we couldn't parse" and "the drill the player defined" the same value. They also
  need to differ in the library section, in the create picker's copy, and in F5's planner treatment.

- **F2 — Its payload is the player's own words, in the field that already exists.**
  `Exercise.notes` becomes the freeform block's content: a multi-line instructions field, authored at
  creation and editable after, shown on the run screen so the player can read what they told
  themselves to do. `NewExercisePlan` carries it like the other templates' payloads (it is a plain
  attribute, not a relationship, so unlike `linkedSongs` it can be set at insert). **No new stored
  field and therefore no migration** — the field has been there all along.

- **F2a — `.freeform` gets a `BespokeEditor` case, because a text field is authoring.** It is the
  first template whose payload is prose rather than musical structure, which is precisely why it
  needs its own editor branch rather than falling through to the plain tempo settings.

- **F3 — No tempo and no ramp.** A freeform block is *a duration and your own instructions*; most of
  what belongs in one (sight-reading, transcribing, a teacher's assignment) has no BPM at all. The
  create step skips the command-tempo stepper, `targetTempo` keeps its schema default and is never
  read, no `CommandRamp` is built, and the run logs `tempoBPM: nil` — which `PracticeRun` already
  documents as the honest value when *"the drill states none"* (ADR 0121). A player who wants a click
  has the standalone metronome; wiring an optional click into this surface is a follow-up, not slice 1.

- **F4 — The run is ear training's shape, plus the one screen ear training omits.** From
  `EarLoopRunView`: no ramp and no natural end, so the clock starts on **appearance** rather than on
  a transport action, and an explicit **Done** is a *genuine completion, not a hand-stop* — the
  player deciding they're finished **is** the end of the run. Skip and exit log nothing. The
  difference: an ear block shows no `RoutineBlockDoneView` because there is nothing to grade, but a
  freeform block **does** show it, because the self-rating is the entire tracking payoff and the
  input `DueScore` and ADR 0134 both read. Nothing on that screen grades the playing (F8); the player
  rates it, as everywhere else.

- **F4a — It logs as `PracticeRunKind.exercise`, with no new case.** It *is* an exercise; the log
  names the unit, and there is no tempo trajectory to protect from muddying (the reason `.earLoop`
  earned its own case). Minutes, days and sittings all fall out unchanged.

- **F5 — Due-scored, never goal-resolved.** Two separate planner behaviours, and the split is the
  containment:
  - **Goal-invisible for free.** `SkillFamilyMap.skillsByTemplate` omits `.basic` and `.warmup`
    deliberately, and a template absent from that map *"never resolves a technique goal"*. `.freeform`
    is likewise absent — the app knows nothing about the content, so it cannot honestly claim the
    block serves any skill. **No new rule is needed** for this; it is the existing rule applied.
  - **Due-scored like any exercise.** `Exercise.lastPracticed` is stamped by `markPracticed()` on
    completion and `mastery` is set on the Done screen, so `goalWeight × dueness × (1 − mastery/5)`
    works on it unmodified. Note this requires *not* extending the `.warmup` exclusion:
    `PracticePlanner.library` filters warm-ups out of the candidate pool entirely
    (`.filter { $0.template != .warmup }`), and `.freeform` must **not** join that filter.
  - Net effect: a freeform block can be picked up by a goal-less session and resurfaces on time and
    rating, but never claims to satisfy a stated goal.

- **F6 — It is a real library unit, created through the one insert path (ADR 0128).** Not a
  routine-local placeholder: the player revisits a freeform block, re-rates it, and accumulates
  history on it, none of which a block with no `unitUID` can do. `.freeform` joins
  `ExerciseTemplate.creatable`, and creation flows through `NewExercisePlan.finalise(in:)` like every
  other template — new creation behaviour goes *there*, never on a second path. Because it is an
  exercise, it appears in `AddRoutineUnitSheet`'s **Exercises** bucket under its own template section
  automatically; it needs no bucket of its own.

- **F7 — Authoring, so Pro (ADR 0112).** Creating one is authoring; running an existing one is free,
  the same line every other template sits on. It is also a strong Pro argument in its own right:
  your whole practice lives here, not only the parts we modelled.

- **F8 — The app knows nothing about the content, so it says nothing about it (ADR 0070).** No
  inference of what a freeform block trains, no suggested skills, no "we noticed you practise X".
  Mastery is self-rated as everywhere else. The one-line rule: **Pocket holds the block; the player
  fills it.**

- **F9 — Naming: "freeform", not "empty".** *Empty block* is the right internal shorthand and the
  wrong user-facing word — a block labelled empty reads as broken or unfinished, and the player is
  about to put the most personal practice they have into it. The section and card should name what it
  is *for*, not what it lacks.

## Consequences

- **The log stops under-reporting.** Once off-app practice can be recorded, minutes/days/sittings
  describe the player's actual week rather than the modelled slice of it. This is the point, and it
  also means historical comparisons straddle the change — an install that adopts freeform blocks will
  show a step up in practice time that isn't a behaviour change.
- **A dead field wakes up.** `Exercise.notes` gains its first reader and writer. Anything that
  round-trips an `Exercise` (`UnitDuplication`, presets, bulk import) should be checked for whether
  it carries `notes` — a duplicate that silently dropped the player's instructions would be a
  particularly bad failure, since the instructions *are* the exercise.
- **The library gains a section that can grow unboundedly.** Freeform blocks are cheap to make and
  invisible to goal resolution, so the failure mode is a drawer of vague one-liners diluting the
  library and the goal-less session pool. F5's due-scoring is the only pressure against that, and it
  is a weak one; worth watching before adding any bulk-create affordance.
- **Two exercise templates now have no bespoke musical content** (`basic` and `freeform`) but differ
  in every downstream behaviour. The distinction has to survive in copy, or players will make basic
  drills when they mean freeform ones.
- **It is the honest answer to "why isn't <technique> in here".** Which is also the risk: it can
  become the excuse not to model something that deserves a real surface. A freeform block is a
  container for practice Pocket *shouldn't* model, not a landfill for the backlog.

## Alternatives considered

- **A mode, following ADR 0104.** Rejected (F1a) — a mode needs existing material to re-run, and this
  has none.
- **Its own `@Model`.** Rejected (F1) — a parallel everything to express an exercise.
- **Reuse `.basic` with a filled-in `notes` field.** Rejected (F1c) — collides with the
  unknown-template fallback, and the two need to differ in the planner and in the create copy.
- **A free-text / user-named template axis.** Rejected, and specifically ring-fenced (F1b). That is
  the old `category` field the closed-set discipline replaced; nothing downstream could reason about
  it. Free prose *inside* a closed case is a different thing.
- **A Journal entry instead of a unit.** Rejected — the Journal captures moments; this needs to be
  repeatable, re-ratable, and addable to a routine, which is a unit's job. (The two compose: a
  freeform block has a journal like any other exercise.)
- **Let the player tag a freeform block with a skill family so goals can resolve it.** Rejected for
  slice 1 (F5/F8) — it invites the app to claim a block serves a skill on the strength of a label
  nothing verifies, and goal resolution is the one planner behaviour where a wrong claim costs the
  player a misbuilt session. Revisitable if freeform blocks become a large share of a player's library.
- **A stopwatch or a countdown instead of open-ended + Done.** Rejected (F4) — ear training already
  demonstrated the third option, and a countdown would impose a length on practice the app knows
  nothing about, while a stopwatch's stop is a hand-stop rather than a completion (the skippable-Done
  trap ADR 0117 already had to correct for).

## Slices

- **Slice 1 — the template, its payload, its run.** `.freeform` on `ExerciseTemplate` (+ `creatable`,
  `displayOrder`, blurb/icon), the `BespokeEditor` case and the `notes` field surfaced in create and
  detail, `NewExercisePlan.notes`, and the run screen: instructions shown, clock on appearance,
  explicit Done → `RoutineBlockDoneView` for the rating, logging `.exercise` with `tempoBPM: nil`.
- **Slice 2 — routine and planner.** Confirm the Exercises bucket lists it, that
  `PracticePlanner.library` does **not** filter it out, that `SkillFamilyMap` omits it, and that
  `DueScore` behaves — mostly verification, since F5 is the existing rules applied rather than new
  ones. Unit tests for the two planner claims, which are the parts that would break silently.

## Parked follow-ups (not sliced)

- **An optional click** on the freeform run, for blocks that do want a pulse (F3).
- **A "New empty block" action inside `AddRoutineUnitSheet`**, creating a freeform unit without
  leaving routine-building. A third creation host, so it must route through
  `NewExercisePlan.finalise(in:)` (ADR 0128) rather than growing its own path.
- **Duration hints** — a suggested minutes value on the block, so a freeform unit can be priced by
  the session builder (ADR 0129) instead of estimated at a default.
- **A take against a freeform block** as evidence of the work (ADR 0069 already allows recordings on
  an exercise; nothing extra is needed, so this is a copy/discoverability question).

## Build notes — slices 1 and 2 (2026-08-04, `pocket-227-freeform-blocks`)

**0. A correction to the Context: `Exercise.notes` was not dead storage.** This ADR says the field is
*"surfaced nowhere in the app — no editor, no reader"* and *"has been dead storage since it was
added"*. That was wrong at the time of writing: `ExerciseDetailSheet` already read **and wrote** it,
as an editable **Description** section with its own footer. The reasoning survives intact — F2 still
holds, there is still no new stored field and still no migration — but two consequences change:

- The *"a dead field wakes up"* consequence is really *"a field changes meaning depending on the
  template"*. On every other template `notes` is a note **about** an exercise; on a freeform block it
  **is** the exercise. That is now expressed in the one place it shows: the detail sheet's section is
  titled *Instructions* with a different prompt and footer for `.freeform`, over identical storage.
- The `UnitDuplication` worry the same paragraph raises was **already handled** — `duplicated(named:)`
  has always carried `notes`. So the failure the ADR calls "particularly bad" cannot happen, and no
  change was needed. A test pins it anyway, because the reason it matters is new.

**1. Everything F1 promised about a case being cheap held, and the compiler proved it.** Adding
`.freeform` broke exactly **five** exhaustive switches, every one of which had to answer for itself:
`AccessPolicy.authoringTier` (→ `.pro`, F7), `ConfigureExerciseForm.fretboardContent` (→ `nil`), and
three in `ExerciseShapeSheet`. No model, no parallel library surface, no fourth unit reference on
`RoutineItem`, no `PracticeRunKind` case. That is the F1-vs-`@Model` argument, measured.

**2. F5 needed no planner code at all — which is exactly why slice 2 is a test file.** Both halves are
absences, and absences are invisible to review:

- Goal-invisibility is `.freeform` **not** appearing in `SkillFamilyMap.skillsByTemplate`. Adding a
  row there later would quietly start claiming skills the app cannot verify.
- Due-scoring is `.freeform` **not** joining `PracticePlanner.library`'s `template != .warmup` filter.
  Adding it there would stop blocks resurfacing, with nothing to notice.

`FreeformBlockPlannerTests` asserts the first across the **whole** taxonomy rather than a sample, so a
future row fails a test rather than shipping a silent claim. It also covers the free consequence F5
didn't name: `SkillFamilyMap.taggableTemplates` derives from the same map, so *"Your own practice"* is
never offered as a loop skill tag — which would have been a skill claim by the back door.

**3. One router, because a missing branch is not a compiler error.** A freeform block reaches
`RoutinePlayerView`'s `.exercise` payload like any exercise, and the library has two more entry points
into a run. Three call sites, three chances to forget — and forgetting wouldn't crash, it would hand
the player a tempo ramp for a drill that has no tempo. So `ExerciseRunScreen` is the one place that
chooses between `ExerciseRunView` and `FreeformRunView`, and all three hosts go through it. This is
ADR 0128's lesson applied to *running* rather than to creating: same trap, same shape of fix.

**4. Create is gated on non-empty instructions.** Not stated in the ADR, and it follows F2 + F9 rather
than extending them: the instructions *are* the content, so a block with none is precisely the empty
block F9 refuses to ship. It reuses the exact rule ADR 0086 set for Chords — a template whose payload
starts empty gates Create on that payload — so it is a precedent applied, not a new one.

**5. F3 in practice: the create step loses two sections, not one.** The ADR names the command-tempo
stepper; the **time signature** picker has to go with it, since its own footer says it *"sets the
run's accents and count-in length"* and a freeform run has neither. Both were lifted into one
`tempoAndMeterSections` so the exception reads as a single `if` rather than as scattered conditions.
The values still exist on the model — `commandAnchored` derives them from a command the form never
shows — and nothing reads them, which is what F3 actually asked for.

**6. A freeform block takes a planned length, via ADR 0141's existing chrome.** Not in this ADR, but
it is unavoidable once a freeform block can be a routine block: a session sized in blocks (ADR 0129)
whose third block has no end isn't a session. `rampLessBlockLength` applies unchanged, with
`cycleSeconds: 0` and `isPlaying: false` — with no audio there is no phrase to protect, so the block
finishes at the planned moment rather than waiting for a loop to come round. Open-ended standalone, as
everywhere else. Note this is *not* the parked "duration hints" follow-up, which is about **authoring**
a suggested length; this is the session's length reaching a block that had none.

**7. F4's Done screen needed no special case, and that is a small vindication of F4a.** The gate in
`RoutinePlayerView.finishedBlock` is `!stage.kind.isRampLess` — and a freeform block's stage kind is
`.exercise`, which is not ramp-less. So it lands on `RoutineBlockDoneView` for the rating by the
ordinary path, while `.earLoop` and `.improviseLoop` skip it by theirs. Had F4a minted a new
`PracticeRunKind`, this would have been a branch.

**Verification:** `swiftlint --strict` clean, generic-simulator build clean, **1812 tests pass**
including 10 new `FreeformBlockPlannerTests`. Two existing `ExerciseTemplateTests` cases were updated
rather than worked around — they asserted the pre-0136 `creatable` list and that every template
outside the musical families has no bespoke editor, both of which this ADR deliberately changes.

The run screen itself is a **look** claim and wants the Xcode preview (`FreeformRunView` ships one)
plus a device pass before it is called done.
