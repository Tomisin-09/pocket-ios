# ADR 0303 — Everything that keeps playing answers to the lock screen

- **Status:** Accepted, built on `pocket-437-lock-screen-controls` for 1.4.1 (build 11, before the
  archive). Tried on Tomisin's phone on 2026-11-17 from a `run-device.sh` build: *"this is working
  now"*. Which of the items owed below were tried was not listed one by one.
- **Date:** 2026-11-17
- **Amends:** ADR 0025 — **"Stop on exit, tear down explicitly"**: a producer no longer clears the
  global Now Playing info or removes the command targets itself. It lets go of a claim, and the lock
  screen goes back to the claim beneath (D2). The lock screen's reach widens from the song screen to
  every producer that can sound for more than a few seconds (D1). *Play/pause only* stands, and so does
  stopping the song screen's audio when you leave the screen.
- **Relates to:** 0129 (the block hand-over that overlaps two producers) · 0292 (Blood Moon, whose art
  the Now Playing square kept missing) · 0126 (the vector brand art, the first time it was missed) ·
  0104, 0135 and 0289 (the continuous-loop modes) · 0066 and 0071 (song blocks) · 0069 and 0174 (takes)
  · 0304 (a take now carries on in the background, which is why D3's take rule matters)

## Context

Tomisin, 2026-11-17, before archiving 1.4.1, with three screenshots of a song playing: Control Center,
the lock screen and the Dynamic Island. *"Could we update these interfaces? Also, we need to make sure
that any sound that's produced from the app can be paused/stopped when out of the app."*

**The square beside the song was still the July crescent**: pale blue, engraved, on black. It is
`DefaultArtwork`, a hand-made PNG from 2026-07-20 (user-testing note 3). The brand art became vector
in ADR 0126 and red in ADR 0292, and both times the App Icon and the imagesets were re-cut by
`scripts/derive-brand-svgs.py`. This PNG was not in the script, so nothing re-cut it.

**Most of what plays had no lock-screen control at all.** Every producer, audited:

| Producer | Plays in | Lock screen before | Now |
|---|---|---|---|
| `WaveformPracticeModel` | the song screen | play/pause | unchanged |
| `StandaloneMetronomeEngine` | metronome, exercise runs, freeform blocks, two previews | play/pause | unchanged |
| `LoopRunModel`, ramp run | a loop run, a routine's loop block | **none** | play/pause |
| `ContinuousLoopPlayer` | Active listening, Improvise, Watch it on the neck, Count and Name the notes | **none**, and it never stops on its own | play starts it, pause stops it (D3) |
| `SongPlayAlongModel` | a routine's song block | **none** | play/pause |
| `RecordingPlayer` | takes: the Journal, the Takes sheet, a take's screen | **none** | play/pause |
| `LoopAudioPreviewPlayer` | a block's *Hear the loop* | none | none: stops itself after 10 s |
| `ToneEngine` | a chord's Hear, the tuner's reference tone and ding | none | none: 1.8 s at most |
| `MetronomeSoundPreviewPlayer` | Settings, the metronome sound | none | none: eight beats, about 5 s |
| a slice | Count and Name the notes | none | none: one phrase |

`UIBackgroundModes: audio` keeps all of them sounding when the phone locks. The continuous loop was
the worst: it is built to loop until you stop it, so leaving Active listening's screen up and locking
the phone left a loop playing that only the app could stop.

**And the producers overlap.** `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` are
process-global, and each `NowPlayingController` cleared the global info when it tore down. A routine
starts the incoming block before it tears down the outgoing one (ADR 0129, bug 1). Read against that
order, an exercise block handing to another cleared the lock screen just after the incoming click had
filled it. That is from the code, not seen on a phone. Adding four more producers to that scheme would
have spread it to every hand-over.

## Decision

**D1. Anything that can sound for more than a few seconds claims the lock screen while it plays.** The
four producers marked **none** above now do. The ones that stop on their own within ten seconds don't:
a lock-screen entry that appears and vanishes in that time is noise, and there is nothing to stop.

**D2. One writer, and claims.** `NowPlayingHub` is the only code that writes the two global centers.
A producer *claims* the lock screen (`activate`), pushes its state (`update`) and *lets go*
(`teardown`); the hub applies the rules of the pure, unit-tested `NowPlayingClaims`:

- **the most recent claim owns it**, and claiming again moves a producer back to the top;
- **only the owner draws**: an update from beneath is kept, not shown;
- **letting go hands back**: the claim beneath takes over with what it last pushed, and with nobody
  left the lock screen is cleared;
- **a release from beneath changes nothing on screen**, and nor does anything from a producer with no
  claim, so a playhead tick after a stop can't bring the session back.

The remote-command targets are registered when the first claim arrives and removed when the last one
goes. They capture no producer: the hub looks up the owner when a command arrives, so no closure keeps
an engine alive (the sharp edge 0025 was written about). A controller that is freed without letting go
lets go in its `deinit`.

**D3. The lock screen's pause means what the screen's own pause means.**

- **A ramp run, a song block and a take** have a paused state on screen, so pause holds the place and
  play resumes from it.
- **A continuous loop** has two states, ▶ and ■, and the screens built on it read `isPlaying` falling
  as an ending. Count the notes closes a pass on it, and a take is finalised *before* the bed stops (ADR
  0069's ordering). A third state would reach all of them. So the lock screen's pause **stops** the
  loop and its play **starts it again** from the top of the region. The player keeps its claim across
  that stop, so there is still a play to press. The on-screen ■, or leaving the screen, lets it go.
  A host that records sets `onRemoteStop` to its take finish, so the lock screen's stop finishes the
  take first, exactly as ■ does. The lock screen's play **never arms a take**.

**D4. What each one is called, and what its clock shows.**

| Producer | Title | Line beneath | Clock |
|---|---|---|---|
| song screen, song block | the song | its artist | the song's timeline, at the practice speed |
| loop run, continuous loop | the loop (*Loop* when unnamed) | song · artist | time spent sounding |
| a stretch of a song (Watch it on the neck) | the song | its artist | time spent sounding |
| a take | its name (*Take* when unnamed) | the Journal's caption for it | the take's timeline |
| metronome | *Metronome* | tempo · meter | time spent sounding (unchanged) |

A loop has no "1:42 of 3:32" to show, so like the metronome it shows how long it has sounded: the pure,
unit-tested `PlayClock`, held across pauses.

**D5. The Now Playing art is the App Icon's own render.** `derive-brand-svgs.py --app-icon` now
writes `DefaultArtwork/artwork-1024.png` as a byte copy of the icon it has just rendered, so the two
can't differ and the next logo change can't leave the lock screen behind. The Dynamic Island colours
its waveform from this art, so it follows too.

## Consequences

- **Every sound Red Moon makes outside the app can now be stopped from outside it**, or stops on its
  own within ten seconds. A routine's hand-over keeps the incoming block on the lock screen.
- **A continuous loop stopped from the lock screen starts again from the top of its region.** A loop
  that is being listened into the ear has no meaningful middle to resume from, and resuming mid-region
  would be the third state D3 keeps out.
- **A paused take holds its claim until the take is unloaded.** Every screen that plays takes
  unloads on leaving (`player.stop()` in `onDisappear`), so the lock screen goes back to whatever is
  beneath, the song screen for instance, when the takes close.
- **Not built:** skipping or scrubbing from the lock screen. 0025's reasoning stands, and the greyed
  ⏪ ⏩ on the lock screen are iOS drawing disabled commands.
- **Owed, on the phone:** the art on all three surfaces; lock-screen pause and play on a routine's loop
  block, a song block, Active listening (with a take rolling: the take should be saved when you press
  pause) and a take in the Journal; a routine handing from one exercise block to the next with the
  phone locked, which should keep the lock screen showing.
