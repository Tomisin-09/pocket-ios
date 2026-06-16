# 0005 — Waveform gesture engine: one drag recogniser, pure math, mode dispatch

- **Status:** Accepted
- **Date:** 2026-06-15

## Context

The practice screen has three interaction modes (Scroll / Tap / Fine, brief
§4.1). Until now a transport **+** button stood in for loop capture and there was
no way to seek, scrub, drop a marker, or define a loop directly on the waveform.
This ADR records how the gesture engine that replaces the stand-in is built.

The natural SwiftUI approach — composing `TapGesture`, `LongPressGesture` and
`DragGesture` per mode — has two problems: `LongPressGesture` reports no
location (so a hold can't know *where* to drop a marker), and composing three
different gestures across three modes is conflict-prone (a tap that's really the
start of a drag, a long-press that should suppress the trailing tap).

## Decision

- **One `DragGesture(minimumDistance: 0)` per render, dispatched by mode.** It
  yields a location for every phase, so taps, scrubs, holds and handle-drags all
  flow through one place with explicit thresholds:
  - **Scroll:** a press starts a 650 ms timer (an amber ring fills under the
    finger); firing drops a marker, movement > 10 px cancels it, and a clean
    release that neither held nor dragged is a seek.
  - **Tap:** movement > 6 px is a live scrub (seek); a near-stationary tap sets
    the loop start, the next closes it.
  - **Fine:** the press grabs the nearer of two blue handles and drags it.
- **All gesture math lives in pure `WaveformGesture`** (point→fraction, bound
  ordering + minimum width, handle hit-testing, handle movement). It is
  unit-tested; the view emits **fractions (0…1)**, never points, so the screen
  stays geometry-free.
- **Fine handles are drawn in the `Canvas` and hit-tested by fraction**, not
  hosted as separate draggable views — one gesture pipeline, no overlapping hit
  targets. Entering Fine seeds a selection (the active loop, else a span at the
  playhead) and opens the creation panel; leaving Fine discards an unsaved one.
- **The transport + button stays as an accessible quick-capture.** Gesture
  capture is primary, but the waveform surface is not yet VoiceOver-operable, so
  + remains a one-tap, VoiceOver-reachable path to capture a loop at the
  playhead.

## Consequences

- The waveform gesture surface is **not VoiceOver-operable yet** (seek, scrub,
  marker drop, loop define). The accessible equivalents are the transport
  buttons, the + quick-capture, and the loop/marker rows. Adding accessibility
  actions to the waveform is a follow-up.
- The 650 ms hold uses a `Timer`, invalidated on gesture end/cancel so a stale
  hold can't drop a marker after the finger lifts.
- Gesture-created loops enforce a minimum width (`WaveformGesture.minLoopWidth`),
  so a stray double-tap or pinched Fine selection can't make a zero-width loop.
- Thresholds (scrub 6 px, hold-cancel 10 px, handle tolerance 0.06) are tuned by
  feel on device; they live as constants on `WaveformView`.

## Alternatives considered

- **Compose `TapGesture` + `LongPressGesture` + `DragGesture` per mode** —
  rejected: `LongPressGesture` gives no location, and cross-mode composition is
  fiddly and conflict-prone.
- **Remove the + capture button entirely** — rejected: gesture capture isn't
  VoiceOver-operable yet, so + remains the accessible capture path.
- **Separate draggable handle views in Fine mode** — rejected: drawing handles
  in the `Canvas` and hit-testing by fraction keeps a single gesture pipeline and
  avoids overlapping hit targets at the bounds.

## Update (2026-06-16) — UX polish from on-device use

First-finger testing surfaced refinements, now decided:

- **Capture is two steps: confirm then name.** Closing a loop (Tap) or selecting
  one (Fine) shows a keyboard-free **ConfirmBar** (range + ✓/✗); ✓ opens a native
  **naming sheet**. This fixed the inline naming panel being occluded by the
  keyboard, and lets the captured range be verified (and re-heard) before naming.
- **Tap mode previews audibly.** The first tap seeks + plays from the start and
  the loop region fills green up to the live playhead; the second tap stops and
  confirms. This replaced the redundant green "pending start" line.
- **Scroll mode drags to scrub** (tap = jump, hold = marker, drag = scrub), via
  the same movement-threshold dispatch already in the recogniser.
- **A live time bubble rides the playhead** in all modes (chosen over a fixed
  transport readout) — the readout is where the eyes already are.
- **Loop & marker lists are unified:** tap a row to *use* it (activate loop /
  seek to marker), edit via a trailing pencil. Previously loops were tap-to-edit,
  which conflicted with marker tap-to-seek.
- **An existing loop's range is editable in Fine mode** ("Adjust range" on the
  loop's edit sheet), so `Loop.start/end` became mutable; the reference area dims
  while adjusting to focus the waveform.

**Consequence:** `WaveformPracticeView` grew enough to split — shared chrome moved
to `WaveformChrome.swift`, capture models to `WaveformLoopCreation.swift`, and the
action handlers into a same-file extension. Region looping, pinch-to-zoom, undo,
and snap-to-marker remain follow-ups on their own branches.

## Update (2026-06-16, round 2) — capture flow

A second on-device pass tightened the capture interaction:

- **Confirm is an icon-only pill over the waveform**, not a bar below the
  transport. The bar showed the range as text, which read as an editable name
  field; the pill is just ✓/✗ floating on the waveform and commits/discards the
  highlighted region. Naming still happens in the sheet after ✓.
- **Tap mode is punch in/out.** Taps no longer seek — they mark the loop start
  and end at the *current playhead* (playback runs between them, filling green).
  The only way to move the playhead in Tap mode is to drag. This removed the
  "tap jumps the playhead to my finger" surprise; tapping is a transport-style
  punch, not a position set.
- **Discarding a name keeps a Fine selection.** The capture stays live while the
  naming sheet is open; a Save consumes it, but a Discard leaves a Fine
  selection's handles + pill in place to re-adjust (a Tap capture still clears).
  The `naming-sheet onDismiss` distinguishes the two by whether `capture`
  survived the Save.
