# 0028 — Loop rows: hold for settings (rename / range / delete)

- **Status:** Accepted
- **Date:** 2026-06-21

## Context

Each saved-loop row carried an always-visible trailing **pencil** that opened the
edit sheet. It was permanent chrome on every row for an action taken rarely, and it
crowded the row next to the **"A"** automator control. The edit sheet itself still
carried a **Speed** slider and a **Repeats** stepper — leftovers from before those
moved into the automator (ADR 0013). They were dead controls: the automator owns the
ramp now, so editing them here did nothing meaningful.

## Decision

- **Drop the pencil.** The row is now just the play/activate area plus the "A"
  automator button.
- **Press and hold a row to open the edit sheet** — rename, range, and **delete** all
  live in that sheet, so the hold is the single way in. A **medium haptic** fires the
  moment the hold registers, before the sheet animates up, so the gesture confirms
  itself. The "A" button stays put; it's the speed-ramp control, a different concern
  from rename/range/delete.
- **Strip Speed/Repeats from the loop edit sheet.** It's now Name + Range (+ "adjust
  on waveform") + Delete. Speed and repeats live solely in the automator.

Tap and long-press live directly on the row's play area (a bare tap target, not a
`Button`, so the two gestures compose without a control swallowing one of them).
VoiceOver can't long-press, so the row exposes **Edit** and **Delete** as
`.accessibilityActions`.

## Swipe-to-reveal — tried and reverted

The first cut hid Edit + Delete behind a leftward **swipe**, hand-rolled in a
`SwipeToRevealRow` (the panels are custom `CollapsiblePanel`s, not `List`s, so
`.swipeActions` isn't available). On device it had two problems: the per-row
`DragGesture` fought the enclosing `ScrollView`, so vertical scrolling lagged and
stuck; and the reveal state bled through on panel collapse/expand (rows rendered
half-open, overlapping the panel below). Rather than keep fighting gesture
arbitration and render state, the swipe was removed entirely. Delete is reachable
inside the edit sheet, so a dedicated swipe action bought little — the hold covers it.

## Alternatives considered

- **Convert the panel to a `List` for native `.swipeActions`.** Rejected — the panels
  are styled custom surfaces nested in a `ScrollView`; a `List` would fight the
  scroll container and bring its own separators/insets.
- **Hold opens the automator instead of the edit sheet.** Rejected — the "A" button
  already opens the automator; the hold should reach the less-obvious edit sheet.
- **Keep the pencil as well.** Rejected — the point was to declutter the row.

## Consequences

- Editing and deleting a loop both route through hold → edit sheet; the row is clean
  and its only gestures (tap, long-press) don't compete with the scroll view.
- `LoopsPanel` keeps an `onDelete` callback, now used only by the VoiceOver Delete
  action (sighted users delete inside the sheet). The marker rows keep their pencil
  for now; this change is scoped to loops.
- The edit sheet no longer touches `loop.speed` / `loop.repeats`; those fields remain
  on the model, owned by the automator.
