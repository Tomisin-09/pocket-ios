# 0082 — Loops finish on the post-run completion screen; "Practice now" launches from the loop edit sheet

- **Status:** Accepted — built 2026-07-11.
- **Date:** 2026-07-11
- **Extends:** ADR 0079 (post-run promote completion screen — built for exercises; this brings loops
  to parity), ADR 0046 (Practice training run + `LoopRunModel`; a loop run naturally completes),
  ADR 0057 (single write path per model — `persist()`), ADR 0075 (stored reach override + auto-clear),
  ADR 0058 (post-run is where journaling already lives), ADR 0039 (loop command tempo / mastery as the
  optional practice fields), ADR 0028 (the loop edit sheet, reached by holding a loop row).
- **Reverses in part:** ADR 0046's **in-setup** loop promote button (the pre-run "I own X% now —
  promote" affordance on `LoopRunView`) — removed, exactly as ADR 0079 removed it for exercises.
  Promotion is now offered only *after* a completed run.
- **Scope:** loops. Exercises already have this (ADR 0079); this is the loop half.

## Context

ADR 0079 gave **exercises** a post-run completion screen: a run that summits its reach naturally
lands on `RoutineBlockDoneView` (completion beat + optional mastery self-rating + optional journal
note + an opt-in "move command up" promote), all committed through the one `persist()`. It explicitly
scoped **loops out** — "Loops keep their current promote behaviour."

That left loops inconsistent in two ways the user caught in testing:

1. **A finished loop run does nothing.** `LoopRunModel.onFinished` is set to `routineContext?.onFinished`
   in `seedIfNeeded` — so in a routine the session advances, but a **standalone** loop run (the common
   case) has `onFinished == nil`. The ramp completes and you're left sitting on the setup screen. No
   mastery prompt, no note prompt, no promote. It just "returns to the start."

2. **Loops still carry the pre-run promote button** that ADR 0079 removed from exercises — the "I own
   X% now — promote" claim you could tap *before* proving it on a run.

Separately, the loop trainer (`LoopRunView`) is reachable only via Practice → Loops. From the
**waveform** — where you make and shape loops — there was no way into it; the design review landed on
surfacing that entry from the **loop edit sheet** (held-row → `LoopEditSheet`), right next to where a
loop's command tempo is set, rather than adding a control to the already-two-control loop row.

## Decision

**1. A standalone loop run finishes on the same completion screen exercises use.** On
`commitAndStart`, when `routineContext == nil`, arm `LoopRunModel.onFinished` to raise a
`RunCompletion` (the same struct ADR 0079 introduced — reused, not duplicated), snapshotting the
summited reach + command in percent-of-original units. That drives a `fullScreenCover` hosting
`RoutineBlockDoneView(title: loop.name, initialMastery: loop.mastery, promote: …, isLast: true,
upNext: nil)`. Fires only on natural completion, never on a manual stop (which leaves `onFinished`
unfired). Routine mode is untouched — the player's advance stays the hook.

**2. Commit mastery + note + promote together, through `persist()`.** `commitCompletion` writes
`loop.mastery`, adds the note via the existing `JournalWriter.add(to: .loop(loop), …)` path (loops
have owned a journal since ADR 0038/0058 — no new model), and, when the promote toggle is on, sets
`command = promoteTo` + `clearOverrideIfCaughtUp()`, then `persist()`. There's no following Start, so
this *is* the commit. Promote math is `PromoteOffer` as-is (unit-agnostic `command`/`reach`/`ceiling`);
the loop's ceiling is the percent range's upper bound (200% of original). Because a loop's command is a
**percent of original** (not an absolute BPM like an exercise), every loop tempo reference carries a
**`%`** and never a "BPM" suffix — the completion nudge reads **"Move command to 90%"**, and the shared
staircase signpost (`RoutineStairs`), previously hardcoded to `"{n} BPM"`, now reads **"90%"** for a
loop. This rides a single value-only `TempoUnit` (`.bpm` default for exercises, `.percent` for loops),
passed into both `RoutineBlockDoneView` and `RoutineStairs`, so the two exercise/loop tempo systems
stay one code path with the unit as the only difference.

**3. Remove the in-setup promote button** from `LoopRunView`. Promotion is post-run only, matching
exercises.

**4. "Practice now" launches the trainer from the loop edit sheet.** `LoopEditSheet` gains a
**Practice now** button in its Practice section, shown **only when the loop has a command tempo** (the
live edited value, `commandTempo != nil`) — the same gate that surfaces a loop into Practice → Loops
(`LoopLibraryView`), so setting a command tempo is the single act that both makes the loop a practice
item and reveals the button. Tapping it commits the sheet's edits (same write as Done, so a
just-set command tempo takes) and, after the sheet dismisses, the waveform presents `LoopRunView`
full-screen; exiting or finishing the run returns you to the waveform you launched from.

## Alternatives considered

- **A dedicated per-loop "detail" destination** (the first mockup). Rejected: Practice → Loops →
  a specific loop *is* that screen already; a second one duplicates it.
- **Replacing the loop row's Automator (ADR 0013) with a Practice button, or adding a third row
  control.** Rejected: the Automator stays a live control (and stays on the Metronome regardless);
  three 44pt controls crowd the landscape drawer (ADR 0042). The edit sheet is where command tempo is
  set, so "Practice now" belongs there — no row change, no semantic overlap with "A".
- **Gating "Practice now" on command tempo *and* mastery.** Rejected: the practice-library gate is
  command tempo alone; mastery is an independent optional rating. Requiring both would hide the button
  behind a field the library itself doesn't require.
- **Gating on the *saved* command tempo.** Rejected in favour of the **live** edited value, so the
  button appears the instant you tap "Set" — no "set it but the button's still hidden until you Done"
  dead spot. "Practice now" persists first, so the run reflects the just-set value.

## Consequences

- Loops and exercises now share one completion surface and one promote rule — the divergence ADR 0079
  left is closed.
- No schema change. `loop.mastery`, the journal relationship, and the ramp fields already exist;
  nothing is added or migrated.
- The waveform gains a full-screen presentation (`practiceLoop`) and a pending-launch hop
  (`pendingPracticeLoop` → `launchPendingPractice()` fired from the edit sheet's `onDismiss`), so the
  run cover presents only after the sheet fully dismisses — avoids the sheet-over-cover race.
  `launchPendingPractice()` also **pauses any in-progress waveform playback** before the run takes over,
  since the loop trainer owns a separate audio engine and two playing at once would double up.
- The Automator is unchanged on both the loop row and the Metronome.
