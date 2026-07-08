# 0070 — No performance feedback: the player is the judge

- **Status:** Accepted (2026-07-07)
- **Date:** 2026-07-07

## Context

Practice apps commonly bolt on **automated feedback**: pitch detection, timing
scores, "you missed the C#", accuracy percentages, streak grades. It is the
default thing people expect a "smart" practice tool to do, and it is technically
within reach — mic capture (ADR 0069 scoping) plus onset/pitch analysis would let
us grade a take.

Pocket's practice model is deliberately built the other way. The metronome and the
routine player push the player *at or past* their command tempo — the point of
[ADR 0066]'s auto-advance is **controlled discomfort, not clean reps**: the command
tempo is a reference marker for "just outside your comfort zone," and playing there
will often not be clean *by design*. A machine grading those reps would be scoring
the user against a standard the exercise deliberately puts out of reach, and would
frame the honest, useful part of practice — the mess at the edge — as failure.

There is also a craft argument the product wants to stand behind: **you can find
music in the mistakes.** A wrong note held, a rushed bar, a bend that overshoots —
these are where phrasing and personal voice come from. An app that flags them as
errors trains them out.

## Decision

**Pocket does not provide automated performance feedback. The player is the sole
judge of their own playing.**

Concretely, and closing off the alternatives:

1. **No scoring or grading** of a take — no accuracy %, no timing score, no
   pass/fail, no per-note right/wrong.
2. **No real-time pitch/timing detection** of the user's playing used to correct,
   coach, or gate progress. The click is a *reference*, never a judge; tempo
   advancement stays **user-driven** (ADR 0016 — clean-before-fast is the player's
   own call, self-reported, not measured).
3. **The recording feature (ADR 0069) stays a mirror, not a critic.** A practice
   take is for the user to *relisten and self-assess*; the app offers playback, not
   analysis. This is the one and only role mic capture plays.
4. Judgement fields that already exist (loop `mastery` / `focus`, ADR 0039) are
   **self-reported intent**, not app verdicts, and remain so.

This does not forbid *non-judgemental* signal — count-ins, the visible ramp, session
progress ("2 of 5"), or a plain recording to listen back to. The line is between
*reflecting* the session back to the user and *grading* it for them.

## Consequences

- **Simpler engine, sharper identity.** No DSP analysis pipeline to build, tune, or
  defend; the product's stance ("we don't grade you — you do") is a real
  differentiator against feedback-heavy competitors.
- **The routine player (ADR 0066, slice 3) needs no evaluation layer.** Block
  completion is the material's own natural length (one ramp pass, a rest countdown),
  never "play it correctly to advance."
- **Reversal cost is high by intent.** Shipping this as a stated principle means
  adding scoring later would contradict a published stance, not just add a feature —
  which is the point.

## Alternatives considered

- **Optional feedback, off by default.** Rejected for now: even opt-in scoring
  seeds the "the app decides if I'm good" frame this ADR rejects, and it still
  requires building the analysis pipeline. Can be revisited, but only against this
  ADR.
- **Timing-only feedback** (grade rhythm, ignore pitch). Rejected: same framing
  problem at the edge of comfort, where rushing/dragging is expected.

[ADR 0066]: 0066-practice-routine-model.md
