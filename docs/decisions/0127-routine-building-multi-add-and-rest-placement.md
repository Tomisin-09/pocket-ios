# ADR 0127 — The add-to-routine picker adds without closing; rests are placed into gaps, and never next to a rest

- **Status:** Accepted
- **Date:** 2026-07-29
- **Amends:** **ADR 0066** (the routine model's `rest` block gains an authoring rule — adjacency is
  now refused, though nothing about the stored model changes) and the picker behaviour introduced in
  its slice 2 (a pick no longer dismisses the sheet). Extends **ADR 0104 Slice 2** (the ear-training
  bucket is one of the four that multi-add covers) and leaves **ADR 0071**'s edit-gating and
  **ADR 0112**'s free-taste demo limits exactly as they were.
- **Number note:** 0120 is still reserved for the analytics/privacy ADR (`docs/backlog.md` Slice 8).

## Context

Slice 7 of the device-testing plan. Building a routine of any size is currently a loop of the same
four taps: tap **Add exercise, loop or song**, drill Exercises → Scales, tap a drill — and the sheet
closes. To add the next one you reopen the picker and walk back down the same two levels. A
six-block routine is six round trips, five of them re-treading a path you were standing on a second
earlier.

Rests are worse. **Insert rest** appends to the end of the list, so a rest that belongs between
blocks 2 and 3 is added at position 7 and then dragged up four rows in edit mode. And nothing stops
you appending a rest to a routine that already ends in one, which produces two rest rows that the
player announces as two separate breaks.

The device notes asked for three things: multi-select when adding units; a **hold** on *Insert rest*
that enters a mode where tapping between two blocks inserts a rest there; and a "rest already here"
message when the tapped position already has one — with the same guard applied to the plain
*Insert rest* path.

## Decision

### 1. A pick adds and the picker stays open; no selection mode, no deferred commit

Tapping a row in `AddRoutineUnitSheet` adds that unit to the routine **immediately** and leaves the
sheet where it is. The row flips to a filled check, a tally appears at the bottom of the stack
("3 blocks added"), and a second tap on a checked row takes that block back out. **Done** closes.
Blocks land in tap order.

Two alternatives were weighed and rejected:

- **Hold a row to enter a selection mode** (the ADR 0125 grammar, where a plain tap keeps today's
  add-and-dismiss). It preserves the one-tap single add, but it hides the whole feature behind a
  gesture nobody will find in a *picker* — 0125's hold works because the panel header is a fixture
  you return to daily, whereas this sheet is transient. It also has to carry a selection across
  three levels of drill-in with a bar visible at each.
- **Checkboxes from the moment the sheet opens, committed by "Add 3"**. Nothing lands until you
  confirm, so backing out is free — but it puts a commit step in front of an action that is already
  provisional. Every edit on this screen is sandboxed and reversible by **Cancel** (ADR 0071); a
  second, sheet-local commit would be the only place in the app where you confirm a change twice.

The cost of the chosen shape is real and accepted: a single add now needs a **Done** tap where it
used to dismiss itself. That is one tap paid on the smallest job to remove five round trips from the
common one — and the sheet no longer *vanishing* is what makes the tally, the checkmarks and the
un-add possible at all.

### 2. The picker keeps no state; the editor owns what was added

`AddRoutineUnitSheet` holds no selection of its own. The editor keeps `pickID → RoutineItem.uid` for
the open session and hands the picker the id set each render, so a checkmark is drawn *because* a
block exists, not because a tap was recorded. `RoutineUnitPick.pickID` is the single definition of a
row's identity — the picker builds its rows from it and the editor keys its map on it, so the two
cannot drift into a state where a checked row removes the wrong block.

The toggle is scoped to the **session**, not the routine: it removes only the block *this* sheet
created. A routine may legitimately hold the same drill twice (a warm-up pass and a focused pass are
a real shape), and blocks added on an earlier visit are the user's structure, not this sheet's to
reclaim. Closing the sheet clears the map — reopening it presents every row unchecked, because the
question it answers is "what did I just add?", not "what is in this routine?".

### 3. Holding *Insert rest* turns the block list into insertion slots

The hold opens **rest-insert mode**: a tappable gap appears before every block and one at the end —
`blocks + 1` slots — each reading *Rest here* beside a dashed hairline. A tap drops a rest into that
slot and re-lays every block's explicit `order` (ADR 0066 R2). The mode stays open, so a routine can
be broken up in one pass. **Done placing rests** leaves it.

Rejected: an "add rest after" chip on each block row. It needs no mode and no hold, but it puts a
permanent control on every row of a list that is read far more often than it is restructured, and it
can't express the slot *before* the first block.

While the mode is live the list belongs to the gaps. Drag-reorder and swipe-delete are suspended
(`editMode` goes inactive without leaving edit mode), and block rows go inert in both directions —
no reps editor, no preview push. Every tap on that screen is a placement, so a mis-aimed one must do
nothing rather than something else. Leaving edit mode via **Save** or **Cancel** leaves rest mode
with it; its only exit is an affordance that the add section hides.

**The row is not a `Button`.** A SwiftUI `Button` runs its action on the release of a long press as
well, so a hold on a `Button` would enter the mode *and* append a stray rest. This is the third time
this trap has been hit in this codebase (ADRs 0124 and 0125); the fix is the same as there — a plain
shape with separate `.onTapGesture` and `.onLongPressGesture`. The row also carries a visible
**"Hold to place"** hint, since a gesture with no affordance is a feature nobody uses.

### 4. One rule: a rest may not sit next to a rest — and it explains itself where you tapped

`RoutineBudget.allowsRest(at:in:)` is the whole guard, and both paths ask it: the gap rows refuse
the two slots either side of an existing rest, and the plain **Insert rest** tap refuses to append
to a routine that already ends in one. A refused gap is drawn muted and **still takes the tap**,
answering with a popover anchored to it — *"Rest already here. Two rests in a row is just one longer
break. Give the rest that's already there more time instead."* An inert, silent gap would leave the
user tapping a row that does nothing with no reason given.

Nothing else is forbidden. A rest at the head or the tail of a routine is a legitimate shape — you
may want to start on a breather, and the append path has always produced the trailing one — so the
rule stays a single sentence a user can hold in their head. The rule is **authoring-only**: the model
is untouched, no migration is owed, and a routine that already contains adjacent rests (a generated
session, a hand-built one) still loads, still runs, and can still be dragged around. We refuse to
*create* the shape; we don't police one that exists.

### 5. Every grouped level offers "All …", but grouping stays the way in

Exercises → templates and Loops/Ear training → songs both assume you know which group a unit landed
in. You often don't: a drill you named "Sweep 4s" is findable by name and not by remembering it was
made under Arpeggios. So each grouped level carries an **All exercises / All loops / All ear
training** row — the same units, flat and A→Z.

It sits in a **section of its own above the groups**, not as a ninth group: it isn't a peer of the
groups, it's the way *past* them, and a section break says that without a word of copy. The groups
keep the bulk of the screen and stay the default path, which is what makes this an escape hatch
rather than a replacement. It's hidden when there's only one group, where it would just be that
group again under another name.

**Songs are untouched** — a song is a top-level entity with nothing to group by, so that bucket is
already the flat list this row produces.

In the flat exercise list the **template moves onto the row** as its context line. In the grouped
list that fact is carried by the section you walked through to get there; drop the walk and it has to
be carried by the row, or an "All" list of similarly-named drills is unreadable. Loop and ear rows
already show their song, so they are the same rows the groups render.

### 6. The picker can create what it doesn't have *(amendment, 2026-08-11)*

*From a device-testing note: "there should be a create an exercise option available when adding an
exercise to the routine."*

§1 through §5 assume the unit you want already exists. When it doesn't, the picker is a dead end: a
player building a routine who has no scales drill has to dismiss the sheet, leave the routine editor,
go to Practice → Exercises, create it, come back, reopen the picker, and re-find it. Six steps to
recover from being one drill short, and the routine they were mid-thought about is behind all of
them.

`UnitPickList` — and its empty state, which currently reads a bare "Nothing here yet." — gains a
create row presenting `NewExerciseSheet`.

Four constraints:

- **It commits through `NewExercisePlan.finalise(in:)` and nothing else.** ADR 0128 made that the one
  insert path and its doc comment says so; this is a third host of an existing sheet, not a third way
  to make an exercise.
- **The created exercise lands in the routine immediately**, via the same `onToggle` every other pick
  uses — so §2 holds (the picker still keeps no selection state, the editor still owns
  `addedPickIDs`) and the "N blocks added" tally counts it. Creating a drill and then making the
  player find it in the list would be the wrong ending to the gesture they actually made.
- **The leaf's template is passed as `fixedTemplate`**, so creating from inside "Scales" starts on a
  scale. The same seam `MetronomeAutomatorPanel`'s "Save as exercise" already uses. Creating from the
  flat "All exercises" list of §5 has no template to pass and opens the picker step normally.
- **It carries the same Pro gate as every other authoring entry point.** Authoring is Pro
  (`ExerciseTemplatePicker` raises `.newExercise(template)`); a create door that skips the gate is a
  hole in the paywall, not a convenience.

The rest-insertion rules of §3 and §4 are untouched — this adds a unit, and a unit is never adjacent
to itself in the sense §4 refuses.

## Consequences

- **The picker's callback surface collapses from four to one.** `onPickExercise`/`onPickLoop`/
  `onPickSong`/`onPickEarLoop` become a single `onToggle: (RoutineUnitPick) -> Void`. Adding a fifth
  bucket later is a case, not a parameter.
- **A single add costs one more tap.** Accepted above. If device use says otherwise, the fallback is
  to auto-dismiss when the tally is still at one on the first pick — but that would make the sheet's
  behaviour depend on how much you had already done, which is worse than a consistent Done.
- **`RoutineDetailView` splits again** — `+Units.swift` (the adders and the toggle) and
  `+Rests.swift` (both entry rows, the gaps, the guard) — to stay under the 400-line cap, and
  `AddRoutineUnitSheet` sheds its drill-in levels to `AddRoutineUnitLists.swift`.
- **`editContext`, `insert` and `nextOrder` go internal.** Cross-file extensions on a `View` can't
  see `private` members; this is the same accommodation `routine`/`isEditing` already made.
- **A rest inserted mid-list is spliced into the displayed order before the insert, not read back
  after it.** A new item sharing an `order` with the block it displaces is ordered against it by the
  `uid` tiebreak in `RoutineItem.ordered` — a coin flip over which side of the tapped block the rest
  lands on.
- **The free-taste demo is unaffected.** Both the picker and the rest rows sit behind `canAddBlocks`
  (ADR 0112), so a free player still cannot extend the curated routine by any of these paths.
- **The pure guard is unit-tested** (`RoutineBudgetTests`); the gestures are not, and are
  device-verified. Neither half of Slice 3's two wiring bugs would have been caught by a test either
  — that is the standing shape of this risk, not a gap this slice introduces.
