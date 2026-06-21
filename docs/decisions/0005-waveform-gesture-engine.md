# 0005 — Waveform gesture engine: one drag recogniser, pure math, mode dispatch

- **Status:** Accepted
- **Date:** 2026-06-15

> **Amendment (2026-06-21, `pocket-036`):** the long-press-drag select (round 5)
> originally anchored the selection at the **touch point** where the hold fired.
> It now anchors at the **playhead** and paints out to the finger, so a hold-drag
> punches a loop in *where playback is* — matching Tap-mode's punch-in-at-playhead
> (`tapPunch`) — and the drag sets the other end. Only `beginDragSelection`'s anchor
> changed (`dragSelectAnchor = playheadFraction`, initial bounds via the same pure
> `selectionBounds`); the live drag, release, and commit are untouched.

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

## Update (2026-06-16, round 3) — edit mode is modal

On-device, the loop-edit state read too much like "just being in Fine mode" — you
couldn't tell you were mid-edit (and had to confirm/discard), and a newly-captured
loop couldn't be heard before saving.

- **The transport bar greys out and locks while a loop is captured** (a capture is
  active), so the edit state is unmistakably modal. The play button and mode pills
  go dim/disabled; you leave edit mode via Y/N, not by switching modes.
- **The mode-instructions line is replaced by an `EditToolbar`** — a ▶︎ audition
  button, a **"New loop" / "Editing loop"** state label, and the decision pill.
- **The decision is Y/N letters, not ✓/✗.** Same green-confirm / red-discard scheme;
  letters read less like an icon you might confuse with the loop name.
- **Audition before saving.** The ▶︎ loops the *captured* region (Tap or Fine) so you
  hear exactly what you made before committing. The engine loop is armed to the
  capture on creation (`previewCapture`); the button toggles play/pause
  (`auditionCapture`). This supersedes round 2's "icon-only ✓/✗ pill over the
  waveform".

## Update (2026-06-17, round 4) — tap = seek; capture via buttons

Pinch-to-zoom (ADR 0010) showed the three-mode model was overloaded: tap meant three
different things, and the hold-to-drop-marker gesture raced with pinch (both start on
the first finger down). Rationalised:

- **Tap always seeks.** Scroll and Tap modes collapse into one **navigate** behaviour
  (tap = seek · drag = scrub · pinch = zoom). `InteractionMode` is now `{ navigate, fine }`.
- **Capture moves to buttons** on the transport's second row (the old mode pills): a
  **Mark** button (`mappin`) drops a marker at the playhead, a **Loop** button (`repeat`,
  a single in→out toggle) punches the loop at the playhead, and a **Fine** toggle
  (`slider.horizontal.3`) enters precise handle-editing. A reserved **A** slot
  (`metronome`) is the future automator entry (ADR 0009). The underlying `dropMarker`
  and `tapPunch` logic is unchanged — just button-triggered.
- **The hold-to-drop-marker gesture is removed entirely** (timer, fill ring, and all),
  which deletes the pinch↔hold race and a chunk of `WaveformView` state.
- **The time ruler follows the zoom** — it labels the visible window, not the whole song.

This supersedes round 2's "Tap mode is punch in/out" and the original Scroll-hold marker
drop. Fine mode and the loop edit flow (audition + Y/N, ADR 0005 round 3) are unchanged.

## Update (2026-06-19, round 5) — long-press-drag to select a loop

The action-bar **Loop** button punches a loop at the *playhead* (in→out), but defining a
loop's **range directly on the waveform** still meant entering Fine and nudging two handles.
Round 4 freed the long-press slot (the hold-to-drop-marker gesture was deleted), so it's
now the primary deliberate loop-creation gesture:

- **Navigate mode: a still hold (~350 ms) then drag paints a loop region.** The hold arms
  the selection (medium haptic confirms the switch from scrub to select); the drag grows the
  green region under the finger; release commits it to a confirmable draft (auto-named on Y,
  ADR 0019). A quick drag (movement before the hold fires) is still a scrub; a tap is still a
  seek — disambiguated purely by **hold duration**, the established single-`DragGesture`
  threshold model.
- **Still one `DragGesture(minimumDistance: 0)`, not a composed `LongPressGesture`.** The hold
  is a cancellable `Task` timer inside the existing recogniser (the same mechanism the original
  650 ms marker-hold used, re-expressed Swift-6-clean as a `Task` instead of a `Timer`). This
  keeps ADR 0005's core decision intact: one pipeline, explicit thresholds, no cross-gesture
  composition.
- **Live drag is exact; commit widens to the minimum.** New pure `WaveformGesture.selectionBounds`
  orders anchor+current with no min-width, so the region tracks the finger precisely; the
  commit runs it through `loopBounds` (min-width) so a barely-moved hold still makes a usable
  loop. Both unit-tested.

**Gesture arbitration re-checked (now four gestures).** Reintroducing a hold timer reintroduces
the pinch↔hold race round 4 had removed (both start on the first finger). Mitigation: the hold
`Task` is cancelled, and any already-armed selection aborted (`onSelectCancelled`), the moment
`MagnifyGesture.onChanged` fires — so a second finger is always authoritative for zoom. The
existing `didPinch` latch (magnify's `onEnded` precedes the drag's, swallowing the phantom
tap) is unchanged; the drag's `onEnded` cancels the hold and commits a selection only when no
pinch was involved. The selection is also gated so it can't start while a capture/forming
region is already live (`canBeginSelection`), and the edit toolbar/transport lock stay back
until release (`isDragSelecting` gates `showConfirm`) so the transport doesn't flicker mid-drag.
