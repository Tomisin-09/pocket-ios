# 0006 — Region looping: continuous loop, reschedule-on-end, exit via chip

- **Status:** Accepted
- **Date:** 2026-06-16

## Context

The practice screen could activate a loop (highlight it, drive the transport
range) but playback didn't actually loop the region — the `repeat` toggle was a
visual no-op. Looping a section is the core of the practice tool, so it needs to
be real. Two questions had to be settled: how the engine loops, and how the user
turns looping off.

A previous pass removed the transport's `repeat`/`clear` buttons as redundant.
That left "how do you stop looping?" open, and re-raised whether a repeat toggle
is justified at all.

## Decision

- **An active loop loops continuously.** There is no on/off toggle — looping
  *is* the behaviour of an active loop. The thing that resembled "repeat" — a
  per-loop **count** — already lives on the model (`Loop.repeats`) and belongs to
  the future **tempo automator** ("loop N times, then raise the speed"), not a
  transport switch. So no repeat toggle.
- **The engine loops by reschedule-on-end.** `PracticeAudioEngine` gains a
  `loopRegion` (seconds) set via `setLoop`/`clearLoop`. `scheduleSegment` now
  ends the segment at the loop end (via the pure, tested
  `AudioMath.loopSegment`), and the completion handler seeks back to the loop
  start and keeps playing instead of stopping. The existing `generation` token
  guards against stale completions across the wrap.
- **Exit via a small ✕ chip** next to the loop name in the transport. Activating
  is done by tapping a loop row; the chip is the deliberate, discoverable way
  back to full-song playback. (Chosen over tap-row-to-toggle, which collided with
  the row's play/pause, and over a hidden long-press.)
- **`activeLoopID` is the single source of truth.** `applyActiveLoopToEngine()`
  mirrors it onto the engine's `loopRegion` wherever it changes (activate, save,
  range-edit, delete, clear), so the highlight and the audio never disagree.

## Consequences

- The wrap is **not gapless** — `seek` stops and reschedules the player, leaving
  a few milliseconds of silence at the loop point. Acceptable for V1 practice;
  gapless (schedule-ahead double-buffering) is a future refinement.
- `Loop.repeats` is now explicitly an automator input, not a playback control.
- `clearLoop()` while playing re-arms from the current position so the song
  plays through rather than stopping at the old loop end.
- `WaveformPracticeView` is at the SwiftLint file-length limit; the next addition
  should be preceded by extracting a view model or splitting the file.

## Alternatives considered

- **Keep a repeat on/off toggle** — rejected: an active loop already encodes
  "should this loop?"; the toggle duplicates state. Count-based repeats belong to
  the automator.
- **`scheduleBuffer(.loops)`** — rejected for V1: it loops a whole buffer, not a
  precise seekable file region, and complicates rate/seek interplay. Revisit for
  gapless.
- **Tap the active loop row to toggle off** — rejected: collides with the row's
  play/pause; the explicit ✕ chip is clearer.
