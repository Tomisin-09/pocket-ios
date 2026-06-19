# 0019 — Instant auto-named loop creation + undo-on-delete toast

- **Status:** Accepted
- **Date:** 2026-06-19

## Context

Creating a loop forced a naming step. Confirming a punch (Tap) or a Fine
selection (the edit toolbar's **Y**) opened a modal `LoopNameSheet`; only after
typing a name (or accepting an empty field that fell back to a time-range string)
was the loop actually created. ADR 0005 designed this two-step "keyboard-free
confirm, then name" flow.

In practice the sheet is friction: you've already drawn the region on the
waveform, and most loops don't need a bespoke name up front — the range *is* the
identity. The extra modal between "I picked a section" and "it's looping" works
against the app's quick-capture intent.

Separately, deleting a loop or marker was unrecoverable — a single tap in the edit
sheet destroyed it with no safety net.

## Decision

- **Create loops instantly, auto-named, no sheet.** Confirming a capture (**Y**)
  now creates, persists, and activates the loop immediately with an auto name
  ("Loop 3"). The naming sheet, `NamingDraft`, `saveNamed`, and `namingDismissed`
  are removed; `confirmCapture` calls `createLoop`. You rename later from the loop
  row (`LoopEditSheet`), where renaming already lived.
- **Auto names track a high-water mark, not a count.** `AutoName.next(prefix:existing:)`
  returns one past the highest trailing number among existing `"Loop <n>"` names,
  ignoring user-typed names. So deleting "Loop 2" of {1,2,3} yields "Loop 4", never
  reissuing a number still in use. It's pure and unit-tested (the numbering collides
  silently without coverage) per AGENTS.md.
- **Markers keep their naming sheet.** A marker *is* its label ("Tricky bend") — a
  single point carries no range to identify it, so auto-naming "Marker 3" would gut
  its value. The marker flow (`dropMarkerAtPlayhead` → `MarkerNameSheet`) is
  unchanged. The instant-create change applies only where the annotation is
  self-identifying.
- **Undo toast on delete (loops and markers).** Deleting shows a transient
  "Deleted X · Undo" pill at the bottom of the cockpit, auto-dismissing after ~4s.
  Undo re-creates the item from a field snapshot taken before the delete —
  **same `uid`** and (for loops) the same automator config — and restores it as the
  active loop if it was. A second delete replaces the toast (the latest delete is
  the undoable one). The timer is a cancellable `Task` owned by the model.
- **Undo on delete only, not create.** An accidental create is trivially reversed
  (delete it), and the instant-create flow has no modal to regret; the toast is
  reserved for the destructive, easy-to-regret action.

## Consequences

- Loop capture is one tap shorter: draw → **Y** → looping, named, done. The
  loops panel fills with "Loop 1/2/3…" until renamed.
- Undo restores identity faithfully (same `uid`), so anything keyed on the loop's
  business id (active tracking, future journal links) survives a delete+undo.
- `Loop`/`Marker` gain no fields; the snapshot lives in the delete closure.
- This reverses ADR 0005's naming-sheet-on-create step for loops (markers keep it).
  ADR 0005's edit toolbar, audition, and Y/N model are otherwise intact.

## Alternatives considered

- **Pre-fill the naming sheet** with the auto name (one-tap Save) — rejected: still
  a modal between picking a region and hearing it loop; doesn't remove the friction,
  just the typing.
- **Auto-name markers too** for consistency — rejected: a marker's label is its
  entire purpose; "Marker 3" is a worse default than making you name it.
- **Undo on create as well as delete** — deferred: create is cheap to reverse and
  has no modal to regret; revisit if quick-capture produces stray loops in practice.
- **SwiftData `undoManager`** for undo — rejected as heavier than needed: a
  field snapshot + re-insert is enough for single-item undo and keeps the context
  configuration unchanged.
