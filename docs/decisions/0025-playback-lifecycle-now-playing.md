# 0025 — Playback lifecycle (stop-on-exit) & lock-screen Now Playing

- **Status:** Accepted
- **Date:** 2026-06-20

## Context

`PracticeAudioEngine` (ADRs 0001, 0006, 0008) drives playback, but until now
nothing managed its *lifecycle* relative to the screen, and the app surfaced no
system transport controls:

- **No stop-on-exit.** The engine is owned by `WaveformPracticeModel`, held as
  `@State` on `WaveformPracticeView`. Leaving the screen eventually deallocates
  the model — and so the engine — but that's lazy: audio can keep rendering
  through the pop animation, and "eventually" is not a contract.
- **No lock-screen controls.** `UIBackgroundModes: [audio]` was already declared
  (playback survives screen-off), but with no `MPNowPlayingInfoCenter` metadata
  and no `MPRemoteCommandCenter` targets, a locked phone showed nothing and its
  play/pause did nothing.

The sharp edge is that `MPRemoteCommandCenter` is a **process-global singleton**.
Registering a target whose closure captures the engine means the command center
keeps the engine alive after the screen is gone — and keeps routing lock-screen
taps to a zombie transport. So lifecycle and Now Playing are one problem: the
thing that adds the controls must also be the thing that removes them.

## Decision

- **Stop on exit, tear down explicitly.** `WaveformPracticeView.onDisappear`
  calls `model.endPlaybackSession()`, which removes the remote-command targets,
  clears the Now Playing info, and calls `engine.stop()` (pause → stop the player
  → stop the engine → deactivate the shared `AVAudioSession` with
  `.notifyOthersOnDeactivation`). Audio halts immediately; nothing leaks via the
  global command center. The model is recreated per visit, so the next entry
  reconfigures from scratch.

- **Keep playing when backgrounded.** Stop-on-exit is about leaving the *screen*,
  not the app. Locking the phone or backgrounding while still on the practice
  screen keeps audio running (that's the point of the lock-screen controls);
  `UIBackgroundModes: [audio]` already permits it.

- **Play/pause only — no scrub, no skip.** A single-song practice screen has
  nothing to skip to, and the waveform is the place to seek. `NowPlayingController`
  wires `play`/`pause`/`togglePlayPause` to the engine and explicitly disables the
  next/previous/seek/skip/changePlaybackPosition commands so the system surfaces no
  dead buttons.

- **A pure `NowPlayingState`, a thin MediaPlayer bridge.** `NowPlayingState`
  (Foundation only) holds title/artist/duration/elapsed/isPlaying/speed and
  computes `reportedRate` — the speed multiplier while playing, `0` when paused,
  so the lock-screen clock freezes on pause and advances *in step with the
  practice speed* (not a hard 1×). It's unit-tested. `NowPlayingController`
  (`@MainActor`, MediaPlayer) maps it onto `MPNowPlayingInfoCenter` and owns the
  command-target lifecycle. The model owns the controller because Now Playing
  needs both the song's metadata and the engine's transport.

- **Event-driven, throttled refresh.** The lock-screen clock is re-anchored on
  transport-significant events (play/pause, rate change) with a forced push; the
  30 Hz playhead tick pushes at most every 0.5 s (the system extrapolates between
  pushes from elapsed-time + reported-rate). This keeps seeks visible on the lock
  screen within ~0.5 s without rebuilding the info dictionary every frame, and
  avoids threading a refresh call through all eight engine-seek call sites.

## Consequences

- Lock-screen / Control Center now show the song and a working play/pause; audio
  reliably stops when you leave the practice screen.
- Remote command handlers assume main-thread delivery (`MainActor.assumeIsolated`)
  — true for `MPRemoteCommandCenter`; it would trap loudly if Apple ever changed
  that, rather than corrupting state silently.
- Seek position on the lock screen can lag a real seek by up to ~0.5 s. Acceptable
  given the play/pause-only scope (no lock-screen scrubber). If a draggable
  lock-screen scrubber is added later, wire `changePlaybackPositionCommand` and
  drop the throttle for seek events.
- The session is set inactive on exit; nothing else in the app uses the audio
  session today, so the global deactivate is safe.
