# ADR 0222 — add to routine from the row

- **Status:** Accepted. Built on `pocket-332-add-to-routine-hold`.
- **Date:** 2026-09-25
- **Relates to:** ADR 0066 (the routine model, and `order` as play order), ADR 0071 (the routine
  editor opens read-only and edits behind **Edit** — unchanged; this is a second door, not a way
  into that screen), ADR 0090 (present a sheet by a stable id), ADR 0127 (the editor's picker: a tap
  adds, a second tap takes back what *this* picking session added), ADR 0138 (a loop's modes are
  decided per mode, by `LoopModeAccess`), ADR 0144 D1 (routines are Pro), ADR 0210 D1 (*Add to
  folder…*, the menu entry this one sits beside).
- **Schema:** none.

---

## Context

A routine can only be extended from inside it: open Routines, open the routine, tap **Edit**, tap
**Add**, then walk the picker's buckets back to a drill or loop the player was very likely looking
at a moment earlier. The Exercises and Loops libraries are where a player *finds* the thing worth
adding, and neither offered a way to add it.

## Decisions

**D1 — Both libraries' hold menus gain *Add to routine…*.** On an exercise it sits after *Add to
folder…* and before *Duplicate*, so the two "put it somewhere" entries are neighbours. On a loop it
follows the loop's run modes. The ellipsis is the platform's "this opens something that asks you
more", as on *Add to folder…*.

**D2 — The entry opens a sheet listing every routine, A→Z, and a tap is a toggle.** The first tap
appends the block as the routine's **last**; a second tap on the same routine takes back the block
*this sheet* added, and never an earlier copy — the editor picker's grammar (ADR 0127 §2), and its
session-scoped ledger. The sheet stays open, so one drill can go into two routines in one visit.
A routine that already holds the same block says *already in it* under its name: a routine may
hold a drill twice on purpose (ADR 0127), so this informs rather than refuses.

Rejected: a submenu of routine names inside the hold menu. It saves a tap, but a menu cannot show
a routine's contents, cannot say *already in it*, cannot be taken back, and grows without limit.

**D3 — A loop asks which block it becomes, from the modes it qualifies for.** A loop block runs in
a mode (trainer, ear, improvise), so the sheet shows a segmented **Add it as** control built from
`LoopModeAccess.modes(for:)` — the list its row buttons and menu already come from — and only when
there is more than one. A loop that qualifies for no mode — unmeasured, over audio that can't be
played (ADR 0001) — is offered no *Add to routine…* at all.

**D4 — Each tap saves.** The routine editor sandboxes its edits because an edit there is many steps
with a Cancel at the end. Here each step is one block with its own take-back in the same row, so
there is nothing for a sandbox to protect. And the save is **required**, not a nicety: the editor
opens each routine in a fresh `ModelContext` that reads the store, so an append left in the main
context would be invisible there the moment the player went to look.

**D5 — The editor's gate, and the editor's paywall reason.** Adding a block is editing a routine,
so the row checks `AccessPolicy.canAddRoutineUnits` and presents `.routine(.edit)`. No new
analytics case: the act is the same one the editor already reports.

**D6 — *New routine…* is in the sheet.** It makes a named routine with this unit as its first
block — the folder picker's *New folder…*, for the same reason: a player with no routine that fits
should not be sent to another library and back to find the drill again.

**D7 — One mapping from a pick to a block.** `RoutineUnitPick.block(order:)` is the only place a
pick chooses a factory, and `Routine.nextOrder` / `renumberItems()` the only place an append or a
removal lays out `order`. The editor now calls both, so a loop added as ear training from its row
is the block the editor's *Ear training* bucket makes.

## Consequences

- The manual's Exercises and Routines pages and the Loops section of *Practice* name the new entry.
  No figure shows either library's hold menu (`docs/manual/shots.md`; the only row-menu figures are
  the song library's), so nothing goes stale and the owed reshoot gains no shot.
- A block added from a row lands at the **end**. Placing it elsewhere is still the editor's job;
  the sheet says so in its footer.
