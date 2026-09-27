# ADR 0226 — a search in view, a shorter marker, a longer loop hold

- **Status:** Accepted. Built on `pocket-335-quick-wins`.
- **Date:** 2026-09-27
- **Amends:** ADR 0221 D3 — a loop's holds range over **1…32 passes**, no longer the shared 1…12
  intervals; an exercise's stay 1…12 intervals of four bars. The *Open* note in 0221's *As built*
  about the 96-pass reach of the old controls is closed by this. Everything else in D3 stands.
- **Amends:** ADR 0037 — a dropped marker is named **"M3"**, not "Marker 3". The instant drop, the
  rename from the row, and the high-water numbering all stand.
- **Amends:** ADR 0178 D8 — its last paragraph kept Exercises and Loops on the default search
  placement and left aligning them to the backlog. They now take `.always` as Routines does (D1).
- **Amends:** ADR 0042 — the implementation note's *"widens the mask on appear and reverts to
  `.portrait` on disappear"* becomes a counted lease (D4). The policy — landscape on the practice
  screen only — stands.
- **Relates to:** ADR 0019 (instant loop create, the other `AutoName` caller) · ADR 0050 (Settings
  V1, whose *Keep screen awake* became the lease this copies) · ADR 0078 (the dwell's 1…12, which is
  still the exercise range) · ADR 0189 (no schema change here, so nothing to weigh).
- **Schema:** none. Marker labels already stored are untouched; the hold ceiling is not stored.

## Context

Reviewing the build before the manual reshoot (2026-09-26) turned up a set of small things, each
already logged or flagged somewhere, and each changing a screen the reshoot will photograph. The
player picked all of them, and the ceiling in D3.

## Decision

### D1 — Exercises and Loops show their search bar without a pull

`.searchable(placement: .navigationBarDrawer(displayMode: .always))`, the choice Routines made in
ADR 0178 D8 and `SearchablePickerList` before it. Under an inline title the default hides the bar
until the list is pulled down, and does so differently by OS version — in the tree from launch on
iOS 26, absent on iOS 18 — so it was two behaviours, and on one of them a search most players would
never find. All three practice libraries now claim a search in `docs/manual/`, and all three show
one.

The cost 0178 named is real: the bar takes vertical space on every visit, including over an empty
library. Routines has paid it since August without complaint.

`LibrarySearchUITests` asserts the bar with **no pull-down fallback**, unlike
`RoutineLibraryUITests.searchField`: here the placement is the decision, and a fallback would pass
the old behaviour. It can only fail on iOS 18, which is what CI runs.

### D2 — Markers name themselves "M3"

A marker's label floats over the waveform as the playhead nears it, where it competes with the
waveform for width, and "Marker 12" is nine characters saying little. `AutoName.nextMarker` hands out
`M<n>`.

**It counts both forms.** Labels already stored are the player's data and keep their names, so a
song can hold "Marker 1"…"Marker 5". A counter that matched only `M<n>` would find no high-water mark
there and start again at M1 — two markers numbered one, the collision `AutoName` exists to prevent.
So "Marker <n>" and "M<n>" both feed the mark, and that song's next marker is M6. A library will mix
the two forms until old markers are renamed or deleted; that is accepted rather than fixed by a
migration, because renaming a player's labels is not ours to do.

The suffix must be **digits only**. `Int` parses `"+5"` and `"-5"`, and neither is a name `AutoName`
wrote; the loop form tightens the same way.

### D3 — A loop holds up to 32 passes; an exercise still 12 intervals

ADR 0221 D3 gave every phase the dwell's 1…12 intervals. On an exercise an interval is four bars,
so 12 is 48 bars. On a loop an interval is one pass, so 12 is twelve times through — and a short loop,
a one-bar lick, wants more than that. The controls 0221 replaced reached 96 (12 × 8 reps a step).

**32 passes**, chosen over keeping 12 and over returning to 96. It covers *"play it twenty times"* on
a short riff with room; 96 was the product of two steppers, not a number anyone chose.

**The ceiling travels with the shape.** `RunShape.holdCeiling` is set by `Loop.runShape` to
`RunShape.loopHoldCeiling` and defaults to the exercise's 12, and `setHold` clamps to it. The panel
takes no range, so the loop run screen and the loop block preview cannot disagree about it, and no
host can forget to pass it. It is not stored: it is what `Loop.runShape` says on every read.

0221's rule for a hold **already above** the ceiling stands: a folded 96 walks down one pass a tap,
+ does nothing, and once inside 1…32 the range holds.

### D4 — Landscape is a lease

The orientation mask is one process-wide slot, and `.landscapeEnabled()` wrote it straight from
`onAppear` and `onDisappear`. That is right for exactly one screen at a time. When two overlap, the
outgoing screen's `onDisappear` narrows the mask the incoming one just widened, and SwiftUI does not
promise the order. *Keep screen awake* shipped exactly that bug — the screen slept mid-routine,
device pass 2026-08-06 — and was fixed with `KeepAwakeLease`. The gate had the same shape and was
safe only because one screen used it.

`OrientationLease` counts holders; `OrientationClaim` is idempotent both ways; the mask is
`[.portrait, .landscape]` while anyone holds and `.portrait` otherwise; a release is floored at zero;
and the scene is asked to re-evaluate only when the mask changes, since a geometry request is a
rotation the player may see. Nothing changes on screen today.

## Consequences

- **The reshoot owes:** the Exercises and Loops library figures (search bar now in view), and the
  loop Practice Settings figure if it shows a hold. No figure shows a marker's auto name.
- A second rotating screen is now safe to add — the reason 0042 limited landscape to one screen was
  cost, not this, but the mechanism no longer adds a constraint of its own.
- A library mixes "Marker 3" and "M4" until the player renames. Deliberate (D2).
- `docs/backlog.md`'s two entries — the hidden search bars and the terse marker labels — are done
  and removed.

## Alternatives considered

- **Rename existing "Marker n" labels to "Mn"** — rejected: a migration over the player's own text
  to tidy a default, and a label they chose to keep as "Marker 3" is indistinguishable from one they
  never touched.
- **Pass the hold range into the panel from each host** — rejected for the ceiling on the shape: two
  loop hosts, and the failure mode of a forgotten argument is a loop quietly capped at 12 again.
- **Keep 12, or restore 96** — the player chose 32 (D3).
