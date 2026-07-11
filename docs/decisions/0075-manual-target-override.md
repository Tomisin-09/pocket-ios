# 0075 — Manual reach/target override for loops & exercises

- **Status:** Accepted
- **Date:** 2026-07-10
- **Superseded in part by:** ADR 0077 — §3's reach editor **on the exercise detail sheet** (the
  `Stepper` + `commitReach` in ⓘ) is removed as ⓘ becomes read-only. The override model itself — the
  stored optionals, effective accessors, auto-clear on catch-up, and **run-screen** reach editing —
  is fully retained.
- **Extends:** ADR 0045 (exercise command/target reach), ADR 0046 (command-anchored run ramp,
  Phase A/B), ADR 0057 (single write path per model). Pairs with ADR 0013 (loop automator target,
  already user-editable, out of scope here) and ADR 0070 (no grading).
- **Supersedes:** nothing. Closes the "pinned-target flag" that ADR 0045 explicitly deferred
  (`Exercise.promoteCommand`: *"a Phase 2 … pinned-target flag are out of scope here"*).

## Context

Every trainable unit in Pocket climbs from a **working** floor, through the owned **command**
tempo, up to a **reach** (the goal above command). The reach was the *only* tempo the player could
not set — it was always auto-derived from command via `TempoStretch` (`Exercise.derivedTarget`, BPM;
`Loop.derivedTargetSpeed`, × of original), a proportional stretch (`defaultProportion = 0.06`)
clamped to `+3…+15 BPM` / `+0.02…+0.10×`. That constant is reasonable but **arbitrary**, and a
player often has a concrete goal in mind (a solo at gig tempo, a gentler target on a hard passage)
that the auto value can't express.

The waveform automator's target (`Loop.automatorTargetSpeed`, ADR 0013) is a *different* tempo — the
waveform-screen speed ramp — and is already user-editable, so it stays out of scope. This ADR is
solely the **command-anchored reach**, unified across both models.

## Decision

### 1. An optional stored override, per model, with an effective accessor

- `Loop.targetSpeedOverride: Double?` (× of original) and `Exercise.targetTempoOverride: Int?` (BPM).
  Optionals with **no declaration default**, so SwiftData lightweight migration leaves pre-0075 rows
  as `nil` (auto) with no store wipe — the CoreData 134110 additive-migration rule (ADR 0011/0012),
  shared with `mastery` / `commandTempo`.
- Effective accessors every surface reads: `Loop.targetSpeed { targetSpeedOverride ?? derivedTargetSpeed }`
  and `Exercise.reachTempo { targetTempoOverride ?? derivedTarget }`. The pure auto values
  (`derivedTargetSpeed` / `derivedTarget`) are kept untouched so a **reset-to-auto** affordance can
  fall back to them. `Loop.ramp` and `Exercise.ramp` summit at the effective reach.

### 2. A reach must stay above command — auto-clear on catch-up

A target below the tempo you already own is meaningless. The editors clamp a pin to `> command`, and
`promoteCommand(to:)` **auto-clears** the override when the newly-owned command meets or passes it
(`if let pinned = override, pinned <= command { override = nil }`) — the reach then reverts to the
auto derivation above the new command. The run/detail UIs mirror this locally as command is nudged,
so the pin never lingers below command.

### 3. Editable-in-place Reach row + reset-to-auto

The read-only "Reach" row becomes an editable stepper/typable row (reusing `EditableTempoRow` on the
run screens, a `Stepper` on the exercise detail sheet), with a one-tap **Reset to auto** shown only
while a pin is set; the caption switches from `auto · +X` to `custom goal`. Loops edit in `%`,
exercises in `BPM`. All commits route through the existing single write paths (`persist` on Start /
Save; `commitReach` on the detail sheet Done, ordered **after** `promoteCommand` so its auto-clear
can't wipe a just-written pin) — no divergent second write path (ADR 0057).

### 4. `Exercise.targetTempo` is now vestigial

The stored `Exercise.targetTempo: Int = 120` was written by `promoteCommand` but read nowhere (every
reach read now goes through `reachTempo` / `derivedTarget`). `promoteCommand` **stops writing it**;
the field is **retained un-removed** for migration safety (dropping a stored attribute is not
additive) and marked vestigial. `Loop` added no vestigial field (its reach was always computed).

### 5. Separately: the redundant transport timecode is dropped

The waveform practice transport bar's idle **playback timecode** duplicated the live playhead time
already rendered as the canvas `TimeBubble`. It is removed; the header renders empty when idle (fixed
height preserved so the row never shifts). Design brief §4.1 updated.

## Consequences

- Players can pin a goal more or less ambitious than the auto `+~6%`, and it sticks across command
  promotions until command catches up.
- **The pins are the data substrate for a learned default.** Each pin is stored per unit as a real
  "at command X, this player reached for Y" signal, with no new logging. This opens a **future
  fast-follow ADR**: a pure, per-user, **on-device** `learnedProportion` over the accumulated
  target/command ratios that seeds the reach for *newly-created* units only — never retroactively
  mutating an existing un-pinned reach, no analytics backend (AGENTS.md no-telemetry). Not built here
  (a learner tuned against zero pins just reproduces `0.06`); this ADR keeps the door open by
  persisting each pin and keeping the auto value a single pure `TempoStretch` seam.

## Alternatives considered

- **A one-off run-screen nudge, not stored.** Rejected — the goal should persist and be the training
  data; an ephemeral nudge is neither.
- **Removing `Exercise.targetTempo`.** Rejected — not an additive migration; retained vestigial.
- **Building the learned default now.** Deferred to a future fast-follow ADR — no pin data to train
  on until this ships.
