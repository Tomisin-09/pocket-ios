# ADR 0128 — Exercise creation has one insert path, and it hangs off the plan, not the factory

- **Status:** Accepted
- **Date:** 2026-07-30
- **Amends:** **ADR 0046**'s "single creation path" — which was true of the *derivation*
  (`Exercise.commandAnchored`) but never of the *insert*. Closes the gap
  **ADR 0111**'s song link and **ADR 0120**'s `exerciseCreated` event each hit separately, and fixes
  an **ADR 0116** instrument drop on the automator seam.

## Context

`NewExerciseSheet` has two hosts: Practice ▸ Exercises ▸ **+**, and the metronome automator's **Save
as exercise** seam (ADR 0046's discovery hand-off). Both put up the same sheet and both receive the
same `NewExercisePlan`. But each then did its own thing with that plan — `ExerciseLibraryView.create`
in one file, an inline closure in `MetronomeAutomatorPanel` in another. **The sheet was shared; the
insert was not.** Anything that had to happen at insert time had to be written twice.

The failure that exposed it: because the form is shared, ADR 0111's Songs picker appeared on the
automator's sheet for free, before that file was touched. On that path you could open the sheet, pick
a song, tap Create, and get a perfectly good exercise. No error, no crash, no red test — only the
link quietly absent. From outside, indistinguishable from "the picker is broken", which was the one
part that was fine.

Three things kept it hidden, and they are the reason this needs an ADR rather than a patch:

1. **The compiler can't see it.** Adding a field to `NewExercisePlan` is a compile error in every
   file that *constructs* a plan — but the automator only *reads* one, and ignoring a struct field is
   legal Swift. The compiler flags missing writers, never missing readers, and **consuming is the
   direction that stays silent.**
2. **The feature looks present.** Shared UI over unshared persistence is worse than no UI: it
   advertises something that doesn't happen. Had the picker not rendered, the gap would have been
   obvious on sight.
3. **Nobody walks that path.** Creating a drill from the library is what gets tested. Saving one out
   of a metronome breakdown is niche, so a gap there can sit for months.

The same trap had already been recorded four days earlier, for a different feature: ADR 0120 noted
that `exerciseCreated` could not be emitted from `commandAnchored`, and had to be written at both
inserts. Two features, one shape, no shared fix — which is the argument for making the fix
structural.

## Decision

**Both hosts call one `NewExercisePlan.finalise(in:)`** (in `ExerciseCreation.swift`), which owns
everything between "the player tapped Create" and "the drill exists": the `commandAnchored` build,
the authored-payload encode, the ADR 0121 rhythm bind, the insert, the ADR 0111 song attach, and the
ADR 0120 event. It returns the inserted `Exercise` so a host can stage its own follow-on, and `nil`
for a nameless plan. What stays in each host is only what is genuinely local — the library's
confirmation haptic and its push into the run screen.

**The choke point is the plan, not the factory.** This is the load-bearing half of the decision.
`Exercise.commandAnchored` is the tempting hook and the wrong one: the **preset seeder** calls it
too, so anything hooked there also fires for the six drills a fresh install seeds — six invented
"creations" reported to analytics on every new device. Only the two *interactive* entry points build
a `NewExercisePlan`. **A plan existing means a person just authored this**, which is exactly the
condition creation behaviour wants, so the plan is where such behaviour belongs.

## Consequences

- **New creation behaviour is written once.** The next feature that needs to happen at create time
  has one place to go, and no second insert to remember. `finalise` says so in its doc comment,
  including why the compiler won't catch a lapse.
- **An ADR 0116 bug is fixed as a side effect.** The automator passed neither `defaultInstrument:` to
  the sheet nor `plan.instrument` to the factory, so a bass player's breakdown was silently saved as
  a guitar drill — while the analytics event on the same path read `plan.instrument` and reported the
  instrument correctly. That is precisely the "field read on one path, dropped on the other" shape.
  The automator now reads the profile, as the library does.
- **The automator gains the ADR 0121 rhythm bind** it never called. Benign until now — a `.basic`
  drill has no payload to state a rhythm — but it was a bug waiting on that seam ever producing a
  non-`.basic` drill.
- **`ExerciseCreation.swift` gains a `SwiftData` import** and stops being a pure factory file. Kept
  co-located deliberately: the pure factory and the interactive insert sitting in one file is the
  strongest available signpost for which one the seeder uses and which one new behaviour goes in.
- **`ExercisePlanFinaliseTests` stands for both hosts.** Tests of the shared function now cover a
  path no test could reasonably reach before — the automator's closure was untestable without
  driving the UI. Song link, instrument, payload+rhythm and the empty-name guard are pinned.
- **The two hosts can still drift in what they do *around* the insert** — the library pushes into a
  run, the automator doesn't. That is real difference, not duplication, and it is now the only
  difference left.

## Alternatives considered

- **Hook `Exercise.commandAnchored`.** The one obvious choke point, and rejected for the reason ADR
  0120 already recorded: the preset seeder shares it, so every hook there fires on a fresh install's
  seeded drills. Any fix here has to sit above the factory and below the hosts.
- **Leave two inserts and rely on discipline** — a comment at each site saying "there is another one"
  (which is what shipped for the song link). It works exactly until someone doesn't grep, and the
  failure mode is silent, compiles clean, and looks like a different component's bug. Discipline is
  not a mechanism when the compiler is structurally unable to help.
- **Give the automator its own sheet** so nothing is shared and nothing is implied. Rejected: it
  doubles the authoring UI to fix a persistence problem, and the sharing is the good part — ADR 0111's
  picker appearing on that sheet for free was correct behaviour, wrongly served.
- **Make `finalise` a method on `ModelContext` or a free function taking the plan.** Same effect;
  hanging it off `NewExercisePlan` puts it where a reader of the plan type will find it, and makes
  "you have a plan" the visible precondition.
- **Have the sheet itself insert**, so no host can forget. Rejected: `NewExerciseSheet` would then own
  a context and a store write, and the library still needs the created model handed back for its
  push. The sheet stays a form that returns a value.
