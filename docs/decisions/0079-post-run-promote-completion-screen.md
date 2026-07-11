# 0079 — Post-run promote: a completion screen offers to move command up

- **Status:** Proposed (decisions locked 2026-07-11; **build deferred** to a later session — this ADR
  records the design so implementation is a mechanical follow-through)
- **Date:** 2026-07-11
- **Follows up / resolves:** ADR 0077 §6, which decided promotion should move *after* a run and
  reframe, but explicitly deferred the **trigger** and **copy** to "a short follow-up ADR with the
  implementation." This is that ADR.
- **Extends:** ADR 0046 (Practice training run + `CommandRamp`; the run naturally completes),
  ADR 0057 (single write path per model), ADR 0075 (stored reach override + auto-clear), ADR 0058
  (post-run is also where journaling already lives).
- **Reverses in part:** ADR 0046's **in-setup** promote button (a pre-run "I own X now — promote"
  affordance) — removed; promotion is now offered only *after* a completed run.
- **Scope:** **exercises only.** Loops keep their current promote behaviour.
- **Non-negotiable:** ADR 0070 — the app never grades. The completion screen is a neutral
  acknowledgement plus an *offer*, never a score, timing verdict, or pass/fail.

## Context

The in-setup promote button ("I own 106 now — promote", shown on the run screen while stopped) is
mistimed and re-treads confusing framing (ADR 0077 §6): mid-drill the player is *playing*, not
tapping, and asking "do you own the reach?" *before* the run inverts the natural order — you earn the
bump by running, then decide. ADR 0077 §6 set the direction (surface it after a run, reframe as
"bump command") but left two things open: **when** exactly it triggers, and the **copy**.

Two facts about the engine make the "after a completed run" design cheap and precise:

1. A standalone exercise run **ends naturally.** When the `CommandRamp` runs its full course
   (working → dwell at command → summit at reach → backoff), `finishRamp()` calls `stop()` and fires
   `onRampFinished` (`StandaloneMetronomeEngine+Automator.swift`). A **manual** early stop is
   deliberately silent — `onRampFinished` fires only for a ramp that ran its course.
2. For a standalone run (`routineContext == nil`) that hook is **currently `nil`**
   (`ExerciseRunView+Actions.swift:36` sets `engine.onRampFinished = routineContext?.onFinished`), so
   it's a ready, unused seam — no new engine plumbing required.

Because the ramp only finishes naturally after holding the command dwell and summiting the reach,
"the run ran its course" *is* "you held the top." The open trigger question answers itself.

## Decision

### 1. Trigger — only on a naturally completed run
Offer the promote **only** when `onRampFinished` fires (the ramp reached the top and backed off), for
a standalone exercise run (`routineContext == nil`). A manual stop partway shows nothing. No separate
"held the top" bookkeeping is needed — natural completion already implies it. (Rejected: offering
after *every* run, or after any run that merely reached command — naggy and fuzzier, and it decouples
the offer from actually earning it.)

### 2. Presentation — a brief completion screen (mirrors the routine Done screen)
On natural completion, present a short **completion screen** rather than silently returning to setup —
the same shape as `RoutineBlockDoneView` (a completion beat + a CTA), so exercises read consistently
whether run solo or in a routine. It is a deliberate "you finished" moment, not a modal interruption
and not a persistent card the user must dismiss. (Rejected: a card bolted onto the returned setup
screen — quieter but easy to miss and clutters setup; a system **alert** — interruptive and reads as a
verdict, against ADR 0070.)

### 3. What accepting offers — move command up to the reach
Accepting sets **command = min(ceiling, reach)** and lets reach re-derive a bit above the new command
(TempoStretch, ADR 0045); a **custom-pinned reach** clears back to auto when command catches up to it
(ADR 0075, the existing `clearOverrideIfCaughtUp` semantics). This is exactly what today's in-setup
promote does — retimed, not re-invented — and the reach is only ~5–8% above command, so it's already a
modest step. (Rejected: a one-warm-up-step bump — gentler but diverges from the established promote
semantics and needs the step size in hand.)

**The promote persists immediately.** Unlike the in-setup button, which only mutated local `command`
state and relied on a subsequent **Save Changes** / **Start** to write (ADR 0057), the post-run promote
has no following Start to piggyback on — accepting **is** the commit, so it writes straight to the
model (`modelContext.save()`). This stays within the single write path: promotion still means
"raise command," it just commits at the new, correct moment.

### 4. Remove the in-setup promote button
Delete the pre-run "I own X now — promote" affordance from `ExerciseRunView` (`promoteButton`,
gated `!isRunning, routineContext == nil`). Promotion is now a single, well-timed post-run offer — no
button you tap before you've played. (Reverses ADR 0046's placement.)

### 5. Nothing to promote ⇒ acknowledge without a CTA
When there is no reach above command (`reach <= command`, e.g. command already at the BPM ceiling),
there's nothing to promote. The completion screen still acknowledges the run but **omits the promote
CTA** (a plain "nice run — done"), rather than offering a no-op. (Exact treatment — omit the CTA vs
skip the screen entirely — settled at build; the lean is to keep a minimal acknowledgement.)

### 6. Copy (direction; final microcopy at build)
Neutral acknowledgement + an offer, in the app's **reach** vocabulary ("summit at the reach"):
- Title: *"Nice run"* (no praise about *how* they played — ADR 0070).
- Body: *"You summited {reach} today."*
- Promote CTA: *"Move command to {reach}."*
- Dismiss: *"Keep it where it is"* / *"Done."*

Exercises only.

## Consequences

- Promotion happens at the one moment it makes sense — right after you've earned it — and the run
  screen's setup state loses a confusing pre-run prompt.
- The offer is honest and un-graded (ADR 0070): completing the climb is a fact, not a score, and the
  promote is an invitation you can decline by dismissing.
- One real behaviour change beyond retiming: the post-run promote **persists on accept**, because
  there's no later Start to carry the write. Still one write path (ADR 0057).
- The standalone `onRampFinished` seam finally has a consumer; routines are untouched (they already
  hook it for advancement).

## Alternatives considered

- **Trigger on every run / any run reaching command.** Rejected — naggy, and it separates the offer
  from earning it; natural completion already means "held the top."
- **Presentation as a setup-screen card or a system alert.** Rejected — a card is easy to miss and
  clutters setup; an alert interrupts and reads as a verdict (ADR 0070).
- **Promote by one warm-up step instead of to the reach.** Rejected — diverges from the existing
  promote semantics for a marginal gentleness gain.
- **Keep the in-setup button too.** Rejected — re-introduces the mistimed pre-run prompt this change
  set out to remove.
- **Fold a mastery tap / journal note into the completion screen** (as `RoutineBlockDoneView` does).
  Deferred — attractive symmetry, but keep the first cut to completion + promote; journaling already
  has its own entry point (ADR 0058) and can be added here later without reopening this decision.

## Implementation notes (for the build session)

- Set `engine.onRampFinished` for the standalone case (`routineContext == nil`) to present the
  completion screen, capturing the **reach at completion** in state (so the copy/target are stable
  even as local edits change afterward).
- Present the screen as a `fullScreenCover`/overlay in the spirit of `RoutineBlockDoneView`; the
  promote action calls the existing promote math (`command = min(ceiling, reach)` +
  `clearOverrideIfCaughtUp`) **and** `modelContext.save()`.
- Guard the CTA on `reach > command`.
- Remove `promoteButton` and its call site; keep **Save Changes** (still the manual persist path for
  other edits) and **Start**.
- Unit-test the pure predicate ("offer promote?" = completed && reach > command) and rely on existing
  `TempoStretch` coverage for the target math. Keep the promote logic pure/testable per AGENTS.md.
- Loops: no change.
