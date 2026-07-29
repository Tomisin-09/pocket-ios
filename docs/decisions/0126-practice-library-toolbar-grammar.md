# ADR 0126 — The practice libraries share one toolbar grammar: leading is where you came from, trailing is what you can do

- **Status:** Accepted
- **Date:** 2026-07-29
- **Amends:** **ADR 0056** (the persisted sort key + direction survive unchanged; what changes is that
  the active key is no longer spelled out on the navigation bar) and **ADR 0119** (the favourites
  filter keeps its per-list scope and its session lifetime, but stops being its own bar button).
  Touches the Routines entry point to the V2 planner's Quick session (**ADR 0066**/**0071**).

## Context

The last device pass found the inline navigation title sitting off-centre in the practice libraries:
on Exercises, "Exercises" was pushed right of centre, and — the tell — it **moved** when the sort key
changed.

The cause is arithmetic, not a layout bug. Exercises carried two `ToolbarItem(placement:
.topBarLeading)` items: the sort control, which renders as a text pill (`↑ Recently Added`), and the
favourites star. Those sit behind the system back button, so the leading group ran to roughly twice
the width of the lone trailing `+`. With `.navigationBarTitleDisplayMode(.inline)` iOS centres the
title in the space the bar-button groups leave over, so a fat leading group shoves it across. And
because the pill's width tracks the label of whichever key is active, changing "Name" to "Recently
Added" widened the group and moved the title again.

It is not one screen's bug. Routines had the same shape (a session-generator wand plus the star,
leading; `+` trailing). Loops was closest to balanced by accident — star leading, sort trailing — but
carried the same variable-width pill. Any fix therefore changes the toolbar grammar of all three, so
it wanted doing once rather than patched per screen, which is why the device-testing plan deferred it
out of Slice 3 rather than folding it in.

## Decision

**One grammar for all three practice libraries: the leading side holds only the back button; the
trailing side holds the list options, then the screen's primary action.**

Concretely:

- Sort key, sort direction and the favourites filter collapse into a **single icon-only menu**,
  `LibraryOptionsMenu`, placed `.topBarTrailing` ahead of the primary action. The icon is
  `ellipsis.circle`, filled when the favourites filter is on.
- The **shared component is the unit of adoption**, as with `pocketRowActions` in Slice 3: a library
  passes its favourites binding and, if it has a sort axis, a `LibrarySortPickers` over its key type.
  The keys unify behind a new Foundation-only `LibrarySortKey` protocol, so `PracticeLibrarySort`
  stays pure.
- On **Routines**, the session-generator wand moves off the bar and into that menu as a labelled row.

Sizes work out: the back button ("‹ Practice") and a trailing group of two 44 pt controls are close
enough to balance, and — the part that actually fixes the complaint — **nothing on the bar changes
width any more**, so the title cannot move.

## Consequences

- **The active sort key is no longer readable from the navigation bar.** It is the checkmarked row
  inside the menu, one tap away, and on Exercises the list's own section headers already restate it.
  This is the real cost, and it is the point: a control that displays variable-length text cannot sit
  in a bar-button group without moving the title. Reintroducing the label — even as a caption under
  the icon — reintroduces the bug.
- **Toggling favourites costs an extra tap.** It was a one-tap star; it is now a menu row. Accepted
  in exchange for a fixed-width group, and it gains a written label, which the bare star never had.
- **The Routines wand is one level deeper**, but it also stops being an unlabelled icon: "Generate a
  quick session" now reads as words, and its two dimmed states (no Pro entitlement → a lock; Pro but
  no non-warm-up exercises to draw from → disabled) are legible instead of mysterious. It is not the
  only route to a generated session — ADR 0118's Library banner reaches the same generator.
- **`ellipsis.circle` rather than a filter or sort glyph**, because on Routines the menu holds an
  action as well as options, and one icon across the three screens is the point. The filled variant
  is the only state the bar carries, and it does not change the control's width.
- Loops loses its trailing sort pill and gains the same menu, so the three screens now differ only in
  what the menu contains, not in where the controls live.

## Alternatives considered

- **Move the sort menu to trailing and leave it a text pill.** The other option the triage recorded.
  It rebalances the groups on Exercises, but the pill is still variable-width, so the title still
  drifts as the key changes — it would just drift the other way. Rejected: it treats the symptom.
- **Keep the label but pad it to a fixed width.** Either the widest key's label sets the width for
  all of them (a permanently fat group) or long labels truncate. Both are worse than the menu.
- **A custom `.principal` title view** to sidestep iOS's centring rule. Fights the platform to keep a
  control the platform is telling us is too wide, and every practice library would need it.
- **Fold the favourites filter into the search scope bar.** Only Exercises and Loops are
  `.searchable`; Routines is not, so it would not have unified the three.
- **Leave Routines alone** — it has no sort axis, so a menu holding one toggle is thin. Rejected: the
  wand gives the menu a second row, and a library that opts out of the grammar is how the three
  drifted apart in the first place.
