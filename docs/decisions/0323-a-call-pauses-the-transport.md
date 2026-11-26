# ADR 0323 — A call pauses the transport

- **Status:** Accepted. Built on `pocket-488-calls-play-along-and-flakes` (PR #478, 2026-11-26)
  and driven on the simulator through a stand-in for a call (D6). Tomisin chose D2 the same day.
  The device pass, with a real call, is owed.
- **Date:** 2026-11-26
- **Amends:** ADR 0321 — **D3** stopped the loop modes' count at an interruption with a flag on the
  player, and left *"the ■ over silence"* as a transport question. This answers it: the loop stops, so
  ▶ comes back and the count stops because the audio did (D1, D5). D3's rule stands: time after an
  interruption is not counted.
- **Amends:** ADR 0322 — **D5** listed *an interruption* among the changes the song player's model
  watches for, through an observer of its own and a flag. The engine now pauses itself and the pause
  reaches the count like any other (D5). D5's split of who counts and who writes stands.
- **Relates to:** 0242 (the Metronome logs the time the click sounded, which ran on through a call
  until now) · 0303 (the lock screen: a loop mode's pause is a stop) · 0304 (a take ends when an
  interruption begins, which this leaves as it was) · 0318 (`-failSaveIn`, the drill this one follows)
  · 0050 (the screen held awake) · 0070 (never grades)
- **Schema:** none.

## Context

Building ADR 0321, the 755-minute fix, turned up an older fault under it. A call, Siri, an alarm or
another app's audio stops Red Moon's audio: the session is `.playback`, which doesn't mix. The system
stops the audio engine without telling it, and nothing in Red Moon was listening, so every transport
went on reading as playing over the silence it had made:

- the song player's ■ stayed up, and so did the loop trainer's Pause and the play-along's;
- Active listening and Improvise went on offering *Stop the loop*;
- the Metronome went on reading Pause, an exercise run's ramp went on climbing with nothing heard, and
  the Metronome's practice-log count (ADR 0242, the time the click sounded) ran on for as long as the
  player was away, which is the 755-minute bug by another door;
- a take being played back went on showing its pause.

ADR 0321 and 0322 stopped the two new counts with a flag, *silenced by interruption*, and left the
transport alone. That kept the log right for those two screens and left the screen wrong on all of
them, and the Metronome's log wrong as well.

The manual had already promised the right behaviour for one sheet: *"If something else pauses the
song, such as a call or headphones coming out, the sheet says paused and offers Resume"* (the song
player's ramp, `looping.md`). It said so because the sheet reads `engine.isPlaying`, which a call never
moved.

## Decisions

### D1 — The engine pauses itself, and the transport above it follows

Each of the three things that play — `PracticeAudioEngine`, `StandaloneMetronomeEngine` and the take
player, `RecordingPlayer` — holds an `AudioInterruptionObserver` and pauses itself when an interruption
begins. No screen has to remember to listen, and a screen that plays one of them for something that
isn't practice (*Watch it on the neck*) is covered too.

An owner that keeps a transport of its own is told (`PracticeAudioEngine.onInterrupted`) and moves it
the way its own controls would:

| What was playing | After the call |
|---|---|
| The song player | Paused, ▶ |
| A loop trainer ramp | Paused, **Resume** carries on up the same staircase |
| Active listening, Improvise, *Watch it on the neck* | Stopped, as the lock screen's pause stops them: a take is finished first, and the lock screen keeps its play |
| A Name-the-notes slice | Cut |
| The play-along | Paused, **Resume** |
| The Metronome, an exercise run | Paused, **Resume**; the sitting's time and a ramp's plateau are kept |
| A freeform block's click | Off, and its toggle turns it back on |
| A take playing back | Paused |

The loop modes stop rather than pause because they have only two states, ▶ and ■ (ADR 0303); every
other transport has a pause and uses it.

### D2 — Nothing resumes by itself

Tomisin, 2026-11-26: stay paused. When the call ends, the player presses ▶ or Resume when their hands
are back on the instrument. A loop never starts while the phone is being put down.

**Rejected: resume when iOS says it may** (`.shouldResume`, after a call or Siri, not after another
app's audio), as a music app does. It is the behaviour of an app being listened to, not one being
played along with, and it would need a second callback, a record of what was playing, and a rule for
every transport in D1's table.

### D3 — The next start brings the audio back

After an interruption the system has deactivated the session, and a producer started into an inactive
session plays silence with no error anywhere (`AudioPlumbing.ensurePlaybackSession`). So the first
start after one asserts the session again, guarded as every producer's start is so it can't downgrade a
take's record session. The Metronome's Resume also restarts its engine: its pause never stops the
engine, so nothing else would.

### D4 — The output going away pauses too

Headphones pulled out, AirPods put back in their case, a car disconnecting: a route change whose reason
is the old device being unavailable. Apple's rule for a player is to pause rather than carry on out of
the speaker, and the manual already said the ramp sheet does. The same observer takes it, with the same
result. A device arriving, or the category changing for a take, is not a cut.

### D5 — The two flags go

ADR 0321's flag on `ContinuousLoopPlayer` and ADR 0322's on `WaveformPracticeModel` existed only because
the transport went on reading as playing. Now it doesn't, so they are removed, with the song player's
own observer and the one `RampLessRunLog` carried for the loop modes. `SongPlayerTime.sounding` loses its
`silenced` input. The counts stop because the audio did.

### D6 — A stand-in for a call, for the UI tests

A simulator can't ring, and a UI test runs in a process that can't reach the app's notifications. So a
test posts a Darwin notification (`UITestHooks.interruptAudioNotification`) and the app answers with the
interruption the system posts (`UITestInterruptionDrill`), in Debug builds under `-uiTesting` only, as
`-failSaveIn` is (ADR 0318). Everything from the notification to the screen is the real code.
`InterruptionUITests` watches the song player, Active listening and the Metronome. What the drill
can't stand in for is the system stopping the engine and deactivating the session, D3's half: that is
the device's.

## Consequences

- **The transport tells the truth after a call**, on every screen in D1's table.
- **The Metronome stops counting at a call.** Its log, and an exercise run's ramp, no longer run on
  over silence.
- **The manual's line about the ramp sheet is true now**, for a call and for headphones.
- **The device pass needs a real call**: on the song player, Active listening, the Metronome and the
  play-along. Pass if each shows ▶ or Resume, and plays again when pressed.

## What stays out

- **The engine stopping for another reason**: the hardware's format changing without a device going
  away, or the media server resetting. Neither has been seen; each needs its own handling.
- **A run's logged length.** A loop trainer or exercise ramp still logs Start to its natural end, a
  pause included, so a ramp paused by a call and resumed after it logs the call. That was already so for
  the on-screen Pause.
- **A freeform block's length**, which has no audio to count. Parked in the backlog, with the options.
- **Resuming** (D2).

## Build notes

- `AudioInterruptionObserver` (in `AudioInterruption.swift`) is a class so letting it go stops the
  observing: an engine can't remove an observer from its own `deinit`, which Swift 6 keeps off the main
  actor.
- `InterruptionPausesTheTransportTests` posts the system's notifications at the observer and both
  engines. Mutants checked: `PracticeAudioEngine` not pausing itself fails its test, and the
  Metronome's Resume not restarting its engine fails the Metronome's. `InterruptionUITests` was run
  against three: that engine not pausing (the song player's test failed), the Metronome not pausing
  (the Metronome's failed), and `ContinuousLoopPlayer` not stopping (Active listening's failed). Active
  listening passes with the engine mutant alone, rightly: its player stops the loop itself.
