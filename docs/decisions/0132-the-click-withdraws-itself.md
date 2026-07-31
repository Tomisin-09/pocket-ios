# ADR 0132 — The click withdraws itself: silent bars as the default practice

- **Status:** Proposed.
- **Date:** 2026-07-31
- **Builds on:** ADR 0043 (the standalone metronome and its sample-clock grid) · ADR 0048/0052 (the
  count-in and its beat boundary) · ADR 0071 R5 (per-slot click voicing — `scheduledLevel` is the one
  place a click's level is decided) · ADR 0045/0046 (the command ramp and its plateaus) ·
  **ADR 0131** (the tempo-change warning — §6 fixed the precedence rule this must obey, and §5
  specified the engine state this now pays for) · ADR 0070 (never grade the player) · ADR 0011/0036
  (the enum-attribute migration rule) · ADR 0075 (the "override, not a copy" field shape).

## Context

The metronome never stops. Every drill in this app is played against a click that is present for
every beat of every bar, and that is a worse practice tool than it looks.

Constant augmented feedback creates dependence on it. A player who only ever plays with the click
develops timing that is *reactive* — corrected continuously against an external reference — rather
than internal. Withdrawing the reference intermittently is the research-backed fix, and it is what
every teacher does by hand: play four bars with me, play four without, and we will both hear what
happened. The moment the click returns is the whole event. If you drifted, you hear it; if you
didn't, you hear that too.

Nothing about this needs new audio machinery. `scheduledLevel(forTick:ticksPerBeat:)` already
resolves a per-tick click level and already returns `nil` for a slot that should not sound — that is
how a strum pattern's rests work today (ADR 0071 R5). A withdrawal is the same mechanism pointed at
whole bars instead of pattern slots: the grid keeps running, the phase never moves, and some ticks
simply don't sound. The click comes back exactly where it would have been, because it never actually
left the schedule.

**This is the other half of ADR 0131, and it was always going to be.** That ADR made the click able
to *announce* a change; this one lets it *disappear*. They are the same seam — the click scheduled
against the near future — pointing in opposite directions, and 0131 §6 already fixed the rule that
keeps them from cancelling out: a warning bar is never silenced. Withdrawing the click is only safe
in an app where the click can also announce itself.

**It stays clear of ADR 0070.** The app removes its own signal and then says nothing. It does not
measure the drift, display the drift, score the return, or keep a record of how you did. The player
hears what happened and draws their own conclusion — which is the opposite of grading, and is in
fact the app declining to look.

## Decision

### 1. Withdrawal is a ladder, not a switch

Three levels, in one direction — thinning, never chopping:

| Level | What sounds |
|---|---|
| `full` | Every tick, exactly as today (meter accents, subdivisions if armed). |
| `downbeatOnly` | Beat 1 of the bar, at `.accent`. Every other tick silent. |
| `silent` | Nothing. |

`downbeatOnly` is the load-bearing middle rung and the reason this isn't a two-state feature. Going
from a full click straight to nothing is a cliff: the player loses the pulse and the bar, and by the
time the click returns they have no idea whether they drifted or simply lost count. A bar with only
its downbeat still tells you *where you are* while withdrawing the thing that was doing the work —
it takes away the crutch without taking away the map. It also costs nothing: it is one more branch
in the same resolver, and it gives the tiers below something to distribute.

### 2. One cycle length — eight bars — and three distributions

The cycle is **always eight bars**, from the first musical downbeat, repeating for the run. Only the
mix changes:

```
                bars 1-2   3-4   5-6   7-8
gentle           full     full   full   downbeat
standard         full     full   downbeat  silent
deep             full   downbeat silent  silent
```

Three properties fall out of fixing the length, and all three are deliberate:

- **It lands on phrase boundaries.** Eight bars is the unit almost everything in this app's library
  is actually built in. A six- or ten-bar cycle would drift against the music and the return would
  land somewhere arbitrary, which is precisely where it carries no information.
- **The return is always in the same place.** The player learns the shape within a couple of cycles
  and can anticipate the test rather than being ambushed by it — the same argument ADR 0131 makes
  for announcing a tempo change.
- **Every cycle starts full.** You cannot withdraw a pulse that was never established. Bars 1–2 are
  a full click at every level, which also means the very start of a run always sounds normal.

**The bar counts are tunable; the tier names are not.** See §5.

### 3. It follows the ramp's shape without being told to

A withdrawal cycle and a `CommandRamp` plateau are both counted in bars, and they interact without
either one knowing about the other.

The default plateau is `rampIntervalCount = 4` bars, and ADR 0131's warning window is
`min(one bar, half the plateau)` — so during the warm-up climb, roughly every fourth bar is a warning
bar, which by §6 is never silenced. The withdrawal is therefore heavily interrupted during warm-up
and barely interrupted during the **dwell**, which holds `dwellIntervals` (default 4) intervals — 16
bars — with a single warning bar at its end.

That is the correct distribution and nothing in the code decides it. Consolidation happens at the
command tempo, during the dwell; the warm-up is for arriving there. The feature concentrates itself
where it belongs as a consequence of two independent rules meeting, rather than through a
`if isDwell` special case that would then need its own edge handling for ramps without a dwell, for
free play, and for the backoff tail.

**When ADR 0131's `sound` mode is off or unbuilt**, warning bars aren't audibly special, so this
interaction is quieter — the withdrawal simply runs its eight-bar cycle through the whole ramp. Both
behaviours are acceptable; neither needs a flag.

### 4. Where it applies, and the one exclusion that has to be enforced properly

**In scope:** every run driven by `StandaloneMetronomeEngine` — the free-play metronome tool, and
every exercise run including those inside a routine block.

**Out of scope by construction:** loop practice, where the click is the song itself (ADR 0131 §7) and
there is no metronome to withdraw; and ear-training blocks, which aren't metronome-driven (ADR 0104
Slice 2) and where the audio *is* the exercise.

**Excluded deliberately: any run with a strum pattern armed.** A strum pattern's rhythm is the
lesson, not the scaffolding. Silencing it doesn't remove a crutch, it removes the exercise.

The exclusion must key on **whether a strum schedule is actually armed**, not on the exercise's
template — because those two are not the same thing. `runStrumPattern` returns `nil` when
Settings ▸ *"Strumming click follows the pattern"* is off, and a strumming exercise running a plain
meter click is, acoustically, a metronome exercise. Withdrawal should apply to it. Keying on
`strumSchedule != nil` — a fact the engine already holds — gets that right; keying on
`ExerciseTemplate` gets it wrong in a way nobody would notice for months.

This also means **withdrawal and a strum pattern can never both be active**, so their relative
precedence in `scheduledLevel` is unobservable. The chain that matters is:

```
count-in  >  warning bar (ADR 0131 §6, when built)  >  withdrawal  >  strum pattern  >  meter default
```

with the withdrawal/strum edge mutually exclusive rather than ordered. The count-in is never
withdrawn for the same reason it is never re-accented: it is how you enter, and it is already
excluded from the strum branch by `automatorCountingIn`.

### 5. The stored value names intent, not mechanics

`ClickWithdrawal: String, CaseIterable` — `off` · `gentle` · `standard` · `deep`, with `off` the
default, stored under `AppSettings.Key.clickWithdrawal` and resolved through a pure
`resolvedClickWithdrawal(storedValue:)` in the same shape as `resolvedTempoWarning` /
`resolvedAppearance` / `resolvedSpelling`.

**Not `twoOnTwoOff`, not `fourBarGap`.** Once a level is written into an exercise it is a persisted
contract, and the bar distributions in §2 are the single thing most likely to change after playing
with this on a device for a week. A raw value that encodes the mechanics starts lying the moment the
mechanics are tuned, and fixing it becomes a data migration for a change that should be a one-line
edit to a lookup table. Intent survives tuning; structure doesn't.

**Default `off`, and this is a departure worth stating.** The standing rule is opinionated defaults,
everything overridable — and ADR 0131 shipped `show` as its default on exactly that reasoning. This
one defaults off anyway, because a metronome that stops clicking is indistinguishable from a
metronome that has broken, and a first-run user who meets this before they have any reason to trust
the app will file it as a bug and stop using the tool. Withdrawal is a technique you adopt, not a
behaviour you should have to discover and switch off. The opinionated part is that it is offered at
all, and that its levels are three sensible presets rather than a bar-count matrix.

### 6. The per-exercise field is an override, and `nil` means "inherit"

Some drills want this and some never will. A slow chord-change drill is a good candidate; a
metronome-as-tool sitting is not. So `Exercise` gains one field:

```swift
/// Per-exercise override of Settings ▸ Click withdrawal. `nil` ⇒ follow the global default.
var clickWithdrawalRaw: String?
```

Three states, and the distinction between two of them is the whole point:

- **`nil` — inherit.** The exercise has no opinion and tracks the Settings default, including future
  changes to it.
- **`"off"` — pinned off.** The player has decided this specific drill keeps its click, and turning
  withdrawal on globally must not override that.
- **a level — pinned on**, at that level, regardless of the global setting.

`nil` cannot be collapsed into `off`. If a newly created exercise were born holding a concrete value
— even the same value as the current default — then changing the Settings default later would reach
nothing already created, and the global row would silently become a "new exercises only" setting.
This is the `backoffTempoOverride` / `targetTempoOverride` / `mastery` shape (ADR 0075), and it is
used here for the same reason.

Three consequences follow from the field being Optional with **no declaration default**:

- **The migration is additive and cannot wipe the store.** Optional attributes are exempt from the
  CoreData 134110 mandatory-attribute rule; existing exercises migrate to `nil`, which is the
  correct meaning ("no opinion"), not a fabricated one.
- **Nothing in the creation path changes.** A new exercise stores nothing, so
  `NewExercisePlan.finalise(in:)` — the single insert path (ADR 0128) — the preset seeder, and every
  `Exercise.init` call site are untouched. The initialiser gains one defaulted parameter and no
  caller passes it.
- **It is stored as a raw `String?`, never as the enum.** Storing a custom enum as a stored attribute
  crashes on migration on a device that already has data, and the in-memory test store cannot see it
  (`docs/swiftdata-gotchas.md`, ADR 0011/0036). Typed access goes through a computed accessor, as
  `rampIntervalUnit` does over `rampIntervalUnitRaw`.

**Resolution is one pure function**, so the rule is in one place and testable:

```swift
static func resolve(exercise: String?, global: ClickWithdrawal, strumArmed: Bool) -> ClickWithdrawal
```

The strum exclusion (§4) lives *here*, not in the UI. Hiding the row on strumming templates is
presentation; this is the rule.

### 7. The dots show what the click did

If the beat indicator keeps flashing through a silent bar, this feature does nothing. It moves the
crutch from the ear to the eye and the player reads the pulse off the screen instead of carrying it.
A visual metronome is a metronome.

So `BeatIndicator` stops lighting during a withdrawn stretch — and the rule that makes this
maintainable is that **the indicator reads the level the click was voiced at**, rather than
separately deciding when to go dark. A `downbeatOnly` bar lights beat 1 and nothing else, because
that is what sounded. A silent bar lights nothing. The visual and the audible cannot diverge because
there is only one decision, made once.

The dots stay *visible*, dimmed and unlit, and the run caption carries a short static word for the
duration. Both matter:

- **Visible-but-unlit is how the player knows the silence is intentional.** Chrome that disappears
  reads as a failure, and this project has hit real audio-session deaths where the click genuinely
  stopped. The indicator being present and deliberately quiet is the difference between "the app is
  listening" and "the app is dead".
- **The caption is the accessibility carrier, not a nicety.** `BeatIndicator` is
  `accessibilityHidden(true)`, so on its own the withdrawal is invisible to VoiceOver — a
  screen-reader user would get an unexplained silence. This is the same reasoning that made the
  caption a decided carrier in ADR 0131 §3, and the same fix.
- **It must not pulse.** A static marker only. Anything animated falls under Reduce Motion and
  `exerciseAnimates` (which defaults off), so it would be disabled by default for some of the people
  who most need to know why the room went quiet — and a *pulsing* marker would be a visual
  metronome, which is the thing this section exists to prevent.

**The visual reads the heard bar; the audio decides on the scheduled tick.** These disagree by one
look-ahead window, exactly as ADR 0131 §5 documents for the warning, and for the same reason: the
indicator describes the present, the scheduler describes the near future. Neither should be made to
follow the other.

### 7a. On beat-driven drills the withdrawal is partial, and that is honest

Four of the five run configurations advance their *content* on `engine.currentBeat` — `FretboardView`
lights the next note each beat, `ChordChangeView` moves to the next chord, the strumming lane walks
its playhead. That content is the exercise. Darkening it would not withdraw a crutch, it would
delete the drill, and §7's rule is explicitly about beat-carrying **chrome**, not about content.

The consequence, stated rather than hidden: on a fretboard or chord-change drill the player still
has a perfect visual pulse, so silencing the click withdraws less than it appears to. The full effect
lands on the plain untemplated metronome exercise and on free play — where the eyes are on the hands
and the click is the only reference.

This is the exact inverse of ADR 0131's carrier coverage. That ADR's visual warning works best on
templated drills and worst on the plain metronome; this works best on the plain metronome and worst
on templated drills. Between them the two features cover the app, which is a better outcome than
either one being uniformly mediocre — but neither is uniform, and pretending otherwise in either ADR
would set up a device-testing session to be confused by its own results.

### 8. This ADR pays ADR 0131 §5's bill

The withdrawal cycle counts bars from **the first musical downbeat** — after the count-in, which is
not part of the cycle. The engine cannot currently express that position: `tickIndex` counts sub-ticks
from `phaseOrigin` (set at `start()`, before the count-in), and nothing records where the count-in
ended.

This is the same missing bridge ADR 0131 §5 specified for the audible warning, and it is satisfied by
the same single piece of engine state — the **tick index of the first musical downbeat**, captured
once. From it, a scheduled tick's bar position is exact with no reference to the wall-clock
integrator:

```
barsSinceDrillStart = (tickIndex − drillOriginTick) / ticksPerBeat / beatsPerBar
```

Exact, and non-obviously so: a ramp step re-origins the grid through
`MetronomeGrid.reanchoredOrigin`, which pins tick `scheduledThrough` to the same frame, so
`tickIndex` stays **monotonic across every plateau of a climb**. The cycle survives the entire ramp
without special handling.

**Invalidation is the edge case to test.** `reanchorPhase()` — a manual tempo change, a meter change,
a subdivision change — resets `phaseOrigin` to `nil` and `scheduledThrough` to `−1`, so the captured
origin must be re-captured rather than carried. Carrying a stale one would silently place every
subsequent silent bar in the wrong place, which is the kind of defect that reads as "the feature
feels wrong" rather than as a bug. Re-capturing means **the cycle restarts at bars 1–2 full**, which
is also the right behaviour: after any manual disruption you re-establish the pulse before
withdrawing it again.

The strategic point: whichever of these two features is built first pays for this state, and the
second gets it free. This ADR builds it, and ADR 0131's deferred `sound` mode becomes materially
cheaper afterwards — §6's precedence change is then the only thing left in it.

## Build slicing

**Slice 1 — the feature, no stored model change.** The pure `ClickWithdrawal` enum and its cycle
math, the `drillOriginTick` capture and its invalidation, the `scheduledLevel` branch, the Settings
row, and the indicator/caption. Everything in §1–§5, §7, §7a, §8. No `@Model` change, so the whole
slice is device-testable without touching persistence at all — and the only way to know whether the
distributions in §2 are right is to play against them.

**Slice 2 — the per-exercise override.** §6: the `clickWithdrawalRaw` field, the
`ConfigureExerciseForm` row, and the resolver gaining its `exercise:` argument. Deferred not because
it is hard but because it is the only part that can break an existing install, and because a week of
practice against the global default is what tells you which drills actually want to differ.

The split mirrors ADR 0131's, and for the same reason: the risky third and the useful two-thirds are
separable, so separate them.

**Where the code goes** — three files are at or near the 400-line cap and the split is decided up
front rather than under a failing `--strict` lint:

- `StandaloneMetronomeEngine.swift` is at **399**. The captured origin and the withdrawal derivation
  go in a new `+Withdrawal` split, as ADR 0131's went in `+Warning`. Never the core file.
- The cycle math is a new pure `ClickWithdrawal.swift` in `Core/Audio` — no SwiftUI, no AVFoundation,
  per AGENTS.md, because this is exactly the kind of arithmetic that breaks silently.
- The Settings row is its own `ClickWithdrawalSection.swift`, as `TempoWarningSection` and
  `MetronomeSoundSection` are; `SettingsView.swift` is at **391**.
- The `scheduledLevel` branch itself lands in `+Strum.swift` (51 lines), which is where per-slot
  voicing already lives and has room.

## Consequences

- **One stored field, additive, no user migration owed.** v1 is approved but its release is held, so
  there are no installs in the field. The device test still has to be done over **existing data** —
  a clean install cannot show a migration failure, and the developer's own device has data.
- **New pure surface that must be exhaustively tested**: the level at every bar of all three cycles,
  the cycle's restart on re-anchor, the `nil`/`off`/level resolution table, the strum-armed
  exclusion, and the bar arithmetic across a ramp step (the monotonic-`tickIndex` property §8 leans
  on). Model-level tests construct `Exercise` **uninserted** — inserting an object graph SIGTRAPs in
  the XCTest host.
- **`scheduledLevel`'s precedence chain grows again** and now needs its order asserted in tests
  rather than left to reading order — ADR 0131 already flagged this and this ADR makes it true.
- **The click is now a channel with three writers** (count-in, warning, withdrawal) plus the meter.
  That is the ceiling; a fourth would want a proper schedule type rather than a branch chain, and
  this ADR is the point at which that becomes worth saying out loud.
- **Free play benefits identically**, through the same engine, with no metronome-tool-specific work.
- **Nothing new is logged or measured.** No practice-log field (ADR 0117), no new analytics event —
  the closed event enum (ADR 0120) stays closed. The app does not record whether the click was
  withdrawn, and certainly not how the player fared, which would be ADR 0070's line.
- **ADR 0070 is untouched.** The app removes its own signal and declines to look at the result.

## Alternatives considered

- **A true amplitude fade — the click gets quieter rather than dropping out.** Rejected on both
  cost and merit. `ClickLevel` is three discrete voices with no gain parameter, so this means new
  `ClickVoice` API and a per-click gain path. And a *quiet* click is worse than no click: you strain
  to hear it and stay dependent on it, which is the opposite of the intent. The name "fade" is
  retired with it — nothing here fades, the click withdraws.
- **Withdraw during the dwell only.** Tempting, and it is where the value is — but §3 shows the ramp
  and the warning window already produce that distribution without a rule. An explicit
  dwell-only branch would then need its own answers for ramps with no dwell, for free play, and for
  the backoff tail, all to reproduce behaviour that is already emergent.
- **A configurable bar count (click N, silent M).** Rejected, same reasoning ADR 0131 used for its
  window. The useful range is narrow, the musical constraint (land on eight) is real, and a matrix
  of bar counts mostly lets a player configure the feature into either uselessness or chaos. Three
  named levels are a choice; two spinners are a chore.
- **Default it on at `gentle`.** Rejected — §5. A metronome that stops clicking looks broken, and
  the first-run user has no context to read it any other way. This is the rare case where the
  opinionated default is "off, and offered clearly".
- **Keep the beat dots flashing through silent bars.** Rejected — §7. It would make the feature a
  no-op for anyone looking at the screen while appearing to work, which is the worst failure mode
  available: a feature that ships, gets used, and does nothing.
- **A countdown before the click drops out.** Rejected — that is the count-in's grammar, and ADR 0131
  already rejected reusing it for a mid-run event. It would also defeat the point twice over: the
  cycle is fixed at eight bars precisely so the player can anticipate it *themselves*, and being told
  "silence in 3, 2, 1" is one more thing to depend on.
- **Silence the click for a whole plateau instead of a bar cycle.** Rejected — a plateau is 4 bars at
  the default and 16 during a dwell. Four is too short to test anything; sixteen unbroken bars with no
  reference is not a desirable difficulty but an invitation to practise something wrong for a long
  time before finding out.
- **Carry it on `SessionBlock.focus`'s `microRestEvery`.** ADR 0131 left this open as a candidate and
  it is worth closing: `microRestEvery` (ADR 0014 R4) is *minutes of rest inside a focus block* — the
  player stops playing. This withdraws the click while the player keeps going. They are different
  events at different scales in different units, and the only thing they share is the word "gap".
  Reusing the field would also scope the feature to planner-built sessions, excluding free play and
  every standalone run — which is where §7a says it works best. `microRestEvery` stays unpopulated and
  stays available for what it was plumbed for.
- **Store the level as a concrete default on new exercises rather than `nil`.** Rejected — §6. It
  would quietly convert the Settings row into a "new exercises only" preference, and the bug report
  ("I turned it on and nothing happened") would be nearly impossible to read.
- **Ship the per-exercise override in the same slice.** Rejected — it is the only part that can break
  an install, and the global default has to prove the distributions first. Deciding it now and
  building it second costs nothing.
