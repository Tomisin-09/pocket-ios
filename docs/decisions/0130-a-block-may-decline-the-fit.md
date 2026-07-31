# ADR 0130 — A block may decline the fit, and says so; loops join the routine-presentation rule

- **Status:** Accepted — built on `pocket-210-block-length-override`
- **Date:** 2026-07-31 (`pocket-210-block-length-override`)
- **Extends:** **ADR 0129** — its bounded fit stays exactly as amended; this adds a *per-block* opt-out
  and makes the override legible where it happens. **ADR 0077** — closes §7 ("loops are out of scope …
  loop in-session consistency is a separate future call") by extending the tempo-only routine
  presentation to loop blocks.
- **Builds on:** ADR 0070 (never grade the player). ADR 0057 (one write path per model). ADR 0012 (the
  additive-migration rule for new stored fields).

## Context

ADR 0129 made a generated block fit the exercise's ramp to the block's allotted minutes, and the
2026-07-31 device pass forced two amendments: the fit is now bounded to 0.5…2.5× the authored dwell,
and the session's length readout prices the ramp that will actually play rather than the allotment it
asked for. Both landed on `pocket-209`.

That leaves the fit *correct* but still *silent and unconditional*. Three things came out of testing
the fixed build:

1. **The player is never told the block differs from what they authored.** The block preview now draws
   the fitted staircase, which is honest — but a player who tuned an exercise to a four-interval dwell
   and then meets a ten-interval one has no way to know the session did that, or why. The surfaces
   agree with each other; neither agrees with the player's memory of what they set.
2. **There is no way to decline.** ADR 0129 sub-decision 3 protects the stored recipe from being
   *rewritten*, which is a different guarantee from letting the player keep it *at run time*. Someone
   who has deliberately shaped a drill has no escape hatch short of removing the block.
3. **A loop block's preview has no tempo controls at all**, where an exercise block's has had them
   since ADR 0077 §3. This is not an oversight — 0077 was explicitly scoped "exercises only" and §7
   parked loop consistency as "a separate future call." The block model has now made loops
   first-class in a generated session (ADR 0129 as amended), so the parked call is due.

There is a real tension to resolve, not just a gap to fill. ADR 0129's whole point is that **a preset
is a promise about how long you will be sitting there**. An opt-out weakens that promise. But the
alternative — a fit that silently overrides authored intent with no recourse — is the thing the device
pass objected to, and bounding it only reduced the magnitude.

## Decision

### 1. The fit is per-block declinable, stored as an opt-out flag

`RoutineItem` gains **`usesAuthoredLength: Bool = false`**. When true, the block runs the exercise's or
loop's own recipe and `plannedMinutes` is ignored by the run, the preview and the estimate.

**A flag, not a cleared `plannedMinutes`.** Clearing the minutes would express the same thing to every
consumer — they all already treat `nil` as "run as authored" — but it is a **one-way door**: the
allotment is the only record of what the session asked for, so discarding it means the toggle cannot
come back. Keeping both means the control is reversible and the note below can always name both
numbers. Declaration default `false`, so SwiftData lightweight migration fills existing rows
additively with no store wipe (ADR 0012 / CoreData 134110).

The effective-length rule becomes one expression, read by all three consumers:

```
effective(item) = item.usesAuthoredLength ? nil : item.plannedMinutes
```

### 2. The block says what it is doing, and what it costs

Where a block's fitted length differs from its authored one, the **block preview** carries a short
line naming both numbers and the consequence — not a warning, a statement of fact:

> *Runs ~3 min in this session · your saved setting is ~2 min.*

**On the block preview, and deliberately not in the exercise library.** In the library the authored
recipe *is* the truth and there is nothing to disclose; worse, one exercise can sit in several routines
fitted differently, so a library note could only say something vague and permanent about a condition
that is neither. The preview is where the player is looking at *this* block, where the number is
concrete, and where the control to change it lives.

The note is omitted when the two agree — which is the common case once the fit is bounded, so this
stays quiet rather than becoming chrome on every block.

### 3. Declining re-flows the session estimate, visibly

`PracticePlanner.estimatedMinutes(forRoutine:)` already prices every block independently, so a
declined block changes the routine's **Estimated length** with no new arithmetic. That is the point:
the player sees the cost of their choice immediately, on the same screen, rather than discovering it
mid-session. This is what makes the opt-out compatible with ADR 0129's promise instead of a hole in
it — the preset stops being a guarantee and becomes a default the player can knowingly spend.

### 4. Loop blocks get the same tempo panel exercise blocks have (closes ADR 0077 §7)

`LoopBlockPreview` gains the Practice Settings panel its exercise counterpart has carried since
ADR 0077 §3 — concretely `LoopSettingsPanel`, the percent-of-original sibling the loop *run* screen
already uses, not `PracticeSettingsPanel` itself, whose labels and captions are BPM — writing
straight to the model as that ADR specified for a surface with no Start to defer to. The panel's
values are read off `Loop.rampFloor` / `command` / `targetSpeed`, the same derivations `Loop.ramp`
and `LoopRunView.seedIfNeeded` use, so the controls and the staircase beneath them cannot disagree. ADR 0077's rule — *the library is the only full editor; in a
routine the only editable knob is tempo* — now reads the same for both unit kinds.

Ear-training blocks are excluded: they have no ramp and no command (ADR 0104 Slice 2), so there is
nothing to tune.

## Consequences

- **One new stored field**, additive and defaulted — no migration owed, and no users yet in any case
  (the v1 release is deliberately held).
- **A preset's minutes become a default rather than a guarantee.** Accepted deliberately: ADR 0129
  already softened them from a budget to an estimate, and an estimate the player can knowingly change
  is more honest than one they cannot.
- **The note only appears where the fit actually moved something**, so a bounded fit that lands on the
  authored length shows nothing at all.
- ADR 0077's exercise/loop asymmetry closes; §7's "separate future call" is answered rather than left
  open indefinitely.
- **Still never grades the player** (ADR 0070). Everything here sizes and discloses effort.

## Alternatives considered

- **Clear `plannedMinutes` to mean "declined."** Rejected — every consumer already reads `nil`
  correctly, so it is tempting, but it destroys the allotment and makes the control one-way. A
  reversible toggle needs both numbers.
- **A global "don't fit my exercises" setting.** Rejected — the decision is per-block by nature (one
  drill is deliberately shaped, the next is not), and a global switch would turn ADR 0129's central
  behaviour off wholesale for anyone who met one exercise they cared about.
- **Put the note in the exercise library.** Rejected — see §2; nothing is wrong there, and the note
  could not name a number.
- **Write the fitted length onto the exercise so the two never differ.** Rejected again, as in
  ADR 0129 — generating a session must never rewrite an authored recipe.
- **Leave loops without a tempo panel.** Rejected — ADR 0129 made loops first-class in generated
  sessions, so the ADR 0077 asymmetry is now a real inconsistency rather than a deferred one.
