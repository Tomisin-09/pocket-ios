# ADR 0272 — Leaving a routine asks first

- **Status:** Accepted. Built on `pocket-386-done-in-block-bar`, beside ADR 0271.
- **Date:** 2026-10-22
- **Relates to:** 0071 (the routine chrome, whose `onExit` this puts a question in front of) · 0271
  (Done leaves the top band, so ✕ is the one control left there that ends anything) · 0117 (leaving
  logs nothing for the block on screen) · 0195 (the tune-up screen's ✕, which does not ask).
- **Schema:** none.

## Context

Tomisin, on the device, after trying 0271: when you exit out of a routine, there should be a warning
that gives you a chance to cancel, in case it was done by accident.

✕ sits at the top left of every block and every rest, and one tap ended the session. What an
accidental tap costs is more than the tap: the block on screen is not logged, a rating and note on the
between-blocks screen are not kept, and the routine starts again from its first block next time. There
was no way back.

## Decision

- **D1 — Leaving mid-session asks.** An alert titled **Leave this routine?**, saying *Blocks you've
  finished stay in your practice log.*, with **Keep practising** (cancel) and **Leave** (destructive).
  Keep practising changes nothing: the block, its audio and its clock carry on underneath.
- **D2 — Every way out of a session in progress.** The ✕ on every block and on a rest countdown, which
  all go through one closure (`RoutineRunContext.onExit`), and the ‹ *Exit routine* on the
  between-blocks screen. One alert, on the player, serves all of them.
- **D3 — Not where nothing is lost.** The ✕ on the tune-up screen, before the session has started, and
  **Done** on the finish screen, after it has ended, leave straight away. A question there would be a
  question about nothing.
- **D4 — An alert, not a confirmation dialog.** On iOS 26 a confirmation dialog is a popover pointing at
  the view it is attached to, so it would need attaching once per exit and would draw differently on
  each. An alert is centred, the same everywhere, and its **Leave** is not under the finger that just
  tapped ✕, so a second accidental tap in the same place cancels nothing and confirms nothing.

## Alternatives rejected

- **Leave at once, with an undo.** Undo would have to rebuild the session where it was: the block, its
  rep, its clock, and a ramp part way through. That is a much bigger feature than a question.
- **Ask only when something would be lost.** Something is lost on almost every block, and a question
  that appears on some blocks and not others is one the player can't predict.
- **A setting to turn the question off.** Not asked for. Not decided here.

## Consequences

- Leaving a routine on purpose is one tap more than it was.
- `docs/manual/routines.md` says that ✕ asks first.
- `RoutineLibraryUITests.testLeavingARoutineAsksFirst` covers ✕, Keep practising and Leave on the
  seeded routine. The between-blocks screen's exit goes through the same alert but is not driven by a
  test: reaching it means running a block to its end.
