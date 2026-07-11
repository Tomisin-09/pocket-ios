# 0079 — Post-run promote: a completion screen offers to move command up

- **Status:** Accepted — **built** 2026-07-11. Standalone finish **reuses `RoutineBlockDoneView`**
  (`upNext: nil`) rather than a bespoke screen (see §2, revised at build); routine Done-screen promote
  toggle per §7; pure `PromoteOffer` math; in-setup promote button removed.
- **Date:** 2026-07-11
- **Follows up / resolves:** ADR 0077 §6, which decided promotion should move *after* a run and
  reframe, but explicitly deferred the **trigger** and **copy** to "a short follow-up ADR with the
  implementation." This is that ADR.
- **Extends:** ADR 0046 (Practice training run + `CommandRamp`; the run naturally completes),
  ADR 0057 (single write path per model), ADR 0075 (stored reach override + auto-clear), ADR 0058
  (post-run is also where journaling already lives).
- **Reverses in part:** ADR 0046's **in-setup** promote button (a pre-run "I own X now — promote"
  affordance) — removed; promotion is now offered only *after* a completed run.
- **Scope:** **exercises only.** Loops keep their current promote behaviour. Applies to a
  standalone run *and* to an exercise block run inside a routine — see §7 for the routine flow.
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

### 2. Presentation — **reuse** the routine Done screen (`RoutineBlockDoneView`)
On natural completion, present a short **completion screen** rather than silently returning to setup.
**Built decision (revised at build, 2026-07-11):** rather than a bespoke standalone view, the run
presents the *actual* `RoutineBlockDoneView` — the routine block's finish screen — with **`upNext:
nil`** (nothing follows a solo run). It's the more integrated surface and gives a standalone run the
same completion beat, **optional mastery tap**, **optional inline note**, and the **opt-in promote
toggle** a routine block gets. This **supersedes** the earlier plan of a bespoke completion view whose
promote was the *primary* CTA (§6 copy), and **reverses** the "fold mastery/journal in — deferred"
alternative below: the reuse gets it for free and reads consistently whether an exercise is run solo or
in a routine. It's a deliberate "you finished" moment, not a modal interruption or a persistent card.
(Rejected: a bespoke second surface — divergent for no benefit; a card bolted onto the returned setup
screen — easy to miss and clutters setup; a system **alert** — interruptive and reads as a verdict,
against ADR 0070.)

### 3. What accepting offers — move command up to the reach (default), or a **custom** value
Accepting defaults command to **min(ceiling, reach)** and lets reach re-derive a bit above the new
command (TempoStretch, ADR 0045); a **custom-pinned reach** clears back to auto when command catches up
to it (ADR 0075, the existing `clearOverrideIfCaughtUp` semantics). The reach is only ~5–8% above
command, so it's already a modest step.

**Follow-up (built 2026-07-11): the target is editable.** The promote row's value defaults to the
reach but the player can nudge it with a ±/typed stepper before committing — a **custom command** they
feel they actually own — clamped to **`(command, ceiling]`** (strictly a promotion, never past the BPM
ceiling). The commit path is unchanged (`promoteCommand(to: chosen)`); only the target is now
player-chosen rather than fixed at the reach. Applies to **both** Done screens (the row is the same
`RoutineBlockDoneView` control). The gate stays `PromoteOffer.canPromote` — now **ceiling-aware**
(`min(ceiling, reach) > command`), so a command already at the ceiling reads as "nothing to promote"
instead of offering a no-op. (Rejected: a one-warm-up-step bump — diverges from promote semantics;
free-typing below command — a "promotion" that lowers command is contradictory, so the floor is
`command + 1`.)

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

### 6. Copy (superseded by the reuse in §2)
The original plan gave the bespoke screen its own copy (title *"Nice run"*, body *"You summited
{reach} today"*, a *"Move command to {reach}"* primary CTA, a *"Keep it where it is"* dismiss). With
the build reusing `RoutineBlockDoneView` (§2), the **shared** copy stands instead: the *"Nice work"* +
drill-name completion beat, the mastery/note prompts, the promote **toggle** *"Move command to
{reach}"* (with the sub-line "You summited it this run — bump the drill up"), and a **Finish** primary.
Still neutral acknowledgement + an offer, never praise about *how* they played (ADR 0070).

Exercises only.

### 7. Inside a routine — fold the promote into the Done screen's single commit
An exercise block run in the routine player fires the **same** `onRampFinished` on natural
completion, but that hook is already consumed for advancement (`finishedBlock()`), and a
naturally-completed unit already lands on `RoutineBlockDoneView` (mastery tap + note + Continue) when
**manual advance** is on (ADR 0071 R4). So the routine promote reuses that surface rather than adding
a second completion screen:

- When the finished block is an exercise with **`reach > command`**, `RoutineBlockDoneView` shows one
  extra **optional toggle** — *"Move command to {reach}"*, default **off** — beside the mastery tap
  and note. When `reach <= command` the toggle is absent (nothing to promote, §5).
- **`Continue` stays the single primary** (the P3 lesson — no competing CTA). It commits all three
  atomically in `commitDone`: mastery, the journal note, and — if the toggle is on — the promote math
  (`command = min(ceiling, reach)` + `clearOverrideIfCaughtUp`), under the existing single
  `modelContext.save()`. Promote is opt-in and never a silent bump.
- **Auto-advance ⇒ no promote.** With auto-advance on, the Done screen is skipped entirely, so there
  is nowhere (and no intent) to offer the bump. This asymmetry is deliberate: auto-advance means
  "don't stop me," and the app never mutates `command` the player didn't see and accept (ADR 0070's
  no-silent-verdict spirit). A summited block under auto-advance simply advances.
- **Reps:** a multi-rep block only reaches the Done screen after its **last** rep (reps are
  back-to-back, ADR 0076), so the toggle is offered once per block, not per rep.

Presentation differs by context, deliberately: standalone makes promote the **primary** CTA (§2/§6 —
finishing *is* the point of that screen); in a routine it is an **optional toggle** under Continue
(advancing is the point). Same math, same persist-on-accept, context-appropriate framing. This
**narrows** the earlier "routines are untouched" note in Consequences — routines gain the opt-in
toggle, but their advance flow, auto-advance behaviour, and journal commit are otherwise unchanged.

## Consequences

- Promotion happens at the one moment it makes sense — right after you've earned it — and the run
  screen's setup state loses a confusing pre-run prompt.
- The offer is honest and un-graded (ADR 0070): completing the climb is a fact, not a score, and the
  promote is an invitation you can decline by dismissing.
- One real behaviour change beyond retiming: the post-run promote **persists on accept**, because
  there's no later Start to carry the write. Still one write path (ADR 0057).
- The standalone `onRampFinished` seam finally has a consumer. Routines already hook it for
  advancement and keep that flow; the only routine change is an **opt-in promote toggle** folded into
  the existing Done-screen commit (§7) — offered on a summited block under manual advance, absent
  under auto-advance.

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
  Deferred at design — but **adopted at build**: reusing `RoutineBlockDoneView` for the standalone
  finish (§2 revised) brings the mastery tap and inline note along for free, and reads consistently
  with a routine block. So a standalone finish now also commits an optional self-rating + note.

## Implementation notes (as built)

- Set `engine.onRampFinished` for the standalone case in `commitAndStart` (`routineContext == nil`),
  capturing the **reach at run start** in a `RunCompletion` value (stable even as the returned setup is
  edited afterward); the routine hook stays the player's advance, set in `seedIfNeeded`.
- Present the finish as a `fullScreenCover` hosting **`RoutineBlockDoneView`** with `upNext: nil`
  (§2) — *not* a bespoke view. The commit closure writes mastery + note (`JournalWriter`) and, when the
  promote toggle is on, the promote math (`PromoteOffer.promotedCommand` + `clearOverrideIfCaughtUp`)
  through the single write path (`persist`, ADR 0057) — accepting *is* the commit.
- Pass a `RoutineBlockDoneView.PromoteConfig` (default target = `promotedCommand`, `minValue =
  command + 1`, `maxValue = ceiling`) only when `PromoteOffer.canPromote(reach:command:ceiling:)`;
  otherwise `nil` (no row). The view holds the editable `promoteValue`; the toggle gates whether it's
  applied, and `onContinue` hands back `promoteTo: Int?` (nil = off, else the chosen value).
- Remove `promoteButton` and its call site; keep **Save Changes** (still the manual persist path for
  other edits) and **Start**. `ExerciseRunView.reach` made internal so the +Actions extension reads it.
- Unit-test the pure predicate ("offer promote?" = completed && reach > command) and rely on existing
  `TempoStretch` coverage for the target math. Keep the promote logic pure/testable per AGENTS.md.
- **Routine path (§7):** add an optional `canPromote: Bool` + promote-target to
  `RoutineBlockDoneView`, rendering the *"Move command to {reach}"* toggle only when true and only for
  an exercise unit; thread a `promote: Bool` back through the `onContinue` closure. In
  `RoutinePlayerView.commitDone`, when `promote` is set for an `.exercise` owner, apply the same
  promote math as the standalone case before the existing `save()`. Nothing to add for auto-advance
  (Done screen already skipped) or for the song/loop/rest paths. Same pure predicate both paths — and
  since the standalone finish now hosts this very view, `RoutineBlockDoneView` is the single completion
  surface for both.
- Loops: no change.
