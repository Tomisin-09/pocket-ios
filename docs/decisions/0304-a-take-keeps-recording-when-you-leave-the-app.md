# ADR 0304 — A take keeps recording when you leave the app

- **Status:** Accepted, built on `pocket-437-lock-screen-controls` for 1.4.1 (build 11, before the
  archive). Tried on Tomisin's phone on 2026-11-17 from a `run-device.sh` build: *"this is working
  now"*. Which of the items owed below were tried was not listed one by one.
- **Date:** 2026-11-17
- **Amends:** ADR 0287 — **D3**: leaving the app no longer ends the take. The click and the take both
  carry on; an interruption beginning still ends and saves it. The rest of 0287 stands.
- **Relates to:** 0069 (takes, and the rule that a take is finalised before the audio under it stops)
  · 0050 (keeping the screen awake) · 0303 (the lock screen's stop of a continuous loop finishes the take
  first) · PR #389, 2026-11-02 (`pocket-396`, which made leaving end a take, with no ADR of its own)

## Context

**#389 ended a take when Red Moon went to the background.** A take left running kept the microphone
indicator lit after you left, which contradicted the manual's privacy page (*"Red Moon releases it as
soon as you leave the screen or send the app to the background"*). One modifier,
`endsTakeOnLeavingApp`, went on all seven recording screens. It fired on `scenePhase == .background`
and on an audio interruption beginning.

**`.background` includes the screen going to sleep.** Tomisin, 2026-11-17: *"When a take is being
recorded and the screen goes to sleep, the take stops. Let's revert this, because some takes can be
longer and it doesn't make sense for it to stop when the screen goes to sleep."* The run screens hold
the screen awake by default (ADR 0050), but not with that setting off, and the Journal's **Record a
take** never holds it at all. A take of a whole run-through, recorded with the phone face down, was
cut off when the phone locked itself.

**Sleep and leaving can't be told apart reliably.** Both arrive as `.background`. The protected-data
notifications that come closest only fire with a passcode set, and only after a delay. One rule has to
cover both.

## Decision

**D1. Leaving the app does not end a take.** The screen sleeping, the phone being locked, another app
opening: the take records on, with iOS's own recording indicator lit, until it is stopped in Red Moon or
the screen it was started on closes. This is the behaviour before #389, restored.

**D2. An interruption still ends it and saves it.** A call, Siri or an alarm beginning stops the
recorder whatever Red Moon wants. Finishing then saves the take up to that moment, instead of leaving
one that shows as recording and captures nothing. The modifier keeps only this half and is renamed
`endsTakeOnInterruption`, so its name says what it does. `RecordingController.endsTake(onInterruption:)`
and its tests are unchanged.

**D3. The privacy page says what happens now.** The microphone stays live while a take you started is
recording, the app in the background included, and iOS shows its indicator the whole time. The tuner
keeps its own promise unchanged: it stops listening when you leave it (`TunerView`, on `scenePhase`).

**D4. From the lock screen, a take ends the way it ends on the screen.** Pausing a ramp run, a song
block or the metronome leaves the take rolling, as the on-screen pause does (0287: *"carries on through
Pause"*). Stopping a continuous loop from the lock screen finishes the take first, as ■ does (0303 D3).
There is no lock-screen control for the take itself.

## Consequences

- **A long take survives the phone locking itself**, on every recording screen, the Journal's included.
- **A take you forget keeps recording until you come back** to Red Moon, with the indicator lit. That
  is the trade Tomisin chose. It is mono AAC at 44.1 kHz, so it grows slowly, but it does grow.
- **The live privacy policy is a separate text** (the site's `RedMoonPrivacyBody.tsx`). The repo's
  canonical `docs/privacy-policy.md` only says iOS shows the indicator whenever the mic is active, which
  stays true. The site's wording needs checking against D3.
- **Owed, on the phone:** start a take on a loop run with *Keep screen awake* off, let the screen
  sleep for a minute, wake it and stop: the take should be the whole length. The same from the
  Journal's **Record a take**. A call arriving mid-take should still save it.
