# 0016 — Speed-trainer staging: a "clean-before-fast" advance gate

- **Status:** Accepted (extends ADR 0013; build deferred — slice after the ramp ships)
- **Date:** 2026-06-18

## Context

ADR 0013 built the per-loop speed-trainer ramp: it advances through plateaus purely on
**loop-wrap count** (`loopsPerStep`), **unconditionally** — every N passes the tempo
steps up, regardless of how the pass went. Practice pedagogy is emphatic that this is
backwards: build **accuracy first**, and only raise the tempo **after error-free reps**
("clean before fast"; the staged order is control → coordination → speed). A purely
count-driven ramp marches the user through tempos they have not yet cleaned — the exact
anti-pattern.

Source: guitargearfinder.com, *"How to Play Fast on Guitar"* and the technique
exercise articles, whose shared method is the control→sync→speed staging and "only
increase tempo once you can play it cleanly." Encodable distillation only; no source
content is used (see `docs/research/guitargearfinder-catalog.md`).

**The hard constraint:** Pocket plays the *reference track* while the user plays
**along**; we do **not** analyse the user's own playing. There is no signal for "was
that rep clean?" So an **automatic** accuracy gate is impossible — and we will **not**
add microphone capture/pitch-detection to manufacture one (it is unreliable, and per
`AGENTS.md` we don't add a permission the app doesn't already exercise). The gate must
therefore be **user-driven**. This ADR records that honest design.

## Decision

The ramp gains a staging gate; the stepping math from ADR 0013 is reused, only the
**advance trigger** changes.

- **A1 — Two advance modes.** `AutomatorConfig` gains an `advanceMode`:
  - **`.automatic(loopsPerStep:)`** — today's ADR 0013 behaviour, unchanged and still
    the default for casual use.
  - **`.onConfirm`** — the ramp **holds at the current plateau** and steps up only when
    the user taps **"Got it — step up."** This is the deliberate-practice mode that
    encodes clean-before-fast: *you* decide a tempo is clean, then advance.

- **A2 — Stumble steps down, not just up.** In either mode a **"too fast — back off"**
  action drops the ramp **exactly one plateau** (and, in `.onConfirm`, resets the
  current clean-rep streak). This complements ADR 0013's "grab the slider = manual wins"
  with a structured single-step retreat that stays *on* the ramp rather than abandoning it.

- **A3 — Start slow by default; the rest is guidance, not coercion.** The setup sheet
  defaults to a **conservative start %** and surfaces the clean-before-fast idea as copy
  ("play it clean a few times, then step up"). We never force a tempo — consistent with
  ADR 0014 R8 and ADR 0013's existing low-start bias.

- **A4 — Cross-exercise staging lives in the planner, not the ramp.** The
  control → coordination → speed ordering *across different skills* (e.g. don't schedule
  a sweep speed-ramp before basic alternate-picking control) is the **planner's** job via
  the taxonomy's `difficulty`/`prereqs` (ADR 0015 + `docs/practice-techniques.md`). ADR
  0016 governs only **within-ramp** advancement; it does not try to sequence exercises.

### Pure stepping math (the test spec)

`AutomatorConfig` carries `advanceMode`. The plateau interpolation is the **same**
`speed(atLoopIteration:)` from ADR 0013:

- `.automatic` advances exactly as today (a function of loop-wrap count).
- `.onConfirm` advances via explicit model state (`stepUp()` / `stepDown()`), each call
  moving one plateau through the *same* interpolated sequence; loop-wrap count no longer
  drives the step.

Properties to assert: `.onConfirm` never advances without a `stepUp()`; `stepDown()`
drops exactly one plateau and never below the start; neither mode exceeds the target;
`.automatic` is byte-for-byte unchanged from ADR 0013's tests; switching modes
mid-ramp preserves the current plateau.

## Consequences

- The automator supports genuine **"nail it, then speed up"** practice, not only a timed
  auto-ramp; the back-off step (A2) makes it forgiving and keeps the user on the rail.
- Persisted as **another defaulted scalar on `Loop`** (an `advanceMode` discriminator +
  its associated value), following ADR 0013/0012's lightweight-migration-safe pattern.
- The "Set ramp" / "Turn off ramp" sheet (ADR 0013) gains a mode choice and, when armed
  in `.onConfirm`, transport-level **step-up / back-off** affordances.
- No new permissions, no audio analysis of the user — the pedagogy is captured entirely
  through user-driven controls.

## Alternatives considered

- **Automatic accuracy detection (mic + pitch analysis to auto-gate the ramp)** —
  rejected: unreliable for polyphonic guitar against a backing track, and it would
  require a microphone usage string the app otherwise doesn't need (`AGENTS.md`:
  never add an unexercised permission). The user-confirm gate (A1) captures the
  pedagogy without it.
- **Leaving ADR 0013 count-only** — rejected: it advances through un-cleaned tempos,
  the precise anti-pattern the sources warn against; A1 fixes it.
- **Auto-advance but auto-*retreat* on a detected miss** — rejected for the same
  sensing reason as the mic option; A2 makes the retreat an explicit user action.
- **A standalone metronome trainer for speed** — deferred: the transport "Auto" slot
  stays reserved for a future metronome (ADR 0013), separate from this loop-ramp gate.
