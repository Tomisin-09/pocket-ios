# ADR 0134 — Command moves both ways: the offer after a run can settle lower

- **Status:** Proposed.
- **Date:** 2026-08-01
- **Builds on:** ADR 0045/0046 (the command / working / reach / backoff anchors and the `CommandRamp`
  built from them) · **ADR 0079** (the post-run promote and the completion screen it lives on — this
  ADR widens that offer rather than replacing it) · ADR 0082 (a loop's tempo reads in `%`, an
  exercise's in BPM) · ADR 0075 (the "override, not a copy" field shape and its auto-clear) ·
  ADR 0057 (one write path per model) · ADR 0121 (a command is bound to the rhythm it was measured
  in) · ADR 0117 (the practice log and the per-unit tempo trajectory) · ADR 0015 S5 / `DueScore`
  (mastery is *need*, and drives resurfacing).
- **Non-negotiable:** ADR 0070 — the app never grades. Nothing here measures how well anything was
  played, and nothing moves a stored tempo the player did not see and accept.
- **Scope:** exercises **and** loops, at the shared completion surface. Standalone runs and routine
  blocks under manual advance, exactly the reach ADR 0079 already has.

## Context

`command` is defined, in the app's own words, as *"the fastest you own it clean"*
(`ExerciseTempoSection`'s footer). It is a claim about clean playing — and it is the only anchor in
the tempo model that can only ever ratchet upward.

That is not a gap in the UI. It is encoded three times:

- The post-run offer is bounded `minValue: finished.command + 1`
  (`ExerciseRunView+Actions.swift`, `LoopRunView+Actions.swift`, `RoutinePlayerView.promoteConfig`).
  The control **cannot express a decrease**.
- `PromoteOffer` only answers "is there headroom above command" (`canPromote`) and "how far up"
  (`promotedCommand`). There is no third question.
- The only way down is the library editor's `Stepper` on `ExerciseTempoSection` — a configuration
  surface, entered deliberately, where lowering the number reads as editing the record of an
  achievement. Nobody chooses that four seconds after a run.

### The contradiction this creates

**The ramp completes on a timer, because the app never listens.** `CommandRamp` walks its plateaus
off elapsed bars or seconds; `onRampFinished` fires when the last plateau's hold elapses. Nothing in
that path knows whether a single note was clean. So a run that fell apart completes *exactly* as a
run that was owned — same hook, same Done screen.

On that screen the player is asked **"How clean did that feel?"** and taps two dots out of five. The
next row down then reads:

> **Move command to 106** — You summited it this run — bump the drill up.

The one honest datum on the screen is collected and ignored, and the only tempo action offered is
faster. `mastery` today feeds `DueScore` resurfacing and nothing else. A player who wants to do the
thing every teacher would tell them to do — settle lower and consolidate — has to leave practice,
open the library, and hand-edit a number downward.

### Why the down direction is the point, not a courtesy

Progress on a motor skill is not monotonic, and the productive move after a messy run is frequently
to drop back to a tempo you can play cleanly and stay there until it is boring. A tempo you cannot
play clean is not a command; it is an aspiration that has been written into the field reserved for
what you own. Once that happens the whole model degrades quietly: the ramp warms up to a tempo that
was never earned, the reach derives above *that*, and the drill silently becomes a place where the
player rehearses their mistakes at speed.

The app cannot detect this. Only the player can, and this ADR's entire job is to make saying so
**cheap, well-timed, and free of any implication that it is a failure**.

### The line ADR 0070 draws, and how this stays behind it

The app must not conclude that you played badly. So:

- The trigger is the player's **own** self-rating, entered by them, on that screen, that moment.
- The offer is **opt-in and default off**, exactly as the promote is. The app proposes; it never
  edits a tempo on your behalf.
- Nothing new is measured, recorded, or scored. A settle is a decision, not an event.

Acting on a self-report the player volunteered is not grading. Acting on it *automatically* would
be — see Alternatives.

## Decision

### 1. The row is a **command revision**, not a promotion

`PromoteOffer` becomes `CommandOffer`, with the same two questions asked in both directions:

```swift
enum CommandOffer {
    enum Direction { case raise, settle }
    static func direction(mastery: Int?, command: Int, reach: Int,
                          floor: Int, ceiling: Int) -> Direction?
    static func raisedCommand(reach: Int, ceiling: Int) -> Int     // today's promotedCommand
    static func settledCommand(backoff: Int, floor: Int) -> Int
}
```

`RoutineBlockDoneView.PromoteConfig` becomes `CommandConfig`, gaining a `direction` and widening its
`minValue`/`maxValue` (§4). The stepper, the toggle, and the single-`Continue` commit are otherwise
the surface that already ships — this is one row changing what it can say, not a new screen.

**Renaming is not cosmetic.** `promoteTo:` runs through `commitCompletion` on both run screens and
`RoutinePlayerView`; leaving the name in place would mean a parameter called `promoteTo` carrying a
demotion, which is precisely the kind of thing that reads as correct for a year.

### 2. The mastery tap chooses the direction, live, on the same screen

`RoutineBlockDoneView` already holds the rating in `@State private var mastery`, so the row can
respond to the dots as they are tapped — no new question, no new control:

| Rating | Row |
|---|---|
| **1–2** | *Settle* — offers to move command **down** (§3). |
| **3** | **No row.** |
| **4–5** | *Raise* — today's promote, unchanged, when there is headroom. |
| **unrated (`nil`)** | *Raise* when there is headroom — **exactly today's behaviour**. |

Three properties of this table are load-bearing:

- **Unrated behaves as it does today.** A player who ignores the dots — every existing user — sees
  the screen they already know. This ADR adds a path; it removes none.
- **3 is a dead band, deliberately.** "Fine" is not a request to change anything. Offering both
  directions at once would turn a completion beat into a quiz, and offering *either* would put the
  app's thumb on a scale the player just declined to tip.
- **The rating read is the one just entered, not the stored one.** `initialMastery` pre-fills from
  the model, so a drill rated 5 months ago would otherwise offer to raise after a run the player has
  just rated 1. The live `@State` is the honest read and it is already there.

### 3. The settle default is the backoff — the tempo the run **already ended on**

The default target is the floor `CommandRamp`'s tail settles to — `command − (reach − command)`,
floored at working. For exercises that is `Exercise.derivedBackoff`, which already exists.

**Loops have no such accessor and slice 1 adds one.** A loop's backoff is computed *inside*
`CommandRamp.plateaus`, in the percent domain `LoopCommandRamp` converts to, and is reachable from
the model only as the optional `backoffSpeedOverride` pin. So `Loop` gains a derived
`backoffSpeed` — `TempoStretch.backoffBPM` over `percent(command)`, `percent(targetSpeed)` and
`percent(rampFloor)`, converted back — and `LoopCommandRamp` is pointed at it. This is the same move
`Loop.rampFloor` already documents (ADR 0129 sub-decision 1, extended to loops): derive it once on
the model so the number the offer proposes and the number the ramp plays cannot drift. Derived, never
stored; no field, no migration.

This is the right default for one reason that is worth stating precisely: **the run just played
it.** `CommandRamp`'s backoff plateau is the last thing that sounded before the Done screen appeared,
minutes ago. So the offer describes something that happened, rather than proposing a number the app
invented:

> **Settle command at 84** — you finished the run there.

Not *"you struggled"*, not *"try something easier"*. The app states a fact about the last two
minutes and lets the player decide what it meant. That framing is the difference between an offer
and a verdict, and it is available for free because the ramp already has a tail.

**When `includeBackoff` is off** the run has no tail, so there is no such fact. Fall back to
`TempoStretch.backoffBPM(command:target:floor:)` computed anyway — the same number, just not one the
player heard — and drop the second clause of the copy.

### 4. The range is the instrument's, not the backoff's

- **Settle:** `bpmRange.lowerBound … command − 1` (exercises, `30…`), `percentRange.lowerBound …
  command − 1` (loops, `25…`).
- **Raise:** unchanged — `command + 1 … ceiling`.

**Not floored at the derived backoff**, even though that is the default. The backoff sits roughly one
reach-width below command, which is a nudge; the case this ADR exists for is sometimes a player who
has been kidding themselves for a month and needs to drop twenty BPM, not four. A range that caps the
step back at one reach-width would quietly encode the belief that big retreats are illegitimate —
which is the belief being corrected.

### 5. Opt-in, default off — and the copy **is** the feature

The toggle defaults off and a settle is committed only through the existing single `Continue`. The
app never lowers a tempo on its own.

Everything else here is wording, and this section exists so that is not treated as decoration to be
trimmed at build time. There is no mechanism that makes a player honest; there is only framing that
makes honesty costless. Two strings carry it:

- **The settle row** names the step back as the technique it is, in the register of *"clean beats
  fast"* — never as a concession, a setback, or a suggestion to try something easier.
- **The mastery caption** (today: *"Optional — the planner resurfaces well-learned drills on its
  own."*) gains the invitation. It is the only place the player learns that rating honestly does
  anything for them beyond scheduling.

Neither is a nag: no second prompt, no confirmation, no follow-up if declined.

### 6. Settling has to move the floor with it

This is the part that breaks silently if it is left to call sites. `Exercise.promoteCommand(to:)`
has a mirror:

```swift
func settleCommand(to tempo: Int)
```

which does three things beyond the assignment:

- **Pulls the working floor down when the new command has passed it.** `Exercise.rampFloor` returns
  `workingTempo` **raw** once a command is measured, and `CommandRamp.plateaus` builds a warm-up only
  when `command > working`. A command settled to at or below working therefore produces a ramp with
  **no warm-up at all** — it opens at command and climbs. That is the exact opposite of what the
  player just asked for, and nothing errors. So when `tempo <= workingTempo`, re-derive
  `workingTempo = TempoStretch.warmupFloorBPM(forCommand: tempo)`.

  **This step is exercises-only, and the asymmetry is worth naming.** `Loop.rampFloor` is
  `min(command − measuredWarmupGap, speed)`, so it *forces* a gap below command and can never invert
  — a settled loop keeps its warm-up with no intervention. The exercise model is the one that trusts
  a stored `workingTempo` to stay below a value it has no control over, which is exactly why this
  fails silently there and nowhere else. Slice 1 does not "fix" `Exercise.rampFloor` to match; that
  would change the ramp every existing exercise plays, which is a much larger blast radius than the
  bug being avoided.
- **Clears a caught-up backoff pin.** `plateaus` appends the tail only when `backoff < command`, so a
  `backoffTempoOverride` at or above the new command silently deletes the backoff. Clear it, reverting
  to the derived value — the same shape and the same reason as `promoteCommand`'s reach-pin clear
  (ADR 0075).
- **Rebinds `commandNotesPerBeat`.** A settled command is still a measurement, taken in this run's
  rhythm (ADR 0121). Promotion already does this "so the binding can't be forgotten at a call site";
  the identical argument applies here.

**A pinned reach is left alone.** `targetTempoOverride` was above the old command and is still above
the new one, so the invariant holds and there is nothing to fix. Clearing it would throw away a goal
the player set for no reason.

The loop mirror (`Loop.settleCommand(to:)`) is the backoff-pin clear and the rhythm rebind only, per
the note above. It is worth observing that `LoopRunView+Actions` already clamps
`working = min(command, …)` in its manual nudges: the working-below-command invariant is real, is
currently enforced at a screen rather than on a model, and `commitCompletion` writes `command`
straight past it. Putting the settle in the model is what keeps that from becoming a second bug.

### 7. Nothing already built punishes the honest answer

Checked rather than assumed, and recorded here so it stays true:

- **`TempoTrajectory` already handles it.** Its own documentation states that *"a trajectory that
  goes down is not reported as a regression — the player is the judge of what a slower day meant"*,
  and `change` is documented as *"a difference, never a verdict"*. No change needed. The data layer
  was built for this before the offer was.
- **`TempoRecord` cannot be fooled or dented.** It counts only `bpm > previous`, so a settle creates
  no record and erases none — the previous best stays in the log as the fact it was.
- **`DueScore` rewards the honest rating.** `masteryTerm` treats a low rating as more need, so rating
  a run 2 resurfaces the drill sooner. Honesty already buys the player something. Nothing to build;
  something to not break.
- **Progress renders a downward step identically.** No red, no down-arrow, no "regression" treatment,
  no offer to explain it. A chart that flinches teaches people not to settle, and would undo §5 in a
  surface the player did not even have open at the time.

### 8. Loops by symmetry, differing only in unit

The loop completion path is the same code (`RoutineBlockDoneView`, `PromoteOffer`, an identical
`commitCompletion`), so the settle arrives there with the offer. Most of the differences are ones
that already exist: `%` rather than BPM (`TempoUnit.percent`, ADR 0082) and `TempoMath.percentRange`
rather than `bpmRange`. The one genuinely new piece is the derived `Loop.backoffSpeed` from §3 —
without it the loop offer would have to re-derive, in a second place, a number `CommandRamp` already
computes internally.

Building it for exercises only would leave two completion screens that look identical and behave
differently.

### 9. What this deliberately does not cover

- **A manually stopped run still offers nothing.** ADR 0079 §1 keeps a manual stop silent, and that
  stands. The player who bails at bar eight gets no Done screen and therefore no settle. This is
  acceptable because the *main* case is already covered — the ramp completes regardless of how it
  sounded (see Context), so the bad run that was played to the end lands on the Done screen anyway.
  Raising a completion surface over an abandoned run reopens the naggy-trigger question 0079 settled,
  and is not worth reopening for the residue.
- **Auto-advance in a routine still skips the Done screen**, so it offers neither direction. Same
  asymmetry, same reasoning as ADR 0079 §7: auto-advance means "don't stop me."
- **Mid-run settling is out of scope** and gets its own ADR — see Build slicing.

## Build slicing

**Slice 1 — the symmetric offer.** Everything in §1–§8: `CommandOffer` and its direction table, the
`CommandConfig` shape change, both run screens and `RoutinePlayerView`, `settleCommand` on `Exercise`
and `Loop`, and the copy. No `@Model` field is added and no stored value changes meaning, so there is
no migration and the whole slice is device-testable against existing data.

**Slice 2 — mid-run settling, deferred to its own ADR.** Realising it is a mess happens in bar
twelve, not on the Done screen, and today the only response is to stop. A transport action that drops
the live run to its backoff plateau and keeps playing is the strongest version of this idea — and it
touches `CommandRamp` mid-flight, re-anchors the grid, and has to answer to ADR 0131's tempo-change
warning (a settle *is* a tempo change, and an unannounced one would be exactly what 0131 was written
to prevent). That is an audio-engine ADR, not this one. Parked in `docs/backlog.md`.

**Where the code goes** — `RoutineBlockDoneView.swift` is at **325** lines and
`RoutinePlayerView.swift` at **382**, against the 400-line cap that CI's `--strict` lint enforces.
The direction table and both `settledCommand`/`raisedCommand` are pure and live in `CommandOffer`
(renamed from the 29-line `PromoteOffer`, with room); if the Done screen's row grows past the cap,
the promote/settle row splits into `RoutineBlockDoneView+CommandRow.swift` rather than the copy being
compressed to fit.

## Consequences

- **No stored field, no migration owed.** Every value involved — `commandTempo`, `currentTempo`,
  `backoffTempoOverride`, `commandNotesPerBeat`, `mastery` — already exists and keeps its meaning.
- **A shipped surface changes behaviour**, which is the risk here. Anyone who taps 1–2 dots now sees a
  different row than they did yesterday. The unrated path is byte-identical, which bounds it.
- **New pure surface that must be exhaustively tested** (AGENTS.md — this is the logic that breaks
  silently): the direction table across `nil` and 0–5, at a command with no headroom and at the range
  floor; `settledCommand` when `includeBackoff` is off; both range bounds in BPM and `%`; the
  working-floor pull-down; the backoff-pin clear; the rhythm rebind; the new `Loop.backoffSpeed`
  agreeing with the tail `CommandRamp.plateaus` actually emits (the whole point of deriving it once);
  and `plateaus` keeping its warm-up **and** its tail after a settle at, just above, and well below
  the old working floor. Model-level tests build `Exercise`/`Loop` **uninserted** — inserting a graph
  SIGTRAPs in the XCTest host (`docs/swiftdata-gotchas.md`).
- **`PromoteConfig` changes shape**, so both run screens, `RoutinePlayerView`, and the
  `RoutineBlockDoneView` previews move together.
- **Nothing new is logged.** No practice-log field (ADR 0117), no analytics event — the closed enum
  (ADR 0120) stays closed. The next run's log row carries the new command, which is the whole record
  a settle deserves.
- **ADR 0079 is widened, not reversed.** Its trigger (§1), its surface (§2), its single-commit rule
  (§7) and its auto-advance asymmetry all stand unchanged; only the offer's direction opens up.
- **ADR 0070 is intact.** The app still measures nothing and grades nothing. It asks a question it
  already asked, and now does something useful with the answer the player chose to give.

## Alternatives considered

- **Lower command automatically on a low mastery rating.** Rejected, and it is the tempting one. It
  converts a self-report into a consequence, and the immediate second-order effect is that players
  stop rating honestly — which destroys both this feature and `DueScore`'s resurfacing at once. The
  rating has to stay costless to stay true. It is also the app forming a verdict from a number the
  player gave it in confidence, which is ADR 0070's line even though no measurement occurred.
- **Infer it from the playing — missed notes, timing drift.** Rejected outright: ADR 0070, and there
  is no listening path to build it on anyway (the tuner is the only mic tap, and Apple Music audio is
  DRM-opaque per ADR 0001).
- **A separate "back off" button beside the promote toggle.** Rejected — two competing CTAs is the P3
  lesson ADR 0079 already learned and designed away, and permanently displaying both directions
  frames every completion as a fork in the road rather than a finished run.
- **A manual segmented control (Raise / Keep / Settle) instead of keying off mastery.** Rejected —
  it is a third question on a screen whose entire design is one primary with everything else optional,
  and the player has already answered it by tapping the dots.
- **Floor the settle range at the derived backoff.** Rejected — §4. It caps the retreat at about one
  reach-width and encodes the idea that only small steps back are legitimate.
- **Leave it in the library editor and just improve the copy there.** Rejected — the moment is wrong
  by an order of magnitude. The decision is live for about four seconds after a run and the editor is
  a surface you enter on purpose, later, to configure something.
- **Decay `command` automatically after N days unpractised.** Rejected — that is the app forming an
  opinion about the player while they are not there, and `DueScore` already expresses "this needs
  attention again" through time without touching a stored claim about what they own.
- **Log the settle as its own event, or add a practice-log field for it.** Rejected — ADR 0117's log
  records what was *played*. A revision is a property of the drill, and the next run's row carries the
  new tempo. Recording retreats separately would also build the exact dataset ADR 0070 says the app
  should not be keeping.
- **Ship exercises first, loops later.** Rejected — §8. They are literally the same completion screen;
  splitting them creates a difference the player would read as a bug.
