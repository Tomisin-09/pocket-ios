# 0026 — Metronome (in-song click)

- **Status:** Accepted
- **Date:** 2026-06-21

## Context

Pocket can now *acquire* a tempo every which way — auto-BPM estimate (ADR 0004
rung 2), tap-tempo + manual entry (ADR 0024), play-along "set the 1" — and turn
`song.preciseBPM` + `song.downbeatSeconds` into beat positions via the pure
`BeatGrid` (ADR 0022). What was missing is the thing that makes that tempo
*audible*: a metronome. It's the last big item in the post-tap-tempo roadmap and
the natural consumer of a confirmed tempo + downbeat.

The defining requirement (locked with the user): **the click rides the song and
follows playback speed.** At 50% speed it plays at 50% of the song's BPM, locked
to the slowed track; at 2× it doubles. A fixed-BPM timer can't do this — it would
drift off a time-stretched track immediately. The click must be anchored to the
same audio clock the song plays on.

A second requirement: the metronome **must not touch `song.preciseBPM`**. Editing
the tempo is what the BPM settings are for; in-song the click is purely there to
accompany the track.

This ADR covers the **in-song** click. A standalone practice metronome (own tempo,
plus an automator ramp like loops have) is a follow-up slice on the same click
engine.

## Decision

- **A pure scheduler, an AVFoundation voice, both on the song's engine.** Timing
  math lives in `MetronomeSchedule` (Foundation only, unit-tested — the house rule
  that UI-free tempo math is exactly what breaks silently). Given the song's grid
  as *source* seconds, the current playhead, the playback `rate`, and a real-time
  horizon, it returns the beats due next and **how far ahead each sounds**:
  `delay = (beatTime − now) / rate`. That single divide is why the click follows
  playback speed. The AVFoundation side is `ClickVoice`: one `AVAudioPlayerNode`
  wired **straight to the main mixer** (bypassing the time-pitch unit, so clicks
  always sound at real pitch/rate) plus two synthesized buffers — an accented
  downbeat (~1200 Hz) and a plain beat (~900 Hz), short sine bursts with a fast
  decay so they read as ticks, not tones.

- **Share the song player's clock.** `ClickVoice` attaches to the *same*
  `AVAudioEngine` as the song player, so clicks are scheduled sample-accurately on
  the shared render clock. `PracticeAudioEngine` refreshes the schedule on its
  existing 0.03 s display timer, scheduling ~1 s ahead and **deduping by a
  watermark** (the source time of the last beat queued) so each beat fires exactly
  once across refresh ticks.

- **Flush on every discontinuity.** A queued click is timed for one rate/position;
  the moment that changes — `setRate`, `seek`, `setLoop`/`clearLoop`, `pause`, a
  loop wrap — the engine cancels the queued clicks (`stopAll`), resets the
  watermark, and lets the next tick refill. During an active loop, a new pass
  resets the watermark so the region's beats re-fire, and beats past the loop end
  are skipped (playback wraps before reaching them).

- **Gated on a grid; no BPM side effects.** The toggle is the reserved transport
  `metronome` button, enabled only when the song has **both** a tempo and a
  downbeat (the same condition under which the beat grid draws — we never guess
  phase). The model pushes the grid (`beatGrid` fractions × duration) to the engine
  when the click turns on and whenever the grid changes; it never writes back to
  the song.

- **Lifecycle (ADR 0025).** `pause()` and `stop()` silence the voice; nothing
  clicks after screen exit. Clicks are not "Now Playing" — the
  `MPNowPlayingInfoCenter`/command-center path is left untouched.

## Consequences

- The click stays locked to the track through speed changes, seeks, and loops —
  the feature's whole point — at the cost of a flush-and-refill on each of those
  events (inaudible: the refill runs within one 0.03 s tick, ~1 s before the next
  click is due).
- The metronome is scoped to playback that has a grid; songs without a confirmed
  tempo + downbeat show the toggle disabled. That's intentional — a guessed phase
  would click *off* the beat, worse than no click.
- Loop-synced clicks rely on the crossfaded loop buffer wrapping at ~the region
  end (ADR 0006); the ~15 ms crossfade can nudge the final in-region click, which
  is below perceptual threshold for a tick.
- The shared-engine design means the standalone metronome (follow-up) reuses
  `ClickVoice` + `MetronomeSchedule` but runs its own `AVAudioEngine` (no song
  clock to share) — the pure scheduler is unchanged, fed a generated beat sequence
  instead of a song grid.
- **Standalone tool deferred (2026-06-21).** A standalone practice metronome
  (own tempo, plus an automator tempo-ramp reusing `AutomatorConfig` with *bars*
  as the step unit) is intended but **postponed until the homescreen / navigation
  exists** — the app has no home surface yet to reach it from. It's to be
  **incorporated with warm-up routines** rather than hung off the Library toolbar.
  The Slice A engine (`ClickVoice` + `MetronomeSchedule`) was built to support it
  unchanged.
