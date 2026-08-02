# 0141 — A block without a ramp still has a length

- **Status:** Proposed (2026-08-02)
- **Date:** 2026-08-02
- **Builds on:** ADR 0129 (a session is sized in blocks; a block's allotment fits the unit's ramp),
  ADR 0130 (`plannedMinutes` / `usesAuthoredLength` / `effectivePlannedMinutes`, and a block's right to
  decline the fit), ADR 0014 (R1 — only deliberate work is budgeted, and *we never tell you to stop
  playing*), ADR 0104 (ear training), ADR 0135 (improvise over a backing track), ADR 0136 (the
  freeform block, unbuilt), ADR 0070 (never grade the player).
- **Amends:** ADR 0135 §B6a's *rationale* — not its placement (L5).

## Context

Three block types run without a ramp: **ear training** (ADR 0104), **improvise** (ADR 0135, Slice 1
shipped 2026-08-02) and the **freeform** block (ADR 0136, not yet built). All three share one shape:
the clock starts on appearance, there is no staircase to run its course, and an explicit **Done** is
the completion. Outside a routine that is exactly right — a standalone sheet is not an exercise, and
open-ended is what it is for.

Inside a routine it is a different object. A routine is a **promise about how long you will be sitting
there** (ADR 0129's whole premise), and a block with no defined end breaks that promise from the
inside: a four-block session whose third block runs until you feel like stopping is not a
40-minute session, and nothing on the screen can honestly say it is.

The machinery to fix this already exists and these blocks simply do not participate in it.
`RoutineItem` has carried `plannedMinutes`, `usesAuthoredLength` and `effectivePlannedMinutes` since
ADR 0130, and `BlockLengthControl` is already the disclosure-plus-opt-out — its own doc says it is
carried by "the exercise and loop block previews, and by nothing else."

There is a **live inaccuracy**, not just a gap. `PracticePlanner.estimatedMinutes(for:mode:
plannedMinutes:)` discards `plannedMinutes` for every non-trainer mode and prices the block as
`region × repeats`. So a routine containing an ear block already misreports its own length, and ADR
0135 Slice 1 widened that to improvise by adding a second mode down the same branch.

**The tension to resolve, stated honestly.** `RoutineItemKind.play` is documented "surfaced but
**unbudgeted** (ADR 0014 R1); we never tell you to stop *playing*", and ADR 0135 §B3 leans on it: "no
ramp, no rep clock, no staircase: this is an open jam, and the app never tells you to stop playing."
§B6a goes further — a backing loop plans as `play` and never `focused`, because "a jam that counts
against a focused time budget would be miscounted work, and would drag session sizing around by a
block that has no defined length."

Those are two different claims wearing one word. R1 is a promise about **not cutting your playing
off**. It was encoded as **unbudgeted**, which is the stronger and separate claim that the block has
no stated length at all. A block can say how long the session allotted it — so the session can be
honest about its own shape — without the app severing anything.

## Decision

- **L1 — The three ramp-less blocks carry a planned length, through the existing fields.** No new
  stored property, no migration: `plannedMinutes`, `usesAuthoredLength` and `effectivePlannedMinutes`
  (ADR 0130) mean here exactly what they mean on an exercise or a loop-trainer block. Generation sets
  the allotment; `BlockLengthControl` discloses and declines it; `estimatedMinutes(for:mode:
  plannedMinutes:)` stops throwing it away. This is the smallest possible change because the design
  was already general — only its consumers were narrow.

- **L2 — It is a budget, not a buzzer.** When the planned time elapses:
  - the audio is **never cut mid-cycle** — an ear or improvise block ends at the next loop-region
    boundary, never mid-phrase;
  - **Done is never disabled**, before or after — finishing early was always the design and stays it;
  - the block then **advances the way a finished ramp advances**. That is the same grammar every other
    block already has: the staircase completes, the session moves on.

  What makes this consistent with ADR 0014 R1 rather than a violation of it is **whose limit it is**.
  R1 protects the player from *the app* deciding when they have played enough. Here the length is the
  player's own — either the session preset they chose (ADR 0129: the preset *is* the promise) or the
  number they set on the block. The app is keeping their arrangement, not imposing one.

- **L3 — A quiet remaining-time readout, and nothing more.** The run screen states time remaining in
  the same register as the rest of Progress — a mirror, not an arcade (ADR 0113). No countdown
  urgency, no colour change at the end, no "30 seconds left!". A player who wants to know looks; a
  player who doesn't is not chased.

- **L4 — Declining the fit restores today's behaviour exactly.** `usesAuthoredLength = true` yields a
  `nil` `effectivePlannedMinutes`, which these blocks read as **open-ended** — the ADR 0104 / 0135
  behaviour, unchanged, one toggle away. This is the load-bearing property of the whole decision: the
  open jam inside a routine is not removed, it becomes a **choice** rather than the only option. It is
  also why ADR 0130's opt-out is the right mechanism rather than a new one.

- **L5 — The budget still counts only `focused` blocks; the *kind* is about intent, the *length* is
  about time.** `RoutineBudget.budgetedMinutes` is left exactly as it is. A backing loop still plans
  as `play` (ADR 0135 §B6a's **placement** stands), still doesn't count as deliberate drilling, and
  now has an honest length for the routine's own estimate — which already sums every non-rest block
  regardless of kind. What §B6a's rationale got wrong is only the clause "a block that has no defined
  length": with L1 it has one, so the thing it feared cannot happen. Two questions, two mechanisms,
  no widening of `.focused`.

- **L6 — Defaults, for a block authored by hand rather than sized by a session.** Ear **5** min,
  improvise **10**, freeform **10** — one constant apiece, in one place. Ear is short because
  internalising a phrase is attention-dense and goes stale; improvise and freeform are longer because
  both need a run-up before anything useful happens. These are only the fallback: the real default is
  whatever the session allotted.

- **L7 — Standalone stays open-ended and unlogged, now for a stated reason.** A routine block has a
  planned length and therefore an honest duration to log; a standalone `EarTrainingSheet` or
  `ImproviseSheet` has neither, and "however long the screen was open" is not a length. This settles
  the question ADR 0117's device pass raised, ADR 0138 left open, and ADR 0135 Slice 1 doubled: the
  answer is **no**, by rule rather than by omission.

## Consequences

- **A session containing these blocks starts telling the truth about its length.** Today it does not,
  and the error grows with every ramp-less block added.
- **ADR 0135 §B6a is amended in its reasoning and upheld in its outcome** — worth noticing that the
  clause which failed is the one that asserted a permanent property ("has no defined length") rather
  than a design intent.
- **"Unbudgeted" narrows to what ADR 0014 R1 actually meant.** After this, `warmup` and `play` mean
  *not deliberate drilling*, not *unmeasured*. That is the more useful distinction and the one the
  rest-injection and block-splitting rules already depend on.
- **ADR 0136 gets this for free** by being unbuilt — the freeform run screen is written once, with a
  length, instead of being retrofitted. Deciding after 0136 shipped would have meant three retrofits.
- **Risk: a length is a new thing to get wrong on a screen whose whole pitch is open-endedness.** L4 is
  the mitigation and it is a real one, but a player who never finds the toggle will experience the
  limit as the app's rather than their own. Watch for it on the device pass.
- **Risk: "ends at the next region boundary" can overshoot.** A 40-second loop region can run up to 40
  seconds past the allotment. That is the correct trade — never cut a phrase — but session sizing
  should treat the planned length as a floor for these blocks, not a ceiling.

## Alternatives considered

- **A hard stop at the planned time.** Rejected — cutting audio mid-phrase is precisely what ADR 0014
  R1 forbids, and it is the one reading of "time limit" that would make the feature feel like a
  supervisor.
- **Leave them open-ended (status quo).** Rejected — it makes every session containing one
  unmeasurable, and the length readout already lies about them. "The block has no length" is not a
  neutral position; it is a wrong number on a screen.
- **A new `maxMinutes` field on `RoutineItem`.** Rejected — a second length axis beside
  `plannedMinutes` with no reason to differ, and every consumer would need to learn which one wins.
  ADR 0130's field already means "how long this block runs in this routine".
- **Make improvise/ear blocks `.focused` so the existing budget covers them.** Rejected (L5) — it
  would make a jam count as deliberate drilling, change rest injection and block splitting around it,
  and answer a time question by corrupting an intent taxonomy.
- **Per-mode lengths stored on the unit (`Loop`/`Exercise`).** Rejected — ADR 0129 sub-decision 3: a
  block's length is a property of *this block in this routine*, and generating a session must never
  rewrite an authored recipe.

## Slices

- **Slice 1 — ear + improvise.** Build alongside ADR 0135 Slice 2, since that slice writes
  `ImproviseLoopRunView` and touches `EarLoopRunView`'s neighbourhood anyway. Covers: the
  `estimatedMinutes(for:mode:plannedMinutes:)` fix, the shared remaining-time readout and
  end-of-cycle advance, `BlockLengthControl` on both block previews, the L6 constants, and unit tests
  for the estimate (the part that breaks silently).
- **Slice 2 — freeform.** Folded into ADR 0136 Slice 1 rather than following it, so the run screen is
  written once with its length.
