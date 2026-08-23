# ADR 0180 — marking a block, in one gesture

- **Status:** Accepted
- **Date:** 2026-08-22 (`pocket-282-a-block-worth-recording`)
- **Relates to:** ADR 0179 (the record switch this widens and re-sites), ADR 0069 (practice-take
  recording, and its 2026-08-05 amendment that let ramp-less blocks record), ADR 0104 (ear
  training), ADR 0135 (improvising over a backing track), ADR 0136 (the freeform block, which this
  deliberately leaves out), ADR 0066 R2 (a routine's explicit `order`), ADR 0076 (the reps editor
  behind the same Edit gate), ADR 0127 (rest-insert mode, which borrows the list)
- **Schema:** none. One derived property (`RoutineItem.canRecordTake`); no new field.

## Context

ADR 0179 shipped **Record this block** three days' work ago, and put it in the only place it could
go at the time: the block's read-only preview. Using it turned out to cost more than deciding it
does — open the routine, tap the block, wait for the push, scroll past the audition and the length
control, flip the switch, go back. Five moves to set one flag, repeated per block.

It also stopped short of three block kinds, and one of them is the kind most worth hearing back. An
**improvise** block is a jam over a backing track; ADR 0135's own note calls it *the longest a player
goes without touching the screen*. 0179 excluded it — along with ear training and freeform — on the
grounds that those already record inside a routine (ADR 0069 amendment §2), so a switch would be a
second control over the same behaviour.

That reasoning was half right, and the wrong half matters. Those blocks record **if you remember to
arm them, mid-session, with a guitar in your hands.** That is not the same offer as *this block
records*, and the difference is exactly what 0179 was built to remove.

A third thing surfaced while looking at the block list. `.onMove` was attached to the block `ForEach`
unconditionally, while its sibling `.onDelete` was handed `nil` outside the authoring gate. `List`
reorders a row on a long press whether or not `editMode` is active, so a **saved routine, open
read-only, could be rearranged by a hold that drifted** — silently, with no Cancel on that path and
the sandbox committing the new `order` on the spot. The manual claims the opposite in as many words:
*"**Edit** is what unlocks the changes, so a routine cannot be rearranged by accident."*

## Decisions

### D1 — Every loop mode carries the switch

`RoutineItem.recordsTake` is honoured by trainer, **ear** and **improvise** blocks alike. 0179's
`item.loopRunMode == .trainer` guard is removed.

A ramp-less block **never auto-starts**, so unlike a ramped one its own arm ring is genuinely
reachable while it runs. The switch therefore *pre-arms* rather than replaces: at `.onAppear` the
block calls the same non-prompting `armIfPermitted()` the ramped screens use, the on-screen controls
render as already armed, and a player who changes their mind can disarm this one run without
touching the routine. **One behaviour, two doors — not two switches.** That is the distinction 0179
missed.

The copy says so. `BlockRecordControl` gained a `Kind`, and a ramp-less block's on-state line reads
*"The take starts with the backing track and … You can still stop it from the block itself."* An
open-ended block's take *"runs until you tap Done"*, because there is no clock to end it.

**And the subtitle had to change with it**, which is the part that nearly shipped wrong. ADR 0179's
switch says *"hear it back when the block finishes"* — but a ramp-less block **never shows a Done
screen**. There is nothing to grade or promote on one (ADR 0104/0135), so `finishedBlock()` advances
straight past it, and the take row 0179 built could never appear there. The same words on this block
would have promised a screen the player will never see. A ramp-less block hands the take back **in
place** instead — `TakeSavedNote` and the takes list are already on that screen the moment the bed
stops — so its subtitle says *"hear it back on the block itself"*. No Done screen was added: doing
that would reverse three ADRs to hold one row that the block already has a better place for.

### D2 — Freeform stays out, and the rule moves to the model

A freeform exercise records through `RecordTakeToggle` — a live start/stop button, not an arm. There
is no armed state to pre-set, and no start event to hang a take on: the block simply appears. A
switch there would have to mean *"start recording the moment the screen loads"*, which is a
different promise from the one every other block makes, and it would quietly bank the seconds spent
reading the screen. Left out, deliberately and reversibly.

The interesting part is where that rule now lives. Three surfaces have to agree about which blocks
can record — the block-list badge, the swipe that sets the flag, and `RoutineSessionPlayer.stage`
that acts on it — and the failure when they disagree is specific and bad: **a badge promising a
recording that nothing will make.** So it is one derived property, `RoutineItem.canRecordTake`, read
by all three and unit-tested once. The player also `&&`s it against the stored flag, so a flag left
behind by an exercise changing template is dropped rather than badged.

### D3 — Reorder answers to the same gate as delete

`.onMove` is handed `blockMoveAction`, `nil` unless the same rule that permits delete does —
`(isEditing || !existsInStore)`. Reordering and removing are the same authoring act, so they answer
to one gate, and the screen's stated promise becomes true.

A **provisional generated session** keeps the hold-drag, because it is `!existsInStore` and passes
the gate. That screen is a review, editable without an Edit tap, and it already swipes to delete on
exactly those grounds.

Nothing is lost. Reordering was never *meant* to be reachable outside Edit, and inside Edit it is
where it always was: explicit drag handles, no hold required.

### D4 — A leading swipe sets the flag from the list

`Record` / `Don't record` on the block row's **leading** edge, with the waveform glyph and the
practice tint, tinted grey when it is the undo.

Leading on purpose. Trailing is swipe-to-delete in edit mode, and the app's swipe grammar already
reads right-ward as the affirmative, non-destructive one — swipe right to favourite a library row,
swipe right to name a take. It is offered in **both** modes, because the flag was never behind the
Edit gate (0179): it says what the next run should capture, not what shape the routine is.

The preview switch stays. It is where the explanation lives — what the take covers, where it is
saved, why the microphone is off — and the swipe is the shortcut for someone who already knows.
Both call one binding, so the microphone prompt still fires in exactly one place.

### D5 — A swipe onto a dead microphone is refused, not obeyed

The preview's switch can go `.disabled` and say why in a caption beside itself. A swipe has nowhere
to put a caption, and flipping the flag anyway would paint a record badge on a block that cannot
record — the app claiming a take that will never exist. So the swipe raises an alert instead
(**Microphone access is off** · *Open Settings* / *Not now*) and leaves the flag alone.

An alert is the right shape here for the reason the caption is not: it can offer the way out.

## Alternatives considered

**A hold menu on the block row instead of a swipe.** Self-labelling, and it could carry *Repeat…*
and *Remove* alongside. Rejected: the routine's block list has no hold menu today, and adding one
means a second, near-duplicate authoring surface next to Edit mode — the accretion ADR 0077 warns
about. The swipe adds one verb to a grammar the app already teaches.

**A record switch on the freeform block too, starting the take on appear.** See D2. Rejected as a
different promise wearing the same words.

**Removing the drag handles as well, and reordering some other way.** The suggestion that opened
this was *"get rid of the hold + drag function, users can change the order via edit button."* The
first half is D3; the second half was already true — handles have always been edit-mode only. There
was nothing to move.

**Leaving `.onMove` alone because no one has reported it.** Rejected. The damage is silent and
unrecoverable in place: a hold that drifts rewrites `order`, the screen offers no Cancel because you
are not editing, and nothing on screen says anything happened.

## Consequences

- A routine can be marked block-by-block from the list, in one gesture per block, for every kind of
  block that can hold a take.
- An improvise or ear block set to record starts its take with the backing track, and still shows
  its own arm ring so the run can be changed without changing the routine.
- A saved routine can no longer be rearranged from its read-only screen.
- Freeform blocks still record, from their own live button, exactly as before — they are the one
  kind whose recording is not decidable in advance.
- `RoutineItem.canRecordTake` is now the single answer to "can this block hold a take?", and the
  place to change if song blocks ever gain a recorder (ADR 0179 D6).
